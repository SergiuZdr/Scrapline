class_name Ink
extends RefCounted

## Ink & Rust (015): the look of the fight, from one place -- the palette, the toon and ink
## materials, and the dressing that turns anything built for the old look into a drawing.
##
## The style (docs/plans/art-direction-options.md, option A): flat colour, heavy black ink,
## one hard light. Readability first: every colour below either names a material or is a
## SIGNAL with one meaning (art-and-audio.md, the registry), and every object has a line.
##
## `ConstructView` and `PartMaterials` are untouched: a machine is built as before and then
## DRESSED here by its zones (`mat_<zone>`), so the other screens keep their look until the
## frame is approved and the rest of the game follows.

# --- The palette ----------------------------------------------------------------
const INK := Color("14110f")
const PAPER := Color("efe3c8")
const PAPER_CARD := Color("f7efdc")
const RUST := Color("b4532a")
const MUSTARD := Color("d9a441")
const OXIDE := Color("9c3b2e")
const OLIVE := Color("6e7443")
const STEEL := Color("7d8a8f")
const NIGHT := Color("1b2233")
const BOARD := Color("1f2024")
const BOARD_ALT := Color("242529")

# --- Signals: one meaning each (art-and-audio.md) --------------------------------
const YOURS := Color("33c8e0")
const DANGER := Color("ff3b30")
const ACTION := Color("ffc43d")
const GAIN := Color("8edb4a")
const BUILT := Color("a070e0")

# --- Line weights, in pixels at 1080 lines. Three, and only three: a line that varies
# from object to object is the fastest way for ink to look cheap (the plan's one risk).
const LINE_WORLD: float = 1.6   ## Ground, scenery, terrain.
const LINE_MACHINE: float = 2.2 ## Machines: the silhouettes the player reads.
const LINE_ACT: float = 3.0     ## Things you can act on: drums, piles, pylons, crates.

## A part's livery in ink, indexed exactly like `PartMaterials.LIVERY`, so a part keeps its
## colour identity (a Brute's frame is the same "yellow" it always was, now flat mustard).
const LIVERY: Array[Color] = [Color("d9a441"), Color("9c3b2e"), Color("6e7443"), Color("8a8f8c"), Color("b4532a")]

## Structure zones: [colour, highlight stripe]. Mechanism goes dark so livery and aluminium
## carry the machine's light values.
const ZONES: Dictionary = {
	"metal": [Color("5f6468"), 0.28],
	"alu": [Color("c9c4b8"), 0.45],
	"rust": [Color("7a3b20"), 0.0],
	"dark": [Color("3a3638"), 0.0],
	"tread": [Color("1f1d1c"), 0.0],
	"hazard": [Color("d9a02b"), 0.0],
	"rock": [Color("34353a"), 0.0],
	"scrapmetal": [Color("3f3c39"), 0.0],
}

## Damage-type lens colours and lamps: kept from the registry, flat and unshaded.
const GLOWS: Dictionary = {
	"glow_lamp": Color("ffe3b0"),
	"glow_kinetic": Color("efeae0"),
	"glow_thermal": Color("ff7a2e"),
	"glow_emp": Color("4fd2ff"),
	"glow_corrosive": Color("9be04a"),
}

const TOON := preload("res://scripts/presentation/ink_toon.gdshader")
const OUTLINE := preload("res://scripts/presentation/ink_outline.gdshader")
const MARK := preload("res://scripts/presentation/ink_mark.gdshader")

static var _materials: Dictionary = {}
static var _hulls: Dictionary = {}


## A flat-colour toon material. `kind`: "matte", "metal" (a hard highlight stripe), "clean"
## (no halftone: machines, where dots would be noise at 40 px), or "flat" (no light at all).
static func toon(colour: Color, kind: String = "matte", stripe: float = -1.0) -> ShaderMaterial:
	var key: String = "toon:%s:%s:%.2f" % [colour.to_html(), kind, stripe]
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = TOON
	m.set_shader_parameter("albedo", colour)
	m.set_shader_parameter("halftone", 0.0 if kind == "clean" or kind == "metal" else 1.0)
	m.set_shader_parameter("stripe", maxf(stripe, 0.0) if stripe >= 0.0 else (0.3 if kind == "metal" else 0.0))
	_materials[key] = m
	return m


