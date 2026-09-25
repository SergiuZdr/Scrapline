class_name YardView
extends Node3D

## The region as a place (play-test 3: "the map is 2D... the Reclaimer needs a proper look").
##
## A tilted camera over a dark yard. Every site is a landmark built from the arena kit on a
## pad whose ring says what it is to you now (amber: here, blue: you can go, grey: done),
## with its icon floating above so it reads at a glance. Roads are on the ground. The
## Reclaimer is a wall of harvester rigs across the whole map, red beacons over a dust
## cloud; behind it the ground is stripped bare, and the zone it takes next pulses red.
## It slides forward when the front moves, so the player SEES a zone fall.
##
## Display only: it is told the state and asked where things are on screen. The map screen
## does the input and every rule question goes to `RunSim`.

const SPACING_X: float = 7.0       # metres between columns
const DEPTH: float = 26.0          # metres across the rows (site y 0..100)
const RECLAIMER_RED := Color("ff3b24")
const RING_HERE := Color("e5b33d")
const RING_GO := Color("5aa9ff")
const RING_DONE := Color("5b5750")
const RING_FAR := Color("8a8478")
const LANDMARK_SCALE: float = 0.46
const PICK_RADIUS: float = 70.0

var _state: RunState
var _columns: int = 7
var _camera: Camera3D
var _sites: Dictionary = {}        # id -> { "root", "ring": MeshInstance3D, "icon": Sprite3D }
var _roads: Node3D
var _road_marks: Node3D
var _reclaimer: Node3D
var _reclaimed: MeshInstance3D
var _next_zone: MeshInstance3D
var _next_material: StandardMaterial3D
var _front_x: float = 0.0
var _hover: int = -1
var _time: float = 0.0
var _materials: Dictionary = {}
var _packed: Dictionary = {}


## Builds the yard once for this run's region.
func build(state: RunState, columns: int) -> void:
	_state = state
	_columns = columns
	_build_world()
	_build_ground()
	_roads = Node3D.new()
	add_child(_roads)
	_road_marks = Node3D.new()
	add_child(_road_marks)
	for site: Dictionary in state.sites:
		_build_site(site)
	_build_roads()
	_build_clutter()
	_build_reclaimer()
	_front_x = _front_target()
	_place_front(_front_x)


## Re-colours the yard for the state now; the Reclaimer slides to the new front.
func refresh(state: RunState, targets: Array[int], hover: int) -> void:
	_state = state
	_hover = hover
	for id: int in _sites:
		_style_site(id, targets)
	_mark_roads(targets)
	var goal: float = _front_target()
	if not is_equal_approx(goal, _front_x):
		var tween := create_tween()
		tween.tween_method(_place_front, _front_x, goal, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_front_x = goal


func site_world(id: int) -> Vector3:
	var site: Dictionary = _state.site(id)
	return _map_point(float(site["x"]), float(site["y"]))


## Where site `id` is on screen (its pad), for labels and picking.
func screen_pos(id: int, lift: float = 0.0) -> Vector2:
	return _camera.unproject_position(site_world(id) + Vector3(0, lift, 0))


## Just below a site's pad on screen, where its label goes.
func label_pos(id: int) -> Vector2:
	return _camera.unproject_position(site_world(id) + Vector3(0, 0, 1.7))


## The site under a screen point, or -1.
func pick(point: Vector2) -> int:
	var best: int = -1
	var best_d: float = PICK_RADIUS
	for id: int in _sites:
		for lift: float in [0.0, 1.6]:
			var d: float = screen_pos(id, lift).distance_to(point)
			if d < best_d:
				best_d = d
				best = id
	return best


func _process(delta: float) -> void:
	_time += delta
	if _next_material != null:
		_next_material.albedo_color.a = 0.10 + 0.08 * sin(_time * 2.4)
	for id: int in _sites:
		var icon: Sprite3D = _sites[id]["icon"]
		if icon != null:
			var bob: float = 0.08 * sin(_time * 1.8 + float(id)) if id == _hover else 0.0
			icon.position.y = 2.25 + bob


# --- World --------------------------------------------------------------------

func _build_world() -> void:
	# The fight's lighting rig: warm sodium key, cold fill (CLAUDE.md, "The visual system").
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("0c0f16")
	sky_material.sky_horizon_color = Color("3a2c28")
	sky_material.ground_bottom_color = Color("0e0c0a")
	sky_material.ground_horizon_color = Color("382c22")
	sky_material.energy_multiplier = 0.6
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.35
	environment.ambient_light_color = Color("2f3a52")
	environment.ambient_light_energy = 0.8
	environment.fog_enabled = true
	environment.fog_light_color = Color("261f22")
	environment.fog_density = 0.008
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.1
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	environment.glow_bloom = 0.1
	environment.glow_hdr_threshold = 0.9
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.environment = environment
	add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, 150, 0)
	key.light_energy = 1.1
	key.light_color = Color("ffd3a4")
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 90.0
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, -30, 0)
	fill.light_energy = 0.8
	fill.light_color = Color("8aa3de")
	fill.light_specular = 0.3
	add_child(fill)

	_camera = Camera3D.new()
	_camera.fov = 34.0
	add_child(_camera)
	# Framed so the whole region sits between the top bar and the crew strip.
	_camera.position = Vector3(0.0, 44.0, 31.0)
	_camera.look_at(Vector3(0.0, 0.0, 1.6))
	_camera.current = true


