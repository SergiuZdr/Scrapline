extends SceneTree

## Combat on the hex board: geometry, every rule, objectives, piles, determinism, undo,
## and whole fights played by bot.
##
##   godot --headless --path . --script res://tools/verify_combat.gd
##
## Positions are derived with `Hex` (a neighbour, an off-axis hex, the hex a line passes
## through) rather than typed as coordinates. Hand-worked odd-r coordinates are exactly the
## kind of number a test gets wrong and then "passes" against.
##
## Loadouts use `co_dynamo` (kinetic, no bonuses, vent 2) and `mo_scavenger` (+2 HP) so
## the damage can be worked out by hand: kinetic is 100% vs plate, 130% vs composite and
## 70% vs reactive.

const HAMMER: Array = ["ch_brute", "co_dynamo", "ar_saw", "ar_hammer", "mo_scavenger"]     # brawler, plate
const LANCE: Array = ["ch_hauler", "co_dynamo", "ar_scanner", "ar_lance", "mo_scavenger"]  # line role, composite
const RAIL: Array = ["ch_lancer", "co_dynamo", "ar_scanner", "ar_railgun", "mo_scavenger"]  # marksman, plate
const MORTAR: Array = ["ch_bulwark", "co_dynamo", "ar_mortar", "ar_hammer", "mo_scavenger"] # anchor, reactive
const COIL: Array = ["ch_hauler", "co_dynamo", "ar_pulse", "ar_scatter", "mo_scavenger"]
const DASHER: Array = ["ch_skirmisher", "co_dynamo", "ar_saw", "ar_hammer", "mo_coolant"]   # abilities: dash, flush
const GUARD: Array = ["ch_brute", "co_dynamo", "ar_saw", "ar_hammer", "mo_reactive"]       # abilities: charge, shield
const SIZE: int = 9
const C := Vector2i(4, 4)

var _db: ContentDB
var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_db = ContentDB.load_all()
	print("")
	print("=== combat on hexes ===")
	_test_hex_geometry()
	_test_fights_build()
	_test_stats_come_from_parts()
	_test_movement()
	_test_free_aim()
	_test_melee_all_neighbours()
	_test_pierce()
	_test_lob()
	_test_damage_wheel_and_cover()
	_test_shove_and_bump()
	_test_mark()
	_test_heat()
	_test_tearing()
	_test_slag()
	_test_intents_target_hexes()
	_test_piles()
	_test_objectives()
	_test_barrels_and_props()
	_test_pits()
	_test_abilities()
	_test_enemy_kinds()
	_test_dry_run_matches()
	for id: String in ["proto_yard", "slag_pit", "container_row"]:
		_test_bot_fight(id)
	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	print("")
	quit(1 if _failed > 0 else 0)


# --- Fixtures ---------------------------------------------------------------

func _rows(marks: Dictionary = {}) -> Array:
	var rows: Array = []
	for y: int in SIZE:
		var row: String = ""
		for x: int in SIZE:
			row += String(marks.get(Vector2i(x, y), "."))
		rows.append(row)
	return rows


func _fight(rows: Array, players: Array, enemies: Array, objective: Dictionary = {}) -> CombatState:
	var fight: Dictionary = {"id": "test", "rows": rows, "player": players, "enemy": enemies}
	if not objective.is_empty():
		fight["objective"] = objective
	var setup: CombatSetup = CombatSetup.build(fight, _db.combat_rules, _db.parts, _db.tiles, _db.balance.effectiveness, 1)
	if not setup.errors.is_empty():
		_check("test setup has no errors %s" % [setup.errors], false)
	var state: CombatState = CombatSim.start(setup)
	state.intents.clear()
	return state


func _unit(parts: Array, cell: Vector2i, hp: int = -1) -> Dictionary:
	var spec: Dictionary = {"parts": parts, "x": cell.x, "y": cell.y}
	if hp > 0:
		spec["hp"] = hp
	return spec


func _place(state: CombatState, ref: int, cell: Vector2i) -> void:
	var u: GridUnit = state.unit(ref)
	u.x = cell.x
	u.y = cell.y


## A hex at cube offset (dq, ds, dr) from `c`.
func _off(c: Vector2i, dq: int, ds: int, dr: int) -> Vector2i:
	return Hex.from_cube(Hex.to_cube(c) + Vector3i(dq, ds, dr))


func _count(state: CombatState, since: int, kind: int) -> int:
	var n: int = 0
	for i: int in range(since, state.events.size()):
		if int(state.events[i][GridEv.F_KIND]) == kind:
			n += 1
	return n


func _attack(state: CombatState, ref: int, w: int, target: Vector2i) -> bool:
	return CombatSim.apply(state, [CombatSim.ACT_ATTACK, ref, w, target.x, target.y])


func _at(state: CombatState, ref: int) -> Vector2i:
	return Vector2i(state.unit(ref).x, state.unit(ref).y)


# --- Geometry ---------------------------------------------------------------

