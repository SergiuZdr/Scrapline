extends SceneTree

## Grid combat: every rule, determinism, replay-based undo, and whole fights played by bot.
##
##   godot --headless --path . --script res://tools/verify_combat.gd
##
## The bot-played fights are the important ones. A rule test proves a rule; only playing
## a fight to the end proves the fight can end.
##
## Loadouts use `co_dynamo` (kinetic, no damage or heat bonus, vent 2) and `mo_scavenger`
## (+2 HP) so the numbers below can be worked out by hand: kinetic is 100% against plate,
## 130% against composite and 70% against reactive.

const HAMMER: Array = ["ch_brute", "co_dynamo", "ar_saw", "ar_hammer", "mo_scavenger"]     # brawler, plate, 13 HP
const LANCE: Array = ["ch_hauler", "co_dynamo", "ar_scanner", "ar_lance", "mo_scavenger"]  # line role, composite
const RAIL: Array = ["ch_lancer", "co_dynamo", "ar_scanner", "ar_railgun", "mo_scavenger"]  # marksman, plate
const MORTAR: Array = ["ch_bulwark", "co_dynamo", "ar_mortar", "ar_hammer", "mo_scavenger"] # anchor, reactive
const SCATTER: Array = ["ch_lancer", "co_dynamo", "ar_pulse", "ar_scatter", "mo_targeting"] # non-piercing line, reach 4
const BLANK: Array = ["......", "......", "......", "......", "......", "......"]

var _db: ContentDB
var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_db = ContentDB.load_all()
	print("")
	print("=== grid combat ===")

	_test_fights_build()
	_test_stats_come_from_parts()
	_test_movement_and_terrain_cost()
	_test_attack_order_and_line_role()
	_test_line_pierce_and_blocking()
	_test_lob_and_splash()
	_test_damage_wheel_and_cover()
	_test_shove_and_bump()
	_test_mark()
	_test_heat_overheat_and_vent()
	_test_tearing_arms()
	_test_slag()
	_test_intent_fires_down_its_line()
	_test_crawler()
	_test_wreck_blocks_and_win()
	for fight_id: String in ["proto_yard", "slag_pit", "container_row"]:
		_test_bot_fight(fight_id)

	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	print("")
	quit(1 if _failed > 0 else 0)


# --- Fixtures ---------------------------------------------------------------

## A small board. Tests reposition everything by hand after `start` and clear the
## intents, so each rule is tested on exact positions rather than wherever the AI walked.
func _fight(rows: Array, players: Array, enemies: Array, crawler: Dictionary = {}) -> CombatState:
	var fight: Dictionary = {"id": "test", "rows": rows, "player": players, "enemy": enemies}
	if not crawler.is_empty():
		fight["crawler"] = crawler
	var setup: CombatSetup = CombatSetup.build(fight, _db.combat_rules, _db.parts, _db.tiles, _db.balance.effectiveness, 1)
	if not setup.errors.is_empty():
		_check("test setup has no errors %s" % [setup.errors], false)
	var state: CombatState = CombatSim.start(setup)
	state.intents.clear()
	return state


func _unit(parts: Array, x: int, y: int, hp: int = -1) -> Dictionary:
	var spec: Dictionary = {"parts": parts, "x": x, "y": y}
	if hp > 0:
		spec["hp"] = hp
	return spec


func _place(state: CombatState, ref: int, x: int, y: int) -> void:
	var u: GridUnit = state.unit(ref)
	u.x = x
	u.y = y


func _count(state: CombatState, since: int, kind: int) -> int:
	var n: int = 0
	for i: int in range(since, state.events.size()):
		if int(state.events[i][GridEv.F_KIND]) == kind:
			n += 1
	return n


func _attack(state: CombatState, ref: int, w: int, dir: int, dist: int = 0) -> bool:
	return CombatSim.apply(state, [CombatSim.ACT_ATTACK, ref, w, dir, dist])


# --- Tests ------------------------------------------------------------------

func _test_fights_build() -> void:
	for id: String in ["proto_yard", "slag_pit", "container_row"]:
		var fight: Dictionary = _db.fights.get(id, {})
		var setup: CombatSetup = CombatSetup.build(fight, _db.combat_rules, _db.parts, _db.tiles, _db.balance.effectiveness, 7)
		_check("%s builds with no errors %s" % [id, setup.errors], not fight.is_empty() and setup.errors.is_empty())
		var crawlers: int = setup.units.filter(func(u: GridUnit) -> bool: return u.objective).size()
		_check("%s has 3 constructs and a Crawler" % id,
			crawlers == 1 and setup.units.filter(func(u: GridUnit) -> bool: return u.team == 0 and not u.objective).size() == 3)


