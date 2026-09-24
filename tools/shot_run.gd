extends SceneTree

## Screenshots of the run screens in a real state: the bot plays a seeded run until the
## requested moment, then the map is opened and photographed.
##
##   godot --path . --resolution 1920x1080 --script res://tools/shot_run.gd -- \
##       --seed 7 --until reward --out shots/reward.png [--refit]
##
## `--until` is a pending kind (reward, scrapyard, workshop, fight) or "moves:N".
## Uses the real `Run` autoload, so it overwrites `user://run.json`; it clears it after.

func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var run: Node = root.get_node("Run")
	var seed_value: int = _arg(args, "--seed", "7").to_int()
	var until: String = _arg(args, "--until", "reward")
	var out: String = _arg(args, "--out", "shots/run.png")
	run.call("new_run", seed_value)
	var guard: int = 0
	while guard < 300:
		var state: RunState = run.get("state")
		if state.outcome != RunState.ONGOING:
			break
		if String(state.pending.get("kind", "")) == until:
			break
		if until.begins_with("moves:") and state.moves >= until.split(":")[1].to_int() and state.pending.is_empty():
			break
		run.call("apply", RunBot.next_action(state, run.get("setup")))
		guard += 1
	change_scene_to_file("res://scenes/run_map.tscn")
	for i: int in 10:
		await process_frame
	if args.has("--refit"):
		var map: Node = current_scene
		map.set("_refit_open", true)
		map.set("_refit_socket", [0, 3])
		map.call("_show_overlay")
		for i: int in 10:
			await process_frame
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	print("shot: %s (%s)" % [out, error_string(image.save_png(out))])
	RunStore.clear()
	quit()


func _arg(args: PackedStringArray, name: String, fallback: String) -> String:
	var at: int = args.find(name)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else fallback
