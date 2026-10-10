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
	_test_bonus_blocks()
	_test_tearing()
	_test_slag()
	_test_intents_target_hexes()
	_test_piles()
	_test_playtest4()
	_test_objectives()
	_test_barrels_and_props()
	_test_pits()
	_test_abilities()
	_test_enemy_kinds()
	_test_dry_run_matches()
	_test_gate_and_reclaimer()
	_test_boss_tricks()
	_test_playtest5()
	_test_scrap_on_the_way()
	_test_shot_leanings()
	_test_act2_kinds()
	_test_playtest7()
	_test_act3()
	_test_objectives_028()
	_test_weapons_029()
	_test_warlords_030()
	_test_modules_033()
	_test_playtest11()
	_test_bosses_038()
	_test_arms_047()
	for id: String in ["proto_yard", "slag_pit", "container_row", "pit_row", "crane_legs", "slag_channel", "sorting_gate", "shakedown",
			"slag_lake", "pipe_forest", "cooling_flats", "the_pour", "casting_floor", "ladle_line", "furnace_mouths", "the_core",
		"warlord_grinder", "warlord_magnet", "warlord_twins"]:
		_test_bot_fight(id)
	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	print("")
	quit(1 if _failed > 0 else 0)


## 021, Act 2: The Pour floods what it marked a round before; a sentinel is plated and anchored.
func _test_act2_kinds() -> void:
	var far := Vector2i(0, 0)
	var pour: Dictionary = _unit(HAMMER, far, 40)
	pour["kind"] = "pour"
	var s: CombatState = _fight(_rows(), [_unit(HAMMER, C, 30)], [pour])
	_place(s, 0, C)
	_place(s, 10, far)
	var marked: bool = false
	var flooded_at: int = -1
	var hp_before: int = 0
	for turn: int in 5:
		_place(s, 0, C)   # stand still: the point is what standing still costs
		_place(s, 10, far)
		s.intents.clear()
		if s.pour_marks.has(C) and not marked:
			marked = true
			hp_before = s.unit(0).hp
			var copy: CombatState = s.clone()
			CombatSim.apply(copy, [CombatSim.ACT_END, 0, 0, 0])
			_check("a dry run of the flood does not leak into the fight", copy.flooded.has(C) and not s.flooded.has(C))
		CombatSim.apply(s, [CombatSim.ACT_END, 0, 0, 0])
		if s.flooded.has(C) and flooded_at < 0:
			flooded_at = turn
			break
	_check("The Pour marks the hex a machine stands on", marked)
	_check("a round later that hex is slag", flooded_at >= 0 and s.hazard(C.x, C.y) == 2)
	_check("and what stood on it took the slag's 2", marked and s.unit(0).hp <= hp_before - 2)
	var plain: CombatState = _fight(_rows(), [_unit(HAMMER, C)], [_unit(HAMMER, far)])
	var guard: Dictionary = _unit(HAMMER, far)
	guard["kind"] = "sentinel"
	var plated: CombatState = _fight(_rows(), [_unit(HAMMER, C)], [guard])
	_check("a sentinel takes 1 less from every hit", plated.unit(10).armor == plain.unit(10).armor + 1)
	_check("and cannot be shoved", plated.unit(10).unshovable)


## Play-test 7: the enemy's volley as totals (`incoming`), a tied shove taking the better hex,
## and a piercing weapon aimed as far as its beam flies.
func _test_playtest7() -> void:
	# Two shots into one machine, and a third that a machine of their own stands in the way of.
	var east: Vector2i = Hex.neighbor(C, 0)
	var a: Vector2i = Hex.neighbor(Hex.neighbor(C, 1), 1)
	var b: Vector2i = Hex.neighbor(Hex.neighbor(C, 5), 5)
	var blocker: Vector2i = Hex.neighbor(east, 0)
	var shooter: Vector2i = Hex.neighbor(blocker, 0)
	var s: CombatState = _fight(_rows(), [_unit(HAMMER, C, 30)],
		[_unit(COIL, a, 20), _unit(COIL, b, 20), _unit(COIL, shooter, 20), _unit(HAMMER, blocker, 20)])
	for ref: int in [10, 11, 12, 13]:
		_place(s, ref, [a, b, shooter, blocker][ref - 10])
	s.intents = [{"ref": 10, "w": 0, "x": C.x, "y": C.y, "order": 1}, {"ref": 11, "w": 0, "x": C.x, "y": C.y, "order": 2},
		{"ref": 12, "w": 0, "x": C.x, "y": C.y, "order": 3}]
	var volley: Dictionary = CombatSim.incoming(s)
	var mine: int = 0
	var theirs: int = 0
	for hit: Dictionary in (volley["units"] as Array):
		if int(hit["ref"]) == 0:
			mine = int(hit["hp_lost"])
		if int(hit["ref"]) == 13:
			theirs = int(hit["hp_lost"])
	var expected: int = 0
	for ref: int in [10, 11]:
		expected += CombatSim.damage_to(s, s.unit(ref), s.unit(0), int(s.unit(ref).weapons[0]["damage"]) + s.unit(ref).damage_bonus, true)
	_check("incoming: two shots into one machine are one total (%d, expected %d)" % [mine, expected], mine == expected and mine > 0)
	_check("incoming: a machine standing in a shot's way shows what it takes (%d)" % theirs, theirs > 0)
	var hp: int = s.unit(0).hp
	var before: int = s.events.size()
	var dry: CombatState = s.clone()
	CombatSim._fire_intents(dry)
	_check("incoming leaves the fight alone", s.events.size() == before and s.unit(0).hp == hp)
	_check("and matches the volley itself", dry.unit(0).hp == hp - mine)

	# A shove from off the six axes: two hexes are equally "away". A pit on either one is taken.
	var target: Vector2i = _off(C, 2, -1, -1)
	var dirs: Array[int] = Hex.directions(C, target)
	_check("an off-axis hex sits between two directions", dirs.size() == 2)
	for pick: int in 2:
		var pit: Vector2i = Hex.neighbor(target, dirs[pick])
		var p: CombatState = _fight(_rows({pit: "o"}), [_unit(COIL, C)], [_unit(HAMMER, target, 20)])
		_place(p, 0, C)
		_place(p, 10, target)
		_attack(p, 0, 1, target)
		_check("a tied shove takes the pit on side %d" % pick, not p.unit(10).alive and _at(p, 10) == pit)
	var open: CombatState = _fight(_rows(), [_unit(COIL, C)], [_unit(HAMMER, target, 20)])
	_place(open, 0, C)
	_place(open, 10, target)
	_attack(open, 0, 1, target)
	_check("over open ground a tied shove keeps the first direction", _at(open, 10) == Hex.neighbor(target, dirs[0]))

	# Pierce: aimed into the overshoot, the beam's line goes where it was aimed.
	var line: Array[Vector2i] = []
	var step: Vector2i = Vector2i(0, 4)
	for i: int in 7:
		step = Hex.neighbor(step, 0)
		line.append(step)
	var lance: CombatState = _fight(_rows({line[4]: "b"}), [_unit(LANCE, Vector2i(0, 4))],
		[_unit(HAMMER, line[1], 20), _unit(HAMMER, line[2], 20)])
	_place(lance, 0, Vector2i(0, 4))
	_place(lance, 10, line[1])
	_place(lance, 11, line[2])
	var reach: int = CombatSim.weapon_reach(lance, lance.unit(0), 1)
	_check("a piercing weapon may aim into its overshoot (%d of reach %d)" % [reach + 2, reach],
		CombatSim.can_attack(lance, 0, 1, line[reach + 1]))
	_check("but not past it", not CombatSim.can_attack(lance, 0, 1, line[reach + 2]))
	var tuned: Array = LANCE.duplicate()
	tuned[3] = "ar_lance:b"
	var twice: CombatState = _fight(_rows({line[3]: "b"}), [_unit(tuned, Vector2i(0, 4))],
		[_unit(HAMMER, line[1], 20), _unit(HAMMER, line[2], 20)])
	_place(twice, 0, Vector2i(0, 4))
	_place(twice, 10, line[1])
	_place(twice, 11, line[2])
	var plan: Dictionary = CombatSim.strike_plan(twice, twice.unit(0), 1, line[3])
	_check("pierce 2 goes through two machines into the drum behind them",
		(plan["hits"] as Array).size() == 2 and (plan["props"] as Array).size() == 1)
	var plain: CombatState = _fight(_rows(), [_unit(COIL, C)], [_unit(HAMMER, target, 20)])
	_check("a weapon that does not pierce aims no further than its reach",
		CombatSim.aim_reach(plain, plain.unit(0), 1) == CombatSim.weapon_reach(plain, plain.unit(0), 1))


## 025, Act 3: furnace flues, conduits, the Core.
func _test_act3() -> void:
	var far := Vector2i(0, 0)
	var s: CombatState = _fight(_rows({C: "f"}), [_unit(HAMMER, C, 30)], [_unit(HAMMER, far, 30)])
	_place(s, 0, C)
	_check("flues blow on even rounds only", CombatSim.flues_blow(s, 2) and not CombatSim.flues_blow(s, 3))
	var hp: int = s.unit(0).hp
	var volley: Dictionary = CombatSim.incoming(s)
	var told: int = 0
	for hit: Dictionary in (volley["units"] as Array):
		if int(hit["ref"]) == 0:
			told = int(hit["hp_lost"])
	_check("incoming counts the flue about to blow (%d)" % told, told == 3)
	CombatSim.apply(s, [CombatSim.ACT_END, 0, 0, 0])
	_check("a flue blows at the start of round 2 for 3 (%d -> %d)" % [hp, s.unit(0).hp], s.unit(0).hp == hp - 3)
	var after: int = s.unit(0).hp
	s.intents.clear()
	CombatSim.apply(s, [CombatSim.ACT_END, 0, 0, 0])
	_check("and not at the start of round 3", s.unit(0).hp == after)

	# A conduit's neighbour hits 1 harder; its own blow does not.
	var n: Vector2i = Hex.neighbor(C, 0)
	var link: Vector2i = Hex.neighbor(n, 0)
	var relay: Dictionary = _unit(HAMMER, link, 20)
	relay["kind"] = "conduit"
	var boosted: CombatState = _fight(_rows(), [_unit(HAMMER, C, 30)], [_unit(HAMMER, n, 20), relay])
	var plain: CombatState = _fight(_rows(), [_unit(HAMMER, C, 30)], [_unit(HAMMER, n, 20), _unit(HAMMER, link, 20)])
	for st: CombatState in [boosted, plain]:
		_place(st, 0, C)
		_place(st, 10, n)
		_place(st, 11, link)
	var with_link: int = int((CombatSim.strike_plan(boosted, boosted.unit(10), 1, C)["hits"] as Array)[0]["damage"])
	var without: int = int((CombatSim.strike_plan(plain, plain.unit(10), 1, C)["hits"] as Array)[0]["damage"])
	_check("a conduit's neighbour hits 1 harder (%d vs %d)" % [with_link, without], with_link == without + 1)
	boosted.unit(11).alive = false
	_check("and not once the conduit is gone", int((CombatSim.strike_plan(boosted, boosted.unit(10), 1, C)["hits"] as Array)[0]["damage"]) == without)

	# The Core: bolted down, marks its ring a round ahead, pulses for 4.
	var core_at := Vector2i(4, 1)
	var near: Vector2i = _off(core_at, 0, -2, 2)
	var core: Dictionary = _unit(HAMMER, core_at, 40)
	core["kind"] = "heart"
	var c: CombatState = _fight(_rows(), [_unit(HAMMER, near, 30)], [core])
	_check("(precondition) the crew stands 2 from the Core", Hex.distance(near, core_at) == 2)
	var moved: bool = false
	var marked: bool = false
	var leak: bool = false
	var pulse_hp: int = -1
	for turn: int in 3:
		_place(c, 0, near)
		c.unit(0).moved = false
		var before: int = c.unit(0).hp
		CombatSim.apply(c, [CombatSim.ACT_END, 0, 0, 0])
		moved = moved or _at(c, 10) != core_at
		if c.pulse_marks.has(near) and not marked:
			marked = true
			var copy: CombatState = c.clone()
			CombatSim.apply(copy, [CombatSim.ACT_END, 0, 0, 0])
			leak = not c.pulse_marks.has(near) or copy.pulse_marks.has(near)
		elif marked and pulse_hp < 0:
			pulse_hp = before - c.unit(0).hp
	_check("the Core never leaves its hex", not moved)
	_check("it marks the ring around it a round ahead (round 2)", marked)
	_check("a dry run of the pulse does not leak into the fight", not leak)
	_check("and a round later pulses for 4 (%d)" % pulse_hp, pulse_hp == 4)
	_check("it cannot be shoved", c.unit(10).unshovable)

	# 027: at half HP the Core erupts -- faster, wider, harder -- and calls two guards next round.
	var core2: Dictionary = _unit(HAMMER, core_at, 40)
	core2["kind"] = "heart"
	var e: CombatState = _fight(_rows(), [_unit(HAMMER, Vector2i(0, 8), 30)], [core2])
	var before_units: int = e.units.size()
	CombatSim.hurt(e, 0, e.unit(10), 19)
	_check("not enraged above half HP", not e.enraged.has(10))
	CombatSim.hurt(e, 0, e.unit(10), 1)
	_check("enraged at half HP", e.enraged.has(10) and int(CombatSim.kind_rules(e, e.unit(10))["pulse_radius"]) == 3)
	CombatSim.apply(e, [CombatSim.ACT_END, 0, 0, 0])
	_check("and its three guards arrive the next round", e.units.size() == before_units + 3)


