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
	"metal": "6b6259",
	"rust": "8c4a26",
	"dark": "2b2b30",
	"tread": "1b1a19",
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
	"metal": Vector2(0.40, 0.90),
	"rust": Vector2(0.92, 0.10),
	"dark": Vector2(0.50, 0.75),
	"tread": Vector2(0.95, 0.00),
	"hazard": Vector2(0.60, 0.10),
	# Concrete is fully diffuse; sheet steel is rougher and less metallic than a
	# construct's machined plate, so the arena never out-shines the machines in it.
	"rock": Vector2(0.98, 0.00),
	"scrapmetal": Vector2(0.78, 0.45),
}

const GLOW_ENERGY: float = 1.8

static var _cache: Dictionary = {}


## The material for a zone. `team_colour` is used only by the `paint` zone and ignored
## everywhere else, so callers never have to know which zones are tinted.
static func for_zone(zone: String, team_colour: Color) -> StandardMaterial3D:
	var key: String = zone if zone != ZONE_PAINT else "paint:" + team_colour.to_html(false)
	if _cache.has(key):
		return _cache[key]

	var material := StandardMaterial3D.new()
	var surface: Vector2 = ZONE_SURFACE.get(zone, Vector2(0.5, 0.6))

	if zone == ZONE_PAINT:
		# Knocked back from the raw team colour so the warm key light has headroom to
		# put a highlight on top. A construct painted in full-strength UI blue reads as
		# a flat sprite the moment the light hits it.
		material.albedo_color = team_colour.darkened(0.18).lerp(Color("6b6259"), 0.12)
	elif zone.begins_with("glow"):
		var glow := Color(ZONE_ALBEDO.get(zone, "ffffff"))
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
