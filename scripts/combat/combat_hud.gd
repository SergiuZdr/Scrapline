class_name CombatHUD
extends Control

## The fight's interface: crew cards, an info panel, the round banner, UNDO and END TURN.
##
## It only DISPLAYS. The combat scene hands it plain dictionaries and listens for its
## signals; nothing here reads the sim or decides anything.
##
## Built for touch first. Every control is at least 56 px tall at 1080p and nothing
## depends on hover. A mouse gets the same controls, plus keyboard shortcuts in the scene.

signal unit_card_pressed(ref: int)
signal undo_pressed
signal end_turn_pressed
signal rotate_pressed(step: int)
signal retry_pressed
signal title_pressed

const CARD_SIZE := Vector2(320, 118)
const PANEL_WIDTH: int = 360

var _banner: Label
var _cards: Dictionary = {}
var _card_column: VBoxContainer
var _info_title: Label
var _info_body: Label
var _hint: Label
var _undo: Button
var _end_turn: Button
var _result: Control
var _result_title: Label
var _result_body: Label


func _ready() -> void:
	UIKit.apply(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Every anchored child is added FIRST and anchored after: a preset applied to a node
	# outside the tree computes its offsets against a zero-size parent, which is what put
	# the banner half off the top-left corner in the first render.
	_banner = _label("", UIKit.SIZE_TITLE, UIKit.TEXT, UIKit.font_display())
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 38)
	add_child(_banner)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = UIKit.SPACE_LG

	_card_column = VBoxContainer.new()
	_card_column.position = Vector2(UIKit.SPACE_XL, 110)
	_card_column.add_theme_constant_override("separation", UIKit.SPACE_MD)
	add_child(_card_column)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.card())
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -PANEL_WIDTH - UIKit.SPACE_XL
	panel.offset_right = -UIKit.SPACE_XL
	panel.offset_top = 110
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", UIKit.SPACE_SM)
	panel.add_child(info)
	_info_title = _label("", UIKit.SIZE_HEADING, UIKit.TEXT, UIKit.font_strong())
	info.add_child(_info_title)
	_info_body = _label("", UIKit.SIZE_BODY, UIKit.TEXT_DIM)
	_info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_body.custom_minimum_size = Vector2(PANEL_WIDTH - UIKit.SPACE_LG * 2, 0)
	info.add_child(_info_body)

	_hint = _label("", UIKit.SIZE_BODY, UIKit.TEXT_DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -120
	_hint.offset_bottom = -92

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", UIKit.SPACE_MD)
	add_child(actions)
	_undo = _button("UNDO", UIKit.secondary(), UIKit.TEXT, Vector2(170, 64))
	_undo.pressed.connect(func() -> void: undo_pressed.emit())
	actions.add_child(_undo)
	_end_turn = _button("END TURN", UIKit.primary(), UIKit.BG, Vector2(230, 64))
	_end_turn.pressed.connect(func() -> void: end_turn_pressed.emit())
	actions.add_child(_end_turn)
	actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, UIKit.SPACE_XL)

	var camera := HBoxContainer.new()
	camera.add_theme_constant_override("separation", UIKit.SPACE_SM)
	add_child(camera)
	# Plain text: the bundled faces have no rotation arrows, and a missing glyph renders
	# as a speck that reads as a broken button.
	var left := _button("< TURN", UIKit.secondary(), UIKit.TEXT, Vector2(120, 64))
	left.pressed.connect(func() -> void: rotate_pressed.emit(-1))
	camera.add_child(left)
	var right := _button("TURN >", UIKit.secondary(), UIKit.TEXT, Vector2(120, 64))
	right.pressed.connect(func() -> void: rotate_pressed.emit(1))
	camera.add_child(right)
	camera.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, UIKit.SPACE_XL)

	_build_result()


## `cards`: one entry per player construct, in slot order:
## `{ "ref", "name", "detail", "hp", "max_hp", "alive", "can_move", "can_act", "selected" }`.
func set_crew(cards: Array) -> void:
	for card: Dictionary in cards:
		var ref: int = int(card["ref"])
		if not _cards.has(ref):
			_cards[ref] = _build_card(ref)
		_fill_card(_cards[ref], card)


func set_banner(text: String, colour: Color = UIKit.TEXT) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", colour)


func set_info(title: String, body: String) -> void:
	_info_title.text = title
	_info_body.text = body


func set_hint(text: String) -> void:
	_hint.text = text


func set_controls(can_undo: bool, can_end: bool) -> void:
	_undo.disabled = not can_undo
	_end_turn.disabled = not can_end


func show_result(won: bool, body: String) -> void:
	_result_title.text = "YARD CLEARED" if won else "CREW LOST"
	_result_title.add_theme_color_override("font_color", UIKit.GREEN if won else UIKit.RED)
	_result_body.text = body
	_result.visible = true