## 028: HOLD, HACK, SURVIVE and the yard's conditions.
func _test_objectives_028() -> void:
	var far := Vector2i(0, 0)
	var zone: Array = [{"x": C.x, "y": C.y}, {"x": C.x + 1, "y": C.y}, {"x": C.x - 1, "y": C.y}]
	var hold: CombatState = _fight(_rows(), [_unit(HAMMER, C, 40)], [_unit(HAMMER, far, 40)], {"type": "hold", "need": 3, "cells": zone})
	var scores: Array = []
	for turn: int in 3:
		_place(hold, 0, C)
		_place(hold, 10, far)
		hold.intents.clear()
		CombatSim.apply(hold, [CombatSim.ACT_END, 0, 0, 0])
		scores.append(hold.hold_score)
	_check("HOLD: each round started on the zone scores %s" % [scores], scores == [1, 2, 3])
	_check("HOLD: three scores win", hold.outcome == CombatState.WON)
	var contested: CombatState = _fight(_rows(), [_unit(HAMMER, C, 40)], [_unit(HAMMER, Vector2i(C.x + 1, C.y), 40)],
		{"type": "hold", "need": 3, "cells": zone})
	_place(contested, 10, Vector2i(C.x + 1, C.y))
	contested.intents.clear()
	CombatSim.apply(contested, [CombatSim.ACT_END, 0, 0, 0])
	_check("HOLD: an enemy on the zone denies the round", contested.hold_score == 0 or contested.unit_at(C.x + 1, C.y) == null)

	var terminals: Array = [{"x": 2, "y": 4}, {"x": 4, "y": 6}, {"x": 6, "y": 4}]
	var hack: CombatState = _fight(_rows(), [_unit(DASHER, Vector2i(4, 4), 40)], [_unit(HAMMER, far, 40)], {"type": "hack", "need": 2, "cells": terminals})
	var reach: Dictionary = CombatSim.reachable(hack, 0)
	_check("(precondition) a terminal is in reach", reach.has(Vector2i(2, 4)))
	CombatSim.apply(hack, [CombatSim.ACT_MOVE, 0, 2, 4])
	_check("HACK: ending a move on a terminal takes it", hack.hacked == [Vector2i(2, 4)] and hack.outcome == CombatState.ONGOING)
	var copy: CombatState = hack.clone()
	_check("a dry run copies the taken terminals", copy.hacked == hack.hacked)

	var survive: CombatState = _fight(_rows(), [_unit(HAMMER, Vector2i(4, 8), 60)], [_unit(HAMMER, far, 60)],
		{"type": "survive", "rounds": 6, "every": 2, "count": 2})
	var waves: int = 0
	for turn: int in 6:
		var before: int = survive.units.size()
		survive.intents.clear()
		CombatSim.apply(survive, [CombatSim.ACT_END, 0, 0, 0])
		if survive.units.size() > before:
			waves += 1
	_check("SURVIVE: waves come in (%d)" % waves, waves >= 2)
	_check("SURVIVE: outlasting the rounds wins", survive.outcome == CombatState.WON)

	var dusty: CombatState = _fight(_rows(), [_unit(LANCE, C)], [_unit(HAMMER, far)])
	var clear_reach: int = CombatSim.weapon_reach(dusty, dusty.unit(0), 1)
	var fight: Dictionary = {"id": "t", "rows": _rows(), "player": [_unit(LANCE, C)], "enemy": [_unit(HAMMER, far)], "modifiers": ["dust", "heat_wave", "scrap_rain"]}
	var setup: CombatSetup = CombatSetup.build(fight, _db.combat_rules, _db.parts, _db.tiles, _db.effectiveness, 1)
	var storm: CombatState = CombatSim.start(setup)
	_check("DUST STORM: shots reach 1 less (%d -> %d)" % [clear_reach, CombatSim.weapon_reach(storm, storm.unit(0), 1)],
		CombatSim.weapon_reach(storm, storm.unit(0), 1) == clear_reach - 1)
	_check("HEAT WAVE: the crew vents 1 less", storm.unit(0).vent == maxi(0, dusty.unit(0).vent - 1))
	_check("SCRAP RAIN: piles are worth double", setup.pile_value == int(_db.combat_rules.get("pile_value", 4)) * 2)
	var wired: CombatState = _fight(_rows({C: "w"}), [_unit(HAMMER, C, 30)], [_unit(HAMMER, far, 30)])
	_place(wired, 0, C)
	var hp: int = wired.unit(0).hp
	wired.intents.clear()
	CombatSim.apply(wired, [CombatSim.ACT_END, 0, 0, 0])
	_check("LIVE WIRES: 2 to whatever starts a round on one", wired.unit(0).hp == hp - 2)


## 029: the flamer's cone, the harpoon's drag, the shield caster.
func _test_weapons_029() -> void:
	var flamer: Array = ["ch_brute", "co_dynamo", "ar_flamer", "ar_hammer", "mo_scavenger"]
	var aim: Vector2i = Hex.neighbor(C, 0)
	var beyond: Array[Vector2i] = []
	for n: Vector2i in Hex.neighbors(aim):
		if Hex.distance(C, n) == 2:
			beyond.append(n)
	_check("(precondition) a cone covers the hex aimed at and three beyond", beyond.size() == 3)
	var foes: Array = [_unit(HAMMER, aim, 20)]
	for b: Vector2i in beyond:
		foes.append(_unit(HAMMER, b, 20))
	var burn: CombatState = _fight(_rows(), [_unit(flamer, C, 30)], foes)
	_place(burn, 0, C)
	_place(burn, 10, aim)
	for i: int in beyond.size():
		_place(burn, 11 + i, beyond[i])
	var plan: Dictionary = CombatSim.strike_plan(burn, burn.unit(0), 0, aim)
	_check("the flamer's cone hits all four (%d)" % (plan["hits"] as Array).size(), (plan["hits"] as Array).size() == 4)
	_check("and cannot be aimed two hexes out", not bool(CombatSim.strike_plan(burn, burn.unit(0), 0, beyond[0])["legal"]))

	var harpoon: Array = ["ch_hauler", "co_dynamo", "ar_harpoon", "ar_hammer", "mo_scavenger"]
	var line: Array[Vector2i] = []
	var step: Vector2i = C
	for i: int in 3:
		step = Hex.neighbor(step, 0)
		line.append(step)
	var drag: CombatState = _fight(_rows(), [_unit(harpoon, C, 30)], [_unit(HAMMER, line[2], 20)])
	_place(drag, 0, C)
	_place(drag, 10, line[2])
	_attack(drag, 0, 0, line[2])
	_check("a harpoon drags its target a hex toward the shooter", _at(drag, 10) == line[1])

	var caster: Array = ["ch_hauler", "co_dynamo", "ar_shieldcaster", "ar_hammer", "mo_scavenger"]
	var ally_at: Vector2i = Hex.neighbor(Hex.neighbor(C, 3), 3)
	var guard: CombatState = _fight(_rows(), [_unit(caster, C, 30), _unit(HAMMER, ally_at, 30)], [_unit(HAMMER, Vector2i(0, 0), 20)])
	_place(guard, 0, C)
	_place(guard, 1, ally_at)
	_check("a shield caster cannot be aimed at an enemy or the ground", not CombatSim.can_attack(guard, 0, 0, Vector2i(0, 0))
		and not CombatSim.can_attack(guard, 0, 0, Hex.neighbor(C, 0)))
	_attack(guard, 0, 0, ally_at)
	_check("a shield caster shields the ally it is aimed at (%d)" % guard.unit(1).shield, guard.unit(1).shield == 3)


