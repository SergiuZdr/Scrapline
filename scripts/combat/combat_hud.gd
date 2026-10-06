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
## HP pips (play-test 9): always this size, this many to a row.
## Play-test 10: 16 to a row (27 HP ran to three rows of 12 and covered the HP line); a card
## grows by a row's height if a machine ever needs a third.
const PIP_SIZE := Vector2(10, 8)
const PIPS_PER_ROW: int = 16
## A machine not picked shrinks to a slim row (016, review point R5-2): its name, what it has
## left this turn, its HP. The picked one is the only full card, so the column asks for less.
const SLIM_SIZE := Vector2(340, 94)
const WEAPON_SIZE := Vector2(310, 76)
const ABILITY_SIZE := Vector2(250, 74)
## The action bar's box: right of the camera buttons, left of UNDO / END TURN.
const BAR_LEFT: float = 356.0
const BAR_WIDTH: float = 1150.0
const PANEL_WIDTH: int = 360

var _banner: Label
var _banner_box: PanelContainer
## 038: the boss's bar -- name, HP, what it is doing -- under the round caption.
var _boss_box: PanelContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _boss_hp: Label
var _boss_line: Label
var _cards: Dictionary = {}
var _card_column: VBoxContainer
var _objective_plate: PanelContainer
var _objective_label: Label
var _weapon_bar: HBoxContainer
var _ability_bar: HBoxContainer
var _bar_area: VBoxContainer
var _lines_button: Button
var _info_title: Label
var _info_tail: BalloonTail
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
var _opening: Control


