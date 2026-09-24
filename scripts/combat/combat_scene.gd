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

const TILE: float = 1.3
const COL_PLAYER := Color("4fa8d8")
const COL_ENEMY := Color("d8654f")
const COL_MOVE := Color(0.38, 0.70, 0.87, 0.42)
const COL_ATTACK := Color(0.90, 0.70, 0.24, 0.55)
const COL_TARGET := Color(0.95, 0.78, 0.30, 0.85)
const COL_THREAT := Color(0.86, 0.30, 0.20, 0.50)
const COL_CRAWLER := Color("e5b33d")
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

## How long each kind of event holds the queue, in seconds.
const T_STEP: float = 0.13
const T_ATTACK: float = 0.24
const T_HIT: float = 0.30
const T_DESTROY: float = 0.55
const T_BANNER: float = 0.45

var _db: ContentDB
var _fight_id: String = "proto_yard"
var _seed: int = 2026
var _bot: bool = false

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
## An attack waiting for its confirming second tap: `[ref, w, dir, dist]`, or empty.
var _pending: Array = []

var _board: Node3D
var _units_root: Node3D
var _marks_root: Node3D
var _hint_quads: Dictionary = {}
var _threat_quads: Dictionary = {}
var _views: Dictionary = {}
var _pivot: Node3D
var _camera: Camera3D
var _zoom: float = 12.5
var _yaw_step: int = 0
var _vfx: BattleVFX
var _hud: CombatHUD


func _ready() -> void:
	_read_args()
	_db = ContentDB.load_all()
	_build_world()
	_hud = CombatHUD.new()
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(_hud)
	_hud.unit_card_pressed.connect(_select)
	_hud.weapon_pressed.connect(_choose_weapon)
	_hud.vent_pressed.connect(_vent)
	_hud.undo_pressed.connect(_undo)
	_hud.end_turn_pressed.connect(_end_turn)
	_hud.rotate_pressed.connect(_rotate)
	_hud.retry_pressed.connect(_start_fight)
	_hud.title_pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))
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
	_setup = CombatSetup.build(_db.fights.get(_fight_id, {}), _db.combat_rules, _db.parts, _db.tiles,
		_db.balance.effectiveness, _seed)
	for error: String in _setup.errors:
		push_error("fight %s: %s" % [_fight_id, error])
	_actions = []
	_turn_start = 0
	_selected = -1
	_pending = []
	_state = CombatSim.start(_setup)
	_build_board()
	_spawn_units()
	_shown = 0
	_frame_camera()
	await _play_new_events()
	_after_events()


# --- World ------------------------------------------------------------------

func _build_world() -> void:
	# The same rig as the old battle scene: a warm sodium key and a cold fill from the
	# opposite side. See CLAUDE.md, "The visual system".
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
	# Fit the board's diagonal into the view, then leave the rest to the zoom control.
	var span: float = maxf(_setup.width, _setup.height) * TILE
	_zoom = clampf(span * 1.62, ZOOM_MIN, ZOOM_MAX)
	_place_camera()


