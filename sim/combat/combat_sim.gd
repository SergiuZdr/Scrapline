class_name CombatSim
extends RefCounted

## The rules of a grid fight.
##
## A fight is `start(setup)` followed by `apply(state, action)` for every action the
## player takes. Nothing else changes a `CombatState`. Because of that, `replay` of the
## same setup and the same action list reproduces a fight exactly, and undo, save and
## load are all "replay a list of actions" rather than three mechanisms.
##
## An action is plain ints, so an action log serializes as-is:
##   [ACT_MOVE,   ref, x, y]
##   [ACT_ATTACK, ref, weapon, dir, dist]   dist matters only for lobbed weapons
##   [ACT_VENT,   ref, 0, 0]
##   [ACT_END,    -1,  0, 0]
##
## `strike_plan` is the ONE place that works out what an attack hits. The preview, the
## enemy AI, the bot and the attack itself all call it, so what the player is shown is
## by construction what happens.

const ACT_MOVE: int = 0
const ACT_ATTACK: int = 1
const ACT_END: int = 2
const ACT_VENT: int = 3


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
	if state.outcome != CombatState.ONGOING or action.is_empty():
		return false
	var ok: bool = false
	match int(action[0]):
		ACT_MOVE:
			ok = _move(state, int(action[1]), int(action[2]), int(action[3]))
		ACT_ATTACK:
			var dist: int = int(action[4]) if action.size() > 4 else 0
			ok = _player_attack(state, int(action[1]), int(action[2]), int(action[3]), dist)
		ACT_VENT:
			ok = _vent(state, int(action[1]))
		ACT_END:
			_end_turn(state)
			ok = true
	if ok:
		state.action_count += 1
	return ok


# --- Queries -----------------------------------------------------------------
# The presentation and the AI ask these instead of working anything out for themselves.

## Every tile a unit could move to this turn, mapped to the path that reaches it
## (excluding the start tile). Empty if the unit cannot move.
static func reachable(state: CombatState, ref: int) -> Dictionary:
	var u: GridUnit = state.unit(ref)
	if u == null or not u.alive or u.objective or u.moved or u.team != GridUnit.TEAM_PLAYER:
		return {}
	if u.acted and not u.move_after_attack:
		return {}
	return paths_from(state, u, u.move)


## Cheapest paths within `budget` movement, over 4 directions. Rubble and ridges cost 2.
## Allies can be walked through but not stopped on; enemies, wrecks and blocking tiles
## cannot be entered. Expansion order is fixed -- lowest cost, then row, then column --
## so the path chosen between two equal routes never depends on anything else.
static func paths_from(state: CombatState, u: GridUnit, budget: int) -> Dictionary:
	var start := Vector2i(u.x, u.y)
	var cost: Dictionary = {start: 0}
	var came_from: Dictionary = {start: start}
	var open: Array[Vector2i] = [start]
	var done: Dictionary = {}
	while not open.is_empty():
		var best_index: int = 0
		for i: int in range(1, open.size()):
			if _before(open[i], open[best_index], cost):
				best_index = i
		var cell: Vector2i = open[best_index]
		open.remove_at(best_index)
		if done.has(cell):
			continue
		done[cell] = true
		for dir: int in 4:
			var n := Vector2i(cell.x + CombatState.DX[dir], cell.y + CombatState.DY[dir])
			if not state.in_bounds(n.x, n.y) or state.tile_blocks(n.x, n.y):
				continue
			var occupant: GridUnit = state.unit_at(n.x, n.y)
			if occupant != null and occupant != u and (not occupant.alive or occupant.team != u.team):
				continue
			var c: int = int(cost[cell]) + state.move_cost(n.x, n.y)
			if c > budget or (cost.has(n) and int(cost[n]) <= c):
				continue
			cost[n] = c
			came_from[n] = cell
			open.append(n)
	var result: Dictionary = {}
	for cell: Variant in cost:
		if cell == start or state.unit_at(cell.x, cell.y) != null:
			continue
		result[cell] = _path(came_from, start, cell)
	return result


