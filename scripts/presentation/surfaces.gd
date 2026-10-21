class_name Surfaces
extends RefCounted

## The arena kit, from one place: every prop pushed through the palette and kept BELOW
## the machines in value before anything is drawn with it.

static var _materials: Dictionary = {}
static var _scenes: Dictionary = {}
## 081: the generated yard pieces (`art/props/yd_<name>.glb`, `Models.prop`) that stand in for kit
## pieces. Both containers have their own; the car and tyre stacks and barriers share one each.
const GENERATED: Dictionary = {
	"container_0": "yd_container_0", "container_1": "yd_container_1",
	"car_stack_0": "yd_car_stack", "car_stack_1": "yd_car_stack", "car_stack_2": "yd_car_stack",
	"tyre_stack_0": "yd_tyre_stack", "tyre_stack_1": "yd_tyre_stack", "tyre_stack_2": "yd_tyre_stack",
	"barrier_0": "yd_barrier", "barrier_1": "yd_barrier",
	"floodlight": "yd_floodlight", "gantry": "yd_gantry", "service_gantry": "yd_service_gantry",
}


## An arena-kit prop (`art/arena/<name>.glb`) dressed in the palette and pushed down in
## value by `dim` (lamps exempt), so scenery never out-shines the machines.
static func kit(name: String, dim: float = 0.12) -> Node3D:
	var generated: PackedScene = Models.prop(String(GENERATED[name])) if GENERATED.has(name) else null
	if generated != null:
		# Textured: `Ink.dress_scenery` darkens its own texture, no zones to paint.
		return generated.instantiate() as Node3D
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