func _rotate(step: int) -> void:
	_yaw_step = (_yaw_step + step + 4) % 4
	var tween := create_tween()
	tween.tween_property(_pivot, "rotation:y", _pivot.rotation.y + step * PI * 0.5, 0.28) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _to_world(x: int, y: int) -> Vector3:
	return Vector3((x - (_setup.width - 1) * 0.5) * TILE, 0.0, (y - (_setup.height - 1) * 0.5) * TILE)


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

	for y: int in _setup.height:
		for x: int in _setup.width:
			var def: Dictionary = _db.tiles[_setup.tiles[y * _setup.width + x]]
			var blocks: bool = bool(def.get("blocks", false))
			var top: float = _tile_top(x, y)
			var slab := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(TILE * 0.97, 0.3 + top, TILE * 0.97)
			slab.mesh = box
			slab.position = _to_world(x, y) + Vector3(0, -0.15 + top * 0.5, 0)
			# A faint checker, so a player can count tiles without a grid line on every edge.
			# The ground sits UNDER the machines in value (CLAUDE.md): lit by a 1.15 key, a
			# lightened tile was the brightest, largest surface on screen.
			var base: Color = Color(String(def.get("colour", "1a1e26")))
			if (x + y) % 2 == 1:
				base = base.lightened(0.04)
			slab.material_override = _material(base, 0.95)
			_board.add_child(slab)
			if blocks:
				_board.add_child(_scrap_heap(x, y))

			_hint_quads[Vector2i(x, y)] = _quad(x, y, top + 0.012, TILE * 0.84)
			_threat_quads[Vector2i(x, y)] = _quad(x, y, top + 0.008, TILE * 0.95)

	# A dark apron around the board, so its edge reads as an edge.
	var apron := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(_setup.width * TILE + 30.0, _setup.height * TILE + 30.0)
	apron.mesh = plane
	apron.position = Vector3(0, -0.31, 0)
	apron.material_override = _material(Color("0f0e0c"), 1.0)
	_board.add_child(apron)


## A blocking tile: a heap of rusted slabs, dressed from a hash of its cell so a map
## looks the same every time it is loaded.
func _scrap_heap(x: int, y: int) -> Node3D:
	var heap := Node3D.new()
	heap.position = _to_world(x, y)
	var h: int = IntentAI.mix(x, y, 91, 7)
	for i: int in 3:
		var piece := MeshInstance3D.new()
		var box := BoxMesh.new()
		var s: float = 0.35 + float((h >> (i * 5)) & 7) * 0.05
		box.size = Vector3(TILE * s, 0.22 + float((h >> (i * 3)) & 3) * 0.12, TILE * (s * 0.8))
		piece.mesh = box
		piece.position = Vector3(float(((h >> (i * 7)) & 7) - 3) * 0.06, box.size.y * 0.5 + i * 0.16, float(((h >> (i * 4)) & 7) - 3) * 0.06)
		piece.rotation.y = float((h >> (i * 6)) & 15) * 0.2
		piece.material_override = _material(Color("4a3526").lerp(Color("2d2f33"), float(i) * 0.4), 0.7, 0.4)
		heap.add_child(piece)
	return heap


func _quad(x: int, y: int, height: float, size: float) -> MeshInstance3D:
	var quad := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	quad.mesh = plane
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

func _spawn_units() -> void:
	for child: Node in _units_root.get_children():
		child.queue_free()
	_views.clear()
	for u: GridUnit in _state.units:
		_views[u.ref] = _build_view(u)


func _build_view(u: GridUnit) -> Dictionary:
	var root := Node3D.new()
	root.position = _to_world(u.x, u.y) + Vector3(0, _tile_top(u.x, u.y), 0)
	# Player machines face the far edge, enemies the near one.
	root.rotation.y = PI if u.team == GridUnit.TEAM_PLAYER else 0.0
	_units_root.add_child(root)

	var colour: Color = COL_PLAYER if u.team == GridUnit.TEAM_PLAYER else COL_ENEMY
	var model: Node3D = _crawler_model() if u.objective else ConstructView.build_parts(u.part_ids, _db, colour)
	model.scale = Vector3.ONE * (1.0 if u.objective else MODEL_SCALE)
	root.add_child(model)
	var ring: MeshInstance3D = _team_ring(COL_CRAWLER if u.objective else colour)
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
	tag.modulate = (COL_CRAWLER if u.objective else colour).lightened(0.45)
	root.add_child(tag)

	var view: Dictionary = {"root": root, "model": model, "rig": rig, "ring": ring, "tag": tag, "dead": false}
	_set_tag(view, u)
	for w: int in u.weapons.size():
		if not u.can_fire(w):
			_hide_arm(view, w)
	if not u.alive:
		_show_wrecked(view, Vector3(0, 0, 1))
	return view


