class_name RunSim
extends RefCounted

## The rules of a run: the region, travel, the Reclaimer front, what each site does,
## salvage, the workshop, refits and how a run ends.
##
## Like `CombatSim`, a run is `start(setup)` plus `apply` for every action, and nothing
## else changes a `RunState`. A fight's result is not reported to the run -- the run
## REPLAYS the fight's own action log through `CombatSim` and reads the result off that.
## So a whole run, fights included, is one list of plain actions: that list is the save
## file, and a run cannot be told it won a fight it did not win.
##
## Actions:
##   [TRAVEL,  site_id]
##   [FIGHT,   combat_actions]           resolves a pending fight
##   [PICK,    index]                    reward / scrapyard; -1 = take nothing (or the scrap)
##   [REPAIR]                            workshop: patch every machine
##   [REBUILD, crew_index]               workshop: rebuild a wreck
##   [LEAVE]                             leave the workshop
##   [REFIT,   crew_index, socket, cargo_index]   swap a socket with cargo; -1 = unfit into cargo
##   [SCRAP_PART, cargo_index]           break a part in the hold down for scrap (any time but a fight)
##   [EXPAND_HOLD]                       workshop: buy more room in the hold

const TRAVEL: int = 0
const FIGHT: int = 1
const PICK: int = 2
const REPAIR: int = 3
const REBUILD: int = 4
const LEAVE: int = 5
const REFIT: int = 6
const SCRAP_PART: int = 7
const EXPAND_HOLD: int = 8
const LEVEL_UP: int = 9
const ASSEMBLE: int = 10

const FIGHT_TYPES: PackedStringArray = ["skirmish", "elite", "boss"]


static func start(setup: RunSetup) -> RunState:
	var state := RunState.new()
	var rules: Dictionary = setup.rules
	state.scrap = int(rules.get("starting_scrap", 0))
	state.hold_size = int((rules.get("hold", {}) as Dictionary).get("start", 8))
	for spec: Dictionary in (rules.get("starting_crew", []) as Array):
		var parts: Array = []
		for id: Variant in spec.get("parts", []):
			parts.append(String(id))
		var member: Dictionary = {"name": String(spec.get("name", "")), "parts": parts, "alive": true, "hp": 0, "level": 0}
		member["hp"] = max_hp(setup, member)
		state.crew.append(member)
	_generate_region(state, setup)
	state.current = 0
	state.sites[0]["visited"] = true
	state.log.append("The crew rolls into the yard. The Reclaimer is somewhere behind.")
	return state


static func replay(setup: RunSetup, actions: Array) -> RunState:
	var state: RunState = start(setup)
	for action: Array in actions:
		apply(state, setup, action)
	return state


## Applies one action. Returns false, and changes nothing, if it is not legal now.
static func apply(state: RunState, setup: RunSetup, action: Array) -> bool:
	if state.outcome != RunState.ONGOING or action.is_empty():
		return false
	match int(action[0]):
		TRAVEL:
			return _travel(state, setup, int(action[1]))
		FIGHT:
			return _fight(state, setup, action[1] as Array)
		PICK:
			return _pick(state, setup, int(action[1]))
		REPAIR:
			return _repair(state, setup)
		REBUILD:
			return _rebuild(state, setup, int(action[1]))
		LEAVE:
			if String(state.pending.get("kind", "")) != "workshop":
				return false
			state.pending = {}
			return true
		REFIT:
			return _refit(state, setup, int(action[1]), int(action[2]), int(action[3]))
		SCRAP_PART:
			return _scrap_part(state, setup, int(action[1]))
		EXPAND_HOLD:
			return _expand_hold(state, setup)
		LEVEL_UP:
			return _level_up(state, setup, int(action[1]))
		ASSEMBLE:
			return _assemble(state, setup, action[1] as Array)
	return false


# --- Queries -----------------------------------------------------------------

## Sites the crew can travel to right now.
static func destinations(state: RunState) -> Array[int]:
	var out: Array[int] = []
	if not state.pending.is_empty() or state.outcome != RunState.ONGOING or state.overfull():
		return out
	for id: Variant in (state.site(state.current)["links"] as Array):
		if not state.consumed(int(id)):
			out.append(int(id))
	out.sort()
	return out


