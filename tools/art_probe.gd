extends SceneTree

## Renders one fixed vignette -- a patch of hex board, a machine, three props -- under the
## game's lighting, in two dressings, so a change of art source is judged by looking at the
## same shot twice instead of by reputation.
##
##   godot --path . --resolution 1280x720 --script res://tools/art_probe.gd -- --mode a --out shots/probe_a.png
##
## Modes:
##   a  the game as it is: flat tile colours, procedural sky, the arena kit.
##   b  Poly Haven: night HDRI for sky light and reflections, triplanar PBR on the board,
##      ground and machine, Poly Haven props.
##   c  b's materials under the game's own dark procedural sky (HDRI for light only).

const PH := "res://art/thirdparty/polyhaven/"
const HEX: float = 1.0
const SQRT3: float = 1.7320508

var _mode: String = "a"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_mode = _arg(args, "--mode", "a")
	_go.call_deferred(_arg(args, "--out", "shots/probe.png"))


func _go(out: String) -> void:
	var world := Node3D.new()
	root.add_child(world)
	_environment(world)
	_board(world)
	_machine(world)
	_props(world)
	var camera := Camera3D.new()
	camera.fov = 38.0
	world.add_child(camera)
	if OS.get_cmdline_user_args().has("--close"):
		# The machine at portrait distance, where its materials can actually be judged.
		camera.position = Vector3(0.9, 1.25, 2.4)
		camera.look_at(Vector3(0.0, 0.75, 0.0))
	else:
		camera.position = Vector3(0.6, 5.6, 7.4)
		camera.look_at(Vector3(0.3, 0.7, 0.2))
	camera.current = true
	for i: int in 30:
		await process_frame
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	print("probe %s: %s (%s)" % [_mode, out, error_string(image.save_png(out))])
	quit()


func _environment(world: Node3D) -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	if _mode == "a":
		var procedural := ProceduralSkyMaterial.new()
		procedural.sky_top_color = Color("10131b")
		procedural.sky_horizon_color = Color("3b3330")
		procedural.ground_bottom_color = Color("0e0c0a")
		procedural.ground_horizon_color = Color("382c22")
		procedural.energy_multiplier = 0.7
		sky.sky_material = procedural
	else:
		var panorama := PanoramaSkyMaterial.new()
		panorama.panorama = load(PH + "hdris/dresden_station_night/dresden_station_night_1k.hdr")
		panorama.energy_multiplier = 0.55
		sky.sky_material = panorama
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.35 if _mode == "a" else 0.6
	environment.ambient_light_color = Color("2f3a52")
	environment.ambient_light_energy = 0.75
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	if _mode == "c":
		# The HDRI lights and reflects; what the camera SEES behind is the game's dark sky.
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color("0e0d0f")
	environment.fog_enabled = true
	environment.fog_light_color = Color("241f26")
	environment.fog_density = 0.01
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.05
	environment.glow_enabled = true
	environment.glow_intensity = 0.36
	environment.glow_hdr_threshold = 1.0
	env.environment = environment
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-46, 148, 0)
	key.light_energy = 1.15
	key.light_color = Color("ffd3a4")
	key.shadow_enabled = true
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28, -34, 0)
	fill.light_energy = 1.0
	fill.light_color = Color("8aa3de")
	fill.light_specular = 0.35
	world.add_child(fill)


func _board(world: Node3D) -> void:
	var tile_flat := _flat(Color("1a1e26"), 0.95)
	var tile_pbr := _pbr("textures/metal_plate_02/metal_plate_02", Color(0.42, 0.42, 0.44), 0.55, true)
	for r: int in range(-2, 3):
		for q: int in range(-3, 4):
			var slab := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = HEX * 0.96
			mesh.bottom_radius = HEX * 0.96
			mesh.height = 0.3
			mesh.radial_segments = 6
			mesh.rings = 1
			slab.mesh = mesh
			slab.position = Vector3(SQRT3 * HEX * (float(q) + 0.5 * float(r & 1)), -0.15, 1.5 * HEX * float(r))
			slab.material_override = tile_flat if _mode == "a" else tile_pbr
			world.add_child(slab)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	ground.position.y = -0.31
	ground.material_override = _flat(Color("0f0e0c"), 1.0) if _mode == "a" \
		else _pbr("textures/asphalt_02/asphalt_02", Color(0.55, 0.53, 0.5), 0.35, false)
	world.add_child(ground)