## The Crawler: a tracked salvage rig, built from primitives until it has a model of its
## own. Deliberately NOT a construct silhouette -- it has to read as the thing you are
## protecting, not as a fourth fighter.
func _crawler_model() -> Node3D:
	var root := Node3D.new()
	var body_mat: StandardMaterial3D = _material(Color("8c7a4a"), 0.7, 0.15)
	var dark: StandardMaterial3D = _material(Color("2a2926"), 0.8, 0.5)
	var metal: StandardMaterial3D = _material(Color("6b6259"), 0.5, 0.8)
	for side: float in [-0.42, 0.42]:
		var track := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.26, 0.28, 1.15)
		track.mesh = box
		track.position = Vector3(side, 0.14, 0)
		track.material_override = dark
		root.add_child(track)
	var hull := MeshInstance3D.new()
	var hull_box := BoxMesh.new()
	hull_box.size = Vector3(0.86, 0.34, 1.0)
	hull.mesh = hull_box
	hull.position = Vector3(0, 0.42, 0)
	hull.material_override = body_mat
	root.add_child(hull)
	var cab := MeshInstance3D.new()
	var cab_box := BoxMesh.new()
	cab_box.size = Vector3(0.5, 0.3, 0.34)
	cab.mesh = cab_box
	cab.position = Vector3(0, 0.74, 0.28)
	cab.material_override = metal
	root.add_child(cab)
	var cargo := MeshInstance3D.new()
	var cargo_box := BoxMesh.new()
	cargo_box.size = Vector3(0.7, 0.36, 0.5)
	cargo.mesh = cargo_box
	cargo.position = Vector3(0, 0.77, -0.2)
	cargo.material_override = _material(Color("4a3526"), 0.8, 0.3)
	root.add_child(cargo)
	var boom := MeshInstance3D.new()
	var boom_box := BoxMesh.new()
	boom_box.size = Vector3(0.08, 0.08, 0.9)
	boom.mesh = boom_box
	boom.position = Vector3(0.22, 1.12, -0.05)
	boom.rotation.x = -0.5
	boom.material_override = metal
	root.add_child(boom)
	return root


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


func _show_wrecked(view: Dictionary, push: Vector3) -> void:
	if bool(view["dead"]):
		return
	view["dead"] = true
	(view["rig"] as ConstructRig).collapse(push)
	(view["tag"] as Label3D).visible = false
	# The ring stays, greyed: a wreck BLOCKS its tile, and a fallen machine seen from the
	# battle camera is a few dark pieces on a dark floor. The team colour goes, because
	# the ring means "whose it is" and a wreck is nobody's.
	var ring: MeshInstance3D = view["ring"]
	var material: StandardMaterial3D = (ring.material_override as StandardMaterial3D).duplicate()
	material.albedo_color = Color(0.55, 0.52, 0.47, 0.55)
	material.emission = Color(0.30, 0.28, 0.25)
	material.emission_energy_multiplier = 0.4
	ring.material_override = material


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
		GridEv.STEP:
			await _step(actor, cell)
		GridEv.MOVED:
			((_views[actor] as Dictionary)["rig"] as ConstructRig).set_moving(false)
		GridEv.INTENT_SET:
			await _wait(0.08)
		GridEv.ATTACK:
			await _attack(actor, cell, int(e[GridEv.F_V1]), int(e[GridEv.F_V2]))
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
		GridEv.FIGHT_END:
			pass


func _unit_pos(ref: int) -> Vector3:
	return ((_views[ref] as Dictionary)["root"] as Node3D).position if _views.has(ref) else Vector3.ZERO


func _step(ref: int, cell: Vector2i) -> void:
	var view: Dictionary = _views[ref]
	var root: Node3D = view["root"]
	var rig: ConstructRig = view["rig"]
	rig.set_moving(true)
	var destination: Vector3 = _to_world(cell.x, cell.y) + Vector3(0, _tile_top(cell.x, cell.y), 0)
	_face(root, destination)
	var tween := create_tween()
	tween.tween_property(root, "position", destination, T_STEP)
	await tween.finished


