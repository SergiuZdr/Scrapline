extends SceneTree

## The co-op boss: is the colossus a target-priority puzzle, and does a shared pool hold?
##
##   godot --headless --path . --script res://tools/verify_coop.gd
##
## Two questions, and the first is a design question rather than a code one:
##
##   - **Does breaking the limbs matter?** If shooting the core works about as well, the
##     boss is a health bar with extra steps and every squad plays it the same way.
##   - **Does a losing attempt still count?** A guild boss that only pays the squads who
##     win it is a boss only the strongest members ever touch.

const TEST_PATH: String = "user://test_coop.json"

var _content: ContentDB
var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_content = ContentDB.load_all()
	if not _content.errors.is_empty():
		for e: String in _content.errors:
			printerr("content: ", e)
		quit(2)
		return

	print("")
	print("=== the co-op colossus ===")

	_test_the_boss_is_authored_correctly()
	_test_the_core_is_guarded()
	_test_killing_the_core_ends_it()
	_test_damage_scales_with_the_squad()
	_test_the_pool_is_shared()
	_test_attempts_are_capped()
	_test_a_losing_attempt_still_pays()

	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	_cleanup()
	quit(1 if _failed > 0 else 0)


func _test_the_boss_is_authored_correctly() -> void:
	print("\n  the colossus")
	var boss: Dictionary = _boss()
	_check("a boss is authored", not boss.is_empty())

	var specs: Array = Colossus.build_specs(boss)
	_check("it builds %d segments" % specs.size(), specs.size() >= 3)

	var vital: int = 0
	var guarded: int = 0
	for spec: Variant in specs:
		if bool((spec as Dictionary).get("vital", false)):
			vital += 1
		if (spec as Dictionary).has("guarded_by"):
			guarded += 1
	# Exactly one vital segment. Two would mean the fight ends when the easier one dies;
	# none would mean it never ends at all.
	_check("exactly one segment is vital", vital == 1)
	_check("and it is the guarded one", guarded == 1)

	var built: Array[SimUnit] = UnitBuilder.build_squads(
		Colossus.build_setup(boss, _squad(200), 1, _content), _content.to_sim_content(),
		_content.balance)
	var core: SimUnit = _core_of(built)
	_check("the core carries its guards into the simulation",
		core != null and core.guard_refs.size() >= 3 and core.guarded_reduction > 0)


func _test_the_core_is_guarded() -> void:
	print("\n  breaking the limbs first")
	var boss: Dictionary = _boss()
	var setup: BattleSetup = Colossus.build_setup(boss, _squad(240), 909, _content)
	var units: Array[SimUnit] = UnitBuilder.build_squads(
		setup, _content.to_sim_content(), _content.balance)
	var attacker: SimUnit = units[0]
	var core: SimUnit = _core_of(units)

	var guarded: int = DamageResolver.compute(
		attacker, core, Balance.SCALE, _content.balance, false, 0, null, false, true)
	var exposed: int = DamageResolver.compute(
		attacker, core, Balance.SCALE, _content.balance, false, 0, null, false, false)

	_check("the core takes far less while a limb stands (%d vs %d)" % [guarded, exposed],
		guarded * 3 < exposed)
	# The reduction has to be a wall, not a nudge. If shooting the core anyway is only
	# slightly worse, the puzzle collapses into "shoot whatever is nearest".
	_check("stripping the limbs is worth at least 4x", exposed >= guarded * 4)


func _test_killing_the_core_ends_it() -> void:
	print("\n  the core is the win condition")
	var boss: Dictionary = _boss()
	var result: BattleResult = _fight(boss, _squad(320), 4242)

	if result.winner != SimDefs.TEAM_A:
		# Not a failure of the mechanic -- a strong squad is meant to be able to do this,
		# so if it cannot, the test says so plainly rather than passing silently.
		_check("a very strong squad can kill the core", false)
		return
	_check("a very strong squad wins by killing the core", true)

	var standing: int = 0
	for entry: Dictionary in result.final_units:
		if int(entry["ref"]) >= 10 and bool(entry.get("alive", false)):
			standing += 1
	# The point of `vital`: the fight ends with the core, not with the last limb.
	_check("and it ends with limbs still standing (%d)" % standing, standing > 0)


func _test_damage_scales_with_the_squad() -> void:
	print("\n  a weak squad still contributes")
	var boss: Dictionary = _boss()
	var weak: int = Colossus.damage_from(_fight(boss, _squad(110), 77))
	var strong: int = Colossus.damage_from(_fight(boss, _squad(260), 77))

	_check("a weak squad deals real damage (%d)" % weak, weak > 0)
	_check("a strong squad deals substantially more (%d)" % strong, strong > weak * 2)


