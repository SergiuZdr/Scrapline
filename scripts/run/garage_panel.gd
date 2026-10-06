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
const VIEW_SIZE := Vector2i(600, 360)
## Width of the lines lettered over the bay (name, sets, perks, LEVEL UP), fitted to it.
const INFO_W: float = 560.0
## The layout (027, play-test 9: "the garage NEEDS a new design"): three columns over the hold --
## THE MACHINE (the bay, then its name, level and LEVEL UP), LOADOUT (its five sockets), and
## DETAILS (everything the fight will read off it; NUMBERS until play-test 11). Each answers one question.
const LOADOUT_W: float = 570.0
const NUMBERS_W: float = 600.0
## Play-test 10 ("issues with the panels' alignment"): one grid. Three captions on one line,
## three columns that start at COLUMN_TOP and end at COLUMN_BOTTOM, the hold under all three.
const CAPTION_Y: float = 106.0
const COLUMN_TOP: float = 146.0
const COLUMN_BOTTOM: float = 690.0
const COLUMN_X: Array = [40.0, 660.0, 1252.0]
## NUMBERS in sections at a readable size (play-test 10: "hard to read").
const NUM_HEAD: int = 22
const NUM_NAME: int = 20
const NUM_TEXT: int = 18

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
var _numbers: VBoxContainer
var _renaming: bool = false
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
## The stage's container, faded in once the machine is drawn: a SubViewport shows black
## until its first frame (play-test 4).
var _view: SubViewportContainer
## What the model on stage was built from; it is rebuilt only when this changes, not on
## every refresh of the panels around it.
var _model_key: String = ""
## True while a level-up plays, so a second press cannot start another over it.
var _celebrating: bool = false
## The perk pick (011), open between LEVEL UP and the level-up event.
var _picker: Control
var _stage_root: Control
## Play-test 8: the garage opens behind a cover until its machine has been drawn, so it is
## never an empty bay that fills in.
var _cover: Control


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
	stage.position = Vector2(COLUMN_X[0], COLUMN_TOP)
	var frame := UIKit.inset(Color("12151d"), 0, 0, 0)
	frame.set_border_width_all(3)
	stage.add_theme_stylebox_override("panel", frame)
	add_child(stage)
	_stage_root = stage
	var view := SubViewportContainer.new()
	_view = view
	view.modulate.a = 0.0
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

	# Under the bay, down to the columns' common foot: the name, the level, LEVEL UP.
	var info_top: float = COLUMN_TOP + float(VIEW_SIZE.y) + 6.0 + UIKit.SPACE_SM
	var info_card := PanelContainer.new()
	info_card.position = Vector2(COLUMN_X[0], info_top)
	info_card.custom_minimum_size = Vector2(float(VIEW_SIZE.x) + 6.0, COLUMN_BOTTOM - info_top)
	info_card.size = info_card.custom_minimum_size
	info_card.clip_contents = true
	info_card.add_theme_stylebox_override("panel", UIKit.ink_card(UIKit.PAPER_CARD, UIKit.SPACE_MD, UIKit.SPACE_SM, 4))
	add_child(info_card)
	_info = VBoxContainer.new()
	_info.mouse_filter = Control.MOUSE_FILTER_PASS
	_info.alignment = BoxContainer.ALIGNMENT_CENTER
	_info.add_theme_constant_override("separation", UIKit.SPACE_SM)
	info_card.add_child(_info)

	for caption: Array in [["THE MACHINE", COLUMN_X[0]], ["LOADOUT", COLUMN_X[1]], ["DETAILS", COLUMN_X[2]]]:
		var head := UIKit.on_page(_label(String(caption[0]), 24, UIKit.PAGE_TEXT, UIKit.font_comic()), 6)
		head.position = Vector2(float(caption[1]) + 2.0, CAPTION_Y)
		add_child(head)
	_right = VBoxContainer.new()
	_right.position = Vector2(COLUMN_X[1], COLUMN_TOP)
	_right.size = Vector2(LOADOUT_W, COLUMN_BOTTOM - COLUMN_TOP)
	_right.add_theme_constant_override("separation", 6)
	add_child(_right)
	var numbers := ScrollContainer.new()
	numbers.position = Vector2(COLUMN_X[2], COLUMN_TOP)
	numbers.custom_minimum_size = Vector2(NUMBERS_W + 28, COLUMN_BOTTOM - COLUMN_TOP)
	numbers.size = numbers.custom_minimum_size
	numbers.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(numbers)
	_numbers = VBoxContainer.new()
	_numbers.custom_minimum_size = Vector2(NUMBERS_W, COLUMN_BOTTOM - COLUMN_TOP)
	numbers.add_child(_numbers)

	_bottom = VBoxContainer.new()
	_bottom.position = Vector2(40, COLUMN_BOTTOM + UIKit.SPACE_MD)
	_bottom.size = Vector2(1840, 1080.0 - COLUMN_BOTTOM - UIKit.SPACE_MD - 16.0)
	_bottom.add_theme_constant_override("separation", UIKit.SPACE_SM)
	add_child(_bottom)

	_glow = StandardMaterial3D.new()
	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow.albedo_color = Color(1.0, 0.72, 0.25, 0.4)
	selected = clampi(selected, 0, Run.state.crew.size() - 1)
	_cover = _build_cover()
	_rebuild()
	Hints.show_once(self, "garage", Run.db, Vector2(1180, 700), 420)


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
	# A working bay, not a void (play-test 4: "the background of the robot looks empty"):
	# plated floor, a corrugated back wall, the service gantry and stacked scrap in the
	# shadows, two work lamps overhead and dust hanging in their light. The night HDRI
	# lights and reflects (art-sourcing.md, mode c); the camera never sees it.
	# Ink & Rust (016): the fight's light in the bay -- a flat night, one hard key from the
	# camera's left -- so a machine looks here exactly as it will on the board.
	var env := WorldEnvironment.new()
	env.environment = Ink.environment(Color("12151d"))
	viewport.add_child(env)
	viewport.add_child(Ink.key_light(Vector3(-34, -30, 0), 20.0))

	var floor_plane := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(14, 10)
	floor_plane.mesh = plane
	floor_plane.material_override = Ink.patterned(Color("20232b"), 2, Color("1a1d24"), 2.4, 0.22)
	viewport.add_child(floor_plane)
	var wall := MeshInstance3D.new()
	var slab := BoxMesh.new()
	slab.size = Vector3(14, 5, 0.2)
	wall.mesh = slab
	wall.position = Vector3(0, 2.4, -2.6)
	# Corrugated steel, drawn: vertical strokes on a dark wall.
	wall.material_override = Ink.patterned(Color("262a33"), 2, Color("1d2028"), 3.0, 0.32)
	viewport.add_child(wall)

	# The lift the machine stands on: a steel hex ringed with a lamp strip.
	_floor = MeshInstance3D.new()
	var lift := CylinderMesh.new()
	lift.top_radius = 0.95
	lift.bottom_radius = 1.0
	lift.height = 0.08
	lift.radial_segments = 6
	_floor.mesh = lift
	_floor.position.y = 0.04
	_floor.material_override = Ink.toon(Color("3d3e44"))
	Ink.line(_floor, Ink.LINE_WORLD)
	viewport.add_child(_floor)
	var strip := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.95
	torus.outer_radius = 1.0
	torus.ring_segments = 6
	torus.rings = 6
	strip.mesh = torus
	strip.scale = Vector3(1, 0.25, 1)
	strip.position.y = 0.08
	var lamp_glow: StandardMaterial3D = Ink.glow(Ink.PAPER, 0.6)
	strip.material_override = lamp_glow
	_floor.add_child(strip)

	for dressing: Array in [["service_gantry", Vector3(-2.4, 0, -1.9), 0.0, 0.62], ["container_0", Vector3(2.9, 0, -1.6), 70.0, 0.55],
			["tyre_stack_1", Vector3(-2.2, 0, -0.4), 0.0, 0.6], ["car_stack_1", Vector3(3.2, 0, 0.3), -30.0, 0.5]]:
		var prop: Node3D = Surfaces.kit(String(dressing[0]), 0.3)
		if prop != null:
			prop.position = dressing[1]
			prop.rotation_degrees.y = float(dressing[2])
			prop.scale = Vector3.ONE * float(dressing[3])
			Ink.dress_scenery(prop, 0.4)
			viewport.add_child(prop)

	# Two work lamps overhead: lit shades, not lights (the toon ramp is drawn by the key).
	for x: float in [-0.9, 0.9]:
		var shade := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.05
		cone.bottom_radius = 0.16
		cone.height = 0.12
		shade.mesh = cone
		shade.position = Vector3(x, 2.48, 0.6)
		shade.material_override = lamp_glow
		viewport.add_child(shade)

	var dust := CPUParticles3D.new()
	dust.amount = 60
	dust.lifetime = 8.0
	dust.preprocess = 8.0
	dust.local_coords = true
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(1.6, 1.2, 1.0)
	dust.gravity = Vector3(0, -0.01, 0)
	dust.initial_velocity_min = 0.01
	dust.initial_velocity_max = 0.05
	dust.direction = Vector3(1, 0.2, 0)
	dust.spread = 180.0
	dust.scale_amount_min = 0.008
	dust.scale_amount_max = 0.018
	var mote := QuadMesh.new()
	var mote_material := StandardMaterial3D.new()
	mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# Without this a billboard throws the particle's scale away and every mote is a 1 m
	# square -- which washed the whole bay out in blocky pale rectangles.
	mote_material.billboard_keep_scale = true
	mote_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote_material.albedo_color = Color(0.94, 0.89, 0.78, 0.3)
	mote.material = mote_material
	dust.mesh = mote
	dust.position = Vector3(0, 1.3, 0.2)
	viewport.add_child(dust)

	_pivot = Node3D.new()
	_pivot.position.y = 0.08
	viewport.add_child(_pivot)
	_camera = Camera3D.new()
	_camera.fov = 32.0
	viewport.add_child(_camera)
	_camera.current = true


