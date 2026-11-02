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


## 084 (B3): how the bot picks its road. "forward" (the default) leans to the next column;
## "explorer" takes every unvisited site it can reach before going on, sideways first, and steps
## back from a column the front is about to take -- the greedy player the Reclaimer must price.
## Set by the bot tools (`--set bot.route="explorer"`), never by the game.
static var route: String = "forward"

## 085: how the bot takes a run-start deal. "best" (the default): the offered deal that comes first in
## `data/run/deals.json`, whose order is the bot's taste (the file lists the deals the bot rates most
## first); "walk": always WALK ON; any deal id: that deal when offered, else WALK ON. Set by the bot
## tools (`--set bot.deals="walk"`), never by the game.
static var deals: String = "best"

## 086 (T1): how the bot picks a perk and a salvage part. "dry" (the default): each candidate is
## played out by the combat bot on the fight the crew is heading for (`_probe_fight`), the crew
## changed by that candidate alone, and the best result wins -- so a perk that changes a rule can
## beat one that adds a number. "old": the first perk of the offer and the rarest part, as before
## 086. Set by the bot tools (`--set bot.choose="old"`), never by the game.
static var choose: String = "dry"

## 086 (T1): how many rounds of the next fight a dry run plays (`--set bot.dry_rounds=3`).
static var dry_rounds: int = 3


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
		"wreck":
			return [RunSim.RECOVER, _choose_wreck_part(state, setup, state.pending["options"])]
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
		"deals":
			return [RunSim.DEAL, _deal_choice(state, setup)]
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
	if best < 0:
		return []
	# "old": the first of the offer, which is seeded -- a stand-in for a player's taste.
	# 086 (T1) "dry": the perk whose machine does best in a dry run of the next fight.
	return [RunSim.LEVEL_UP, best, _choose_perk(state, setup, best) if choose == "dry" else 0]


## 086 (T1): the perk of machine `index`'s offer that plays best on the next fight; ties keep
## the earlier card (the seeded order, the old choice).
static func _choose_perk(state: RunState, setup: RunSetup, index: int) -> int:
	var offer: Array[String] = RunSim.perk_offer(state, setup, index)
	if offer.size() < 2:
		return 0
	var probe: Dictionary = _probe_fight(state, setup)
	if probe.is_empty():
		return 0
	var best: int = 0
	var best_score: int = -(1 << 40)
	for i: int in offer.size():
		var crew: Array = _crew_copy(state)
		var member: Dictionary = crew[index]
		var before: int = RunSim.max_hp(setup, member)
		member["level"] = int(member.get("level", 0)) + 1
		var perks: Array = (member.get("perks", []) as Array).duplicate()
		perks.append(offer[i])
		member["perks"] = perks
		member["hp"] = int(member["hp"]) + maxi(0, RunSim.max_hp(setup, member) - before)
		var score: int = _dry_score(state, setup, probe, crew)
		if score > best_score:
			best_score = score
			best = i
	return best


## 086 (T1): the fight the crew is heading for, made as a travel there would make it:
## `{ "site", "kind" }`, the fight-type site linked to the current one that the route would take
## (the highest column, then the lowest id), else the first fight site of the next column, else {}.
static func _probe_fight(state: RunState, setup: RunSetup) -> Dictionary:
	var here: Dictionary = state.site(state.current)
	if here.is_empty():
		return {}
	var best: int = -1
	var links: Array = (here["links"] as Array).duplicate()
	links.sort()
	for id: Variant in links:
		var s: Dictionary = state.site(int(id))
		if state.consumed(int(id)) or bool(s["visited"]) or not RunSim.FIGHT_TYPES.has(RunSim.site_kind(state, int(id))):
			continue
		if best < 0 or int(s["col"]) > int(state.site(best)["col"]):
			best = int(id)
	if best < 0:
		for s: Dictionary in state.sites:
			if int(s["col"]) == int(here["col"]) + 1 and RunSim.FIGHT_TYPES.has(RunSim.site_kind(state, int(s["id"]))):
				best = int(s["id"])
				break
	if best < 0:
		return {}
	var kind: String = RunSim.site_kind(state, best)
	return {"site": best, "kind": kind, "fight": RunSim._make_fight(state, setup, best, kind)}


