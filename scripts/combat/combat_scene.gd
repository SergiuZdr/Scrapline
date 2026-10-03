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
##   --reclaimer    the Reclaimer's drones reach into this practice fight (arriving round 2)
##   --fight-file <res://path.json>   a fight from a file outside the content (a staged
##                  screenshot like `tools/frames/decision.json`: never in a run or the hash)
##
## `scenes/shakedown.tscn` is this scene with `tutorial` on (012): the shakedown fight from
## `data/tutorial.json`, with the coach (`coach.gd`) over it.

## Centre-to-corner size of a hex, in metres. Pointy-top: a hex is sqrt(3) * HEX wide.
const HEX: float = 0.78
const SQRT3: float = 1.7320508
## Ink & Rust (015): the signals are `Ink`'s. Each mark colour below also names a STYLE of
## mark (`MARK_STYLES`): the hatching and the border carry the read, so it survives grey.
const COL_PLAYER := Ink.YOURS
const COL_ENEMY := Ink.DANGER
const COL_MOVE := Color("33c8e0")
## A hex in range that costs 2 to enter (rubble, a ridge): the same blue, fainter hatching and
## a broken border, so a route that goes round it reads as a choice (play-test 5).
const COL_MOVE_SLOW := Color("33c8e0c0")
const COL_ATTACK := Color("ffc43d80")
const COL_TARGET := Color("ffc43d")
const COL_ATTACK_FAINT := Color("ffc43d40")
const COL_SPAWN := Color("a070e0")
## A hive pad, and the same pad the turn before it builds (play-test 4: warn a turn ahead).
const COL_PAD := Color("a070e0")
const COL_PAD_DANGER := Color("ff3b30")
const COL_THREAT := Color("ff3b30c0")
## A defend cache is YOURS to protect, so it wears your colour (docs/plans/art-and-audio.md:
## amber means "your action", and a cache is not one).
const COL_CACHE := Ink.YOURS
## What an aimed shot sets off (015): a drum's blast, drawn on every hex it will reach.
const COL_BLAST := Color("ffc43d30")
## How each mark is drawn: [hatch alpha, hatch width, wash alpha, border, dashes (0 = solid),
## hatch direction]. The direction carries the meaning in grey: one diagonal for where you can
## go, the other for what will be hit, crossed for what you aim at (the grey copy of the first
## frame could not tell a move hex from a threatened one without its badge).
const MARK_STYLES: Dictionary = {
	COL_MOVE: [0.55, 0.30, 0.10, 0.09, 0.0, 1.0],
	COL_MOVE_SLOW: [0.32, 0.14, 0.04, 0.07, 12.0, 1.0],
	COL_ATTACK: [0.35, 0.20, 0.06, 0.08, 0.0, 0.0],
	COL_TARGET: [0.62, 0.24, 0.16, 0.12, 0.0, 0.0],
	COL_ATTACK_FAINT: [0.0, 0.0, 0.0, 0.06, 12.0, 0.0],
	COL_SPAWN: [0.50, 0.30, 0.12, 0.09, 0.0, -1.0],
	COL_THREAT: [0.62, 0.30, 0.16, 0.10, 0.0, -1.0],
	COL_BLAST: [0.22, 0.12, 0.05, 0.08, 10.0, 0.0],
}
## Terrain in ink: flat fields, told apart by value and by what is drawn on them.
const INK_TERRAIN: Dictionary = {
	"open": Color("1f2024"), "rubble": Color("403830"), "slag": Color("3d1f17"), "ridge": Color("42454c"),
	"scrap": Color("1c1917"), "barrel": Color("1f2024"), "crate": Color("1f2024"), "pylon": Color("1f2024"),
	"flue": Color("241a17"), "wire": Color("2a2818"),
}
## The gate keepers drawn bigger than anything else on the board (013, 025).
const BIG_KINDS: Array[String] = ["sorter", "heart", "pour", "grinder", "magnet", "twin"]
## 038: the act's bosses stand bigger still than the warlords (the Pour was not even big).
const BOSS_KINDS: Array[String] = ["sorter", "pour", "heart"]
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
## The beat between consequences of one cause that are played together (play-test 7), and the
## events that are.
const T_TOGETHER: float = 0.05
## How long the opening card stays up at least (play-test 8).
const OPENING_SECONDS: float = 5.0
const CONCURRENT: Array[int] = [GridEv.DAMAGE, GridEv.DESTROYED, GridEv.PROP_HIT, GridEv.PROP_BROKEN,
	GridEv.EXPLOSION, GridEv.PILE_DROPPED, GridEv.BUMP, GridEv.MARKED, GridEv.PART_TORN, GridEv.HEAT,
	GridEv.PILE_LOST, GridEv.FLUE_BLEW]

## The shakedown (012): set in `scenes/shakedown.tscn`.
@export var tutorial: bool = false

const Coach := preload("res://scripts/combat/coach.gd")

var _db: ContentDB
var _fight_id: String = "proto_yard"
var _coach: Control
## The coach's marker on the board: a ring and a bobbing chevron in the colour of your action.
var _coach_marker: Node3D
## The route the picked machine would walk to the hovered hex (dots), rebuilt on hover.
var _path_root: Node3D
## The amber ring and chevron on the machine under the player's hand (play-test 7).
var _sel_marker: Node3D
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
## 038: how far a boss fight's view is pulled back to clear the boss bar.
var _boss_shift: float = 0.0
## 039: the attack being played, so its first hit can be lettered with its sound.
var _sfx_attacker: int = -1
var _sfx_weapon: int = -1
var _sfx_said: bool = false
var _zoom: float = 12.5
var _yaw_step: int = 0
var _vfx: BattleVFX
var _hud: CombatHUD


func _ready() -> void:
	Audio.ambience(true)
	_read_args()
	_db = ContentDB.load_all()
	if tutorial:
		_fight_id = String(_db.tutorial.get("fight", "shakedown"))
		_seed = int(_db.tutorial.get("seed", 1))
	_build_world()
	# 036: the world printed on paper, under the HUD.
	Ink.print_pass(self, 0)
	_hud = CombatHUD.new()
	_hud.glossary = _db.glossary
	var layer := CanvasLayer.new()
	layer.layer = 1
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
	_run_mode = Run.in_fight() and not OS.get_cmdline_user_args().has("--fight") \
		and not OS.get_cmdline_user_args().has("--fight-file") and not tutorial
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
		var fight: Dictionary = (_db.fights.get(_fight_id, {}) as Dictionary).duplicate(true)
		var file_at: int = OS.get_cmdline_user_args().find("--fight-file")
		if file_at >= 0 and file_at + 1 < OS.get_cmdline_user_args().size():
			fight = JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[file_at + 1]))
		if OS.get_cmdline_user_args().has("--reclaimer"):
			fight["reclaimer"] = {"round": 2, "count": 2}
		_setup = CombatSetup.build(fight, _db.combat_rules, _db.parts, _db.tiles, _db.balance.effectiveness, _seed)
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
	# The objective is up before anything moves (play-test 7), on the opening card and in its plate.
	var status: Dictionary = CombatSim.objective_status(_state)
	_hud.set_objective(String(status["text"]) + _yard_line(), false)
	_busy = true
	if _actions.is_empty():
		# A fresh fight plays from the very start, so the models start where the SETUP
		# puts them and the enemies' opening moves and grabs play out on screen.
		_spawn_initial()
	else:
		# A resumed fight does not replay its history on screen: it opens on the turn.
		_spawn_units()
	await _opening(String(status["text"]) + _yard_line())
	if _actions.is_empty():
		_shown = 0
		await _play_new_events()
	else:
		_shown = _state.events.size()
	_after_events()


## The opening card over the board while one of every effect is drawn behind it (play-test 7).
## On this Mac's GL driver the first draw of each kind of material compiled its shader on the
## spot -- 300 ms a time, mid-fight, which read as the game hanging whenever a lot happened at
## once. Here they compile under the card instead. The card stays long enough to be read.
func _opening(objective: String) -> void:
	var headless: bool = DisplayServer.get_name() == "headless"
	var shown_at: int = Time.get_ticks_msec()
	# 039: a boss's or warlord's fight opens as a comic STRIP -- where, who, what to do.
	var keeper: GridUnit = null
	for u: GridUnit in _setup.units:
		if u.team == GridUnit.TEAM_ENEMY and BIG_KINDS.has(u.kind):
			keeper = u
			break
	if keeper != null:
		var kind: Dictionary = _setup.kinds.get(keeper.kind, {})
		var said: String = String(kind.get("text", ""))
		var crew: Array = []
		for c: GridUnit in _setup.units:
			if c.team == GridUnit.TEAM_PLAYER and not c.objective:
				crew.append(Array(c.part_ids))
		_hud.show_opening_strip([
			{"caption": "MEANWHILE...", "big": "AT THE GATE" if BOSS_KINDS.has(keeper.kind) else "OFF THE ROAD", "small": _setup_name()},
			{"caption": "BOSS" if BOSS_KINDS.has(keeper.kind) else "WARLORD", "big": String(kind.get("name", keeper.name)).to_upper(),
				"small": said.get_slice(". ", 0) + ("." if said.contains(". ") else ""), "machines": [Array(keeper.part_ids)],
				"paint": Color("6e1a14") if BOSS_KINDS.has(keeper.kind) else Color("3b3936")},
			{"caption": "YOUR JOB", "big": "BREAK IT", "small": objective, "machines": crew},
		])
	else:
		_hud.show_opening(_setup_name(), objective)
	var cell := Vector2i(_setup.width / 2, _setup.height / 2)
	var at: Vector3 = _to_world(cell.x, cell.y) + Vector3(0, _tile_top(cell.x, cell.y), 0)
	var hot := Color("ff7a3c")
	var before: Array = _marks_root.get_children()
	_vfx.impact(at, hot, 1.0)
	_vfx.muzzle_flash(at, at + Vector3(1, 0, 0), hot)
	_vfx.burst(at, hot, 1.2)
	_vfx.fireball(at, 0.6)
	_vfx.destruction(at, hot)
	_tracer(at + Vector3(0, 0.7, 0), at + Vector3(1.5, 0.6, 0), hot)
	_float_text(at, "-1", UIKit.RED)
	_letters(at, "BOOM!", Ink.ACTION)
	# 039: the comic effects compile here too, behind the card.
	_focus_lines(at)
	_streaks(at, at + Vector3(1, 0, 0))
	_badge("-3 KO", at, Ink.DANGER, 1.0)
	_marker_label("warm", at, Ink.PAPER, 24)
	_spawn_marker(-1, cell)
	_arrival_marker(cell)
	_flood_marker(cell)
	_terminal(Hex.neighbor(cell, 3) if _state.inside(Hex.neighbor(cell, 3)) else cell, false)
	_throw_arrow(cell, Hex.neighbor(cell, 0))
	_intent_marker_bar(at, at + Vector3(1.5, 0, 0))
	_intent_marker_bar(at, at + Vector3(0, 0, 1.5), Ink.DANGER, true)
	# Every style of hex mark, and the HUD as it will first be drawn.
	var ring: Array[Vector2i] = Hex.neighbors(cell)
	var styles: Array = MARK_STYLES.keys()
	for i: int in styles.size():
		var quads: Dictionary = _threat_quads if i % 2 == 0 else _hint_quads
		_mark(quads, ring[i % ring.size()] if _state.inside(ring[i % ring.size()]) else cell, styles[i])
	_refresh_hud(CombatSim.threats(_state))
	var pile: bool = not _pile_views.has(cell)
	if pile:
		_spawn_pile(cell)
	var marker: Node3D = _build_selection_marker() if _sel_marker == null else _sel_marker
	_sel_marker = marker
	marker.visible = true
	marker.position = at
	for i: int in 4:
		await get_tree().process_frame
	# Marks go now. The tracer, the float and the lettering are hidden and left to finish their
	# own tweens (freeing them under a running tween would call into a freed node).
	_clear_marks()
	for child: Node in _marks_root.get_children():
		if not before.has(child) and child is Node3D:
			(child as Node3D).visible = false
	_vfx.settle()
	_hud.set_info("", "")
	_hud.set_hint("")
	if pile:
		_remove_pile(cell)
	# Play-test 8: at least 5 s, so the objective can be read before the board takes over.
	var left: float = 0.0 if headless or _bot else OPENING_SECONDS - float(Time.get_ticks_msec() - shown_at) / 1000.0
	if left > 0.0:
		await _wait(left)
	_hud.hide_opening(0.0 if headless else 0.3)


## The yard's conditions (028), as a line under the objective.
func _yard_line() -> String:
	var lines: PackedStringArray = []
	var table: Dictionary = _db.combat_rules.get("modifiers", {})
	for id: String in _setup.modifiers:
		var m: Dictionary = table.get(id, {})
		lines.append("%s · %s" % [String(m.get("name", id.to_upper())), String(m.get("text", ""))])
	return "" if lines.is_empty() else "\n" + "\n".join(lines)


func _setup_name() -> String:
	return _setup.fight_name if not _setup.fight_name.is_empty() else "The Fight"


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


## The fight recap (014, review point R5-1): what each machine did, and what its build added
## -- counted by `FightRecap` from the fight's own events.
func _recap_text() -> String:
	var crew: Array = []
	for index: Variant in RunSim._fielded_crew(Run.state):
		crew.append(Run.state.crew[int(index)])
	var recap: Dictionary = FightRecap.build(_state, Run.setup, crew)
	var lines: PackedStringArray = []
	for m: Dictionary in (recap["machines"] as Array):
		var bits: PackedStringArray = ["%d dealt" % int(m["dealt"]), "%d taken" % int(m["taken"])]
		if int(m["kills"]) > 0:
			bits.append("%d kill%s" % [int(m["kills"]), "" if int(m["kills"]) == 1 else "s"])
		if int(m["torn"]) > 0:
			bits.append("%d arm%s torn, bolted back on" % [int(m["torn"]), "" if int(m["torn"]) == 1 else "s"])
		if bool(m["wrecked"]):
			bits.append("WRECKED")
		lines.append("%s  ·  %s" % [String(m["name"]).to_upper(), "  ·  ".join(bits)])
	var builds: Array = recap["builds"]
	if not builds.is_empty():
		lines.append("")
		lines.append("YOUR BUILD AT WORK")
		for b: Dictionary in builds:
			lines.append("%s  ·  %s: %s" % [String(b["who"]).to_upper(), String(b["what"]), String(b["text"])])
	return "\n".join(lines)


## Hands the finished fight's action log to the run, which replays it for itself.
func _back_to_run() -> void:
	Run.finish_fight(_actions)
	get_tree().change_scene_to_file("res://scenes/run_map.tscn")


func _record() -> void:
	if _run_mode:
		Run.record_fight(_actions)


# --- World ------------------------------------------------------------------

