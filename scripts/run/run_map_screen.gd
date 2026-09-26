extends Control

## The region map: a 3D yard (`YardView`) under a thin layer of interface.
##
## Play-tests 3 and 4 rebuilt it twice. Now:
##   - the yard is a place: landmarks, roads, fog over everything not yet scouted, and the
##     Reclaimer as a wall you watch advance, its ghost standing where it will be next;
##   - the crew stands on the map and walks the road when it travels; the camera follows it
##     (drag, keys and the wheel to look around; C to come back);
##   - ONE click travels. Hovering (PC) shows what a site is and what the move costs; the
##     direction and any cost are also written on the site itself, for touch;
##   - how the Reclaimer moves is a GAUGE, not a sentence: a pip per move, the last one
##     pulsing when your next move brings it;
##   - a dock of crew portraits (the real machines, levels and all) opens the garage;
##   - the story: a briefing on a new run, the act and mission on screen, site text and
##     endings in the world's voice (`data/run/story.json`).
##
## Reads `Run.state`; changes it only through `Run.apply`.

const GaragePanel := preload("res://scripts/run/garage_panel.gd")
const AssemblyPanel := preload("res://scripts/run/assembly_panel.gd")
const TunePanel := preload("res://scripts/run/tune_panel.gd")

const SITE_NAMES: Dictionary = {"start": "CAMP", "skirmish": "FIGHT", "elite": "ELITE",
	"scrapyard": "SCRAPYARD", "workshop": "WORKSHOP", "boss": "THE GATE"}
const RECLAIMER_RED := Color("ff5a3d")

var _yard: YardView
var _labels: Control
var _site_labels: Dictionary = {}     # id -> Control
var _preview: PanelContainer
var _gauge_pips: HBoxContainer
var _ground_chip: PanelContainer
var _scrap_label: Label
var _garage_button: Button
var _warning: PanelContainer
var _dock: VBoxContainer
var _portraits: Array[MachinePortrait] = []
var _overlay: Control
var _garage: Control
## The workshop's TUNE bench (011), open over the workshop panel.
var _tuner: Control
var _hover: int = -1
## Left-button press on the map: a click if it ends where it began, a pan if it moved.
var _press_at := Vector2(-1, -1)
var _panning: bool = false
var _drag_pan: bool = false
## True while the crew walks a road: the map takes no input until they arrive.
var _busy: bool = false


func _ready() -> void:
	UIKit.apply(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not Run.active and not Run.continue_run():
		Run.new_run()
	_yard = YardView.new()
	add_child(_yard)
	_yard.build(Run.state, int((Run.setup.rules.get("region", {}) as Dictionary).get("columns", 9)),
		int((Run.setup.rules.get("front", {}) as Dictionary).get("every", 2)), Run.db)
	# Every part model starts loading now, so the garage never waits for one.
	ConstructView.warm(Run.db.parts.keys())
	_labels = Control.new()
	_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_labels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_labels)
	_build_top_bar()
	_build_crew_dock()
	var hint := _label("Click a site to go  ·  drag to look around  ·  wheel to zoom  ·  C to come back",
		UIKit.SIZE_LABEL, UIKit.TEXT_FAINT)
	hint.position = Vector2(760, 1080 - 44)
	add_child(hint)
	_preview = PanelContainer.new()
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.add_theme_stylebox_override("panel", UIKit.card(UIKit.SURFACE))
	_preview.custom_minimum_size = Vector2(380, 0)
	_preview.visible = false
	add_child(_preview)
	_refresh()


# --- Input: hover previews, one click travels ---------------------------------