func _rebuild_model() -> void:
	var member: Dictionary = Run.state.crew[selected]
	var key: String = "%d:%s:%d:%s" % [selected, ",".join(member["parts"]), int(member.get("level", 0)), member["alive"]]
	if key == _model_key and _model != null:
		return
	_model_key = key
	if _model != null:
		_model.queue_free()
	_model = ConstructView.build_parts(PackedStringArray(member["parts"]), Run.db, TEAM, int(member.get("level", 0)))
	Ink.dress_machine(_model, PackedStringArray(member["parts"]), Ink.YOURS)
	_pivot.add_child(_model)
	# Framed by the machine's own height, so a squat anchor and a tall marksman both fill
	# the stage; nudged right because the name sits over the left of it.
	var h: float = ConstructView.height_of(_model)
	_camera.position = Vector3(-0.3 * h, 0.62 * h + 0.15, 3.4 * h)
	_camera.look_at(Vector3(-0.28 * h, 0.5 * h, 0))
	if not bool(member["alive"]):
		_model.rotation_degrees = Vector3(0, 0, 78)
	_focus = -1
	_fade_in_stage.call_deferred()


## Shows the stage once the new machine has had a frame to be drawn: a fade, never a
## black square.
func _fade_in_stage() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if _view.modulate.a < 1.0:
		create_tween().tween_property(_view, "modulate:a", 1.0, 0.25)
	if _cover != null and is_instance_valid(_cover):
		var cover: Control = _cover
		_cover = null
		var fade := cover.create_tween()
		fade.tween_property(cover, "modulate:a", 0.0, 0.3)
		fade.tween_callback(cover.queue_free)


