class_name ConstructView
extends RefCounted

## Assembles a construct's 3D model from its parts at runtime.
##
## The chassis `.glb` carries empties named `socket_core`, `socket_arm_l`,
## `socket_arm_r` and `socket_module`; each attachment is modelled with its mount at
## the origin. So bolting a loadout together is: instance the chassis, find the
## sockets, instance each part, parent it. No per-combination offsets, no bespoke
## prefabs — which is the entire reason the parts are modular in the first place.
##
## A missing `.glb` falls back to a primitive rather than an empty node. Art lands
## piecemeal, and a half-generated part set should still produce a playable battle.

const PARTS_DIR: String = "res://art/parts"

## How far each arm is turned outward, and how far it is canted down. See the note in
## `build` -- this is purely so weapons read in profile at gameplay distance.
const ARM_SPLAY: float = 0.30
const ARM_CANT: float = 0.10
## Arm seating (027): the share of an arm allowed inside its body's bounds, and the furthest an
## arm is pushed out to get there.
const ARM_INSIDE: float = 0.06
const ARM_PUSH_MAX: float = 0.22
## 043 (play-test 13: "I don't like how big the arms are"): a weapon arm is drawn at this share
## of its modelled size, so the frame -- not the gun -- is the machine's outline.
const ARM_SCALE: float = 0.8
static var _arm_push: Dictionary = {}

const SOCKETS: Dictionary = {
	"core": "socket_core",
	"arm_l": "socket_arm_l",
	"arm_r": "socket_arm_r",
	"module": "socket_module",
}

## Cached so a twelve-construct battle loads each mesh once rather than twelve times.
static var _scene_cache: Dictionary = {}
## Parts asked for in the background (`warm`) and not yet collected: `id -> path`.
static var _warming: Dictionary = {}

## How much bigger a machine stands per level: mass is the first thing that reads.
const LEVEL_SCALE: float = 0.035


## Builds the model for one unit and returns its root.
##
## `team_colour` no longer paints the frame. It lights the EYES and nothing else, because
## paint is livery and livery is per-part: a chassis wears whatever colour it was built
## in, chipped, exactly as the reference sheets do. Team identity has to survive a
## machine being turned away, buried in a melee or eighty pixels tall, and a lit lens at
## the top of the silhouette does that where a painted flank does not.
##
## The core keeps its own damage-type colour, because that is the fastest read for what
## a construct actually does.
static func build(unit: SimUnit, content: ContentDB, team_colour: Color) -> Node3D:
	return build_parts(unit.part_ids, content, team_colour)