func _build_world() -> void:
	# Ink & Rust (015): one hard key over a flat night. The toon ramp and the ink line draw the
	# look; the light only decides what is lit and what falls in shadow, so there is no fill,
	# no sky and no fog -- and glow is left to the signals, the only things bright enough.
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("11141c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("6b7390")
	environment.ambient_light_energy = 1.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.glow_enabled = true
	environment.glow_intensity = 0.35
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 1.05
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.environment = environment
	add_child(env)

	# From the camera's left and fairly low: the faces the player sees are lit, and the long
	# hard shadows fall away up the board, where they read as shapes on the ground. (The first
	# frame lit from behind, and every machine showed the camera its shadow band.)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -38, 0)
	key.light_energy = 1.0
	key.light_color = Color("fff0da")
	key.shadow_enabled = true
	key.shadow_blur = 0.0
	key.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key.directional_shadow_max_distance = 32.0
	key.shadow_bias = 0.03
	key.shadow_normal_bias = 1.2
	add_child(key)

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
	var aim := Vector3(0.0, 0.0, AIM_NEAR - _boss_shift)
	_camera.position = aim + Vector3(0.0, sin(pitch) * _zoom, cos(pitch) * _zoom)
	_camera.look_at_from_position(_camera.position, aim, Vector3.UP)


func _frame_camera() -> void:
	# Fit the board's larger side into the view, then leave the rest to the zoom control.
	var span: float = maxf(_origin.x, _origin.y) * 2.0 + HEX * 2.0
	_zoom = clampf(span * 1.5, ZOOM_MIN, ZOOM_MAX)
	# 038: a boss's bar sits across the top, so a boss fight is framed a little further out and
	# lower -- the far row (where the boss stands) clears the bar.
	_boss_shift = 0.0
	if _setup != null:
		for u: GridUnit in _setup.units:
			if u.team == GridUnit.TEAM_ENEMY and BIG_KINDS.has(u.kind):
				_boss_shift = HEX * 0.8
				_zoom = clampf(_zoom * 1.1, ZOOM_MIN, ZOOM_MAX * 1.1)
				break
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
			Ink.line(slab, Ink.LINE_WORLD)
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
	# Ink (015): a heavy dark frame -- the board ends in a line, drawn.
	var curb: Material = Ink.toon(Color("1d1b1a"), "clean")
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
				Ink.line(segment, Ink.LINE_WORLD)
				_board.add_child(segment)


## Each terrain type's field (015): a flat colour, and ink drawn on it where the ground DOES
## something -- rubble is stippled (rough, costs 2), slag hatched (it burns). Alternate open
## hexes step a shade, so a count across the board is easy.
func _tile_material(def: Dictionary, alternate: bool) -> Material:
	var id: String = String(def.get("id", "open"))
	var field: Color = INK_TERRAIN.get(id, Ink.BOARD)
	if alternate and field == Ink.BOARD:
		field = Ink.BOARD_ALT
	match id:
		"rubble":
			return Ink.patterned(field, 1, field.lerp(Ink.PAPER, 0.5), 9.0, 0.55)
		"slag":
			return Ink.patterned(field, 2, Color("6b2a14"), 6.0, 0.22)
	return Ink.toon(field)


## What stands on a tile beyond its surface: rubble has chunks you could hide behind, slag a
## glowing pool you should not stand in, a ridge a lit lip that says "higher".
func _dress_tile(id: String, x: int, y: int, top: float) -> void:
	var at: Vector3 = _to_world(x, y) + Vector3(0, top, 0)
	var h: int = IntentAI.mix(x, y, 23, 5)
	match id:
		"rubble":
			# A few outlined stones, not a photograph of gravel: rough ground you can read.
			var stone: Material = Ink.toon(Color("7a6c59"))
			for i: int in 4:
				var chunk := MeshInstance3D.new()
				var box := BoxMesh.new()
				var s: float = 0.09 + float((h >> (i * 3)) & 7) * 0.016
				box.size = Vector3(s * 1.5, s * 0.8, s * 1.1)
				chunk.mesh = box
				var angle: float = float(i) / 4.0 * TAU + float(h & 15) * 0.1
				var reach: float = HEX * (0.22 + float((h >> (i * 2)) & 3) * 0.1)
				chunk.position = at + Vector3(cos(angle) * reach, box.size.y * 0.4, sin(angle) * reach)
				chunk.rotation = Vector3(float((h >> i) & 3) * 0.2, angle, float((h >> (i + 1)) & 3) * 0.2)
				chunk.material_override = stone
				Ink.line(chunk, Ink.LINE_WORLD)
				_board.add_child(chunk)
		"slag":
			# Molten, and a signal: the one ground that glows.
			var pool := MeshInstance3D.new()
			pool.mesh = _hex_mesh(HEX * 0.52, 0.02)
			pool.position = at + Vector3(0, 0.012, 0)
			pool.material_override = Ink.glow(Color("ff6a2a"), 1.1)
			Ink.line(pool, Ink.LINE_WORLD)
			_board.add_child(pool)
		"wire":
			# LIVE WIRES (028): a downed cable across the hex, hazard-striped, sparking.
			var cable: Material = Ink.toon(Color("1d1c1a"), "clean")
			var stripe: Material = Ink.glow(Color("ffc43d"), 0.6)
			for k: int in 3:
				var seg := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3(HEX * 0.5, 0.05, 0.06)
				seg.mesh = box
				var angle: float = float(h % 7) * 0.4 + float(k) * 0.9
				seg.position = at + Vector3(cos(angle) * 0.12, 0.04, sin(angle) * 0.12)
				seg.rotation.y = angle
				seg.material_override = cable if k != 1 else stripe
				Ink.line(seg, Ink.LINE_WORLD)
				_board.add_child(seg)
		"flue":
			# A furnace flue (025): an ember glow under an iron grate. The glow is the flue's own
			# signal; the red hatching the round before it blows is drawn by `_refresh`.
			var ember := MeshInstance3D.new()
			ember.mesh = _hex_mesh(HEX * 0.6, 0.02)
			ember.position = at + Vector3(0, 0.01, 0)
			ember.material_override = Ink.glow(Color("ff5a1f"), 0.7)
			_board.add_child(ember)
			var iron: Material = Ink.toon(Color("2b2725"), "clean")
			for i: int in 4:
				var bar := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3(HEX * 1.05, 0.05, 0.07)
				bar.mesh = box
				bar.position = at + Vector3(0, 0.05, (float(i) - 1.5) * HEX * 0.24)
				bar.material_override = iron
				Ink.line(bar, Ink.LINE_WORLD)
				_board.add_child(bar)
		"ridge":
			var lip := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = HEX * 0.86
			torus.outer_radius = HEX * 0.95
			torus.ring_segments = 6
			torus.rings = 4
			lip.mesh = torus
			lip.scale = Vector3(1, 0.18, 1)
			lip.position = at
			lip.material_override = Ink.toon(Color("7f838c"))
			Ink.line(lip, Ink.LINE_WORLD)
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
	# The yard beyond the board: night ground with a faint drawn grain.
	ground.material_override = Ink.patterned(Color("1b1e27"), 2, Color("171a22"), 2.5, 0.18)
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
		Ink.dress_scenery(prop, 0.55)
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
		Ink.dress_scenery(lamp, 0.45)
		_board.add_child(lamp)


## A pit (015): pure black, with a torn pale rim -- a hole in the drawing, so "you can be
## shoved in here" is the one thing it can mean.
func _pit(x: int, y: int) -> Node3D:
	var root := Node3D.new()
	root.position = _to_world(x, y)
	var hole := MeshInstance3D.new()
	hole.mesh = _hex_mesh(HEX * 0.92, 1.2)
	hole.position = Vector3(0, -0.75, 0)
	hole.material_override = Ink.flat(Color("000000"))
	root.add_child(hole)
	var rim := MeshInstance3D.new()
	rim.mesh = _jagged_rim(HEX * 0.93, HEX * 0.80, HEX * 0.68, 18, IntentAI.mix(x, y, 13, 3))
	rim.position = Vector3(0, 0.02, 0)
	rim.material_override = Ink.flat(Ink.PAPER.darkened(0.12))
	root.add_child(rim)
	return root


## A flat ring: a pointy-top hex outside, a jagged torn edge inside (`points` teeth between
## `inner_far` and `inner_near`, jittered from `seed`).
func _jagged_rim(outer: float, inner_far: float, inner_near: float, points: int, seed: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var inner: Array[Vector3] = []
	for i: int in points:
		var angle: float = TAU * float(i) / float(points)
		var jitter: float = float((seed >> (i % 24)) & 3) * 0.015
		var r: float = (inner_far if i % 2 == 0 else inner_near) - jitter
		inner.append(Vector3(sin(angle) * r, 0.0, cos(angle) * r))
	for i: int in points:
		var a0: float = TAU * float(i) / float(points)
		var a1: float = TAU * float(i + 1) / float(points)
		var o0: Vector3 = _hex_edge_point(a0, outer)
		var o1: Vector3 = _hex_edge_point(a1, outer)
		var i0: Vector3 = inner[i]
		var i1: Vector3 = inner[(i + 1) % points]
		for v: Vector3 in [o0, i1, i0, o0, o1, i1]:
			st.add_vertex(v)
	return st.commit()


## Where a ray at `angle` (0 = +Z) leaves a pointy-top hex of circumradius `r`.
func _hex_edge_point(angle: float, r: float) -> Vector3:
	var dir := Vector3(sin(angle), 0.0, cos(angle))
	var apothem: float = r * 0.8660254
	var best: float = 1000.0
	for k: int in 6:
		var n_angle: float = TAU * float(k) / 6.0 + PI / 6.0
		var n := Vector3(sin(n_angle), 0.0, cos(n_angle))
		var d: float = dir.dot(n)
		if d > 0.0001:
			best = minf(best, apothem / d)
	return dir * best


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
	# Three broken slabs stacked into a mass that fills its hex: big, then smaller, tilting.
	for i: int in 3:
		var piece := MeshInstance3D.new()
		var box := BoxMesh.new()
		var s: float = [0.98, 0.74, 0.5][i] + float((h >> (i * 5)) & 3) * 0.03
		box.size = Vector3(HEX * s * 1.25, 0.26 + float((h >> (i * 3)) & 3) * 0.07, HEX * s * 1.0)
		piece.mesh = box
		piece.position = Vector3(float(((h >> (i * 7)) & 7) - 3) * 0.03, box.size.y * 0.5 + i * 0.24, float(((h >> (i * 4)) & 7) - 3) * 0.03)
		piece.rotation.y = float((h >> (i * 6)) & 15) * 0.2
		# Ink (015): a solid black mass edged in paper -- a wall, not ground, at any size.
		piece.rotation.x = float(((h >> (i * 2)) & 3) - 1) * 0.12
		piece.rotation.z = float(((h >> (i * 3 + 1)) & 3) - 1) * 0.12
		piece.material_override = Ink.toon(Color("1b1816"), "clean")
		Ink.line(piece, Ink.LINE_WORLD, Ink.PAPER.darkened(0.3))
		heap.add_child(piece)
	return heap


func _quad(x: int, y: int, height: float, size: float) -> MeshInstance3D:
	var quad := MeshInstance3D.new()
	quad.mesh = _hex_mesh(size, 0.012)
	quad.position = _to_world(x, y) + Vector3(0, height, 0)
	quad.material_override = Ink.mark_material(size)
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


## A prop (015, in ink): a fuel drum -- red, a hazard band of chevrons and a flame glyph, so
## it reads as "this explodes" in grey as well as in colour -- a gate pylon, or a crate wall.
## Props are things you act on, so they carry the thickest line.
func _spawn_prop(cell: Vector2i, kind: String) -> void:
	if _prop_views.has(cell):
		return
	var root := Node3D.new()
	root.position = _to_world(cell.x, cell.y)
	if kind == "barrel":
		var skin: Material = Ink.textured(_drum_texture())
		for i: int in 2:
			var drum := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.21
			cyl.bottom_radius = 0.21
			cyl.height = 0.58
			cyl.radial_segments = 16
			drum.mesh = cyl
			drum.position = Vector3(-0.15 + i * 0.31, 0.29, -0.06 + i * 0.13)
			# The flame glyph (texture u = 0.25) toward the camera, one drum a little turned.
			drum.rotation.y = -PI * 0.5 + (0.0 if i == 0 else 0.6)
			drum.material_override = skin
			Ink.line(drum, Ink.LINE_ACT)
			root.add_child(drum)
	elif kind == "pylon":
		# A gate pylon (013): a black column banded in the danger red. Its beam to the Sorter is
		# drawn with the intents (`_pylon_beams`).
		var column := MeshInstance3D.new()
		var shaft := CylinderMesh.new()
		shaft.top_radius = 0.22
		shaft.bottom_radius = 0.3
		shaft.height = 1.5
		shaft.radial_segments = 6
		column.mesh = shaft
		column.position.y = 0.75
		column.material_override = Ink.toon(Color("1d1b1f"), "clean")
		Ink.line(column, Ink.LINE_ACT)
		root.add_child(column)
		for i: int in 3:
			var band := MeshInstance3D.new()
			var ring := CylinderMesh.new()
			ring.top_radius = 0.26 - 0.02 * i
			ring.bottom_radius = ring.top_radius
			ring.height = 0.07
			ring.radial_segments = 6
			band.mesh = ring
			band.position.y = 0.45 + 0.4 * i
			band.material_override = Ink.glow(COL_PAD_DANGER, 1.4)
			root.add_child(band)
	else:
		# A crate wall: steel boxes, strapped, outlined.
		var steel: Material = Ink.toon(Ink.STEEL)
		var strap: Material = Ink.toon(Color("2c2a2b"), "clean")
		for s: Array in [[Vector3(0.7, 0.5, 0.5), Vector3(0, 0.25, 0)], [Vector3(0.5, 0.4, 0.45), Vector3(0.05, 0.7, 0)]]:
			var crate := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = s[0]
			crate.mesh = box
			crate.position = s[1]
			crate.material_override = steel
			Ink.line(crate, Ink.LINE_ACT)
			root.add_child(crate)
			var band := MeshInstance3D.new()
			var band_box := BoxMesh.new()
			band_box.size = (s[0] as Vector3) * Vector3(1.03, 0.16, 1.03)
			band.mesh = band_box
			band.position = s[1]
			band.material_override = strap
			root.add_child(band)
	_units_root.add_child(root)
	_prop_views[cell] = root


## A drum's painted skin: red, an ink hoop top and bottom, a band of hazard chevrons, and a
## flame glyph above it on two sides. CylinderMesh maps its side to the top half of the
## texture (u around, v down) and its caps to the bottom half.
func _drum_texture() -> Texture2D:
	return Ink.texture("drum", Vector2i(256, 256), func(image: Image) -> void:
		var red := Color("c7372c")
		var ink := Ink.INK
		image.fill(Color("8e2a22"))
		for y: int in 128:
			for x: int in 256:
				var v: float = float(y) / 128.0
				var c: Color = red
				if v < 0.07 or v > 0.93 or absf(v - 0.30) < 0.018:
					c = ink
				elif v > 0.56 and v < 0.78:
					# Chevrons: ink wedges on the hazard band.
					var u: float = fmod(float(x) / 256.0 * 8.0, 1.0)
					var w: float = (v - 0.56) / 0.22
					c = ink if absf(u - 0.5) * 2.0 > 1.0 - w * 0.9 and absf(u - 0.5) * 2.0 < 1.35 - w * 0.9 else Ink.ACTION
				image.set_pixel(x, y, c)
		# The flame glyph, twice around: a paper teardrop in an ink ring.
		for centre: float in [64.0, 192.0]:
			for y: int in range(34, 68):
				for x: int in range(int(centre) - 16, int(centre) + 17):
					var dx: float = float(x) - centre
					var dy: float = float(y) - 51.0
					var r: float = sqrt(dx * dx + dy * dy)
					if r < 16.0 and r > 13.0:
						image.set_pixel(x, y, ink)
					# A flame: wide at the bottom, a point at the top.
					var half: float = 7.5 * clampf((float(y) - 38.0) / 18.0, 0.0, 1.0) * clampf((64.0 - float(y)) / 6.0, 0.0, 1.0)
					if absf(dx) < half:
						image.set_pixel(x, y, Ink.PAPER))


func _build_view(u: GridUnit) -> Dictionary:
	var root := Node3D.new()
	root.position = _to_world(u.x, u.y) + Vector3(0, _tile_top(u.x, u.y), 0)
	# Player machines face the far edge, enemies the near one.
	root.rotation.y = PI if u.team == GridUnit.TEAM_PLAYER else 0.0
	_units_root.add_child(root)

	var colour: Color = COL_PLAYER if u.team == GridUnit.TEAM_PLAYER else COL_ENEMY
	var model: Node3D = _cache_model() if u.objective else ConstructView.build_parts(u.part_ids, _db, colour, u.level)
	if not u.objective:
		# 038: a boss in crimson, a warlord in gunmetal -- one livery, not a patchwork of parts.
		var paint: Color = Color("6e1a14") if BOSS_KINDS.has(u.kind) else (Color("3b3936") if BIG_KINDS.has(u.kind) else Color(0, 0, 0, 0))
		Ink.dress_machine(model, u.part_ids, colour, paint)
	# The gate's keeper is bigger than anything else on the board (013).
	model.scale = Vector3.ONE * (1.0 if u.objective else MODEL_SCALE * (1.75 if BOSS_KINDS.has(u.kind) else (1.4 if BIG_KINDS.has(u.kind) else 1.0)))
	root.add_child(model)
	var ring: MeshInstance3D = _team_ring(COL_CACHE if u.objective else colour)
	root.add_child(ring)

	var rig := ConstructRig.new()
	rig.bind(model)

	# Lettered in the comic face, paper on a heavy ink outline: a caption, not a HUD readout.
	var tag := Label3D.new()
	tag.font = UIKit.font_comic()
	tag.font_size = 44
	tag.pixel_size = 0.0045
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.position = Vector3(0, 2.8 if BOSS_KINDS.has(u.kind) else (2.35 if BIG_KINDS.has(u.kind) else 1.75), 0)
	tag.outline_size = 18
	tag.outline_modulate = Ink.INK
	tag.modulate = Ink.PAPER
	# Above everything on the board (play-test 8: the hatching of enemy fire hid HP).
	tag.render_priority = 10
	tag.outline_render_priority = 9
	tag.set_meta("base_pos", tag.position)
	root.add_child(tag)

	# Play-test 4: not every enemy drops scrap. Play-test 8: a mark beside the tag kept drifting
	# with the labels, so a carrier now carries it -- a green scrap bundle on the ground at the
	# edge of its own ring, moving with it and never among the labels.
	if u.team == GridUnit.TEAM_ENEMY and u.carries_scrap and not u.objective:
		root.add_child(_scrap_bundle())

	var view: Dictionary = {"root": root, "model": model, "rig": rig, "ring": ring, "tag": tag, "dead": false}
	view["extras"] = root.get_children().filter(func(n: Node) -> bool: return n.has_meta("label_of"))
	_set_tag(view, u)
	for w: int in u.weapons.size():
		if not u.can_fire(w):
			_hide_arm(view, w)
	return view


## What a scrap carrier wears (play-test 8): a little heap of green bolts on the ground at its
## ring's edge -- the colour of a gain, in the scrap piles' own shapes, so "this one drops a
## pile" reads as the pile it will become.
func _scrap_bundle() -> Node3D:
	var bundle := Node3D.new()
	bundle.position = Vector3(-0.42, 0.0, 0.34)
	var bolt: Material = Ink.toon(Ink.GAIN, "clean")
	for i: int in 3:
		var bit := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.13, 0.08, 0.1) * (1.0 - 0.18 * float(i))
		bit.mesh = box
		bit.position = Vector3(float(i % 2) * 0.09 - 0.04, 0.04 + float(i) * 0.06, float(i) * 0.03)
		bit.rotation = Vector3(0.2 * float(i), 0.7 * float(i), 0.1)
		bit.material_override = bolt
		Ink.line(bit, Ink.LINE_WORLD)
		bundle.add_child(bit)
	return bundle


## A salvage cache (defend objective): a stack of strapped crates. Not a machine
## silhouette on purpose -- it must read as cargo to protect, not as a fighter.
func _cache_model() -> Node3D:
	var root := Node3D.new()
	var wood: Material = Ink.toon(Color("9a7a4a"))
	var strap: Material = Ink.toon(Color("2a2926"), "clean")
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
		Ink.line(crate, Ink.LINE_ACT)
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


## A scrap pile: what a destroyed machine becomes. Walkable, worth scrap and a patch-up to
## whoever walks over it -- so it is drawn as a GAIN (015): bright green bolts, outlined, with
## a paper glint over them. The one green thing on the board.
func _spawn_pile(cell: Vector2i) -> void:
	if _pile_views.has(cell):
		return
	var pile := Node3D.new()
	pile.position = _to_world(cell.x, cell.y) + Vector3(0, _tile_top(cell.x, cell.y), 0)
	var h: int = IntentAI.mix(cell.x, cell.y, 55, 3)
	var bolt: Material = Ink.toon(Ink.GAIN, "clean")
	for i: int in 5:
		var bit := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.13 + float((h >> i) & 3) * 0.04, 0.07 + float((h >> (i + 2)) & 3) * 0.03, 0.11 + float((h >> (i + 4)) & 3) * 0.03)
		bit.mesh = box
		var angle: float = float(i) / 5.0 * TAU + float(h & 7) * 0.2
		bit.position = Vector3(cos(angle) * 0.19, box.size.y * 0.5 + float(i % 2) * 0.05, sin(angle) * 0.19)
		bit.rotation = Vector3(float((h >> i) & 3) * 0.3, angle, 0.0)
		bit.material_override = bolt
		Ink.line(bit, Ink.LINE_WORLD)
		pile.add_child(bit)
	var glint := Sprite3D.new()
	glint.texture = _glint_texture()
	glint.pixel_size = 0.0055
	glint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	glint.shaded = false
	glint.position = Vector3(0.18, 0.5, 0.0)
	pile.add_child(glint)
	_units_root.add_child(pile)
	_pile_views[cell] = pile
	var tween := create_tween()
	pile.scale = Vector3.ONE * 0.2
	tween.tween_property(pile, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A four-point paper star with an ink edge: the glint a comic puts on something worth taking.
func _glint_texture() -> Texture2D:
	return Ink.texture("glint", Vector2i(64, 64), func(image: Image) -> void:
		image.fill(Color(0, 0, 0, 0))
		for y: int in 64:
			for x: int in 64:
				var dx: float = absf(float(x) - 31.5)
				var dy: float = absf(float(y) - 31.5)
				# A concave four-point star: |x|^0.5 + |y|^0.5 < r^0.5.
				var s: float = sqrt(dx / 30.0) + sqrt(dy / 30.0)
				if s < 0.78:
					image.set_pixel(x, y, Ink.PAPER)
				elif s < 0.98:
					image.set_pixel(x, y, Ink.INK))


func _remove_pile(cell: Vector2i) -> void:
	var pile: Node3D = _pile_views.get(cell)
	if pile == null:
		return
	_pile_views.erase(cell)
	var tween := create_tween()
	tween.tween_property(pile, "scale", Vector3.ONE * 0.05, 0.14)
	tween.tween_callback(pile.queue_free)


## The ground ring is half of the team read: lit eyes are the other half. See CLAUDE.md.
## In ink (015): a flat signal ellipse with an ink edge -- drawn, not lit.
## The ENEMY's ring is toothed -- a saw blade -- so whose a machine is survives grey and
## colour-blindness as a shape, not only as a hue.
func _team_ring(colour: Color) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	if colour == COL_ENEMY:
		ring.mesh = _saw_ring(0.43, 0.51, 0.60, 14)
		ring.material_override = Ink.flat(colour)
		ring.position = Vector3(0, 0.035, 0)
		Ink.line(ring, Ink.LINE_WORLD)
		return ring
	var torus := TorusMesh.new()
	torus.inner_radius = 0.43
	torus.outer_radius = 0.52
	torus.rings = 32
	torus.ring_segments = 4
	ring.mesh = torus
	# Flat, no bloom: the ring is read by its hue and its ink edge, and a glowing ring lit the
	# ground around every machine brighter than the machine (measure_contrast.gd).
	ring.material_override = Ink.flat(colour)
	ring.position = Vector3(0, 0.03, 0)
	ring.scale = Vector3(1, 0.25, 1)
	Ink.line(ring, Ink.LINE_WORLD)
	return ring


## A flat ring with `teeth` saw teeth standing out from `outer` to `tip`, with a little
## thickness so the ink line has an edge to follow.
func _saw_ring(inner: float, outer: float, tip: float, teeth: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps: int = teeth * 4
	var top: float = 0.02
	for i: int in steps:
		var a0: float = TAU * float(i) / float(steps)
		var a1: float = TAU * float(i + 1) / float(steps)
		# Each tooth: up the leading edge to the tip, back down along the ring (a saw).
		var r0: float = tip if i % 4 == 1 else outer
		var r1: float = tip if (i + 1) % 4 == 1 else outer
		var in0 := Vector3(sin(a0) * inner, top, cos(a0) * inner)
		var in1 := Vector3(sin(a1) * inner, top, cos(a1) * inner)
		var out0 := Vector3(sin(a0) * r0, top, cos(a0) * r0)
		var out1 := Vector3(sin(a1) * r1, top, cos(a1) * r1)
		st.set_normal(Vector3.UP)
		for v: Vector3 in [in0, out1, out0, in0, in1, out1]:
			st.add_vertex(v)
		# The outer wall, so the ring has a side for the line to trace.
		var dn := Vector3(0, -top, 0)
		st.set_normal(Vector3(sin((a0 + a1) * 0.5), 0, cos((a0 + a1) * 0.5)))
		for v: Vector3 in [out0, out1, out1 + dn, out0, out1 + dn, out0 + dn]:
			st.add_vertex(v)
	return st.commit()


## A flat disc facing the camera (a badge's back): `fill` inside a `rim` ring -- two tinted
## sprites of one white disc, the rim drawn first and a little larger.
func _disc(at: Vector3, radius: float, fill: Color, rim: Color, priority: int = 0, lift: Vector2 = Vector2.ZERO, burst: bool = false) -> Node3D:
	var root := Node3D.new()
	root.position = at
	# 036, comic style: a number that HITS sits in a starburst, the comic's shape for impact.
	var texture: Texture2D = Ink.texture("burst", Vector2i(96, 96), func(image: Image) -> void:
		image.fill(Color(0, 0, 0, 0))
		for y: int in 96:
			for x: int in 96:
				var v := Vector2(float(x) - 47.5, float(y) - 47.5)
				var t: float = absf(fposmod(v.angle() / TAU * 12.0 + 0.25, 1.0) * 2.0 - 1.0)
				var edge: float = 46.5 * (0.72 + 0.28 * t)
				image.set_pixel(x, y, Color(1, 1, 1, clampf(edge - v.length(), 0.0, 1.0)))) if burst \
		else Ink.texture("disc", Vector2i(96, 96), func(image: Image) -> void:
		image.fill(Color(0, 0, 0, 0))
		for y: int in 96:
			for x: int in 96:
				var r: float = Vector2(float(x) - 47.5, float(y) - 47.5).length()
				image.set_pixel(x, y, Color(1, 1, 1, clampf(46.5 - r, 0.0, 1.0))))
	for layer: Array in [[rim, 1.0, priority], [fill, 0.8, priority + 1]]:
		var sprite := Sprite3D.new()
		sprite.texture = texture
		sprite.pixel_size = radius * 2.0 / 93.0 * float(layer[1])
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.no_depth_test = true
		sprite.shaded = false
		sprite.modulate = layer[0]
		sprite.render_priority = int(layer[2])
		sprite.offset = lift / sprite.pixel_size
		root.add_child(sprite)
	return root


## HP, then the state a player must read before moving: heat, a mark, a seize.
func _set_tag(view: Dictionary, u: GridUnit) -> void:
	var lines: PackedStringArray = ["%d/%d" % [u.hp, u.max_hp]]
	var status: PackedStringArray = []
	# Play-test 10: your machines carry their names on the board, as an enemy carries its kind.
	if u.team == GridUnit.TEAM_PLAYER and not u.objective and not u.name.is_empty():
		status.append(u.name.to_upper())
	if not u.kind.is_empty():
		# 038: a boss or warlord is named ("THE CORE"), not its kind's id ("HEART").
		status.append(String((_state.setup.kinds.get(u.kind, {}) as Dictionary).get("name", u.kind)).to_upper() if BIG_KINDS.has(u.kind) and _state != null else u.kind.to_upper())
	if u.unshovable and not u.objective:
		status.append("ANCHORED")
	if u.shield > 0:
		status.append("SHIELD")
	if u.kind == "sorter" and _state != null and CombatSim.has_pylon(_state):
		status.append("PYLONS -3")
	if u.team == GridUnit.TEAM_PLAYER and not u.objective and u.heat > 0:
		status.append("HEAT %d/%d" % [u.heat, u.heat_cap])
	if _state != null and _state.enraged.has(u.ref):
		status.append("ENRAGED")
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
	_declutter()
	_follow_selection()
	_point_info()


## 039: the info balloon's tail points at its subject: the hex aimed at, else the enemy tapped,
## else the machine selected.
func _point_info() -> void:
	if _hud == null or _camera == null or _state == null:
		return
	var at: Variant = null
	if not _pending.is_empty():
		var cell: Vector2i = _pending["cell"]
		at = _to_world(cell.x, cell.y) + Vector3(0, 0.4, 0)
	else:
		for ref: int in [_focus_enemy, _selected]:
			if ref >= 0 and _views.has(ref) and not bool((_views[ref] as Dictionary).get("dead", false)):
				at = ((_views[ref] as Dictionary)["root"] as Node3D).global_position + Vector3(0, 1.0, 0)
				break
	if at == null or _camera.is_position_behind(at):
		_hud.point_info_at(null)
		return
	_hud.point_info_at(_camera.unproject_position(at))


## Play-test 7: "make it easier to see which robot I am controlling". The machine under your
## hand stands in a wide amber ring (amber is the player's action) with an amber chevron bobbing
## over its tag. Both follow it as it walks and sit above wherever its labels were laid out.
func _follow_selection() -> void:
	var view: Dictionary = _views.get(_selected, {})
	if view.is_empty() or bool(view.get("dead", false)) or _state == null or _state.outcome != CombatState.ONGOING:
		if _sel_marker != null:
			_sel_marker.visible = false
		return
	if _sel_marker == null:
		_sel_marker = _build_selection_marker()
	var root: Node3D = view["root"]
	_sel_marker.visible = true
	_sel_marker.position = root.position
	var tag: Label3D = view["tag"]
	var lines: int = tag.text.count("\n") + 1
	(_sel_marker.get_node("chevron") as Node3D).position.y = tag.position.y + 0.7 + float(lines - 1) * 0.12


func _build_selection_marker() -> Node3D:
	var marker := Node3D.new()
	add_child(marker)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.6
	torus.outer_radius = 0.74
	torus.rings = 32
	torus.ring_segments = 4
	ring.mesh = torus
	ring.scale = Vector3(1, 0.3, 1)
	ring.position.y = 0.05
	ring.material_override = Ink.glow(Ink.ACTION, 0.6)
	Ink.line(ring, Ink.LINE_ACT)
	marker.add_child(ring)
	var pulse := ring.create_tween().set_loops()
	pulse.tween_property(ring, "scale", Vector3(1.1, 0.3, 1.1), 0.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(ring, "scale", Vector3(1.0, 0.3, 1.0), 0.5).set_trans(Tween.TRANS_SINE)
	var holder := Node3D.new()
	holder.name = "chevron"
	marker.add_child(holder)
	# A drawn arrow, not a cone: from the board camera's pitch a cone reads as a diamond.
	var arrow := Sprite3D.new()
	arrow.texture = Ink.texture("select_arrow", Vector2i(96, 96), func(image: Image) -> void:
		image.fill(Color(0, 0, 0, 0))
		for y: int in 96:
			for x: int in 96:
				# A downward triangle, amber in an ink edge.
				var half: float = (86.0 - float(y)) * 0.52
				var dx: float = absf(float(x) - 47.5)
				if y < 8 or y > 86 or dx > half:
					continue
				image.set_pixel(x, y, Ink.INK if (dx > half - 7.0 or y < 15) else Ink.ACTION))
	arrow.pixel_size = 0.005
	arrow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	arrow.no_depth_test = true
	arrow.shaded = false
	arrow.render_priority = 5
	holder.add_child(arrow)
	var bob := arrow.create_tween().set_loops()
	bob.tween_property(arrow, "position:y", 0.14, 0.4).set_trans(Tween.TRANS_SINE)
	bob.tween_property(arrow, "position:y", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	return marker


## Board labels never overlap (016; play-test 6 caught "TRACKER" under an order badge and a
## tag under a scrap mark). Each machine's labels -- its tag, its scrap mark, the badge with its
## firing order -- are one group; the badges naming what will be hit sit fixed on the ground.
## Every frame, each group is measured in SCREEN space and the groups are taken top to bottom:
## one that would overlap anything already placed is pushed down just clear of it. The push is
## in world height, which a billboard keeps vertical on screen, and it is recomputed from the
## labels' home positions every frame, so nothing drifts and a camera turn just re-lays it.
func _declutter() -> void:
	if _camera == null or not _camera.is_inside_tree():
		return
	var placed: Array[Rect2] = []
	for node: Node in _marks_root.get_children():
		if node.has_meta("ground_badge") and node is Node3D and not (node as Node3D).is_queued_for_deletion():
			var rect: Rect2 = _screen_box(node as Node3D)
			if rect.size != Vector2.ZERO:
				placed.append(rect.grow(2.0))
	var badges: Dictionary = {}
	for node: Node in _marks_root.get_children():
		if node.has_meta("badge_of") and not node.is_queued_for_deletion():
			var owner: int = int(node.get_meta("badge_of"))
			if not badges.has(owner):
				badges[owner] = []
			(badges[owner] as Array).append(node)
	var groups: Array = []
	for ref: Variant in _views:
		var view: Dictionary = _views[ref]
		if bool(view["dead"]):
			continue
		var nodes: Array = [view["tag"]]
		nodes.append_array(view.get("extras", []))
		nodes.append_array(badges.get(int(ref), []))
		var box := Rect2()
		var first: bool = true
		var tag_h: float = 0.0
		for node: Variant in nodes:
			var n := node as Node3D
			if n == null or not is_instance_valid(n) or not n.visible:
				continue
			n.position = n.get_meta("base_pos", n.position)
			var r: Rect2 = _screen_box(n)
			if r.size == Vector2.ZERO:
				continue
			if node == view["tag"]:
				tag_h = r.size.y
			box = r if first else box.merge(r)
			first = false
		if not first:
			groups.append({"nodes": nodes, "box": box, "anchor": (view["tag"] as Node3D).global_position, "tag_h": tag_h})
	groups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: float = (a["box"] as Rect2).position.y
		var tb: float = (b["box"] as Rect2).position.y
		return ta < tb or (ta == tb and (a["box"] as Rect2).position.x < (b["box"] as Rect2).position.x))
	for group: Dictionary in groups:
		var box: Rect2 = group["box"]
		# Play-test 7: always pushing DOWN walked a crowded tag onto its own machine's body.
		# Both ways are tried and the shorter one is taken.
		var down_shift: float = _clear_shift(box, placed, 1.0)
		var up_shift: float = _clear_shift(box, placed, -1.0)
		var shift: float = down_shift if absf(down_shift) <= absf(up_shift) else up_shift
		# Play-test 8: never further than the group's own height -- a tag that had to climb
		# further went all the way to the banner. Past that, it stays and may overlap.
		# Play-test 11: the limit is the TAG's height, not the group's -- a group counts the damage
		# badges hanging by its machine, and a tall group let a name climb far above its machine.
		if absf(shift) > maxf(float(group["tag_h"]), 24.0) + 4.0:
			shift = 0.0
		if shift != 0.0:
			# Screen pixels per metre of world height at this group, from the camera itself.
			var anchor: Vector3 = group["anchor"]
			var per_m: float = absf(_camera.unproject_position(anchor - Vector3(0, 1, 0)).y - _camera.unproject_position(anchor).y)
			var down: float = shift / maxf(per_m, 1.0)
			for node: Variant in group["nodes"]:
				var n := node as Node3D
				if n != null and is_instance_valid(n):
					n.position = (n.get_meta("base_pos", n.position) as Vector3) - Vector3(0, down, 0)
		placed.append(Rect2(box.position + Vector2(0, shift), box.size))


## How far (in screen pixels, signed by `sense`: +1 down, -1 up) `box` must move to clear every
## rect in `placed`.
func _clear_shift(box: Rect2, placed: Array[Rect2], sense: float) -> float:
	var shift: float = 0.0
	for pass_index: int in 8:
		var moved: bool = false
		for other: Rect2 in placed:
			var here := Rect2(box.position + Vector2(0, shift), box.size)
			if here.intersects(other):
				shift = (other.end.y - box.position.y + 3.0) if sense > 0.0 else (other.position.y - box.end.y - 3.0)
				moved = true
		if not moved:
			break
	return shift


## A billboard label's box on screen: its own quad's size, centred where it projects.
func _screen_box(node: Node3D) -> Rect2:
	var quad := AABB()
	if node is Label3D:
		quad = (node as Label3D).get_aabb()
	elif node is Sprite3D:
		quad = (node as Sprite3D).get_aabb()
	elif node.get_child_count() > 0 and node.get_child(0) is Sprite3D:
		quad = (node.get_child(0) as Sprite3D).get_aabb()
	if quad.size == Vector3.ZERO or _camera.is_position_behind(node.global_position):
		return Rect2()
	var centre: Vector2 = _camera.unproject_position(node.global_position)
	var distance: float = _camera.global_position.distance_to(node.global_position)
	var per_m: float = get_viewport().get_visible_rect().size.y / (2.0 * distance * tan(deg_to_rad(_camera.fov * 0.5)))
	var size := Vector2(quad.size.x, quad.size.y) * per_m
	var offset := Vector2.ZERO
	if node is Label3D:
		offset = (node as Label3D).offset * (node as Label3D).pixel_size * per_m * Vector2(1, -1)
		if (node as Label3D).horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT:
			offset.x += size.x * 0.5
	elif node is Sprite3D:
		offset = (node as Sprite3D).offset * (node as Sprite3D).pixel_size * per_m * Vector2(1, -1)
	elif node.get_child_count() > 0 and node.get_child(0) is Sprite3D:
		var sprite: Sprite3D = node.get_child(0)
		offset = sprite.offset * sprite.pixel_size * per_m * Vector2(1, -1)
	return Rect2(centre + offset - size * 0.5, size)


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
		# Play-test 7: one shot through three machines, or a drum going up among them, played
		# its hits one after another, a sixth of a second each -- and read as lag. What one cause
		# does now lands together: each is started, and the next follows a beat later.
		var next: int = int(_state.events[_shown][GridEv.F_KIND]) if _shown < _state.events.size() else -1
		if CONCURRENT.has(int(e[GridEv.F_KIND])) and CONCURRENT.has(next):
			_animate(e)
			await _wait(T_TOGETHER)
		else:
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
			_sfx_attacker = actor
			_sfx_weapon = int(e[GridEv.F_V1])
			_sfx_said = false
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
		GridEv.WRECK_THROWN:
			var packed: int = int(e[GridEv.F_V1])
			await _wreck_flight(Vector2i(packed % 64, packed / 64), cell, int(e[GridEv.F_V2]) == 1)
		GridEv.PILE_LOST:
			_remove_pile(cell)
			if _state.piles.has(cell):
				_spawn_pile(cell)
		GridEv.BUMP:
			_letters(_unit_pos(target) + Vector3(0.3, 2.0, 0), "THUD!", UIKit.GOLD, 84, 0.12)
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
			Audio.play("pickup" if actor < 10 else "ui_deny", -8.0)
			await _wait(0.12)
		GridEv.PROP_PLACED:
			_spawn_prop(cell, GridEv.PROP_KINDS[clampi(int(e[GridEv.F_V1]), 0, GridEv.PROP_KINDS.size() - 1)])
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
			# High and big: a wreck's KRANG! often lands on the same drum a beat earlier, and the
			# two effects stack like a panel's, never overprint.
			_letters(at + Vector3(0.25, 2.0, 0), "BOOM!", Ink.ACTION, 130, 0.1)
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
			Audio.play("warn", -12.0)
		GridEv.ARRIVAL_MARKED:
			Audio.play("warn", -8.0)
		GridEv.POUR_MARKED:
			_float_text(_to_world(cell.x, cell.y) + Vector3(0, 1.4, 0), "THE POUR MARKS IT", COL_PAD_DANGER)
			Audio.play("warn", -8.0)
			await _wait(0.12)
		GridEv.FLOODED:
			_flood_marker(cell)
			_float_text(_to_world(cell.x, cell.y) + Vector3(0, 1.2, 0), "FLOODED", COL_PAD_DANGER)
			_vfx.shake(0.2)
			Audio.play("flood", -5.0)
			await _wait(0.15)
		GridEv.FLUE_BLEW:
			var at: Vector3 = _to_world(cell.x, cell.y) + Vector3(0, _tile_top(cell.x, cell.y) + 0.2, 0)
			_vfx.burst(at, Color("ff7a3c"), 1.3)
			_vfx.sparks(at, Color("ffb060"), 12, 1.4)
			Audio.play("thump", -10.0)
			await _wait(0.06)
		GridEv.ENRAGED:
			# 027: a keeper at half HP escalates -- the moment the fight turns.
			var at: Vector3 = _unit_pos(actor) + Vector3(0, 0.6, 0)
			_vfx.burst(at, COL_PAD_DANGER, 4.0)
			_vfx.shake(0.8)
			var u: GridUnit = _state.unit(actor)
			_letters(at + Vector3(0, 2.6, 0), "BOILS OVER!" if u != null and u.kind == "pour" else "ERUPTS!", Ink.DANGER, 120, 0.06)
			_refresh_tag(actor)
			Audio.play("detonate", -2.0)
			await _wait(0.6)
		GridEv.REPAIRED:
			# 033: a repair drone or a kill patches a machine.
			_float_text(_unit_pos(actor) + Vector3(0, 2.3, 0), "+%d HP" % int(e[GridEv.F_V1]), UIKit.GREEN)
			_refresh_tag(actor)
			Audio.play("pickup", -10.0)
			await _wait(0.15)
		GridEv.LAST_STAND:
			# 033: the Phoenix Cell -- the blow that should have wrecked it did not.
			var stand_at: Vector3 = _unit_pos(actor) + Vector3(0, 0.6, 0)
			_vfx.burst(stand_at, Color("ffb060"), 3.0)
			_letters(stand_at + Vector3(0, 2.4, 0), "HOLDS!", Ink.ACTION, 110, 0.06)
			_refresh_tag(actor)
			Audio.play("reward", -4.0)
			await _wait(0.45)
		GridEv.HAULED:
			_float_text(_unit_pos(actor) + Vector3(0, 2.6, 0), "HAUL!", COL_PAD_DANGER)
			_vfx.burst(_unit_pos(actor) + Vector3(0, 0.4, 0), Color("c9a2ff"), 5.0)
			Audio.play("zap", -4.0)
			await _wait(0.25)
		GridEv.HOLD_SCORED:
			_float_text(_to_world(cell.x, cell.y) + Vector3(0, 1.6, 0), "ZONE HELD  %d / %d" % [int(e[GridEv.F_V1]), int(e[GridEv.F_V2])], UIKit.GREEN)
			Audio.play("reward", -8.0)
			await _wait(0.3)
		GridEv.HACKED:
			_float_text(_to_world(cell.x, cell.y) + Vector3(0, 1.6, 0), "TERMINAL TAKEN  %d / %d" % [int(e[GridEv.F_V1]), int(e[GridEv.F_V2])], UIKit.GREEN)
			Audio.play("pickup", -6.0)
			await _wait(0.3)
		GridEv.WAVE_MARKED:
			Audio.play("warn", -8.0)
		GridEv.PULSE_MARKED:
			_float_text(_unit_pos(actor) + Vector3(0, 2.9, 0), "THE CORE CHARGES", COL_PAD_DANGER)
			Audio.play("warn", -6.0)
			await _wait(0.2)
		GridEv.PULSED:
			var at: Vector3 = _unit_pos(actor) + Vector3(0, 0.3, 0)
			_vfx.burst(at, COL_PAD_DANGER, 5.0)
			_vfx.shake(0.6)
			_letters(at + Vector3(0.2, 2.6, 0), "WHUMM!", Ink.ACTION, 120, 0.08)
			Audio.play("detonate", -4.0)
			await _wait(0.25)
		GridEv.SPAWNED:
			var by_reclaimer: bool = int(e[GridEv.F_ACTOR]) < 0
			var words: String = "BUILT BY ITS PAD"
			if int(e[GridEv.F_ACTOR]) == -1:
				words = "THE RECLAIMER ARRIVES"
			elif int(e[GridEv.F_ACTOR]) == -2:
				words = "REINFORCEMENTS"
			elif _state.enraged.has(int(e[GridEv.F_ACTOR])):
				words = "CALLED TO GUARD"
			_float_text(_to_world(cell.x, cell.y) + Vector3(0, 1.8, 0), words, COL_PAD_DANGER if by_reclaimer else Color("c9a2ff"))
			var drone: GridUnit = _state.unit(target)
			if drone != null and not _views.has(target):
				_views[target] = _build_view(drone)
				var root: Node3D = (_views[target] as Dictionary)["root"]
				root.position = _to_world(cell.x, cell.y)
				root.scale = Vector3.ONE * 0.1
				var grow := create_tween()
				grow.tween_property(root, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
				Audio.play("spawn", -7.0)
				await _wait(0.2)
		GridEv.SPAWN_BLOCKED:
			var shut: bool = int(e[GridEv.F_V1]) == 1
			_float_text(_to_world(cell.x, cell.y) + Vector3(0, 1.0, 0), "PAD SHUT DOWN" if shut else "BUILD BLOCKED", UIKit.GREEN)
		GridEv.SHIELDED:
			_refresh_tag(target)
			Audio.play("shield", -9.0)
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
		tween.tween_callback(func() -> void: Audio.play("step", -14.0, 0.25))
		var destination: Vector3 = _to_world(cell.x, cell.y) + Vector3(0, _tile_top(cell.x, cell.y), 0)
		var heading: Vector3 = destination - from
		if heading.length_squared() > 0.0004:
			var yaw: float = atan2(heading.x, heading.z)
			tween.tween_property(root, "rotation:y", root.rotation.y + wrapf(yaw - root.rotation.y, -PI, PI), 0.04)
		var step_from: Vector3 = from
		var step_to: Vector3 = destination
		tween.tween_callback(func() -> void: _streaks(step_from, step_to))
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
			Audio.play("zap" if int(weapon["chain"]) > 0 else "shot", -7.0)
		"cone":
			# 029: the flamer -- a gout of fire over the wedge it burns.
			_vfx.muzzle_flash(muzzle, _to_world(aim.x, aim.y), Color("ff7a3c"))
			for n: Vector2i in [aim] + Hex.neighbors(aim):
				if _state.inside(n) and (n == aim or Hex.distance(Vector2i(u.x, u.y), n) == 2):
					_vfx.burst(_to_world(n.x, n.y) + Vector3(0, 0.3, 0), Color("ff7a3c"), 1.0)
			Audio.play("flood", -8.0)
		"shield":
			_tracer(muzzle, _to_world(aim.x, aim.y) + Vector3(0, 0.8, 0), Ink.YOURS)
			Audio.play("shield", -8.0)
		"lob":
			var landing: Vector3 = _to_world(aim.x, aim.y) + Vector3(0, 0.4, 0)
			_vfx.muzzle_flash(muzzle, landing, colour.lightened(0.5))
			Audio.play("lob", -8.0)
			await _lob(muzzle, landing, colour)
			_vfx.burst(landing, colour, 1.2)
			Audio.play("thump", -5.0)
		_:
			Audio.play("saw" if String(weapon["class"]) == "saw" or String(weapon["class"]) == "ripper" else "clang", -8.0)
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
	shell.material_override = Ink.hold(material)
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
	_sfx_word(attacker, root.position)
	if severity > 0.45:
		_focus_lines(root.position + Vector3(0, 0.7, 0))
	if attacker >= 0 and _views.has(attacker):
		(view["rig"] as ConstructRig).stagger(_local_push(attacker, victim), severity)
	# Terrain damage is labelled as terrain, so slag reads as a cause and not as a bug.
	var ground: String = "FLUE" if u.x >= 0 and _state.flue(u.x, u.y) > 0 else "SLAG"
	_float_text(root.position + Vector3(0, 1.8, 0), ("-%d" % amount) if attacker >= 0 else ("%s -%d" % [ground, amount]),
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


## A killing shove's wreck (play-test 5): a chunk of the machine flies one hex along the
## shove -- and lands, or slams into whatever stands there.
func _wreck_flight(from: Vector2i, to: Vector2i, landed: bool) -> void:
	var start: Vector3 = _to_world(from.x, from.y) + Vector3(0, _tile_top(from.x, from.y) + 0.4, 0)
	var goal: Vector3 = _to_world(to.x, to.y) + Vector3(0, 0.4, 0)
	if not landed:
		goal = start.lerp(goal, 0.62)
	var chunk := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.42, 0.3, 0.36)
	chunk.mesh = box
	chunk.material_override = Ink.toon(Color("4a4440"), "clean")
	Ink.line(chunk, Ink.LINE_MACHINE)
	chunk.position = start
	_units_root.add_child(chunk)
	var fly := create_tween().set_parallel(true)
	fly.tween_method(func(k: float) -> void:
		chunk.position = start.lerp(goal, k) + Vector3(0, sin(k * PI) * 0.7, 0), 0.0, 1.0, 0.22)
	fly.tween_property(chunk, "rotation", Vector3(2.4, 1.2, 0.6), 0.22)
	await fly.finished
	if not landed:
		_letters(goal + Vector3(-0.3, 0.85, 0), "KRANG!", Ink.ACTION, 84)
		_vfx.sparks(goal, Color("ffb070"), 14, 0.8)
		_vfx.shake(0.3)
		Audio.play("hit_heavy", -6.0)
	var fade := create_tween()
	fade.tween_interval(0.25)
	fade.tween_callback(chunk.queue_free)
	await _wait(0.12)


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
	_punch()
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
	glow.material_override = Ink.hold(haze)
	_marks_root.add_child(glow)
	glow.look_at_from_position((from + to) * 0.5, to, Vector3.UP)
	var haze_fade := create_tween()
	haze_fade.tween_property(haze, "albedo_color:a", 0.0, 0.3)
	haze_fade.tween_callback(glow.queue_free)
	var beam := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.04, 0.04, from.distance_to(to))
	beam.mesh = box
	# Additive and over-bright rather than emissive (play-test 7): the emissive, transparent
	# version recompiled its shader on every shot here -- a 300 ms freeze -- however it was held.
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var hot: Color = colour.lerp(Color.WHITE, 0.5)
	material.albedo_color = Color(hot.r * 2.5, hot.g * 2.5, hot.b * 2.5, 1.0)
	beam.material_override = Ink.hold(material)
	_marks_root.add_child(beam)
	beam.look_at_from_position((from + to) * 0.5, to, Vector3.UP)
	var tween := create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.25)
	tween.tween_callback(beam.queue_free)


func _float_text(at: Vector3, text: String, colour: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = UIKit.font_comic()
	label.font_size = 56
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 18
	label.outline_modulate = Ink.INK
	label.modulate = colour
	label.position = at
	_marks_root.add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position", at + Vector3(0, 0.9, 0), 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)


## A lettered sound effect (015): KRANG, BOOM. Hand lettering, tilted, popped in and held a
## beat -- and only on the impacts that matter, or it stops meaning anything.
func _letters(at: Vector3, text: String, colour: Color, size: int = 110, tilt: float = -0.14) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = UIKit.font_letters()
	label.font_size = size
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 30
	label.outline_modulate = Ink.INK
	label.modulate = colour
	label.position = at
	label.rotation.z = tilt
	label.render_priority = 3
	label.outline_render_priority = 2
	label.scale = Vector3.ONE * 0.3
	_marks_root.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector3.ONE * 1.1, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector3.ONE, 0.06)
	tween.tween_interval(0.45)
	tween.tween_property(label, "modulate:a", 0.0, 0.25)
	tween.tween_callback(label.queue_free)


## 039: a thought cloud over an enemy: a bumpy paper cloud lettered in ink, two puffs trailing
## down to its head. Part of the intent marks (cleared with them).
func _thought(u: GridUnit, text: String) -> void:
	var top: float = 2.8 if BOSS_KINDS.has(u.kind) else (2.35 if BIG_KINDS.has(u.kind) else 1.75)
	var head: Vector3 = _to_world(u.x, u.y) + Vector3(0, top, 0)
	var cloud_at: Vector3 = head + Vector3(0, 0.62, 0)
	var cloud: Texture2D = Ink.texture("cloud", Vector2i(192, 112), func(image: Image) -> void:
		image.fill(Color(0, 0, 0, 0))
		var lobes: Array = [Vector3(52, 60, 34), Vector3(96, 46, 40), Vector3(140, 60, 34), Vector3(76, 72, 30), Vector3(118, 72, 30)]
		for y: int in 112:
			for x: int in 192:
				var inside: float = 0.0
				var rim: float = 0.0
				for lobe: Vector3 in lobes:
					var d: float = Vector2(x - lobe.x, y - lobe.y).length()
					inside = maxf(inside, clampf(lobe.z - 5.0 - d, 0.0, 1.0))
					rim = maxf(rim, clampf(lobe.z - d, 0.0, 1.0))
				if rim > 0.0:
					image.set_pixel(x, y, Color(1, 1, 1, 1).lerp(Color(0.08, 0.07, 0.06, 1), 1.0 - inside) * Color(1, 1, 1, rim)))
	var sprite := Sprite3D.new()
	sprite.texture = cloud
	sprite.pixel_size = 0.0062
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.shaded = false
	sprite.modulate = Ink.PAPER
	sprite.render_priority = 7
	sprite.position = cloud_at
	sprite.set_meta("intent", true)
	_marks_root.add_child(sprite)
	for puff: Array in [[0.32, 0.09], [0.16, 0.06]]:
		var dot: Node3D = _disc(head + Vector3(0, float(puff[0]), 0), float(puff[1]), Ink.PAPER, Ink.INK, 7)
		dot.set_meta("intent", true)
		_marks_root.add_child(dot)
	var label := Label3D.new()
	label.text = text
	label.font = UIKit.font_comic()
	label.font_size = 40
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 0
	label.modulate = Ink.DANGER.darkened(0.2)
	label.render_priority = 8
	label.position = cloud_at
	label.set_meta("intent", true)
	_marks_root.add_child(label)


## 039: the sound a hit makes, lettered by what made it: one word per attack.
const SFX_WORDS: Array[String] = ["KRANG!", "WHOOMPH!", "FZZT!", "HSSS!"]


func _sfx_word(attacker: int, at: Vector3) -> void:
	if _sfx_said or attacker < 0 or attacker != _sfx_attacker:
		return
	_sfx_said = true
	var u: GridUnit = _state.unit(attacker)
	if u == null or _sfx_weapon < 0 or _sfx_weapon >= u.weapons.size():
		return
	var weapon: Dictionary = u.weapons[_sfx_weapon]
	var t: int = int(weapon.get("dtype", -1)) if int(weapon.get("dtype", -1)) >= 0 else u.damage_type
	var word: String = "WHAM!" if String(weapon["shape"]) == "melee" and t == 0 else SFX_WORDS[clampi(t, 0, 3)]
	_letters(at + Vector3(0.35, 1.9, 0), word, DAMAGE_COLOURS[clampi(t, 0, DAMAGE_COLOURS.size() - 1)], 92, -0.18 if attacker % 2 == 0 else 0.16)


## 039: speed lines -- ink streaks left behind a machine that moves or charges, along its path
## as the camera sees it.
func _streaks(from: Vector3, to: Vector3) -> void:
	if _camera == null:
		return
	var a: Vector2 = _camera.unproject_position(from)
	var b: Vector2 = _camera.unproject_position(to)
	if a.distance_to(b) < 2.0:
		return
	var texture: Texture2D = Ink.texture("streaks", Vector2i(160, 64), func(image: Image) -> void:
		image.fill(Color(0, 0, 0, 0))
		for line: Array in [[12, 120, 3], [24, 150, 2], [36, 110, 3], [48, 140, 2]]:
			for x: int in int(line[1]):
				for w: int in int(line[2]):
					image.set_pixel(159 - x, int(line[0]) + w, Color(1, 1, 1, clampf(1.0 - float(x) / float(line[1]), 0.0, 1.0))))
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = 0.006
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.shaded = false
	sprite.modulate = Ink.INK
	sprite.render_priority = 2
	sprite.position = from + Vector3(0, 0.7, 0)
	# Screen y runs down; the sprite's rotation runs counter-clockwise in its own plane.
	sprite.rotation.z = -(b - a).angle()
	_marks_root.add_child(sprite)
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(sprite.queue_free)


## 039: focus lines -- a ring of ink spikes snapping in around a heavy hit.
func _focus_lines(at: Vector3) -> void:
	var texture: Texture2D = Ink.texture("focus", Vector2i(160, 160), func(image: Image) -> void:
		image.fill(Color(0, 0, 0, 0))
		for i: int in 28:
			var ang: float = TAU * float(i) / 28.0 + (0.05 if i % 2 == 0 else -0.04)
			var inner: float = 46.0 + float((i * 37) % 11)
			for r: int in range(int(inner), 79):
				var width: float = 2.6 * (1.0 - (float(r) - inner) / (79.0 - inner)) + 0.6
				for w: int in range(-int(width), int(width) + 1):
					var p := Vector2(80, 80) + Vector2(cos(ang), sin(ang)) * float(r) + Vector2(-sin(ang), cos(ang)) * float(w) * 0.5
					if p.x >= 0 and p.y >= 0 and p.x < 160 and p.y < 160:
						image.set_pixel(int(p.x), int(p.y), Color(1, 1, 1, 1)))
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = 0.016
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.shaded = false
	sprite.modulate = Ink.INK
	sprite.render_priority = 2
	sprite.position = at
	sprite.scale = Vector3.ONE * 0.6
	_marks_root.add_child(sprite)
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector3.ONE, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.12)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.18)
	tween.tween_callback(sprite.queue_free)


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
		if _run_mode:
			body += "\n\n" + _recap_text()
		Audio.play("win" if _state.outcome == CombatState.WON else "lose", -6.0, 0.0)
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
	if _path_root != null:
		for child: Node in _path_root.get_children():
			child.queue_free()
		_path_root.set_meta("route", "")
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
	_volley_badges(threats)

	for ref: Variant in _state.spawn_marks:
		_mark(_threat_quads, _state.spawn_marks[ref], COL_THREAT if CombatSim.drone_in(_state, int(ref)) <= 1 else COL_SPAWN)
		_spawn_marker(int(ref), _state.spawn_marks[ref])
	for cell: Vector2i in _state.arrivals:
		_mark(_threat_quads, cell, COL_THREAT)
		_arrival_marker(cell)
	# The Pour (021): hexes already slag, and the ones that flood next round.
	for cell: Variant in _state.flooded:
		_flood_marker(cell)
	for cell: Vector2i in _state.pour_marks:
		_mark(_threat_quads, cell, COL_THREAT)
		var top: Vector3 = _to_world(cell.x, cell.y) + Vector3(0, _tile_top(cell.x, cell.y), 0)
		_marker_label("FLOODS NEXT TURN · move off", top + Vector3(0, 0.08, HEX * 0.72), COL_PAD_DANGER.lightened(0.35), 24)
	_pylon_beams()
	_conduit_links()
	_objective_marks()
	_warlord_marks()
	# Act 3 (025): flues that blow at the start of next round, and the Core's marked ring.
	if CombatSim.flues_blow(_state, _state.round_number + 1):
		for y: int in _state.height:
			for x: int in _state.width:
				if _state.flue(x, y) > 0:
					_mark(_threat_quads, Vector2i(x, y), COL_THREAT)
	if not _state.pulse_marks.is_empty():
		for cell: Vector2i in _state.pulse_marks:
			_mark(_threat_quads, cell, COL_THREAT)
		var keeper: GridUnit = _state.unit(_state.pulse_by)
		if keeper != null and keeper.alive:
			var top: Vector3 = _to_world(keeper.x, keeper.y) + Vector3(0, _tile_top(keeper.x, keeper.y), 0)
			_marker_label("PULSES NEXT ROUND · get out of the ring", top + Vector3(0, 0.08, HEX * 2.4), Ink.PAPER, 34)

	var sel: GridUnit = _state.unit(_selected) if _selected >= 0 else null
	if sel != null and sel.alive:
		if _armed and _ability >= 0:
			if not _pending.is_empty():
				_mark(_hint_quads, _pending["cell"], COL_TARGET)
				# Play-test 11: an aimed ability shows what it will do on the board, as a shot does.
				var cell_p: Vector2i = _pending["cell"]
				_aim_badges(CombatSim.dry_run(_state, [CombatSim.ACT_ABILITY, sel.ref, int(_pending["i"]), cell_p.x, cell_p.y]))
			else:
				for cell: Vector2i in CombatAbilities.targets(_state, sel, _ability):
					_mark(_hint_quads, cell, COL_ATTACK)
		elif _armed and not sel.acted and not sel.seized and sel.can_fire(_weapon):
			if not _pending.is_empty():
				var plan: Dictionary = CombatSim.strike_plan(_state, sel, _weapon, _pending["cell"])
				_preview_marks(sel, _weapon, _pending["cell"])
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
				var at: Vector2i = cell
				_mark(_hint_quads, at, COL_MOVE_SLOW if _state.move_cost(at.x, at.y) > 1 else COL_MOVE)
	_refresh_hud(threats)
	if _coach != null:
		_coach.refresh()