func _test_hex_geometry() -> void:
	var ring: Array[Vector2i] = Hex.neighbors(C)
	var unique: Dictionary = {}
	var all_one: bool = true
	for n: Vector2i in ring:
		unique[n] = true
		all_one = all_one and Hex.distance(C, n) == 1
	_check("six distinct neighbours, all at distance 1", unique.size() == 6 and all_one)
	var odd := Vector2i(3, 3)
	_check("an odd row's hex also has six neighbours at distance 1",
		Hex.neighbors(odd).all(func(n: Vector2i) -> bool: return Hex.distance(odd, n) == 1))
	_check("offset -> cube -> offset round-trips", Hex.from_cube(Hex.to_cube(Vector2i(5, 3))) == Vector2i(5, 3))
	_check("a radius-2 area holds 18 hexes", Hex.within(C, 2).size() == 18)
	var off_axis: Vector2i = _off(C, 2, -1, -1)
	var line: Array[Vector2i] = Hex.line(C, off_axis)
	_check("a line has one hex per step and ends on its target", line.size() == 2 and line[-1] == off_axis)
	_check("each step of a line is adjacent to the last", Hex.distance(C, line[0]) == 1 and Hex.distance(line[0], line[1]) == 1)
	var ray: Array[Vector2i] = Hex.ray(C, Hex.neighbor(C, 0), 4)
	_check("a ray carries on past its target to full reach", ray.size() == 4 and Hex.distance(C, ray[-1]) == 4)
	_check("direction toward a neighbour is that neighbour's direction", Hex.neighbor(C, Hex.direction(C, ring[2])) == ring[2])


# --- Setup ------------------------------------------------------------------

func _test_fights_build() -> void:
	for id: String in ["proto_yard", "slag_pit", "container_row"]:
		var fight: Dictionary = _db.fights.get(id, {})
		var setup: CombatSetup = CombatSetup.build(fight, _db.combat_rules, _db.parts, _db.tiles, _db.balance.effectiveness, 7)
		_check("%s builds with no errors %s" % [id, setup.errors], not fight.is_empty() and setup.errors.is_empty())
	var defend: CombatSetup = CombatSetup.build(_db.fights["container_row"], _db.combat_rules, _db.parts, _db.tiles, _db.balance.effectiveness, 7)
	var cache_refs: Array = []
	for u: GridUnit in defend.units:
		if u.objective:
			cache_refs.append(u.ref)
	_check("a defend fight places its caches after the crew (refs 3, 4)", cache_refs == [3, 4])
	var salvage: CombatSetup = CombatSetup.build(_db.fights["slag_pit"], _db.combat_rules, _db.parts, _db.tiles, _db.balance.effectiveness, 7)
	_check("a salvage fight starts with scrap piles", salvage.start_piles.size() == 4)


func _test_stats_come_from_parts() -> void:
	var state: CombatState = _fight(_rows(), [_unit(HAMMER, C), _unit(RAIL, Vector2i(0, 8))], [_unit(HAMMER, Vector2i(0, 0))])
	var brute: GridUnit = state.unit(0)
	_check("HP = chassis + module (11 + 2)", brute.max_hp == 13)
	_check("brawler +1 melee, marksman +1 range", brute.melee_bonus == 1 and state.unit(1).range_bonus == 1)
	var carried: CombatState = _fight(_rows(), [{"parts": HAMMER, "x": C.x, "y": C.y, "hp_now": 5}], [_unit(HAMMER, Vector2i(0, 0))])
	_check("a machine can enter a fight damaged (HP carried from the run)", carried.unit(0).hp == 5 and carried.unit(0).max_hp == 13)


# --- Movement ---------------------------------------------------------------

func _test_movement() -> void:
	var ring: Array[Vector2i] = Hex.neighbors(C)
	var state: CombatState = _fight(_rows({ring[0]: "s", ring[1]: "r"}), [_unit(HAMMER, C)], [_unit(HAMMER, Vector2i(0, 0))])
	_place(state, 0, C)
	_place(state, 10, Vector2i(0, 0))
	var reach: Dictionary = CombatSim.reachable(state, 0)
	_check("every open neighbour is in reach", ring.slice(2).all(func(n: Vector2i) -> bool: return reach.has(n)))
	_check("a scrap heap cannot be entered", not reach.has(ring[0]))
	_check("rubble is enterable (costs 2 of a 3 move)", reach.has(ring[1]))
	_check("a legal move is accepted", CombatSim.apply(state, [CombatSim.ACT_MOVE, 0, ring[3].x, ring[3].y]))
	_check("cannot move twice", not CombatSim.apply(state, [CombatSim.ACT_MOVE, 0, ring[4].x, ring[4].y]))


# --- Aim --------------------------------------------------------------------

