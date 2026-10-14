extends SceneTree

## 074: every ranged arm firing, as the fight draws it: its own animation (`ConstructRig.strike` with
## its `WeaponFX` style) and its own trail (`ShotFX`) from its gun's tip to a target three hexes off.
## One picture per arm, taken while the trail is in the air, plus the moment it leaves.
##
##   godot --path . --resolution 900x600 --script res://tools/shot_trails.gd -- \
##       --models gen --gen-dir res://art/parts_gen_scrap --out shots/074_trail [--only ar_scatter,ar_railgun]
##
## `--legacy` draws the shot as the game did before 074 (the class's strike, a tracer or a lobbed ball
## from the chest), for before/after sheets.
## Writes `<out>_<arm>_fire.png` (the frame it leaves), `<out>_<arm>.png` (in flight) and `<out>_<arm>_land.png`.
## Not headless: it has to render.

const FRAME: Array = ["ch_skirmisher", "co_null", "ar_hammer", "", "mo_capacitor"]
const TARGET: Array = ["ch_brute", "co_slug", "ar_saw", "ar_hammer", "mo_scavenger"]
const MODEL_SCALE: float = 1.45
const RANGE: float = 3.6

var _rig: ConstructRig


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[args.find("--out") + 1] if args.has("--out") else "shots/trail"
	var arms: Array = WeaponFX.table().keys()
	arms.sort()
	if args.has("--only"):
		arms = Array(args[args.find("--only") + 1].split(","))
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
	var vfx := BattleVFX.new()
	world.add_child(vfx)
	var marks := Node3D.new()
	world.add_child(marks)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 30.0
	camera.look_at_from_position(Vector3(6.2, 2.6, -RANGE * 0.5 + 0.6), Vector3(0.0, 0.6, -RANGE * 0.5), Vector3.UP)
	vfx.setup(camera)

	var target: Node3D = ConstructView.build_parts(PackedStringArray(TARGET), db, Ink.DANGER)
	Ink.dress_machine(target, PackedStringArray(TARGET), Ink.DANGER)
	target.scale = Vector3.ONE * MODEL_SCALE
	target.position = Vector3(0.0, 0.0, -RANGE)
	world.add_child(target)

	for arm: Variant in arms:
		var id: String = String(arm)
		var parts := PackedStringArray(FRAME)
		parts[3] = id
		var model: Node3D = ConstructView.build_parts(parts, db, Ink.YOURS)
		Ink.dress_machine(model, parts, Ink.YOURS)
		model.scale = Vector3.ONE * MODEL_SCALE
		model.rotation.y = PI
		world.add_child(model)
		_rig = ConstructRig.new()
		_rig.bind(model)
		var cls: String = String((db.parts.get(id, {}) as Dictionary).get("weapon_class", ""))
		_rig.set_stances(PackedStringArray(["hammer", cls]))
		await _run_for(0.4)
		var legacy: bool = args.has("--legacy")
		var lead: float = _rig.strike("arm_r", cls, self, "" if legacy else WeaponFX.fire_style(id))
		await _run_for(lead)
		await _save("%s_%s_fire.png" % [out, id])
		var to: Vector3 = target.position + Vector3(0, 0.6, 0)
		var shape: String = String(((db.parts.get(id, {}) as Dictionary).get("grid", {}) as Dictionary).get("shape", "shot"))
		if shape == "lob" or shape == "mine":
			to = target.position + Vector3(0, 0.3, 0.6)
		var cells: Array = [to + Vector3(-0.8, -0.3, 0.3), to + Vector3(0, -0.3, 0), to + Vector3(0.8, -0.3, 0.3)] if shape == "cone" else []
		var travel: float = 0.0
		if legacy:
			travel = _legacy(shape, marks, vfx, model.position + Vector3(0, 0.7, 0), to, Color("ffcf9a"), cells)
		else:
			travel = ShotFX.play(WeaponFX.trail(id), marks, vfx, _rig.muzzle("arm_r"), to,
				WeaponFX.colour(id, Color("ffcf9a")), {"cells": cells})
		await _run_for(clampf(travel * 0.6, 0.03, 0.4))
		await _save("%s_%s.png" % [out, id])
		await _run_for(maxf(0.12, travel * 0.4 + 0.1))
		await _save("%s_%s_land.png" % [out, id])
		await _run_for(1.2)
		model.queue_free()
		for child: Node in marks.get_children():
			child.queue_free()
		vfx.settle()
		await _run_for(0.1)
	quit()