## Whether the player knows what a site is. Fog lifts from every site next to one the
## crew has visited.
static func revealed(state: RunState, id: int) -> bool:
	var s: Dictionary = state.site(id)
	if bool(s["visited"]) or String(s["type"]) == "boss":
		return true
	for other: Variant in (s["links"] as Array):
		if bool(state.site(int(other))["visited"]):
			return true
	return false


## The CombatSetup for the pending fight, or null.
static func fight_setup(state: RunState, setup: RunSetup) -> CombatSetup:
	if String(state.pending.get("kind", "")) != "fight":
		return null
	return CombatSetup.build(state.pending["fight"], setup.combat_rules, setup.parts, setup.tiles,
		setup.wheel, IntentAI.mix(setup.rng_seed, state.current, 17, 0))


## A machine's full HP: its chassis plus its module, the same sum `CombatSetup` makes.
static func max_hp(setup: RunSetup, member: Dictionary) -> int:
	var parts: Array = member["parts"]
	var cg: Dictionary = (setup.parts.get(String(parts[0]), {}) as Dictionary).get("grid", {})
	var mg: Dictionary = (setup.parts.get(String(parts[4]), {}) as Dictionary).get("grid", {})
	return int(cg.get("hp", 8)) + int(mg.get("hp", 0)) + level_bonus(setup, member, "hp")


## A crew member as a fight's unit spec: parts, HP now, and its levels as bonuses.
static func machine_spec(setup: RunSetup, member: Dictionary) -> Dictionary:
	return {"name": String(member["name"]), "parts": (member["parts"] as Array).duplicate(),
		"hp_now": maxi(1, int(member["hp"])), "bonus_hp": level_bonus(setup, member, "hp"),
		"bonus_damage": level_bonus(setup, member, "damage"), "level": int(member.get("level", 0))}


## The machine as the next fight will field it, for the garage's numbers.
static func preview_machine(setup: RunSetup, member: Dictionary) -> GridUnit:
	return CombatSetup.unit_from(machine_spec(setup, member), setup.combat_rules, setup.parts)


## What a machine's levels add up to: `what` is "hp" or "damage" (`run.json` `levels.bonus`,
## one entry per level).
static func level_bonus(setup: RunSetup, member: Dictionary, what: String) -> int:
	var steps: Array = (setup.rules.get("levels", {}) as Dictionary).get("bonus", [])
	var total: int = 0
	for n: int in mini(int(member.get("level", 0)), steps.size()):
		total += int((steps[n] as Dictionary).get(what, 0))
	return total


## What machine `index`'s NEXT level adds, `{ "hp", "damage" }` (empty at the top).
static func next_level_bonus(state: RunState, setup: RunSetup, index: int) -> Dictionary:
	var steps: Array = (setup.rules.get("levels", {}) as Dictionary).get("bonus", [])
	var level: int = int(state.crew[index].get("level", 0))
	return steps[level] if level < steps.size() else {}


## Scrap for machine `index`'s next level, or -1 when it is at the top.
static func level_cost(state: RunState, setup: RunSetup, index: int) -> int:
	var costs: Array = (setup.rules.get("levels", {}) as Dictionary).get("costs", [])
	var level: int = int(state.crew[index].get("level", 0))
	return int(costs[level]) if level < costs.size() else -1


static func can_refit(state: RunState) -> bool:
	return state.outcome == RunState.ONGOING and String(state.pending.get("kind", "")) != "fight"


# --- Actions -----------------------------------------------------------------

static func _travel(state: RunState, setup: RunSetup, to: int) -> bool:
	if not destinations(state).has(to):
		return false
	var front: Dictionary = setup.rules.get("front", {})
	# Lingering in consumed ground costs the whole crew, move by move. It wears machines
	# down but never finishes one: the front pushes, it does not execute.
	if state.consumed(state.current):
		var bite: int = int(front.get("damage", 2))
		for member: Dictionary in state.crew:
			if bool(member["alive"]):
				member["hp"] = maxi(1, int(member["hp"]) - bite)
		state.log.append("The Reclaimer tears at the crew as it pulls out: -%d each." % bite)
	state.current = to
	state.moves += 1
	if state.moves % maxi(1, int(front.get("every", 2))) == 0:
		state.front_col += 1
		state.log.append("The Reclaimer swallows column %d." % (state.front_col + 1))
	var s: Dictionary = state.sites[to]
	if bool(s["visited"]):
		return true
	s["visited"] = true
	var kind: String = String(s["type"])
	if FIGHT_TYPES.has(kind):
		state.pending = {"kind": "fight", "site_type": kind, "fight": _make_fight(state, setup, to, kind)}
		state.log.append("%s at site %d." % ["The act boss" if kind == "boss" else kind.capitalize(), to])
	elif kind == "scrapyard":
		var rewards: Dictionary = setup.rules.get("rewards", {})
		state.pending = {"kind": "scrapyard", "options": _roll_parts(setup, _rng(setup, to, 3), 1),
			"scrap": int(rewards.get("scrapyard_scrap", 15))}
		state.log.append("A scrapyard. Something in here still works.")
	elif kind == "workshop":
		state.pending = {"kind": "workshop"}
		state.log.append("A workshop with the lights still on.")
	return true