## The cover the garage opens behind: the bay's name on the page, over everything.
func _build_cover() -> Control:
	var cover := Control.new()
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = UIKit.BG
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := VBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := _page("GARAGE", UIKit.SIZE_DISPLAY, UIKit.PAGE_TEXT, UIKit.font_display(), 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(title)
	var line := _page("Bringing the crew up on the lifts...", UIKit.SIZE_BODY, UIKit.PAGE_TEXT, UIKit.font_strong())
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(line)
	return cover


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
		mesh.material_overlay = Ink.outline(Ink.LINE_ACT + 1.5, Ink.ACTION) if on else Ink.outline(Ink.LINE_MACHINE)
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
	for box: Node in [_header, _info, _right, _bottom, _numbers]:
		for child: Node in box.get_children():
			child.queue_free()
	_sockets = []
	_build_header()
	_build_info()
	_build_parts()
	_build_stats()
	_build_hold()
	_rebuild_model()


func _build_header() -> void:
	var state: RunState = Run.state
	_header.add_child(UIKit.caption_title("GARAGE", 44))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(30, 0)
	_header.add_child(gap)
	for i: int in state.crew.size():
		var member: Dictionary = state.crew[i]
		var level: int = int(member.get("level", 0))
		var text: String = String(member["name"]).to_upper() + ("  LV %d" % level if level > 0 else "")
		if not bool(member["alive"]):
			text += "  · WRECK"
		# The amber BORDER marks the selection; the lettering stays ink (amber text does not
		# read on paper).
		var tab := _button(text, UIKit.choice() if i == selected else UIKit.secondary(), UIKit.TEXT, Vector2(220, 60))
		tab.pressed.connect(_select.bind(i))
		tab.set_drag_forwarding(Callable(), _can_drop_tab.bind(i), _drop_tab.bind(i))
		_header.add_child(tab)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(spacer)
	var words := _button("?", UIKit.secondary(), UIKit.TEXT, Vector2(60, 60))
	words.name = "glossary_button"
	words.tooltip_text = "Glossary"
	words.pressed.connect(func() -> void: Glossary.open(self, Run.db.glossary))
	_header.add_child(words)
	_header.add_child(UIKit.on_page(_label("SCRAP %d" % state.scrap, 30, UIKit.PAGE_TEXT, UIKit.font_comic()), 8))
	var done := _button("BACK TO MAP", UIKit.primary(), UIKit.BG, Vector2(260, 64))
	done.pressed.connect(func() -> void: closed.emit())
	_header.add_child(done)


## Under the bay (027): the machine's name (RENAME), its level out of the top one, HP, and
## LEVEL UP with what the next level gives. Sets and perks are in NUMBERS.
func _build_info() -> void:
	var member: Dictionary = Run.state.crew[selected]
	var alive: bool = bool(member["alive"])
	var level: int = int(member.get("level", 0))
	var top_level: int = ((Run.setup.rules.get("levels", {}) as Dictionary).get("costs", []) as Array).size()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIKit.SPACE_SM)
	_info.add_child(head)
	if _renaming:
		var edit := LineEdit.new()
		edit.text = String(member["name"])
		edit.max_length = RunSim.NAME_MAX
		edit.custom_minimum_size = Vector2(300, 48)
		edit.add_theme_font_override("font", UIKit.font_comic())
		edit.add_theme_font_size_override("font_size", 30)
		for key: String in ["normal", "focus"]:
			edit.add_theme_stylebox_override(key, UIKit.ink_card(UIKit.PAPER, UIKit.SPACE_SM, 2, 3))
		edit.add_theme_color_override("font_color", UIKit.INK)
		edit.add_theme_color_override("caret_color", UIKit.INK)
		edit.text_submitted.connect(_rename)
		head.add_child(edit)
		edit.grab_focus.call_deferred()
		var ok := _button("SAVE", UIKit.choice(), UIKit.TEXT, Vector2(110, 48))
		ok.pressed.connect(func() -> void: _rename(edit.text))
		head.add_child(ok)
	else:
		head.add_child(UIKit.fit(_label(String(member["name"]).to_upper(), 36, UIKit.INK, UIKit.font_comic()), 300, 1, 20))
		var rename := _button("RENAME", UIKit.secondary(), UIKit.TEXT, Vector2(120, 44))
		rename.add_theme_font_size_override("font_size", 18)
		rename.pressed.connect(func() -> void:
			_renaming = true
			_rebuild())
		head.add_child(rename)
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", UIKit.SPACE_MD)
	_info.add_child(status)
	if not alive:
		status.add_child(_label("WRECK: rebuild it at a workshop", 22, UIKit.INK_RED, UIKit.font_comic()))
		return
	status.add_child(_label("LEVEL %d / %d" % [level, top_level], 22, UIKit.INK, UIKit.font_comic()))
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 3)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for n: int in top_level:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(26, 10)
		pip.color = Ink.ACTION if n < level else UIKit.PAPER_DIM
		pips.add_child(pip)
	status.add_child(pips)
	status.add_child(_label("%d / %d HP" % [int(member["hp"]), RunSim.max_hp(Run.setup, member)], 22, UIKit.INK, UIKit.font_comic()))
	var cost: int = RunSim.level_cost(Run.state, Run.setup, selected)
	var next: Dictionary = RunSim.next_level_bonus(Run.state, Run.setup, selected)
	var gain: String = "next level: %s, and one perk of three" % PartText.bonus_text(next)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", UIKit.SPACE_MD)
	_info.add_child(foot)
	if cost < 0:
		foot.add_child(_label("TOP LEVEL", 22, UIKit.INK_GREEN, UIKit.font_comic()))
	elif Run.state.scrap >= cost:
		var up := _button("LEVEL UP  ·  %d SCRAP" % cost, UIKit.choice(), UIKit.TEXT, Vector2(280, 48))
		up.tooltip_text = "Overhaul %s (%s)" % [String(member["name"]), gain]
		up.pressed.connect(_offer_perks)
		foot.add_child(up)
		foot.add_child(UIKit.fit(_label(gain, UIKit.SIZE_LABEL, UIKit.INK_GREEN, UIKit.font_strong()), INFO_W - 300, 2, 10))
	else:
		foot.add_child(UIKit.fit(_label("LEVEL UP  ·  %d SCRAP (you have %d)  ·  %s" % [cost, Run.state.scrap, gain],
			UIKit.SIZE_LABEL, UIKit.INK_DIM, UIKit.font_strong()), INFO_W, 2, 10))


