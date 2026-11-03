extends Control

## The shakedown's coach (012): one instruction at a time over a real fight, and a marker on
## the thing to click.
##
## It never plays the game and never computes an outcome. It reads the fight the scene is
## showing -- the state, what is selected, what is armed -- and moves to its next step when
## the thing it asked for has happened (`data/tutorial.json`: `until`). So the tutorial is
## the real rules with a guide on top, and cannot teach something the game does not do.
##
## 088 (A15): a step's `point` may be a LIST of marks, shown one at a time -- the first one not yet
## done: pick the machine, walk to the ring, arm the weapon, then the enemy. A move ring never
## stands on a hex an enemy intent aims at (`aimed`): the coach would be walking you into the red.

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
## Over the board once the shakedown is skipped: the last card is all there is to press.
var _blocker: Control


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
	_blocker = ColorRect.new()
	_blocker.name = "coach_blocker"
	(_blocker as ColorRect).color = Color(0, 0, 0, 0.35)
	_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blocker.visible = false
	add_child(_blocker)

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
	if _blocker != null:
		_blocker.visible = false
	_show()


func current_id() -> String:
	return String((_steps[_index] as Dictionary).get("id", "")) if _index < _steps.size() else ""


func next_step() -> void:
	if _index >= _steps.size() - 1:
		finished.emit(true)
		return
	_advance()
	refresh()


## 088 (the user): SKIP on the first card ends the shakedown as if it were played -- the profile
## records it (played, and that it was skipped) and the last card offers the run or the title.
func skip() -> void:
	var profile: Node = get_tree().root.get_node_or_null("Profile") if is_inside_tree() else null
	if profile != null:
		profile.call("finish_tutorial")
		profile.call("mark_seen", "shakedown_skipped")
	_index = _steps.size() - 1
	_blocker.visible = true
	_show()


func _advance() -> void:
	_index += 1
	var state: CombatState = _scene.get("_state")
	_since = state.events.size() if state != null else 0


func _met(step: Dictionary) -> bool:
	var state: CombatState = _scene.get("_state")
	var unit: int = int(step.get("unit", -1))
	match String(step.get("until", "next")):
		"selected":
			return int(_scene.get("_selected")) == unit
		"moved":
			return _happened(state, [GridEv.MOVED], unit)
		"armed":
			return bool(_scene.get("_armed")) and int(_scene.get("_ability")) < 0 \
				and (unit < 0 or int(_scene.get("_selected")) == unit) \
				and (not step.has("weapon") or int(_scene.get("_weapon")) == int(step["weapon"]))
		"attacked":
			# The machine named has used its attack, whatever it hit: the step cannot wait forever.
			return _happened(state, [GridEv.ATTACK], unit) or (unit >= 0 and state.unit(unit) != null and state.unit(unit).acted)
		"ability":
			return _happened(state, [GridEv.ABILITY], unit)
		"heat_choice":
			# 088: heat is a choice -- paid (the ability), refused (fired without it), or vented.
			return _happened(state, [GridEv.ABILITY, GridEv.ATTACK, GridEv.VENTED], unit)
		"cancelled":
			# 087's INTENT_LOST: an enemy's standing intent was cancelled by one of the crew.
			return _cancelled(state)
		"fell":
			return _happened(state, [GridEv.FELL], unit) or (unit >= 0 and state.unit(unit) != null and state.unit(unit).acted)
		"torn":
			return _happened(state, [GridEv.PART_TORN], unit) or (unit >= 0 and state.unit(unit) != null and state.unit(unit).acted)
		"prop":
			return _happened(state, [GridEv.PROP_BROKEN, GridEv.EXPLOSION]) or _barrel(state) == null
		"round":
			return state.round_number >= int(step.get("round", 2))
		"won":
			return state.outcome == CombatState.WON
	return false


func _cancelled(state: CombatState) -> bool:
	for i: int in range(_since, state.events.size()):
		var e: Array = state.events[i]
		if int(e[GridEv.F_KIND]) == GridEv.INTENT_LOST and int(e[GridEv.F_TARGET]) >= 0 and int(e[GridEv.F_TARGET]) < 10:
			return true
	return false


## Whether one of the player's machines (`unit`, when one is named) did one of `kinds` since the
## step began.
func _happened(state: CombatState, kinds: Array, unit: int = -1) -> bool:
	for i: int in range(_since, state.events.size()):
		var e: Array = state.events[i]
		var actor: int = int(e[GridEv.F_ACTOR])
		if kinds.has(int(e[GridEv.F_KIND])) and actor >= 0 and actor < 10 and (unit < 0 or actor == unit):
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
	elif _index == 0:
		# 088 (the user): the first card can end the shakedown at once.
		_buttons.add_child(_button("NEXT", Ink.ACTION, next_step))
		_buttons.add_child(_button("SKIP", UIKit.PAPER_CARD, skip))
	elif String(step.get("until", "next")) == "next":
		_buttons.add_child(_button("NEXT", Ink.ACTION, next_step))
		_buttons.add_child(_button("SKIP TUTORIAL", UIKit.PAPER_CARD, skip))
	else:
		_buttons.add_child(_button("SKIP STEP", UIKit.PAPER_CARD, next_step))
		_buttons.add_child(_button("SKIP TUTORIAL", UIKit.PAPER_CARD, skip))
	if _scene.get("_state") != null:
		_scene.call("coach_point", _board_target())


