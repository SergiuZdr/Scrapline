class_name CombatSim
extends RefCounted

## The rules of a fight on the hex board.
##
## A fight is `start(setup)` followed by `apply(state, action)` for every action the
## player takes. Nothing else changes a `CombatState`. Because of that, `replay` of the
## same setup and the same action list reproduces a fight exactly, and undo, save and
## load are all "replay a list of actions" rather than three mechanisms.
##
## An action is plain ints, so an action log serializes as-is:
##   [ACT_MOVE,   ref, x, y]
##   [ACT_ATTACK, ref, weapon, x, y]      the hex aimed at
##   [ACT_VENT,   ref, 0, 0]
##   [ACT_END,    -1,  0, 0]
##
## Aim is free: a weapon targets a HEX. Melee reaches the six neighbours; a shot travels
## the hex line toward its target and hits the first thing on it (piercing shots carry
## on to full range); a lob lands on its hex over everything.
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
	for pile: Dictionary in setup.start_piles:
		var cell := Vector2i(int(pile["x"]), int(pile["y"]))
		state.piles[cell] = int(state.piles.get(cell, 0)) + int(pile["value"])
		state.emit(GridEv.PILE_DROPPED, -1, -1, cell.x, cell.y, int(pile["value"]))
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
			if action.size() >= 5:
				ok = _player_attack(state, int(action[1]), int(action[2]), Vector2i(int(action[3]), int(action[4])))
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

## Every hex a unit could move to this turn, mapped to the path that reaches it
## (excluding the start hex). Empty if the unit cannot move.
static func reachable(state: CombatState, ref: int) -> Dictionary:
	var u: GridUnit = state.unit(ref)
	if u == null or not u.alive or u.objective or u.moved or u.team != GridUnit.TEAM_PLAYER:
		return {}
	if u.acted and not u.move_after_attack:
		return {}
	return paths_from(state, u, u.move)


## Cheapest paths within `budget` movement over the six neighbours. Rubble and ridges cost
## 2. Allies can be walked through but not stopped on; enemies and scrap heaps cannot be
## entered. Scrap piles are open ground. Expansion order is fixed -- lowest cost, then row,
## then column -- so the path chosen between two equal routes never depends on anything else.
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
		for n: Vector2i in Hex.neighbors(cell):
			if not state.inside(n) or state.tile_blocks(n.x, n.y):
				continue
			var occupant: GridUnit = state.unit_at(n.x, n.y)
			if occupant != null and occupant != u and occupant.team != u.team:
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


