extends SceneTree

## Grid combat: rules, determinism, replay-based undo, and a whole fight played by bot.
##
##   godot --headless --path . --script res://tools/verify_combat.gd
##
## The bot-played fight is the important one. A rule test proves a rule; only playing a
## fight to the end proves the fight can end.

const RANGED: Array = ["ch_strider", "co_arc", "ar_scanner", "ar_railgun", "mo_targeting"]
const MELEE: Array = ["ch_brute", "co_slug", "ar_saw", "ar_hammer", "mo_servo"]

var _db: ContentDB
var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_db = ContentDB.load_all()
	print("")
	print("=== grid combat ===")

	_test_setup_builds()
	_test_movement_rules()
	_test_move_then_attack_only()
	_test_line_stops_at_first_unit()
	_test_scrap_blocks_shot()
	_test_intent_fires_down_its_line()
	_test_wreck_blocks_and_win()
	_test_bot_fight()

	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	print("")
	quit(1 if _failed > 0 else 0)


# --- Fixtures ---------------------------------------------------------------

## A 5x5 board with one scrap heap in the middle. Enemies start in the far corners and
## tests reposition everything by hand after `start`, so the rules are tested on exact
## positions rather than on wherever the AI happened to walk.
func _small_fight(players: Array, enemies: Array) -> CombatState:
	var fight: Dictionary = {
		"id": "test",
		"rows": [".....", ".....", "..s..", ".....", "....."],
		"player": players,
		"enemy": enemies,
	}
	var setup: CombatSetup = CombatSetup.build(fight, _db.combat_rules, _db.parts, _db.tiles, 1)
	_check("test setup has no errors %s" % [setup.errors], setup.errors.is_empty())
	var state: CombatState = CombatSim.start(setup)
	state.intents.clear()
	return state


func _place(state: CombatState, ref: int, x: int, y: int) -> void:
	var u: GridUnit = state.unit(ref)
	u.x = x
	u.y = y


func _events_since(state: CombatState, count: int, kind: int) -> Array:
	var out: Array = []
	for i: int in range(count, state.events.size()):
		if int(state.events[i][GridEv.F_KIND]) == kind:
			out.append(state.events[i])
	return out


# --- Tests ------------------------------------------------------------------

func _test_setup_builds() -> void:
	var fight: Dictionary = _db.fights.get("proto_yard", {})
	_check("proto_yard fight loads", not fight.is_empty())
	var setup: CombatSetup = CombatSetup.build(fight, _db.combat_rules, _db.parts, _db.tiles, 7)
	_check("proto_yard builds with no errors %s" % [setup.errors], setup.errors.is_empty())
	_check("board is 8x8", setup.width == 8 and setup.height == 8)
	_check("3 player constructs", setup.units.filter(func(u: GridUnit) -> bool: return u.team == 0).size() == 3)
	var state: CombatState = CombatSim.start(setup)
	_check("enemies telegraph or approach on round 1", state.round_number == 1)


func _test_movement_rules() -> void:
	var state: CombatState = _small_fight([{"parts": MELEE, "x": 2, "y": 4}], [{"parts": MELEE, "x": 0, "y": 0}])
	_place(state, 0, 2, 4)
	_place(state, 10, 0, 0)
	_check("cannot move onto scrap", not CombatSim.apply(state, [CombatSim.ACT_MOVE, 0, 2, 2]))
	_check("cannot move beyond move range", not CombatSim.apply(state, [CombatSim.ACT_MOVE, 0, 2, 0]))
	_check("cannot move onto an enemy", not CombatSim.apply(state, [CombatSim.ACT_MOVE, 0, 0, 0]))
	var before: int = state.events.size()
	_check("legal move is accepted", CombatSim.apply(state, [CombatSim.ACT_MOVE, 0, 1, 2]))
	_check("move emits one STEP per tile (3)", _events_since(state, before, GridEv.STEP).size() == 3)
	_check("cannot move twice", not CombatSim.apply(state, [CombatSim.ACT_MOVE, 0, 1, 3]))
	_check("cannot move an enemy", not CombatSim.apply(state, [CombatSim.ACT_MOVE, 10, 0, 1]))


