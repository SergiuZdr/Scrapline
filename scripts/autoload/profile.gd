extends Node

## The player's profile, as the `Profile` autoload (012): what outlives a run -- whether the
## shakedown has been played, which first-time hints have been seen.
##
## It changes ONLY through the methods below, and each one saves before it returns. That is
## the old game's hardest lesson: a write straight into the profile dictionary typechecked,
## ran, and evaporated at the next launch, because nothing had told the save it happened.

var _path: String = SaveFile.SAVE_PATH
var _data: Dictionary = {}


func _ready() -> void:
	_load()


## Points the profile at another file and reloads it -- for tests, so they never touch the
## player's own profile.
func use_path(path: String) -> void:
	_path = path
	_load()


func tutorial_done() -> bool:
	return bool(_data.get("tutorial_done", false))


func finish_tutorial() -> void:
	if tutorial_done():
		return
	_data["tutorial_done"] = true
	_save()


func seen(tip: String) -> bool:
	return (_data.get("seen_tips", []) as Array).has(tip)


func mark_seen(tip: String) -> void:
	if seen(tip):
		return
	var tips: Array = _data.get("seen_tips", [])
	tips.append(tip)
	_data["seen_tips"] = tips
	_save()


## Shows every first-time hint again (and offers the shakedown again).
func reset_hints() -> void:
	_data["seen_tips"] = []
	_data["tutorial_done"] = false
	_save()


func _load() -> void:
	_data = SaveFile.load_from(_path).data


func _save() -> void:
	SaveFile.save_to(_data, _path)
