class_name Surfaces
extends RefCounted

## Every non-machine surface in the game, from one place: photographed PBR sets from Poly
## Haven (see `docs/plans/art-sourcing.md`) and the arena kit, both pushed through the
## palette before anything is drawn with them.
##
## Two rules from the art spike live here, so no call site can forget them:
##   - **Tinted, always.** A Poly Haven set is a photograph with its own colours; it is
##     multiplied by a tint from our palette and kept BELOW the machines in value.
##   - **Triplanar.** None of our generated geometry has UVs, so textures are projected
##     in world space; the scale says how many metres one tile of texture covers.

const PH := "res://art/thirdparty/polyhaven/textures/"

static var _materials: Dictionary = {}
static var _scenes: Dictionary = {}


## A photographed surface, tinted. `set` is the Poly Haven id (e.g. "asphalt_02");
## `scale` is texture repeats per metre.
static func pbr(set: String, tint: Color, scale: float = 0.5, metallic: float = 0.0,
		normal_strength: float = 1.0) -> StandardMaterial3D:
	var key: String = "%s:%s:%.3f:%.2f:%.2f" % [set, tint.to_html(), scale, metallic, normal_strength]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	var base: String = PH + set + "/" + set
	m.albedo_texture = _texture(base + "_diff_1k.jpg")
	m.albedo_color = tint
	var normal: Texture2D = _texture(base + "_nor_gl_1k.jpg")
	if normal != null:
		m.normal_enabled = true
		m.normal_texture = normal
		m.normal_scale = normal_strength
	var rough: Texture2D = _texture(base + "_rough_1k.jpg")
	if rough != null:
		m.roughness_texture = rough
	m.roughness = 1.0
	m.metallic = metallic
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	_materials[key] = m
	return m


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


static func _texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path)


static func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	return _scenes[path]
