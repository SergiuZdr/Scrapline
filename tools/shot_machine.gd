extends SceneTree

## One machine, drawn by the game in ink, turned to several angles (051): built by `ConstructView`
## and dressed by `Ink.dress_machine` exactly as a fight dresses it. For judging a generated set.
##
##   godot --path . --resolution 900x1100 --script res://tools/shot_machine.gd -- \
##       --models gen --gen-dir res://art/parts_gen_scrap --yaw 45,25,0 --out shots/brute
##       [--parts ch_brute,co_slug,ar_saw,ar_hammer,mo_scavenger]
##
## Writes `<out>_<yaw>.png` per angle: 0 is the machine's front to the camera, 45 is three-quarter.
## Not headless: it has to render.

const DISTANCE: float = 3.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[args.find("--out") + 1] if args.has("--out") else "shots/machine"
	var parts := PackedStringArray(["ch_brute", "co_slug", "ar_saw", "ar_hammer", "mo_scavenger"])
	if args.has("--parts"):
		parts = args[args.find("--parts") + 1].split(",")
	var yaws: PackedStringArray = (args[args.find("--yaw") + 1] if args.has("--yaw") else "45,0").split(",")
	var db: ContentDB = ContentDB.load_all()

	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Ink.environment()
	world.add_child(env)
	world.add_child(Ink.key_light(Vector3(-40, -38, 0), 30.0))
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	ground.material_override = Ink.toon(Ink.BOARD)
	world.add_child(ground)

	var model: Node3D = ConstructView.build_parts(parts, db, Ink.YOURS)
	Ink.dress_machine(model, parts, Ink.YOURS)
	world.add_child(model)

	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 26.0
	var aim := Vector3(0.0, 0.38, 0.0)
	camera.look_at_from_position(aim + Vector3(0.0, 0.75, DISTANCE), aim, Vector3.UP)
	for yaw: String in yaws:
		model.rotation_degrees.y = -yaw.to_float()
		await _settle()
		var path: String = "%s_%s.png" % [out, yaw]
		root.get_viewport().get_texture().get_image().save_png(path)
		print("saved ", path)
	quit()


func _settle() -> void:
	for i: int in 8:
		await process_frame
	await create_timer(0.3).timeout
