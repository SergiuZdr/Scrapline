class_name Surfaces
extends RefCounted

## The arena kit, from one place: every prop pushed through the palette and kept BELOW
## the machines in value before anything is drawn with it.

static var _materials: Dictionary = {}
static var _scenes: Dictionary = {}


## An arena-kit prop (`art/arena/<name>.glb`) dressed in the palette and pushed down in
## value by `dim` (lamps exempt), so scenery never out-shines the machines.
static func kit(name: String, dim: float = 0.12) -> Node3D:
	var packed: PackedScene = _scene("res://art/arena/%s.glb" % name)
	if packed == null:
		return null
	var prop: Node3D = packed.instantiate() as Node3D
	for mesh: MeshInstance3D in ConstructView.meshes_of(prop):
		if mesh.mesh == null:
			continue
		for surface: int in mesh.mesh.get_surface_count():
			var zone: String = PartMaterials.zone_of(mesh.mesh.surface_get_material(surface))
			mesh.set_surface_override_material(surface, kit_material(zone, dim))
	return prop


static func kit_material(zone: String, dim: float) -> StandardMaterial3D:
	var key: String = "kit:%s:%.2f" % [zone, dim]
	if _materials.has(key):
		return _materials[key]
	var source: StandardMaterial3D = PartMaterials.for_zone(zone, Color("7f8a99"))
	var material: StandardMaterial3D = source
	if not zone.begins_with("glow") and dim > 0.0:
		material = source.duplicate()
		material.albedo_color = source.albedo_color.darkened(dim)
		material.rim_enabled = false
	_materials[key] = material
	return material


static func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	return _scenes[path]
