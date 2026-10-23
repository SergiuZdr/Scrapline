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


func has_saved() -> bool:
	return RunStore.exists()


## What this run gave the profile (022): `{ "new": [unlock entries], "next": entry or {} }`.
## Banked once, whatever screen asks and however often. 084 (B8): the run goes into the history
## too, and a seeded run banks nothing else.
func bank() -> Dictionary:
	if not active or state.outcome == RunState.ONGOING:
		return {}
	var key: String = "%d:%d" % [setup.rng_seed, actions.size()]
	_record(key)
	var fresh: Array = Profile.bank_run(key, state, db.meta, int(setup.options.get("tier", 0)), is_seeded())
	var entries: Array = []
	for entry: Dictionary in (db.meta.get("unlocks", []) as Array):
		if fresh.has(String(entry["id"])):
			entries.append(entry)
	return {"new": entries, "next": Meta.next_unlock(Profile.unlocked(), db.meta)}


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
	new_run(seed_value, seeded)
	return true


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
		"names": state.crew.map(func(m: Dictionary) -> String: return String(m["name"]))})


func new_run(seed_value: int = -1, options: Dictionary = {}) -> void:
	# The only place a run reads the clock: choosing a seed. Everything after is seeded.
	if seed_value < 0:
		# 084: inside 24 bits (`RunSetup.SEED_MASK`), so every run's seed has a word code.
		seed_value = int(Time.get_unix_time_from_system() * 1000.0) & RunSetup.SEED_MASK
	setup = _make_setup(seed_value, options)
	state = RunSim.start(setup)
	actions = []
	fight_actions = []
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
		_record("%d:%d" % [setup.rng_seed, actions.size()], "abandoned")
	end_run()


func _make_setup(seed_value: int, options: Dictionary = {}) -> RunSetup:
	return RunSetup.create(db.parts, db.tiles, db.fights, db.run_rules, db.combat_rules,
		db.effectiveness, seed_value, options)


func _save() -> void:
	if active:
		RunStore.save(setup.rng_seed, db.content_version(), actions, fight_actions, setup.options)