static func _fight(state: RunState, setup: RunSetup, combat_actions: Array) -> bool:
	var combat_setup: CombatSetup = fight_setup(state, setup)
	if combat_setup == null:
		return false
	var result: CombatState = CombatSim.replay(combat_setup, combat_actions)
	if result.outcome == CombatState.ONGOING:
		return false   # a fight is only reported once it has ended
	var kind: String = String(state.pending["site_type"])

	# HP carries: each machine leaves with what the fight left it. Torn arms are bolted back
	# on. A machine DESTROYED in the fight is a wreck: it keeps its chassis, nothing else.
	var fielded: Array = _fielded_crew(state)
	for slot: int in fielded.size():
		var unit: GridUnit = result.unit(slot)
		var member: Dictionary = state.crew[int(fielded[slot])]
		if unit == null:
			continue
		if unit.alive:
			member["hp"] = unit.hp
		else:
			member["alive"] = false
			member["hp"] = 0
			member["parts"] = [String(member["parts"][0]), "", "", "", ""]
			state.log.append("%s was wrecked. Its parts are gone." % member["name"])
	# Scrap piles collected during the fight are banked whatever the outcome.
	state.scrap += result.scrap_collected

	if state.alive_crew() == 0:
		_end(state, RunState.LOST, "The whole crew is wrecked.")
		return true
	if result.outcome == CombatState.LOST and kind == "boss":
		# There is no road past the gate to go on along, and the road back is reclaimed:
		# a crew that survives but does not win here is stranded, so the run ends.
		_end(state, RunState.LOST, "The gate held: the crew could not break through in time.")
		return true
	if result.outcome == CombatState.LOST:
		# The objective failed but the crew lives: no salvage, and the road goes on.
		state.pending = {}
		state.log.append("Driven off. No salvage from this one.")
		return true
	state.fights_won += 1
	if kind == "boss":
		_end(state, RunState.WON, "Act 1 cleared: the crew is through the gate.")
		return true
	var rewards: Dictionary = setup.rules.get("rewards", {})
	var gained: int = int(rewards.get("elite_scrap" if kind == "elite" else "skirmish_scrap", 10))
	gained += result.caches().size() * int(rewards.get("cache_scrap", 6))
	state.scrap += gained
	var min_rarity: int = int(rewards.get("elite_min_rarity", 2)) if kind == "elite" else 1
	state.pending = {"kind": "reward", "options": _roll_parts(setup, _rng(setup, state.current, 5), min_rarity)}
	state.log.append("Won. +%d scrap%s, and salvage to pick through." % [gained,
		" (+%d from piles)" % result.scrap_collected if result.scrap_collected > 0 else ""])
	return true


static func _pick(state: RunState, setup: RunSetup, index: int) -> bool:
	var kind: String = String(state.pending.get("kind", ""))
	if kind != "reward" and kind != "scrapyard":
		return false
	var options: Array = state.pending["options"]
	if index < -1 or index >= options.size():
		return false
	if index == -1:
		if kind == "scrapyard":
			state.scrap += int(state.pending["scrap"])
			state.log.append("Stripped the yard for %d scrap." % int(state.pending["scrap"]))
		state.pending = {}
		return true
	# Always allowed. If the hold goes over, travel waits until something is fitted or
	# scrapped -- the choice is made with the new part in hand, not before (play-test 2).
	var part: String = String(options[index])
	state.cargo.append(part)
	state.log.append("Loaded %s into the hold." % String((setup.parts[part] as Dictionary).get("name", part)))
	state.pending = {}
	return true