func _build_ground() -> void:
	var width: float = SPACING_X * float(_columns - 1)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(width + 60.0, DEPTH + 40.0)
	ground.mesh = plane
	ground.material_override = _flat(Color("262625"), 1.0)
	add_child(ground)
	# The zones: a faint seam between columns and a name on the far edge.
	for col: int in _columns:
		var x: float = _column_x(col)
		if col > 0:
			var seam := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.08, 0.02, DEPTH + 6.0)
			seam.mesh = box
			seam.position = Vector3(x - SPACING_X * 0.5, 0.01, 0.0)
			seam.material_override = _flat(Color("3b352e"), 1.0)
			add_child(seam)
		var name := Label3D.new()
		name.text = "CAMP" if col == 0 else ("GATE" if col == _columns - 1 else "ZONE %d" % (col + 1))
		name.font = UIKit.font_strong()
		name.font_size = 96
		name.pixel_size = 0.012
		name.modulate = Color(0.75, 0.72, 0.66, 0.55)
		name.outline_size = 0
		name.rotation_degrees = Vector3(-90, 0, 0)
		name.position = Vector3(x, 0.03, -DEPTH * 0.5 - 2.2)
		add_child(name)

	_reclaimed = MeshInstance3D.new()
	_reclaimed.mesh = PlaneMesh.new()
	_reclaimed.material_override = _flat(Color("5a1d12"), 1.0)
	add_child(_reclaimed)
	_next_zone = MeshInstance3D.new()
	var next_plane := PlaneMesh.new()
	next_plane.size = Vector2(SPACING_X, DEPTH + 6.0)
	_next_zone.mesh = next_plane
	_next_material = StandardMaterial3D.new()
	_next_material.albedo_color = Color(RECLAIMER_RED, 0.12)
	_next_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_next_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_next_zone.material_override = _next_material
	add_child(_next_zone)


# --- Sites --------------------------------------------------------------------

func _build_site(site: Dictionary) -> void:
	var id: int = int(site["id"])
	var root := Node3D.new()
	root.position = site_world(id)
	add_child(root)
	var pad := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.35
	disc.bottom_radius = 1.5
	disc.height = 0.16
	pad.mesh = disc
	pad.position.y = 0.08
	pad.material_override = _flat(Color("3a3632"), 0.9)
	root.add_child(pad)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.38
	torus.outer_radius = 1.55
	ring.mesh = torus
	ring.position.y = 0.17
	root.add_child(ring)
	var icon := Sprite3D.new()
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.pixel_size = 0.009
	icon.no_depth_test = true
	icon.shaded = false
	icon.render_priority = 10
	icon.position.y = 2.25
	root.add_child(icon)
	_sites[id] = {"root": root, "ring": ring, "icon": icon, "landmark": null, "type": ""}


func _style_site(id: int, targets: Array[int]) -> void:
	var entry: Dictionary = _sites[id]
	var site: Dictionary = _state.site(id)
	var known: bool = RunSim.revealed(_state, id)
	var type: String = String(site["type"]) if known else "?"
	if String(entry["type"]) != type:
		entry["type"] = type
		if entry["landmark"] != null:
			(entry["landmark"] as Node3D).queue_free()
		var landmark: Node3D = _landmark(type, id)
		(entry["root"] as Node3D).add_child(landmark)
		entry["landmark"] = landmark
		var icon: Sprite3D = entry["icon"]
		var icon_name: String = String(_ICONS.get(type, ""))
		icon.texture = load("res://art/icons/%s.svg" % icon_name) if not icon_name.is_empty() else null
	var colour: Color = RING_FAR
	var glow: float = 0.4
	if id == _state.current:
		colour = RING_HERE
		glow = 2.2
	elif targets.has(id):
		colour = RING_GO
		glow = 2.6 if id == _hover else 1.4
	elif bool(site["visited"]):
		colour = RING_DONE
		glow = 0.2
	(entry["ring"] as MeshInstance3D).material_override = _glow(colour, glow)
	var icon: Sprite3D = entry["icon"]
	var faded: bool = _state.consumed(id) or (bool(site["visited"]) and id != _state.current)
	icon.modulate = Color(1, 1, 1, 0.35) if faded else Color(1, 1, 1, 1)
	icon.pixel_size = 0.012 if id == _hover else 0.009


