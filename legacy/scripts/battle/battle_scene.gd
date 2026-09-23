extends Node3D

## The playable battle: a 3D diorama plus the Order Phase panel.
##
## This layer computes nothing. It reads the simulation's event stream and animates
## it, which is what makes skip-animation, replays, and server verification free --
## all three are the same events played back, or not played back, at different
## speeds. If you ever find yourself calculating damage in here, the architecture has
## been broken.
##
## The 3D is deliberately primitives. Phase 1 exists to answer "is the combat fun",
## and that question must be answerable before a single hour goes into art.

const FIXTURE_PATH: String = "res://tools/fixtures/battle_01.json"
const PLAYER_TEAM: int = SimDefs.TEAM_A

const COL_TEAM_A := Color("4fa8d8")
const COL_TEAM_B := Color("d8654f")
const COL_GROUND := Color("15181d")
const DAMAGE_COLOURS: Dictionary = {
	SimDefs.DMG_KINETIC: Color("d9d4c8"),
	SimDefs.DMG_THERMAL: Color("ff8a3d"),
	SimDefs.DMG_EMP: Color("5fd0ff"),
	SimDefs.DMG_CORROSIVE: Color("9ddc46"),
}

var _db: ContentDB
var _controller: BattleController
var _panel: OrderPanel
var _status: Label
var _speed_button: Button
var _arena: Node3D
var _field: Battlefield

var _visuals: Dictionary = {}     ## unit_ref -> Node3D
var _name_tags: Dictionary = {}   ## unit_ref -> Label3D
var _unit_state: Dictionary = {}  ## unit_ref -> SimUnit, refreshed each Order Phase
var _move_tweens: Dictionary = {}  ## unit_ref -> active movement Tween
var _downed: Dictionary = {}      ## unit_ref -> true once destroyed; excluded from framing
var _rigs: Dictionary = {}        ## unit_ref -> ConstructRig driving legs and arms
var _terrain_cache: Dictionary = {}
var _terrain_materials: Dictionary = {}  ## tile id -> shared StandardMaterial3D
var _arena_materials: Dictionary = {}    ## zone -> shared darkened scenery material
var _camera_rig: BattleCamera
var _vfx: BattleVFX
const TERRAIN_VARIANTS: int = 3
## Rings of heaped scrap around the play area. Three is enough to read as a bank without
## putting a hundred extra props on a phone.
const BERM_RINGS: int = 3

## How far the arena's scenery is pushed below the constructs in value. See
## `_arena_material` -- at 0.0 the walls were brighter than the machines in front of them.
const ARENA_DIM: float = 0.42

## How each tile type renders, on the Rust & Sodium palette. Overrides the flat colour
## baked into the `.glb` so terrain and constructs are lit by one set of rules.
## Keyed by the material name baked into each `.glb`, minus the `mat_` prefix, so a tile
## built from several materials keeps them apart. Slag is the reason this is per-surface
## rather than per-prop: its basin and lip are cooled rock and only the pool is molten.
const TERRAIN_LOOK: Dictionary = {
	"rubble": {"albedo": "302e2c", "rough": 0.96, "metal": 0.05},
	"scrap": {"albedo": "38362f", "rough": 0.70, "metal": 0.55},
	"ridge": {"albedo": "383931", "rough": 0.95, "metal": 0.05},
	"slag_crust": {"albedo": "1a0c07", "rough": 0.62, "metal": 0.05},
	# The one emissive surface on the battlefield. Kept deliberately low: it is a hazard
	# cue, not a light source, and the constructs are the subject of the screen.
	"slag_molten": {"albedo": "6e2408", "rough": 0.45, "metal": 0.0,
			"emission": "ff5410", "energy": 0.42},
}

var _queue: Array = []
var _queue_index: int = 0
var _playback_tick: float = 0.0
var _playing: bool = false
var _speed: float = 1.0
## Dev flag: commit empty orders automatically so a battle runs unattended.
var _autoplay: bool = false
## Campaign node this battle belongs to; empty when running the fixture directly.
var _node_id: String = ""
var _reported: bool = false


func _ready() -> void:
	# The session's content, NOT a fresh load: `Session` has already applied the live
	# balance patch to its copy. Loading again here fought every battle on the shipped
	# numbers while the rest of the game used the patched ones, and the server -- which
	# runs the patch -- rejected every submission as a content mismatch.
	_db = Session.content if Session.content != null else ContentDB.load_all()
	if not _db.errors.is_empty():
		for e: String in _db.errors:
			push_error("content: " + e)
		return

	var setup: BattleSetup = _load_setup()
	if setup == null:
		return

	# The controller comes first now: the map decides the terrain geometry and the
	# camera framing, so the world cannot be built until the battlefield exists.
	_controller = BattleController.new()
	_controller.player_team = PLAYER_TEAM
	_controller.cycle_resolved.connect(_on_cycle_resolved)
	_controller.battle_finished.connect(_on_battle_finished)
	_controller.start(setup, _db.to_sim_content(), _db.balance, _doctrines)
	_field = _controller.battlefield()

	_build_world()
	_build_terrain()
	_build_ui()

	# Set before the first Order Phase opens, or `--autoplay` only works in combination
	# with `--shot`, which is where it used to be read.
	_autoplay = OS.get_cmdline_user_args().has("--autoplay")
	_spawn_units(_controller.starting_units())
	_open_order_phase()
	_maybe_capture()


## Dev-only: `--shot <path> [--after <frames>] [--autoplay]` renders and writes a PNG,
## so layout and playback can be checked without a human sitting in front of the
## window.
func _maybe_capture() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find("--shot")
	if index < 0 or index + 1 >= args.size():
		return
	var path: String = args[index + 1]

	var frames: int = 2
	var after: int = args.find("--after")
	if after >= 0 and after + 1 < args.size():
		frames = args[after + 1].to_int()

	# Dev: swing the rig onto one construct to inspect how the parts actually seat.
	if args.has("--closeup"):
		var target: Node3D = _visuals.get(0)
		if target != null:
			# Hide everything else, so a close-up shows ONE construct and cannot be
			# misread as a single exploded model -- which it was, twice.
			if args.has("--solo"):
				for unit_ref: Variant in _visuals.keys():
					if int(unit_ref) != 0:
						(_visuals[unit_ref] as Node3D).visible = false
				for tag_ref: Variant in _name_tags.keys():
					(_name_tags[tag_ref] as Label3D).visible = int(tag_ref) == 0
			# Aim at the construct's middle, not its feet. Focusing on the base put the
			# torso off the top of the frame and made a perfectly assembled model look
			# like it had come apart.
			if args.has("--dump"):
				_dump_model(target)
			# Auto-framing would overwrite all of this on the next tick.
			_camera_rig.hold()
			_camera_rig._target_focus = target.position + Vector3(0, 0.62, 0)
			_camera_rig._target_zoom = 3.4 if args.has("--solo") else 4.6
			_camera_rig._target_pitch = 22.0
			_camera_rig._apply(true)

	# Dev: pull all the way out to review the ARENA rather than the fight. Auto-framing
	# fits the shot to the constructs, which is right for play and useless for checking
	# whether the yard around them reads as an enclosure.
	if args.has("--wide"):
		_camera_rig.hold()
		_camera_rig._target_focus = Vector3.ZERO
		_camera_rig._target_zoom = 42.0
		_camera_rig._target_pitch = 30.0
		_camera_rig._apply(true)

	for _i: int in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(path)
	print("screenshot -> ", path)
	get_tree().quit()


