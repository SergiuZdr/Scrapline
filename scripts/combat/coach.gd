extends Control

## The shakedown's coach (012): one instruction at a time over a real fight, and a marker on
## the thing to click.
##
## It never plays the game and never computes an outcome. It reads the fight the scene is
## showing -- the state, what is selected, what is armed -- and moves to its next step when
## the thing it asked for has happened (`data/tutorial.json`: `until`). So the tutorial is
## the real rules with a guide on top, and cannot teach something the game does not do.

signal finished(to_run: bool)

const PANEL_WIDTH: float = 380.0

var _scene: Node
var _steps: Array = []
var _index: int = 0
## Events already in the stream when the current step began: "has it happened" only counts
## what came after.
var _since: int = 0
var _time: float = 0.0
var _panel: PanelContainer
var _count: Label
var _title: Label
var _text: RichTextLabel
var _buttons: HBoxContainer
var _outline: Panel


## `scene`: the combat scene; `tutorial`: `ContentDB.tutorial`.
func setup(scene: Node, tutorial: Dictionary) -> void:
	_scene = scene
	_steps = tutorial.get("steps", [])


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline = Panel.new()
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color(0, 0, 0, 0)
	ring.border_color = UIKit.AMBER
	ring.set_border_width_all(4)
	ring.set_corner_radius_all(4)
	_outline.add_theme_stylebox_override("panel", ring)
	_outline.visible = false
	add_child(_outline)

	_panel = PanelContainer.new()
	_panel.name = "coach_panel"
	# Ink & Rust (015): the coach is the narrator -- a comic caption box, pale yellow on ink.
	var style: InkBox = UIKit.ink_caption(UIKit.SPACE_LG, UIKit.SPACE_MD)
	style.border_width = 3.0
	style.shadow = Vector2(5, 5)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_KEEP_SIZE)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_right = -UIKit.SPACE_XL
	_panel.offset_bottom = -120
	_panel.offset_left = _panel.offset_right - PANEL_WIDTH
	_panel.offset_top = _panel.offset_bottom - 10
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.SPACE_SM)
	_panel.add_child(box)
	_count = _label("", UIKit.SIZE_LABEL, UIKit.INK_DIM, UIKit.font_comic())
	box.add_child(_count)
	_title = _label("", 26, UIKit.INK, UIKit.font_comic())
	box.add_child(_title)
	_text = Glossary.label("", UIKit.SIZE_BODY, UIKit.INK, _glossary(), PANEL_WIDTH - UIKit.SPACE_LG * 2,
		UIKit.font_strong(), UIKit.INK_LINK)
	box.add_child(_text)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", UIKit.SPACE_SM)
	box.add_child(_buttons)
	_show()


func _process(delta: float) -> void:
	_time += delta
	var target: Control = _button_target()
	_outline.visible = target != null
	if target != null:
		var rect: Rect2 = target.get_global_rect().grow(6.0)
		_outline.position = rect.position
		_outline.size = rect.size
		_outline.modulate.a = 0.55 + 0.45 * sin(_time * 6.0)


## Called by the scene whenever what it shows changes: after every action and refresh.
## Steps whose thing has happened are passed, possibly several at once.
func refresh() -> void:
	if _steps.is_empty():
		return
	var state: CombatState = _scene.get("_state")
	if state == null:
		return
	_since = mini(_since, state.events.size())
	var guard: int = 0
	while _index < _steps.size() - 1 and _met(_steps[_index]) and guard < _steps.size():
		_advance()
		guard += 1
	_show()


## Back to the first step (FIGHT AGAIN restarts the shakedown).
func restart() -> void:
	_index = 0
	_since = 0
	_show()


func current_id() -> String:
	return String((_steps[_index] as Dictionary).get("id", "")) if _index < _steps.size() else ""


func next_step() -> void:
	if _index >= _steps.size() - 1:
		finished.emit(true)
		return
	_advance()
	refresh()


func _advance() -> void:
	_index += 1
	var state: CombatState = _scene.get("_state")
	_since = state.events.size() if state != null else 0


func _met(step: Dictionary) -> bool:
	var state: CombatState = _scene.get("_state")
	match String(step.get("until", "next")):
		"selected":
			return int(_scene.get("_selected")) == int(step.get("unit", 0))
		"moved":
			return _happened(state, [GridEv.MOVED])
		"armed":
			return bool(_scene.get("_armed")) and int(_scene.get("_ability")) < 0
		"attacked":
			return _happened(state, [GridEv.ATTACK])
		"ability":
			return _happened(state, [GridEv.ABILITY])
		"prop":
			return _happened(state, [GridEv.PROP_BROKEN, GridEv.EXPLOSION]) or _barrel(state) == null
		"round":
			return state.round_number >= int(step.get("round", 2))
		"won":
			return state.outcome == CombatState.WON
	return false


## Whether one of the player's machines did one of `kinds` since the step began.
func _happened(state: CombatState, kinds: Array) -> bool:
	for i: int in range(_since, state.events.size()):
		var e: Array = state.events[i]
		if kinds.has(int(e[GridEv.F_KIND])) and int(e[GridEv.F_ACTOR]) >= 0 and int(e[GridEv.F_ACTOR]) < 10:
			return true
	return false