const _ICONS: Dictionary = {"start": "yard", "skirmish": "fight", "elite": "colossus",
	"scrapyard": "scrap", "workshop": "foundry", "boss": "gauntlet"}


## What stands on a site. Built from the arena kit, so the map is made of the same
## things the fights are.
func _landmark(type: String, id: int) -> Node3D:
	var root := Node3D.new()
	match type:
		"start":
			_prop(root, "container_0", Vector3(-0.3, 0, -0.9), 12.0)
			_prop(root, "container_1", Vector3(0.2, 0, 0.5), -8.0)
			_lamp(root, Vector3(1.1, 0, -0.2), Color("ffc27a"), 3.0)
		"skirmish":
			_prop(root, "car_stack_0", Vector3(-0.4, 0, -0.3), float(_h(id, 1) % 60))
			_prop(root, "tyre_stack_0", Vector3(0.8, 0, 0.6), 0.0)
		"elite":
			_prop(root, "car_stack_2", Vector3(-0.3, 0, -0.2), 20.0, 0.62)
			_prop(root, "car_stack_0", Vector3(0.7, 0, 0.7), -30.0)
		"scrapyard":
			_prop(root, "tyre_stack_1", Vector3(-0.6, 0, -0.3), 0.0)
			_prop(root, "tyre_stack_2", Vector3(0.5, 0, -0.5), 0.0)
			_prop(root, "car_stack_1", Vector3(0.1, 0, 0.6), 70.0)
		"workshop":
			_prop(root, "service_gantry", Vector3(0, 0, 0), 90.0, 0.6)
			_lamp(root, Vector3(0.0, 0, 0.0), Color("ffc27a"), 4.0)
		"boss":
			_prop(root, "gantry", Vector3(0, 0, 0), 0.0, 0.7)
			for i: int in 4:
				_prop(root, "barrier_%d" % (i % 2), Vector3(0.0, 0, -2.6 - float(i) * 0.8), 90.0, 0.8)
				_prop(root, "barrier_%d" % ((i + 1) % 2), Vector3(0.0, 0, 2.6 + float(i) * 0.8), 90.0, 0.8)
			_lamp(root, Vector3(0.0, 0, 0.0), RECLAIMER_RED, 3.0)
		_:
			# Not scouted: a question mark over an empty pad.
			var mark := Label3D.new()
			mark.text = "?"
			mark.font = UIKit.font_display()
			mark.font_size = 160
			mark.pixel_size = 0.012
			mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			mark.modulate = Color(0.8, 0.77, 0.7, 0.7)
			mark.position.y = 1.2
			root.add_child(mark)
	return root


func _prop(parent: Node3D, name: String, at: Vector3, yaw: float, scale_by: float = LANDMARK_SCALE,
		dim: float = 0.12) -> Node3D:
	var prop: Node3D = _kit(name, dim)
	if prop == null:
		return null
	prop.position = at
	prop.rotation_degrees.y = yaw
	prop.scale = Vector3.ONE * scale_by
	parent.add_child(prop)
	return prop


