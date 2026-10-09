class_name ConstructRig
extends RefCounted

## Animates one assembled construct: legs that walk, arms that strike, a body that
## reacts to being hit.
##
## The chassis `.glb` exports its two legs as child objects named `limb_leg_l` and
## `limb_leg_r`, each with its ORIGIN on the hip joint (see `set_origin` in
## `make_parts.py`). Rotating those objects therefore rotates the hip, and a walk cycle
## is two opposed curves rather than a skinned armature -- which suits a roster that
## is generated rather than authored, because a new chassis needs no rigging pass.
##
## Nothing here computes an outcome. The rig is told "this unit is moving", "this unit
## just struck" and "this unit was hit from over there"; it never decides any of them.
## That is the same presentation boundary the event stream draws, and it is what keeps
## skip-animation and server verification free.
##
## **Attack shape comes from `weapon_class`**, the same field in `data/parts/arms.json`
## that picks the weapon's model. A hammer winds up and slams, a lance thrusts, a railgun
## recoils, a scanner sweeps. Ten arms that all played one generic jab was the reason a
## mixed loadout felt identical to fight with no matter what the player had equipped.
##
## ## Two kinds of motion, and why they are built differently
##
## The walk is a FUNCTION OF PHASE: given a stride phase, every limb angle follows. It
## is cyclic, it never ends, and it must be interruptible at any instant.
##
## Reactions -- recoil from a hit, kick from firing, the weight of a footfall -- are a
## SPRING-DAMPER integrated in `update`. Not tweens, and that is deliberate:
##
## * They compose. Three hits in one tick add three impulses to the same spring and
##   produce one bigger lurch. Three tweens fight over the same property and the last
##   one wins, so a construct hit by a whole squad reacts exactly as much as one hit.
## * They cannot freeze. Playback stops dead when the Order Phase opens, and a tween
##   caught mid-flight leaves a machine leaning at 20 degrees for as long as the player
##   takes to think -- the same failure that made `BattleVFX.clear_transients` necessary.
##   A spring is always heading home, and `reset_transients` snaps it there.
## * They are honest about weight. A heavy construct shoved by a light hit should barely
##   move, and severity scaling a single impulse gives that for free.

## Radians of hip swing at a full stride.
const STRIDE_SWING: float = 0.62
## Strides per second at normal speed.
const STRIDE_RATE: float = 2.35
## How fast the legs settle back to neutral once a construct stops.
const SETTLE: float = 6.0
## Vertical bob at full stride, in metres. Small on purpose -- a construct that bounces
## reads as light, and these are supposed to be heavy.
const BOB: float = 0.035

## Fraction of each leg's cycle spent PLANTED.
##
## Above a half, which is what makes it a walk rather than a run: both feet are on the
## ground for part of the cycle. A pure sine spends exactly half the cycle on each side
## and reads as marching in place, because the foot is never still relative to the
## ground while the body passes over it.
const STANCE_FRACTION: float = 0.62

## Body lean into travel, radians at full stride.
const WALK_LEAN: float = 0.055
## Lateral roll, radians. Weight shifting onto each foot in turn -- the strongest
## realism cue available on legs that cannot bend at the knee.
const WALK_ROLL: float = 0.045
## Downward impulse when a foot lands, in metres per second.
const FOOTFALL: float = 0.30

## Spring constants for every reaction.
##
## Just under critical damping (critical is `2 * sqrt(stiffness)`), so a hit produces
## one clean lurch and a small settle rather than a wobble. These are machines; anything
## that oscillates visibly reads as rubber.
##
## The stiffness came DOWN from 210 after measuring what it actually produced: a
## full-severity hit peaked at 3.5 cm of travel, which on a 1.1 m construct seen from
## the battle camera is about two pixels. It was correct, stable, well-damped, and
## invisible -- the easiest kind of animation bug to ship, because every test passes and
## the still frames look like the machine is standing still because it very nearly is.
const REACT_STIFFNESS: float = 120.0
const REACT_DAMPING: float = 17.0
const LEAN_STIFFNESS: float = 105.0
const LEAN_DAMPING: float = 14.5

## Reactions integrate at a FIXED rate, whatever the display is doing.
##
## With a spring stepped once per frame, damping is applied once per frame too, so the
## same hit produced 3.5 cm of travel at 60 fps, 1.8 cm at 30 and 0.4 cm at 15 -- the
## reaction quietly disappearing on exactly the hardware least able to spare the frames.
## An animation that depends on frame rate is one that has not been designed, and this
## ships on phones.
const REACT_HZ: float = 120.0
## Never run more than this many substeps in one frame. A hitch or a debugger pause
## must not turn into a hundred steps of catch-up in a single frame.
const MAX_SUBSTEPS: int = 8
## Hard caps, so a unit hit by everything at once lurches hard instead of leaving the
## battlefield. Reached only by an overkill volley.
const RECOIL_LIMIT: float = 0.32
const LEAN_LIMIT: float = 0.42

## How hard a hit shoves the body, in metres per second at full severity.
## Tuned against the MEASURED peak travel, not by eye: this puts a heavy hit at roughly
## 13 cm, which is a tenth of a construct's height and reads clearly at battle distance.
const STAGGER_KICK: float = 4.2
## ...and how hard it tips it, in radians per second.
const STAGGER_TIP: float = 6.4
## A stagger interrupts the walk. This is how long the hitch lasts, in seconds.
const HITCH_TIME: float = 0.34

