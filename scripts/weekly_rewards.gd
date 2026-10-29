class_name WeeklyRewards
extends RefCounted

## 085: what clearing a weekly contract gives -- a TROPHY for the garage's trophy wall and a LIVERY
## (a named paint scheme, `Ink.LIVERIES`) any crew machine may wear. Cosmetic only, never power.
##
## `data/weekly_rewards.json` is the rotation, `[{id, trophy, livery, name}]` in order: `trophy` is the
## picture `art/trophies/<trophy>.png`, `name` the trophy's. Not in the content hash (no rule reads it).
## The week's reward is the contract's own when its options name one (`reward`: an id from the list),
## else week mod the list's length.

const PATH: String = "res://data/weekly_rewards.json"

static var _list: Array = []


## The rotation, read once.
static func list() -> Array:
	if _list.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH)) if FileAccess.file_exists(PATH) else null
		if data is Array:
			for entry: Variant in (data as Array):
				if entry is Dictionary and not String((entry as Dictionary).get("id", "")).is_empty():
					_list.append(entry)
	return _list


## The reward with this id, or {}.
static func by_id(id: String) -> Dictionary:
	for entry: Dictionary in list():
		if String(entry["id"]) == id:
			return entry.duplicate()
	return {}


## Week `week`'s reward: the one the contract's options name (`options.reward`), else week mod N.
static func for_week(week: int, options: Dictionary = {}) -> Dictionary:
	var given: Variant = options.get("reward")
	if given is Dictionary:
		given = (given as Dictionary).get("id", "")
	if given is String and not by_id(String(given)).is_empty():
		return by_id(String(given))
	var all: Array = list()
	return (all[posmod(week, all.size())] as Dictionary).duplicate() if not all.is_empty() else {}


## The picture of a trophy, or null.
static func picture(trophy: String) -> Texture2D:
	var path: String = "res://art/trophies/%s.png" % trophy
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