static func _before(a: Vector2i, b: Vector2i, cost: Dictionary) -> bool:
	var ca: int = int(cost[a])
	var cb: int = int(cost[b])
	if ca != cb:
		return ca < cb
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


## Effective reach of weapon `w` for `u` standing where it stands now.
static func weapon_reach(state: CombatState, u: GridUnit, w: int) -> int:
	var weapon: Dictionary = u.weapons[w]
	if String(weapon["shape"]) == "melee":
		return 1
	return int(weapon["range"]) + u.range_bonus + state.range_bonus(u.x, u.y)


## Every `[dir, dist]` weapon `w` could be aimed at from where `u` stands.
static func aim_options(state: CombatState, u: GridUnit, w: int) -> Array:
	var out: Array = []
	if not u.can_fire(w):
		return out
	var weapon: Dictionary = u.weapons[w]
	var lob: bool = String(weapon["shape"]) == "lob"
	var reach: int = weapon_reach(state, u, w)
	for dir: int in 4:
		if lob:
			for dist: int in range(int(weapon["range_min"]), reach + 1):
				if state.in_bounds(u.x + CombatState.DX[dir] * dist, u.y + CombatState.DY[dir] * dist):
					out.append([dir, dist])
		elif state.in_bounds(u.x + CombatState.DX[dir], u.y + CombatState.DY[dir]):
			out.append([dir, 0])
	return out


## What firing weapon `w` of `u` in `dir` (at `dist`, for a lob) would do right now.
## `{ "legal", "aim": Vector2i, "tiles": [Vector2i], "hits": [{ "ref", "damage", "primary" }] }`.
## `tiles` are the cells the attack covers, for drawing; `hits` are the units it lands on,
## in the order it lands on them. Nothing is changed.
static func strike_plan(state: CombatState, u: GridUnit, w: int, dir: int, dist: int) -> Dictionary:
	var plan: Dictionary = {"legal": false, "aim": Vector2i(u.x, u.y), "tiles": [], "hits": []}
	if not u.can_fire(w) or dir < 0 or dir > 3:
		return plan
	var weapon: Dictionary = u.weapons[w]
	var shape: String = String(weapon["shape"])
	var base: int = int(weapon["damage"])
	if base > 0:
		base += u.damage_bonus + (u.melee_bonus if shape == "melee" else 0)
	var dx: int = CombatState.DX[dir]
	var dy: int = CombatState.DY[dir]
	var tiles: Array[Vector2i] = []
	var hits: Array[Dictionary] = []

	if shape == "lob":
		var reach: int = weapon_reach(state, u, w)
		if dist < int(weapon["range_min"]) or dist > reach:
			return plan
		var centre := Vector2i(u.x + dx * dist, u.y + dy * dist)
		if not state.in_bounds(centre.x, centre.y):
			return plan
		plan["aim"] = centre
		tiles.append(centre)
		_add_hit(state, u, hits, centre, base, true, false)
		for d: int in 4:
			var n := Vector2i(centre.x + CombatState.DX[d], centre.y + CombatState.DY[d])
			if not state.in_bounds(n.x, n.y):
				continue
			tiles.append(n)
			if int(weapon["splash"]) > 0:
				_add_hit(state, u, hits, n, int(weapon["splash"]), false, false)
	else:
		var reach: int = weapon_reach(state, u, w)
		var pierce_left: int = int(weapon["pierce"])
		for step: int in range(1, reach + 1):
			var c := Vector2i(u.x + dx * step, u.y + dy * step)
			if not state.in_bounds(c.x, c.y):
				break
			tiles.append(c)
			plan["aim"] = c
			if state.tile_blocks(c.x, c.y):
				break
			var occupant: GridUnit = state.unit_at(c.x, c.y)
			if occupant == null or occupant == u:
				continue
			if not occupant.alive:
				break
			_add_hit(state, u, hits, c, base, hits.is_empty(), shape == "line")
			if pierce_left <= 0:
				break
			pierce_left -= 1
		if tiles.is_empty():
			return plan
		# A coil arcs from the first thing it hits into one neighbour, a point weaker.
		if int(weapon["chain"]) > 0 and not hits.is_empty() and base > 1:
			var first: GridUnit = state.unit(int(hits[0]["ref"]))
			for d: int in 4:
				var n := Vector2i(first.x + CombatState.DX[d], first.y + CombatState.DY[d])
				if not state.in_bounds(n.x, n.y):
					continue
				var next: GridUnit = state.unit_at(n.x, n.y)
				if next != null and next.alive and next != u and not _already_hit(hits, next.ref):
					_add_hit(state, u, hits, n, base - 1, false, false)
					tiles.append(n)
					break

	plan["legal"] = true
	plan["tiles"] = tiles
	plan["hits"] = hits
	return plan


