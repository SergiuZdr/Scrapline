class_name SaveFile
extends RefCounted

## Versioned save with a migration chain, built before there is anything to save.
##
## This exists on day one on purpose. A free-to-play game patches constantly, and every
## patch that adds a currency, a part slot or a building changes the shape of the save.
## A format that cannot migrate strands every existing player the first time the schema
## moves -- which in practice means month three, with real players in it. Retrofitting
## migration after that is the expensive kind of impossible.
##
## Rules:
##   - `VERSION` goes up by one whenever the saved shape changes.
##   - Every bump gets a `_migrate_N_to_N_plus_1` function, and none is ever deleted.
##   - Migrations run in sequence, so a save from version 1 walks all the way up.
##   - Writes are atomic: a power cut mid-write must not destroy the previous save.

const VERSION: int = 1
const SAVE_PATH: String = "user://profile.json"
const BACKUP_PATH: String = "user://profile.backup.json"
const TEMP_PATH: String = "user://profile.tmp.json"

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
		raw = file._read(BACKUP_PATH)
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

	var temp: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if temp == null:
		push_error("save: cannot open temp file")
		return false
	temp.store_string(JSON.stringify(payload, "\t"))
	temp.close()

	var directory: DirAccess = DirAccess.open("user://")
	if directory == null:
		return false
	if FileAccess.file_exists(path):
		directory.remove(BACKUP_PATH)
		directory.rename(path, BACKUP_PATH)
	return directory.rename(TEMP_PATH, path) == OK


## The shape a brand-new player starts with. Every field the game reads must appear
## here, so a fresh profile and a migrated one are structurally identical.
static func default_profile() -> Dictionary:
	return {
		"version": VERSION,
		"player": {"name": "Reclaimer", "level": 1, "xp": 0},
		"currencies": {"scrap": 500, "alloy": 0, "cores": 0},
		# part id -> {"level": int, "copies": int, "rarity_tier": int}
		"inventory": {},
		# Named squads, each six build specs in formation order.
		"squads": {"main": []},
		"doctrines": {},
		"foundry": {"buildings": {}, "last_collected": 0},
		# crate id -> {"opened": int, "since_pity": int}; "seed" advances every open so
		# any pull can be replayed exactly for a support ticket or a server check.
		"crates": {"seed": 20260809, "counters": {}},
		"campaign": {"cleared": [], "current_zone": 0},
		"stats": {"battles": 0, "wins": 0},
		# Which one-time tips the player has already been shown.
		"seen_tips": [],
		# Async PvP standing. Rating survives a season; matches reset with it.
		"pvp": {"id": "", "rating": 1000, "matches": 0, "wins": 0, "losses": 0, "season": -1},
		# Endless tower. `best_depth` is kept forever; the run resets weekly.
		"gauntlet": {"floor": 1, "best_depth": 0, "week": -1, "week_best": 0},
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
			_:
				# Unknown gap: fill in anything missing rather than losing the save.
				working = _fill_defaults(working)
		version += 1

	working["version"] = VERSION
	return _fill_defaults(working)


## Version 0 is any save written before versioning existed.
func _migrate_0_to_1(working: Dictionary) -> Dictionary:
	return _fill_defaults(working)


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


func status_name() -> String:
	match status:
		Status.OK: return "ok"
		Status.MISSING: return "new profile"
		Status.CORRUPT: return "corrupt"
		Status.TOO_NEW: return "too new"
		Status.MIGRATED: return "migrated"
	return "unknown"
