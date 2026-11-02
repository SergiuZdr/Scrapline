extends SceneTree

## Screenshot of a fight in a chosen state: a construct selected, a weapon armed, a
## target aimed. `--shot` alone can only photograph what the opening turn happens to show.
##
##   godot --path . --resolution 1920x1080 --script res://tools/shot_combat.gd -- \
##       --fight slag_pit --select 1 --weapon 1 --aim 5 3 --out shots/lob.png   (aim = a hex x y)
##       --select 0 --ability 0 --aim 2 3     arms an ability instead of a weapon
##       --select 0 --move 3 4 --weapon 1 --aim 2 3   walks first, then aims
##       --steps "select=2 weapon=0 tap=0,3 tap=0,3 select=0 hover=0,3 end"   any sequence, in
##           order, before the flags above (tap and end settle the playback; hover draws a route)
##       --fire 0 --wait-meta cancelled 6   (087) fire, then wait for the CANCELLED beat, 6 frames more
##       --livery oxide_red --close 0 2.5   (085) the crew in a weekly livery; the camera 2.5 m from unit 0
##
## Not headless: it has to render. Everything is driven through the scene's own methods,
## the same ones a tap reaches.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scene: Node = (load("res://scenes/combat.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await _settle(scene)

	var steps: int = args.find("--steps")
	if steps >= 0 and steps + 1 < args.size():
		for token: String in args[steps + 1].split(" ", false):
			var kv: PackedStringArray = token.split("=")
			var cell := Vector2i.ZERO
			if kv.size() > 1 and kv[1].contains(","):
				cell = Vector2i(kv[1].get_slice(",", 0).to_int(), kv[1].get_slice(",", 1).to_int())
			match kv[0]:
				"select":
					scene.call("_select", kv[1].to_int())
				"weapon":
					scene.call("_choose_weapon", kv[1].to_int())
				"ability":
					scene.call("_choose_ability", kv[1].to_int())
				"tap":
					scene.call("_tap", cell)
					await _settle(scene)
				"end":
					scene.call("_end_turn")
					for i: int in 5:
						await process_frame
					await _settle(scene)
				"hover":
					var camera: Camera3D = scene.get("_camera")
					scene.call("_hover_path", camera.unproject_position(scene.call("_to_world", cell.x, cell.y)))
	# 087: --stage-hot X Y / --stage-wave X Y: put hot ground, or a reinforcement's wave mark (and two
	# waves to come), on the live state -- the LOOK only, for a sheet before the sim makes them itself.
	var state: CombatState = scene.get("_state")
	var sh: int = args.find("--stage-hot")
	for i: int in args.size() - 2:
		if args[i] == "--stage-hot":
			state.hot_ground[Vector2i(args[i + 1].to_int(), args[i + 2].to_int())] = {"rounds": 1, "heat": 2}
	var sw: int = args.find("--stage-wave")
	if sw >= 0 and sw + 2 < args.size():
		state.wave_marks.append(Vector2i(args[sw + 1].to_int(), args[sw + 2].to_int()))
		state.wave_refs.append(90)
		var setup: CombatSetup = scene.get("_setup")
		setup.escort_waves.append({"round": state.round_number + 1, "refs": [90]})
		setup.escort_waves.append({"round": state.round_number + 3, "refs": [91]})
	if args.has("--deselect"):
		scene.set("_selected", -1)
	if sh >= 0 or sw >= 0 or args.has("--deselect"):
		scene.call("_refresh")
	var select: int = _int_arg(args, "--select", -1)
	if select >= 0:
		scene.call("_select", select)
	# --move X Y: the selected machine walks there first (a tap in move mode).
	var mv: int = args.find("--move")
	if mv >= 0 and mv + 2 < args.size():
		scene.call("_tap", Vector2i(args[mv + 1].to_int(), args[mv + 2].to_int()))
		await _settle(scene)
		if select >= 0:
			scene.call("_select", select)
	var weapon: int = _int_arg(args, "--weapon", -1)
	if weapon >= 0:
		scene.call("_choose_weapon", weapon)
	var ability: int = _int_arg(args, "--ability", -1)
	if ability >= 0:
		scene.call("_choose_ability", ability)
	var at: int = args.find("--aim")
	if at >= 0 and at + 2 < args.size():
		scene.call("_tap", Vector2i(args[at + 1].to_int(), args[at + 2].to_int()))
	for i: int in 20:
		await process_frame
	# --fire N: tap the aimed hex again (which fires), then wait N frames -- to photograph
	# an effect mid-flight.
	var fire: int = _int_arg(args, "--fire", -1)
	if fire >= 0 and at >= 0:
		scene.call("_tap", Vector2i(args[at + 1].to_int(), args[at + 2].to_int()))
		for i: int in fire:
			await process_frame
	# 087: --wait-meta NAME N: after firing, wait until a mark carrying meta NAME is on the board (the
	# CANCELLED beat's "cancelled"), then N frames more -- to photograph a beat mid-play.
	var wm: int = args.find("--wait-meta")
	if wm >= 0 and wm + 2 < args.size():
		var marks: Node = scene.get("_marks_root")
		for i: int in 3000:
			await process_frame
			if marks.get_children().any(func(n: Node) -> bool: return n.has_meta(args[wm + 1]) and not n.is_queued_for_deletion()):
				break
		for i: int in args[wm + 2].to_int():
			await process_frame

	# --boom x y N: play the explosion effect on a hex and wait N frames (the look only).
	var boom: int = args.find("--boom")
	if boom >= 0 and boom + 3 < args.size():
		var cell := Vector2i(args[boom + 1].to_int(), args[boom + 2].to_int())
		var vfx: Node = scene.get("_vfx")
		vfx.call("fireball", scene.call("_to_world", cell.x, cell.y), 1.0)
		for i: int in args[boom + 3].to_int():
			await process_frame

	# 085: --close REF DIST: the board's camera brought down to DIST metres from unit REF (a close-up
	# of a machine as the board sees it -- from the crew's side, so a player's back).
	var close: int = args.find("--close")
	if close >= 0 and close + 2 < args.size():
		var view: Dictionary = (scene.get("_views") as Dictionary).get(args[close + 1].to_int(), {})
		if not view.is_empty():
			var camera: Camera3D = scene.get("_camera")
			var centre: Vector3 = (view["root"] as Node3D).global_position + Vector3(0, 0.45, 0)
			var back: Vector3 = (camera.global_position - centre).normalized()
			camera.look_at_from_position(centre + back * args[close + 2].to_float(), centre, Vector3.UP)
			for i: int in 4:
				await process_frame

	var out: String = "shots/combat.png"
	var o: int = args.find("--out")
	if o >= 0 and o + 1 < args.size():
		out = args[o + 1]
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	print("shot: %s (%s)" % [out, error_string(image.save_png(out))])
	quit()


func _settle(scene: Node) -> void:
	for i: int in 3000:
		await process_frame
		if i > 10 and not bool(scene.get("_busy")):
			break


func _int_arg(args: PackedStringArray, name: String, fallback: int) -> int:
	var at: int = args.find(name)
	return args[at + 1].to_int() if at >= 0 and at + 1 < args.size() else fallback
