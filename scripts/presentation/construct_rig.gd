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
## Which half-stride the last footfall landed on, so each landing fires once.
var _last_footfall: int = -1


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

	# Two bobs per stride: the body rises as each leg passes under it.
	var bob: float = absf(sin(_phase)) * BOB * stride
	_body.position = _base + Vector3(_recoil.x, bob + _recoil.y, _recoil.z)

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

	_body_recoil(weapon_class)

	var rest: Vector3 = Vector3.ZERO
	var rest_pos: Vector3 = arm.position
	var tween: Tween = tree.create_tween()

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
	_fall_velocity = 0.0
	_buckle = 0.0

	# The knees go first. Without this it tips like a felled statue, stiff-legged, and
	# the machine reads as having been pushed rather than as having stopped working.
	_recoil_velocity.y -= FALL_KICK
	_recoil_velocity += fall * 0.35


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
	_body.transform.basis = yaw * Basis(_fall_axis, _fall)

	var settle: float = -WRECK_SINK * clampf(_buckle, 0.0, 1.0)
	_body.position = _base + Vector3(_recoil.x, _recoil.y + settle, _recoil.z)


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