func _ready() -> void:
	UIKit.apply(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Every anchored child is added FIRST and anchored after: a preset applied to a node
	# outside the tree computes its offsets against a zero-size parent, which is what put
	# the banner half off the top-left corner in the first render.
	# 036, comic style: the round is lettered in a CAPTION BOX -- paper, an ink border and a hard
	# shadow, the box a comic opens a panel with -- not loose letters on the board.
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	holder.offset_top = UIKit.SPACE_SM
	holder.offset_bottom = UIKit.SPACE_SM + 52
	_banner_box = PanelContainer.new()
	_banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_box.add_theme_stylebox_override("panel", UIKit.ink_card(UIKit.PAPER, UIKit.SPACE_LG, 0, 5))
	holder.add_child(_banner_box)
	_banner = _label("", 30, UIKit.INK, UIKit.font_comic())
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_box.add_child(_banner)

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
	# 039: the info panel is a SPEECH BALLOON -- its tail points at what it is talking about.
	_info_tail = BalloonTail.new()
	_info_tail.panel = panel
	add_child(_info_tail)
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
## 038 (play-test 11: "the bosses do not look scary"): a boss or warlord gets a bar across the top
## -- its name in red, its HP, and the line that says what it is doing now. `name` empty hides it.
func set_boss(name: String, hp: int, max_hp: int, line: String) -> void:
	if _boss_box == null:
		var holder := CenterContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(holder)
		holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		holder.offset_top = 66
		holder.offset_bottom = 66 + 84
		_boss_box = PanelContainer.new()
		_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boss_box.add_theme_stylebox_override("panel", UIKit.ink_card(UIKit.INK, UIKit.SPACE_LG, UIKit.SPACE_XS, 5))
		holder.add_child(_boss_box)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boss_box.add_child(col)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", UIKit.SPACE_MD)
		col.add_child(head)
		_boss_name = _label("", 26, Ink.DANGER, UIKit.font_comic())
		head.add_child(_boss_name)
		_boss_bar = ProgressBar.new()
		_boss_bar.show_percentage = false
		_boss_bar.custom_minimum_size = Vector2(420, 18)
		_boss_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var well := StyleBoxFlat.new()
		well.bg_color = Color("2a2420")
		well.border_color = UIKit.PAPER
		well.set_border_width_all(2)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Ink.DANGER
		_boss_bar.add_theme_stylebox_override("background", well)
		_boss_bar.add_theme_stylebox_override("fill", fill)
		head.add_child(_boss_bar)
		_boss_hp = _label("", 22, UIKit.PAPER, UIKit.font_comic())
		head.add_child(_boss_hp)
		_boss_line = _label("", UIKit.SIZE_LABEL, UIKit.PAPER, UIKit.font_strong())
		col.add_child(_boss_line)
	_boss_box.visible = not name.is_empty()
	if name.is_empty():
		return
	_boss_name.text = name.to_upper()
	_boss_bar.max_value = max_hp
	_boss_bar.value = hp
	_boss_hp.text = "%d / %d" % [hp, max_hp]
	_boss_line.text = line


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
	# Play-test 8: the name on one line and the detail on two, each fitted to the card's own
	# width (`UIKit.fit` steps the font down), so nothing runs off its edge or below its foot.
	var inner: float = size.x - box.offset_left - UIKit.SPACE_SM
	box.add_child(UIKit.fit(_label(String(info["name"]).to_upper(), 20 if not ability else 16,
		UIKit.INK if available else UIKit.INK_FAINT, UIKit.font_comic()), inner, 1, 12))
	var line: String = String(info["detail"]) if available else String(info["reason"])
	box.add_child(UIKit.fit(_label(line, UIKit.SIZE_MICRO if ability else UIKit.SIZE_LABEL,
		(UIKit.INK_DIM if available else UIKit.INK_RED), UIKit.font_strong()), inner, 2, 10))
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
	# Ink on paper; danger is a red caption with paper lettering.
	var danger: bool = colour == UIKit.RED
	_banner_box.add_theme_stylebox_override("panel", UIKit.ink_card(Ink.DANGER if danger else UIKit.PAPER, UIKit.SPACE_LG, 0, 5))
	_banner.add_theme_color_override("font_color", UIKit.PAPER if danger else UIKit.INK)
	_banner_box.visible = not text.is_empty()


func set_info(title: String, body: String) -> void:
	_info_title.text = title
	_info_body.text = Glossary.linkify(body, glossary, UIKit.INK_LINK)


## Where the info balloon's tail points, in screen pixels; null for no tail.
func point_info_at(where: Variant) -> void:
	if _info_tail != null:
		_info_tail.point_at(where)


func set_hint(text: String) -> void:
	_hint.text = text
	_hint_box.visible = not text.is_empty()


func set_controls(can_undo: bool, can_end: bool) -> void:
	_undo.disabled = not can_undo
	_end_turn.disabled = not can_end


## `in_run`: the fight belongs to a run, so the only way on is CONTINUE (back to the map);
## a practice fight offers FIGHT AGAIN and TITLE instead.
## `headline` (046): a big win names itself -- GATE BROKEN!, WARLORD DOWN! -- instead of every
## win reading YARD CLEARED!.
func show_result(won: bool, body: String, in_run: bool = false, headline: String = "") -> void:
	_result_title.text = headline if won and not headline.is_empty() else ("YARD CLEARED!" if won else ("CREW LOST!" if not in_run else "RUN OVER!"))
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
	# Play-test 9: a fixed pip in fixed rows of PIPS_PER_ROW, so the card never changes size
	# with a machine's HP (a long bar used to squeeze or stretch every pip).
	var bar := GridContainer.new()
	bar.columns = PIPS_PER_ROW
	bar.add_theme_constant_override("h_separation", 2)
	bar.add_theme_constant_override("v_separation", 2)
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
		"heat": heat, "move": move, "act": act, "portrait": portrait, "frame": frame}


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
	var slim: bool = not selected
	var rows: int = (maxi(1, int(card["max_hp"])) + PIPS_PER_ROW - 1) / PIPS_PER_ROW
	var extra: float = float(maxi(0, rows - 2)) * (PIP_SIZE.y + 2.0)
	button.custom_minimum_size = (SLIM_SIZE if slim else CARD_SIZE) + Vector2(0, extra)
	button.size = button.custom_minimum_size
	for key: String in ["frame", "detail", "arms"]:
		(parts[key] as Control).visible = not slim

	(parts["name"] as Label).text = String(card["name"]).to_upper() + ("" if alive else "  ·  WRECKED")
	(parts["detail"] as Label).text = String(card["detail"])
	var bar: GridContainer = parts["bar"]
	var full: int = maxi(1, int(card["max_hp"]))
	var now: int = int(card["hp"])
	if bar.get_child_count() != full or int(bar.get_meta("hp", -1)) != now:
		bar.set_meta("hp", now)
		for child: Node in bar.get_children():
			child.queue_free()
		for n: int in full:
			var pip := Panel.new()
			pip.custom_minimum_size = PIP_SIZE
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var colour: Color = (Ink.DANGER if now * 3 <= full else Ink.YOURS) if n < now else UIKit.PAPER_CARD
			var pip_style := InkBox.new(colour, 0, 0)
			pip_style.border_width = 1.5
			pip_style.shadow = Vector2.ZERO
			pip.add_theme_stylebox_override("panel", pip_style)
			bar.add_child(pip)
	(parts["portrait"] as MachinePortrait).show_machine(card.get("parts", []), int(card.get("level", 0)), alive)
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


