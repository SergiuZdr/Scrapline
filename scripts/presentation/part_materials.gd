class_name PartMaterials
extends RefCounted

## The Rust & Sodium palette: turns a zone name baked into a part's `.glb` into the
## real material the battlefield renders.
##
## `tools/blender/make_parts.py` tags every piece of every part with a ZONE rather than
## a colour, and the zone survives into the mesh as a material named `mat_<zone>`. This
## file is the other half of that contract, and it is deliberately the only place the
## look of a construct is decided.
##
## Why the indirection is worth a file of its own:
##
## * **Retuning is one edit.** Making worn metal a shade colder across a forty-part
##   roster happens here, not in forty Blender re-exports.
## * **Only `paint` is team-tinted.** Everything else keeps its own material. The old
##   code applied one flat `material_override` to every mesh in a construct, which threw
##   away every bevel, rib, piston and vent the generator builds -- twelve machines on
##   the field rendered as twelve monochrome silhouettes in red and blue, and no player
##   could tell a Brute Frame from a Strider.
## * **`hazard` means one thing.** Warning ochre appears on overdrive modules and
##   nowhere else, so "this construct explodes" stays readable as a colour.
##
## Materials are cached per (zone, tint), so a twelve-construct battle allocates a
## handful of materials rather than one per mesh surface.

## Painted armour. The only zone that takes the team colour.
const ZONE_PAINT: String = "paint"

## Authored in sRGB hex to match `ZONE_COLOURS` in `make_parts.py`. If a value changes
## in one place it should change in both, but only this one reaches the screen.
const ZONE_ALBEDO: Dictionary = {
	"metal": "8a8074",
	"rust": "8c4a26",
	"dark": "3c3c45",
	"tread": "2a2825",
	"hazard": "d9a02b",
	# Arena kit. Concrete, sheet steel, and the floodlamps that are the diegetic source
	# of the battlefield's warm key light.
	"rock": "342d24",
	"scrapmetal": "4a4036",
	"glow_lamp": "ffd79a",
	"glow_visor": "ffb24a",
	"glow_kinetic": "dbd6c9",
	"glow_thermal": "ff6b23",
	"glow_emp": "42c2ff",
	"glow_corrosive": "8fdb38",
}

## roughness, metallic. Painted plate is rough and barely metallic; bare structure is
## smoother and very metallic; rust is almost fully diffuse. That spread is what makes
## the sodium key light land differently on each zone, which is the entire read.
const ZONE_SURFACE: Dictionary = {
	"paint": Vector2(0.62, 0.05),
	"metal": Vector2(0.52, 0.88),
	"rust": Vector2(0.92, 0.10),
	"dark": Vector2(0.58, 0.70),
	"tread": Vector2(0.95, 0.00),
	"hazard": Vector2(0.60, 0.10),
	# Concrete is fully diffuse; sheet steel is rougher and less metallic than a
	# construct's machined plate, so the arena never out-shines the machines in it.
	"rock": Vector2(0.98, 0.00),
	"scrapmetal": Vector2(0.78, 0.45),
}

const GLOW_ENERGY: float = 1.8

## Worn liveries, straight off the reference sheets in `art/reference/`.
##
## **Paint no longer carries the team.** The reference machines are scrapyard salvage
## wearing whatever paint they were built with -- construction yellow, oxide red, olive,
## primer grey -- all of it chipped. Forcing that surface to also answer "whose is it"
## is what made every construct a flat block of UI blue or UI red and threw the whole
## palette away. Team identity moved to markers that do nothing else (see `TEAM_ZONES`),
## which is both more legible at distance and frees the roster to look like junk.
const LIVERY: PackedStringArray = [
	"b08a2c",  # worn construction yellow
	"8e3a28",  # worn oxide red
	"55603c",  # worn olive
	"7d7266",  # primer grey
	"9a5a24",  # worn orange
]

## Zones whose colour IS the team, and which therefore may never be used for decoration.
##
## The eye is the primary read: it is emissive, it sits at the highest point of the
## machine, and it is the one surface that faces whoever the construct is fighting. A
## painted panel can be turned away from the camera; a lit eye in a dark yard cannot be
## mistaken for anything else.
const TEAM_ZONES: PackedStringArray = ["glow_visor"]


## The livery a part wears, chosen from its id so a Brute is the same colour in every
## build, in the garage and in the fight.
static func livery_of(part_id: String) -> Color:
	var h: int = 2166136261
	for index: int in part_id.length():
		h = (h ^ part_id.unicode_at(index)) * 16777619
		h &= 0xffffffff
	return Color(LIVERY[h % LIVERY.size()])

static var _cache: Dictionary = {}
static var _wear: NoiseTexture2D


