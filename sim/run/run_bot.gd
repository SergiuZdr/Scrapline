class_name RunBot
extends RefCounted

## Plays a run: routes, fights (through `CombatBot`), salvage, refits and workshops.
##
## This is the successor to the old game's `verify_loop.gd`, the one test that found a
## starter squad losing its first fight while every unit test was green. It plays the
## REAL run through `RunSim.apply`, so anything it can do a player can do, and anything
## that breaks for it breaks for a player.
##
## Its choices are simple on purpose -- rarity as a stand-in for "better", forward as a
## stand-in for "progress". A run that only a clever bot can win is a balance problem this
## tool should surface, not hide.


## The next action for the run as it stands, or [] if the run is over.
static func next_action(state: RunState, setup: RunSetup) -> Array:
	if state.outcome != RunState.ONGOING:
		return []
	var kind: String = String(state.pending.get("kind", ""))
	match kind:
		"fight":
			return [RunSim.FIGHT, play_fight(RunSim.fight_setup(state, setup))]
		"reward", "scrapyard":
			return [RunSim.PICK, _choose_part(state, setup, state.pending["options"], kind)]
		"workshop":
			for i: int in state.crew.size():
				if not bool(state.crew[i]["alive"]) and state.scrap >= int((setup.rules["workshop"] as Dictionary)["rebuild_cost"]):
					return [RunSim.REBUILD, i]
			if RunSim.needs_repair(state, setup) and state.scrap >= int((setup.rules["workshop"] as Dictionary)["repair_cost"]):
				return [RunSim.REPAIR]
			var refit: Array = _best_refit(state, setup)
			if not refit.is_empty():
				return refit
			var tune: Array = _best_tune(state, setup)
			return tune if not tune.is_empty() else [RunSim.LEAVE]
		"trader":
			return _trade(state, setup)
		"tower":
			return [RunSim.LEAVE]
		# 031: refine the best part it can afford, keeping a rebuild's worth back; one crate at
		# an auction if the scrap is spare; then on.
		"refinery":
			if not bool(state.pending.get("used", false)):
				var reserve: int = int((setup.rules.get("workshop", {}) as Dictionary).get("rebuild_cost", 20))
				var best: int = -1
				for c: int in state.cargo.size():
					var cost: int = RunSim.refine_cost(setup, state.cargo[c])
					if cost >= 0 and state.scrap - cost >= reserve and (best < 0 or setup.rarity(state.cargo[c]) > setup.rarity(state.cargo[best])):
						best = c
				if best >= 0:
					return [RunSim.REFINE, best]
			return [RunSim.LEAVE]
		"auction":
			if not bool(state.pending.get("used", false)):
				var tiers: Array = (setup.rules.get("auction", {}) as Dictionary).get("tiers", [])
				if not tiers.is_empty() and state.scrap - int((tiers[0] as Dictionary).get("cost", 0)) >= 30 and not state.overfull():
					return [RunSim.BID, 0]
			return [RunSim.LEAVE]
		"signal":
			return [RunSim.CHOOSE, _signal_choice(state, setup)]
	var refit: Array = _best_refit(state, setup)
	if not refit.is_empty():
		return refit
	if state.overfull():
		return [RunSim.SCRAP_PART, _worst_cargo(state, setup)]
	var level: Array = _level_up(state, setup)
	if not level.is_empty():
		return level
	return [RunSim.TRAVEL, _choose_site(state, setup)]


## Spends scrap on levels, lowest level first, keeping enough back to rebuild a wreck.
static func _level_up(state: RunState, setup: RunSetup) -> Array:
	var reserve: int = int((setup.rules.get("workshop", {}) as Dictionary).get("rebuild_cost", 20))
	var best: int = -1
	for i: int in state.crew.size():
		var cost: int = RunSim.level_cost(state, setup, i)
		if not bool(state.crew[i]["alive"]) or cost < 0 or state.scrap < cost + reserve:
			continue
		if best < 0 or int(state.crew[i].get("level", 0)) < int(state.crew[best].get("level", 0)):
			best = i
	# The perk: the first of the offer, which is seeded -- a stand-in for a player's taste.
	return [RunSim.LEVEL_UP, best, 0] if best >= 0 else []


## Buys the stock part that would improve the crew most, if it can keep a rebuild in
## reserve; otherwise leaves. It never sells: the hold is emptied by refits and scrapping.
static func _trade(state: RunState, setup: RunSetup) -> Array:
	var reserve: int = int((setup.rules.get("workshop", {}) as Dictionary).get("rebuild_cost", 20))
	var best: int = -1
	var best_gain: int = 0
	var stock: Array = state.pending.get("stock", [])
	for i: int in stock.size():
		var price: int = RunSim.trader_price(state, setup, i)
		if price < 0 or state.scrap < price + reserve:
			continue
		var gain: int = _best_gain(state, setup, String(stock[i]))
		if gain > best_gain:
			best_gain = gain
			best = i
	return [RunSim.BUY, best] if best >= 0 else [RunSim.LEAVE]


## A signal's option: the first it can take that neither moves the Reclaimer nor costs HP
## while the crew is below half; failing that, the last it can take (usually "leave").
static func _signal_choice(state: RunState, setup: RunSetup) -> int:
	var options: Array = ((setup.rules.get("events", {}) as Dictionary).get(String(state.pending.get("event", "")), {}) as Dictionary).get("options", [])
	var hp: int = 0
	var full: int = 0
	for member: Dictionary in state.crew:
		if bool(member["alive"]):
			hp += int(member["hp"])
			full += RunSim.max_hp(setup, member)
	var hurt: bool = hp * 2 < full
	var last: int = 0
	for i: int in options.size():
		if not RunSim.can_choose(state, setup, i):
			continue
		last = i
		var effects: Dictionary = (options[i] as Dictionary).get("effects", {})
		if int(effects.get("front", 0)) > 0:
			continue
		if hurt and (int(effects.get("hp", 0)) < 0 or int(effects.get("hp_one", 0)) < 0 or effects.has("fight")):
			continue
		return i
	return last