func _machine(world: Node3D) -> void:
	var db: ContentDB = ContentDB.load_all()
	var level: int = _arg(OS.get_cmdline_user_args(), "--level", "0").to_int()
	var model: Node3D = ConstructView.build_parts(PackedStringArray(["ch_brute", "co_dynamo", "ar_saw", "ar_hammer", "mo_scavenger"]),
		db, Color("4fa8d8"), level)
	model.rotation_degrees.y = 25.0
	world.add_child(model)
	if _mode == "a":
		return
	# Detail from Poly Haven maps on top of the game's own zone colours: the livery stays
	# the livery, the surface gains paint chips, plate seams and grain.
	for mesh: MeshInstance3D in ConstructView.meshes_of(model):
		if mesh.mesh == null:
			continue
		for s: int in mesh.mesh.get_surface_count():
			var current: Material = mesh.get_surface_override_material(s)
			if not (current is StandardMaterial3D):
				continue
			var zone: String = PartMaterials.zone_of(mesh.mesh.surface_get_material(s))
			var detail: StandardMaterial3D = (current as StandardMaterial3D).duplicate()
			var set: String = ""
			if zone == "paint":
				set = "textures/rusty_painted_metal/rusty_painted_metal"
			elif zone == "metal" or zone == "dark":
				set = "textures/metal_plate_02/metal_plate_02"
			if set.is_empty():
				continue
			detail.normal_enabled = true
			detail.normal_texture = load(PH + set + "_nor_gl_1k.jpg")
			detail.normal_scale = 0.8
			detail.roughness_texture = load(PH + set + "_rough_1k.jpg")
			detail.uv1_triplanar = true
			detail.uv1_scale = Vector3(1.6, 1.6, 1.6)
			mesh.set_surface_override_material(s, detail)


func _props(world: Node3D) -> void:
	var spots: Array = [Vector3(-3.4, 0, 1.4), Vector3(3.2, 0, -1.2), Vector3(-2.6, 0, -2.4)]
	if _mode == "a":
		var names: Array = ["barrier_0", "tyre_stack_0", "car_stack_0"]
		for i: int in 3:
			var prop: Node3D = (load("res://art/arena/%s.glb" % names[i]) as PackedScene).instantiate()
			prop.position = spots[i]
			prop.scale = Vector3.ONE * (0.7 if i == 2 else 1.0)
			world.add_child(prop)
			for mesh: MeshInstance3D in ConstructView.meshes_of(prop):
				for s: int in mesh.mesh.get_surface_count():
					var zone: String = PartMaterials.zone_of(mesh.mesh.surface_get_material(s))
					var m: StandardMaterial3D = PartMaterials.for_zone(zone, Color("7f8a99")).duplicate()
					if not zone.begins_with("glow"):
						m.albedo_color = m.albedo_color.darkened(0.42)
					mesh.set_surface_override_material(s, m)
		return
	# (Barrel_02, a saturated blue plastic drum, was tried and rejected -- art-sourcing.md.)
	var models: Array = ["concrete_road_barrier/concrete_road_barrier_1k.gltf", "old_tyre/old_tyre_1k.gltf"]
	var scales: Array = [1.0, 1.3]
	for i: int in 2:
		var prop: Node3D = (load(PH + "models/" + models[i]) as PackedScene).instantiate()
		prop.position = spots[i]
		prop.scale = Vector3.ONE * float(scales[i])
		world.add_child(prop)


func _pbr(set: String, tint: Color, scale: float, metal: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(PH + set + "_diff_1k.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(PH + set + "_nor_gl_1k.jpg")
	m.roughness_texture = load(PH + set + "_rough_1k.jpg")
	m.metallic = 0.6 if metal else 0.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	return m


func _flat(colour: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = roughness
	return m


func _arg(args: PackedStringArray, name: String, fallback: String) -> String:
	var at: int = args.find(name)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else fallback
