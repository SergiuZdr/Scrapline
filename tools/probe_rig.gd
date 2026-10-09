extends SceneTree
## Prints each crew machine's skeletons (bone parents and rest positions in the body's frame) and
## where its arms sit, so a rig change can be reasoned about on the real bones (059).
##   godot --headless --path . --script res://tools/probe_rig.gd -- --models gen --gen-dir res://art/parts_gen_scrap

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	var db: ContentDB = ContentDB.load_all()
	for parts: Array in [["ch_brute", "co_slug", "ar_saw", "ar_hammer", "mo_scavenger"],
			["ch_hauler", "co_furnace", "ar_pulse", "ar_lance", "mo_ablative"],
			["ch_strider", "co_arc", "ar_scanner", "ar_pulse", "mo_governor"]]:
		var model: Node3D = ConstructView.build_parts(PackedStringArray(parts), db, Ink.YOURS)
		root.add_child(model)
		print("== ", parts[0], " yaw ", model.rotation.y)
		_walk(model, model, 0)
		model.queue_free()
	quit()

func _walk(body: Node3D, n: Node, depth: int) -> void:
	if n is Skeleton3D:
		var sk: Skeleton3D = n
		var rel: Transform3D = body.global_transform.affine_inverse() * sk.global_transform
		for b: int in sk.get_bone_count():
			var g: Transform3D = rel * sk.get_bone_global_rest(b)
			print("  ".repeat(depth), "bone ", sk.get_bone_name(b), " parent ", sk.get_bone_parent(b), " at ", g.origin.snapped(Vector3.ONE * 0.01), " x ", g.basis.x.normalized().snapped(Vector3.ONE * 0.01))
	elif n is Node3D and depth < 6 and (String(n.name).begins_with("part_") or String(n.name).begins_with("socket") or String(n.name).begins_with("limb")):
		var rel2: Transform3D = body.global_transform.affine_inverse() * (n as Node3D).global_transform
		print("  ".repeat(depth), n.name, " at ", rel2.origin.snapped(Vector3.ONE * 0.01), " basis.x ", rel2.basis.x.snapped(Vector3.ONE * 0.01), " scale ", rel2.basis.get_scale().snapped(Vector3.ONE * 0.01))
	for c: Node in n.get_children():
		_walk(body, c, depth + 1)
