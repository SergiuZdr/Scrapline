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
	_check("fresh profile has starting scrap", int(file.data["currencies"]["scrap"]) == 500)


func _test_round_trip() -> void:
	_cleanup()
	var profile: Dictionary = SaveFile.default_profile()
	profile["currencies"]["scrap"] = 1234
	profile["inventory"]["ch_brute"] = {"level": 3, "copies": 2, "rarity_tier": 1}
	_check("write succeeds", SaveFile.save_to(profile, TEST_PATH))

	var loaded: SaveFile = SaveFile.load_from(TEST_PATH)
	_check("round trip reads back cleanly", loaded.status == SaveFile.Status.OK)
	_check("round trip preserves currency", int(loaded.data["currencies"]["scrap"]) == 1234)
	_check("round trip preserves inventory", int(loaded.data["inventory"]["ch_brute"]["level"]) == 3)


## The case that actually matters: a save written before versioning existed.
func _test_migration_from_unversioned() -> void:
	_cleanup()
	var ancient: Dictionary = {"currencies": {"scrap": 77}}
	var handle: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	handle.store_string(JSON.stringify(ancient))
	handle.close()

	var loaded: SaveFile = SaveFile.load_from(TEST_PATH)
	_check("unversioned save migrates", loaded.status == SaveFile.Status.MIGRATED)
	_check("migration keeps the player's data", int(loaded.data["currencies"]["scrap"]) == 77)
	_check("migration adds missing sections", loaded.data.has("foundry"))
	_check("migration stamps the current version", int(loaded.data["version"]) == SaveFile.VERSION)


## A field added in a later patch must appear on an old save without its own migration.
func _test_backfills_new_fields() -> void:
	_cleanup()
	var partial: Dictionary = SaveFile.default_profile()
	partial["currencies"].erase("alloy")
	partial.erase("campaign")
	var handle: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	handle.store_string(JSON.stringify(partial))
	handle.close()

	var loaded: SaveFile = SaveFile.load_from(TEST_PATH)
	_check("missing top-level section is backfilled", loaded.data.has("campaign"))
	_check("missing nested field is backfilled", (loaded.data["currencies"] as Dictionary).has("alloy"))


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
	good["currencies"]["scrap"] = 999
	SaveFile.save_to(good, TEST_PATH)
	# Second write promotes the first to backup.
	SaveFile.save_to(good, TEST_PATH)

	var handle: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	handle.store_string('{"version": 1, "currencies": {"scr')
	handle.close()

	var loaded: SaveFile = SaveFile.load_from(TEST_PATH)
	_check("corrupt save falls back to the backup", int(loaded.data["currencies"]["scrap"]) == 999)


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
