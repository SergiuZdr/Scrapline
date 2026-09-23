class_name HubYard
extends SubViewportContainer

## The hub's 3D backdrop: your yard at night, with your squad standing in it.
##
## The menu used to be a document -- a dark blue page with rows of text on it. Measured,
## 78% of every pixel on the Upgrade screen was a single hue and 88% of them were darker
## than 0.20, which is what "flat" and "one shade of blue" mean numerically. No amount of
## retuning a palette fixes that, because the problem was never the palette: a screen
## made entirely of flat fills has no light in it, and this project's own art doctrine
## already says warmth has to come from the LIGHT and never from the pigment. The 3D
## renderer obeys that rule. The interface was breaking it on every screen.
##
## So the hub gets a place instead of a background. Everything here already existed --
## the arena kit from `make_arena.py`, the sodium/cold light rig from `battle_scene.gd`,
## and `ConstructView` to assemble a construct out of a squad entry. Nothing new is
## authored; it is the game's own scene, standing still.
##
## It carries its own World3D. Sharing the hub's would mean sharing a world that has no
## camera and no lights in it, which renders as a grey rectangle -- the same trap the
## loadout preview documents.

const COL_TEAM := Color("4fa8d8")

## Where the squad stands, and where the camera looks from. Per section, because a
## hangar that never moves is a photograph.
## A construct stands 0.85 m. The first framing put the camera 9 m back at 38 deg, which
## covers 6 m of frame height -- so the machines came out 13% of the shot and a 2.5 m
## container wall behind them owned the picture. These are close, low and slightly off
## axis: near enough that a chassis silhouette is readable, low enough that the machines
## are seen from a human's eye line rather than from a drone.
## The hub now runs the yard full width under a band ~400 px tall, with the mission card
## standing at the band's right end. So every shot aims right of and below the squad:
## the machines land in the upper left, clear of both the card and the sub-tab row that
## starts under the band. (The first framings aimed LEFT, to clear a sidebar that no
## longer exists.)
const FRAMING: Dictionary = {
	"default":  {"pos": Vector3(0.10, 1.38, 4.75), "look": Vector3(0.86, -0.36, 0.0), "fov": 36.0},
	# Pulled back and aimed higher than the first pass, which cropped every head: a
	# machine two metres from the lens subtends far more than the line's average, so the
	# framing has to be solved against the NEAREST construct, not the middle of the rank.
	"parts":    {"pos": Vector3(1.70, 1.12, 4.35), "look": Vector3(0.74, -0.14, 0.0), "fov": 36.0},
	"upgrade":  {"pos": Vector3(-1.55, 1.14, 4.40), "look": Vector3(0.94, -0.14, 0.0), "fov": 36.0},
	"campaign": {"pos": Vector3(-0.30, 1.44, 4.95), "look": Vector3(0.88, -0.36, 0.0), "fov": 37.0},
}

var _world: Node3D
var _camera: Camera3D
var _squad_root: Node3D
var _prop_cache: Dictionary = {}


func _init() -> void:
	stretch = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# The yard is scenery. Every click has to reach the interface on top of it.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)

	_world = Node3D.new()
	viewport.add_child(_world)
	_build_environment()
	_build_yard()

	_squad_root = Node3D.new()
	_world.add_child(_squad_root)


## Rebuilds the constructs standing in the yard from the player's current squad.
func refresh(squad: Array) -> void:
	for child: Node in _squad_root.get_children():
		child.queue_free()

	# Centred on the line however many constructs there are, so a squad of four does not
	# sit off to one side of the shot.
	# Just under a metre. At 1.85 the line was nine metres wide and no framing that fits
	# it can also make a 0.85 m machine legible.
	var spacing: float = 0.92
	var offset: float = -spacing * (squad.size() - 1) * 0.5
	for index: int in squad.size():
		var spec: Dictionary = squad[index] as Dictionary
		var parts: Dictionary = spec.get("parts", {}) as Dictionary
		if String(parts.get("chassis", "")).is_empty():
			continue

		var unit := SimUnit.new()
		unit.unit_ref = index
		unit.team = SimDefs.TEAM_A
		var ids: PackedStringArray = []
		for slot: String in ["chassis", "core", "arm_l", "arm_r", "module"]:
			ids.append(String(parts.get(slot, "")))
		unit.part_ids = ids

		var model: Node3D = ConstructView.build(unit, Session.content, COL_TEAM)
		model.position = Vector3(offset + spacing * index, 0.0, 0.0)
		# Turned a few degrees off dead-on, alternating, so the line reads as machines
		# parked rather than as a row of icons. Weapons project straight forward, and a
		# rank facing the camera square points every one of them at the lens.
		# 16, not 196: at 196 the whole squad stood with its BACK to the camera, so the
		# visors and core lenses -- the brightest, most identifying things on a machine --
		# were never in the shot.
		model.rotation.y = deg_to_rad(16.0 + (8.0 if index % 2 == 0 else -7.0))
		_squad_root.add_child(model)