## Patches every living machine by `repair_amount`, for one price.
static func _repair(state: RunState, setup: RunSetup) -> bool:
	var shop: Dictionary = setup.rules.get("workshop", {})
	var cost: int = int(shop.get("repair_cost", 8))
	if String(state.pending.get("kind", "")) != "workshop" or state.scrap < cost or not needs_repair(state, setup):
		return false
	state.scrap -= cost
	for member: Dictionary in state.crew:
		if bool(member["alive"]):
			member["hp"] = mini(max_hp(setup, member), int(member["hp"]) + int(shop.get("repair_amount", 3)))
	state.log.append("Patched the crew.")
	return true


static func needs_repair(state: RunState, setup: RunSetup) -> bool:
	for member: Dictionary in state.crew:
		if bool(member["alive"]) and int(member["hp"]) < max_hp(setup, member):
			return true
	return false


static func _rebuild(state: RunState, setup: RunSetup, index: int) -> bool:
	var cost: int = int((setup.rules.get("workshop", {}) as Dictionary).get("rebuild_cost", 20))
	if String(state.pending.get("kind", "")) != "workshop" or index < 0 or index >= state.crew.size():
		return false
	var member: Dictionary = state.crew[index]
	if bool(member["alive"]) or state.scrap < cost:
		return false
	state.scrap -= cost
	member["alive"] = true
	member["hp"] = maxi(1, max_hp(setup, member) / 2)
	state.log.append("Rebuilt %s on its old frame at half strength. Its sockets are empty." % member["name"])
	return true


static func _refit(state: RunState, setup: RunSetup, index: int, socket: int, cargo_index: int) -> bool:
	if not can_refit(state) or index < 0 or index >= state.crew.size() or socket < 0 or socket > 4:
		return false
	var member: Dictionary = state.crew[index]
	if not bool(member["alive"]):
		return false
	var parts: Array = member["parts"]
	var old: String = String(parts[socket])
	if cargo_index == -1:
		# Unfit into the hold. A machine cannot give up its chassis.
		if socket == 0 or old.is_empty():
			return false
		parts[socket] = ""
		state.cargo.append(old)
		_clamp_hp(setup, member)
		return true
	if cargo_index < 0 or cargo_index >= state.cargo.size():
		return false
	var incoming: String = state.cargo[cargo_index]
	if String((setup.parts.get(incoming, {}) as Dictionary).get("slot", "")) != RunSetup.socket_slot(socket):
		return false
	parts[socket] = incoming
	if old.is_empty():
		state.cargo.remove_at(cargo_index)
	else:
		state.cargo[cargo_index] = old
	_clamp_hp(setup, member)
	return true


## A refit can lower a machine's full HP (a lighter chassis, losing an HP module).
static func _clamp_hp(setup: RunSetup, member: Dictionary) -> void:
	member["hp"] = mini(int(member["hp"]), max_hp(setup, member))


## Scrap a part from the hold, by rarity (`scrap_value.by_rarity`).
static func scrap_value(setup: RunSetup, part: String) -> int:
	var values: Array = (setup.rules.get("scrap_value", {}) as Dictionary).get("by_rarity", [3, 6, 10])
	return int(values[clampi(setup.rarity(part) - 1, 0, values.size() - 1)])


static func _scrap_part(state: RunState, setup: RunSetup, index: int) -> bool:
	if not can_refit(state) or index < 0 or index >= state.cargo.size():
		return false
	var part: String = state.cargo[index]
	var value: int = scrap_value(setup, part)
	state.cargo.remove_at(index)
	state.scrap += value
	state.log.append("Broke down %s for %d scrap." % [String((setup.parts[part] as Dictionary).get("name", part)), value])
	return true


## The price of the next hold expansion, or -1 when there are no more.
static func expand_cost(state: RunState, setup: RunSetup) -> int:
	var hold: Dictionary = setup.rules.get("hold", {})
	var bought: int = (state.hold_size - int(hold.get("start", 8))) / maxi(1, int(hold.get("expand_by", 2)))
	var costs: Array = hold.get("expand_costs", [])
	return int(costs[bought]) if bought < costs.size() else -1


## Scrap buys a machine a level: more HP (and that HP now), more damage on every weapon.
## Play-test 3: scrap had nothing to buy once the crew was healthy.
static func _level_up(state: RunState, setup: RunSetup, index: int) -> bool:
	if not can_refit(state) or index < 0 or index >= state.crew.size():
		return false
	var member: Dictionary = state.crew[index]
	var cost: int = level_cost(state, setup, index)
	if not bool(member["alive"]) or cost < 0 or state.scrap < cost:
		return false
	var gain: Dictionary = next_level_bonus(state, setup, index)
	state.scrap -= cost
	member["level"] = int(member.get("level", 0)) + 1
	member["hp"] = int(member["hp"]) + int(gain.get("hp", 0))
	state.log.append("%s is overhauled to level %d." % [member["name"], int(member["level"])])
	return true


