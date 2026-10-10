class_name ConstructRig
extends RefCounted

## Animates one assembled machine: it runs, it strikes, it takes a hit, it dies.
##
## Nothing here computes an outcome. The rig is told "this unit is moving", "this unit just struck"
## and "this unit was hit from over there"; it never decides any of them.
##
## ## 059: pose to pose, like a comic
##
## Everything a machine does is a sum of POSES over named channels (the body's drop, surge, sway,
## pitch and roll; the upper body's pitch, twist and roll; each arm's shoulder, elbow, wrist and
## flare; each foot's step). A motion is a CLIP: a list of key poses, each reached over a time with
## a curve and then HELD. That is how a comic page is drawn -- strong key poses, the panel the eye
## rests on, and almost nothing in between:
##
## * **Anticipation** is a key the machine reaches and holds before the action (the hammer up
##   behind its head), and the fight waits for the strike's IMPACT before it shows the shot.
## * **The impact is a held pose** (a hit-stop of the body, not of the game), then a rebound past
##   rest and a settle -- never one ease from A to B with every joint arriving together.
## * **The body leads, limbs drag.** The upper body turns into a swing before the arm comes over; a
##   hit snaps the torso before the arms fly out.
## * **Stepped keys** (`STEP`) jump from pose to pose with no in-between: a dying machine sputters
##   and a scanner ticks, the way stop-motion and comic panels do.
##
## 058 and earlier eased every channel together, turned generated arm bones about each BONE's own X
## (which on a generated arm points anywhere), never moved the torso, and the rigid roster's legs
## cycled the wrong way round. Every joint here turns about the MACHINE's axes: the front is +Z, the
## up is +Y; "flex" (a limb swinging forward and up) is a turn about FWD x UP.
##
## Reactions to hits ALSO drive a spring-damper on the body's position and lean (`stagger`), which
## composes: three hits in a tick add three impulses to one spring and produce one bigger lurch.

# --- Channels ------------------------------------------------------------------
## Body: DROP lowers it (share of the leg), SURGE/SWAY move it along its own +Z/+X (shares of the
## leg), PITCH tips its top toward +Z, ROLL turns about +Z (raw radians: + carries the top to -X).
const DROP: int = 0
const SURGE: int = 1
const SWAY: int = 2
const PITCH: int = 3
const ROLL: int = 4
## Upper body about the waist (skeleton frames; folded into the body on rigid ones): pitch toward
## +Z, TWIST about +Y (raw), roll about +Z (raw).
const T_PITCH: int = 5
const T_TWIST: int = 6
const T_ROLL: int = 7
## Arms: SH/EL/WR flex the shoulder, elbow and wrist (+ swings forward and up), FL flares the arm
## out from the body. Left block then right block.
const SH_L: int = 8
const EL_L: int = 9
const WR_L: int = 10
const FL_L: int = 11
const SH_R: int = 12
const EL_R: int = 13
const WR_R: int = 14
const FL_R: int = 15
## Feet: forward and up (shares of the leg), and out to the side. Left then right.
const LF_F: int = 16
const LF_U: int = 17
const LF_S: int = 18
const RF_F: int = 19
const RF_U: int = 20
const RF_S: int = 21
const N_CH: int = 22

## Curves a key is reached with.
const SNAP: int = 0   # arrives fast and settles into the pose (ease out)
const SMEAR: int = 1  # accelerates INTO the pose: a swing that lands at full speed
const EASE: int = 2   # in and out
const BACK: int = 3   # overshoots and comes back
const STEP: int = 4   # holds the last pose, then jumps (no in-between)

const FWD := Vector3(0, 0, 1)
## Feet drawn in under the hips by this share of their sideways offset (the Brute stood wide).
const FEET_IN: float = 0.0
## Flex: a turn about this axis carries "down" toward "forward" (FWD x UP).
const FLEX := Vector3(-1, 0, 0)

# --- Run ---------------------------------------------------------------------
## Fraction of each leg's cycle on the ground. Under a half: a run, with a moment in the air
## between steps, which is what crosses a hex in a stride or two.
const STANCE_FRACTION: float = 0.42
## Strides per second when the rig is told it moves but its holder is not moving (tests, previews).
const STRIDE_RATE: float = 2.2
## How fast the run fades in and out.
const SETTLE: float = 7.0
## One cycle of both legs covers this many leg lengths, per role (a machine's own size sets its
## cadence: a big one takes fewer strides over the same hex).
const GAITS: Dictionary = {
	# reach: how far a foot steps, lift: knee-up, dip: how far the body sinks on landing, bounce: lift
	# in the air, sway/roll: weight over the planted foot, twist: shoulders against hips, arms: swing,
	# lean: into the run, cycle: leg lengths per cycle.
	"brawler": {"feet_in": 0.32, "reach": 0.42, "lift": 0.34, "dip": 0.14, "bounce": 0.04, "sway": 0.10, "roll": 0.07,
		"twist": 0.30, "arms": 0.55, "lean": 0.16, "cycle": 4.2},
	"anchor": {"reach": 0.32, "lift": 0.22, "dip": 0.18, "bounce": 0.0, "sway": 0.16, "roll": 0.10,
		"twist": 0.16, "arms": 0.30, "lean": 0.08, "cycle": 3.4},
	"line": {"reach": 0.40, "lift": 0.30, "dip": 0.10, "bounce": 0.05, "sway": 0.07, "roll": 0.05,
		"twist": 0.24, "arms": 0.45, "lean": 0.13, "cycle": 4.2},
	"marksman": {"reach": 0.46, "lift": 0.40, "dip": 0.06, "bounce": 0.10, "sway": 0.04, "roll": 0.03,
		"twist": 0.16, "arms": 0.30, "lean": 0.18, "cycle": 4.8},
}
## Legacy names (verify_animation reads these).
const STRIDE_SWING: float = 0.62
const BOB: float = 0.035
const FOOTFALL: float = 0.55

# --- Reactions (springs) ---------------------------------------------------------
## Just under critical damping, integrated at a FIXED rate (a spring stepped per frame damps per
## frame: the same hit travelled 3.5 cm at 60 fps and 0.4 cm at 15).
const REACT_STIFFNESS: float = 120.0
const REACT_DAMPING: float = 17.0
const LEAN_STIFFNESS: float = 105.0
const LEAN_DAMPING: float = 14.5
const REACT_HZ: float = 120.0
const MAX_SUBSTEPS: int = 8
const RECOIL_LIMIT: float = 0.32
const LEAN_LIMIT: float = 0.42
const STAGGER_KICK: float = 4.2
const STAGGER_TIP: float = 6.4
const HITCH_TIME: float = 0.34

# --- Death ---------------------------------------------------------------------
## The wreck goes over about the edge of its footprint, away from what killed it.
const FALL_GRAVITY: float = 13.0
const FALL_REST: float = PI * 0.5
const FALL_BOUNCE: float = 0.22
const BUCKLE_ANGLE: float = 0.95
const WRECK_SINK: float = 0.06
## The killing hit's snap, the sputter, the knees: how long before it goes over.
const DEATH_STAND: float = 0.78

## Weapons swung by hand: they hang heavy at rest and their strikes are melee.
const MELEE: PackedStringArray = ["hammer", "maul", "saw", "ripper", "lance"]
## Rest pose by weapon: (upper arm, forearm) as angles from straight DOWN toward forward. A hammer
## hangs forward-down ready to come up, a saw is held out low, a gun is level.
const REST_AIM: Dictionary = {
	"hammer": Vector2(0.15, 0.70), "maul": Vector2(0.15, 0.70),
	"saw": Vector2(0.25, 1.15), "ripper": Vector2(0.25, 1.15),
	"lance": Vector2(0.30, 1.40), "mortar": Vector2(0.30, 1.85),
	"scanner": Vector2(0.35, 1.55), "": Vector2(0.25, 1.50),
}

var _body: Node3D
var _base: Vector3 = Vector3.ZERO
var _base_yaw: float = 0.0
var _scale: float = 1.0
var _leg_len: float = 0.4
var _gait: Dictionary = GAITS["line"]

# Rigid limbs (the shipped roster): leg nodes turn at the hip, arm nodes about their socket.
var _leg_l: Node3D
var _leg_r: Node3D
var _leg_rest: Dictionary = {}
var _arm_l: Node3D
var _arm_r: Node3D
## slot -> {node, rest (Transform3D, in its socket), skel, ids, s0/e0/w0 and bases in socket space,
## m (socket <- skeleton), side, stance (Vector3 sh/el/wr)}
var _arms: Dictionary = {}
## Sockets the upper body carries: node -> rest transform (in the chassis frame).
var _sockets: Dictionary = {}

# Skeleton frame.
var _frame_skel: Skeleton3D
var _frame_bones: Dictionary = {}
var _legs: Dictionary = {}
var _fwd: Vector3 = Vector3(0, 0, 1)
var _torso_rest: Transform3D = Transform3D.IDENTITY
var _torso_pivot: Vector3 = Vector3.ZERO
var _chassis: Node3D
## Points on the upper body (chassis frame) checked against the floor when the wreck is down.
var _probe_top: PackedVector3Array = PackedVector3Array()

# Motion state.
var _moving: bool = false
var _stride: float = 0.0
var _phase: float = 0.0
var _last_holder: Vector3 = Vector3.INF
var _last_contact := PackedInt32Array([-1, -1])
var _clock: float = 0.0
## layer -> {keys: Array, time: float, from: PackedFloat32Array, fired: int, stepped: bool}
var _layers: Dictionary = {}
var _striking: Dictionary = {}
## Stepped shudder after a heavy hit or impact: seconds left and strength.
var _shudder: float = 0.0
var _shudder_amp: float = 0.0
var _pose: PackedFloat32Array = PackedFloat32Array()

# Springs.
var _recoil: Vector3 = Vector3.ZERO
var _recoil_velocity: Vector3 = Vector3.ZERO
var _lean: Vector2 = Vector2.ZERO
var _lean_velocity: Vector2 = Vector2.ZERO
var _hitch: float = 0.0
var _react_clock: float = 0.0

# Death.
var _dead: bool = false
var _death_clock: float = 0.0
var _fall: float = 0.0
var _fall_velocity: float = 0.0
var _fall_axis: Vector3 = Vector3.RIGHT
var _fall_dir: Vector3 = Vector3(0, 0, 1)
var _pivot: Vector3 = Vector3.ZERO
var _landed: int = 0
var _buckle: float = 0.0
var _lift: float = 0.0
var _kneel_lift: float = 0.0
var _slide: Vector2 = Vector2.ZERO
var _frozen_legs: Dictionary = {}


# --- Binding --------------------------------------------------------------------

## Binds to an assembled model. Missing limbs are fine: a body with no legs still reacts.
func bind(model: Node3D) -> void:
	_body = model
	_base = model.position
	_base_yaw = model.rotation.y
	_scale = model.scale.y
	_pose.resize(N_CH)
	_leg_l = _find(model, "limb_leg_l")
	_leg_r = _find(model, "limb_leg_r")
	for leg: Node3D in [_leg_l, _leg_r]:
		if leg != null:
			_leg_rest[leg] = leg.transform
	if _leg_l != null:
		_leg_len = maxf(_leg_l.position.y, 0.2)
	_chassis = _find(model, "part_chassis")
	_arm_l = _first_child_of(_find(model, "socket_arm_l"))
	_arm_r = _first_child_of(_find(model, "socket_arm_r"))
	for name: String in ["socket_arm_l", "socket_arm_r", "socket_core", "socket_module"]:
		var socket: Node3D = _find(model, name)
		if socket != null:
			_sockets[socket] = socket.transform
	_bind_frame(model)
	for slot: String in ["arm_l", "arm_r"]:
		_bind_arm(slot)
	_bind_probe()
	_bind_skin_points()
	_bind_guards()
	_apply(_pose)