## Tunes the rarest fitted part it can afford, keeping half a rebuild in reserve (the full
## reserve left it tuning 0.1 parts a run, too rarely to test the rule). Option `a`.
static func _best_tune(state: RunState, setup: RunSetup) -> Array:
	var reserve: int = int((setup.rules.get("workshop", {}) as Dictionary).get("rebuild_cost", 20)) / 2
	var best: Array = []
	var best_rarity: int = 0
	for i: int in state.crew.size():
		if not bool(state.crew[i]["alive"]):
			continue
		for socket: int in 5:
			var part: String = String((state.crew[i]["parts"] as Array)[socket])
			if not PartTuning.can_tune(setup.parts, part) or state.scrap < RunSim.tune_cost(setup, part) + reserve:
				continue
			if setup.rarity(part) > best_rarity:
				best_rarity = setup.rarity(part)
				best = [RunSim.TUNE, i, socket, 0]
	return best


## The hold part worth least to the crew: lowest rarity, then oldest.
static func _worst_cargo(state: RunState, setup: RunSetup) -> int:
	var worst: int = 0
	for i: int in state.cargo.size():
		if setup.rarity(state.cargo[i]) < setup.rarity(state.cargo[worst]):
			worst = i
	return worst


## Plays a whole fight with the combat bot and returns its action log.
static func play_fight(combat_setup: CombatSetup) -> Array:
	var combat: CombatState = CombatSim.start(combat_setup)
	var actions: Array = []
	var guard: int = 0
	while combat.outcome == CombatState.ONGOING and guard < 60:
		actions.append_array(CombatBot.take_turn(combat))
		guard += 1
	return actions


static func _choose_part(state: RunState, setup: RunSetup, options: Array, _kind: String) -> int:
	var best: int = -1
	var best_gain: int = 0
	for i: int in options.size():
		var gain: int = _best_gain(state, setup, String(options[i]))
		if gain > best_gain:
			best_gain = gain
			best = i
	# Nothing it would fit: the scrap is worth more than a spare part (011: every salvage
	# screen offers it).
	return best


## How much fitting `part` would improve the crew's best-matching socket (rarity, and
## a lot for filling an empty socket).
static func _best_gain(state: RunState, setup: RunSetup, part: String) -> int:
	var slot: String = String((setup.parts[part] as Dictionary).get("slot", ""))
	var best: int = 0
	for member: Dictionary in state.crew:
		if not bool(member["alive"]):
			continue
		for socket: int in 5:
			if RunSetup.socket_slot(socket) != slot:
				continue
			var current: String = String(member["parts"][socket])
			var gain: int = 10 if current.is_empty() else setup.rarity(part) - setup.rarity(current)
			best = maxi(best, gain)
	return best


## `[REFIT, crew, socket, cargo]` for the best improvement the hold offers, or [].
static func _best_refit(state: RunState, setup: RunSetup) -> Array:
	if not RunSim.can_refit(state):
		return []
	var best: Array = []
	var best_gain: int = 0
	for c: int in state.cargo.size():
		var part: String = state.cargo[c]
		var slot: String = String((setup.parts[part] as Dictionary).get("slot", ""))
		for i: int in state.crew.size():
			var member: Dictionary = state.crew[i]
			if not bool(member["alive"]):
				continue
			for socket: int in 5:
				if RunSetup.socket_slot(socket) != slot:
					continue
				var current: String = String(member["parts"][socket])
				var gain: int = 10 if current.is_empty() else setup.rarity(part) - setup.rarity(current)
				if gain > best_gain:
					best_gain = gain
					best = [RunSim.REFIT, i, socket, c]
	return best


static func _choose_site(state: RunState, setup: RunSetup) -> int:
	var options: Array[int] = RunSim.destinations(state)
	var best: int = options[0] if not options.is_empty() else state.current
	var best_score: int = -1000000
	var hp: int = 0
	var full: int = 0
	for member: Dictionary in state.crew:
		if bool(member["alive"]):
			hp += int(member["hp"])
			full += RunSim.max_hp(setup, member)
	var hurt: bool = hp * 2 < full
	for id: int in options:
		var s: Dictionary = state.site(id)
		var score: int = int(s["col"]) * 12
		if bool(s["visited"]):
			score -= 25
		else:
			match String(s["type"]):
				"boss":
					score += 40
				"workshop":
					score += 30 if hurt or state.alive_crew() < state.crew.size() else 4
				"elite":
					score += -20 if hurt else 6
				# 030: a warlord is a detour worth a legendary; a hurt crew passes it by.
				"warlord":
					score += -30 if hurt else 10
				# Fights are where salvage comes from; a bot that detours to every scrapyard
				# plays a run with half the fights a player would take.
				"scrapyard":
					score += 5
				"skirmish":
					score += 9
				"signal":
					score += 6
				"trader":
					score += 3
				"refinery", "auction":
					score += 3
				"arena":
					score += -25 if hurt else 5
				"tower":
					score += 2
		score = score * 1000 + (IntentAI.mix(setup.rng_seed, id, state.moves, 3) & 0x3FF)
		if score > best_score:
			best_score = score
			best = id
	return best