## Renames the machine for this run and its crew's next (027).
func _rename(text: String) -> void:
	_renaming = false
	if not Run.rename(selected, text):
		_message = "A name is 1 to %d letters, digits, spaces or dashes." % RunSim.NAME_MAX
	_rebuild()


func _build_tabs() -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", UIKit.SPACE_SM)
	_right.add_child(tabs)
	for name: String in ["PARTS", "STATS"]:
		var tab := _button(name, UIKit.choice() if name == _tab else UIKit.secondary(), UIKit.TEXT, Vector2(180, 48))
		tab.pressed.connect(func() -> void:
			_tab = name
			_rebuild())
		tabs.add_child(tab)


# --- PARTS --------------------------------------------------------------------

func _build_parts() -> void:
	var alive: bool = bool(Run.state.crew[selected]["alive"])
	for s: int in 5:
		_right.add_child(_socket(selected, s, alive))


func _socket(i: int, s: int, alive: bool) -> Control:
	var part: String = String((Run.state.crew[i]["parts"] as Array)[s])
	var button := Button.new()
	button.custom_minimum_size = Vector2(LOADOUT_W, (COLUMN_BOTTOM - COLUMN_TOP - 6.0 * 4.0) / 5.0)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not alive
	_sockets.append([button, i, s])
	var style: InkBox = _socket_style(i, s)
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
	picture.custom_minimum_size = Vector2(70, 70)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var rarity: String = ""
	if not part.is_empty():
		rarity = "  ·  " + PartCard.RARITY_NAMES[clampi(int((Run.db.parts.get(part, {}) as Dictionary).get("rarity", 1)), 1, 4) - 1]
	# Play-test 8: both lines fitted to the row (`UIKit.fit`), whatever the part's name.
	text.add_child(UIKit.fit(_label("%s  ·  %s%s" % [SOCKET_NAMES[s], PartText.name_of(Run.db.parts, part) if not part.is_empty() else "EMPTY", rarity],
		20, PartText.rarity_colour(Run.db.parts, part) if not part.is_empty() else UIKit.RED, UIKit.font_comic()), LOADOUT_W - 220, 1, 13))
	text.add_child(UIKit.fit(_label(PartText.summary(Run.db.parts, part, Run.db.combat_abilities) if not part.is_empty()
		else "Drag %s %s here from the hold." % ["an" if RunSetup.socket_slot(s) == "arm" else "a", RunSetup.socket_slot(s)], UIKit.SIZE_LABEL, UIKit.TEXT_DIM), LOADOUT_W - 220, 2, 10))
	if not part.is_empty():
		row.add_child(_maker_tag(i, part))
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