func _bind_frame(model: Node3D) -> void:
	_frame_skel = _skeleton_in(_chassis if _chassis != null else model, "hip_l")
	if _frame_skel == null:
		return
	for bone: String in ["torso", "hip_l", "knee_l", "ankle_l", "hip_r", "knee_r", "ankle_r"]:
		_frame_bones[bone] = _frame_skel.find_bone(bone)
	var to_body: Transform3D = _relative(_frame_skel)
	_fwd = (to_body.basis.inverse() * FWD)
	_fwd.y = 0.0
	_fwd = _fwd.normalized()
	for tag: String in ["l", "r"]:
		var h: Transform3D = _frame_skel.get_bone_global_rest(_frame_bones["hip_" + tag])
		var k: Transform3D = _frame_skel.get_bone_global_rest(_frame_bones["knee_" + tag])
		var a: Transform3D = _frame_skel.get_bone_global_rest(_frame_bones["ankle_" + tag])
		# Which way this knee bends, as drawn: forward (a person) or back (a bird's leg).
		var line: Vector3 = (a.origin - h.origin).normalized()
		var off: Vector3 = (k.origin - h.origin) - line * (k.origin - h.origin).dot(line)
		var side: float = -1.0 if off.dot(_fwd) < -0.005 else 1.0
		# 060: the knee bends toward where it is DRAWN (sideways splay included): solving it in the pure
		# forward plane turned the shin and swung its foot end into the floor.
		var pole: Vector3 = off.normalized() if off.length() > 0.002 else _fwd * side
		_legs[tag] = {"hip": h, "knee": k, "ankle": a, "side": side, "pole": pole,
			"l1": (k.origin - h.origin).length(), "l2": (a.origin - k.origin).length()}
	_leg_len = (float(_legs["l"]["l1"]) + float(_legs["l"]["l2"])) * to_body.basis.get_scale().y
	if int(_frame_bones["torso"]) >= 0:
		_torso_rest = _frame_skel.get_bone_global_rest(_frame_bones["torso"])
		_torso_pivot = to_body * _torso_rest.origin


func _bind_arm(slot: String) -> void:
	var node: Node3D = _arm_l if slot == "arm_l" else _arm_r
	if node == null:
		return
	var socket: Node3D = node.get_parent() as Node3D
	var side: float = signf((_relative(socket).origin).x)
	if side == 0.0:
		side = -1.0 if slot == "arm_l" else 1.0
	var arm: Dictionary = {"node": node, "rest": node.transform, "side": side, "stance": Vector3.ZERO}
	var sk: Skeleton3D = _skeleton_in(node, "shoulder")
	if sk != null and sk.find_bone("elbow") >= 0 and sk.find_bone("wrist") >= 0:
		var ids: Array[int] = [sk.find_bone("shoulder"), sk.find_bone("elbow"), sk.find_bone("wrist")]
		var m: Transform3D = _relative_to(sk, socket)
		var rests: Array[Transform3D] = []
		for id: int in ids:
			rests.append(m * sk.get_bone_global_rest(id))
		arm["skel"] = sk
		arm["ids"] = ids
		arm["m"] = m
		arm["m_inv"] = m.affine_inverse()
		arm["rests"] = rests
	_arms[slot] = arm
	_set_stance(slot, "")


## Top corners of the chassis meshes (in the chassis frame): with the bones and sockets, the points
## kept above the floor when a wreck lies down.
func _bind_probe() -> void:
	if _chassis == null:
		return
	var inv: Transform3D = _chassis.global_transform.affine_inverse() if _chassis.is_inside_tree() else Transform3D.IDENTITY
	for mesh: MeshInstance3D in ConstructView.meshes_of(_chassis):
		var to_chassis: Transform3D = (inv * mesh.global_transform) if _chassis.is_inside_tree() else _relative_to(mesh, _chassis)
		var box: AABB = mesh.get_aabb()
		for i: int in 8:
			var p: Vector3 = to_chassis * box.get_endpoint(i)
			if p.y > _torso_pivot.y:
				_probe_top.append(p)


## 060: a sample of each skinned mesh's vertices, in the frame of the bone it is bound to, so the
## machine's TRUE lowest point can be found in any pose (`lowest_point`): the feet against the floor
## while it runs, a wreck kept out of the ground. [Skeleton3D, bone, PackedVector3Array] per bone.
var _skin_points: Array = []
## Unskinned meshes (rigid parts): [MeshInstance3D, PackedVector3Array of mesh-space points].
var _rigid_points: Array = []
const SKIN_SAMPLES: int = 48
## 060: what must never go under the floor while the machine stands: per leg tag, the skin points of
## its hip, knee and ankle bones (skeleton frames); or the rigid leg meshes' points.
var _leg_guard: Dictionary = {}
var _rigid_guard: Array = []


func _bind_guards() -> void:
	_leg_guard = {"l": [], "r": []}
	_rigid_guard = []
	for entry: Array in _skin_points:
		if entry[0] != _frame_skel:
			continue
		var name: String = _frame_skel.get_bone_name(int(entry[1]))
		for tag: String in ["l", "r"]:
			if name.ends_with("_" + tag) and name != "torso":
				(_leg_guard[tag] as Array).append(entry)
	for arm: Dictionary in _arms.values():
		var node: Node3D = arm["node"]
		arm["guard_skin"] = _skin_points.filter(func(e: Array) -> bool: return node.is_ancestor_of(e[0]))
		arm["guard_rigid"] = _rigid_points.filter(func(e: Array) -> bool: return node == e[0] or node.is_ancestor_of(e[0]))
	for entry: Array in _rigid_points:
		var mesh: MeshInstance3D = entry[0]
		for leg: Node3D in [_leg_l, _leg_r]:
			if leg != null and (leg == mesh or leg.is_ancestor_of(mesh)):
				_rigid_guard.append(entry)


## The lowest world y of a set of skin entries / rigid entries.
static func _low_of(skin: Array, rigid: Array) -> float:
	var low: float = INF
	for entry: Array in skin:
		var sk: Skeleton3D = entry[0]
		var g: Transform3D = sk.global_transform * sk.get_bone_global_pose(int(entry[1]))
		for p: Vector3 in entry[2]:
			low = minf(low, (g * p).y)
	for entry: Array in rigid:
		var g: Transform3D = (entry[0] as MeshInstance3D).global_transform
		for p: Vector3 in entry[1]:
			low = minf(low, (g * p).y)
	return low


func _floor_y() -> float:
	var parent: Node3D = _body.get_parent() as Node3D
	return (parent.global_position.y if parent != null and parent.is_inside_tree() else 0.0) + _base.y


func _bind_skin_points() -> void:
	_skin_points = []
	_rigid_points = []
	for mesh: MeshInstance3D in ConstructView.meshes_of(_body):
		if mesh.mesh == null:
			continue
		var sk: Skeleton3D = mesh.get_node_or_null(mesh.skeleton) as Skeleton3D if mesh.skin != null else null
		var by_bone: Dictionary = {}
		var flat := PackedVector3Array()
		for surface: int in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
			var per: int = (bones.size() / verts.size()) if verts.size() > 0 and bones.size() > 0 else 0
			for i: int in verts.size():
				if sk == null or per == 0:
					flat.append(verts[i])
					continue
				var best: int = 0
				for j: int in per:
					if weights[i * per + j] > weights[i * per + best]:
						best = j
				var bind: int = bones[i * per + best]
				var list: PackedVector3Array = by_bone.get(bind, PackedVector3Array())
				list.append(verts[i])
				by_bone[bind] = list  # a packed array read out of a Dictionary is a copy
		if sk != null:
			for bind: int in by_bone:
				var bone: int = mesh.skin.get_bind_bone(bind)
				if bone < 0:
					bone = sk.find_bone(String(mesh.skin.get_bind_name(bind)))
				if bone < 0:
					continue
				var pose: Transform3D = mesh.skin.get_bind_pose(bind)
				_skin_points.append([sk, bone, _sample(by_bone[bind], pose)])
		elif not flat.is_empty():
			_rigid_points.append([mesh, _sample(flat, Transform3D.IDENTITY)])


