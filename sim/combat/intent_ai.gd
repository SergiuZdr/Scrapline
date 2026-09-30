class_name IntentAI
extends RefCounted

## Picks where a unit moves, which arm it fires and at which hex.
##
## Enemies use it to choose their telegraphed intent. The bot uses the same function for
## the player side, so "the bot can win" and "the enemy plays sensibly" are one piece of
## code rather than two that drift apart. Every attack is scored through
## `CombatSim.strike_plan`, the same function that resolves it.
##
## Deterministic: candidates are visited in a fixed order and ties are broken by a
## full avalanche hash, never by visit order alone. (The old game's tie-break was a
## 16-bit multiply, and it handed one team every simultaneous exchange.)

const SCORE_HIT: int = 100
const SCORE_KILL: int = 60
## Enemies want the salvage caches: they are what makes a telegraphed shot worth
## stepping INTO on a defend fight.
const SCORE_OBJECTIVE: int = 90
## Ending a move on a scrap pile: grabbing it denies the player (and heals). On a salvage
## fight it is the whole point.
const SCORE_PAD: int = -40
const SCORE_PILE: int = 14
const SCORE_PILE_SALVAGE: int = 70
const SCORE_MARK: int = 25
const SCORE_FRIENDLY_FIRE: int = -100
const SCORE_OWN_OBJECTIVE: int = -250
const SCORE_HAZARD: int = -30
## Per point of expected incoming damage on a tile (bot only).
const SCORE_DANGER: int = -12
const SCORE_OVERHEAT: int = -25
## Hitting an enemy that is currently aiming at something (bot only).
const SCORE_DISRUPT: int = 30
const SCORE_FELL: int = 30
## Breaking a gate pylon strips the Sorter's shield (013): worth about a kill to the player's
## side, nothing to the enemy's.
const SCORE_PYLON: int = 90
## How many of the best candidates get the full dry run (explosions, pits, bombers).
const REFINE: int = 6


## Returns `{ "dest", "path", "w" (-1 = no attack), "target": Vector2i, "score" }`.
## `ctx` is empty for enemies. The bot passes `"danger": {cell: damage}` and
## `"shield": {cell: value}` -- see `CombatBot`.
static func plan(state: CombatState, u: GridUnit, ctx: Dictionary) -> Dictionary:
	var here := Vector2i(u.x, u.y)
	var options: Dictionary = {}
	# A kind that is `still` (025: the Core) never leaves its hex.
	if not u.moved and not bool((state.setup.kinds.get(u.kind, {}) as Dictionary).get("still", false)):
		options = CombatSim.paths_from(state, u, u.move)
	options[here] = [] as Array[Vector2i]
	var danger: Dictionary = ctx.get("danger", {})
	var shield: Dictionary = ctx.get("shield", {})
	var can_shoot: bool = not u.acted and not u.seized

	var cells: Array = options.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))

	var best: Dictionary = {}
	var best_score: int = -1000000
	var best_tie: int = 0
	var best_attack: int = 0
	var candidates: Array = []
	for cell: Vector2i in cells:
		var base: int = _tile_value(state, cell, (options[cell] as Array).size(), danger, shield)
		# Evaluate from the destination by standing there for the length of the loop.
		u.x = cell.x
		u.y = cell.y
		var choice: Array = [-1, Vector2i.ZERO, 0]
		if can_shoot:
			choice = _best_shot(state, u, ctx)
		u.x = here.x
		u.y = here.y
		var attack_value: int = int(choice[2]) if int(choice[0]) >= 0 else 0
		var score: int = base + maxi(0, attack_value)
		var aim: Vector2i = choice[1]
		var tie: int = mix(state.setup.rng_seed, u.ref * 131 + state.round_number, cell.x * 17 + cell.y, int(choice[0]) * 4096 + aim.y * 64 + aim.x)
		if int(choice[0]) >= 0:
			candidates.append([score, tie, cell, choice, base])
		if score > best_score or (score == best_score and tie < best_tie):
			best_score = score
			best_tie = tie
			best_attack = attack_value
			best = {"dest": cell, "path": options[cell], "w": int(choice[0]), "target": aim, "score": score}

	# The quick score only sees direct hits. The best few candidates are played for real on
	# a copy, so a shot into a barrel beside three machines, a shove into a pit or killing a
	# bomber next to its friends is valued by what actually happens.
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]) or (int(a[0]) == int(b[0]) and int(a[1]) < int(b[1])))
	for k: int in mini(REFINE, candidates.size()):
		var c: Array = candidates[k]
		var choice: Array = c[3]
		var refined: int = int(c[4]) + _dry_value(state, u, c[2], int(choice[0]), choice[1], ctx)
		if refined > best_score or (refined == best_score and int(c[1]) < best_tie):
			best_score = refined
			best_tie = int(c[1])
			best_attack = refined - int(c[4])
			best = {"dest": c[2], "path": options[c[2]], "w": int(choice[0]), "target": choice[1], "score": refined}

	if best_attack >= SCORE_HIT / 2:
		return best

	# Nothing worth shooting from anywhere reachable: close to a useful distance instead.
	var want: int = _preferred_distance(u)
	best = {}
	best_score = -1000000
	for cell: Vector2i in cells:
		var gap: int = _nearest_target_distance(state, u, cell)
		var score: int = -absi(gap - want) * 10 + _tile_value(state, cell, (options[cell] as Array).size(), danger, shield)
		var tie: int = mix(state.setup.rng_seed, u.ref * 131 + state.round_number, cell.x * 17 + cell.y, 99)
		if score > best_score or (score == best_score and tie < best_tie):
			best_score = score
			best_tie = tie
			best = {"dest": cell, "path": options[cell], "w": -1, "target": Vector2i.ZERO, "score": score}
	return best