## The aim preview drawn on the board (015), from the real rules run on a copy: every drum
## the shot sets off marks the hexes its blast reaches, and a killing shove's wreck gets an
## arrow to where it is thrown. The info panel says the same in words.
func _preview_marks(sel: GridUnit, w: int, cell: Vector2i) -> void:
	var preview: Dictionary = CombatSim.preview_attack(_state, sel.ref, w, cell)
	_aim_badges(preview.get("effects", []))
	# Play-test 8: a beam stops at its range + 2, at half damage past its range; say where.
	var weapon: Dictionary = sel.weapons[w]
	if String(weapon["shape"]) == "shot" and int(weapon["pierce"]) > 0 and bool(preview.get("legal", false)):
		var end: Vector2i = preview["end"]
		var top: Vector3 = _to_world(end.x, end.y) + Vector3(0, _tile_top(end.x, end.y), 0)
		_marker_label("BEAM ENDS", top + Vector3(0, 0.1, HEX * 0.7), Ink.ACTION, 28)
	for effect: Dictionary in (preview.get("effects", []) as Array):
		if not effect.has("prop"):
			continue
		var at: Vector2i = effect["prop"]
		if String((_state.props.get(at, {}) as Dictionary).get("kind", "")) != "barrel":
			continue
		for n: Vector2i in [at] + Hex.neighbors(at):
			if _state.inside(n):
				_mark(_threat_quads, n, COL_BLAST)
	if int(sel.weapons[w]["shove"]) <= 0:
		return
	for hit: Dictionary in (preview.get("hits", []) as Array):
		if bool(hit["primary"]) and (preview.get("kills", []) as Array).has(int(hit["ref"])):
			var victim: GridUnit = _state.unit(int(hit["ref"]))
			var from := Vector2i(victim.x, victim.y)
			_throw_arrow(from, Hex.neighbor(from, Hex.direction(Vector2i(sel.x, sel.y), from)))