## The same, from a bare loadout: chassis, core, arm_l, arm_r, module. The grid game's
## units are not `SimUnit`s, and the view has no business caring which sim built them.
static func build_parts(part_ids: PackedStringArray, _content: ContentDB, team_colour: Color, level: int = 0) -> Node3D:
	var root := Node3D.new()
	# 053: Ink.dress_machine reads it -- a generated part's rust wears off as the machine levels.
	root.set_meta("level", level)

	var chassis_id: String = _part_id(part_ids, 0)
	var chassis: Node3D = _instance(chassis_id)
	if chassis == null:
		root.add_child(_fallback_body(team_colour))
		return root

	# Each part is named for its slot ("part_chassis", "part_arm_l", ...) so a screen can
	# find one part of an assembled machine -- the garage lights up the one under the cursor.
	chassis.name = "part_chassis"
	root.add_child(chassis)
	_tint(chassis, team_colour, PartMaterials.livery_of(chassis_id))

	var sockets: Dictionary = _find_sockets(chassis)
	var loadout: Dictionary = {
		"core": _part_id(part_ids, 1),
		"arm_l": _part_id(part_ids, 2),
		"arm_r": _part_id(part_ids, 3),
		"module": _part_id(part_ids, 4),
	}

	for slot: String in ["core", "arm_l", "arm_r", "module"]:
		var part_id: String = String(loadout[slot])
		if part_id.is_empty():
			continue
		var socket: Node3D = sockets.get(SOCKETS[slot])
		if socket == null:
			continue
		var piece: Node3D = _instance(part_id)
		if piece == null:
			continue
		piece.name = "part_" + slot
		socket.add_child(piece)
		if slot == "arm_l" or slot == "arm_r":
			# Splayed outward and canted down a few degrees.
			#
			# Weapons are modelled pointing straight forward, so a construct facing its
			# target presents both of them end-on to the battle camera and the player sees
			# two small squares where a hammer and a railgun ought to be. A modest splay
			# puts them in PROFILE without making the machine look cross-eyed, and real
			# hardpoints are never perfectly parallel anyway.
			var outward: float = ARM_SPLAY if slot == "arm_r" else -ARM_SPLAY
			# 062: a generated arm is posed by its rig (aimed or hanging by weapon) from a socket set on
			# its shoulder's face; splayed and canted on top, it stood off the frame at an angle.
			var generated: bool = Models.part_path(chassis_id).contains("/parts_gen")
			piece.rotation = Vector3.ZERO if generated else Vector3(ARM_CANT, outward, 0.0)
			piece.scale = Vector3.ONE * ARM_SCALE
		if slot == "arm_l":
			# Mirrored so the pair reads as a left and a right arm rather than two
			# identical ones pointing the same way. Applied after the rotation, because
			# a negative scale flips the handedness of any rotation set on top of it.
			piece.scale = Vector3(-ARM_SCALE, ARM_SCALE, ARM_SCALE)
		# The core goes through the palette like everything else. Its damage-type colour
		# now lives on the LENS zone alone, so the housing around it can be plain metal
		# instead of the whole reactor glowing and washing the signal out.
		_tint(piece, team_colour, PartMaterials.livery_of(part_id))

	_seat_arms(root, chassis, chassis_id)
	if level > 0:
		# 053: a generated frame shows its level by its rust wearing off (Ink.clean_of); the bolted
		# kit is placed for the scripted frames and floats off a generated one. It still grows.
		if Models.part_path(chassis_id).contains("/parts_gen"):
			chassis.scale *= 1.0 + LEVEL_SCALE * float(level)
		else:
			_level_kit(chassis, sockets, level, PartMaterials.livery_of(chassis_id), team_colour)
	return root


## Arms clear of the body (027, play-test 9: "arms go through other parts of the body"). Each
## arm is pushed straight out from the body, a step at a time, until no more than ARM_INSIDE of
## it lies inside the body's bounds (the shoulder may still sit in its socket), at most
## ARM_PUSH_MAX. Measured on the real geometry; cached per frame, arm and side.
static func _seat_arms(root: Node3D, chassis: Node3D, chassis_id: String) -> void:
	# 053: a generated frame's arm sockets are placed by hand on its own shoulders; pushing its
	# arms out of the body's box left them hanging in the air.
	if Models.part_path(chassis_id).contains("/parts_gen"):
		return
	var body := AABB()
	var legs: Array[AABB] = []
	var have_body: bool = false
	for slot: String in ["arm_l", "arm_r"]:
		var arm: Node3D = _find_named(root, "part_" + slot)
		if arm == null:
			continue
		var key: String = "%s|%s|%s|%s" % [chassis_id, String(arm.scene_file_path), slot, Models.part_path(chassis_id)]
		if not _arm_push.has(key):
			if not have_body:
				body = _body_bounds(chassis, root)
				legs = _leg_bounds(chassis, root)
				have_body = true
			var points: PackedVector3Array = _vertices(arm, root)
			var centre: Vector3 = body.get_center()
			var mean := Vector3.ZERO
			for v: Vector3 in points:
				mean += v
			mean /= float(maxi(1, points.size()))
			var out := Vector3(signf(mean.x - centre.x), 0, 0)
			if out.x == 0.0:
				out.x = 1.0 if slot == "arm_r" else -1.0
			var push: float = 0.0
			while push < ARM_PUSH_MAX and _inside_share(points, out * push, body, legs) > ARM_INSIDE:
				push += 0.01
			_arm_push[key] = out * push
		var offset: Vector3 = _arm_push[key]
		if offset != Vector3.ZERO:
			# The offset is in machine space; the arm hangs from a socket with its own turn.
			var parent_xf := Transform3D.IDENTITY
			var n: Node = arm.get_parent()
			while n != null and n != root:
				if n is Node3D:
					parent_xf = (n as Node3D).transform * parent_xf
				n = n.get_parent()
			arm.position += parent_xf.basis.inverse() * offset