func _attack(ref: int, aim: Vector2i, w: int, dir: int) -> void:
	var view: Dictionary = _views[ref]
	var root: Node3D = view["root"]
	var u: GridUnit = _state.unit(ref)
	var weapon: Dictionary = u.weapons[w]
	var toward: Vector3 = root.position + Vector3(CombatState.DX[dir], 0, CombatState.DY[dir])
	_face(root, toward)
	await _wait(0.12)
	(view["rig"] as ConstructRig).strike("arm_l" if w == GridUnit.ARM_L else "arm_r", String(weapon["class"]), get_tree())
	var colour: Color = DAMAGE_COLOURS[clampi(u.damage_type, 0, DAMAGE_COLOURS.size() - 1)]
	var muzzle: Vector3 = root.position + Vector3(0, 0.7, 0)
	var hit_point: Vector3 = _to_world(aim.x, aim.y) + Vector3(0, 0.6, 0)
	match String(weapon["shape"]):
		"line":
			_vfx.muzzle_flash(muzzle, hit_point, colour.lightened(0.5))
			_tracer(muzzle, hit_point, colour)
			Audio.play("detonate", -12.0)
		"lob":
			_vfx.muzzle_flash(muzzle, hit_point, colour.lightened(0.5))
			await _lob(muzzle, hit_point, colour)
			_vfx.burst(hit_point, colour, 1.2)
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
	var view: Dictionary = _views[victim]
	var root: Node3D = view["root"]
	var u: GridUnit = _state.unit(victim)
	var severity: float = clampf(float(amount) / maxf(1.0, float(u.max_hp) * 0.35), 0.15, 1.0)
	_vfx.impact(root.position + Vector3(0, 0.6, 0), Color("ffb070"), severity)
	if attacker >= 0:
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
	var root: Node3D = (_views[target] as Dictionary)["root"]
	var destination: Vector3 = _to_world(cell.x, cell.y) + Vector3(0, _tile_top(cell.x, cell.y), 0)
	var tween := create_tween()
	tween.tween_property(root, "position", destination, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	((_views[target] as Dictionary)["rig"] as ConstructRig).stagger(_local_push(actor, target), 0.8)
	Audio.play("hit_light", -8.0)
	await tween.finished


func _torn(ref: int, w: int) -> void:
	var view: Dictionary = _views[ref]
	_hide_arm(view, w)
	var at: Vector3 = (view["root"] as Node3D).position + Vector3(0, 0.8, 0)
	_vfx.destruction(at, Color("ffb070"))
	_float_text(at + Vector3(0, 1.3, 0), "ARM TORN OFF", UIKit.GOLD)
	Audio.play("destroy", -8.0)
	await _wait(0.4)


func _destroyed(killer: int, victim: int) -> void:
	var view: Dictionary = _views[victim]
	_vfx.destruction((view["root"] as Node3D).position + Vector3(0, 0.5, 0), Color("ff9a5a"))
	_show_wrecked(view, _local_push(killer, victim) if killer >= 0 else Vector3(0, 0, 1))
	Audio.play("destroy", -4.0)
	await _wait(T_DESTROY)


## Which way a hit pushes a construct, in the construct's own space. See the note on
## `_stagger` in the legacy battle scene: a world direction makes every unit lurch north.
func _local_push(from_ref: int, to_ref: int) -> Vector3:
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
	var beam := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.05, from.distance_to(to))
	beam.mesh = box
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
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
	if _state.outcome != CombatState.ONGOING:
		_selected = -1
		_refresh()
		_hud.set_banner("FIGHT OVER", UIKit.TEXT_DIM)
		_hud.set_hint("")
		var crawler: GridUnit = _state.crawler()
		var body: String = "Round %d  ·  %d of 3 constructs standing" % [_state.round_number, _state.crew(GridUnit.TEAM_PLAYER).size()]
		if crawler != null:
			body += "  ·  Crawler %d/%d" % [crawler.hp, crawler.max_hp] if crawler.alive else "\nThe Crawler was destroyed."
		_hud.show_result(_state.outcome == CombatState.WON, body)
		return
	if _selected < 0 or not _unit_has_moves(_selected):
		_selected = _next_ready_unit()
	_weapon = _default_weapon(_selected, _weapon)
	_hud.set_banner("ROUND %d  ·  YOUR TURN" % _state.round_number)
	_refresh()
	if _bot:
		await _wait(0.6)
		await _bot_turn()


