extends SceneTree
## 085: where `ConstructView.add_plate` puts a plate on each starting machine, in the model's space:
## the body's bounds, the core socket and the plate's bounds.
##   godot --headless --path . --script res://tools/probe_plate.gd [-- --plate pl_shield]

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var id: String = args[args.find("--plate") + 1] if args.has("--plate") else "pl_shield"
	var db: ContentDB = ContentDB.load_all()
	for member: Variant in db.run_rules.get("starting_crew", []):
		var parts := PackedStringArray((member as Dictionary)["parts"])
		var model: Node3D = ConstructView.build_parts(parts, db, Ink.YOURS)
		var ok: bool = ConstructView.add_plate(model, id)
		var plate: Node3D = ConstructView._find_named(model, "plate")
		var pts: PackedVector3Array = ConstructView._vertices(plate, model) if plate != null else PackedVector3Array()
		var box := AABB(pts[0], Vector3.ZERO) if not pts.is_empty() else AABB()
		for v: Vector3 in pts:
			box = box.expand(v)
		var chassis: Node3D = model.get_node("part_chassis")
		var core: Node3D = ConstructView._find_sockets(chassis).get("socket_core")
		print("%s ok=%s body=%s core=%s plate=%s" % [parts[0], ok, ConstructView._body_bounds(chassis, model),
			ConstructView._in_space(core, model).origin if core != null else Vector3.ZERO, box])
		model.free()
	quit()
