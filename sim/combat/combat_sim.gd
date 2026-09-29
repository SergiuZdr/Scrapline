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
##   [ACT_ABILITY, ref, ability, x, y]    x, y ignored by abilities that take no target
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
const ACT_ABILITY: int = 4

## What an arc's route search (play-test 5) counts, besides damage x 10: a kill, and a crate
## (a jump into a crate is better than none, worse than any real damage).
const ARC_KILL: int = 60
const ARC_CRATE: int = 2


static func start(setup: CombatSetup) -> CombatState:
	var state := CombatState.new()
	state.setup = setup
	state.width = setup.width
	state.height = setup.height
	for u: GridUnit in setup.units:
		state.units.append(u.copy())
	state.units.sort_custom(func(a: GridUnit, b: GridUnit) -> bool: return a.ref < b.ref)
	state.emit(GridEv.FIGHT_START)
	for prop: Dictionary in setup.start_props:
		var cell := Vector2i(int(prop["x"]), int(prop["y"]))
		state.props[cell] = {"kind": String(prop["kind"]), "hp": int(prop["hp"])}
		state.emit(GridEv.PROP_PLACED, -1, -1, cell.x, cell.y, maxi(0, GridEv.PROP_KINDS.find(String(prop["kind"]))))
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
		ACT_ABILITY:
			if action.size() >= 5:
				ok = CombatAbilities.use(state, int(action[1]), int(action[2]), Vector2i(int(action[3]), int(action[4])))
				if ok:
					_check_outcome(state)
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
## 2. Allies can be walked through but not stopped on; enemies, scrap heaps, props and pits
## cannot be entered. Scrap piles are open ground. Expansion order is fixed -- lowest cost, then row,
## then column -- so the path chosen between two equal routes never depends on anything else.
##
## Among routes of equal cost, the one that picks up the most scrap wins, then the one with
## fewer hexes (`_better`). Every pile on a route is taken (`collect_path`), so which of two
## equally cheap routes a machine walks is a real outcome: play-test 5 watched machines walk
## round piles as often as over them. Never a detour -- the cost, and so the reach, is the
## cheapest either way. Every step costs at least 1, so a hex's best route is settled before
## it is expanded.
static func paths_from(state: CombatState, u: GridUnit, budget: int) -> Dictionary:
	var start := Vector2i(u.x, u.y)
	var cost: Dictionary = {start: 0}
	# Scrap picked up on the way (an objective takes none), then hexes walked: the tie-breaks.
	var scrap: Dictionary = {start: 0}
	var steps: Dictionary = {start: 0}
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
			if not state.inside(n) or state.solid(n) or state.is_pit(n):
				continue
			var occupant: GridUnit = state.unit_at(n.x, n.y)
			if occupant != null and occupant != u and occupant.team != u.team:
				continue
			var c: int = int(cost[cell]) + state.move_cost(n.x, n.y)
			var taken: int = int(scrap[cell]) + (0 if u.objective else int(state.piles.get(n, 0)))
			var walked: int = int(steps[cell]) + 1
			if c > budget or done.has(n):
				continue
			if cost.has(n) and not _better(c, taken, walked, int(cost[n]), int(scrap[n]), int(steps[n])):
				continue
			cost[n] = c
			scrap[n] = taken
			steps[n] = walked
			came_from[n] = cell
			open.append(n)
	var result: Dictionary = {}
	for cell: Variant in cost:
		if cell == start or state.unit_at(cell.x, cell.y) != null:
			continue
		result[cell] = _path(came_from, start, cell)
	return result


## Whether a route to a hex beats the best one found so far: cheaper, then more scrap picked
## up on the way, then fewer hexes. A tie keeps the route found first.
static func _better(c: int, taken: int, walked: int, best_c: int, best_taken: int, best_walked: int) -> bool:
	if c != best_c:
		return c < best_c
	if taken != best_taken:
		return taken > best_taken
	return walked < best_walked


static func _before(a: Vector2i, b: Vector2i, cost: Dictionary) -> bool:
	var ca: int = int(cost[a])
	var cb: int = int(cost[b])
	if ca != cb:
		return ca < cb
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


