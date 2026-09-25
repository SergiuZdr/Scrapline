class_name TitleStage
extends Node3D

## The title screen's scene (010): the crew -- the default three, numbered -- standing on a
## plated hardstand under the floodlights, the yard's junk around them, and on the horizon
## the Reclaimer: a line of red beacons over red dust, the thing the whole run is spent
## outrunning. A slow drift of the camera, dust in the lamplight. No UI here; the title
## screen puts its menu over this.
##
## Presentation only. Handed the content database rather than reaching for the `Run`
## autoload, like every display class (CLAUDE.md).

const RECLAIMER_RED := Color("ff3b24")

var _camera: Camera3D
var _time: float = 0.0
var _rigs: Array[ConstructRig] = []
var _blink: Array[StandardMaterial3D] = []


func build(db: ContentDB, crew: Array) -> void:
	_environment()
	_ground()
	_crew(db, crew)
	_yard()
	_horizon()
	_camera = Camera3D.new()
	_camera.fov = 34.0
	_camera.far = 300.0
	add_child(_camera)
	_camera.current = true
	_place_camera()


func _process(delta: float) -> void:
	_time += delta
	for rig: ConstructRig in _rigs:
		rig.update(delta)
	_place_camera()
	var on: bool = fmod(_time, 1.7) < 0.2
	for blink: StandardMaterial3D in _blink:
		blink.emission_energy_multiplier = 5.0 if on else 0.4


## A slow sway, so the scene is alive without asking to be watched.
func _place_camera() -> void:
	var sway: float = sin(_time * 0.12) * 0.16
	var at := Vector3(sin(sway) * 7.6 - 1.6, 1.9 + sin(_time * 0.2) * 0.05, cos(sway) * 7.6)
	_camera.look_at_from_position(at, Vector3(-1.1, 1.05, 0.0), Vector3.UP)


func _environment() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0c0d11")
	var sky := Sky.new()
	var panorama := PanoramaSkyMaterial.new()
	panorama.panorama = load("res://art/thirdparty/polyhaven/hdris/dresden_station_night/dresden_station_night_1k.hdr")
	panorama.energy_multiplier = 0.5
	sky.sky_material = panorama
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.5
	environment.ambient_light_energy = 0.7
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.fog_enabled = true
	environment.fog_light_color = Color("2a2025")
	environment.fog_density = 0.018
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.1
	environment.glow_enabled = true
	environment.glow_intensity = 0.55
	environment.glow_bloom = 0.1
	environment.glow_hdr_threshold = 0.9
	env.environment = environment
	add_child(env)
	var key := SpotLight3D.new()
	key.light_color = Color("ffc98a")
	key.light_energy = 9.0
	key.spot_range = 18.0
	key.spot_angle = 34.0
	key.shadow_enabled = true
	add_child(key)
	key.look_at_from_position(Vector3(3.5, 7.5, 4.5), Vector3(-0.6, 0.4, 0.0), Vector3.UP)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -140, 0)
	fill.light_energy = 0.55
	fill.light_color = Color("8aa3de")
	add_child(fill)


func _ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, 160)
	ground.mesh = plane
	ground.material_override = Surfaces.pbr("asphalt_02", Color(0.32, 0.31, 0.3), 0.25)
	add_child(ground)
	var stand := MeshInstance3D.new()
	var slab := CylinderMesh.new()
	slab.top_radius = 2.6
	slab.bottom_radius = 2.7
	slab.height = 0.12
	slab.radial_segments = 6
	stand.mesh = slab
	stand.position = Vector3(-1.1, 0.06, 0.0)
	stand.material_override = Surfaces.pbr("metal_plate_02", Color(0.46, 0.45, 0.43), 0.8, 0.55, 0.8)
	add_child(stand)


