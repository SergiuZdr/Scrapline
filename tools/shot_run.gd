extends SceneTree

## Screenshots of the run screens in a real state: the bot plays a seeded run until the
## requested moment, then the map is opened and photographed.
##
##   godot --path . --resolution 1920x1080 --script res://tools/shot_run.gd -- \
##       --seed 7 --until reward --out shots/reward.png [--refit [--stats] [--focus S]] [--choose] [--fill-hold] [--brief]
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
	if args.has("--fill-hold"):
		# Screenshot only: pack the hold to its limit to show the full-hold salvage screen.
		var packed: RunState = run.get("state")
		while packed.cargo.size() < packed.hold_size:
			packed.cargo.append(String(packed.crew[packed.cargo.size() % 3]["parts"][1 + packed.cargo.size() % 4]))
	# The briefing covers the map on a new run; photograph it only when asked.
	run.set("briefed", not args.has("--brief"))
	change_scene_to_file("res://scenes/run_map.tscn")
	for i: int in 10:
		await process_frame
	if args.has("--choose"):
		# Preview the first reachable site, as a first tap would.
		var targets: Array[int] = RunSim.destinations(run.get("state"))
		if not targets.is_empty():
			current_scene.set("_hover", targets[targets.size() - 1])
			current_scene.call("_refresh")
			for i: int in 5:
				await process_frame
	if args.has("--refit"):
		current_scene.call("_open_garage", 0)
		for i: int in 10:
			await process_frame
		var garage: Node = current_scene.get("_garage")
		if args.has("--stats"):
			garage.set("_tab", "STATS")
			garage.call("_rebuild")
		if args.has("--levelup"):
			# Photograph the level-up mid-flight: scrap for it (screenshot only), press, wait.
			(run.get("state") as RunState).scrap = 200
			garage.call("_rebuild")
			for i: int in 3:
				await process_frame
			garage.call("_level_up")
			for i: int in _arg(args, "--levelup", "24").to_int():
				await process_frame
			var shot: Image = root.get_texture().get_image()
			shot.save_png(out)
			print("shot: %s (mid level-up)" % out)
			RunStore.clear()
			quit()
			return
		if args.has("--focus"):
			for i: int in 3:
				await process_frame
			garage.call("_focus_socket", _arg(args, "--focus", "3").to_int())
		for i: int in 40:
			await process_frame
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