## Moves the camera for a section. Sections with no entry get the default framing.
func focus(section: String) -> void:
	var shot: Dictionary = FRAMING.get(section, FRAMING["default"])
	var target: Vector3 = shot["pos"]
	var look: Vector3 = shot["look"]
	if _camera == null:
		return
	# Tweened, not cut. A cut between two static shots of the same six machines reads as
	# a rendering glitch; a short move reads as a camera.
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(_look_from.bind(look), _camera.position, target, 0.45)
	tween.parallel().tween_property(_camera, "fov", float(shot["fov"]), 0.45)


func _look_from(at: Vector3, look: Vector3) -> void:
	_camera.position = at
	_camera.look_at_from_position(at, look, Vector3.UP)


# --- Scene -------------------------------------------------------------------

func _build_environment() -> void:
	# The battle's environment, unchanged. The hub and the fight have to look like the
	# same place or the menu is a different product with the same name on it.
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("10131b")
	sky_material.sky_horizon_color = Color("3b3330")
	sky_material.sky_curve = 0.18
	sky_material.ground_bottom_color = Color("0e0c0a")
	sky_material.ground_horizon_color = Color("382c22")
	sky_material.ground_curve = 0.08
	sky_material.energy_multiplier = 0.7
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.35
	environment.ambient_light_color = Color("2f3a52")
	environment.ambient_light_energy = 0.75
	environment.fog_enabled = true
	environment.fog_light_color = Color("241f26")
	environment.fog_light_energy = 0.7
	environment.fog_sun_scatter = 0.10
	# Denser than the battlefield's. The hub looks down a much shorter yard and the fog
	# is doing a different job here: separating the containers behind the squad from the
	# squad itself, so the machines have a background rather than a backdrop.
	environment.fog_density = 0.026
	environment.fog_sky_affect = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.05
	environment.tonemap_white = 3.0
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.12
	environment.glow_enabled = true
	environment.glow_intensity = 0.4
	environment.glow_bloom = 0.14
	environment.glow_hdr_threshold = 1.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.environment = environment
	_world.add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-44, 152, 0)
	key.light_energy = 1.2
	key.light_color = Color("ffd3a4")
	key.light_specular = 0.9
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 40.0
	key.shadow_bias = 0.04
	key.shadow_normal_bias = 1.4
	_world.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-26, -32, 0)
	fill.light_energy = 1.0
	fill.light_color = Color("8aa3de")
	fill.shadow_enabled = false
	_world.add_child(fill)

	_camera = Camera3D.new()
	var shot: Dictionary = FRAMING["default"]
	_camera.fov = float(shot["fov"])
	_world.add_child(_camera)
	_look_from(shot["pos"], shot["look"])