## The heat one attack with `weapon` adds to `u`: the arm's, the core's and module's, and any
## boost it has armed. Never below zero -- a tuning can take heat off an arm, and a cold
## weapon must not cool the machine by firing.
static func attack_heat(u: GridUnit, weapon: Dictionary) -> int:
	return maxi(0, int(weapon.get("heat", 0)) + u.heat_bonus + u.boost_heat)


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
		base += u.damage_bonus + (u.melee_bonus if shape == "melee" else 0) + u.boost_damage
	var tiles: Array[Vector2i] = []
	var hits: Array[Dictionary] = []
	# Props struck, `{ "cell", "damage" }`: a prop takes the raw number, no armour wheel.
	var props: Array[Dictionary] = []

	match shape:
		"melee":
			tiles.append(target)
			_add_hit(state, u, hits, target, base, true, false)
			_add_prop(state, props, target, base)
		"lob":
			tiles.append(target)
			_add_hit(state, u, hits, target, base, true, false)
			_add_prop(state, props, target, base)
			for n: Vector2i in Hex.neighbors(target):
				if not state.inside(n):
					continue
				tiles.append(n)
				if int(weapon["splash"]) > 0:
					_add_hit(state, u, hits, n, int(weapon["splash"]), false, false)
					_add_prop(state, props, n, int(weapon["splash"]))
		_:
			# A shot: the hex line toward the target, on whichever of the two leanings is
			# clear (play-test 4). Piercing shots are a beam that carries on past their range
			# (`pierce_overshoot` hexes) at reduced damage.
			var pierce_left: int = int(weapon["pierce"])
			var piercing: bool = pierce_left > 0
			var overshoot: int = state.setup.pierce_overshoot if piercing else 0
			var path: Array[Vector2i] = best_line(state, here, target, reach + overshoot if piercing else 0, u)
			var far: int = maxi(state.setup.min_damage, (base * state.setup.pierce_overshoot_pct + 50) / 100)
			for i: int in path.size():
				var c: Vector2i = path[i]
				if not state.inside(c):
					break
				# Past its range a beam keeps going at reduced damage. (Not `pierce_left`: that
				# counts down with every unit the beam passes through.)
				var amount: int = far if piercing and i >= reach else base
				tiles.append(c)
				plan["end"] = c
				if state.tile_blocks(c.x, c.y):
					break
				if state.props.has(c):
					# Play-test 5: a piercing shot goes through a drum or a crate too (a drum
					# goes off), and the prop counts against its pierce like a machine.
					_add_prop(state, props, c, amount)
					if pierce_left <= 0:
						break
					pierce_left -= 1
					continue
				var occupant: GridUnit = state.unit_at(c.x, c.y)
				if occupant == null or occupant == u:
					continue
				_add_hit(state, u, hits, c, amount, hits.is_empty(), true)
				if pierce_left <= 0:
					break
				pierce_left -= 1
			if int(weapon["chain"]) > 0:
				_arc(state, u, hits, props, tiles, maxi(state.setup.min_damage, base - 1), int(weapon["chain"]))

	plan["legal"] = true
	plan["tiles"] = tiles
	plan["hits"] = hits
	plan["props"] = props
	return plan


## A coil arcs from the first thing it hits -- a machine or a prop -- into a neighbour,
## a point weaker, and on from there, `jumps` times (play-test 3 wanted terrain, play-test 4
## two enemies). Play-test 5: it takes the ROUTE that does the most. Every route is tried
## (`_arc_search`): an enemy is worth the damage it takes, a drum the blast on the enemies
## around it, a crate a little; the arc never jumps into its own side, and stops rather than
## waste a jump. **Scrap heaps conduct**: an arc runs through a heap (no damage, no jump) to
## whatever stands beyond it.
static func _arc(state: CombatState, u: GridUnit, hits: Array[Dictionary], props: Array[Dictionary],
		tiles: Array[Vector2i], amount: int, jumps: int) -> void:
	var origin := Vector2i(-1, -1)
	if not hits.is_empty():
		var first: GridUnit = state.unit(int(hits[0]["ref"]))
		origin = Vector2i(first.x, first.y)
	elif not props.is_empty():
		origin = props[0]["cell"]
	else:
		return
	var taken: Dictionary = {origin: true}
	for hit: Dictionary in hits:
		var t: GridUnit = state.unit(int(hit["ref"]))
		taken[Vector2i(t.x, t.y)] = true
	for p: Dictionary in props:
		taken[p["cell"]] = true
	var best: Dictionary = {"value": 0, "route": []}
	_arc_search(state, u, origin, jumps, amount, taken, [], 0, best)
	for cell: Vector2i in (best["route"] as Array):
		tiles.append(cell)
		if state.tile_blocks(cell.x, cell.y):
			continue   # a heap the arc ran through
		if state.props.has(cell):
			_add_prop(state, props, cell, amount)
		else:
			_add_hit(state, u, hits, cell, amount, false, false)