func _test_free_aim() -> void:
	# The play-test complaint: a target off the straight lines could not be hit at all.
	var off_axis: Vector2i = _off(C, 2, -1, -1)
	var state: CombatState = _fight(_rows(), [_unit(LANCE, C)], [_unit(HAMMER, off_axis, 20)])
	_place(state, 0, C)
	_place(state, 10, off_axis)
	_check("a shot can target an off-axis hex", CombatSim.can_attack(state, 0, 1, off_axis))
	_attack(state, 0, 1, off_axis)
	_check("and it hits (lance 3 kinetic vs plate)", state.unit(10).hp == 17)

	var between: Vector2i = Hex.line(C, off_axis)[0]
	var blocked: CombatState = _fight(_rows({between: "s"}), [_unit(LANCE, C)], [_unit(HAMMER, off_axis, 20)])
	_place(blocked, 0, C)
	_place(blocked, 10, off_axis)
	var plan: Dictionary = CombatSim.preview_attack(blocked, 0, 1, off_axis)
	_check("a scrap heap on the line blocks the shot", (plan["hits"] as Array).is_empty() and plan["end"] == between)

	var coil: CombatState = _fight(_rows(), [_unit(COIL, C)], [_unit(HAMMER, between, 20), _unit(HAMMER, off_axis, 20)])
	_place(coil, 0, C)
	_place(coil, 10, between)
	_place(coil, 11, off_axis)
	var hits: Array = CombatSim.strike_plan(coil, coil.unit(0), 1, off_axis)["hits"]
	_check("a shot stops at the first unit on its line", hits.size() == 1 and int(hits[0]["ref"]) == 10)
	_check("out of reach is not a legal aim", not CombatSim.can_attack(state, 0, 1, _off(C, 4, -2, -2)))


func _test_melee_all_neighbours() -> void:
	var ok: bool = true
	for n: Vector2i in Hex.neighbors(C):
		var state: CombatState = _fight(_rows(), [_unit(HAMMER, C)], [_unit(HAMMER, n, 20)])
		_place(state, 0, C)
		_place(state, 10, n)
		ok = ok and CombatSim.can_attack(state, 0, 0, n)
	_check("melee reaches all six neighbours", ok)


func _test_pierce() -> void:
	var a: Vector2i = Hex.neighbor(C, 0)
	var b: Vector2i = Hex.neighbor(a, 0)
	var c: Vector2i = Hex.neighbor(b, 0)
	var state: CombatState = _fight(_rows(), [_unit(LANCE, C), _unit(RAIL, Vector2i(0, 8))],
		[_unit(HAMMER, a, 20), _unit(HAMMER, b, 20), _unit(HAMMER, c, 20)])
	_place(state, 0, C)
	_place(state, 10, a)
	_place(state, 11, b)
	_place(state, 12, c)
	_check("lance (pierce 1) hits the first two in line", (CombatSim.strike_plan(state, state.unit(0), 1, a)["hits"] as Array).size() == 2)
	_place(state, 0, Vector2i(0, 8))
	_place(state, 1, C)
	_check("railgun beams through every unit to full reach", (CombatSim.strike_plan(state, state.unit(1), 1, a)["hits"] as Array).size() == 3)


func _test_lob() -> void:
	var far: Vector2i = _off(C, 3, -2, -1)
	var near: Vector2i = Hex.neighbor(C, 3)
	var splash_victim: Vector2i = Hex.neighbor(far, 0)
	var state: CombatState = _fight(_rows({Hex.line(C, far)[0]: "s"}), [_unit(MORTAR, C)],
		[_unit(HAMMER, far, 20), _unit(HAMMER, splash_victim, 20)])
	_place(state, 0, C)
	_place(state, 10, far)
	_place(state, 11, splash_victim)
	_check("a lob cannot land closer than its minimum", not CombatSim.can_attack(state, 0, 0, near))
	_check("a lob flies over scrap to its hex", CombatSim.can_attack(state, 0, 0, far))
	_attack(state, 0, 0, far)
	_check("centre takes 3, a neighbour takes the splash 1", state.unit(10).hp == 17 and state.unit(11).hp == 19)


func _test_damage_wheel_and_cover() -> void:
	var r: Vector2i = Hex.neighbor(C, 1)
	var state: CombatState = _fight(_rows({r: "r"}), [_unit(HAMMER, C)],
		[_unit(LANCE, Vector2i(0, 0), 20), _unit(MORTAR, Vector2i(8, 0), 20), _unit(HAMMER, r, 20)])
	var brute: GridUnit = state.unit(0)
	_check("kinetic beats composite (4 -> 5)", CombatSim.damage_to(state, brute, state.unit(10), 4, false) == 5)
	_check("kinetic is blunted by reactive (4 -> 3)", CombatSim.damage_to(state, brute, state.unit(11), 4, false) == 3)
	_place(state, 12, r)
	_check("rubble takes 1 off a shot", CombatSim.damage_to(state, brute, state.unit(12), 3, true) == 2)
	_check("but not off a blow", CombatSim.damage_to(state, brute, state.unit(12), 3, false) == 3)


