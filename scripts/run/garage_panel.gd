extends Control

## The garage (play-test 3 replaced REFIT with it, after a "manage soldier" reference):
##
##   - crew tabs across the top; the selected machine stands WHOLE in 3D on the left;
##   - beside it, PARTS (its five sockets) and STATS (every number, from the sim's own
##     unit, so the garage cannot disagree with the fight);
##   - hovering a part turns the machine to show it and lights that part up;
##   - LEVEL UP under the machine: where scrap goes;
##   - the hold is a low strip along the bottom with SORT and a SCRAP bin.
##
## Drag a part onto a socket, from a socket back to the hold, onto a crew tab (it fits on
## that machine), or onto SCRAP. Tap a part, then tap where it goes, does the same.
## Every change goes through `Run.apply`.

signal closed

const SOCKET_NAMES: PackedStringArray = ["FRAME", "CORE", "LEFT ARM", "RIGHT ARM", "MODULE"]
const SOCKET_NODES: PackedStringArray = ["part_chassis", "part_core", "part_arm_l", "part_arm_r", "part_module"]
const HOLD_CARD := Vector2(184, 196)
const SORTS: PackedStringArray = ["NEWEST", "RARITY", "SLOT"]
const SLOT_ORDER: PackedStringArray = ["chassis", "core", "arm", "module"]
const TEAM := Color("4fa8d8")
const REST_YAW: float = 0.6
const VIEW_SIZE := Vector2i(700, 560)

## The crew member on show.
var selected: int = 0
var _tab: String = "PARTS"
var _sort: String = "NEWEST"
## What is being moved: `{ "from": "hold", "index" }` or `{ "from": "socket", "crew", "socket" }`.
var _held: Dictionary = {}
var _message: String = ""
var _status: Label
var _header: HBoxContainer
var _info: VBoxContainer
var _right: VBoxContainer
var _bottom: VBoxContainer
## `[button, crew, socket]` for every socket on screen, so a drag can light the ones that fit.
var _sockets: Array = []

var _pivot: Node3D
var _camera: Camera3D
var _floor: MeshInstance3D
var _model: Node3D
var _yaw: float = REST_YAW
var _yaw_goal: float = REST_YAW
var _focus: int = -1
var _glow: StandardMaterial3D
var _time: float = 0.0
var _turning: bool = false


func _ready() -> void:
	UIKit.apply(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var floor_colour := ColorRect.new()
	floor_colour.color = UIKit.BG
	add_child(floor_colour)
	floor_colour.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UIKit.backdrop())

	_header = HBoxContainer.new()
	_header.position = Vector2(40, 24)
	_header.size = Vector2(1840, 72)
	_header.add_theme_constant_override("separation", UIKit.SPACE_MD)
	add_child(_header)

	var stage := PanelContainer.new()
	stage.position = Vector2(40, 116)
	stage.add_theme_stylebox_override("panel", UIKit.inset(UIKit.SURFACE_SUNK, UIKit.RADIUS_CARD, 0, 0))
	add_child(stage)
	var view := SubViewportContainer.new()
	view.custom_minimum_size = Vector2(VIEW_SIZE)
	view.stretch = true
	view.gui_input.connect(_on_view_input)
	view.tooltip_text = "Drag to turn the machine"
	stage.add_child(view)
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	view.add_child(viewport)
	_build_stage(viewport)

	_info = VBoxContainer.new()
	_info.position = Vector2(64, 136)
	_info.mouse_filter = Control.MOUSE_FILTER_PASS
	_info.add_theme_constant_override("separation", UIKit.SPACE_XS)
	add_child(_info)

	_right = VBoxContainer.new()
	_right.position = Vector2(770, 116)
	_right.size = Vector2(1110, 560)
	_right.add_theme_constant_override("separation", UIKit.SPACE_SM)
	add_child(_right)

	_bottom = VBoxContainer.new()
	_bottom.position = Vector2(40, 700)
	_bottom.size = Vector2(1840, 360)
	_bottom.add_theme_constant_override("separation", UIKit.SPACE_SM)
	add_child(_bottom)

	_glow = StandardMaterial3D.new()
	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow.albedo_color = Color(1.0, 0.72, 0.25, 0.4)
	selected = clampi(selected, 0, Run.state.crew.size() - 1)
	_rebuild()