func _refresh() -> void:
	_clear_marks()
	var threats: Dictionary = CombatSim.threats(_state)
	for ref: Variant in threats:
		var threat: Dictionary = threats[ref]
		for cell: Vector2i in (threat["tiles"] as Array):
			_mark(_threat_quads, cell, COL_THREAT)
		_intent_marker(int(ref), threat)

	var sel: GridUnit = _state.unit(_selected) if _selected >= 0 else null
	if sel != null and sel.alive:
		if _armed and not sel.acted and not sel.seized and sel.can_fire(_weapon):
			if _pending.size() == 4:
				var plan: Dictionary = CombatSim.strike_plan(_state, sel, _weapon, int(_pending[2]), int(_pending[3]))
				for cell: Vector2i in (plan["tiles"] as Array):
					_mark(_hint_quads, cell, COL_TARGET)
			else:
				for aim: Array in CombatSim.aim_options(_state, sel, _weapon):
					var plan: Dictionary = CombatSim.strike_plan(_state, sel, _weapon, int(aim[0]), int(aim[1]))
					if not bool(plan["legal"]):
						continue
					# A lob is aimed at one tile; a line or a blow covers its whole path.
					if String(sel.weapons[_weapon]["shape"]) == "lob":
						_mark(_hint_quads, plan["aim"], COL_ATTACK)
					else:
						for cell: Vector2i in (plan["tiles"] as Array):
							_mark(_hint_quads, cell, COL_ATTACK)
		if not _armed:
			for cell: Variant in CombatSim.reachable(_state, _selected):
				_mark(_hint_quads, cell, COL_MOVE)
	_refresh_hud(threats)


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
		})
	_hud.set_crew(cards)
	var crawler: GridUnit = _state.crawler()
	_hud.set_crawler(crawler.hp if crawler != null else 0, crawler.max_hp if crawler != null else 0)
	var ongoing: bool = _state.outcome == CombatState.ONGOING and not _bot
	_hud.set_controls(ongoing and not _busy and _actions.size() > _turn_start, ongoing and not _busy)

	var sel: GridUnit = _state.unit(_selected) if _selected >= 0 else null
	_refresh_weapon_bar(sel)
	if _pending.size() == 4:
		_hud.set_info("FIRE %s" % String(sel.weapons[int(_pending[1])]["name"]).to_upper(),
			_preview_text(CombatSim.preview_attack(_state, int(_pending[0]), int(_pending[1]), int(_pending[2]), int(_pending[3])))
			+ "\n\nTap the same target again to confirm.")
		_hud.set_hint("Tap the yellow target again to fire  ·  tap elsewhere to cancel")
	elif sel != null:
		_hud.set_info(sel.name.to_upper(), "%s\n%s\n\n%s" % [_unit_line(sel), _arms_line(sel), _threat_summary(threats)])
		if sel.seized:
			_hud.set_hint("SEIZED this round: it can move but not attack.")
		elif _armed:
			_hud.set_hint("Yellow: %s targets  ·  tap one to aim  ·  tap the weapon again to go back to moving" % String(sel.weapons[_weapon]["name"]))
		elif not sel.acted:
			_hud.set_hint("Blue: move  ·  Red: where enemies will fire  ·  pick a weapon below to attack")
		else:
			_hud.set_hint("This construct is done. Pick another, or END TURN.")
	else:
		_hud.set_info("ENEMY INTENTS", _threat_summary(threats))
		_hud.set_hint("Every construct has acted. END TURN to let the enemy fire.")


