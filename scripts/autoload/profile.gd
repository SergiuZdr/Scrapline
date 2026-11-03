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
		# 088 (A14): the objective callouts are hints too (`obj_<kind>`, words in story.json): a tool
		# profile made before them gets them marked seen, or a callout sits over a shot.
		var story: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/run/story.json"))
		if story is Dictionary:
			var tips: Array = _data.get("seen_tips", [])
			var added: bool = false
			for kind: Variant in ((story as Dictionary).get("objectives", {}) as Dictionary):
				if not String(kind).begins_with("_") and not tips.has("obj_" + String(kind)):
					tips.append("obj_" + String(kind))
					added = true
			if added:
				_data["seen_tips"] = tips
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
## 043, the ladder: a tier that opens becomes the next run's tier at once -- the player is
## carried up it without a choice screen, and may step back down from the title.
## 084 (B8): a SEEDED run (one the player chose the seed of) banks nothing -- no stats, no unlocks,
## no tier -- or a known winning seed would farm the ladder. It still goes into the run history.
func bank_run(key: String, state: RunState, rules: Dictionary, tier: int = 0, seeded: bool = false) -> Array:
	if seeded:
		return []
	if String(_data.get("banked", "")) == key:
		return _data.get("banked_new", [])
	var after: Dictionary = Meta.stats_after(stats(), state, tier)
	var held: Array = unlocked()
	var fresh: Array = []
	for id: Variant in Meta.earned(after, rules):
		if not held.has(id):
			held.append(id)
			fresh.append(id)
	_data["stats"] = after
	_data["unlocked"] = held
	for entry: Dictionary in (rules.get("unlocks", []) as Array):
		if fresh.has(String(entry["id"])) and String(entry.get("kind", "")) == "tier":
			_data["tier"] = maxi(int(_data.get("tier", 0)), int(entry["what"]))
	_data["banked"] = key
	_data["banked_new"] = fresh
	_save()
	return fresh


## 084 (B8): how many finished runs the ledger keeps, newest first.
const HISTORY_CAP: int = 50


## The last runs, newest first: `{key, seed, code, seeded, crew, tier, act, ended, reason, fights, parts, names, date}`
## (`ended` is "won", "wrecked", "gate" or "abandoned"; `parts` holds each machine's part ids).
func run_history() -> Array:
	return (_data.get("run_history", []) as Array).duplicate(true)


## Writes one finished run into the ledger, once per `entry.key`, and keeps the last 50.
func record_run(entry: Dictionary) -> void:
	var history: Array = _data.get("run_history", [])
	var key: String = String(entry.get("key", ""))
	for old: Variant in history:
		if not key.is_empty() and String((old as Dictionary).get("key", "")) == key:
			return
	var kept: Dictionary = entry.duplicate(true)
	if not kept.has("date"):
		kept["date"] = Time.get_date_string_from_system()
	history.push_front(kept)
	while history.size() > HISTORY_CAP:
		history.pop_back()
	_data["run_history"] = history
	_save()


# --- 085: the daily yard, the weekly contract, medals, trophies and liveries, crew records

## How many days of daily results the profile keeps (the streak is counted on its own).
const DAILY_CAP: int = 120


## A result as it is scored: acts cleared, then fights won, then HP left.
static func _score(result: Dictionary) -> Array:
	return [int(result.get("acts", 0)), int(result.get("fights", 0)), int(result.get("hp", 0))]


## Whether result `a` beats `b` ({} is beaten by anything).
static func better(a: Dictionary, b: Dictionary) -> bool:
	if b.is_empty():
		return true
	var x: Array = _score(a)
	var y: Array = _score(b)
	for i: int in 3:
		if int(x[i]) != int(y[i]):
			return int(x[i]) > int(y[i])
	return false


## A day's daily (`day`: days since 1970-01-01 UTC) as the profile has it: {} when not played, else
## `{day, seed, crew, ended, acts, fights, hp}` -- `ended` is "" while the attempt is still out.
func daily(day: int) -> Dictionary:
	return ((_data.get("daily", {}) as Dictionary).get(str(day), {}) as Dictionary).duplicate()


## Takes the day's one attempt (the user, 2026-10-22: abandoning counts). False if already taken.
func start_daily(day: int, seed_value: int, crew: String) -> bool:
	var all: Dictionary = (_data.get("daily", {}) as Dictionary).duplicate(true)
	if all.has(str(day)):
		return false
	all[str(day)] = {"day": day, "seed": seed_value, "crew": crew, "ended": "", "acts": 0, "fights": 0, "hp": 0}
	var days: Array = all.keys().map(func(k: Variant) -> int: return int(k))
	days.sort()
	while days.size() > DAILY_CAP:
		all.erase(str(days.pop_front()))
	_data["daily"] = all
	var streak: Dictionary = _data.get("daily_streak", {})
	var last: int = int(streak.get("last", -10))
	var count: int = int(streak.get("count", 0))
	_data["daily_streak"] = {"last": day, "count": count + 1 if last == day - 1 else (count if last == day else 1)}
	_save()
	return true