func _notification(what: int) -> void:
	# A drag dropped nowhere (or cancelled) puts the part back down.
	if what == NOTIFICATION_DRAG_END and not _held.is_empty():
		_held = {}
		_restyle_sockets()


func _process(delta: float) -> void:
	_time += delta
	if not _turning:
		_yaw = lerp_angle(_yaw, _yaw_goal, 1.0 - exp(-delta * 6.0))
	if _pivot != null:
		_pivot.rotation.y = _yaw
	_glow.albedo_color.a = 0.28 + 0.16 * sin(_time * 5.0)


# --- The stage: the machine in 3D --------------------------------------------

func _build_stage(viewport: SubViewport) -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("10131b")
	sky_material.sky_horizon_color = Color("3b3330")
	sky_material.ground_bottom_color = Color("0e0c0a")
	sky_material.ground_horizon_color = Color("382c22")
	sky_material.energy_multiplier = 0.7
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.35
	environment.ambient_light_color = Color("2f3a52")
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.1
	environment.glow_enabled = true
	environment.glow_intensity = 0.45
	environment.glow_hdr_threshold = 0.9
	env.environment = environment
	viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 35, 0)
	key.light_energy = 1.2
	key.light_color = Color("ffd3a4")
	key.shadow_enabled = true
	viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -140, 0)
	fill.light_energy = 0.9
	fill.light_color = Color("8aa3de")
	viewport.add_child(fill)
	_floor = MeshInstance3D.new()
	var floor_mesh: MeshInstance3D = _floor
	var disc := CylinderMesh.new()
	disc.top_radius = 1.4
	disc.bottom_radius = 1.5
	disc.height = 0.08
	floor_mesh.mesh = disc
	floor_mesh.position.y = -0.04
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("2e2b28")
	floor_material.roughness = 0.9
	floor_mesh.material_override = floor_material
	viewport.add_child(floor_mesh)
	_pivot = Node3D.new()
	viewport.add_child(_pivot)
	_camera = Camera3D.new()
	_camera.fov = 32.0
	viewport.add_child(_camera)
	_camera.current = true


func _rebuild_model() -> void:
	if _model != null:
		_model.queue_free()
	var member: Dictionary = Run.state.crew[selected]
	_model = ConstructView.build_parts(PackedStringArray(member["parts"]), Run.db, TEAM)
	_pivot.add_child(_model)
	# Framed by the machine's own height, so a squat anchor and a tall marksman both fill
	# the stage; nudged right because the name sits over the left of it.
	var h: float = ConstructView.height_of(_model)
	_camera.position = Vector3(-0.3 * h, 0.62 * h + 0.15, 3.4 * h)
	_camera.look_at(Vector3(-0.28 * h, 0.5 * h, 0))
	_floor.scale = Vector3.ONE * clampf(h * 0.55, 0.5, 1.4)
	if not bool(member["alive"]):
		_model.rotation_degrees = Vector3(0, 0, 78)
	_focus = -1


## Turn the machine to show socket `s` and light that part up (-1: back to rest).
func _focus_socket(s: int) -> void:
	if s == _focus:
		return
	_light(_focus, false)
	_focus = s
	_light(s, true)
	var part: Node3D = _part_node(s)
	if part == null or s == 0:
		_yaw_goal = REST_YAW
		return
	var p: Vector3 = _pivot.global_transform.affine_inverse() * part.global_position
	# The yaw that swings this part round to face the camera, then a little past, so it is
	# seen in three-quarter rather than dead on.
	_yaw_goal = atan2(-p.x, p.z) + (0.35 if p.x <= 0.0 else -0.35)


func _part_node(s: int) -> Node3D:
	if s < 0 or _model == null:
		return null
	return _find(_model, SOCKET_NODES[s])