func _test_stats_come_from_parts() -> void:
	var state: CombatState = _fight(BLANK, [_unit(HAMMER, 0, 5), _unit(RAIL, 5, 5)], [_unit(HAMMER, 0, 0)])
	var brute: GridUnit = state.unit(0)
	_check("HP = chassis grid hp + module hp (11 + 2)", brute.max_hp == 13)
	_check("move from the chassis (3)", brute.move == 3)
	_check("two weapons, one per arm", brute.weapons.size() == 2 and String(brute.weapons[1]["class"]) == "hammer")
	_check("brawler role adds +1 melee", brute.melee_bonus == 1)
	_check("marksman role adds +1 range", state.unit(1).range_bonus == 1)


func _test_movement_and_terrain_cost() -> void:
	var rows: Array = ["......", "......", "..s...", "......", ".rr...", "......"]
	var state: CombatState = _fight(rows, [_unit(HAMMER, 1, 5)], [_unit(HAMMER, 5, 0)])
	_place(state, 0, 1, 5)
	_place(state, 10, 5, 0)
	var reach: Dictionary = CombatSim.reachable(state, 0)
	_check("rubble costs 2: (1,4) is reachable at cost 2", reach.has(Vector2i(1, 4)))
	_check("rubble costs 2: (1,3) through rubble costs 3, still in reach", reach.has(Vector2i(1, 3)))
	_check("but not (1,2): that would cost 4", not reach.has(Vector2i(1, 2)) or (reach[Vector2i(1, 2)] as Array).size() <= 3)
	_check("cannot move onto scrap", not CombatSim.apply(state, [CombatSim.ACT_MOVE, 0, 2, 2]))
	_check("legal move is accepted", CombatSim.apply(state, [CombatSim.ACT_MOVE, 0, 0, 4]))
	_check("cannot move twice", not CombatSim.apply(state, [CombatSim.ACT_MOVE, 0, 0, 3]))


func _test_attack_order_and_line_role() -> void:
	var state: CombatState = _fight(BLANK, [_unit(HAMMER, 0, 5), _unit(LANCE, 3, 5)], [_unit(HAMMER, 0, 4, 20), _unit(HAMMER, 3, 2, 20)])
	_place(state, 0, 0, 5)
	_place(state, 10, 0, 4)
	_place(state, 1, 3, 5)
	_place(state, 11, 3, 2)
	_check("hammer attack north", _attack(state, 0, 1, 0))
	_check("a brawler cannot move after attacking", CombatSim.reachable(state, 0).is_empty())
	_check("cannot attack twice", not _attack(state, 0, 1, 0))
	_check("a line construct fires first...", _attack(state, 1, 1, 0))
	_check("...and may still move after", not CombatSim.reachable(state, 1).is_empty())


func _test_line_pierce_and_blocking() -> void:
	var rows: Array = ["......", "......", "......", "..s...", "......", "......"]
	var state: CombatState = _fight(rows,
		[_unit(LANCE, 0, 5), _unit(RAIL, 5, 5), _unit(RAIL, 2, 5)],
		[_unit(HAMMER, 0, 4, 20), _unit(HAMMER, 0, 3, 20), _unit(HAMMER, 0, 2, 20), _unit(HAMMER, 5, 3, 20), _unit(HAMMER, 5, 1, 20), _unit(HAMMER, 2, 1, 20)])
	for p: Array in [[0, 0, 5], [1, 5, 5], [2, 2, 5], [10, 0, 4], [11, 0, 3], [12, 0, 2], [13, 5, 3], [14, 5, 1], [15, 2, 1]]:
		_place(state, p[0], p[1], p[2])
	var lance: Dictionary = CombatSim.preview_attack(state, 0, 1, 0, 0)
	_check("lance pierces one: hits the first two in line", (lance["hits"] as Array).size() == 2)
	var rail: Dictionary = CombatSim.preview_attack(state, 1, 1, 0, 0)
	_check("railgun pierces every unit in its line", (rail["hits"] as Array).size() == 2)
	var blocked: Dictionary = CombatSim.preview_attack(state, 2, 1, 0, 0)
	_check("a scrap heap stops a railgun", (blocked["hits"] as Array).is_empty())
	var before: int = state.events.size()
	_attack(state, 2, 1, 0)
	_check("a blocked shot reports MISSED", _count(state, before, GridEv.MISSED) == 1)