## Depth-first over every route the arc could take from `from`, keeping the best in `best`
## (highest value; on a tie the shorter route, then the one found first -- neighbours are
## visited in `Hex.neighbors` order, so the choice is always the same).
static func _arc_search(state: CombatState, u: GridUnit, from: Vector2i, jumps: int, amount: int,
		taken: Dictionary, route: Array, value: int, best: Dictionary) -> void:
	if value > int(best["value"]) or (value == int(best["value"]) and value > 0 and route.size() < (best["route"] as Array).size()):
		best["value"] = value
		best["route"] = route.duplicate()
	for n: Vector2i in Hex.neighbors(from):
		if not state.inside(n) or taken.has(n) or n == Vector2i(u.x, u.y):
			continue
		var step: int = 0
		var relay: bool = false
		var other: GridUnit = state.unit_at(n.x, n.y)
		if other != null:
			if other.team == u.team:
				continue   # never into its own side
			if jumps <= 0:
				continue
			var dmg: int = mini(damage_to(state, u, other, amount, false), other.hp)
			step = dmg * 10 + (ARC_KILL if dmg >= other.hp else 0)
		elif state.props.has(n):
			if jumps <= 0:
				continue
			step = _arc_prop_value(state, u, n) if String(state.props[n]["kind"]) == "barrel" else ARC_CRATE
		elif state.tile_blocks(n.x, n.y):
			relay = true
		else:
			continue
		taken[n] = true
		route.append(n)
		_arc_search(state, u, n, jumps if relay else jumps - 1, amount, taken, route, value + step, best)
		route.pop_back()
		taken.erase(n)


## What arcing into a drum is worth: its blast on every machine next to it (enemies for,
## the arc's own side hard against).
static func _arc_prop_value(state: CombatState, u: GridUnit, cell: Vector2i) -> int:
	var blast: int = state.setup.barrel_damage
	var value: int = 0
	for n: Vector2i in Hex.neighbors(cell):
		var other: GridUnit = state.unit_at(n.x, n.y) if state.inside(n) else null
		if other == null:
			continue
		var dmg: int = mini(blast, other.hp)
		if other.team == u.team:
			value -= dmg * 20 + (ARC_KILL * 3 if dmg >= other.hp else 0)
		else:
			value += dmg * 10 + (ARC_KILL if dmg >= other.hp else 0)
	return value


## The better of the two leanings of the hex line from `from` toward `to` (see `Hex.line`):
## the one that reaches `to` with nothing in the way, else the one that runs clear longer;
## the +1 leaning on a tie, so the choice is deterministic. `reach` > 0 extends it into a
## ray (piercing shots). `ignore` is the unit doing the looking.
##
## Play-test 4: with only one leaning, a shot between two equally short paths always took
## the same side -- into a scrap heap or an ally -- which read as the game cheating. Both
## teams go through here, so the preview, the AI and the shot itself always agree.
static func best_line(state: CombatState, from: Vector2i, to: Vector2i, reach: int = 0,
		ignore: GridUnit = null) -> Array[Vector2i]:
	var a: Array[Vector2i] = Hex.ray(from, to, reach, 1) if reach > 0 else Hex.line(from, to, 1)
	var b: Array[Vector2i] = Hex.ray(from, to, reach, -1) if reach > 0 else Hex.line(from, to, -1)
	if a == b:
		return a
	return b if _clear_run(state, b, to, ignore) > _clear_run(state, a, to, ignore) else a


## How far along `path` the way stays clear on its way to `to`: the index of the first thing
## standing in it (a blocking tile, a prop, a unit other than `ignore`), or 1000 when it
## reaches `to` untouched. Pits are no obstacle: shots fly over them.
static func _clear_run(state: CombatState, path: Array[Vector2i], to: Vector2i, ignore: GridUnit) -> int:
	for i: int in path.size():
		var c: Vector2i = path[i]
		if c == to:
			return 1000
		if not state.inside(c) or state.tile_blocks(c.x, c.y) or state.props.has(c):
			return i
		var occupant: GridUnit = state.unit_at(c.x, c.y)
		if occupant != null and occupant != ignore:
			return i
	return path.size()