## The three machines of a run's default crew, numbered, at ease.
func _crew(db: ContentDB, crew: Array) -> void:
	var spots: Array = [Vector3(-2.4, 0.12, 0.5), Vector3(-0.9, 0.12, -0.5), Vector3(0.5, 0.12, 0.6)]
	for i: int in mini(crew.size(), spots.size()):
		var parts: PackedStringArray = PackedStringArray((crew[i] as Dictionary).get("parts", []))
		var model: Node3D = ConstructView.build_parts(parts, db, Color("4fa8d8"), 0, i + 1)
		model.scale = Vector3.ONE * 1.35
		model.position = spots[i]
		model.rotation.y = 0.55 - float(i) * 0.35
		add_child(model)
		var rig := ConstructRig.new()
		rig.bind(model)
		_rigs.append(rig)


## Junk and lamps close by, and a crane over it all.
func _yard() -> void:
	for dressing: Array in [["container_0", Vector3(-7.0, 0, -4.5), 20.0, 0.62], ["container_1", Vector3(-7.4, 1.55, -4.2), 35.0, 0.62],
			["car_stack_2", Vector3(4.2, 0, -3.8), -40.0, 0.7], ["tyre_stack_1", Vector3(2.8, 0, 2.2), 0.0, 0.7],
			["gantry", Vector3(-10.0, 0, -13.0), 90.0, 1.1], ["car_stack_0", Vector3(-5.2, 0, 2.6), 60.0, 0.6]]:
		var prop: Node3D = Surfaces.kit(String(dressing[0]), 0.28)
		if prop != null:
			prop.position = dressing[1]
			prop.rotation_degrees.y = float(dressing[2])
			prop.scale = Vector3.ONE * float(dressing[3])
			add_child(prop)
	var lamp: Node3D = Surfaces.kit("floodlight", 0.1)
	if lamp != null:
		lamp.position = Vector3(3.6, 0, -1.4)
		lamp.rotation_degrees.y = -130.0
		add_child(lamp)
	var dust := CPUParticles3D.new()
	dust.amount = 80
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.local_coords = true
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(4.0, 2.0, 2.5)
	dust.gravity = Vector3(0.02, -0.01, 0)
	dust.initial_velocity_min = 0.02
	dust.initial_velocity_max = 0.06
	dust.spread = 180.0
	dust.scale_amount_min = 0.012
	dust.scale_amount_max = 0.03
	var mote := QuadMesh.new()
	var motes := StandardMaterial3D.new()
	motes.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	motes.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	motes.billboard_keep_scale = true
	motes.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	motes.albedo_color = Color(1.0, 0.86, 0.62, 0.4)
	mote.material = motes
	dust.mesh = mote
	dust.position = Vector3(-0.8, 2.0, 0.5)
	add_child(dust)


## The Reclaimer on the horizon: beacons over a long red glow of dust. It is far away and
## it is coming.
func _horizon() -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("141214")
	dark.roughness = 0.9
	for i: int in 16:
		var x: float = -60.0 + float(i) * 8.0 + sin(float(i) * 1.7) * 2.0
		var z: float = -58.0 + cos(float(i) * 2.3) * 4.0
		var rig: Node3D = Surfaces.kit("gantry" if i % 2 == 0 else "service_gantry", 0.0)
		if rig != null:
			for mesh: MeshInstance3D in ConstructView.meshes_of(rig):
				mesh.material_override = dark
			rig.position = Vector3(x, 0, z)
			rig.scale = Vector3.ONE * (2.4 if i % 2 == 0 else 3.0)
			add_child(rig)
		var beacon := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.5
		ball.height = 1.0
		beacon.mesh = ball
		var glow := StandardMaterial3D.new()
		glow.albedo_color = RECLAIMER_RED
		glow.emission_enabled = true
		glow.emission = RECLAIMER_RED
		glow.emission_energy_multiplier = 3.0
		beacon.material_override = glow
		beacon.position = Vector3(x, 12.0 if i % 2 == 0 else 8.0, z)
		add_child(beacon)
		if i % 3 == 0:
			_blink.append(glow)
	var haze := OmniLight3D.new()
	haze.light_color = Color("ff4a2a")
	haze.light_energy = 8.0
	haze.omni_range = 70.0
	haze.position = Vector3(-10.0, 4.0, -52.0)
	add_child(haze)
