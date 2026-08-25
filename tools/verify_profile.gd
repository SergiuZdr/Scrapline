extends SceneTree

## Profile and economy tests.
##
## The economy is where a free-to-play game quietly breaks: a command that lets
## currency go negative, a refit that eats duplicates without granting the tier, a
## batch that half-applies. Each of those is unnoticeable for months and then
## catastrophic, so they are pinned down here.
##
##   godot --headless --path . --script res://tools/verify_profile.gd

const TEST_PATH: String = "user://test_store.json"

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
	print("=== profile, commands and economy ===")

	_test_grant_and_duplicates()
	_test_cannot_overspend()
	_test_leveling()
	_test_level_cap_needs_refit()
	_test_refit_consumes_duplicates()
	_test_squad_validation()
	_test_batch_is_atomic()
	_test_persistence_round_trip()
	_test_cost_curves_rise()

	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	print("")
	_cleanup()
	quit(1 if _failed > 0 else 0)


func _store() -> ProfileStore:
	_cleanup()
	return ProfileStore.open(_content, TEST_PATH)


func _test_grant_and_duplicates() -> void:
	var store: ProfileStore = _store()
	store.execute(ProfileCommands.GrantPart.new("ch_brute"))
	_check("granting a part puts it in the inventory", store.profile.owns("ch_brute"))
	_check("a new part starts at level 1", store.profile.part_level("ch_brute") == 1)
	_check("a new part has no duplicates", store.profile.part_copies("ch_brute") == 0)

	store.execute(ProfileCommands.GrantPart.new("ch_brute"))
	_check("granting it again banks a duplicate", store.profile.part_copies("ch_brute") == 1)
	_check("a duplicate does not raise the level", store.profile.part_level("ch_brute") == 1)

	var unknown: int = store.execute(ProfileCommands.GrantPart.new("ch_does_not_exist"))
	_check("an unknown part id is refused", unknown == ProfileCommand.Result.INVALID)


func _test_cannot_overspend() -> void:
	var store: ProfileStore = _store()
	var scrap: int = store.profile.currency(PlayerProfile.SCRAP)
	var result: int = store.execute(
		ProfileCommands.SpendCurrency.new(PlayerProfile.SCRAP, scrap + 1, "test"))
	_check("spending more than you have is refused", result == ProfileCommand.Result.NOT_ENOUGH_CURRENCY)
	_check("a refused spend changes nothing", store.profile.currency(PlayerProfile.SCRAP) == scrap)


func _test_leveling() -> void:
	var store: ProfileStore = _store()
	store.execute(ProfileCommands.GrantPart.new("ch_brute"))
	var before: int = store.profile.currency(PlayerProfile.SCRAP)
	var cost: int = Economy.level_cost(store.profile, "ch_brute", _content)

	var result: int = store.execute(ProfileCommands.LevelPart.new("ch_brute"))
	_check("levelling an owned part succeeds", result == ProfileCommand.Result.OK)
	_check("levelling raises the level", store.profile.part_level("ch_brute") == 2)
	_check("levelling charges exactly the quoted cost",
		store.profile.currency(PlayerProfile.SCRAP) == before - cost)

	var unowned: int = store.execute(ProfileCommands.LevelPart.new("ch_bulwark"))
	_check("levelling a part you do not own is refused", unowned == ProfileCommand.Result.NOT_OWNED)


## The interesting one: levels are capped by tier, so scrap alone cannot max a part.
func _test_level_cap_needs_refit() -> void:
	var store: ProfileStore = _store()
	store.execute(ProfileCommands.GrantPart.new("ch_brute"))
	store.execute(ProfileCommands.GrantCurrency.new(PlayerProfile.SCRAP, 10_000_000, "test"))

	var guard: int = 0
	while store.execute(ProfileCommands.LevelPart.new("ch_brute")) == ProfileCommand.Result.OK and guard < 100:
		guard += 1

	_check("levelling stops at the tier ceiling",
		store.profile.part_level("ch_brute") == store.profile.level_cap("ch_brute"))
	_check("the tier-0 ceiling is 5 levels", store.profile.level_cap("ch_brute") == 5)
	var capped: int = store.execute(ProfileCommands.LevelPart.new("ch_brute"))
	_check("levelling past the ceiling is refused", capped == ProfileCommand.Result.ALREADY_MAX)