## --- Death -------------------------------------------------------------------
##
## A wreck TOPPLES. It used to squash to 5% of its height on the spot, which reads
## clearly as "this unit is gone" and reads as nothing physical whatsoever -- twelve
## machines a battle each ending as a pancake where it stood. A construct is a heavy
## thing balanced on two legs; when it stops working it falls over.
##
## The fall is angular, about the feet, and that one choice is what makes it cheap: the
## body's origin already sits at ground level, so rotating it is a felled tree for free
## -- nothing has to be moved, and it cannot sink through the floor on the way down.

## Angular acceleration of the topple, radians/s². Not real gravity: a construct
## pivoting about its ankles takes roughly 1.4 s to reach the ground, which is far too
## long to sit through twelve times in a battle.
const FALL_GRAVITY: float = 11.0
## The knees give first, so it drops before it tips. This is the difference between a
## machine losing power and a statue being pushed over.
const FALL_KICK: float = 1.15
## Flat, and slightly past 90° so it settles ONTO its side instead of balancing on edge.
const FALL_REST: float = PI * 0.52
## How much of the impact comes back. Heavy, and mostly inelastic.
const FALL_BOUNCE: float = 0.16
## How far the legs fold on the way down.
const BUCKLE_ANGLE: float = 0.95
## How far a wreck settles into the ground once it has landed, in metres. Small: enough
## that the field reads as littered rather than as a pile of intact machines.
const WRECK_SINK: float = 0.12

var _body: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D

var _phase: float = 0.0
## 0 = standing, 1 = full stride. Eased rather than switched, so a construct does not
## snap from a dead stand into a full walk on the frame its order resolves.
var _stride: float = 0.0
var _moving: bool = false
var _base: Vector3 = Vector3.ZERO
## Set while an attack tween owns an arm, so the walk cycle does not fight it.
var _striking: Dictionary = {}

## Reaction state: local-space offset and the tilt that goes with it.
var _recoil: Vector3 = Vector3.ZERO
var _recoil_velocity: Vector3 = Vector3.ZERO
## x = pitch (nose up/down), y = roll (side to side).
var _lean: Vector2 = Vector2.ZERO
var _lean_velocity: Vector2 = Vector2.ZERO
## Both legs brace together when shoved -- a stumble step rather than a stride.
var _brace: float = 0.0
var _brace_velocity: float = 0.0
## Counts down after a hit; suppresses the stride while it does.
var _hitch: float = 0.0
## Unspent time owed to the fixed-rate reaction integrator.
var _react_clock: float = 0.0

## Death. Once set, the walk stops driving anything and the fall owns the body.
var _dead: bool = false
## Radians fallen, 0 upright to FALL_REST flat.
var _fall: float = 0.0
var _fall_velocity: float = 0.0
## The axis the construct topples about, in its own space.
var _fall_axis: Vector3 = Vector3.RIGHT
## The model's own yaw at bind. A toppling basis is built around it rather than over it.
var _base_yaw: float = 0.0
## How far the legs have folded, 0..1.
var _buckle: float = 0.0
## 056: the edge of the footprint the wreck tips over, in its own space. Toppling about the
## middle of the feet put half of every wreck below the floor.
var _pivot: Vector3 = Vector3.ZERO
## Which half-stride the last footfall landed on, so each landing fires once.
var _last_footfall: int = -1

# --- 056: skeletons ------------------------------------------------------------
# A generated part carries a Skeleton3D with STANDARD bone names (frame: torso, hip/knee/ankle
# _l/_r; arm: shoulder, elbow, wrist), so these motions drive any part of its slot. Every
# bone's local X is the machine's lateral axis: a positive turn swings the limb forward.
## 057: a skeleton frame walks by IK -- each foot is PLACED (on the ground in stance, lifted on
## an arc in swing) and the hip and knee are solved to reach it, so a foot can never go under the
## floor and the knees always bend forward. Distances are shares of the leg's length.
const STEP_REACH: float = 0.22
const STEP_LIFT: float = 0.16
## Feet are drawn in under the hips by this share of their sideways offset (the Brute's model
## stands wide; walking that wide read as bow-legged).
const FEET_IN: float = 0.15
## The body dips as each leg passes under it (a heavy machine sinks into its stride).
const STEP_DIP: float = 0.05
## Death (058): a machine that stops slumps -- knees give, the hips drop (this share of the leg),
## the torso folds forward onto them, the arms hang. The feet stay planted on the floor.
const KNEEL_DROP: float = 0.45
const KNEEL_TIME: float = 0.55
const SLUMP_PITCH: float = 0.55
## Weapons swung by hand hang at the side, weapon low; everything else is held up and aimed.
const MELEE: PackedStringArray = ["hammer", "maul", "saw", "ripper"]
## Where the forearm points at rest, as a pitch below horizontal-forward (radians): a hand weapon
## hangs nearly straight down, a gun is held level and a touch low. The elbow angle that gets
## there is worked out per arm from its own drawn pose (`_forearm_turn`), because generated arms
## come in whatever pose their concept had.
const PITCH_MELEE: float = 1.3
const PITCH_AIM: float = 0.12
var _frame_skel: Skeleton3D
var _frame_bones: Dictionary = {}
## Per leg (l/r): rest globals in skeleton space, lengths, and the walk's forward/up.
var _legs: Dictionary = {}
var _fwd: Vector3 = Vector3.FORWARD
var _kneel: float = 0.0
var _dip: float = 0.0
## slot -> [Skeleton3D, {bone: index}]
var _arm_skel: Dictionary = {}
## slot -> rest pose (Vector3), and the strike's offset on top of it
var _stance: Dictionary = {}
var _arm_offset: Dictionary = {}