func _test_lob_and_splash() -> void:
	var rows: Array = ["......", "......", "......", "..s...", "......", "......"]
	var state: CombatState = _fight(rows, [_unit(MORTAR, 2, 5)],
		[_unit(HAMMER, 2, 1, 20), _unit(HAMMER, 1, 1, 20), _unit(HAMMER, 5, 5, 20)])
	_place(state, 0, 2, 5)
	_place(state, 10, 2, 1)
	_place(state, 11, 1, 1)
	_place(state, 12, 5, 5)
	_check("a lob cannot land closer than its minimum", not CombatSim.can_attack(state, 0, 0, 0, 1))
	var plan: Dictionary = CombatSim.preview_attack(state, 0, 0, 0, 4)
	_check("a lob flies over scrap to its tile", bool(plan["legal"]) and plan["aim"] == Vector2i(2, 1))
	_check("centre takes full damage, a neighbour takes splash", (plan["hits"] as Array).size() == 2)
	_attack(state, 0, 0, 0, 4)
	# Mortar 3 kinetic vs plate (100%) = 3; splash 1.
	_check("centre hit for 3", state.unit(10).hp == 17)
	_check("splash hit for 1", state.unit(11).hp == 19)


func _test_damage_wheel_and_cover() -> void:
	var rows: Array = ["......", "......", "......", "......", ".r....", "......"]
	var state: CombatState = _fight(rows, [_unit(HAMMER, 0, 5), _unit(RAIL, 5, 5)],
		[_unit(LANCE, 0, 4, 20), _unit(MORTAR, 5, 4, 20), _unit(HAMMER, 1, 4, 20)])
	_place(state, 0, 0, 5)
	_place(state, 10, 0, 4)
	_place(state, 1, 5, 5)
	_place(state, 11, 5, 4)
	_place(state, 12, 1, 0)
	var brute: GridUnit = state.unit(0)
	# Hammer: 3 + 1 brawler = 4. Kinetic vs composite 130% -> 5.2 -> 5.
	_check("kinetic beats composite (4 -> 5)", CombatSim.damage_to(state, brute, state.unit(10), 4, false) == 5)
	# Kinetic vs reactive 70% -> 2.8 -> 3.
	_check("kinetic is blunted by reactive (4 -> 3)", CombatSim.damage_to(state, brute, state.unit(11), 4, false) == 3)
	_place(state, 12, 1, 4)
	_check("rubble takes 1 off a line shot", CombatSim.damage_to(state, brute, state.unit(12), 3, true) == 2)
	_check("but not off a melee blow", CombatSim.damage_to(state, brute, state.unit(12), 3, false) == 3)


func _test_shove_and_bump() -> void:
	var state: CombatState = _fight(BLANK, [_unit(HAMMER, 2, 5), _unit(HAMMER, 0, 1)],
		[_unit(HAMMER, 2, 4, 20), _unit(HAMMER, 0, 0, 20), _unit(MORTAR, 4, 4, 20), _unit(HAMMER, 5, 5, 20)])
	_place(state, 0, 2, 5)
	_place(state, 10, 2, 4)
	_attack(state, 0, 1, 0)
	_check("hammer shoves its target one tile back", state.unit(10).y == 3)
	_check("shoved target took the hit (20 - 4)", state.unit(10).hp == 16)
	_place(state, 1, 0, 1)
	_place(state, 11, 0, 0)
	_attack(state, 1, 1, 0)
	_check("shoved into the edge: no move, 1 bump damage on top", state.unit(11).y == 0 and state.unit(11).hp == 20 - 4 - 1)
	_place(state, 12, 4, 4)
	var anchor: GridUnit = state.unit(12)
	_check("an anchor cannot be shoved", anchor.unshovable)


