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
signal weapon_pressed(w: int)
signal vent_pressed
signal undo_pressed
signal end_turn_pressed
signal rotate_pressed(step: int)
signal retry_pressed
signal title_pressed
signal continue_pressed

const CARD_SIZE := Vector2(320, 140)
const WEAPON_SIZE := Vector2(250, 76)
const PANEL_WIDTH: int = 360

var _banner: Label
var _cards: Dictionary = {}
var _card_column: VBoxContainer
var _crawler_plate: PanelContainer
var _crawler_bar: ProgressBar
var _crawler_label: Label
var _weapon_bar: HBoxContainer
var _weapon_row: CenterContainer
var _info_title: Label
var _info_body: Label
var _hint: Label
var _undo: Button
var _end_turn: Button
var _result: Control
var _result_title: Label
var _result_body: Label
var _retry: Button
var _title: Button
var _continue: Button


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
	_card_column.position = Vector2(UIKit.SPACE_XL, 96)
	_card_column.add_theme_constant_override("separation", UIKit.SPACE_SM)
	add_child(_card_column)
	_build_crawler_plate()

	# The selected construct's arms, as buttons: what it can DO comes from what is bolted
	# onto it, so the choice of attack is a choice of part.
	# A full-width centring row, so the bar stays centred however many buttons it holds.
	# Anchoring the bar itself was computed from its size mid-rebuild and landed it in the
	# bottom-left corner, half off the screen.
	_weapon_row = CenterContainer.new()
	_weapon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_weapon_row)
	_weapon_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_weapon_row.offset_top = -WEAPON_SIZE.y - UIKit.SPACE_XL
	_weapon_row.offset_bottom = -UIKit.SPACE_XL
	_weapon_bar = HBoxContainer.new()
	_weapon_bar.add_theme_constant_override("separation", UIKit.SPACE_SM)
	_weapon_row.add_child(_weapon_bar)

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
	_hint.offset_top = -148
	_hint.offset_bottom = -120

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


## The Crawler is not a construct the player commands, so it is a plate, not a card:
## a button that never does anything would be a label pretending to be a control.
func set_crawler(hp: int, max_hp: int) -> void:
	_crawler_plate.visible = max_hp > 0
	_crawler_bar.max_value = max_hp
	_crawler_bar.value = hp
	_crawler_label.text = "CRAWLER   %d / %d" % [hp, max_hp]
	var low: bool = hp * 3 <= max_hp
	_crawler_bar.add_theme_stylebox_override("fill", UIKit.plain(UIKit.RED if low else UIKit.GREEN, 2))


## `weapons`: `{ "name", "detail", "available", "reason" }` per arm, in arm order.
## `selected`: index of the ARMED weapon, or -1 when the construct is in move mode.
## `vent`: "" to hide VENT, else its label.
func set_weapons(weapons: Array, selected: int, vent: String) -> void:
	for child: Node in _weapon_bar.get_children():
		child.queue_free()
	for w: int in weapons.size():
		var info: Dictionary = weapons[w]
		if not bool(info["available"]):
			# A weapon that cannot fire is a plate that says why, not a disabled button.
			var plate := PanelContainer.new()
			plate.custom_minimum_size = WEAPON_SIZE
			plate.add_theme_stylebox_override("panel", UIKit.inset(UIKit.SURFACE_SUNK))
			var box := VBoxContainer.new()
			plate.add_child(box)
			box.add_child(_label(String(info["name"]).to_upper(), UIKit.SIZE_LABEL, UIKit.TEXT_FAINT, UIKit.font_strong()))
			box.add_child(_label(String(info["reason"]), UIKit.SIZE_LABEL, UIKit.RED))
			_weapon_bar.add_child(plate)
			continue
		var button := Button.new()
		button.custom_minimum_size = WEAPON_SIZE
		button.focus_mode = Control.FOCUS_NONE
		var style: StyleBoxFlat = UIKit.choice() if w == selected else UIKit.secondary()
		if w == selected:
			style.set_border_width_all(2)
		for state: String in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, style)
		var index: int = w
		button.pressed.connect(func() -> void: weapon_pressed.emit(index))
		var box := VBoxContainer.new()
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.offset_left = UIKit.SPACE_MD
		box.offset_top = UIKit.SPACE_SM
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(box)
		box.add_child(_label(String(info["name"]).to_upper(), UIKit.SIZE_BODY,
			UIKit.AMBER if w == selected else UIKit.TEXT, UIKit.font_strong()))
		box.add_child(_label(String(info["detail"]), UIKit.SIZE_LABEL, UIKit.TEXT_DIM))
		_weapon_bar.add_child(button)
	if not vent.is_empty():
		var vent_button := _button("VENT", UIKit.secondary(), UIKit.BLUE, Vector2(130, WEAPON_SIZE.y))
		vent_button.tooltip_text = vent
		vent_button.pressed.connect(func() -> void: vent_pressed.emit())
		_weapon_bar.add_child(vent_button)


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