## Binds to an assembled model. Missing limbs are fine -- a fallback body or a chassis
## generated before the split still animates, it just does not walk.
func bind(model: Node3D) -> void:
	_body = model
	# All three axes, because reactions displace the body sideways and forward as well
	# as vertically. Recording only Y was fine while the rig could not push.
	_base = model.position
	_base_yaw = model.rotation.y
	_leg_l = _find(model, "limb_leg_l")
	_leg_r = _find(model, "limb_leg_r")
	_arm_l = _first_child_of(_find(model, "socket_arm_l"))
	_arm_r = _first_child_of(_find(model, "socket_arm_r"))
	_frame_skel = null
	_frame_bones = {}
	_arm_skel = {}
	var chassis: Node = _find(model, "part_chassis")
	var frame: Skeleton3D = _skeleton_in(chassis if chassis != null else model, "hip_l")
	if frame != null:
		_frame_skel = frame
		for bone: String in ["torso", "hip_l", "knee_l", "ankle_l", "hip_r", "knee_r", "ankle_r"]:
			_frame_bones[bone] = frame.find_bone(bone)
		_legs = {}
		# Forward is the MACHINE's (-Z of the body, the way it faces in a fight), carried into the
		# skeleton's space -- toe-guessing pointed Relay backwards.
		var skel_rel: Transform3D = _relative(frame)
		_fwd = (skel_rel.basis.inverse() * Vector3(0, 0, -1))
		_fwd.y = 0.0
		_fwd = _fwd.normalized()
		for tag: String in ["l", "r"]:
			var h: Transform3D = frame.get_bone_global_rest(_frame_bones["hip_" + tag])
			var k: Transform3D = frame.get_bone_global_rest(_frame_bones["knee_" + tag])
			var a: Transform3D = frame.get_bone_global_rest(_frame_bones["ankle_" + tag])
			# Which way this knee bends, as drawn: forward (a person) or back (a bird's leg).
			var line: Vector3 = (a.origin - h.origin).normalized()
			var off: Vector3 = (k.origin - h.origin) - line * (k.origin - h.origin).dot(line)
			var side: float = -1.0 if off.dot(_fwd) < -0.005 else 1.0
			_legs[tag] = {"hip": h, "knee": k, "ankle": a, "side": side,
				"l1": (k.origin - h.origin).length(), "l2": (a.origin - k.origin).length()}
	for slot: String in ["arm_l", "arm_r"]:
		var arm: Node3D = _arm_l if slot == "arm_l" else _arm_r
		var sk: Skeleton3D = _skeleton_in(arm, "shoulder") if arm != null else null
		if sk != null:
			_arm_skel[slot] = [sk, {"shoulder": sk.find_bone("shoulder"), "elbow": sk.find_bone("elbow"), "wrist": sk.find_bone("wrist")}]
			_stance[slot] = Vector3(0.0, _forearm_turn(slot, PITCH_AIM), 0.0)
			_arm_offset[slot] = Vector3.ZERO
	_pose_arms()
	if _frame_skel != null:
		_walk_legs(Vector2.ZERO, Vector2.ZERO, 0.0)


## The rest pose of each arm from its weapon: hand weapons hang at the side, guns are held up and
## aimed (the user, 055). `classes` is [arm_l class, arm_r class].
func set_stances(classes: PackedStringArray) -> void:
	for i: int in mini(classes.size(), 2):
		var slot: String = "arm_l" if i == 0 else "arm_r"
		if _arm_skel.has(slot):
			_stance[slot] = Vector3(0.0, _forearm_turn(slot, PITCH_MELEE if MELEE.has(classes[i]) else PITCH_AIM), 0.0)
	_pose_arms()


## The elbow turn that points this arm's forearm `pitch` below level-forward. Measured on the
## skeleton's rest: the forearm is elbow -> wrist, "forward" is the side the arm reaches to.
## A turn about the lateral X axis by t moves an angle atan2(z, y) by +t.
func _forearm_turn(slot: String, pitch: float) -> float:
	var sk: Skeleton3D = _arm_skel[slot][0]
	var ids: Dictionary = _arm_skel[slot][1]
	if ids["elbow"] < 0 or ids["wrist"] < 0:
		return 0.0
	var shoulder: Vector3 = sk.get_bone_global_rest(ids["shoulder"]).origin
	var elbow: Vector3 = sk.get_bone_global_rest(ids["elbow"]).origin
	var wrist: Vector3 = sk.get_bone_global_rest(ids["wrist"]).origin
	var forearm: Vector3 = wrist - elbow
	var forward: float = signf(wrist.z - shoulder.z) if absf(wrist.z - shoulder.z) > 0.001 else 1.0
	var target := Vector3(0.0, -sin(pitch), cos(pitch) * forward)
	return wrapf(atan2(target.z, target.y) - atan2(forearm.z, forearm.y), -PI, PI)


func has_skeleton() -> bool:
	return _frame_skel != null or not _arm_skel.is_empty()


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


static func _turn(sk: Skeleton3D, bone: int, angle: float) -> void:
	if bone < 0:
		return
	sk.set_bone_pose_rotation(bone, sk.get_bone_rest(bone).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, angle))


func _pose_arms() -> void:
	for slot: String in _arm_skel:
		var sk: Skeleton3D = _arm_skel[slot][0]
		if not is_instance_valid(sk):
			continue
		var ids: Dictionary = _arm_skel[slot][1]
		var a: Vector3 = (_stance.get(slot, Vector3.ZERO) as Vector3) + (_arm_offset.get(slot, Vector3.ZERO) as Vector3)
		_turn(sk, ids["shoulder"], a.x)
		_turn(sk, ids["elbow"], a.y)
		_turn(sk, ids["wrist"], a.z)