static func _add_hit(state: CombatState, u: GridUnit, hits: Array[Dictionary], cell: Vector2i,
		amount: int, primary: bool, ranged_line: bool) -> void:
	var target: GridUnit = state.unit_at(cell.x, cell.y)
	if target == null or not target.alive or target == u:
		return
	hits.append({"ref": target.ref, "damage": damage_to(state, u, target, amount, ranged_line), "primary": primary})


static func _already_hit(hits: Array[Dictionary], ref: int) -> bool:
	for hit: Dictionary in hits:
		if int(hit["ref"]) == ref:
			return true
	return false


## Final damage of `amount` from `u` to `target`: the type wheel, cover against line
## shots, armour, and a mark. Integer only; `(x * pct + 50) / 100` rounds half up.
## A zero-damage weapon (the scanner) stays at zero -- it marks, it does not hurt.
static func damage_to(state: CombatState, u: GridUnit, target: GridUnit, amount: int, ranged_line: bool) -> int:
	if amount <= 0:
		return 0
	var pct: int = 100
	var wheel: Array = state.setup.wheel
	if u.damage_type < wheel.size():
		var row: Variant = wheel[u.damage_type]
		if target.armor_type < row.size():
			pct = int(row[target.armor_type])
	var dmg: int = (amount * pct + 50) / 100
	if ranged_line:
		dmg -= state.cover(target.x, target.y)
	dmg -= target.armor
	if target.marked:
		dmg += state.setup.mark_bonus
	return maxi(state.setup.min_damage, dmg)


## `strike_plan` plus what the player needs to decide: legality for the player, whether
## it overheats the shooter, and which targets it would kill or tear an arm off.
static func preview_attack(state: CombatState, ref: int, w: int, dir: int, dist: int) -> Dictionary:
	var u: GridUnit = state.unit(ref)
	if u == null or not u.alive:
		return {"legal": false}
	var plan: Dictionary = strike_plan(state, u, w, dir, dist)
	plan["legal"] = can_attack(state, ref, w, dir, dist)
	var weapon: Dictionary = u.weapons[w] if w >= 0 and w < u.weapons.size() else {}
	plan["overheats"] = not weapon.is_empty() and u.heat + int(weapon.get("heat", 0)) + u.heat_bonus >= u.heat_cap
	var kills: Array = []
	var tears: Array = []
	for hit: Dictionary in (plan["hits"] as Array):
		var t: GridUnit = state.unit(int(hit["ref"]))
		if int(hit["damage"]) >= t.hp:
			kills.append(t.ref)
		elif bool(hit["primary"]) and _would_tear(state, t, weapon, int(hit["damage"])):
			tears.append(t.ref)
	plan["kills"] = kills
	plan["tears"] = tears
	return plan


static func can_attack(state: CombatState, ref: int, w: int, dir: int, dist: int) -> bool:
	var u: GridUnit = state.unit(ref)
	if state.outcome != CombatState.ONGOING or u == null or not u.alive or u.objective:
		return false
	if u.team != GridUnit.TEAM_PLAYER or u.acted or u.seized:
		return false
	return bool(strike_plan(state, u, w, dir, dist)["legal"])


