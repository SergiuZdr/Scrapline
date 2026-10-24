extends Node

## The live run, as the `Run` autoload: the only thing that changes it, and the only thing
## that saves it.
##
## Every screen hands actions to `apply`, which runs them through `RunSim` and writes the
## save before returning -- so there is no moment where the game has done something the
## save does not know about. A fight in progress is saved per combat action through
## `record_fight`, and a finished fight is handed back as its action log, which the run
## replays for itself rather than taking the combat scene's word for the result.

var db: ContentDB
var setup: RunSetup
var state: RunState
var actions: Array = []
## Combat actions of the fight in progress, saved so a quit mid-fight resumes mid-fight.
var fight_actions: Array = []
var active: bool = false
## Why the last CONTINUE failed, for the title screen to say.
var problem: String = ""
## Whether this run's briefing has been read. A new run starts unbriefed; CONTINUE does not
## show it again.
var briefed: bool = true
## Whether the assembly bay has been through this session (it opens once, after the
## briefing, while the crew can still be built).
var bay_seen: bool = false


func _ready() -> void:
	db = ContentDB.load_all()
	# 085: the start deals' pool, until ContentDB loads (and hashes) data/run/deals.json itself.
	if not db.run_rules.has("deals") and FileAccess.file_exists("res://data/run/deals.json"):
		var pool: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/run/deals.json"))
		if pool is Dictionary:
			db.run_rules["deals"] = RunStore._ints(pool)


func has_saved() -> bool:
	return RunStore.exists()


## What this run gave the profile (022): `{ "new": [unlock entries], "next": entry or {} }`.
## Banked once, whatever screen asks and however often. 084 (B8): the run goes into the history
## too, and a seeded run banks nothing else.
## 085: and a run that counts (`counts`) earns its crew's medals and, won, the crew's record rung;
## a daily or weekly run writes its result to the yard board instead (`medals`, `plate`, `yard`).
func bank() -> Dictionary:
	if not active or state.outcome == RunState.ONGOING:
		return {}
	var key: String = "%d:%d" % [setup.rng_seed, actions.size()]
	if _banked_key == key:
		return _banked
	_record(key)
	var tier: int = int(setup.options.get("tier", 0))
	var fresh: Array = Profile.bank_run(key, state, db.meta, tier, not counts())
	var entries: Array = []
	for entry: Dictionary in (db.meta.get("unlocks", []) as Array):
		if fresh.has(String(entry["id"])):
			entries.append(entry)
	var out: Dictionary = {"new": entries, "next": Meta.next_unlock(Profile.unlocked(), db.meta), "medals": [], "plate": {}}
	if counts():
		out["medals"] = Profile.award_medals(crew_id(), RunSim.medals_earned(state, setup))
		if state.outcome == RunState.WON:
			Profile.note_win(crew_id(), tier)
	elif mode() == DAILY:
		Profile.finish_daily(int(setup.options.get("day", -1)), result())
	elif mode() == WEEKLY:
		out["plate"] = Profile.finish_weekly(int(setup.options.get("week", -1)), key, result(), plate())
	_banked_key = key
	_banked = out
	return out


var _banked_key: String = ""
var _banked: Dictionary = {}


# --- 085: the daily yard and the weekly contract ------------------------------------

const DAILY: String = "daily"
const WEEKLY: String = "weekly"
## Tests set the day (days since 1970-01-01 UTC) the clock would give; -1 reads the clock.
var clock_day: int = -1


## "daily", "weekly" or "" for this run (`options.mode`).
func mode() -> String:
	return String(setup.options.get("mode", "")) if setup != null else ""


## Whether this run counts toward the ladder, unlocks, medals and records: not seeded, not a yard run.
func counts() -> bool:
	return setup != null and not is_seeded() and mode().is_empty()


## Today as days since 1970-01-01, by the local clock in UTC -- the only clock the yard reads, and
## never inside the sim.
func today() -> int:
	return clock_day if clock_day >= 0 else int(Time.get_unix_time_from_system()) / 86400


## This week as weeks since Monday 1970-01-05 (day 4).
func this_week() -> int:
	return (today() - 4) / 7