## Whether the crew can still be built from the bench: before the first move, once.
static func can_assemble(state: RunState) -> bool:
	return state.outcome == RunState.ONGOING and state.moves == 0 and not state.assembled \
		and state.pending.is_empty()


## How many of a part the bench holds: every common part without limit (-1), the listed
## extras (the defaults' uncommons) once each, anything else not at all (0).
static func bench_count(setup: RunSetup, part: String) -> int:
	var bench: Dictionary = setup.rules.get("assembly", {})
	if part.is_empty() or not setup.parts.has(part):
		return 0
	if setup.rarity(part) <= int(bench.get("free_rarity", 1)):
		return -1
	return int((bench.get("extra", {}) as Dictionary).get(part, 0))


## Builds the three machines from the bench (play-test 4: "a way to customise the starting
## robots from basic parts"). `loadouts`: one five-part list per crew member, in socket
## order. The frame names the machine; a second machine on the same frame is "II".
static func _assemble(state: RunState, setup: RunSetup, loadouts: Array) -> bool:
	if not can_assemble(state) or loadouts.size() != state.crew.size():
		return false
	var used: Dictionary = {}
	for loadout: Variant in loadouts:
		var parts: Array = loadout as Array
		if parts.size() != 5 or String(parts[0]).is_empty():
			return false
		for s: int in 5:
			var part: String = String(parts[s])
			if part.is_empty():
				continue
			if String((setup.parts.get(part, {}) as Dictionary).get("slot", "")) != RunSetup.socket_slot(s):
				return false
			var limit: int = bench_count(setup, part)
			used[part] = int(used.get(part, 0)) + 1
			if limit == 0 or (limit > 0 and int(used[part]) > limit):
				return false
	var names: Dictionary = {}
	for i: int in state.crew.size():
		var parts: Array = []
		for id: Variant in (loadouts[i] as Array):
			parts.append(String(id))
		var member: Dictionary = state.crew[i]
		member["parts"] = parts
		var base: String = String((setup.parts[parts[0]] as Dictionary).get("name", "Machine")).replace(" Frame", "")
		names[base] = int(names.get(base, 0)) + 1
		member["name"] = base if int(names[base]) == 1 else "%s %s" % [base, ["", "", "II", "III"][mini(int(names[base]), 3)]]
		member["hp"] = max_hp(setup, member)
	state.assembled = true
	state.log.append("The crew is built from the bench.")
	return true


static func _expand_hold(state: RunState, setup: RunSetup) -> bool:
	var cost: int = expand_cost(state, setup)
	if String(state.pending.get("kind", "")) != "workshop" or cost < 0 or state.scrap < cost:
		return false
	state.scrap -= cost
	state.hold_size += int((setup.rules.get("hold", {}) as Dictionary).get("expand_by", 2))
	state.log.append("Welded more racks into the hold: room for %d." % state.hold_size)
	return true


static func _end(state: RunState, outcome: int, reason: String) -> void:
	state.outcome = outcome
	state.end_reason = reason
	state.pending = {}
	state.log.append(reason)


# --- Generation --------------------------------------------------------------

## An RNG for one purpose at one site, independent of the order anything else was rolled
## in: a site's fight is the same whether the player got there first or last.
static func _rng(setup: RunSetup, site_id: int, salt: int) -> SimRNG:
	return SimRNG.new(IntentAI.mix(setup.rng_seed, site_id, salt, 0x5C4A))