## A battle launched from the hub gets its squads, map and Condition from the campaign
## node. Running the scene directly still falls back to the fixture, which keeps the
## battle testable on its own.
func _load_setup() -> BattleSetup:
	# Ranked first: an attack carries a defender who is not present, so their side is
	# played by THEIR stored doctrine. Nothing the attacker sends decides how the
	# defence behaves -- that is the whole point of an async ladder.
	if Session.pending_tournament:
		_node_id = "tournament"
		return Session.tournaments.build_setup(Session.profile())

	if Session.pending_boss:
		# The colossus. Won or lost, the attempt is scored on damage dealt, which is why
		# the setup comes from the co-op service rather than the campaign.
		_node_id = "boss"
		return Session.coop.build_setup(Session.now())

	if Session.pending_defence != null:
		_node_id = "pvp"
		_doctrines = [null, Session.pending_defence.doctrine()]
		return Session.pvp.build_setup(Session.pending_defence, Session.now())
	if Session.pending_floor > 0:
		_node_id = "gauntlet"
		var climb: BattleSetup = Gauntlet.build_setup(
			Session.profile(), Session.content, Session.pending_floor,
			Session.pending_squad, Session.now())
		if climb != null:
			return climb
	if not Session.pending_node_id.is_empty():
		_node_id = Session.pending_node_id
		var built: BattleSetup = Campaign.build_setup(
			Session.profile(), Session.content, _node_id,
			Session.pending_squad, Session.now())
		if built != null:
			return built
	return _load_fixture_setup()


## Per-team doctrine for the simulation. Index 0 is the player (null -- they issue
## orders themselves), index 1 the opponent.
var _doctrines: Array = []


func _load_fixture_setup() -> BattleSetup:
	if not FileAccess.file_exists(FIXTURE_PATH):
		push_error("missing fixture: " + FIXTURE_PATH)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(FIXTURE_PATH)) != OK:
		push_error("bad fixture json")
		return null
	# The fixture's scripted order log is ignored -- here the player supplies orders.
	return BattleSetup.from_dict(json.data as Dictionary)


# --- World -------------------------------------------------------------------

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()

	# A sky, not a background colour. The old flat #0a0c10 void gave the constructs
	# nothing to stand against: at a low camera angle a silhouette is only readable if
	# there is something BEHIND it, and black is not something.
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	# Smog overhead grading into a sodium-lit haze at the horizon -- the light of a
	# working yard at night, which is the fiction the whole palette is built on.
	sky_material.sky_top_color = Color("10131b")
	sky_material.sky_horizon_color = Color("3b3330")
	sky_material.sky_curve = 0.18
	sky_material.ground_bottom_color = Color("0e0c0a")
	sky_material.ground_horizon_color = Color("382c22")
	sky_material.ground_curve = 0.08
	sky_material.sun_angle_max = 24.0
	sky_material.energy_multiplier = 0.7
	sky.sky_material = sky_material
	environment.sky = sky

	# Ambient comes off that sky, so the shadowed side of a construct picks up the cold
	# blue overhead and the warm bounce near the ground for free.
	# Weighted toward the explicit COLD colour rather than the sky. Letting the warm
	# horizon drive ambient flooded every surface with the same brown and the whole
	# screen collapsed to one value -- constructs, terrain and berm all reading alike.
	# The palette only works if the shadows stay cold and the key stays warm.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.35
	environment.ambient_light_color = Color("2f3a52")
	environment.ambient_light_energy = 0.75

	# Depth haze. Dense enough to actually separate the far rank from the near one --
	# at 0.015 it was doing nothing at all and the field read as one flat plane.
	environment.fog_enabled = true
	environment.fog_light_color = Color("241f26")
	environment.fog_light_energy = 0.7
	environment.fog_sun_scatter = 0.28
	# Enough to push the berm and the far rank back, not enough to grey out the fight.
	# At 0.028 the yard turned into flat haze and the battlefield lost its depth again.
	environment.fog_density = 0.013
	environment.fog_sky_affect = 0.35

	# Filmic tonemapping with a little extra contrast is most of the difference between
	# "engine defaults" and "art directed" on a dark palette -- without it the sodium key
	# clips to white the moment it hits a metallic surface.
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.05
	environment.tonemap_white = 3.0
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.12
	environment.adjustment_saturation = 1.0

	# Glow so the core lenses, visors and overdrive caps read as LIGHT rather than as
	# bright paint. Those emissives are the game's damage-type and danger signals.
	environment.glow_enabled = true
	environment.glow_intensity = 0.36
	environment.glow_bloom = 0.12
	environment.glow_hdr_threshold = 1.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	env.environment = environment
	add_child(env)

	# --- Light rig: one warm key, one cold fill, opposed.
	#
	# The key is a sodium-vapour yard lamp and it casts the shadows. The fill is a cold
	# skylight from the opposite side at a fraction of the energy, which is what keeps
	# the shadowed half of a construct readable instead of a black shape. Two opposed
	# lights of different temperature is the cheapest way to make hard-surface geometry
	# describe its own form.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-46, 148, 0)
	# Warm, but not so warm that it paints the whole yard. A saturated sodium key at 1.7
	# turned every neutral surface tan and the red team stopped separating from the
	# terrain it was standing on -- the light has to READ warm on highlights while
	# leaving mid-tones close to neutral.
	key.light_energy = 1.15
	key.light_color = Color("ffd3a4")
	key.light_specular = 0.9
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 70.0
	key.shadow_bias = 0.04
	key.shadow_normal_bias = 1.4
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28, -34, 0)
	# Strong enough to actually be seen. At 0.55 the cold side of the rig was invisible
	# next to a 1.45 key and the screen read as a single orange wash.
	fill.light_energy = 1.0
	fill.light_color = Color("8aa3de")
	fill.light_specular = 0.35
	add_child(fill)

	# An orbit rig rather than a fixed camera. The player can look at the fight from
	# wherever they like, and the rig clamps pitch and panning so the battlefield can
	# never be lost off-screen.
	_camera_rig = BattleCamera.new()
	add_child(_camera_rig)
	_camera_rig.setup(_field, 42.0)

	_arena = Node3D.new()
	add_child(_arena)

	_vfx = BattleVFX.new()
	add_child(_vfx)
	_vfx.setup(_camera_rig)