## The opening card (play-test 7: "the objective must be visible from the moment the board is").
## The fight's name and its objective over a cover while the board is drawn and every effect
## is warmed up behind it; the cover then fades and the card with it.
func show_opening(title: String, objective: String) -> void:
	hide_opening()
	_opening = Control.new()
	_opening.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_opening)
	_opening.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color("11141c")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_opening.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_opening.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.ink_card(UIKit.PAPER_CARD, UIKit.SPACE_XXL, UIKit.SPACE_XL, 8))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.SPACE_MD)
	panel.add_child(box)
	var name := _label(title.to_upper(), 52, UIKit.INK, UIKit.font_comic())
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name)
	var caption := _label("OBJECTIVE", UIKit.SIZE_MICRO, UIKit.INK_DIM, UIKit.font_comic())
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(caption)
	var goal := _label(objective, 30, UIKit.INK, UIKit.font_comic())
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goal.custom_minimum_size = Vector2(760, 0)
	box.add_child(goal)


## 039, the comic's story beat: the opening as three panels in a row, each a little askew, each
## with its caption box -- `[{ caption, big, small }]`. Shown and hidden like the plain card.
func show_opening_strip(panels: Array) -> void:
	hide_opening()
	_opening = Control.new()
	_opening.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_opening)
	_opening.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color("11141c")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_opening.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_opening.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.SPACE_XL)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(row)
	var tilts: Array = [-3.0, 2.0, -2.0]
	var fills: Array = [UIKit.PAPER_CARD, Ink.DANGER, UIKit.PAPER_CARD]
	for i: int in panels.size():
		var data: Dictionary = panels[i]
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(500, 420)
		panel.add_theme_stylebox_override("panel", UIKit.ink_card(fills[i % fills.size()], UIKit.SPACE_LG, UIKit.SPACE_LG, 8))
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# A container resets rotation (039): the tilted panel sits in a plain holder.
		var holder := Control.new()
		holder.custom_minimum_size = panel.custom_minimum_size + Vector2(20, 30)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(holder)
		holder.add_child(panel)
		panel.position = Vector2(10, 15)
		panel.rotation_degrees = float(tilts[i % tilts.size()])
		panel.pivot_offset = Vector2(250, 210)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", UIKit.SPACE_LG)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(box)
		box.add_child(UIKit.caption_title(String(data.get("caption", "")), 22, -1.5))
		var red: bool = fills[i % fills.size()] == Ink.DANGER
		# The panel's picture: the boss, or the crew -- the real machines, drawn in ink.
		var machines: Array = data.get("machines", [])
		if not machines.is_empty():
			var pics := HBoxContainer.new()
			pics.alignment = BoxContainer.ALIGNMENT_CENTER
			pics.add_theme_constant_override("separation", UIKit.SPACE_SM)
			pics.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(pics)
			var side: int = 230 if machines.size() == 1 else 130
			for parts: Variant in machines:
				var portrait := MachinePortrait.new(Vector2i(side, side), "full", true)
				pics.add_child(portrait)
				portrait.show_machine(parts as Array, 0, true, Color(data.get("paint", Color(0, 0, 0, 0))))
		var big := _label(String(data.get("big", "")), 54 if machines.is_empty() else 40, UIKit.PAPER if red else UIKit.INK, UIKit.font_letters())
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		big.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		big.custom_minimum_size = Vector2(450, 0)
		big.size_flags_vertical = Control.SIZE_EXPAND_FILL
		big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(big)
		var small := _label(String(data.get("small", "")), 22, UIKit.PAPER if red else UIKit.INK, UIKit.font_comic())
		small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		small.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		small.custom_minimum_size = Vector2(450, 0)
		box.add_child(small)
		# Panels land one after another, like reading a strip.
		holder.modulate.a = 0.0
		var tween := holder.create_tween()
		tween.tween_interval(0.25 + 0.45 * float(i))
		tween.tween_property(holder, "modulate:a", 1.0, 0.18)


func hide_opening(fade: float = 0.0) -> void:
	if _opening == null or not is_instance_valid(_opening):
		_opening = null
		return
	var card: Control = _opening
	_opening = null
	if fade <= 0.0:
		card.queue_free()
		return
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := card.create_tween()
	tween.tween_property(card, "modulate:a", 0.0, fade)
	tween.tween_callback(card.queue_free)


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
	# 039: the result is a SPLASH -- the sound-effect face, big, at a slant.
	_result_title = _label("", 72, UIKit.INK, UIKit.font_letters())
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title.add_theme_constant_override("outline_size", 10)
	_result_title.add_theme_color_override("font_outline_color", UIKit.INK)
	_result_title.rotation_degrees = -3.0
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
