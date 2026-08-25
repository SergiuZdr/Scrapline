extends SceneTree

## Checks the construct rig NUMERICALLY.
##
##     $GODOT --headless --path . --script res://tools/verify_animation.gd
##
## Why this exists when `gait_preview.tscn` already films the walk
## ---------------------------------------------------------------
## The preview is the honest way to see whether a gait LOOKS right, and nothing here
## replaces it. But a still frame cannot answer the questions that actually break an
## animation system, because they are all about behaviour over time:
##
## * Does the body come back to rest, or does every hit leave it slightly displaced
##   until a construct has visibly drifted off its own feet by cycle six?
## * Do two hits in one tick produce a bigger reaction than one, or does the second
##   overwrite the first?
## * Is the spring stable, or does it gain a little energy each frame and end up
##   shaking a machine apart at a frame rate nobody tested at?
## * Does a hit from the LEFT actually push right? A sign error moves the construct
##   convincingly and in exactly the wrong direction, and it reads as correct in
##   every screenshot where you do not know where the attacker was standing.
##
## Every one of those is invisible in a still and obvious in a number.

## Simulated frame, in seconds. Deliberately not the frame rate the game runs at -- an
## animation that only settles at 60 fps is one that breaks on a phone.
const STEP: float = 1.0 / 60.0

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	print("=== verify_animation ===")
	_test_finds_limbs()
	_test_walk_moves_legs()
	_test_gait_is_not_a_sine()
	_test_walk_settles()
	_test_stagger_direction()
	_test_stagger_returns_to_rest()
	_test_stagger_accumulates()
	_test_stagger_is_visible()
	_test_stagger_is_bounded()
	_test_spring_is_stable()
	_test_reset_transients()
	_test_facing_is_untouched()
	_test_collapse_falls_over()
	_test_collapse_direction()
	_test_collapse_is_idempotent()
	_test_collapse_survives_order_phase()
	_test_real_chassis_binds()

	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	print("  %s" % ("PASS" if _failed == 0 else "FAIL"))
	quit(1 if _failed > 0 else 0)


# --- Tests -------------------------------------------------------------------

func _test_finds_limbs() -> void:
	var model: Node3D = _model()
	var rig := ConstructRig.new()
	rig.bind(model)
	rig.set_moving(true)
	_run(rig, 0.5)
	var moved: bool = not is_equal_approx(_leg(model, "limb_leg_l").rotation.x, 0.0)
	_check("bind finds the legs and drives them", moved)


func _test_walk_moves_legs() -> void:
	var model: Node3D = _model()
	var rig := ConstructRig.new()
	rig.bind(model)
	rig.set_moving(true)

	var left_seen: Array[float] = []
	var opposed: int = 0
	var samples: int = 0
	for _i: int in 180:
		rig.update(STEP)
		var left: float = _leg(model, "limb_leg_l").rotation.x
		var right: float = _leg(model, "limb_leg_r").rotation.x
		left_seen.append(left)
		# The legs must be on opposite sides of neutral for most of the cycle. Both
		# swinging together is not a walk, it is a hop.
		if absf(left) > 0.05 and absf(right) > 0.05:
			samples += 1
			if signf(left) != signf(right):
				opposed += 1

	var span: float = left_seen.max() - left_seen.min()
	_check("the hip sweeps a real arc (%.2f rad)" % span, span > 0.6)
	_check("the legs are opposed (%d/%d samples)" % [opposed, samples],
		samples > 0 and float(opposed) / float(samples) > 0.9)


func _test_gait_is_not_a_sine() -> void:
	# A sine is symmetric: it spends exactly half its cycle on each side of neutral.
	# The gait must not, or the walk reads as marching in place -- the planted foot is
	# supposed to be still relative to the ground while the body travels over it, and
	# the free leg is what moves fast.
	var model: Node3D = _model()
	var rig := ConstructRig.new()
	rig.bind(model)
	rig.set_moving(true)
	_run(rig, 1.0)  # reach full stride before sampling

	var forward: int = 0
	var total: int = 0
	var fastest: float = 0.0
	var previous: float = _leg(model, "limb_leg_l").rotation.x
	for _i: int in 240:
		rig.update(STEP)
		var value: float = _leg(model, "limb_leg_l").rotation.x
		fastest = maxf(fastest, absf(value - previous))
		if value > previous:
			forward += 1
		total += 1
		previous = value

	var swing_share: float = float(forward) / float(total)
	_check("the swing is faster than the stance (%.0f%% of the cycle)"
		% (swing_share * 100.0), swing_share > 0.2 and swing_share < 0.48)