func _refresh_weapon_bar(sel: GridUnit) -> void:
	if sel == null or not sel.alive or sel.objective:
		_hud.set_weapons([], -1, "")
		return
	var list: Array = []
	for w: int in sel.weapons.size():
		var weapon: Dictionary = sel.weapons[w]
		var reason: String = ""
		if bool(weapon["torn"]):
			reason = "ARM TORN OFF"
		elif sel.seized:
			reason = "SEIZED THIS ROUND"
		elif sel.acted:
			reason = "ALREADY ACTED"
		list.append({"name": String(weapon["name"]), "detail": _weapon_detail(sel, w),
			"available": reason.is_empty(), "reason": reason})
	var vent: String = ""
	if not sel.acted and sel.heat > 0:
		vent = "Drop heat to 0. Uses this construct's action."
	_hud.set_weapons(list, _weapon if _armed and sel.can_fire(_weapon) else -1, vent)


func _preview_text(preview: Dictionary) -> String:
	var lines: PackedStringArray = []
	var hits: Array = preview.get("hits", [])
	if hits.is_empty():
		lines.append("Nothing there takes damage.")
	for hit: Dictionary in hits:
		var t: GridUnit = _state.unit(int(hit["ref"]))
		var who: String = t.name + (" (ALLY)" if t.team == GridUnit.TEAM_PLAYER else "")
		var extra: String = ""
		if (preview["kills"] as Array).has(t.ref):
			extra = "  DESTROYS IT"
		elif (preview["tears"] as Array).has(t.ref):
			extra = "  TEARS AN ARM OFF"
		lines.append("%s  -%d → %d/%d%s" % [who, int(hit["damage"]), maxi(0, t.hp - int(hit["damage"])), t.max_hp, extra])
	if bool(preview.get("overheats", false)):
		lines.append("OVERHEATS: no attack next round")
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
		lines.append("%d. %s (%s) → %s" % [int(threat["order"]), shooter.name,
			String(shooter.weapons[int(threat["w"])]["name"]), ", ".join(names) if not names.is_empty() else "nothing"])
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
		"line":
			bits.append("line %d" % CombatSim.weapon_reach(_state, u, w))
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
	bits.append("+%d heat" % (int(weapon["heat"]) + u.heat_bonus))
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


## The firing order on the line of fire, and a red bar from the shooter to where it lands.
func _intent_marker(ref: int, threat: Dictionary) -> void:
	var u: GridUnit = _state.unit(ref)
	var from: Vector3 = _to_world(u.x, u.y) + Vector3(0, 0.35, 0)
	var end: Vector2i = threat["aim"]
	var to: Vector3 = _to_world(end.x, end.y) + Vector3(0, 0.35, 0)

	var label := Label3D.new()
	label.text = str(int(threat["order"]))
	label.font_size = 72
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 16
	label.outline_modulate = Color(0, 0, 0, 0.95)
	label.modulate = Color("ff7a5c")
	# On the line of fire rather than over the shooter: above the machine it sat on top
	# of the health tag and the two numbers read as one.
	label.position = (from.lerp(to, 0.5) if from.distance_to(to) > 0.01 else from) + Vector3(0, 0.55, 0)
	label.set_meta("intent", true)
	_marks_root.add_child(label)

	if from.distance_to(to) < 0.01:
		return
	var bar := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.07, 0.03, from.distance_to(to))
	bar.mesh = box
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ff5a3c")
	bar.material_override = material
	bar.set_meta("intent", true)
	_marks_root.add_child(bar)
	bar.look_at_from_position((from + to) * 0.5, to, Vector3.UP)


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
			KEY_Q:
				_rotate(-1)
			KEY_E:
				_rotate(1)


func _set_zoom(value: float) -> void:
	_zoom = clampf(value, ZOOM_MIN, ZOOM_MAX)
	_place_camera()


