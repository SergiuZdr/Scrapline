extends SceneTree

## Screenshots of the run screens in a real state: the bot plays a seeded run until the
## requested moment, then the map is opened and photographed.
##
##   godot --path . --resolution 1920x1080 --script res://tools/shot_run.gd -- \
##       --seed 7 --until reward --out shots/reward.png [--refit [--stats] [--focus S] [--perks] [--levelup N]]
##       [--act N] [--zoom STEP] [--pan DX DY] [--choose] [--fill-hold] [--brief] [--tune S]   (--tune needs --until workshop; S = the socket to show)
##       [--force KIND]   the sites next to the camp become KIND (trader, tower, signal...)
##       [--enter SECONDS]   with --until fight: enter the fight, photograph its board after SECONDS
##
## `--until` is a pending kind (reward, scrapyard, workshop, fight), "moves:N", "fit" (082: a salvage
## card that offers FIT ON <NAME>) or "over" (the run's end). `--wreck` (screenshot only) then wrecks
## the whole crew, for the run-over screen's roll call after a loss. "defend_partial" (083) waits for a
## DEFEND salvage won with a cache broken.
## 083, screenshot only, both with `--until reward`: `--stage-defend` makes the salvage a DEFEND's with
## 1 of 2 caches standing; `--stage-wreck` wrecks crew 1 and puts the part pulled from its guarded wreck in front of it.
## 084: `--hover-fight` hovers a revealed fight site the crew can reach (its card names the fight);
## `--title [--seed-text TEXT] [--press]` photographs the title instead, TEXT in NEW RUN's seed field
## (`--press` presses NEW RUN, to show a refusal); `--ledger` opens UNLOCKS on its RUNS tab after
## writing a few made-up runs into the tool profile's history.
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
	if args.has("--title") or args.has("--ledger"):
		await _title_shot(args, run, out)
		return
	if args.has("--force"):
		# Screenshot only: every site reachable from the camp becomes this kind, so the first
		# move lands on one (for the sites a seeded bot run may never visit).
		var fresh: RunState = run.get("state")
		for id: int in RunSim.destinations(fresh):
			fresh.sites[id]["type"] = _arg(args, "--force", "signal")
	var guard: int = 0
	var card_script: Script = load("res://scripts/ui/part_card.gd")
	while guard < (3000 if until == "over" else 300):
		var state: RunState = run.get("state")
		if state.outcome != RunState.ONGOING:
			break
		# 049: `--act N` waits for that act first (moves start again at every act).
		var in_act: bool = state.act >= _arg(args, "--act", "1").to_int()
		if in_act and String(state.pending.get("kind", "")) == until:
			break
		if in_act and until == "fit" and ["reward", "scrapyard"].has(String(state.pending.get("kind", ""))) \
				and (state.pending["options"] as Array).any(func(id: Variant) -> bool:
					return not (card_script.call("fit_target", (run.get("db") as ContentDB).parts, String(id), state.crew) as Array).is_empty()):
			break
		if in_act and until == "defend_partial" and String(state.pending.get("kind", "")) == "reward" \
				and (state.pending.get("caches", [1, 1]) as Array)[0] < (state.pending.get("caches", [1, 1]) as Array)[1]:
			break
		if in_act and until.begins_with("moves:") and state.moves >= until.split(":")[1].to_int() and state.pending.is_empty():
			break
		run.call("apply", RunBot.next_action(state, run.get("setup")))
		guard += 1
	if args.has("--fill-hold"):
		# Screenshot only: pack the hold to its limit to show the full-hold salvage screen.
		var packed: RunState = run.get("state")
		while packed.cargo.size() < packed.hold_size:
			var part: String = String(packed.crew[packed.cargo.size() % 3]["parts"][1 + packed.cargo.size() % 4])
			packed.cargo.append(part if not part.is_empty() else "ar_hammer")
	if args.has("--stage-defend"):
		var at: RunState = run.get("state")
		at.pending = RunSim.salvage(at, run.get("setup"), "skirmish", 1, 2)
	if args.has("--stage-wreck"):
		var at: RunState = run.get("state")
		var member: Dictionary = at.crew[1]
		var lost: Array = (member["parts"] as Array).slice(1)
		member["alive"] = false
		member["hp"] = 0
		member["parts"] = [String(member["parts"][0]), "", "", "", ""]
		RunSim._queue_wreck(at, RunSim.wreck_pull(at, run.get("setup"), [0, 1, 2], {1: lost}, [1]))
	if args.has("--wreck"):
		# Screenshot only: the crew is wrecked where it stands, for the roll call after a loss.
		var lost: RunState = run.get("state")
		for member: Dictionary in lost.crew:
			member["alive"] = false
			member["hp"] = 0
		lost.outcome = RunState.LOST
		lost.end_reason = "The whole crew is wrecked."
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
	if args.has("--hover-fight"):
		var at_state: RunState = run.get("state")
		var pick: int = -1
		for id: int in RunSim.destinations(at_state):
			if RunSim.FIGHT_TYPES.has(String(at_state.site(id)["type"])) and RunSim.revealed(at_state, id):
				pick = id
		if pick >= 0:
			current_scene.set("_hover", pick)
			current_scene.call("_refresh")
			for i: int in 5:
				await process_frame
		else:
			print("no revealed fight site within reach")
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
	# 049: `--pan DX DY` drags the map by that many pixels (positive DX looks left).
	var pan_at: int = args.find("--pan")
	if pan_at >= 0 and pan_at + 2 < args.size():
		var yard: Node = current_scene.get("_yard")
		yard.call("pan", Vector2(args[pan_at + 1].to_float(), args[pan_at + 2].to_float()))
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