## Every hex weapon `w` of `u` could be aimed at from where it stands.
static func aim_options(state: CombatState, u: GridUnit, w: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not u.can_fire(w):
		return out
	var here := Vector2i(u.x, u.y)
	var weapon: Dictionary = u.weapons[w]
	var reach: int = weapon_reach(state, u, w)
	var minimum: int = int(weapon["range_min"]) if String(weapon["shape"]) == "lob" else 1
	for cell: Vector2i in Hex.within(here, reach):
		if state.inside(cell) and Hex.distance(here, cell) >= minimum:
			out.append(cell)
	return out


## What firing weapon `w` of `u` at hex `target` would do right now.
## `{ "legal", "aim": Vector2i, "end": Vector2i, "tiles": [Vector2i], "hits": [{ "ref", "damage", "primary" }] }`.
## `tiles` are the hexes the attack covers, for drawing; `end` is where a shot stopped;
## `hits` are the units it lands on, in the order it lands on them. Nothing is changed.
static func strike_plan(state: CombatState, u: GridUnit, w: int, target: Vector2i) -> Dictionary:
	var here := Vector2i(u.x, u.y)
	var plan: Dictionary = {"legal": false, "aim": target, "end": target, "tiles": [], "hits": []}
	if not u.can_fire(w) or not state.inside(target) or target == here:
		return plan
	var weapon: Dictionary = u.weapons[w]
	var shape: String = String(weapon["shape"])
	var reach: int = weapon_reach(state, u, w)
	var dist: int = Hex.distance(here, target)
	var minimum: int = int(weapon["range_min"]) if shape == "lob" else 1
	if dist > reach or dist < minimum:
		return plan
	var base: int = int(weapon["damage"])
	if base > 0:
		base += u.damage_bonus + (u.melee_bonus if shape == "melee" else 0)
	var tiles: Array[Vector2i] = []
	var hits: Array[Dictionary] = []

	match shape:
		"melee":
			tiles.append(target)
			_add_hit(state, u, hits, target, base, true, false)
		"lob":
			tiles.append(target)
			_add_hit(state, u, hits, target, base, true, false)
			for n: Vector2i in Hex.neighbors(target):
				if not state.inside(n):
					continue
				tiles.append(n)
				if int(weapon["splash"]) > 0:
					_add_hit(state, u, hits, n, int(weapon["splash"]), false, false)
		_:
			# A shot: the hex line toward the target. Piercing shots are a beam to full range.
			var pierce_left: int = int(weapon["pierce"])
			var path: Array[Vector2i] = Hex.ray(here, target, reach) if pierce_left > 0 else Hex.line(here, target)
			for c: Vector2i in path:
				if not state.inside(c):
					break
				tiles.append(c)
				plan["end"] = c
				if state.tile_blocks(c.x, c.y):
					break
				var occupant: GridUnit = state.unit_at(c.x, c.y)
				if occupant == null or occupant == u:
					continue
				_add_hit(state, u, hits, c, base, hits.is_empty(), true)
				if pierce_left <= 0:
					break
				pierce_left -= 1
			# A coil arcs from the first thing it hits into one neighbour, a point weaker.
			if int(weapon["chain"]) > 0 and not hits.is_empty() and base > 1:
				var first: GridUnit = state.unit(int(hits[0]["ref"]))
				for n: Vector2i in Hex.neighbors(Vector2i(first.x, first.y)):
					if not state.inside(n):
						continue
					var next: GridUnit = state.unit_at(n.x, n.y)
					if next != null and next != u and not _already_hit(hits, next.ref):
						_add_hit(state, u, hits, n, base - 1, false, false)
						tiles.append(n)
						break

	plan["legal"] = true
	plan["tiles"] = tiles
	plan["hits"] = hits
	return plan


static func _add_hit(state: CombatState, u: GridUnit, hits: Array[Dictionary], cell: Vector2i,
		amount: int, primary: bool, shot: bool) -> void:
	var target: GridUnit = state.unit_at(cell.x, cell.y)
	if target == null or target == u:
		return
	hits.append({"ref": target.ref, "damage": damage_to(state, u, target, amount, shot), "primary": primary})


static func _already_hit(hits: Array[Dictionary], ref: int) -> bool:
	for hit: Dictionary in hits:
		if int(hit["ref"]) == ref:
			return true
	return false


## Final damage of `amount` from `u` to `target`: the type wheel, cover against shots,
## armour, and a mark. Integer only; `(x * pct + 50) / 100` rounds half up.
## A zero-damage weapon stays at zero.
static func damage_to(state: CombatState, u: GridUnit, target: GridUnit, amount: int, shot: bool) -> int:
	if amount <= 0:
		return 0
	var pct: int = 100
	var wheel: Array = state.setup.wheel
	if u.damage_type < wheel.size():
		var row: Variant = wheel[u.damage_type]
		if target.armor_type < row.size():
			pct = int(row[target.armor_type])
	var dmg: int = (amount * pct + 50) / 100
	if shot:
		dmg -= state.cover(target.x, target.y)
	dmg -= target.armor
	if target.marked:
		dmg += state.setup.mark_bonus
	return maxi(state.setup.min_damage, dmg)


## `strike_plan` plus what the player needs to decide: legality for the player, whether
## it overheats the shooter, and which targets it would kill or tear an arm off.
static func preview_attack(state: CombatState, ref: int, w: int, target: Vector2i) -> Dictionary:
	var u: GridUnit = state.unit(ref)
	if u == null or not u.alive:
		return {"legal": false}
	var plan: Dictionary = strike_plan(state, u, w, target)
	plan["legal"] = can_attack(state, ref, w, target)
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


static func can_attack(state: CombatState, ref: int, w: int, target: Vector2i) -> bool:
	var u: GridUnit = state.unit(ref)
	if state.outcome != CombatState.ONGOING or u == null or not u.alive or u.objective:
		return false
	if u.team != GridUnit.TEAM_PLAYER or u.acted or u.seized:
		return false
	return bool(strike_plan(state, u, w, target)["legal"])


## What each enemy intent would do if the turn ended now, keyed by ref:
## `{ ref: { "w", "order", "aim", "end", "tiles", "hits", "legal" } }`. An intent whose hex
## is now out of the attacker's reach (it was shoved) shows as not legal: it will miss.
static func threats(state: CombatState) -> Dictionary:
	var out: Dictionary = {}
	for intent: Dictionary in state.intents:
		var u: GridUnit = state.unit(int(intent["ref"]))
		if u == null or not u.alive or not u.can_fire(int(intent["w"])):
			continue
		var target := Vector2i(int(intent["x"]), int(intent["y"]))
		var plan: Dictionary = strike_plan(state, u, int(intent["w"]), target)
		plan["w"] = int(intent["w"])
		plan["order"] = int(intent["order"])
		out[u.ref] = plan
	return out


## How the fight is going against its objective, for the HUD and the run.
## `{ "type", "text", "caches", "caches_total", "piles", "need", "rounds_left" }`.
static func objective_status(state: CombatState) -> Dictionary:
	var o: Dictionary = state.objective()
	var kind: String = String(o.get("type", "rout"))
	var total: int = 0
	for u: GridUnit in state.units:
		if u.objective:
			total += 1
	var status: Dictionary = {"type": kind, "caches": state.caches().size(), "caches_total": total,
		"piles": state.piles_collected, "need": int(o.get("need", 0)),
		"rounds_left": maxi(0, int(o.get("rounds", 0)) - state.round_number + 1)}
	match kind:
		"defend":
			status["text"] = "DEFEND  ·  %d of %d caches standing  ·  hold %d more round%s, or destroy every enemy" % [
				status["caches"], total, status["rounds_left"], "" if int(status["rounds_left"]) == 1 else "s"]
		"salvage":
			status["text"] = "SALVAGE  ·  scrap piles collected %d of %d  ·  or destroy every enemy" % [
				state.piles_collected, status["need"]]
		_:
			status["text"] = "ROUT  ·  destroy every enemy"
	return status


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
	_collect(state, u)
	_check_outcome(state)
	return true


static func _player_attack(state: CombatState, ref: int, w: int, target: Vector2i) -> bool:
	if not can_attack(state, ref, w, target):
		return false
	var u: GridUnit = state.unit(ref)
	_execute_attack(state, u, w, target)
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


static func _execute_attack(state: CombatState, u: GridUnit, w: int, target: Vector2i) -> void:
	var plan: Dictionary = strike_plan(state, u, w, target)
	var weapon: Dictionary = u.weapons[w]
	var end: Vector2i = plan["end"]
	var origin := Vector2i(u.x, u.y)
	state.emit(GridEv.ATTACK, u.ref, -1, target.x, target.y, w, end.y * 64 + end.x)
	var hits: Array = plan["hits"]
	if hits.is_empty():
		state.emit(GridEv.MISSED, u.ref, -1, end.x, end.y)
	for hit: Dictionary in hits:
		var victim: GridUnit = state.unit(int(hit["ref"]))
		if not victim.alive:
			continue
		var dmg: int = int(hit["damage"])
		var primary: bool = bool(hit["primary"])
		if dmg > 0:
			victim.marked = false
			_hurt(state, u.ref, victim, dmg)
			if victim.alive and primary and _would_tear(state, victim, weapon, dmg):
				_tear(state, u.ref, victim)
		if victim.alive and primary and bool(weapon["mark"]):
			victim.marked = true
			state.emit(GridEv.MARKED, u.ref, victim.ref, victim.x, victim.y)
		if victim.alive and primary and int(weapon["shove"]) > 0:
			_shove(state, u.ref, victim, Hex.direction(origin, Vector2i(victim.x, victim.y)))
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


## Damage, and on death a scrap pile where the machine stood. A cache just breaks.
static func _hurt(state: CombatState, actor: int, target: GridUnit, dmg: int) -> void:
	target.hp = maxi(0, target.hp - dmg)
	state.emit(GridEv.DAMAGE, actor, target.ref, target.x, target.y, dmg, target.hp)
	if target.hp > 0:
		return
	target.alive = false
	state.emit(GridEv.DESTROYED, actor, target.ref, target.x, target.y)
	if not target.objective:
		var cell := Vector2i(target.x, target.y)
		state.piles[cell] = int(state.piles.get(cell, 0)) + state.setup.pile_value
		state.emit(GridEv.PILE_DROPPED, actor, target.ref, cell.x, cell.y, state.setup.pile_value)


## Whoever ends a move on a scrap pile takes it: the player banks the scrap, and the
## machine patches itself. An enemy that gets there first carries it off.
static func _collect(state: CombatState, u: GridUnit) -> void:
	var cell := Vector2i(u.x, u.y)
	if not state.piles.has(cell) or u.objective:
		return
	var value: int = int(state.piles[cell])
	state.piles.erase(cell)
	var heal: int = mini(state.setup.pile_heal, u.max_hp - u.hp)
	u.hp += heal
	if u.team == GridUnit.TEAM_PLAYER:
		state.piles_collected += 1
		state.scrap_collected += value
	state.emit(GridEv.PILE_TAKEN, u.ref, -1, cell.x, cell.y, value, heal)


## Right arm first, then left: a rule the player can learn in one fight.
static func _tear(state: CombatState, actor: int, target: GridUnit) -> void:
	for w: int in [GridUnit.ARM_R, GridUnit.ARM_L]:
		if target.can_fire(w):
			target.weapons[w]["torn"] = true
			state.emit(GridEv.PART_TORN, actor, target.ref, target.x, target.y, w)
			return


## One hex away from the attacker. Into anything solid -- the edge, scrap, a unit -- it
## does not move, and both it and whatever it hit take bump damage instead.
static func _shove(state: CombatState, actor: int, target: GridUnit, dir: int) -> void:
	if target.unshovable:
		return
	var n: Vector2i = Hex.neighbor(Vector2i(target.x, target.y), dir)
	var bump: int = state.setup.bump_damage
	if not state.inside(n) or state.tile_blocks(n.x, n.y):
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
	# Intents fire in their displayed order, from wherever each attacker stands now, at
	# the hex it chose. One that can no longer reach its hex (it was shoved) misses.
	for intent: Dictionary in state.intents:
		var u: GridUnit = state.unit(int(intent["ref"]))
		if u == null or not u.alive or not u.can_fire(int(intent["w"])):
			continue
		var target := Vector2i(int(intent["x"]), int(intent["y"]))
		if not bool(strike_plan(state, u, int(intent["w"]), target)["legal"]):
			state.emit(GridEv.MISSED, u.ref, -1, target.x, target.y)
			continue
		_execute_attack(state, u, int(intent["w"]), target)
		if _check_outcome(state):
			return
	state.intents.clear()
	var o: Dictionary = state.objective()
	if String(o.get("type", "")) == "defend" and state.round_number >= int(o.get("rounds", 0)):
		_finish(state, CombatState.WON)
		return
	if state.round_number >= state.setup.max_rounds:
		_finish(state, CombatState.LOST)
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
	# ones have already left it, so two never pick the same hex.
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
			_collect(state, u)
		var w: int = int(plan["w"])
		if w >= 0:
			order += 1
			var target: Vector2i = plan["target"]
			state.intents.append({"ref": u.ref, "w": w, "x": target.x, "y": target.y, "order": order})
			state.emit(GridEv.INTENT_SET, u.ref, -1, target.x, target.y, w, order)


## Ends the fight if its objective is met or failed. Returns true if it ended.
static func _check_outcome(state: CombatState) -> bool:
	if state.outcome != CombatState.ONGOING:
		return true
	var o: Dictionary = state.objective()
	var kind: String = String(o.get("type", "rout"))
	if state.crew(GridUnit.TEAM_ENEMY).is_empty():
		_finish(state, CombatState.WON)
	elif state.crew(GridUnit.TEAM_PLAYER).is_empty():
		_finish(state, CombatState.LOST)
	elif kind == "defend" and state.caches().is_empty():
		_finish(state, CombatState.LOST)
	elif kind == "salvage" and state.piles_collected >= int(o.get("need", 0)):
		_finish(state, CombatState.WON)
	else:
		return false
	return true


static func _finish(state: CombatState, outcome: int) -> void:
	state.outcome = outcome
	state.intents.clear()
	state.emit(GridEv.FIGHT_END, -1, -1, -1, -1, outcome)


static func _path(came_from: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var cell: Vector2i = goal
	while cell != start:
		path.push_front(cell)
		cell = came_from[cell]
	return path