func _light(s: int, on: bool) -> void:
	var part: Node3D = _part_node(s)
	if part == null:
		return
	for mesh: MeshInstance3D in _part_meshes(part):
		mesh.material_overlay = _glow if on else null
	if s != 0:
		# Stand the part proud of the frame while it is lit.
		if not part.has_meta("rest_scale"):
			part.set_meta("rest_scale", part.scale)
		var rest: Vector3 = part.get_meta("rest_scale")
		part.scale = rest * (1.14 if on else 1.0)


## The meshes of one part, not of the parts bolted onto it.
func _part_meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node)
	for child: Node in node.get_children():
		if String(child.name).begins_with("part_"):
			continue
		out.append_array(_part_meshes(child))
	return out


func _on_view_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_turning = (event as InputEventMouseButton).pressed
	elif event is InputEventMouseMotion and _turning:
		# Drag right, the front swings right (CLAUDE.md, "Drag sign is geometry").
		_yaw += (event as InputEventMouseMotion).relative.x * 0.01
		_yaw_goal = _yaw


# --- Layout -------------------------------------------------------------------

func _rebuild() -> void:
	for box: Node in [_header, _info, _right, _bottom]:
		for child: Node in box.get_children():
			child.queue_free()
	_sockets = []
	_build_header()
	_build_info()
	if _tab == "PARTS":
		_build_parts()
	else:
		_build_stats()
	_build_hold()
	_rebuild_model()


func _build_header() -> void:
	var state: RunState = Run.state
	_header.add_child(_label("GARAGE", UIKit.SIZE_DISPLAY, UIKit.TEXT, UIKit.font_display()))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(30, 0)
	_header.add_child(gap)
	for i: int in state.crew.size():
		var member: Dictionary = state.crew[i]
		var level: int = int(member.get("level", 0))
		var text: String = String(member["name"]).to_upper() + ("  LV %d" % level if level > 0 else "")
		if not bool(member["alive"]):
			text += "  · WRECK"
		var tab := _button(text, UIKit.choice() if i == selected else UIKit.secondary(),
			UIKit.AMBER if i == selected else UIKit.TEXT, Vector2(220, 60))
		tab.pressed.connect(_select.bind(i))
		tab.set_drag_forwarding(Callable(), _can_drop_tab.bind(i), _drop_tab.bind(i))
		_header.add_child(tab)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(spacer)
	_header.add_child(_label("SCRAP %d" % state.scrap, UIKit.SIZE_TITLE, UIKit.TEXT, UIKit.font_numbers()))
	var done := _button("BACK TO MAP", UIKit.primary(), UIKit.BG, Vector2(260, 64))
	done.pressed.connect(func() -> void: closed.emit())
	_header.add_child(done)


## Over the machine: its name, level, HP; under it, LEVEL UP.
func _build_info() -> void:
	var member: Dictionary = Run.state.crew[selected]
	var alive: bool = bool(member["alive"])
	var level: int = int(member.get("level", 0))
	_info.add_child(_label(String(member["name"]).to_upper(), UIKit.SIZE_DISPLAY, UIKit.TEXT, UIKit.font_display()))
	_info.add_child(_label(("LEVEL %d" % level) if alive else "WRECK: rebuild it at a workshop", UIKit.SIZE_HEADING,
		UIKit.AMBER if alive else UIKit.RED, UIKit.font_strong()))
	if alive:
		var full: int = RunSim.max_hp(Run.setup, member)
		_info.add_child(_label("%d / %d HP" % [int(member["hp"]), full], UIKit.SIZE_BODY, UIKit.TEXT_DIM, UIKit.font_numbers()))
	# LEVEL UP sits under the name, clear of the machine.
	var foot := VBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_PASS
	_info.add_child(foot)
	if not alive:
		return
	var levels: Dictionary = Run.setup.rules.get("levels", {})
	var cost: int = RunSim.level_cost(Run.state, Run.setup, selected)
	var gain: String = "+%d HP, +%d damage" % [int(levels.get("hp", 0)), int(levels.get("damage", 0))]
	if cost < 0:
		foot.add_child(_label("TOP LEVEL", UIKit.SIZE_HEADING, UIKit.GREEN, UIKit.font_strong()))
	elif Run.state.scrap >= cost:
		var up := _button("LEVEL UP  ·  %d SCRAP" % cost, UIKit.choice(), UIKit.TEXT, Vector2(300, 52))
		up.tooltip_text = "Overhaul %s: %s on every weapon" % [String(member["name"]), gain]
		up.pressed.connect(_level_up)
		foot.add_child(up)
		foot.add_child(_label(gain, UIKit.SIZE_LABEL, UIKit.GREEN))
	else:
		foot.add_child(_label("LEVEL UP  ·  %d SCRAP (you have %d)" % [cost, Run.state.scrap], UIKit.SIZE_BODY, UIKit.TEXT_FAINT, UIKit.font_strong()))
		foot.add_child(_label(gain, UIKit.SIZE_LABEL, UIKit.TEXT_FAINT))