## Sim coordinates are fixed-point integers; the view works in metres, with the map
## centred on the origin so the camera framing does not depend on map size.
func _to_world(sim_x: int, sim_z: int) -> Vector3:
	return Vector3(
		float(sim_x) / float(Battlefield.TILE) - float(_field.width) * 0.5,
		0.0,
		float(sim_z) / float(Battlefield.TILE) - float(_field.depth) * 0.5)


## Terrain is drawn once: a base slab for the whole map, then a raised block for each
## tile that is anything other than open ground. Only ~40 of 168 tiles need geometry,
## and the height differences are what make cover and ridges readable at a glance.
func _build_terrain() -> void:
	var half_w: float = float(_field.width) * 0.5
	var half_d: float = float(_field.depth) * 0.5

	# The yard the battle sits in. Without this the arena was a lit trapezoid floating in
	# empty space -- the single loudest "this is a prototype" cue on the screen. The
	# outer plane runs well past the play area and lets the depth fog carry it into the
	# horizon, so the battlefield has somewhere to BE.
	var yard := MeshInstance3D.new()
	var yard_mesh := PlaneMesh.new()
	yard_mesh.size = Vector2(240, 240)
	yard.mesh = yard_mesh
	yard.position = Vector3(0, -0.02, 0)
	# Darker than the play area. The constructs are mid-value objects, so the ground they
	# stand on has to sit below them or nothing on the field has a silhouette.
	#
	# The albedo is COOL despite the yard being dirt. A warm ground under a warm key put
	# every pixel on screen in the same orange band and the palette stopped being two
	# colours -- the warmth has to come from the light, so that anything the key does not
	# reach falls back to cold and the two halves stay distinguishable.
	var yard_material := _material(Color("232228"))
	yard_material.roughness = 0.97
	yard.material_override = yard_material
	_arena.add_child(yard)

	var slab := MeshInstance3D.new()
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(float(_field.width) + 2.0, 0.3, float(_field.depth) + 2.0)
	slab.mesh = slab_mesh
	slab.position = Vector3(0, -0.15, 0)
	var slab_material := _material(COL_GROUND)
	slab_material.roughness = 0.94
	slab.material_override = slab_material
	_arena.add_child(slab)

	_build_arena(half_w, half_d)

	# One generated prop per non-open tile. Variants are picked by position so a field
	# of rubble does not look stamped, and the choice is stable across runs.
	for row: int in _field.depth:
		for column: int in _field.width:
			var definition: Dictionary = _field.types[_field.tiles[row * _field.width + column]]
			var tile_id: String = String(definition.get("id", "open"))
			if tile_id == "open":
				continue
			var variant: int = (row * 7 + column * 3) % TERRAIN_VARIANTS
			var prop: Node3D = _terrain_prop(tile_id, variant)
			if prop == null:
				continue
			prop.position = Vector3(column - half_w + 0.5, 0.0, row - half_d + 0.5)
			# A quarter-turn per tile, so repeated props do not line up into a grid.
			prop.rotation.y = deg_to_rad(90.0 * float((row + column) % 4))
			_arena.add_child(prop)

	var divider := MeshInstance3D.new()
	var strip := BoxMesh.new()
	strip.size = Vector3(float(_field.width), 0.02, 0.05)
	divider.mesh = strip
	divider.position = Vector3(0, 0.04, 0)
	divider.material_override = _material(Color("2c3442"))
	_arena.add_child(divider)


func _terrain_prop(tile_id: String, variant: int) -> Node3D:
	var key: String = "%s_%d" % [tile_id, variant]
	if not _terrain_cache.has(key):
		var path: String = "res://art/terrain/%s.glb" % key
		if not ResourceLoader.exists(path):
			path = "res://art/terrain/%s.glb" % tile_id
		_terrain_cache[key] = load(path) if ResourceLoader.exists(path) else null
	var packed: PackedScene = _terrain_cache[key]
	if packed == null:
		return null
	var prop: Node3D = packed.instantiate() as Node3D
	_dress_prop(prop, tile_id)
	return prop