## Steps the rig in real time for `seconds` (the trails' tweens run in real time too).
func _run_for(seconds: float) -> void:
	var start: int = Time.get_ticks_usec()
	var last: int = start
	while float(last - start) / 1e6 < seconds:
		await process_frame
		var now: int = Time.get_ticks_usec()
		if _rig != null:
			_rig.update(float(now - last) / 1e6)
		last = now


func _save(path: String) -> void:
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)


## The shot as `combat_scene._attack` drew it before 074 (its `_tracer` and `_lob`, copied).
func _legacy(shape: String, marks: Node3D, vfx: BattleVFX, muzzle: Vector3, to: Vector3, colour: Color, cells: Array) -> float:
	match shape:
		"shot":
			vfx.muzzle_flash(muzzle, to, colour.lightened(0.5))
			_tracer(marks, muzzle, to, colour)
			return 0.0
		"cone":
			vfx.muzzle_flash(muzzle, to, Color("ff7a3c"))
			for at: Variant in cells:
				vfx.burst(at, Color("ff7a3c"), 1.0)
			return 0.0
		"shield":
			_tracer(marks, muzzle, to + Vector3(0, 0.2, 0), Ink.YOURS)
			return 0.0
		"lob", "mine":
			if shape == "lob":
				vfx.muzzle_flash(muzzle, to, colour.lightened(0.5))
			var shell := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.09
			sphere.height = 0.18
			shell.mesh = sphere
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_color = colour
			shell.material_override = material
			marks.add_child(shell)
			var arc_height: float = 1.2 + muzzle.distance_to(to) * 0.25
			var tween := marks.create_tween()
			tween.tween_method(func(k: float) -> void:
				shell.position = muzzle.lerp(to, k) + Vector3(0, sin(k * PI) * arc_height, 0), 0.0, 1.0, 0.42)
			tween.tween_callback(shell.queue_free)
			if shape == "lob":
				tween.tween_callback(func() -> void: vfx.burst(to, colour, 1.2))
			return 0.42
	return 0.0


func _tracer(marks: Node3D, from: Vector3, to: Vector3, colour: Color) -> void:
	var glow := MeshInstance3D.new()
	var glow_box := BoxMesh.new()
	glow_box.size = Vector3(0.16, 0.16, from.distance_to(to))
	glow.mesh = glow_box
	var haze := StandardMaterial3D.new()
	haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	haze.albedo_color = Color(colour, 0.35)
	glow.material_override = haze
	marks.add_child(glow)
	glow.look_at_from_position((from + to) * 0.5, to, Vector3.UP)
	var haze_fade := marks.create_tween()
	haze_fade.tween_property(haze, "albedo_color:a", 0.0, 0.3)
	haze_fade.tween_callback(glow.queue_free)
	var beam := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.04, 0.04, from.distance_to(to))
	beam.mesh = box
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var hot: Color = colour.lerp(Color.WHITE, 0.5)
	material.albedo_color = Color(hot.r * 2.5, hot.g * 2.5, hot.b * 2.5, 1.0)
	beam.material_override = material
	marks.add_child(beam)
	beam.look_at_from_position((from + to) * 0.5, to, Vector3.UP)
	var tween := marks.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.25)
	tween.tween_callback(beam.queue_free)