## Play-test 7: what the aimed attack does, on the board -- an amber total on every machine it
## hurts (the player's action is amber), KO where it kills, at the hex's far edge so it never
## sits on the enemy's own total. From the same dry run as the info panel.
func _aim_badges(effects: Array) -> void:
	for effect: Dictionary in effects:
		if effect.has("prop"):
			# Play-test 11: props show what they take too (a gate pylon, a crate wall).
			if int(effect.get("hp_lost", 0)) > 0:
				var at: Vector2i = effect["prop"]
				_badge("-%d%s" % [int(effect["hp_lost"]), " BREAKS" if bool(effect["broken"]) else ""],
					_to_world(at.x, at.y) + Vector3(0, 0.05, -HEX * 0.6), Ink.ACTION, 0.85)
			continue
		if int(effect.get("hp_lost", 0)) <= 0:
			continue
		var t: GridUnit = _state.unit(int(effect["ref"]))
		if t == null:
			continue
		var word: String = " KO" if bool(effect["killed"]) else ""
		_badge("-%d%s" % [int(effect["hp_lost"]), word], _to_world(t.x, t.y) + Vector3(0, 0.05, -HEX * 0.6), Ink.ACTION, 1.0)


## A flat amber arrow on the ground, inked: this goes there.
func _throw_arrow(from: Vector2i, to: Vector2i) -> void:
	var a: Vector3 = _to_world(from.x, from.y)
	var b: Vector3 = _to_world(to.x, to.y)
	var length: float = a.distance_to(b)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	# Along +Z from 0 to `length`: a shaft, then a head.
	var s0: float = length * 0.18
	var s1: float = length * 0.62
	var w: float = 0.09
	var hw: float = 0.24
	var tip: float = length * 0.86
	for v: Vector3 in [Vector3(-w, 0, s0), Vector3(w, 0, s0), Vector3(w, 0, s1),
			Vector3(-w, 0, s0), Vector3(w, 0, s1), Vector3(-w, 0, s1),
			Vector3(-hw, 0, s1), Vector3(hw, 0, s1), Vector3(0, 0, tip)]:
		st.add_vertex(v)
	var arrow := MeshInstance3D.new()
	arrow.mesh = st.commit()
	arrow.material_override = Ink.glow(Ink.ACTION, 0.0)
	arrow.position = a + Vector3(0, 0.34, 0)
	arrow.rotation.y = atan2(b.x - a.x, b.z - a.z)
	Ink.line(arrow, Ink.LINE_ACT)
	arrow.set_meta("intent", true)
	_marks_root.add_child(arrow)


