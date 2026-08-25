extends Node3D

## Dev-only: renders one construct WALKING, in isolation.
##
##     $GODOT --path . res://tools/gait_preview.tscn --resolution 620x620 -- \
##         --shot /tmp/gait --frames 6 --every 7 [--chassis ch_brute] [--strike]
##
## Why this is a separate scene rather than a camera flag on the battle
## -----------------------------------------------------------------
## Verifying the walk cycle from a live battle means catching a unit that happens to be
## mid-move at the frame the screenshot lands on. Every attempt to do that photographed a
## construct standing still, which proves nothing -- and "the code runs without errors" is
## not evidence that a limb moved.
##
## Here the rig is simply told it is moving and held that way, so the gait is on screen by
## construction. It is the only honest way to check an animation from stills.

var _rig: ConstructRig
var _frames: int = 6
var _every: int = 7
var _path: String = ""
var _tick: int = 0
var _shot: int = 0
var _strike_at: int = -1
var _stagger_at: int = -1
var _die_at: int = -1
var _stagger_from: Vector3 = Vector3.FORWARD
var _weapon: String = ""
var _still: bool = false
var _stem: String = ""


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_path = _arg(args, "--shot", "")
	_frames = int(_arg(args, "--frames", "6"))
	_every = int(_arg(args, "--every", "7"))
	var chassis_id: String = _arg(args, "--chassis", "ch_brute")
	# `--still` holds the construct standing, and names the frame after the chassis so a
	# shell loop can build a roster sheet of what the GAME actually draws -- which is not
	# necessarily what Blender draws, as the socket export bug proved.
	_still = args.has("--still")
	# `--still` names its frame after the chassis so a shell loop can build a roster
	# sheet. That is right for ONE frame per chassis and wrong the moment there is a
	# sequence: every frame writes to `<chassis>.png` and eight renders leave one file,
	# which composes as a one-frame sheet and looks like the animation never played.
	# A held-still construct being hit or striking is still a sequence.
	var sequence: bool = args.has("--stagger") or args.has("--strike") or args.has("--die")
	_stem = chassis_id if _still and not sequence else ""
	if args.has("--strike"):
		# Late enough that the walk is established first, so the strip shows both.
		_strike_at = _every * 2
	if args.has("--die"):
		# The collapse takes about a second, so it needs the longest lead-in of the
		# three and the widest sampling interval to fit the whole fall on one strip.
		_die_at = _every
		_stagger_from = _direction(_arg(args, "--stagger-from", "front"))
	if args.has("--stagger"):
		# Same reasoning as `--strike`, and the same reason this scene exists at all:
		# catching a stagger in a live battle screenshot means catching the two frames
		# after a hit landed on the one unit the camera happens to be framing. Every
		# attempt at that photographs a construct standing still.
		#
		# `--stagger-from` is the direction of the shove in the construct's own space,
		# so a reviewer can check that a hit from the left rolls it to the right rather
		# than assuming the sign is correct because it moved at all.
		_stagger_at = _every * 2
		_stagger_from = _direction(_arg(args, "--stagger-from", "front"))

	var db: ContentDB = Session.content if Session.content != null else ContentDB.load_all()
	_build_world()

	# A construct assembled from real parts through the game's own view code, so this
	# tests what ships rather than a bespoke preview model.
	var unit := SimUnit.new()
	unit.unit_ref = 0
	unit.team = SimDefs.TEAM_A
	unit.part_ids = _loadout(db, chassis_id)
	_weapon = String((db.parts.get(unit.part_ids[3], {}) as Dictionary).get("weapon_class", ""))

	var model: Node3D = ConstructView.build(unit, db, Color("4fa8d8"))
	# Turned for the roster shot. Weapons project straight forward, so a dead-on front
	# view points every one of them at the camera and a sheet of ten frames shows no
	# weapons at all -- which is exactly the read the sheet exists to check.
	model.rotation.y = deg_to_rad(float(_arg(args, "--yaw", "0")))
	add_child(model)

	_rig = ConstructRig.new()
	_rig.bind(model)
	# The whole point: held moving, so the gait is guaranteed to be on screen.
	_rig.set_moving(not _still)


func _loadout(db: ContentDB, chassis_id: String) -> Array[String]:
	var out: Array[String] = [chassis_id, "", "", "", ""]
	var slots: Array[String] = ["core", "arm", "arm", "module"]
	for index: int in slots.size():
		for part_id: String in db.parts:
			var part: Dictionary = db.parts[part_id]
			if String(part.get("slot", "")) == slots[index]:
				out[index + 1] = part_id
				break
	return out


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("2b2f36")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8a93a6")
	environment.ambient_light_energy = 1.4
	env.environment = environment
	add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-42, 138, 0)
	key.light_energy = 1.5
	key.shadow_enabled = true
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -40, 0)
	fill.light_energy = 0.7
	fill.light_color = Color("9fb2d8")
	add_child(fill)

	# Framed on the LEGS, low and pulled back. The first framing cropped them off the
	# bottom of the shot, which is the one part of the model this scene exists to show.
	var camera := Camera3D.new()
	camera.position = Vector3(1.9, 0.85, 2.9)
	camera.look_at_from_position(camera.position, Vector3(0, 0.50, 0), Vector3.UP)
	camera.fov = 34.0
	add_child(camera)

	# A ground plane, so a foot passing near it reads as a step rather than as a limb
	# waving in a void.
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor_mesh.mesh = plane
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("3a3f47")
	floor_material.roughness = 0.95
	floor_mesh.material_override = floor_material
	add_child(floor_mesh)


func _process(delta: float) -> void:
	if _rig != null:
		_rig.update(delta)
	_tick += 1

	if _tick == _strike_at and _rig != null:
		_rig.strike("arm_r", _weapon, get_tree())

	if _tick == _stagger_at and _rig != null:
		_rig.stagger(_stagger_from, 1.0)

	if _tick == _die_at and _rig != null:
		_rig.collapse(_stagger_from)

	if _path.is_empty():
		return
	if _tick % _every != 0:
		return
	if _shot >= _frames:
		get_tree().quit()
		return

	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_path)
	image.save_png("%s/%s.png" % [_path, _stem if not _stem.is_empty() else "%02d" % _shot])
	print("gait frame %d" % _shot)
	_shot += 1


## Where the blow came FROM, as the push it produces in the construct's own space.
## Hit in the front means shoved backwards, which is +Z.
func _direction(from: String) -> Vector3:
	match from:
		"back":
			return Vector3(0, 0, -1)
		"left":
			return Vector3(1, 0, 0)
		"right":
			return Vector3(-1, 0, 0)
		_:
			return Vector3(0, 0, 1)


func _arg(args: PackedStringArray, name: String, fallback: String) -> String:
	var index: int = args.find(name)
	if index >= 0 and index + 1 < args.size():
		return args[index + 1]
	return fallback