## The yard the squad is standing in: ground, a wall of containers behind them, junk at
## human scale beside them, and the floodlights the warm key is pretending to come from.
func _build_yard() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(70, 70)
	ground.mesh = plane
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color("241d17")
	dirt.roughness = 0.98
	dirt.metallic = 0.0
	ground.material_override = dirt
	_world.add_child(ground)

	# Behind the squad, and only behind: this is a backdrop, not an arena. A full ring
	# would put containers between the camera and the machines.
	for index: int in 9:
		var hash_value: int = _scatter(index * 7 + 3)
		var container: Node3D = _prop("container_%d" % (hash_value % 2))
		if container == null:
			continue
		container.position = Vector3(-13.0 + 3.0 * index, 0.0, -12.5 - float(hash_value % 3))
		container.rotation.y = deg_to_rad(float(hash_value % 7) - 3.0)
		_world.add_child(container)
		if hash_value % 3 == 0:
			var stacked: Node3D = _prop("container_%d" % ((hash_value + 1) % 2))
			if stacked != null:
				stacked.position = container.position + Vector3(0.0, 2.55, 0.0)
				stacked.rotation.y = container.rotation.y + deg_to_rad(2.0)
				_world.add_child(stacked)

	# Junk at human scale, out at the edges of frame. Without something a person's size
	# in shot the constructs have nothing to be big against.
	var junk: Array = [
		["car_stack_0", Vector3(-4.6, 0.0, -6.2)],
		["tyre_stack_0", Vector3(4.1, 0.0, -5.1)],
		["car_stack_2", Vector3(6.4, 0.0, -9.0)],
		["tyre_stack_0", Vector3(-6.2, 0.0, -9.4)],
	]
	for entry: Variant in junk:
		var pair: Array = entry as Array
		var prop: Node3D = _prop(String(pair[0]))
		if prop == null:
			continue
		prop.position = pair[1]
		prop.rotation.y = deg_to_rad(float(_scatter(int(prop.position.x * 10.0)) % 90))
		_world.add_child(prop)

	# Cranes on the skyline. Without them the top corners of the shot are an unlit hole
	# -- the yard needs a horizon rather than an edge, which is the same reason the
	# battlefield puts gantries on its far side.
	for entry: Variant in [[Vector3(-15.0, 0.0, -21.0), 24.0], [Vector3(13.5, 0.0, -25.0), -16.0]]:
		var pair: Array = entry as Array
		var gantry: Node3D = _prop("gantry")
		if gantry == null:
			continue
		gantry.position = pair[0]
		gantry.rotation.y = deg_to_rad(float(pair[1]))
		_world.add_child(gantry)

	# The lamps the key light is coming from. A warm key with no visible source is just a
	# colour grade; a lamp in shot is the difference between lit and tinted.
	for spot: Variant in [Vector3(-5.2, 0.0, -3.4), Vector3(5.2, 0.0, -3.4)]:
		var lamp: Node3D = _prop("floodlight")
		if lamp == null:
			continue
		lamp.position = spot
		lamp.rotation.y = deg_to_rad(-28.0 if (spot as Vector3).x > 0.0 else 28.0)
		_world.add_child(lamp)

		var glow := OmniLight3D.new()
		glow.position = (spot as Vector3) + Vector3(0.0, 4.4, 0.0)
		glow.light_color = Color("ffc27a")
		glow.light_energy = 2.4
		glow.omni_range = 11.0
		glow.shadow_enabled = false
		_world.add_child(glow)


func _prop(name: String) -> Node3D:
	if not _prop_cache.has(name):
		var path: String = "res://art/arena/%s.glb" % name
		_prop_cache[name] = load(path) if ResourceLoader.exists(path) else null
	var packed: PackedScene = _prop_cache[name]
	if packed == null:
		return null
	var prop: Node3D = packed.instantiate() as Node3D
	# Scenery is dimmed, exactly as it is on the battlefield: dressed in the constructs'
	# own materials the walls come out brighter than the machines in front of them and
	# the eye goes to the containers.
	for mesh: MeshInstance3D in ConstructView.meshes_of(prop):
		if mesh.mesh == null:
			continue
		for surface: int in mesh.mesh.get_surface_count():
			var zone: String = PartMaterials.zone_of(mesh.mesh.surface_get_material(surface))
			mesh.set_surface_override_material(surface, _scenery_material(zone))
	return prop


static var _scenery_cache: Dictionary = {}


func _scenery_material(zone: String) -> StandardMaterial3D:
	if _scenery_cache.has(zone):
		return _scenery_cache[zone]
	var source: StandardMaterial3D = PartMaterials.for_zone(zone, COL_TEAM)
	var dimmed: StandardMaterial3D = source.duplicate()
	if not zone.begins_with("glow"):
		dimmed.albedo_color = source.albedo_color.darkened(0.50)
		# Scenery also loses the silhouette rim. That rim is part of what separates a
		# unit from its background; giving it to the background throws it away.
		dimmed.rim_enabled = false
	_scenery_cache[zone] = dimmed
	return dimmed


## A cheap fixed hash, so the yard dresses identically every time the hub opens. A yard
## that rearranges itself between visits reads as a bug.
static func _scatter(index: int) -> int:
	var h: int = (index * 2654435761) & 0x7fffffff
	h ^= (h >> 13)
	return (h * 1274126177) & 0x7fffffff
