class_name CombatHUD
extends Control

## The fight's interface: crew cards, an info panel, the round banner, UNDO and END TURN.
##
## It only DISPLAYS. The combat scene hands it plain dictionaries and listens for its
## signals; nothing here reads the sim or decides anything.
##
## Built for touch first. Every control is at least 56 px tall at 1080p and nothing
## depends on hover. A mouse gets the same controls, plus keyboard shortcuts in the scene.
##
## Ink & Rust (015): comic panels -- paper cards with ink borders and hard shadows, ink text,
## Anton for names and numbers, the hint as a narrator's caption. Amber still means your
## action: the armed weapon, END TURN, and the band on the selected machine's card.

signal unit_card_pressed(ref: int)
signal weapon_pressed(w: int)
signal vent_pressed
signal undo_pressed
signal end_turn_pressed
signal rotate_pressed(step: int)
signal lines_pressed
signal retry_pressed
signal title_pressed
signal continue_pressed

const CARD_SIZE := Vector2(340, 150)
const WEAPON_SIZE := Vector2(310, 76)
const ABILITY_SIZE := Vector2(176, 58)
## The action bar's box: right of the camera buttons, left of UNDO / END TURN.
const BAR_LEFT: float = 356.0
const BAR_WIDTH: float = 1150.0
const PANEL_WIDTH: int = 360

var _banner: Label
var _cards: Dictionary = {}
var _card_column: VBoxContainer
var _objective_plate: PanelContainer
var _objective_label: Label
var _weapon_bar: HBoxContainer
var _ability_bar: HBoxContainer
var _bar_area: VBoxContainer
var _lines_button: Button
var _info_title: Label
## Rich text: the words in it are glossary links (012).
var _info_body: RichTextLabel
## `ContentDB.glossary`, set by the scene before the HUD enters the tree.
var glossary: Dictionary = {}
var _hint: Label
var _hint_box: PanelContainer
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
	_banner = _label("", 40, UIKit.PAPER, UIKit.font_comic())
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_constant_override("outline_size", 14)
	_banner.add_theme_color_override("font_outline_color", UIKit.INK)
	add_child(_banner)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = UIKit.SPACE_MD

	_card_column = VBoxContainer.new()
	_card_column.position = Vector2(UIKit.SPACE_XL, 96)
	_card_column.add_theme_constant_override("separation", UIKit.SPACE_MD)
	add_child(_card_column)
	_build_objective_plate()

	# What the selected machine can do, in two labelled rows inside a FIXED area between
	# the camera buttons and UNDO: abilities above, weapons below. A single centred row
	# grew with every ability and ran under UNDO and END TURN (play-test 2).
	_bar_area = VBoxContainer.new()
	_bar_area.add_theme_constant_override("separation", UIKit.SPACE_SM)
	_bar_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_area)
	_bar_area.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_bar_area.offset_left = BAR_LEFT
	_bar_area.offset_right = BAR_LEFT + BAR_WIDTH
	_bar_area.offset_top = -(WEAPON_SIZE.y + ABILITY_SIZE.y + UIKit.SPACE_SM + UIKit.SPACE_XL)
	_bar_area.offset_bottom = -UIKit.SPACE_XL
	_ability_bar = _bar_row("ABILITIES")
	_weapon_bar = _bar_row("WEAPONS")

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.ink_card())
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -PANEL_WIDTH - UIKit.SPACE_XL
	panel.offset_right = -UIKit.SPACE_XL
	panel.offset_top = 96
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", UIKit.SPACE_SM)
	panel.add_child(info)
	_info_title = _label("", 24, UIKit.INK, UIKit.font_comic())
	info.add_child(_info_title)
	_info_body = Glossary.label("", UIKit.SIZE_BODY, UIKit.INK_DIM, glossary, PANEL_WIDTH - UIKit.SPACE_LG * 2,
		UIKit.font_strong(), UIKit.INK_LINK)
	info.add_child(_info_body)

	# The hint is the narrator: a pale caption box, centred over the action bar.
	var hint_row := CenterContainer.new()
	hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint_row)
	hint_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint_row.offset_top = -(WEAPON_SIZE.y + ABILITY_SIZE.y + 76)
	hint_row.offset_bottom = -(WEAPON_SIZE.y + ABILITY_SIZE.y + 34)
	_hint_box = PanelContainer.new()
	_hint_box.add_theme_stylebox_override("panel", UIKit.ink_caption())
	_hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_row.add_child(_hint_box)
	_hint = _label("", UIKit.SIZE_BODY, UIKit.INK, UIKit.font_strong())
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_box.add_child(_hint)
	_hint_box.visible = false

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", UIKit.SPACE_LG)
	add_child(actions)
	_undo = _button("UNDO", UIKit.PAPER_CARD, Vector2(170, 64))
	_undo.pressed.connect(func() -> void: undo_pressed.emit())
	actions.add_child(_undo)
	_end_turn = _button("END TURN", Ink.ACTION, Vector2(230, 64))
	_end_turn.pressed.connect(func() -> void: end_turn_pressed.emit())
	actions.add_child(_end_turn)
	actions.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, UIKit.SPACE_XL)

	var camera := HBoxContainer.new()
	camera.add_theme_constant_override("separation", UIKit.SPACE_MD)
	add_child(camera)
	# Plain text: the bundled faces have no rotation arrows, and a missing glyph renders
	# as a speck that reads as a broken button.
	var left := _button("<", UIKit.PAPER_CARD, Vector2(58, 64))
	left.tooltip_text = "Turn the camera (Q)"
	left.pressed.connect(func() -> void: rotate_pressed.emit(-1))
	camera.add_child(left)
	var right := _button(">", UIKit.PAPER_CARD, Vector2(58, 64))
	right.tooltip_text = "Turn the camera (E)"
	right.pressed.connect(func() -> void: rotate_pressed.emit(1))
	camera.add_child(right)
	# Every enemy's full line of fire at once, for when the quiet default is not enough (L).
	_lines_button = _button("LINES", UIKit.PAPER_CARD, Vector2(104, 64))
	_lines_button.add_theme_font_size_override("font_size", UIKit.SIZE_HEADING)
	_lines_button.pressed.connect(func() -> void: lines_pressed.emit())
	camera.add_child(_lines_button)
	# Every word the fight uses (012). The same words are links in the info panel.
	var words := _button("?", UIKit.PAPER_CARD, Vector2(58, 64))
	words.name = "glossary_button"
	words.tooltip_text = "Glossary"
	words.pressed.connect(func() -> void: Glossary.open(self, glossary))
	camera.add_child(words)
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