## What each enemy intent would do if the turn ended now, keyed by ref:
## `{ ref: { "w", "dir", "dist", "order", "aim", "tiles", "hits" } }`.
static func threats(state: CombatState) -> Dictionary:
	var out: Dictionary = {}
	for intent: Dictionary in state.intents:
		var u: GridUnit = state.unit(int(intent["ref"]))
		if u == null or not u.alive or not u.can_fire(int(intent["w"])):
			continue
		var plan: Dictionary = strike_plan(state, u, int(intent["w"]), int(intent["dir"]), int(intent["dist"]))
		plan["w"] = int(intent["w"])
		plan["dir"] = int(intent["dir"])
		plan["dist"] = int(intent["dist"])
		plan["order"] = int(intent["order"])
		out[u.ref] = plan
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


static func _player_attack(state: CombatState, ref: int, w: int, dir: int, dist: int) -> bool:
	if not can_attack(state, ref, w, dir, dist):
		return false
	var u: GridUnit = state.unit(ref)
	_execute_attack(state, u, w, dir, dist)
	u.acted = true
	if not u.move_after_attack:
		u.moved = true
	_check_outcome(state)
	return true


static func _vent(state: CombatState, ref: int) -> bool:
	var u: GridUnit = state.unit(ref)
	if u == null or not u.alive or u.objective or u.team != GridUnit.TEAM_PLAYER or u.acted:
		return false
	u.heat = 0
	u.acted = true
	if not u.move_after_attack:
		u.moved = true
	state.emit(GridEv.VENTED, ref, -1, u.x, u.y, 0)
	return true


static func _execute_attack(state: CombatState, u: GridUnit, w: int, dir: int, dist: int) -> void:
	var plan: Dictionary = strike_plan(state, u, w, dir, dist)
	var weapon: Dictionary = u.weapons[w]
	var aim: Vector2i = plan["aim"]
	state.emit(GridEv.ATTACK, u.ref, -1, aim.x, aim.y, w, dir)
	var hits: Array = plan["hits"]
	if hits.is_empty():
		state.emit(GridEv.MISSED, u.ref, -1, aim.x, aim.y)
	for hit: Dictionary in hits:
		var target: GridUnit = state.unit(int(hit["ref"]))
		if not target.alive:
			continue
		var dmg: int = int(hit["damage"])
		var primary: bool = bool(hit["primary"])
		if dmg > 0:
			target.marked = false
			_hurt(state, u.ref, target, dmg)
			if target.alive and primary and _would_tear(state, target, weapon, dmg):
				_tear(state, u.ref, target)
		if target.alive and primary and bool(weapon["mark"]):
			target.marked = true
			state.emit(GridEv.MARKED, u.ref, target.ref, target.x, target.y)
		if target.alive and primary and int(weapon["shove"]) > 0:
			_shove(state, u.ref, target, dir)
	# Heat is the PLAYER's resource. Enemies ignore it: an enemy that sometimes cannot
	# fire would be one more hidden state to read off the board every turn.
	if u.team == GridUnit.TEAM_PLAYER:
		u.heat += int(weapon["heat"]) + u.heat_bonus
		state.emit(GridEv.HEAT, u.ref, -1, u.x, u.y, u.heat, u.heat_cap)
		if u.heat >= u.heat_cap and not u.overheated:
			u.overheated = true
			state.emit(GridEv.OVERHEAT, u.ref, -1, u.x, u.y)


static func _would_tear(state: CombatState, target: GridUnit, weapon: Dictionary, dmg: int) -> bool:
	if target.objective or not target.has_weapon() or dmg <= 0:
		return false
	return dmg >= state.setup.tear_threshold or bool(weapon.get("tears", false))


static func _hurt(state: CombatState, actor: int, target: GridUnit, dmg: int) -> void:
	target.hp = maxi(0, target.hp - dmg)
	state.emit(GridEv.DAMAGE, actor, target.ref, target.x, target.y, dmg, target.hp)
	if target.hp == 0:
		target.alive = false
		state.emit(GridEv.DESTROYED, actor, target.ref, target.x, target.y)


## Right arm first, then left: a rule the player can learn in one fight.
static func _tear(state: CombatState, actor: int, target: GridUnit) -> void:
	for w: int in [GridUnit.ARM_R, GridUnit.ARM_L]:
		if target.can_fire(w):
			target.weapons[w]["torn"] = true
			state.emit(GridEv.PART_TORN, actor, target.ref, target.x, target.y, w)
			return


