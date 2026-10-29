extends SceneTree

## 085: the weekly contract's plates (`art/props/pl_*.glb`) in the game's ink, a row of five turned
## to each angle -- a turntable sheet of the models as a machine wears them (`ConstructView.add_plate`'s
## dressing: printed texture under the machines' comic print, the machines' line).
##
##   godot --path . --resolution 1800x420 --script res://tools/shot_plates.gd -- --yaw -35,0,35,150 --out shots/085/plates
##
## Writes `<out>_<yaw>.png` per angle (0: the plate's face to the camera). Not headless: it has to render.

const IDS: Array[String] = ["pl_name", "pl_shield", "pl_pennant", "pl_cog", "pl_hubcap"]
const STEP: float = 0.3


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[args.find("--out") + 1] if args.has("--out") else "shots/plates"
	var yaws: PackedStringArray = (args[args.find("--yaw") + 1] if args.has("--yaw") else "-35,0,35").split(",")
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Ink.environment()
	world.add_child(env)
	world.add_child(Ink.key_light(Vector3(-40, -38, 0), 30.0))
	var plates: Array[Node3D] = []
	for i: int in IDS.size():
		var packed: PackedScene = Models.prop(IDS[i])
		if packed == null:
			print("missing ", IDS[i])
			continue
		var plate: Node3D = packed.instantiate() as Node3D
		for mesh: MeshInstance3D in ConstructView.meshes_of(plate):
			for s: int in mesh.mesh.get_surface_count():
				var source: BaseMaterial3D = mesh.mesh.surface_get_material(s) as BaseMaterial3D
				if source != null and source.albedo_texture != null:
					mesh.set_surface_override_material(s, Ink.comic_machine(Ink.textured(source.albedo_texture, Color.WHITE)))
			Ink.line(mesh, Ink.LINE_MACHINE)
		var pivot := Node3D.new()
		pivot.position = Vector3((float(i) - 2.0) * STEP, 0, 0)
		world.add_child(pivot)
		pivot.add_child(plate)
		plate.position = Vector3(0, -0.09, 0)
		plates.append(pivot)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.36
	camera.look_at_from_position(Vector3(0, 0.25, 2.0), Vector3(0, 0, 0), Vector3.UP)
	for yaw: String in yaws:
		for pivot: Node3D in plates:
			pivot.rotation_degrees.y = yaw.to_float()
		for i: int in 8:
			await process_frame
		await create_timer(0.3).timeout
		var path: String = "%s_%s.png" % [out, yaw]
		root.get_viewport().get_texture().get_image().save_png(path)
		print("saved ", path)
	quit()