static func _prop_struck(props: Array[Dictionary], cell: Vector2i) -> bool:
	for p: Dictionary in props:
		if p["cell"] == cell:
			return true
	return false


static func _add_prop(state: CombatState, props: Array[Dictionary], cell: Vector2i, amount: int) -> void:
	if amount > 0 and state.props.has(cell):
		props.append({"cell": cell, "damage": amount})


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
	dmg -= target.armor + target.shield + _warden_cover(state, target) + _pylon_cover(state, target)
	if target.marked:
		dmg += state.setup.mark_bonus
	return maxi(state.setup.min_damage, dmg)


## The Sorter (013) takes `pylon_armor` off every hit while any gate pylon stands.
static func _pylon_cover(state: CombatState, target: GridUnit) -> int:
	if target.kind != "sorter" or not has_pylon(state):
		return 0
	return int((state.setup.kinds.get("sorter", {}) as Dictionary).get("pylon_armor", 3))


static func has_pylon(state: CombatState) -> bool:
	for cell: Variant in state.props:
		if String((state.props[cell] as Dictionary).get("kind", "")) == "pylon":
			return true
	return false


## A warden takes damage off every hit on its neighbours (not on itself).
static func _warden_cover(state: CombatState, target: GridUnit) -> int:
	for n: Vector2i in Hex.neighbors(Vector2i(target.x, target.y)):
		if not state.inside(n):
			continue
		var other: GridUnit = state.unit_at(n.x, n.y)
		if other != null and other.team == target.team and other.kind == "warden":
			return int((state.setup.kinds.get("warden", {}) as Dictionary).get("armor", 2))
	return 0


## `strike_plan` plus what the player needs to decide: legality for the player, whether
## it overheats the shooter, and which targets it would kill or tear an arm off.
static func preview_attack(state: CombatState, ref: int, w: int, target: Vector2i) -> Dictionary:
	var u: GridUnit = state.unit(ref)
	if u == null or not u.alive:
		return {"legal": false}
	var plan: Dictionary = strike_plan(state, u, w, target)
	plan["legal"] = can_attack(state, ref, w, target)
	var weapon: Dictionary = u.weapons[w] if w >= 0 and w < u.weapons.size() else {}
	plan["overheats"] = not weapon.is_empty() and u.heat + attack_heat(u, weapon) >= u.heat_cap
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
	plan["effects"] = dry_run(state, [ACT_ATTACK, ref, w, target.x, target.y]) if bool(plan["legal"]) else []
	return plan


## Runs one player action on a COPY of the fight and reports what it changed, unit by unit:
## `[{ "ref", "hp_lost", "killed", "fell", "moved_to": Vector2i or null }]`, plus
## `{ "prop": Vector2i, "broken": bool }` for props that broke. With explosions, chains,
## pits and bombers, only the real rules can say what an attack does; this is them.
static func dry_run(state: CombatState, action: Array) -> Array:
	var copy: CombatState = state.clone()
	if not apply(copy, action):
		return []
	return diff(state, copy)


## What changed between two states of the same fight, in ref order.
static func diff(before: CombatState, after: CombatState) -> Array:
	var out: Array = []
	for u: GridUnit in after.units:
		var old: GridUnit = before.unit(u.ref)
		if old == null:
			out.append({"ref": u.ref, "hp_lost": 0, "killed": false, "fell": false, "moved_to": Vector2i(u.x, u.y), "spawned": true})
			continue
		if not old.alive:
			continue
		var lost: int = old.hp - (u.hp if u.alive else 0)
		var moved: bool = u.alive and (u.x != old.x or u.y != old.y)
		if lost == 0 and u.alive and not moved:
			continue
		out.append({"ref": u.ref, "hp_lost": maxi(0, lost), "killed": not u.alive,
			"fell": not u.alive and u.hp == 0 and after.is_pit(Vector2i(u.x, u.y)),
			"moved_to": Vector2i(u.x, u.y) if moved else null})
	var cells: Array = before.props.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell: Variant in cells:
		if not after.props.has(cell):
			out.append({"prop": cell, "broken": true})
	return out


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
		var target: Vector2i = intent_target(state, intent)
		var plan: Dictionary = strike_plan(state, u, int(intent["w"]), target)
		plan["w"] = int(intent["w"])
		plan["order"] = int(intent["order"])
		plan["lock"] = int(intent.get("lock", -1))
		out[u.ref] = plan
	return out