## What this fight asks for, always on screen: the play-test found a goal nobody explains
## is not a goal. `text` comes from `CombatSim.objective_status`.
func set_objective(text: String, urgent: bool) -> void:
	_objective_label.text = text
	_objective_label.add_theme_color_override("font_color", UIKit.INK_RED if urgent else UIKit.INK)


## `items`: `{ "name", "detail", "available", "reason", "ability": bool, "free": bool,
## "cooldown": int }`, weapons first. `selected`: the armed item's index, or -1.
## `vent`: "" to hide VENT. Pressing an item emits `weapon_pressed(index into items)`.
func set_weapons(items: Array, selected: int, vent: String) -> void:
	for bar: HBoxContainer in [_weapon_bar, _ability_bar]:
		for child: Node in bar.get_children():
			if child.has_meta("item"):
				child.queue_free()
	for i: int in items.size():
		var info: Dictionary = items[i]
		var ability: bool = bool(info.get("ability", false))
		(_ability_bar if ability else _weapon_bar).add_child(_action_button(info, i, i == selected, ability))
	if not vent.is_empty():
		var vent_button := _button("VENT HEAT", UIKit.PAPER_CARD, ABILITY_SIZE)
		vent_button.set_meta("item", true)
		vent_button.add_theme_font_size_override("font_size", UIKit.SIZE_HEADING)
		vent_button.pressed.connect(func() -> void: vent_pressed.emit())
		_ability_bar.add_child(vent_button)
	(_ability_bar.get_parent() as Control).visible = items.any(func(x: Dictionary) -> bool: return bool(x.get("ability", false))) or not vent.is_empty()
	(_weapon_bar.get_parent() as Control).visible = not items.is_empty()


## One row with a small lettered caption on its left, so the two rows name themselves.
func _bar_row(caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.SPACE_MD)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_area.add_child(row)
	var tag := _label(caption, UIKit.SIZE_LABEL, UIKit.PAPER, UIKit.font_comic())
	tag.add_theme_constant_override("outline_size", 8)
	tag.add_theme_color_override("font_outline_color", UIKit.INK)
	tag.custom_minimum_size = Vector2(76, 0)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(tag)
	return row