## 038: the boss bar -- the first living boss or warlord on the board, its HP, and what it is
## doing: shielded, marking, erupted.
func _hud_boss() -> void:
	for u: GridUnit in _state.units:
		if not u.alive or u.team != GridUnit.TEAM_ENEMY or not BIG_KINDS.has(u.kind):
			continue
		var bits: PackedStringArray = []
		var rules: Dictionary = CombatSim.kind_rules(_state, u)
		bits.append(("BOSS" if BOSS_KINDS.has(u.kind) else "WARLORD"))
		if _state.enraged.has(u.ref):
			bits.append("ENRAGED")
		var shield_kind: String = String(rules.get("cover_kind", ""))
		var shields: int = 0
		for other: GridUnit in _state.units:
			if other.alive and not shield_kind.is_empty() and other.kind == shield_kind:
				shields += 1
		if shields > 0:
			bits.append("SHIELDED by %d %s%s: -%d per hit" % [shields, shield_kind.to_upper(), "S" if shields > 1 else "", int(rules.get("cover_armor", 0))])
		if u.kind == "sorter" and CombatSim.has_pylon(_state):
			bits.append("SHIELDED by its pylons: -3 per hit")
		if not _state.enraged.has(u.ref) and (rules.has("enraged") or (_state.setup.kinds.get(u.kind, {}) as Dictionary).has("enraged")):
			bits.append("erupts at half HP")
		_hud.set_boss(String((_state.setup.kinds.get(u.kind, {}) as Dictionary).get("name", u.name)), u.hp, u.max_hp, "  ·  ".join(bits))
		return
	_hud.set_boss("", 0, 0, "")


