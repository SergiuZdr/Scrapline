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
static func build_parts(part_ids: PackedStringArray, _content: ContentDB, team_colour: Color, level: int = 0,
		number: int = -1) -> Node3D:
	var root := Node3D.new()

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
			piece.rotation = Vector3(ARM_CANT, outward, 0.0)
		if slot == "arm_l":
			# Mirrored so the pair reads as a left and a right arm rather than two
			# identical ones pointing the same way. Applied after the rotation, because
			# a negative scale flips the handedness of any rotation set on top of it.
			piece.scale = Vector3(-1, 1, 1)
		# The core goes through the palette like everything else. Its damage-type colour
		# now lives on the LENS zone alone, so the housing around it can be plain metal
		# instead of the whole reactor glowing and washing the signal out.
		_tint(piece, team_colour, PartMaterials.livery_of(part_id))

	if level > 0:
		_level_kit(chassis, sockets, level, PartMaterials.livery_of(chassis_id), team_colour)
	if number >= 0:
		var core_socket: Node3D = sockets.get(SOCKETS["core"])
		if core_socket != null and core_socket.get_child_count() > 0:
			_stencil(core_socket.get_child(core_socket.get_child_count() - 1) as Node3D, number)
	return root


## A stencilled two-digit number (art/reference: "the cheapest per-machine identity on the
## sheet, and it survives any distance"), painted on the top-left of the core's front plate
## -- the one flat face every machine is guaranteed to show, clear of the lens. Placed
## from the core mesh's own bounds, so it sits ON the plate whatever core is fitted.
static func _stencil(core: Node3D, number: int) -> void:
	var bounds := AABB()
	var first: bool = true
	for mesh: MeshInstance3D in _meshes(core):
		if mesh.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var node: Node = mesh
		while node != null and node != core:
			if node is Node3D:
				xf = (node as Node3D).transform * xf
			node = node.get_parent()
		var box: AABB = xf * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if first:
		return
	var label := Label3D.new()
	label.text = "%02d" % (number % 100)
	label.font = UIKit.font_display()
	label.font_size = 64
	label.pixel_size = bounds.size.y * 0.0092
	label.shaded = true
	label.double_sided = false
	label.modulate = Color(0.07, 0.06, 0.05, 0.9)
	label.outline_size = 0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.position = Vector3(bounds.position.x + bounds.size.x * 0.06, bounds.end.y - bounds.size.y * 0.05, bounds.end.z + 0.002)
	core.add_child(label)


## Starts loading part models on background threads, so the first time a screen builds a
## machine it does not stall (play-test 4: the garage showed a black square for a second
## while its parts loaded). `_instance` collects them.
static func warm(part_ids: Array) -> void:
	for id: Variant in part_ids:
		var part_id: String = String(id)
		if part_id.is_empty() or _scene_cache.has(part_id) or _warming.has(part_id):
			continue
		var path: String = "%s/%s.glb" % [PARTS_DIR, part_id]
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

static func _part_id(part_ids: PackedStringArray, index: int) -> String:
	if index >= part_ids.size():
		return ""
	return part_ids[index]


static func _instance(part_id: String) -> Node3D:
	if part_id.is_empty():
		return null
	if not _scene_cache.has(part_id):
		var path: String = "%s/%s.glb" % [PARTS_DIR, part_id]
		if _warming.has(part_id):
			# Already loading in the background: collect it (waits only if not yet done).
			_scene_cache[part_id] = ResourceLoader.load_threaded_get(path)
			_warming.erase(part_id)
		else:
			_scene_cache[part_id] = load(path) if ResourceLoader.exists(path) else null
	var packed: PackedScene = _scene_cache[part_id]
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
