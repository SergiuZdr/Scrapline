extends SceneTree

## Screenshots of the run screens in a real state: the bot plays a seeded run until the
## requested moment, then the map is opened and photographed.
##
##   godot --path . --resolution 1920x1080 --script res://tools/shot_run.gd -- \
##       --seed 7 --until reward --out shots/reward.png [--refit [--stats] [--focus S] [--perks] [--levelup N]]
##       [--choose] [--fill-hold] [--brief] [--tune S]   (--tune needs --until workshop; S = the socket to show)
##       [--force KIND]   the sites next to the camp become KIND (trader, tower, signal...)
##       [--enter SECONDS]   with --until fight: enter the fight, photograph its board after SECONDS
##
## `--until` is a pending kind (reward, scrapyard, workshop, fight) or "moves:N".
## Uses the real `Run` autoload; under `--script` it saves to `user://tool_run.json` and a profile
## of its own (032), never the player's.

func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var run: Node = root.get_node("Run")
	var seed_value: int = _arg(args, "--seed", "7").to_int()
	var until: String = _arg(args, "--until", "reward")
	var out: String = _arg(args, "--out", "shots/run.png")
	run.call("new_run", seed_value)
	if args.has("--force"):
		# Screenshot only: every site reachable from the camp becomes this kind, so the first
		# move lands on one (for the sites a seeded bot run may never visit).
		var fresh: RunState = run.get("state")
		for id: int in RunSim.destinations(fresh):
			fresh.sites[id]["type"] = _arg(args, "--force", "signal")
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
			var part: String = String(packed.crew[packed.cargo.size() % 3]["parts"][1 + packed.cargo.size() % 4])
			packed.cargo.append(part if not part.is_empty() else "ar_hammer")
	# The briefing covers the map on a new run; photograph it only when asked.
	run.set("briefed", not args.has("--brief"))
	run.set("bay_seen", not args.has("--bay"))
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
	if args.has("--dump-fog"):
		var fog_image: Image = current_scene.get("_yard").get("_fog_image")
		fog_image.save_png("shots/_fogmask.png")
		print("fog mask %dx%d saved" % [fog_image.get_width(), fog_image.get_height()])
	if args.has("--zoom"):
		var yard: Node = current_scene.get("_yard")
		yard.call("zoom_by", _arg(args, "--zoom", "0").to_float())
		yard.call("settle_camera")
		for i: int in 6:
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
			garage.call("_level_up", 0)
			for i: int in _arg(args, "--levelup", "24").to_int():
				await process_frame
			var shot: Image = root.get_texture().get_image()
			shot.save_png(out)
			print("shot: %s (mid level-up)" % out)
			RunStore.clear()
			quit()
			return
		if args.has("--perks"):
			# The perk pick LEVEL UP opens (011): scrap for it, screenshot only.
			(run.get("state") as RunState).scrap = 200
			garage.call("_rebuild")
			for i: int in 3:
				await process_frame
			garage.call("_offer_perks")
		if args.has("--focus"):
			for i: int in 3:
				await process_frame
			garage.call("_focus_socket", _arg(args, "--focus", "3").to_int())
		for i: int in 40:
			await process_frame
		for i: int in 10:
			await process_frame
	if args.has("--tune"):
		(run.get("state") as RunState).scrap = maxi(30, (run.get("state") as RunState).scrap)
		current_scene.call("_refresh")
		current_scene.call("_open_tuner")
		for i: int in 3:
			await process_frame
		var tuner: Node = current_scene.get("_tuner")
		tuner.set("_chosen", _arg(args, "--tune", "3").to_int())
		tuner.call("_rebuild")
		for i: int in 20:
			await process_frame
	if args.has("--wait"):
		await create_timer(_arg(args, "--wait", "2").to_float()).timeout
	if args.has("--enter"):
		# 032: walk into the pending fight and photograph the board once the opening card is
		# gone (`--until fight --enter`).
		change_scene_to_file("res://scenes/combat.tscn")
		await create_timer(_arg(args, "--enter", "8").to_float()).timeout
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	print("shot: %s (%s)" % [out, error_string(image.save_png(out))])
	RunStore.clear()
	quit()


func _arg(args: PackedStringArray, name: String, fallback: String) -> String:
	var at: int = args.find(name)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else fallback