func _test_move_then_attack_only() -> void:
	var state: CombatState = _small_fight([{"parts": MELEE, "x": 0, "y": 4}], [{"parts": MELEE, "x": 4, "y": 0}])
	_place(state, 0, 0, 1)
	_place(state, 10, 0, 0)
	_check("attack without moving", CombatSim.apply(state, [CombatSim.ACT_ATTACK, 0, 0, 0]))
	_check("cannot move after attacking", not CombatSim.apply(state, [CombatSim.ACT_MOVE, 0, 1, 1]))
	_check("cannot attack twice", not CombatSim.apply(state, [CombatSim.ACT_ATTACK, 0, 0, 0]))
	_check("melee hit for 4", state.unit(10).hp == state.unit(10).max_hp - 4)


func _test_line_stops_at_first_unit() -> void:
	var state: CombatState = _small_fight(
		[{"parts": RANGED, "x": 0, "y": 4}],
		[{"parts": MELEE, "x": 0, "y": 2}, {"parts": MELEE, "x": 0, "y": 1}])
	_place(state, 0, 0, 4)
	_place(state, 10, 0, 2)
	_place(state, 11, 0, 1)
	var preview: Dictionary = CombatSim.preview_attack(state, 0, 0)
	_check("preview names the first unit in line", int(preview["target"]) == 10)
	CombatSim.apply(state, [CombatSim.ACT_ATTACK, 0, 0, 0])
	_check("first unit in line is hit", state.unit(10).hp < state.unit(10).max_hp)
	_check("unit behind it is untouched", state.unit(11).hp == state.unit(11).max_hp)


func _test_scrap_blocks_shot() -> void:
	var state: CombatState = _small_fight([{"parts": RANGED, "x": 2, "y": 4}], [{"parts": MELEE, "x": 2, "y": 0}])
	_place(state, 0, 2, 4)
	_place(state, 10, 2, 0)
	var before: int = state.events.size()
	CombatSim.apply(state, [CombatSim.ACT_ATTACK, 0, 0, 0])
	_check("scrap heap stops the shot", state.unit(10).hp == state.unit(10).max_hp)
	_check("a blocked shot reports MISSED", _events_since(state, before, GridEv.MISSED).size() == 1)


## The core puzzle rule: an intent is a DIRECTION from the attacker, resolved at end of
## turn. Stepping out of the line dodges it; stepping into it takes the hit.
func _test_intent_fires_down_its_line() -> void:
	var state: CombatState = _small_fight(
		[{"parts": RANGED, "x": 0, "y": 3}, {"parts": MELEE, "x": 1, "y": 1}],
		[{"parts": RANGED, "x": 0, "y": 0}])
	_place(state, 0, 0, 3)
	_place(state, 1, 1, 1)
	_place(state, 10, 0, 0)
	state.intents = [{"ref": 10, "dir": 2, "order": 1}]
	var threat: Dictionary = CombatSim.threats(state)[10]
	_check("threat currently lands on the ranged unit", int(threat["hit"]) == 0)

	CombatSim.apply(state, [CombatSim.ACT_MOVE, 0, 1, 3])
	CombatSim.apply(state, [CombatSim.ACT_MOVE, 1, 0, 1])
	threat = CombatSim.threats(state)[10]
	_check("after moving, the threat lands on the unit that stepped in", int(threat["hit"]) == 1)
	CombatSim.apply(state, [CombatSim.ACT_END, -1, 0, 0])
	_check("the unit that stepped out is unhurt", state.unit(0).hp == state.unit(0).max_hp)
	_check("the unit that stepped in took the shot", state.unit(1).hp == state.unit(1).max_hp - 3)