func _test_the_pool_is_shared() -> void:
	print("\n  the shared pool")
	var service: CoopService = _service()
	service.refresh_local(1000)
	var encounter: Colossus.Encounter = service.encounter
	_check("an encounter opens", encounter != null and encounter.hp_remaining > 0)

	var pool: int = encounter.hp_pool
	# One attempt must be a dent, not a kill -- otherwise it is a solo boss with a guild
	# label on it.
	var one: int = Colossus.damage_from(_fight(_boss(), _squad(300), 5))
	_check("one attempt is a dent, not a kill (%d of %d)" % [one, pool], one > 0 and one < pool / 10)

	var outcome: Dictionary = service.resolve_attempt(one, 1000)
	_check("the pool went down by exactly the damage dealt",
		service.encounter.hp_remaining == pool - one)
	_check("the player's contribution is recorded", service.encounter.contributed == one)
	_check("and it paid scrap (%d)" % int(outcome.get("scrap", 0)), int(outcome["scrap"]) > 0)

	# Twenty players doing what one player did should be in the right order of magnitude
	# for a week-long fight, not off by ten.
	var attempts_to_kill: int = pool / maxi(1, one)
	_check("the pool needs a guild to finish it (%d attempts)" % attempts_to_kill,
		attempts_to_kill >= 20 and attempts_to_kill <= 400)


func _test_attempts_are_capped() -> void:
	print("\n  attempt limits")
	var service: CoopService = _service()
	service.refresh_local(2000)
	_check("a fresh window grants attempts (%d)" % service.attempts_left(),
		service.attempts_left() == CoopService.ATTEMPTS_PER_WINDOW)

	for _i: int in CoopService.ATTEMPTS_PER_WINDOW:
		service.resolve_attempt(10, 2000)
	_check("they run out", service.attempts_left() == 0)
	# Without a cap the boss belongs to whoever can sit at it longest, which is the least
	# interesting answer a co-op fight can have.
	_check("and the pool did not empty from one player grinding",
		service.encounter.hp_remaining > 0)


func _test_a_losing_attempt_still_pays() -> void:
	print("\n  losing well")
	var boss: Dictionary = _boss()
	var result: BattleResult = _fight(boss, _squad(120), 31)
	_check("the weak squad lost", result.winner != SimDefs.TEAM_A)

	var service: CoopService = _service()
	service.refresh_local(3000)
	var damage: int = Colossus.damage_from(result)
	var outcome: Dictionary = service.resolve_attempt(damage, 3000)
	_check("it still moved the bar (%d)" % damage, damage > 0)
	_check("and it still paid (%d scrap)" % int(outcome.get("scrap", 0)),
		int(outcome.get("scrap", 0)) > 0)


# --- Helpers -----------------------------------------------------------------

func _boss() -> Dictionary:
	var ids: Array = _content.bosses.keys()
	ids.sort()
	return _content.bosses[ids[0]] as Dictionary if not ids.is_empty() else {}


func _service() -> CoopService:
	_cleanup()
	var store: ProfileStore = ProfileStore.open(_content, TEST_PATH)
	return CoopService.open(_content, store.profile, store)


func _fight(boss: Dictionary, squad: Array, seed_value: int) -> BattleResult:
	var setup: BattleSetup = Colossus.build_setup(boss, squad, seed_value, _content)
	return BattleSim.simulate(setup, [], _content.to_sim_content(), _content.balance, [])


func _core_of(units: Array[SimUnit]) -> SimUnit:
	for u: SimUnit in units:
		if u.is_vital:
			return u
	return null


func _squad(power: int) -> Array:
	var builds: Array = [
		["ch_brute", "co_ember", "ar_hammer", "ar_hammer", "mo_overclock"],
		["ch_bulwark", "co_slug", "ar_ripper", "ar_ripper", "mo_ablative"],
		["ch_lancer", "co_mag", "ar_lance", "ar_lance", "mo_targeting"],
		["ch_strider", "co_tesla", "ar_railgun", "ar_scanner", "mo_targeting"],
		["ch_reaper", "co_solvent", "ar_saw", "ar_scatter", "mo_servo"],
		["ch_citadel", "co_arc", "ar_pulse", "ar_mortar", "mo_capacitor"],
	]
	var squad: Array = []
	for b: Variant in builds:
		var parts: Array = b as Array
		squad.append({"name": String(parts[0]), "power": power, "parts": {
			"chassis": parts[0], "core": parts[1], "arm_l": parts[2],
			"arm_r": parts[3], "module": parts[4]}})
	return squad


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