func hide_result() -> void:
	_result.visible = false


# --- Building ---------------------------------------------------------------

func _build_card(ref: int) -> Dictionary:
	# The whole card is the button: a separate SELECT control would be a second, smaller
	# target for the one thing the card is for.
	var button := Button.new()
	button.custom_minimum_size = CARD_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: unit_card_pressed.emit(ref))
	_card_column.add_child(button)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = UIKit.SPACE_LG
	box.offset_right = -UIKit.SPACE_LG
	box.offset_top = UIKit.SPACE_MD
	box.offset_bottom = -UIKit.SPACE_MD
	box.add_theme_constant_override("separation", UIKit.SPACE_XS)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)

	var name := _label("", UIKit.SIZE_HEADING, UIKit.TEXT, UIKit.font_strong())
	box.add_child(name)
	var detail := _label("", UIKit.SIZE_LABEL, UIKit.TEXT_DIM)
	box.add_child(detail)

	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.add_theme_stylebox_override("background", UIKit.plain(UIKit.SURFACE_SUNK, 2))
	bar.add_theme_stylebox_override("fill", UIKit.plain(UIKit.BLUE, 2))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.SPACE_MD)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var hp := _label("", UIKit.SIZE_LABEL, UIKit.TEXT, UIKit.font_numbers())
	row.add_child(hp)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var move := _label("MOVE", UIKit.SIZE_LABEL, UIKit.GREEN, UIKit.font_strong())
	row.add_child(move)
	var act := _label("ATTACK", UIKit.SIZE_LABEL, UIKit.GREEN, UIKit.font_strong())
	row.add_child(act)

	return {"button": button, "name": name, "detail": detail, "bar": bar, "hp": hp, "move": move, "act": act}


func _fill_card(parts: Dictionary, card: Dictionary) -> void:
	var alive: bool = bool(card["alive"])
	var selected: bool = bool(card["selected"])
	var button: Button = parts["button"]
	# Amber marks the selection, which is the one thing on this column that matters.
	var style: StyleBoxFlat = UIKit.card(UIKit.SURFACE_HIGH if selected else UIKit.SURFACE)
	if selected:
		style.border_color = UIKit.AMBER
		style.set_border_width_all(2)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, style)
	button.disabled = not alive
	button.modulate = Color(1, 1, 1, 1.0 if alive else 0.45)

	(parts["name"] as Label).text = String(card["name"]) + ("" if alive else "  ·  WRECKED")
	(parts["detail"] as Label).text = String(card["detail"])
	var bar: ProgressBar = parts["bar"]
	bar.max_value = int(card["max_hp"])
	bar.value = int(card["hp"])
	(parts["hp"] as Label).text = "%d / %d HP" % [int(card["hp"]), int(card["max_hp"])]
	_chip(parts["move"], alive and bool(card["can_move"]))
	_chip(parts["act"], alive and bool(card["can_act"]))


## A spent action stays on the card, faint, rather than disappearing: the player is
## checking WHICH of the two a construct has left, and a missing word answers nothing.
func _chip(label: Label, available: bool) -> void:
	label.add_theme_color_override("font_color", UIKit.GREEN if available else UIKit.TEXT_FAINT)


func _build_result() -> void:
	_result = Control.new()
	_result.visible = false
	add_child(_result)
	_result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	_result.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	_result.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.card(UIKit.SURFACE, UIKit.RADIUS_CARD, UIKit.SPACE_XXL, UIKit.SPACE_XL))
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.SPACE_LG)
	panel.add_child(box)
	_result_title = _label("", UIKit.SIZE_DISPLAY, UIKit.TEXT, UIKit.font_display())
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_title)
	_result_body = _label("", UIKit.SIZE_BODY, UIKit.TEXT_DIM)
	_result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_body)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UIKit.SPACE_MD)
	box.add_child(row)
	var title := _button("TITLE", UIKit.secondary(), UIKit.TEXT, Vector2(170, 60))
	title.pressed.connect(func() -> void: title_pressed.emit())
	row.add_child(title)
	var retry := _button("FIGHT AGAIN", UIKit.primary(), UIKit.BG, Vector2(230, 60))
	retry.pressed.connect(func() -> void: retry_pressed.emit())
	row.add_child(retry)


func _label(text: String, size: int, colour: Color, face: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	if face != null:
		label.add_theme_font_override("font", face)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, style: StyleBoxFlat, ink: Color, size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", UIKit.font_strong())
	button.add_theme_font_size_override("font_size", UIKit.SIZE_HEADING)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, style)
	var dim: StyleBoxFlat = style.duplicate()
	dim.bg_color = dim.bg_color.darkened(0.45)
	button.add_theme_stylebox_override("disabled", dim)
	button.add_theme_color_override("font_disabled_color", ink.darkened(0.2) if ink == UIKit.BG else UIKit.TEXT_FAINT)
	return button