func _refresh_hud(threats: Dictionary) -> void:
	var cards: Array = []
	for u: GridUnit in _state.units:
		if u.team != GridUnit.TEAM_PLAYER or u.objective:
			continue
		cards.append({
			"ref": u.ref, "name": u.name, "detail": _card_line(u), "arms": _arms_line(u),
			"hp": u.hp, "max_hp": u.max_hp, "alive": u.alive, "heat": u.heat, "heat_cap": u.heat_cap,
			"can_move": not CombatSim.reachable(_state, u.ref).is_empty(),
			"can_act": not u.acted and not u.seized and u.has_weapon(),
			"selected": u.ref == _selected,
			"parts": Array(u.part_ids), "level": u.level,
		})
	_hud.set_crew(cards)
	var status: Dictionary = CombatSim.objective_status(_state)
	_hud.set_objective(String(status["text"]) + _yard_line(), String(status["type"]) == "defend" and int(status["caches"]) < int(status["caches_total"]))
	_hud_boss()
	var ongoing: bool = _state.outcome == CombatState.ONGOING and not _bot
	_hud.set_controls(ongoing and not _busy and _actions.size() > _turn_start, ongoing and not _busy)

	var sel: GridUnit = _state.unit(_selected) if _selected >= 0 else null
	_refresh_weapon_bar(sel)
	if not _pending.is_empty():
		var cell: Vector2i = _pending["cell"]
		if bool(_pending["ability"]):
			var ability: Dictionary = sel.abilities[int(_pending["i"])]
			var act: Array = [CombatSim.ACT_ABILITY, sel.ref, int(_pending["i"]), cell.x, cell.y]
			_hud.set_info(String(ability["name"]).to_upper(), _effects_text(CombatSim.dry_run(_state, act), {}, act)
				+ "\n\nTap the same hex again to confirm.")
		else:
			_hud.set_info("FIRE %s" % String(sel.weapons[int(_pending["i"])]["name"]).to_upper(),
				_preview_text(CombatSim.preview_attack(_state, sel.ref, int(_pending["i"]), cell))
				+ "\n\nTap the same target again to confirm.")
		_hud.set_hint(("Tap the yellow hex again to use %s  ·  tap elsewhere to cancel" % String(sel.abilities[int(_pending["i"])]["name"]).to_upper())
			if bool(_pending["ability"]) else "Tap the yellow target again to fire  ·  tap elsewhere to cancel")
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
		# What it does first, then what it costs (016, play-test 6: the card said only the cost).
		var cost: String = "free" if bool(ability["free"]) else "uses the action"
		var short: String = String(ability.get("short", ""))
		list.append({"name": String(ability["name"]), "detail": "%s%s  ·  cooldown %d" % [
			(short + "  ·  ") if not short.is_empty() else "", cost, int(ability["cooldown"])],
			"available": reason.is_empty(), "reason": reason, "ability": true})
		_bar_items.append(["ability", i])
	var vent: String = ""
	if not sel.acted and sel.heat > 0:
		vent = "Drop heat to 0. Uses this machine's action."
	_hud.set_weapons(list, selected, vent)


func _preview_text(preview: Dictionary) -> String:
	var act: Array = []
	var sel_p: GridUnit = _state.unit(_selected) if _selected >= 0 else null
	if sel_p != null and not _pending.is_empty() and not bool(_pending["ability"]):
		var at_p: Vector2i = _pending["cell"]
		act = [CombatSim.ACT_ATTACK, sel_p.ref, int(_pending["i"]), at_p.x, at_p.y]
	var text: String = _effects_text(preview.get("effects", []), preview, act)
	if preview.has("shield"):
		var guarded: GridUnit = _state.unit(int((preview["shield"] as Dictionary)["ref"]))
		text = "%s takes %d less from every hit until your next turn." % [guarded.name, int((preview["shield"] as Dictionary)["amount"])]
	var sel: GridUnit = _state.unit(_selected) if _selected >= 0 else null
	if sel != null and not _pending.is_empty() and not bool(_pending["ability"]):
		var w: int = int(_pending["i"])
		var weapon: Dictionary = sel.weapons[w]
		var reach: int = CombatSim.weapon_reach(_state, sel, w)
		if int(weapon["pierce"]) > 0:
			text += "\nThe beam goes %d hexes, then stops (BEAM ENDS); past %d it does half damage." % [
				reach + _state.setup.pierce_overshoot, reach]
	if bool(preview.get("overheats", false)):
		text += "\nOVERHEATS: no attack next round"
	return text