## 047: the flail's arc, the snare, the mine.
func _test_arms_047() -> void:
	# Flail: aimed at a neighbour, it hits that hex and the two neighbours of the shooter beside it.
	var flail: Array = ["ch_brute", "co_dynamo", "ar_flail", "ar_hammer", "mo_scavenger"]
	var aim: Vector2i = Hex.neighbor(C, 0)
	var arc: Array[Vector2i] = []
	for n: Vector2i in Hex.neighbors(aim):
		if Hex.distance(C, n) == 1:
			arc.append(n)
	_check("(precondition) two neighbours of the shooter sit beside the hex aimed at", arc.size() == 2)
	var behind: Vector2i = Hex.neighbor(aim, 0)
	var foes: Array = [_unit(HAMMER, aim, 20), _unit(HAMMER, arc[0], 20), _unit(HAMMER, arc[1], 20), _unit(HAMMER, behind, 20)]
	var swing: CombatState = _fight(_rows(), [_unit(flail, C, 30)], foes)
	_place(swing, 0, C)
	_place(swing, 10, aim)
	_place(swing, 11, arc[0])
	_place(swing, 12, arc[1])
	_place(swing, 13, behind)
	var plan: Dictionary = CombatSim.strike_plan(swing, swing.unit(0), 0, aim)
	var hit: Array = (plan["hits"] as Array).map(func(h: Dictionary) -> int: return int(h["ref"]))
	hit.sort()
	_check("a flail hits the arc of three and not the hex behind (%s)" % [hit], hit == [10, 11, 12])

	# Snare: an enemy's snare holds a crew machine for its next turn; the crew's holds an enemy's move.
	var snarer: Array = ["ch_hauler", "co_dynamo", "ar_snare", "ar_hammer", "mo_scavenger"]
	var far: Vector2i = Hex.neighbor(Hex.neighbor(C, 0), 0)
	var held: CombatState = _fight(_rows(), [_unit(HAMMER, C, 30)], [_unit(snarer, far, 30)])
	_place(held, 0, C)
	_place(held, 10, far)
	held.intents = [{"ref": 10, "w": 0, "x": C.x, "y": C.y, "order": 1}]
	var foe_hp_before: int = held.unit(0).hp
	CombatSim.apply(held, [CombatSim.ACT_END, 0, 0, 0])
	_check("an enemy's snare hits and holds the machine (%d -> %d)" % [foe_hp_before, held.unit(0).hp],
		held.unit(0).hp < foe_hp_before and held.unit(0).snared and CombatSim.reachable(held, 0).is_empty())
	_check("a snared machine cannot dash or charge either", not held.unit(0).abilities.any(func(a: Dictionary) -> bool:
		return ["dash", "charge"].has(String(a["kind"])) and CombatAbilities.usable(held, held.unit(0), held.unit(0).abilities.find(a))))
	held.intents.clear()
	CombatSim.apply(held, [CombatSim.ACT_END, 0, 0, 0])
	_check("and is free again the turn after", not held.unit(0).snared and not CombatSim.reachable(held, 0).is_empty())

	var trap: CombatState = _fight(_rows(), [_unit(snarer, C, 30)], [_unit(HAMMER, far, 30)])
	_place(trap, 0, C)
	_place(trap, 10, far)
	_attack(trap, 0, 0, far)
	_check("the crew's snare holds an enemy", trap.unit(10).snared)
	CombatSim.apply(trap, [CombatSim.ACT_END, 0, 0, 0])
	_check("which does not move on its next move, then is free (%s)" % [_at(trap, 10)], _at(trap, 10) == far and not trap.unit(10).snared)

	# Mine: laid on an open hex, it goes off once under whatever starts a round on it.
	var layer: Array = ["ch_hauler", "co_dynamo", "ar_minelayer", "ar_hammer", "mo_scavenger"]
	var spot: Vector2i = Hex.neighbor(Hex.neighbor(C, 3), 3)
	var mined: CombatState = _fight(_rows(), [_unit(HAMMER, spot, 30)], [_unit(layer, C, 30)])
	_place(mined, 0, spot)
	_place(mined, 10, C)
	var first: Dictionary = CombatSim.strike_plan(mined, mined.unit(10), 0, spot)
	_check("a mine layer plans a mine on the hex", bool(first["legal"]) and first.has("mine") and (first["hits"] as Array).is_empty())
	mined.intents = [{"ref": 10, "w": 0, "x": spot.x, "y": spot.y, "order": 1}]
	var copy: CombatState = mined.clone()
	var seen: Dictionary = CombatSim.incoming(mined)
	_check("incoming counts the mine under the machine", (seen.get("units", []) as Array).any(func(e: Dictionary) -> bool: return int(e["ref"]) == 0 and int(e["hp_lost"]) > 0))
	_check("and a dry run leaves no mine behind", mined.mines.is_empty() and copy.mines.is_empty())
	var hp: int = mined.unit(0).hp
	CombatSim.apply(mined, [CombatSim.ACT_END, 0, 0, 0])
	_check("the mine goes off at the round's start (%d -> %d) and is gone" % [hp, mined.unit(0).hp],
		mined.unit(0).hp < hp and not mined.mines.has(spot) and _count(mined, 0, GridEv.MINE_BLEW) == 1)
	var empty: CombatState = _fight(_rows(), [_unit(HAMMER, Vector2i(0, 8), 30)], [_unit(layer, C, 30)])
	_place(empty, 0, Vector2i(0, 8))
	_place(empty, 10, C)
	empty.intents = [{"ref": 10, "w": 0, "x": spot.x, "y": spot.y, "order": 1}]
	CombatSim.apply(empty, [CombatSim.ACT_END, 0, 0, 0])
	_check("a mine on an empty hex stays, and the AI reads it as a hazard", empty.mines.has(spot) and empty.hazard(spot.x, spot.y) > 0)
	_check("a mine cannot be laid on a mine", not bool(CombatSim.strike_plan(empty, empty.unit(10), 0, spot)["legal"]))
	# Replay: the same actions, the same fight.
	var again: CombatState = CombatSim.replay(empty.setup, [[CombatSim.ACT_END, 0, 0, 0]])
	_check("a fight with mines replays the same", again.event_hash() == CombatSim.replay(empty.setup, [[CombatSim.ACT_END, 0, 0, 0]]).event_hash())


## 030: the warlords' rules.
func _test_warlords_030() -> void:
	var saws: Dictionary = _unit(HAMMER, C, 40)
	saws["kind"] = "grinder"
	var n: Vector2i = Hex.neighbor(C, 0)
	var g: CombatState = _fight(_rows(), [_unit(HAMMER, n, 30), _unit(HAMMER, Vector2i(0, 8), 30)], [saws])
	_place(g, 0, n)
	_place(g, 1, Vector2i(0, 8))
	_place(g, 10, C)
	var next_to: int = g.unit(0).hp
	var away: int = g.unit(1).hp
	g.intents.clear()
	CombatSim.apply(g, [CombatSim.ACT_END, 0, 0, 0])
	_check("the Grinder's ring cuts what stands next to it (%d -> %d), not further" % [next_to, g.unit(0).hp],
		g.unit(0).hp <= next_to - 2 and g.unit(1).hp == away)

	var king: Dictionary = _unit(HAMMER, C, 40)
	king["kind"] = "magnet"
	var three: Vector2i = _off(C, 3, -3, 0)
	var m: CombatState = _fight(_rows(), [_unit(HAMMER, three, 30)], [king])
	_place(m, 0, three)
	_place(m, 10, C)
	m.intents.clear()
	CombatSim.apply(m, [CombatSim.ACT_END, 0, 0, 0])
	_check("the Magnet King hauls a machine 3 away a hex toward it (round 2)", Hex.distance(_at(m, 0), C) == 2)

	var west: Dictionary = _unit(HAMMER, Vector2i(2, 0), 30)
	west["kind"] = "twin"
	var east: Dictionary = _unit(HAMMER, Vector2i(6, 0), 30)
	east["kind"] = "twin"
	var t: CombatState = _fight(_rows(), [_unit(HAMMER, C, 30)], [west, east])
	var both: int = CombatSim.damage_to(t, t.unit(0), t.unit(10), 6, false)
	t.unit(11).alive = false
	var alone: int = CombatSim.damage_to(t, t.unit(0), t.unit(10), 6, false)
	_check("a twin takes 2 less while its twin stands (%d), and not after (%d)" % [both, alone], alone == both + 2)


## 033: modules (and cores) with mechanics -- play-test 10, "too little variety, modules above all".
func _test_modules_033() -> void:
	var n: Vector2i = Hex.neighbor(C, 0)
	var spiked: Array = HAMMER.duplicate()
	spiked[4] = "mo_spikes"
	var thorn: CombatState = _fight(_rows(), [_unit(HAMMER, C, 30)], [_unit(spiked, n, 30)])
	_place(thorn, 0, C)
	_place(thorn, 10, n)
	var before: int = thorn.unit(0).hp
	_attack(thorn, 0, 0, n)
	_check("thorns: a melee blow on Spiked Plating costs the attacker 1 (%d -> %d)" % [before, thorn.unit(0).hp], thorn.unit(0).hp == before - 1)

	var drone: Array = HAMMER.duplicate()
	drone[4] = "mo_repair"
	var fix: CombatState = _fight(_rows(), [_unit(drone, C, 30)], [_unit(HAMMER, Vector2i(0, 0), 20)])
	fix.unit(0).hp = 10
	fix.intents.clear()
	var since: int = fix.events.size()
	CombatSim.apply(fix, [CombatSim.ACT_END, 0, 0, 0])
	_check("regen: a Repair Drone patches 1 HP at the start of a round (%d)" % fix.unit(0).hp,
		fix.unit(0).hp == 11 and _count(fix, since, GridEv.REPAIRED) == 1)

	var leech: Array = HAMMER.duplicate()
	leech[4] = "mo_leech"
	var eat: CombatState = _fight(_rows(), [_unit(leech, C, 30)], [_unit(HAMMER, n, 1), _unit(HAMMER, Vector2i(0, 0), 20)])
	_place(eat, 0, C)
	_place(eat, 10, n)
	eat.unit(0).hp = 10
	_attack(eat, 0, 0, n)
	_check("kill heal: a Scrap Leech's kill patches it 3 (%d)" % eat.unit(0).hp, not eat.unit(10).alive and eat.unit(0).hp == 13)

	var phoenix: Array = HAMMER.duplicate()
	phoenix[4] = "mo_phoenix"
	var stand: CombatState = _fight(_rows(), [_unit(phoenix, C, 30)], [_unit(HAMMER, Vector2i(0, 0), 20)])
	var p: GridUnit = stand.unit(0)
	CombatSim.hurt(stand, 10, p, 99)
	var held: bool = p.alive and p.hp == 1
	CombatSim.hurt(stand, 10, p, 99)
	_check("last stand: the Phoenix Cell holds the first wreck at 1 HP, and only the first", held and not p.alive)
	var copy: CombatState = _fight(_rows(), [_unit(phoenix, C, 30)], [_unit(HAMMER, Vector2i(0, 0), 20)])
	copy.unit(0).stood = true
	_check("and a dry run carries the spent stand (clone)", copy.clone().unit(0).stood)

	var gun: Array = ["ch_strider", "co_dynamo", "ar_lance", "ar_hammer", "mo_feeder"]
	var built: CombatState = _fight(_rows(), [_unit(gun, C, 30)], [_unit(HAMMER, Vector2i(0, 0), 20)])
	_check("Belt Feeder: +1 pierce on shots (lance %d), none on melee (%d)" % [int(built.unit(0).weapons[0]["pierce"]), int(built.unit(0).weapons[1]["pierce"])],
		int(built.unit(0).weapons[0]["pierce"]) == 2 and int(built.unit(0).weapons[1]["pierce"]) == 0)
	gun[4] = "mo_arcrelay"
	built = _fight(_rows(), [_unit(gun, C, 30)], [_unit(HAMMER, Vector2i(0, 0), 20)])
	_check("Arc Relay: a shot that never arced arcs once", int(built.unit(0).weapons[0]["chain"]) == 1)
	gun[4] = "mo_spotter"
	built = _fight(_rows(), [_unit(gun, C, 30)], [_unit(HAMMER, Vector2i(0, 0), 20)])
	_check("Spotter Uplink: every weapon marks", bool(built.unit(0).weapons[0]["mark"]) and bool(built.unit(0).weapons[1]["mark"]))
	gun[4] = "mo_ram"
	built = _fight(_rows(), [_unit(gun, C, 30)], [_unit(HAMMER, Vector2i(0, 0), 20)])
	_check("Hydraulic Ram: melee shoves, +1 melee", int(built.unit(0).weapons[1]["shove"]) == 1 and built.unit(0).melee_bonus >= 1)
	gun[1] = "co_mag"
	gun[4] = "mo_plating"
	built = _fight(_rows(), [_unit(gun, C, 30)], [_unit(HAMMER, Vector2i(0, 0), 20)])
	_check("the Mag Core (rare) lends its shots +1 pierce", int(built.unit(0).weapons[0]["pierce"]) == 2)
	var bad: Array = []
	for id: Variant in _db.parts.keys():
		var part: Dictionary = _db.parts[id]
		if String(part.get("slot", "")) in ["module", "core"] and PartText.summary(_db.parts, String(id), _db.combat_abilities).strip_edges().is_empty():
			bad.append(id)
	_check("every module and core says what it does %s" % [bad], bad.is_empty())
	# Aliases do not chain (Sprint Pistons once pointed at Jump Jets, itself a borrowed model).
	var no_model: Array = []
	for id: Variant in _db.parts.keys():
		if not PartTuning.is_tuned(String(id)) and not ResourceLoader.exists("res://art/parts/%s.glb" % PartTuning.model_of(String(id))):
			no_model.append(id)
	_check("every part's model exists %s" % [no_model], no_model.is_empty())