## A weapon is a paper card with its arm's picture, AMBER when armed (your action); an
## ability a smaller card banded in your blue. Unavailable ones grey out and say why.
func _action_button(info: Dictionary, index: int, selected: bool, ability: bool) -> Control:
	var size: Vector2 = ABILITY_SIZE if ability else WEAPON_SIZE
	var available: bool = bool(info["available"])
	var button := Button.new()
	button.set_meta("item", true)
	button.custom_minimum_size = size
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not available
	var fill: Color = Ink.ACTION if selected else (UIKit.PAPER_CARD if available else UIKit.PAPER_DIM)
	var up: InkBox = UIKit.ink_button(fill)
	var down: InkBox = UIKit.ink_button(fill, true)
	if selected:
		# Armed reads as a heavier line as well as amber: the frame's grey copy could barely tell
		# an amber card from a paper one.
		for box: InkBox in [up, down]:
			box.border_width = 5.0
	if ability:
		for box: InkBox in [up, down]:
			box.band_width = 7.0
			box.band = Ink.YOURS if available else UIKit.INK_FAINT
	for key: String in ["normal", "hover", "focus", "disabled"]:
		button.add_theme_stylebox_override(key, up)
	button.add_theme_stylebox_override("pressed", down)
	button.pressed.connect(func() -> void: weapon_pressed.emit(index))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	button.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = UIKit.SPACE_MD + (8 if ability else 4)
	box.offset_right = -UIKit.SPACE_SM
	box.offset_top = UIKit.SPACE_XS + 1
	# 010: a weapon button shows the arm it fires (the same thumbnail as its part card).
	var part: String = String(info.get("part", ""))
	if not ability and not part.is_empty():
		var picture := TextureRect.new()
		picture.texture = PartText.thumb(part)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.modulate = Color(1, 1, 1, 1.0 if available else 0.35)
		button.add_child(picture)
		picture.set_anchors_preset(Control.PRESET_TOP_LEFT)
		picture.position = Vector2(UIKit.SPACE_MD, (size.y - 60.0) * 0.5)
		picture.size = Vector2(60, 60)
		box.offset_left = UIKit.SPACE_MD + 68
	box.add_child(_label(String(info["name"]).to_upper(), 20 if not ability else 16,
		UIKit.INK if available else UIKit.INK_FAINT, UIKit.font_comic()))
	var line: String = String(info["detail"]) if available else String(info["reason"])
	var detail := _label(line, UIKit.SIZE_MICRO if ability else UIKit.SIZE_LABEL,
		(UIKit.INK_DIM if available else UIKit.INK_RED), UIKit.font_strong())
	# Wrapped inside the button's own width: nothing runs off its right edge.
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(size.x - box.offset_left - UIKit.SPACE_SM, 0)
	detail.max_lines_visible = 2
	box.add_child(detail)
	return button


## What the shakedown's coach points at (012): "weapon" / "ability" -- the first live button
## in that row -- or "end_turn". Looked up every frame: the bars are rebuilt on every refresh.
func control_for(kind: String) -> Control:
	match kind:
		"end_turn":
			return _end_turn
		"weapon", "ability":
			for child: Node in (_weapon_bar if kind == "weapon" else _ability_bar).get_children():
				if child is Button and child.has_meta("item") and not child.is_queued_for_deletion() \
						and (child as Button).is_visible_in_tree():
					return child
	return null


func set_banner(text: String, colour: Color = UIKit.PAPER) -> void:
	_banner.text = text
	# The banner is lettered on the board, so it keeps paper for everything but danger.
	_banner.add_theme_color_override("font_color", Ink.DANGER if colour == UIKit.RED else UIKit.PAPER)


func set_info(title: String, body: String) -> void:
	_info_title.text = title
	_info_body.text = Glossary.linkify(body, glossary, UIKit.INK_LINK)


func set_hint(text: String) -> void:
	_hint.text = text
	_hint_box.visible = not text.is_empty()


func set_controls(can_undo: bool, can_end: bool) -> void:
	_undo.disabled = not can_undo
	_end_turn.disabled = not can_end