## The attempt's result, once: `{ended, acts, fights, hp}`. The best daily ever is kept beside it.
func finish_daily(day: int, result: Dictionary) -> void:
	var all: Dictionary = (_data.get("daily", {}) as Dictionary).duplicate(true)
	var entry: Dictionary = all.get(str(day), {})
	if entry.is_empty() or not String(entry.get("ended", "")).is_empty():
		return
	for key: String in ["ended", "acts", "fights", "hp"]:
		entry[key] = result.get(key, entry.get(key))
	all[str(day)] = entry
	_data["daily"] = all
	if better(entry, _data.get("daily_best", {})):
		_data["daily_best"] = entry.duplicate()
	_save()


## The best daily result ever played, or {}.
func daily_best() -> Dictionary:
	return (_data.get("daily_best", {}) as Dictionary).duplicate()


## Days in a row with a daily played, up to today (a streak still stands on a day not yet played).
func daily_streak(today: int) -> int:
	var streak: Dictionary = _data.get("daily_streak", {})
	return int(streak.get("count", 0)) if int(streak.get("last", -10)) >= today - 1 else 0


## A week's contract as the profile has it: `{attempts, best, cleared}`.
func weekly(week: int) -> Dictionary:
	var entry: Dictionary = ((_data.get("weekly", {}) as Dictionary).get(str(week), {}) as Dictionary).duplicate(true)
	return {"attempts": int(entry.get("attempts", 0)), "best": entry.get("best", {}), "cleared": bool(entry.get("cleared", false))}


## An attempt at the week's contract begins (any number are allowed).
func start_weekly(week: int) -> void:
	var all: Dictionary = (_data.get("weekly", {}) as Dictionary).duplicate(true)
	var entry: Dictionary = all.get(str(week), {})
	entry["attempts"] = int(entry.get("attempts", 0)) + 1
	all[str(week)] = entry
	# Only the last weeks are worth keeping; the trophies outlive them.
	var weeks: Array = all.keys().map(func(k: Variant) -> int: return int(k))
	weeks.sort()
	while weeks.size() > 12:
		all.erase(str(weeks.pop_front()))
	_data["weekly"] = all
	_save()


## An attempt ends (once per `key`): the best is kept, and clearing it (`result.won`) the first time
## gives the week's REWARD (`WeeklyRewards.for_week`: `{id, trophy, livery, name}`), cosmetic only: a
## trophy for the wall and its livery for any machine. Returns the trophy when this attempt earned it
## (`{id, trophy, livery, name, week, crew}`), else {}.
func finish_weekly(week: int, key: String, result: Dictionary, reward: Dictionary) -> Dictionary:
	if String(_data.get("weekly_banked", "")) == key:
		return {}
	_data["weekly_banked"] = key
	var all: Dictionary = (_data.get("weekly", {}) as Dictionary).duplicate(true)
	var entry: Dictionary = all.get(str(week), {"attempts": 1})
	if better(result, entry.get("best", {})):
		entry["best"] = result.duplicate()
	var fresh: Dictionary = {}
	if bool(result.get("won", false)) and not bool(entry.get("cleared", false)):
		entry["cleared"] = true
		var held: Array = _data.get("trophies", [])
		if not reward.is_empty() and not held.any(func(t: Variant) -> bool: return int((t as Dictionary).get("week", -1)) == week):
			fresh = _trophy(reward, week, String(reward.get("crew", "")))
			held.append(fresh)
			_data["trophies"] = held
	all[str(week)] = entry
	_data["weekly"] = all
	_save()
	return fresh.duplicate()


## A trophy as the profile keeps it.
static func _trophy(reward: Dictionary, week: int, crew: String) -> Dictionary:
	return {"id": String(reward.get("id", "")), "trophy": String(reward.get("trophy", "")), "livery": String(reward.get("livery", "")),
		"name": String(reward.get("name", "")), "week": week, "crew": crew}


## Every trophy earned, oldest first: `{id, trophy, livery, name, week, crew}` (one per cleared week).
func trophies() -> Array:
	return (_data.get("trophies", []) as Array).duplicate(true)


## Every livery a trophy has given, in the order they were earned (each once).
func liveries() -> Array:
	var out: Array = []
	for t: Variant in (_data.get("trophies", []) as Array):
		var id: String = String((t as Dictionary).get("livery", ""))
		if not id.is_empty() and not out.has(id):
			out.append(id)
	return out


## The livery a crew's machine (`slot`: its place in the crew) wears: an earned one, or "" (the makers' paint).
func livery_for(crew: String, slot: int) -> String:
	var id: String = String((_data.get("machine_liveries", {}) as Dictionary).get("%s:%d" % [crew, slot], ""))
	return id if liveries().has(id) else ""


## Paints a crew's machine in an earned livery ("" = back to the makers' paint). False if not earned.
func set_livery(crew: String, slot: int, id: String) -> bool:
	if not id.is_empty() and not liveries().has(id):
		return false
	var all: Dictionary = (_data.get("machine_liveries", {}) as Dictionary).duplicate()
	if id.is_empty():
		all.erase("%s:%d" % [crew, slot])
	else:
		all["%s:%d" % [crew, slot]] = id
	_data["machine_liveries"] = all
	_save()
	return true


