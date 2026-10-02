class_name RunStore
extends RefCounted

## The saved run: a seed, the content it was played against, and the list of actions.
## Nothing else. The state is rebuilt by replaying them, so the save cannot disagree with
## what the game would compute, and it stays a few kilobytes however long the run.
##
## `fight` holds the combat actions of a fight in progress, so quitting mid-fight
## resumes on the same turn rather than restarting the fight.
##
## Written after every action, atomically: to a temp file, then renamed over the old one.
## A crash mid-write leaves the previous save intact instead of half a file.

const VERSION: int = 1
const PATH: String = "user://run.json"
const TEMP_PATH: String = "user://run.tmp.json"
## Play-test 10: a tool (`--script`) never touches the player's own run. A screenshot that
## played a bot run to its end once wrote over a real save; tools get files of their own.
const TOOL_PATH: String = "user://tool_run.json"
const TOOL_TEMP_PATH: String = "user://tool_run.tmp.json"


static func _tool() -> bool:
	return OS.get_cmdline_args().has("--script")


static func path() -> String:
	return TOOL_PATH if _tool() else PATH


static func _temp() -> String:
	return TOOL_TEMP_PATH if _tool() else TEMP_PATH


static func encode(seed_value: int, content_version: String, actions: Array, fight: Array, options: Dictionary = {}) -> String:
	return JSON.stringify({"version": VERSION, "seed": seed_value, "content": content_version,
		"actions": actions, "fight": fight, "options": options})


## Parses a save. Returns `{}` if it is unreadable or from a newer version.
## JSON has no integers -- every number comes back a float -- so every number is turned
## back into an int here. An action with a float in it is a different action.
static func decode(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	var data: Dictionary = _ints(parsed)
	if int(data.get("version", 0)) > VERSION:
		return {}
	return {"seed": int(data.get("seed", 0)), "content": String(data.get("content", "")),
		"actions": data.get("actions", []), "fight": data.get("fight", []), "options": data.get("options", {})}


static func save(seed_value: int, content_version: String, actions: Array, fight: Array, options: Dictionary = {}) -> bool:
	var file: FileAccess = FileAccess.open(_temp(), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(encode(seed_value, content_version, actions, fight, options))
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(_temp()),
		ProjectSettings.globalize_path(path())) == OK


static func exists() -> bool:
	return FileAccess.file_exists(path())


static func load_saved() -> Dictionary:
	if not exists():
		return {}
	return decode(FileAccess.get_file_as_string(path()))


static func clear() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path()))


static func _ints(value: Variant) -> Variant:
	if value is float:
		return int(value)
	if value is Array:
		var out: Array = []
		for item: Variant in value:
			out.append(_ints(item))
		return out
	if value is Dictionary:
		var out: Dictionary = {}
		for key: Variant in value:
			out[key] = _ints(value[key])
		return out
	return value
