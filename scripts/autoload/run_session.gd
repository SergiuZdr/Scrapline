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


func _ready() -> void:
	db = ContentDB.load_all()


func has_saved() -> bool:
	return RunStore.exists()


func new_run(seed_value: int = -1) -> void:
	# The only place a run reads the clock: choosing a seed. Everything after is seeded.
	if seed_value < 0:
		seed_value = int(Time.get_unix_time_from_system() * 1000.0) & 0x7FFFFFFF
	setup = _make_setup(seed_value)
	state = RunSim.start(setup)
	actions = []
	fight_actions = []
	active = true
	_save()


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
	setup = _make_setup(int(data["seed"]))
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


func _make_setup(seed_value: int) -> RunSetup:
	return RunSetup.create(db.parts, db.tiles, db.fights, db.run_rules, db.combat_rules,
		db.balance.effectiveness, seed_value)


func _save() -> void:
	if active:
		RunStore.save(setup.rng_seed, db.content_version(), actions, fight_actions)