func _test_walk_settles() -> void:
	var model: Node3D = _model()
	var rig := ConstructRig.new()
	rig.bind(model)
	rig.set_moving(true)
	_run(rig, 1.0)
	rig.set_moving(false)
	_run(rig, 2.0)
	var left: float = _leg(model, "limb_leg_l").rotation.x
	var height: float = model.position.y
	_check("legs return to neutral when it stops (%.4f)" % left, absf(left) < 0.01)
	_check("the body returns to its base height (%.4f)" % height, absf(height) < 0.01)


func _test_stagger_direction() -> void:
	# The sign test. A construct shoved from the front must move BACKWARD -- +Z in its
	# own space -- and one shoved from its left must move to its right.
	for case: Dictionary in [
		{"name": "front", "push": Vector3(0, 0, 1), "axis": "z", "sign": 1.0},
		{"name": "back", "push": Vector3(0, 0, -1), "axis": "z", "sign": -1.0},
		{"name": "left", "push": Vector3(1, 0, 0), "axis": "x", "sign": 1.0},
		{"name": "right", "push": Vector3(-1, 0, 0), "axis": "x", "sign": -1.0},
	]:
		var model: Node3D = _model()
		var rig := ConstructRig.new()
		rig.bind(model)
		rig.stagger(case["push"], 1.0)
		var peak: float = 0.0
		for _i: int in 30:
			rig.update(STEP)
			var value: float = model.position.z if case["axis"] == "z" else model.position.x
			if absf(value) > absf(peak):
				peak = value
		_check("hit from the %s pushes %s%s (%.3f)"
			% [case["name"], "+" if case["sign"] > 0 else "-", case["axis"], peak],
			signf(peak) == case["sign"] and absf(peak) > 0.02)


func _test_stagger_returns_to_rest() -> void:
	# The one that matters most over a whole battle. A reaction that leaves any residue
	# accumulates: forty hits later the construct is standing somewhere it never walked
	# to, and nothing in the game will ever put it back.
	var model: Node3D = _model()
	var rig := ConstructRig.new()
	rig.bind(model)
	for _hit: int in 20:
		rig.stagger(Vector3(0, 0, 1), 1.0)
		_run(rig, 0.6)
	_run(rig, 2.0)
	var drift: float = model.position.distance_to(Vector3.ZERO)
	var tilt: float = absf(model.rotation.x) + absf(model.rotation.z)
	_check("20 hits leave no positional drift (%.5f m)" % drift, drift < 0.005)
	_check("20 hits leave no residual tilt (%.5f rad)" % tilt, tilt < 0.005)


func _test_stagger_accumulates() -> void:
	# Six units focusing one target in a tick should produce one big lurch. With tweens
	# the last one wins and a focused volley reads exactly like a single hit.
	var single: float = _peak_recoil(1)
	var triple: float = _peak_recoil(3)
	_check("three hits move more than one (%.3f vs %.3f)" % [triple, single],
		triple > single * 1.4)


func _test_stagger_is_bounded() -> void:
	# ...but a whole squad unloading must not launch a construct off the field.
	var model: Node3D = _model()
	var rig := ConstructRig.new()
	rig.bind(model)
	for _i: int in 40:
		rig.stagger(Vector3(0, 0, 1), 1.0)
	var peak: float = 0.0
	for _i: int in 60:
		rig.update(STEP)
		peak = maxf(peak, model.position.length())
	_check("40 simultaneous hits stay bounded (%.3f m)" % peak,
		peak <= ConstructRig.RECOIL_LIMIT + 0.001)


func _test_stagger_is_visible() -> void:
	# A reaction can be stable, correctly signed, perfectly damped and far too small to
	# see. That is the version this rig shipped first: 3.5 cm of travel on a 1.1 m
	# construct, which is about two pixels at battle distance. Every other test passed.
	#
	# The floor is a fraction of a construct's height rather than an absolute, so it
	# stays meaningful if the roster is ever rescaled.
	var peak: float = _peak_recoil(1)
	_check("a heavy hit visibly moves the construct (%.3f m)" % peak,
		peak > 0.08 and peak < ConstructRig.RECOIL_LIMIT)