func _gui_input(event: InputEvent) -> void:
	if _overlay != null or _garage != null or _busy:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_LEFT:
				if button.pressed:
					_press_at = button.position
					_panning = false
				else:
					if not _panning and _press_at.x >= 0.0:
						var id: int = _yard.pick(button.position)
						if id >= 0:
							_choose(id)
					_press_at = Vector2(-1, -1)
					_panning = false
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_drag_pan = button.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if button.pressed:
					_yard.zoom_by(-2.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					_yard.zoom_by(2.0)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var left_held: bool = (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
		if left_held and _press_at.x >= 0.0 and motion.position.distance_to(_press_at) > 10.0:
			_panning = true
		if _panning or _drag_pan:
			_yard.pan(motion.relative)
			return
		var over: int = _yard.pick(motion.position)
		if over != _hover:
			_hover = over
			_yard.refresh(Run.state, RunSim.destinations(Run.state), _hover)
			_show_preview()
	elif event is InputEventMagnifyGesture:
		_yard.zoom_by((1.0 - (event as InputEventMagnifyGesture).factor) * 20.0)
	elif event is InputEventPanGesture:
		_yard.pan(-(event as InputEventPanGesture).delta * 8.0)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_C:
		_yard.recentre()


## One click (or tap): travel there if the road allows. The crew walks the road first;
## whatever waits at the site opens when they arrive.
func _choose(id: int) -> void:
	if _busy:
		return
	if not RunSim.destinations(Run.state).has(id):
		if id != Run.state.current:
			Audio.play("ui_deny", -14.0)
		return
	var from: int = Run.state.current
	if not Run.apply([RunSim.TRAVEL, id]):
		Audio.play("ui_deny", -10.0)
		return
	Audio.play("ui_confirm", -12.0)
	_busy = true
	_hover = -1
	_preview.visible = false
	for child: Node in _labels.get_children():
		(child as CanvasItem).visible = false
	await _yard.travel(from, id)
	_busy = false
	_refresh()


func _process(_delta: float) -> void:
	# The camera moves now: keep every label on its site, and off the screen's furniture.
	for id: int in _site_labels:
		var label: Control = _site_labels[id]
		var at: Vector2 = _yard.label_pos(id)
		label.position = at + Vector2(-label.size.x * 0.5, 2)
		label.visible = not _busy and at.y > 120.0 and at.y < size.y - 60.0 and at.x > 360.0 and at.x < size.x + 40.0
	if not _busy and _overlay == null and _garage == null:
		var keys := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if keys != Vector2.ZERO:
			_yard.pan(-keys * 14.0)
	if _preview.visible and _hover >= 0:
		var at: Vector2 = _yard.screen_pos(_hover, 1.0) + Vector2(70, -80)
		at.x = minf(at.x, size.x - _preview.size.x - 20)
		at.y = clampf(at.y, 130, size.y - _preview.size.y - 170)
		_preview.position = at


# --- Top bar ------------------------------------------------------------------

func _build_top_bar() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.03, 0.035, 0.9)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.position = Vector2.ZERO
	shade.size = Vector2(1920, 118)
	add_child(shade)
	var act: Dictionary = _act()
	var title := _label("ACT 1  ·  %s" % String(act.get("name", "THE CRANE YARDS")), 44, UIKit.TEXT, UIKit.font_display())
	title.position = Vector2(40, 16)
	add_child(title)
	var mission := _label(String(act.get("mission", "")), UIKit.SIZE_BODY, UIKit.TEXT_DIM)
	mission.position = Vector2(42, 74)
	add_child(mission)

	# The Reclaimer as a gauge (play-test 4: "should not come from text"): its name, and one
	# pip per move of its step. Pips fill as you move; the last pulses when your next move
	# brings it forward -- and on the map its ghost pulses on the line it will take.
	var gauge := PanelContainer.new()
	var style := UIKit.card(Color("2a1210"))
	style.border_color = RECLAIMER_RED.darkened(0.3)
	style.set_border_width_all(2)
	gauge.add_theme_stylebox_override("panel", style)
	gauge.position = Vector2(760, 20)
	gauge.tooltip_text = "The Reclaimer takes one zone every %d moves. Each lit pip is one of your moves; when the last lights, it advances to its red ghost line." \
		% int((Run.setup.rules.get("front", {}) as Dictionary).get("every", 2))
	add_child(gauge)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.SPACE_MD)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge.add_child(row)
	row.add_child(_label(String((Run.db.story.get("reclaimer", {}) as Dictionary).get("name", "THE RECLAIMER")), UIKit.SIZE_TITLE,
		RECLAIMER_RED, UIKit.font_display()))
	_gauge_pips = HBoxContainer.new()
	_gauge_pips.add_theme_constant_override("separation", UIKit.SPACE_SM)
	_gauge_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge_pips.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_gauge_pips)
	_ground_chip = PanelContainer.new()
	_ground_chip.add_theme_stylebox_override("panel", UIKit.card(RECLAIMER_RED.darkened(0.6)))
	_ground_chip.position = Vector2(760, 92)
	_ground_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ground_chip.add_child(_label("IN RECLAIMED GROUND  ·  -%d HP EACH PER MOVE" % int((Run.setup.rules["front"] as Dictionary)["damage"]),
		UIKit.SIZE_LABEL, UIKit.TEXT, UIKit.font_strong()))
	add_child(_ground_chip)

	var right := HBoxContainer.new()
	right.position = Vector2(1320, 28)
	right.add_theme_constant_override("separation", UIKit.SPACE_LG)
	add_child(right)
	_scrap_label = _label("", UIKit.SIZE_TITLE, UIKit.TEXT, UIKit.font_numbers())
	_scrap_label.custom_minimum_size = Vector2(170, 0)
	right.add_child(_scrap_label)
	_garage_button = _button("GARAGE", UIKit.secondary(), UIKit.TEXT, Vector2(200, 56))
	_garage_button.pressed.connect(_open_garage.bind(0))
	right.add_child(_garage_button)
	var quit := _button("TITLE", UIKit.secondary(), UIKit.TEXT, Vector2(130, 56))
	quit.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))
	right.add_child(quit)

	_warning = PanelContainer.new()
	_warning.add_theme_stylebox_override("panel", UIKit.card(UIKit.RED.darkened(0.55)))
	_warning.position = Vector2(760, 140)
	_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_warning)


