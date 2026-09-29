extends SceneTree

## Screenshot of a fight in a chosen state: a construct selected, a weapon armed, a
## target aimed. `--shot` alone can only photograph what the opening turn happens to show.
##
##   godot --path . --resolution 1920x1080 --script res://tools/shot_combat.gd -- \
##       --fight slag_pit --select 1 --weapon 1 --aim 5 3 --out shots/lob.png   (aim = a hex x y)
##       --select 0 --ability 0 --aim 2 3     arms an ability instead of a weapon
##       --select 0 --move 3 4 --weapon 1 --aim 2 3   walks first, then aims
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

	# --boom x y N: play the explosion effect on a hex and wait N frames (the look only).
	var boom: int = args.find("--boom")
	if boom >= 0 and boom + 3 < args.size():
		var cell := Vector2i(args[boom + 1].to_int(), args[boom + 2].to_int())
		var vfx: Node = scene.get("_vfx")
		vfx.call("fireball", scene.call("_to_world", cell.x, cell.y), 1.0)
		for i: int in args[boom + 3].to_int():
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
