extends SceneTree

## Save-system tests: round trip, migration, corruption recovery, and version guard.
##
## These run headless so a save-format change can never ship without proving it can
## still read what shipped before it.
##
##   godot --headless --path . --script res://tools/verify_save.gd

const TEST_PATH: String = "user://test_profile.json"

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("")
	print("=== save system ===")

	_test_fresh_profile()
	_test_round_trip()
	_test_migration_from_unversioned()
	_test_migration_from_the_old_game()
	_test_backfills_new_fields()
	_test_rejects_future_version()
	_test_recovers_from_corruption()

	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	print("")
	_cleanup()
	quit(1 if _failed > 0 else 0)


func _test_fresh_profile() -> void:
	_cleanup()
	var file: SaveFile = SaveFile.load_from(TEST_PATH)
	_check("missing save yields a fresh profile", file.status == SaveFile.Status.MISSING)
	_check("a fresh profile has not played the shakedown and has seen no hints",
		not bool(file.data["tutorial_done"]) and (file.data["seen_tips"] as Array).is_empty())


func _test_round_trip() -> void:
	_cleanup()
	var profile: Dictionary = SaveFile.default_profile()
	profile["tutorial_done"] = true
	profile["seen_tips"] = ["map", "garage"]
	_check("write succeeds", SaveFile.save_to(profile, TEST_PATH))

	var loaded: SaveFile = SaveFile.load_from(TEST_PATH)
	_check("round trip reads back cleanly", loaded.status == SaveFile.Status.OK)
	_check("round trip keeps the tutorial flag and the hints", bool(loaded.data["tutorial_done"])
		and (loaded.data["seen_tips"] as Array) == ["map", "garage"])
	_check("a test profile keeps its backup beside itself, never in the real profile's",
		SaveFile.backup_of(TEST_PATH) != SaveFile.BACKUP_PATH and SaveFile.backup_of(SaveFile.SAVE_PATH) == SaveFile.BACKUP_PATH)


## A save written before versioning existed.
func _test_migration_from_unversioned() -> void:
	_cleanup()
	var handle: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	handle.store_string(JSON.stringify({"seen_tips": ["map"]}))
	handle.close()

	var loaded: SaveFile = SaveFile.load_from(TEST_PATH)
	_check("unversioned save migrates", loaded.status == SaveFile.Status.MIGRATED)
	_check("migration keeps the player's data", (loaded.data["seen_tips"] as Array) == ["map"])
	_check("migration adds missing fields", loaded.data.has("tutorial_done"))
	_check("migration stamps the current version", int(loaded.data["version"]) == SaveFile.VERSION)


## Version 1 was the archived free-to-play profile: its tips survive, its economy does not.
func _test_migration_from_the_old_game() -> void:
	_cleanup()
	var old: Dictionary = {"version": 1, "currencies": {"scrap": 500}, "squads": {"main": []}, "seen_tips": ["hub"]}
	var handle: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	handle.store_string(JSON.stringify(old))
	handle.close()
	var loaded: SaveFile = SaveFile.load_from(TEST_PATH)
	_check("the old game's profile migrates, keeping its tips", loaded.status == SaveFile.Status.MIGRATED
		and (loaded.data["seen_tips"] as Array) == ["hub"])
	_check("and dropping the free-to-play economy", not loaded.data.has("currencies") and not loaded.data.has("squads"))


## A field added in a later patch must appear on an old save without its own migration.
func _test_backfills_new_fields() -> void:
	_cleanup()
	var partial: Dictionary = SaveFile.default_profile()
	partial.erase("tutorial_done")
	var handle: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	handle.store_string(JSON.stringify(partial))
	handle.close()

	var loaded: SaveFile = SaveFile.load_from(TEST_PATH)
	_check("a missing field is backfilled", loaded.data.has("tutorial_done") and not bool(loaded.data["tutorial_done"]))


func _test_rejects_future_version() -> void:
	_cleanup()
	var future: Dictionary = SaveFile.default_profile()
	future["version"] = SaveFile.VERSION + 5
	var handle: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	handle.store_string(JSON.stringify(future))
	handle.close()

	var loaded: SaveFile = SaveFile.load_from(TEST_PATH)
	_check("a save from a newer build is refused, not mangled", loaded.status == SaveFile.Status.TOO_NEW)


## Truncated JSON is what a power cut during a write used to look like. The atomic
## write should mean this never happens, but the recovery path is tested anyway.
func _test_recovers_from_corruption() -> void:
	_cleanup()
	var good: Dictionary = SaveFile.default_profile()
	good["seen_tips"] = ["keep me"]
	SaveFile.save_to(good, TEST_PATH)
	# Second write promotes the first to backup.
	SaveFile.save_to(good, TEST_PATH)

	var handle: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	handle.store_string('{"version": 2, "seen_ti')
	handle.close()

	var loaded: SaveFile = SaveFile.load_from(TEST_PATH)
	_check("corrupt save falls back to the backup", (loaded.data["seen_tips"] as Array) == ["keep me"])


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
	for path: String in [TEST_PATH, SaveFile.backup_of(TEST_PATH), SaveFile.temp_of(TEST_PATH)]:
		if FileAccess.file_exists(path):
			directory.remove(path)