func _act() -> Dictionary:
	var acts: Array = Run.db.story.get("acts", [])
	return acts[0] if not acts.is_empty() else {}


func _refresh_gauge() -> void:
	for child: Node in _gauge_pips.get_children():
		child.queue_free()
	var every: int = maxi(1, int((Run.setup.rules["front"] as Dictionary)["every"]))
	var done: int = Run.state.moves % every
	for i: int in every:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(26, 26)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lit: bool = i < done
		var next: bool = i == done and done == every - 1
		var style := UIKit.plain(RECLAIMER_RED if lit else Color("1a0c0a"), 4)
		style.border_color = RECLAIMER_RED if (lit or next) else RECLAIMER_RED.darkened(0.5)
		style.set_border_width_all(2)
		pip.add_theme_stylebox_override("panel", style)
		_gauge_pips.add_child(pip)
		if next:
			# The one that fills on your next move, and brings it forward.
			var pulse := pip.create_tween().set_loops()
			pulse.tween_property(pip, "modulate", Color(1.6, 0.7, 0.6), 0.4)
			pulse.tween_property(pip, "modulate", Color(1, 1, 1), 0.4)
	_ground_chip.visible = Run.state.consumed(Run.state.current)


# --- Crew dock ----------------------------------------------------------------

func _build_crew_dock() -> void:
	_dock = VBoxContainer.new()
	_dock.position = Vector2(24, 140)
	_dock.add_theme_constant_override("separation", UIKit.SPACE_SM)
	add_child(_dock)


func _refresh_crew() -> void:
	# The portraits outlive the cards (each is a small studio worth keeping): lift them out
	# before the old cards go, then deal fresh cards around them.
	for portrait: MachinePortrait in _portraits:
		if portrait.get_parent() != null:
			portrait.get_parent().remove_child(portrait)
	for child: Node in _dock.get_children():
		_dock.remove_child(child)
		child.queue_free()
	for i: int in Run.state.crew.size():
		_dock.add_child(_crew_card(i))