func _test_shove_and_bump() -> void:
	var n: Vector2i = Hex.neighbor(C, 0)
	var state: CombatState = _fight(_rows(), [_unit(HAMMER, C)], [_unit(HAMMER, n, 20)])
	_place(state, 0, C)
	_place(state, 10, n)
	_attack(state, 0, 1, n)
	_check("a hammer shoves one hex straight back", _at(state, 10) == Hex.neighbor(n, 0))
	var edge := Vector2i(SIZE - 2, 4)
	var wall: Vector2i = Hex.neighbor(edge, 0)
	var bumped: CombatState = _fight(_rows(), [_unit(HAMMER, edge)], [_unit(HAMMER, wall, 20)])
	_place(bumped, 0, edge)
	_place(bumped, 10, wall)
	_attack(bumped, 0, 1, wall)
	_check("shoved off the board edge: no move, 1 bump on top", _at(bumped, 10) == wall and bumped.unit(10).hp == 20 - 4 - 1)


func _test_mark() -> void:
	var n: Vector2i = Hex.neighbor(C, 0)
	var spotter: Vector2i = Hex.neighbor(n, 0)
	var state: CombatState = _fight(_rows(), [_unit(LANCE, spotter), _unit(HAMMER, C)], [_unit(HAMMER, n, 20)])
	_place(state, 0, spotter)
	_place(state, 1, C)
	_place(state, 10, n)
	_attack(state, 0, 0, n)
	_check("the scanner chips 1 and marks", state.unit(10).marked and state.unit(10).hp == 19)
	_attack(state, 1, 0, n)
	_check("a marked target takes +2 (saw 5 + 2) and the mark clears", state.unit(10).hp == 12 and not state.unit(10).marked)


func _test_heat() -> void:
	var n: Vector2i = _off(C, 2, -1, -1)
	var state: CombatState = _fight(_rows(), [_unit(RAIL, C), _unit(LANCE, Vector2i(0, 8))], [_unit(HAMMER, n, 40)])
	_place(state, 0, C)
	_place(state, 10, n)
	var rail: GridUnit = state.unit(0)
	rail.heat = 3
	_check("preview warns the shot will overheat", bool(CombatSim.preview_attack(state, 0, 1, n)["overheats"]))
	_attack(state, 0, 1, n)
	_check("reaching the cap overheats", rail.overheated)
	CombatSim.apply(state, [CombatSim.ACT_END, -1, 0, 0])
	state.intents.clear()
	rail = state.unit(0)
	_check("next round it is seized, heat reset, no attacks", rail.seized and rail.heat == 0 and not CombatSim.can_attack(state, 0, 1, _at(state, 10)))
	state.unit(1).heat = 3
	_check("VENT clears heat and uses the action", CombatSim.apply(state, [CombatSim.ACT_VENT, 1, 0, 0]) and state.unit(1).heat == 0)


func _test_tearing() -> void:
	var n: Vector2i = Hex.neighbor(C, 0)
	var state: CombatState = _fight(_rows(), [_unit(HAMMER, C)], [_unit(LANCE, n, 40)])
	_place(state, 0, C)
	_place(state, 10, n)
	_check("preview says the saw will tear an arm", (CombatSim.preview_attack(state, 0, 0, n)["tears"] as Array).has(10))
	_attack(state, 0, 0, n)
	_check("the right arm goes first", bool(state.unit(10).weapons[GridUnit.ARM_R]["torn"]) and not bool(state.unit(10).weapons[GridUnit.ARM_L]["torn"]))


func _test_slag() -> void:
	var state: CombatState = _fight(_rows({C: "l"}), [_unit(HAMMER, C)], [_unit(HAMMER, Vector2i(0, 0), 20)])
	_place(state, 0, C)
	var before: int = state.unit(0).hp
	CombatSim.apply(state, [CombatSim.ACT_END, -1, 0, 0])
	_check("a machine on slag at round start takes 1", state.unit(0).hp == before - 1)


# --- Intents ----------------------------------------------------------------

func _test_intents_target_hexes() -> void:
	var target: Vector2i = _off(C, 3, -2, -1)
	var state: CombatState = _fight(_rows(), [_unit(HAMMER, target)], [_unit(LANCE, C, 20)])
	_place(state, 0, target)
	_place(state, 10, C)
	state.intents = [{"ref": 10, "w": 1, "x": target.x, "y": target.y, "order": 1}]
	_check("the intent lands on the machine on its hex", int(CombatSim.threats(state)[10]["hits"][0]["ref"]) == 0)
	var step: Vector2i = Vector2i(-1, -1)
	for n: Vector2i in Hex.neighbors(target):
		if state.inside(n) and not Hex.line(C, target).has(n) and Hex.distance(C, n) > Hex.distance(C, target):
			step = n
			break
	CombatSim.apply(state, [CombatSim.ACT_MOVE, 0, step.x, step.y])
	var hp: int = state.unit(0).hp
	CombatSim.apply(state, [CombatSim.ACT_END, -1, 0, 0])
	_check("stepping off the targeted hex dodges it", state.unit(0).hp == hp)

	# Shoving a brawler away makes its blow hit air.
	var mine: Vector2i = Hex.neighbor(C, 3)
	var shove: CombatState = _fight(_rows(), [_unit(HAMMER, mine)], [_unit(HAMMER, C, 20)])
	_place(shove, 0, mine)
	_place(shove, 10, C)
	shove.intents = [{"ref": 10, "w": 0, "x": mine.x, "y": mine.y, "order": 1}]
	_attack(shove, 0, 1, C)
	_check("after the shove the blow is out of reach", not bool(CombatSim.threats(shove)[10]["legal"]))
	var hp2: int = shove.unit(0).hp
	var before: int = shove.events.size()
	CombatSim.apply(shove, [CombatSim.ACT_END, -1, 0, 0])
	_check("and at the end of the turn it misses", shove.unit(0).hp == hp2 and _count(shove, before, GridEv.MISSED) >= 1)