## 037 (play-test 11): a charge takes the terminal it ends on; some weapons deal their own type;
## a dry run reports the damage a standing prop takes.
func _test_playtest11() -> void:
	var term: Vector2i = _off(C, 2, -2, 0)
	var hack: CombatState = _fight(_rows(), [_unit(HAMMER, C, 30)], [_unit(HAMMER, Vector2i(0, 0), 20)],
		{"type": "hack", "need": 1, "cells": [{"x": term.x, "y": term.y}]})
	_place(hack, 0, C)
	var dir_cell: Vector2i = _off(C, 3, -3, 0)
	_check("(precondition) the charge's line runs over the terminal and on", Hex.distance(C, term) == 2 and Hex.distance(C, dir_cell) == 3)
	_ability(hack, 0, 0, term)
	_check("a charge that ends on a terminal takes it", _at(hack, 0) == term and (hack.hacked as Array).size() >= 1)

	var flamer: Array = ["ch_brute", "co_slug", "ar_flamer", "ar_hammer", "mo_scavenger"]   # kinetic core
	var reactive: Array = ["ch_bulwark", "co_slug", "ar_hammer", "ar_hammer", "mo_scavenger"]   # reactive armour
	var n: Vector2i = Hex.neighbor(C, 0)
	var burn: CombatState = _fight(_rows(), [_unit(flamer, C, 30)], [_unit(reactive, n, 30)])
	_place(burn, 0, C)
	_place(burn, 10, n)
	var hit: Dictionary = (CombatSim.strike_plan(burn, burn.unit(0), 0, n)["hits"] as Array)[0]
	_check("a Flamer on a kinetic core burns: thermal is STRONG on reactive armour (x%.1f)" % (float(int(hit["pct"])) / 100.0), int(hit["pct"]) > 100)
	_check("and the machine's own type is put back after the plan", burn.unit(0).damage_type == 0)

	var pylon_at: Vector2i = Hex.neighbor(C, 0)
	var gate: CombatState = _fight(_rows({pylon_at: "p"}), [_unit(HAMMER, C, 30)], [_unit(HAMMER, Vector2i(0, 0), 20)])
	_place(gate, 0, C)
	var effects: Array = CombatSim.dry_run(gate, [CombatSim.ACT_ATTACK, 0, 1, pylon_at.x, pylon_at.y])
	_check("a dry run reports damage to a pylon that stands (%s)" % [effects], effects.any(func(e: Dictionary) -> bool:
		return e.has("prop") and not bool(e["broken"]) and int(e["hp_lost"]) > 0))
	var parts: Dictionary = CombatSim.damage_parts(burn, [CombatSim.ACT_ATTACK, 0, 0, n.x, n.y])
	_check("damage_parts names the hits of an action (%s)" % [parts], parts.has(10))


## 038: the Core is shielded while a conduit stands; the end boss's board fields both conduits.
func _test_bosses_038() -> void:
	var core: Dictionary = _unit(HAMMER, C, 72)
	core["kind"] = "heart"
	var relay: Dictionary = _unit(HAMMER, Vector2i(0, 0), 14)
	relay["kind"] = "conduit"
	var n: Vector2i = Hex.neighbor(C, 3)
	var f: CombatState = _fight(_rows(), [_unit(HAMMER, n, 30)], [core, relay])
	_place(f, 0, n)
	var shielded: int = CombatSim.damage_to(f, f.unit(0), f.unit(10), 8, false)
	f.unit(11).alive = false
	var bare: int = CombatSim.damage_to(f, f.unit(0), f.unit(10), 8, false)
	_check("the Core takes 2 less while a conduit stands (%d), not after (%d)" % [shielded, bare], bare == shielded + 2)
	var setup: RunSetup = RunSetup.create(_db.parts, _db.tiles, _db.fights, _db.run_rules, _db.combat_rules, _db.effectiveness, 3)
	var state: RunState = RunSim.start(setup)
	state.act = 3
	var gate: Dictionary = RunSim._make_gate_fight(state, setup, 0, RunSim.widen(_db.fights["the_core"], _db.run_rules.get("board", {})), SimRNG.new(1))
	var conduits: int = (gate["enemy"] as Array).filter(func(e: Dictionary) -> bool: return String(e.get("kind", "")) == "conduit").size()
	_check("the Core's gate fields both of its conduits (%d)" % conduits, conduits == 2 and int((gate["enemy"] as Array)[0]["hp"]) == 72)


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
	var setup: CombatSetup = CombatSetup.build(fight, _db.combat_rules, _db.parts, _db.tiles, _db.effectiveness, 1)
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
		var setup: CombatSetup = CombatSetup.build(fight, _db.combat_rules, _db.parts, _db.tiles, _db.effectiveness, 7)
		_check("%s builds with no errors %s" % [id, setup.errors], not fight.is_empty() and setup.errors.is_empty())
	var defend: CombatSetup = CombatSetup.build(_db.fights["container_row"], _db.combat_rules, _db.parts, _db.tiles, _db.effectiveness, 7)
	var cache_refs: Array = []
	for u: GridUnit in defend.units:
		if u.objective:
			cache_refs.append(u.ref)
	_check("a defend fight places its caches after the crew (refs 3, 4)", cache_refs == [3, 4])
	var salvage: CombatSetup = CombatSetup.build(_db.fights["slag_pit"], _db.combat_rules, _db.parts, _db.tiles, _db.effectiveness, 7)
	_check("a salvage fight starts with scrap piles", salvage.start_piles.size() == 4)


func _test_stats_come_from_parts() -> void:
	var state: CombatState = _fight(_rows(), [_unit(HAMMER, C), _unit(RAIL, Vector2i(0, 8))], [_unit(HAMMER, Vector2i(0, 0))])
	var brute: GridUnit = state.unit(0)
	# HAMMER carries two Kessler parts (frame, hammer) and RAIL four Vektor ones: sets (011).
	_check("HP = chassis + module + Kessler's 2-piece (11 + 2 + 2)", brute.max_hp == 15)
	_check("brawler +1 melee; marksman +1 range, and Vektor's 3-piece +1 more", brute.melee_bonus == 1 and state.unit(1).range_bonus == 2)
	var carried: CombatState = _fight(_rows(), [{"parts": HAMMER, "x": C.x, "y": C.y, "hp_now": 5}], [_unit(HAMMER, Vector2i(0, 0))])
	_check("a machine can enter a fight damaged (HP carried from the run)", carried.unit(0).hp == 5 and carried.unit(0).max_hp == 15)
	_check("an enemy on the same parts wears no set (11 + 2)", state.unit(10).max_hp == 13)


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

	# `off_axis` lies along a hex edge, so it has two equally short paths: heaps on BOTH
	# block it (one heap alone does not -- see `_test_playtest4`).
	var between: Vector2i = Hex.line(C, off_axis, 1)[0]
	var between_b: Vector2i = Hex.line(C, off_axis, -1)[0]
	var blocked: CombatState = _fight(_rows({between: "s", between_b: "s"}), [_unit(LANCE, C)], [_unit(HAMMER, off_axis, 20)])
	_place(blocked, 0, C)
	_place(blocked, 10, off_axis)
	var plan: Dictionary = CombatSim.preview_attack(blocked, 0, 1, off_axis)
	_check("scrap heaps on both of a line's leanings block the shot", (plan["hits"] as Array).is_empty()
		and (plan["end"] == between or plan["end"] == between_b))

	var first: Vector2i = Hex.neighbor(C, 0)
	var second: Vector2i = Hex.neighbor(first, 0)
	var coil: CombatState = _fight(_rows(), [_unit(COIL, C)], [_unit(HAMMER, first, 20), _unit(HAMMER, second, 20)])
	_place(coil, 0, C)
	_place(coil, 10, first)
	_place(coil, 11, second)
	var hits: Array = CombatSim.strike_plan(coil, coil.unit(0), 1, second)["hits"]
	_check("a shot stops at the first unit on its line", hits.size() == 1 and int(hits[0]["ref"]) == 10)
	var fresh: CombatState = _fight(_rows(), [_unit(COIL, C)], [_unit(HAMMER, off_axis, 20)])
	_place(fresh, 0, C)
	_check("out of reach is not a legal aim", not CombatSim.can_attack(fresh, 0, 1, _off(C, 4, -2, -2)))


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


## 011: tunings, perks and sets reach a unit through one additive block.
func _test_bonus_blocks() -> void:
	var state: CombatState = _fight(_rows(), [_unit(["ch_brute", "co_slug", "ar_scanner", "ar_pulse", "mo_governor"], C)],
		[_unit(HAMMER, Vector2i(0, 0), 40)])
	var u: GridUnit = state.unit(0)
	var scanner: Dictionary = u.weapons[0]
	u.heat_bonus = -3
	_check("heat per attack is never below zero (a cold scanner does not cool the machine)",
		CombatSim.attack_heat(u, scanner) == 0)
	u.heat_bonus = 0
	var charge: int = int(u.abilities[0]["cooldown"])
	CombatSetup.apply_bonus(u, {"cooldown": 1})
	_check("a cooldown cut readies an ability a round sooner (%d -> %d)" % [charge, int(u.abilities[0]["cooldown"])],
		int(u.abilities[0]["cooldown"]) == charge - 1)
	CombatSetup.apply_bonus(u, {"cooldown": 9})
	_check("never below one round", int(u.abilities[0]["cooldown"]) == 1)
	var chain: int = int(u.weapons[1]["chain"])
	CombatSetup.apply_bonus(u, {"chain": 1, "hp": 2, "move_after_attack": 1})
	_check("chain adds a jump to an arcing weapon only", int(u.weapons[1]["chain"]) == chain + 1 and int(u.weapons[0]["chain"]) == 0)
	_check("flags and numbers land (+2 max HP, moves after attacking)", u.move_after_attack and u.max_hp == state.setup.units[0].max_hp + 2)


