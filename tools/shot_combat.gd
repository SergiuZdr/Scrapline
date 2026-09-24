extends SceneTree

## Screenshot of a fight in a chosen state: a construct selected, a weapon armed, a
## target aimed. `--shot` alone can only photograph what the opening turn happens to show.
##
##   godot --path . --resolution 1920x1080 --script res://tools/shot_combat.gd -- \
##       --fight slag_pit --select 1 --weapon 1 --aim 0 3 --out shots/lob.png
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
	var weapon: int = _int_arg(args, "--weapon", -1)
	if weapon >= 0:
		scene.call("_choose_weapon", weapon)
	var at: int = args.find("--aim")
	if at >= 0 and at + 2 < args.size():
		var state: CombatState = scene.get("_state")
		var u: GridUnit = state.unit(select)
		var plan: Dictionary = CombatSim.strike_plan(state, u, int(scene.get("_weapon")), args[at + 1].to_int(), args[at + 2].to_int())
		var aim: Vector2i = plan["aim"]
		scene.call("_tap", aim)
	for i: int in 20:
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
