extends Node3D

## One grid fight: builds the board, animates the sim's events, and turns taps into actions.
##
## The sim decides everything. This scene asks `CombatSim` what is reachable, what an
## attack would do and what the enemies threaten, then draws the answers. After every
## action it plays only the events it has not shown yet.
##
## Undo is `CombatSim.replay` with one fewer action, followed by snapping every model to
## the replayed state. No inverse operations exist anywhere, so undo cannot drift from
## what a fresh replay would produce.
##
## Dev flags (after `--`):
##   --fight <id>   which fight (default proto_yard)
##   --seed <n>     tie-break seed
##   --bot          the player's turns are played by `CombatBot`, for demos and screenshots
##
## `scenes/shakedown.tscn` is this scene with `tutorial` on (012): the shakedown fight from
## `data/tutorial.json`, with the coach (`coach.gd`) over it.

## Centre-to-corner size of a hex, in metres. Pointy-top: a hex is sqrt(3) * HEX wide.
const HEX: float = 0.78
const SQRT3: float = 1.7320508
const COL_PLAYER := Color("4fa8d8")
const COL_ENEMY := Color("d8654f")
const COL_MOVE := Color(0.38, 0.70, 0.87, 0.42)
const COL_ATTACK := Color(0.90, 0.70, 0.24, 0.55)
const COL_TARGET := Color(0.95, 0.78, 0.30, 0.85)
const COL_ATTACK_FAINT := Color(0.90, 0.70, 0.24, 0.22)
const COL_SPAWN := Color(0.62, 0.36, 0.86, 0.55)
## A hive pad, and the same pad the turn before it builds (play-test 4: warn a turn ahead).
const COL_PAD := Color("a070e0")
const COL_PAD_DANGER := Color("ff3b30")
const COL_THREAT := Color(0.86, 0.30, 0.20, 0.50)
## A defend cache is YOURS to protect, so it wears your colour (docs/plans/art-and-audio.md:
## amber means "your action", and a cache is not one).
const COL_CACHE := Color("4fa8d8")
## Damage-type colours for impacts, indexed like the rules' `damage_types`.
const DAMAGE_COLOURS: Array[Color] = [Color("ffcf9a"), Color("ff7a3c"), Color("7fd4ff"), Color("b5e05a")]

const PITCH_DEG: float = 56.0
const ZOOM_MIN: float = 8.0
const ZOOM_MAX: float = 20.0
## A construct is 0.85 m and a tile 1.3 m. At the scale the art was built for, a machine
## covered a third of its tile and read as a figurine on a floor.
const MODEL_SCALE: float = 1.45
## The camera aims this far toward the near edge, so the side panels and the bottom bar
## sit over the apron rather than over the first row of tiles.
const AIM_NEAR: float = 0.9

## How long each kind of event holds the queue, in seconds. Play-test 1 called the old
## timings laggy (0.13 s a tile, a pause before every strike, half a second per death):
## a move is now one continuous glide, and nothing waits longer than it has to be seen.
const T_STEP: float = 0.075
const T_ATTACK: float = 0.14
const T_HIT: float = 0.16
const T_DESTROY: float = 0.30
const T_BANNER: float = 0.30

## The shakedown (012): set in `scenes/shakedown.tscn`.
@export var tutorial: bool = false

const Coach := preload("res://scripts/combat/coach.gd")

var _db: ContentDB
var _fight_id: String = "proto_yard"
var _coach: Control
## The coach's marker on the board: a ring and a bobbing chevron in the colour of your action.
var _coach_marker: Node3D
var _seed: int = 2026
var _bot: bool = false
## The fight belongs to the live run (`Run`): read from it, saved into it, reported to it.
var _run_mode: bool = false

var _setup: CombatSetup
var _state: CombatState
var _actions: Array = []
## Index in `_actions` where the current player turn began; undo cannot cross it.
var _turn_start: int = 0
## Events already animated.
var _shown: int = 0
var _busy: bool = false
var _selected: int = -1
## The selected construct's weapon (index into its arms), and whether it is ARMED.
## Unarmed, taps move; armed, taps aim. Two modes rather than one screen that means both:
## a mortar's landing tile is usually a tile the construct could also walk to, and no tap
## priority can tell which the player meant.
var _weapon: int = 0
var _armed: bool = false
## The ability armed instead of a weapon (index into the unit's abilities), or -1.
var _ability: int = -1
## An attack or ability waiting for its confirming second tap:
## `{ "ref", "ability": bool, "i": weapon or ability index, "cell": Vector2i }`, or empty.
var _pending: Dictionary = {}
## What each weapon-bar button stands for: `["weapon", w]` or `["ability", i]`.
var _bar_items: Array = []
## Props, pits' rims and spawn marks drawn on the board.
var _prop_views: Dictionary = {}
var _mark_views: Dictionary = {}
## The enemy whose line of fire is drawn in full (tapped), or -1; and whether every line is.
var _focus_enemy: int = -1
var _all_lines: bool = false

var _board: Node3D
var _units_root: Node3D
var _marks_root: Node3D
var _hint_quads: Dictionary = {}
var _threat_quads: Dictionary = {}
var _views: Dictionary = {}
## Scrap pile models, by hex.
var _pile_views: Dictionary = {}
## Board-space offset that centres the hex layout on the origin.
var _origin: Vector2 = Vector2.ZERO
var _pivot: Node3D
var _camera: Camera3D
var _zoom: float = 12.5
var _yaw_step: int = 0
var _vfx: BattleVFX
var _hud: CombatHUD


func _ready() -> void:
	_read_args()
	_db = ContentDB.load_all()
	if tutorial:
		_fight_id = String(_db.tutorial.get("fight", "shakedown"))
		_seed = int(_db.tutorial.get("seed", 1))
	_build_world()
	_hud = CombatHUD.new()
	_hud.glossary = _db.glossary
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(_hud)
	_hud.unit_card_pressed.connect(_select)
	_hud.weapon_pressed.connect(_bar_press)
	_hud.vent_pressed.connect(_vent)
	_hud.undo_pressed.connect(_undo)
	_hud.end_turn_pressed.connect(_end_turn)
	_hud.rotate_pressed.connect(_rotate)
	_hud.lines_pressed.connect(_toggle_lines)
	_hud.retry_pressed.connect(_start_fight)
	_hud.title_pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))
	_hud.continue_pressed.connect(_back_to_run)
	_run_mode = Run.in_fight() and not OS.get_cmdline_user_args().has("--fight") and not tutorial
	if tutorial:
		_coach = Coach.new()
		_coach.setup(self, _db.tutorial)
		_coach.finished.connect(_finish_tutorial)
		layer.add_child(_coach)
	_start_fight()


func _read_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--fight")
	if at >= 0 and at + 1 < args.size():
		_fight_id = args[at + 1]
	at = args.find("--seed")
	if at >= 0 and at + 1 < args.size():
		_seed = args[at + 1].to_int()
	_bot = args.has("--bot")


func _start_fight() -> void:
	_hud.hide_result()
	_actions = []
	if _coach != null:
		_coach.call("restart")
	if _run_mode:
		_setup = Run.fight_setup()
		# Resuming mid-fight: the saved combat actions replay to the exact turn.
		_actions = Run.fight_actions.duplicate(true)
	else:
		_setup = CombatSetup.build(_db.fights.get(_fight_id, {}), _db.combat_rules, _db.parts, _db.tiles,
			_db.balance.effectiveness, _seed)
	for error: String in _setup.errors:
		push_error("fight %s: %s" % [_setup.fight_id, error])
	_turn_start = 0
	for i: int in _actions.size():
		if int(_actions[i][0]) == CombatSim.ACT_END:
			_turn_start = i + 1
	_selected = -1
	_pending = {}
	_armed = false
	_state = CombatSim.replay(_setup, _actions)
	_build_board()
	_frame_camera()
	if _actions.is_empty():
		# A fresh fight plays from the very start, so the models start where the SETUP
		# puts them and the enemies' opening moves and grabs play out on screen.
		_spawn_initial()
		_shown = 0
		await _play_new_events()
	else:
		# A resumed fight does not replay its history on screen: it opens on the turn.
		_spawn_units()
		_shown = _state.events.size()
	_after_events()


## The coach's marker: stands on `cell`, or hides for null.
func coach_point(cell: Variant) -> void:
	if _coach_marker == null:
		_coach_marker = Node3D.new()
		add_child(_coach_marker)
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = HEX * 0.72
		torus.outer_radius = HEX * 0.86
		ring.mesh = torus
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = UIKit.AMBER
		glow.emission_enabled = true
		glow.emission = UIKit.AMBER
		glow.emission_energy_multiplier = 2.0
		ring.material_override = glow
		_coach_marker.add_child(ring)
		# The chevron hangs just over the ring on an empty hex and over the head of whatever
		# stands there -- high above an empty hex, the tilted camera puts it hexes away.
		var holder := Node3D.new()
		holder.name = "chevron_holder"
		_coach_marker.add_child(holder)
		var chevron := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.2
		cone.bottom_radius = 0.0
		cone.height = 0.34
		cone.radial_segments = 4
		chevron.mesh = cone
		chevron.material_override = glow
		holder.add_child(chevron)
		var bob := create_tween().set_loops()
		bob.tween_property(chevron, "position:y", 0.3, 0.45).set_trans(Tween.TRANS_SINE)
		bob.tween_property(chevron, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_SINE)
	_coach_marker.visible = cell != null
	if cell != null:
		var at: Vector2i = cell
		_coach_marker.position = _to_world(at.x, at.y) + Vector3(0, _tile_top(at.x, at.y) + 0.06, 0)
		var height: float = 0.8
		if _state != null and _state.unit_at(at.x, at.y) != null:
			height = 2.4
		elif _state != null and _state.props.has(at):
			height = 1.5
		(_coach_marker.get_node("chevron_holder") as Node3D).position.y = height


## The shakedown is over (or skipped): it counts as played either way, so the first NEW RUN
## stops offering it. `to_run` starts a run; otherwise back to the title.
func _finish_tutorial(to_run: bool) -> void:
	Profile.finish_tutorial()
	if to_run:
		Run.new_run()
		get_tree().change_scene_to_file("res://scenes/run_map.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/main.tscn")


## Hands the finished fight's action log to the run, which replays it for itself.
func _back_to_run() -> void:
	Run.finish_fight(_actions)
	get_tree().change_scene_to_file("res://scenes/run_map.tscn")


func _record() -> void:
	if _run_mode:
		Run.record_fight(_actions)


# --- World ------------------------------------------------------------------