## Where an intent fires: its hex, or -- for a tracker -- wherever its locked machine
## stands now. A tracker's lock is broken only by that machine dying.
static func intent_target(state: CombatState, intent: Dictionary) -> Vector2i:
	var lock: int = int(intent.get("lock", -1))
	if lock >= 0:
		var locked: GridUnit = state.unit(lock)
		if locked != null and locked.alive:
			return Vector2i(locked.x, locked.y)
	return Vector2i(int(intent["x"]), int(intent["y"]))


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
			# A fight with its own, shorter limit says so (014: the gate closes).
			if state.setup.max_rounds < 20:
				var left: int = state.setup.max_rounds - state.round_number + 1
				status["text"] += "  ·  %d round%s left" % [left, "" if left == 1 else "s"]
				status["rounds_left"] = left
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
	collect_path(state, u, options[dest])
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
			hurt(state, u.ref, victim, dmg)
			if victim.alive and primary and _would_tear(state, victim, weapon, dmg):
				_tear(state, u.ref, victim)
		if victim.alive and primary and bool(weapon["mark"]):
			victim.marked = true
			state.emit(GridEv.MARKED, u.ref, victim.ref, victim.x, victim.y)
		if primary and int(weapon["shove"]) > 0:
			var dir: int = Hex.direction(origin, Vector2i(victim.x, victim.y))
			if victim.alive:
				shove(state, u.ref, victim, dir)
			else:
				throw_wreck(state, u.ref, victim, dir)
	for prop: Dictionary in (plan.get("props", []) as Array):
		damage_prop(state, u.ref, prop["cell"], int(prop["damage"]))
	u.boost_damage = 0
	# Heat is the PLAYER's resource. Enemies ignore it: an enemy that sometimes cannot
	# fire would be one more hidden state to read off the board every turn.
	if u.team == GridUnit.TEAM_PLAYER:
		u.heat += attack_heat(u, weapon)
		u.boost_heat = 0
		state.emit(GridEv.HEAT, u.ref, -1, u.x, u.y, u.heat, u.heat_cap)
		if u.heat >= u.heat_cap and not u.overheated:
			u.overheated = true
			state.emit(GridEv.OVERHEAT, u.ref, -1, u.x, u.y)


static func _would_tear(state: CombatState, target: GridUnit, weapon: Dictionary, dmg: int) -> bool:
	if target.objective or not target.has_weapon() or dmg <= 0:
		return false
	return dmg >= state.setup.tear_threshold or bool(weapon.get("tears", false))


## Damage, and on death a scrap pile where the machine stood. A cache just breaks.
static func hurt(state: CombatState, actor: int, target: GridUnit, dmg: int) -> void:
	target.hp = maxi(0, target.hp - dmg)
	state.emit(GridEv.DAMAGE, actor, target.ref, target.x, target.y, dmg, target.hp)
	if target.hp > 0:
		return
	target.alive = false
	state.emit(GridEv.DESTROYED, actor, target.ref, target.x, target.y)
	var cell := Vector2i(target.x, target.y)
	if not target.objective and target.carries_scrap:
		state.piles[cell] = int(state.piles.get(cell, 0)) + state.setup.pile_value
		state.emit(GridEv.PILE_DROPPED, actor, target.ref, cell.x, cell.y, state.setup.pile_value)
	if target.kind == "bomber":
		explode(state, target.ref, cell, int((state.setup.kinds.get("bomber", {}) as Dictionary).get("blast", 4)))


## Damage to every neighbour of `cell`: units take it straight (no armour), props take it
## and may break -- a barrel that breaks explodes in turn, which is how chains happen.
static func explode(state: CombatState, actor: int, cell: Vector2i, dmg: int) -> void:
	state.emit(GridEv.EXPLOSION, actor, -1, cell.x, cell.y, dmg)
	for n: Vector2i in Hex.neighbors(cell):
		if not state.inside(n):
			continue
		var victim: GridUnit = state.unit_at(n.x, n.y)
		if victim != null:
			hurt(state, actor, victim, dmg)
		damage_prop(state, actor, n, dmg)