# --- Piles and objectives -----------------------------------------------------

func _test_piles() -> void:
	var n: Vector2i = Hex.neighbor(C, 0)
	var state: CombatState = _fight(_rows(), [_unit(HAMMER, C)], [_unit(HAMMER, n, 4), _unit(HAMMER, Vector2i(0, 0), 30)])
	_place(state, 0, C)
	_place(state, 10, n)
	_place(state, 11, Vector2i(0, 0))
	_attack(state, 0, 1, n)
	_check("a destroyed machine leaves a scrap pile on its hex", not state.unit(10).alive and state.piles.has(n))
	_check("and no longer blocks it", state.unit_at(n.x, n.y) == null)

	var walk: CombatState = _fight(_rows(), [_unit(HAMMER, C)], [_unit(HAMMER, Vector2i(0, 0), 30)],
		{"type": "rout", "piles": [{"x": n.x, "y": n.y}]})
	_place(walk, 0, C)
	walk.unit(0).hp = 8
	CombatSim.apply(walk, [CombatSim.ACT_MOVE, 0, n.x, n.y])
	_check("ending a move on a pile collects its scrap and patches 2 HP",
		walk.scrap_collected == 4 and walk.unit(0).hp == 10 and not walk.piles.has(n))

	var grab: CombatState = _fight(_rows(), [_unit(HAMMER, Vector2i(0, 8))], [_unit(HAMMER, C, 20)],
		{"type": "salvage", "need": 2, "piles": [{"x": n.x, "y": n.y}, {"x": 8, "y": 8}]})
	_check("on a salvage fight an enemy grabs a pile in reach", not grab.piles.has(n))


func _test_objectives() -> void:
	var cache := Vector2i(4, 8)
	var defend: CombatState = _fight(_rows(), [_unit(HAMMER, Vector2i(0, 8))], [_unit(RAIL, Vector2i(4, 2), 30)],
		{"type": "defend", "rounds": 2, "caches": [{"x": cache.x, "y": cache.y, "hp": 1}]})
	_place(defend, 10, Vector2i(4, 2))
	defend.intents = [{"ref": 10, "w": 1, "x": cache.x, "y": cache.y, "order": 1}]
	CombatSim.apply(defend, [CombatSim.ACT_END, -1, 0, 0])
	_check("defend: losing every cache loses the fight", defend.outcome == CombatState.LOST)

	var hold: CombatState = _fight(_rows(), [_unit(HAMMER, Vector2i(0, 8))], [_unit(HAMMER, Vector2i(8, 0), 30)],
		{"type": "defend", "rounds": 2, "caches": [{"x": 8, "y": 8, "hp": 30}]})
	for i: int in 2:
		if hold.outcome == CombatState.ONGOING:
			hold.intents.clear()
			CombatSim.apply(hold, [CombatSim.ACT_END, -1, 0, 0])
	_check("defend: holding for the rounds wins", hold.outcome == CombatState.WON)

	var n: Vector2i = Hex.neighbor(C, 0)
	var salvage: CombatState = _fight(_rows(), [_unit(HAMMER, C)], [_unit(HAMMER, Vector2i(0, 0), 30)],
		{"type": "salvage", "need": 1, "piles": [{"x": n.x, "y": n.y}]})
	_place(salvage, 0, C)
	var had: bool = salvage.piles.has(n)
	CombatSim.apply(salvage, [CombatSim.ACT_MOVE, 0, n.x, n.y])
	_check("salvage: collecting the piles needed wins", not had or salvage.outcome == CombatState.WON)
	_check("the objective has a line of text for the HUD", String(CombatSim.objective_status(salvage)["text"]).begins_with("SALVAGE"))


# --- 006: terrain, abilities, enemy kinds -------------------------------------

func _ability(state: CombatState, ref: int, i: int, cell: Vector2i = Vector2i.ZERO) -> bool:
	return CombatSim.apply(state, [CombatSim.ACT_ABILITY, ref, i, cell.x, cell.y])


