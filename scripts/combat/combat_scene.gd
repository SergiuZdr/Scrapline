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
## An attack waiting for its confirming second tap: `[ref, dir]`, or empty.
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
	_setup = CombatSetup.build(_db.fights.get(_fight_id, {}), _db.combat_rules, _db.parts, _db.tiles, _seed)
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
	var model: Node3D = ConstructView.build_parts(u.part_ids, _db, colour)
	model.scale = Vector3.ONE * MODEL_SCALE
	root.add_child(model)
	var ring: MeshInstance3D = _team_ring(colour)
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
	tag.modulate = colour.lightened(0.45)
	root.add_child(tag)

	var view: Dictionary = {"root": root, "model": model, "rig": rig, "ring": ring, "tag": tag, "dead": false}
	_set_tag(view, u.hp, u.max_hp)
	if not u.alive:
		_show_wrecked(view, Vector3(0, 0, 1))
	return view


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


func _set_tag(view: Dictionary, hp: int, max_hp: int) -> void:
	(view["tag"] as Label3D).text = "%d/%d" % [hp, max_hp]


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


## Snaps every model to the state -- after an undo, when nothing should animate.
## A unit that died in the undone part of the turn is rebuilt: a fall cannot be un-played.
func _sync_all() -> void:
	for u: GridUnit in _state.units:
		var view: Dictionary = _views[u.ref]
		if u.alive and bool(view["dead"]):
			(view["root"] as Node3D).queue_free()
			view = _build_view(u)
			_views[u.ref] = view
		var root: Node3D = view["root"]
		root.position = _to_world(u.x, u.y) + Vector3(0, _tile_top(u.x, u.y), 0)
		_set_tag(view, u.hp, u.max_hp)


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
			await _attack(actor, cell, int(e[GridEv.F_V1]))
		GridEv.DAMAGE:
			await _hit(actor, target, int(e[GridEv.F_V1]), int(e[GridEv.F_V2]))
		GridEv.DESTROYED:
			await _destroyed(actor, target)
		GridEv.MISSED:
			_float_text(_to_world(cell.x, cell.y) + Vector3(0, 0.9, 0), "MISS", UIKit.TEXT_DIM)
			await _wait(0.18)
		GridEv.FIGHT_END:
			pass


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


func _attack(ref: int, end: Vector2i, dir: int) -> void:
	var view: Dictionary = _views[ref]
	var root: Node3D = view["root"]
	var u: GridUnit = _state.unit(ref)
	var toward: Vector3 = root.position + Vector3(CombatState.DX[dir], 0, CombatState.DY[dir])
	_face(root, toward)
	await _wait(0.12)
	(view["rig"] as ConstructRig).strike("arm_r", u.weapon_class, get_tree())
	var colour: Color = COL_PLAYER if u.team == GridUnit.TEAM_PLAYER else COL_ENEMY
	var muzzle: Vector3 = root.position + Vector3(0, 0.7, 0)
	var hit_point: Vector3 = _to_world(end.x, end.y) + Vector3(0, 0.6, 0)
	if u.attack_range > 1:
		_vfx.muzzle_flash(muzzle, hit_point, colour.lightened(0.5))
		_tracer(muzzle, hit_point, colour.lightened(0.3))
		Audio.play("detonate", -12.0)
	await _wait(T_ATTACK)


func _hit(attacker: int, victim: int, amount: int, hp_left: int) -> void:
	var view: Dictionary = _views[victim]
	var root: Node3D = view["root"]
	var u: GridUnit = _state.unit(victim)
	var severity: float = clampf(float(amount) / maxf(1.0, float(u.max_hp) * 0.35), 0.15, 1.0)
	_vfx.impact(root.position + Vector3(0, 0.6, 0), Color("ffb070"), severity)
	(view["rig"] as ConstructRig).stagger(_local_push(attacker, victim), severity)
	_float_text(root.position + Vector3(0, 1.8, 0), "-%d" % amount, UIKit.RED.lightened(0.25))
	_set_tag(view, hp_left, u.max_hp)
	Audio.play("hit_heavy" if severity > 0.6 else "hit_light", -6.0)
	if severity > 0.8:
		_vfx.shake(0.35 * severity)
	await _wait(T_HIT)