static func damage_prop(state: CombatState, actor: int, cell: Vector2i, dmg: int) -> void:
	if not state.props.has(cell) or dmg <= 0:
		return
	var prop: Dictionary = state.props[cell]
	prop["hp"] = int(prop["hp"]) - dmg
	state.emit(GridEv.PROP_HIT, actor, -1, cell.x, cell.y, dmg, maxi(0, int(prop["hp"])))
	if int(prop["hp"]) > 0:
		return
	var barrel: bool = String(prop["kind"]) == "barrel"
	state.props.erase(cell)
	state.emit(GridEv.PROP_BROKEN, actor, -1, cell.x, cell.y, 1 if barrel else 0)
	if barrel:
		explode(state, actor, cell, state.setup.barrel_damage)


## Into a pit: gone, with no pile (it went down with its scrap).
static func fall(state: CombatState, actor: int, target: GridUnit, cell: Vector2i) -> void:
	target.x = cell.x
	target.y = cell.y
	target.hp = 0
	target.alive = false
	state.emit(GridEv.FELL, actor, target.ref, cell.x, cell.y)
	state.emit(GridEv.DESTROYED, actor, target.ref, cell.x, cell.y)


## Whoever ends a move on a scrap pile takes it: the player banks the scrap, and the
## machine patches itself. An enemy that gets there first carries it off.
static func collect(state: CombatState, u: GridUnit) -> void:
	collect_at(state, u, Vector2i(u.x, u.y))


## Every pile on the way is picked up, not only the one a move ends on (play-test 3:
## walking straight over scrap and leaving it there read as broken). Both teams.
static func collect_path(state: CombatState, u: GridUnit, path: Array) -> void:
	for cell: Variant in path:
		collect_at(state, u, cell)
	collect(state, u)


## Takes the pile at `cell` for `u` (Magnet reaches one without stepping on it).
static func collect_at(state: CombatState, u: GridUnit, cell: Vector2i) -> void:
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
static func shove(state: CombatState, actor: int, target: GridUnit, dir: int) -> void:
	if target.unshovable:
		return
	var n: Vector2i = Hex.neighbor(Vector2i(target.x, target.y), dir)
	var bump: int = state.setup.bump_damage
	if state.inside(n) and state.is_pit(n) and state.unit_at(n.x, n.y) == null:
		var start := Vector2i(target.x, target.y)
		state.emit(GridEv.SHOVED, actor, target.ref, n.x, n.y, start.x, start.y)
		fall(state, actor, target, n)
		return
	if not state.inside(n) or state.solid(n):
		state.emit(GridEv.BUMP, actor, target.ref, n.x, n.y, bump)
		hurt(state, actor, target, bump)
		damage_prop(state, actor, n, bump)
		return
	var occupant: GridUnit = state.unit_at(n.x, n.y)
	if occupant != null:
		state.emit(GridEv.BUMP, actor, target.ref, n.x, n.y, bump)
		hurt(state, actor, target, bump)
		if occupant.alive:
			hurt(state, actor, occupant, bump)
		return
	var from := Vector2i(target.x, target.y)
	target.x = n.x
	target.y = n.y
	state.emit(GridEv.SHOVED, actor, target.ref, n.x, n.y, from.x, from.y)