func _lamp(parent: Node3D, at: Vector3, colour: Color, energy: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = colour
	light.light_energy = energy
	light.omni_range = 5.0
	light.position = at + Vector3(0, 2.2, 0)
	parent.add_child(light)


# --- Roads --------------------------------------------------------------------

func _build_roads() -> void:
	for a: Dictionary in _state.sites:
		for other: Variant in (a["links"] as Array):
			if int(other) < int(a["id"]):
				continue
			_roads.add_child(_strip(site_world(int(a["id"])), site_world(int(other)), 1.0, 0.03, _flat(Color("403d37"), 0.85)))


func _mark_roads(targets: Array[int]) -> void:
	for child: Node in _road_marks.get_children():
		child.queue_free()
	var here: Vector3 = site_world(_state.current)
	for id: int in targets:
		var hot: bool = id == _hover
		_road_marks.add_child(_strip(here, site_world(id), 0.24 if hot else 0.16, 0.05,
			_glow(RING_HERE if hot else RING_GO, 1.8 if hot else 0.9)))


## A flat strip on the ground from `a` to `b`, stopping short of the pads.
func _strip(a: Vector3, b: Vector3, width: float, height: float, material: Material) -> MeshInstance3D:
	var flat_a := Vector3(a.x, 0, a.z)
	var flat_b := Vector3(b.x, 0, b.z)
	var length: float = maxf(0.1, flat_a.distance_to(flat_b) - 3.6)
	var strip := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(length, height, width)
	strip.mesh = box
	strip.material_override = material
	strip.position = (flat_a + flat_b) * 0.5 + Vector3(0, height * 0.5 + 0.01, 0)
	strip.rotation.y = -atan2(flat_b.z - flat_a.z, flat_b.x - flat_a.x)
	return strip


## Loose junk between the sites, so the yard is a yard and not a diagram.
func _build_clutter() -> void:
	var names: PackedStringArray = ["tyre_stack_0", "tyre_stack_1", "car_stack_1", "container_0", "container_1", "barrier_0"]
	var width: float = SPACING_X * float(_columns - 1)
	var placed: int = 0
	var tries: int = 0
	while placed < 46 and tries < 400:
		tries += 1
		var x: float = -width * 0.5 - 4.0 + float(_h(tries, 7) % 1000) / 1000.0 * (width + 8.0)
		var z: float = -DEPTH * 0.5 - 3.0 + float(_h(tries, 11) % 1000) / 1000.0 * (DEPTH + 6.0)
		var spot := Vector3(x, 0, z)
		# Keep clear of the sites, the roads and the zone names on the far edge.
		if _near_site_or_road(spot) or z < -DEPTH * 0.5 - 0.5:
			continue
		_prop(self, names[_h(tries, 13) % names.size()], spot, float(_h(tries, 17) % 360), 0.34, 0.45)
		placed += 1


func _near_site_or_road(p: Vector3) -> bool:
	for id: int in _sites:
		if Vector2(p.x, p.z).distance_to(Vector2(site_world(id).x, site_world(id).z)) < 3.2:
			return true
	for a: Dictionary in _state.sites:
		for other: Variant in (a["links"] as Array):
			var s: Vector3 = site_world(int(a["id"]))
			var e: Vector3 = site_world(int(other))
			if Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), Vector2(s.x, s.z), Vector2(e.x, e.z)).distance_to(Vector2(p.x, p.z)) < 1.6:
				return true
	return false


# --- The Reclaimer ------------------------------------------------------------

func _build_reclaimer() -> void:
	_reclaimer = Node3D.new()
	add_child(_reclaimer)
	var dark: StandardMaterial3D = _flat(Color("171314"), 0.7)
	dark.metallic = 0.6
	# The mouth: a long low harvester blade across the whole map, lit red along its teeth.
	var blade := MeshInstance3D.new()
	var blade_box := BoxMesh.new()
	blade_box.size = Vector3(1.4, 0.9, DEPTH + 12.0)
	blade.mesh = blade_box
	blade.position = Vector3(-0.6, 0.45, 0)
	blade.material_override = dark
	_reclaimer.add_child(blade)
	var teeth := MeshInstance3D.new()
	var teeth_box := BoxMesh.new()
	teeth_box.size = Vector3(0.12, 0.14, DEPTH + 12.0)
	teeth.mesh = teeth_box
	teeth.position = Vector3(0.12, 0.25, 0)
	teeth.material_override = _glow(RECLAIMER_RED, 2.4)
	_reclaimer.add_child(teeth)
	# Rigs: crane booms and harvester frames behind the blade, each with a red beacon.
	var z: float = -DEPTH * 0.5 - 5.0
	var i: int = 0
	while z <= DEPTH * 0.5 + 5.0:
		var name: String = "gantry" if i % 2 == 0 else "service_gantry"
		var rig: Node3D = _kit(name, 0.0)
		if rig != null:
			_blacken(rig, dark)
			rig.position = Vector3(-2.2 - float(_h(i, 3) % 100) / 100.0, 0, z)
			rig.rotation_degrees.y = 90.0 if name == "service_gantry" else 0.0
			rig.scale = Vector3.ONE * (0.62 if name == "gantry" else 0.75)
			_reclaimer.add_child(rig)
		var beacon := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.16
		ball.height = 0.32
		beacon.mesh = ball
		beacon.material_override = _glow(RECLAIMER_RED, 4.0)
		beacon.position = Vector3(-2.2, 5.2 if name == "gantry" else 2.5, z)
		_reclaimer.add_child(beacon)
		if i % 2 == 0:
			var light := OmniLight3D.new()
			light.light_color = RECLAIMER_RED
			light.light_energy = 2.2
			light.omni_range = 7.0
			light.position = Vector3(0.5, 1.5, z)
			_reclaimer.add_child(light)
		z += 3.4
		i += 1
	# The dust it raises, lit red from below.
	var dust := CPUParticles3D.new()
	dust.amount = 90
	dust.lifetime = 5.0
	dust.preprocess = 5.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(1.5, 0.3, DEPTH * 0.5 + 6.0)
	dust.direction = Vector3(0.3, 1, 0)
	dust.spread = 25.0
	dust.initial_velocity_min = 0.4
	dust.initial_velocity_max = 1.0
	dust.gravity = Vector3.ZERO
	dust.scale_amount_min = 2.0
	dust.scale_amount_max = 4.0
	var puff := QuadMesh.new()
	puff.size = Vector2(1, 1)
	var puff_material := StandardMaterial3D.new()
	puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	puff_material.billboard_keep_scale = true
	puff_material.albedo_color = Color(0.55, 0.2, 0.14, 0.16)
	puff_material.vertex_color_use_as_albedo = true
	puff.material = puff_material
	dust.mesh = puff
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.3, Color(1, 1, 1, 1))
	dust.color_ramp = fade
	dust.position = Vector3(-1.5, 0.5, 0)
	# Local: it was pre-simulated at the map's centre before the wall was placed, and left
	# a trail of puffs across the middle of the yard.
	dust.local_coords = true
	var soft := GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	var falloff := Gradient.new()
	falloff.set_color(0, Color(1, 1, 1, 1))
	falloff.set_color(1, Color(1, 1, 1, 0))
	soft.gradient = falloff
	puff_material.albedo_texture = soft
	_reclaimer.add_child(dust)