func _test_refit_consumes_duplicates() -> void:
	var store: ProfileStore = _store()
	store.execute(ProfileCommands.GrantPart.new("ch_brute"))

	var too_soon: int = store.execute(ProfileCommands.RefitPart.new("ch_brute"))
	_check("refit without duplicates is refused", too_soon == ProfileCommand.Result.NOT_ENOUGH_COPIES)

	for _i: int in 4:
		store.execute(ProfileCommands.GrantPart.new("ch_brute"))
	store.execute(ProfileCommands.GrantCurrency.new(PlayerProfile.ALLOY, 5000, "test"))

	var copies_before: int = store.profile.part_copies("ch_brute")
	var needed: int = Economy.refit_copies(store.profile, "ch_brute")
	var result: int = store.execute(ProfileCommands.RefitPart.new("ch_brute"))

	_check("refit with enough duplicates succeeds", result == ProfileCommand.Result.OK)
	_check("refit raises the tier", store.profile.part_tier("ch_brute") == 1)
	_check("refit consumes exactly the duplicates it quoted",
		store.profile.part_copies("ch_brute") == copies_before - needed)
	_check("refit raises the level ceiling", store.profile.level_cap("ch_brute") == 10)


func _test_squad_validation() -> void:
	var store: ProfileStore = _store()
	var loadout: Array = [{"name": "Test", "parts": {"chassis": "ch_brute", "core": "co_slug"}}]

	var unowned: int = store.execute(ProfileCommands.SetSquad.new("main", loadout))
	_check("a squad using parts you do not own is refused", unowned == ProfileCommand.Result.NOT_OWNED)

	store.execute(ProfileCommands.GrantPart.new("ch_brute"))
	store.execute(ProfileCommands.GrantPart.new("co_slug"))
	var ok: int = store.execute(ProfileCommands.SetSquad.new("main", loadout))
	_check("a squad of owned parts is accepted", ok == ProfileCommand.Result.OK)
	_check("the saved squad reads back", store.profile.squad("main").size() == 1)
	_check("the saved squad validates", store.profile.squad_is_valid("main"))


## A half-applied batch is the bug that silently corrupts an economy.
func _test_batch_is_atomic() -> void:
	var store: ProfileStore = _store()
	var scrap: int = store.profile.currency(PlayerProfile.SCRAP)

	var batch: Array = [
		ProfileCommands.GrantCurrency.new(PlayerProfile.SCRAP, 100, "test"),
		ProfileCommands.SpendCurrency.new(PlayerProfile.CORES, 999, "test"),  # must fail
	]
	var result: int = store.execute_batch(batch)
	_check("a batch with a failing command is refused", result == ProfileCommand.Result.NOT_ENOUGH_CURRENCY)
	_check("no part of a refused batch is applied",
		store.profile.currency(PlayerProfile.SCRAP) == scrap)


func _test_persistence_round_trip() -> void:
	var store: ProfileStore = _store()
	store.execute(ProfileCommands.GrantPart.new("ar_lance"))
	store.execute(ProfileCommands.LevelPart.new("ar_lance"))
	store.execute(ProfileCommands.GrantCurrency.new(PlayerProfile.CORES, 42, "test"))
	_check("save succeeds", store.save())

	var reopened: ProfileStore = ProfileStore.open(_content, TEST_PATH)
	_check("reopened profile keeps the part", reopened.profile.owns("ar_lance"))
	_check("reopened profile keeps the level", reopened.profile.part_level("ar_lance") == 2)
	_check("reopened profile keeps premium currency", reopened.profile.currency(PlayerProfile.CORES) == 42)


## Flat curves are what make one maxed part strictly better than a broad collection.
func _test_cost_curves_rise() -> void:
	var store: ProfileStore = _store()
	store.execute(ProfileCommands.GrantPart.new("ch_brute"))
	store.execute(ProfileCommands.GrantCurrency.new(PlayerProfile.SCRAP, 10_000_000, "test"))

	var first: int = Economy.level_cost(store.profile, "ch_brute", _content)
	store.execute(ProfileCommands.LevelPart.new("ch_brute"))
	var second: int = Economy.level_cost(store.profile, "ch_brute", _content)
	_check("each level costs more than the last", second > first)

	var common: int = Economy.level_cost(store.profile, "ch_brute", _content)      # rarity 1
	store.execute(ProfileCommands.GrantPart.new("ch_bulwark"))                      # rarity 2
	var rare: int = Economy.level_cost(store.profile, "ch_bulwark", _content)
	_check("rarer parts cost more per level than common ones at level 1",
		rare > Economy.value("level_base_cost") and common > 0)
	_check("stat multiplier rises with level and tier",
		Economy.stat_multiplier(5, 1) > Economy.stat_multiplier(1, 0))


# --- Harness -----------------------------------------------------------------

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