## `in_run`: the fight belongs to a run, so the only way on is CONTINUE (back to the map);
## a practice fight offers FIGHT AGAIN and TITLE instead.
func show_result(won: bool, body: String, in_run: bool = false) -> void:
	_result_title.text = "YARD CLEARED" if won else ("CREW LOST" if not in_run else "RUN OVER")
	_result_title.add_theme_color_override("font_color", UIKit.GREEN if won else UIKit.RED)
	_result_body.text = body
	_retry.visible = not in_run
	_title.visible = not in_run
	_continue.visible = in_run
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
	var arms := _label("", UIKit.SIZE_LABEL, UIKit.TEXT_DIM)
	box.add_child(arms)

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
	var heat := _label("", UIKit.SIZE_LABEL, UIKit.GOLD, UIKit.font_numbers())
	row.add_child(heat)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var move := _label("MOVE", UIKit.SIZE_LABEL, UIKit.GREEN, UIKit.font_strong())
	row.add_child(move)
	var act := _label("ATTACK", UIKit.SIZE_LABEL, UIKit.GREEN, UIKit.font_strong())
	row.add_child(act)

	return {"button": button, "name": name, "detail": detail, "arms": arms, "bar": bar, "hp": hp,
		"heat": heat, "move": move, "act": act}


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
	(parts["arms"] as Label).text = String(card.get("arms", ""))
	var heat: Label = parts["heat"]
	heat.text = "HEAT %d/%d" % [int(card.get("heat", 0)), int(card.get("heat_cap", 0))]
	heat.add_theme_color_override("font_color",
		UIKit.RED if int(card.get("heat", 0)) >= int(card.get("heat_cap", 1)) - 1 else UIKit.GOLD)
	_chip(parts["move"], alive and bool(card["can_move"]))
	_chip(parts["act"], alive and bool(card["can_act"]))


## A spent action stays on the card, faint, rather than disappearing: the player is
## checking WHICH of the two a construct has left, and a missing word answers nothing.
func _chip(label: Label, available: bool) -> void:
	label.add_theme_color_override("font_color", UIKit.GREEN if available else UIKit.TEXT_FAINT)


func _build_crawler_plate() -> void:
	_crawler_plate = PanelContainer.new()
	_crawler_plate.custom_minimum_size = Vector2(CARD_SIZE.x, 0)
	_crawler_plate.add_theme_stylebox_override("panel", UIKit.inset(UIKit.SURFACE, UIKit.RADIUS_CARD, UIKit.SPACE_LG, UIKit.SPACE_SM))
	_crawler_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_column.add_child(_crawler_plate)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.SPACE_XS)
	_crawler_plate.add_child(box)
	_crawler_label = _label("", UIKit.SIZE_LABEL, UIKit.TEXT, UIKit.font_strong())
	box.add_child(_crawler_label)
	_crawler_bar = ProgressBar.new()
	_crawler_bar.show_percentage = false
	_crawler_bar.custom_minimum_size = Vector2(0, 10)
	_crawler_bar.add_theme_stylebox_override("background", UIKit.plain(UIKit.SURFACE_SUNK, 2))
	_crawler_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_crawler_bar)
	box.add_child(_label("Lose it and the fight is lost", UIKit.SIZE_MICRO, UIKit.TEXT_FAINT))


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
	_title = _button("TITLE", UIKit.secondary(), UIKit.TEXT, Vector2(170, 60))
	_title.pressed.connect(func() -> void: title_pressed.emit())
	row.add_child(_title)
	_retry = _button("FIGHT AGAIN", UIKit.primary(), UIKit.BG, Vector2(230, 60))
	_retry.pressed.connect(func() -> void: retry_pressed.emit())
	row.add_child(_retry)
	_continue = _button("CONTINUE", UIKit.primary(), UIKit.BG, Vector2(260, 60))
	_continue.pressed.connect(func() -> void: continue_pressed.emit())
	row.add_child(_continue)


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
