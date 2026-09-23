class_name IntentAI
extends RefCounted

## Picks where a unit moves and which way it fires.
##
## Enemies use it to choose their telegraphed intent. The headless bot uses the same
## function for the player side, which keeps "the bot can win" and "the enemy plays
## sensibly" one piece of code instead of two that drift apart.
##
## Deterministic: candidates are visited in a fixed order and ties are broken by a
## full avalanche hash, never by visit order alone. (The old game's tie-break was a
## 16-bit multiply, and it handed one team every simultaneous exchange.)

const SCORE_HIT: int = 100
const SCORE_KILL: int = 60
const SCORE_FRIENDLY_FIRE: int = -100
const SCORE_DANGER: int = -40
## Preferred distance from the nearest foe when there is nothing to shoot at.
const APPROACH_MELEE: int = 1
const APPROACH_RANGED: int = 3


## Returns `{ "dest": Vector2i, "path": Array[Vector2i], "dir": int (-1 = no attack), "score": int }`.
## `danger`: tiles to avoid ending on (`{Vector2i: true}`). The bot passes the tiles enemy
## intents will strike; enemies pass nothing.
static func plan(state: CombatState, u: GridUnit, danger: Dictionary) -> Dictionary:
	var here := Vector2i(u.x, u.y)
	var options: Dictionary = CombatSim.paths_from(state, u, u.move)
	options[here] = [] as Array[Vector2i]

	var cells: Array = options.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))

	var best: Dictionary = {}
	var best_score: int = -1000000
	var best_tie: int = 0
	for cell: Vector2i in cells:
		var path: Array = options[cell]
		var base: int = -path.size() + (SCORE_DANGER if danger.has(cell) else 0)
		for dir: int in 4:
			var shot: Dictionary = CombatSim.trace(state, cell.x, cell.y, dir, u.attack_range, u.ref)
			var score: int = base + _shot_value(state, u, int(shot["hit"]))
			var tie: int = mix(state.setup.rng_seed, u.ref * 131 + state.round_number, cell.x * 17 + cell.y, dir)
			if score > best_score or (score == best_score and tie < best_tie):
				best_score = score
				best_tie = tie
				best = {"dest": cell, "path": path, "dir": dir, "score": score}

	if best_score >= SCORE_HIT / 2:
		return best

	# Nothing worth shooting from anywhere reachable: close to a useful distance instead.
	var want: int = APPROACH_MELEE if u.attack_range <= 1 else APPROACH_RANGED
	best = {}
	best_score = -1000000
	for cell: Vector2i in cells:
		var gap: int = _nearest_foe_distance(state, u, cell)
		var score: int = -absi(gap - want) * 10 - (options[cell] as Array).size() \
			+ (SCORE_DANGER if danger.has(cell) else 0)
		var tie: int = mix(state.setup.rng_seed, u.ref * 131 + state.round_number, cell.x * 17 + cell.y, 7)
		if score > best_score or (score == best_score and tie < best_tie):
			best_score = score
			best_tie = tie
			best = {"dest": cell, "path": options[cell], "dir": -1, "score": score}
	return best


static func _shot_value(state: CombatState, u: GridUnit, hit_ref: int) -> int:
	if hit_ref < 0:
		return 0
	var target: GridUnit = state.unit(hit_ref)
	if target == null or not target.alive:
		return 0
	if not target.is_enemy_of(u):
		return SCORE_FRIENDLY_FIRE
	var value: int = SCORE_HIT + u.damage * 10 + (target.max_hp - target.hp)
	if u.damage >= target.hp:
		value += SCORE_KILL
	return value


static func _nearest_foe_distance(state: CombatState, u: GridUnit, cell: Vector2i) -> int:
	var nearest: int = 1000
	for other: GridUnit in state.units:
		if other.alive and other.is_enemy_of(u):
			nearest = mini(nearest, absi(other.x - cell.x) + absi(other.y - cell.y))
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