func _build_tabs() -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", UIKit.SPACE_SM)
	_right.add_child(tabs)
	for name: String in ["PARTS", "STATS"]:
		var tab := _button(name, UIKit.choice() if name == _tab else UIKit.secondary(),
			UIKit.AMBER if name == _tab else UIKit.TEXT_DIM, Vector2(180, 48))
		tab.pressed.connect(func() -> void:
			_tab = name
			_rebuild())
		tabs.add_child(tab)


# --- PARTS --------------------------------------------------------------------

func _build_parts() -> void:
	_build_tabs()
	var alive: bool = bool(Run.state.crew[selected]["alive"])
	for s: int in 5:
		_right.add_child(_socket(selected, s, alive))


func _socket(i: int, s: int, alive: bool) -> Control:
	var part: String = String((Run.state.crew[i]["parts"] as Array)[s])
	var button := Button.new()
	button.custom_minimum_size = Vector2(1110, 92)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not alive
	_sockets.append([button, i, s])
	var style: StyleBoxFlat = _socket_style(i, s)
	for key: String in ["normal", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(key, style)
	button.add_theme_stylebox_override("hover", _socket_style(i, s, true))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UIKit.SPACE_MD)
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, UIKit.SPACE_SM)
	var picture := TextureRect.new()
	picture.texture = PartText.thumb(part)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(76, 76)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var rarity: String = ""
	if not part.is_empty():
		rarity = "  ·  " + PartCard.RARITY_NAMES[clampi(int((Run.db.parts.get(part, {}) as Dictionary).get("rarity", 1)), 1, 3) - 1]
	text.add_child(_label("%s  ·  %s%s" % [SOCKET_NAMES[s], PartText.name_of(Run.db.parts, part) if not part.is_empty() else "EMPTY", rarity],
		UIKit.SIZE_HEADING, PartText.rarity_colour(Run.db.parts, part).lightened(0.3) if not part.is_empty() else UIKit.RED, UIKit.font_strong()))
	var summary := _label(PartText.summary(Run.db.parts, part, Run.db.combat_abilities) if not part.is_empty()
		else "Drag a %s here from the hold." % RunSetup.socket_slot(s), UIKit.SIZE_BODY, UIKit.TEXT_DIM)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.custom_minimum_size = Vector2(980, 0)
	summary.max_lines_visible = 2
	text.add_child(summary)
	button.mouse_entered.connect(_focus_socket.bind(s))
	button.mouse_exited.connect(func() -> void:
		if _focus == s:
			_focus_socket(-1))
	if alive:
		var source: Dictionary = {"from": "socket", "crew": i, "socket": s}
		button.set_drag_forwarding(_drag_from.bind(source) if not part.is_empty() and s != 0 else Callable(),
			_can_drop_socket.bind(i, s), _drop_socket.bind(i, s))
		button.pressed.connect(_tap_socket.bind(i, s))
	return button


# --- STATS --------------------------------------------------------------------

