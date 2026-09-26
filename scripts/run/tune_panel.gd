extends Control

## The workshop's TUNE bench (011): re-cut one part, one of two ways, once and for good.
##
## A tab per living machine and one for the hold; the parts on the left; the chosen part's
## two options on the right as two cards, each saying what it changes and what the numbers
## become. A card is the button, and pressing it is one `RunSim.TUNE`. A part already tuned
## is a label, not a dead button.

signal done

const SOCKET_NAMES: PackedStringArray = ["FRAME", "CORE", "LEFT ARM", "RIGHT ARM", "MODULE"]
## The numbers a tuning can change, in the order they are read out.
const SHOWN: PackedStringArray = ["hp", "move", "heat_cap", "damage", "heat", "vent", "armor", "range", "range_min",
	"pierce", "chain", "shove", "tears", "cooldown"]

## A crew index, or -1 for the hold.
var _tab: int = 0
## A socket (on a machine tab) or a place in the hold (on the hold tab); -1 = nothing chosen.
var _chosen: int = -1
var _message: String = ""
var _tabs: HBoxContainer
var _list: VBoxContainer
var _options: VBoxContainer
var _status: Label
var _scrap: Label


func _ready() -> void:
	UIKit.apply(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var floor_colour := ColorRect.new()
	floor_colour.color = UIKit.BG
	add_child(floor_colour)
	floor_colour.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UIKit.backdrop())
	var title := _label("TUNE A PART", UIKit.SIZE_DISPLAY, UIKit.TEXT, UIKit.font_display())
	title.position = Vector2(40, 20)
	add_child(title)
	var line := _label("Re-cut a part one of two ways. Each part can be tuned once, for good; a tuned part is marked +.",
		UIKit.SIZE_BODY, UIKit.TEXT_DIM)
	line.position = Vector2(42, 84)
	add_child(line)
	_scrap = _label("", UIKit.SIZE_TITLE, UIKit.TEXT, UIKit.font_numbers())
	_scrap.position = Vector2(1560, 30)
	add_child(_scrap)

	_tabs = HBoxContainer.new()
	_tabs.position = Vector2(40, 128)
	_tabs.add_theme_constant_override("separation", UIKit.SPACE_SM)
	add_child(_tabs)
	_list = VBoxContainer.new()
	_list.position = Vector2(40, 208)
	_list.custom_minimum_size = Vector2(880, 0)
	_list.add_theme_constant_override("separation", UIKit.SPACE_SM)
	add_child(_list)
	_options = VBoxContainer.new()
	_options.position = Vector2(960, 208)
	_options.custom_minimum_size = Vector2(920, 0)
	_options.add_theme_constant_override("separation", UIKit.SPACE_MD)
	add_child(_options)

	var bar := HBoxContainer.new()
	bar.position = Vector2(40, 1080 - 92)
	bar.add_theme_constant_override("separation", UIKit.SPACE_LG)
	add_child(bar)
	var back := _button("BACK TO WORKSHOP", UIKit.primary(), UIKit.BG, Vector2(320, 64))
	back.pressed.connect(func() -> void: done.emit())
	bar.add_child(back)
	_status = _label("", UIKit.SIZE_BODY, UIKit.TEXT, UIKit.font_strong())
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_status)
	for i: int in Run.state.crew.size():
		if bool(Run.state.crew[i]["alive"]):
			_tab = i
			break
	_rebuild()
	Hints.show_once(self, "tune", Run.db, Vector2(960, 660))


func _rebuild() -> void:
	for box: Node in [_tabs, _list, _options]:
		for child: Node in box.get_children():
			box.remove_child(child)
			child.queue_free()
	_scrap.text = "SCRAP %d" % Run.state.scrap
	_status.text = _message
	for i: int in Run.state.crew.size():
		var member: Dictionary = Run.state.crew[i]
		if bool(member["alive"]):
			_tabs.add_child(_tab_button(String(member["name"]).to_upper(), i))
	if not Run.state.cargo.is_empty():
		_tabs.add_child(_tab_button("HOLD  %d" % Run.state.cargo.size(), -1))
	var entries: Array = _entries()
	for k: int in entries.size():
		_list.add_child(_row(entries[k][0], String(entries[k][1]), String(entries[k][2])))
	_build_options()


## `[index, part, label]` for every part on the tab: sockets on a machine, places in the hold.
func _entries() -> Array:
	var out: Array = []
	if _tab >= 0:
		var parts: Array = Run.state.crew[_tab]["parts"]
		for s: int in 5:
			if not String(parts[s]).is_empty():
				out.append([s, String(parts[s]), SOCKET_NAMES[s]])
	else:
		for c: int in Run.state.cargo.size():
			out.append([c, Run.state.cargo[c], "HOLD"])
	return out


func _tab_button(text: String, tab: int) -> Button:
	var selected: bool = tab == _tab
	var button := _button(text, UIKit.choice() if selected else UIKit.secondary(), UIKit.AMBER if selected else UIKit.TEXT,
		Vector2(220, 56))
	button.pressed.connect(func() -> void:
		_tab = tab
		_chosen = -1
		_message = ""
		_rebuild())
	return button


