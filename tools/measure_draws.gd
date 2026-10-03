extends SceneTree

## Draw calls, objects and primitives per frame on a scene (play-test 12: "does the game use the
## PC's resources recklessly?"):
##   godot --path . --resolution 1920x1080 --script res://tools/measure_draws.gd -- --scene res://scenes/combat.tscn [--fight slag_pit]

func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scene: String = args[args.find("--scene") + 1] if args.has("--scene") else "res://scenes/combat.tscn"
	change_scene_to_file(scene)
	await create_timer(9.0).timeout
	var calls: float = 0.0
	var objects: float = 0.0
	var prims: float = 0.0
	for i: int in 30:
		await process_frame
		calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	print("%s: draw calls %.0f, objects %.0f, primitives %.0f a frame; process %.1f ms" % [scene.get_file(), calls / 30.0, objects / 30.0, prims / 30.0,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
	if args.has("--classes"):
		var by: Dictionary = {}
		for n: Node in current_scene.find_children("*", "GeometryInstance3D", true, false):
			var g := n as GeometryInstance3D
			if not g.is_visible_in_tree():
				continue
			var key: String = "%s%s%s" % [g.get_class(), " +line" if g.material_overlay != null else "", " +shadow" if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else ""]
			by[key] = int(by.get(key, 0)) + 1
		for k: Variant in by:
			print("  %-40s %d" % [k, by[k]])
	if args.has("--census"):
		var counts: Dictionary = {}
		_census(current_scene, "", counts)
		var keys: Array = counts.keys()
		keys.sort_custom(func(a: String, b: String) -> bool: return int(counts[a][0]) > int(counts[b][0]))
		for k: String in keys.slice(0, 14):
			print("  %-28s meshes %4d  shadow-casting %4d  outlined %4d  tris %7d" % [k, counts[k][0], counts[k][1], counts[k][2], counts[k][3]])
	quit()


## Mesh instances by their top-level branch under the scene: count, shadow casters, outlined, triangles.
func _census(node: Node, branch: String, counts: Dictionary) -> void:
	for child: Node in node.get_children():
		var here: String = branch if not branch.is_empty() else String(child.name).left(24)
		if child is MeshInstance3D and (child as MeshInstance3D).visible and (child as MeshInstance3D).is_visible_in_tree():
			var m := child as MeshInstance3D
			var row: Array = counts.get(here, [0, 0, 0, 0])
			row[0] += 1
			row[1] += 1 if m.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF else 0
			row[2] += 1 if m.material_overlay != null else 0
			if m.mesh != null:
				for sidx: int in m.mesh.get_surface_count():
					var arrays: Array = m.mesh.surface_get_arrays(sidx)
					var idx: Variant = arrays[Mesh.ARRAY_INDEX]
					row[3] += (idx as PackedInt32Array).size() / 3 if idx != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			counts[here] = row
		_census(child, here, counts)
