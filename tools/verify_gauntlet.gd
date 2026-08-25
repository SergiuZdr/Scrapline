extends SceneTree

## Gauntlet and progression-power tests.
##
## Two things get checked here that nothing else can:
##
##   - **Does levelling a part actually do anything?** It did not, until the power
##     multiplier was wired through. A progression system that changes a number on a
##     screen and nothing on the battlefield is the most expensive kind of bug,
##     because players feel it long before anyone can name it.
##   - **Does the tower actually end?** An "endless" mode that a strong squad never
##     loses is not endless, it is an idle button.
##
##   godot --headless --path . --script res://tools/verify_gauntlet.gd

const TEST_PATH: String = "user://test_gauntlet.json"

var _passed: int = 0
var _failed: int = 0
var _content: ContentDB


func _initialize() -> void:
	_content = ContentDB.load_all()
	if not _content.errors.is_empty():
		for e: String in _content.errors:
			printerr("content: ", e)
		quit(1)
		return

	print("")
	print("=== gauntlet and progression power ===")

	_test_floors_are_deterministic()
	_test_floors_escalate()
	_test_levelling_changes_a_battle()
	_test_run_state()
	_test_synergy_rewards_building()
	_climb()

	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	print("")
	_cleanup()
	quit(1 if _failed > 0 else 0)


## Every player must meet the same squad on the same floor, or a depth leaderboard
## compares nothing.
func _test_floors_are_deterministic() -> void:
	var a: Array = Gauntlet.floor_squad(37, _content)
	var b: Array = Gauntlet.floor_squad(37, _content)
	_check("the same floor generates the same squad", JSON.stringify(a) == JSON.stringify(b))
	_check("different floors differ",
		JSON.stringify(Gauntlet.floor_squad(5, _content)) != JSON.stringify(a))


func _test_floors_escalate() -> void:
	_check("floor 1 is small", Gauntlet.floor_squad(1, _content).size() <= 3)
	_check("deep floors are full squads", Gauntlet.floor_squad(20, _content).size() == SimDefs.SQUAD_SIZE)
	_check("power climbs with depth", Gauntlet.floor_power(50) > Gauntlet.floor_power(10))
	_check("early floors carry no Condition", Gauntlet.floor_condition(1, _content).is_empty())
	_check("deep floors carry a Condition", not Gauntlet.floor_condition(25, _content).is_empty())
	_check("rewards climb with depth", Gauntlet.floor_reward(30) > Gauntlet.floor_reward(3))


## The one that matters: the same squad, before and after levelling, against the same
## enemy. If the outcome and damage are identical, progression is cosmetic.
func _test_levelling_changes_a_battle() -> void:
	var store: ProfileStore = _store()
	_grant_starter(store)

	var setup_before: BattleSetup = Gauntlet.build_setup(store.profile, _content, 6, "main", 4242)
	var before: BattleResult = BattleSim.simulate(setup_before, [], _content.to_sim_content(), _content.balance)
	var power_before: int = Economy.squad_power(store.profile, _content)

	store.execute(ProfileCommands.GrantCurrency.new(PlayerProfile.SCRAP, 500_000, "test"))
	for part_id: String in store.profile.owned_part_ids():
		for _step: int in 4:
			store.execute(ProfileCommands.LevelPart.new(part_id))

	var power_after: int = Economy.squad_power(store.profile, _content)
	var setup_after: BattleSetup = Gauntlet.build_setup(store.profile, _content, 6, "main", 4242)
	var after: BattleResult = BattleSim.simulate(setup_after, [], _content.to_sim_content(), _content.balance)

	_check("levelling raises squad power (%d%% -> %d%%)" % [power_before, power_after],
		power_after > power_before)
	_check("a levelled squad fights a measurably different battle",
		after.damage_dealt[0] != before.damage_dealt[0] or after.winner != before.winner)
	_check("a levelled squad deals more damage",
		after.damage_dealt[0] > before.damage_dealt[0])


func _test_run_state() -> void:
	var store: ProfileStore = _store()
	_grant_starter(store)
	var now: int = 3 * Gauntlet.SECONDS_PER_WEEK + 1000

	_check("a run starts at floor 1", Gauntlet.current_floor(store.profile, now) == 1)

	store.execute(ProfileCommands.RecordGauntlet.new(1, true, now))
	store.execute(ProfileCommands.RecordGauntlet.new(2, true, now))
	_check("winning advances the floor", Gauntlet.current_floor(store.profile, now) == 3)
	_check("best depth is recorded", Gauntlet.best_depth(store.profile) == 2)

	store.execute(ProfileCommands.RecordGauntlet.new(3, false, now))
	_check("losing resets the run to floor 1", Gauntlet.current_floor(store.profile, now) == 1)
	_check("losing does NOT erase the best depth", Gauntlet.best_depth(store.profile) == 2)

	var next_week: int = now + Gauntlet.SECONDS_PER_WEEK
	store.execute(ProfileCommands.RecordGauntlet.new(1, true, next_week))
	_check("a new week clears the weekly record", Gauntlet.week_best(store.profile, next_week) == 1)
	_check("a new week keeps the all-time best", Gauntlet.best_depth(store.profile) == 2)