func _destroyed(killer: int, victim: int) -> void:
	var view: Dictionary = _views[victim]
	_vfx.destruction((view["root"] as Node3D).position + Vector3(0, 0.5, 0), Color("ff9a5a"))
	_show_wrecked(view, _local_push(killer, victim))
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
	var length: float = from.distance_to(to)
	box.size = Vector3(0.05, 0.05, length)
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
	label.font_size = 64
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
	if _state.outcome != CombatState.ONGOING:
		_selected = -1
		_refresh()
		_hud.set_banner("FIGHT OVER", UIKit.TEXT_DIM)
		_hud.set_hint("")
		var standing: int = _state.living(GridUnit.TEAM_PLAYER).size()
		_hud.show_result(_state.outcome == CombatState.WON,
			"Round %d  ·  %d of 3 constructs still standing" % [_state.round_number, standing])
		return
	if _selected < 0 or not _unit_has_moves(_selected):
		_selected = _next_ready_unit()
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
		# Attack lines first, then moves over them: a tile that is both means MOVE when
		# tapped (see `_tap`), so it must be drawn as a move.
		if not sel.acted:
			for dir: int in 4:
				var preview: Dictionary = CombatSim.preview_attack(_state, _selected, dir)
				if not bool(preview.get("legal", false)):
					continue
				var pending: bool = _pending.size() == 2 and int(_pending[1]) == dir
				for cell: Vector2i in (preview["tiles"] as Array):
					_mark(_hint_quads, cell, COL_TARGET if pending else COL_ATTACK)
		for cell: Variant in CombatSim.reachable(_state, _selected):
			_mark(_hint_quads, cell, COL_MOVE)
	_refresh_hud(threats)


func _refresh_hud(threats: Dictionary) -> void:
	var cards: Array = []
	for u: GridUnit in _state.units:
		if u.team != GridUnit.TEAM_PLAYER:
			continue
		cards.append({
			"ref": u.ref, "name": u.name, "detail": _weapon_line(u),
			"hp": u.hp, "max_hp": u.max_hp, "alive": u.alive,
			"can_move": not u.moved and not u.acted, "can_act": not u.acted,
			"selected": u.ref == _selected,
		})
	_hud.set_crew(cards)
	var ongoing: bool = _state.outcome == CombatState.ONGOING and not _bot
	_hud.set_controls(ongoing and not _busy and _actions.size() > _turn_start, ongoing and not _busy)

	var sel: GridUnit = _state.unit(_selected) if _selected >= 0 else null
	if _pending.size() == 2:
		var preview: Dictionary = CombatSim.preview_attack(_state, int(_pending[0]), int(_pending[1]))
		var target: GridUnit = _state.unit(int(preview["target"]))
		if target == null:
			_hud.set_info("FIRE — NO TARGET", "Nothing in that line takes damage.\nTap again to fire anyway.")
		else:
			var side: String = "ALLY" if target.team == GridUnit.TEAM_PLAYER else "ENEMY"
			_hud.set_info("FIRE AT %s" % target.name.to_upper(),
				"%s  ·  %d damage → %d / %d HP%s\nTap the same line again to confirm." % [
					side, int(preview["damage"]), maxi(0, target.hp - int(preview["damage"])), target.max_hp,
					"\nDESTROYS IT" if bool(preview["kills"]) else ""])
		_hud.set_hint("Tap the highlighted line again to fire  ·  tap elsewhere to cancel")
	elif sel != null:
		_hud.set_info(sel.name.to_upper(), "%s\nMove %d  ·  %d HP\n\n%s" % [
			_weapon_line(sel), sel.move, sel.hp, _threat_summary(threats)])
		if not sel.moved and not sel.acted:
			_hud.set_hint("Blue: move  ·  Yellow: attack line  ·  Red: where enemies will fire")
		elif not sel.acted:
			_hud.set_hint("Tap a yellow line to attack, or pick another construct")
		else:
			_hud.set_hint("This construct is done. Pick another, or END TURN.")
	else:
		_hud.set_info("ENEMY INTENTS", _threat_summary(threats))
		_hud.set_hint("Every construct has acted. END TURN to let the enemy fire.")


func _threat_summary(threats: Dictionary) -> String:
	if threats.is_empty():
		return "No enemy is aiming at anything this round."
	var lines: PackedStringArray = []
	var refs: Array = threats.keys()
	refs.sort_custom(func(a: int, b: int) -> bool: return int(threats[a]["order"]) < int(threats[b]["order"]))
	for ref: Variant in refs:
		var threat: Dictionary = threats[ref]
		var shooter: GridUnit = _state.unit(int(ref))
		var hit: GridUnit = _state.unit(int(threat["hit"]))
		lines.append("%d. %s → %s" % [int(threat["order"]), shooter.name,
			("%s (-%d)" % [hit.name, shooter.damage]) if hit != null else "nothing"])
	return "Enemy fire, in order:\n" + "\n".join(lines)


