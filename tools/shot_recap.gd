extends SceneTree

## Screenshot of a run fight's result screen with its recap (014): a seeded run walks to its
## first fight, the combat bot finishes it, and the result is photographed.
##
##   godot --path . --resolution 1920x1080 --script res://tools/shot_recap.gd -- --seed 7 --out shots/recap.png
##
## Uses the real `Run` autoload and a scratch profile; clears the run save after.

func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--seed")
	var seed_value: int = args[at + 1].to_int() if at >= 0 and at + 1 < args.size() else 7
	at = args.find("--out")
	var out: String = args[at + 1] if at >= 0 and at + 1 < args.size() else "shots/recap.png"
	var profile: Node = root.get_node("Profile")
	profile.call("use_path", "user://shot_profile.json")
	var run: Node = root.get_node("Run")
	for id: Variant in ((run.get("db") as ContentDB).tutorial.get("hints", {}) as Dictionary):
		profile.call("mark_seen", String(id))
	run.call("new_run", seed_value)
	run.set("briefed", true)
	run.set("bay_seen", true)
	var guard: int = 0
	while guard < 40 and String((run.get("state") as RunState).pending.get("kind", "")) != "fight":
		run.call("apply", RunBot.next_action(run.get("state"), run.get("setup")))
		guard += 1
	change_scene_to_file("res://scenes/combat.tscn")
	for i: int in 120:
		await process_frame
	var scene: Node = current_scene
	var setup: CombatSetup = scene.get("_setup")
	var actions: Array = (scene.get("_actions") as Array).duplicate(true)
	var state: CombatState = CombatSim.replay(setup, actions)
	guard = 0
	while state.outcome == CombatState.ONGOING and guard < 60:
		actions.append_array(CombatBot.take_turn(state))
		guard += 1
	scene.set("_actions", actions)
	scene.set("_state", state)
	scene.call("_after_events")
	for i: int in 30:
		await process_frame
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	print("shot: %s (%s)" % [out, error_string(image.save_png(out))])
	RunStore.clear()
	quit()