## Every number of the machine, read off the unit the sim would field. Play-test 10 ("hard to
## read"): in sections -- STATS, WEAPONS, ABILITIES, then role, perks and sets -- each name in
## the comic face and each rule in full ink at NUM_TEXT, never a dim paragraph.
func _build_stats() -> void:
	var member: Dictionary = Run.state.crew[selected]
	var u: GridUnit = RunSim.preview_machine(Run.setup, member)
	var rules: Dictionary = Run.setup.combat_rules
	# On a paper card (016): ink text needs paper under it.
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", UIKit.card(UIKit.SURFACE, 0, UIKit.SPACE_LG, UIKit.SPACE_MD))
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_numbers.add_child(sheet)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", UIKit.SPACE_XS)
	sheet.add_child(body)
	var width: int = int(NUMBERS_W) - 44
	var words: Dictionary = Run.db.glossary

	var grid := GridContainer.new()
	grid.columns = 1
	grid.add_theme_constant_override("v_separation", 2)
	body.add_child(grid)
	var armor_types: Array = rules.get("armor_types", [])
	var damage_types: Array = rules.get("damage_types", [])
	_stat(grid, "HEALTH", u.max_hp, 24, "%d" % u.max_hp)
	_stat(grid, "MOVE", u.move, 6, "%d hexes" % u.move)
	_stat(grid, "HEAT CAP", u.heat_cap, 10, "%d" % u.heat_cap)
	_stat(grid, "VENT", u.vent, 4, "%d a turn" % u.vent)
	_stat(grid, "ARMOUR", u.armor, 3, "%d · %s" % [u.armor, String(armor_types[u.armor_type]) if u.armor_type < armor_types.size() else ""])
	_stat(grid, "DAMAGE", u.damage_bonus, 4, "+%d · %s" % [u.damage_bonus, String(damage_types[u.damage_type]) if u.damage_type < damage_types.size() else ""])

	if u.weapons.any(func(w: Dictionary) -> bool: return not bool(w["empty"])):
		_section(body, "WEAPONS")
	for w: Dictionary in u.weapons:
		if bool(w["empty"]):
			continue
		var shape: String = String(w["shape"])
		var reach: String = "melee" if shape == "melee" else ("lob %d-%d" % [int(w["range_min"]), int(w["range"])] if shape == "lob" else "shot %d" % int(w["range"]))
		if shape == "cone":
			reach = "flame cone"
		elif shape == "shield":
			reach = "shields an ally %d" % int(w["range"])
		elif shape == "sweep":
			reach = "flail (3 hexes)"
		elif shape == "mine":
			reach = "lays a mine %d-%d" % [int(w["range_min"]), int(w["range"])]
		var dmg: int = int(w["damage"]) + u.damage_bonus + (u.melee_bonus if shape == "melee" else 0)
		var types: Array = Run.setup.combat_rules.get("damage_types", [])
		var t: int = int(w.get("dtype", -1)) if int(w.get("dtype", -1)) >= 0 else u.damage_type
		var kind: String = (String(types[t]).to_upper() + " ") if t >= 0 and t < types.size() and shape != "shield" else ""
		var bits: PackedStringArray = [reach, "%d %sdamage" % [dmg, kind], "+%d heat" % CombatSim.attack_heat(u, w)]
		for key: String in ["pierce", "chain"]:
			if int(w.get(key, 0)) > 0:
				bits.append("%s %d" % [key, int(w[key])])
		for key: String in ["splash", "shove", "snare"]:
			if int(w.get(key, 0)) > 0:
				bits.append(key)
		body.add_child(UIKit.fit(_label(String(w["name"]).to_upper(), NUM_NAME, UIKit.INK, UIKit.font_comic()), width, 1, 14))
		body.add_child(Glossary.label("  ·  ".join(bits), NUM_TEXT, UIKit.TEXT, words, width, UIKit.font_strong()))

	if not u.abilities.is_empty():
		_section(body, "ABILITIES")
	for ability: Dictionary in u.abilities:
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", UIKit.SPACE_SM)
		body.add_child(head)
		head.add_child(_label(String(ability["name"]).to_upper(), NUM_NAME, UIKit.INK, UIKit.font_comic()))
		head.add_child(_label("%s  ·  COOLDOWN %d" % ["FREE" if bool(ability["free"]) else "USES THE ACTION", int(ability["cooldown"])],
			UIKit.SIZE_LABEL, Ink.RUST, UIKit.font_comic()))
		body.add_child(Glossary.label(String(ability.get("text", "")), NUM_TEXT, UIKit.TEXT, words, width))

	# Play-test 11 ("why does everyone have this text?"): the ROLE is the frame's, and every frame
	# of a role shares its trait -- say so, and say what the four roles are.
	_section(body, "ROLE")
	var role_names: Dictionary = {"brawler": "+1 damage with melee weapons and Charge", "line": "can move after attacking",
		"marksman": "+1 range on shots", "anchor": "cannot be shoved or dragged"}
	body.add_child(Glossary.label("%s  ·  %s (every %s frame)" % [u.role.to_upper(), String(role_names.get(u.role, "")), u.role.capitalize()],
		NUM_TEXT, UIKit.TEXT, words, width, UIKit.font_strong()))
	var extra: String = _role_note(u, String(role_names.get(u.role, "")))
	if not extra.is_empty():
		body.add_child(Glossary.label("From its parts and perks: " + extra, NUM_TEXT, UIKit.INK_GREEN, words, width))
	# Play-test 11: damage types, said where a player reads the machine -- what it hits hardest and
	# softest with, and what hits IT hardest and softest.
	_section(body, "DAMAGE TYPES")
	for line_text: String in _type_lines(u):
		body.add_child(Glossary.label(line_text, NUM_TEXT, UIKit.TEXT, words, width))
	var perks: Array = member.get("perks", [])
	if not perks.is_empty():
		_section(body, "PERKS")
	for id: Variant in perks:
		var perk: Dictionary = Run.db.perks.get(String(id), {})
		body.add_child(Glossary.label("%s  ·  %s" % [String(perk.get("name", id)).to_upper(), String(perk.get("text", ""))],
			NUM_TEXT, UIKit.INK_GREEN, words, width))
	var sets: PackedStringArray = PartText.set_lines(Run.db.parts, Run.db.makers, member["parts"])
	if not sets.is_empty():
		_section(body, "SETS")
	for line_text: String in sets:
		body.add_child(Glossary.label(line_text, NUM_TEXT, UIKit.INK_GREEN, words, width))


## A section's heading on the NUMBERS sheet, with an ink rule under it.
func _section(body: VBoxContainer, title: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, UIKit.SPACE_XS)
	body.add_child(gap)
	body.add_child(_label(title, NUM_HEAD, UIKit.INK, UIKit.font_comic()))
	var rule := ColorRect.new()
	rule.color = UIKit.INK
	rule.custom_minimum_size = Vector2(0, 2)
	body.add_child(rule)


## Who made a part, and how many of that maker's parts the machine carries: three pips that
## turn green once two or more make a set (011).
func _maker_tag(i: int, part: String) -> Control:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size = Vector2(104, 0)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var maker: String = String((Run.db.parts.get(part, {}) as Dictionary).get("maker", ""))
	if maker.is_empty():
		return box
	var count: int = 0
	for id: Variant in (Run.state.crew[i]["parts"] as Array):
		if String((Run.db.parts.get(String(id), {}) as Dictionary).get("maker", "")) == maker:
			count += 1
	var colour: Color = UIKit.GREEN if count >= 2 else UIKit.TEXT_DIM
	var name := _label(PartText.maker_short(Run.db.makers, Run.db.parts, part), UIKit.SIZE_LABEL, colour, UIKit.font_strong())
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(name)
	var pips := HBoxContainer.new()
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.alignment = BoxContainer.ALIGNMENT_END
	pips.add_theme_constant_override("separation", 4)
	for n: int in 3:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(20, 6)
		pip.color = colour if n < count else UIKit.SURFACE_SUNK
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
	box.add_child(pips)
	return box


## What the machine has of the role traits BEYOND its own role's (a module or a perk can lend
## one): "" when nothing.
func _role_note(u: GridUnit, own: String) -> String:
	var bits: PackedStringArray = []
	var melee_from_role: int = 1 if u.role == "brawler" else 0
	if u.melee_bonus > melee_from_role:
		bits.append("+%d melee damage" % (u.melee_bonus - melee_from_role))
	if u.unshovable and u.role != "anchor":
		bits.append("cannot be shoved")
	if u.move_after_attack and u.role != "line":
		bits.append("can move after attacking")
	return ", ".join(bits)