## Up to SKIN_SAMPLES points from `points`, the lowest ones first (they are the ones that touch).
static func _sample(points: PackedVector3Array, into: Transform3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var step: int = maxi(1, points.size() / SKIN_SAMPLES)
	for i: int in range(0, points.size(), step):
		out.append(into * points[i])
	# Extremes along every axis, so a thin foot plate is never missed between samples.
	for axis: int in 3:
		var lo: int = 0
		var hi: int = 0
		for i: int in points.size():
			if points[i][axis] < points[lo][axis]:
				lo = i
			if points[i][axis] > points[hi][axis]:
				hi = i
		if not points.is_empty():
			out.append(into * points[lo])
			out.append(into * points[hi])
	return out


## Bone poses set this frame are applied lazily; measure only after they are.
func _refresh_skeletons() -> void:
	if _frame_skel != null and is_instance_valid(_frame_skel):
		_frame_skel.force_update_all_bone_transforms()
	for arm: Dictionary in _arms.values():
		if arm.has("skel") and is_instance_valid(arm["skel"]):
			(arm["skel"] as Skeleton3D).force_update_all_bone_transforms()


## The machine's lowest point (world y), from its posed vertices.
func lowest_point() -> float:
	return float(lowest()[0])


## [world y, what it is] of the lowest posed vertex (a bone name or a mesh name).
func lowest() -> Array:
	var low: float = INF
	var what: String = ""
	for entry: Array in _skin_points:
		var sk: Skeleton3D = entry[0]
		if not is_instance_valid(sk) or not sk.is_inside_tree():
			continue
		var g: Transform3D = sk.global_transform * sk.get_bone_global_pose(int(entry[1]))
		for p: Vector3 in entry[2]:
			var y: float = (g * p).y
			if y < low:
				low = y
				what = "%s/%s" % [sk.get_parent().name, sk.get_bone_name(int(entry[1]))]
	for entry: Array in _rigid_points:
		var mesh: MeshInstance3D = entry[0]
		if not is_instance_valid(mesh) or not mesh.is_inside_tree() or not mesh.is_visible_in_tree():
			continue
		var g: Transform3D = mesh.global_transform
		for p: Vector3 in entry[1]:
			var y: float = (g * p).y
			if y < low:
				low = y
				what = String(mesh.name)
	return [low, what]


## The rest pose of each arm from its weapon: hand weapons hang heavy, guns are held level.
## `classes` is [arm_l class, arm_r class].
func set_stances(classes: PackedStringArray) -> void:
	for i: int in mini(classes.size(), 2):
		_set_stance("arm_l" if i == 0 else "arm_r", classes[i])
	_apply(_pose)


## Which gait: the chassis' role (brawler, anchor, line, marksman).
func set_gait(role: String) -> void:
	_gait = GAITS.get(role, GAITS["line"])


func _set_stance(slot: String, weapon_class: String) -> void:
	var arm: Dictionary = _arms.get(slot, {})
	if arm.is_empty():
		return
	arm["class"] = weapon_class
	if not arm.has("skel"):
		return
	var aim: Vector2 = REST_AIM.get(weapon_class, REST_AIM[""])
	var rests: Array[Transform3D] = arm["rests"]
	var upper: float = _sagittal(rests[1].origin - rests[0].origin)
	var fore: float = _sagittal(rests[2].origin - rests[1].origin)
	var sh: float = wrapf(aim.x - upper, -PI, PI)
	var el: float = wrapf(aim.y - (fore + sh), -PI, PI)
	arm["stance"] = Vector3(sh, el, 0.0)
	# 062: the upper arm hangs straight down from its shoulder (a drawn arm slanting outward held
	# the whole arm away from the frame).
	var u: Vector3 = rests[1].origin - rests[0].origin
	var lateral: float = atan2(u.x * float(arm["side"]), -u.y)
	arm["stance_fl"] = clampf(-(lateral - 0.06), -0.7, 0.2)


## A direction's angle in the side view: 0 straight down, PI/2 forward, PI straight up.
static func _sagittal(v: Vector3) -> float:
	return atan2(v.z, -v.y)


func has_skeleton() -> bool:
	if _frame_skel != null:
		return true
	for arm: Dictionary in _arms.values():
		if arm.has("skel"):
			return true
	return false


# --- Driving --------------------------------------------------------------------

func set_moving(moving: bool) -> void:
	if moving == _moving:
		return
	_moving = moving
	if _dead:
		return
	if moving:
		# Crouch and rock back, then throw the weight forward into the first stride.
		_play("move", [
			[0.07, _p({"drop": 0.12, "pitch": -0.10, "tpitch": -0.06, "sh": -0.25, "osh": -0.25}), SNAP],
			[0.12, _p({"drop": 0.04, "pitch": 0.10, "tpitch": 0.10}), SMEAR],
			[0.20, _p({}), EASE],
		])
	else:
		# The brake: heels dig in and the body rears back, then the top carries on forward past
		# upright (follow-through), arms swinging through, and settles.
		_play("move", [
			[0.06, _p({"drop": 0.16, "pitch": -0.16, "tpitch": -0.12, "surge": -0.05,
				"sh": 0.25, "osh": 0.25}), SNAP],
			[0.14, _p({"drop": 0.05, "pitch": 0.08, "tpitch": 0.14, "sh": 0.35, "osh": 0.35}), BACK],
			[0.26, _p({}), EASE],
		])
		_recoil_velocity.y -= FOOTFALL * 0.8


## How long the scene should let the start crouch play before the machine moves off.
func start_lead() -> float:
	return 0.07


func update(delta: float, speed_scale: float = 1.0) -> void:
	if _body == null or not is_instance_valid(_body):
		return
	_clock += delta
	_advance_reactions(delta)
	if _dead:
		_advance_death(delta)
		return
	_hitch = maxf(0.0, _hitch - delta)
	var pose: PackedFloat32Array = _rest_pose()
	_add(pose, _run_pose(delta, speed_scale))
	_add(pose, _idle_pose())
	_advance_layers(delta, pose)
	_add_shudder(delta, pose)
	_pose = pose
	_apply(pose)
	_keep_feet_down()


## 060: last resort, for stiff legs: if a leg still reaches under the floor, the body is lifted.
func _keep_feet_down() -> void:
	if _rigid_guard.is_empty() or not _body.is_inside_tree():
		return
	var under: float = _floor_y() - _low_of([], _rigid_guard)
	if under > 0.001:
		_body.global_position.y += under


## A hit landing. `direction` is the push in the machine's OWN space; `severity` is 0..1, scaled by
## the caller against the target's health. Impulses add (a spring), and a held impact pose plays on
## top: the torso snaps with the push, the arms fly, the knees give, a heavy hit takes a stumble step.
func stagger(direction: Vector3, severity: float) -> void:
	if _body == null or not is_instance_valid(_body) or _dead:
		return
	var force: float = clampf(severity, 0.0, 1.0)
	if force <= 0.0:
		return
	var push: Vector3 = Vector3(direction.x, 0.0, direction.z)
	if push.length_squared() < 0.000001:
		push = Vector3(0, 0, 1)
	push = push.normalized()
	_recoil_velocity += push * STAGGER_KICK * force
	_lean_velocity += Vector2(push.z, -push.x) * STAGGER_TIP * force
	_hitch = maxf(_hitch, HITCH_TIME * force)
	var snap: PackedFloat32Array = _push_pose(push, force)
	var rebound: PackedFloat32Array = _scaled(snap, -0.22)
	# A heavy hit knocks a foot back along the push: the machine catches itself.
	var foot: int = LF_F if push.x * _side("arm_l") >= 0.0 else RF_F
	var catch: PackedFloat32Array = snap.duplicate()
	if force > 0.45:
		catch[foot] = push.z * 0.35 * force
		catch[foot + 1] = 0.18 * force
		catch[foot + 2] = absf(push.x) * 0.15 * force
		rebound[foot] = push.z * 0.30 * force
	_play("react", [
		[0.035, snap, SNAP],
		[0.05 + 0.09 * force, catch, EASE],
		[0.10, rebound, EASE],
		[0.26, _p({}), EASE],
	])
	if force > 0.4:
		_shudder = 0.10 + 0.10 * force
		_shudder_amp = 0.05 * force


## The pose a push snaps a machine into (scaled by force).
func _push_pose(push: Vector3, force: float) -> PackedFloat32Array:
	var p: PackedFloat32Array = _p({})
	p[PITCH] = push.z * 0.22 * force
	p[ROLL] = -push.x * 0.22 * force
	p[T_PITCH] = push.z * 0.38 * force
	p[T_ROLL] = -push.x * 0.34 * force
	p[T_TWIST] = push.x * 0.20 * force
	p[DROP] = 0.10 * force
	# Arms are thrown against the push and out: pushed back, they fly forward and up.
	for ch: int in [SH_L, SH_R]:
		p[ch] = -push.z * 0.70 * force + 0.15 * force
	p[FL_L] = 0.35 * force
	p[FL_R] = 0.35 * force
	p[EL_L] = 0.25 * force
	p[EL_R] = 0.25 * force
	return p


## Plays one arm's strike, shaped by `weapon_class`. Returns the seconds until the IMPACT, so the
## fight can show the shot, the flash and the sound when the weapon actually lands.
func strike(slot: String, weapon_class: String, _tree: SceneTree = null) -> float:
	if _body == null or not is_instance_valid(_body) or _dead or not _arms.has(slot):
		return 0.0
	_striking[slot] = true
	var lead: String = slot
	var keys: Array = _strike_keys(weapon_class, lead)
	var impact: float = 0.0
	for key: Array in keys:
		impact += float(key[0])
		if key.size() > 3 and key[3] is Callable:
			break
	_play("act_" + slot, keys, func() -> void: _striking.erase(slot))
	return impact


## The key poses of each weapon's strike. A key is [seconds, pose, curve, (callable at arrival)];
## the first key with a callable is the impact.
func _strike_keys(weapon_class: String, lead: String) -> Array:
	var hit := func(kick: Vector3, shake: float) -> void:
		_recoil_velocity += kick
		_shudder = maxf(_shudder, 0.12)
		_shudder_amp = maxf(_shudder_amp, shake)
	match weapon_class:
		"hammer", "maul":
			# Up and back over the head, held (the tell), then brought down with the whole body,
			# the lead foot stamping forward; it stays down a beat, rebounds, settles.
			var top := _p({"drop": 0.04, "pitch": -0.16, "tpitch": -0.26, "twist": -0.42, "sh": 2.55,
				"el": 0.55, "wr": 0.35, "osh": -0.30, "ofl": 0.30, "ff": 0.22, "fu": 0.24}, lead)
			var down := _p({"drop": 0.24, "pitch": 0.30, "tpitch": 0.38, "twist": 0.28, "sh": 0.80,
				"el": -0.45, "wr": -0.30, "osh": -0.50, "ofl": 0.45, "ff": 0.34}, lead)
			return [
				[0.09, _p({"drop": 0.10, "twist": -0.22, "pitch": -0.04, "sh": 0.35, "el": 0.2}, lead), SNAP],
				[0.15, top, EASE],
				[0.10, top, STEP],
				[0.07, down, SMEAR, hit.bind(Vector3(0, -1.1, 0), 0.07)],
				[0.15, down, STEP],
				[0.11, _p({"drop": 0.12, "pitch": 0.14, "tpitch": 0.16, "sh": 0.55, "el": -0.2, "ff": 0.34}, lead), SNAP],
				[0.30, _p({}), EASE],
			]
		"saw", "ripper":
			# Coil back with the blade cocked, lunge in, and GRIND: stepped bites, the body bucking.
			var bite := _p({"drop": 0.16, "pitch": 0.26, "tpitch": 0.18, "twist": 0.32, "surge": 0.30,
				"sh": 0.85, "el": -0.50, "osh": -0.40, "ofl": 0.25, "ff": 0.40}, lead)
			var keys: Array = [
				[0.11, _p({"drop": 0.12, "pitch": -0.10, "tpitch": -0.10, "twist": -0.40, "surge": -0.06,
					"sh": -0.25, "el": 0.65, "of": -0.1}, lead), SNAP],
				[0.08, _p({"drop": 0.12, "pitch": -0.12, "tpitch": -0.12, "twist": -0.44, "surge": -0.07,
					"sh": -0.28, "el": 0.70, "of": -0.1}, lead), STEP],
				[0.07, bite, SMEAR, hit.bind(Vector3(0, 0, 0.6), 0.04)],
			]
			for i: int in 4:
				var buck: float = 1.0 if i % 2 == 0 else -1.0
				var k: PackedFloat32Array = bite.duplicate()
				k[T_ROLL] += 0.07 * buck
				k[T_PITCH] += 0.05 * buck
				k[_ch(lead, "sh")] += 0.10 * buck
				k[_ch(lead, "el")] -= 0.08 * buck
				keys.append([0.05, k, STEP])
			keys.append([0.10, _p({"surge": 0.06, "pitch": 0.06, "sh": 0.35, "el": 0.15, "ff": 0.30}, lead), SNAP])
			keys.append([0.26, _p({}), EASE])
			return keys
		"lance":
			# A fencer's thrust: the arm drawn back and the shoulders turned away, held, then the
			# full extension with a deep lunge, held long enough to read.
			var drawn := _p({"drop": 0.08, "pitch": -0.08, "twist": -0.55, "surge": -0.08, "sh": -0.15,
				"el": 0.85, "of": -0.18, "osh": 0.2}, lead)
			var thrust := _p({"drop": 0.22, "pitch": 0.30, "tpitch": 0.12, "twist": 0.45, "surge": 0.32,
				"sh": 0.95, "el": -0.85, "wr": -0.2, "ff": 0.46, "of": -0.2, "osh": -0.45, "ofl": 0.3}, lead)
			return [
				[0.13, drawn, SNAP],
				[0.10, drawn, STEP],
				[0.06, thrust, SMEAR, hit.bind(Vector3(0, 0, 0.5), 0.03)],
				[0.18, thrust, STEP],
				[0.12, _p({"drop": 0.10, "pitch": 0.10, "surge": 0.10, "sh": 0.4, "el": -0.3, "ff": 0.3}, lead), SNAP],
				[0.28, _p({}), EASE],
			]
		"railgun":
			# Squared up low and wide, the barrel level on the target; a long stepped charge tremble
			# that rises; the shot throws the barrel up, snaps the body back and SKIDS the machine a
			# foot back along the ground (feet and all); it holds there, then walks it back.
			var aim: PackedFloat32Array = _gun_aim(lead, {"drop": 0.14, "fs": 0.12, "ofs": 0.12, "ff": 0.16, "of": -0.18})
			var keys: Array = [[0.12, aim, BACK]]
			for i: int in 4:
				var k: PackedFloat32Array = aim.duplicate()
				var s: float = (1.0 if i % 2 == 0 else -1.0) * (0.012 + 0.01 * i)
				k[T_ROLL] += s
				k[_ch(lead, "sh")] += s
				k[_ch(lead, "el")] -= s
				keys.append([0.05, k, STEP])
			var blast: PackedFloat32Array = _plus(aim, _p({"sh": 0.45, "el": 0.60, "wr": 0.25, "tpitch": -0.42,
				"twist": -0.28, "pitch": -0.16, "surge": -0.30, "ff": -0.30, "of": -0.30, "drop": 0.04,
				"osh": -0.30, "oel": -0.20, "ofl": 0.30}, lead))
			var skidded: PackedFloat32Array = _plus(aim, _p({"surge": -0.30, "ff": -0.30, "of": -0.30, "tpitch": -0.06}, lead))
			keys.append([0.0, aim, STEP, hit.bind(Vector3(0, 0, -1.4), 0.07)])
			keys.append([0.04, blast, SNAP])
			keys.append([0.10, blast, STEP])
			keys.append([0.22, skidded, BACK])
			keys.append([0.16, skidded, STEP])
			keys.append([0.36, _p({}), EASE])
			return keys
		"mortar":
			# The tube tipped up high, set low and wide, a beat -- FWOOMP drives the machine down
			# into its knees (the recoil goes into the ground), it bounces back up and watches.
			var aim: PackedFloat32Array = _gun_aim(lead, {"drop": 0.18, "pitch": -0.04, "tpitch": -0.10, "fs": 0.10, "ofs": 0.10}, 0.45)
			var thump: PackedFloat32Array = _plus(aim, _p({"drop": 0.16, "sh": -0.15, "el": -0.12, "tpitch": 0.12, "osh": -0.2}, lead))
			return [
				[0.12, aim, BACK],
				[0.10, aim, STEP, hit.bind(Vector3(0, -1.5, -0.2), 0.06)],
				[0.03, thump, SNAP],
				[0.08, thump, STEP],
				[0.14, _plus(aim, _p({"drop": -0.05}, lead)), BACK],
				[0.16, aim, STEP],
				[0.30, _p({}), EASE],
			]
		"coil", "pulse":
			# Energy: squared up and leaning IN, the arm level on the target, a stepped shiver that
			# grows while it charges (the body sinking into it); the bolt goes OUT -- the torso
			# pushes forward with it -- and only then the arm bucks up and settles back on target.
			var aim: PackedFloat32Array = _gun_aim(lead, {"tpitch": 0.10, "drop": 0.10})
			var keys: Array = [[0.10, aim, BACK]]
			for i: int in 4:
				var k: PackedFloat32Array = aim.duplicate()
				var s: float = (1.0 if i % 2 == 0 else -1.0) * (0.012 + 0.012 * i)
				k[T_ROLL] += s
				k[_ch(lead, "sh")] += s
				k[DROP] += 0.015 * i
				keys.append([0.045, k, STEP])
			var thrust: PackedFloat32Array = _plus(aim, _p({"surge": 0.07, "tpitch": 0.14, "pitch": 0.05, "sh": 0.06, "el": -0.06}, lead))
			var buck: PackedFloat32Array = _plus(aim, _p({"sh": 0.28, "el": 0.34, "wr": 0.15, "tpitch": -0.20, "twist": -0.14, "surge": -0.05}, lead))
			keys.append([0.0, aim, STEP, hit.bind(Vector3(0, 0, 0.5), 0.04)])
			keys.append([0.03, thrust, SNAP])
			keys.append([0.05, thrust, STEP])
			keys.append([0.06, buck, SNAP])
			keys.append([0.06, buck, STEP])
			keys.append([0.14, aim, BACK])
			keys.append([0.16, aim, STEP])
			keys.append([0.28, _p({}), EASE])
			return keys
		"scanner":
			# It LOOKS: the scanner arm comes up straight at the target, the upper body ticks across
			# the field and back (stepped, a searching head), snaps on, and pings twice.
			var aim: PackedFloat32Array = _gun_aim(lead, {"tpitch": -0.06, "osh": -0.5, "oel": -0.4, "ofl": 0.15}, 0.0, 0.95)
			var keys: Array = [[0.10, aim, BACK]]
			for t: float in [-0.34, 0.30, -0.10]:
				keys.append([0.08, _plus(aim, _p({"twist": t, "troll": t * 0.2}, lead)), STEP])
			var lock: PackedFloat32Array = _plus(aim, _p({"tpitch": 0.08, "drop": 0.04}, lead))
			keys.append([0.04, lock, SNAP, hit.bind(Vector3.ZERO, 0.0)])
			for i: int in 2:
				keys.append([0.05, _plus(lock, _p({"sh": 0.07, "el": -0.07}, lead)), STEP])
				keys.append([0.05, lock, STEP])
			keys.append([0.14, lock, STEP])
			keys.append([0.26, _p({}), EASE])
			return keys
		_:
			# A gun (scattergun and anything new): snapped up to the shoulder with the barrel LEVEL
			# on the target and the other arm braced, a beat -- BOOM: the barrel flips up, the
			# upper body snaps back, the machine slides back a step; held; the barrel comes back
			# down past the target and onto it; the action is racked (two stepped jerks); it holds
			# on target, then lowers.
			var aim: PackedFloat32Array = _gun_aim(lead, {})
			var kick: PackedFloat32Array = _plus(aim, _p({"sh": 0.35, "el": 0.45, "wr": 0.20, "tpitch": -0.32,
				"twist": -0.22, "pitch": -0.10, "surge": -0.12, "ff": -0.12, "of": -0.12, "osh": -0.25}, lead))
			var settled: PackedFloat32Array = _plus(aim, _p({"surge": -0.12, "ff": -0.12, "of": -0.12}, lead))
			return [
				[0.10, aim, BACK],
				[0.09, aim, STEP, hit.bind(Vector3(0, 0, -1.0), 0.06)],
				[0.035, kick, SNAP],
				[0.07, kick, STEP],
				[0.12, _plus(settled, _p({"el": -0.10}, lead)), BACK],
				[0.06, settled, SNAP],
				[0.06, _plus(settled, _p({"el": 0.25, "wr": -0.2, "sh": -0.08, "osh": 0.25}, lead)), STEP],
				[0.06, _plus(settled, _p({"el": -0.05}, lead)), STEP],
				[0.16, settled, STEP],
				[0.30, _p({}), EASE],
			]


## The shooting stance (060): the gun arm raised forward to shoulder height with the forearm kept
## LEVEL (the elbow undoes what the shoulder raised, so the barrel points at the target instead of
## the sky), the shoulders squared toward it, the other arm brought in to brace, feet set front and
## back. `extra` adds to it; `tilt` points the barrel above level (a mortar); `raise` is how high.
func _gun_aim(lead: String, extra: Dictionary, tilt: float = 0.0, raise: float = 0.75) -> PackedFloat32Array:
	var d: Dictionary = {"drop": 0.08, "pitch": 0.04, "tpitch": 0.06, "twist": 0.14, "sh": raise,
		"el": -raise + tilt, "osh": 0.60, "oel": 0.50, "ofl": -0.15, "ff": 0.12, "of": -0.14}
	var p: PackedFloat32Array = _p(d, lead)
	return _plus(p, _p(extra, lead))


static func _plus(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate()
	for i: int in mini(out.size(), b.size()):
		out[i] += b[i]
	return out


## The machine is destroyed. `direction` is which way it goes down (its own space): away from
## whatever killed it. The killing hit SNAPS it (held), it sputters (stepped twitches, one arm dies
## first), the knees give, it hangs on its knees a beat -- and goes over, lands, bounces once.
## Idempotent: DESTROYED can be re-applied when playback is skipped.
func collapse(direction: Vector3) -> void:
	if _dead or _body == null or not is_instance_valid(_body):
		return
	_dead = true
	_death_clock = 0.0
	_striking.clear()
	var fall: Vector3 = Vector3(direction.x, 0.0, direction.z)
	if fall.length_squared() < 0.000001:
		fall = Vector3(0, 0, 1)
	fall = fall.normalized()
	_fall_dir = fall
	_fall_axis = Vector3(fall.z, 0.0, -fall.x).normalized()
	_fall = 0.0
	_fall_velocity = 0.0
	_landed = 0
	_buckle = 0.0
	_lift = 0.0
	_kneel_lift = 0.0
	_slide = Vector2.ZERO
	_recoil_velocity += fall * 0.9
	# 062: how it dies depends on what it still has. Two arms: it loses one, looks, reaches with the
	# other and falls back. One arm: it stumbles back clutching its chest, reaches for its killer,
	# the last arm drops off, and it falls on its face. No arms: it looks at both stumps, sways, a
	# knee gives on one side and it topples over sideways.
	var plan: Array
	match _arms.size():
		0:
			plan = _death_none(fall)
		1:
			plan = _death_one(fall)
		_:
			plan = _death_two(fall)
	var keys: Array = plan[0]
	_death_hold = plan[1]
	_fall_dir = plan[2]
	_fall_axis = Vector3(_fall_dir.z, 0.0, -_fall_dir.x).normalized()
	fall = _fall_dir
	_stand_time = 0.0
	for key: Array in keys:
		_stand_time += float(key[0])
	_layers.erase("react")
	_layers.erase("move")
	_layers.erase("act_arm_l")
	_layers.erase("act_arm_r")
	var now: PackedFloat32Array = _pose.duplicate() if _pose.size() == N_CH else _p({})
	var rest: PackedFloat32Array = _rest_pose()
	for i: int in N_CH:
		now[i] -= rest[i]
	_play("death", keys)
	(_layers["death"] as Dictionary)["from"] = now
	_pivot = fall * _reach(fall)


## Two arms (060): one breaks off, it looks where it was, one step, the other arm reaches, the
## backpack drops, the knees give, its head comes up once -- and it goes over backwards.
func _death_two(fall: Vector3) -> Array:
	# 060: it FALLS APART, and it minds. The killing hit snaps it; the arm on the side it was hit
	# from breaks off; it reels from the lost weight and turns to look at where the arm was; it tries
	# one step and reaches out with the arm it has left, shaking; the backpack drops off; the knees
	# give; on its knees it lifts its head once -- and goes over. Landing, its core rolls out of its
	# chest and the last arm comes loose.
	var lost: String = "arm_l" if fall.x * _side("arm_l") <= 0.0 else "arm_r"
	var kept: String = "arm_r" if lost == "arm_l" else "arm_l"
	var limp: PackedFloat32Array = _limp()
	var jolt: PackedFloat32Array = _push_pose(fall, 1.0)
	jolt[DROP] = 0.06
	jolt[SURGE] = fall.z * 0.12
	jolt[SWAY] = fall.x * 0.12
	var reel: PackedFloat32Array = _p({"roll": -0.18, "troll": -0.12, "drop": 0.08, "osh": 0.55, "oel": 0.2, "ofl": 0.45,
		"twist": 0.15, "ff": -0.12, "fu": 0.0}, lost)
	var look: PackedFloat32Array = _p({"roll": 0.06, "twist": -0.38, "tpitch": 0.30, "troll": 0.10, "drop": 0.10,
		"osh": 0.25, "oel": 0.45, "ofl": -0.1, "ff": -0.12}, lost)
	var look_twitch: PackedFloat32Array = _plus(look, _p({"twist": -0.06, "tpitch": 0.05, "osh": 0.08}, lost))
	var lift_step: PackedFloat32Array = _p({"surge": 0.08, "pitch": 0.10, "tpitch": -0.06, "twist": 0.18, "drop": 0.06,
		"osh": 1.25, "oel": -0.70, "ofl": 0.05, "of": 0.20, "ofu": 0.22, "ff": -0.12}, lost)
	var reach: PackedFloat32Array = _p({"surge": 0.12, "pitch": 0.12, "tpitch": -0.10, "twist": 0.18, "drop": 0.15,
		"osh": 1.35, "oel": -0.75, "of": 0.30, "ff": -0.12}, lost)
	var kneel: PackedFloat32Array = _plus(limp, _p({"drop": 0.30, "tpitch": 0.40, "pitch": 0.06, "surge": 0.04,
		"of": 0.30, "ff": -0.12}, lost))
	var head_up: PackedFloat32Array = _plus(kneel, _p({"tpitch": -0.22, "osh": 0.25}, lost))
	var bow: PackedFloat32Array = _plus(kneel, _p({"tpitch": 0.15}, lost))
	var keys: Array = [
		[0.04, jolt, SNAP],
		[0.10, jolt, STEP, _break_arm.bind(lost, fall)],
		[0.06, reel, SNAP],
		[0.14, look, EASE],
		[0.16, look, STEP],
		[0.10, look_twitch, STEP],
		[0.10, look, STEP],
		[0.16, lift_step, SMEAR],
		[0.08, reach, SNAP],
	]
	for i: int in 3:
		var k: PackedFloat32Array = reach.duplicate()
		var shake: float = 0.06 if i % 2 == 0 else -0.05
		k[_ch(kept, "sh")] += shake
		k[_ch(kept, "el")] -= shake * 0.5
		k[T_ROLL] += shake * 0.6
		keys.append([0.07, k, STEP])
	keys.append([0.0, reach, STEP, _break_part.bind("part_module", Vector3(0, 0, -1), 1.2)])
	keys.append([0.20, kneel, SMEAR])
	keys.append([0.16, kneel, STEP])
	keys.append([0.16, head_up, EASE])
	keys.append([0.12, head_up, STEP])
	keys.append([0.14, bow, SMEAR])
	return [keys, bow, fall]


## One arm: knocked back two stumbling steps, it hunches and clutches its chest with the arm it
## has; the backpack drops; it straightens to reach for whatever killed it, shaking -- and that arm
## drops off too. It sags to its knees and falls forward, on its face.
func _death_one(fall: Vector3) -> Array:
	var kept: String = _arms.keys()[0]
	var back: float = clampf(fall.z, -1.0, 1.0)
	var jolt: PackedFloat32Array = _push_pose(fall, 1.0)
	jolt[DROP] = 0.06
	var step_a := _p({"surge": back * 0.10, "drop": 0.10, "tpitch": 0.15, "ff": back * 0.28, "fu": 0.22, "sh": 0.4, "fl": 0.3}, kept)
	var plant_a := _p({"surge": back * 0.14, "drop": 0.14, "tpitch": 0.20, "ff": back * 0.28, "sh": 0.3}, kept)
	var step_b := _p({"surge": back * 0.22, "drop": 0.12, "tpitch": 0.22, "ff": back * 0.28, "of": back * 0.30, "ofu": 0.2, "sh": 0.3}, kept)
	var plant_b := _p({"surge": back * 0.26, "drop": 0.16, "tpitch": 0.25, "ff": back * 0.28, "of": back * 0.30}, kept)
	var clutch := _plus(plant_b, _p({"tpitch": 0.18, "troll": 0.06, "sh": 0.85, "el": 1.15, "fl": -0.55, "drop": 0.04}, kept))
	var reach := _plus(plant_b, _p({"tpitch": -0.18, "twist": 0.20, "pitch": 0.08, "sh": 1.35, "el": -0.70, "fl": 0.0}, kept))
	var sag := _plus(plant_b, _p({"tpitch": 0.30, "drop": 0.10, "pitch": 0.10}, kept))
	var kneel := _plus(sag, _p({"drop": 0.16, "tpitch": 0.12, "pitch": 0.06}, kept))
	var keys: Array = [
		[0.04, jolt, SNAP],
		[0.10, jolt, STEP],
		[0.12, step_a, SMEAR],
		[0.07, plant_a, SNAP],
		[0.12, step_b, SMEAR],
		[0.07, plant_b, SNAP],
		[0.16, clutch, EASE],
	]
	for i: int in 3:
		var k: PackedFloat32Array = clutch.duplicate()
		k[T_ROLL] += 0.05 if i % 2 == 0 else -0.05
		k[T_PITCH] += 0.03 if i % 2 == 0 else 0.0
		keys.append([0.08, k, STEP])
	keys.append([0.0, clutch, STEP, _break_part.bind("part_module", Vector3(0, 0, -1), 1.0)])
	keys.append([0.18, reach, EASE])
	for i: int in 3:
		var k: PackedFloat32Array = reach.duplicate()
		var shake: float = 0.07 if i % 2 == 0 else -0.06
		k[_ch(kept, "sh")] += shake
		k[T_ROLL] += shake * 0.5
		keys.append([0.07, k, STEP])
	keys.append([0.0, reach, STEP, _break_arm.bind(kept, -fall)])
	keys.append([0.10, sag, SNAP])
	keys.append([0.20, kneel, SMEAR])
	keys.append([0.18, kneel, STEP])
	# Forward: toward what killed it.
	return [keys, kneel, -fall]


## No arms: it looks down at one stump, then the other; it sways, wider each time; a knee gives
## on one side and it topples over that way.
func _death_none(fall: Vector3) -> Array:
	var side := Vector3(1, 0, 0) if fall.x >= 0.0 else Vector3(-1, 0, 0)
	var s: float = side.x
	var jolt: PackedFloat32Array = _push_pose(fall, 1.0)
	jolt[DROP] = 0.06
	var look_a := _p({"twist": 0.0, "tpitch": 0.28, "drop": 0.08})
	look_a[T_TWIST] = 0.38
	look_a[T_ROLL] = -0.08
	var look_b := _p({"tpitch": 0.28, "drop": 0.08})
	look_b[T_TWIST] = -0.38
	look_b[T_ROLL] = 0.08
	var keys: Array = [
		[0.04, jolt, SNAP],
		[0.12, jolt, STEP],
		[0.16, look_a, EASE],
		[0.18, look_a, STEP],
		[0.16, look_b, EASE],
		[0.18, look_b, STEP],
	]
	for i: int in 3:
		var k := _p({"tpitch": 0.20, "drop": 0.10 + 0.03 * i})
		var w: float = (0.08 + 0.05 * i) * (1.0 if i % 2 == 0 else -1.0)
		k[SWAY] = w
		k[ROLL] = -w * 0.8
		keys.append([0.20, k, EASE])
	keys.append([0.0, keys[keys.size() - 1][1], STEP, _break_part.bind("part_module", Vector3(0, 0, -1), 1.0)])
	# The knee on the falling side gives: that foot slides out, the body drops and leans over it.
	var give := _p({"tpitch": 0.25, "drop": 0.22})
	give[SWAY] = s * 0.10
	give[ROLL] = -s * 0.22
	var foot: int = LF_F if s == _hip_side(0) else RF_F
	give[foot + 2] = 0.18
	keys.append([0.18, give, SMEAR])
	keys.append([0.16, give, STEP])
	return [keys, give, side]


# --- 060/061: parts that break off -------------------------------------------------------
# 061: a loose part is a SOLID body (RigidBody3D with a box from its own vertices): it lands on the
# floor, on the wreck and on the other parts instead of through them. The wreck carries a box per
# frame bone (`_wreck`, moved with the bones every frame); the floor is a plane under the hex.
# Parts stay on the machine's hex (`LOOSE_RADIUS`): the board is hexes.

## Called with (world position, what broke) when a part comes off, for sparks and a sound word.
var on_break: Callable = Callable()
## The held last pose of a death, and how long it stands before it goes over.
var _death_hold: PackedFloat32Array = PackedFloat32Array()
var _stand_time: float = DEATH_STAND
## Loose parts: {body: RigidBody3D, node, age, apart: bool (exception with the wreck lifted)}.
var _loose: Array = []
## The wreck's colliders: AnimatableBody3D and [CollisionShape3D, bone, local centre] per frame bone.
var _wreck: AnimatableBody3D
var _wreck_boxes: Array = []
var _floor_body: StaticBody3D
## Physics layer of loose parts, wrecks and their floors only (the board uses none).
const LOOSE_LAYER: int = 1 << 19
## How far from the middle of its hex a loose part may end up, in metres of a machine's size.
const LOOSE_RADIUS: float = 0.42


func _break_arm(slot: String, fall: Vector3) -> void:
	if not _arms.has(slot):
		return
	var node: Node3D = (_arms[slot] as Dictionary)["node"]
	_arms.erase(slot)
	# Knocked off its shoulder: out on its own side a little, up, turning over. It falls by the
	# machine, not across the board.
	var out := Vector3(_side(slot), 0.0, 0.0)
	_break_node(node, out * 0.55 + fall * 0.25 + Vector3.UP * 1.1, Vector3(-3.0, 0.5, _side(slot) * 3.5), "arm")
	_recoil_velocity += -out * 0.4


func _break_part(name: String, push: Vector3, up: float) -> void:
	var node: Node3D = _find(_body, name)
	if node == null:
		return
	_break_node(node, push * 0.5 + Vector3.UP * up, Vector3(2.0, 1.0, -1.5), name.trim_prefix("part_"))


## Takes `node` off the machine (it keeps where it is in the world) as a solid body.
## `velocity` is in the machine's own space, per metre of its size.
func _break_node(node: Node3D, velocity: Vector3, spin: Vector3, what: String) -> void:
	if node == null or not is_instance_valid(node) or not _body.is_inside_tree():
		return
	var holder: Node3D = _body.get_parent() as Node3D
	if holder == null:
		return
	_ensure_physics(holder)
	var skin: Array = []
	var rigid: Array = []
	for entry: Array in _skin_points.duplicate():
		if node.is_ancestor_of(entry[0]):
			skin.append(entry)
			_skin_points.erase(entry)
	for entry: Array in _rigid_points.duplicate():
		if node == entry[0] or node.is_ancestor_of(entry[0]):
			rigid.append(entry)
			_rigid_points.erase(entry)
	var keep: Transform3D = node.global_transform
	var body := RigidBody3D.new()
	body.collision_layer = LOOSE_LAYER
	body.collision_mask = LOOSE_LAYER
	body.continuous_cd = true
	body.linear_damp = 0.4
	body.angular_damp = 2.5
	body.contact_monitor = true
	body.max_contacts_reported = 2
	var frame := Transform3D(keep.basis.orthonormalized(), keep.origin)
	holder.add_child(body)
	body.global_transform = frame
	# A box around the part's own posed vertices, in the body's frame.
	var inv: Transform3D = frame.affine_inverse()
	var box := AABB()
	var first: bool = true
	for entry: Array in skin:
		var sk: Skeleton3D = entry[0]
		var g: Transform3D = inv * sk.global_transform * sk.get_bone_global_pose(int(entry[1]))
		for p: Vector3 in entry[2]:
			box = AABB(g * p, Vector3.ZERO) if first else box.expand(g * p)
			first = false
	for entry: Array in rigid:
		var g: Transform3D = inv * (entry[0] as MeshInstance3D).global_transform
		for p: Vector3 in entry[1]:
			box = AABB(g * p, Vector3.ZERO) if first else box.expand(g * p)
			first = false
	if first:
		box = AABB(Vector3(-0.05, -0.05, -0.05), Vector3(0.1, 0.1, 0.1))
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	# A little smaller than the vertices: boxes are fatter than the pieces they stand for.
	cube.size = (box.size * 0.85).max(Vector3.ONE * 0.03)
	shape.shape = cube
	shape.position = box.get_center()
	body.add_child(shape)
	body.mass = clampf(box.size.x * box.size.y * box.size.z * 400.0, 0.5, 8.0)
	node.get_parent().remove_child(node)
	body.add_child(node)
	node.global_transform = keep
	body.linear_velocity = _body.global_transform.basis.orthonormalized() * velocity * _scale * 0.9
	body.angular_velocity = _body.global_transform.basis.orthonormalized() * spin
	if _wreck != null:
		body.add_collision_exception_with(_wreck)
	_loose.append({"body": body, "node": node, "age": 0.0, "apart": false})
	_shudder = maxf(_shudder, 0.12)
	_shudder_amp = maxf(_shudder_amp, 0.07)
	if on_break.is_valid():
		on_break.call(node.global_position, what)


## The floor under the hex and the wreck's own boxes, made once, the first time a part comes off.
func _ensure_physics(holder: Node3D) -> void:
	if _floor_body != null:
		return
	_floor_body = StaticBody3D.new()
	_floor_body.collision_layer = LOOSE_LAYER
	_floor_body.collision_mask = LOOSE_LAYER
	var plane := CollisionShape3D.new()
	plane.shape = WorldBoundaryShape3D.new()
	_floor_body.add_child(plane)
	holder.add_child(_floor_body)
	_floor_body.global_position = Vector3(holder.global_position.x, _floor_y(), holder.global_position.z)
	if _frame_skel == null:
		return
	_wreck = AnimatableBody3D.new()
	_wreck.sync_to_physics = false
	_wreck.collision_layer = LOOSE_LAYER
	_wreck.collision_mask = 0
	holder.add_child(_wreck)
	_wreck.global_transform = Transform3D.IDENTITY
	for entry: Array in _skin_points:
		if entry[0] != _frame_skel:
			continue
		var pts: PackedVector3Array = entry[2]
		if pts.size() < 4:
			continue
		var box := AABB(pts[0], Vector3.ZERO)
		for p: Vector3 in pts:
			box = box.expand(p)
		var shape := CollisionShape3D.new()
		var cube := BoxShape3D.new()
		var units: float = _frame_skel.global_transform.basis.get_scale().y
		cube.size = (box.size * units * 0.85).max(Vector3.ONE * 0.03)
		shape.shape = cube
		_wreck.add_child(shape)
		_wreck_boxes.append([shape, int(entry[1]), box.get_center()])
	_sync_wreck()


## The wreck's boxes follow its bones.
func _sync_wreck() -> void:
	if _wreck == null or not is_instance_valid(_frame_skel):
		return
	for entry: Array in _wreck_boxes:
		var g: Transform3D = _frame_skel.global_transform * _frame_skel.get_bone_global_pose(int(entry[1]))
		(entry[0] as CollisionShape3D).global_transform = Transform3D(g.basis.orthonormalized(), g * (entry[2] as Vector3))


func _advance_loose(delta: float) -> void:
	_sync_wreck()
	if _loose.is_empty() or not _body.is_inside_tree():
		return
	var holder: Node3D = _body.get_parent() as Node3D
	var centre: Vector3 = holder.global_position
	var radius: float = LOOSE_RADIUS * _scale
	for part: Dictionary in _loose:
		var body: RigidBody3D = part["body"]
		if not is_instance_valid(body):
			continue
		part["age"] = float(part["age"]) + delta
		# Clear of the wreck it came off, it may land on it.
		if not bool(part["apart"]) and float(part["age"]) > 0.3 and _wreck != null:
			body.remove_collision_exception_with(_wreck)
			part["apart"] = true
		# It stays on its hex: past the edge it is turned back and slowed.
		var flat := Vector3(body.global_position.x - centre.x, 0.0, body.global_position.z - centre.z)
		if flat.length() > radius:
			# Past the edge of its hex it is pulled back in (and the outward part of its run killed).
			var v: Vector3 = body.linear_velocity
			var outward: float = v.dot(flat.normalized())
			if outward > 0.0:
				v -= flat.normalized() * outward
			v -= flat.normalized() * (flat.length() - radius) * 6.0
			body.linear_velocity = Vector3(v.x * 0.9, v.y, v.z * 0.9)
			body.sleeping = false
		if on_break.is_valid() and body.get_contact_count() > 0 and body.linear_velocity.length() > 1.4 and not bool(part.get("clanked", false)):
			part["clanked"] = true
			on_break.call(body.global_position, "clank")


## Arms hanging dead (flex channels that undo the stance and let the forearm drop).
func _limp() -> PackedFloat32Array:
	var p: PackedFloat32Array = _p({})
	for slot: String in _arms:
		var stance: Vector3 = (_arms[slot] as Dictionary)["stance"]
		p[_ch(slot, "sh")] = -stance.x + 0.05
		p[_ch(slot, "el")] = -stance.y + 0.15
		p[_ch(slot, "wr")] = 0.2
	return p


## How far the posed machine reaches toward `dir` (its own space, unscaled), from its vertices.
func _reach_now(dir: Vector3) -> float:
	if not _body.is_inside_tree():
		return _reach(dir)
	var inv: Transform3D = _body.global_transform.affine_inverse()
	var far: float = 0.0
	for entry: Array in _skin_points:
		var sk: Skeleton3D = entry[0]
		var g: Transform3D = inv * sk.global_transform * sk.get_bone_global_pose(int(entry[1]))
		for p: Vector3 in entry[2]:
			far = maxf(far, (g * p).dot(dir))
	for entry: Array in _rigid_points:
		var g: Transform3D = inv * (entry[0] as MeshInstance3D).global_transform
		for p: Vector3 in entry[1]:
			far = maxf(far, (g * p).dot(dir))
	return clampf(far, 0.0, 0.9)


## How far the machine reaches from its feet toward `dir` (its own space).
func _reach(dir: Vector3) -> float:
	var far: float = 0.0
	var inv: Transform3D = _body.global_transform.affine_inverse() if _body.is_inside_tree() else Transform3D.IDENTITY
	for mesh: MeshInstance3D in ConstructView.meshes_of(_body):
		var box: AABB = mesh.get_aabb()
		var to_body: Transform3D = (inv * mesh.global_transform) if _body.is_inside_tree() else _relative(mesh)
		for i: int in 8:
			far = maxf(far, (to_body * box.get_endpoint(i)).dot(dir))
	return clampf(far, 0.0, 0.6)


## True once the wreck has gone over and lies still.
func is_settled() -> bool:
	return _dead and _death_clock > _stand_time and _fall >= FALL_REST - 0.03 and absf(_fall_velocity) < 0.05


## Snaps every reaction home (the Order Phase opens). A wreck stays down.
func reset_transients() -> void:
	_recoil = Vector3.ZERO
	_recoil_velocity = Vector3.ZERO
	_lean = Vector2.ZERO
	_lean_velocity = Vector2.ZERO
	_hitch = 0.0
	_react_clock = 0.0
	_shudder = 0.0
	if _dead:
		return
	_layers.clear()
	_striking.clear()
	if _body != null and is_instance_valid(_body):
		_body.position = _base
		_body.rotation.x = 0.0
		_body.rotation.z = 0.0


# --- Poses ------------------------------------------------------------------------

## A pose from named channels. Arm and foot names are relative to `lead` (the striking arm's slot):
## sh/el/wr/fl and ff/fu/fs are the lead side, osh/oel/owr/ofl and of/ofu/ofs the other.
## twist + turns the lead shoulder FORWARD; roll/sway + go toward the lead side.
## With no lead, sides are left = "lead".
func _p(d: Dictionary, lead: String = "arm_l") -> PackedFloat32Array:
	var p := PackedFloat32Array()
	p.resize(N_CH)
	var other: String = "arm_r" if lead == "arm_l" else "arm_l"
	var s: float = _side(lead)
	for key: String in d:
		var v: float = float(d[key])
		match key:
			"drop": p[DROP] += v
			"surge": p[SURGE] += v
			"sway": p[SWAY] += v * s
			"pitch": p[PITCH] += v
			"roll": p[ROLL] += -v * s
			"tpitch": p[T_PITCH] += v
			"twist": p[T_TWIST] += -v * s
			"troll": p[T_ROLL] += v
			"sh", "el", "wr", "fl": p[_ch(lead, key)] += v
			"osh", "oel", "owr", "ofl": p[_ch(other, key.substr(1))] += v
			"ff": p[_foot(lead) + 0] += v
			"fu": p[_foot(lead) + 1] += v
			"fs": p[_foot(lead) + 2] += v
			"of": p[_foot(other) + 0] += v
			"ofu": p[_foot(other) + 1] += v
			"ofs": p[_foot(other) + 2] += v
	return p


func _ch(slot: String, joint: String) -> int:
	var base: int = SH_L if slot == "arm_l" else SH_R
	match joint:
		"el": return base + 1
		"wr": return base + 2
		"fl": return base + 3
	return base


## The foot under an arm's side.
func _foot(slot: String) -> int:
	var s: float = _side(slot)
	var left_foot_side: float = -1.0
	if not _legs.is_empty():
		left_foot_side = signf((_legs["l"]["hip"] as Transform3D).origin.x)
	elif _leg_l != null:
		left_foot_side = signf(_leg_l.position.x)
	return LF_F if s == left_foot_side else RF_F


func _side(slot: String) -> float:
	if _arms.has(slot):
		return float((_arms[slot] as Dictionary)["side"])
	return -1.0 if slot == "arm_l" else 1.0


static func _add(into: PackedFloat32Array, more: PackedFloat32Array) -> void:
	for i: int in mini(into.size(), more.size()):
		into[i] += more[i]


static func _scaled(p: PackedFloat32Array, k: float) -> PackedFloat32Array:
	var out := p.duplicate()
	for i: int in out.size():
		out[i] *= k
	return out


func _rest_pose() -> PackedFloat32Array:
	var p := PackedFloat32Array()
	p.resize(N_CH)
	for slot: String in _arms:
		var stance: Vector3 = (_arms[slot] as Dictionary)["stance"]
		p[_ch(slot, "sh")] = stance.x
		p[_ch(slot, "el")] = stance.y
		p[_ch(slot, "wr")] = stance.z
		p[_ch(slot, "fl")] = float((_arms[slot] as Dictionary).get("stance_fl", 0.0))
	return p


## The run: phase follows the distance the holder actually travels (so feet keep pace with the
## ground), or time when nothing moves it (a preview). Each foot: planted and driven back, then
## knee-up and STAMPED down (it falls faster than it rose); the body sinks on each landing, rises
## through the stride, sways over the planted foot; shoulders counter the hips; arms pump.
func _run_pose(delta: float, speed_scale: float) -> PackedFloat32Array:
	var p := PackedFloat32Array()
	p.resize(N_CH)
	var holder: Node3D = _body.get_parent() as Node3D
	var at: Vector3 = holder.global_position if holder != null and holder.is_inside_tree() else Vector3.INF
	var travelled: float = 0.0
	if at != Vector3.INF and _last_holder != Vector3.INF:
		travelled = Vector2(at.x - _last_holder.x, at.z - _last_holder.z).length()
	_last_holder = at
	var hitched: float = 1.0 - clampf(_hitch / HITCH_TIME, 0.0, 1.0)
	_stride = move_toward(_stride, 1.0 if _moving else 0.0, delta * SETTLE)
	var stride: float = _stride * hitched
	if stride <= 0.001:
		_phase = 0.0
		_last_contact = PackedInt32Array([-1, -1])
		return p
	var cycle: float = float(_gait["cycle"]) * _leg_len * _scale
	if travelled > 0.0001 and cycle > 0.0:
		_phase += travelled / cycle * TAU
	else:
		_phase += delta * STRIDE_RATE * TAU * clampf(speed_scale, 0.5, 1.8) * stride
	var reach: float = float(_gait["reach"])
	var lift: float = float(_gait["lift"])
	var drop: float = 0.0
	for leg: int in 2:
		var t: float = fposmod(_phase / TAU + 0.5 * leg, 1.0)
		var step: Vector2 = _foot_step(t, reach, lift)
		var f: int = LF_F if leg == 0 else RF_F
		p[f] = step.x * stride
		p[f + 1] = step.y * stride
		# Landing: the body is lowest just after contact and rises by mid-stance.
		if t < STANCE_FRACTION:
			drop = maxf(drop, float(_gait["dip"]) * (1.0 - smoothstep(0.0, STANCE_FRACTION * 0.8, t)))
		# Each landing is a footfall: weight arrives with the foot.
		var cycle_n: int = int(floor(_phase / TAU + 0.5 * leg))
		if cycle_n != _last_contact[leg]:
			if _last_contact[leg] >= 0 and stride > 0.35:
				_recoil_velocity.y -= FOOTFALL * stride
			_last_contact[leg] = cycle_n
		# Weight over the planted foot.
		var hip_side: float = _hip_side(leg)
		var on: float = sin(PI * clampf(t / STANCE_FRACTION, 0.0, 1.0)) if t < STANCE_FRACTION else 0.0
		p[SWAY] += hip_side * float(_gait["sway"]) * on * stride
		p[ROLL] += -hip_side * float(_gait["roll"]) * on * stride
		# The shoulder on this side goes back as this foot goes forward; the arm on this side
		# swings against the leg, lagging it a little.
		p[T_TWIST] += hip_side * float(_gait["twist"]) * (step.x / maxf(reach, 0.01)) * 0.5 * stride
		var lag: Vector2 = _foot_step(fposmod(t - 0.07, 1.0), reach, lift)
		var arm: String = _arm_on(hip_side)
		if arm != "":
			var swing: float = -float(_gait["arms"]) * (lag.x / maxf(reach, 0.01)) * stride
			var held: String = String((_arms[arm] as Dictionary).get("class", ""))
			if not MELEE.has(held) or held == "lance":
				swing *= 0.4  # a gun stays roughly on target while it runs
			p[_ch(arm, "sh")] += swing
			p[_ch(arm, "el")] += absf(swing) * 0.5
	var air: float = float(_gait["bounce"]) * absf(sin(_phase * 2.0 + PI * 0.5)) * stride
	p[DROP] += drop * stride - air
	p[PITCH] += float(_gait["lean"]) * stride
	# The head nods after the landing (the upper body lags the hips).
	p[T_PITCH] += drop * 0.8 * stride
	return p


## (forward, up) of a foot at cycle position t (0 = it lands): planted and driven back through the
## stance, then a knee-up that rises fast and stamps down accelerating.
static func _foot_step(t: float, reach: float, lift: float) -> Vector2:
	if t < STANCE_FRACTION:
		return Vector2(lerpf(reach, -reach, t / STANCE_FRACTION), 0.0)
	var u: float = (t - STANCE_FRACTION) / (1.0 - STANCE_FRACTION)
	var forward: float = lerpf(-reach, reach, smoothstep(0.0, 0.85, u))
	var up: float = (1.0 - pow(1.0 - u / 0.45, 2.0)) if u < 0.45 else (1.0 - pow((u - 0.45) / 0.55, 2.2))
	return Vector2(forward, lift * up)


func _hip_side(leg: int) -> float:
	if not _legs.is_empty():
		return signf((_legs["l" if leg == 0 else "r"]["hip"] as Transform3D).origin.x)
	var node: Node3D = _leg_l if leg == 0 else _leg_r
	if node != null:
		return signf(node.position.x) if node.position.x != 0.0 else (-1.0 if leg == 0 else 1.0)
	return -1.0 if leg == 0 else 1.0


func _arm_on(side: float) -> String:
	for slot: String in _arms:
		if float((_arms[slot] as Dictionary)["side"]) == side:
			return slot
	return ""


## Standing, a skeleton machine breathes: its upper body shifts a little, slowly, never in step
## with its neighbours.
func _idle_pose() -> PackedFloat32Array:
	var p := PackedFloat32Array()
	p.resize(N_CH)
	if _frame_skel == null:
		return p
	var calm: float = 1.0 - _stride
	var seed: float = float(absi(hash(_body.get_instance_id())) % 1000) * 0.01
	p[T_PITCH] = 0.018 * sin(_clock * 1.6 + seed) * calm
	p[T_TWIST] = 0.02 * sin(_clock * 0.9 + seed * 2.0) * calm
	return p


func _add_shudder(delta: float, pose: PackedFloat32Array) -> void:
	if _shudder <= 0.0:
		return
	_shudder -= delta
	# Stepped at 30 Hz: a machine rattling, not a smooth wobble.
	var tick: int = int(_clock * 30.0)
	var s: float = (1.0 if tick % 2 == 0 else -1.0) * _shudder_amp
	pose[T_ROLL] += s
	pose[T_PITCH] += s * 0.5 * (1.0 if tick % 3 == 0 else -1.0)


# --- Clips -------------------------------------------------------------------------

func _play(layer: String, keys: Array, done: Callable = Callable()) -> void:
	var from := PackedFloat32Array()
	from.resize(N_CH)
	if _layers.has(layer):
		from = _eval(_layers[layer])
	_layers[layer] = {"keys": keys, "time": 0.0, "from": from, "fired": -1, "done": done}


func _advance_layers(delta: float, pose: PackedFloat32Array) -> void:
	for layer: String in _layers.keys():
		var clip: Dictionary = _layers[layer]
		clip["time"] = float(clip["time"]) + delta
		_add(pose, _eval(clip))
		if _clip_over(clip):
			_layers.erase(layer)
			var done: Callable = clip["done"]
			if done.is_valid():
				done.call()


func _clip_over(clip: Dictionary) -> bool:
	var total: float = 0.0
	for key: Array in clip["keys"]:
		total += float(key[0])
	return float(clip["time"]) >= total


## The pose a clip is at now; fires each key's callable once on arrival.
func _eval(clip: Dictionary) -> PackedFloat32Array:
	var keys: Array = clip["keys"]
	var time: float = clip["time"]
	var prev: PackedFloat32Array = clip["from"]
	var start: float = 0.0
	for i: int in keys.size():
		var key: Array = keys[i]
		var length: float = float(key[0])
		var target: PackedFloat32Array = key[1]
		var arrived: bool = time >= start + length
		if arrived and i > int(clip["fired"]):
			clip["fired"] = i
			if key.size() > 3 and key[3] is Callable:
				(key[3] as Callable).call()
		if not arrived:
			var u: float = clampf((time - start) / maxf(length, 0.0001), 0.0, 1.0)
			var w: float = _curve(int(key[2]), u)
			var out := PackedFloat32Array()
			out.resize(N_CH)
			for c: int in N_CH:
				out[c] = lerpf(prev[c], target[c], w)
			return out
		prev = target
		start += length
	return prev


static func _curve(kind: int, u: float) -> float:
	match kind:
		SNAP:
			return 1.0 - pow(1.0 - u, 4.0)
		SMEAR:
			return u * u * u
		BACK:
			var c1: float = 1.9
			var c3: float = c1 + 1.0
			return 1.0 + c3 * pow(u - 1.0, 3.0) + c1 * pow(u - 1.0, 2.0)
		STEP:
			return 0.0 if u < 1.0 else 1.0
	return u * u * (3.0 - 2.0 * u)


# --- Applying a pose -------------------------------------------------------------------

## Puts a pose on the model: body transform (with the springs), upper body (torso bone and the
## sockets it carries), arms, legs.
func _apply(pose: PackedFloat32Array) -> void:
	if _body == null or not is_instance_valid(_body) or pose.size() < N_CH:
		return
	var rigid_upper: bool = _frame_skel == null
	var leg_m: float = _leg_len * _scale
	var offset := Vector3(pose[SWAY] * leg_m, -pose[DROP] * leg_m, pose[SURGE] * leg_m)
	var yaw := Basis(Vector3.UP, _base_yaw)
	var pitch: float = pose[PITCH] + _lean.x + (pose[T_PITCH] * 0.5 if rigid_upper else 0.0)
	var roll: float = pose[ROLL] + _lean.y + (pose[T_ROLL] * 0.5 if rigid_upper else 0.0)
	if not _dead:
		_body.position = _base + (yaw * offset + _recoil).limit_length(RECOIL_LIMIT * maxf(_scale, 1.0))
		_body.rotation.x = pitch
		_body.rotation.z = roll
	_apply_upper(pose)
	_apply_arms(pose)
	_apply_legs(pose)


func _upper_delta(pose: PackedFloat32Array) -> Transform3D:
	var r := Basis(Vector3.UP, pose[T_TWIST]) * Basis(Vector3.RIGHT, pose[T_PITCH]) * Basis(FWD, pose[T_ROLL])
	return Transform3D(r, _torso_pivot - r * _torso_pivot)


func _apply_upper(pose: PackedFloat32Array) -> void:
	if _frame_skel == null or not is_instance_valid(_frame_skel):
		return
	var d: Transform3D = _upper_delta(pose)
	for socket: Node3D in _sockets:
		if is_instance_valid(socket):
			socket.transform = d * (_sockets[socket] as Transform3D)
	var torso: int = _frame_bones.get("torso", -1)
	if torso >= 0:
		var m: Transform3D = _relative(_frame_skel)
		_frame_skel.set_bone_global_pose(torso, m.affine_inverse() * d * m * _torso_rest)


func _apply_arms(pose: PackedFloat32Array) -> void:
	for slot: String in _arms:
		var arm: Dictionary = _arms[slot]
		if not is_instance_valid(arm["node"]):
			continue
		var base: int = SH_L if slot == "arm_l" else SH_R
		var sh: float = pose[base]
		_pose_arm(arm, sh, pose[base + 1], pose[base + 2], pose[base + 3])
		# 060: an arm (a hanging hammer, a limp arm on a kneeling wreck) never goes through the
		# floor: it swings forward onto it instead.
		var guard: Array = arm.get("guard_skin", [])
		var guard_rigid: Array = arm.get("guard_rigid", [])
		if (guard.is_empty() and guard_rigid.is_empty()) or not _body.is_inside_tree():
			continue
		var floor_y: float = _floor_y() + 0.002
		var low: float = _low_of(guard, guard_rigid)
		if low >= floor_y:
			continue
		# Whichever way lifts it (an arm hanging behind the body swings back, one in front forward).
		var step: float = 0.16
		_pose_arm(arm, sh + step, pose[base + 1], pose[base + 2], pose[base + 3])
		if _low_of(guard, guard_rigid) < low:
			step = -step
		for _try: int in 8:
			sh += step
			_pose_arm(arm, sh, pose[base + 1], pose[base + 2], pose[base + 3])
			if _low_of(guard, guard_rigid) >= floor_y:
				break


func _pose_arm(arm: Dictionary, sh: float, el: float, wr: float, fl: float) -> void:
	var node: Node3D = arm["node"]
	var side: float = arm["side"]
	var r_sh := Basis(FWD, side * fl) * Basis(FLEX, sh)
	if not arm.has("skel"):
		# A rigid arm turns whole about its socket: the elbow's share folds into the shoulder.
		var r := Basis(FWD, side * fl) * Basis(FLEX, sh + el * 0.5)
		node.transform = Transform3D(r, Vector3.ZERO) * (arm["rest"] as Transform3D)
		return
	var sk: Skeleton3D = arm["skel"]
	if not is_instance_valid(sk):
		return
	var rests: Array[Transform3D] = arm["rests"]
	var ids: Array[int] = arm["ids"]
	var m_inv: Transform3D = arm["m_inv"]
	var s0: Vector3 = rests[0].origin
	var e0: Vector3 = rests[1].origin
	var w0: Vector3 = rests[2].origin
	var r_el := Basis(r_sh * FLEX, el) * r_sh
	var r_wr := Basis(r_el * FLEX, wr) * r_el
	var e: Vector3 = s0 + r_sh * (e0 - s0)
	var w: Vector3 = e + r_el * (w0 - e0)
	sk.set_bone_global_pose(ids[0], m_inv * Transform3D(r_sh * rests[0].basis, s0))
	sk.set_bone_global_pose(ids[1], m_inv * Transform3D(r_el * rests[1].basis, e))
	sk.set_bone_global_pose(ids[2], m_inv * Transform3D(r_wr * rests[2].basis, w))


func _apply_legs(pose: PackedFloat32Array) -> void:
	if _frame_skel != null and is_instance_valid(_frame_skel) and not _legs.is_empty():
		if _dead and _fall > 0.0:
			# Gone over: the legs keep the shape they had (their LOCAL poses, held).
			if _frozen_legs.is_empty():
				for bone: String in ["hip_l", "knee_l", "ankle_l", "hip_r", "knee_r", "ankle_r"]:
					var b: int = _frame_bones[bone]
					_frozen_legs[b] = [_frame_skel.get_bone_pose_position(b), _frame_skel.get_bone_pose_rotation(b), _lying_pose(bone)]
			# 061: and as it goes over they go slack, so it lies with its legs out along the ground
			# instead of folded up at its chest. 062: brought together and the feet pointed along them
			# (straight, a frame drawn standing wide lay with its legs open and its feet up like flaps).
			var slack: float = smoothstep(0.0, 0.85, _fall / FALL_REST)
			for b: int in _frozen_legs:
				var rest: Transform3D = _frame_skel.get_bone_rest(b)
				_frame_skel.set_bone_pose_position(b, (_frozen_legs[b][0] as Vector3).lerp(rest.origin, slack))
				_frame_skel.set_bone_pose_rotation(b, (_frozen_legs[b][1] as Quaternion).slerp(_frozen_legs[b][2], slack))
			return
		var to_now: Transform3D = _ground_to_skeleton()
		for leg: int in 2:
			var tag: String = "l" if leg == 0 else "r"
			var f: int = LF_F if leg == 0 else RF_F
			var data: Dictionary = _legs[tag]
			var hip: Transform3D = data["hip"]
			var ankle: Transform3D = data["ankle"]
			var length: float = float(data["l1"]) + float(data["l2"])
			var foot: Vector3 = ankle.origin
			var inward: Vector3 = hip.origin - ankle.origin
			inward -= _fwd * inward.dot(_fwd)
			inward.y = 0.0
			var out_dir: Vector3 = -inward.normalized() if inward.length() > 0.001 else Vector3.ZERO
			foot += inward * float(_gait.get("feet_in", FEET_IN))
			foot += _fwd * pose[f] * length + Vector3.UP * maxf(pose[f + 1] * length, 0.0) + out_dir * pose[f + 2] * length
			_solve_leg(tag, to_now * foot, to_now.basis.orthonormalized())
			# 060: nothing of the leg below the floor. A bent knee swings the bottom of the shin
			# (and a tilted body the toe) under the ground: lift the foot by what went under, solve again.
			if not _body.is_inside_tree() or (_leg_guard.get(tag, []) as Array).is_empty():
				continue
			var units: float = maxf(_frame_skel.global_transform.basis.get_scale().y, 0.0001)
			for _try: int in 4:
				var under: float = _floor_y() + 0.004 * _scale - _low_of(_leg_guard[tag], [])
				if under <= 0.001:
					break
				foot.y += under / units
				_solve_leg(tag, to_now * foot, to_now.basis.orthonormalized())
		return
	for leg: int in 2:
		var node: Node3D = _leg_l if leg == 0 else _leg_r
		if node == null or not is_instance_valid(node):
			continue
		var f: int = LF_F if leg == 0 else RF_F
		# A rigid leg turns at the hip toward where its foot is placed (+ rotation.x swings it BACK).
		var swing: float = atan2(pose[f], maxf(1.0 - pose[f + 1], 0.3)) * 1.4
		var fold: float = _buckle * BUCKLE_ANGLE * (1.0 if leg == 0 else 0.72)
		# Knee-up: the free leg is thrown further forward as it lifts.
		node.rotation.x = -(swing + pose[f + 1] * 0.3) + fold
		# 060: a stiff leg cannot bend to crouch, so it SPLAYS: a leg turned out by phi lifts its foot
		# by L(1 - cos phi), which is what the body drops.
		var crouch: float = clampf(pose[DROP], 0.0, 0.5) if not _dead else 0.0
		node.rotation.z = _hip_side(leg) * acos(1.0 - crouch)


## 062: a leg bone's local rotation lying down: the hip turned in until the leg hangs straight under
## it, the knee straight, the foot pointed along the shin.
func _lying_pose(bone: String) -> Quaternion:
	var sk: Skeleton3D = _frame_skel
	var b: int = _frame_bones[bone]
	var tag: String = bone.right(1)
	var rest_local: Quaternion = sk.get_bone_rest(b).basis.get_rotation_quaternion()
	var hip: Transform3D = sk.get_bone_global_rest(_frame_bones["hip_" + tag])
	var ankle: Transform3D = sk.get_bone_global_rest(_frame_bones["ankle_" + tag])
	var m: Basis = _relative(sk).basis.orthonormalized()
	if bone.begins_with("hip"):
		var v: Vector3 = m * (ankle.origin - hip.origin)
		var hip_side: float = signf((m * hip.origin).x)
		var lateral: float = atan2(v.x * hip_side, -v.y)
		var turn := Quaternion((m.inverse() * FWD).normalized(), -hip_side * lateral)
		var parent: int = sk.get_bone_parent(b)
		var parent_global: Quaternion = sk.get_bone_global_rest(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
		return parent_global.inverse() * turn * hip.basis.get_rotation_quaternion()
	if bone.begins_with("ankle"):
		var knee: Transform3D = sk.get_bone_global_rest(_frame_bones["knee_" + tag])
		var point := Quaternion((m.inverse() * Vector3.RIGHT).normalized(), 1.3)
		return knee.basis.get_rotation_quaternion().inverse() * point * ankle.basis.get_rotation_quaternion()
	return rest_local


## The skeleton's frame as it would be with the body standing upright at its base, mapped into the
## skeleton's frame as it is now: feet are placed on the GROUND, whatever the body is doing.
func _ground_to_skeleton() -> Transform3D:
	if not _body.is_inside_tree():
		return Transform3D.IDENTITY
	var parent: Node3D = _body.get_parent() as Node3D
	var parent_global: Transform3D = parent.global_transform if parent != null else Transform3D.IDENTITY
	var upright := Transform3D(Basis.from_euler(Vector3(0.0, _base_yaw, 0.0)).scaled(_body.scale), _base)
	var rel: Transform3D = _relative(_frame_skel)
	return _frame_skel.global_transform.affine_inverse() * parent_global * upright * rel


## Two-bone IK in the plane of hip, foot and forward: the knee bends the way it is drawn.
func _solve_leg(tag: String, foot: Vector3, ground: Basis = Basis.IDENTITY) -> void:
	var leg: Dictionary = _legs[tag]
	var sk: Skeleton3D = _frame_skel
	var hip_rest: Transform3D = leg["hip"]
	var knee_rest: Transform3D = leg["knee"]
	var ankle_rest: Transform3D = leg["ankle"]
	var l1: float = leg["l1"]
	var l2: float = leg["l2"]
	var h: Vector3 = hip_rest.origin
	var to_foot: Vector3 = foot - h
	var d: float = clampf(to_foot.length(), absf(l1 - l2) + 0.001, (l1 + l2) * 0.999)
	var dir: Vector3 = to_foot.normalized()
	foot = h + dir * d
	var along: float = (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var out: float = sqrt(maxf(l1 * l1 - along * along, 0.0))
	var pole: Vector3 = leg["pole"]
	var bend: Vector3 = (pole - dir * pole.dot(dir))
	bend = bend.normalized() if bend.length() > 0.001 else pole
	var knee: Vector3 = h + dir * along + bend * out
	var hip_rot := Quaternion((knee_rest.origin - h).normalized(), (knee - h).normalized())
	var knee_rot := Quaternion((ankle_rest.origin - knee_rest.origin).normalized(), (foot - knee).normalized())
	sk.set_bone_global_pose(_frame_bones["hip_" + tag], Transform3D(Basis(hip_rot) * hip_rest.basis, h))
	sk.set_bone_global_pose(_frame_bones["knee_" + tag], Transform3D(Basis(knee_rot) * knee_rest.basis, knee))
	# The foot stays flat on the GROUND, not square to a body that leans (its toe went under).
	sk.set_bone_global_pose(_frame_bones["ankle_" + tag], Transform3D(ground * ankle_rest.basis, foot))


# --- Death ---------------------------------------------------------------------------

func _advance_death(delta: float) -> void:
	_death_clock += delta
	var pose: PackedFloat32Array = _rest_pose()
	var playing: bool = _layers.has("death")
	_advance_layers(delta, pose)
	if not playing:
		# The last key held.
		_add(pose, _death_hold if _death_hold.size() == N_CH else _limp_kneel())
	_pose = pose
	_advance_loose(delta)
	if _death_clock >= _stand_time:
		if _fall == 0.0 and _fall_velocity == 0.0:
			# It goes over the edge of where it is NOW (a kneeling machine's shins reach back past
			# its standing footprint), so nothing swings into the floor as it tips.
			_pivot = _fall_dir * _reach_now(_fall_dir)
		if _landed == 0 or (_fall < FALL_REST - 0.002 and _fall_velocity > 0.0):
			_fall_velocity += FALL_GRAVITY * delta
			_fall = minf(_fall + _fall_velocity * delta, FALL_REST)
			if _fall >= FALL_REST:
				_fall_velocity = -_fall_velocity * FALL_BOUNCE
				# A bounce too small to see is no bounce: it lies still (it used to rattle forever).
				if absf(_fall_velocity) < 0.3:
					_fall_velocity = 0.0
				_recoil_velocity.y -= 0.6 if _landed == 0 else 0.0
				_landed += 1
				# The landing rattles it, and the arms flop.
				if _landed == 1:
					_shudder = 0.16
					_shudder_amp = 0.06
					# The core rolls out of its chest; the last arm comes loose.
					_break_part("part_core", _fall_dir * 0.4 + Vector3(0, 0, 0.6), 0.9)
					for slot: String in _arms.keys():
						_break_arm(slot, _fall_dir * 0.3)
		else:
			_fall_velocity += -(_fall - FALL_REST) * 90.0 * delta
			_fall_velocity *= 1.0 - minf(1.0, 9.0 * delta)
			_fall = clampf(_fall + _fall_velocity * delta, FALL_REST - 0.12, FALL_REST)
			if _fall >= FALL_REST and _fall_velocity > 0.0:
				_fall_velocity = -_fall_velocity * FALL_BOUNCE
		_buckle = move_toward(_buckle, 1.0, delta * 3.2)
	else:
		_buckle = move_toward(_buckle, 0.6, delta * 1.5) if _death_clock > _stand_time * 0.7 else _buckle
	_add_shudder(delta, pose)
	# 062: going over, the upper body unbends (a torso still bowed over its knees held the wreck
	# 30 degrees off the floor) and the arms lie out: it ends FLAT.
	var flat: float = smoothstep(0.0, 0.9, _fall / FALL_REST)
	for ch: int in [T_PITCH, T_TWIST, T_ROLL]:
		pose[ch] *= 1.0 - flat
	# Body first (kneel height, toppled about the footprint's edge), then the pose on it (the feet
	# are placed against the body as it is THIS frame), then kept above the floor.
	var leg_m: float = _leg_len * _scale
	var yaw := Basis(Vector3.UP, _base_yaw)
	var topple := Basis(_fall_axis, _fall)
	var upright: float = 1.0 - clampf(_fall / FALL_REST, 0.0, 1.0)
	var lean := Basis(Vector3.RIGHT, pose[PITCH] * upright) * Basis(FWD, pose[ROLL] * upright)
	_body.transform.basis = (yaw * topple * lean).scaled(Vector3.ONE * _scale)
	var hinge: Vector3 = yaw * (_pivot - topple * _pivot) * _scale
	var kneel_drop: float = maxf(pose[DROP] * leg_m - _kneel_lift, 0.0) * cos(_fall)
	var offset := Vector3(pose[SWAY] * leg_m * upright, -kneel_drop, pose[SURGE] * leg_m * upright)
	var sink: float = -WRECK_SINK * _scale * (1.0 - upright)
	_body.position = _base + hinge + yaw * offset + Vector3(_recoil.x, _recoil.y + sink, _recoil.z)
	_apply(pose)
	_keep_above_floor()


func _limp_kneel() -> PackedFloat32Array:
	var p: PackedFloat32Array = _limp()
	p[DROP] = 0.30
	p[T_PITCH] = 0.45
	p[PITCH] = 0.05
	return p


## Lifts a lying (or kneeling) wreck so no bone, socket or top corner of its body is below the
## floor -- whatever pose the generated frame was drawn in.
func _keep_above_floor() -> void:
	if not _body.is_inside_tree():
		return
	var parent: Node3D = _body.get_parent() as Node3D
	var floor_y: float = (parent.global_position.y if parent != null else 0.0) + _base.y
	_refresh_skeletons()
	var lowest: float = lowest_point()
	if lowest == INF:
		for p: Vector3 in _probe_points():
			lowest = minf(lowest, p.y)
	if lowest == INF:
		return
	if _fall <= 0.0:
		# Kneeling, the feet are on the floor (the IK holds them); if the chest bows into the ground
		# (a short frame folding forward), it kneels less deep, settled over the next frames.
		_kneel_lift = maxf(0.0, _kneel_lift + floor_y + 0.004 * _scale - lowest)
		return
	var need: float = floor_y + 0.004 * _scale - lowest
	if _fall >= FALL_REST - 0.05:
		# 062: lying, it rests exactly ON the floor -- lifted or lowered (it hovered face-down).
		_lift = need if need > _lift else move_toward(_lift, need, 1.2 * (1.0 / 30.0))
	else:
		# Rises at once, lets go slowly (a bounce does not leave the wreck hovering).
		_lift = maxf(need, maxf(_lift - 1.5 * (1.0 / 60.0), 0.0))
	_body.global_position.y += _lift
	# 062: and it lies over its own hex: as it goes over, its middle slides back toward the hex's
	# middle (lying full length from the edge of its feet, half of it was on the next hex).
	if parent != null:
		var mid := Vector3.ZERO
		var n: int = 0
		for entry: Array in _skin_points:
			var sk: Skeleton3D = entry[0]
			mid += (sk.global_transform * sk.get_bone_global_pose(int(entry[1]))).origin
			n += 1
		if n > 0:
			mid /= float(n)
			var off := Vector2(mid.x - parent.global_position.x, mid.z - parent.global_position.z)
			_slide += off * -0.15 * smoothstep(0.2, 1.0, _fall / FALL_REST)
		_body.global_position += Vector3(_slide.x, 0.0, _slide.y)


func _probe_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	for sk: Skeleton3D in [_frame_skel]:
		if sk != null and is_instance_valid(sk):
			for b: int in sk.get_bone_count():
				out.append(sk.global_transform * sk.get_bone_global_pose(b).origin)
	for arm: Dictionary in _arms.values():
		if arm.has("skel") and is_instance_valid(arm["skel"]):
			var sk: Skeleton3D = arm["skel"]
			for b: int in sk.get_bone_count():
				out.append(sk.global_transform * sk.get_bone_global_pose(b).origin)
	for socket: Node3D in _sockets:
		if is_instance_valid(socket):
			out.append(socket.global_position)
	if _chassis != null and is_instance_valid(_chassis) and not _probe_top.is_empty():
		var d: Transform3D = _upper_delta(_pose) if _frame_skel != null else Transform3D.IDENTITY
		var g: Transform3D = _chassis.global_transform * d
		for p: Vector3 in _probe_top:
			out.append(g * p)
	return out


# --- Springs ---------------------------------------------------------------------------

func _advance_reactions(delta: float) -> void:
	const STEP_S: float = 1.0 / REACT_HZ
	_react_clock = minf(_react_clock + delta, STEP_S * float(MAX_SUBSTEPS))
	while _react_clock >= STEP_S:
		_react_clock -= STEP_S
		_substep(STEP_S)


## Semi-implicit Euler: velocity first, then position from the NEW velocity.
func _substep(step: float) -> void:
	_recoil_velocity += (-_recoil * REACT_STIFFNESS - _recoil_velocity * REACT_DAMPING) * step
	_recoil = (_recoil + _recoil_velocity * step).limit_length(RECOIL_LIMIT)
	_lean_velocity += (-_lean * LEAN_STIFFNESS - _lean_velocity * LEAN_DAMPING) * step
	_lean = (_lean + _lean_velocity * step).limit_length(LEAN_LIMIT)


# --- Nodes ------------------------------------------------------------------------------

static func _skeleton_in(node: Node, bone: String) -> Skeleton3D:
	if node == null:
		return null
	if node is Skeleton3D and (node as Skeleton3D).find_bone(bone) >= 0:
		return node
	for child: Node in node.get_children():
		var found: Skeleton3D = _skeleton_in(child, bone)
		if found != null:
			return found
	return null


## `node`'s transform in the body's own frame.
func _relative(node: Node3D) -> Transform3D:
	return _relative_to(node, _body)


static func _relative_to(node: Node3D, ancestor: Node) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != ancestor:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


static func _find(node: Node, name: String) -> Node3D:
	if node.name == name and node is Node3D:
		return node as Node3D
	for child: Node in node.get_children():
		var found: Node3D = _find(child, name)
		if found != null:
			return found
	return null


static func _first_child_of(node: Node3D) -> Node3D:
	if node == null:
		return null
	for child: Node in node.get_children():
		if child is Node3D:
			return child as Node3D
	return null