## The run as the yard board scores it: acts cleared, fights won, HP left.
func result(ended: String = "") -> Dictionary:
	if state == null:
		return {}
	if ended.is_empty():
		ended = "won" if state.outcome == RunState.WON else ("ongoing" if state.outcome == RunState.ONGOING else "wrecked")
	var hp: int = 0
	for member: Dictionary in state.crew:
		if bool(member["alive"]):
			hp += int(member["hp"])
	var won: bool = state.outcome == RunState.WON
	return {"ended": ended, "won": won, "acts": state.act - (0 if won else 1), "fights": state.fights_won, "hp": hp}


## The plate this week's contract gives when cleared (cosmetic only): the contract's own, or one
## named for its week.
func plate() -> Dictionary:
	var week: int = int(setup.options.get("week", this_week()))
	var given: Dictionary = setup.options.get("plate", {}) if setup.options.get("plate") is Dictionary else {}
	var monday: String = Time.get_date_string_from_unix_time((week * 7 + 4) * 86400)
	return {"id": String(given.get("id", "plate_w%d" % week)), "week": week, "crew": crew_id(),
		"name": String(given.get("name", "CONTRACT %s" % monday))}


func daily_options(day: int) -> Dictionary:
	return RunSetup.daily_options(db.run_rules, day)


func weekly_options(week: int) -> Dictionary:
	return RunSetup.weekly_options(db.run_rules, week)


## Plays today's daily: one attempt a day, taken as it starts (abandoning counts). Refused over a
## live run (as a seed is), when today's is played, or when there is none. False with `problem` set.
func new_daily() -> bool:
	problem = ""
	var day: int = today()
	var yard: Dictionary = daily_options(day)
	if has_saved():
		problem = "A run is in progress. Finish it, or abandon it in SETTINGS, before the daily yard."
		return false
	if not Profile.daily(day).is_empty():
		problem = "Today's yard is played. A new one opens tomorrow."
		return false
	if yard.is_empty():
		problem = "No yard is posted today."
		return false
	var options: Dictionary = yard_run_options(yard)
	options["mode"] = DAILY
	options["day"] = day
	if not Profile.start_daily(day, int(yard["seed"]), String(options.get("crew_id", "salvagers"))):
		problem = "Today's yard is played. A new one opens tomorrow."
		return false
	new_run(int(yard["seed"]), options)
	return true


## Plays this week's contract (any number of attempts; the best is kept). Refused over a live run.
func new_weekly() -> bool:
	problem = ""
	var week: int = this_week()
	var yard: Dictionary = weekly_options(week)
	if has_saved():
		problem = "A run is in progress. Finish it, or abandon it in SETTINGS, before the weekly contract."
		return false
	if yard.is_empty():
		problem = "No contract is posted this week."
		return false
	var options: Dictionary = yard_run_options(yard)
	options["mode"] = WEEKLY
	options["week"] = week
	Profile.start_weekly(week)
	new_run(int(yard["seed"]), options)
	return true


## A yard's options as a run's: the crew it fixes (or the one the player chose) and the rung it
## fixes, resolved by `Meta.options` as if that crew and rung were open, then the yard's own keys
## (its seed aside) over them.
func yard_run_options(yard: Dictionary) -> Dictionary:
	var crew: String = String(yard.get("crew_id", Profile.run_choice()["crew"]))
	# The sim's own resolution, the same for every profile (`Meta.challenge_options`), when it has one.
	var meta_script: GDScript = load("res://sim/run/meta.gd")
	if meta_script.get_script_method_list().any(func(m: Dictionary) -> bool: return String(m["name"]) == "challenge_options"):
		var resolved: Dictionary = meta_script.call("challenge_options", db.meta, yard, crew)
		resolved.erase(SEEDED)
		return resolved
	var rung: int = int(yard.get("rung", 0))
	var held: Array = Profile.unlocked()
	for entry: Dictionary in (db.meta.get("unlocks", []) as Array):
		var kind: String = String(entry.get("kind", ""))
		var opens: bool = (kind == "tier" and int(entry["what"]) <= rung) or (kind == "crew" and String(entry["what"]) == crew and yard.has("crew_id"))
		if opens and not held.has(String(entry["id"])):
			held.append(String(entry["id"]))
	var out: Dictionary = Meta.options(db.meta, held, crew, rung)
	for key: Variant in yard:
		if String(key) != "seed":
			out[key] = yard[key].duplicate(true) if (yard[key] is Dictionary or yard[key] is Array) else yard[key]
	out["tier"] = rung
	out.erase(SEEDED)
	return out