## A shove that kills still throws the wreck (play-test 5), one hex along the shove. Into
## anything solid it stops, and what it hits takes the bump: a machine takes it, a crate
## cracks, a drum goes off. Into a pit, the wreck and the scrap it carried are gone. Onto open
## ground it lands there, and its scrap pile goes with it.
static func throw_wreck(state: CombatState, actor: int, target: GridUnit, dir: int) -> void:
	if target.unshovable or target.objective:
		return
	var from := Vector2i(target.x, target.y)
	var n: Vector2i = Hex.neighbor(from, dir)
	var bump: int = state.setup.bump_damage
	var carried: int = mini(state.setup.pile_value if target.carries_scrap else 0, int(state.piles.get(from, 0)))
	var occupant: GridUnit = state.unit_at(n.x, n.y) if state.inside(n) else null
	var packed: int = from.y * 64 + from.x
	if not state.inside(n) or state.solid(n) or occupant != null:
		state.emit(GridEv.WRECK_THROWN, actor, target.ref, n.x, n.y, packed, 0)
		if occupant != null:
			hurt(state, actor, occupant, bump)
		else:
			damage_prop(state, actor, n, bump)
		return
	state.emit(GridEv.WRECK_THROWN, actor, target.ref, n.x, n.y, packed, 1)
	target.x = n.x
	target.y = n.y
	if carried > 0:
		var left: int = int(state.piles[from]) - carried
		if left > 0:
			state.piles[from] = left
		else:
			state.piles.erase(from)
		state.emit(GridEv.PILE_LOST, actor, target.ref, from.x, from.y, carried)
	if state.is_pit(n):
		state.emit(GridEv.FELL, actor, target.ref, n.x, n.y)
		return
	if carried > 0:
		state.piles[n] = int(state.piles.get(n, 0)) + carried
		state.emit(GridEv.PILE_DROPPED, actor, target.ref, n.x, n.y, carried)


static func _end_turn(state: CombatState) -> void:
	state.emit(GridEv.TURN_END)
	# Intents fire in their displayed order, from wherever each attacker stands now, at
	# the hex it chose. One that can no longer reach its hex (it was shoved) misses.
	for intent: Dictionary in state.intents:
		var u: GridUnit = state.unit(int(intent["ref"]))
		if u == null or not u.alive or not u.can_fire(int(intent["w"])):
			continue
		var target: Vector2i = intent_target(state, intent)
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
		u.boost_damage = 0
		u.boost_heat = 0
		if u.team == GridUnit.TEAM_PLAYER:
			u.shield = 0
		for ability: Dictionary in u.abilities:
			ability["wait"] = maxi(0, int(ability["wait"]) - 1)
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
			hurt(state, -1, u, state.hazard(u.x, u.y))
	if _check_outcome(state):
		return

	_hives(state)
	_reclaimer(state)

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
			collect_path(state, u, plan["path"])
		var w: int = int(plan["w"])
		if w >= 0:
			order += 1
			var target: Vector2i = plan["target"]
			var intent: Dictionary = {"ref": u.ref, "w": w, "x": target.x, "y": target.y, "order": order}
			# A tracker locks onto the machine on its target hex, not the hex.
			var locked: GridUnit = state.unit_at(target.x, target.y)
			if u.kind == "tracker" and locked != null and locked.team != u.team:
				intent["lock"] = locked.ref
			state.intents.append(intent)
			state.emit(GridEv.INTENT_SET, u.ref, int(intent.get("lock", -1)), target.x, target.y, w, order)


## Hives build on their marked hex, then mark the next one. A marked hex that anything
## stands on (or that became solid) blocks the build: that is the counterplay.
static func _hives(state: CombatState) -> void:
	# Play-test 4: the build site used to be re-marked next to the hive every other round,
	# then the hive walked off, so the site seemed to wander. Now a hive sets down ONE
	# fabricator pad and it stays put: every `every` rounds it builds a drone, the round
	# before it the pad warns, standing on it blocks the build, and it dies with its hive.
	# 013: any kind that `builds` has a pad (the hive, the Sorter), each at its own pace.
	var refs: Array = state.spawn_marks.keys()
	refs.sort()
	for ref: Variant in refs:
		var cell: Vector2i = state.spawn_marks[ref]
		var builder: GridUnit = state.unit(int(ref))
		if builder == null or not builder.alive or state.setup.drone == null:
			state.spawn_marks.erase(ref)
			state.spawn_due.erase(ref)
			state.emit(GridEv.SPAWN_BLOCKED, int(ref), -1, cell.x, cell.y, 1)
			continue
		if int(state.spawn_due.get(ref, 0)) != state.round_number:
			continue
		state.spawn_due[ref] = state.round_number + _build_every(state, builder.kind)
		if state.unit_at(cell.x, cell.y) != null or state.solid(cell) or state.is_pit(cell):
			state.emit(GridEv.SPAWN_BLOCKED, builder.ref, -1, cell.x, cell.y, 0)
			continue
		var drone: GridUnit = state.setup.drone.copy()
		var slot: int = 0
		for u: GridUnit in state.units:
			if u.team == GridUnit.TEAM_ENEMY:
				slot = maxi(slot, u.slot + 1)
		drone.slot = slot
		drone.ref = GridUnit.TEAM_ENEMY * 10 + slot
		drone.x = cell.x
		drone.y = cell.y
		state.units.append(drone)
		state.units.sort_custom(func(a: GridUnit, b: GridUnit) -> bool: return a.ref < b.ref)
		state.emit(GridEv.SPAWNED, builder.ref, drone.ref, cell.x, cell.y)
	for u: GridUnit in state.units:
		if not u.alive or not _builds(state, u.kind) or state.spawn_marks.has(u.ref):
			continue
		var every: int = _build_every(state, u.kind)
		var free: Array[Vector2i] = []
		for n: Vector2i in Hex.neighbors(Vector2i(u.x, u.y)):
			if state.inside(n) and not state.solid(n) and not state.is_pit(n) and state.unit_at(n.x, n.y) == null \
					and not state.spawn_marks.values().has(n):
				free.append(n)
		if free.is_empty():
			continue
		var pick: Vector2i = free[IntentAI.mix(state.setup.rng_seed, u.ref, state.round_number, 41) % free.size()]
		state.spawn_marks[u.ref] = pick
		state.spawn_due[u.ref] = state.round_number + every
		state.emit(GridEv.SPAWN_MARKED, u.ref, -1, pick.x, pick.y, every)


