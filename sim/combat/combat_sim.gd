class_name CombatSim
extends RefCounted

## The rules of a grid fight.
##
## A fight is `start(setup)` followed by `apply(state, action)` for every action the
## player takes. Nothing else changes a `CombatState`. Because of that, `replay` of the
## same setup and the same action list reproduces a fight exactly, and undo, save and
## load are all "replay a list of actions" rather than three mechanisms.
##
## An action is `[kind, ref, a, b]`, plain ints, so an action log serializes as-is:
##   [ACT_MOVE,   ref, x, y]
##   [ACT_ATTACK, ref, dir, 0]
##   [ACT_END,    -1,  0, 0]

const ACT_MOVE: int = 0
const ACT_ATTACK: int = 1
const ACT_END: int = 2


static func start(setup: CombatSetup) -> CombatState:
	var state := CombatState.new()
	state.setup = setup
	state.width = setup.width
	state.height = setup.height
	for u: GridUnit in setup.units:
		state.units.append(u.copy())
	state.units.sort_custom(func(a: GridUnit, b: GridUnit) -> bool: return a.ref < b.ref)
	state.emit(GridEv.FIGHT_START)
	_begin_round(state)
	return state


static func replay(setup: CombatSetup, actions: Array) -> CombatState:
	var state: CombatState = start(setup)
	for action: Array in actions:
		apply(state, action)
	return state


## Applies one player action. Returns false, and changes nothing, if it is not legal.
static func apply(state: CombatState, action: Array) -> bool:
	if state.outcome != CombatState.ONGOING:
		return false
	var kind: int = int(action[0])
	var ok: bool = false
	match kind:
		ACT_MOVE:
			ok = _move(state, int(action[1]), int(action[2]), int(action[3]))
		ACT_ATTACK:
			ok = _player_attack(state, int(action[1]), int(action[2]))
		ACT_END:
			_end_turn(state)
			ok = true
	if ok:
		state.action_count += 1
	return ok


# --- Queries -----------------------------------------------------------------
# The presentation asks these instead of working anything out for itself.

## Every tile a unit could move to this turn, mapped to the path that reaches it
## (excluding the start tile). Empty if the unit cannot move.
static func reachable(state: CombatState, ref: int) -> Dictionary:
	var u: GridUnit = state.unit(ref)
	if u == null or not u.alive or u.moved or u.acted or u.team != GridUnit.TEAM_PLAYER:
		return {}
	return paths_from(state, u, u.move)


## BFS over 4 directions in fixed order. Allies can be walked through but not stopped
## on; enemies, wrecks and blocking tiles cannot be entered at all.
static func paths_from(state: CombatState, u: GridUnit, budget: int) -> Dictionary:
	var result: Dictionary = {}
	var start := Vector2i(u.x, u.y)
	var came_from: Dictionary = {start: start}
	var frontier: Array[Vector2i] = [start]
	var cost: Dictionary = {start: 0}
	while not frontier.is_empty():
		var next_frontier: Array[Vector2i] = []
		for cell: Vector2i in frontier:
			if int(cost[cell]) >= budget:
				continue
			for dir: int in 4:
				var n := Vector2i(cell.x + CombatState.DX[dir], cell.y + CombatState.DY[dir])
				if came_from.has(n) or not state.in_bounds(n.x, n.y) or state.tile_blocks(n.x, n.y):
					continue
				var occupant: GridUnit = state.unit_at(n.x, n.y)
				if occupant != null and (not occupant.alive or occupant.team != u.team):
					continue
				came_from[n] = cell
				cost[n] = int(cost[cell]) + 1
				next_frontier.append(n)
				if occupant == null:
					result[n] = _path(came_from, start, n)
		frontier = next_frontier
	return result


## Traces a shot from (x, y) one step at a time in `dir`, for up to `reach` tiles.
## Stops at the first unit or wreck, a blocking tile, or the board edge.
## Returns `{ "hit": ref or -1, "end": Vector2i, "tiles": Array[Vector2i] }`, where
## `tiles` are the cells the shot passed over including the one it stopped on, and
## `end` is (x, y) itself if it could not leave the start tile.
static func trace(state: CombatState, x: int, y: int, dir: int, reach: int,
		ignore_ref: int = -1) -> Dictionary:
	var tiles: Array[Vector2i] = []
	var end := Vector2i(x, y)
	var hit: int = -1
	for step: int in range(1, reach + 1):
		var cx: int = x + CombatState.DX[dir] * step
		var cy: int = y + CombatState.DY[dir] * step
		if not state.in_bounds(cx, cy):
			break
		tiles.append(Vector2i(cx, cy))
		end = Vector2i(cx, cy)
		if state.tile_blocks(cx, cy):
			break
		var occupant: GridUnit = state.unit_at(cx, cy)
		if occupant != null and occupant.ref != ignore_ref:
			if occupant.alive:
				hit = occupant.ref
			break
	return {"hit": hit, "end": end, "tiles": tiles}


## What an attack in `dir` would do right now:
## `{ "legal": bool, "target": ref or -1, "damage": int, "kills": bool, "tiles": [...], "end": Vector2i }`.
static func preview_attack(state: CombatState, ref: int, dir: int) -> Dictionary:
	var u: GridUnit = state.unit(ref)
	if u == null or not u.alive:
		return {"legal": false}
	var shot: Dictionary = trace(state, u.x, u.y, dir, u.attack_range)
	var target: GridUnit = state.unit(int(shot["hit"]))
	return {
		"legal": can_attack(state, ref, dir),
		"target": int(shot["hit"]),
		"damage": u.damage if target != null else 0,
		"kills": target != null and u.damage >= target.hp,
		"tiles": shot["tiles"],
		"end": shot["end"],
	}


