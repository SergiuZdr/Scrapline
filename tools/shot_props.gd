extends SceneTree

## 081: a close-up of each generated battlefield prop (`Models.prop`) on board hexes, dressed as the
## fight dresses it, beside a machine for scale -- the "after" half of the props' before/after sheet.
##
##   godot --path . --resolution 700x560 --script res://tools/shot_props.gd -- --out shots/081/prop
##
## Writes `<out>_<name>.png`. The wall is shown as three blocks in a bent line, as it stands in a fight.

const HEX: float = 0.78
const NAMES: PackedStringArray = ["barrel", "coolant", "pylon", "wall", "cache", "scrap_pile", "hive_pad"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[args.find("--out") + 1] if args.has("--out") else "shots/prop"
	var db: ContentDB = ContentDB.load_all()
	var only: String = args[args.find("--only") + 1] if args.has("--only") else ""
	for name: String in NAMES:
		if not only.is_empty() and name != only:
			continue
		var world := Node3D.new()
		root.add_child(world)
		var env := WorldEnvironment.new()
		env.environment = Ink.environment()
		world.add_child(env)
		world.add_child(Ink.key_light(Vector3(-40, -38, 0), 30.0))
		var cells: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(0, -1), Vector2i(-1, -1)]
		for cell: Vector2i in cells:
			var tile := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = HEX * 0.94
			mesh.bottom_radius = HEX * 0.94
			mesh.height = 0.1
			mesh.radial_segments = 6
			tile.mesh = mesh
			tile.position = _at(cell) - Vector3(0, 0.05, 0)
			tile.material_override = Ink.toon(Color("2b2c31"))
			Ink.line(tile, Ink.LINE_WORLD)
			world.add_child(tile)
		var blocks: Array = [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(-1, 1)] if name == "wall" else [Vector2i(0, 0)]
		for cell: Vector2i in blocks:
			var piece: Node3D = (Models.prop(name) as PackedScene).instantiate() as Node3D
			piece.position = _at(cell)
			piece.rotation.y = PI / 6.0 if name == "wall" or name == "hive_pad" else 0.0
			Ink.dress_set_piece(piece, Ink.STEEL, Ink.LINE_ACT)
			world.add_child(piece)
		var parts := PackedStringArray(["ch_brute", "co_slug", "ar_saw", "ar_hammer", "mo_scavenger"])
		var model: Node3D = ConstructView.build_parts(parts, db, Ink.YOURS)
		Ink.dress_machine(model, parts, Ink.YOURS)
		model.scale = Vector3.ONE * 1.45
		model.position = _at(Vector2i(1, 0))
		model.rotation.y = PI
		world.add_child(model)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.current = true
		camera.fov = 30.0
		camera.look_at_from_position(Vector3(0.2, 4.2, 4.6), Vector3(0.2, 0.3, 0.2), Vector3.UP)
		for i: int in 20:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [out, name])
		print("saved ", name)
		root.remove_child(world)
		world.free()
		await process_frame
	quit()


## Pointy-top hexes in odd-r offset, as the fight lays them out.
func _at(cell: Vector2i) -> Vector3:
	return Vector3(sqrt(3.0) * HEX * (float(cell.x) + 0.5 * float(cell.y & 1)), 0.0, 1.5 * HEX * float(cell.y))