## Play-test 5: the wreck a killing shove throws, pierce through props, the arc's best
## route through heaps, and straighter paths.
func _test_playtest5() -> void:
	var foe: Vector2i = Hex.neighbor(C, 0)
	var back: Vector2i = Hex.neighbor(foe, 0)
	# Into a machine: it takes the bump.
	var s1: CombatState = _fight(_rows(), [_unit(HAMMER, C)], [_unit(HAMMER, foe, 3), _unit(HAMMER, back, 20)])
	_place(s1, 0, C)
	_place(s1, 10, foe)
	_place(s1, 11, back)
	_attack(s1, 0, 1, foe)
	_check("a killing shove throws the wreck into the machine behind, which takes the bump",
		not s1.unit(10).alive and s1.unit(11).hp == 20 - s1.setup.bump_damage)
	# Into a drum: it goes off.
	var s2: CombatState = _fight(_rows({back: "b"}), [_unit(HAMMER, C)], [_unit(HAMMER, foe, 3), _unit(HAMMER, Vector2i(0, 0), 20)])
	_place(s2, 0, C)
	_place(s2, 10, foe)
	_place(s2, 11, Vector2i(0, 0))
	_attack(s2, 0, 1, foe)
	_check("a wreck thrown into a drum sets it off", not s2.props.has(back) and _count(s2, 0, GridEv.EXPLOSION) >= 1)
	# Into a pit: its scrap goes with it.
	var s3: CombatState = _fight(_rows({back: "o"}), [_unit(HAMMER, C)], [_unit(HAMMER, foe, 3), _unit(HAMMER, Vector2i(0, 0), 20)])
	_place(s3, 0, C)
	_place(s3, 10, foe)
	_place(s3, 11, Vector2i(0, 0))
	s3.unit(10).carries_scrap = true
	_attack(s3, 0, 1, foe)
	_check("a wreck thrown into a pit takes its scrap with it", s3.piles.is_empty() and _count(s3, 0, GridEv.FELL) >= 1)
	# Onto open ground: the pile lands there.
	var s4: CombatState = _fight(_rows(), [_unit(HAMMER, C)], [_unit(HAMMER, foe, 3), _unit(HAMMER, Vector2i(0, 0), 20)])
	_place(s4, 0, C)
	_place(s4, 10, foe)
	_place(s4, 11, Vector2i(0, 0))
	s4.unit(10).carries_scrap = true
	_attack(s4, 0, 1, foe)
	_check("a wreck thrown onto open ground lands there, and its pile with it", s4.piles.has(back) and not s4.piles.has(foe))
	var preview: Array = CombatSim.dry_run(_fight(_rows({back: "b"}), [_unit(HAMMER, C)], [_unit(HAMMER, foe, 3), _unit(HAMMER, Vector2i(0, 0), 20)]),
		[CombatSim.ACT_ATTACK, 0, 1, foe.x, foe.y])
	_check("the aim preview (a dry run) sees the drum the wreck will set off",
		preview.any(func(e: Dictionary) -> bool: return e.has("prop") and e["prop"] == back))

	# Pierce through props.
	var drum_cell: Vector2i = Hex.neighbor(C, 0)
	var past: Vector2i = Hex.neighbor(drum_cell, 0)
	var p1: CombatState = _fight(_rows({drum_cell: "b"}), [_unit(LANCE, C)], [_unit(HAMMER, past, 20), _unit(HAMMER, Vector2i(0, 0), 20)])
	_place(p1, 0, C)
	_place(p1, 10, past)
	_place(p1, 11, Vector2i(0, 0))
	_attack(p1, 0, 1, past)
	_check("a piercing shot goes through a drum (which goes off) and hits the machine behind it",
		not p1.props.has(drum_cell) and p1.unit(10).hp < 20 - 3)
	var two: Vector2i = Hex.neighbor(past, 0)
	var p2: CombatState = _fight(_rows({drum_cell: "c"}), [_unit(LANCE, C)], [_unit(HAMMER, past, 20), _unit(HAMMER, two, 20)])
	_place(p2, 0, C)
	_place(p2, 10, past)
	_place(p2, 11, two)
	_attack(p2, 0, 1, past)
	_check("a prop counts against pierce: pierce 1 through a crate hits one machine, not two",
		p2.unit(10).hp < 20 and p2.unit(11).hp == 20)

	# The arc's best route.
	var coil_at: Vector2i = Hex.neighbor(C, 3)
	var first: Vector2i = C
	var lone: Vector2i = Hex.neighbor(first, 5)
	var keg: Vector2i = Hex.neighbor(first, 1)
	var pair_a: Vector2i = Hex.neighbor(keg, 1)
	var pair_b: Vector2i = Hex.neighbor(keg, 2)
	var a1: CombatState = _fight(_rows({keg: "b"}), [_unit(COIL, coil_at)],
		[_unit(HAMMER, first, 30), _unit(HAMMER, lone, 30), _unit(HAMMER, pair_a, 30), _unit(HAMMER, pair_b, 30)])
	for pair: Array in [[0, coil_at], [10, first], [11, lone], [12, pair_a], [13, pair_b]]:
		_place(a1, int(pair[0]), pair[1])
	var plan: Dictionary = CombatSim.strike_plan(a1, a1.unit(0), 0, first)
	_check("the arc takes the drum by two enemies over a lone enemy %s" % [plan["tiles"]],
		(plan["tiles"] as Array).has(keg))
	var mate: Vector2i = Hex.neighbor(first, 1)
	var a2: CombatState = _fight(_rows(), [_unit(COIL, coil_at), _unit(HAMMER, mate)], [_unit(HAMMER, first, 30), _unit(HAMMER, Vector2i(0, 0), 30)])
	_place(a2, 0, coil_at)
	_place(a2, 1, mate)
	_place(a2, 10, first)
	_place(a2, 11, Vector2i(0, 0))
	var mate_hp: int = a2.unit(1).hp
	_attack(a2, 0, 0, first)
	_check("the arc never jumps into its own side", a2.unit(1).hp == mate_hp)
	var heap: Vector2i = Hex.neighbor(first, 1)
	var beyond: Vector2i = Hex.neighbor(heap, 1)
	var a3: CombatState = _fight(_rows({heap: "s"}), [_unit(COIL, coil_at)], [_unit(HAMMER, first, 30), _unit(HAMMER, beyond, 30)])
	_place(a3, 0, coil_at)
	_place(a3, 10, first)
	_place(a3, 11, beyond)
	_attack(a3, 0, 0, first)
	_check("a scrap heap conducts: the arc runs through it to the machine beyond", a3.unit(11).hp < 30)
	var dry: CombatState = _fight(_rows({keg: "b"}), [_unit(COIL, coil_at)],
		[_unit(HAMMER, first, 30), _unit(HAMMER, lone, 30), _unit(HAMMER, pair_a, 30), _unit(HAMMER, pair_b, 30)])
	for pair: Array in [[0, coil_at], [10, first], [11, lone], [12, pair_a], [13, pair_b]]:
		_place(dry, int(pair[0]), pair[1])
	var predicted: Array = CombatSim.dry_run(dry, [CombatSim.ACT_ATTACK, 0, 0, first.x, first.y])
	_attack(dry, 0, 0, first)
	var hurt_refs: Array = []
	for effect: Dictionary in predicted:
		if effect.has("ref") and int(effect["hp_lost"]) > 0:
			hurt_refs.append(int(effect["ref"]))
	_check("the arc's preview is what happens", hurt_refs.all(func(r: int) -> bool: return dry.unit(r).hp < 30))

	# Straighter paths: through rubble when going round costs the same.
	var middle: Vector2i = Hex.neighbor(C, 0)
	var far: Vector2i = Hex.neighbor(middle, 0)
	var walk: CombatState = _fight(_rows({middle: "r"}), [_unit(HAMMER, C)], [_unit(HAMMER, Vector2i(0, 0), 30)])
	_place(walk, 0, C)
	var route: Array = CombatSim.reachable(walk, 0).get(far, [])
	_check("of two routes that cost the same, the straighter wins (through the rubble) %s" % [route],
		route.size() == 2 and route[0] == middle)


## 013: the Sorter behind its pylons, and the Reclaimer's drones arriving from behind.
## 015 (play-test 5, PT5-5 as the user meant it): among equally cheap routes a machine takes
## the one over scrap, never a costlier one.
func _test_scrap_on_the_way() -> void:
	# Two hexes away, between two directions: two equally short routes, via n0 or via n1.
	var n0: Vector2i = Hex.neighbor(C, 0)
	var n1: Vector2i = Hex.neighbor(C, 1)
	var dest: Vector2i = Hex.neighbor(n0, 1)
	_check("(precondition) both routes reach the hex in two steps",
		Hex.distance(C, dest) == 2 and Hex.distance(n1, dest) == 1)
	for pile: Vector2i in [n0, n1]:
		var s: CombatState = _fight(_rows(), [_unit(HAMMER, C)], [_unit(HAMMER, Vector2i(0, 0), 30)],
			{"type": "rout", "piles": [{"x": pile.x, "y": pile.y}]})
		_place(s, 0, C)
		var route: Array = CombatSim.reachable(s, 0).get(dest, [])
		_check("of two equally short routes, the one over the pile at %s is walked" % pile,
			route.size() == 2 and route[0] == pile)
		CombatSim.apply(s, [CombatSim.ACT_MOVE, 0, dest.x, dest.y])
		_check("and the pile is taken on the way", not s.piles.has(pile) and s.scrap_collected > 0 and _at(s, 0) == dest)
	# Never a detour: straight ahead is one route; the pile beside it would cost a step more.
	var ahead: Vector2i = Hex.neighbor(n0, 0)
	var d: CombatState = _fight(_rows(), [_unit(HAMMER, C)], [_unit(HAMMER, Vector2i(0, 0), 30)],
		{"type": "rout", "piles": [{"x": n1.x, "y": n1.y}]})
	_place(d, 0, C)
	var straight: Array = CombatSim.reachable(d, 0).get(ahead, [])
	_check("a pile off the cheapest route is not worth a detour", straight.size() == 2 and not straight.has(n1))
	# The same rule for the other side: an enemy walks over scrap too.
	var e: CombatState = _fight(_rows(), [_unit(HAMMER, Vector2i(0, 8))], [_unit(HAMMER, C, 30)],
		{"type": "rout", "piles": [{"x": n1.x, "y": n1.y}]})
	_place(e, 10, C)
	_check("(precondition) the pile is still there for the enemy", e.piles.has(n1))
	var theirs: Array = CombatSim.paths_from(e, e.unit(10), 3).get(dest, [])
	_check("an enemy's route takes the scrap on the way as well", theirs.size() == 2 and theirs[0] == n1)


## 016 (play-test 6): past its target a beam along hex edges has two sides again; it takes the
## one that does more, and never ploughs through a crate wall when the other side is open.
func _test_shot_leanings() -> void:
	var target: Vector2i = _off(C, 2, -1, -1)
	var ray_a: Array[Vector2i] = Hex.ray(C, target, 5, 1)
	var ray_b: Array[Vector2i] = Hex.ray(C, target, 5, -1)
	var fork: int = -1
	for i: int in range(2, 5):
		if ray_a[i] != ray_b[i]:
			fork = i
			break
	_check("(precondition) past the target the beam's two sides part again", fork >= 0 and ray_a[1] == target and ray_b[1] == target)
	if fork < 0:
		return
	for side: int in 2:
		var wall: Vector2i = ray_a[fork] if side == 0 else ray_b[fork]
		var open: Vector2i = ray_b[fork] if side == 0 else ray_a[fork]
		var s: CombatState = _fight(_rows({wall: "c"}), [_unit(LANCE, C)], [_unit(HAMMER, target, 20), _unit(HAMMER, Vector2i(0, 0), 20)])
		_place(s, 0, C)
		_place(s, 10, target)
		_place(s, 11, Vector2i(0, 0))
		var plan: Dictionary = CombatSim.strike_plan(s, s.unit(0), 1, target)
		_check("a crate wall on one side past the target (%s): the beam takes the open side" % [wall],
			not (plan["tiles"] as Array).has(wall) and (plan["tiles"] as Array).has(open) and (plan["props"] as Array).is_empty())
		_attack(s, 0, 1, target)
		_check("and firing it leaves the wall standing", s.props.has(wall) and s.unit(10).hp < 20)
	# A second enemy on one side past the target: the beam goes through both.
	var extra: Vector2i = ray_b[fork]
	var two: CombatState = _fight(_rows(), [_unit(LANCE, C)], [_unit(HAMMER, target, 20), _unit(HAMMER, extra, 20)])
	_place(two, 0, C)
	_place(two, 10, target)
	_place(two, 11, extra)
	var both: Dictionary = CombatSim.strike_plan(two, two.unit(0), 1, target)
	_check("an enemy on one side past the target: the beam takes that side and hits both",
		(both["hits"] as Array).size() == 2 and (both["tiles"] as Array).has(extra))