func _pose_legs(_hip_l: float, _hip_r: float, _knee_l: float, _knee_r: float) -> void:
	pass


## Where a foot is in its cycle: (forward, lift) as shares of the leg. Stance (the first
## STANCE_FRACTION) slides it back along the floor; swing carries it forward on an arc.
static func _foot_step(phase: float) -> Vector2:
	var t: float = fposmod(phase / TAU, 1.0)
	if t < STANCE_FRACTION:
		return Vector2(lerpf(STEP_REACH, -STEP_REACH, t / STANCE_FRACTION), 0.0)
	var u: float = (t - STANCE_FRACTION) / (1.0 - STANCE_FRACTION)
	return Vector2(lerpf(-STEP_REACH, STEP_REACH, smoothstep(0.0, 1.0, u)), STEP_LIFT * sin(PI * u))


func _leg_length() -> float:
	if _legs.is_empty():
		return 0.0
	return float(_legs["l"]["l1"]) + float(_legs["l"]["l2"])


## 057: places each foot and solves its leg. `step` per leg is (forward share, lift share) of the
## leg's length; `drop` is how far the BODY has been lowered (skeleton units): the feet are raised
## by it in the skeleton's space, so they stay planted on the floor.
func _walk_legs(step_l: Vector2, step_r: Vector2, _drop: float = 0.0) -> void:
	if _frame_skel == null or not is_instance_valid(_frame_skel) or _legs.is_empty():
		return
	# 058: feet are placed in the GROUND's frame (the machine standing upright where it stands) and
	# carried into the skeleton as it is now -- leaning, recoiling, dipping, kneeling -- so a foot
	# never follows the body under the floor.
	var to_now: Transform3D = _ground_to_skeleton()
	for tag: String in ["l", "r"]:
		var leg: Dictionary = _legs[tag]
		var hip: Transform3D = leg["hip"]
		var ankle: Transform3D = leg["ankle"]
		var length: float = float(leg["l1"]) + float(leg["l2"])
		var step: Vector2 = step_l if tag == "l" else step_r
		var foot: Vector3 = ankle.origin
		var inward: Vector3 = hip.origin - ankle.origin
		inward -= _fwd * inward.dot(_fwd)
		inward.y = 0.0
		foot += inward * FEET_IN
		foot += _fwd * step.x * length + Vector3.UP * maxf(step.y * length, 0.0)
		_solve_leg(tag, to_now * foot)


## The skeleton's frame as it would be with the body standing upright at its base (no lean, no
## recoil, no dip), mapped into the skeleton's frame as it is now.
func _ground_to_skeleton() -> Transform3D:
	if not _body.is_inside_tree():
		return Transform3D.IDENTITY
	var parent: Node3D = _body.get_parent() as Node3D
	var parent_global: Transform3D = parent.global_transform if parent != null else Transform3D.IDENTITY
	var upright := Transform3D(Basis.from_euler(Vector3(0.0, _base_yaw, 0.0)).scaled(_body.scale), _base)
	var rel: Transform3D = _relative(_frame_skel)
	return _frame_skel.global_transform.affine_inverse() * parent_global * upright * rel


## `node`'s transform in the body's own frame.
func _relative(node: Node3D) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != _body:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