static func _builds(state: CombatState, kind: String) -> bool:
	return not kind.is_empty() and bool((state.setup.kinds.get(kind, {}) as Dictionary).get("builds", false))


static func _build_every(state: CombatState, kind: String) -> int:
	return maxi(1, int((state.setup.kinds.get(kind, {}) as Dictionary).get("every", 2)))


## The Reclaimer reaching into a fight fought near its line (013). The round before its
## drones arrive it marks where -- open hexes on the player's back row, chosen by a hash --
## and at `reclaimer_round` a drone comes in on each marked hex nothing stands on.
static func _reclaimer(state: CombatState) -> void:
	var setup: CombatSetup = state.setup
	if setup.reclaimer_round <= 0 or setup.reclaimer_drone == null:
		return
	if state.round_number == setup.reclaimer_round - 1 and state.arrivals.is_empty():
		var row: int = state.height - 1
		var open: Array[Vector2i] = []
		for x: int in state.width:
			var cell := Vector2i(x, row)
			if not state.solid(cell) and not state.is_pit(cell):
				open.append(cell)
		open.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var ha: int = IntentAI.mix(setup.rng_seed, a.x, a.y, 61)
			var hb: int = IntentAI.mix(setup.rng_seed, b.x, b.y, 61)
			return ha < hb or (ha == hb and a.x < b.x))
		for i: int in mini(setup.reclaimer_count, open.size()):
			state.arrivals.append(open[i])
			state.emit(GridEv.ARRIVAL_MARKED, -1, -1, open[i].x, open[i].y, 1)
	elif state.round_number == setup.reclaimer_round and not state.arrivals.is_empty():
		for cell: Vector2i in state.arrivals:
			if state.unit_at(cell.x, cell.y) != null or state.solid(cell):
				state.emit(GridEv.SPAWN_BLOCKED, -1, -1, cell.x, cell.y, 0)
				continue
			var drone: GridUnit = setup.reclaimer_drone.copy()
			var slot: int = 0
			for u: GridUnit in state.units:
				if u.team == GridUnit.TEAM_ENEMY:
					slot = maxi(slot, u.slot + 1)
			drone.slot = slot
			drone.ref = GridUnit.TEAM_ENEMY * 10 + slot
			drone.x = cell.x
			drone.y = cell.y
			state.units.append(drone)
			state.units.sort_custom(func(a: GridUnit, b: GridUnit) -> bool: return a.ref < b.ref)
			state.emit(GridEv.SPAWNED, -1, drone.ref, cell.x, cell.y)
		state.arrivals.clear()


## Rounds until hive `ref`'s pad builds its next drone (1 = at the start of next round), or
## -1 if it has no pad. What the pad's countdown shows.
static func drone_in(state: CombatState, ref: int) -> int:
	if not state.spawn_due.has(ref):
		return -1
	return int(state.spawn_due[ref]) - state.round_number


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