func _build_world() -> void:
	# The same rig as the old battle scene: a warm sodium key and a cold fill from the
	# opposite side. See CLAUDE.md, "The visual system".
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	# The night HDRI lights and reflects (the metal finally has something to reflect); the
	# camera sees the game's own dark sky (art-sourcing.md, mode c).
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("0d0e12")
	var sky := Sky.new()
	var sky_material := PanoramaSkyMaterial.new()
	sky_material.panorama = load("res://art/thirdparty/polyhaven/hdris/dresden_station_night/dresden_station_night_1k.hdr")
	sky_material.energy_multiplier = 0.5
	sky.sky_material = sky_material
	environment.sky = sky
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.45
	environment.ambient_light_color = Color("2f3a52")
	environment.ambient_light_energy = 0.75
	environment.fog_enabled = true
	environment.fog_light_color = Color("241f26")
	environment.fog_light_energy = 0.7
	environment.fog_density = 0.010
	environment.fog_sky_affect = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.05
	environment.tonemap_white = 3.0
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.12
	environment.glow_enabled = true
	environment.glow_intensity = 0.36
	environment.glow_bloom = 0.12
	environment.glow_hdr_threshold = 1.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.environment = environment
	add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-46, 148, 0)
	key.light_energy = 1.15
	key.light_color = Color("ffd3a4")
	key.shadow_enabled = true
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 40.0
	key.shadow_bias = 0.04
	key.shadow_normal_bias = 1.4
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28, -34, 0)
	fill.light_energy = 1.0
	fill.light_color = Color("8aa3de")
	fill.light_specular = 0.35
	add_child(fill)

	# A fixed tilted camera on a pivot that turns in 90 degree steps. Free orbit hides
	# tiles on a grid, and hidden tiles are hidden information.
	_pivot = Node3D.new()
	add_child(_pivot)
	_camera = Camera3D.new()
	_camera.fov = 38.0
	_pivot.add_child(_camera)
	_place_camera()

	_board = Node3D.new()
	add_child(_board)
	_marks_root = Node3D.new()
	add_child(_marks_root)
	_units_root = Node3D.new()
	add_child(_units_root)

	_vfx = BattleVFX.new()
	add_child(_vfx)
	_vfx.setup(_pivot)


func _place_camera() -> void:
	var pitch: float = deg_to_rad(PITCH_DEG)
	var aim := Vector3(0.0, 0.0, AIM_NEAR)
	_camera.position = aim + Vector3(0.0, sin(pitch) * _zoom, cos(pitch) * _zoom)
	_camera.look_at_from_position(_camera.position, aim, Vector3.UP)


func _frame_camera() -> void:
	# Fit the board's larger side into the view, then leave the rest to the zoom control.
	var span: float = maxf(_origin.x, _origin.y) * 2.0 + HEX * 2.0
	_zoom = clampf(span * 1.5, ZOOM_MIN, ZOOM_MAX)
	_place_camera()


func _rotate(step: int) -> void:
	_yaw_step = (_yaw_step + step + 4) % 4
	var tween := create_tween()
	tween.tween_property(_pivot, "rotation:y", _pivot.rotation.y + step * PI * 0.5, 0.28) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Pointy-top hexes in odd-r offset: odd rows sit half a hex to the right.
func _to_world(x: int, y: int) -> Vector3:
	return Vector3(SQRT3 * HEX * (float(x) + 0.5 * float(y & 1)) - _origin.x, 0.0, 1.5 * HEX * float(y) - _origin.y)


func _tile_top(x: int, y: int) -> float:
	var def: Dictionary = _db.tiles[_setup.tiles[y * _setup.width + x]]
	if bool(def.get("blocks", false)):
		return 0.0
	return 0.02 + maxf(0.0, float(def.get("height", 0.0))) * 0.25


func _build_board() -> void:
	for child: Node in _board.get_children():
		child.queue_free()
	for child: Node in _marks_root.get_children():
		child.queue_free()
	_hint_quads.clear()
	_threat_quads.clear()
	_pile_views.clear()
	_origin = Vector2(SQRT3 * HEX * (float(_setup.width) - 0.5) * 0.5, 1.5 * HEX * float(_setup.height - 1) * 0.5)

	for y: int in _setup.height:
		for x: int in _setup.width:
			var def: Dictionary = _db.tiles[_setup.tiles[y * _setup.width + x]]
			var blocks: bool = bool(def.get("blocks", false))
			var top: float = _tile_top(x, y)
			if _setup.pit[y * _setup.width + x] == 1:
				_board.add_child(_pit(x, y))
				_hint_quads[Vector2i(x, y)] = _quad(x, y, 0.012, HEX * 0.80)
				_threat_quads[Vector2i(x, y)] = _quad(x, y, 0.008, HEX * 0.94)
				continue
			var slab := MeshInstance3D.new()
			slab.mesh = _hex_mesh(HEX * 0.96, 0.3 + top)
			slab.position = _to_world(x, y) + Vector3(0, -0.15 + top * 0.5, 0)
			# The ground sits UNDER the machines in value (art-and-audio.md): a photographed
			# surface per terrain type, at low frequency, tinted to its field colour.
			slab.material_override = _tile_material(def, (x + y) % 2 == 1)
			slab.set_meta("tile", Vector2i(x, y))
			_board.add_child(slab)
			if blocks:
				_board.add_child(_scrap_heap(x, y))
			_dress_tile(String(def.get("id", "open")), x, y, top)
			_hint_quads[Vector2i(x, y)] = _quad(x, y, top + 0.012, HEX * 0.80)
			_threat_quads[Vector2i(x, y)] = _quad(x, y, top + 0.008, HEX * 0.94)

	_build_edges()
	_build_surroundings()


## The board ends in a line you can see (play-test 4: "the battlefield needs edges"): a
## steel curb along every hex side that faces off the board, traced from the real hex
## geometry so it follows the board's ragged odd-r outline exactly.
func _build_edges() -> void:
	var curb: StandardMaterial3D = Surfaces.pbr("rusty_painted_metal", Color(0.46, 0.43, 0.40), 1.4, 0.55, 0.8)
	var box := BoxMesh.new()
	box.size = Vector3(HEX * 1.1, 0.24, 0.13)
	for y: int in _setup.height:
		for x: int in _setup.width:
			var here := Vector2i(x, y)
			for dir: int in 6:
				var n: Vector2i = Hex.neighbor(here, dir)
				if n.x >= 0 and n.y >= 0 and n.x < _setup.width and n.y < _setup.height:
					continue
				var a: Vector3 = _to_world(x, y)
				var out: Vector3 = (_to_world(n.x, n.y) - a).normalized()
				var segment := MeshInstance3D.new()
				segment.mesh = box
				segment.material_override = curb
				# Just outside the slab's edge; the box's long side runs along the hex side.
				segment.position = a + out * (SQRT3 * HEX * 0.5 + 0.05) + Vector3(0, 0.0, 0)
				segment.rotation.y = atan2(out.x, out.z)
				_board.add_child(segment)


## Each terrain type's surface: what it IS reads from the photograph, what it DOES from the
## field colour it is tinted to (art-and-audio.md, read contracts). Frequency is capped --
## large texture scale, soft normals -- so the machines stay the busiest thing on screen.
const TILE_SURFACES: Dictionary = {
	"open": ["metal_plate_02", 2.3, 0.5, 0.45, 0.55],     # set, tint gain, texture scale, metallic, normal
	"rubble": ["rocky_gravel", 1.9, 0.7, 0.0, 0.9],
	"scrap": ["corrugated_iron_02", 1.6, 0.8, 0.4, 0.7],
	"slag": ["rock_ground", 1.2, 0.6, 0.0, 0.8],
	"ridge": ["damaged_concrete_floor", 2.0, 0.55, 0.0, 0.8],
	"pit": ["rusty_painted_metal", 0.8, 0.9, 0.3, 0.6],
	"barrel": ["metal_plate_02", 2.3, 0.5, 0.45, 0.55],
	"crate": ["metal_plate_02", 2.3, 0.5, 0.45, 0.55],
}


func _tile_material(def: Dictionary, alternate: bool) -> StandardMaterial3D:
	var id: String = String(def.get("id", "open"))
	var surface: Array = TILE_SURFACES.get(id, TILE_SURFACES["open"])
	var field: Color = Color(String(def.get("colour", "1a1e26")))
	if alternate:
		field = field.lightened(0.04)
	var tint := Color(minf(1.0, field.r * float(surface[1])), minf(1.0, field.g * float(surface[1])), minf(1.0, field.b * float(surface[1])))
	return Surfaces.pbr(String(surface[0]), tint, float(surface[2]), float(surface[3]), float(surface[4]))


## What stands on a tile beyond its surface: rubble has chunks you could hide behind, slag a
## glowing pool you should not stand in, a ridge a lit lip that says "higher".
func _dress_tile(id: String, x: int, y: int, top: float) -> void:
	var at: Vector3 = _to_world(x, y) + Vector3(0, top, 0)
	var h: int = IntentAI.mix(x, y, 23, 5)
	match id:
		"rubble":
			var chunk_material: StandardMaterial3D = Surfaces.pbr("damaged_concrete_floor", Color(0.55, 0.53, 0.5), 1.4, 0.0, 0.8)
			for i: int in 5:
				var chunk := MeshInstance3D.new()
				var box := BoxMesh.new()
				var s: float = 0.08 + float((h >> (i * 3)) & 7) * 0.018
				box.size = Vector3(s * 1.4, s * 0.8, s)
				chunk.mesh = box
				var angle: float = float(i) / 5.0 * TAU + float(h & 15) * 0.1
				var reach: float = HEX * (0.25 + float((h >> (i * 2)) & 3) * 0.12)
				chunk.position = at + Vector3(cos(angle) * reach, box.size.y * 0.4, sin(angle) * reach)
				chunk.rotation = Vector3(float((h >> i) & 3) * 0.25, angle, float((h >> (i + 1)) & 3) * 0.2)
				chunk.material_override = chunk_material
				_board.add_child(chunk)
		"slag":
			# A crusted glow, not a lamp: slag is a hazard to notice, but the brightest thing on
			# the board must stay the machines (art-and-audio.md, value layers).
			var pool := MeshInstance3D.new()
			pool.mesh = _hex_mesh(HEX * 0.5, 0.02)
			pool.position = at + Vector3(0, 0.012, 0)
			var molten := StandardMaterial3D.new()
			molten.albedo_color = Color("7a2a10")
			molten.emission_enabled = true
			molten.emission = Color("d8401a")
			molten.emission_energy_multiplier = 0.55
			molten.albedo_texture = load("res://art/thirdparty/polyhaven/textures/rock_ground/rock_ground_diff_1k.jpg")
			molten.uv1_triplanar = true
			molten.uv1_world_triplanar = true
			molten.uv1_scale = Vector3.ONE * 1.2
			pool.material_override = molten
			_board.add_child(pool)
			var heat := OmniLight3D.new()
			heat.light_color = Color("ff6a2a")
			heat.light_energy = 0.5
			heat.omni_range = 1.6
			heat.position = at + Vector3(0, 0.35, 0)
			_board.add_child(heat)
		"ridge":
			var lip := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = HEX * 0.88
			torus.outer_radius = HEX * 0.96
			torus.ring_segments = 6
			torus.rings = 4
			lip.mesh = torus
			lip.scale = Vector3(1, 0.18, 1)
			lip.position = at + Vector3(0, 0.0, 0)
			lip.material_override = Surfaces.pbr("damaged_concrete_floor", Color(0.62, 0.64, 0.66), 1.4, 0.0, 0.6)
			_board.add_child(lip)