## `[w, target, value]` of the best attack from where `u` stands, or w = -1.
## Only hexes that hold a unit are worth aiming at, which keeps the search small: the
## plan for an empty hex hits nothing unless it is a lob's splash or a shot's line, and
## those are found by aiming at the unit itself.
static func _best_shot(state: CombatState, u: GridUnit, ctx: Dictionary) -> Array:
	var best: Array = [-1, Vector2i.ZERO, -1000000]
	var best_tie: int = 0
	for w: int in u.weapons.size():
		if not u.can_fire(w):
			continue
		var weapon: Dictionary = u.weapons[w]
		var hot: bool = u.team == GridUnit.TEAM_PLAYER and u.heat + CombatSim.attack_heat(u, weapon) >= u.heat_cap
		var lob: bool = String(weapon["shape"]) == "lob"
		for aim: Vector2i in CombatSim.aim_options(state, u, w):
			var prop: bool = state.props.has(aim)
			if not lob and not prop and state.unit_at(aim.x, aim.y) == null:
				continue
			var plan: Dictionary = CombatSim.strike_plan(state, u, w, aim)
			if not bool(plan["legal"]) or ((plan["hits"] as Array).is_empty() and (plan["props"] as Array).is_empty()):
				continue
			var value: int = plan_value(state, u, weapon, plan, ctx) + (SCORE_OVERHEAT if hot else 0)
			var tie: int = mix(state.setup.rng_seed, u.ref, w * 4096 + aim.y * 64 + aim.x, state.round_number)
			if value > int(best[2]) or (value == int(best[2]) and tie < best_tie):
				best = [w, aim, value]
				best_tie = tie
	return best


## How much `u` wants the outcome of `plan`.
static func plan_value(state: CombatState, u: GridUnit, weapon: Dictionary, plan: Dictionary, ctx: Dictionary) -> int:
	var value: int = 0
	var any_foe: bool = false
	var intents: Dictionary = {}
	if ctx.has("danger"):
		for intent: Dictionary in state.intents:
			intents[int(intent["ref"])] = true
	for hit: Dictionary in (plan["hits"] as Array):
		var t: GridUnit = state.unit(int(hit["ref"]))
		if t == null or not t.alive:
			continue
		var dmg: int = int(hit["damage"])
		if t.team == u.team:
			value += SCORE_OWN_OBJECTIVE if t.objective else SCORE_FRIENDLY_FIRE
			continue
		any_foe = true
		value += dmg * 10
		if dmg >= t.hp:
			value += SCORE_KILL
		if t.objective:
			value += SCORE_OBJECTIVE
		if bool(hit["primary"]) and bool(weapon["mark"]) and not t.marked:
			value += SCORE_MARK
		if intents.has(t.ref):
			value += SCORE_DISRUPT
	if any_foe:
		value += SCORE_HIT
	# A barrel in the line is worth a look: the dry run decides whether it is worth it.
	for prop: Dictionary in (plan.get("props", []) as Array):
		var kind: String = String((state.props[prop["cell"]] as Dictionary)["kind"])
		if kind == "barrel":
			value += 40
		elif kind == "pylon" and u.team == GridUnit.TEAM_PLAYER:
			value += SCORE_PYLON / 2
	return value