static func _generate_region(state: RunState, setup: RunSetup) -> void:
	var rules: Dictionary = setup.rules
	var region: Dictionary = rules.get("region", {})
	var columns: int = maxi(3, int(region.get("columns", 7)))
	var rng: SimRNG = _rng(setup, -1, 1)
	var by_col: Array = []
	for col: int in columns:
		var rows: int = 1 if col == 0 or col == columns - 1 else rng.range_int(int(region.get("rows_min", 2)), int(region.get("rows_max", 3)))
		var ids: Array = []
		for row: int in rows:
			var id: int = state.sites.size()
			var y: int = (row * 2 + 1) * 100 / (rows * 2)
			if rows > 1:
				y = clampi(y + rng.range_int(-8, 8), 8, 92)
			state.sites.append({"id": id, "col": col, "row": row, "x": col * 100 / (columns - 1),
				"y": y, "type": "", "links": [], "visited": false})
			ids.append(id)
		by_col.append(ids)

	# Forward links: each site to its nearest neighbour in the next column (sometimes also
	# the second nearest), then every site with no way in gets one from its nearest.
	for col: int in columns - 1:
		var here: Array = by_col[col]
		var next: Array = by_col[col + 1]
		for id: Variant in here:
			var ranked: Array = next.duplicate()
			var y: int = int(state.sites[id]["y"])
			ranked.sort_custom(func(a: int, b: int) -> bool:
				var da: int = absi(int(state.sites[a]["y"]) - y)
				var db: int = absi(int(state.sites[b]["y"]) - y)
				return da < db or (da == db and a < b))
			_link(state, int(id), int(ranked[0]))
			if ranked.size() > 1 and rng.chance_percent(40):
				_link(state, int(id), int(ranked[1]))
		for id: Variant in next:
			var has_in: bool = false
			for other: Variant in (state.sites[id]["links"] as Array):
				if int(state.sites[other]["col"]) == col:
					has_in = true
			if not has_in:
				var best: int = int(here[0])
				for candidate: Variant in here:
					if absi(int(state.sites[candidate]["y"]) - int(state.sites[id]["y"])) < absi(int(state.sites[best]["y"]) - int(state.sites[id]["y"])):
						best = int(candidate)
				_link(state, best, int(id))
		# Sideways: neighbours in the same column, so the map is a region and not a tree.
		for i: int in range(1, next.size()):
			if col + 1 < columns - 1:
				_link(state, int(next[i - 1]), int(next[i]))

	# Site types.
	var weights: Dictionary = rules.get("site_weights", {})
	var kinds: Array = weights.keys()
	kinds.sort()
	for col: int in columns:
		for id: Variant in by_col[col]:
			var kind: String
			if col == 0:
				kind = "start"
			elif col == columns - 1:
				kind = "boss"
			elif col == 1:
				# The first step is always a fight or a scrapyard: something happens at once.
				kind = "skirmish" if rng.chance_percent(70) else "scrapyard"
			else:
				kind = _weighted(rng, kinds, weights, col >= int(rules.get("elite_from_column", 2)))
			state.sites[id]["type"] = kind
	for col: Variant in (rules.get("workshop_guaranteed_columns", []) as Array):
		var ids: Array = by_col[clampi(int(col), 1, columns - 2)]
		var has_shop: bool = false
		for id: Variant in ids:
			has_shop = has_shop or String(state.sites[id]["type"]) == "workshop"
		if not has_shop:
			state.sites[int(ids[rng.range_int(0, ids.size() - 1)])]["type"] = "workshop"


static func _link(state: RunState, a: int, b: int) -> void:
	if a == b:
		return
	var la: Array = state.sites[a]["links"]
	var lb: Array = state.sites[b]["links"]
	if not la.has(b):
		la.append(b)
		la.sort()
	if not lb.has(a):
		lb.append(a)
		lb.sort()


static func _weighted(rng: SimRNG, kinds: Array, weights: Dictionary, allow_elite: bool) -> String:
	var total: int = 0
	for kind: Variant in kinds:
		if String(kind) != "elite" or allow_elite:
			total += int(weights[kind])
	var roll: int = rng.range_int(1, maxi(1, total))
	for kind: Variant in kinds:
		if String(kind) == "elite" and not allow_elite:
			continue
		roll -= int(weights[kind])
		if roll <= 0:
			return String(kind)
	return "skirmish"


## Crew members that take the field, in order: the living ones.
static func _fielded_crew(state: RunState) -> Array:
	var out: Array = []
	for i: int in state.crew.size():
		if bool(state.crew[i]["alive"]):
			out.append(i)
	return out