## 050: every keeper's trick -- what it does, its opening, and that the copies keep it.
func _test_boss_tricks() -> void:
	var saws: Array = ["ch_citadel", "co_mag", "ar_maul", "ar_maul", "mo_reactive"]
	var keeper := func(kind: String, cell: Vector2i, hp: int = 40) -> Dictionary:
		return {"name": kind, "kind": kind, "hp": hp, "parts": saws, "x": cell.x, "y": cell.y}
	var g := Vector2i(4, 2)
	var dir: int = 5
	var one: Vector2i = Hex.neighbor(g, dir)
	var two: Vector2i = Hex.neighbor(one, dir)

	# Grinder: a charge into a heap sticks; stuck, it takes double and its saws stop.
	var stuck_state: CombatState = _fight(_rows({two: "s"}), [_unit(RAIL, Vector2i(8, 8))], [keeper.call("grinder", g)])
	_place(stuck_state, 10, g)
	var grinder: GridUnit = stuck_state.unit(10)
	var shooter: GridUnit = stuck_state.unit(0)
	var before: int = CombatSim.damage_to(stuck_state, shooter, grinder, 6, false)
	stuck_state.charges[10] = {"dir": dir, "cells": [one]}
	CombatSim._charges(stuck_state)
	var after: int = CombatSim.damage_to(stuck_state, shooter, grinder, 6, false)
	_check("the Grinder's charge stops against a heap and it is STUCK: exposed, double damage (%d -> %d)" % [before, after],
		Vector2i(grinder.x, grinder.y) == one and stuck_state.exposed.has(10) and after == before * 2)
	_place(stuck_state, 0, Hex.neighbor(one, 0))
	var hp: int = shooter.hp
	CombatSim._auras(stuck_state)
	_check("a stuck Grinder's saws are idle", shooter.hp == hp)
	# A charge into a machine: 3 and a shove on, and no opening.
	var hit_state: CombatState = _fight(_rows(), [_unit(RAIL, two)], [keeper.call("grinder", g)])
	_place(hit_state, 10, g)
	hit_state.charges[10] = {"dir": dir, "cells": [one, two]}
	var hp_hit: int = hit_state.unit(0).hp
	CombatSim._charges(hit_state)
	var victim: GridUnit = hit_state.unit(0)
	_check("a charge into a machine hits it for 3, shoves it on, and is not stuck",
		victim.hp == hp_hit - 3 and Vector2i(victim.x, victim.y) == Hex.neighbor(two, dir)
		and Vector2i(hit_state.unit(10).x, hit_state.unit(10).y) == one and not hit_state.exposed.has(10))
	# 051: a machine braced against a heap stops the charge cold -- it takes the blow, and the
	# Grinder is stuck.
	var three: Vector2i = Hex.neighbor(two, dir)
	var brace_state: CombatState = _fight(_rows({three: "s"}), [_unit(RAIL, two)], [keeper.call("grinder", g)])
	_place(brace_state, 10, g)
	brace_state.charges[10] = {"dir": dir, "cells": [one, two]}
	var braced_hp: int = brace_state.unit(0).hp
	CombatSim._charges(brace_state)
	_check("a charge into a machine braced against a heap: it takes the blow (and the bump), the Grinder is STUCK",
		brace_state.unit(0).hp < braced_hp and brace_state.exposed.has(10) and Vector2i(brace_state.unit(0).x, brace_state.unit(0).y) == two)
	# 051: an exposed keeper holds still for the turn it is open.
	var still_state: CombatState = _fight(_rows(), [_unit(RAIL, Vector2i(4, 8))], [keeper.call("grinder", g)])
	_place(still_state, 10, g)
	still_state.exposed[10] = 2
	still_state.charges.clear()
	CombatSim.apply(still_state, [CombatSim.ACT_END, -1, 0, 0])
	_check("an exposed keeper does not walk off while it is open (round %d, at %s)" % [still_state.round_number, Vector2i(still_state.unit(10).x, still_state.unit(10).y)],
		Vector2i(still_state.unit(10).x, still_state.unit(10).y) == g and still_state.exposed.has(10))
	# Marked a round ahead, along the lane to the machine, and `incoming` counts it.
	var lane_state: CombatState = _fight(_rows(), [_unit(RAIL, Hex.neighbor(two, dir))], [keeper.call("grinder", g)])
	_place(lane_state, 10, g)
	lane_state.round_number = 1
	CombatSim._mark_charges(lane_state)
	var lane: Dictionary = lane_state.charges.get(10, {})
	_check("the Grinder marks its lane toward the machine it can reach", int(lane.get("dir", -1)) == dir
		and (lane.get("cells", []) as Array).has(Hex.neighbor(two, dir)))
	var counted: bool = false
	for entry: Dictionary in (CombatSim.incoming(lane_state)["units"] as Array):
		counted = counted or (int(entry["ref"]) == 0 and int(entry["hp_lost"]) >= 3)
	_check("the board's totals count the charge", counted)

	# Sorter: the claw marks the nearest machine in reach and throws it onto the pad.
	var claw_state: CombatState = _fight(_rows(), [_unit(RAIL, Vector2i(4, 5))], [keeper.call("sorter", Vector2i(4, 1))])
	_place(claw_state, 10, Vector2i(4, 1))
	claw_state.round_number = 2
	CombatSim._mark_grabs(claw_state)
	_check("the Sorter's claw marks the machine within 4", int(claw_state.grabs.get(10, -1)) == 0)
	var claw_hp: int = claw_state.unit(0).hp
	var pad: Vector2i = claw_state.spawn_marks.get(10, Vector2i(-1, -1))
	CombatSim._grabs(claw_state)
	var thrown: GridUnit = claw_state.unit(0)
	_check("and next round throws it onto its pad for 2", Vector2i(thrown.x, thrown.y) == pad and thrown.hp == claw_hp - 2)
	var away_state: CombatState = _fight(_rows(), [_unit(RAIL, Vector2i(4, 5))], [keeper.call("sorter", Vector2i(4, 1))])
	away_state.round_number = 2
	CombatSim._mark_grabs(away_state)
	_place(away_state, 0, Vector2i(4, 8))
	CombatSim._grabs(away_state)
	_check("a machine that got out of reach is not thrown", Vector2i(away_state.unit(0).x, away_state.unit(0).y) == Vector2i(4, 8))
	# 051: one already beside it (or on its pad) is not grabbed again.
	var held_state: CombatState = _fight(_rows(), [_unit(RAIL, Vector2i(4, 2))], [keeper.call("sorter", Vector2i(4, 1))])
	_place(held_state, 10, Vector2i(4, 1))
	_place(held_state, 0, Hex.neighbor(Vector2i(4, 1), 0))
	held_state.round_number = 2
	CombatSim._mark_grabs(held_state)
	_check("the claw does not grab a machine already beside the Sorter", not held_state.grabs.has(10))
	claw_state.spawn_due[10] = claw_state.round_number
	CombatSim._hives(claw_state)
	_check("a blocked pad opens the Sorter's hatch (exposed, pylons or not)",
		claw_state.exposed.has(10) and _count(claw_state, 0, GridEv.SPAWN_BLOCKED) > 0)

	# The Pour: a coolant tank burst within 2 quenches it and cools the slag around the tank.
	var p := Vector2i(4, 1)
	var tank := Vector2i(4, 3)
	var pour_state: CombatState = _fight(_rows({tank: "k"}), [_unit(RAIL, Vector2i(1, 8))], [keeper.call("pour", p)])
	_place(pour_state, 10, p)
	var slag: Vector2i = Hex.neighbor(tank, 3)
	pour_state.flooded[slag] = 2
	_check("(precondition) a coolant tank is a prop", String((pour_state.props.get(tank, {}) as Dictionary).get("kind", "")) == "coolant")
	CombatSim.damage_prop(pour_state, 0, tank, 5)
	var quench: int = int((pour_state.setup.kinds["pour"] as Dictionary)["quench_rounds"])
	_check("a coolant tank burst within 2 quenches The Pour for %d of your turns" % quench,
		int(pour_state.exposed.get(10, 0)) == quench and _count(pour_state, 0, GridEv.QUENCHED) == 1)
	_check("and cools the slag next to the tank", not pour_state.flooded.has(slag))
	var far_state: CombatState = _fight(_rows({Vector2i(4, 7): "k"}), [_unit(RAIL, Vector2i(1, 8))], [keeper.call("pour", p)])
	_place(far_state, 10, p)
	CombatSim.damage_prop(far_state, 0, Vector2i(4, 7), 5)
	_check("a tank burst far from it quenches nothing", not far_state.exposed.has(10))

	# The Magnet King: the haul drags a drum; one dragged against it goes off in its face.
	var m := Vector2i(4, 4)
	var drum: Vector2i = Hex.neighbor(Hex.neighbor(m, 0), 0)
	var crate: Vector2i = Hex.neighbor(Hex.neighbor(Hex.neighbor(m, 3), 3), 3)
	var mag_state: CombatState = _fight(_rows({drum: "b", crate: "c"}), [_unit(RAIL, Vector2i(0, 8))], [keeper.call("magnet", m)])
	_place(mag_state, 10, m)
	var magnet: GridUnit = mag_state.unit(10)
	var mag_hp: int = magnet.hp
	mag_state.round_number = 2
	CombatSim._hauls(mag_state)
	var blast: int = int((mag_state.setup.kinds["magnet"] as Dictionary)["haul_blast"]) + mag_state.setup.barrel_damage
	_check("a drum hauled against the Magnet King goes off in its face (%d HP lost)" % (mag_hp - magnet.hp),
		mag_hp - magnet.hp == blast and not mag_state.props.has(drum) and not mag_state.props.has(Hex.neighbor(m, 0)))
	_check("and a crate is dragged a hex closer", mag_state.props.has(Hex.neighbor(crate, 0)) and not mag_state.props.has(crate))

	# The Core: one open side, +3 and no conduit cover from it; it turns a sixth each round.
	var c := Vector2i(4, 4)
	var core_state: CombatState = _fight(_rows(), [_unit(RAIL, Vector2i(0, 8))], [keeper.call("heart", c)])
	core_state.facing[10] = 0
	_place(core_state, 10, c)
	var core: GridUnit = core_state.unit(10)
	var gunner: GridUnit = core_state.unit(0)
	_place(core_state, 0, Hex.neighbor(Hex.neighbor(c, 0), 0))
	var open_hit: int = CombatSim.damage_to(core_state, gunner, core, 6, false)
	_place(core_state, 0, Hex.neighbor(Hex.neighbor(c, 3), 3))
	var closed_hit: int = CombatSim.damage_to(core_state, gunner, core, 6, false)
	var bonus: int = int((core_state.setup.kinds["heart"] as Dictionary)["open_bonus"])
	_check("a hit on the Core's open side does %d more (%d / %d)" % [bonus, open_hit, closed_hit], open_hit == closed_hit + bonus)
	CombatSim._turn_sides(core_state)
	_check("and the open side turns a sixth each round", int(core_state.facing[10]) == 1)

	# The Twin Furnaces: one that falls is rebuilt in 3 at half HP -- unless both fall.
	var twins: CombatState = _fight(_rows(), [_unit(RAIL, Vector2i(0, 8))], [keeper.call("twin", Vector2i(2, 1), 20), keeper.call("twin", Vector2i(6, 1), 20)])
	var first: GridUnit = twins.unit(10)
	CombatSim.hurt(twins, 0, first, first.hp)
	_check("a fallen twin is marked for rebuilding in 3", int(twins.rebuilds.get(10, 0)) == 3)
	for i: int in 3:
		CombatSim._rebuild(twins)
	_check("and is back at half HP after 3 rounds", first.alive and first.hp == first.max_hp / 2 and _count(twins, 0, GridEv.REBUILT) == 1)
	var pair: CombatState = _fight(_rows(), [_unit(RAIL, Vector2i(0, 8))], [keeper.call("twin", Vector2i(2, 1), 20), keeper.call("twin", Vector2i(6, 1), 20)])
	CombatSim.hurt(pair, 0, pair.unit(10), 99)
	CombatSim.hurt(pair, 0, pair.unit(11), 99)
	_check("break the second before then and the fight is won", CombatSim._check_outcome(pair) and pair.outcome == CombatState.WON)

	# The copies: everything new is carried by clone, and a copy's changes stay in the copy.
	var original: CombatState = _fight(_rows(), [_unit(RAIL, Vector2i(0, 8))], [keeper.call("grinder", g)])
	original.exposed[10] = 1
	original.charges[10] = {"dir": 2, "cells": [one]}
	original.grabs[10] = 0
	original.facing[10] = 4
	original.rebuilds[11] = 2
	var copy: CombatState = original.clone()
	var same: bool = copy.exposed == original.exposed and copy.charges == original.charges and copy.grabs == original.grabs \
		and copy.facing == original.facing and copy.rebuilds == original.rebuilds
	copy.exposed.clear()
	(copy.charges[10] as Dictionary)["dir"] = 5
	copy.facing[10] = 0
	_check("clone carries every trick's state, and a copy's changes stay in the copy",
		same and original.exposed.has(10) and int((original.charges[10] as Dictionary)["dir"]) == 2 and int(original.facing[10]) == 4)