## 043 (play-test 13: arms "go through the frame"): the legs count too -- a hammer hanging at the
## hip went through the thigh, which the body's bounds alone never saw.
static func _inside_share(points: PackedVector3Array, shift: Vector3, body: AABB, legs: Array[AABB] = []) -> float:
	var inside: int = 0
	for v: Vector3 in points:
		var p: Vector3 = v + shift
		if body.has_point(p) or legs.any(func(box: AABB) -> bool: return box.has_point(p)):
			inside += 1
	return float(inside) / float(maxi(1, points.size()))


## Each leg's bounds (its `limb_leg_*` node and everything under it), in `space`'s coordinates,
## shrunk a little like the body's.
static func _leg_bounds(chassis: Node3D, space: Node3D) -> Array[AABB]:
	var out: Array[AABB] = []
	var stack: Array[Node] = [chassis]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if String(node.name).begins_with("limb_leg"):
			var points: PackedVector3Array = _vertices(node, space)
			if not points.is_empty():
				var box := AABB(points[0], Vector3.ZERO)
				for v: Vector3 in points:
					box = box.expand(v)
				out.append(box.grow(-0.02))
			continue
		if not String(node.name).begins_with("part_") or node == chassis:
			stack.append_array(node.get_children())
	return out


## The share of a machine's arm geometry that sits inside its body (027, play-test 9: "arms go
## through other parts of the body"): arm vertices inside the bounds of the chassis without its
## legs, both arms together. For `tools/probe_arms.gd` and the seating below.
static func arm_intrusion(model: Node3D) -> float:
	var chassis: Node3D = model.get_node_or_null("part_chassis")
	if chassis == null:
		return 0.0
	var body: AABB = _body_bounds(chassis, model)
	var legs: Array[AABB] = _leg_bounds(chassis, model)
	var inside: int = 0
	var total: int = 0
	for slot: String in ["arm_l", "arm_r"]:
		var arm: Node3D = _find_named(model, "part_" + slot)
		if arm == null:
			continue
		for v: Vector3 in _vertices(arm, model):
			total += 1
			if body.has_point(v) or legs.any(func(box: AABB) -> bool: return box.has_point(v)):
				inside += 1
	return float(inside) / float(maxi(1, total))


## Bounds of a chassis's body -- every mesh but its legs -- in `space`'s coordinates, shrunk a
## little so a part merely touching the surface does not count as inside.
static func _body_bounds(chassis: Node3D, space: Node3D) -> AABB:
	var box := AABB()
	var first: bool = true
	for mesh: MeshInstance3D in _meshes(chassis):
		if _under_leg(mesh, chassis):
			continue
		for v: Vector3 in _vertices(mesh, space, false):
			if first:
				box = AABB(v, Vector3.ZERO)
				first = false
			else:
				box = box.expand(v)
	return box.grow(-0.02)


static func _under_leg(node: Node, top: Node) -> bool:
	var n: Node = node
	while n != null and n != top:
		# The legs, and every part bolted onto a socket (arms, core, module): not the body.
		if String(n.name).begins_with("limb_leg") or String(n.name).begins_with("part_"):
			return true
		n = n.get_parent()
	return false


## Every triangle corner of the meshes under `node` (or of `node` alone), in `space`'s coordinates
## -- composed from local transforms, so it works before the model is in a tree.
static func _vertices(node: Node, space: Node3D, deep: bool = true) -> PackedVector3Array:
	var out := PackedVector3Array()
	var meshes: Array[MeshInstance3D] = _meshes(node) if deep else ([node] as Array[MeshInstance3D] if node is MeshInstance3D else [] as Array[MeshInstance3D])
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var n: Node = mesh
		while n != null and n != space:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		for i: int in range(0, faces.size(), 3):
			out.append(xf * faces[i])
	return out


static func _find_named(node: Node, name: String) -> Node3D:
	if String(node.name) == name and node is Node3D:
		return node as Node3D
	for child: Node in node.get_children():
		var found: Node3D = _find_named(child, name)
		if found != null:
			return found
	return null