## Beyond the curb: dark asphalt and a ring of yard -- containers, wrecks, tyres and
## floodlights -- far enough out that no camera angle loses a tile behind them, placed from
## a hash of the fight so a map dresses the same way every time.
func _build_surroundings() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(_origin.x * 2.0 + 60.0, _origin.y * 2.0 + 60.0)
	ground.mesh = plane
	ground.position = Vector3(0, -0.31, 0)
	ground.material_override = Surfaces.pbr("asphalt_02", Color(0.30, 0.29, 0.28), 0.3)
	_board.add_child(ground)
	var half := Vector2(_origin.x + HEX * 2.0, _origin.y + HEX * 2.0)
	var seed: int = IntentAI.mix(_setup.rng_seed, _setup.width, _setup.height, 77)
	var tall: PackedStringArray = ["container_0", "container_1", "car_stack_2"]
	var low: PackedStringArray = ["tyre_stack_0", "tyre_stack_1", "tyre_stack_2", "car_stack_0", "car_stack_1", "barrier_0"]
	var count: int = 26
	for i: int in count:
		var h: int = IntentAI.mix(seed, i, 3, 11)
		var angle: float = TAU * (float(i) + float(h % 100) / 200.0) / float(count)
		var far: bool = i % 3 != 0
		var reach: float = (5.5 if far else 2.8) + float((h >> 8) % 100) / 100.0 * 2.5
		var at := Vector3(cos(angle) * (half.x + reach), -0.31, sin(angle) * (half.y + reach))
		var names: PackedStringArray = tall if far else low
		var prop: Node3D = Surfaces.kit(names[(h >> 4) % names.size()], 0.35)
		if prop == null:
			continue
		prop.position = at
		prop.rotation.y = -angle + float((h >> 12) % 60 - 30) * 0.02
		prop.scale = Vector3.ONE * 0.62
		_board.add_child(prop)
	# Floodlights on the diagonals: the diegetic source of the warm key light.
	for k: int in 4:
		var angle: float = TAU * (float(k) + 0.5) / 4.0
		var at := Vector3(cos(angle) * (half.x + 3.4), -0.31, sin(angle) * (half.y + 3.4))
		var lamp: Node3D = Surfaces.kit("floodlight", 0.2)
		if lamp == null:
			continue
		lamp.position = at
		lamp.rotation.y = -angle + PI * 0.5
		lamp.scale = Vector3.ONE * 0.7
		_board.add_child(lamp)
		var light := OmniLight3D.new()
		light.light_color = Color("ffc27a")
		light.light_energy = 1.4
		light.omni_range = 7.0
		light.position = at + Vector3(0, 3.0, 0)
		_board.add_child(light)


## A pit: a hex hole with a faint rim, so "you can be shoved in here" reads at a glance.
func _pit(x: int, y: int) -> Node3D:
	var root := Node3D.new()
	root.position = _to_world(x, y)
	var hole := MeshInstance3D.new()
	hole.mesh = _hex_mesh(HEX * 0.9, 1.2)
	hole.position = Vector3(0, -0.75, 0)
	hole.material_override = _material(Color("040405"), 1.0)
	root.add_child(hole)
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = HEX * 0.8
	torus.outer_radius = HEX * 0.9
	torus.ring_segments = 6
	torus.rings = 6
	rim.mesh = torus
	rim.scale = Vector3(1, 0.15, 1)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("3a2418")
	glow.emission_enabled = true
	glow.emission = Color("7a3a1c")
	glow.emission_energy_multiplier = 0.6
	rim.material_override = glow
	root.add_child(rim)
	return root


