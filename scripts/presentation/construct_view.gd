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
	var root := Node3D.new()

	var chassis_id: String = _part_id(unit, 0)
	var chassis: Node3D = _instance(chassis_id)
	if chassis == null:
		root.add_child(_fallback_body(team_colour))
		return root

	root.add_child(chassis)
	_tint(chassis, team_colour, PartMaterials.livery_of(chassis_id))

	var sockets: Dictionary = _find_sockets(chassis)
	var loadout: Dictionary = {
		"core": _part_id(unit, 1),
		"arm_l": _part_id(unit, 2),
		"arm_r": _part_id(unit, 3),
		"module": _part_id(unit, 4),
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

	return root


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

static func _part_id(unit: SimUnit, index: int) -> String:
	if index >= unit.part_ids.size():
		return ""
	return unit.part_ids[index]


static func _instance(part_id: String) -> Node3D:
	if part_id.is_empty():
		return null
	if not _scene_cache.has(part_id):
		var path: String = "%s/%s.glb" % [PARTS_DIR, part_id]
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