## A fight for a site: an authored map, the crew in its player slots, the Crawler as it is
## now, and an enemy squad rolled from the parts pool by column and site type.
static func _make_fight(state: RunState, setup: RunSetup, site_id: int, kind: String) -> Dictionary:
	var rng: SimRNG = _rng(setup, site_id, 2)
	var ids: Array = setup.fights.keys()
	ids.sort()
	var template: Dictionary = setup.fights[ids[rng.range_int(0, ids.size() - 1)]]
	var col: int = int(state.sites[site_id]["col"])
	var enemies_rules: Dictionary = setup.rules.get("enemies", {})
	var counts: Array = enemies_rules.get("count_by_column", [3])
	var caps: Array = enemies_rules.get("rarity_cap_by_column", [3])
	var count: int = int(counts[mini(col, counts.size() - 1)])
	var cap: int = int(caps[mini(col, caps.size() - 1)])
	var hp_bonus: int = 0
	if kind == "elite":
		count += int(enemies_rules.get("elite_extra", 1))
		hp_bonus = int(enemies_rules.get("elite_hp_bonus", 3))
	elif kind == "boss":
		count = int(enemies_rules.get("boss_count", 5))
		hp_bonus = int(enemies_rules.get("boss_hp_bonus", 4))
		cap = 3

	var fight: Dictionary = {"id": "run_site_%d" % site_id, "name": String(template.get("name", "")),
		"rows": _scatter_terrain(setup, rng, template)}
	var laid: Dictionary = template.duplicate()
	laid["rows"] = fight["rows"]
	fight["objective"] = _roll_objective(setup, rng, laid, kind)

	var player: Array = []
	var slots: Array = template.get("player", [])
	var fielded: Array = _fielded_crew(state)
	for i: int in mini(fielded.size(), slots.size()):
		var member: Dictionary = state.crew[int(fielded[i])]
		var spec: Dictionary = machine_spec(setup, member)
		spec["x"] = int(slots[i]["x"])
		spec["y"] = int(slots[i]["y"])
		player.append(spec)
	fight["player"] = player

	var positions: Array = _enemy_positions(template, count)
	var enemy: Array = []
	for i: int in positions.size():
		var parts: Array = [_roll_slot(setup, rng, "chassis", cap), _roll_slot(setup, rng, "core", cap),
			_roll_slot(setup, rng, "arm", cap), _roll_slot(setup, rng, "arm", cap), _roll_slot(setup, rng, "module", cap)]
		var spec: Dictionary = {"name": String((setup.parts[parts[0]] as Dictionary).get("name", "")).replace(" Frame", ""),
			"parts": parts, "x": int(positions[i].x), "y": int(positions[i].y)}
		var kind_rules: Dictionary = setup.rules.get("kinds", {})
		var chances: Array = kind_rules.get("chance_by_column", [0])
		if rng.chance_percent(int(chances[mini(col, chances.size() - 1)])):
			spec["kind"] = _weighted(rng, (kind_rules.get("weights", {}) as Dictionary).keys(), kind_rules.get("weights", {}), true)
		if hp_bonus > 0 and i == 0:
			var cg: Dictionary = (setup.parts[parts[0]] as Dictionary).get("grid", {})
			var mg: Dictionary = (setup.parts[parts[4]] as Dictionary).get("grid", {})
			spec["hp"] = int(cg.get("hp", 8)) + int(mg.get("hp", 0)) + hp_bonus
			spec["name"] = String(spec["name"]) + (" Warlord" if kind == "boss" else " Veteran")
		enemy.append(spec)
	fight["enemy"] = enemy
	return fight


## The template's map with barrels, crate walls and pits scattered on open hexes in the
## middle rows, never where anyone starts.
static func _scatter_terrain(setup: RunSetup, rng: SimRNG, template: Dictionary) -> Array:
	var rows: Array = (template["rows"] as Array).duplicate()
	var terrain: Dictionary = setup.rules.get("terrain", {})
	var taken: Array = []
	for spec: Dictionary in (template.get("player", []) as Array) + (template.get("enemy", []) as Array):
		taken.append(Vector2i(int(spec["x"]), int(spec["y"])))
	for pair: Array in [["barrels", "b"], ["crates", "c"], ["pits", "o"]]:
		var span: Array = terrain.get(pair[0], [0, 0])
		var count: int = rng.range_int(int(span[0]), int(span[1]))
		for cell: Vector2i in _free_cells(rng, rows, taken, terrain.get("rows", [2, 3, 4, 5]), count):
			var row: String = String(rows[cell.y])
			rows[cell.y] = row.substr(0, cell.x) + String(pair[1]) + row.substr(cell.x + 1)
			taken.append(cell)
	return rows