## The full consequence of `u` attacking from `cell`: the attack is executed on a copy and
## every change is scored, both sides.
static func _dry_value(state: CombatState, u: GridUnit, cell: Vector2i, w: int, target: Vector2i, ctx: Dictionary) -> int:
	var before: CombatState = state.clone()
	var me: GridUnit = before.unit(u.ref)
	me.x = cell.x
	me.y = cell.y
	var after: CombatState = before.clone()
	CombatSim._execute_attack(after, after.unit(u.ref), w, target)
	var value: int = 0
	var any_foe: bool = false
	var intents: Dictionary = {}
	if ctx.has("danger"):
		for intent: Dictionary in state.intents:
			intents[int(intent["ref"])] = true
	for effect: Dictionary in CombatSim.diff(before, after):
		if effect.has("prop") and u.team == GridUnit.TEAM_PLAYER \
				and String((before.props.get(effect["prop"], {}) as Dictionary).get("kind", "")) == "pylon":
			value += SCORE_PYLON
		if not effect.has("ref"):
			continue
		var t: GridUnit = before.unit(int(effect["ref"]))
		if t == null:
			continue
		var lost: int = int(effect["hp_lost"])
		if t.team == u.team:
			value -= lost * 10
			if bool(effect["killed"]):
				value += SCORE_OWN_OBJECTIVE if t.objective else SCORE_FRIENDLY_FIRE
			continue
		if lost > 0 or bool(effect["killed"]):
			any_foe = true
		value += lost * 10
		if bool(effect["killed"]):
			value += SCORE_KILL + (SCORE_OBJECTIVE if t.objective else 0)
		if bool(effect["fell"]):
			value += SCORE_FELL
		if intents.has(t.ref):
			value += SCORE_DISRUPT
	if any_foe:
		value += SCORE_HIT
	var weapon: Dictionary = u.weapons[w]
	if bool(weapon["mark"]) and any_foe:
		value += SCORE_MARK
	if u.team == GridUnit.TEAM_PLAYER and u.heat + CombatSim.attack_heat(u, weapon) >= u.heat_cap:
		value += SCORE_OVERHEAT
	return value


static func _tile_value(state: CombatState, cell: Vector2i, steps: int, danger: Dictionary, shield: Dictionary) -> int:
	var value: int = -steps + SCORE_HAZARD * state.hazard(cell.x, cell.y) \
		+ SCORE_DANGER * int(danger.get(cell, 0)) + int(shield.get(cell, 0))
	# A flue that blows at the start of the next round (025), for either side.
	if state.flue(cell.x, cell.y) > 0 and CombatSim.flues_blow(state, state.round_number + 1):
		value += SCORE_HAZARD * state.flue(cell.x, cell.y)
	if state.piles.has(cell):
		value += SCORE_PILE_SALVAGE if String(state.objective().get("type", "")) == "salvage" else SCORE_PILE
	# Never park on a hive's pad: it would block the enemy's own drone.
	if state.spawn_marks.values().has(cell):
		value += SCORE_PAD
	return value


static func _preferred_distance(u: GridUnit) -> int:
	if u.kind == "hive":
		return 4
	var want: int = 1
	for w: int in u.weapons.size():
		if not u.can_fire(w):
			continue
		var weapon: Dictionary = u.weapons[w]
		match String(weapon["shape"]):
			"shot":
				want = maxi(want, mini(3, int(weapon["range"])))
			"lob":
				want = maxi(want, int(weapon["range_min"]) + 1)
	return want


## Hex distance to the nearest thing worth attacking. Enemies count the caches.
static func _nearest_target_distance(state: CombatState, u: GridUnit, cell: Vector2i) -> int:
	var nearest: int = 1000
	for other: GridUnit in state.units:
		if other.alive and other.is_enemy_of(u):
			nearest = mini(nearest, Hex.distance(Vector2i(other.x, other.y), cell))
	return nearest


## Murmur3's finalizer over four inputs: every input bit affects every output bit.
static func mix(a: int, b: int, c: int, d: int) -> int:
	var h: int = a & 0xFFFFFFFF
	for v: int in [b, c, d]:
		h = (h ^ (v & 0xFFFFFFFF)) & 0xFFFFFFFF
		h = ((h ^ (h >> 16)) * 0x85EBCA6B) & 0xFFFFFFFF
		h = ((h ^ (h >> 13)) * 0xC2B2AE35) & 0xFFFFFFFF
		h = (h ^ (h >> 16)) & 0xFFFFFFFF
	return h