## One part on the list. Tunable: a button with its price. Tuned already: a label saying how.
func _row(index: int, part: String, where: String) -> Control:
	var parts: Dictionary = Run.db.parts
	var tunable: bool = PartTuning.can_tune(parts, part)
	var chosen: bool = index == _chosen
	var holder: Control
	if tunable:
		var button := Button.new()
		button.name = "tune_row_%d" % index
		button.focus_mode = Control.FOCUS_NONE
		var style: StyleBoxFlat = UIKit.choice() if chosen else UIKit.inset(UIKit.SURFACE_HIGH, UIKit.RADIUS_CARD, 0, 0)
		for key: String in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(key, style)
		button.pressed.connect(func() -> void:
			_chosen = index
			_message = ""
			_rebuild())
		holder = button
	else:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UIKit.plain(UIKit.SURFACE, UIKit.RADIUS_CARD))
		holder = panel
	holder.custom_minimum_size = Vector2(880, 76)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UIKit.SPACE_MD)
	holder.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, UIKit.SPACE_SM)
	var picture := TextureRect.new()
	picture.texture = PartText.thumb(part)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(60, 60)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(_label("%s  ·  %s" % [where, PartText.name_of(parts, part)], UIKit.SIZE_HEADING,
		PartText.rarity_colour(parts, part).lightened(0.3), UIKit.font_strong()))
	var detail: String = PartText.tune_line(parts, part) if not tunable else "%s  ·  %s" % [
		PartText.maker_short(Run.db.makers, parts, part), PartText.slot_label(parts, part)]
	text.add_child(_label(detail, UIKit.SIZE_LABEL, UIKit.TEXT_DIM))
	var price := _label("%d SCRAP" % RunSim.tune_cost(Run.setup, part) if tunable else "TUNED", UIKit.SIZE_HEADING,
		UIKit.TEXT if tunable else UIKit.GREEN, UIKit.font_numbers())
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(price)
	return holder


## The chosen part's two options, side by side: each a card that IS the button.
func _build_options() -> void:
	var part: String = _chosen_part()
	if part.is_empty() or not PartTuning.can_tune(Run.db.parts, part):
		_options.add_child(_label("Pick a part on the left to see its two tunings.", UIKit.SIZE_BODY, UIKit.TEXT_FAINT))
		return
	var cost: int = RunSim.tune_cost(Run.setup, part)
	_options.add_child(_label(PartText.name_of(Run.db.parts, part).to_upper(), UIKit.SIZE_TITLE, UIKit.TEXT, UIKit.font_strong()))
	_options.add_child(_label("%s  ·  choose one, for %d scrap" % [PartText.summary(Run.db.parts, part, Run.db.combat_abilities), cost],
		UIKit.SIZE_LABEL, UIKit.TEXT_DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.SPACE_LG)
	_options.add_child(row)
	for option: int in PartTuning.OPTIONS.size():
		row.add_child(_option_card(part, option, cost))


func _option_card(part: String, option: int, cost: int) -> Control:
	var parts: Dictionary = Run.db.parts
	var tuned: Dictionary = parts.get(PartTuning.variant(part, option), {})
	var affordable: bool = Run.state.scrap >= cost
	var holder: Control
	if affordable:
		var button := Button.new()
		button.name = "tune_option_%d" % option
		button.focus_mode = Control.FOCUS_NONE
		var style: StyleBoxFlat = UIKit.choice()
		var hover: StyleBoxFlat = style.duplicate()
		hover.bg_color = UIKit.SURFACE_HIGH.lightened(0.05)
		for key: String in ["normal", "pressed", "focus"]:
			button.add_theme_stylebox_override(key, style)
		button.add_theme_stylebox_override("hover", hover)
		button.pressed.connect(_tune.bind(option))
		holder = button
	else:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UIKit.plain(UIKit.SURFACE, UIKit.RADIUS_CARD))
		holder = panel
	holder.custom_minimum_size = Vector2(440, 250)
	var inner := VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", UIKit.SPACE_SM)
	holder.add_child(inner)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, UIKit.SPACE_LG)
	inner.add_child(_label(String(tuned.get("tune", "")).to_upper(), UIKit.SIZE_TITLE, UIKit.TEXT, UIKit.font_strong()))
	inner.add_child(_label(PartText.bonus_text(tuned.get("tune_grid", {})), UIKit.SIZE_HEADING, UIKit.GREEN, UIKit.font_strong()))
	var before: Dictionary = (parts.get(part, {}) as Dictionary).get("grid", {})
	var after: Dictionary = tuned.get("grid", {})
	for key: String in SHOWN:
		if (tuned.get("tune_grid", {}) as Dictionary).has(key):
			var was: Variant = before.get(key, false if after.get(key) is bool else 0)
			inner.add_child(_label("%s  %s  ->  %s" % [key.replace("_", " "), _value(was), _value(after.get(key, 0))],
				UIKit.SIZE_BODY, UIKit.TEXT_DIM, UIKit.font_numbers()))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(spacer)
	inner.add_child(_label(("TUNE  ·  %d SCRAP" % cost) if affordable else ("NEEDS %d SCRAP (you have %d)" % [cost, Run.state.scrap]),
		UIKit.SIZE_HEADING, UIKit.AMBER if affordable else UIKit.TEXT_FAINT, UIKit.font_strong()))
	return holder


func _value(v: Variant) -> String:
	if v is bool:
		return "yes" if v else "no"
	return "%d" % int(v)


func _chosen_part() -> String:
	if _chosen < 0:
		return ""
	if _tab >= 0:
		var parts: Array = Run.state.crew[_tab]["parts"]
		return String(parts[_chosen]) if _chosen < parts.size() else ""
	return Run.state.cargo[_chosen] if _chosen < Run.state.cargo.size() else ""


func _tune(option: int) -> void:
	var part: String = _chosen_part()
	if Run.apply([RunSim.TUNE, _tab, _chosen, option]):
		Audio.play("level_up", -12.0)
		_message = "Tuned: %s is now %s." % [PartText.name_of(Run.db.parts, part),
			String((Run.db.parts.get(PartTuning.variant(part, option), {}) as Dictionary).get("tune", ""))]
	else:
		Audio.play("ui_deny", -10.0)
		_message = "That cannot be tuned now."
	_rebuild()


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