## One machine in the dock: its portrait (the real model), name, level marks and HP as
## pips. Opens the garage on that machine.
func _crew_card(i: int) -> Control:
	var member: Dictionary = Run.state.crew[i]
	var alive: bool = bool(member["alive"])
	var card := Button.new()
	card.custom_minimum_size = Vector2(340, 124)
	card.focus_mode = Control.FOCUS_NONE
	var style := UIKit.card(Color(UIKit.SURFACE, 0.92))
	for key: String in ["normal", "pressed", "focus"]:
		card.add_theme_stylebox_override(key, style)
	var hover: StyleBoxFlat = style.duplicate()
	hover.border_color = UIKit.AMBER
	hover.set_border_width_all(2)
	card.add_theme_stylebox_override("hover", hover)
	card.tooltip_text = "Open %s in the garage" % String(member["name"])
	card.pressed.connect(_open_garage.bind(i))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UIKit.SPACE_SM)
	card.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, UIKit.SPACE_XS)
	while _portraits.size() <= i:
		_portraits.append(MachinePortrait.new(Vector2i(112, 112)))
	var portrait: MachinePortrait = _portraits[i]
	if portrait.get_parent() != null:
		portrait.get_parent().remove_child(portrait)
	row.add_child(portrait)
	portrait.show_machine(member["parts"], int(member.get("level", 0)), alive, i + 1)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", 2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(_label(String(member["name"]).to_upper(), UIKit.SIZE_HEADING, UIKit.TEXT if alive else UIKit.RED, UIKit.font_strong()))
	text.add_child(_level_marks(int(member.get("level", 0))))
	if alive:
		var full: int = RunSim.max_hp(Run.setup, member)
		text.add_child(_hp_pips(int(member["hp"]), full))
		text.add_child(_label("%d / %d HP" % [int(member["hp"]), full], UIKit.SIZE_LABEL, UIKit.TEXT_DIM, UIKit.font_numbers()))
	else:
		text.add_child(_label("WRECK · rebuild at a workshop", UIKit.SIZE_LABEL, UIKit.RED))
	return card