## The crew as plain copies, to change one candidate on without touching the run.
static func _crew_copy(state: RunState) -> Array:
	var out: Array = []
	for member: Dictionary in state.crew:
		out.append(member.duplicate(true))
	return out


## 086 (T1): plays the first `dry_rounds` rounds of `probe`'s fight with `crew` fielded instead of the
## run's crew, and scores it: a win first, then HP the crew lost (a wreck heavily), then HP and
## machines the enemy lost, then the rounds it took.
static func _dry_score(state: RunState, setup: RunSetup, probe: Dictionary, crew: Array) -> int:
	var fight: Dictionary = (probe["fight"] as Dictionary).duplicate(true)
	var player: Array = []
	var k: int = 0
	for i: int in crew.size():
		if not bool(crew[i]["alive"]):
			continue
		if k >= (fight["player"] as Array).size():
			break
		var spec: Dictionary = RunSim.machine_spec(setup, crew[i])
		spec["x"] = int((fight["player"] as Array)[k]["x"])
		spec["y"] = int((fight["player"] as Array)[k]["y"])
		player.append(spec)
		k += 1
	fight["player"] = player
	var combat_setup: CombatSetup = CombatSetup.build(fight, setup.combat_rules, setup.parts, setup.tiles,
		setup.wheel, IntentAI.mix(setup.rng_seed, int(probe["site"]), 17, 0))
	var combat: CombatState = CombatSim.start(combat_setup)
	# What the fight costs and deals, not the HP left: a perk that adds HP now would win every dry run
	# by its own number, before it did anything.
	var start_hp: Dictionary = {}
	for u: GridUnit in combat.units:
		start_hp[u.ref] = u.hp
	var guard: int = 0
	# Only the first `dry_rounds` rounds: a whole fight per candidate made a run 3x slower, and the
	# opening rounds are where a build's difference shows (the rest is mostly cleanup).
	while combat.outcome == CombatState.ONGOING and guard < 60 and combat.round_number <= dry_rounds:
		CombatBot.take_turn(combat)
		guard += 1
	var score: int = 1000000 if combat.outcome == CombatState.WON else 0
	for u: GridUnit in combat.units:
		if u.objective:
			continue
		var lost: int = int(start_hp.get(u.ref, 0)) - (maxi(0, u.hp) if u.alive else 0)
		if u.team == GridUnit.TEAM_PLAYER:
			score -= 1000 * lost + (20000 if not u.alive else 0)
		elif u.team == GridUnit.TEAM_ENEMY:
			score += 600 * lost + (5000 if not u.alive else 0)
	return score - 10 * combat.round_number


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
	var fitting: Array = []
	for i: int in options.size():
		var gain: int = _best_gain(state, setup, String(options[i]))
		if gain > 0:
			fitting.append(i)
		if gain > best_gain:
			best_gain = gain
			best = i
	# 086 (T1) "dry": among the parts it would fit, the one whose refit plays best on the next fight
	# (fitted where `_best_refit` would put it); ties keep the rarest, as before.
	if choose == "dry" and fitting.size() > 1:
		var probe: Dictionary = _probe_fight(state, setup)
		if not probe.is_empty():
			var best_score: int = -(1 << 40)
			for i: int in fitting:
				var crew: Array = _crew_copy(state)
				var at: Array = _refit_socket(state, setup, String(options[i]))
				if not at.is_empty():
					var member: Dictionary = crew[int(at[0])]
					var full_before: int = RunSim.max_hp(setup, member)
					(member["parts"] as Array)[int(at[1])] = String(options[i])
					RunSim._keep_missing(setup, member, full_before)
				var score: int = _dry_score(state, setup, probe, crew)
				var gain: int = _best_gain(state, setup, String(options[i]))
				if score > best_score or (score == best_score and gain > _best_gain(state, setup, String(options[best]))):
					best_score = score
					best = i
	# Nothing it would fit: the scrap is worth more than a spare part (011: every salvage
	# screen offers it).
	return best