## 084: the title (its seed field) or the UNLOCKS panel's RUNS ledger.
func _title_shot(args: PackedStringArray, run: Node, out: String) -> void:
	var profile: Node = root.get_node("Profile")
	if args.has("--ledger"):
		var db: ContentDB = run.get("db")
		var crews: Array = (db.meta.get("crews", {}) as Dictionary).keys()
		var ends: Array = ["wrecked", "won", "gate", "wrecked", "abandoned", "wrecked"]
		for i: int in 6:
			run.call("new_run", 1000 + i * 77)
			var st: RunState = run.get("state")
			profile.call("record_run", {"key": "ledger%d" % i, "seed": 1000 + i * 77, "code": String(run.call("seed_code")),
				"seeded": i == 3, "crew": String(crews[i % crews.size()]), "tier": i % 2, "act": 1 + i % 3, "ended": ends[i],
				"reason": "", "fights": 3 + i * 2, "parts": st.crew.map(func(m: Dictionary) -> Array: return (m["parts"] as Array).duplicate()),
				"names": st.crew.map(func(m: Dictionary) -> String: return String(m["name"])),
				"date": "2026-10-%02d" % (10 + i)})
	RunStore.clear()
	if args.has("--press"):
		run.call("new_run", 4242)   # a live run behind the title, for the refusal
	change_scene_to_file("res://scenes/main.tscn")
	for i: int in 10:
		await process_frame
	if args.has("--ledger"):
		var panel: Node = (load("res://scripts/ui/unlocks_panel.gd") as GDScript).call("open", current_scene, run.get("db"), profile.call("unlocked"), profile.call("stats"), [], profile.call("run_history"))
		for i: int in 3:
			await process_frame
		panel.call("_show_tab", "RUNS")
	else:
		var field: LineEdit = current_scene.find_child("seed_field", true, false)
		field.text = _arg(args, "--seed-text", "")
		if args.has("--press"):
			current_scene.call("_new_run")
	await create_timer(1.0).timeout
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	print("shot: %s (%s)" % [out, error_string(image.save_png(out))])
	RunStore.clear()
	quit()


func _arg(args: PackedStringArray, name: String, fallback: String) -> String:
	var at: int = args.find(name)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else fallback