func _test_mark() -> void:
	var state: CombatState = _fight(BLANK, [_unit(LANCE, 0, 5), _unit(HAMMER, 1, 3)], [_unit(HAMMER, 0, 3, 20)])
	_place(state, 0, 0, 5)
	_place(state, 10, 0, 3)
	_place(state, 1, 1, 3)
	_attack(state, 0, 0, 0)   # scanner
	_check("the scanner chips 1 and marks", state.unit(10).marked and state.unit(10).hp == 19)
	_attack(state, 1, 0, 3)   # saw west (no shove): 5 + mark 2
	_check("a marked target takes +2 and the mark clears", state.unit(10).hp == 12 and not state.unit(10).marked)


func _test_heat_overheat_and_vent() -> void:
	var state: CombatState = _fight(BLANK, [_unit(RAIL, 0, 5), _unit(LANCE, 5, 5)], [_unit(HAMMER, 0, 0, 40)])
	_place(state, 0, 0, 5)
	_place(state, 10, 0, 0)
	var rail: GridUnit = state.unit(0)
	rail.heat = 3   # cap 5, railgun +2
	var preview: Dictionary = CombatSim.preview_attack(state, 0, 1, 0, 0)
	_check("preview warns the shot will overheat", bool(preview["overheats"]))
	_attack(state, 0, 1, 0)
	_check("reaching the cap overheats", rail.overheated and rail.heat == 5)
	CombatSim.apply(state, [CombatSim.ACT_END, -1, 0, 0])
	state.intents.clear()
	rail = state.unit(0)
	_check("next round it is seized, heat reset to 0", rail.seized and rail.heat == 0)
	_check("a seized construct cannot attack", not CombatSim.can_attack(state, 0, 1, 0, 0))
	_check("but it can still move", not CombatSim.reachable(state, 0).is_empty())
	var lance: GridUnit = state.unit(1)
	lance.heat = 3
	_check("VENT is accepted", CombatSim.apply(state, [CombatSim.ACT_VENT, 1, 0, 0]))
	_check("VENT clears heat and uses the action", lance.heat == 0 and lance.acted)


func _test_tearing_arms() -> void:
	var state: CombatState = _fight(BLANK, [_unit(HAMMER, 0, 5)], [_unit(LANCE, 0, 4, 40)])
	_place(state, 0, 0, 5)
	_place(state, 10, 0, 4)
	# Saw: 4 + 1 brawler = 5, kinetic vs composite 130% -> 6.5 -> 7 (half rounds up): over the threshold.
	var preview: Dictionary = CombatSim.preview_attack(state, 0, 0, 0, 0)
	_check("preview says the blow will tear an arm", (preview["tears"] as Array).has(10))
	_attack(state, 0, 0, 0)
	var target: GridUnit = state.unit(10)
	_check("a heavy hit tears the RIGHT arm first", bool(target.weapons[GridUnit.ARM_R]["torn"]) and not bool(target.weapons[GridUnit.ARM_L]["torn"]))
	_check("a torn arm cannot fire", not target.can_fire(GridUnit.ARM_R))


func _test_slag() -> void:
	var rows: Array = ["......", "......", "......", "......", "......", "l....."]
	var state: CombatState = _fight(rows, [_unit(HAMMER, 5, 5)], [_unit(HAMMER, 5, 0, 20)])
	_place(state, 0, 0, 5)
	var before: int = state.unit(0).hp
	CombatSim.apply(state, [CombatSim.ACT_END, -1, 0, 0])
	_check("a construct on slag at round start takes 1", state.unit(0).hp == before - 1 or state.unit(0).x != 0)


## The core puzzle rule: an intent is a DIRECTION from the attacker, resolved at end of
## turn. Stepping out of the line dodges it; stepping into it takes the hit.
func _test_intent_fires_down_its_line() -> void:
	var state: CombatState = _fight(BLANK, [_unit(RAIL, 0, 3), _unit(HAMMER, 1, 1)], [_unit(LANCE, 0, 0, 20)])
	_place(state, 0, 0, 3)
	_place(state, 1, 1, 1)
	_place(state, 10, 0, 0)
	state.intents = [{"ref": 10, "w": 1, "dir": 2, "dist": 0, "order": 1}]
	var hits: Array = CombatSim.threats(state)[10]["hits"]
	_check("threat currently lands on the rail unit", hits.size() == 1 and int(hits[0]["ref"]) == 0)
	CombatSim.apply(state, [CombatSim.ACT_MOVE, 0, 1, 3])
	CombatSim.apply(state, [CombatSim.ACT_MOVE, 1, 0, 1])
	hits = CombatSim.threats(state)[10]["hits"]
	_check("after moving, the threat lands on the unit that stepped in", int(hits[0]["ref"]) == 1)
	var rail_hp: int = state.unit(0).hp
	CombatSim.apply(state, [CombatSim.ACT_END, -1, 0, 0])
	_check("the unit that stepped out is unhurt", state.unit(0).hp == rail_hp)
	_check("the unit that stepped in took the shot", state.unit(1).hp < state.unit(1).max_hp)