## Three marks, lit up to the machine's level.
func _level_marks(level: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var steps: int = maxi(3, ((Run.setup.rules.get("levels", {}) as Dictionary).get("costs", []) as Array).size())
	for n: int in steps:
		var mark := Panel.new()
		mark.custom_minimum_size = Vector2(22, 7)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.add_theme_stylebox_override("panel", UIKit.plain(UIKit.TEXT if n < level else UIKit.SURFACE_SUNK, 1))
		row.add_child(mark)
	var caption := _label("LV %d" % level if level > 0 else "", UIKit.SIZE_MICRO, UIKit.TEXT_DIM, UIKit.font_strong())
	row.add_child(caption)
	return row


## HP as a row of pips, one per point, so a glance counts it.
func _hp_pips(hp: int, full: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var low: bool = hp * 3 <= full
	var width: float = clampf(190.0 / float(maxi(1, full)) - 2.0, 5.0, 14.0)
	for n: int in full:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(width, 12)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var colour: Color = (UIKit.RED if low else UIKit.GREEN) if n < hp else UIKit.SURFACE_SUNK
		pip.add_theme_stylebox_override("panel", UIKit.plain(colour, 1))
		row.add_child(pip)
	return row


# --- Refresh ------------------------------------------------------------------

func _refresh() -> void:
	var state: RunState = Run.state
	_refresh_gauge()
	_scrap_label.text = "SCRAP %d" % state.scrap
	var over: bool = state.overfull()
	_garage_button.text = "GARAGE  %d/%d" % [state.cargo.size(), state.hold_size]
	for key: String in ["normal", "hover", "pressed", "focus"]:
		_garage_button.add_theme_stylebox_override(key, UIKit.primary() if over else UIKit.secondary())
	for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		_garage_button.add_theme_color_override(key, UIKit.BG if over else UIKit.TEXT)
	for child: Node in _warning.get_children():
		child.queue_free()
	_warning.visible = over
	if over:
		_warning.add_child(_label("HOLD OVERFULL (%d / %d): fit or scrap %d in the GARAGE before moving on" % [
			state.cargo.size(), state.hold_size, state.cargo.size() - state.hold_size], UIKit.SIZE_BODY, UIKit.TEXT))
	if _hover >= 0 and not RunSim.destinations(state).has(_hover) and _hover != state.current:
		_hover = -1
	_yard.refresh(state, RunSim.destinations(state), _hover)
	_yard.set_crew(state.crew)
	_build_site_labels()
	_refresh_crew()
	_show_preview()
	_show_overlay()


## Under every site: its name; for the ones you can reach, the direction and any cost.
func _build_site_labels() -> void:
	for child: Node in _labels.get_children():
		child.queue_free()
	_site_labels.clear()
	var state: RunState = Run.state
	var targets: Array[int] = RunSim.destinations(state)
	for site: Dictionary in state.sites:
		var id: int = int(site["id"])
		var known: bool = RunSim.revealed(state, id)
		if not known:
			continue   # under fog: nothing to label
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.custom_minimum_size = Vector2(170, 0)
		box.add_theme_constant_override("separation", 0)
		var name: String = String(SITE_NAMES.get(String(site["type"]), "?"))
		if bool(site["visited"]) and id != state.current and String(site["type"]) != "start":
			name += " · DONE"
		var reachable: bool = targets.has(id)
		box.add_child(_centred(name, UIKit.SIZE_LABEL, UIKit.TEXT if reachable or id == state.current else UIKit.TEXT_FAINT))
		if id == state.current:
			box.add_child(_centred("YOU ARE HERE", UIKit.SIZE_MICRO, UIKit.AMBER))
		elif reachable:
			box.add_child(_centred(_direction(id), UIKit.SIZE_MICRO, UIKit.BLUE.lightened(0.35)))
			var cost: String = _cost_tag()
			if not cost.is_empty():
				box.add_child(_centred(cost, UIKit.SIZE_MICRO, RECLAIMER_RED))
		_labels.add_child(box)
		_site_labels[id] = box


func _centred(text: String, font_size: int, colour: Color) -> Label:
	var label := _label(text, font_size, colour, UIKit.font_strong())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	return label


func _direction(to: int) -> String:
	var here: int = int(Run.state.site(Run.state.current)["col"])
	var there: int = int(Run.state.site(to)["col"])
	return "FORWARD" if there > here else ("SIDEWAYS" if there == here else "BACK")


## What any move from here costs, short enough to sit under a site. (Whether it brings the
## Reclaimer forward is shown by the gauge and its ghost, not written.)
func _cost_tag() -> String:
	var front: Dictionary = Run.setup.rules["front"]
	if Run.state.consumed(Run.state.current):
		return "-%d HP EACH" % int(front["damage"])
	return ""


## The hover card: what the site is, in the world's words, and what going there costs.
func _show_preview() -> void:
	for child: Node in _preview.get_children():
		child.queue_free()
	var state: RunState = Run.state
	_preview.visible = _hover >= 0 and _overlay == null
	if not _preview.visible:
		return
	var site: Dictionary = state.site(_hover)
	var known: bool = RunSim.revealed(state, _hover)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.SPACE_XS)
	_preview.add_child(box)
	var reachable: bool = RunSim.destinations(state).has(_hover)
	var head: String = String(SITE_NAMES.get(String(site["type"]), "?")) if known else "NOT SCOUTED"
	if reachable:
		head = "%s  ·  %s" % [_direction(_hover), head]
	box.add_child(_label(head, UIKit.SIZE_HEADING, UIKit.AMBER if reachable else UIKit.TEXT, UIKit.font_strong()))
	var text: String = String((Run.db.story.get("sites", {}) as Dictionary).get(String(site["type"]), "")) if known \
		else "Nobody has looked yet. You find out when you get there."
	if bool(site["visited"]) and _hover != state.current:
		text = "Already cleared. Nothing happens there now."
	box.add_child(_wrap(text, UIKit.SIZE_BODY, UIKit.TEXT, 340))
	if reachable:
		for line: String in _move_costs(_hover):
			box.add_child(_wrap(line, UIKit.SIZE_LABEL, RECLAIMER_RED, 340))
		box.add_child(_label("CLICK TO GO", UIKit.SIZE_LABEL, UIKit.BLUE.lightened(0.35), UIKit.font_strong()))
	elif _hover == state.current:
		box.add_child(_label("YOU ARE HERE", UIKit.SIZE_LABEL, UIKit.AMBER, UIKit.font_strong()))
	else:
		box.add_child(_label("No road from here.", UIKit.SIZE_LABEL, UIKit.TEXT_FAINT))


func _move_costs(to: int) -> PackedStringArray:
	var state: RunState = Run.state
	var front: Dictionary = Run.setup.rules["front"]
	var every: int = maxi(1, int(front["every"]))
	var out: PackedStringArray = []
	if state.consumed(state.current):
		out.append("Leaving reclaimed ground: every machine loses %d HP." % int(front["damage"]))
	if (state.moves + 1) % every == 0 and int(state.site(to)["col"]) <= state.front_col + 1:
		out.append("The Reclaimer will take that ground as you arrive: the next move out costs %d HP each." % int(front["damage"]))
	return out


# --- Site panels --------------------------------------------------------------

func _show_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	var state: RunState = Run.state
	if state.outcome != RunState.ONGOING:
		_run_over()
		return
	if not Run.briefed:
		_briefing()
		return
	if RunSim.can_assemble(state) and not Run.bay_seen:
		_assembly()
		return
	match String(state.pending.get("kind", "")):
		"fight":
			_fight_panel()
		"reward", "scrapyard":
			_pick_panel()
		"workshop":
			_workshop_panel()


func _modal(title: String, subtitle: String, width: float = 1100.0) -> VBoxContainer:
	_overlay = Control.new()
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.62)
	_overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.add_theme_stylebox_override("panel", UIKit.card(UIKit.SURFACE, UIKit.RADIUS_CARD, UIKit.SPACE_XXL, UIKit.SPACE_XL))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.SPACE_LG)
	panel.add_child(box)
	box.add_child(_label(title, UIKit.SIZE_DISPLAY, UIKit.TEXT, UIKit.font_display()))
	if not subtitle.is_empty():
		box.add_child(_wrap(subtitle, UIKit.SIZE_BODY, UIKit.TEXT_DIM, width - 100))
	_preview.visible = false
	return box


