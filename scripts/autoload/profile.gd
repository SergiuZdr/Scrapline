extends Node

## The player's profile, as the `Profile` autoload (012): what outlives a run -- whether the
## shakedown has been played, which first-time hints have been seen.
##
## It changes ONLY through the methods below, and each one saves before it returns. That is
## the old game's hardest lesson: a write straight into the profile dictionary typechecked,
## ran, and evaporated at the next launch, because nothing had told the save it happened.

var _path: String = SaveFile.SAVE_PATH
const TOOL_PATH: String = "user://tool_profile.json"
var _data: Dictionary = {}


func _ready() -> void:
	# Play-test 10: a tool (`--script`) gets a profile of its own, every hint already seen, so a
	# screenshot or a test can never bank a bot's run into the player's unlocks.
	if OS.get_cmdline_args().has("--script"):
		_path = TOOL_PATH
		_load()
		if not tutorial_done():
			_data["tutorial_done"] = true
			var tutorial: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorial.json"))
			if tutorial is Dictionary:
				_data["seen_tips"] = ((tutorial as Dictionary).get("hints", {}) as Dictionary).keys()
			_save()
		return
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


## Play-test 11: the unlocks earned but not yet looked at on the UNLOCKS screen. A profile from
## before this has no record: the last run's new unlocks count as unseen, the rest as seen.
func unseen_unlocks() -> Array:
	var seen: Array = _data.get("unlocks_seen", []) if _data.has("unlocks_seen") else \
		unlocked().filter(func(id: Variant) -> bool: return not (_data.get("banked_new", []) as Array).has(id))
	return unlocked().filter(func(id: Variant) -> bool: return not seen.has(id))


## The last act whose arrival was told for the run with this seed (040: once a run, CONTINUE too).
func act_told(run_key: String) -> int:
	var told: Dictionary = _data.get("acts_told", {})
	return int(told.get(run_key, 1))


func tell_act(run_key: String, act: int) -> void:
	# Only the latest run is worth keeping: a new run's seed replaces the record.
	_data["acts_told"] = {run_key: act}
	_save()


## Everything held has now been seen on the UNLOCKS screen.
func mark_unlocks_seen() -> void:
	_data["unlocks_seen"] = unlocked()
	_save()


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


## Names the player gave a crew's machines (027), by crew id and slot: a new run of that crew
## starts with them. "" where the crew's own name stands.
func crew_names(crew_id: String) -> Array:
	return ((_data.get("names", {}) as Dictionary).get(crew_id, []) as Array).duplicate()


func set_crew_name(crew_id: String, slot: int, name: String) -> void:
	var names: Dictionary = (_data.get("names", {}) as Dictionary).duplicate(true)
	var list: Array = names.get(crew_id, [])
	while list.size() <= slot:
		list.append("")
	list[slot] = name
	names[crew_id] = list
	_data["names"] = names
	_save()


## The SOUND switch on the title (023).
func sound_on() -> bool:
	return bool(_data.get("sound", true))


func set_sound(on: bool) -> void:
	_data["sound"] = on
	_save()
	Audio.set_enabled(on)


func _load() -> void:
	_data = SaveFile.load_from(_path).data
	Audio.set_enabled(sound_on())


func _save() -> void:
	SaveFile.save_to(_data, _path)