## 086 (T1): `[crew, socket]` where `_best_refit` would fit `part` (the largest rarity gain, the
## first found), or [] when it would fit nowhere.
static func _refit_socket(state: RunState, setup: RunSetup, part: String) -> Array:
	var slot: String = String((setup.parts[part] as Dictionary).get("slot", ""))
	var best: Array = []
	var best_gain: int = 0
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
				best = [i, socket]
	return best


## 083: the part pulled from a guarded wreck. The wrecked machine comes back from a rebuild with
## empty sockets, so the part nearly always helps: it is taken (0), unless the hold is already
## full and the part is no rarer than the worst one in it (-1: it would only be scrapped).
static func _choose_wreck_part(state: RunState, setup: RunSetup, options: Array) -> int:
	if options.is_empty():
		return -1
	var part: String = String(options[0])
	if state.cargo.size() >= state.hold_size and not state.cargo.is_empty() \
			and setup.rarity(part) <= setup.rarity(state.cargo[_worst_cargo(state, setup)]):
		return -1
	return 0


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
	if route == "explorer":
		return _explore(state, setup, options, hurt)
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


## 084 (B3): the explorer's road. Any unvisited site beats any visited one; among them the lowest
## column first (a sweep), then the forward bot's taste in site types; a site the front takes with
## this very move counts against it (the crew would stand in consumed ground). The gate waits until
## nothing unvisited is next to the crew. Visited sites only when there is nothing new: then forward.
static func _explore(state: RunState, setup: RunSetup, options: Array[int], hurt: bool) -> int:
	var best: int = options[0] if not options.is_empty() else state.current
	var best_score: int = -1000000
	var here: int = int(state.site(state.current)["col"])
	for id: int in options:
		var s: Dictionary = state.site(id)
		var col: int = int(s["col"])
		var kind: String = String(s["type"])
		var score: int = col * 12 - 400
		if not bool(s["visited"]) and kind != "boss":
			score = 200 - (col - here) * 20 + _taste(kind, hurt, state)
			if col <= int(RunSim.move_preview(state, setup, id)["front_after"]):
				score -= 60
		elif kind == "boss":
			score = -100
		score = score * 1000 + (IntentAI.mix(setup.rng_seed, id, state.moves, 3) & 0x3FF)
		if score > best_score:
			best_score = score
			best = id
	return best


## The forward bot's bonus for a site type, shared with the explorer.
static func _taste(kind: String, hurt: bool, state: RunState) -> int:
	match kind:
		"workshop":
			return 30 if hurt or state.alive_crew() < state.crew.size() else 4
		"elite":
			return -20 if hurt else 6
		"warlord":
			return -30 if hurt else 10
		"scrapyard":
			return 5
		"skirmish":
			return 9
		"signal":
			return 6
		"trader", "refinery", "auction":
			return 3
		"arena":
			return -25 if hurt else 5
		"tower":
			return 2
	return 0


## 085: the deal by the stated policy (`deals`): its index in the offer, or -1 for WALK ON.
static func _deal_choice(state: RunState, setup: RunSetup) -> int:
	if deals == "walk":
		return -1
	var offer: Array = state.deal_offer
	if deals != "best":
		return offer.find(deals)
	var best: int = -1
	var best_rank: int = 1 << 30
	var pool: Array = (setup.rules.get("deals", {}) as Dictionary).get("deals", [])
	for i: int in offer.size():
		for rank: int in pool.size():
			if String((pool[rank] as Dictionary).get("id", "")) == String(offer[i]) and rank < best_rank:
				best_rank = rank
				best = i
	return best

