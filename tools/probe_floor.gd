extends SceneTree
## 060: measures how far each machine goes under the floor while it runs, strikes and is hit, from
## its posed vertices (`ConstructRig.lowest_point`). Also checks the skinned sample against the
## mesh's own bounds at rest.
##   godot --headless --path . --script res://tools/probe_floor.gd -- [--models gen --gen-dir res://art/parts_gen_scrap]

const CREW: Array = [
	["ch_brute", "co_slug", "ar_saw", "ar_hammer", "mo_scavenger"],
	["ch_hauler", "co_furnace", "ar_pulse", "ar_lance", "mo_ablative"],
	["ch_strider", "co_arc", "ar_scanner", "ar_pulse", "mo_governor"],
]

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	var db: ContentDB = ContentDB.load_all()
	var worst_all: float = 0.0
	for parts: Array in CREW:
		var holder := Node3D.new()
		root.add_child(holder)
		var ids := PackedStringArray(parts)
		var model: Node3D = ConstructView.build_parts(ids, db, Ink.YOURS)
		model.scale = Vector3.ONE * 1.45
		holder.add_child(model)
		var rig := ConstructRig.new()
		rig.bind(model)
		var classes := PackedStringArray()
		for k: int in [2, 3]:
			classes.append(String((db.parts.get(parts[k], {}) as Dictionary).get("weapon_class", "")))
		rig.set_stances(classes)
		rig.set_gait(String((db.parts.get(parts[0], {}) as Dictionary).get("role", "line")))
		rig.update(1.0 / 60.0)
		var rest_low: float = rig.lowest_point()
		var report: Dictionary = {}
		for phase: String in ["run", "strike_l", "strike_r", "hit", "brake"]:
			var worst: float = INF
			var who: String = ""
			match phase:
				"run":
					rig.set_moving(true)
				"strike_l":
					rig.strike("arm_l", classes[0])
				"strike_r":
					rig.strike("arm_r", classes[1])
				"hit":
					rig.stagger(Vector3(0.3, 0, -1).normalized(), 1.0)
				"brake":
					rig.set_moving(false)
			for i: int in 90:
				if phase == "run":
					holder.position += holder.global_transform.basis.z * (1.351 / 0.20) / 60.0
				rig.update(1.0 / 60.0)
				var low: Array = rig.lowest()
				if float(low[0]) < worst:
					worst = low[0]
					who = low[1]
			report[phase] = "%.3f %s" % [worst, who]
			worst_all = minf(worst_all, worst)
			if phase == "run":
				rig.set_moving(false)
				for i: int in 60:
					rig.update(1.0 / 60.0)
		print("%s rest low %.3f %s" % [parts[0], rest_low, rig.lowest()[1]])
		for k: String in report:
			print("    ", k, " ", report[k])
		holder.queue_free()
	print("worst %.3f m" % worst_all)
	quit()
