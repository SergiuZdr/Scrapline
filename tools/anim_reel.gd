extends SceneTree

## The crew's animations in one clip (056): every machine walks, strikes with each arm, takes a
## hit and goes down, driven by its ConstructRig exactly as a fight drives it. For Godot's movie
## writer:
##
##   godot --path . --resolution 1280x720 --write-movie shots/reel.avi --fixed-fps 30 \
##       --script res://tools/anim_reel.gd -- --models gen --gen-dir res://art/parts_gen_scrap [--crew 0|1|2]
## `--crew N` films one machine alone, close, from its three-quarter side (feet against the floor).

const CREW: Array = [
	["ch_brute", "co_slug", "ar_saw", "ar_hammer", "mo_scavenger"],
	["ch_hauler", "co_furnace", "ar_pulse", "ar_lance", "mo_ablative"],
	["ch_strider", "co_arc", "ar_scanner", "ar_pulse", "mo_governor"],
]
## (time, what) -- seconds from the start.
const SCRIPT: Array = [
	[0.6, "walk"], [3.4, "stop"], [4.0, "strike_r"], [5.4, "strike_l"], [6.8, "hit"], [8.0, "die"], [10.0, "end"],
]

var _rigs: Array = []
var _models: Array = []
var _clock: float = 0.0
var _step: int = 0
var _walking: bool = false
var _camera: Camera3D
var _follow: Vector3 = Vector3.ZERO


func _initialize() -> void:
	_build.call_deferred()


func _build() -> void:
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
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var only: int = args[args.find("--crew") + 1].to_int() if args.has("--crew") else -1
	# A floor grid, so a foot that goes under the floor shows.
	for k: int in range(-10, 11):
		for horizontal: bool in [true, false]:
			var bar := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(20, 0.004, 0.01) if horizontal else Vector3(0.01, 0.004, 20)
			bar.mesh = box
			bar.position = Vector3(0, 0.002, k * 0.25) if horizontal else Vector3(k * 0.25, 0.002, 0)
			bar.material_override = Ink.toon(Color(0.35, 0.36, 0.40))
			world.add_child(bar)
	for i: int in CREW.size():
		if only >= 0 and i != only:
			continue
		var parts := PackedStringArray(CREW[i])
		var model: Node3D = ConstructView.build_parts(parts, db, Ink.YOURS)
		Ink.dress_machine(model, parts, Ink.YOURS)
		# The rig owns the model's own transform (lean, recoil); walking moves a holder, as the
		# combat scene moves a unit's root.
		var holder := Node3D.new()
		holder.position = Vector3((float(i) - 1.0) * 1.7, 0.0, 0.0) if only < 0 else Vector3.ZERO
		holder.rotation_degrees.y = -30.0 if only < 0 else -60.0
		world.add_child(holder)
		holder.add_child(model)
		var rig := ConstructRig.new()
		rig.bind(model)
		var classes := PackedStringArray()
		for k: int in [2, 3]:
			classes.append(String((db.parts.get(parts[k], {}) as Dictionary).get("weapon_class", "")))
		rig.set_stances(classes)
		_rigs.append([rig, classes])
		_models.append(model)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 30.0 if only < 0 else 20.0
	_camera = camera
	if only >= 0:
		_follow = camera.position
	var aim := Vector3(0.0, 0.4, 0.3) if only < 0 else Vector3(0.0, 0.35, 0.3)
	camera.look_at_from_position(aim + (Vector3(0.0, 2.4, 8.5) if only < 0 else Vector3(0.0, 0.9, 3.4)), aim, Vector3.UP)
	_follow = camera.position
	process_frame.connect(_tick)


func _tick() -> void:
	var delta: float = 1.0 / 30.0
	_clock += delta
	while _step < SCRIPT.size() and _clock >= float(SCRIPT[_step][0]):
		_do(String(SCRIPT[_step][1]))
		_step += 1
	for i: int in _rigs.size():
		var rig: ConstructRig = _rigs[i][0]
		rig.update(delta)
		if _walking:
			var m: Node3D = (_models[i] as Node3D).get_parent()
			m.position += -m.global_transform.basis.z * delta * 0.25
	# Filming one machine, the camera follows it.
	if _models.size() == 1:
		var at: Vector3 = ((_models[0] as Node3D).get_parent() as Node3D).position
		_camera.position = _follow + Vector3(at.x, 0.0, at.z)


func _do(what: String) -> void:
	for entry: Array in _rigs:
		var rig: ConstructRig = entry[0]
		var classes: PackedStringArray = entry[1]
		match what:
			"walk":
				_walking = true
				rig.set_moving(true)
			"stop":
				_walking = false
				rig.set_moving(false)
			"strike_r":
				rig.strike("arm_r", classes[1], self)
			"strike_l":
				rig.strike("arm_l", classes[0], self)
			"hit":
				rig.stagger(Vector3(0.0, 0.0, 1.0), 0.9)
			"die":
				rig.collapse(Vector3(0.0, 0.0, -1.0))
			"end":
				quit()