## The wear mask: blotchy, mostly bright, with darker patches where paint has gone.
##
## Multiplied into the livery, so bright means intact paint and dark means worn through.
## Generated rather than shipped -- it is noise, and an asset would be a licence and a
## file for something four lines of code describe exactly.
static func _wear_texture() -> NoiseTexture2D:
	if _wear != null:
		return _wear
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	# Fine and busy. At 0.035 the blotches came out panel-sized and evenly split between
	# painted and worn, which reads as CAMOUFLAGE -- a completely different machine, and
	# the exact trap the ramp below is biased against.
	noise.frequency = 0.12
	noise.fractal_octaves = 5
	noise.fractal_gain = 0.62
	_wear = NoiseTexture2D.new()
	_wear.noise = noise
	_wear.width = 256
	_wear.height = 256
	_wear.seamless = true
	# Biased bright: most of a panel is still painted. A 50/50 mask reads as camouflage
	# rather than as wear, which is a completely different machine.
	var ramp := Gradient.new()
	# Heavily biased toward intact paint: only the darkest fifth of the noise shows as
	# worn-through metal, and even that is a knock-down rather than a hole.
	ramp.offsets = PackedFloat32Array([0.0, 0.20, 0.38, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.42, 0.38, 0.34),
		Color(0.72, 0.68, 0.64),
		Color(0.94, 0.93, 0.92),
		Color(1.0, 1.0, 1.0),
	])
	_wear.color_ramp = ramp
	return _wear


## The material for a zone. `team_colour` is used only by the `paint` zone and ignored
## everywhere else, so callers never have to know which zones are tinted.
static func for_zone(zone: String, team_colour: Color,
		livery: Color = Color(0, 0, 0, 0)) -> StandardMaterial3D:
	if livery.a == 0.0:
		livery = Color(LIVERY[0])
	var key: String = zone
	if zone == ZONE_PAINT:
		key = "paint:" + livery.to_html(false)
	elif TEAM_ZONES.has(zone):
		key = zone + ":" + team_colour.to_html(false)
	if _cache.has(key):
		return _cache[key]

	var material := StandardMaterial3D.new()
	var surface: Vector2 = ZONE_SURFACE.get(zone, Vector2(0.5, 0.6))

	if zone == ZONE_PAINT:
		# Knocked back so the warm key has headroom to put a highlight on top. Paint at
		# full strength reads as a flat sprite the moment the light hits it.
		material.albedo_color = livery.darkened(0.12).lerp(Color("6b6259"), 0.10)
	elif zone.begins_with("glow"):
		# A team zone takes the team colour; every other emissive keeps its own.
		var glow: Color = team_colour.lightened(0.18) if TEAM_ZONES.has(zone) \
			else Color(ZONE_ALBEDO.get(zone, "ffffff"))
		material.albedo_color = glow
		material.emission_enabled = true
		material.emission = glow
		material.emission_energy_multiplier = GLOW_ENERGY
		# Emissive parts should not also be shaded, or the lit side of a construct gets
		# a bright lens and the shadowed side gets a dull one -- and the damage-type
		# read is supposed to be constant from every angle.
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_cache[key] = material
		return material
	else:
		material.albedo_color = Color(ZONE_ALBEDO.get(zone, "6b6259"))

	material.roughness = surface.x
	material.metallic = surface.y

	# --- Paint wear.
	#
	# Reference paint is never flat: every panel is chipped along its edges, scratched
	# across its face and stained downward from its fixings. Flat livery colour was the
	# single biggest thing still separating these machines from the sheets in
	# `art/reference/`.
	#
	# Done with TRIPLANAR noise rather than a texture map, because none of this geometry
	# has UVs -- the generator produces raw bevelled boxes and the exporter deliberately
	# writes no texcoords, since a single float of UV drift was breaking export
	# reproducibility. Triplanar needs no UVs at all, the noise is generated at load, and
	# nothing new ships.
	if zone == ZONE_PAINT:
		material.albedo_texture = _wear_texture()
		material.roughness_texture = _wear_texture()
		material.uv1_triplanar = true
		# Scaled so the mottling lands at panel size rather than as fine speckle -- fine
		# noise on a 40 px construct is just dirt on the lens.
		material.uv1_scale = Vector3(1.5, 1.5, 1.5)
	# A cold rim separates a construct from the terrain behind it without a shader or
	# an outline pass -- the cheapest silhouette read available on the Compatibility
	# renderer, and twelve units deep in a melee it is what stops the field going soupy.
	material.rim_enabled = true
	material.rim = 0.42
	material.rim_tint = 0.55

	_cache[key] = material
	return material


## Extracts the zone from a surface material's name. The `.glb` names them `mat_<zone>`;
## Godot's glTF importer sometimes appends a suffix, so this matches on the prefix
## rather than demanding an exact string.
static func zone_of(material: Material) -> String:
	if material == null:
		return "metal"
	var name: String = material.resource_name
	if not name.begins_with("mat_"):
		return "metal"
	var zone: String = name.substr(4)
	# Strip an importer suffix like `mat_metal_001`.
	if zone.begins_with("glow_"):
		for known: String in ZONE_ALBEDO:
			if known.begins_with("glow_") and zone.begins_with(known):
				return known
		return "glow_visor"
	# Longest names first: `scrapmetal` must not be matched by the `metal` prefix, which
	# would render every container and lattice tower as machined construct plate.
	for known: String in ["scrapmetal", "paint", "metal", "rust", "dark", "tread",
			"hazard", "rock"]:
		if zone.begins_with(known):
			return known
	return "metal"