func _front_target() -> float:
	# The wall stands on the far edge of the last zone it has taken (before any, just off
	# the start's left edge).
	return _column_x(_state.front_col) + SPACING_X * 0.5


func _place_front(x: float) -> void:
	_reclaimer.position.x = x
	var left: float = _column_x(0) - SPACING_X * 0.5 - 30.0
	var taken: float = maxf(0.01, x - left)
	(_reclaimed.mesh as PlaneMesh).size = Vector2(taken, DEPTH + 40.0)
	_reclaimed.position = Vector3(left + taken * 0.5, 0.015, 0)
	var next_col: int = _state.front_col + 1
	_next_zone.visible = next_col < _columns - 1
	_next_zone.position = Vector3(_column_x(next_col), 0.02, 0)


# --- Helpers ------------------------------------------------------------------

func _map_point(x: float, y: float) -> Vector3:
	var width: float = SPACING_X * float(_columns - 1)
	return Vector3(-width * 0.5 + x / 100.0 * width, 0.0, -DEPTH * 0.5 + y / 100.0 * DEPTH)


func _column_x(col: int) -> float:
	return -SPACING_X * float(_columns - 1) * 0.5 + float(col) * SPACING_X


func _kit(name: String, dim: float) -> Node3D:
	if not _packed.has(name):
		var path: String = "res://art/arena/%s.glb" % name
		_packed[name] = load(path) if ResourceLoader.exists(path) else null
	var packed: PackedScene = _packed[name]
	if packed == null:
		return null
	var prop: Node3D = packed.instantiate() as Node3D
	for mesh: MeshInstance3D in ConstructView.meshes_of(prop):
		if mesh.mesh == null:
			continue
		for surface: int in mesh.mesh.get_surface_count():
			var zone: String = PartMaterials.zone_of(mesh.mesh.surface_get_material(surface))
			mesh.set_surface_override_material(surface, _kit_material(zone, dim))
	return prop


## The construct palette, pushed down in value for scenery (lamps exempt), as the arena did.
func _kit_material(zone: String, dim: float) -> StandardMaterial3D:
	var key: String = "%s:%.2f" % [zone, dim]
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


func _blacken(node: Node, material: Material) -> void:
	for mesh: MeshInstance3D in ConstructView.meshes_of(node):
		if mesh.mesh == null:
			continue
		for surface: int in mesh.mesh.get_surface_count():
			mesh.set_surface_override_material(surface, material)


func _flat(colour: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	return material


func _glow(colour: Color, energy: float) -> StandardMaterial3D:
	var key: String = "glow:%s:%.2f" % [colour.to_html(false), energy]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = energy
	_materials[key] = material
	return material


## Integer avalanche for scatter (presentation only, but stable so a region dresses the
## same way every time it is drawn).
func _h(i: int, salt: int) -> int:
	var x: int = (i * 73856093) ^ (salt * 19349663) ^ (_state.sites.size() * 83492791)
	x = (x ^ (x >> 13)) * 1274126177
	x = x ^ (x >> 16)
	return absi(x)