## The medal ids a crew holds (B10).
func medals(crew: String) -> Array:
	return ((_data.get("medals", {}) as Dictionary).get(crew, []) as Array).duplicate()


## Adds the medals a finished run earned for its crew; returns those that are new.
func award_medals(crew: String, ids: Array) -> Array:
	var all: Dictionary = (_data.get("medals", {}) as Dictionary).duplicate(true)
	var held: Array = all.get(crew, [])
	var fresh: Array = []
	for id: Variant in ids:
		if not held.has(String(id)):
			held.append(String(id))
			fresh.append(String(id))
	if fresh.is_empty():
		return []
	all[crew] = held
	_data["medals"] = all
	_save()
	return fresh


## Every crew's medals and record at once, for the UNLOCKS screen: `{crew: {medals, record}}`.
func crew_marks() -> Dictionary:
	var out: Dictionary = {}
	var medal_map: Dictionary = _data.get("medals", {})
	var records: Dictionary = _data.get("crew_records", {})
	for crew: Variant in medal_map.keys() + records.keys():
		out[String(crew)] = {"medals": medals(String(crew)), "record": crew_record(String(crew))}
	return out


## The highest rung a crew has won (-1: none) -- the record stamp on its card (B4).
func crew_record(crew: String) -> int:
	return int((_data.get("crew_records", {}) as Dictionary).get(crew, -1))


func note_win(crew: String, rung: int) -> void:
	if crew_record(crew) >= rung:
		return
	var all: Dictionary = (_data.get("crew_records", {}) as Dictionary).duplicate()
	all[crew] = rung
	_data["crew_records"] = all
	_save()


## 085: what an older profile lacks, worked out once from what it holds. Crew records come from the
## run history's wins (seeded, daily and weekly runs never counted); the unlocks pass through
## `Meta.migrate_unlocks` when the rules provide one -- and nothing held is ever taken away.
func _migrate() -> void:
	var changed: bool = false
	if not _data.has("crew_records"):
		var records: Dictionary = {}
		for entry: Variant in (_data.get("run_history", []) as Array):
			var e: Dictionary = entry
			if String(e.get("ended", "")) == "won" and not bool(e.get("seeded", false)) and String(e.get("mode", "")).is_empty():
				var crew: String = String(e.get("crew", "salvagers"))
				records[crew] = maxi(int(records.get(crew, -1)), int(e.get("tier", 0)))
		_data["crew_records"] = records
		changed = not records.is_empty()
	var meta_script: GDScript = load("res://sim/run/meta.gd")
	var can: bool = meta_script.get_script_method_list().any(func(m: Dictionary) -> bool: return String(m["name"]) == "migrate_unlocks")
	if can and _data.has("unlocked"):
		var before: Array = unlocked()
		var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/meta.json"))
		if meta is Dictionary:
			var after: Array = (meta_script.call("migrate_unlocks", before, stats(), meta) as Array).duplicate()
			for id: Variant in before:
				if not after.has(id):
					after.append(id)
			if after != before:
				_data["unlocked"] = after
				changed = true
	# 085: the 3D weekly plates were dropped (the user, 2026-10-29): a plate held becomes the trophy and
	# livery its week gives now, so a profile from before keeps what it won.
	if _data.get("plates") is Array:
		var held: Array = _data.get("trophies", []) if _data.get("trophies") is Array else []
		for plate: Variant in (_data["plates"] as Array):
			if not (plate is Dictionary):
				continue
			var week: int = int((plate as Dictionary).get("week", -1))
			var reward: Dictionary = WeeklyRewards.for_week(week)
			if week >= 0 and not reward.is_empty() and not held.any(func(t: Variant) -> bool: return int((t as Dictionary).get("week", -1)) == week):
				held.append(_trophy(reward, week, String((plate as Dictionary).get("crew", ""))))
		_data["trophies"] = held
		_data.erase("plates")
		changed = true
	if changed:
		_save()


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


## 082 (A16): how fast fights play back, 1x, 2x or 3x. The enemy's turn plays at this speed; the
## player's own actions at most 2x.
func playback() -> int:
	return clampi(int(_data.get("playback", 1)), 1, 3)


func set_playback(speed: int) -> void:
	_data["playback"] = clampi(speed, 1, 3)
	_save()


## 082 (A24): the master volume, 0-100 in steps the settings sheet offers. SOUND OFF (`set_sound`)
## still silences the bank on its own.
func volume() -> int:
	return clampi(int(_data.get("volume", 100)), 0, 100)


func set_volume(level: int) -> void:
	_data["volume"] = clampi(level, 0, 100)
	_save()
	_apply_volume()


func _apply_volume() -> void:
	var level: int = volume()
	AudioServer.set_bus_mute(0, level <= 0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(level), 1.0) / 100.0))


func _load() -> void:
	_data = SaveFile.load_from(_path).data
	_migrate()
	Audio.set_enabled(sound_on())
	_apply_volume()


func _save() -> void:
	SaveFile.save_to(_data, _path)
