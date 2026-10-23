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
	_test_settings_survive_reload()
	_test_run_history()

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


## 082 (A16, A24): the playback speed and the volume are profile commands; a reload keeps them.
func _test_settings_survive_reload() -> void:
	_cleanup()
	var profile: Node = root.get_node_or_null("Profile")
	_check("(precondition) the Profile autoload exists", profile != null)
	if profile == null:
		return
	profile.call("use_path", TEST_PATH)
	_check("a fresh profile plays back at 1x, full volume", int(profile.call("playback")) == 1 and int(profile.call("volume")) == 100)
	profile.call("set_playback", 3)
	profile.call("set_volume", 50)
	profile.call("use_path", TEST_PATH)
	_check("playback 3x and volume 50 survive a reload of the profile",
		int(profile.call("playback")) == 3 and int(profile.call("volume")) == 50)
	_check("the volume is applied to the master bus", absf(AudioServer.get_bus_volume_db(0) - linear_to_db(0.5)) < 0.01
		and not AudioServer.is_bus_mute(0))
	profile.call("set_playback", 9)
	profile.call("set_volume", 0)
	profile.call("use_path", TEST_PATH)
	_check("speeds clamp to 1-3, volume 0 mutes the bus", int(profile.call("playback")) == 3 and AudioServer.is_bus_mute(0))
	profile.call("set_volume", 100)
	profile.call("use_path", "user://tool_profile.json")


## 084 (B8): the run history is written by a Profile command, survives a restart (a reload of the
## file), keeps each run once, and keeps the last 50, newest first.
func _test_run_history() -> void:
	_cleanup()
	var profile: Node = root.get_node_or_null("Profile")
	if profile == null:
		_check("(precondition) the Profile autoload exists", false)
		return
	profile.call("use_path", TEST_PATH)
	_check("a fresh profile has no run history", (profile.call("run_history") as Array).is_empty())
	var first: Dictionary = {"key": "11:40", "seed": 11, "code": "ANVIL-ARC-ASH-0001", "seeded": false, "crew": "salvagers",
		"tier": 1, "act": 2, "ended": "wrecked", "reason": "The whole crew is wrecked.", "fights": 7,
		"parts": [["ch_a", "ar_hammer", "", "co_slug", "mo_governor:a"], ["ch_b"], ["ch_c"]],
		"names": ["KNUCKLES", "NEEDLE", "RELAY"], "options": {"crew_id": "salvagers", "tier": 1, "locked": ["ar_ripper"]}}
	profile.call("record_run", first)
	profile.call("record_run", first)
	profile.call("use_path", TEST_PATH)
	var back: Array = profile.call("run_history")
	_check("a run in the history survives a restart, once (%d)" % back.size(), back.size() == 1)
	var entry: Dictionary = back[0] if not back.is_empty() else {}
	_check("with its seed code, crew, tier, act, ending, fights and parts", String(entry.get("code", "")) == "ANVIL-ARC-ASH-0001"
		and String(entry.get("crew", "")) == "salvagers" and int(entry.get("tier", -1)) == 1 and int(entry.get("act", 0)) == 2
		and String(entry.get("ended", "")) == "wrecked" and int(entry.get("fights", 0)) == 7
		and str(entry.get("parts", [])) == str(first["parts"]) and not String(entry.get("date", "")).is_empty())
	var options: Variant = RunStore._ints(entry.get("options", {}))
	_check("with the machines' names and the run's options, ints again through RunStore._ints (PLAY THIS SEED replays them)",
		(entry.get("names", []) as Array) == ["KNUCKLES", "NEEDLE", "RELAY"] and options is Dictionary
		and typeof((options as Dictionary).get("tier")) == TYPE_INT and int((options as Dictionary)["tier"]) == 1
		and (options as Dictionary).get("locked") == ["ar_ripper"])
	for i: int in 60:
		profile.call("record_run", {"key": "run%d" % i, "seed": i, "ended": "won" if i % 3 == 0 else "wrecked", "act": 1 + i % 3})
	profile.call("use_path", TEST_PATH)
	back = profile.call("run_history")
	_check("the history keeps the last 50 (%d), newest first" % back.size(), back.size() == 50
		and String((back[0] as Dictionary)["key"]) == "run59" and String((back[49] as Dictionary)["key"]) == "run10")
	profile.call("use_path", "user://tool_profile.json")


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