func _test_barrels_and_props() -> void:
	var barrel: Vector2i = Hex.neighbor(C, 0)
	var second: Vector2i = Hex.neighbor(barrel, 0)
	var victim: Vector2i = Hex.neighbor(second, 1)
	var shooter: Vector2i = Hex.neighbor(C, 3)
	var state: CombatState = _fight(_rows({barrel: "b", second: "b"}), [_unit(LANCE, shooter)], [_unit(HAMMER, victim, 20), _unit(HAMMER, Vector2i(0, 0), 20)])
	_place(state, 0, shooter)
	_place(state, 10, victim)
	_place(state, 11, Vector2i(0, 0))
	_check("a barrel starts on the board as a prop", state.props.has(barrel) and state.props.has(second))
	_check("a prop cannot be walked into", not CombatSim.reachable(state, 0).has(barrel))
	var preview: Dictionary = CombatSim.preview_attack(state, 0, 1, barrel)
	_check("the preview (a dry run) sees the chain reach the unit beyond", preview["effects"].any(func(e: Dictionary) -> bool: return e.has("ref") and int(e["ref"]) == 10))
	_attack(state, 0, 1, barrel)
	_check("shooting a barrel breaks it, and it sets off the next one", not state.props.has(barrel) and not state.props.has(second))
	_check("the chain's blast hits the unit next to the second barrel (3)", state.unit(10).hp == 17)

	var wall: Vector2i = Hex.neighbor(C, 0)
	var behind: Vector2i = Hex.neighbor(wall, 0)
	var crate: CombatState = _fight(_rows({wall: "c"}), [_unit(LANCE, C)], [_unit(HAMMER, behind, 20)])
	_place(crate, 0, C)
	_place(crate, 10, behind)
	_attack(crate, 0, 1, behind)
	_check("a crate wall stops a shot and takes the damage (3 -> 0 HP, broken)", crate.unit(10).hp == 20 and not crate.props.has(wall))


func _test_pits() -> void:
	var pit: Vector2i = Hex.neighbor(Hex.neighbor(C, 0), 0)
	var enemy: Vector2i = Hex.neighbor(C, 0)
	var state: CombatState = _fight(_rows({pit: "o"}), [_unit(HAMMER, C)], [_unit(HAMMER, enemy, 20), _unit(HAMMER, Vector2i(0, 0), 20)])
	_place(state, 0, C)
	_place(state, 10, enemy)
	_place(state, 11, Vector2i(0, 0))
	_check("a pit cannot be walked into", not CombatSim.paths_from(state, state.unit(0), 5).has(pit))
	_attack(state, 0, 1, enemy)
	_check("shoved into a pit: gone", not state.unit(10).alive)
	_check("and it leaves no scrap pile (it went down with its scrap)", not state.piles.has(pit) and not state.piles.has(enemy))
	var over: CombatState = _fight(_rows({enemy: "o"}), [_unit(LANCE, C)], [_unit(HAMMER, pit, 20)])
	_place(over, 0, C)
	_place(over, 10, pit)
	_attack(over, 0, 1, pit)
	_check("shots pass over a pit", over.unit(10).hp < 20)


func _test_abilities() -> void:
	var brute: CombatState = _fight(_rows(), [_unit(HAMMER, C)], [_unit(HAMMER, _off(C, 3, -3, 0), 20), _unit(HAMMER, Vector2i(0, 0), 20)])
	var target: Vector2i = _off(C, 3, -3, 0)
	_place(brute, 0, C)
	_place(brute, 10, target)
	_place(brute, 11, Vector2i(0, 0))
	_check("a brawler frame gives Charge, a Scavenger module gives Magnet",
		String(brute.unit(0).abilities[0]["id"]) == "charge" and String(brute.unit(0).abilities[1]["id"]) == "magnet")
	_check("charge can aim down a straight hex line", CombatAbilities.targets(brute, brute.unit(0), 0).has(target))
	_check("charge runs up to the enemy, hits for 3 and shoves it", _ability(brute, 0, 0, target)
		and Hex.distance(_at(brute, 0), target) == 1 and brute.unit(10).hp == 17 and _at(brute, 10) != target)
	_check("charge uses the action", brute.unit(0).acted)
	_check("and then waits its cooldown", not brute.unit(0).ability_ready(0))

	var far: Vector2i = _off(C, 3, -3, 0)
	var pit: Vector2i = _off(C, 2, -2, 0)
	var hook: CombatState = _fight(_rows({pit: "o"}), [_unit(LANCE, C)], [_unit(HAMMER, far, 20)])
	_place(hook, 0, C)
	_place(hook, 10, far)
	_check("grapple drags across a pit, and the victim falls in", _ability(hook, 0, 0, far) and not hook.unit(10).alive)
	var pull: CombatState = _fight(_rows(), [_unit(LANCE, C)], [_unit(HAMMER, far, 20)])
	_place(pull, 0, C)
	_place(pull, 10, far)
	_ability(pull, 0, 0, far)
	_check("grapple pulls a unit until it is adjacent", Hex.distance(_at(pull, 10), C) == 1)

	var wall_at: Vector2i = Hex.neighbor(C, 0)
	var shooter_at: Vector2i = Hex.neighbor(wall_at, 0)
	var fort: CombatState = _fight(_rows(), [_unit(MORTAR, C)], [_unit(LANCE, Hex.neighbor(shooter_at, 0), 20)])
	_place(fort, 0, C)
	_place(fort, 10, Hex.neighbor(shooter_at, 0))
	_check("an anchor frame drops a barricade on a neighbouring hex", _ability(fort, 0, 0, wall_at) and fort.props.has(wall_at))

	var dash: CombatState = _fight(_rows(), [_unit(DASHER, C)], [_unit(HAMMER, Hex.neighbor(C, 0), 20)])
	_place(dash, 0, C)
	_place(dash, 10, Hex.neighbor(C, 0))
	_attack(dash, 0, 0, Hex.neighbor(C, 0))
	var away: Vector2i = _off(C, -2, 1, 1)
	_check("dash moves again after attacking, for free", _ability(dash, 0, 0, away) and _at(dash, 0) == away)
	dash.unit(0).heat = 3
	_check("flush dumps heat for free", _ability(dash, 0, 1) and dash.unit(0).heat == 0)

	var aim: CombatState = _fight(_rows(), [_unit(RAIL, C)], [_unit(HAMMER, _off(C, 2, -1, -1), 30)])
	_place(aim, 0, C)
	_place(aim, 10, _off(C, 2, -1, -1))
	_check("focus is free and adds +2 to the next attack", _ability(aim, 0, 0) and not aim.unit(0).acted)
	_attack(aim, 0, 1, _off(C, 2, -1, -1))
	_check("rail 3 + focus 2 = 5", aim.unit(10).hp == 25)

	var mate: Vector2i = Hex.neighbor(C, 3)
	var shield: CombatState = _fight(_rows(), [_unit(GUARD, C), _unit(HAMMER, mate)], [_unit(HAMMER, Vector2i(0, 0), 20)])
	_place(shield, 0, C)
	_place(shield, 1, mate)
	_ability(shield, 0, 1)
	_check("shield covers this machine and its neighbours", shield.unit(0).shield == 2 and shield.unit(1).shield == 2)
	_check("a shielded machine takes 2 less", CombatSim.damage_to(shield, shield.unit(10), shield.unit(1), 4, false) == 2)

	var pile: Vector2i = _off(C, 2, -1, -1)
	var mag: CombatState = _fight(_rows(), [_unit(HAMMER, C)], [_unit(HAMMER, Vector2i(0, 0), 20)],
		{"type": "rout", "piles": [{"x": pile.x, "y": pile.y}]})
	_place(mag, 0, C)
	_check("magnet pulls in a pile 2 hexes away without moving", _ability(mag, 0, 1, pile) and mag.scrap_collected == 4 and _at(mag, 0) == C)


