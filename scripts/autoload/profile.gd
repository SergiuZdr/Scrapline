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


# --- Between-run progression (022) ---------------------------------------------

## Lifetime stats: `{ runs, fights, act, wins }`.
func stats() -> Dictionary:
	return (_data.get("stats", {}) as Dictionary).duplicate()


## The unlock ids held.
func unlocked() -> Array:
	return (_data.get("unlocked", []) as Array).duplicate()


## Counts a finished run once (`key` names it) and returns the unlock ids it newly earned.
func bank_run(key: String, state: RunState, rules: Dictionary) -> Array:
	if String(_data.get("banked", "")) == key:
		return _data.get("banked_new", [])
	var after: Dictionary = Meta.stats_after(stats(), state)
	var held: Array = unlocked()
	var fresh: Array = []
	for id: Variant in Meta.earned(after, rules):
		if not held.has(id):
			held.append(id)
			fresh.append(id)
	_data["stats"] = after
	_data["unlocked"] = held
	_data["banked"] = key
	_data["banked_new"] = fresh
	_save()
	return fresh


## The crew and tier the next run starts with, as last chosen.
func run_choice() -> Dictionary:
	return {"crew": String(_data.get("crew", "salvagers")), "tier": int(_data.get("tier", 0))}


func choose_run(crew: String, tier: int) -> void:
	_data["crew"] = crew
	_data["tier"] = tier
	_save()


func _load() -> void:
	_data = SaveFile.load_from(_path).data


func _save() -> void:
	SaveFile.save_to(_data, _path)