func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.SPACE_MD)
	parent.add_child(row)
	return row


## The assembly bay: the crew built from the bench before the first move.
func _assembly() -> void:
	_overlay = AssemblyPanel.new()
	add_child(_overlay)
	_preview.visible = false
	_overlay.done.connect(func() -> void:
		Run.bay_seen = true
		_refresh())


## The story, once, at the start of a run.
func _briefing() -> void:
	var brief: Dictionary = Run.db.story.get("briefing", {})
	var box := _modal(String(brief.get("title", "THE KEY")), "", 1000)
	for line: Variant in (brief.get("lines", []) as Array):
		box.add_child(_wrap(String(line), UIKit.SIZE_HEADING, UIKit.TEXT, 900))
	var go := _button(String(brief.get("go", "ROLL OUT")), UIKit.primary(), UIKit.BG, Vector2(280, 64))
	go.pressed.connect(func() -> void:
		Run.briefed = true
		_refresh())
	_row(box).add_child(go)


func _fight_panel() -> void:
	var state: RunState = Run.state
	var kind: String = String(state.pending["site_type"])
	var fight: Dictionary = state.pending["fight"]
	var titles: Dictionary = {"skirmish": "FIGHT", "elite": "ELITE FIGHT", "boss": String(_act().get("gate", "THE GATE"))}
	var enemies: PackedStringArray = []
	for spec: Dictionary in (fight["enemy"] as Array):
		var kind_name: String = String(spec.get("kind", ""))
		enemies.append(String(spec["name"]) + ((" (%s)" % kind_name.to_upper()) if not kind_name.is_empty() else ""))
	var objective: Dictionary = fight.get("objective", {"type": "rout"})
	var goals: Dictionary = {
		"rout": "ROUT: destroy every enemy.",
		"defend": "DEFEND: keep the salvage caches standing for %d rounds (or destroy every enemy). Each cache you save pays out scrap." % int(objective.get("rounds", 0)),
		"salvage": "SALVAGE: collect %d scrap piles before the enemy carries them off (or destroy every enemy)." % int(objective.get("need", 0)),
	}
	var flavour: String = String((Run.db.story.get("sites", {}) as Dictionary).get(kind, ""))
	var box := _modal(String(titles.get(kind, "FIGHT")),
		"%s\n\n%s\n\n%d enemies: %s.\nDamage your machines take here stays with them after the fight." % [
			flavour, String(goals.get(String(objective.get("type", "rout")), "")), enemies.size(), ", ".join(enemies)], 960)
	if Run.fight_actions.size() > 0:
		box.add_child(_label("This fight is in progress. It resumes where you left it.", UIKit.SIZE_BODY, UIKit.GOLD))
	var go := _button("ENTER FIGHT" if Run.fight_actions.is_empty() else "RESUME FIGHT", UIKit.primary(), UIKit.BG, Vector2(300, 64))
	go.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/combat.tscn"))
	_row(box).add_child(go)