static func can_attack(state: CombatState, ref: int, dir: int) -> bool:
	var u: GridUnit = state.unit(ref)
	if state.outcome != CombatState.ONGOING or u == null or not u.alive:
		return false
	if u.team != GridUnit.TEAM_PLAYER or u.acted or dir < 0 or dir > 3:
		return false
	return not (trace(state, u.x, u.y, dir, u.attack_range)["tiles"] as Array).is_empty()


## Tiles each enemy intent would strike if the turn ended now, keyed by ref:
## `{ ref: { "dir", "order", "tiles": [...], "end": Vector2i, "hit": ref or -1 } }`.
static func threats(state: CombatState) -> Dictionary:
	var out: Dictionary = {}
	for intent: Dictionary in state.intents:
		var u: GridUnit = state.unit(int(intent["ref"]))
		if u == null or not u.alive:
			continue
		var shot: Dictionary = trace(state, u.x, u.y, int(intent["dir"]), u.attack_range)
		out[u.ref] = {
			"dir": int(intent["dir"]),
			"order": int(intent["order"]),
			"tiles": shot["tiles"],
			"end": shot["end"],
			"hit": shot["hit"],
		}
	return out


# --- Actions -----------------------------------------------------------------

static func _move(state: CombatState, ref: int, x: int, y: int) -> bool:
	var options: Dictionary = reachable(state, ref)
	var dest := Vector2i(x, y)
	if not options.has(dest):
		return false
	var u: GridUnit = state.unit(ref)
	var from := Vector2i(u.x, u.y)
	for cell: Vector2i in (options[dest] as Array):
		state.emit(GridEv.STEP, ref, -1, cell.x, cell.y)
	u.x = x
	u.y = y
	u.moved = true
	state.emit(GridEv.MOVED, ref, -1, x, y, from.x, from.y)
	return true


static func _player_attack(state: CombatState, ref: int, dir: int) -> bool:
	if not can_attack(state, ref, dir):
		return false
	var u: GridUnit = state.unit(ref)
	_fire(state, u, dir)
	u.acted = true
	# A player unit cannot move after attacking.
	u.moved = true
	_check_outcome(state)
	return true


static func _fire(state: CombatState, u: GridUnit, dir: int) -> void:
	var shot: Dictionary = trace(state, u.x, u.y, dir, u.attack_range)
	var end: Vector2i = shot["end"]
	var hit: int = int(shot["hit"])
	state.emit(GridEv.ATTACK, u.ref, hit, end.x, end.y, dir)
	if hit < 0:
		state.emit(GridEv.MISSED, u.ref, -1, end.x, end.y)
		return
	var target: GridUnit = state.unit(hit)
	target.hp = maxi(0, target.hp - u.damage)
	state.emit(GridEv.DAMAGE, u.ref, hit, target.x, target.y, u.damage, target.hp)
	if target.hp == 0:
		target.alive = false
		state.emit(GridEv.DESTROYED, u.ref, hit, target.x, target.y)


static func _end_turn(state: CombatState) -> void:
	state.emit(GridEv.TURN_END)
	# Intents fire in their displayed order, from wherever each attacker stands now.
	for intent: Dictionary in state.intents:
		var u: GridUnit = state.unit(int(intent["ref"]))
		if u == null or not u.alive:
			continue
		_fire(state, u, int(intent["dir"]))
		if _check_outcome(state):
			return
	state.intents.clear()
	if state.round_number >= state.setup.max_rounds:
		state.outcome = CombatState.LOST
		state.emit(GridEv.FIGHT_END, -1, -1, -1, -1, CombatState.LOST)
		return
	_begin_round(state)


static func _begin_round(state: CombatState) -> void:
	state.round_number += 1
	state.intents.clear()
	for u: GridUnit in state.units:
		u.moved = false
		u.acted = false
	state.emit(GridEv.ROUND_START, -1, -1, -1, -1, state.round_number)

	# Enemies move and commit in ref order. Each one plans against the board as the
	# earlier ones have already left it, so two never pick the same tile.
	var order: int = 0
	for u: GridUnit in state.units:
		if not u.alive or u.team != GridUnit.TEAM_ENEMY:
			continue
		var plan: Dictionary = IntentAI.plan(state, u, {})
		var dest: Vector2i = plan["dest"]
		if dest != Vector2i(u.x, u.y):
			var from := Vector2i(u.x, u.y)
			for cell: Vector2i in (plan["path"] as Array):
				state.emit(GridEv.STEP, u.ref, -1, cell.x, cell.y)
			u.x = dest.x
			u.y = dest.y
			state.emit(GridEv.MOVED, u.ref, -1, u.x, u.y, from.x, from.y)
		var dir: int = int(plan["dir"])
		if dir >= 0:
			order += 1
			state.intents.append({"ref": u.ref, "dir": dir, "order": order})
			var shot: Dictionary = trace(state, u.x, u.y, dir, u.attack_range)
			var end: Vector2i = shot["end"]
			state.emit(GridEv.INTENT_SET, u.ref, int(shot["hit"]), end.x, end.y, dir, order)


## Ends the fight if one side has nothing left standing. Returns true if it ended.
static func _check_outcome(state: CombatState) -> bool:
	if state.outcome != CombatState.ONGOING:
		return true
	if state.living(GridUnit.TEAM_ENEMY).is_empty():
		state.outcome = CombatState.WON
	elif state.living(GridUnit.TEAM_PLAYER).is_empty():
		state.outcome = CombatState.LOST
	else:
		return false
	state.intents.clear()
	state.emit(GridEv.FIGHT_END, -1, -1, -1, -1, state.outcome)
	return true


static func _path(came_from: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var cell: Vector2i = goal
	while cell != start:
		path.push_front(cell)
		cell = came_from[cell]
	return path