## The tile under a screen point, or null. Intersects the board plane rather than
## physics bodies: nothing on the board needs a collider, and a phone does not pay for one.
func _pick(screen: Vector2) -> Variant:
	var origin: Vector3 = _camera.project_ray_origin(screen)
	var normal: Vector3 = _camera.project_ray_normal(screen)
	if absf(normal.y) < 0.0001:
		return null
	var t: float = (0.05 - origin.y) / normal.y
	if t < 0.0:
		return null
	var hit: Vector3 = origin + normal * t
	var x: int = roundi(hit.x / TILE + (_setup.width - 1) * 0.5)
	var y: int = roundi(hit.z / TILE + (_setup.height - 1) * 0.5)
	if x < 0 or y < 0 or x >= _setup.width or y >= _setup.height:
		return null
	return Vector2i(x, y)


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
			_pending = []
			_act([CombatSim.ACT_MOVE, sel.ref, cell.x, cell.y])
			return
	if sel != null and sel.alive and _armed:
		var aim: Array = _aim_for(sel, cell)
		if not aim.is_empty():
			if _pending.size() == 4 and int(_pending[2]) == int(aim[0]) and int(_pending[3]) == int(aim[1]):
				_pending = []
				_armed = false
				_act([CombatSim.ACT_ATTACK, sel.ref, _weapon, int(aim[0]), int(aim[1])])
			else:
				_pending = [sel.ref, _weapon, int(aim[0]), int(aim[1])]
				Audio.play("ui_confirm", -14.0)
				_refresh()
			return

	_pending = []
	_refresh()
	if there != null:
		_hud.set_info(there.name.to_upper() + ("" if there.alive else "  ·  WRECK"),
			"%d / %d HP\n%s" % [there.hp, there.max_hp, "Protect it: losing it loses the fight." if there.objective
				else _unit_line(there) + "\n" + _arms_line(there)])


## `[dir, dist]` of the armed weapon's aim that covers `cell`, or empty. A lob is aimed
## at its landing tile; a line or a blow at any tile of its path.
func _aim_for(u: GridUnit, cell: Vector2i) -> Array:
	if u.acted or u.seized or not u.can_fire(_weapon):
		return []
	var lob: bool = String(u.weapons[_weapon]["shape"]) == "lob"
	for aim: Array in CombatSim.aim_options(_state, u, _weapon):
		var plan: Dictionary = CombatSim.strike_plan(_state, u, _weapon, int(aim[0]), int(aim[1]))
		if not bool(plan["legal"]):
			continue
		if (lob and plan["aim"] == cell) or (not lob and (plan["tiles"] as Array).has(cell)):
			return aim
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
	_pending = []
	Audio.play("ui_confirm", -16.0)
	_refresh()


func _choose_weapon(w: int) -> void:
	var u: GridUnit = _state.unit(_selected) if _selected >= 0 else null
	if _busy or u == null or not u.can_fire(w):
		return
	# Tapping the armed weapon again puts the construct back into moving.
	_armed = not (_armed and _weapon == w)
	_weapon = w
	_pending = []
	Audio.play("ui_confirm", -16.0)
	_refresh()


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
	_pending = []
	_act([CombatSim.ACT_VENT, _selected, 0, 0])


func _act(action: Array) -> void:
	if not CombatSim.apply(_state, action):
		Audio.play("ui_deny", -10.0)
		return
	_actions.append(action)
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
	_state = CombatSim.replay(_setup, _actions)
	_shown = _state.events.size()
	_pending = []
	_armed = false
	_spawn_units()
	_weapon = _default_weapon(_selected, _weapon)
	Audio.play("ui_deny", -14.0)
	_refresh()


func _end_turn() -> void:
	if _busy or _state.outcome != CombatState.ONGOING:
		return
	_pending = []
	_armed = false
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
			await _play_new_events()
	if _state.outcome == CombatState.ONGOING:
		await _wait(0.4)
		_selected = -1
		if CombatSim.apply(_state, [CombatSim.ACT_END, -1, 0, 0]):
			_actions.append([CombatSim.ACT_END, -1, 0, 0])
		_turn_start = _actions.size()
		await _play_new_events()
	_after_events()