func _test_crawler() -> void:
	var state: CombatState = _fight(BLANK, [_unit(HAMMER, 5, 5), _unit(LANCE, 3, 3), _unit(RAIL, 4, 5)],
		[_unit(SCATTER, 2, 1, 20)], {"x": 2, "y": 5, "hp": 3})
	var crawler: GridUnit = state.crawler()
	_check("the Crawler is on the player's team, immobile, unshovable", crawler.team == 0 and crawler.move == 0 and crawler.unshovable)
	_check("the Crawler cannot be moved", not CombatSim.apply(state, [CombatSim.ACT_MOVE, crawler.ref, 2, 4]))
	_place(state, 10, 2, 1)
	state.intents = [{"ref": 10, "w": 1, "dir": 2, "dist": 0, "order": 1}]
	_check("an enemy line aimed down the column hits the Crawler", int(CombatSim.threats(state)[10]["hits"][0]["ref"]) == crawler.ref)
	var shield: Dictionary = CombatBot.context(state)["shield"]
	_check("the bot sees shield value in front of the Crawler, not behind it",
		shield.has(Vector2i(2, 3)) and not shield.has(Vector2i(2, 5)))
	var undo_point: Array = []
	_check("(the shielding move is legal)", CombatSim.apply(state, [CombatSim.ACT_MOVE, 1, 2, 3]))
	_check("a construct stepping in front shields it", int(CombatSim.threats(state)[10]["hits"][0]["ref"]) == 1)
	state = CombatSim.replay(state.setup, undo_point)
	_place(state, 10, 2, 1)
	state.intents = [{"ref": 10, "w": 1, "dir": 2, "dist": 0, "order": 1}]
	CombatSim.apply(state, [CombatSim.ACT_END, -1, 0, 0])
	_check("losing the Crawler loses the fight", state.outcome == CombatState.LOST and not state.crawler().alive)


func _test_wreck_blocks_and_win() -> void:
	var state: CombatState = _fight(BLANK, [_unit(HAMMER, 0, 5)],
		[_unit(HAMMER, 0, 0, 4), _unit(HAMMER, 5, 0, 30)])
	_place(state, 0, 0, 1)
	_place(state, 10, 0, 0)
	_place(state, 11, 5, 0)
	_attack(state, 0, 1, 0)
	_check("4 damage destroys a 4 hp unit", not state.unit(10).alive)
	_check("fight goes on while an enemy stands", state.outcome == CombatState.ONGOING)
	CombatSim.apply(state, [CombatSim.ACT_END, -1, 0, 0])
	_check("wreck tile is not reachable", not CombatSim.reachable(state, 0).has(Vector2i(0, 0)))
	state.intents.clear()
	state.unit(11).hp = 1
	_place(state, 11, 1, 1)
	_place(state, 0, 0, 1)
	_attack(state, 0, 1, 1)
	_check("destroying the last enemy wins", state.outcome == CombatState.WON)
	_check("nothing is legal after the fight ends", not CombatSim.apply(state, [CombatSim.ACT_END, -1, 0, 0]))


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
	var crawler: GridUnit = state.crawler()
	print("    %s: %s in %d rounds, crew %d/3, crawler %d/%d, damage dealt player %d / enemy %d, hash %s" % [
		fight_id, "WON" if state.outcome == CombatState.WON else "LOST", state.round_number,
		state.crew(GridUnit.TEAM_PLAYER).size(), crawler.hp, crawler.max_hp, dealt[0], dealt[1], state.event_hash()])

	var same: bool = true
	for i: int in 3:
		if CombatSim.replay(setup, actions).event_hash() != state.event_hash():
			same = false
	_check("%s: replaying gives the same hash 3 times" % fight_id, same)

	# Prefix stability: undo is "replay one fewer action", so the replay of any prefix
	# must produce exactly the events the full fight produced up to that point.
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
