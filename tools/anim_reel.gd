extends SceneTree

## The crew's animations in one clip (056): every machine walks, strikes with each arm, takes a
## hit and goes down, driven by its ConstructRig exactly as a fight drives it. For Godot's movie
## writer:
##
##   godot --path . --resolution 1280x720 --write-movie shots/reel.avi --fixed-fps 30 \
##       --script res://tools/anim_reel.gd -- --models gen --gen-dir res://art/parts_gen_skel

const CREW: Array = [
	["ch_brute", "co_slug", "ar_saw", "ar_hammer", "mo_scavenger"],
	["ch_hauler", "co_furnace", "ar_pulse", "ar_lance", "mo_ablative"],
	["ch_strider", "co_arc", "ar_scanner", "ar_pulse", "mo_governor"],
]
## (time, what) -- seconds from the start.
const SCRIPT: Array = [
	[0.6, "walk"], [2.6, "stop"], [3.2, "strike_r"], [4.4, "strike_l"], [5.6, "hit"], [6.8, "die"], [9.0, "end"],
]

var _rigs: Array = []
var _models: Array = []
var _clock: float = 0.0
var _step: int = 0
var _walking: bool = false


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
	for i: int in CREW.size():
		var parts := PackedStringArray(CREW[i])
		var model: Node3D = ConstructView.build_parts(parts, db, Ink.YOURS)
		Ink.dress_machine(model, parts, Ink.YOURS)
		model.position = Vector3((float(i) - 1.0) * 1.7, 0.0, 0.0)
		model.rotation_degrees.y = -30.0
		world.add_child(model)
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
	camera.fov = 30.0
	var aim := Vector3(0.0, 0.4, 0.3)
	camera.look_at_from_position(aim + Vector3(0.0, 2.4, 8.5), aim, Vector3.UP)
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
			(_models[i] as Node3D).position.z += delta * 0.25


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
				rig.collapse(Vector3(-1.0, 0.0, 0.0))
			"end":
				quit()