## Starts loading part models on background threads, so the first time a screen builds a
## machine it does not stall (play-test 4: the garage showed a black square for a second
## while its parts loaded). `_instance` collects them.
static func warm(part_ids: Array) -> void:
	for id: Variant in part_ids:
		var part_id: String = PartTuning.model_of(String(id))
		if part_id.is_empty() or _warming.has(part_id):
			continue
		var path: String = Models.part_path(part_id)
		if _scene_cache.has(path):
			continue
		if ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path) == OK:
			_warming[part_id] = path


## A machine's levels, bolted on where you can see them (play-test 4: levelling up did not
## sell the machine getting stronger). Each level adds to the last:
##   1: armour over both shoulders -- the biggest objects in the outline, so the first read;
##   2: a framed, bolted plate around the chest core;
##   3: exhaust stacks rising off the back, above the shoulder line.
## And the frame grows a little every level. Pieces use the machine's own zones and livery,
## are built on the CHASSIS from each socket's transform (valid before the model is in the
## tree), and carry `level_kit` metadata so a screen can make the newest ones arrive.
static func _level_kit(chassis: Node3D, sockets: Dictionary, level: int, livery: Color, team_colour: Color) -> void:
	chassis.scale *= 1.0 + LEVEL_SCALE * float(level)
	var paint: StandardMaterial3D = PartMaterials.for_zone("paint", team_colour, livery)
	var metal: StandardMaterial3D = PartMaterials.for_zone("metal", team_colour)
	var dark: StandardMaterial3D = PartMaterials.for_zone("dark", team_colour)
	var arm_l: Vector3 = _socket_origin(chassis, sockets.get("socket_arm_l"), Vector3(-0.16, 0.6, 0.0))
	var arm_r: Vector3 = _socket_origin(chassis, sockets.get("socket_arm_r"), Vector3(0.16, 0.6, 0.0))
	var core: Vector3 = _socket_origin(chassis, sockets.get("socket_core"), Vector3(0.0, 0.55, 0.1))
	var back: Vector3 = _socket_origin(chassis, sockets.get("socket_module"), Vector3(0.0, 0.53, -0.1))
	if level >= 1:
		for side: float in [-1.0, 1.0]:
			var at: Vector3 = arm_r if side > 0.0 else arm_l
			# Seated ON the shoulder, only slightly canted: perched high and tilted, a plate
			# reads as a wing (CLAUDE.md, pauldrons).
			var plate := _kit_box(Vector3(0.11, 0.03, 0.13), paint, 1)
			plate.position = at + Vector3(side * 0.022, 0.058, 0.0)
			plate.rotation.z = -side * 0.22
			chassis.add_child(plate)
			for z: float in [-0.04, 0.04]:
				var bolt := _kit_box(Vector3(0.016, 0.016, 0.016), dark, 1)
				bolt.position = at + Vector3(side * 0.035, 0.078, z)
				chassis.add_child(bolt)
	if level >= 2:
		for bar: Array in [[Vector3(0.17, 0.022, 0.02), Vector3(0, 0.08, 0)], [Vector3(0.17, 0.022, 0.02), Vector3(0, -0.08, 0)],
				[Vector3(0.022, 0.17, 0.02), Vector3(0.08, 0, 0)], [Vector3(0.022, 0.17, 0.02), Vector3(-0.08, 0, 0)]]:
			var frame := _kit_box(bar[0], metal, 2)
			frame.position = core + (bar[1] as Vector3) + Vector3(0, 0, 0.03)
			chassis.add_child(frame)
		for side: float in [-1.0, 1.0]:
			var cheek := _kit_box(Vector3(0.05, 0.15, 0.025), paint, 2)
			cheek.position = core + Vector3(side * 0.115, 0.0, 0.02)
			cheek.rotation.y = side * 0.5
			chassis.add_child(cheek)
	if level >= 3:
		for side: float in [-1.0, 1.0]:
			var stack := MeshInstance3D.new()
			var pipe := CylinderMesh.new()
			pipe.top_radius = 0.022
			pipe.bottom_radius = 0.028
			pipe.height = 0.26
			pipe.radial_segments = 10
			stack.mesh = pipe
			stack.material_override = dark
			stack.position = back + Vector3(side * 0.06, 0.16, -0.03)
			stack.rotation.x = -0.18
			stack.set_meta("level_kit", 3)
			chassis.add_child(stack)
			var cap := _kit_box(Vector3(0.06, 0.02, 0.06), metal, 3)
			cap.position = stack.position + Vector3(0, 0.13, -0.024)
			chassis.add_child(cap)