## Builds the scrapyard arena around the play area.
##
## Read from the fight outwards, each ring does one job:
##
##   BARRIER    a low concrete line at the play edge -- the boundary the constructs
##              fight inside, readable without a glowing rectangle or a grid overlay
##   CONTAINER  stacked steel behind it: the wall that encloses the yard
##   FILL       car and tyre stacks in the gaps, at human scale, so the constructs read
##              as big machines rather than as toys on a table
##   FLOODLIGHT one per corner -- the diegetic source of the warm key light. Without a
##              visible source the lighting is just a setting in an Environment
##   GANTRY     a crane on the skyline, so the arena has a horizon instead of an edge
##
## Everything is placed from `_scatter_hash`, never from RNG, so a map dresses identically
## on every run and two screenshots can be compared.
##
## The berm of loose scrap this replaced said "there is junk here". It never said ARENA:
## nothing enclosed the fight and nothing implied anybody built the place.
func _build_arena(half_w: float, half_d: float) -> void:
	var index: int = 0

	# --- Barriers, nose to tail around the play edge with occasional gaps.
	var barrier_out: float = 1.3
	for axis: int in 2:
		var along: float = half_w if axis == 0 else half_d
		var offset: float = (half_d + barrier_out) if axis == 0 else (half_w + barrier_out)
		var step: float = 1.75
		var position: float = -along
		while position <= along:
			for side: int in [-1, 1]:
				index += 1
				var hash_value: int = _scatter_hash(index)
				# A gap every so often: an unbroken wall reads as poured concrete rather
				# than as blocks somebody dragged into place.
				if hash_value % 9 == 0:
					position += step
					continue
				var prop: Node3D = _arena_prop("barrier_%d" % (hash_value % 2))
				if prop == null:
					continue
				if axis == 0:
					prop.position = Vector3(position, 0.0, float(side) * offset)
				else:
					prop.position = Vector3(float(side) * offset, 0.0, position)
					prop.rotation.y = PI * 0.5
				prop.rotation.y += deg_to_rad(float(hash_value % 5) - 2.0)
				_arena.add_child(prop)
			position += step

	# --- Containers: the enclosing wall, some stacked two high.
	var wall_out: float = 5.2
	for axis: int in 2:
		var along: float = half_w if axis == 0 else half_d
		var offset: float = (half_d + wall_out) if axis == 0 else (half_w + wall_out)
		var step: float = 6.8
		var position: float = -along + 1.0
		while position <= along:
			for side: int in [-1, 1]:
				index += 1
				var hash_value: int = _scatter_hash(index)
				var stack: int = 2 if hash_value % 3 == 0 else 1
				for level: int in stack:
					var prop: Node3D = _arena_prop("container_%d" % ((hash_value + level) % 2))
					if prop == null:
						continue
					var jitter: float = float(hash_value % 40) / 100.0 - 0.2
					var lift: float = float(level) * 2.55
					if axis == 0:
						prop.position = Vector3(position + jitter, lift, float(side) * offset)
					else:
						prop.position = Vector3(float(side) * offset, lift, position + jitter)
						prop.rotation.y = PI * 0.5
					# Stacked containers are never square with each other.
					prop.rotation.y += deg_to_rad(float((hash_value + level * 7) % 7) - 3.0)
					_arena.add_child(prop)
			position += step

	# --- Fill: cars and tyres between the barrier line and the container wall.
	var fill_band: float = (wall_out + barrier_out) * 0.5
	for axis: int in 2:
		var along: float = half_w if axis == 0 else half_d
		var offset: float = (half_d + fill_band) if axis == 0 else (half_w + fill_band)
		var step: float = 4.2
		var position: float = -along
		while position <= along:
			for side: int in [-1, 1]:
				index += 1
				var hash_value: int = _scatter_hash(index)
				if hash_value % 3 == 0:
					position += step
					continue
				var name: String = "car_stack_%d" % (hash_value % 3) if hash_value % 2 == 0 \
					else "tyre_stack_%d" % (hash_value % 3)
				var prop: Node3D = _arena_prop(name)
				if prop == null:
					continue
				var jitter: float = float(hash_value % 60) / 100.0 - 0.3
				if axis == 0:
					prop.position = Vector3(position + jitter, 0.0, float(side) * offset)
				else:
					prop.position = Vector3(float(side) * offset, 0.0, position + jitter)
				prop.rotation.y = deg_to_rad(float(hash_value % 360))
				_arena.add_child(prop)
			position += step

	# --- Floodlights at the four corners, plus real light so the arena is lit BY them.
	for corner_x: int in [-1, 1]:
		for corner_z: int in [-1, 1]:
			var tower: Node3D = _arena_prop("floodlight")
			if tower == null:
				continue
			# Inside the corner container stacks, not level with them -- at +3.4 the
			# towers stood in the same place as the corner fill and were swallowed by it.
			var spot := Vector3(float(corner_x) * (half_w + 2.0), 0.0,
				float(corner_z) * (half_d + 2.0))
			tower.position = spot
			# Turned to face the middle, so the lamp bank points at the fight.
			tower.rotation.y = atan2(-spot.x, -spot.z)
			_arena.add_child(tower)

			var lamp := OmniLight3D.new()
			lamp.position = spot + Vector3(0, 4.7, 0)
			lamp.light_color = Color("ffd2a0")
			lamp.light_energy = 2.6
			lamp.omni_range = 26.0
			lamp.omni_attenuation = 1.4
			# No shadows: four shadow-casting omnis on the Compatibility renderer is a
			# phone's whole frame budget, and the directional key already casts.
			lamp.shadow_enabled = false
			_arena.add_child(lamp)

	# --- Corners. The four side runs stop short of each other, and without this the
	# enclosure has a hole at every corner that looks straight out onto empty ground --
	# which undoes the one thing the wall is for.
	for corner_x: int in [-1, 1]:
		for corner_z: int in [-1, 1]:
			for level: int in 2:
				var corner: Node3D = _arena_prop("container_%d" % (level % 2))
				if corner == null:
					continue
				corner.position = Vector3(
					float(corner_x) * (half_w + wall_out - 1.4), float(level) * 2.55,
					float(corner_z) * (half_d + wall_out - 1.4))
				# Turned across the corner so it closes the diagonal rather than
				# duplicating one of the runs it sits between.
				corner.rotation.y = deg_to_rad(45.0 * float(corner_x) * float(corner_z))
				_arena.add_child(corner)

	# --- Gantries on the FAR skyline. The camera sits on the player's side at -Z, so
	# placed there they loomed over the near edge and pushed into the order panel.
	for corner_x: int in [-1, 1]:
		var gantry: Node3D = _arena_prop("gantry")
		if gantry == null:
			continue
		gantry.position = Vector3(float(corner_x) * (half_w * 0.62), 0.0,
			half_d + 15.0)
		gantry.rotation.y = deg_to_rad(90.0 if corner_x > 0 else -90.0)
		_arena.add_child(gantry)


## Loads an arena prop and puts it on the shared palette. Cached: a map rings itself with
## dozens of barriers and they must not each load their own copy of the mesh.
func _arena_prop(name: String) -> Node3D:
	if not _terrain_cache.has(name):
		var path: String = "res://art/arena/%s.glb" % name
		_terrain_cache[name] = load(path) if ResourceLoader.exists(path) else null
	var packed: PackedScene = _terrain_cache[name]
	if packed == null:
		return null
	var prop: Node3D = packed.instantiate() as Node3D
	for mesh: MeshInstance3D in ConstructView.meshes_of(prop):
		if mesh.mesh == null:
			continue
		for surface: int in mesh.mesh.get_surface_count():
			var zone: String = PartMaterials.zone_of(mesh.mesh.surface_get_material(surface))
			mesh.set_surface_override_material(surface, _arena_material(zone))
	return prop


## The arena palette: the construct palette, pushed down in value.
##
## Scenery has to sit BELOW the subject. Dressed in the constructs' own materials the
## containers and barriers came out brighter than the machines fighting in front of them,
## and the eye went to the walls -- the same mistake the loose-scrap berm made before it.
## Lamps are exempt: they are supposed to be the brightest thing in the yard.
func _arena_material(zone: String) -> StandardMaterial3D:
	if _arena_materials.has(zone):
		return _arena_materials[zone]
	var source: StandardMaterial3D = PartMaterials.for_zone(zone, COL_TEAM_A)
	if zone.begins_with("glow"):
		_arena_materials[zone] = source
		return source
	var dimmed: StandardMaterial3D = source.duplicate()
	dimmed.albedo_color = source.albedo_color.darkened(ARENA_DIM)
	# Scenery does not get the silhouette rim the constructs use -- that rim is part of
	# what separates a unit from its background, and giving it to the background too
	# throws the distinction away.
	dimmed.rim_enabled = false
	_arena_materials[zone] = dimmed
	return dimmed


## Integer avalanche, so consecutive prop indices scatter instead of marching. A single
## multiply here produced a berm whose heaps grew monotonically along each edge.
func _scatter_hash(value: int) -> int:
	var h: int = value * 0x9E3779B1
	h = (h ^ (h >> 15)) * 0x85EBCA6B
	h = (h ^ (h >> 13)) * 0xC2B2AE35
	return absi(h ^ (h >> 16))


## Puts terrain on the same palette as the constructs.
##
## The `.glb` files carry a flat colour baked at generation time; overriding it here means
## the battlefield and the machines standing on it are lit by one set of rules. Slag is
## the interesting case: a dark cooled crust with a hot emissive read, rather than the
## flat bright orange it bakes as, which looked like an untextured debug volume.
func _dress_prop(prop: Node3D, tile_id: String) -> void:
	for mesh: MeshInstance3D in ConstructView.meshes_of(prop):
		if mesh.mesh == null:
			continue
		for surface: int in mesh.mesh.get_surface_count():
			var source: Material = mesh.mesh.surface_get_material(surface)
			var look: String = tile_id
			if source != null and source.resource_name.begins_with("mat_"):
				look = source.resource_name.substr(4)
			var material: StandardMaterial3D = _terrain_material(look)
			if material != null:
				mesh.set_surface_override_material(surface, material)