## "DEALS EMP: strong against shielded (x1.3), weak against composite (x0.7)" and the same for
## what hits its armour -- from the wheel the fight uses (`balance.json` effectiveness).
func _type_lines(u: GridUnit) -> PackedStringArray:
	var types: Array = Run.setup.combat_rules.get("damage_types", [])
	var armours: Array = Run.setup.combat_rules.get("armor_types", [])
	var wheel: Array = Run.setup.wheel
	var out: PackedStringArray = []
	if u.damage_type < wheel.size():
		var row: Array = wheel[u.damage_type]
		var strong: PackedStringArray = []
		var weak: PackedStringArray = []
		for a: int in row.size():
			if int(row[a]) > 100:
				strong.append("%s armour (x%.1f)" % [armours[a], float(row[a]) / 100.0])
			elif int(row[a]) < 100:
				weak.append("%s armour (x%.1f)" % [armours[a], float(row[a]) / 100.0])
		out.append("DEALS %s: strong against %s, weak against %s." % [String(types[u.damage_type]).to_upper(),
			", ".join(strong), ", ".join(weak)])
	for w: Dictionary in u.weapons:
		var own: int = int(w.get("dtype", -1))
		if not bool(w["empty"]) and own >= 0 and own != u.damage_type:
			out.append("(%s deals %s whatever the core.)" % [String(w["name"]), String(types[own]).to_upper()])
	var harder: PackedStringArray = []
	var softer: PackedStringArray = []
	for t: int in wheel.size():
		var pct: int = int((wheel[t] as Array)[u.armor_type])
		if pct > 100:
			harder.append(String(types[t]))
		elif pct < 100:
			softer.append(String(types[t]))
	out.append("ITS %s ARMOUR: %s hits it harder, %s softer." % [String(armours[u.armor_type]).to_upper(), ", ".join(harder), ", ".join(softer)])
	return out


func _stat(grid: GridContainer, name: String, value: int, top: int, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.SPACE_SM)
	row.custom_minimum_size = Vector2(NUMBERS_W - 50, 30)
	var label := _label(name, NUM_TEXT, UIKit.TEXT, UIKit.font_comic())
	label.custom_minimum_size = Vector2(130, 0)
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(170, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = top
	bar.value = clampi(value, 0, top)
	var well := UIKit.plain(UIKit.SURFACE_SUNK, 0)
	well.border_color = UIKit.HAIRLINE
	well.set_border_width_all(2)
	bar.add_theme_stylebox_override("background", well)
	bar.add_theme_stylebox_override("fill", UIKit.plain(Ink.YOURS, 0))
	row.add_child(bar)
	row.add_child(_label(text, NUM_TEXT, UIKit.TEXT, UIKit.font_numbers()))
	grid.add_child(row)


# --- The hold -----------------------------------------------------------------

func _build_hold() -> void:
	var state: RunState = Run.state
	var news: bool = not _held.is_empty() or not _message.is_empty()
	_status = _page(_message if _held.is_empty() and not _message.is_empty() else _status_text(),
		UIKit.SIZE_BODY, Ink.ACTION if news else UIKit.PAGE_TEXT, UIKit.font_strong())
	_message = ""
	_bottom.add_child(_status)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIKit.SPACE_SM)
	_bottom.add_child(head)
	var over: bool = state.overfull()
	head.add_child(_page("HOLD  %d / %d%s" % [state.cargo.size(), state.hold_size,
		"   OVER: fit or scrap %d before moving on" % (state.cargo.size() - state.hold_size) if over else ""],
		24, Ink.DANGER if over else UIKit.PAGE_TEXT, UIKit.font_comic()))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(30, 0)
	head.add_child(spacer)
	head.add_child(_page("SORT", UIKit.SIZE_LABEL, UIKit.PAGE_TEXT, UIKit.font_comic()))
	for sort: String in SORTS:
		var b := _button(sort, UIKit.choice() if sort == _sort else UIKit.secondary(), UIKit.TEXT, Vector2(120, 38))
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


## The scrap bin, which is also its own button (play-test 4): drop a part on it, or pick a
## part and click it. No separate SCRAP IT.
func _scrap_bin() -> Control:
	var bin := Button.new()
	bin.custom_minimum_size = Vector2(240, HOLD_CARD.y + 30)
	bin.focus_mode = Control.FOCUS_NONE
	var armed: bool = not _held.is_empty()
	var style := UIKit.inset(Ink.DANGER if armed else UIKit.SURFACE_SUNK, 0, UIKit.SPACE_MD, UIKit.SPACE_SM)
	style.border_color = UIKit.HAIRLINE if armed else UIKit.RED
	style.set_border_width_all(4)
	var hover: InkBox = style.duplicate()
	hover.bg_color = Ink.DANGER.lightened(0.15)
	hover.border_color = UIKit.HAIRLINE
	for key: String in ["normal", "pressed", "focus", "disabled"]:
		bin.add_theme_stylebox_override(key, style)
	bin.add_theme_stylebox_override("hover", hover)
	bin.tooltip_text = "Scrap the part you picked, or drop one here"
	bin.set_drag_forwarding(Callable(), _can_drop_bin, _drop_bin)
	bin.pressed.connect(func() -> void:
		if _held.is_empty():
			_message = "Pick a part first (click it in the hold or on the machine), then click SCRAP."
			_rebuild()
		else:
			_drop_bin(Vector2.ZERO, _held))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bin.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, UIKit.SPACE_MD)
	box.add_child(_label("SCRAP", UIKit.SIZE_DISPLAY, UIKit.TEXT if armed else UIKit.RED, UIKit.font_display()))
	var value: String = "Drop a part here, or pick one and click.\nCommon 3 · Uncommon 6 · Rare 10"
	if armed:
		value = "Click to break down %s for +%d scrap" % [PartText.name_of(Run.db.parts, _held_part()), RunSim.scrap_value(Run.setup, _held_part())]
	box.add_child(UIKit.fit(_label(value, UIKit.SIZE_LABEL, UIKit.TEXT if armed else UIKit.TEXT_DIM), 200, 4, 10))
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