func _weapon_line(u: GridUnit) -> String:
	var kind: String = "melee" if u.attack_range <= 1 else "range %d line" % u.attack_range
	return "%s  ·  %s  ·  %d dmg" % [u.weapon_class.capitalize(), kind, u.damage]


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


## The firing order above the attacker and a red bar down its line of fire.
func _intent_marker(ref: int, threat: Dictionary) -> void:
	var u: GridUnit = _state.unit(ref)
	var from: Vector3 = _to_world(u.x, u.y) + Vector3(0, 0.35, 0)
	var end: Vector2i = threat["end"]
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
				_select((event as InputEventKey).keycode - KEY_1)
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
	#   2. a tile the selected construct can move to: move
	#   3. a tile on one of its attack lines: aim, and a second tap on the same line fires
	if there != null and there.alive and there.team == GridUnit.TEAM_PLAYER:
		_select(there.ref)
		return

	var sel: GridUnit = _state.unit(_selected) if _selected >= 0 else null
	if sel != null and sel.alive:
		if CombatSim.reachable(_state, sel.ref).has(cell):
			_pending = []
			_act([CombatSim.ACT_MOVE, sel.ref, cell.x, cell.y])
			return
		var dir: int = _attack_dir(sel, cell)
		if dir >= 0:
			if _pending.size() == 2 and int(_pending[1]) == dir:
				_pending = []
				_act([CombatSim.ACT_ATTACK, sel.ref, dir, 0])
			else:
				_pending = [sel.ref, dir]
				Audio.play("ui_confirm", -14.0)
				_refresh()
			return

	_pending = []
	if there != null:
		_refresh()
		_hud.set_info(there.name.to_upper() + ("" if there.alive else "  ·  WRECK"),
			"%s\n%d / %d HP" % [_weapon_line(there), there.hp, there.max_hp])
	else:
		_refresh()


## The direction of an attack line from `u` that covers `cell`, or -1.
func _attack_dir(u: GridUnit, cell: Vector2i) -> int:
	if u.acted:
		return -1
	for dir: int in 4:
		var preview: Dictionary = CombatSim.preview_attack(_state, u.ref, dir)
		if bool(preview.get("legal", false)) and (preview["tiles"] as Array).has(cell):
			return dir
	return -1


func _select(ref: int) -> void:
	if _busy or ref < 0:
		return
	var u: GridUnit = _state.unit(ref)
	if u == null or not u.alive or u.team != GridUnit.TEAM_PLAYER:
		return
	_selected = ref
	_pending = []
	Audio.play("ui_confirm", -16.0)
	_refresh()


func _act(action: Array) -> void:
	if not CombatSim.apply(_state, action):
		Audio.play("ui_deny", -10.0)
		return
	_actions.append(action)
	_refresh_hud(CombatSim.threats(_state))
	await _play_new_events()
	_after_events()


func _undo() -> void:
	if _busy or _bot or _actions.size() <= _turn_start:
		return
	_actions.pop_back()
	_state = CombatSim.replay(_setup, _actions)
	_shown = _state.events.size()
	_pending = []
	_sync_all()
	Audio.play("ui_deny", -14.0)
	_refresh()


func _end_turn() -> void:
	if _busy or _state.outcome != CombatState.ONGOING:
		return
	_pending = []
	_selected = -1
	await _act([CombatSim.ACT_END, -1, 0, 0])
	_turn_start = _actions.size()


func _unit_has_moves(ref: int) -> bool:
	var u: GridUnit = _state.unit(ref)
	return u != null and u.alive and not u.acted


func _next_ready_unit() -> int:
	for u: GridUnit in _state.units:
		if u.team == GridUnit.TEAM_PLAYER and u.alive and not u.acted:
			return u.ref
	return -1


## `--bot`: plays each unit's move and attack through the same `_act` a tap reaches, so
## the demo exercises the real input path rather than a shortcut around it.
func _bot_turn() -> void:
	for u: GridUnit in _state.living(GridUnit.TEAM_PLAYER):
		if _state.outcome != CombatState.ONGOING:
			return
		_selected = u.ref
		_refresh()
		for action: Array in CombatBot.plan_unit(_state, u.ref, false):
			await _wait(0.35)
			if _state.outcome != CombatState.ONGOING:
				return
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