func _terrain_material(look: String) -> StandardMaterial3D:
	if _terrain_materials.has(look):
		return _terrain_materials[look]
	var spec: Dictionary = TERRAIN_LOOK.get(look, {})
	if spec.is_empty():
		return null
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(String(spec["albedo"]))
	material.roughness = float(spec["rough"])
	material.metallic = float(spec["metal"])
	if spec.has("emission"):
		material.emission_enabled = true
		material.emission = Color(String(spec["emission"]))
		material.emission_energy_multiplier = float(spec["energy"])
	_terrain_materials[look] = material
	return material


## The team ring: a flat lit disc on the ground under a construct.
##
## The SECOND team channel, and it exists because the first one has a blind spot. Lit
## eyes are the strongest read on the field, but a machine turned away, or buried in a
## six-on-six melee with something standing in front of its head, shows none. A ring on
## the floor is visible from every angle, is never occluded by the unit it belongs to,
## and sits in the one part of the frame nothing else competes for.
##
## Unshaded on purpose: this is a signal, not a surface, and it must read identically in
## the lit half of the yard and the shadowed half.
func _team_ring(team_colour: Color) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.30
	torus.outer_radius = 0.38
	torus.rings = 20
	torus.ring_segments = 4
	ring.mesh = torus
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(team_colour.r, team_colour.g, team_colour.b, 0.85)
	material.emission_enabled = true
	material.emission = team_colour
	material.emission_energy_multiplier = 1.3
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Drawn on top of the ground rather than fighting it for depth. A ring that
	# z-fights with terrain flickers, and a flickering signal is worse than none.
	material.no_depth_test = false
	ring.mesh.material = material
	ring.position = Vector3(0.0, 0.035, 0.0)
	return ring


func _spawn_units(units: Array[SimUnit]) -> void:
	for u: SimUnit in units:
		var root := Node3D.new()
		root.position = _to_world(u.pos_x, u.pos_z)
		_arena.add_child(root)

		var team_colour: Color = COL_TEAM_A if u.team == SimDefs.TEAM_A else COL_TEAM_B
		# The model is assembled from the unit's actual parts, so a loadout change is
		# visible on the battlefield without any extra wiring.
		var model: Node3D = ConstructView.build(u, _db, team_colour)
		root.add_child(model)
		root.add_child(_team_ring(team_colour))

		# One rig per construct, bound after the model is in the tree so the limb and
		# socket lookups resolve.
		var rig := ConstructRig.new()
		rig.bind(model)
		_rigs[u.unit_ref] = rig

		var tag := Label3D.new()
		tag.text = _tag_text(u)
		tag.font_size = 32
		tag.pixel_size = 0.0042
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = Vector3(0, 1.55, 0)
		tag.outline_size = 10
		tag.outline_modulate = Color(0, 0, 0, 0.85)
		tag.modulate = team_colour.lightened(0.45)
		root.add_child(tag)

		_visuals[u.unit_ref] = root
		_name_tags[u.unit_ref] = tag
		_unit_state[u.unit_ref] = u


# --- UI ----------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The same theme the hub uses. The battle HUD and the menus are the same product and
	# should not be two different opinions about what a button looks like.
	UIKit.apply(root)
	layer.add_child(root)

	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	# Translucent so the battlefield reads THROUGH the bar. A solid strip across the top
	# of a 3D scene crops it into a letterbox.
	var top_style := UIKit.plain(Color(UIKit.BG, 0.82), 0, UIKit.SPACE_LG, UIKit.SPACE_SM)
	top_style.border_width_bottom = 1
	top_style.border_color = Color(UIKit.HAIRLINE, 0.6)
	top.add_theme_stylebox_override("panel", top_style)
	root.add_child(top)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", UIKit.SPACE_SM)
	top.add_child(top_row)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", UIKit.SIZE_HEADING)
	_status.add_theme_color_override("font_color", UIKit.TEXT)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_row.add_child(_status)

	_speed_button = Button.new()
	_speed_button.text = "SPEED  1x"
	_speed_button.pressed.connect(_on_speed_pressed)
	top_row.add_child(_speed_button)

	var recentre := Button.new()
	recentre.text = "RECENTRE"
	recentre.pressed.connect(func() -> void: _camera_rig.recentre())
	top_row.add_child(recentre)

	var skip := Button.new()
	skip.text = "SKIP  ⏭"
	skip.pressed.connect(_on_skip_pressed)
	top_row.add_child(skip)

	_panel = OrderPanel.new()
	# Anchored by hand rather than with PRESET_BOTTOM_WIDE: the preset derives its
	# offsets from the control's current size, and a control that has not run _ready
	# yet still has a size of zero -- which collapsed the whole panel to nothing.
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top = -float(OrderPanel.PANEL_HEIGHT)
	_panel.offset_bottom = 0.0
	_panel.orders_committed.connect(_on_orders_committed)
	root.add_child(_panel)


# --- Flow --------------------------------------------------------------------

func _open_order_phase() -> void:
	# Nothing transient should survive into the Order Phase. See `clear_transients`.
	if _vfx != null:
		_vfx.clear_transients()
	# Constructs included. A machine still leaning away from the last hit of the cycle
	# is not reading as a reaction any more -- playback has stopped, so it just looks
	# bent, for as long as the player takes to give orders.
	for unit_ref: int in _rigs:
		var rig: ConstructRig = _rigs[unit_ref]
		if rig != null:
			rig.reset_transients()
	var units: Array[SimUnit] = _controller.current_units()
	for u: SimUnit in units:
		_unit_state[u.unit_ref] = u
		_sync_visual(u)

	var condition: Dictionary = _db.conditions.get(_controller.setup.condition_id, {})
	_panel.show_cycle(units, PLAYER_TEAM, _controller.cycle, String(condition.get("name", "")))
	_panel.set_enabled(true)
	_status.text = "Give orders, then Resume.   Cycle %d of %d      drag to orbit · right-drag to pan · wheel to zoom" % [
		_controller.cycle + 1, _db.balance.max_cycles]
	if _autoplay:
		_on_orders_committed({})


func _on_orders_committed(orders: Dictionary) -> void:
	Analytics.milestone("battle_started")
	Audio.play("cycle", -16.0)
	_panel.set_enabled(false)
	_controller.commit_cycle(orders)


func _on_cycle_resolved(new_events: Array) -> void:
	_queue = new_events
	_queue_index = 0
	_playing = not _queue.is_empty()
	if _playing:
		_playback_tick = float(_queue[0][SimEv.F_TICK])
		_status.text = "Resolving cycle %d…" % _controller.cycle
	else:
		_after_playback()