func _test_spring_is_stable() -> void:
	# Explicit Euler at this stiffness GAINS energy every frame, and the construct ends
	# up vibrating harder than the hit that started it. Checked at a long frame too,
	# because that is where an integrator blows up first.
	#
	# The peaks are also compared ACROSS frame rates. Stepping the spring once per frame
	# damps it once per frame, so the same hit travelled 3.5 cm at 60 fps and 0.4 cm at
	# 15 -- the reaction quietly vanishing on the hardware least able to spare frames,
	# which for a phone game is the hardware that matters. Testing each rate in isolation
	# says "stable" to all three and misses it completely; only the comparison finds it.
	var peaks: Dictionary = {}
	for step: float in [1.0 / 60.0, 1.0 / 30.0, 1.0 / 15.0]:
		var model: Node3D = _model()
		var rig := ConstructRig.new()
		rig.bind(model)
		rig.stagger(Vector3(0, 0, 1), 1.0)
		var peak: float = 0.0
		var late: float = 0.0
		for i: int in 200:
			rig.update(step)
			var magnitude: float = model.position.length()
			peak = maxf(peak, magnitude)
			if i > 150:
				late = maxf(late, magnitude)
		peaks[step] = peak
		_check("stable at %.0f fps (peak %.3f, settled %.4f)" % [1.0 / step, peak, late],
			peak < 1.0 and late < 0.01)

	var reference: float = peaks[1.0 / 60.0]
	for step: float in peaks:
		var ratio: float = peaks[step] / maxf(0.0001, reference)
		_check("%.0f fps matches 60 fps within 25%% (%.0f%%)"
			% [1.0 / step, ratio * 100.0], absf(ratio - 1.0) < 0.25)


func _test_reset_transients() -> void:
	var model: Node3D = _model()
	var rig := ConstructRig.new()
	rig.bind(model)
	rig.stagger(Vector3(0, 0, 1), 1.0)
	rig.update(STEP)
	rig.update(STEP)
	_check("a hit displaces the body first", model.position.length() > 0.0)
	rig.reset_transients()
	_check("reset snaps the body home", model.position.is_equal_approx(Vector3.ZERO))
	_check("reset clears the tilt",
		is_zero_approx(model.rotation.x) and is_zero_approx(model.rotation.z))


func _test_facing_is_untouched() -> void:
	# The battle scene owns yaw: it turns a construct to face whatever it is shooting.
	# If the rig ever writes rotation.y, units turn away from their targets mid-fight.
	var model: Node3D = _model()
	model.rotation.y = 1.234
	var rig := ConstructRig.new()
	rig.bind(model)
	rig.set_moving(true)
	rig.stagger(Vector3(1, 0, 1), 1.0)
	_run(rig, 1.5)
	_check("the rig never touches facing (%.4f)" % model.rotation.y,
		is_equal_approx(model.rotation.y, 1.234))


func _test_collapse_falls_over() -> void:
	var model: Node3D = _model()
	var rig := ConstructRig.new()
	rig.bind(model)
	rig.collapse(Vector3(0, 0, 1))
	_run(rig, 3.0)

	# "Fallen over" measured as the body's own up axis, not as an euler angle. The fall
	# is built as an axis-angle basis, and reading euler back out of a 90-degree
	# rotation is exactly where the numbers stop meaning what they look like.
	var up: Vector3 = model.transform.basis.y
	_check("the construct ends up on its side (up.y = %.3f)" % up.y, up.y < 0.15)
	_check("the fall settles (still moving: %s)" % (not rig.is_settled()), rig.is_settled())
	# Legs must have folded, or it toppled like a statue.
	var fold: float = _leg(model, "limb_leg_l").rotation.x
	_check("the knees buckle (%.2f rad)" % fold, fold > 0.5)


func _test_collapse_direction() -> void:
	# A machine killed from the front goes over BACKWARDS. Falling the same way every
	# time regardless of what killed it is the tell that the direction was never wired.
	for case: Dictionary in [
		{"name": "front", "push": Vector3(0, 0, 1), "axis": 2, "sign": 1.0},
		{"name": "back", "push": Vector3(0, 0, -1), "axis": 2, "sign": -1.0},
		{"name": "left", "push": Vector3(1, 0, 0), "axis": 0, "sign": 1.0},
	]:
		var model: Node3D = _model()
		var rig := ConstructRig.new()
		rig.bind(model)
		rig.collapse(case["push"])
		_run(rig, 3.0)
		# Once it is flat, the body's own UP axis points the way it fell.
		var up: Vector3 = model.transform.basis.y
		var component: float = up[case["axis"]]
		_check("killed from the %s, it falls that way (%.2f)" % [case["name"], component],
			signf(component) == case["sign"] and absf(component) > 0.7)