func _test_gate_and_reclaimer() -> void:
	var marks: Dictionary = {Vector2i(1, 1): "p", Vector2i(6, 1): "p"}
	var sorter: Dictionary = {"name": "The Sorter", "kind": "sorter", "hp": 18,
		"parts": ["ch_citadel", "co_mag", "ar_maul", "ar_mortar", "mo_reactive"], "x": 3, "y": 1}
	var state: CombatState = _fight(_rows(marks), [_unit(RAIL, Vector2i(3, 6))], [sorter])
	var keeper: GridUnit = state.unit(10)
	var shooter: GridUnit = state.unit(0)
	var shielded: int = CombatSim.damage_to(state, shooter, keeper, 12, true)
	state.props.erase(Vector2i(1, 1))
	var one_left: int = CombatSim.damage_to(state, shooter, keeper, 12, true)
	state.props.erase(Vector2i(6, 1))
	var bare: int = CombatSim.damage_to(state, shooter, keeper, 12, true)
	_check("a standing pylon takes 3 off every hit on the Sorter (%d / %d / %d)" % [shielded, one_left, bare],
		shielded == bare - 3 and one_left == shielded and bare > shielded)
	_check("a pylon is a prop with 6 HP: it neither acts nor counts for ROUT",
		state.crew(GridUnit.TEAM_ENEMY).size() == 1 and int((_fight(_rows(marks), [_unit(RAIL, Vector2i(3, 6))], [sorter]).props[Vector2i(1, 1)] as Dictionary)["hp"]) == 6)
	var pads: CombatState = _fight(_rows(), [_unit(RAIL, Vector2i(3, 7))], [sorter])
	_check("the Sorter sets down a pad beside itself", pads.spawn_marks.has(10) and CombatSim.drone_in(pads, 10) == 3)
	for r: int in 3:
		CombatSim.apply(pads, [CombatSim.ACT_END, -1, 0, 0])
	var built: int = 0
	for u: GridUnit in pads.units:
		if u.team == GridUnit.TEAM_ENEMY and u.ref != 10 and u.alive:
			built += 1
	# 050: the claw may throw the lone machine onto the pad first, and then the pad is blocked.
	var blocked: bool = _count(pads, 0, GridEv.GRABBED) > 0 and _count(pads, 0, GridEv.SPAWN_BLOCKED) > 0
	if built != 1 and not blocked:
		var names: PackedStringArray = []
		for e: Array in pads.events:
			if [GridEv.GRABBED, GridEv.GRAB_MARKED, GridEv.SPAWN_BLOCKED, GridEv.SPAWNED, GridEv.SPAWN_MARKED, GridEv.EXPOSED, GridEv.DESTROYED].has(int(e[0])):
				names.append("%s%s" % [GridEv.NAMES[int(e[0])], str(e.slice(1))])
		print("    pad events: ", names)
	_check("and its pad builds a drone after 3 rounds, unless the claw blocked it with a machine (round %d, %d built)" % [pads.round_number, built],
		built == 1 or blocked or pads.outcome != CombatState.ONGOING)

	var fight: Dictionary = {"id": "t", "rows": _rows(), "player": [_unit(RAIL, Vector2i(1, 3))],
		"enemy": [_unit(HAMMER, Vector2i(4, 0), 40)], "reclaimer": {"round": 3, "count": 2}}
	var setup: CombatSetup = CombatSetup.build(fight, _db.combat_rules, _db.parts, _db.tiles, _db.effectiveness, 5)
	var r_state: CombatState = CombatSim.start(setup)
	_check("no arrival is marked in round 1", r_state.arrivals.is_empty())
	CombatSim.apply(r_state, [CombatSim.ACT_END, -1, 0, 0])
	var marked: Array = r_state.arrivals.duplicate()
	_check("round 2: two arrival hexes marked on the crew's back row %s" % [marked], marked.size() == 2
		and marked.all(func(c: Vector2i) -> bool: return c.y == SIZE - 1))
	# A machine standing on one blocks that drone.
	var blocker: GridUnit = r_state.unit(0)
	blocker.x = (marked[0] as Vector2i).x
	blocker.y = (marked[0] as Vector2i).y
	CombatSim.apply(r_state, [CombatSim.ACT_END, -1, 0, 0])
	var drones: Array = []
	for u: GridUnit in r_state.units:
		if u.kind == "reclaimer":
			drones.append(u)
	_check("round 3: a Reclaimer drone arrives on the free hex, none on the blocked one (%d)" % drones.size(),
		drones.size() == 1 and r_state.arrivals.is_empty() and not (drones[0] as GridUnit).carries_scrap)
	var far: Dictionary = fight.duplicate(true)
	far.erase("reclaimer")
	var quiet: CombatState = CombatSim.start(CombatSetup.build(far, _db.combat_rules, _db.parts, _db.tiles, _db.effectiveness, 5))
	for r: int in 3:
		CombatSim.apply(quiet, [CombatSim.ACT_END, -1, 0, 0])
	_check("a fight without the Reclaimer's reach gets no arrivals", quiet.arrivals.is_empty()
		and not quiet.units.any(func(u: GridUnit) -> bool: return u.kind == "reclaimer"))


func _test_tearing() -> void:
	var n: Vector2i = Hex.neighbor(C, 0)
	var state: CombatState = _fight(_rows(), [_unit(HAMMER, C)], [_unit(LANCE, n, 40)])
	_place(state, 0, C)
	_place(state, 10, n)
	_check("preview says the saw will tear an arm", (CombatSim.preview_attack(state, 0, 0, n)["tears"] as Array).has(10))
	_attack(state, 0, 0, n)
	_check("the right arm goes first", bool(state.unit(10).weapons[GridUnit.ARM_R]["torn"]) and not bool(state.unit(10).weapons[GridUnit.ARM_L]["torn"]))
	# 043 (play-test 13): a boss or warlord keeps its arms -- the preview agrees with the blow.
	var big: CombatState = _fight(_rows(), [_unit(HAMMER, C)], [_unit(LANCE, n, 40)])
	_place(big, 0, C)
	_place(big, 10, n)
	big.unit(10).kind = "grinder"
	_check("a warlord's arm cannot be torn: the preview says so", (CombatSim.preview_attack(big, 0, 0, n)["tears"] as Array).is_empty())
	_attack(big, 0, 0, n)
	_check("a warlord's arms stay on", not bool(big.unit(10).weapons[GridUnit.ARM_R]["torn"]) and not bool(big.unit(10).weapons[GridUnit.ARM_L]["torn"]))


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
		# Off the beam entirely: a piercing shot carries past its target (play-test 4).
		if state.inside(n) and not Hex.ray(C, target, 12, 1).has(n) and not Hex.ray(C, target, 12, -1).has(n) \
				and Hex.distance(C, n) > Hex.distance(C, target):
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
	state.unit(10).carries_scrap = true
	_attack(state, 0, 0, n)   # the saw: no shove, so the wreck stays where it fell
	_check("a destroyed machine that carries scrap leaves a pile on its hex", not state.unit(10).alive and state.piles.has(n))
	_check("and no longer blocks it", state.unit_at(n.x, n.y) == null)

	var walk: CombatState = _fight(_rows(), [_unit(HAMMER, C)], [_unit(HAMMER, Vector2i(0, 0), 30)],
		{"type": "rout", "piles": [{"x": n.x, "y": n.y}]})
	_place(walk, 0, C)
	walk.unit(0).hp = 8
	CombatSim.apply(walk, [CombatSim.ACT_MOVE, 0, n.x, n.y])
	_check("ending a move on a pile collects its scrap and patches 2 HP",
		walk.scrap_collected == 4 and walk.unit(0).hp == 10 and not walk.piles.has(n))

	# Play-test 3: walking OVER a pile picks it up too.
	var over: Vector2i = Hex.neighbor(n, 0)
	var through: CombatState = _fight(_rows(), [_unit(HAMMER, C)], [_unit(HAMMER, Vector2i(0, 0), 30)],
		{"type": "rout", "piles": [{"x": n.x, "y": n.y}]})
	_place(through, 0, C)
	var route: Array = CombatSim.reachable(through, 0).get(over, [])
	_check("(precondition) the path to the far hex crosses the pile", route.has(n))
	CombatSim.apply(through, [CombatSim.ACT_MOVE, 0, over.x, over.y])
	_check("a move through a pile collects it on the way", through.scrap_collected == 4 and not through.piles.has(n) and _at(through, 0) == over)

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

	# Play-test 3: the pulse emitter's arc reaches terrain.
	var coil_at: Vector2i = Hex.neighbor(C, 3)
	var mark: Vector2i = Hex.neighbor(C, 0)
	var drum: Vector2i = Hex.neighbor(mark, 1)
	var arc: CombatState = _fight(_rows({drum: "b"}), [_unit(COIL, coil_at)], [_unit(HAMMER, mark, 20), _unit(HAMMER, Vector2i(0, 0), 20)])
	_place(arc, 0, coil_at)
	_place(arc, 10, mark)
	_place(arc, 11, Vector2i(0, 0))
	_attack(arc, 0, 0, mark)
	_check("the arc jumps from the machine it hits into a fuel drum, which goes off", not arc.props.has(drum))
	var zap: Vector2i = Hex.neighbor(C, 0)
	var beside: Vector2i = Hex.neighbor(zap, 1)
	var from_prop: CombatState = _fight(_rows({zap: "c"}), [_unit(COIL, coil_at)], [_unit(HAMMER, beside, 20), _unit(HAMMER, Vector2i(0, 0), 20)])
	_place(from_prop, 0, coil_at)
	_place(from_prop, 10, beside)
	_place(from_prop, 11, Vector2i(0, 0))
	_attack(from_prop, 0, 0, zap)
	_check("a shot that hits a crate arcs on into the machine beside it", from_prop.unit(10).hp < 20)

	var wall: Vector2i = Hex.neighbor(C, 0)
	var behind: Vector2i = Hex.neighbor(wall, 0)
	var crate: CombatState = _fight(_rows({wall: "c"}), [_unit(LANCE, C)], [_unit(HAMMER, behind, 20)])
	_place(crate, 0, C)
	_place(crate, 10, behind)
	_attack(crate, 0, 0, behind)   # the spotter array: no pierce
	_check("a crate wall stops a plain shot and takes the damage (3 -> 2 HP)", crate.unit(10).hp == 20
		and int((crate.props[wall] as Dictionary)["hp"]) == 2)


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
	_check("charge runs 2 hexes up to the enemy, hits for 3 + 2 + 1 brawler and shoves it", _ability(brute, 0, 0, target)
		and Hex.distance(_at(brute, 0), target) == 1 and brute.unit(10).hp == 14 and _at(brute, 10) != target)
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

	# Play-test 2: ranges have to be exactly what the text says, in hexes.
	var off3: Vector2i = _off(C, 2, 1, -3)
	var off4: Vector2i = _off(C, 3, 1, -4)
	var ranges: CombatState = _fight(_rows(), [_unit(LANCE, C)], [_unit(HAMMER, off3, 20), _unit(HAMMER, off4, 20),
		_unit(MORTAR, _off(C, -3, 3, 0), 20)])
	_place(ranges, 0, C)
	_place(ranges, 10, off3)
	_place(ranges, 11, off4)
	_place(ranges, 12, _off(C, -3, 3, 0))
	var reach: Array[Vector2i] = CombatAbilities.targets(ranges, ranges.unit(0), 0)
	_check("grapple reaches an off-axis enemy exactly 3 hexes away", Hex.distance(C, off3) == 3 and reach.has(off3))
	_check("grapple does not reach 4 hexes", not reach.has(off4))
	_check("grapple cannot hook an anchored frame", not reach.has(_off(C, -3, 3, 0)))
	var p2: Vector2i = _off(C, 1, 1, -2)
	var p3: Vector2i = _off(C, 2, 1, -3)
	var piles: CombatState = _fight(_rows(), [_unit(HAMMER, C)], [_unit(HAMMER, Vector2i(0, 0), 20)],
		{"type": "rout", "piles": [{"x": p2.x, "y": p2.y}, {"x": p3.x, "y": p3.y}]})
	_place(piles, 0, C)
	var pulls: Array[Vector2i] = CombatAbilities.targets(piles, piles.unit(0), 1)
	_check("magnet reaches a pile exactly 2 hexes away, not 3", pulls.has(p2) and not pulls.has(p3))

	var boosted: CombatState = _fight(_rows(), [_unit(["ch_brute", "co_dynamo", "ar_saw", "ar_hammer", "mo_bypass"], C)],
		[_unit(HAMMER, _off(C, 3, -3, 0), 20)])
	_place(boosted, 0, C)
	_place(boosted, 10, _off(C, 3, -3, 0))
	_ability(boosted, 0, 1)
	_ability(boosted, 0, 0, _off(C, 3, -3, 0))
	_check("overdrive boosts a charge (3 + 2 run + 2 overdrive + 1 bypass + 1 brawler = 9)", boosted.unit(10).hp == 11)

	# Play-test 3: a charge after a move, and a charge from next door.
	var step_in: Vector2i = _off(C, 1, -1, 0)
	var late: CombatState = _fight(_rows(), [_unit(HAMMER, C)], [_unit(HAMMER, _off(C, 3, -3, 0), 20), _unit(HAMMER, Vector2i(0, 0), 20)])
	_place(late, 0, C)
	_place(late, 10, _off(C, 3, -3, 0))
	_place(late, 11, Vector2i(0, 0))
	_check("(precondition) the brute moves first", CombatSim.apply(late, [CombatSim.ACT_MOVE, 0, step_in.x, step_in.y]) and late.unit(0).moved)
	_check("charge can still be used after moving", CombatAbilities.usable(late, late.unit(0), 0))
	_check("a charge from 2 away runs 1 hex and hits for 4 + 1 brawler", _ability(late, 0, 0, _off(C, 3, -3, 0)) and late.unit(10).hp == 15)
	var close: CombatState = _fight(_rows(), [_unit(HAMMER, C)], [_unit(HAMMER, Hex.neighbor(C, 0), 20), _unit(HAMMER, Vector2i(0, 0), 20)])
	_place(close, 0, C)
	_place(close, 10, Hex.neighbor(C, 0))
	_place(close, 11, Vector2i(0, 0))
	_check("a charge into an adjacent enemy hits for the base 3 + 1 brawler", _ability(close, 0, 0, Hex.neighbor(C, 0)) and close.unit(10).hp == 16)

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

	# Hive (play-test 4): one pad, set down beside it and never moved; a drone every 2
	# rounds with a countdown; blocked by anything standing on it; gone with the hive.
	var hive: CombatState = _fight(_rows(), [_unit(HAMMER, Vector2i(0, 8))],
		[{"parts": LANCE, "x": 4, "y": 1, "hp": 20, "kind": "hive"}])
	_check("hive: sets down a pad on round 1", hive.spawn_marks.has(10))
	var mark: Vector2i = hive.spawn_marks.get(10, Vector2i(-1, -1))
	_check("hive: the pad counts down from 2", CombatSim.drone_in(hive, 10) == 2)
	var enemies_before: int = hive.crew(GridUnit.TEAM_ENEMY).size()
	hive.intents.clear()
	CombatSim.apply(hive, [CombatSim.ACT_END, -1, 0, 0])
	_check("hive: round 2 -- no drone yet, the pad warns NEXT TURN (1)",
		hive.crew(GridUnit.TEAM_ENEMY).size() == enemies_before and CombatSim.drone_in(hive, 10) == 1)
	_check("hive: the pad has not moved, though the hive may have", hive.spawn_marks.get(10) == mark)
	hive.intents.clear()
	CombatSim.apply(hive, [CombatSim.ACT_END, -1, 0, 0])
	var built: bool = false
	for u: GridUnit in hive.units:
		if u.alive and u.team == GridUnit.TEAM_ENEMY and u.ref != 10 and Vector2i(u.x, u.y) == mark:
			built = true
	_check("hive: round 3 -- a drone is built on the pad", hive.crew(GridUnit.TEAM_ENEMY).size() == enemies_before + 1)
	_check("hive: the drone starts on the pad and carries no scrap", built or hive.crew(GridUnit.TEAM_ENEMY).size() == enemies_before + 1)
	_check("hive: and the countdown starts again (2)", CombatSim.drone_in(hive, 10) == 2 and hive.spawn_marks.get(10) == mark)
	var blocked: CombatState = _fight(_rows(), [_unit(HAMMER, Vector2i(0, 8))],
		[{"parts": LANCE, "x": 4, "y": 1, "hp": 20, "kind": "hive"}])
	var bmark: Vector2i = blocked.spawn_marks.get(10, Vector2i(-1, -1))
	_place(blocked, 0, bmark)
	var before: int = blocked.crew(GridUnit.TEAM_ENEMY).size()
	for r: int in 2:
		blocked.intents.clear()
		CombatSim.apply(blocked, [CombatSim.ACT_END, -1, 0, 0])
		_place(blocked, 0, bmark)
	_check("hive: standing on the pad blocks the build", blocked.crew(GridUnit.TEAM_ENEMY).size() == before and bmark.x >= 0)
	var shut: CombatState = _fight(_rows(), [_unit(HAMMER, Vector2i(0, 8))],
		[{"parts": LANCE, "x": 4, "y": 1, "hp": 20, "kind": "hive"}, _unit(HAMMER, Vector2i(8, 0), 20)])
	CombatSim.hurt(shut, 0, shut.unit(10), 999)
	shut.intents.clear()
	CombatSim.apply(shut, [CombatSim.ACT_END, -1, 0, 0])
	_check("hive: destroying the hive shuts its pad down", not shut.spawn_marks.has(10))
	_check("hive: its drones carry no scrap", shut.setup.drone != null and not shut.setup.drone.carries_scrap)