func _process(delta: float) -> void:
	# Framing runs even while playback is paused, so the Order Phase opens on the fight
	# rather than wherever the camera happened to stop.
	_camera_rig.frame(_living_positions(), delta)
	_drive_rigs(delta)
	if not _playing:
		return
	# A heavy hit freezes playback for a couple of frames. Hitstop does more for the
	# feel of an impact than any particle effect, and it costs nothing.
	if _vfx.is_frozen():
		return
	_playback_tick += delta * float(_db.balance.tick_hz) * _speed
	while _queue_index < _queue.size() and float(_queue[_queue_index][SimEv.F_TICK]) <= _playback_tick:
		_apply_event(_queue[_queue_index])
		_queue_index += 1
	if _queue_index >= _queue.size():
		_playing = false
		_after_playback()


## Dev-only: prints every mesh under a construct with its world position and size.
##
## Exists because a stray box kept appearing beside an assembled unit that BOTH the
## in-part connectivity check and the surface-distance assembly check called clean. When
## the mesh data says one thing and the screen says another, the answer is to ask the
## running scene what it is actually drawing rather than to reason about the geometry.
func _dump_sockets(node: Node, depth: int) -> void:
	if node is Node3D:
		var n3: Node3D = node as Node3D
		print("  %s%-22s local(%.2f, %.2f, %.2f)  world(%.2f, %.2f, %.2f)" % [
			"  ".repeat(depth), node.name,
			n3.position.x, n3.position.y, n3.position.z,
			n3.global_transform.origin.x, n3.global_transform.origin.y,
			n3.global_transform.origin.z])
	for child: Node in node.get_children():
		_dump_sockets(child, depth + 1)


func _dump_model(root: Node3D) -> void:
	print("--- sockets under %s ---" % root.name)
	_dump_sockets(root, 0)
	print("--- meshes under %s ---" % root.name)
	for mesh: MeshInstance3D in ConstructView.meshes_of(root):
		var aabb: AABB = mesh.get_aabb()
		var origin: Vector3 = mesh.global_transform.origin
		print("  %-28s pos(%.2f, %.2f, %.2f)  size(%.2f, %.2f, %.2f)  parent=%s" % [
			mesh.name, origin.x, origin.y, origin.z,
			aabb.size.x, aabb.size.y, aabb.size.z,
			mesh.get_parent().name])


## Walks every construct whose movement tween is still running.
##
## The rig is told whether a unit is moving; it never works it out. Movement itself is
## still driven entirely by the simulation's events -- this only decides whether the legs
## are swinging while that happens.
func _drive_rigs(delta: float) -> void:
	for unit_ref: int in _rigs:
		var rig: ConstructRig = _rigs[unit_ref]
		var tween: Tween = _move_tweens.get(unit_ref)
		var moving: bool = tween != null and is_instance_valid(tween) and tween.is_running()
		rig.set_moving(moving and not _downed.has(unit_ref))
		rig.update(delta, _stride_scale(unit_ref))


## Faster chassis take quicker strides, so movement speed reads on the model rather than
## only on how fast the position changes.
func _stride_scale(unit_ref: int) -> float:
	var u: SimUnit = _unit_state.get(unit_ref)
	if u == null:
		return 1.0
	return clampf(float(u.speed) / 120.0, 0.6, 1.7)


## The weapon class of one of a unit's arms, for picking its strike animation. Read from
## `data/parts/arms.json` -- the same field that chose the weapon's model, so the motion
## and the silhouette can never describe two different weapons.
func _weapon_class(unit_ref: int, index: int) -> String:
	var u: SimUnit = _unit_state.get(unit_ref)
	if u == null or index >= u.part_ids.size():
		return ""
	var part: Dictionary = _db.parts.get(String(u.part_ids[index]), {})
	return String(part.get("weapon_class", ""))


## World positions of every construct still standing, for the camera to fit a shot to.
func _living_positions() -> PackedVector3Array:
	var out := PackedVector3Array()
	for unit_ref: int in _visuals:
		if _downed.has(unit_ref):
			continue
		var node: Node3D = _visuals[unit_ref]
		if node != null and is_instance_valid(node):
			out.append(node.position)
	return out


func _after_playback() -> void:
	if _controller.is_finished():
		var result: BattleResult = _controller.result
		var who: String = "VICTORY" if result.winner == PLAYER_TEAM else (
			"DEFEAT" if result.winner != BattleResult.WINNER_DRAW else "STALEMATE")
		_status.text = "%s   ·   %d cycles   ·   survivors %d-%d" % [
			who, result.cycles, result.survivors[0], result.survivors[1]]
		_panel.set_enabled(false)
		_finish_battle(result)
	else:
		_open_order_phase()


## The result is paid out in _after_playback instead, once the animation has caught
## up -- a player should watch the fight resolve before the rewards land.
func _on_battle_finished(_result: BattleResult) -> void:
	pass


func _on_speed_pressed() -> void:
	_speed = 1.0 if _speed >= 4.0 else _speed * 2.0
	_speed_button.text = "SPEED  %dx" % int(_speed)


## Skipping is not a shortcut around the simulation -- the result already exists.
## It only stops drawing it.
func _on_skip_pressed() -> void:
	while _queue_index < _queue.size():
		_apply_event(_queue[_queue_index])
		_queue_index += 1
	if _playing:
		_playing = false
		_after_playback()


# --- Event playback ----------------------------------------------------------

func _apply_event(e: Array) -> void:
	var kind: int = e[SimEv.F_KIND]
	var actor: int = e[SimEv.F_ACTOR]
	var target: int = e[SimEv.F_TARGET]

	match kind:
		SimEv.ATTACK:
			_lunge(actor, target)
			var shooter: Node3D = _visuals.get(actor)
			var victim: Node3D = _visuals.get(target)
			if shooter != null and victim != null:
				_vfx.muzzle_flash(shooter.position, victim.position,
					DAMAGE_COLOURS.get(e[SimEv.F_V1], Color.WHITE))
		SimEv.DAMAGE:
			_float_text(target, "-%d" % e[SimEv.F_V1], Color("ff6b5a"))
			_flash(target, Color("ff8a7a"))
			_on_damage(target, e[SimEv.F_V1])
			_stagger(actor, target, e[SimEv.F_V1])
			Audio.play("hit_light", -14.0)
			# F_V2, not F_V1. The DAMAGE event carries (amount, remaining hp) and this
			# passed the AMOUNT as the new health, so every name tag on the field showed
			# the size of the last hit a unit took instead of what it had left -- the
			# one number the tag exists to answer.
			_set_hp(target, e[SimEv.F_V2])
		SimEv.HEAL:
			_float_text(target, "+%d" % e[SimEv.F_V1], Color("6bd97a"))
			# Healing never updated the tag at all, so a repaired construct kept showing
			# whatever it was left on until something hit it again.
			_set_hp(target, e[SimEv.F_V2])
		SimEv.DETONATION:
			_float_text(target, String(e[SimEv.F_SID]).to_upper() + "!", Color("ffd452"))
			var detonated: Node3D = _visuals.get(target)
			if detonated != null:
				_vfx.burst(detonated.position, Color("ffd452"), 2.6)
				_vfx.shake(0.8)
			Audio.play("detonate", -6.0)
		SimEv.LINKAGE:
			_float_text(actor, "LINK", Color("9ad4ff"))
		SimEv.OVERDRIVE:
			_float_text(actor, "OVERDRIVE", Color("ffb03d"))
			_flash(actor, Color("ffb03d"))
			var charged: Node3D = _visuals.get(actor)
			if charged != null:
				_vfx.burst(charged.position, Color("ffb03d"), 2.0)
			Audio.play("overdrive", -7.0)
		SimEv.SEIZE:
			_float_text(actor, "SEIZED", Color("8b93a3"))
			Audio.play("seize", -9.0)
		SimEv.BRACE:
			_float_text(actor, "BRACE", Color("8fd3ff"))
		SimEv.VENT:
			_float_text(actor, "VENT", Color("7fe4c8"))
		SimEv.STATE_APPLIED:
			_float_text(target, String(e[SimEv.F_SID]).to_upper(), Color("c79bff"))
		SimEv.MOVED:
			_move_to(actor, e[SimEv.F_V1], e[SimEv.F_V2])
		SimEv.FALL_BACK:
			_float_text(actor, "FALL BACK", Color("ffc07a"))
		SimEv.DESTROYED:
			var wreck: Node3D = _visuals.get(target)
			if wreck != null:
				var team_colour: Color = COL_TEAM_A if SimDefs.team_of_ref(target) == SimDefs.TEAM_A else COL_TEAM_B
				_vfx.destruction(wreck.position, team_colour)
			Audio.play("destroy", -3.0)
			_destroy(target, actor)