## LEVEL UP opens the choice first (011): three perks, and the machine keeps one for the rest
## of the run. The level-up event plays after the pick, and names what was picked.
func _offer_perks() -> void:
	if _celebrating or _picker != null:
		return
	var offer: Array[String] = RunSim.perk_offer(Run.state, Run.setup, selected)
	var cost: int = RunSim.level_cost(Run.state, Run.setup, selected)
	if offer.is_empty() or cost < 0 or Run.state.scrap < cost:
		_after(false, "not enough scrap.")
		return
	var member: Dictionary = Run.state.crew[selected]
	var next: Dictionary = RunSim.next_level_bonus(Run.state, Run.setup, selected)
	_picker = Control.new()
	_picker.name = "perk_pick"
	add_child(_picker)
	_picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.74)
	_picker.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_picker.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.SPACE_LG)
	center.add_child(box)
	box.add_child(_page("%s  ·  LEVEL %d" % [String(member["name"]).to_upper(), int(member.get("level", 0)) + 1],
		UIKit.SIZE_DISPLAY, UIKit.PAGE_TEXT, UIKit.font_display(), 10))
	box.add_child(_page("%s for %d scrap, and it keeps ONE of these for the rest of the run." % [PartText.bonus_text(next), cost],
		UIKit.SIZE_BODY, UIKit.PAGE_TEXT, UIKit.font_strong()))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.SPACE_LG)
	box.add_child(row)
	for k: int in offer.size():
		row.add_child(_perk_card(k, offer[k]))
	var later := _button("NOT NOW", UIKit.secondary(), UIKit.TEXT, Vector2(220, 56))
	later.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	later.pressed.connect(_close_picker)
	box.add_child(later)
	Hints.show_once(_picker, "perks", Run.db, Vector2(40, 40))


## A perk as a card: its name, what it does, the numbers in the colour of a gain.
func _perk_card(k: int, id: String) -> Button:
	var perk: Dictionary = Run.db.perks.get(id, {})
	var card := Button.new()
	card.name = "perk_%d" % k
	card.custom_minimum_size = Vector2(430, 200)
	card.focus_mode = Control.FOCUS_NONE
	var style: InkBox = UIKit.choice()
	var hover: InkBox = style.duplicate()
	hover.bg_color = UIKit.SURFACE_HIGH.lightened(0.05)
	for key: String in ["normal", "pressed", "focus"]:
		card.add_theme_stylebox_override(key, style)
	card.add_theme_stylebox_override("hover", hover)
	var inner := VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", UIKit.SPACE_SM)
	card.add_child(inner)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, UIKit.SPACE_LG)
	inner.add_child(_label(String(perk.get("name", id)).to_upper(), 28, UIKit.TEXT, UIKit.font_comic()))
	var text := _label(String(perk.get("text", "")), UIKit.SIZE_BODY, UIKit.TEXT_DIM)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(390, 0)
	inner.add_child(text)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(spacer)
	inner.add_child(_label(PartText.bonus_text(perk.get("grid", {})).to_upper(), 22, UIKit.GREEN, UIKit.font_comic()))
	card.pressed.connect(_level_up.bind(k))
	return card


func _close_picker() -> void:
	if _picker != null:
		_picker.queue_free()
		_picker = null


func _level_up(choice: int) -> void:
	if _celebrating:
		return
	var member: Dictionary = Run.state.crew[selected]
	var gains: Dictionary = RunSim.next_level_bonus(Run.state, Run.setup, selected)
	var offer: Array[String] = RunSim.perk_offer(Run.state, Run.setup, selected)
	var old_scale: float = 1.0 + ConstructView.LEVEL_SCALE * float(int(member.get("level", 0)))
	_close_picker()
	if choice < 0 or choice >= offer.size() or not Run.apply([RunSim.LEVEL_UP, selected, choice]):
		_after(false, "not enough scrap.")
		return
	var perk: String = String((Run.db.perks.get(offer[choice], {}) as Dictionary).get("name", offer[choice]))
	_celebrating = true
	_message = "%s is now level %d: %s." % [String(member["name"]), int(member["level"]), perk]
	_rebuild()
	await _celebrate(int(member["level"]), gains, old_scale, perk)
	_celebrating = false