func _pick_panel() -> void:
	var state: RunState = Run.state
	var scrapyard: bool = String(state.pending["kind"]) == "scrapyard"
	var note: String = ("Take one part into the hold, or strip the yard for scrap." if scrapyard else "Take one part off the wrecks.")
	note += "  Hold: %d / %d." % [state.cargo.size(), state.hold_size]
	if state.cargo.size() >= state.hold_size:
		note += "  It is full: you can still take a part, then fit or scrap something in the GARAGE before moving on."
	var box := _modal("SCRAPYARD" if scrapyard else "SALVAGE", note, 1240)
	var row := _row(box)
	var options: Array = state.pending["options"]
	for i: int in options.size():
		var card: Button = PartCard.build(Run.db, String(options[i]), Vector2(380, 236), state.crew)
		card.pressed.connect(_pick.bind(i))
		row.add_child(card)
	# 011: every salvage screen has a scrap alternative, so leaving the parts is a choice.
	var skip := _button("TAKE %d SCRAP INSTEAD" % int(state.pending.get("scrap", 0)) if int(state.pending.get("scrap", 0)) > 0
		else "LEAVE IT", UIKit.secondary(), UIKit.TEXT, Vector2(320, 60))
	skip.pressed.connect(_pick.bind(-1))
	_row(box).add_child(skip)


func _workshop_panel() -> void:
	var state: RunState = Run.state
	var shop: Dictionary = Run.setup.rules.get("workshop", {})
	var box := _modal("WORKSHOP", String((Run.db.story.get("sites", {}) as Dictionary).get("workshop", "")) + "  You have %d scrap." % state.scrap, 960)
	if RunSim.needs_repair(state, Run.setup):
		box.add_child(_offer("PATCH THE CREW  +%d HP EACH" % int(shop["repair_amount"]), int(shop["repair_cost"]), state.scrap, [RunSim.REPAIR]))
	else:
		box.add_child(_label("Every machine is in one piece.", UIKit.SIZE_BODY, UIKit.GREEN))
	for i: int in state.crew.size():
		var member: Dictionary = state.crew[i]
		if not bool(member["alive"]):
			box.add_child(_offer("REBUILD %s AT HALF HP (sockets empty)" % String(member["name"]).to_upper(),
				int(shop["rebuild_cost"]), state.scrap, [RunSim.REBUILD, i]))
	var tunable: Array = _tunable_costs()
	if not tunable.is_empty():
		var cheapest: int = tunable.min()
		var label: String = "TUNE A PART  ·  %s SCRAP" % (str(cheapest) if tunable.max() == cheapest else "%d-%d" % [cheapest, tunable.max()])
		if state.scrap < cheapest:
			box.add_child(_label("%s (you have %d)" % [label, state.scrap], UIKit.SIZE_BODY, UIKit.TEXT_FAINT))
		else:
			var tune := _button(label, UIKit.choice(), UIKit.TEXT, Vector2(700, 60))
			tune.pressed.connect(_open_tuner)
			box.add_child(tune)
	var expand: int = RunSim.expand_cost(state, Run.setup)
	if expand >= 0:
		box.add_child(_offer("MORE ROOM IN THE HOLD  %d TO %d" % [state.hold_size,
			state.hold_size + int((Run.setup.rules["hold"] as Dictionary)["expand_by"])], expand, state.scrap, [RunSim.EXPAND_HOLD]))
	var row := _row(box)
	var garage := _button("GARAGE", UIKit.secondary(), UIKit.TEXT, Vector2(180, 60))
	garage.pressed.connect(_open_garage.bind(0))
	row.add_child(garage)
	var leave := _button("MOVE ON", UIKit.primary(), UIKit.BG, Vector2(240, 60))
	leave.pressed.connect(func() -> void: _apply([RunSim.LEAVE]))
	row.add_child(leave)