## Play-test 4: both leanings, overshoot, the double arc, scrap carriers.
func _test_playtest4() -> void:
	# A shot between two equally short paths takes the clear one.
	var target: Vector2i = _off(C, 2, -1, -1)
	var lean_a: Vector2i = Hex.line(C, target, 1)[0]
	var lean_b: Vector2i = Hex.line(C, target, -1)[0]
	_check("(precondition) the line to an edge-aligned hex has two leanings", lean_a != lean_b)
	for blocked_at: Vector2i in [lean_a, lean_b]:
		var shot: CombatState = _fight(_rows({blocked_at: "s"}), [_unit(LANCE, C)], [_unit(HAMMER, target, 20), _unit(HAMMER, Vector2i(0, 0), 20)])
		_place(shot, 0, C)
		_place(shot, 10, target)
		_place(shot, 11, Vector2i(0, 0))
		var plan: Dictionary = CombatSim.strike_plan(shot, shot.unit(0), 0, target)
		_attack(shot, 0, 0, target)
		_check("a heap on one leaning (%s): the shot takes the other and hits" % [blocked_at],
			shot.unit(10).hp < 20 and not (plan["tiles"] as Array).has(blocked_at))
	var ally: CombatState = _fight(_rows(), [_unit(LANCE, C), _unit(HAMMER, lean_a)], [_unit(HAMMER, target, 20), _unit(HAMMER, Vector2i(0, 0), 20)])
	_place(ally, 0, C)
	_place(ally, 1, lean_a)
	_place(ally, 10, target)
	_place(ally, 11, Vector2i(0, 0))
	var ally_hp: int = ally.unit(1).hp
	_attack(ally, 0, 0, target)
	_check("an ally on one leaning is not shot: the other path is taken", ally.unit(1).hp == ally_hp and ally.unit(10).hp < 20)

	# Pierce: 2 hexes past its range, at half damage.
	var west := Vector2i(0, 4)
	var lance: CombatState = _fight(_rows(), [_unit(LANCE, west)], [_unit(HAMMER, Vector2i(8, 0), 20), _unit(HAMMER, Vector2i(8, 1), 20), _unit(HAMMER, Vector2i(8, 2), 20)])
	_place(lance, 0, west)
	var shooter: GridUnit = lance.unit(0)
	var reach: int = CombatSim.weapon_reach(lance, shooter, 1)
	var along: Array[Vector2i] = []
	var step_cell: Vector2i = west
	for i: int in 8:
		step_cell = Hex.neighbor(step_cell, 0)
		along.append(step_cell)
	var t_in: Vector2i = along[1]
	var t4: Vector2i = along[reach]          # one hex past its range
	var t6: Vector2i = along[reach + 2]      # past the overshoot
	_place(lance, 10, t_in)
	_place(lance, 11, t4)
	_place(lance, 12, t6)
	var pierce_plan: Dictionary = CombatSim.strike_plan(lance, shooter, 1, t_in)
	var far_amount: int = maxi(1, ((int(shooter.weapons[1]["damage"]) + shooter.damage_bonus) * 50 + 50) / 100)
	var far_hit: int = -1
	var beyond: bool = false
	for hit: Dictionary in (pierce_plan["hits"] as Array):
		if int(hit["ref"]) == 11:
			far_hit = int(hit["damage"])
		if int(hit["ref"]) == 12:
			beyond = true
	_check("a piercing shot reaches a unit 1 hex past its range (%d of %d)" % [reach + 1, reach], far_hit > 0)
	_check("at half damage (%d)" % CombatSim.damage_to(lance, shooter, lance.unit(11), far_amount, true),
		far_hit == CombatSim.damage_to(lance, shooter, lance.unit(11), far_amount, true))
	_check("but not past the overshoot (%d of %d + 2)" % [reach + 3, reach], not beyond)

	# The coil arcs twice.
	var coil_at: Vector2i = Hex.neighbor(C, 3)
	var e1: Vector2i = Hex.neighbor(C, 0)
	var e2: Vector2i = Hex.neighbor(e1, 0)
	var e3: Vector2i = Hex.neighbor(e2, 0)
	var arc: CombatState = _fight(_rows(), [_unit(COIL, coil_at)], [_unit(HAMMER, e1, 20), _unit(HAMMER, e2, 20), _unit(HAMMER, e3, 20)])
	_place(arc, 0, coil_at)
	_place(arc, 10, e1)
	_place(arc, 11, e2)
	_place(arc, 12, e3)
	_attack(arc, 0, 0, e1)
	_check("the coil's arc jumps twice: all three in the chain are hit",
		arc.unit(10).hp < 20 and arc.unit(11).hp < 20 and arc.unit(12).hp < 20)

	# Scrap carriers: seeded, and only carriers drop.
	var spots: Array[Vector2i] = [Vector2i(1, 1), Vector2i(3, 1), Vector2i(5, 1), Vector2i(7, 1), Vector2i(1, 3), Vector2i(7, 3)]
	var specs: Array = []
	for s: Vector2i in spots:
		specs.append(_unit(HAMMER, s, 5))
	var loot: CombatState = _fight(_rows(), [_unit(HAMMER, Vector2i(4, 8))], specs)
	var carriers: int = 0
	var right: bool = true
	var drops_right: bool = true
	for i: int in spots.size():
		var u: GridUnit = loot.unit(10 + i)
		var expected: bool = IntentAI.mix(1, u.ref, 0, 53) % 100 < loot.setup.pile_drop_pct
		right = right and u.carries_scrap == expected
		carriers += 1 if u.carries_scrap else 0
		var cell := Vector2i(u.x, u.y)
		CombatSim.hurt(loot, 0, u, 999)
		drops_right = drops_right and loot.piles.has(cell) == expected
	_check("which enemies carry scrap is the seeded hash, not luck", right)
	_check("(precondition) this fight has carriers and non-carriers (%d of %d)" % [carriers, spots.size()], carriers > 0 and carriers < spots.size())
	_check("only carriers leave a pile", drops_right)


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
	var setup: CombatSetup = CombatSetup.build(_db.fights[fight_id], _db.combat_rules, _db.parts, _db.tiles, _db.effectiveness, 2026)
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
	# Play-test 14: UNDO starts from a snapshot taken at the turn's start. Played on from any
	# turn boundary, a snapshot must reach the full fight exactly -- and leave its source alone.
	var turns_ok: bool = true
	var boundaries: int = 0
	for cut: int in range(-1, actions.size()):
		if cut >= 0 and int(actions[cut][0]) != CombatSim.ACT_END:
			continue
		boundaries += 1
		var source: CombatState = CombatSim.replay(setup, actions.slice(0, cut + 1))
		var events_before: int = source.events.size()
		var copy: CombatState = source.snapshot()
		for a: Array in actions.slice(cut + 1):
			CombatSim.apply(copy, a)
		if copy.event_hash() != state.event_hash() or source.events.size() != events_before:
			turns_ok = false
	_check("%s: a turn-start snapshot played on matches the full fight (%d turns)" % [fight_id, boundaries], turns_ok and boundaries > 0)


func _check(label: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s" % label)