## A new run as the profile has it (022): the crew and tier last chosen, the parts unlocked.
func new_run_from_profile() -> void:
	new_run(-1, profile_options())


func profile_options() -> Dictionary:
	var choice: Dictionary = Profile.run_choice()
	return Meta.options(db.meta, Profile.unlocked(), String(choice["crew"]), int(choice["tier"]))


# --- 084 (B8): seeds -------------------------------------------------------------

## The run option that marks a run whose seed the player chose: it banks nothing (Profile.bank_run).
const SEEDED: String = "seeded"


func is_seeded() -> bool:
	return setup != null and RunSetup.is_seeded(setup.options)


## This run's seed as the short word code shown at its end ("" until the sim gives one).
func seed_code() -> String:
	return RunSetup.seed_code(setup.rng_seed, db.content_version()) if setup != null else ""


## A typed or pasted code: `{"seed": int}`, or `{"error": what is wrong with it}`.
func read_code(code: String) -> Dictionary:
	var text: String = code.strip_edges()
	if text.is_empty():
		return {"error": "Type or paste a seed code."}
	var parsed: Dictionary = RunSetup.parse_seed_code(text, db.content_version())
	if parsed.is_empty():
		return {"error": "\"%s\" is not a seed code." % text.left(40)}
	# The code carries the content version: another build's code would make another region.
	if bool(parsed.get("stale", false)):
		return {"error": "That code is from another version of the game: its region would not be the same."}
	return {"seed": int(parsed["seed"])}


## Starts a seeded run with these options (a replay passes the old run's, NEW RUN the profile's),
## unless a run is saved: a seeded run never overwrites a live save (084: it refuses rather than
## keeping a second slot). False with `problem` set when refused.
func new_seeded_run(seed_value: int, options: Dictionary) -> bool:
	problem = ""
	if has_saved():
		problem = "A run is in progress. Finish it, or abandon it in SETTINGS, before playing a seed."
		return false
	var seeded: Dictionary = options.duplicate(true)
	seeded[SEEDED] = true
	# 085: a daily or weekly played again from its seed is an ordinary seeded run, off the board.
	for key: String in ["mode", "day", "week"]:
		seeded.erase(key)
	new_run(seed_value, seeded)
	return true


## PLAY THIS SEED from a line of the history: that seed with the options the run had (kept in the
## line), or -- for a line from before they were kept -- its crew and tier with today's unlocks.
func play_entry(entry: Dictionary) -> bool:
	var options: Dictionary = entry.get("options", {})
	if options.is_empty():
		options = Meta.options(db.meta, Profile.unlocked(), String(entry.get("crew", "salvagers")), int(entry.get("tier", 0)))
	# The profile is JSON: its numbers come back as floats, and an option holding a float is a
	# different option.
	options = RunStore._ints(options.duplicate(true))
	options.erase(SEEDED)
	return new_seeded_run(int(entry.get("seed", -1)), options) if int(entry.get("seed", -1)) >= 0 else false


## The run as one line of the history (`Profile.record_run`), once per `key`.
func _record(key: String, ended: String = "") -> void:
	if setup == null or state == null:
		return
	if ended.is_empty():
		ended = "won" if state.outcome == RunState.WON else ("gate" if state.end_reason.begins_with("The gate held") else "wrecked")
	var parts: Array = []
	for member: Dictionary in state.crew:
		parts.append((member["parts"] as Array).duplicate())
	Profile.record_run({"key": key, "seed": setup.rng_seed, "code": seed_code(), "seeded": is_seeded(),
		"crew": crew_id(), "tier": int(setup.options.get("tier", 0)), "act": state.act, "ended": ended,
		"reason": state.end_reason, "fights": state.fights_won, "parts": parts,
		"names": state.crew.map(func(m: Dictionary) -> String: return String(m["name"])),
		"options": setup.options.duplicate(true), "mode": mode()})


