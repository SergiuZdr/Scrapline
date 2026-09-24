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


## Returns `{ "dest", "path", "w" (-1 = no attack), "target": Vector2i, "score" }`.
## `ctx` is empty for enemies. The bot passes `"danger": {cell: damage}` and
## `"shield": {cell: value}` -- see `CombatBot`.
static func plan(state: CombatState, u: GridUnit, ctx: Dictionary) -> Dictionary:
	var here := Vector2i(u.x, u.y)
	var options: Dictionary = {}
	if not u.moved:
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
		if score > best_score or (score == best_score and tie < best_tie):
			best_score = score
			best_tie = tie
			best_attack = attack_value
			best = {"dest": cell, "path": options[cell], "w": int(choice[0]), "target": aim, "score": score}

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
		var hot: bool = u.team == GridUnit.TEAM_PLAYER and u.heat + int(weapon["heat"]) + u.heat_bonus >= u.heat_cap
		var lob: bool = String(weapon["shape"]) == "lob"
		for aim: Vector2i in CombatSim.aim_options(state, u, w):
			if not lob and state.unit_at(aim.x, aim.y) == null:
				continue
			var plan: Dictionary = CombatSim.strike_plan(state, u, w, aim)
			if not bool(plan["legal"]) or (plan["hits"] as Array).is_empty():
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
	return value


static func _tile_value(state: CombatState, cell: Vector2i, steps: int, danger: Dictionary, shield: Dictionary) -> int:
	var value: int = -steps + SCORE_HAZARD * state.hazard(cell.x, cell.y) \
		+ SCORE_DANGER * int(danger.get(cell, 0)) + int(shield.get(cell, 0))
	if state.piles.has(cell):
		value += SCORE_PILE_SALVAGE if String(state.objective().get("type", "")) == "salvage" else SCORE_PILE
	return value


static func _preferred_distance(u: GridUnit) -> int:
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