## Every number of the machine, read off the unit the sim would field.
func _build_stats() -> void:
	_build_tabs()
	var member: Dictionary = Run.state.crew[selected]
	var u: GridUnit = RunSim.preview_machine(Run.setup, member)
	var rules: Dictionary = Run.setup.combat_rules
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", UIKit.SPACE_XL)
	grid.add_theme_constant_override("v_separation", UIKit.SPACE_XS)
	_right.add_child(grid)
	var armor_types: Array = rules.get("armor_types", [])
	var damage_types: Array = rules.get("damage_types", [])
	_stat(grid, "HEALTH", u.max_hp, 24, "%d" % u.max_hp)
	_stat(grid, "MOVE", u.move, 6, "%d hexes" % u.move)
	_stat(grid, "HEAT CAP", u.heat_cap, 10, "%d" % u.heat_cap)
	_stat(grid, "VENT", u.vent, 4, "%d a turn" % u.vent)
	_stat(grid, "ARMOUR", u.armor, 3, "%d · %s" % [u.armor, String(armor_types[u.armor_type]) if u.armor_type < armor_types.size() else ""])
	_stat(grid, "DAMAGE BONUS", u.damage_bonus, 4, "+%d · %s" % [u.damage_bonus, String(damage_types[u.damage_type]) if u.damage_type < damage_types.size() else ""])

	_right.add_child(_label("ROLE  ·  %s%s" % [u.role.to_upper(), _role_note(u)], UIKit.SIZE_BODY, UIKit.TEXT, UIKit.font_strong()))
	for w: Dictionary in u.weapons:
		if bool(w["empty"]):
			continue
		var shape: String = String(w["shape"])
		var reach: String = "melee" if shape == "melee" else ("lob %d-%d" % [int(w["range_min"]), int(w["range"])] if shape == "lob" else "shot %d" % int(w["range"]))
		var dmg: int = int(w["damage"]) + u.damage_bonus + (u.melee_bonus if shape == "melee" else 0)
		_right.add_child(_label("%s  ·  %s  ·  %d damage  ·  +%d heat" % [String(w["name"]).to_upper(), reach, dmg, int(w["heat"]) + u.heat_bonus],
			UIKit.SIZE_BODY, UIKit.AMBER.lightened(0.2)))
	for ability: Dictionary in u.abilities:
		var line := _label("%s  ·  %s  ·  cooldown %d:  %s" % [String(ability["name"]).to_upper(),
			"free" if bool(ability["free"]) else "uses the action", int(ability["cooldown"]), String(ability.get("text", ""))],
			UIKit.SIZE_LABEL, UIKit.BLUE.lightened(0.35))
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(1100, 0)
		_right.add_child(line)


func _role_note(u: GridUnit) -> String:
	var bits: PackedStringArray = []
	if u.melee_bonus > 0:
		bits.append("+%d melee damage" % u.melee_bonus)
	if u.unshovable:
		bits.append("cannot be shoved")
	if u.move_after_attack:
		bits.append("can move after attacking")
	return ("  (%s)" % ", ".join(bits)) if not bits.is_empty() else ""


