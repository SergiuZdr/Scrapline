extends SceneTree
## 062: plays each crew machine's death with two, one and no arms and reports how the wreck lies:
## its highest and lowest points over the floor once settled (flat = the highest is about the
## body's depth, nothing under the floor), and where its loose parts ended (within the hex).
##   godot --headless --path . --script res://tools/probe_death.gd -- --models gen --gen-dir res://art/parts_gen_scrap

const CREW: Array = [
	["ch_brute", "co_slug", "ar_saw", "ar_hammer", "mo_scavenger"],
	["ch_hauler", "co_furnace", "ar_pulse", "ar_lance", "mo_ablative"],
	["ch_strider", "co_arc", "ar_scanner", "ar_pulse", "mo_governor"],
]
var _jobs: Array = []
var _rig: ConstructRig
var _model: Node3D
var _holder: Node3D
var _t: int = 0
var _db: ContentDB

func _initialize() -> void:
	_db = ContentDB.load_all()
	for parts: Array in CREW:
		for arms: int in [2, 1, 0]:
			_jobs.append([parts, arms])
	_next.call_deferred()
	process_frame.connect(_tick)

func _next() -> void:
	if _jobs.is_empty():
		quit()
		return
	var job: Array = _jobs.pop_front()
	_holder = Node3D.new()
	root.add_child(_holder)
	_model = ConstructView.build_parts(PackedStringArray(job[0]), _db, Ink.YOURS)
	_model.scale = Vector3.ONE * 1.45
	_holder.add_child(_model)
	for slot: String in (["part_arm_l", "part_arm_r"].slice(0, 2 - int(job[1]))):
		var arm: Node = _model.find_child(slot, true, false)
		if arm != null:
			arm.get_parent().remove_child(arm)
			arm.free()
	_rig = ConstructRig.new()
	_rig.bind(_model)
	_rig.set_gait(String((_db.parts.get(job[0][0], {}) as Dictionary).get("role", "line")))
	_rig.collapse(Vector3(0, 0, -1))
	_rig.set_meta("job", "%s %d arms" % [job[0][0], job[1]])
	_t = 0

func _tick() -> void:
	if _rig == null:
		return
	_rig.update(1.0 / 30.0)
	_t += 1
	if _t == 150:
		var low: float = _rig.lowest_point()
		var high: float = -INF
		for e: Array in _rig._skin_points:
			var sk: Skeleton3D = e[0]
			var g: Transform3D = sk.global_transform * sk.get_bone_global_pose(int(e[1]))
			for p: Vector3 in e[2]:
				high = maxf(high, (g * p).y)
		var far: float = 0.0
		for part: Dictionary in _rig._loose:
			var b: Node3D = part["body"]
			far = maxf(far, Vector2(b.global_position.x, b.global_position.z).length())
		print("fall %.3f vel %.4f clock %.2f stand %.2f" % [_rig._fall, _rig._fall_velocity, _rig._death_clock, _rig._stand_time])
		print("%-22s settled %s  low %.3f high %.3f  up %s  parts %d farthest %.2f m" % [_rig.get_meta("job"), _rig.is_settled(), low, high,
			str(_model.global_transform.basis.y.normalized().snapped(Vector3.ONE * 0.01)), _rig._loose.size(), far])
		_holder.queue_free()
		_rig = null
		_next.call_deferred()