## A toon material with a pattern drawn on it in world space (1 stipple, 2 hatching).
static func patterned(colour: Color, pattern: int, ink_colour: Color, scale: float, amount: float) -> ShaderMaterial:
	var key: String = "pat:%s:%d:%s:%.2f:%.2f" % [colour.to_html(), pattern, ink_colour.to_html(), scale, amount]
	if _materials.has(key):
		return _materials[key]
	var m: ShaderMaterial = toon(colour).duplicate()
	m.set_shader_parameter("pattern", pattern)
	m.set_shader_parameter("pattern_colour", ink_colour)
	m.set_shader_parameter("pattern_scale", scale)
	m.set_shader_parameter("pattern_amount", amount)
	_materials[key] = m
	return m


## A toon material over a texture (a drum's painted band), tinted by `colour`.
static func textured(texture: Texture2D, colour: Color = Color.WHITE) -> ShaderMaterial:
	var key: String = "tex:%d:%s" % [texture.get_instance_id(), colour.to_html()]
	if _materials.has(key):
		return _materials[key]
	var m: ShaderMaterial = toon(colour).duplicate()
	m.set_shader_parameter("use_tex", true)
	m.set_shader_parameter("albedo_tex", texture)
	m.set_shader_parameter("halftone", 0.0)
	_materials[key] = m
	return m


## Keeps one copy of a short-lived material alive for the session, per set of shader features
## (play-test 7). Godot builds ONE shader for every StandardMaterial3D with the same features and
## frees it with the last of them, so a tracer whose material died with it compiled its shader
## again on the next shot: on this Mac's GL driver, a half-second freeze on every attack.
## Wrap any material an effect makes and throws away: `x.material_override = Ink.hold(m)`.
static var _held: Dictionary = {}


static func hold(m: BaseMaterial3D) -> BaseMaterial3D:
	var key: String = str([m.shading_mode, m.transparency, m.blend_mode, m.billboard_mode, m.billboard_keep_scale,
		m.emission_enabled, m.vertex_color_use_as_albedo, m.albedo_texture != null, m.no_depth_test,
		m.disable_receive_shadows, m.cull_mode, m.depth_draw_mode, m.metallic > 0.0, m.roughness < 1.0])
	if not _held.has(key):
		var copy: BaseMaterial3D = m.duplicate()
		# Asking for the RID builds the copy's shader now; a copy that is never drawn and never
		# asked holds nothing (measured: 300 ms a tracer either way until this line).
		copy.get_rid()
		_held[key] = copy
	return m


## A signal: flat, unlit, and the only thing allowed to bloom.
static func glow(colour: Color, energy: float = 1.4) -> StandardMaterial3D:
	var key: String = "glow:%s:%.2f" % [colour.to_html(), energy]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = colour
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = energy
	_materials[key] = m
	return m


## Flat, unlit, no bloom: paper rims, ink holes.
static func flat(colour: Color) -> StandardMaterial3D:
	return glow(colour, 0.0)


## Flat and drawn over everything: a route's dots must show on a pile, not under it.
static func on_top(colour: Color) -> StandardMaterial3D:
	var key: String = "top:%s" % colour.to_html()
	if _materials.has(key):
		return _materials[key]
	var m: StandardMaterial3D = flat(colour).duplicate()
	m.no_depth_test = true
	m.render_priority = 2
	_materials[key] = m
	return m


## The ink line, as a `material_overlay`.
static func outline(width: float, colour: Color = INK) -> ShaderMaterial:
	var key: String = "line:%.2f:%s" % [width, colour.to_html()]
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = OUTLINE
	m.set_shader_parameter("width_px", width)
	m.set_shader_parameter("ink", colour)
	_materials[key] = m
	return m