func _stat(grid: GridContainer, name: String, value: int, top: int, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.SPACE_SM)
	row.custom_minimum_size = Vector2(540, 40)
	var label := _label(name, UIKit.SIZE_BODY, UIKit.TEXT_DIM, UIKit.font_strong())
	label.custom_minimum_size = Vector2(150, 0)
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(170, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = top
	bar.value = clampi(value, 0, top)
	bar.add_theme_stylebox_override("background", UIKit.plain(UIKit.SURFACE_SUNK, 2))
	bar.add_theme_stylebox_override("fill", UIKit.plain(UIKit.BLUE, 2))
	row.add_child(bar)
	row.add_child(_label(text, UIKit.SIZE_BODY, UIKit.TEXT, UIKit.font_numbers()))
	grid.add_child(row)


# --- The hold -----------------------------------------------------------------

func _build_hold() -> void:
	var state: RunState = Run.state
	var news: bool = not _held.is_empty() or not _message.is_empty()
	_status = _label(_message if _held.is_empty() and not _message.is_empty() else _status_text(),
		UIKit.SIZE_BODY, UIKit.AMBER if news else UIKit.TEXT_DIM, UIKit.font_strong())
	_message = ""
	_bottom.add_child(_status)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIKit.SPACE_SM)
	_bottom.add_child(head)
	var over: bool = state.overfull()
	head.add_child(_label("HOLD  %d / %d%s" % [state.cargo.size(), state.hold_size,
		"   OVER: fit or scrap %d before moving on" % (state.cargo.size() - state.hold_size) if over else ""],
		UIKit.SIZE_HEADING, UIKit.RED if over else UIKit.TEXT, UIKit.font_strong()))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(30, 0)
	head.add_child(spacer)
	head.add_child(_label("SORT", UIKit.SIZE_LABEL, UIKit.TEXT_FAINT, UIKit.font_strong()))
	for sort: String in SORTS:
		var b := _button(sort, UIKit.choice() if sort == _sort else UIKit.secondary(),
			UIKit.AMBER if sort == _sort else UIKit.TEXT_DIM, Vector2(120, 38))
		b.add_theme_font_size_override("font_size", UIKit.SIZE_LABEL)
		b.pressed.connect(func() -> void:
			_sort = sort
			_rebuild())
		head.add_child(b)

	var lower := HBoxContainer.new()
	lower.add_theme_constant_override("separation", UIKit.SPACE_MD)
	_bottom.add_child(lower)
	var hold_drop := PanelContainer.new()
	hold_drop.add_theme_stylebox_override("panel", UIKit.inset(UIKit.SURFACE, UIKit.RADIUS_CARD, UIKit.SPACE_SM, UIKit.SPACE_SM))
	hold_drop.custom_minimum_size = Vector2(1580, HOLD_CARD.y + 30)
	hold_drop.set_drag_forwarding(Callable(), _can_drop_hold, _drop_hold)
	lower.add_child(hold_drop)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(1560, HOLD_CARD.y + 14)
	hold_drop.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.SPACE_SM)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(row)
	for c: int in _sorted_hold():
		var card: Button = PartCard.build(Run.db, state.cargo[c], HOLD_CARD, state.crew)
		var from: Dictionary = {"from": "hold", "index": c}
		card.set_drag_forwarding(_drag_from.bind(from), _can_drop_hold, _drop_hold)
		card.pressed.connect(_tap_source.bind(from))
		if _held == from:
			card.modulate = Color(1.2, 1.1, 0.7)
		row.add_child(card)
	if state.cargo.is_empty():
		row.add_child(_label("Empty. Salvage from fights and scrapyards lands here.", UIKit.SIZE_BODY, UIKit.TEXT_FAINT))
	lower.add_child(_scrap_bin())


## Hold indices in display order. Sorting never changes the hold, only how it is shown.
func _sorted_hold() -> Array[int]:
	var cargo: Array[String] = Run.state.cargo
	var order: Array[int] = []
	for c: int in cargo.size():
		order.append(c)
	var parts: Dictionary = Run.db.parts
	match _sort:
		"NEWEST":
			order.reverse()
		"RARITY":
			order.sort_custom(func(a: int, b: int) -> bool:
				var ra: int = int((parts.get(cargo[a], {}) as Dictionary).get("rarity", 1))
				var rb: int = int((parts.get(cargo[b], {}) as Dictionary).get("rarity", 1))
				return ra > rb or (ra == rb and a > b))
		"SLOT":
			order.sort_custom(func(a: int, b: int) -> bool:
				var sa: int = SLOT_ORDER.find(String((parts.get(cargo[a], {}) as Dictionary).get("slot", "")))
				var sb: int = SLOT_ORDER.find(String((parts.get(cargo[b], {}) as Dictionary).get("slot", "")))
				return sa < sb or (sa == sb and a > b))
	return order