func _show() -> void:
	if _steps.is_empty() or _title == null:
		return
	var step: Dictionary = _steps[_index]
	var final: bool = bool(step.get("final", false))
	_count.text = "SHAKEDOWN  ·  %d / %d" % [_index + 1, _steps.size()]
	_title.text = String(step.get("title", ""))
	_text.text = Glossary.linkify(String(step.get("text", "")), _glossary())
	for child: Node in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	if final:
		_buttons.add_child(_button("START A RUN", Ink.ACTION, func() -> void: finished.emit(true)))
		_buttons.add_child(_button("TITLE", UIKit.PAPER_CARD, func() -> void: finished.emit(false)))
	elif String(step.get("until", "next")) == "next":
		_buttons.add_child(_button("NEXT", Ink.ACTION, next_step))
		_buttons.add_child(_button("SKIP TUTORIAL", UIKit.PAPER_CARD, func() -> void: finished.emit(false)))
	else:
		_buttons.add_child(_button("SKIP STEP", UIKit.PAPER_CARD, next_step))
		_buttons.add_child(_button("SKIP TUTORIAL", UIKit.PAPER_CARD, func() -> void: finished.emit(false)))
	if _scene.get("_state") != null:
		_scene.call("coach_point", _board_target())


## The hex the marker stands on, or null (a button, or nothing).
func _board_target() -> Variant:
	var step: Dictionary = _steps[_index]
	var point: Dictionary = step.get("point", {})
	var state: CombatState = _scene.get("_state")
	var selected: int = int(_scene.get("_selected"))
	if point.has("unit"):
		if point.has("then") and selected == int(point["unit"]):
			return null
		var u: GridUnit = state.unit(int(point["unit"]))
		return Vector2i(u.x, u.y) if u != null and u.alive else null
	if point.has("beside_enemy"):
		return _beside_enemy(state, selected)
	if point.has("enemy_near"):
		var foe: GridUnit = _nearest_enemy(state, selected)
		return Vector2i(foe.x, foe.y) if foe != null else null
	if point.has("prop"):
		return _barrel(state)
	if point.has("pile"):
		var cells: Array = state.piles.keys()
		cells.sort()
		return cells[0] if not cells.is_empty() else null
	return null


func _button_target() -> Control:
	if _steps.is_empty() or _index >= _steps.size():
		return null
	var point: Dictionary = (_steps[_index] as Dictionary).get("point", {})
	var kind: String = String(point.get("button", ""))
	if point.has("then") and int(_scene.get("_selected")) == int(point.get("unit", -1)):
		kind = String(point["then"])
	if kind.is_empty():
		return null
	return (_scene.get("_hud") as CombatHUD).control_for(kind)


## A hex the selected machine can walk to that stands next to an enemy: the closest one.
func _beside_enemy(state: CombatState, ref: int) -> Variant:
	var u: GridUnit = state.unit(ref) if ref >= 0 else null
	if u == null or not u.alive:
		return null
	var best: Variant = null
	var best_d: int = 1 << 20
	var cells: Array = CombatSim.reachable(state, ref).keys()
	cells.sort()
	for cell: Vector2i in cells:
		for foe: GridUnit in state.units:
			if foe.alive and foe.team == GridUnit.TEAM_ENEMY and Hex.distance(cell, Vector2i(foe.x, foe.y)) == 1:
				var d: int = Hex.distance(cell, Vector2i(u.x, u.y))
				if d < best_d:
					best_d = d
					best = cell
	return best


func _nearest_enemy(state: CombatState, ref: int) -> GridUnit:
	var u: GridUnit = state.unit(ref) if ref >= 0 else null
	var best: GridUnit = null
	var best_d: int = 1 << 20
	for foe: GridUnit in state.units:
		if not foe.alive or foe.team != GridUnit.TEAM_ENEMY:
			continue
		var d: int = Hex.distance(Vector2i(foe.x, foe.y), Vector2i(u.x, u.y)) if u != null else foe.ref
		if d < best_d:
			best_d = d
			best = foe
	return best


func _barrel(state: CombatState) -> Variant:
	var cells: Array = state.props.keys()
	cells.sort()
	for cell: Vector2i in cells:
		if String((state.props[cell] as Dictionary).get("kind", "")) == "barrel":
			return cell
	return null


func _glossary() -> Dictionary:
	var db: ContentDB = _scene.get("_db") if _scene != null else null
	return db.glossary if db != null else {}


func _label(text: String, size: int, colour: Color, face: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	if face != null:
		label.add_theme_font_override("font", face)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, fill: Color, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 46)
	button.add_theme_font_override("font", UIKit.font_comic())
	button.add_theme_font_size_override("font_size", UIKit.SIZE_HEADING)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, UIKit.INK)
	for key: String in ["normal", "hover", "focus"]:
		button.add_theme_stylebox_override(key, UIKit.ink_button(fill))
	button.add_theme_stylebox_override("pressed", UIKit.ink_button(fill, true))
	button.pressed.connect(on_press)
	return button