## A board mark's material (one per hex quad: `_mark` recolours it).
static func mark_material(radius: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = MARK
	m.set_shader_parameter("radius", radius)
	m.render_priority = 1
	return m


## Draws `mesh` with an ink line: swaps in the hull-ready copy (smoothed normals in UV2)
## and sets the outline overlay. Surface overrides are kept.
static func line(mesh: MeshInstance3D, width: float, colour: Color = INK) -> void:
	if mesh.mesh == null:
		return
	var overrides: Array = []
	for i: int in mesh.get_surface_override_material_count():
		overrides.append(mesh.get_surface_override_material(i))
	mesh.mesh = hull_mesh(mesh.mesh)
	for i: int in overrides.size():
		mesh.set_surface_override_material(i, overrides[i])
	mesh.material_overlay = outline(width, colour)


## Every MeshInstance3D under `node`: `material` on all surfaces, and a line.
static func paint(node: Node, material: Material, width: float = LINE_WORLD, colour: Color = INK) -> void:
	for mesh: MeshInstance3D in ConstructView.meshes_of(node):
		mesh.material_override = material
		line(mesh, width, colour)


## A copy of `mesh` whose UV2 holds each vertex's SMOOTHED normal (octahedral): the average
## of every face normal meeting at that position. Cached per mesh, so a roster of forty parts
## is prepared once per session.
static func hull_mesh(mesh: Mesh) -> ArrayMesh:
	# Imported parts are shared by every machine that carries them: cache those. A primitive
	# built in code is usually one of a kind, and caching it would only grow the table.
	var shared: bool = mesh is ArrayMesh
	var key: int = mesh.get_instance_id()
	if shared and _hulls.has(key):
		return _hulls[key]
	var out := ArrayMesh.new()
	for s: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var sums: Dictionary = {}
		for i: int in verts.size():
			var k: Vector3i = Vector3i((verts[i] * 4000.0).round())
			sums[k] = (sums.get(k, Vector3.ZERO) as Vector3) + (normals[i] if i < normals.size() else Vector3.UP)
		var packed := PackedVector2Array()
		packed.resize(verts.size())
		for i: int in verts.size():
			var n: Vector3 = sums[Vector3i((verts[i] * 4000.0).round())]
			if n.length_squared() < 0.000001:
				n = normals[i] if i < normals.size() else Vector3.UP
			packed[i] = _oct(n.normalized())
		arrays[Mesh.ARRAY_TEX_UV2] = packed
		var primitive: int = (mesh as ArrayMesh).surface_get_primitive_type(s) if shared else Mesh.PRIMITIVE_TRIANGLES
		out.add_surface_from_arrays(primitive, arrays)
		out.surface_set_material(s, mesh.surface_get_material(s))
	if shared:
		_hulls[key] = out
	return out


static func _oct(n: Vector3) -> Vector2:
	var d: float = absf(n.x) + absf(n.y) + absf(n.z)
	var p := Vector2(n.x / d, n.y / d)
	if n.z < 0.0:
		p = Vector2((1.0 - absf(p.y)) * (1.0 if p.x >= 0.0 else -1.0), (1.0 - absf(p.x)) * (1.0 if p.y >= 0.0 else -1.0))
	return p * 0.5 + Vector2(0.5, 0.5)


## 018 (proposal, `--models new` only): livery by maker, [livery, accent]. Kessler Mining is the
## concept Brute's yellow with orange trim; a maker SET (011) shows at a glance.
const MAKER_LIVERY: Dictionary = {
	"kessler": [Color("d9a441"), Color("c8602a")],
	"cinder": [Color("9c3b2e"), Color("d9a441")],
	"vektor": [Color("6e7443"), Color("c9b27a")],
	"arclight": [Color("8a8f8c"), Color("b4532a")],
}


## The colour of a scavenged plate on a part of this livery: another maker's paint, faded.
static func patch_of(livery: Color) -> Color:
	var makers: Array = MAKER_LIVERY.values()
	for i: int in makers.size():
		if (makers[i][0] as Color).is_equal_approx(livery):
			return (makers[(i + 2) % makers.size()][0] as Color).lerp(Color("8a8f8c"), 0.25)
	return Color("6e7443")


## The accent a livery's `trim` zone wears: its maker's, or a fixed partner for the old liveries.
static func accent_of(livery: Color) -> Color:
	for pair: Array in MAKER_LIVERY.values():
		if (pair[0] as Color).is_equal_approx(livery):
			return pair[1]
	return Color("c8602a") if livery.is_equal_approx(LIVERY[0]) else Color("d9a441")


## The ink livery of a part: the same index `PartMaterials.livery_of` picks.
static func livery_of(part_id: String) -> Color:
	# 018, only with `--models new`: a part wears its MAKER's colour (a proposal to judge).
	var maker: String = Models.maker_of(part_id)
	if MAKER_LIVERY.has(maker):
		return MAKER_LIVERY[maker][0]
	var old: Color = PartMaterials.livery_of(part_id)
	for i: int in PartMaterials.LIVERY.size():
		if Color(PartMaterials.LIVERY[i]).is_equal_approx(old):
			return LIVERY[i]
	return LIVERY[0]


## The material for one zone of a machine. Structure (`metal`) wears its part's livery a
## shade darker: in flat colour a machine is read by its colour families, and grey limbs under
## a painted chest made every machine the same grey figure (the first frame showed it).
static func zone_material(zone: String, livery: Color, team: Color) -> Material:
	if zone == PartMaterials.ZONE_PAINT:
		return toon(livery, "clean")
	if zone == "steel":
		# Neutral structure (018): NOT tinted by the livery, so a part shows a second colour.
		return toon(Color("7d848c"), "metal", 0.22)
	if zone == "trim":
		return toon(accent_of(livery), "clean")
	if zone == "patch":
		# A plate scavenged from another machine (019): never the part's own livery.
		return toon(patch_of(livery), "clean")
	if zone == "metal":
		return toon(livery.darkened(0.12).lerp(Color("6a6f76"), 0.18), "metal", 0.16)
	if PartMaterials.TEAM_ZONES.has(zone):
		return glow(team, 1.6)
	if zone.begins_with("glow"):
		return glow(GLOWS.get(zone, PAPER), 1.2)
	var z: Array = ZONES.get(zone, ZONES["metal"])
	return toon(z[0], "metal" if float(z[1]) > 0.0 else "clean", float(z[1]))


## Dresses a machine built by `ConstructView.build_parts`: every surface by its zone and its
## part's livery, the level kit by the material it was given, and a line on everything.
static func dress_machine(model: Node3D, part_ids: PackedStringArray, team: Color) -> void:
	var slots: Dictionary = {"part_chassis": 0, "part_core": 1, "part_arm_l": 2, "part_arm_r": 3, "part_module": 4}
	var chassis_id: String = PartTuning.base_of(part_ids[0]) if part_ids.size() > 0 else ""
	# The level kit is built from PartMaterials' cached zone materials: map them back.
	var kit: Dictionary = {}
	for zone: String in ["metal", "dark"]:
		kit[PartMaterials.for_zone(zone, team)] = zone
	kit[PartMaterials.for_zone("paint", team, PartMaterials.livery_of(chassis_id))] = "paint"
	_dress_node(model, "", slots, part_ids, team, kit)


static func _dress_node(node: Node, part_id: String, slots: Dictionary, part_ids: PackedStringArray,
		team: Color, kit: Dictionary) -> void:
	var here: String = part_id
	if slots.has(String(node.name)):
		var index: int = int(slots[String(node.name)])
		here = PartTuning.base_of(part_ids[index]) if index < part_ids.size() else ""
	if node is MeshInstance3D:
		var mesh: MeshInstance3D = node
		var livery: Color = livery_of(here)
		if mesh.material_override != null:
			mesh.material_override = zone_material(String(kit.get(mesh.material_override, "metal")), livery, team)
		elif mesh.mesh != null:
			for s: int in mesh.mesh.get_surface_count():
				var zone: String = PartMaterials.zone_of(mesh.mesh.surface_get_material(s))
				mesh.set_surface_override_material(s, zone_material(zone, livery, team))
		line(mesh, LINE_MACHINE)
	for child: Node in node.get_children():
		_dress_node(child, here, slots, part_ids, team, kit)


## Scenery (the arena kit): pushed down into the night, a thinner line, lamps kept lit.
static func dress_scenery(node: Node, dim: float = 0.45) -> void:
	for mesh: MeshInstance3D in ConstructView.meshes_of(node):
		if mesh.mesh == null:
			continue
		for s: int in mesh.mesh.get_surface_count():
			var zone: String = PartMaterials.zone_of(mesh.mesh.surface_get_material(s))
			var m: Material
			if zone.begins_with("glow"):
				m = flat(GLOWS.get(zone, PAPER).darkened(0.2))
			else:
				# Monochrome: scenery is never allowed a signal's hue (a red container read as
				# danger in the first frame).
				var grey: float = (ZONES.get(zone, ZONES["metal"])[0] as Color).get_luminance()
				m = toon(Color(grey, grey, grey).lerp(NIGHT, dim), "matte")
			mesh.set_surface_override_material(s, m)
		line(mesh, LINE_WORLD * 0.8, INK)


## The ink world's environment (016): a flat night ambient (the shadow band is albedo times
## this), no sky, a linear tonemap so a palette colour lands as itself, glow only on signals.
## Every 3D screen uses it, so a machine looks the same in the garage, on the map and in a fight.
static func environment(background: Color = Color("11141c")) -> Environment:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = background
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("6b7390")
	e.ambient_light_energy = 1.0
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.glow_enabled = true
	e.glow_intensity = 0.35
	e.glow_bloom = 0.0
	e.glow_hdr_threshold = 1.05
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	return e


## The ink world's one light: a hard key. The toon ramp draws with the DIRECTIONAL light only,
## so a scene lit by spots or omnis renders its machines as ambient alone.
static func key_light(rotation: Vector3 = Vector3(-40, -38, 0), shadow_distance: float = 40.0) -> DirectionalLight3D:
	var key := DirectionalLight3D.new()
	key.rotation_degrees = rotation
	key.light_energy = 1.0
	key.light_color = Color("fff0da")
	key.shadow_enabled = true
	key.shadow_blur = 0.0
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = shadow_distance
	key.shadow_bias = 0.03
	key.shadow_normal_bias = 1.2
	return key


## A LANDMARK (016): a kit prop that is a place you can go, drawn in its zones' own colours --
## `livery` on its painted panels -- with a line. Unlike scenery it keeps its hue: a map is
## read by what stands on the sites.
static func dress_prop(node: Node, livery: Color, width: float = LINE_WORLD) -> void:
	for mesh: MeshInstance3D in ConstructView.meshes_of(node):
		if mesh.mesh == null:
			continue
		for s: int in mesh.mesh.get_surface_count():
			var zone: String = PartMaterials.zone_of(mesh.mesh.surface_get_material(s))
			var m: Material
			if zone.begins_with("glow"):
				m = glow(GLOWS.get(zone, PAPER), 0.9)
			elif zone == PartMaterials.ZONE_PAINT:
				m = toon(livery)
			else:
				m = toon((ZONES.get(zone, ZONES["metal"])[0] as Color).lightened(0.12))
			mesh.set_surface_override_material(s, m)
		line(mesh, width)


## A generated set piece (017/018, `Models.site`): a surface that brought its own texture keeps
## it under the toon ramp (`textured`); one that was zoned is dressed like the kit. One line.
static func dress_set_piece(node: Node, livery: Color, width: float = LINE_WORLD) -> void:
	var textured_any: bool = false
	for mesh: MeshInstance3D in ConstructView.meshes_of(node):
		if mesh.mesh == null:
			continue
		for s: int in mesh.mesh.get_surface_count():
			var source: BaseMaterial3D = mesh.mesh.surface_get_material(s) as BaseMaterial3D
			if source != null and source.albedo_texture != null:
				mesh.set_surface_override_material(s, textured(source.albedo_texture))
				textured_any = true
		if textured_any:
			line(mesh, width)
	if not textured_any:
		dress_prop(node, livery, width)


## A texture drawn in code, cached by name. `draw` fills a blank Image of `size`.
static var _textures: Dictionary = {}


static func texture(name: String, size: Vector2i, draw: Callable) -> ImageTexture:
	if _textures.has(name):
		return _textures[name]
	var image := Image.create(size.x, size.y, true, Image.FORMAT_RGBA8)
	draw.call(image)
	image.generate_mipmaps()
	var t := ImageTexture.create_from_image(image)
	_textures[name] = t
	return t
