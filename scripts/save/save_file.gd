class_name SaveFile
extends RefCounted

## The player's profile: versioned, migrated, written atomically with a backup.
##
## Since 012 it holds what outlives a run -- whether the shakedown (the tutorial) was played
## and which first-time hints were seen -- and nothing else yet. Version 1 was the archived
## free-to-play game's profile; migrating from it keeps the tips it had seen and drops the
## rest. A format that cannot migrate strands every player the first time the schema moves,
## which is why this existed before there was anything to save.
##
## Rules:
##   - `VERSION` goes up by one whenever the saved shape changes.
##   - Every bump gets a `_migrate_N_to_N_plus_1` function, and none is ever deleted.
##   - Migrations run in sequence, so a save from version 1 walks all the way up.
##   - Writes are atomic: a power cut mid-write must not destroy the previous save.

const VERSION: int = 2
const SAVE_PATH: String = "user://profile.json"
const BACKUP_PATH: String = "user://profile.backup.json"
const TEMP_PATH: String = "user://profile.tmp.json"


## The backup and temp files live beside the save they belong to: a test writing its own
## profile must never promote itself into the real profile's backup (it did, until 012).
static func backup_of(path: String) -> String:
	return BACKUP_PATH if path == SAVE_PATH else path.get_basename() + ".backup.json"


static func temp_of(path: String) -> String:
	return TEMP_PATH if path == SAVE_PATH else path.get_basename() + ".tmp.json"

enum Status { OK, MISSING, CORRUPT, TOO_NEW, MIGRATED }

var status: int = Status.MISSING
var data: Dictionary = {}
var loaded_version: int = 0
var message: String = ""


## Reads, validates and migrates the save. Never returns null and never throws: a
## missing or unreadable save yields a fresh profile, because a player who cannot get
## past the title screen is worse off than one who lost progress.
static func load_from(path: String = SAVE_PATH) -> SaveFile:
	var file := SaveFile.new()

	var raw: Variant = file._read(path)
	if raw == null:
		# The main save failed. Try the backup before giving up on the player.
		raw = file._read(backup_of(path))
		if raw != null:
			file.message = "main save unreadable, recovered from backup"

	if raw == null:
		file.status = Status.MISSING if not FileAccess.file_exists(path) else Status.CORRUPT
		file.data = default_profile()
		return file

	var loaded: Dictionary = raw as Dictionary
	file.loaded_version = int(loaded.get("version", 0))

	if file.loaded_version > VERSION:
		# A save written by a newer build. Refuse rather than silently dropping
		# whatever fields this build does not understand.
		file.status = Status.TOO_NEW
		file.message = "save is version %d, this build understands %d" % [file.loaded_version, VERSION]
		file.data = default_profile()
		return file

	var migrated: bool = file.loaded_version < VERSION
	file.data = file._migrate(loaded, file.loaded_version)
	file.status = Status.MIGRATED if migrated else Status.OK
	if migrated:
		file.message = "migrated save from version %d to %d" % [file.loaded_version, VERSION]
	return file


## Atomic write: serialise to a temp file, promote the current save to backup, then
## move the temp into place. An interrupted write leaves the previous save intact.
static func save_to(data: Dictionary, path: String = SAVE_PATH) -> bool:
	var payload: Dictionary = data.duplicate(true)
	payload["version"] = VERSION
	payload["saved_at"] = Time.get_unix_time_from_system()

	var temp: FileAccess = FileAccess.open(temp_of(path), FileAccess.WRITE)
	if temp == null:
		push_error("save: cannot open temp file")
		return false
	temp.store_string(JSON.stringify(payload, "\t"))
	temp.close()

	var directory: DirAccess = DirAccess.open("user://")
	if directory == null:
		return false
	if FileAccess.file_exists(path):
		directory.remove(backup_of(path))
		directory.rename(path, backup_of(path))
	return directory.rename(temp_of(path), path) == OK


## The shape a brand-new player starts with. Every field the game reads must appear
## here, so a fresh profile and a migrated one are structurally identical.
static func default_profile() -> Dictionary:
	return {
		"version": VERSION,
		# The shakedown (012's tutorial fight) has been played through, or skipped for good.
		"tutorial_done": false,
		# Which one-time hints the player has already been shown.
		"seen_tips": [],
	}


# --- Migration ---------------------------------------------------------------

## Walks a save up to the current version, one step at a time. Adding a version means
## adding a branch here and never touching the ones below it.
func _migrate(loaded: Dictionary, from_version: int) -> Dictionary:
	var working: Dictionary = loaded.duplicate(true)
	var version: int = from_version

	while version < VERSION:
		match version:
			0:
				working = _migrate_0_to_1(working)
			1:
				working = _migrate_1_to_2(working)
			_:
				# Unknown gap: fill in anything missing rather than losing the save.
				working = _fill_defaults(working)
		version += 1

	working["version"] = VERSION
	return _fill_defaults(working)


## Version 0 is any save written before versioning existed.
func _migrate_0_to_1(working: Dictionary) -> Dictionary:
	return _fill_defaults(working)


## Version 1 was the archived free-to-play game's profile (currencies, crates, squads, PvP).
## None of it means anything to the roguelike; the tips it had shown still do.
func _migrate_1_to_2(working: Dictionary) -> Dictionary:
	var fresh: Dictionary = default_profile()
	fresh["seen_tips"] = (working.get("seen_tips", []) as Array).duplicate()
	return fresh


## Backfills every key the current build expects. Runs after every migration so a
## field added this patch appears on old saves without needing its own migration step.
func _fill_defaults(working: Dictionary) -> Dictionary:
	var defaults: Dictionary = default_profile()
	for key: Variant in defaults.keys():
		if not working.has(key):
			working[key] = defaults[key]
		elif working[key] is Dictionary and defaults[key] is Dictionary:
			for inner: Variant in (defaults[key] as Dictionary).keys():
				if not (working[key] as Dictionary).has(inner):
					(working[key] as Dictionary)[inner] = (defaults[key] as Dictionary)[inner]
	return working


func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("save: %s: line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	if not (json.data is Dictionary):
		return null
	return json.data
