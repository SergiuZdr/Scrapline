extends SceneTree

## How far each arm sits inside its frame's body (027, play-test 9: "arms go through other parts
## of the body"). For every frame and arm, builds the machine as the game does and counts the arm's
## vertices that lie inside the body's bounds (the chassis without its legs), in machine space.
##   godot --headless --path . --script res://tools/probe_arms.gd

func _initialize() -> void:
	var db: ContentDB = ContentDB.load_all()
	var frames: Array = []
	var arms: Array = []
	for id: Variant in db.parts:
		if PartTuning.is_tuned(String(id)):
			continue
		match String(db.parts[id].get("slot", "")):
			"chassis":
				frames.append(String(id))
			"arm":
				arms.append(String(id))
	frames.sort()
	arms.sort()
	var worst: Array = []
	for f: String in frames:
		for a: String in arms:
			var model: Node3D = ConstructView.build_parts(PackedStringArray([f, "co_slug", a, a, "mo_scavenger"]), db, Color.WHITE)
			root.add_child(model)
			var inside: float = ConstructView.arm_intrusion(model)
			worst.append([inside, f, a])
			model.free()
	worst.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	for i: int in mini(25, worst.size()):
		print("%5.1f%%  %s  %s" % [float(worst[i][0]) * 100.0, worst[i][1], worst[i][2]])
	var bad: int = worst.filter(func(x: Array) -> bool: return float(x[0]) > 0.12).size()
	print("combinations over 12%%: %d of %d" % [bad, worst.size()])
	quit()