func _lunge(actor_ref: int, target_ref: int) -> void:
	var actor: Node3D = _visuals.get(actor_ref)
	var target: Node3D = _visuals.get(target_ref)
	if actor == null or target == null:
		return

	# Face the target before striking. A construct that swings a hammer sideways at
	# nothing is worse than one that does not swing at all.
	var direction: Vector3 = target.position - actor.position
	if direction.length_squared() > 0.001:
		actor.rotation.y = atan2(direction.x, direction.z)

	# The arm plays its weapon's own strike; the body only leans into it. Melee leans
	# hard because the whole construct commits; a railgun barely moves.
	var rig: ConstructRig = _rigs.get(actor_ref)
	var melee: bool = false
	if rig != null:
		var weapon: String = _weapon_class(actor_ref, 3)
		if weapon.is_empty():
			weapon = _weapon_class(actor_ref, 2)
		melee = weapon in ["hammer", "maul", "ripper", "saw", "lance"]
		rig.strike("arm_r", weapon, get_tree())

	var home: Vector3 = actor.position
	var toward: Vector3 = home + direction.normalized() * (0.45 if melee else 0.12)
	var tween := create_tween()
	tween.tween_property(actor, "position", toward, 0.09).set_ease(Tween.EASE_OUT)
	tween.tween_property(actor, "position", home, 0.16).set_ease(Tween.EASE_IN)


## Squash plus a brief emissive pop. Impact reads from the deformation more than the
## colour, but the two together are what stop a hit from feeling like a number change.
func _flash(unit_ref: int, colour: Color) -> void:
	var node: Node3D = _visuals.get(unit_ref)
	if node == null:
		return
	var body: Node3D = node.get_child(0) as Node3D
	if body == null:
		return

	var squash := create_tween()
	squash.tween_property(body, "scale", Vector3(1.14, 0.88, 1.14), 0.06).set_ease(Tween.EASE_OUT)
	squash.tween_property(body, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK)

	# Flash every mesh in the assembled model, not just the first child -- a construct
	# is a dozen meshes now, and lighting one of them reads as a glitch.
	for mesh: MeshInstance3D in ConstructView._meshes(body):
		var material: StandardMaterial3D = mesh.material_override as StandardMaterial3D
		if material == null:
			continue
		material.emission_enabled = true
		material.emission = colour
		var glow := create_tween()
		glow.tween_property(material, "emission_energy_multiplier", 1.4, 0.05)
		glow.tween_property(material, "emission_energy_multiplier", 0.0, 0.22)


func _float_text(unit_ref: int, text: String, colour: Color) -> void:
	var node: Node3D = _visuals.get(unit_ref)
	if node == null:
		return
	var label := Label3D.new()
	label.text = text
	label.font_size = 46
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = colour
	# Scattered a little in all three axes: several events routinely land on the same
	# unit in the same tick, and stacked text is unreadable text. Engine RNG is fine
	# here -- nothing in the presentation layer feeds back into the simulation.
	label.position = node.position + Vector3(
		randf_range(-0.5, 0.5), 1.85 + randf_range(0.0, 0.7), randf_range(-0.3, 0.3))
	_arena.add_child(label)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector3(0, 1.1, 0), 0.85)
	tween.tween_property(label, "modulate:a", 0.0, 0.85).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)


## Sparks, shake and hitstop, all scaled by how hard the hit was relative to the
## target's health. Small hits must not shake or the screen never settles.
func _on_damage(unit_ref: int, amount: int) -> void:
	var node: Node3D = _visuals.get(unit_ref)
	var u: SimUnit = _unit_state.get(unit_ref)
	if node == null or u == null:
		return
	var severity: float = clampf(float(amount) / maxf(1.0, float(u.hp_max) * BattleVFX.HEAVY_FRACTION), 0.0, 1.0)
	_vfx.impact(node.position, DAMAGE_COLOURS.get(u.damage_type, Color("ff8a7a")), severity)
	# Only a hit at the very top of the severity curve. At 0.85 the trigger was a blow
	# worth 10% of max health, which for a 580 HP scout is an ordinary exchange -- so the
	# light units froze the screen every time anything connected with them.
	if severity >= 0.97:
		_vfx.shake(0.6 * severity)
		_vfx.hitstop(0.05)


## Shoves a construct away from whatever just hit it.
##
## The direction is real: it comes from the attacker's position in the DAMAGE event, so
## a unit shot from behind pitches forward and one clubbed from its left rolls right.
## A generic "flinch backwards" would have been a third of the work and would read as
## wrong precisely when the fight is most legible -- when two lines have closed and the
## player can see who is hitting whom.
##
## Converted into the TARGET'S OWN space before it reaches the rig, because the rig
## animates a model that has already been turned to face its own heading. Handing it a
## world direction makes every construct lurch toward world north.
##
## Nothing here decides anything: `severity` is scaled from the damage the simulation
## already reported, against the health the simulation already set.
func _stagger(attacker_ref: int, victim_ref: int, amount: int) -> void:
	if _downed.has(victim_ref):
		return
	var rig: ConstructRig = _rigs.get(victim_ref)
	var victim: Node3D = _visuals.get(victim_ref)
	var u: SimUnit = _unit_state.get(victim_ref)
	if rig == null or victim == null or u == null:
		return

	# The same severity curve the impact VFX use, so the shove, the sparks and the
	# hitstop all agree about how hard the blow was. A floor of 0.12 keeps chip damage
	# visible as a twitch -- a hit that moves nothing looks like a missed frame.
	var severity: float = clampf(
		float(amount) / maxf(1.0, float(u.hp_max) * BattleVFX.HEAVY_FRACTION), 0.12, 1.0)

	rig.stagger(_local_push(attacker_ref, victim_ref), severity)