## `in_run`: the fight belongs to a run, so the only way on is CONTINUE (back to the map);
## a practice fight offers FIGHT AGAIN and TITLE instead.
func show_result(won: bool, body: String, in_run: bool = false) -> void:
	_result_title.text = "YARD CLEARED" if won else ("CREW LOST" if not in_run else "RUN OVER")
	_result_title.add_theme_color_override("font_color", UIKit.INK_GREEN if won else UIKit.INK_RED)
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

	# 010: the machine itself on the card (the real model, levels and number), not only its
	# name -- the same portrait the map's crew dock shows. 015: drawn in ink, framed in a
	# small halftone panel, the way a comic introduces a character.
	var row_all := HBoxContainer.new()
	row_all.set_anchors_preset(Control.PRESET_FULL_RECT)
	row_all.offset_left = UIKit.SPACE_MD
	row_all.offset_right = -UIKit.SPACE_SM
	row_all.offset_top = UIKit.SPACE_SM + 2
	row_all.offset_bottom = -UIKit.SPACE_SM - 2
	row_all.add_theme_constant_override("separation", UIKit.SPACE_MD)
	row_all.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row_all)
	var frame := PanelContainer.new()
	var frame_style: InkBox = UIKit.ink_card(Ink.MUSTARD.lightened(0.12), 0, 0, 0)
	frame_style.border_width = 2.0
	frame_style.dots = Color(UIKit.INK, 0.22)
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_all.add_child(frame)
	var portrait := MachinePortrait.new(Vector2i(88, 124), "portrait", true)
	frame.add_child(portrait)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 1)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_all.add_child(box)

	# The name, with what it has left this turn beside it.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIKit.SPACE_SM)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	var name := _label("", 22, UIKit.INK, UIKit.font_comic())
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	head.add_child(name)
	var move := _label("MOVE", UIKit.SIZE_MICRO, UIKit.INK_GREEN, UIKit.font_comic())
	head.add_child(move)
	var act := _label("ATTACK", UIKit.SIZE_MICRO, UIKit.INK_GREEN, UIKit.font_comic())
	head.add_child(act)
	# Detail lines trim with an ellipsis inside the card rather than running off its edge.
	var detail := _label("", UIKit.SIZE_LABEL, UIKit.INK_DIM, UIKit.font_strong())
	detail.clip_text = true
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.custom_minimum_size = Vector2(190, 0)
	box.add_child(detail)
	var arms := _label("", UIKit.SIZE_LABEL, UIKit.INK_DIM, UIKit.font_strong())
	arms.clip_text = true
	arms.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	arms.custom_minimum_size = Vector2(190, 0)
	box.add_child(arms)

	# HP as pips, one per point, so a glance counts it (as the map's dock does): ink boxes,
	# filled in your blue.
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 2)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.SPACE_MD)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var hp := _label("", UIKit.SIZE_LABEL, UIKit.INK, UIKit.font_comic())
	row.add_child(hp)
	var heat := _label("", UIKit.SIZE_LABEL, Ink.RUST, UIKit.font_comic())
	row.add_child(heat)

	return {"button": button, "name": name, "detail": detail, "arms": arms, "bar": bar, "hp": hp,
		"heat": heat, "move": move, "act": act, "portrait": portrait}