## What tuning would cost for every part the crew or the hold could still have tuned.
func _tunable_costs() -> Array:
	var out: Array = []
	var ids: Array = Run.state.cargo.duplicate()
	for member: Dictionary in Run.state.crew:
		if bool(member["alive"]):
			ids.append_array(member["parts"])
	for id: Variant in ids:
		if PartTuning.can_tune(Run.db.parts, String(id)):
			out.append(RunSim.tune_cost(Run.setup, String(id)))
	return out


func _open_tuner() -> void:
	if _tuner != null:
		return
	_tuner = TunePanel.new()
	add_child(_tuner)
	_preview.visible = false
	_tuner.done.connect(func() -> void:
		_tuner.queue_free()
		_tuner = null
		_refresh())


func _offer(text: String, cost: int, scrap: int, action: Array) -> Control:
	if scrap < cost:
		return _label("%s  ·  %d SCRAP (you have %d)" % [text, cost, scrap], UIKit.SIZE_BODY, UIKit.TEXT_FAINT)
	var button := _button("%s  ·  %d SCRAP" % [text, cost], UIKit.choice(), UIKit.TEXT, Vector2(700, 60))
	button.pressed.connect(func() -> void: _apply(action))
	return button


func _run_over() -> void:
	var state: RunState = Run.state
	var won: bool = state.outcome == RunState.WON
	var endings: Dictionary = Run.db.story.get("endings", {})
	var ending: String = String(endings.get("won", "")) if won else (String(endings.get("gate_held", ""))
		if state.end_reason.begins_with("The gate held") else String(endings.get("wrecked", "")))
	var box := _modal("ACT 1 CLEARED" if won else "RUN OVER",
		"%s\n\n%d fights won  ·  %d moves  ·  %d scrap" % [ending if not ending.is_empty() else state.end_reason,
			state.fights_won, state.moves, state.scrap], 900)
	var row := _row(box)
	var title := _button("TITLE", UIKit.secondary(), UIKit.TEXT, Vector2(200, 64))
	title.pressed.connect(func() -> void:
		Run.end_run()
		get_tree().change_scene_to_file("res://scenes/main.tscn"))
	row.add_child(title)
	var again := _button("NEW RUN", UIKit.primary(), UIKit.BG, Vector2(260, 64))
	again.pressed.connect(func() -> void:
		Run.end_run()
		Run.new_run()
		get_tree().reload_current_scene())
	row.add_child(again)


# --- Actions ------------------------------------------------------------------

func _pick(index: int) -> void:
	_apply([RunSim.PICK, index])


func _open_garage(crew_index: int = 0) -> void:
	if _garage != null or not RunSim.can_refit(Run.state):
		return
	_garage = GaragePanel.new()
	if "selected" in _garage:
		_garage.set("selected", crew_index)
	add_child(_garage)
	_preview.visible = false
	_garage.closed.connect(func() -> void:
		_garage.queue_free()
		_garage = null
		_refresh())


func _apply(action: Array) -> void:
	if Run.apply(action):
		Audio.play("ui_confirm", -12.0)
		if int(action[0]) == RunSim.TRAVEL:
			_hover = -1
	else:
		Audio.play("ui_deny", -10.0)
	_refresh()


# --- Pieces -------------------------------------------------------------------

func _wrap(text: String, font_size: int, colour: Color, width: float) -> Label:
	var label := _label(text, font_size, colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	return label


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