## Two-bone IK in the plane of hip, foot and the walk's forward: the knee always bends FORWARD.
## Each bone keeps its rest orientation turned by the shortest arc onto its new direction; the
## foot keeps its rest orientation (flat on the floor).
func _solve_leg(tag: String, foot: Vector3) -> void:
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
	# Knee: the law of cosines, bent toward the forward side of the hip-foot line.
	var along: float = (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var out: float = sqrt(maxf(l1 * l1 - along * along, 0.0))
	var pole: Vector3 = _fwd * float(leg["side"])
	var bend: Vector3 = (pole - dir * pole.dot(dir))
	bend = bend.normalized() if bend.length() > 0.001 else pole
	var knee: Vector3 = h + dir * along + bend * out
	var hip_rot := Quaternion((knee_rest.origin - h).normalized(), (knee - h).normalized())
	var knee_rot := Quaternion((ankle_rest.origin - knee_rest.origin).normalized(), (foot - knee).normalized())
	sk.set_bone_global_pose(_frame_bones["hip_" + tag], Transform3D(Basis(hip_rot) * hip_rest.basis, h))
	sk.set_bone_global_pose(_frame_bones["knee_" + tag], Transform3D(Basis(knee_rot) * knee_rest.basis, knee))
	sk.set_bone_global_pose(_frame_bones["ankle_" + tag], Transform3D(ankle_rest.basis, foot))



func set_moving(moving: bool) -> void:
	_moving = moving


## Drives the walk cycle and settles every reaction. `speed_scale` lets a fast chassis
## take quicker strides than a heavy one, so movement speed reads on the model and not
## only on the position.
func update(delta: float, speed_scale: float = 1.0) -> void:
	if _body == null or not is_instance_valid(_body):
		return

	if _dead:
		_advance_fall(delta)
		return

	_advance_reactions(delta)

	# A construct that has just been shoved does not keep walking through it.
	_hitch = maxf(0.0, _hitch - delta)
	var hitched: float = 1.0 - clampf(_hitch / HITCH_TIME, 0.0, 1.0)

	var target: float = 1.0 if _moving else 0.0
	_stride = move_toward(_stride, target, delta * SETTLE)
	if _stride <= 0.001 and not _moving:
		_phase = 0.0
		_last_footfall = -1
	var stride: float = _stride * hitched

	_phase += delta * STRIDE_RATE * TAU * clampf(speed_scale, 0.5, 1.8) * stride
	_emit_footfalls(stride)

	# Opposed gait curves rather than opposed sines: the planted leg rotates steadily
	# while the body passes over it, then the free leg swings through quickly.
	var swing_l: float = _gait(_phase) * STRIDE_SWING * stride
	var swing_r: float = _gait(_phase + PI) * STRIDE_SWING * stride

	if _leg_l != null and is_instance_valid(_leg_l):
		_leg_l.rotation.x = swing_l + _brace
	if _leg_r != null and is_instance_valid(_leg_r):
		_leg_r.rotation.x = swing_r + _brace
	# 057: a skeleton frame places its feet (stance on the floor, swing on an arc) and solves the
	# legs; the hips dip as each leg passes under.
	if _frame_skel != null:
		_dip = STEP_DIP * stride * absf(sin(_phase)) * _leg_length()
		_walk_legs(_foot_step(_phase) * stride, _foot_step(_phase + PI) * stride)

	# Two bobs per stride: the body rises as each leg passes under it. (A skeleton frame sinks into
	# its legs instead, above -- lifting its body lifted its feet off the floor.)
	var bob: float = 0.0 if _frame_skel != null else absf(sin(_phase)) * BOB * stride
	_body.position = _base + Vector3(_recoil.x, bob - _dip * _body.scale.y + _recoil.y, _recoil.z)

	# Lean into the walk, and roll onto whichever foot is carrying. Only x and z are
	# touched -- y is the unit's FACING, owned by the battle scene, and writing it here
	# would make a construct turn away from whatever it is shooting at.
	_body.rotation.x = _lean.x + WALK_LEAN * stride
	_body.rotation.z = _lean.y + sin(_phase) * WALK_ROLL * stride

	# Arms counter-swing at half amplitude, and only while not mid-attack.
	var counter: float = -swing_l * 0.35
	if _arm_l != null and is_instance_valid(_arm_l) and not _striking.has("arm_l"):
		_arm_l.rotation.x = counter
	if _arm_r != null and is_instance_valid(_arm_r) and not _striking.has("arm_r"):
		_arm_r.rotation.x = -counter
	_pose_arms()


## A hit landing. `direction` is the push, in the CONSTRUCT'S OWN space: +Z is shoved
## backwards, +X is shoved to its right. `severity` is 0..1, already scaled by the
## caller against the target's health -- the rig must not know what a hit point is.
##
## Impulses ADD. Six units focusing one target in a single tick produce one heavy lurch
## instead of six competing animations, which is the whole reason this is a spring.
func stagger(direction: Vector3, severity: float) -> void:
	if _body == null or not is_instance_valid(_body):
		return
	var force: float = clampf(severity, 0.0, 1.0)
	if force <= 0.0:
		return
	var push: Vector3 = direction
	push.y = 0.0
	if push.length_squared() < 0.000001:
		push = Vector3(0.0, 0.0, 1.0)
	push = push.normalized()

	_recoil_velocity += push * STAGGER_KICK * force
	# Tipping follows the push: shoved backwards, the top goes backwards too. Positive
	# rotation.x carries the top toward +Z; positive rotation.z carries it toward -X,
	# hence the sign flip on roll.
	_lean_velocity += Vector2(push.z, -push.x) * STAGGER_TIP * force
	# Legs jolt the other way, as if catching the weight.
	_brace_velocity -= push.z * 2.4 * force
	_hitch = maxf(_hitch, HITCH_TIME * force)


## Plays the strike for one arm. `weapon_class` picks the shape of the motion; anything
## unrecognised falls back to a short recoil rather than to nothing, so a new weapon
## class is never silently inert.
##
## The arm's motion is a tween because it is a one-shot pose sequence with authored
## timing. The BODY's part is a spring impulse, so that firing and being shot share one
## mechanism -- a railgun shoving its own construct backwards is the same event, to the
## body, as being hit from the front.
func strike(slot: String, weapon_class: String, tree: SceneTree) -> void:
	var arm: Node3D = _arm_l if slot == "arm_l" else _arm_r
	if arm == null or not is_instance_valid(arm) or tree == null:
		return
	if _striking.has(slot):
		return
	_striking[slot] = true

	# 057: a skeleton arm plays a staged strike: anticipation, a held impact, recovery, with the
	# body in it -- the quick whole-arm flicks below were too small to read (the user).
	if _arm_skel.has(slot):
		_strike_skeleton(slot, arm, weapon_class, tree)
		return

	_body_recoil(weapon_class)

	var rest: Vector3 = Vector3.ZERO
	var rest_pos: Vector3 = arm.position
	var tween: Tween = tree.create_tween()

	# 056: a skeleton arm never slides out of its shoulder: guns kick back through the shoulder
	# and elbow (below) instead of the whole arm travelling along its length.
	match weapon_class:
		"hammer", "maul":
			# Wind up and slam. The wind-up is the tell: it is longer than the strike,
			# which is what makes a heavy hit feel heavy rather than merely large.
			tween.tween_property(arm, "rotation:x", -1.15, 0.22).set_ease(Tween.EASE_OUT)
			tween.tween_property(arm, "rotation:x", 0.75, 0.09).set_ease(Tween.EASE_IN)
			tween.tween_property(arm, "rotation:x", rest.x, 0.26).set_ease(Tween.EASE_OUT)
		"ripper", "saw":
			# Fast repeated bites rather than one swing -- these are the weapons whose
			# ability text says they hit repeatedly.
			for _i: int in 3:
				tween.tween_property(arm, "rotation:x", -0.42, 0.06)
				tween.tween_property(arm, "rotation:x", 0.30, 0.06)
			tween.tween_property(arm, "rotation:x", rest.x, 0.12)
		"lance":
			# A thrust: the weapon travels forward along its own length.
			tween.tween_property(arm, "position", rest_pos + Vector3(0, 0, -0.45), 0.10) \
				.set_ease(Tween.EASE_IN)
			tween.tween_property(arm, "position", rest_pos, 0.30).set_ease(Tween.EASE_OUT)
		"mortar":
			# Kicks up and back, and settles slowly. The heaviest recoil in the roster.
			tween.tween_property(arm, "rotation:x", -0.50, 0.07).set_ease(Tween.EASE_OUT)
			tween.tween_property(arm, "rotation:x", rest.x, 0.55).set_ease(Tween.EASE_OUT)
		"railgun":
			tween.tween_property(arm, "position", rest_pos + Vector3(0, 0, 0.30), 0.05)
			tween.tween_property(arm, "position", rest_pos, 0.42).set_ease(Tween.EASE_OUT)
		"coil":
			# No recoil at all: an induction weapon has nothing to push back. It pulses
			# instead, which is what makes it read as energy next to the kinetic arms.
			tween.tween_property(arm, "scale", Vector3(1.14, 1.14, 1.14), 0.07)
			tween.tween_property(arm, "scale", Vector3.ONE, 0.22)
		"scanner":
			# Sweeps rather than fires. The spotter should never look like it is shooting.
			tween.tween_property(arm, "rotation:y", 0.55, 0.18).set_ease(Tween.EASE_OUT)
			tween.tween_property(arm, "rotation:y", 0.0, 0.30).set_ease(Tween.EASE_IN_OUT)
		_:
			tween.tween_property(arm, "position", rest_pos + Vector3(0, 0, 0.16), 0.05)
			tween.tween_property(arm, "position", rest_pos, 0.24).set_ease(Tween.EASE_OUT)

	tween.finished.connect(func() -> void: _striking.erase(slot))


## 057: one staged strike for a skeleton arm. Poses are (whole-arm swing at the shoulder socket,
## elbow, wrist) on top of the arm's rest stance; the body leans into it through the same spring a
## hit uses (negative lean = toward the target, which is -Z).
func _strike_skeleton(slot: String, arm: Node3D, weapon_class: String, tree: SceneTree) -> void:
	var t: Tween = tree.create_tween()
	var pose := func(v: Vector3) -> void:
		if is_instance_valid(arm):
			arm.rotation.x = v.x
		_arm_offset[slot] = Vector3(0.0, v.y, v.z)
		_pose_arms()
	var lean := func(amount: float) -> void:
		_lean_velocity.x += amount
	var key := func(from: Vector3, to: Vector3, time: float, ease_type: int) -> void:
		t.tween_method(pose, from, to, time).set_ease(ease_type).set_trans(Tween.TRANS_CUBIC)
	match weapon_class:
		"hammer", "maul":
			# Raised high and held: the tell. Then it comes down hard and STAYS down a beat.
			var up := Vector3(-2.1, 0.9, 0.5)
			var down := Vector3(0.85, -0.35, -0.3)
			t.tween_callback(lean.bind(2.2))
			key.call(Vector3.ZERO, up, 0.38, Tween.EASE_OUT)
			t.tween_interval(0.10)
			t.tween_callback(lean.bind(-5.5))
			key.call(up, down, 0.10, Tween.EASE_IN)
			t.tween_callback(func() -> void: _recoil_velocity.y -= 0.9)
			t.tween_interval(0.16)
			key.call(down, Vector3.ZERO, 0.40, Tween.EASE_IN_OUT)
		"ripper", "saw":
			# A lunge: the arm drives forward, grinds three times, pulls back.
			var drive := Vector3(-0.9, -0.7, 0.0)
			t.tween_callback(lean.bind(1.2))
			key.call(Vector3.ZERO, Vector3(0.3, 0.5, 0.0), 0.18, Tween.EASE_OUT)
			t.tween_callback(lean.bind(-4.0))
			key.call(Vector3(0.3, 0.5, 0.0), drive, 0.12, Tween.EASE_IN)
			for _i: int in 3:
				key.call(drive, drive + Vector3(0.12, 0.18, 0.1), 0.06, Tween.EASE_IN_OUT)
				key.call(drive + Vector3(0.12, 0.18, 0.1), drive, 0.06, Tween.EASE_IN_OUT)
			key.call(drive, Vector3.ZERO, 0.35, Tween.EASE_IN_OUT)
		"scanner":
			# Sweeps, steadies, holds: it looks, it does not shoot.
			t.tween_property(arm, "rotation:y", 0.6, 0.30).set_ease(Tween.EASE_OUT)
			t.tween_property(arm, "rotation:y", -0.25, 0.35).set_ease(Tween.EASE_IN_OUT)
			t.tween_interval(0.25)
			t.tween_property(arm, "rotation:y", 0.0, 0.30).set_ease(Tween.EASE_IN_OUT)
		_:
			# A gun: brought up and steadied (the tell), then a hard kick through shoulder and
			# elbow that rocks the whole machine back, and a slow settle.
			var aim := Vector3(-0.15, 0.1, 0.0)
			var kick := Vector3(-0.75, -0.55, -0.35)
			key.call(Vector3.ZERO, aim, 0.22, Tween.EASE_OUT)
			t.tween_interval(0.12)
			t.tween_callback(lean.bind(3.6))
			t.tween_callback(func() -> void: _recoil_velocity.z += 0.9)
			key.call(aim, kick, 0.05, Tween.EASE_OUT)
			key.call(kick, Vector3.ZERO, 0.50, Tween.EASE_OUT)
	t.finished.connect(func() -> void:
		_striking.erase(slot)
		_arm_offset[slot] = Vector3.ZERO
		_pose_arms())


## The construct is destroyed: buckle and fall over.
##
## `direction` is which way it goes down, in the construct's own space -- the same
## convention `stagger` uses, so the battle scene can hand both the same vector and a
## machine falls away from whatever killed it rather than in a fixed direction.
##
## Idempotent. `DESTROYED` can be re-applied when playback is skipped and the whole
## event queue is drained in one frame, and a second call must not restart the topple of
## something already lying down.
func collapse(direction: Vector3) -> void:
	if _dead or _body == null or not is_instance_valid(_body):
		return
	_dead = true

	var fall: Vector3 = direction
	fall.y = 0.0
	if fall.length_squared() < 0.000001:
		fall = Vector3(0.0, 0.0, 1.0)
	fall = fall.normalized()

	# The axis is perpendicular to the fall, in the horizontal plane: topple toward +Z
	# and you rotate about +X. Built as an axis-angle rather than as euler x/z, because
	# a diagonal fall decomposed into two euler terms stops describing a rotation
	# anywhere near 90° and the wreck arrives twisted.
	_fall_axis = Vector3(fall.z, 0.0, -fall.x).normalized()
	_pivot = fall * _reach(fall)
	_kneel = 0.0
	_fall_velocity = 0.0
	_buckle = 0.0

	# The knees go first. Without this it tips like a felled statue, stiff-legged, and
	# the machine reads as having been pushed rather than as having stopped working.
	_recoil_velocity.y -= FALL_KICK
	_recoil_velocity += fall * 0.35


## How far the machine reaches from its feet in direction `dir` (its own space): the half-
## extent of every mesh in it, measured on their bounding boxes in the body's frame.
func _reach(dir: Vector3) -> float:
	var far: float = 0.0
	var inv: Transform3D = _body.global_transform.affine_inverse() if _body.is_inside_tree() else Transform3D.IDENTITY
	for mesh: MeshInstance3D in ConstructView.meshes_of(_body):
		var box: AABB = mesh.get_aabb()
		var to_body: Transform3D = (inv * mesh.global_transform) if _body.is_inside_tree() else _local_to(mesh)
		for i: int in 8:
			far = maxf(far, (to_body * box.get_endpoint(i)).dot(dir))
	return clampf(far, 0.0, 0.6)


func _local_to(node: Node3D) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != _body:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


## True once the construct has finished falling and is lying still.
func is_settled() -> bool:
	return _dead and _fall >= FALL_REST - 0.02 and absf(_fall_velocity) < 0.05


## Snaps every reaction home. Called when the Order Phase opens.
##
## Playback stops there and the board becomes something the player reads rather than
## watches, so nothing should still be mid-motion. A construct frozen leaning away from
## a hit stops reading as a reaction and starts reading as a machine that is broken --
## the same reason transient VFX are cleared at the same moment.
func reset_transients() -> void:
	_recoil = Vector3.ZERO
	_recoil_velocity = Vector3.ZERO
	_lean = Vector2.ZERO
	_lean_velocity = Vector2.ZERO
	_brace = 0.0
	_brace_velocity = 0.0
	_hitch = 0.0
	_react_clock = 0.0
	# A wreck is not a transient. Snapping the body upright here would stand every
	# destroyed construct back on its feet the moment the Order Phase opened -- and
	# since the Order Phase is exactly when the player reads the board, the one frame
	# they study would be the one showing their casualties alive again.
	if _dead:
		return
	if _body != null and is_instance_valid(_body):
		_body.position = _base
		_body.rotation.x = 0.0
		_body.rotation.z = 0.0


# --- Internals ---------------------------------------------------------------

## Integrates the topple, folds the legs, and settles the wreck.
##
## Reactions keep running underneath it: the drop from the buckling knees is the same
## recoil spring a hit uses, so a construct that dies mid-stagger carries that momentum
## into the fall instead of snapping upright first.
func _advance_fall(delta: float) -> void:
	_advance_reactions(delta)

	# 058: a skeleton machine slumps where it stands -- knees give, hips drop, the torso folds
	# forward over them, the arms hang -- with its feet planted on the floor (the IK holds them).
	# It does not topple: a toppled generated frame lay half through the floor and read as nothing.
	if _frame_skel != null:
		_kneel = move_toward(_kneel, 1.0, delta / KNEEL_TIME)
		var k: float = ease(_kneel, 0.4)
		var drop: float = KNEEL_DROP * _leg_length() * _body.scale.y * k
		var yaw0 := Basis.from_euler(Vector3(0.0, _base_yaw, 0.0))
		_body.transform.basis = yaw0 * Basis(Vector3.RIGHT, -SLUMP_PITCH * k)
		_body.position = _base + Vector3(_recoil.x, _recoil.y - drop, _recoil.z)
		_walk_legs(Vector2.ZERO, Vector2.ZERO)
		for slot: String in _arm_skel:
			_arm_offset[slot] = Vector3(0.0, -(_stance.get(slot, Vector3.ZERO) as Vector3).y * 0.9, 0.35) * k
		var arm_hang: float = SLUMP_PITCH * k * 0.9
		if _arm_l != null and is_instance_valid(_arm_l):
			_arm_l.rotation.x = arm_hang
		if _arm_r != null and is_instance_valid(_arm_r):
			_arm_r.rotation.x = arm_hang
		_pose_arms()
		return

	if _fall < FALL_REST:
		_fall_velocity += FALL_GRAVITY * delta
		_fall += _fall_velocity * delta
		if _fall >= FALL_REST:
			# It has hit the ground. One bounce, heavily absorbed.
			_fall = FALL_REST
			_fall_velocity = -_fall_velocity * FALL_BOUNCE
			_recoil_velocity.y -= 0.55
	else:
		# Rocking on its side, damping out.
		_fall_velocity += -(_fall - FALL_REST) * 90.0 * delta
		_fall_velocity *= 1.0 - minf(1.0, 9.0 * delta)
		_fall = maxf(FALL_REST - 0.10, _fall + _fall_velocity * delta)

	_buckle = move_toward(_buckle, 1.0, delta * 3.2)
	var fold: float = _buckle * BUCKLE_ANGLE
	if _leg_l != null and is_instance_valid(_leg_l):
		_leg_l.rotation.x = fold
	if _leg_r != null and is_instance_valid(_leg_r):
		_leg_r.rotation.x = fold * 0.72  # asymmetric: one knee gives before the other

	# Yaw first, then the topple in the construct's OWN frame. Composed rather than
	# written as euler angles so the machine falls the way it was facing; building the
	# basis the other way round topples it toward world north regardless of its heading.
	var yaw := Basis.from_euler(Vector3(0.0, _base_yaw, 0.0))
	var topple := Basis(_fall_axis, _fall)
	_body.transform.basis = yaw * topple

	# Tipped about the footprint's edge, not its middle: the pivot stays where it was.
	var hinge: Vector3 = yaw * (_pivot - topple * _pivot) * _body.scale.x
	var settle: float = -WRECK_SINK * clampf(_buckle, 0.0, 1.0)
	if _frame_skel != null:
		# Kneeling, it goes over from the knees: start from the knelt height, not the standing one.
		settle = -KNEEL_DROP * _leg_length() * _body.scale.y * cos(clampf(_fall, 0.0, PI * 0.5)) * 0.5
	_body.position = _base + hinge + Vector3(_recoil.x, _recoil.y + settle, _recoil.z)


## Advances every spring by `delta`, in FIXED substeps.
##
## The fixed step is the whole point: a spring integrated once per frame damps once per
## frame, so its behaviour is a function of the frame rate rather than of the hit. The
## leftover time is carried, not dropped, so no energy is lost between frames.
func _advance_reactions(delta: float) -> void:
	const STEP: float = 1.0 / REACT_HZ
	_react_clock = minf(_react_clock + delta, STEP * float(MAX_SUBSTEPS))
	while _react_clock >= STEP:
		_react_clock -= STEP
		_substep(STEP)


## One integration step. Semi-implicit Euler: velocity first, then position from the NEW
## velocity. Explicit Euler at this stiffness gains energy every step and a hit construct
## slowly shakes itself apart.
func _substep(step: float) -> void:
	_recoil_velocity += (-_recoil * REACT_STIFFNESS - _recoil_velocity * REACT_DAMPING) * step
	_recoil = (_recoil + _recoil_velocity * step).limit_length(RECOIL_LIMIT)

	_lean_velocity += (-_lean * LEAN_STIFFNESS - _lean_velocity * LEAN_DAMPING) * step
	_lean = (_lean + _lean_velocity * step).limit_length(LEAN_LIMIT)

	_brace_velocity += (-_brace * LEAN_STIFFNESS - _brace_velocity * LEAN_DAMPING) * step
	_brace = clampf(_brace + _brace_velocity * step, -LEAN_LIMIT, LEAN_LIMIT)


## Fires one impulse per foot landing, so the machine's weight arrives with the foot
## rather than being a continuous bob. Free, because the reaction spring already exists.
func _emit_footfalls(stride: float) -> void:
	if stride < 0.35:
		return
	var half: int = int(floor(_phase / PI))
	if half == _last_footfall:
		return
	if _last_footfall >= 0:
		_recoil_velocity.y -= FOOTFALL * stride
	_last_footfall = half


## Firing pushes the construct around too, and how much is the weapon's business.
func _body_recoil(weapon_class: String) -> void:
	match weapon_class:
		"hammer", "maul":
			# Commits forward into the swing.
			_recoil_velocity.z -= 0.85
			_lean_velocity.x -= 1.9
		"lance":
			_recoil_velocity.z -= 0.55
		"railgun":
			# The heaviest kick in the roster, straight back.
			_recoil_velocity.z += 1.25
			_lean_velocity.x += 2.2
		"mortar":
			_recoil_velocity.y += 0.35
			_lean_velocity.x += 1.5
		"ripper", "saw":
			_recoil_velocity.z -= 0.30
		"coil", "scanner":
			pass  # Nothing to push back.
		_:
			_recoil_velocity.z += 0.35
			_lean_velocity.x += 0.6


## Hip angle for a leg, -1..1, from its phase.
##
## Deliberately not a sine. A sine spends half the cycle on each side and moves fastest
## through the middle, which is the opposite of walking: the planted foot is stationary
## on the ground and the free foot is what moves quickly. Here the stance is a straight
## ramp -- constant rotation while the body travels over a fixed foot -- and the swing
## is a fast smoothstep back to the front.
static func _gait(phase: float) -> float:
	var t: float = fposmod(phase, TAU) / TAU
	if t < STANCE_FRACTION:
		return lerpf(1.0, -1.0, t / STANCE_FRACTION)
	var u: float = (t - STANCE_FRACTION) / (1.0 - STANCE_FRACTION)
	return lerpf(-1.0, 1.0, u * u * (3.0 - 2.0 * u))


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