## The level-up, as an event (play-test 4: "doesn't sell the machine getting stronger").
## About a second and a half, all of it saying the same thing: a ratchet and a rising
## chord, a lamp flare, sparks from the shoulders, a ring of light sweeping up the frame,
## the frame swelling to its new size, the new armour arriving piece by piece, the camera
## leaning in, and a banner with what was gained. Input on the stage waits for it.
func _celebrate(level: int, gains: Dictionary, old_scale: float, perk: String = "") -> void:
	Audio.play("level_up", -5.0, 0.0)
	var h: float = ConstructView.height_of(_model)
	var viewport: SubViewport = _pivot.get_parent() as SubViewport
	var chassis: Node3D = _find(_model, "part_chassis")
	var fresh: Array[Node3D] = []
	for node: Node in _descendants(_model):
		if node is Node3D and node.has_meta("level_kit") and int(node.get_meta("level_kit")) == level:
			fresh.append(node)
			(node as Node3D).scale = Vector3.ONE * 0.01
	var new_scale: Vector3 = Vector3.ONE
	if chassis != null:
		new_scale = chassis.scale
		chassis.scale = new_scale * (old_scale / (1.0 + ConstructView.LEVEL_SCALE * float(level)))

	var flare := OmniLight3D.new()
	flare.light_color = Color("ffd08a")
	flare.omni_range = 3.0
	flare.light_energy = 0.0
	flare.position = Vector3(0, h * 0.7, 0.6)
	viewport.add_child(flare)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.46
	ring.mesh = torus
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.albedo_color = Color(1.0, 0.8, 0.45, 0.9)
	ring.material_override = ring_material
	ring.position.y = 0.05
	viewport.add_child(ring)
	var sparks := _sparks(h)
	viewport.add_child(sparks)
	sparks.emitting = true

	var go := create_tween().set_parallel(true)
	go.tween_property(flare, "light_energy", 5.0, 0.12)
	go.tween_property(flare, "light_energy", 0.0, 0.7).set_delay(0.12)
	go.tween_property(ring, "position:y", h * 1.05, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	go.tween_property(ring_material, "albedo_color:a", 0.0, 0.25).set_delay(0.45)
	go.tween_property(_pivot, "scale", Vector3.ONE * 1.1, 0.16).set_delay(0.18).set_trans(Tween.TRANS_BACK)
	go.tween_property(_pivot, "scale", Vector3.ONE, 0.5).set_delay(0.34).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if chassis != null:
		go.tween_property(chassis, "scale", new_scale, 0.45).set_delay(0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i: int in fresh.size():
		go.tween_property(fresh[i], "scale", Vector3.ONE, 0.3).set_delay(0.3 + 0.07 * float(i)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	go.tween_property(_camera, "fov", 27.0, 0.25).set_delay(0.15).set_trans(Tween.TRANS_SINE)
	go.tween_property(_camera, "fov", 32.0, 0.6).set_delay(0.9).set_trans(Tween.TRANS_SINE)
	_banner(level, gains, perk)
	await go.finished
	flare.queue_free()
	ring.queue_free()
	await get_tree().create_timer(0.6).timeout
	sparks.queue_free()


func _sparks(h: float) -> CPUParticles3D:
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.emitting = false
	sparks.amount = 46
	sparks.lifetime = 0.7
	sparks.explosiveness = 0.85
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sparks.emission_box_extents = Vector3(0.25, 0.1, 0.12)
	sparks.direction = Vector3(0, 1, 0)
	sparks.spread = 70.0
	sparks.initial_velocity_min = 1.2
	sparks.initial_velocity_max = 2.6
	sparks.gravity = Vector3(0, -6.0, 0)
	sparks.scale_amount_min = 0.012
	sparks.scale_amount_max = 0.026
	var dot := QuadMesh.new()
	var hot := StandardMaterial3D.new()
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hot.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	hot.billboard_keep_scale = true
	hot.albedo_color = Color(1.0, 0.8, 0.45)
	dot.material = hot
	sparks.mesh = dot
	sparks.position = Vector3(0, h * 0.68, 0.05)
	return sparks


## "LEVEL 2" over the stage, the gains -- and the perk it kept -- under it in the colour of a gain.
func _banner(level: int, gains: Dictionary, perk: String = "") -> void:
	var banner := VBoxContainer.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.alignment = BoxContainer.ALIGNMENT_CENTER
	var title := _label("LEVEL %d!" % level, 110, Ink.ACTION, UIKit.font_letters())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", UIKit.HAIRLINE)
	title.add_theme_constant_override("outline_size", 24)
	banner.add_child(title)
	var bits: PackedStringArray = []
	if int(gains.get("hp", 0)) > 0:
		bits.append("+%d HP" % int(gains["hp"]))
	if int(gains.get("damage", 0)) > 0:
		bits.append("+%d DAMAGE" % int(gains["damage"]))
	if not perk.is_empty():
		bits.append(perk.to_upper())
	# The level kit is plating on the model, not an armour stat: say so, or it reads as a gain.
	bits.append("NEW PLATING ON THE FRAME")
	var line := _label("  ·  ".join(bits), 30, Ink.GAIN, UIKit.font_comic())
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_color_override("font_outline_color", UIKit.HAIRLINE)
	line.add_theme_constant_override("outline_size", 12)
	banner.add_child(line)
	add_child(banner)
	banner.size = Vector2(VIEW_SIZE.x, 200)
	# Inside the stage: lower, its gains line ran over the machine's name card.
	banner.position = _stage_root.position + Vector2(0, VIEW_SIZE.y - banner.size.y)
	banner.pivot_offset = banner.size * 0.5
	banner.modulate.a = 0.0
	banner.scale = Vector2.ONE * 1.35
	var show := create_tween()
	show.tween_property(banner, "modulate:a", 1.0, 0.18).set_delay(0.25)
	show.parallel().tween_property(banner, "scale", Vector2.ONE, 0.3).set_delay(0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	show.tween_interval(1.0)
	show.tween_property(banner, "modulate:a", 0.0, 0.35)
	show.tween_callback(banner.queue_free)


func _descendants(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child: Node in node.get_children():
		out.append_array(_descendants(child))
	return out


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


func _socket_style(i: int, s: int, hover: bool = false) -> InkBox:
	var fits: bool = not _held.is_empty() and _fits(_held, i, s)
	var style := UIKit.inset(UIKit.SURFACE_HIGH if fits or hover else UIKit.SURFACE, 0, UIKit.SPACE_MD, UIKit.SPACE_SM)
	style.set_border_width_all(3)
	if fits or hover:
		style.border_color = UIKit.AMBER_DEEP
		style.set_border_width_all(5)
	elif _held == {"from": "socket", "crew": i, "socket": s}:
		style.border_color = UIKit.BLUE
		style.set_border_width_all(5)
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
		return "Holding %s: tap a lit socket (or a crew tab), or click SCRAP." % PartText.name_of(Run.db.parts, _held_part())
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
	label.add_theme_font_override("font", face if face != null else UIKit.font())
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## A label lettered on the dark page or over the bay: paper (or a signal) on an ink edge.
func _page(text: String, font_size: int, colour: Color, face: Font = null, outline: int = 6) -> Label:
	var label := UIKit.on_page(_label(text, font_size, colour, face), outline)
	label.add_theme_color_override("font_color", colour)
	return label


func _button(text: String, style: InkBox, ink: Color, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", UIKit.font_comic())
	button.add_theme_font_size_override("font_size", 22)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, ink)
	for key: String in ["normal", "hover", "focus"]:
		button.add_theme_stylebox_override(key, style)
	button.add_theme_stylebox_override("pressed", UIKit.pressed(style))
	return button