static func _kit_box(size: Vector3, material: Material, level: int) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	piece.mesh = box
	piece.material_override = material
	piece.set_meta("level_kit", level)
	return piece


## A socket's position in its chassis's space, from the transforms between them, so it can
## be read before the model is in the scene tree.
static func _socket_origin(chassis: Node3D, socket: Variant, fallback: Vector3) -> Vector3:
	if not (socket is Node3D):
		return fallback
	var xf := Transform3D.IDENTITY
	var node: Node = socket
	while node != null and node != chassis:
		if node is Node3D:
			xf = (node as Node3D).transform * xf
		node = node.get_parent()
	return xf.origin


## Height of the assembled model, so the health tag and floating text sit above it
## rather than at a guessed offset.
static func height_of(node: Node3D) -> float:
	var highest: float = 0.0
	for mesh: MeshInstance3D in _meshes(node):
		var aabb: AABB = mesh.get_aabb()
		var top: float = (mesh.global_transform * aabb).end.y if mesh.is_inside_tree() else aabb.end.y
		highest = maxf(highest, top)
	return maxf(0.8, highest)


# --- Internals ---------------------------------------------------------------

## The part to DRAW in a socket: a tuned part (`ar_hammer:a`, 011) is its base part's model,
## livery and all -- a tuning is a number, not a new machine.
static func _part_id(part_ids: PackedStringArray, index: int) -> String:
	if index >= part_ids.size():
		return ""
	return PartTuning.model_of(part_ids[index])


static func _instance(part_id: String) -> Node3D:
	if part_id.is_empty():
		return null
	# Which file is decided by `Models` (017: the shipped set, or the new one under proof).
	var path: String = Models.part_path(part_id)
	if not _scene_cache.has(path):
		if _warming.get(part_id, "") == path:
			# Already loading in the background: collect it (waits only if not yet done).
			_scene_cache[path] = ResourceLoader.load_threaded_get(path)
			_warming.erase(part_id)
		else:
			_scene_cache[path] = load(path) if ResourceLoader.exists(path) else null
	var packed: PackedScene = _scene_cache[path]
	if packed == null:
		return null
	return packed.instantiate() as Node3D


static func _find_sockets(node: Node) -> Dictionary:
	var found: Dictionary = {}
	for child: Node in node.get_children():
		if child.name.begins_with("socket_") and child is Node3D:
			found[String(child.name)] = child
		found.merge(_find_sockets(child))
	return found


## Every MeshInstance3D under a node. Public because the battlefield dresses terrain
## props the same way it dresses constructs, and two copies of a recursive walk is two
## places for the palette to be applied inconsistently.
static func meshes_of(node: Node) -> Array[MeshInstance3D]:
	return _meshes(node)


static func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		out.append_array(_meshes(child))
	return out


## Applies the Rust & Sodium palette to every mesh under a node, one surface at a time.
##
## Each surface carries a zone name from the generator (`mat_paint`, `mat_metal`, ...),
## and only `paint` takes the team colour -- so a construct reads as a weathered machine
## wearing team livery rather than as a solid block of team colour.
##
## This is deliberately a per-SURFACE override, not `material_override`. An override
## replaces the whole mesh's material and was flattening every part to one colour,
## discarding the bevels, ribs, pistons and vents the generator exists to produce.
static func _tint(node: Node, colour: Color, livery: Color) -> void:
	for mesh: MeshInstance3D in _meshes(node):
		var surfaces: int = mesh.mesh.get_surface_count() if mesh.mesh != null else 0
		for surface: int in surfaces:
			var zone: String = PartMaterials.zone_of(mesh.mesh.surface_get_material(surface))
			mesh.set_surface_override_material(surface,
				PartMaterials.for_zone(zone, colour, livery))


static func _fallback_body(colour: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 1.0, 0.7)
	mesh.mesh = box
	mesh.position = Vector3(0, 0.5, 0)
	mesh.material_override = PartMaterials.for_zone(PartMaterials.ZONE_PAINT, colour)
	return mesh
