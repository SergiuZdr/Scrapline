extends SceneTree

## The whole roster as the game draws it (019): every frame with a core, two arms and a module
## of its own maker where there are some, in two rows, three-quarter, in ink.
##
##   godot --path . --resolution 2400x1100 --script res://tools/shot_roster.gd -- --out shots/roster.png [--yaw 145]
##
## Not headless: it has to render.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[args.find("--out") + 1] if args.has("--out") else "shots/roster.png"
	var yaw: float = args[args.find("--yaw") + 1].to_float() if args.has("--yaw") else -35.0
	var db: ContentDB = ContentDB.load_all()
	var by_slot: Dictionary = {"chassis": [], "core": [], "arm": [], "module": []}
	var ids: Array = db.parts.keys()
	ids.sort()
	for id: Variant in ids:
		if not PartTuning.is_tuned(String(id)):
			(by_slot[String(db.parts[id].get("slot", ""))] as Array).append(String(id))
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Ink.environment()
	world.add_child(env)
	world.add_child(Ink.key_light(Vector3(-40, -38, 0), 40.0))
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	ground.material_override = Ink.toon(Ink.BOARD)
	world.add_child(ground)
	var frames: Array = by_slot["chassis"]
	for i: int in frames.size():
		var maker: String = String(db.parts[frames[i]].get("maker", ""))
		var parts := PackedStringArray([frames[i], _of(db, by_slot["core"], maker, i), _of(db, by_slot["arm"], maker, i),
			_of(db, by_slot["arm"], maker, i + 1), _of(db, by_slot["module"], maker, i)])
		var model: Node3D = ConstructView.build_parts(parts, db, Ink.YOURS if i % 2 == 0 else Ink.DANGER)
		Ink.dress_machine(model, parts, Ink.YOURS if i % 2 == 0 else Ink.DANGER)
		model.position = Vector3((float(i % 5) - 2.0) * (1.5 if i < 5 else 1.05), 0.0, -2.2 if i < 5 else 0.9)
		model.rotation_degrees.y = yaw
		world.add_child(model)
		var tag := Label3D.new()
		tag.text = String(db.parts[frames[i]].get("name", "")).to_upper().replace(" FRAME", "")
		tag.font = UIKit.font_display()
		tag.font_size = 40
		tag.pixel_size = 0.004
		tag.modulate = Ink.PAPER
		tag.outline_modulate = Ink.INK
		tag.outline_size = 10
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = model.position + Vector3(0.0, 1.25, 0.0)
		world.add_child(tag)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 24.0
	var aim := Vector3(0.0, 0.35, -0.6)
	camera.look_at_from_position(aim + Vector3(0.0, 4.6, 7.2), aim, Vector3.UP)
	for i: int in 8:
		await process_frame
	root.get_texture().get_image().save_png(out)
	print("shot: ", out)
	quit()


## A part of this maker from a list (the `turn`-th of them), or any part if the maker has none.
func _of(db: ContentDB, ids: Array, maker: String, turn: int) -> String:
	var own: Array = ids.filter(func(id: String) -> bool: return String(db.parts[id].get("maker", "")) == maker)
	return String(own[turn % own.size()]) if not own.is_empty() else String(ids[turn % ids.size()])