## One tile away from the attacker. Into anything solid -- the edge, scrap, a wreck, a
## unit -- it does not move, and both it and whatever it hit take bump damage instead.
static func _shove(state: CombatState, actor: int, target: GridUnit, dir: int) -> void:
	if target.unshovable:
		return
	var n := Vector2i(target.x + CombatState.DX[dir], target.y + CombatState.DY[dir])
	var bump: int = state.setup.bump_damage
	if not state.in_bounds(n.x, n.y) or state.tile_blocks(n.x, n.y):
		state.emit(GridEv.BUMP, actor, target.ref, n.x, n.y, bump)
		_hurt(state, actor, target, bump)
		return
	var occupant: GridUnit = state.unit_at(n.x, n.y)
	if occupant != null:
		state.emit(GridEv.BUMP, actor, target.ref, n.x, n.y, bump)
		_hurt(state, actor, target, bump)
		if occupant.alive:
			_hurt(state, actor, occupant, bump)
		return
	var from := Vector2i(target.x, target.y)
	target.x = n.x
	target.y = n.y
	state.emit(GridEv.SHOVED, actor, target.ref, n.x, n.y, from.x, from.y)


static func _end_turn(state: CombatState) -> void:
	state.emit(GridEv.TURN_END)
	# Intents fire in their displayed order, from wherever each attacker stands now.
	for intent: Dictionary in state.intents:
		var u: GridUnit = state.unit(int(intent["ref"]))
		if u == null or not u.alive or not u.can_fire(int(intent["w"])):
			continue
		var plan: Dictionary = strike_plan(state, u, int(intent["w"]), int(intent["dir"]), int(intent["dist"]))
		if not bool(plan["legal"]):
			continue
		_execute_attack(state, u, int(intent["w"]), int(intent["dir"]), int(intent["dist"]))
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
	state.emit(GridEv.ROUND_START, -1, -1, -1, -1, state.round_number)
	for u: GridUnit in state.units:
		u.moved = false
		u.acted = false
		u.seized = false
		if not u.alive or u.objective or u.team != GridUnit.TEAM_PLAYER:
			continue
		if u.overheated:
			u.overheated = false
			u.seized = true
			u.heat = 0
			state.emit(GridEv.SEIZED, u.ref, -1, u.x, u.y)
		elif u.heat > 0:
			u.heat = maxi(0, u.heat - u.vent)
			state.emit(GridEv.HEAT, u.ref, -1, u.x, u.y, u.heat, u.heat_cap)

	# Terrain bites before anyone moves, so standing on slag is a decision made last turn.
	for u: GridUnit in state.units:
		if u.alive and state.hazard(u.x, u.y) > 0:
			_hurt(state, -1, u, state.hazard(u.x, u.y))
	if _check_outcome(state):
		return

	# Enemies move and commit in ref order. Each plans against the board as the earlier
	# ones have already left it, so two never pick the same tile.
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
		var w: int = int(plan["w"])
		if w >= 0:
			order += 1
			var intent: Dictionary = {"ref": u.ref, "w": w, "dir": int(plan["dir"]), "dist": int(plan["dist"]), "order": order}
			state.intents.append(intent)
			var aim: Vector2i = strike_plan(state, u, w, int(plan["dir"]), int(plan["dist"]))["aim"]
			state.emit(GridEv.INTENT_SET, u.ref, -1, aim.x, aim.y, w, int(plan["dir"]) * 16 + int(plan["dist"]))


## Ends the fight if one side is finished. Returns true if it ended.
## The player loses when the crew is gone OR the Crawler is.
static func _check_outcome(state: CombatState) -> bool:
	if state.outcome != CombatState.ONGOING:
		return true
	var crawler: GridUnit = state.crawler()
	if state.crew(GridUnit.TEAM_ENEMY).is_empty():
		state.outcome = CombatState.WON
	elif state.crew(GridUnit.TEAM_PLAYER).is_empty() or (crawler != null and not crawler.alive):
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