func _fill_card(parts: Dictionary, card: Dictionary) -> void:
	var alive: bool = bool(card["alive"])
	var selected: bool = bool(card["selected"])
	var button: Button = parts["button"]
	# Amber marks the selection -- a band down the card's edge, the one thing on this column
	# that matters -- and the selected card stands a little prouder off the page.
	var style: InkBox = UIKit.ink_card(UIKit.PAPER_CARD, 0, 0, 7 if selected else 4)
	if selected:
		style.band_width = 9.0
		style.band = Ink.ACTION
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, style)
	button.disabled = not alive
	button.modulate = Color(1, 1, 1, 1.0 if alive else 0.5)

	(parts["name"] as Label).text = String(card["name"]).to_upper() + ("" if alive else "  ·  WRECKED")
	(parts["detail"] as Label).text = String(card["detail"])
	var bar: HBoxContainer = parts["bar"]
	var full: int = maxi(1, int(card["max_hp"]))
	var now: int = int(card["hp"])
	if bar.get_child_count() != full or int(bar.get_meta("hp", -1)) != now:
		bar.set_meta("hp", now)
		for child: Node in bar.get_children():
			child.queue_free()
		var width: float = clampf(190.0 / float(full) - 2.0, 4.0, 13.0)
		for n: int in full:
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(width, 12)
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var colour: Color = (Ink.DANGER if now * 3 <= full else Ink.YOURS) if n < now else UIKit.PAPER_CARD
			var pip_style := InkBox.new(colour, 0, 0)
			pip_style.border_width = 1.5
			pip_style.shadow = Vector2.ZERO
			pip.add_theme_stylebox_override("panel", pip_style)
			bar.add_child(pip)
	(parts["portrait"] as MachinePortrait).show_machine(card.get("parts", []), int(card.get("level", 0)), alive, int(card.get("number", -1)))
	(parts["hp"] as Label).text = "%d / %d HP" % [int(card["hp"]), int(card["max_hp"])]
	(parts["arms"] as Label).text = String(card.get("arms", ""))
	var heat: Label = parts["heat"]
	heat.text = "HEAT %d/%d" % [int(card.get("heat", 0)), int(card.get("heat_cap", 0))]
	heat.add_theme_color_override("font_color",
		UIKit.INK_RED if int(card.get("heat", 0)) >= int(card.get("heat_cap", 1)) - 1 else Ink.RUST)
	_chip(parts["move"], alive and bool(card["can_move"]))
	_chip(parts["act"], alive and bool(card["can_act"]))


## A spent action stays on the card, faint, rather than disappearing: the player is
## checking WHICH of the two a construct has left, and a missing word answers nothing.
func _chip(label: Label, available: bool) -> void:
	label.add_theme_color_override("font_color", UIKit.INK_GREEN if available else UIKit.INK_FAINT)


func _build_objective_plate() -> void:
	_objective_plate = PanelContainer.new()
	_objective_plate.custom_minimum_size = Vector2(CARD_SIZE.x, 0)
	_objective_plate.add_theme_stylebox_override("panel", UIKit.ink_card(UIKit.PAPER, UIKit.SPACE_LG, UIKit.SPACE_SM, 4))
	_objective_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_column.add_child(_objective_plate)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	_objective_plate.add_child(box)
	box.add_child(_label("OBJECTIVE", UIKit.SIZE_MICRO, UIKit.INK_DIM, UIKit.font_comic()))
	_objective_label = _label("", 17, UIKit.INK, UIKit.font_comic())
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.custom_minimum_size = Vector2(CARD_SIZE.x - UIKit.SPACE_LG * 2, 0)
	box.add_child(_objective_label)


func _build_result() -> void:
	_result = Control.new()
	_result.visible = false
	add_child(_result)
	_result.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.05, 0.07, 0.6)
	_result.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	_result.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.ink_card(UIKit.PAPER_CARD, UIKit.SPACE_XXL, UIKit.SPACE_XL, 8))
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.SPACE_LG)
	panel.add_child(box)
	_result_title = _label("", 52, UIKit.INK, UIKit.font_comic())
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_title)
	_result_body = _label("", UIKit.SIZE_BODY, UIKit.INK_DIM, UIKit.font_strong())
	_result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_body)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UIKit.SPACE_LG)
	box.add_child(row)
	_title = _button("TITLE", UIKit.PAPER_CARD, Vector2(170, 60))
	_title.pressed.connect(func() -> void: title_pressed.emit())
	row.add_child(_title)
	_retry = _button("FIGHT AGAIN", Ink.ACTION, Vector2(230, 60))
	_retry.pressed.connect(func() -> void: retry_pressed.emit())
	row.add_child(_retry)
	_continue = _button("CONTINUE", Ink.ACTION, Vector2(260, 60))
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


## A comic button: `fill` paper or amber, ink lettering; pressed, it drops onto its shadow.
func _button(text: String, fill: Color, size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", UIKit.font_comic())
	button.add_theme_font_size_override("font_size", 22)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, UIKit.INK)
	button.add_theme_color_override("font_disabled_color", UIKit.INK_FAINT)
	var up: InkBox = UIKit.ink_button(fill)
	for state: String in ["normal", "hover", "focus"]:
		button.add_theme_stylebox_override(state, up)
	button.add_theme_stylebox_override("pressed", UIKit.ink_button(fill, true))
	var dim: InkBox = UIKit.ink_button(UIKit.PAPER_DIM)
	dim.shadow = Vector2(2, 2)
	button.add_theme_stylebox_override("disabled", dim)
	return button
