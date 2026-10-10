extends SceneTree

## One machine, drawn by the game in ink, turned to several angles (051): built by `ConstructView`
## and dressed by `Ink.dress_machine` exactly as a fight dresses it. For judging a generated set.
##
##   godot --path . --resolution 900x1100 --script res://tools/shot_machine.gd -- \
##       --models gen --gen-dir res://art/parts_gen_scrap --yaw 45,25,0 --out shots/brute
##       [--parts ch_brute,co_slug,ar_saw,ar_hammer,mo_scavenger] [--level 0..5] [--walk seconds]
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

	var level: int = args[args.find("--level") + 1].to_int() if args.has("--level") else 0
	var model: Node3D = ConstructView.build_parts(parts, db, Ink.YOURS, level)
	Ink.dress_machine(model, parts, Ink.YOURS)
	world.add_child(model)
	# 056: the rest pose of a skeleton machine comes from its rig (stances by weapon class).
	var rig := ConstructRig.new()
	rig.bind(model)
	var classes := PackedStringArray()
	for i: int in [2, 3]:
		classes.append(String((db.parts.get(PartTuning.base_of(parts[i]), {}) as Dictionary).get("weapon_class", "")) if i < parts.size() else "")
	rig.set_stances(classes)
	if args.has("--aabb"):
		for m: MeshInstance3D in ConstructView.meshes_of(model):
			m.custom_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	if args.has("--die"):
		rig.collapse(Vector3(1.0, 0.0, 0.0))
		for i: int in 120:
			rig.update(1.0 / 60.0)
	var walk: float = args[args.find("--walk") + 1].to_float() if args.has("--walk") else -1.0
	if walk >= 0.0:
		rig.set_moving(true)
		for i: int in 60:
			rig.update(walk / 60.0)

	# 062: close-ups of the arm mounts. `--hide-arms` draws the bare frame, `--marks` a red ball on
	# every socket, `--dist`/`--aim-y`/`--height` frame the camera, `--top` looks straight down.
	if args.has("--hide-arms"):
		for slot: String in ["part_arm_l", "part_arm_r"]:
			var arm: Node = model.find_child(slot, true, false)
			if arm != null:
				(arm as Node3D).visible = false
	if args.has("--marks"):
		for name: String in ["socket_arm_l", "socket_arm_r", "socket_core", "socket_module"]:
			var socket: Node3D = model.find_child(name, true, false) as Node3D
			if socket == null:
				continue
			var ball := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.015
			sphere.height = 0.03
			ball.mesh = sphere
			var red := StandardMaterial3D.new()
			red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			red.albedo_color = Color.RED
			red.no_depth_test = true
			ball.material_override = red
			socket.add_child(ball)
	var distance: float = args[args.find("--dist") + 1].to_float() if args.has("--dist") else DISTANCE
	var aim_y: float = args[args.find("--aim-y") + 1].to_float() if args.has("--aim-y") else 0.38
	var height: float = args[args.find("--height") + 1].to_float() if args.has("--height") else 0.75
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 26.0
	var aim := Vector3(0.0, aim_y, 0.0)
	if args.has("--top"):
		camera.look_at_from_position(aim + Vector3(0.0, distance, 0.001), aim, Vector3(0, 0, -1))
	else:
		camera.look_at_from_position(aim + Vector3(0.0, height, distance), aim, Vector3.UP)
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