func new_run(seed_value: int = -1, options: Dictionary = {}) -> void:
	# The only place a run reads the clock: choosing a seed. Everything after is seeded.
	if seed_value < 0:
		# 084: inside 24 bits (`RunSetup.SEED_MASK`), so every run's seed has a word code.
		seed_value = int(Time.get_unix_time_from_system() * 1000.0) & RunSetup.SEED_MASK
	setup = _make_setup(seed_value, options)
	state = RunSim.start(setup)
	actions = []
	fight_actions = []
	_banked_key = ""
	active = true
	briefed = false
	bay_seen = false
	# 084: the same seed played again tells its acts again (the record is keyed by seed).
	Profile.tell_act(str(seed_value), 1)
	_save()
	# The names the player gave this crew last time (027), as actions: the save holds them.
	var names: Array = Profile.crew_names(crew_id())
	for i: int in mini(names.size(), state.crew.size()):
		if not String(names[i]).is_empty() and String(names[i]) != String(state.crew[i]["name"]):
			apply([RunSim.RENAME, i, String(names[i])])


## Which crew this run started with (022).
func crew_id() -> String:
	return String(setup.options.get("crew_id", "salvagers")) if setup != null else "salvagers"


## Renames machine `i` for this run and remembers the name for the next run of this crew (027).
func rename(i: int, text: String) -> bool:
	var name: String = RunSim.clean_name(text)
	if name.is_empty() or not apply([RunSim.RENAME, i, name]):
		return false
	Profile.set_crew_name(crew_id(), i, name)
	return true


## Resumes the saved run. False (with `problem` set) if there is none or it cannot load.
func continue_run() -> bool:
	problem = ""
	var data: Dictionary = RunStore.load_saved()
	if data.is_empty():
		problem = "No saved run could be read."
		return false
	# A run replays against the content it was played with. If an update changed the
	# rules, the replay would be a different run, so say so instead of guessing.
	if String(data["content"]) != db.content_version():
		problem = "This run was saved with an older version of the game's rules and cannot be resumed."
		return false
	setup = _make_setup(int(data["seed"]), data.get("options", {}))
	state = RunSim.replay(setup, data["actions"])
	actions = (data["actions"] as Array).duplicate(true)
	fight_actions = (data["fight"] as Array).duplicate(true)
	_banked_key = ""
	active = true
	return true


func apply(action: Array) -> bool:
	if not active or not RunSim.apply(state, setup, action):
		return false
	actions.append(action)
	if int(action[0]) == RunSim.FIGHT:
		fight_actions = []
	_save()
	return true


func fight_setup() -> CombatSetup:
	return RunSim.fight_setup(state, setup) if active else null


func in_fight() -> bool:
	return active and String(state.pending.get("kind", "")) == "fight"


func record_fight(combat_actions: Array) -> void:
	fight_actions = combat_actions.duplicate(true)
	_save()


func finish_fight(combat_actions: Array) -> bool:
	return apply([RunSim.FIGHT, combat_actions.duplicate(true)])


## The player has seen the run's end. The save goes: a finished run is not resumable.
func end_run() -> void:
	active = false
	RunStore.clear()


## 082 (A24): the player gives the run up from the settings sheet. Nothing is banked: the save
## goes, as at the run's end, and the title offers NEW RUN.
func abandon() -> void:
	fight_actions = []
	if active and state != null and state.outcome == RunState.ONGOING:
		var key: String = "%d:%d" % [setup.rng_seed, actions.size()]
		_record(key, "abandoned")
		# 085: an abandoned daily is the day's attempt, scored where it stopped.
		if mode() == DAILY:
			Profile.finish_daily(int(setup.options.get("day", -1)), result("abandoned"))
		elif mode() == WEEKLY:
			Profile.finish_weekly(int(setup.options.get("week", -1)), key, result("abandoned"), plate())
	end_run()


func _make_setup(seed_value: int, options: Dictionary = {}) -> RunSetup:
	return RunSetup.create(db.parts, db.tiles, db.fights, db.run_rules, db.combat_rules,
		db.effectiveness, seed_value, options)


func _save() -> void:
	if active:
		RunStore.save(setup.rng_seed, db.content_version(), actions, fight_actions, setup.options)