## What this fight asks for. A boss is always a rout. Otherwise rolled by weight; a defend
## fight puts caches in the player's half, a salvage fight scatters piles in the middle.
static func _roll_objective(setup: RunSetup, rng: SimRNG, template: Dictionary, kind: String) -> Dictionary:
	if kind == "boss":
		return {"type": "rout"}
	var weights: Dictionary = setup.rules.get("objective_weights", {"rout": 1})
	var kinds: Array = weights.keys()
	kinds.sort()
	var total: int = 0
	for k: Variant in kinds:
		total += int(weights[k])
	var roll: int = rng.range_int(1, maxi(1, total))
	var chosen: String = "rout"
	for k: Variant in kinds:
		roll -= int(weights[k])
		if roll <= 0:
			chosen = String(k)
			break
	var o: Dictionary = setup.rules.get("objectives", {})
	var rows: Array = template["rows"]
	var taken: Array = []
	for spec: Dictionary in (template.get("player", []) as Array) + (template.get("enemy", []) as Array):
		taken.append(Vector2i(int(spec["x"]), int(spec["y"])))
	match chosen:
		"defend":
			var caches: Array = []
			for cell: Vector2i in _free_cells(rng, rows, taken, [rows.size() - 1, rows.size() - 2], int(o.get("defend_caches", 2))):
				caches.append({"x": cell.x, "y": cell.y})
				taken.append(cell)
			return {"type": "defend", "rounds": int(o.get("defend_rounds", 4)), "caches": caches}
		"salvage":
			var piles: Array = []
			for cell: Vector2i in _free_cells(rng, rows, taken, [2, 3, 4, 5], int(o.get("salvage_piles", 4))):
				piles.append({"x": cell.x, "y": cell.y})
				taken.append(cell)
			return {"type": "salvage", "need": mini(int(o.get("salvage_need", 3)), piles.size()), "piles": piles}
	return {"type": "rout"}


## `count` open cells from the given rows, chosen by the RNG from a sorted candidate list.
static func _free_cells(rng: SimRNG, rows: Array, taken: Array, row_ids: Array, count: int) -> Array:
	var candidates: Array = []
	for y: Variant in row_ids:
		var row: String = String(rows[int(y)])
		for x: int in row.length():
			var cell := Vector2i(x, int(y))
			if row[x] == "." and not taken.has(cell):
				candidates.append(cell)
	var out: Array = []
	while out.size() < count and not candidates.is_empty():
		out.append(candidates.pop_at(rng.range_int(0, candidates.size() - 1)))
	return out


## The template's enemy positions, then free cells from the top rows if more are needed.
static func _enemy_positions(template: Dictionary, count: int) -> Array:
	var out: Array = []
	for spec: Dictionary in (template.get("enemy", []) as Array):
		if out.size() < count:
			out.append(Vector2i(int(spec["x"]), int(spec["y"])))
	var rows: Array = template["rows"]
	for y: int in 2:
		for x: int in String(rows[y]).length():
			if out.size() >= count:
				return out
			var cell := Vector2i(x, y)
			if String(rows[y])[x] == "." and not out.has(cell):
				out.append(cell)
	return out


static func _roll_slot(setup: RunSetup, rng: SimRNG, slot: String, cap: int) -> String:
	var pool: Array = []
	for id: Variant in (setup.pools[slot] as Array):
		if setup.rarity(String(id)) <= cap:
			pool.append(id)
	return String(rng.pick(pool))


## `choices` distinct parts, weighted by rarity; at least one at `min_rarity` or above.
static func _roll_parts(setup: RunSetup, rng: SimRNG, min_rarity: int) -> Array:
	var rewards: Dictionary = setup.rules.get("rewards", {})
	var weights: Array = rewards.get("rarity_weights", [60, 30, 10])
	var choices: int = int(rewards.get("choices", 3))
	var all: Array = []
	for slot: String in ["chassis", "core", "arm", "module"]:
		all.append_array(setup.pools[slot])
	var out: Array = []
	var guard: int = 0
	while out.size() < choices and guard < 200:
		guard += 1
		var rarity: int = 1
		var roll: int = rng.range_int(1, 100)
		for r: int in weights.size():
			roll -= int(weights[r])
			if roll <= 0:
				rarity = r + 1
				break
		if out.is_empty():
			rarity = maxi(rarity, min_rarity)
		var pool: Array = all.filter(func(id: String) -> bool: return setup.rarity(id) == rarity and not out.has(id))
		if not pool.is_empty():
			out.append(String(rng.pick(pool)))
	return out