## What a dry run changed, as lines a player reads: every machine hurt, destroyed, dropped
## into a pit, moved, and every prop that breaks. Built from the REAL rules run on a copy.
func _effects_text(effects: Array, preview: Dictionary, action: Array = []) -> String:
	var lines: PackedStringArray = []
	# Play-test 11: every total says what it is made of -- "-7 (4 + 3 blast)", "(arc)" -- and a
	# hit the damage type helps or blunts says so (STRONG / WEAK).
	var parts: Dictionary = CombatSim.damage_parts(_state, action) if not action.is_empty() else {}
	var how: Dictionary = {}
	for hit: Dictionary in (preview.get("hits", []) as Array):
		var ref_h: int = int(hit["ref"])
		var notes: PackedStringArray = []
		if bool(hit.get("arc", false)):
			notes.append("arc: 1 less")
		var pct: int = int(hit.get("pct", 100))
		if pct > 100:
			notes.append("STRONG x%.1f" % (float(pct) / 100.0))
		elif pct < 100:
			notes.append("WEAK x%.1f" % (float(pct) / 100.0))
		if not notes.is_empty():
			how[ref_h] = notes
	for effect: Dictionary in _nearest_first(effects):
		if effect.has("prop"):
			var cell: Vector2i = effect["prop"]
			var prop: Dictionary = _state.props.get(cell, {"kind": "prop"})
			var kind: String = String(prop["kind"])
			if kind == "barrel":
				lines.append("A fuel drum EXPLODES (3 to everything next to it)")
			elif bool(effect.get("broken", true)):
				lines.append("A %s breaks" % ("gate pylon" if kind == "pylon" else "crate wall"))
			else:
				lines.append("A %s -%d → %d/%d" % ["gate pylon" if kind == "pylon" else "crate wall", int(effect.get("hp_lost", 0)),
					int(prop.get("hp", 1)) - int(effect.get("hp_lost", 0)), int(prop.get("max", prop.get("hp", 1)))])
			continue
		var t: GridUnit = _state.unit(int(effect["ref"]))
		if t == null:
			continue
		var who: String = t.name + (" (YOURS)" if t.team == GridUnit.TEAM_PLAYER else "")
		var made: String = ""
		var bits: PackedStringArray = parts.get(t.ref, PackedStringArray())
		if bits.size() > 1 or (bits.size() == 1 and String(bits[0]).contains(" ")):
			made = " (%s)" % " + ".join(bits)
		if how.has(t.ref):
			made += "  " + ", ".join(how[t.ref])
		if bool(effect["fell"]):
			lines.append("%s FALLS INTO THE PIT" % who)
		elif bool(effect["killed"]):
			lines.append("%s -%d%s  DESTROYED" % [who, int(effect["hp_lost"]), made])
		elif int(effect["hp_lost"]) > 0:
			var tear: String = "  TEARS AN ARM OFF" if (preview.get("tears", []) as Array).has(t.ref) else ""
			lines.append("%s -%d%s → %d/%d%s" % [who, int(effect["hp_lost"]), made, t.hp - int(effect["hp_lost"]), t.max_hp, tear])
		elif effect["moved_to"] != null:
			lines.append("%s is moved" % who)
	if lines.is_empty():
		return "Nothing there is affected."
	return "\n".join(lines)


## Play-test 7: the preview reads from the shooter outwards -- the other side's machines nearest
## first, then your own, then props -- so "robot, drum, enemy" lists the enemy's damage first.
func _nearest_first(effects: Array) -> Array:
	var sel: GridUnit = _state.unit(_selected) if _selected >= 0 else null
	var from := Vector2i(sel.x, sel.y) if sel != null else Vector2i.ZERO
	var keyed: Array = []
	for effect: Dictionary in effects:
		var group: int = 2
		var cell: Vector2i = from
		if effect.has("prop"):
			cell = effect["prop"]
		else:
			var t: GridUnit = _state.unit(int(effect["ref"]))
			if t != null:
				group = 1 if t.team == GridUnit.TEAM_PLAYER else 0
				cell = Vector2i(t.x, t.y)
		keyed.append([group, Hex.distance(from, cell), keyed.size(), effect])
	keyed.sort_custom(func(a: Array, b: Array) -> bool:
		for i: int in 3:
			if int(a[i]) != int(b[i]):
				return int(a[i]) < int(b[i])
		return false)
	var out: Array = []
	for k: Array in keyed:
		out.append(k[3])
	return out


## What the next round's start does besides the enemy's fire (025): flues, the Core's pulse.
func _round_start_note() -> String:
	var notes: PackedStringArray = []
	if CombatSim.flues_blow(_state, _state.round_number + 1):
		for y: int in _state.height:
			for x: int in _state.width:
				if _state.flue(x, y) > 0 and notes.is_empty():
					notes.append("The furnace flues blow at the start of next round: %d to whatever stands on one." % _state.flue(x, y))
	if not _state.pulse_marks.is_empty():
		notes.append("The Core pulses its red ring at the start of next round.")
	return "" if notes.is_empty() else "\n\n" + "\n".join(notes)


func _threat_summary(threats: Dictionary) -> String:
	if threats.is_empty():
		return "No enemy is aiming at anything this round." + _round_start_note()
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
	var text: String = "Enemy fire, in order:\n" + "\n".join(lines)
	return text + _round_start_note()


## A card's line: short enough never to be cut off (play-test 6: "Brawler · move 3 · plate
## armour · th..."). The damage type and the rest are in the info panel.
func _card_line(u: GridUnit) -> String:
	return "%s  ·  %s  ·  move %d" % [_frame_of(u), u.role.capitalize(), u.move]


## The frame a machine is built on ("Brute"): crew machines carry their own names now
## (play-test 7), so the frame is said beside it.
func _frame_of(u: GridUnit) -> String:
	var chassis: String = String(u.part_ids[0]) if not u.part_ids.is_empty() else ""
	return String((_db.parts.get(chassis, {}) as Dictionary).get("name", "Machine")).replace(" Frame", "")


func _unit_line(u: GridUnit) -> String:
	if u.team == GridUnit.TEAM_PLAYER:
		return "%s frame  ·  %s  ·  move %d  ·  %s armour  ·  %s" % [_frame_of(u), u.role.capitalize(), u.move,
			String((_db.combat_rules.get("armor_types", []) as Array)[u.armor_type]),
			String((_db.combat_rules.get("damage_types", []) as Array)[u.damage_type])]
	return "%s  ·  move %d  ·  %s armour  ·  %s" % [u.role.capitalize(), u.move,
		String((_db.combat_rules.get("armor_types", []) as Array)[u.armor_type]),
		String((_db.combat_rules.get("damage_types", []) as Array)[u.damage_type])]


func _arms_line(u: GridUnit) -> String:
	var names: PackedStringArray = []
	for w: int in u.weapons.size():
		names.append(String(u.weapons[w]["name"]) + (" (torn)" if bool(u.weapons[w]["torn"]) else ""))
	return " / ".join(names)


## The damage type a weapon deals, in capitals: its own (a Flamer burns), else the core's.
func _dtype_name(u: GridUnit, w: int) -> String:
	var types: Array = _db.combat_rules.get("damage_types", [])
	var t: int = int((u.weapons[w] as Dictionary).get("dtype", -1))
	if t < 0:
		t = u.damage_type
	return String(types[t]).to_upper() if t >= 0 and t < types.size() else "dmg"


func _weapon_detail(u: GridUnit, w: int) -> String:
	var weapon: Dictionary = u.weapons[w]
	var dmg: int = int(weapon["damage"])
	if dmg > 0:
		# Play-test 11: a Focus or Overdrive shows on the card the moment it is used.
		dmg += u.damage_bonus + (u.melee_bonus if String(weapon["shape"]) == "melee" else 0) + u.boost_damage \
			+ CombatSim.conduit_boost(_state, u)
	var bits: PackedStringArray = []
	match String(weapon["shape"]):
		"melee":
			bits.append("melee")
		"cone":
			bits.append("flame cone")
		"shield":
			bits.append("shield ally %d" % CombatSim.weapon_reach(_state, u, w))
		"shot":
			bits.append("shot %d" % CombatSim.weapon_reach(_state, u, w))
		"lob":
			bits.append("lob %d-%d" % [int(weapon["range_min"]), CombatSim.weapon_reach(_state, u, w)])
	bits.append("%d %s" % [dmg, _dtype_name(u, w)] if String(weapon["shape"]) != "shield" else "%d dmg" % dmg)
	for key: String in ["pierce", "chain"]:
		if int(weapon[key]) > 0:
			bits.append("%s %d" % [key, int(weapon[key])])
	for key: String in ["splash", "shove"]:
		if int(weapon[key]) > 0:
			bits.append(key)
	if int(weapon.get("pull", 0)) > 0:
		bits.append("drags")
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
	var style: Array = MARK_STYLES.get(colour, MARK_STYLES[COL_THREAT])
	var material: ShaderMaterial = quad.material_override
	material.set_shader_parameter("colour", Color(colour.r, colour.g, colour.b, 1.0))
	material.set_shader_parameter("hatch_alpha", style[0])
	material.set_shader_parameter("hatch_width", style[1])
	material.set_shader_parameter("fill_alpha", style[2])
	material.set_shader_parameter("border", style[3])
	material.set_shader_parameter("dashes", style[4])
	material.set_shader_parameter("hatch_dir", style[5])


func _clear_marks() -> void:
	for quad: Variant in _hint_quads.values():
		(quad as MeshInstance3D).visible = false
	for quad: Variant in _threat_quads.values():
		(quad as MeshInstance3D).visible = false
	for child: Node in _marks_root.get_children():
		if child.has_meta("intent"):
			child.queue_free()


## An intent that will MISS (its shooter was shoved out of reach) says so on the hex it was
## aimed at; when `full`, a red bar runs from the shooter along its whole line. What the volley
## does is `_volley_badges`: one total per hex, not one badge per shot.
func _intent_marker(ref: int, threat: Dictionary, full: bool) -> void:
	var u: GridUnit = _state.unit(ref)
	var legal: bool = bool(threat["legal"])
	var from: Vector3 = _to_world(u.x, u.y) + Vector3(0, 0.35, 0)
	var end: Vector2i = threat["end"] if legal else threat["aim"]
	var to: Vector3 = _to_world(end.x, end.y) + Vector3(0, 0.35, 0)
	var colour: Color = Ink.DANGER if legal else Color(0.6, 0.6, 0.6, 0.7)
	# 039: the enemy's plan as a THOUGHT -- a cloud over its head with its place in the volley and
	# what it means to do, puffs trailing down to it.
	var planned: int = 0
	for hit: Dictionary in (threat.get("hits", []) as Array):
		var victim_t: GridUnit = _state.unit(int(hit["ref"]))
		if victim_t != null and victim_t.team != u.team:
			planned += int(hit["damage"])
	_thought(u, "%d%s" % [int(threat.get("order", 0)), ("  ·  -%d" % planned) if planned > 0 and legal else ("  ·  MISS" if not legal else "")])
	if not legal:
		_badge("0 MISSES", to + Vector3(0, -0.2, HEX * 0.62), colour, 0.8)
	if not full or from.distance_to(to) < 0.01:
		return
	var lob: bool = String((u.weapons[int(threat["w"])] as Dictionary).get("shape", "")) == "lob"
	_intent_marker_bar(from, to, colour, lob)


## An attack's line (play-test 8): a flat ribbon ending in an arrow head, so it says where it
## goes; a lob -- which touches nothing on the way -- rises in an arch over whatever is between.
func _intent_marker_bar(from: Vector3, to: Vector3, colour: Color = Ink.DANGER, lob: bool = false) -> void:
	var points: PackedVector3Array = []
	var steps: int = 14 if lob else 1
	var rise: float = 0.9 + from.distance_to(to) * 0.18 if lob else 0.0
	for i: int in steps + 1:
		var t: float = float(i) / float(steps)
		points.append(from.lerp(to, t) + Vector3(0, sin(t * PI) * rise, 0))
	var head: float = 0.46
	var half: float = 0.05
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	# The shaft stops where the head begins.
	var tip: Vector3 = points[points.size() - 1]
	var back: Vector3 = (points[points.size() - 2] - tip).normalized()
	points[points.size() - 1] = tip + back * head
	for i: int in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var side: Vector3 = (b - a).cross(Vector3.UP).normalized() * half
		for v: Vector3 in [a - side, a + side, b + side, a - side, b + side, b - side]:
			st.add_vertex(v)
	var base: Vector3 = tip + back * head
	var wide: Vector3 = (-back).cross(Vector3.UP).normalized() * half * 4.0
	for v: Vector3 in [base - wide, base + wide, tip]:
		st.add_vertex(v)
	var bar := MeshInstance3D.new()
	bar.mesh = st.commit()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = colour
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Over the machines, so the head is seen where it lands (tags stay above it).
	material.no_depth_test = true
	material.render_priority = 3
	bar.material_override = Ink.hold(material)
	bar.set_meta("intent", true)
	_marks_root.add_child(bar)


## Play-test 7: "when several enemies hit one spot, show one number -- the total", and whatever
## stands in a line's way shows what it takes too. The whole volley is run on a copy of the
## fight (`CombatSim.incoming`), so the number is what END TURN will do: every machine's total
## on its hex (KO if it will not survive), a prop's on its own. LOCKED where a tracker has it.
func _volley_badges(threats: Dictionary) -> void:
	var locked: Dictionary = {}
	for ref: Variant in threats:
		if bool(threats[ref]["legal"]) and int(threats[ref].get("lock", -1)) >= 0:
			locked[int(threats[ref]["lock"])] = true
	var volley: Dictionary = CombatSim.incoming(_state)
	for hit: Dictionary in (volley["units"] as Array):
		var cell: Vector2i = hit["cell"]
		var word: String = " KO" if bool(hit["killed"]) else (" LOCKED" if locked.has(int(hit["ref"])) else "")
		_badge("-%d%s" % [int(hit["hp_lost"]), word], _to_world(cell.x, cell.y) + Vector3(0, -0.2, HEX * 0.62), Ink.DANGER, 1.0)
	for hit: Dictionary in (volley["props"] as Array):
		var cell: Vector2i = hit["cell"]
		_badge("-%d" % int(hit["hp_lost"]), _to_world(cell.x, cell.y) + Vector3(0, -0.2, HEX * 0.62), Ink.DANGER, 0.8)