func _test_enemy_kinds() -> void:
	# Tracker: its shot follows the machine it locked onto.
	var tracker := Vector2i(4, 1)
	var victim: Vector2i = _off(tracker, 0, -3, 3)
	var state: CombatState = _fight(_rows(), [_unit(HAMMER, victim)], [{"parts": LANCE, "x": tracker.x, "y": tracker.y, "hp": 30, "kind": "tracker"}])
	_place(state, 0, victim)
	_place(state, 10, tracker)
	state.intents = [{"ref": 10, "w": 1, "x": victim.x, "y": victim.y, "order": 1, "lock": 0}]
	# Sideways, staying in range: getting OUT of range is real counterplay, not a dodge.
	var step: Vector2i = victim
	for n: Vector2i in Hex.neighbors(victim):
		if state.inside(n) and Hex.distance(n, tracker) <= 3 and n != victim and not Hex.line(tracker, victim).has(n):
			step = n
			break
	CombatSim.apply(state, [CombatSim.ACT_MOVE, 0, step.x, step.y])
	var hp: int = state.unit(0).hp
	CombatSim.apply(state, [CombatSim.ACT_END, -1, 0, 0])
	_check("tracker: stepping aside does not dodge a locked shot", state.unit(0).hp < hp)

	var gen: CombatState = _fight(_rows(), [_unit(HAMMER, victim)], [{"parts": LANCE, "x": tracker.x, "y": tracker.y, "hp": 30, "kind": "tracker"}])
	_check("tracker: its intent is locked onto a machine", gen.intents.is_empty() or int(gen.intents[0].get("lock", -1)) == 0)

	# Bomber: explodes on death, both sides.
	var bomb: Vector2i = Hex.neighbor(C, 0)
	var friend: Vector2i = Hex.neighbor(bomb, 1)
	var boom: CombatState = _fight(_rows(), [_unit(HAMMER, C)],
		[{"parts": HAMMER, "x": bomb.x, "y": bomb.y, "hp": 4, "kind": "bomber"}, _unit(HAMMER, friend, 20)])
	_place(boom, 0, C)
	_place(boom, 10, bomb)
	_place(boom, 11, friend)
	var mine: int = boom.unit(0).hp
	_attack(boom, 0, 0, bomb)
	_check("bomber: killing it blasts its neighbours for 4 (its friend too)", boom.unit(11).hp == 16)
	_check("bomber: and the machine that killed it, if adjacent", boom.unit(0).hp == mine - 4)

	# Warden: its neighbours take 2 less.
	var w_at: Vector2i = Hex.neighbor(C, 0)
	var ward: CombatState = _fight(_rows(), [_unit(HAMMER, Vector2i(0, 8))],
		[_unit(HAMMER, C, 20), {"parts": HAMMER, "x": w_at.x, "y": w_at.y, "hp": 20, "kind": "warden"}])
	_place(ward, 10, C)
	_place(ward, 11, w_at)
	_check("warden: a neighbour takes 2 less (4 -> 2)", CombatSim.damage_to(ward, ward.unit(0), ward.unit(10), 4, false) == 2)
	_check("warden: the warden itself does not", CombatSim.damage_to(ward, ward.unit(0), ward.unit(11), 4, false) == 4)

	# Hive: marks a hex, builds on it next round -- unless something stands there.
	var hive: CombatState = _fight(_rows(), [_unit(HAMMER, Vector2i(0, 8))],
		[{"parts": LANCE, "x": 4, "y": 1, "hp": 20, "kind": "hive"}])
	_check("hive: marks a spawn hex on round 1", hive.spawn_marks.has(10))
	var mark: Vector2i = hive.spawn_marks.get(10, Vector2i(-1, -1))
	var enemies_before: int = hive.crew(GridUnit.TEAM_ENEMY).size()
	hive.intents.clear()
	CombatSim.apply(hive, [CombatSim.ACT_END, -1, 0, 0])
	_check("hive: builds a drone there next round", hive.crew(GridUnit.TEAM_ENEMY).size() == enemies_before + 1)
	var blocked: CombatState = _fight(_rows(), [_unit(HAMMER, Vector2i(0, 8))],
		[{"parts": LANCE, "x": 4, "y": 1, "hp": 20, "kind": "hive"}])
	var bmark: Vector2i = blocked.spawn_marks.get(10, Vector2i(-1, -1))
	_place(blocked, 0, bmark)
	blocked.intents.clear()
	var before: int = blocked.crew(GridUnit.TEAM_ENEMY).size()
	CombatSim.apply(blocked, [CombatSim.ACT_END, -1, 0, 0])
	_check("hive: standing on the marked hex blocks the build", blocked.crew(GridUnit.TEAM_ENEMY).size() == before and mark.x >= 0)