func _scrap_bin() -> Control:
	var bin := PanelContainer.new()
	bin.custom_minimum_size = Vector2(240, HOLD_CARD.y + 30)
	var style := UIKit.inset(UIKit.SURFACE_SUNK, UIKit.RADIUS_CARD, UIKit.SPACE_MD, UIKit.SPACE_SM)
	style.border_color = UIKit.RED.darkened(0.2)
	style.set_border_width_all(2)
	bin.add_theme_stylebox_override("panel", style)
	bin.set_drag_forwarding(Callable(), _can_drop_bin, _drop_bin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bin.add_child(box)
	box.add_child(_label("SCRAP", UIKit.SIZE_DISPLAY, UIKit.RED, UIKit.font_display()))
	var value: String = "Drop a part here to break it down.\nCommon 3 · Uncommon 6 · Rare 10"
	if not _held.is_empty():
		value = "Break down %s for +%d scrap" % [PartText.name_of(Run.db.parts, _held_part()), RunSim.scrap_value(Run.setup, _held_part())]
	var text := _label(value, UIKit.SIZE_LABEL, UIKit.TEXT_DIM)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(210, 0)
	box.add_child(text)
	var tap := _button("SCRAP IT", UIKit.secondary(), UIKit.RED, Vector2(180, 44))
	tap.visible = not _held.is_empty()
	tap.pressed.connect(func() -> void: _drop_bin(Vector2.ZERO, _held))
	box.add_child(tap)
	return bin


# --- Actions ------------------------------------------------------------------

func _select(i: int) -> void:
	# A held part stays held: pick it up here, switch machine, tap its socket there.
	if i == selected:
		return
	selected = i
	_yaw = REST_YAW
	_yaw_goal = REST_YAW
	Audio.play("ui_confirm", -16.0)
	_rebuild()


func _level_up() -> void:
	_after(Run.apply([RunSim.LEVEL_UP, selected]), "%s levelled up." % String(Run.state.crew[selected]["name"]))


func _drag_from(_at: Vector2, source: Dictionary) -> Variant:
	_held = source
	set_drag_preview(_label(PartText.name_of(Run.db.parts, _held_part()), UIKit.SIZE_HEADING, UIKit.AMBER, UIKit.font_strong()))
	_restyle_sockets.call_deferred()
	return source


func _can_drop_socket(_at: Vector2, data: Variant, i: int, s: int) -> bool:
	if not (data is Dictionary):
		return false
	var ok: bool = _fits(data, i, s)
	if ok and _status != null:
		var current: String = String(Run.state.crew[i]["parts"][s])
		_status.text = "Fit %s as %s's %s%s" % [PartText.name_of(Run.db.parts, _part_of(data)), Run.state.crew[i]["name"],
			SOCKET_NAMES[s].to_lower(), "" if current.is_empty() else " (the %s goes to the hold)" % PartText.name_of(Run.db.parts, current)]
	return ok


func _drop_socket(_at: Vector2, data: Variant, i: int, s: int) -> void:
	var from: Dictionary = data
	var ok: bool
	if String(from["from"]) == "hold":
		ok = Run.apply([RunSim.REFIT, i, s, int(from["index"])])
	else:
		# Socket to socket: through the hold, as two ordinary refits.
		ok = Run.apply([RunSim.REFIT, int(from["crew"]), int(from["socket"]), -1]) \
			and Run.apply([RunSim.REFIT, i, s, Run.state.cargo.size() - 1])
	_after(ok, "Fitted." if ok else "That part does not fit there.")


## A crew tab takes a part too: it goes in the first socket on that machine that fits,
## an empty one first.
func _can_drop_tab(_at: Vector2, data: Variant, i: int) -> bool:
	return data is Dictionary and _tab_socket(data, i) >= 0


func _drop_tab(at: Vector2, data: Variant, i: int) -> void:
	var s: int = _tab_socket(data, i)
	if s >= 0:
		selected = i
		_drop_socket(at, data, i, s)


func _tab_socket(data: Dictionary, i: int) -> int:
	var best: int = -1
	for s: int in 5:
		if not _fits(data, i, s):
			continue
		if String(Run.state.crew[i]["parts"][s]).is_empty():
			return s
		if best < 0 or s == 3:
			best = s
	return best


func _can_drop_hold(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and String((data as Dictionary).get("from", "")) == "socket"


func _drop_hold(_at: Vector2, data: Variant) -> void:
	var from: Dictionary = data
	_after(Run.apply([RunSim.REFIT, int(from["crew"]), int(from["socket"]), -1]), "Moved to the hold.")


func _can_drop_bin(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and not (data as Dictionary).is_empty()


func _drop_bin(_at: Vector2, data: Variant) -> void:
	var from: Dictionary = data
	var part: String = _part_of(from)
	var ok: bool
	if String(from["from"]) == "hold":
		ok = Run.apply([RunSim.SCRAP_PART, int(from["index"])])
	else:
		ok = Run.apply([RunSim.REFIT, int(from["crew"]), int(from["socket"]), -1]) \
			and Run.apply([RunSim.SCRAP_PART, Run.state.cargo.size() - 1])
	_after(ok, "Broke down %s for %d scrap." % [PartText.name_of(Run.db.parts, part), RunSim.scrap_value(Run.setup, part)])


func _tap_source(source: Dictionary) -> void:
	_held = {} if _held == source else source
	Audio.play("ui_confirm", -14.0)
	_rebuild()


func _tap_socket(i: int, s: int) -> void:
	if not _held.is_empty() and _fits(_held, i, s):
		_drop_socket(Vector2.ZERO, _held, i, s)
		return
	if not String(Run.state.crew[i]["parts"][s]).is_empty() and s != 0:
		_tap_source({"from": "socket", "crew": i, "socket": s})


# --- Helpers ------------------------------------------------------------------

func _after(ok: bool, message: String) -> void:
	_held = {}
	Audio.play("ui_confirm" if ok else "ui_deny", -10.0)
	_message = message if ok else "Not possible: " + message
	# Deferred: this may run inside a drop callback, and rebuilding now would free the
	# nodes the engine is still delivering the drop through.
	_rebuild.call_deferred()


## Restyles the sockets in place. Rebuilding under an active drag would free the very node
## being dragged, so a drag only restyles.
func _restyle_sockets() -> void:
	for entry: Array in _sockets:
		var button: Button = entry[0]
		if not is_instance_valid(button):
			continue
		button.add_theme_stylebox_override("normal", _socket_style(int(entry[1]), int(entry[2])))


func _socket_style(i: int, s: int, hover: bool = false) -> StyleBoxFlat:
	var fits: bool = not _held.is_empty() and _fits(_held, i, s)
	var style := UIKit.inset(UIKit.SURFACE_HIGH if fits or hover else UIKit.SURFACE, UIKit.RADIUS_CONTROL, UIKit.SPACE_MD, UIKit.SPACE_SM)
	if fits or hover:
		style.border_color = UIKit.AMBER
		style.set_border_width_all(2)
	elif _held == {"from": "socket", "crew": i, "socket": s}:
		style.border_color = UIKit.BLUE
		style.set_border_width_all(2)
	return style


func _fits(data: Dictionary, i: int, s: int) -> bool:
	if data.is_empty() or not bool(Run.state.crew[i]["alive"]):
		return false
	if String(data["from"]) == "socket" and int(data["crew"]) == i and int(data["socket"]) == s:
		return false
	var part: String = _part_of(data)
	return String((Run.db.parts.get(part, {}) as Dictionary).get("slot", "")) == RunSetup.socket_slot(s)


func _held_part() -> String:
	return _part_of(_held)


func _part_of(data: Dictionary) -> String:
	if data.is_empty():
		return ""
	if String(data["from"]) == "hold":
		var index: int = int(data["index"])
		return Run.state.cargo[index] if index < Run.state.cargo.size() else ""
	return String(Run.state.crew[int(data["crew"])]["parts"][int(data["socket"])])


func _status_text() -> String:
	if not _held.is_empty():
		return "Holding %s: tap a lit socket (or a crew tab), or SCRAP IT." % PartText.name_of(Run.db.parts, _held_part())
	return "Drag a part onto a socket or a crew tab to fit it; onto SCRAP to break it down. Hover a part to see it on the machine."


func _find(node: Node, name: String) -> Node3D:
	if node.name == name and node is Node3D:
		return node as Node3D
	for child: Node in node.get_children():
		var found: Node3D = _find(child, name)
		if found != null:
			return found
	return null


func _label(text: String, font_size: int, colour: Color, face: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	if face != null:
		label.add_theme_font_override("font", face)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, style: StyleBoxFlat, ink: Color, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", UIKit.font_strong())
	button.add_theme_font_size_override("font_size", UIKit.SIZE_HEADING)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, ink)
	for key: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(key, style)
	return button