func _set_hp(unit_ref: int, hp: int) -> void:
	var u: SimUnit = _unit_state.get(unit_ref)
	if u == null:
		return
	u.hp = hp
	var tag: Label3D = _name_tags.get(unit_ref)
	if tag != null:
		tag.text = _tag_text(u)


## Positions arrive periodically rather than every tick, so each one is tweened
## linearly over slightly more than the expected gap between reports. The result reads
## as continuous walking without the view ever inventing a position the simulation
## did not produce.
func _move_to(unit_ref: int, sim_x: int, sim_z: int) -> void:
	var node: Node3D = _visuals.get(unit_ref)
	if node == null:
		return
	var destination: Vector3 = _to_world(sim_x, sim_z)
	destination.y = node.position.y
	if _move_tweens.has(unit_ref):
		var previous: Tween = _move_tweens[unit_ref]
		if previous != null and previous.is_valid():
			previous.kill()
	var tween := create_tween()
	tween.tween_property(node, "position", destination, 0.2 / maxf(0.25, _speed)).set_trans(Tween.TRANS_LINEAR)
	_move_tweens[unit_ref] = tween

	# Face the direction of travel. Constructs that walk sideways read as sliding
	# scenery; ones that turn read as machines.
	var heading: Vector3 = destination - node.position
	if heading.length_squared() > 0.0004:
		var yaw: float = atan2(heading.x, heading.z)
		var turn := create_tween()
		turn.tween_property(node, "rotation:y", yaw, 0.18)


## A construct is destroyed: it buckles and falls over where it stood.
##
## It used to sink 1.4 m into the ground while squashing to 5% of its height. That is a
## completely legible "this unit is gone" and it is not a physical event at all -- twelve
## machines a battle each dissolving into the floor on the spot. A construct is a heavy
## thing on two legs, and the one thing it can do when it stops working is fall over.
##
## The topple lives in `ConstructRig` because the rig owns the limbs and the body's
## origin, and the body's origin is already at ground level -- so falling is a rotation
## about the feet and nothing has to be moved to keep it out of the floor.
func _destroy(unit_ref: int, killer_ref: int = -1) -> void:
	# Recorded so the camera stops framing a wreck. The node stays in `_visuals` -- it
	# falls rather than vanishing -- so aliveness cannot be inferred from the dictionary.
	_downed[unit_ref] = true
	var node: Node3D = _visuals.get(unit_ref)
	if node == null:
		return
	var tag: Label3D = _name_tags.get(unit_ref)
	if tag != null:
		tag.visible = false

	var rig: ConstructRig = _rigs.get(unit_ref)
	if rig == null:
		# No rig means a fallback body with no limbs to fold. Sinking is still better
		# than a construct standing intact with no health left.
		var tween := create_tween()
		tween.tween_property(node, "position", node.position + Vector3(0, -1.2, 0), 0.6) \
			.set_ease(Tween.EASE_IN)
		return

	rig.collapse(_local_push(killer_ref, unit_ref))

	# The landing, timed to the fall rather than to the kill. Announcing the impact as
	# the machine starts to tip puts the thud half a second before the thing that makes
	# it -- which reads as a bug in the audio, not as a mistimed animation.
	var thud := create_tween()
	thud.tween_interval(0.42)
	thud.tween_callback(func() -> void:
		if _vfx != null:
			_vfx.shake(0.45)
		Audio.play("hit_heavy", -6.0))


## Which way a unit is shoved by something at `from_ref`, in the TARGET'S own space.
##
## Shared by the stagger and the death fall so a construct is knocked down in the same
## direction it was being knocked around, and a machine killed from the front goes over
## backwards. Falls back to "straight back" when there is no attacker -- a detonation or
## a heat death has no direction to it.
func _local_push(from_ref: int, to_ref: int) -> Vector3:
	var target: Node3D = _visuals.get(to_ref)
	var source: Node3D = _visuals.get(from_ref)
	if target == null or source == null or not is_instance_valid(source):
		return Vector3(0.0, 0.0, 1.0)
	var world: Vector3 = target.position - source.position
	world.y = 0.0
	if world.length_squared() <= 0.0001:
		return Vector3(0.0, 0.0, 1.0)
	# Both nodes are children of `_arena`, so their `position` is already in one shared
	# frame; only the target's own yaw has to be undone.
	return target.transform.basis.inverse() * world.normalized()


func _sync_visual(u: SimUnit) -> void:
	var node: Node3D = _visuals.get(u.unit_ref)
	if node == null:
		return
	if u.alive:
		node.position = _to_world(u.pos_x, u.pos_z)
	var tag: Label3D = _name_tags.get(u.unit_ref)
	if tag != null:
		tag.text = _tag_text(u)
		tag.visible = u.alive


func _tag_text(u: SimUnit) -> String:
	return "%s\n%d" % [u.display_name, u.hp]


func _material(albedo: Color, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 0.9
	return material


## Pays the battle out through the command layer and returns to the hub. Only reached
## once the animation has caught up, so the player sees the fight resolve before the
## rewards land.
func _finish_battle(result: BattleResult) -> void:
	if _node_id.is_empty() or _reported:
		return
	_reported = true
	if result.winner == PLAYER_TEAM:
		Analytics.milestone("battle_won", {"cycles": result.cycles})
	Session.last_battle_damage = result.damage_dealt[PLAYER_TEAM]
	Session.last_battle_score = Tournament.score_of(result, _db.balance)
	if Session.pending_tournament:
		Session.pending_submission = BattleSubmission.from_result(
			_controller.setup, _controller.order_log, result,
			"tourney:" + String(Session.tournaments.tournament.get("id", "")),
			_db.content_version())
	if Session.pending_tournament:
		_node_id = "tournament"
		return Session.tournaments.build_setup(Session.profile())

	if Session.pending_boss:
		Session.pending_submission = BattleSubmission.from_result(
			_controller.setup, _controller.order_log, result,
			"boss:" + String(Session.coop.current_boss().get("id", "")), _db.content_version())
	if Session.pending_defence != null:
		Session.pending_submission = BattleSubmission.from_result(
			_controller.setup, _controller.order_log, result,
			"pvp:" + Session.pending_defence.id, _db.content_version())
	Session.report_battle(_node_id, result.winner == PLAYER_TEAM, result.cycles)
	Session.pending_node_id = ""

	var back := Button.new()
	back.text = "RETURN TO FOUNDRY"
	back.custom_minimum_size = Vector2(280, 52)
	back.anchor_left = 0.5
	back.anchor_right = 0.5
	back.anchor_top = 0.5
	back.anchor_bottom = 0.5
	back.offset_left = -140
	back.offset_right = 140
	back.offset_top = -26
	back.offset_bottom = 26
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/ui/hub.tscn"))
	_panel.get_parent().add_child(back)