## The preview is the real rules on a copy, so it must match what then happens.
func _test_dry_run_matches() -> void:
	var barrel: Vector2i = Hex.neighbor(C, 0)
	var a: Vector2i = Hex.neighbor(barrel, 1)
	var b: Vector2i = Hex.neighbor(barrel, 5)
	var state: CombatState = _fight(_rows({barrel: "b"}), [_unit(LANCE, Hex.neighbor(C, 3))],
		[{"parts": HAMMER, "x": a.x, "y": a.y, "hp": 3, "kind": "bomber"}, _unit(HAMMER, b, 20)])
	_place(state, 0, Hex.neighbor(C, 3))
	_place(state, 10, a)
	_place(state, 11, b)
	var predicted: Array = CombatSim.preview_attack(state, 0, 1, barrel)["effects"]
	var before: CombatState = state.clone()
	_attack(state, 0, 1, barrel)
	var actual: Array = CombatSim.diff(before, state)
	_check("a barrel + bomber chain: the preview predicted exactly what happened", str(predicted) == str(actual) and not actual.is_empty())


# --- Whole fights -------------------------------------------------------------

func _test_bot_fight(fight_id: String) -> void:
	var setup: CombatSetup = CombatSetup.build(_db.fights[fight_id], _db.combat_rules, _db.parts, _db.tiles, _db.balance.effectiveness, 2026)
	var state: CombatState = CombatSim.start(setup)
	var actions: Array = []
	var guard: int = 0
	while state.outcome == CombatState.ONGOING and guard < 100:
		actions.append_array(CombatBot.take_turn(state))
		guard += 1
	_check("%s: bot fight ends within max_rounds" % fight_id, state.outcome != CombatState.ONGOING and state.round_number <= setup.max_rounds)
	var dealt: Array[int] = [0, 0]
	for e: Array in state.events:
		if int(e[GridEv.F_KIND]) == GridEv.DAMAGE and int(e[GridEv.F_ACTOR]) >= 0:
			dealt[int(e[GridEv.F_ACTOR]) / 10] += int(e[GridEv.F_V1])
	print("    %s (%s): %s in %d rounds, crew %d/3, piles %d, damage player %d / enemy %d, hash %s" % [
		fight_id, String(setup.objective["type"]), "WON" if state.outcome == CombatState.WON else "LOST",
		state.round_number, state.crew(GridUnit.TEAM_PLAYER).size(), state.piles_collected, dealt[0], dealt[1], state.event_hash()])
	var same: bool = true
	for i: int in 3:
		if CombatSim.replay(setup, actions).event_hash() != state.event_hash():
			same = false
	_check("%s: replaying gives the same hash 3 times" % fight_id, same)
	var stable: bool = true
	for cut: int in [1, actions.size() / 3, actions.size() / 2, actions.size() - 1]:
		var partial: CombatState = CombatSim.replay(setup, actions.slice(0, cut))
		for i: int in partial.events.size():
			if partial.events[i] != state.events[i]:
				stable = false
	_check("%s: every replayed prefix matches the full fight (undo is exact)" % fight_id, stable)


func _check(label: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s" % label)