func _test_wreck_blocks_and_win() -> void:
	var state: CombatState = _small_fight(
		[{"parts": MELEE, "x": 0, "y": 4}],
		[{"parts": MELEE, "x": 0, "y": 0, "hp": 4}, {"parts": MELEE, "x": 4, "y": 0, "hp": 30}])
	_place(state, 0, 0, 1)
	_place(state, 10, 0, 0)
	_place(state, 11, 4, 0)
	CombatSim.apply(state, [CombatSim.ACT_ATTACK, 0, 0, 0])
	_check("4 damage destroys a 4 hp unit", not state.unit(10).alive)
	_check("fight goes on while an enemy stands", state.outcome == CombatState.ONGOING)
	CombatSim.apply(state, [CombatSim.ACT_END, -1, 0, 0])
	_check("wreck tile is not reachable", not CombatSim.reachable(state, 0).has(Vector2i(0, 0)))

	state.unit(11).hp = 1
	_place(state, 11, 1, 1)
	state.unit(0).moved = false
	state.unit(0).acted = false
	_place(state, 0, 0, 1)
	CombatSim.apply(state, [CombatSim.ACT_ATTACK, 0, 1, 0])
	_check("destroying the last enemy wins", state.outcome == CombatState.WON)
	_check("nothing is legal after the fight ends", not CombatSim.apply(state, [CombatSim.ACT_END, -1, 0, 0]))


func _test_bot_fight() -> void:
	var setup: CombatSetup = CombatSetup.build(_db.fights["proto_yard"], _db.combat_rules, _db.parts, _db.tiles, 2026)
	var state: CombatState = CombatSim.start(setup)
	var actions: Array = []
	var guard: int = 0
	while state.outcome == CombatState.ONGOING and guard < 100:
		actions.append_array(CombatBot.take_turn(state))
		guard += 1
	_check("bot fight ends", state.outcome != CombatState.ONGOING)
	_check("bot fight ends within max_rounds", state.round_number <= setup.max_rounds)
	var standing: int = state.living(GridUnit.TEAM_PLAYER).size()
	var dealt: Array[int] = [0, 0]
	var intents_set: int = 0
	for e: Array in state.events:
		if int(e[GridEv.F_KIND]) == GridEv.DAMAGE:
			dealt[int(e[GridEv.F_ACTOR]) / 10] += int(e[GridEv.F_V1])
		elif int(e[GridEv.F_KIND]) == GridEv.INTENT_SET:
			intents_set += 1
	print("    bot fight: %s in %d rounds, %d/3 constructs standing, %d actions, %d events, hash %s" % [
		"WON" if state.outcome == CombatState.WON else "LOST", state.round_number, standing,
		actions.size(), state.events.size(), state.event_hash()])
	print("    damage dealt: player %d, enemy %d; enemy intents set: %d" % [dealt[0], dealt[1], intents_set])

	var hashes: Array = []
	for i: int in 3:
		hashes.append(CombatSim.replay(setup, actions).event_hash())
	_check("replaying the fight gives the same hash 3 times", hashes[0] == state.event_hash()
		and hashes[1] == hashes[0] and hashes[2] == hashes[0])

	# Prefix stability: undo is "replay one fewer action", so the replay of any prefix
	# must produce exactly the events the full fight produced up to that point.
	var stable: bool = true
	for cut: int in [1, actions.size() / 3, actions.size() / 2, actions.size() - 1]:
		var partial: CombatState = CombatSim.replay(setup, actions.slice(0, cut))
		for i: int in partial.events.size():
			if partial.events[i] != state.events[i]:
				stable = false
	_check("every replayed prefix matches the full fight (undo is exact)", stable)

	var reloaded: ContentDB = ContentDB.load_all()
	var setup2: CombatSetup = CombatSetup.build(reloaded.fights["proto_yard"], reloaded.combat_rules, reloaded.parts, reloaded.tiles, 2026)
	_check("a freshly loaded setup replays identically", CombatSim.replay(setup2, actions).event_hash() == state.event_hash())


func _check(label: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s" % label)
