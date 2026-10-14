extends SceneTree

## 077: one picture of every `BattleVFX` effect, beside a machine for scale, at the moment it reads best.
## Run it on two commits (the before from a scratch copy) and compose them with names
## (`tools/blender/compose_sheet.py` or the sheet script in the iteration) -- the user picks what changes.
##
##   godot --path . --resolution 700x500 --script res://tools/shot_effects.gd -- --out shots/fx/after
##
## Writes `<out>_<effect>.png`. Uses only the `BattleVFX` calls every version has.

## [name, seconds after the trigger to take the picture]
const EFFECTS: Array = [
	["muzzle_flash", 0.03], ["impact", 0.08], ["star", 0.06], ["sparks", 0.12], ["smoke", 0.4],
	["fireball", 0.14], ["fireball_late", 0.55], ["burst", 0.1], ["destruction", 0.12], ["shards", 0.12],
	["dust", 0.2], ["ground_lines", 0.08], ["crush", 0.12], ["scorch", 0.4], ["break_arm", 0.12],
	["break_core", 0.14], ["break_land", 0.12], ["break_clank", 0.1],
]

var _vfx: BattleVFX


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[args.find("--out") + 1] if args.has("--out") else "shots/fx"
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
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 30.0
	camera.look_at_from_position(Vector3(0.6, 2.2, 4.2), Vector3(0.6, 0.6, 0.0), Vector3.UP)
	_vfx = BattleVFX.new()
	world.add_child(_vfx)
	_vfx.setup(camera)
	var parts := PackedStringArray(["ch_brute", "co_slug", "ar_saw", "ar_hammer", "mo_scavenger"])
	var model: Node3D = ConstructView.build_parts(parts, db, Ink.YOURS)
	Ink.dress_machine(model, parts, Ink.YOURS)
	model.scale = Vector3.ONE * 1.45
	model.position = Vector3(-0.6, 0, -0.4)
	world.add_child(model)
	for i: int in 20:
		await process_frame
	var at := Vector3(0.9, 0.0, 0.0)
	var hot := Color("ff7a3c")
	for entry: Array in EFFECTS:
		var name: String = entry[0]
		match name:
			"muzzle_flash": _vfx.muzzle_flash(at, at + Vector3(1, 0, 0), hot)
			"impact": _vfx.impact(at, Color("ffb070"), 1.0)
			"star": _vfx.star(at + Vector3(0, 0.7, 0), 0.0075)
			"sparks": _vfx.sparks(at + Vector3(0, 0.6, 0), hot, 14, 1.4)
			"smoke": _vfx.smoke(at + Vector3(0, 0.4, 0), 6, 1.0)
			"fireball", "fireball_late": _vfx.fireball(at, 1.0)
			"burst": _vfx.burst(at + Vector3(0, 0.3, 0), hot, 1.2)
			"destruction": _vfx.destruction(at, hot)
			"shards": _vfx.shards(at + Vector3(0, 0.5, 0), 8, 1.4)
			"dust": _vfx.dust(at, 6, 1.0)
			"ground_lines": _vfx.ground_lines(at, 1.0)
			"crush": _vfx.crush(at)
			"scorch": _vfx.scorch(at, 1.0)
			"break_arm": _vfx.on_break(at, "arm")
			"break_core": _vfx.on_break(at, "explode_core")
			"break_land": _vfx.on_break(at, "land")
			"break_clank": _vfx.on_break(at, "clank")
		await create_timer(float(entry[1])).timeout
		root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [out, name])
		print("saved ", name)
		await create_timer(1.6).timeout
		_vfx.settle()
		await create_timer(0.2).timeout
	quit()