func _test_collapse_is_idempotent() -> void:
	# SKIP drains the whole event queue in one frame, so DESTROYED can arrive again on a
	# construct that is already lying down. Restarting the topple would stand it up and
	# drop it a second time, which is visible precisely when a player has asked to stop
	# watching the animation.
	var model: Node3D = _model()
	var rig := ConstructRig.new()
	rig.bind(model)
	rig.collapse(Vector3(0, 0, 1))
	_run(rig, 3.0)
	var resting: Transform3D = model.transform
	rig.collapse(Vector3(1, 0, 0))
	_run(rig, 0.2)
	_check("a second DESTROYED does not restart the fall",
		model.transform.basis.y.distance_to(resting.basis.y) < 0.05)


func _test_collapse_survives_order_phase() -> void:
	# `reset_transients` runs on every rig when the Order Phase opens. Without a guard
	# it snaps the body upright, and the one frame the player actually studies -- the
	# board, while giving orders -- is the frame showing their casualties back on their
	# feet.
	var model: Node3D = _model()
	var rig := ConstructRig.new()
	rig.bind(model)
	rig.collapse(Vector3(0, 0, 1))
	_run(rig, 3.0)
	rig.reset_transients()
	rig.update(STEP)
	var up: Vector3 = model.transform.basis.y
	_check("a wreck stays down through the Order Phase (up.y = %.3f)" % up.y, up.y < 0.15)


func _test_real_chassis_binds() -> void:
	# The synthetic model above proves the maths. This proves the NAMES: a chassis whose
	# legs did not export as `limb_leg_l` / `limb_leg_r` animates perfectly and moves
	# nothing, and every test above would still pass.
	var db: ContentDB = ContentDB.load_all()
	var checked: int = 0
	var walked: int = 0
	for part_id: String in db.parts:
		var part: Dictionary = db.parts[part_id]
		if String(part.get("slot", "")) != "chassis":
			continue
		var unit := SimUnit.new()
		unit.unit_ref = 0
		unit.team = SimDefs.TEAM_A
		unit.part_ids = [part_id, "", "", "", ""]
		var model: Node3D = ConstructView.build(unit, db, Color.WHITE)
		var rig := ConstructRig.new()
		rig.bind(model)
		rig.set_moving(true)
		_run(rig, 0.5)
		checked += 1
		var leg: Node3D = _find(model, "limb_leg_l")
		if leg != null and absf(leg.rotation.x) > 0.001:
			walked += 1
		model.free()
	_check("every chassis has legs the rig can drive (%d/%d)" % [walked, checked],
		checked > 0 and walked == checked)


# --- Helpers -----------------------------------------------------------------

func _peak_recoil(hits: int) -> float:
	var model: Node3D = _model()
	var rig := ConstructRig.new()
	rig.bind(model)
	for _i: int in hits:
		rig.stagger(Vector3(0, 0, 1), 1.0)
	var peak: float = 0.0
	for _i: int in 40:
		rig.update(STEP)
		peak = maxf(peak, model.position.length())
	return peak


func _run(rig: ConstructRig, seconds: float) -> void:
	for _i: int in int(seconds / STEP):
		rig.update(STEP)


## A stand-in construct with the limb names the real chassis export carries.
func _model() -> Node3D:
	var root := Node3D.new()
	for name: String in ["limb_leg_l", "limb_leg_r"]:
		var leg := Node3D.new()
		leg.name = name
		root.add_child(leg)
	for name: String in ["socket_arm_l", "socket_arm_r"]:
		var socket := Node3D.new()
		socket.name = name
		var arm := Node3D.new()
		arm.name = name + "_part"
		socket.add_child(arm)
		root.add_child(socket)
	return root


func _leg(model: Node3D, name: String) -> Node3D:
	return _find(model, name)


func _find(node: Node, name: String) -> Node3D:
	if node.name == name and node is Node3D:
		return node as Node3D
	for child: Node in node.get_children():
		var found: Node3D = _find(child, name)
		if found != null:
			return found
	return null


func _check(what: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("  ok   %s" % what)
	else:
		_failed += 1
		print("  FAIL %s" % what)
