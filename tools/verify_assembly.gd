extends SceneTree

## Checks assembled constructs AS THE GAME LOADS THEM.
##
##     $GODOT --headless --path . --script res://tools/verify_assembly.gd
##
## Why this exists when `check_parts.py` already passes
## ----------------------------------------------------
## `check_parts.py` runs inside Blender. It proved every part was internally connected
## and every attachment seated on every chassis -- and it was right, in Blender. The game
## still assembled constructs lying on their backs with both arms on the floor, because
## the fault was in the EXPORT: sockets parented with a bare `child.parent = root` left
## `matrix_parent_inverse` at identity, and `export_yup` then wrote the hierarchy in a
## rotated basis. A socket reading "0.43 m up" arrived in Godot at ground level.
##
## No amount of checking in Blender can catch that, because Blender is the side that is
## correct. This loads the exported `.glb` through the same code path the battle uses and
## asks where things actually ended up.

## An arm or core socket this low is on the floor, not on a torso.
const MIN_MOUNT_HEIGHT: float = 0.15
## A socket further than this from the chassis' own bounds is not on the chassis.
const MAX_MOUNT_REACH: float = 0.55

var _passed: int = 0
var _failed: int = 0


func _check(what: String, ok: bool) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("  FAIL  %s" % what)


func _initialize() -> void:
	print("\n=== assembled constructs, as the game loads them ===")
	_run.call_deferred()


func _run() -> void:
	var content: ContentDB = ContentDB.load_all()
	var chassis_ids: Array[String] = []
	for part_id: String in content.parts:
		if String((content.parts[part_id] as Dictionary).get("slot", "")) == "chassis":
			chassis_ids.append(part_id)
	chassis_ids.sort()

	for chassis_id: String in chassis_ids:
		var path: String = "res://art/parts/%s.glb" % chassis_id
		if not ResourceLoader.exists(path):
			_check("%s has an exported mesh" % chassis_id, false)
			continue
		var model: Node3D = (load(path) as PackedScene).instantiate() as Node3D
		root.add_child(model)

		var bounds: AABB = _bounds_of(model)
		_check("%s stands on the ground (lowest %.2f)" % [chassis_id, bounds.position.y],
			absf(bounds.position.y) < 0.20)
		# Height, NOT an aspect ratio. "Taller than wide" looks like a neat way to catch a
		# construct lying down, but an anchor is deliberately a squat wide wall and fails
		# it while standing perfectly upright. The real signature of the lying-down export
		# bug was mount sockets at y=0, which the socket check below catches directly.
		_check("%s has a plausible standing height (%.2f m)" % [chassis_id, bounds.size.y],
			bounds.size.y > 0.45)

		for socket_name: String in ["socket_core", "socket_arm_l", "socket_arm_r",
				"socket_module"]:
			var socket: Node3D = _find(model, socket_name)
			if socket == null:
				_check("%s has %s" % [chassis_id, socket_name], false)
				continue
			var where: Vector3 = socket.global_transform.origin
			_check("%s %s is off the floor (y=%.2f)" % [chassis_id, socket_name, where.y],
				where.y > MIN_MOUNT_HEIGHT)
			_check("%s %s is on the chassis" % [chassis_id, socket_name],
				_distance_to(bounds, where) < MAX_MOUNT_REACH)

		model.queue_free()

	print("\n  %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## True world bounds, from the actual vertices.
##
## NOT `global_transform * get_aabb()`. The glTF importer leaves the conversion rotation
## on the mesh nodes, and transforming a snug local box by a rotation yields the
## axis-aligned bound of a tilted box -- which overstated one chassis by 23 cm and
## reported it as sunk into the ground when it was standing correctly. An outer bound of
## a rotated box is not a measurement of the geometry.
func _bounds_of(node: Node3D) -> AABB:
	var out := AABB()
	var first: bool = true
	for mesh: MeshInstance3D in _meshes(node):
		if mesh.mesh == null:
			continue
		var transform: Transform3D = mesh.global_transform
		for surface: int in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			if arrays.is_empty():
				continue
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for point: Vector3 in points:
				var world: Vector3 = transform * point
				if first:
					out = AABB(world, Vector3.ZERO)
					first = false
				else:
					out = out.expand(world)
	return out


func _distance_to(box: AABB, point: Vector3) -> float:
	var clamped := Vector3(
		clampf(point.x, box.position.x, box.end.x),
		clampf(point.y, box.position.y, box.end.y),
		clampf(point.z, box.position.z, box.end.z))
	return point.distance_to(clamped)


func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		out.append_array(_meshes(child))
	return out


func _find(node: Node, name: String) -> Node3D:
	if node.name == name and node is Node3D:
		return node as Node3D
	for child: Node in node.get_children():
		var found: Node3D = _find(child, name)
		if found != null:
			return found
	return null