## A six-sided prism, pointy-top. CylinderMesh already puts a corner at +Z (north), which
## is exactly the pointy-top layout `_to_world` uses -- so it must NOT be turned. An extra
## 30 degree turn once made every tile meet its neighbours at the corners, and distances
## counted by eye came out one short (play-test 2).
func _hex_mesh(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	mesh.rings = 1
	return mesh


## A blocking hex: a heap of rusted slabs, dressed from a hash of its cell so a map
## looks the same every time it is loaded.
func _scrap_heap(x: int, y: int) -> Node3D:
	var heap := Node3D.new()
	heap.position = _to_world(x, y)
	var h: int = IntentAI.mix(x, y, 91, 7)
	for i: int in 3:
		var piece := MeshInstance3D.new()
		var box := BoxMesh.new()
		var s: float = 0.32 + float((h >> (i * 5)) & 7) * 0.045
		box.size = Vector3(HEX * s * 1.5, 0.22 + float((h >> (i * 3)) & 3) * 0.12, HEX * s * 1.2)
		piece.mesh = box
		piece.position = Vector3(float(((h >> (i * 7)) & 7) - 3) * 0.05, box.size.y * 0.5 + i * 0.16, float(((h >> (i * 4)) & 7) - 3) * 0.05)
		piece.rotation.y = float((h >> (i * 6)) & 15) * 0.2
		piece.material_override = Surfaces.pbr("rusty_painted_metal" if i % 2 == 0 else "corrugated_iron_02",
			Color(0.7, 0.55, 0.45).lerp(Color(0.45, 0.47, 0.5), float(i) * 0.4), 1.8, 0.4, 0.8)
		heap.add_child(piece)
	return heap


func _quad(x: int, y: int, height: float, size: float) -> MeshInstance3D:
	var quad := MeshInstance3D.new()
	quad.mesh = _hex_mesh(size, 0.012)
	quad.position = _to_world(x, y) + Vector3(0, height, 0)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material_override = material
	quad.visible = false
	_marks_root.add_child(quad)
	return quad


func _material(colour: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	material.metallic = metallic
	return material


# --- Units ------------------------------------------------------------------

func _spawn_initial() -> void:
	_clear_board_objects()
	for u: GridUnit in _setup.units:
		_views[u.ref] = _build_view(u)


func _spawn_units() -> void:
	_clear_board_objects()
	for u: GridUnit in _state.units:
		if u.alive:
			_views[u.ref] = _build_view(u)
	for cell: Variant in _state.pile_cells():
		_spawn_pile(cell)
	for cell: Variant in _state.props:
		_spawn_prop(cell, String((_state.props[cell] as Dictionary)["kind"]))


func _clear_board_objects() -> void:
	for child: Node in _units_root.get_children():
		child.queue_free()
	_views.clear()
	_pile_views.clear()
	_prop_views.clear()


## A prop: a fuel drum (red oxide, a bright band so it reads as dangerous) or a crate wall.
func _spawn_prop(cell: Vector2i, kind: String) -> void:
	if _prop_views.has(cell):
		return
	var root := Node3D.new()
	root.position = _to_world(cell.x, cell.y)
	if kind == "barrel":
		for i: int in 2:
			var drum := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.2
			cyl.bottom_radius = 0.2
			cyl.height = 0.55
			drum.mesh = cyl
			drum.position = Vector3(-0.14 + i * 0.3, 0.28, -0.05 + i * 0.12)
			# Red-rust: the danger family -- this thing explodes (art-and-audio.md).
			drum.material_override = Surfaces.pbr("rusty_painted_metal", Color(0.85, 0.42, 0.34), 2.6, 0.35, 0.7)
			root.add_child(drum)
			var band := MeshInstance3D.new()
			var band_mesh := CylinderMesh.new()
			band_mesh.top_radius = 0.205
			band_mesh.bottom_radius = 0.205
			band_mesh.height = 0.07
			band.mesh = band_mesh
			band.position = drum.position + Vector3(0, 0.12, 0)
			var hot := StandardMaterial3D.new()
			hot.albedo_color = Color("ffb04a")
			hot.emission_enabled = true
			hot.emission = Color("ff8a2a")
			hot.emission_energy_multiplier = 0.9
			band.material_override = hot
			root.add_child(band)
	else:
		for s: Array in [[Vector3(0.7, 0.5, 0.5), Vector3(0, 0.25, 0)], [Vector3(0.5, 0.4, 0.45), Vector3(0.05, 0.7, 0)]]:
			var crate := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = s[0]
			crate.mesh = box
			crate.position = s[1]
			# Neutral steel: the container photograph is green paint, and green means a gain.
			crate.material_override = Surfaces.pbr("corrugated_iron_02", Color(0.5, 0.5, 0.52), 1.6, 0.45, 0.7)
			root.add_child(crate)
	_units_root.add_child(root)
	_prop_views[cell] = root


func _build_view(u: GridUnit) -> Dictionary:
	var root := Node3D.new()
	root.position = _to_world(u.x, u.y) + Vector3(0, _tile_top(u.x, u.y), 0)
	# Player machines face the far edge, enemies the near one.
	root.rotation.y = PI if u.team == GridUnit.TEAM_PLAYER else 0.0
	_units_root.add_child(root)

	var colour: Color = COL_PLAYER if u.team == GridUnit.TEAM_PLAYER else COL_ENEMY
	# Crew machines carry their crew number; an enemy a two-digit number from the fight's
	# seed, the same every replay (presentation only).
	var number: int = u.slot + 1 if u.team == GridUnit.TEAM_PLAYER else 10 + IntentAI.mix(_setup.rng_seed, u.ref, 7, 29) % 89
	var model: Node3D = _cache_model() if u.objective else ConstructView.build_parts(u.part_ids, _db, colour, u.level, number)
	model.scale = Vector3.ONE * (1.0 if u.objective else MODEL_SCALE)
	root.add_child(model)
	var ring: MeshInstance3D = _team_ring(COL_CACHE if u.objective else colour)
	root.add_child(ring)

	var rig := ConstructRig.new()
	rig.bind(model)

	var tag := Label3D.new()
	tag.font_size = 40
	tag.pixel_size = 0.0045
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.position = Vector3(0, 1.75, 0)
	tag.outline_size = 12
	tag.outline_modulate = Color(0, 0, 0, 0.9)
	tag.modulate = (COL_CACHE if u.objective else colour).lightened(0.45)
	root.add_child(tag)

	# Play-test 4: not every enemy drops scrap. The ones that will say so, over their tag,
	# in the colour of a gain -- which makes "who do I finish first" a real choice.
	if u.team == GridUnit.TEAM_ENEMY and u.carries_scrap and not u.objective:
		var loot := Sprite3D.new()
		loot.texture = load("res://art/icons/scrap.svg")
		loot.pixel_size = 0.0042
		loot.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		loot.no_depth_test = true
		loot.shaded = false
		loot.modulate = UIKit.GREEN.lightened(0.2)
		loot.position = Vector3(0, 2.2, 0)
		root.add_child(loot)

	var view: Dictionary = {"root": root, "model": model, "rig": rig, "ring": ring, "tag": tag, "dead": false}
	_set_tag(view, u)
	for w: int in u.weapons.size():
		if not u.can_fire(w):
			_hide_arm(view, w)
	return view


## A salvage cache (defend objective): a stack of strapped crates. Not a machine
## silhouette on purpose -- it must read as cargo to protect, not as a fighter.
func _cache_model() -> Node3D:
	var root := Node3D.new()
	var wood: StandardMaterial3D = _material(Color("6e5a3a"), 0.85, 0.05)
	var strap: StandardMaterial3D = _material(Color("2a2926"), 0.6, 0.6)
	var sizes: Array = [[Vector3(0.62, 0.34, 0.5), Vector3(0, 0.17, 0), 0.0],
		[Vector3(0.44, 0.28, 0.4), Vector3(0.04, 0.48, 0.02), 0.3],
		[Vector3(0.3, 0.2, 0.3), Vector3(-0.06, 0.72, -0.02), -0.2]]
	for s: Array in sizes:
		var crate := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = s[0]
		crate.mesh = box
		crate.position = s[1]
		crate.rotation.y = float(s[2])
		crate.material_override = wood
		root.add_child(crate)
		var band := MeshInstance3D.new()
		var band_box := BoxMesh.new()
		band_box.size = (s[0] as Vector3) * Vector3(1.02, 0.18, 1.02)
		band.mesh = band_box
		band.position = s[1]
		band.rotation.y = float(s[2])
		band.material_override = strap
		root.add_child(band)
	return root


## A scrap pile: what a destroyed machine becomes. Walkable, worth scrap and a patch-up
## to whoever ends a move on it -- so it gets a glint, because it is a thing to go for.
func _spawn_pile(cell: Vector2i) -> void:
	if _pile_views.has(cell):
		return
	var pile := Node3D.new()
	pile.position = _to_world(cell.x, cell.y) + Vector3(0, _tile_top(cell.x, cell.y), 0)
	var h: int = IntentAI.mix(cell.x, cell.y, 55, 3)
	for i: int in 6:
		var bit := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.12 + float((h >> i) & 3) * 0.05, 0.06 + float((h >> (i + 2)) & 3) * 0.03, 0.1 + float((h >> (i + 4)) & 3) * 0.04)
		bit.mesh = box
		var angle: float = float(i) / 6.0 * TAU + float(h & 7) * 0.2
		bit.position = Vector3(cos(angle) * 0.2, box.size.y * 0.5 + float(i % 2) * 0.05, sin(angle) * 0.2)
		bit.rotation = Vector3(float((h >> i) & 3) * 0.3, angle, 0.0)
		bit.material_override = Surfaces.pbr("metal_plate_02", Color(0.75, 0.7, 0.62).lerp(Color(0.9, 0.72, 0.45), float(i % 3) * 0.35), 3.0, 0.8, 0.6)
		pile.add_child(bit)
	# Scrap you can take is a gain: a faint green ring under it (art-and-audio.md).
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = HEX * 0.42
	torus.outer_radius = HEX * 0.48
	ring.mesh = torus
	ring.scale = Vector3(1, 0.2, 1)
	ring.position.y = 0.02
	var gain := StandardMaterial3D.new()
	gain.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gain.albedo_color = Color(UIKit.GREEN, 0.9)
	ring.material_override = gain
	pile.add_child(ring)
	var glint := OmniLight3D.new()
	glint.light_color = Color("ffcf7a")
	glint.light_energy = 0.6
	glint.omni_range = 1.2
	glint.position = Vector3(0, 0.5, 0)
	pile.add_child(glint)
	_units_root.add_child(pile)
	_pile_views[cell] = pile
	var tween := create_tween()
	pile.scale = Vector3.ONE * 0.2
	tween.tween_property(pile, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _remove_pile(cell: Vector2i) -> void:
	var pile: Node3D = _pile_views.get(cell)
	if pile == null:
		return
	_pile_views.erase(cell)
	var tween := create_tween()
	tween.tween_property(pile, "scale", Vector3.ONE * 0.05, 0.14)
	tween.tween_callback(pile.queue_free)


## The ground ring is half of the team read: lit eyes are the other half. See CLAUDE.md.
func _team_ring(colour: Color) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.52
	torus.rings = 24
	torus.ring_segments = 4
	ring.mesh = torus
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(colour.r, colour.g, colour.b, 0.85)
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = 1.3
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = material
	ring.position = Vector3(0, 0.03, 0)
	ring.scale = Vector3(1, 0.3, 1)
	return ring


## HP, then the state a player must read before moving: heat, a mark, a seize.
func _set_tag(view: Dictionary, u: GridUnit) -> void:
	var lines: PackedStringArray = ["%d/%d" % [u.hp, u.max_hp]]
	var status: PackedStringArray = []
	if not u.kind.is_empty():
		status.append(u.kind.to_upper())
	if u.unshovable and not u.objective:
		status.append("ANCHORED")
	if u.shield > 0:
		status.append("SHIELD")
	if u.team == GridUnit.TEAM_PLAYER and not u.objective and u.heat > 0:
		status.append("HEAT %d/%d" % [u.heat, u.heat_cap])
	if u.marked:
		status.append("MARKED")
	if u.seized:
		status.append("SEIZED")
	elif u.overheated:
		status.append("OVERHEATED")
	if not status.is_empty():
		lines.append(" · ".join(status))
	(view["tag"] as Label3D).text = "\n".join(lines)


func _refresh_tag(ref: int) -> void:
	var u: GridUnit = _state.unit(ref)
	if u != null and _views.has(ref):
		_set_tag(_views[ref], u)


## The torn arm leaves the model: the weapon that just stopped existing in the sim
## stops existing on screen too.
func _hide_arm(view: Dictionary, w: int) -> void:
	var socket: Node = _find_node(view["model"], "socket_arm_l" if w == GridUnit.ARM_L else "socket_arm_r")
	if socket != null:
		for child: Node in socket.get_children():
			if child is Node3D:
				(child as Node3D).visible = false


func _find_node(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for child: Node in node.get_children():
		var found: Node = _find_node(child, name)
		if found != null:
			return found
	return null


## A destroyed machine bursts: the model flies apart and is gone, and the pile the sim
## drops on its hex takes its place. The old slow topple read as lag and left a body that
## blocked the hex for no visible reason (play-test 1).
func _burst(view: Dictionary, push: Vector3) -> void:
	if bool(view["dead"]):
		return
	view["dead"] = true
	var root: Node3D = view["root"]
	(view["tag"] as Label3D).visible = false
	(view["ring"] as MeshInstance3D).visible = false
	var model: Node3D = view["model"]
	var world_push: Vector3 = root.transform.basis * push
	var tween := create_tween().set_parallel(true)
	tween.tween_property(model, "position", model.position + Vector3(world_push.x * 0.3, 0.35, world_push.z * 0.3), 0.12)
	tween.tween_property(model, "scale", model.scale * 0.05, 0.22).set_delay(0.06).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(root.queue_free)


func _process(delta: float) -> void:
	for ref: Variant in _views:
		((_views[ref] as Dictionary)["rig"] as ConstructRig).update(delta)


# --- Playback ---------------------------------------------------------------

func _play_new_events() -> void:
	_busy = true
	_clear_marks()
	while _shown < _state.events.size():
		var e: Array = _state.events[_shown]
		_shown += 1
		# A move is played as ONE glide along its whole path: collect the run of STEPs.
		if int(e[GridEv.F_KIND]) == GridEv.STEP:
			var actor: int = int(e[GridEv.F_ACTOR])
			var path: Array[Vector2i] = [Vector2i(int(e[GridEv.F_X]), int(e[GridEv.F_Y]))]
			while _shown < _state.events.size() and int(_state.events[_shown][GridEv.F_KIND]) == GridEv.STEP \
					and int(_state.events[_shown][GridEv.F_ACTOR]) == actor:
				var next: Array = _state.events[_shown]
				path.append(Vector2i(int(next[GridEv.F_X]), int(next[GridEv.F_Y])))
				_shown += 1
			await _walk(actor, path)
			continue
		await _animate(e)
		while _vfx.is_frozen():
			await get_tree().process_frame
	_busy = false


func _animate(e: Array) -> void:
	var kind: int = int(e[GridEv.F_KIND])
	var actor: int = int(e[GridEv.F_ACTOR])
	var target: int = int(e[GridEv.F_TARGET])
	var cell := Vector2i(int(e[GridEv.F_X]), int(e[GridEv.F_Y]))
	match kind:
		GridEv.ROUND_START:
			_hud.set_banner("ROUND %d" % int(e[GridEv.F_V1]))
			await _wait(T_BANNER)
		GridEv.TURN_END:
			_hud.set_banner("ENEMY FIRE", UIKit.RED)
			await _wait(T_BANNER)
		GridEv.MOVED:
			if _views.has(actor):
				((_views[actor] as Dictionary)["rig"] as ConstructRig).set_moving(false)
		GridEv.INTENT_SET:
			await _wait(0.03)
		GridEv.ATTACK:
			var packed: int = int(e[GridEv.F_V2])
			await _attack(actor, cell, int(e[GridEv.F_V1]), Vector2i(packed % 64, packed / 64))
		GridEv.DAMAGE:
			await _hit(actor, target, int(e[GridEv.F_V1]))
		GridEv.DESTROYED:
			await _destroyed(actor, target)
		GridEv.MISSED:
			_float_text(_to_world(cell.x, cell.y) + Vector3(0, 0.9, 0), "MISS", UIKit.TEXT_DIM)
			await _wait(0.18)
		GridEv.SHOVED:
			await _shoved(actor, target, cell)
		GridEv.BUMP:
			_float_text(_unit_pos(target) + Vector3(0, 2.2, 0), "BUMP", UIKit.GOLD)
			_vfx.shake(0.25)
			Audio.play("hit_light", -8.0)
			await _wait(0.15)
		GridEv.HEAT:
			_refresh_tag(actor)
		GridEv.OVERHEAT:
			_refresh_tag(actor)
			_float_text(_unit_pos(actor) + Vector3(0, 2.2, 0), "OVERHEATED", UIKit.RED)
			Audio.play("seize", -8.0)
			await _wait(0.35)
		GridEv.SEIZED:
			_refresh_tag(actor)
			_float_text(_unit_pos(actor) + Vector3(0, 2.2, 0), "SEIZED", UIKit.RED)
			await _wait(0.2)
		GridEv.VENTED:
			_refresh_tag(actor)
			_float_text(_unit_pos(actor) + Vector3(0, 2.2, 0), "VENTED", UIKit.BLUE)
			Audio.play("cycle", -10.0)
			await _wait(0.3)
		GridEv.MARKED:
			_refresh_tag(target)
			_float_text(_unit_pos(target) + Vector3(0, 2.4, 0), "MARKED", UIKit.GOLD)
			await _wait(0.2)
		GridEv.PART_TORN:
			await _torn(target, int(e[GridEv.F_V1]))
		GridEv.PILE_DROPPED:
			_spawn_pile(cell)
		GridEv.PILE_TAKEN:
			_remove_pile(cell)
			var gain: String = ("+%d SCRAP" % int(e[GridEv.F_V1])) if actor < 10 else "SCRAP LOST"
			if int(e[GridEv.F_V2]) > 0:
				gain += "  +%d HP" % int(e[GridEv.F_V2])
			_float_text(_to_world(cell.x, cell.y) + Vector3(0, 1.9, 0), gain, UIKit.GREEN if actor < 10 else UIKit.RED)
			_refresh_tag(actor)
			Audio.play("ui_confirm", -8.0)
			await _wait(0.12)
		GridEv.PROP_PLACED:
			_spawn_prop(cell, "barrel" if int(e[GridEv.F_V1]) == 1 else "crate")
		GridEv.PROP_HIT:
			if _prop_views.has(cell):
				var prop: Node3D = _prop_views[cell]
				var jolt := create_tween()
				jolt.tween_property(prop, "scale", Vector3(1.12, 0.9, 1.12), 0.05)
				jolt.tween_property(prop, "scale", Vector3.ONE, 0.1)
		GridEv.PROP_BROKEN:
			if _prop_views.has(cell):
				(_prop_views[cell] as Node3D).queue_free()
				_prop_views.erase(cell)
			_vfx.destruction(_to_world(cell.x, cell.y) + Vector3(0, 0.3, 0), Color("9a9a9a"))
		GridEv.EXPLOSION:
			var at: Vector3 = _to_world(cell.x, cell.y) + Vector3(0, 0.4, 0)
			_vfx.fireball(_to_world(cell.x, cell.y), 1.0)
			_vfx.burst(at, Color("ff8a3c"), 2.2)
			_vfx.shake(0.55)
			_float_text(at + Vector3(0, 1.2, 0), "BOOM", Color("ffb04a"))
			Audio.play("destroy", -2.0)
			await _wait(0.22)
		GridEv.FELL:
			if _views.has(target):
				var view: Dictionary = _views[target]
				var root: Node3D = view["root"]
				_views.erase(target)
				var drop := create_tween()
				drop.tween_property(root, "position", _to_world(cell.x, cell.y) + Vector3(0, -2.2, 0), 0.32).set_ease(Tween.EASE_IN)
				drop.tween_callback(root.queue_free)
			_float_text(_to_world(cell.x, cell.y) + Vector3(0, 1.4, 0), "INTO THE PIT", UIKit.RED)
			Audio.play("destroy", -6.0)
			await _wait(0.35)
		GridEv.ABILITY:
			var user: GridUnit = _state.unit(actor)
			if user != null and int(e[GridEv.F_V1]) < user.abilities.size():
				_float_text(_unit_pos(actor) + Vector3(0, 2.3, 0), String(user.abilities[int(e[GridEv.F_V1])]["name"]).to_upper(), UIKit.BLUE)
			Audio.play("cycle", -10.0)
			await _wait(0.12)
		GridEv.PULLED:
			if _views.has(target):
				var root: Node3D = (_views[target] as Dictionary)["root"]
				var pull := create_tween()
				pull.tween_property(root, "position", _to_world(cell.x, cell.y) + Vector3(0, _tile_top(cell.x, cell.y), 0), 0.18)
				await pull.finished
		GridEv.SPAWN_MARKED:
			_float_text(_to_world(cell.x, cell.y) + Vector3(0, 1.0, 0), "HIVE PAD SET", Color("b58cf0"))
		GridEv.SPAWNED:
			_float_text(_to_world(cell.x, cell.y) + Vector3(0, 1.8, 0), "BUILT BY THE HIVE", Color("c9a2ff"))
			var drone: GridUnit = _state.unit(target)
			if drone != null and not _views.has(target):
				_views[target] = _build_view(drone)
				var root: Node3D = (_views[target] as Dictionary)["root"]
				root.position = _to_world(cell.x, cell.y)
				root.scale = Vector3.ONE * 0.1
				var grow := create_tween()
				grow.tween_property(root, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
				await _wait(0.2)
		GridEv.SPAWN_BLOCKED:
			var shut: bool = int(e[GridEv.F_V1]) == 1
			_float_text(_to_world(cell.x, cell.y) + Vector3(0, 1.0, 0), "PAD SHUT DOWN" if shut else "BUILD BLOCKED", UIKit.GREEN)
		GridEv.SHIELDED:
			_refresh_tag(target)
		GridEv.FIGHT_END:
			pass


func _unit_pos(ref: int) -> Vector3:
	return ((_views[ref] as Dictionary)["root"] as Node3D).position if _views.has(ref) else Vector3.ZERO


func _walk(ref: int, path: Array[Vector2i]) -> void:
	if not _views.has(ref):
		return
	var view: Dictionary = _views[ref]
	var root: Node3D = view["root"]
	var rig: ConstructRig = view["rig"]
	rig.set_moving(true)
	var tween := create_tween()
	var from: Vector3 = root.position
	for cell: Vector2i in path:
		var destination: Vector3 = _to_world(cell.x, cell.y) + Vector3(0, _tile_top(cell.x, cell.y), 0)
		var heading: Vector3 = destination - from
		if heading.length_squared() > 0.0004:
			var yaw: float = atan2(heading.x, heading.z)
			tween.tween_property(root, "rotation:y", root.rotation.y + wrapf(yaw - root.rotation.y, -PI, PI), 0.04)
		tween.tween_property(root, "position", destination, T_STEP)
		from = destination
	await tween.finished


func _attack(ref: int, aim: Vector2i, w: int, end: Vector2i) -> void:
	if not _views.has(ref):
		return
	var view: Dictionary = _views[ref]
	var root: Node3D = view["root"]
	var u: GridUnit = _state.unit(ref)
	var weapon: Dictionary = u.weapons[w]
	_face(root, _to_world(aim.x, aim.y))
	await _wait(0.05)
	(view["rig"] as ConstructRig).strike("arm_l" if w == GridUnit.ARM_L else "arm_r", String(weapon["class"]), get_tree())
	var colour: Color = DAMAGE_COLOURS[clampi(u.damage_type, 0, DAMAGE_COLOURS.size() - 1)]
	var muzzle: Vector3 = root.position + Vector3(0, 0.7, 0)
	match String(weapon["shape"]):
		"shot":
			var hit_point: Vector3 = _to_world(end.x, end.y) + Vector3(0, 0.6, 0)
			_vfx.muzzle_flash(muzzle, hit_point, colour.lightened(0.5))
			_tracer(muzzle, hit_point, colour)
			Audio.play("detonate", -12.0)
		"lob":
			var landing: Vector3 = _to_world(aim.x, aim.y) + Vector3(0, 0.4, 0)
			_vfx.muzzle_flash(muzzle, landing, colour.lightened(0.5))
			await _lob(muzzle, landing, colour)
			_vfx.burst(landing, colour, 1.2)
			Audio.play("hit_heavy", -8.0)
	await _wait(T_ATTACK)


## A shell arcing to its tile, so a mortar reads as going OVER things.
func _lob(from: Vector3, to: Vector3, colour: Color) -> void:
	var shell := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	shell.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	shell.material_override = material
	_marks_root.add_child(shell)
	var arc_height: float = 1.2 + from.distance_to(to) * 0.25
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		shell.position = from.lerp(to, t) + Vector3(0, sin(t * PI) * arc_height, 0), 0.0, 1.0, 0.42)
	await tween.finished
	shell.queue_free()


func _hit(attacker: int, victim: int, amount: int) -> void:
	if not _views.has(victim):
		return
	var view: Dictionary = _views[victim]
	var root: Node3D = view["root"]
	var u: GridUnit = _state.unit(victim)
	var severity: float = clampf(float(amount) / maxf(1.0, float(u.max_hp) * 0.35), 0.15, 1.0)
	_vfx.impact(root.position + Vector3(0, 0.6, 0), Color("ffb070"), severity)
	if attacker >= 0 and _views.has(attacker):
		(view["rig"] as ConstructRig).stagger(_local_push(attacker, victim), severity)
	# Terrain damage is labelled as terrain, so slag reads as a cause and not as a bug.
	_float_text(root.position + Vector3(0, 1.8, 0), ("-%d" % amount) if attacker >= 0 else ("SLAG -%d" % amount),
		UIKit.RED.lightened(0.25))
	_refresh_tag_from_event(view, victim)
	Audio.play("hit_heavy" if severity > 0.6 else "hit_light", -6.0)
	if severity > 0.8:
		_vfx.shake(0.35 * severity)
	await _wait(T_HIT)


## HP as of THIS event, not as of the end of the turn: the tag must count down hit by
## hit while the queue plays, so it reads the event's own number.
func _refresh_tag_from_event(view: Dictionary, ref: int) -> void:
	var e: Array = _state.events[_shown - 1]
	var u: GridUnit = _state.unit(ref)
	var hp_now: int = int(e[GridEv.F_V2])
	(view["tag"] as Label3D).text = "%d/%d" % [hp_now, u.max_hp]


func _shoved(actor: int, target: int, cell: Vector2i) -> void:
	if not _views.has(target):
		return
	var root: Node3D = (_views[target] as Dictionary)["root"]
	var destination: Vector3 = _to_world(cell.x, cell.y) + Vector3(0, _tile_top(cell.x, cell.y), 0)
	var tween := create_tween()
	tween.tween_property(root, "position", destination, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	((_views[target] as Dictionary)["rig"] as ConstructRig).stagger(_local_push(actor, target), 0.8)
	Audio.play("hit_light", -8.0)
	await tween.finished


func _torn(ref: int, w: int) -> void:
	if not _views.has(ref):
		return
	var view: Dictionary = _views[ref]
	_hide_arm(view, w)
	var at: Vector3 = (view["root"] as Node3D).position + Vector3(0, 0.8, 0)
	_vfx.destruction(at, Color("ffb070"))
	_float_text(at + Vector3(0, 1.3, 0), "ARM TORN OFF", UIKit.GOLD)
	Audio.play("destroy", -8.0)
	await _wait(0.4)


func _destroyed(killer: int, victim: int) -> void:
	if not _views.has(victim):
		return
	var view: Dictionary = _views[victim]
	_vfx.destruction((view["root"] as Node3D).position + Vector3(0, 0.5, 0), Color("ff9a5a"))
	_vfx.shake(0.3)
	_burst(view, _local_push(killer, victim) if killer >= 0 and _views.has(killer) else Vector3(0, 0, 1))
	_views.erase(victim)
	Audio.play("destroy", -4.0)
	await _wait(T_DESTROY)


## Which way a hit pushes a construct, in the construct's own space. See the note on
## `_stagger` in the legacy battle scene: a world direction makes every unit lurch north.
func _local_push(from_ref: int, to_ref: int) -> Vector3:
	if not _views.has(to_ref):
		return Vector3(0, 0, 1)
	var target: Node3D = (_views[to_ref] as Dictionary)["root"]
	var source: Node3D = (_views[from_ref] as Dictionary)["root"] if _views.has(from_ref) else null
	if source == null:
		return Vector3(0, 0, 1)
	var world: Vector3 = target.position - source.position
	world.y = 0.0
	if world.length_squared() < 0.0001:
		return Vector3(0, 0, 1)
	return target.transform.basis.inverse() * world.normalized()


## Models face +Z, so the yaw that points one at a spot is atan2(dx, dz).
func _face(root: Node3D, toward: Vector3) -> void:
	var heading: Vector3 = toward - root.position
	if heading.length_squared() < 0.0004:
		return
	var yaw: float = atan2(heading.x, heading.z)
	# The short way round: tweening straight to `yaw` from an unwrapped angle can spin a
	# machine through 270 degrees to turn 90.
	var target: float = root.rotation.y + wrapf(yaw - root.rotation.y, -PI, PI)
	var tween := create_tween()
	tween.tween_property(root, "rotation:y", target, 0.12)


func _tracer(from: Vector3, to: Vector3, colour: Color) -> void:
	# A hot core inside a soft glow (010): one thin opaque bar read as a stick, not a shot.
	var glow := MeshInstance3D.new()
	var glow_box := BoxMesh.new()
	glow_box.size = Vector3(0.16, 0.16, from.distance_to(to))
	glow.mesh = glow_box
	var haze := StandardMaterial3D.new()
	haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	haze.albedo_color = Color(colour, 0.35)
	glow.material_override = haze
	_marks_root.add_child(glow)
	glow.look_at_from_position((from + to) * 0.5, to, Vector3.UP)
	var haze_fade := create_tween()
	haze_fade.tween_property(haze, "albedo_color:a", 0.0, 0.3)
	haze_fade.tween_callback(glow.queue_free)
	var beam := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.04, 0.04, from.distance_to(to))
	beam.mesh = box
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour.lerp(Color.WHITE, 0.5)
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = 2.5
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = material
	_marks_root.add_child(beam)
	beam.look_at_from_position((from + to) * 0.5, to, Vector3.UP)
	var tween := create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.25)
	tween.tween_callback(beam.queue_free)


func _float_text(at: Vector3, text: String, colour: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 56
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 14
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.modulate = colour
	label.position = at
	_marks_root.add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position", at + Vector3(0, 0.9, 0), 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


# --- After each batch of events: redraw everything the player reads -----------

func _after_events() -> void:
	for u: GridUnit in _state.units:
		_refresh_tag(u.ref)
	if _coach != null and _state.outcome != CombatState.ONGOING:
		# The shakedown ends in its coach, not on the practice fight's result screen.
		_selected = -1
		_refresh()
		_hud.set_banner("FIGHT OVER", UIKit.TEXT_DIM)
		if _state.outcome != CombatState.WON:
			_hud.show_result(false, "Try the shakedown again: FIGHT AGAIN.", false)
		return
	if _state.outcome != CombatState.ONGOING:
		_selected = -1
		_refresh()
		_hud.set_banner("FIGHT OVER", UIKit.TEXT_DIM)
		_hud.set_hint("")
		var status: Dictionary = CombatSim.objective_status(_state)
		var body: String = "Round %d  ·  %d of 3 machines standing  ·  %d scrap from piles" % [
			_state.round_number, _state.crew(GridUnit.TEAM_PLAYER).size(), _state.scrap_collected]
		if String(status["type"]) == "defend":
			body += "\n%d of %d caches saved" % [int(status["caches"]), int(status["caches_total"])]
		if _state.outcome != CombatState.WON and not _state.crew(GridUnit.TEAM_PLAYER).is_empty():
			body += "\nThe objective failed, but the crew made it out. No salvage from this one."
		_hud.show_result(_state.outcome == CombatState.WON, body, _run_mode)
		return
	if _selected < 0 or not _unit_has_moves(_selected):
		_selected = _next_ready_unit()
	_weapon = _default_weapon(_selected, _weapon)
	_hud.set_banner("ROUND %d  ·  YOUR TURN" % _state.round_number)
	_refresh()
	if _coach == null and not _bot:
		Hints.show_once(_hud, "fight", _db, Vector2(1535, 600), 360)
	if _bot:
		await _wait(0.6)
		await _bot_turn()


func _refresh() -> void:
	_clear_marks()
	var threats: Dictionary = CombatSim.threats(_state)
	for ref: Variant in threats:
		var threat: Dictionary = threats[ref]
		# Quiet by default (play-test 2: a web of crossing lines was overwhelming): the hexes
		# that will be hit and a numbered badge. The whole line is drawn for the enemy the
		# player tapped, for shots at the selected machine, or for all with LINES.
		var full: bool = _all_lines or int(ref) == _focus_enemy or _hits_selected(threat)
		if bool(threat["legal"]):
			if full:
				for cell: Vector2i in (threat["tiles"] as Array):
					_mark(_threat_quads, cell, COL_THREAT)
			else:
				for hit: Dictionary in (threat["hits"] as Array):
					var victim: GridUnit = _state.unit(int(hit["ref"]))
					_mark(_threat_quads, Vector2i(victim.x, victim.y), COL_THREAT)
				_mark(_threat_quads, threat["end"], COL_THREAT)
		_intent_marker(int(ref), threat, full)

	for ref: Variant in _state.spawn_marks:
		_mark(_threat_quads, _state.spawn_marks[ref], COL_THREAT if CombatSim.drone_in(_state, int(ref)) <= 1 else COL_SPAWN)
		_spawn_marker(int(ref), _state.spawn_marks[ref])

	var sel: GridUnit = _state.unit(_selected) if _selected >= 0 else null
	if sel != null and sel.alive:
		if _armed and _ability >= 0:
			if not _pending.is_empty():
				_mark(_hint_quads, _pending["cell"], COL_TARGET)
			else:
				for cell: Vector2i in CombatAbilities.targets(_state, sel, _ability):
					_mark(_hint_quads, cell, COL_ATTACK)
		elif _armed and not sel.acted and not sel.seized and sel.can_fire(_weapon):
			if not _pending.is_empty():
				var plan: Dictionary = CombatSim.strike_plan(_state, sel, _weapon, _pending["cell"])
				for cell: Vector2i in (plan["tiles"] as Array):
					_mark(_hint_quads, cell, COL_TARGET)
			else:
				# Free aim: every hex in reach is a target. Hexes holding a unit are drawn
				# stronger, because those are the ones worth considering.
				for aim: Vector2i in CombatSim.aim_options(_state, sel, _weapon):
					var occupied: bool = _state.unit_at(aim.x, aim.y) != null
					_mark(_hint_quads, aim, COL_TARGET if occupied else COL_ATTACK_FAINT)
		if not _armed:
			for cell: Variant in CombatSim.reachable(_state, _selected):
				_mark(_hint_quads, cell, COL_MOVE)
	_refresh_hud(threats)
	if _coach != null:
		_coach.refresh()


func _refresh_hud(threats: Dictionary) -> void:
	var cards: Array = []
	for u: GridUnit in _state.units:
		if u.team != GridUnit.TEAM_PLAYER or u.objective:
			continue
		cards.append({
			"ref": u.ref, "name": u.name, "detail": _unit_line(u), "arms": _arms_line(u),
			"hp": u.hp, "max_hp": u.max_hp, "alive": u.alive, "heat": u.heat, "heat_cap": u.heat_cap,
			"can_move": not CombatSim.reachable(_state, u.ref).is_empty(),
			"can_act": not u.acted and not u.seized and u.has_weapon(),
			"selected": u.ref == _selected,
			"parts": Array(u.part_ids), "level": u.level, "number": u.slot + 1,
		})
	_hud.set_crew(cards)
	var status: Dictionary = CombatSim.objective_status(_state)
	_hud.set_objective(String(status["text"]), String(status["type"]) == "defend" and int(status["caches"]) < int(status["caches_total"]))
	var ongoing: bool = _state.outcome == CombatState.ONGOING and not _bot
	_hud.set_controls(ongoing and not _busy and _actions.size() > _turn_start, ongoing and not _busy)

	var sel: GridUnit = _state.unit(_selected) if _selected >= 0 else null
	_refresh_weapon_bar(sel)
	if not _pending.is_empty():
		var cell: Vector2i = _pending["cell"]
		if bool(_pending["ability"]):
			var ability: Dictionary = sel.abilities[int(_pending["i"])]
			_hud.set_info(String(ability["name"]).to_upper(), _effects_text(CombatSim.dry_run(_state,
				[CombatSim.ACT_ABILITY, sel.ref, int(_pending["i"]), cell.x, cell.y]), {}) + "\n\nTap the same hex again to confirm.")
		else:
			_hud.set_info("FIRE %s" % String(sel.weapons[int(_pending["i"])]["name"]).to_upper(),
				_preview_text(CombatSim.preview_attack(_state, sel.ref, int(_pending["i"]), cell))
				+ "\n\nTap the same target again to confirm.")
		_hud.set_hint("Tap the yellow target again to fire  ·  tap elsewhere to cancel")
	elif sel != null and _armed and _ability >= 0:
		var ability: Dictionary = sel.abilities[_ability]
		_hud.set_info(String(ability["name"]).to_upper(), "%s\n\n%s  ·  cooldown %d round%s" % [String(ability["text"]),
			"Free: does not use the action" if bool(ability["free"]) else "Uses this machine's action",
			int(ability["cooldown"]), "" if int(ability["cooldown"]) == 1 else "s"])
		_hud.set_hint("Yellow: where %s can go  ·  tap one to aim  ·  tap %s again to go back to moving" % [
			String(ability["name"]), String(ability["name"]).to_upper()])
	elif sel != null:
		_hud.set_info(sel.name.to_upper(), "%s\n%s\n\n%s" % [_unit_line(sel), _arms_line(sel), _threat_summary(threats)])
		if sel.seized:
			_hud.set_hint("SEIZED this round: it can move but not attack.")
		elif _armed and _ability >= 0:
			_hud.set_hint("Yellow: where %s can go  ·  tap one to aim  ·  tap %s again to go back to moving" % [
				String(sel.abilities[_ability]["name"]), String(sel.abilities[_ability]["name"]).to_upper()])
		elif _armed:
			_hud.set_hint("Yellow: %s targets  ·  tap one to aim  ·  tap the weapon again to go back to moving" % String(sel.weapons[_weapon]["name"]))
		elif not sel.acted:
			_hud.set_hint("Blue: move  ·  Red: where enemies will fire  ·  pick a weapon below to attack")
		else:
			_hud.set_hint("This machine is done. Pick another, or END TURN.")
	else:
		_hud.set_info("ENEMY INTENTS", _threat_summary(threats))
		_hud.set_hint("Every machine has acted. END TURN to let the enemy fire.")


func _refresh_weapon_bar(sel: GridUnit) -> void:
	_bar_items = []
	if sel == null or not sel.alive or sel.objective:
		_hud.set_weapons([], -1, "")
		return
	var list: Array = []
	var selected: int = -1
	for w: int in sel.weapons.size():
		var weapon: Dictionary = sel.weapons[w]
		var reason: String = ""
		if bool(weapon.get("empty", false)):
			reason = "EMPTY SOCKET"
		elif bool(weapon["torn"]):
			reason = "ARM TORN OFF"
		elif sel.seized:
			reason = "SEIZED THIS ROUND"
		elif sel.acted:
			reason = "ALREADY ACTED"
		if _armed and _ability < 0 and w == _weapon:
			selected = list.size()
		list.append({"name": String(weapon["name"]), "detail": _weapon_detail(sel, w),
			"available": reason.is_empty(), "reason": reason, "part": String(weapon.get("id", ""))})
		_bar_items.append(["weapon", w])
	# Abilities after the arms: what the chassis and module can DO besides shoot.
	for i: int in sel.abilities.size():
		var ability: Dictionary = sel.abilities[i]
		var reason: String = ""
		if not sel.ability_ready(i):
			reason = "READY IN %d ROUND%s" % [int(ability["wait"]), "" if int(ability["wait"]) == 1 else "S"]
		elif not CombatAbilities.usable(_state, sel, i):
			reason = "NOT NOW"
		if _armed and _ability == i:
			selected = list.size()
		var cost: String = "FREE" if bool(ability["free"]) else "USES ACTION"
		list.append({"name": String(ability["name"]), "detail": "%s · COOLDOWN %d" % [cost, int(ability["cooldown"])],
			"available": reason.is_empty(), "reason": reason, "ability": true})
		_bar_items.append(["ability", i])
	var vent: String = ""
	if not sel.acted and sel.heat > 0:
		vent = "Drop heat to 0. Uses this machine's action."
	_hud.set_weapons(list, selected, vent)


func _preview_text(preview: Dictionary) -> String:
	var text: String = _effects_text(preview.get("effects", []), preview)
	if bool(preview.get("overheats", false)):
		text += "\nOVERHEATS: no attack next round"
	return text


## What a dry run changed, as lines a player reads: every machine hurt, destroyed, dropped
## into a pit, moved, and every prop that breaks. Built from the REAL rules run on a copy.
func _effects_text(effects: Array, preview: Dictionary) -> String:
	var lines: PackedStringArray = []
	for effect: Dictionary in effects:
		if effect.has("prop"):
			var cell: Vector2i = effect["prop"]
			var kind: String = String((_state.props.get(cell, {"kind": "prop"}) as Dictionary)["kind"])
			lines.append("A fuel drum EXPLODES" if kind == "barrel" else "A crate wall breaks")
			continue
		var t: GridUnit = _state.unit(int(effect["ref"]))
		if t == null:
			continue
		var who: String = t.name + (" (YOURS)" if t.team == GridUnit.TEAM_PLAYER else "")
		if bool(effect["fell"]):
			lines.append("%s FALLS INTO THE PIT" % who)
		elif bool(effect["killed"]):
			lines.append("%s -%d  DESTROYED" % [who, int(effect["hp_lost"])])
		elif int(effect["hp_lost"]) > 0:
			var tear: String = "  TEARS AN ARM OFF" if (preview.get("tears", []) as Array).has(t.ref) else ""
			lines.append("%s -%d → %d/%d%s" % [who, int(effect["hp_lost"]), t.hp - int(effect["hp_lost"]), t.max_hp, tear])
		elif effect["moved_to"] != null:
			lines.append("%s is moved" % who)
	if lines.is_empty():
		return "Nothing there is affected."
	return "\n".join(lines)


func _threat_summary(threats: Dictionary) -> String:
	if threats.is_empty():
		return "No enemy is aiming at anything this round."
	var lines: PackedStringArray = []
	var refs: Array = threats.keys()
	refs.sort_custom(func(a: int, b: int) -> bool: return int(threats[a]["order"]) < int(threats[b]["order"]))
	for ref: Variant in refs:
		var threat: Dictionary = threats[ref]
		var shooter: GridUnit = _state.unit(int(ref))
		var names: PackedStringArray = []
		for hit: Dictionary in (threat["hits"] as Array):
			names.append("%s -%d" % [_state.unit(int(hit["ref"])).name, int(hit["damage"])])
		var outcome: String = ", ".join(names) if not names.is_empty() else "nothing"
		if int(threat.get("lock", -1)) >= 0:
			outcome += "  (locked on: moving does not dodge it)"
		if not bool(threat["legal"]):
			outcome = "out of reach now: it will miss"
		lines.append("%d. %s (%s) → %s" % [int(threat["order"]), shooter.name,
			String(shooter.weapons[int(threat["w"])]["name"]), outcome])
	return "Enemy fire, in order:\n" + "\n".join(lines)


func _unit_line(u: GridUnit) -> String:
	return "%s  ·  move %d  ·  %s armour  ·  %s" % [u.role.capitalize(), u.move,
		String((_db.combat_rules.get("armor_types", []) as Array)[u.armor_type]),
		String((_db.combat_rules.get("damage_types", []) as Array)[u.damage_type])]


func _arms_line(u: GridUnit) -> String:
	var names: PackedStringArray = []
	for w: int in u.weapons.size():
		names.append(String(u.weapons[w]["name"]) + (" (torn)" if bool(u.weapons[w]["torn"]) else ""))
	return " / ".join(names)


func _weapon_detail(u: GridUnit, w: int) -> String:
	var weapon: Dictionary = u.weapons[w]
	var dmg: int = int(weapon["damage"])
	if dmg > 0:
		dmg += u.damage_bonus + (u.melee_bonus if String(weapon["shape"]) == "melee" else 0)
	var bits: PackedStringArray = []
	match String(weapon["shape"]):
		"melee":
			bits.append("melee")
		"shot":
			bits.append("shot %d" % CombatSim.weapon_reach(_state, u, w))
		"lob":
			bits.append("lob %d-%d" % [int(weapon["range_min"]), CombatSim.weapon_reach(_state, u, w)])
	bits.append("%d dmg" % dmg)
	for key: String in ["pierce", "splash", "shove", "chain"]:
		if int(weapon[key]) > 0:
			bits.append(key)
	if bool(weapon["mark"]):
		bits.append("marks")
	if bool(weapon["tears"]):
		bits.append("tears")
	# A cold weapon says nothing about heat ("+0 heat" is noise).
	if CombatSim.attack_heat(u, weapon) > 0:
		bits.append("+%d heat" % CombatSim.attack_heat(u, weapon))
	return " · ".join(bits)


func _mark(quads: Dictionary, cell: Vector2i, colour: Color) -> void:
	var quad: MeshInstance3D = quads.get(cell)
	if quad == null:
		return
	quad.visible = true
	(quad.material_override as StandardMaterial3D).albedo_color = colour


func _clear_marks() -> void:
	for quad: Variant in _hint_quads.values():
		(quad as MeshInstance3D).visible = false
	for quad: Variant in _threat_quads.values():
		(quad as MeshInstance3D).visible = false
	for child: Node in _marks_root.get_children():
		if child.has_meta("intent"):
			child.queue_free()


## An intent's badge (its firing order, on the hex it will hit) and, when `full`, a red bar
## from the shooter along its whole line. Grey and MISSES when the shooter can no longer
## reach (it was shoved); LOCKED for a tracker.
func _intent_marker(ref: int, threat: Dictionary, full: bool) -> void:
	var u: GridUnit = _state.unit(ref)
	var legal: bool = bool(threat["legal"])
	var from: Vector3 = _to_world(u.x, u.y) + Vector3(0, 0.35, 0)
	var end: Vector2i = threat["end"] if legal else threat["aim"]
	var to: Vector3 = _to_world(end.x, end.y) + Vector3(0, 0.35, 0)
	var colour: Color = Color("ff5a3c") if legal else Color(0.6, 0.6, 0.6, 0.7)
	var text: String = str(int(threat["order"]))
	if not legal:
		text += " MISSES"
	elif int(threat.get("lock", -1)) >= 0:
		text += " LOCKED"
	_marker_label(text, to + Vector3(0, 0.5, 0), Color("ff7a5c") if legal else colour, 56 if legal else 40)
	# The shooter wears its number too, so a badge on the ground can be traced back.
	_marker_label(str(int(threat["order"])), from + Vector3(0, 2.0, 0), Color("ff7a5c"), 40)
	if not full or from.distance_to(to) < 0.01:
		return
	var bar := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.07, 0.03, from.distance_to(to))
	bar.mesh = box
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bar.material_override = material
	bar.set_meta("intent", true)
	_marks_root.add_child(bar)
	bar.look_at_from_position((from + to) * 0.5, to, Vector3.UP)


func _marker_label(text: String, at: Vector3, colour: Color, size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 14
	label.outline_modulate = Color(0, 0, 0, 0.95)
	label.modulate = colour
	label.position = at
	label.set_meta("intent", true)
	_marks_root.add_child(label)


## A hive's fabricator pad (play-test 4). It stays where the hive set it down, so it is a
## PLACE on the board, not a label: a dark plate with a lit ring, the rounds until its next
## drone in big numerals, and a beam back to the hive that runs it. The turn before it
## builds, the ring turns red and pulses, a ghost of the drone flickers on it, and the label
## says so -- one full turn of warning to block it or kill the hive.
func _spawn_marker(hive_ref: int, cell: Vector2i) -> void:
	var hive: GridUnit = _state.unit(hive_ref)
	var at: Vector3 = _to_world(cell.x, cell.y) + Vector3(0, _tile_top(cell.x, cell.y), 0)
	var due: int = CombatSim.drone_in(_state, hive_ref)
	var urgent: bool = due <= 1
	var colour: Color = COL_PAD_DANGER if urgent else COL_PAD

	var plate := MeshInstance3D.new()
	plate.mesh = _hex_mesh(HEX * 0.74, 0.05)
	plate.position = at + Vector3(0, 0.035, 0)
	var plate_material := StandardMaterial3D.new()
	plate_material.albedo_color = Color("1b1720")
	plate_material.metallic = 0.6
	plate_material.roughness = 0.5
	plate_material.emission_enabled = true
	plate_material.emission = colour
	plate_material.emission_energy_multiplier = 0.25
	plate.material_override = plate_material
	plate.set_meta("intent", true)
	_marks_root.add_child(plate)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = HEX * 0.62
	torus.outer_radius = HEX * 0.74
	torus.ring_segments = 6
	torus.rings = 6
	ring.mesh = torus
	ring.scale = Vector3(1, 0.3, 1)
	ring.position = at + Vector3(0, 0.07, 0)
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = colour
	ring.material_override = ring_material
	ring.set_meta("intent", true)
	_marks_root.add_child(ring)
	if urgent:
		# Pulses for as long as the warning stands; freed with the marker on the next refresh.
		var pulse := ring.create_tween().set_loops()
		pulse.tween_property(ring, "scale", Vector3(1.12, 0.3, 1.12), 0.45).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(ring, "scale", Vector3(1, 0.3, 1), 0.45).set_trans(Tween.TRANS_SINE)
		var ghost := MeshInstance3D.new()
		var body := BoxMesh.new()
		body.size = Vector3(HEX * 0.55, HEX * 0.9, HEX * 0.55)
		ghost.mesh = body
		ghost.position = at + Vector3(0, HEX * 0.5, 0)
		var ghost_material := StandardMaterial3D.new()
		ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ghost_material.albedo_color = Color(colour, 0.22)
		ghost.material_override = ghost_material
		ghost.set_meta("intent", true)
		_marks_root.add_child(ghost)
		var flicker := ghost.create_tween().set_loops()
		flicker.tween_property(ghost_material, "albedo_color:a", 0.06, 0.3)
		flicker.tween_property(ghost_material, "albedo_color:a", 0.26, 0.3)

	if due >= 0:
		var numeral := Label3D.new()
		numeral.text = str(maxi(1, due))
		numeral.font = UIKit.font_display()
		numeral.font_size = 150
		numeral.pixel_size = 0.005
		numeral.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		numeral.no_depth_test = true
		numeral.outline_size = 18
		numeral.outline_modulate = Color(0, 0, 0, 0.9)
		numeral.modulate = colour.lightened(0.3)
		numeral.position = at + Vector3(0, 0.75, 0)
		numeral.set_meta("intent", true)
		_marks_root.add_child(numeral)
	# Under the pad, not over it: the hive that set it down is usually right next door, and
	# its own tag sits at head height.
	_marker_label("DRONE NEXT TURN · stand here to block" if urgent else "HIVE PAD · drone in %d" % due,
		at + Vector3(0, 0.08, HEX * 0.72), colour.lightened(0.35), 24)
	if hive == null or not hive.alive:
		return
	var from: Vector3 = _to_world(hive.x, hive.y) + Vector3(0, 0.25, 0)
	var to: Vector3 = at + Vector3(0, 0.25, 0)
	var beam := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.05, from.distance_to(to))
	beam.mesh = box
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(colour, 0.7)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.material_override = material
	beam.set_meta("intent", true)
	_marks_root.add_child(beam)
	beam.look_at_from_position((from + to) * 0.5, to, Vector3.UP)


func _hits_selected(threat: Dictionary) -> bool:
	for hit: Dictionary in (threat["hits"] as Array):
		if int(hit["ref"]) == _selected:
			return true
	return false


func _toggle_lines() -> void:
	_all_lines = not _all_lines
	_refresh()


# --- Input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_zoom - 0.8)
		elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_zoom + 0.8)
		elif mouse.button_index == MOUSE_BUTTON_LEFT:
			var cell: Variant = _pick(mouse.position)
			if cell != null:
				_tap(cell)
	elif event is InputEventMagnifyGesture:
		_set_zoom(_zoom / (event as InputEventMagnifyGesture).factor)
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_1, KEY_2, KEY_3:
				_select(_crew_ref((event as InputEventKey).keycode - KEY_1))
			KEY_TAB:
				_cycle_weapon()
			KEY_V:
				_vent()
			KEY_Z:
				_undo()
			KEY_SPACE, KEY_ENTER:
				_end_turn()
			KEY_L:
				_toggle_lines()
			KEY_Q:
				_rotate(-1)
			KEY_E:
				_rotate(1)


func _set_zoom(value: float) -> void:
	_zoom = clampf(value, ZOOM_MIN, ZOOM_MAX)
	_place_camera()


## The hex under a screen point, or null. Intersects the board plane rather than physics
## bodies: nothing on the board needs a collider, and a phone does not pay for one. The
## point is converted to fractional axial coordinates and cube-rounded, the standard
## pixel-to-hex, so a tap near a hex's corner lands on the right one.
func _pick(screen: Vector2) -> Variant:
	var origin: Vector3 = _camera.project_ray_origin(screen)
	var normal: Vector3 = _camera.project_ray_normal(screen)
	if absf(normal.y) < 0.0001:
		return null
	var t_hit: float = (0.05 - origin.y) / normal.y
	if t_hit < 0.0:
		return null
	var hit: Vector3 = origin + normal * t_hit
	var px: float = hit.x + _origin.x
	var pz: float = hit.z + _origin.y
	var q: float = (SQRT3 / 3.0 * px - pz / 3.0) / HEX
	var r: float = (2.0 / 3.0 * pz) / HEX
	var s: float = -q - r
	var rq: float = roundf(q)
	var rr: float = roundf(r)
	var rs: float = roundf(s)
	var dq: float = absf(rq - q)
	var dr: float = absf(rr - r)
	var ds: float = absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	var cell: Vector2i = Hex.from_cube(Vector3i(int(rq), int(-rq - rr), int(rr)))
	if cell.x < 0 or cell.y < 0 or cell.x >= _setup.width or cell.y >= _setup.height:
		return null
	return cell


func _tap(cell: Vector2i) -> void:
	if _busy or _bot or _state.outcome != CombatState.ONGOING:
		return
	var there: GridUnit = _state.unit_at(cell.x, cell.y)

	# One meaning per tap, in a fixed priority. The first version let an attack line win,
	# so a melee construct could not step onto an empty tile beside it (that tile was also
	# its attack line), and tapping an ally standing in someone's line of fire aimed at the
	# ally instead of selecting it.
	#   1. a friendly construct: select it
	#   2. unarmed: a tile the selected construct can move to -> move
	#   3. armed: a target of the armed weapon -> aim; the same target again -> fire
	if there != null and there.alive and there.team == GridUnit.TEAM_PLAYER and not there.objective:
		_select(there.ref)
		return

	var sel: GridUnit = _state.unit(_selected) if _selected >= 0 else null
	if sel != null and sel.alive and not _armed:
		if CombatSim.reachable(_state, sel.ref).has(cell):
			_pending = {}
			_act([CombatSim.ACT_MOVE, sel.ref, cell.x, cell.y])
			return
	if sel != null and sel.alive and _armed and _ability >= 0:
		if CombatAbilities.targets(_state, sel, _ability).has(cell):
			if not _pending.is_empty() and _pending["cell"] == cell:
				var i: int = _ability
				_pending = {}
				_armed = false
				_ability = -1
				_act([CombatSim.ACT_ABILITY, sel.ref, i, cell.x, cell.y])
			else:
				_pending = {"ref": sel.ref, "ability": true, "i": _ability, "cell": cell}
				Audio.play("ui_confirm", -14.0)
				_refresh()
			return
	elif sel != null and sel.alive and _armed:
		var aim: Array = _aim_for(sel, cell)
		if not aim.is_empty():
			var at := Vector2i(int(aim[0]), int(aim[1]))
			if not _pending.is_empty() and _pending["cell"] == at:
				_pending = {}
				_armed = false
				_act([CombatSim.ACT_ATTACK, sel.ref, _weapon, at.x, at.y])
			else:
				_pending = {"ref": sel.ref, "ability": false, "i": _weapon, "cell": at}
				Audio.play("ui_confirm", -14.0)
				_refresh()
			return

	_pending = {}
	_refresh()
	_focus_enemy = there.ref if there != null and there.team == GridUnit.TEAM_ENEMY else -1
	_refresh()
	if there != null:
		var about: String = "Protect it: every cache still standing pays out scrap." if there.objective \
			else _unit_line(there) + "\n" + _arms_line(there)
		if not there.kind.is_empty():
			var kind: Dictionary = _db.enemy_kinds.get(there.kind, {})
			about += "\n\n%s: %s" % [String(kind.get("name", there.kind)).to_upper(), String(kind.get("text", ""))]
		_hud.set_info(there.name.to_upper(), "%d / %d HP\n%s" % [there.hp, there.max_hp, about])
	else:
		_terrain_info(cell)


## The hex to aim the armed weapon at if `cell` is tapped, or empty: any hex in reach.
func _aim_for(u: GridUnit, cell: Vector2i) -> Array:
	if u.acted or u.seized or not u.can_fire(_weapon):
		return []
	if CombatSim.aim_options(_state, u, _weapon).has(cell):
		return [cell.x, cell.y]
	return []


func _select(ref: int) -> void:
	if _busy or ref < 0:
		return
	var u: GridUnit = _state.unit(ref)
	if u == null or not u.alive or u.team != GridUnit.TEAM_PLAYER or u.objective:
		return
	if _selected != ref:
		_weapon = _default_weapon(ref, -1)
	_selected = ref
	_armed = false
	_ability = -1
	_pending = {}
	Audio.play("ui_confirm", -16.0)
	_refresh()


func _choose_weapon(w: int) -> void:
	var u: GridUnit = _state.unit(_selected) if _selected >= 0 else null
	if _busy or u == null or not u.can_fire(w):
		return
	# Tapping the armed weapon again puts the construct back into moving.
	_armed = not (_armed and _ability < 0 and _weapon == w)
	_ability = -1
	_weapon = w
	_pending = {}
	Audio.play("ui_confirm", -16.0)
	_refresh()


func _bar_press(index: int) -> void:
	if index < 0 or index >= _bar_items.size():
		return
	var item: Array = _bar_items[index]
	if String(item[0]) == "weapon":
		_choose_weapon(int(item[1]))
	else:
		_choose_ability(int(item[1]))


## An untargeted ability happens on the tap (UNDO takes it back); a targeted one is armed
## like a weapon: its hexes light up, tap one to aim, tap it again to use.
func _choose_ability(i: int) -> void:
	var u: GridUnit = _state.unit(_selected) if _selected >= 0 else null
	if _busy or u == null or not CombatAbilities.usable(_state, u, i):
		Audio.play("ui_deny", -10.0)
		return
	_pending = {}
	if not CombatAbilities.needs_target(u.abilities[i]):
		_armed = false
		_ability = -1
		_act([CombatSim.ACT_ABILITY, u.ref, i, 0, 0])
		return
	_armed = not (_armed and _ability == i)
	_ability = i if _armed else -1
	Audio.play("ui_confirm", -16.0)
	_refresh()


## Tapping an empty hex explains what is on it: terms the player has not been told yet are
## the first thing play-test 1 complained about.
func _terrain_info(cell: Vector2i) -> void:
	if _state.props.has(cell):
		var prop: Dictionary = _state.props[cell]
		var def: Dictionary = _tile_def_by_id(String(prop["kind"]))
		_hud.set_info(String(def.get("name", "")).to_upper(), "%s\n%d HP left." % [String(def.get("text", "")), int(prop["hp"])])
		return
	if _state.piles.has(cell):
		_hud.set_info("SCRAP PILE", "Worth %d scrap. End a move here to collect it and patch 2 HP. Enemies grab them too." % int(_state.piles[cell]))
		return
	for ref: Variant in _state.spawn_marks:
		if _state.spawn_marks[ref] == cell:
			_hud.set_info("DRONE BUILD SITE", "A hive will build a drone here next round. Stand on it to stop the build.")
			return
	var def: Dictionary = _db.tiles[_state.tile_at(cell.x, cell.y)]
	if String(def.get("id", "")) != "open":
		_hud.set_info(String(def.get("name", "")).to_upper(), String(def.get("text", "")))


func _tile_def_by_id(id: String) -> Dictionary:
	for def: Variant in _db.tiles:
		if String((def as Dictionary).get("id", "")) == id:
			return def
	return {}


func _cycle_weapon() -> void:
	var u: GridUnit = _state.unit(_selected) if _selected >= 0 else null
	if u == null:
		return
	for step: int in range(0 if not _armed else 1, u.weapons.size() + 1):
		var w: int = (_weapon + step) % u.weapons.size()
		if u.can_fire(w):
			_armed = false
			_choose_weapon(w)
			return


## Keeps the current weapon if it can still fire, otherwise the first arm that can.
func _default_weapon(ref: int, current: int) -> int:
	var u: GridUnit = _state.unit(ref) if ref >= 0 else null
	if u == null:
		return 0
	if current >= 0 and u.can_fire(current):
		return current
	for w: int in u.weapons.size():
		if u.can_fire(w):
			return w
	return 0


func _crew_ref(index: int) -> int:
	var crew: Array = []
	for u: GridUnit in _state.units:
		if u.team == GridUnit.TEAM_PLAYER and not u.objective:
			crew.append(u.ref)
	return crew[index] if index < crew.size() else -1


func _vent() -> void:
	if _busy or _selected < 0:
		return
	_pending = {}
	_act([CombatSim.ACT_VENT, _selected, 0, 0])


func _act(action: Array) -> void:
	if not CombatSim.apply(_state, action):
		Audio.play("ui_deny", -10.0)
		return
	_actions.append(action)
	_record()
	_refresh_hud(CombatSim.threats(_state))
	await _play_new_events()
	_after_events()


## Replays the fight without the last action and rebuilds every model from the result.
## Rebuilding rather than patching is what keeps a torn-off arm, a fall and a shove from
## each needing their own "un-" animation.
func _undo() -> void:
	if _busy or _bot or _actions.size() <= _turn_start:
		return
	_actions.pop_back()
	_record()
	_state = CombatSim.replay(_setup, _actions)
	_shown = _state.events.size()
	_pending = {}
	_armed = false
	_ability = -1
	_spawn_units()
	_weapon = _default_weapon(_selected, _weapon)
	Audio.play("ui_deny", -14.0)
	_refresh()


func _end_turn() -> void:
	if _busy or _state.outcome != CombatState.ONGOING:
		return
	_pending = {}
	_armed = false
	_ability = -1
	_selected = -1
	await _act([CombatSim.ACT_END, -1, 0, 0])
	_turn_start = _actions.size()


func _unit_has_moves(ref: int) -> bool:
	var u: GridUnit = _state.unit(ref)
	return u != null and u.alive and not u.objective and (not u.acted or not CombatSim.reachable(_state, ref).is_empty())


func _next_ready_unit() -> int:
	for u: GridUnit in _state.units:
		if u.team == GridUnit.TEAM_PLAYER and u.alive and not u.objective and not u.acted:
			return u.ref
	return -1


## `--bot`: plays each unit's actions through the same `_act` path a tap reaches.
func _bot_turn() -> void:
	for u: GridUnit in _state.crew(GridUnit.TEAM_PLAYER):
		if _state.outcome != CombatState.ONGOING:
			return
		_selected = u.ref
		_refresh()
		for action: Array in CombatBot.plan_unit(_state, u.ref, false):
			await _wait(0.35)
			if _state.outcome != CombatState.ONGOING:
				return
			if int(action[0]) == CombatSim.ACT_ATTACK:
				_weapon = int(action[2])
				_armed = true
				_refresh()
				await _wait(0.35)
				_armed = false
			if not CombatSim.apply(_state, action):
				continue
			_actions.append(action)
			_record()
			await _play_new_events()
	if _state.outcome == CombatState.ONGOING:
		await _wait(0.4)
		_selected = -1
		if CombatSim.apply(_state, [CombatSim.ACT_END, -1, 0, 0]):
			_actions.append([CombatSim.ACT_END, -1, 0, 0])
			_record()
		_turn_start = _actions.size()
		await _play_new_events()
	_after_events()