## The mark showing now: of the step's marks (one, or a list), the first not yet done.
func current_mark() -> Dictionary:
	if _steps.is_empty() or _index >= _steps.size():
		return {}
	var point: Variant = (_steps[_index] as Dictionary).get("point", {})
	var marks: Array = point if point is Array else [point]
	for i: int in marks.size():
		var mark: Dictionary = marks[i]
		if i == marks.size() - 1 or not _mark_done(mark):
			return mark
	return {}


## Whether a mark's own little goal is reached, so the next mark in the list takes over.
func _mark_done(mark: Dictionary) -> bool:
	var state: CombatState = _scene.get("_state")
	var selected: int = int(_scene.get("_selected"))
	if mark.has("cell"):
		var u: GridUnit = state.unit(int(mark.get("unit", selected)))
		return u == null or not u.alive or u.moved or Vector2i(u.x, u.y) == _cell(mark["cell"])
	if mark.has("weapon"):
		return bool(_scene.get("_armed")) and int(_scene.get("_ability")) < 0 and int(_scene.get("_weapon")) == int(mark["weapon"])
	if mark.has("unit"):
		# Legacy form {unit, then: button}: the machine until it is picked, then the button.
		return selected == int(mark["unit"]) and not mark.has("then")
	return false


## The hex the marker stands on, or null (a button, or nothing).
func _board_target() -> Variant:
	var mark: Dictionary = current_mark()
	var state: CombatState = _scene.get("_state")
	var selected: int = int(_scene.get("_selected"))
	if mark.has("cell"):
		return _cell(mark["cell"])
	if mark.has("weapon") or mark.has("ability") or mark.has("button"):
		return null
	if mark.has("enemy"):
		var foe: GridUnit = state.unit(int(mark["enemy"]))
		return Vector2i(foe.x, foe.y) if foe != null and foe.alive else null
	if mark.has("unit"):
		if mark.has("then") and selected == int(mark["unit"]):
			return null
		var u: GridUnit = state.unit(int(mark["unit"]))
		return Vector2i(u.x, u.y) if u != null and u.alive else null
	if mark.has("beside_enemy"):
		return _beside_enemy(state, selected)
	if mark.has("enemy_near"):
		var near: GridUnit = _nearest_enemy(state, selected)
		return Vector2i(near.x, near.y) if near != null else null
	if mark.has("prop"):
		return _barrel(state)
	if mark.has("pile"):
		var cells: Array = state.pile_cells()
		return cells[0] if not cells.is_empty() else null
	return null


## Whether the marker is a MOVE ring (it stands on an empty hex the crew is told to walk to).
func is_move_ring() -> bool:
	var mark: Dictionary = current_mark()
	return mark.has("cell") or mark.has("beside_enemy")


## Every hex an enemy intent will hit if the turn ended now: the red the player is told to avoid.
static func aimed(state: CombatState) -> Dictionary:
	var out: Dictionary = {}
	var threats: Dictionary = CombatSim.threats(state)
	for ref: Variant in threats:
		var threat: Dictionary = threats[ref]
		if bool(threat["legal"]):
			for cell: Vector2i in (threat["tiles"] as Array):
				out[cell] = true
	return out


func _button_target() -> Control:
	var mark: Dictionary = current_mark()
	var hud: CombatHUD = _scene.get("_hud")
	if hud == null or mark.is_empty():
		return null
	if mark.has("weapon"):
		return _bar_button(hud.get("_weapon_bar"), int(mark["weapon"]))
	if mark.has("ability"):
		return _bar_button(hud.get("_ability_bar"), int(mark["ability"]))
	var kind: String = String(mark.get("button", ""))
	if mark.has("then") and int(_scene.get("_selected")) == int(mark.get("unit", -1)):
		kind = String(mark["then"])
	if kind.is_empty():
		return null
	return hud.control_for(kind)


## The `index`-th item button of one of the HUD's bars (weapons in arm order, abilities in order).
static func _bar_button(bar: Node, index: int) -> Control:
	if bar == null:
		return null
	var n: int = 0
	for child: Node in bar.get_children():
		if child is Button and child.has_meta("item") and not child.is_queued_for_deletion() \
				and (child as Button).is_visible_in_tree() and (child as Button).text.is_empty():
			if n == index:
				return child
			n += 1
	return null


static func _cell(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	return Vector2i(int((value as Array)[0]), int((value as Array)[1]))


## A hex the selected machine can walk to that stands next to an enemy: the closest one.
func _beside_enemy(state: CombatState, ref: int) -> Variant:
	var u: GridUnit = state.unit(ref) if ref >= 0 else null
	if u == null or not u.alive:
		return null
	var best: Variant = null
	var best_d: int = 1 << 20
	var cells: Array = CombatSim.reachable(state, ref).keys()
	cells.sort()
	var red: Dictionary = aimed(state)
	for cell: Vector2i in cells:
		if red.has(cell):
			continue
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