## How deep does a realistically-progressed squad get? An endless mode nobody can lose
## is not a mode.
func _climb() -> void:
	var store: ProfileStore = _store()
	_grant_starter(store)
	store.execute(ProfileCommands.GrantCurrency.new(PlayerProfile.SCRAP, 300_000, "test"))
	for part_id: String in store.profile.owned_part_ids():
		for _step: int in 4:
			store.execute(ProfileCommands.LevelPart.new(part_id))

	print("")
	print("  climbing with a fully-levelled starter squad (power %d%%):" % Economy.squad_power(store.profile, _content))
	var reached: int = 0
	for floor_number: int in range(1, 40):
		var setup: BattleSetup = Gauntlet.build_setup(store.profile, _content, floor_number, "main", 900 + floor_number)
		var result: BattleResult = BattleSim.simulate(setup, [], _content.to_sim_content(), _content.balance)
		if result.winner != SimDefs.TEAM_A:
			print("    stopped on floor %d (enemy power %d%%, %d enemies)" % [
				floor_number, Gauntlet.floor_power(floor_number),
				Gauntlet.floor_squad(floor_number, _content).size()])
			break
		reached = floor_number

	_check("the tower is climbable at all (reached floor %d)" % reached, reached >= 3)
	_check("the tower eventually stops you (reached floor %d, under 39)" % reached, reached < 39)


## Cross-unit Synergy is the deepest mechanic in the design, and it is invisible: it
## either fires or it does not, and nobody notices a system that quietly stopped
## working. This pins the payoff for building ON PURPOSE.
##
## It caught two real bugs already: the doctrine only ever reaching for one ability
## slot, and detonators aiming at the nearest enemy instead of the marked one.
func _test_synergy_rewards_building() -> void:
	var paired: Array = [
		_spec("Mark1", "ch_lancer", "co_null", "ar_scanner", "ar_scanner", "mo_targeting"),
		_spec("Mark2", "ch_hauler", "co_slug", "ar_hammer", "ar_hammer", "mo_governor"),
		_spec("Cash1", "ch_brute", "co_mag", "ar_ripper", "ar_ripper", "mo_servo"),
		_spec("Cash2", "ch_dredge", "co_bile", "ar_saw", "ar_saw", "mo_ablative"),
		_spec("Cash3", "ch_lancer", "co_tesla", "ar_lance", "ar_lance", "mo_targeting"),
		_spec("Cash4", "ch_strider", "co_arc", "ar_railgun", "ar_railgun", "mo_coolant"),
	]
	var unpaired: Array = []
	for i: int in 6:
		unpaired.append(_spec("Plain%d" % i, "ch_hauler", "co_slug", "ar_pulse", "ar_pulse", "mo_governor"))

	var total: int = 0
	for i: int in 30:
		var setup: BattleSetup = BattleSetup.make(3000 + i, paired, unpaired, "", "map_foundry_yard")
		var result: BattleResult = BattleSim.simulate(setup, [], _content.to_sim_content(), _content.balance)
		for e: Array in result.events.events:
			if e[SimEv.F_KIND] == SimEv.DETONATION:
				total += 1
	var per_battle: float = float(total) / 30.0
	_check("a purpose-built synergy squad detonates often (%.2f per battle)" % per_battle,
		per_battle >= 1.5)


func _spec(name: String, ch: String, co: String, al: String, ar: String, mo: String) -> Dictionary:
	return {"name": name, "parts": {
		"chassis": ch, "core": co, "arm_l": al, "arm_r": ar, "module": mo}}


# --- Harness -----------------------------------------------------------------

func _store() -> ProfileStore:
	_cleanup()
	return ProfileStore.open(_content, TEST_PATH)


func _grant_starter(store: ProfileStore) -> void:
	var starter: PackedStringArray = [
		"ch_brute", "ch_skirmisher", "ch_hauler",
		"co_slug", "co_dynamo", "co_furnace",
		"ar_ripper", "ar_hammer", "ar_pulse", "ar_scanner", "ar_lance",
		"mo_governor", "mo_ablative",
	]
	var commands: Array = []
	for part_id: String in starter:
		commands.append(ProfileCommands.GrantPart.new(part_id))
	store.execute_batch(commands)
	store.execute(ProfileCommands.SetSquad.new("main", [
		{"name": "Anvil", "parts": {"chassis": "ch_hauler", "core": "co_slug",
			"arm_l": "ar_hammer", "arm_r": "ar_hammer", "module": "mo_ablative"}},
		{"name": "Grinder", "parts": {"chassis": "ch_brute", "core": "co_furnace",
			"arm_l": "ar_ripper", "arm_r": "ar_ripper", "module": "mo_governor"}},
		{"name": "Ledger", "parts": {"chassis": "ch_hauler", "core": "co_slug",
			"arm_l": "ar_ripper", "arm_r": "ar_hammer", "module": "mo_ablative"}},
		{"name": "Sparrow", "parts": {"chassis": "ch_skirmisher", "core": "co_dynamo",
			"arm_l": "ar_pulse", "arm_r": "ar_lance", "module": "mo_governor"}},
	]))


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		printerr("  FAIL  %s" % label)


func _cleanup() -> void:
	var directory: DirAccess = DirAccess.open("user://")
	if directory == null:
		return
	for path: String in [TEST_PATH, SaveFile.BACKUP_PATH, SaveFile.TEMP_PATH]:
		if FileAccess.file_exists(path):
			directory.remove(path)