func _marker_label(text: String, at: Vector3, colour: Color, size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = UIKit.font_comic()
	label.font_size = size
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 16
	label.outline_modulate = Ink.INK
	label.modulate = colour
	label.position = at
	label.set_meta("intent", true)
	_marks_root.add_child(label)


## An intent badge (015): an ink disc ringed in the danger red, the firing order lettered in
## paper on it -- the sketch the user picked, and it reads in grey (a dark disc, a pale figure).
## A MISSES or LOCKED suffix hangs under it.
func _badge(text: String, at: Vector3, colour: Color, scale: float, owner_ref: int = -1, lift: Vector2 = Vector2.ZERO) -> void:
	var nodes: Array[Node3D] = []
	var parts: PackedStringArray = text.split(" ", false, 1)
	# A total like "-12" needs a wider disc than a single figure.
	var radius: float = 0.21 * scale * (1.0 + 0.18 * float(maxi(0, parts[0].length() - 1)))
	var disc: Node3D = _disc(at, radius * 1.25, Ink.INK, colour, 4, lift, true)
	nodes.append(disc)
	var label := Label3D.new()
	label.text = parts[0]
	label.font = UIKit.font_comic()
	label.font_size = int(64 * scale)
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 0
	label.modulate = Ink.PAPER
	label.render_priority = 6
	label.position = at
	label.offset = lift / label.pixel_size
	nodes.append(label)
	if parts.size() > 1:
		# MISSES / LOCKED reads BESIDE the disc (play-test 6: under it, the word hid behind it).
		var word := Label3D.new()
		word.text = parts[1]
		word.font = UIKit.font_comic()
		word.font_size = int(34 * scale)
		word.pixel_size = 0.005
		word.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		word.no_depth_test = true
		word.outline_size = 14
		word.outline_modulate = Ink.INK
		word.modulate = colour.lightened(0.3)
		word.render_priority = 6
		word.outline_render_priority = 5
		word.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		word.offset = (lift + Vector2(radius + 0.05, 0.0)) / 0.005
		word.position = at
		nodes.append(word)
	for node: Node3D in nodes:
		node.set_meta("intent", true)
		node.set_meta("base_pos", node.position)
		if owner_ref >= 0:
			node.set_meta("badge_of", owner_ref)
		else:
			node.set_meta("ground_badge", true)
		_marks_root.add_child(node)


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
	plate.material_override = Ink.hold(plate_material)
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
	ring.material_override = Ink.hold(ring_material)
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
		ghost.material_override = Ink.hold(ghost_material)
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
	_marker_label("DRONE NEXT TURN · stand here to block" if urgent else "PAD · drone in %d" % due,
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
	beam.material_override = Ink.hold(material)
	beam.set_meta("intent", true)
	_marks_root.add_child(beam)
	beam.look_at_from_position((from + to) * 0.5, to, Vector3.UP)


## A hex The Pour has flooded (021): a pool of slag over the tile, for the rest of the fight.
func _flood_marker(cell: Vector2i) -> void:
	var pool := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = HEX * 0.86
	disc.bottom_radius = HEX * 0.86
	disc.height = 0.03
	disc.radial_segments = 6
	pool.mesh = disc
	pool.material_override = Ink.glow(Color("ff6a1f"), 0.5)
	pool.position = _to_world(cell.x, cell.y) + Vector3(0, _tile_top(cell.x, cell.y) + 0.02, 0)
	pool.set_meta("intent", true)
	_marks_root.add_child(pool)


## Where the Reclaimer's drones come in next round (013): a red hex, a ghost of what is
## coming, and what to do about it.
func _arrival_marker(cell: Vector2i, text: String = "RECLAIMER NEXT TURN · stand here to block") -> void:
	var at: Vector3 = _to_world(cell.x, cell.y) + Vector3(0, _tile_top(cell.x, cell.y), 0)
	var ghost := MeshInstance3D.new()
	var body := BoxMesh.new()
	body.size = Vector3(HEX * 0.55, HEX * 0.9, HEX * 0.55)
	ghost.mesh = body
	ghost.position = at + Vector3(0, HEX * 0.5, 0)
	var ghost_material := StandardMaterial3D.new()
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.albedo_color = Color(COL_PAD_DANGER, 0.24)
	ghost.material_override = Ink.hold(ghost_material)
	ghost.set_meta("intent", true)
	_marks_root.add_child(ghost)
	var flicker := ghost.create_tween().set_loops()
	flicker.tween_property(ghost_material, "albedo_color:a", 0.06, 0.3)
	flicker.tween_property(ghost_material, "albedo_color:a", 0.28, 0.3)
	_marker_label(text, at + Vector3(0, 0.08, HEX * 0.72), COL_PAD_DANGER.lightened(0.35), 24)


## A red beam from every standing gate pylon to the Sorter it shields (013): the shield is
## a thing on the board you can see, and break.
func _pylon_beams() -> void:
	var keeper: GridUnit = null
	for u: GridUnit in _state.units:
		if u.alive and u.kind == "sorter":
			keeper = u
	if keeper == null:
		return
	var to: Vector3 = _to_world(keeper.x, keeper.y) + Vector3(0, 1.4, 0)
	var cells: Array = _state.props.keys()
	cells.sort()
	for cell: Vector2i in cells:
		if String((_state.props[cell] as Dictionary).get("kind", "")) != "pylon":
			continue
		var from: Vector3 = _to_world(cell.x, cell.y) + Vector3(0, 1.55, 0)
		var beam := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.06, 0.06, from.distance_to(to))
		beam.mesh = box
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(COL_PAD_DANGER, 0.75)
		beam.material_override = Ink.hold(material)
		beam.set_meta("intent", true)
		_marks_root.add_child(beam)
		beam.look_at_from_position((from + to) * 0.5, to, Vector3.UP)
		var hum := beam.create_tween().set_loops()
		hum.tween_property(material, "albedo_color:a", 0.35, 0.5).set_trans(Tween.TRANS_SINE)
		hum.tween_property(material, "albedo_color:a", 0.8, 0.5).set_trans(Tween.TRANS_SINE)


## 030: the warlords' rules on the board -- the Grinder's saw ring (its neighbours, red, every
## round), the Magnet King's reach the round before it hauls, a beam between the Twin Furnaces.
func _warlord_marks() -> void:
	var twins: Array[GridUnit] = []
	for u: GridUnit in _state.units:
		if not u.alive or u.kind.is_empty():
			continue
		var rules: Dictionary = CombatSim.kind_rules(_state, u)
		var here := Vector2i(u.x, u.y)
		var top: Vector3 = _to_world(u.x, u.y) + Vector3(0, _tile_top(u.x, u.y), 0)
		if int(rules.get("aura", 0)) > 0:
			for n: Vector2i in Hex.neighbors(here):
				if _state.inside(n):
					_mark(_threat_quads, n, COL_THREAT)
			_marker_label("SAW RING · %d to anything next to it, every round" % int(rules["aura"]), top + Vector3(0, 0.08, HEX * 1.6), Ink.PAPER, 28)
		if CombatSim.hauls_on(_state, u, _state.round_number + 1):
			for cell: Vector2i in Hex.within(here, int(rules.get("haul_radius", 3))):
				if _state.inside(cell) and Hex.distance(cell, here) > 1:
					_mark(_threat_quads, cell, COL_SPAWN)
			_marker_label("HAULS NEXT ROUND · everything within %d comes a hex closer" % int(rules.get("haul_radius", 3)),
				top + Vector3(0, 0.08, HEX * 1.6), Ink.PAPER, 28)
		if int((_db.enemy_kinds.get(u.kind, {}) as Dictionary).get("twin_armor", 0)) > 0:
			twins.append(u)
	if twins.size() == 2:
		_intent_marker_bar(_to_world(twins[0].x, twins[0].y) + Vector3(0, 1.4, 0), _to_world(twins[1].x, twins[1].y) + Vector3(0, 1.4, 0), COL_PAD_DANGER)


## 028: HOLD's zone (blue rings, HOLD ZONE), HACK's terminals (consoles: blue to take, green when
## taken), SURVIVE's next wave (the arrival ghost, WAVE NEXT TURN).
func _objective_marks() -> void:
	var o: Dictionary = _state.objective()
	var cells: Array = o.get("cells", [])
	match String(o.get("type", "")):
		"hold":
			for cell: Vector2i in cells:
				_zone_ring(cell, Ink.YOURS)
			var first: Vector2i = cells[0]
			_marker_label("HOLD ZONE · %d / %d" % [_state.hold_score, int(o.get("need", 0))],
				_to_world(first.x, first.y) + Vector3(0, 0.1, HEX * 0.75), Ink.YOURS.lightened(0.3), 28)
		"hack":
			for cell: Vector2i in cells:
				_terminal(cell, _state.hacked.has(cell))
	for cell: Vector2i in _state.wave_marks:
		_mark(_threat_quads, cell, COL_THREAT)
		_arrival_marker(cell, "WAVE NEXT TURN · stand here to block")


func _zone_ring(cell: Vector2i, colour: Color) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = HEX * 0.78
	torus.outer_radius = HEX * 0.9
	torus.ring_segments = 6
	torus.rings = 6
	ring.mesh = torus
	ring.scale = Vector3(1, 0.3, 1)
	ring.position = _to_world(cell.x, cell.y) + Vector3(0, _tile_top(cell.x, cell.y) + 0.05, 0)
	ring.material_override = Ink.glow(colour, 0.5)
	ring.set_meta("intent", true)
	_marks_root.add_child(ring)


## A hacking terminal (028): a squat console with a lit screen -- blue to take, green once taken.
func _terminal(cell: Vector2i, taken: bool) -> void:
	var root := Node3D.new()
	root.position = _to_world(cell.x, cell.y) + Vector3(0, _tile_top(cell.x, cell.y), 0)
	root.set_meta("intent", true)
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.34, 0.42, 0.26)
	body.mesh = box
	body.position = Vector3(0.0, 0.21, -0.18)
	body.material_override = Ink.toon(Color("3a3d45"), "clean")
	Ink.line(body, Ink.LINE_ACT)
	root.add_child(body)
	var screen := MeshInstance3D.new()
	var face := BoxMesh.new()
	face.size = Vector3(0.26, 0.18, 0.02)
	screen.mesh = face
	screen.position = Vector3(0.0, 0.3, -0.04)
	screen.material_override = Ink.glow(Ink.GAIN if taken else Ink.YOURS, 0.8)
	root.add_child(screen)
	_marks_root.add_child(root)
	_zone_ring(cell, Ink.GAIN if taken else Ink.YOURS)


## A red link from every conduit to each ally next to it (025): who hits 1 harder, on the board.
func _conduit_links() -> void:
	for relay: GridUnit in _state.units:
		if not relay.alive or relay.kind != "conduit":
			continue
		var from: Vector3 = _to_world(relay.x, relay.y) + Vector3(0, 1.5, 0)
		for n: Vector2i in Hex.neighbors(Vector2i(relay.x, relay.y)):
			var ally: GridUnit = _state.unit_at(n.x, n.y) if _state.inside(n) else null
			if ally == null or ally.team != relay.team:
				continue
			var to: Vector3 = _to_world(n.x, n.y) + Vector3(0, 1.5, 0)
			var beam := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.09, 0.09, from.distance_to(to))
			beam.mesh = box
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = Color(COL_PAD_DANGER, 0.75)
			beam.material_override = Ink.hold(material)
			beam.set_meta("intent", true)
			_marks_root.add_child(beam)
			beam.look_at_from_position((from + to) * 0.5, to, Vector3.UP)
			var hum := beam.create_tween().set_loops()
			hum.tween_property(material, "albedo_color:a", 0.5, 0.45).set_trans(Tween.TRANS_SINE)
			hum.tween_property(material, "albedo_color:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)


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
	if event is InputEventMouseMotion:
		_hover_path((event as InputEventMouseMotion).position)
		return
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


## Hovering a hex the picked machine can walk to draws the route it will take (play-test 5:
## "they go around the scrap" -- the route should never be a surprise). Mouse only; on touch
## the walk itself shows it.
func _hover_path(screen: Vector2) -> void:
	var cell: Variant = null
	if not _busy and not _armed and _selected >= 0 and _state != null and _state.outcome == CombatState.ONGOING:
		cell = _pick(screen)
	var route: Array = []
	if cell != null:
		route = CombatSim.reachable(_state, _selected).get(cell, [])
	var key: String = str(route)
	if _path_root != null and String(_path_root.get_meta("route", "")) == key:
		return
	if _path_root == null:
		_path_root = Node3D.new()
		add_child(_path_root)
	for child: Node in _path_root.get_children():
		child.queue_free()
	_path_root.set_meta("route", key)
	for i: int in route.size():
		var step: Vector2i = route[i]
		var dot := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.1 if i < route.size() - 1 else 0.17
		disc.bottom_radius = disc.top_radius
		disc.height = 0.02
		dot.mesh = disc
		dot.material_override = Ink.on_top(COL_PLAYER.lightened(0.35))
		dot.position = _to_world(step.x, step.y) + Vector3(0, _tile_top(step.x, step.y) + 0.06, 0)
		_path_root.add_child(dot)


## A kill punches the camera in and eases it back (023). The only thing that moves it: the
## camera is fixed so that no hex is ever hidden.
func _punch() -> void:
	var rest: float = _zoom
	var punch := create_tween()
	punch.tween_method(func(z: float) -> void:
		_zoom = z
		_place_camera(), rest, rest * 0.93, 0.07)
	punch.tween_method(func(z: float) -> void:
		_zoom = z
		_place_camera(), rest * 0.93, rest, 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


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
		if there.team == GridUnit.TEAM_ENEMY and not there.objective:
			about += "\n" + ("Drops a scrap pile when destroyed (the green bolts at its feet)." if there.carries_scrap
				else "Drops nothing when destroyed.")
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
			_hud.set_info("DRONE BUILD SITE", "A pad will build a drone here. Stand on it to stop the build.")
			return
	var o: Dictionary = _state.objective()
	if (o.get("cells", []) as Array).has(cell):
		if String(o.get("type", "")) == "hold":
			_hud.set_info("HOLD ZONE", "Start a round with one of your machines here and no enemy on the zone: the zone is held. Hold it %d times to win." % int(o.get("need", 0)))
		else:
			_hud.set_info("TERMINAL", "End a move here to take it%s. Take %d to win." % [" (already yours)" if _state.hacked.has(cell) else "", int(o.get("need", 0))])
		return
	if _state.pulse_marks.has(cell):
		_hud.set_info("THE CORE'S RING", "The Core pulses here at the start of next round: 4 to any of your machines standing in it. Get out of the ring.")
		return
	if _state.arrivals.has(cell):
		_hud.set_info("RECLAIMER ARRIVAL", "You are fighting near the Reclaimer's line: one of its drones comes in here next round. Stand on the hex to block it.")
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
	var undone: Array = _actions.pop_back()
	_record()
	_state = CombatSim.replay(_setup, _actions)
	_shown = _state.events.size()
	_pending = {}
	_armed = false
	_ability = -1
	_spawn_units()
	# Play-test 5: UNDO goes back to the machine whose action it took back -- never to the
	# next one the game picked for you, nor to none. An undone attack is armed again, ready to
	# aim; an undone targeted ability too.
	var ref: int = int(undone[1]) if undone.size() > 1 else -1
	var who: GridUnit = _state.unit(ref) if ref >= 0 else null
	if who != null and who.alive and who.team == GridUnit.TEAM_PLAYER and not who.objective:
		_selected = ref
		match int(undone[0]):
			CombatSim.ACT_ATTACK:
				_weapon = int(undone[2])
				_armed = who.can_fire(_weapon)
			CombatSim.ACT_ABILITY:
				var i: int = int(undone[2])
				if i >= 0 and i < who.abilities.size() and CombatAbilities.needs_target(who.abilities[i]):
					_ability = i
					_armed = true
	if not _armed:
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
	# The enemy's next round is planned inside the END action (a fifth of a second with a full
	# board): the banner answers the press first, so the wait reads as the enemy getting ready.
	_busy = true
	_hud.set_banner("ENEMY FIRE", UIKit.RED)
	await get_tree().process_frame
	_busy = false
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
