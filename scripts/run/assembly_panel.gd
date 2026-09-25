extends Control

## The assembly bay (play-test 4: "at the start of the run there should be a way to
## customise the initial robots from basic parts").
##
## Three machines side by side, each whole on its lift, each socket a row you step through
## with the arrows: every common part without limit, plus one each of the defaults'
## uncommons (`run.json` `assembly`). The draft is only a draft until ROLL OUT, which is a
## single `RunSim.ASSEMBLE` -- so the build is part of the run's action list like
## everything else, and a replay rebuilds it exactly.

signal done

const SOCKET_NAMES: PackedStringArray = ["FRAME", "CORE", "LEFT ARM", "RIGHT ARM", "MODULE"]
const COLUMN_WIDTH: float = 590.0

## One five-part list per machine, in socket order.
var _draft: Array = []
var _defaults: Array = []
var _columns: HBoxContainer
var _portraits: Array[MachinePortrait] = []
var _status: Label


func _ready() -> void:
	UIKit.apply(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var floor_colour := ColorRect.new()
	floor_colour.color = UIKit.BG
	add_child(floor_colour)
	floor_colour.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UIKit.backdrop())
	for member: Dictionary in Run.state.crew:
		_draft.append((member["parts"] as Array).duplicate())
		_defaults.append((member["parts"] as Array).duplicate())

	var story: Dictionary = Run.db.story.get("briefing", {})
	var title := _label(String(story.get("bay", "THE ASSEMBLY BAY")), UIKit.SIZE_DISPLAY, UIKit.TEXT, UIKit.font_display())
	title.position = Vector2(40, 20)
	add_child(title)
	var line := _label(String(story.get("bay_text", "")) + "  Basic parts as many as you like; one each of the Rend Saw, the Rail Lance and the Strider frame.",
		UIKit.SIZE_BODY, UIKit.TEXT_DIM)
	line.position = Vector2(42, 84)
	add_child(line)

	_columns = HBoxContainer.new()
	_columns.position = Vector2(40, 124)
	_columns.add_theme_constant_override("separation", UIKit.SPACE_LG)
	add_child(_columns)
	for i: int in _draft.size():
		_portraits.append(MachinePortrait.new(Vector2i(int(COLUMN_WIDTH), 380), "full"))

	var bar := HBoxContainer.new()
	bar.position = Vector2(40, 1080 - 92)
	bar.add_theme_constant_override("separation", UIKit.SPACE_MD)
	add_child(bar)
	var reset := _button("RESET", UIKit.secondary(), UIKit.TEXT, Vector2(180, 60))
	reset.pressed.connect(func() -> void:
		_draft = _defaults.duplicate(true)
		_rebuild())
	bar.add_child(reset)
	var shuffle := _button("RANDOMISE", UIKit.secondary(), UIKit.TEXT, Vector2(220, 60))
	shuffle.pressed.connect(_randomise)
	bar.add_child(shuffle)
	_status = _label("", UIKit.SIZE_BODY, UIKit.RED, UIKit.font_strong())
	_status.custom_minimum_size = Vector2(900, 0)
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_status)
	var go := _button("ROLL OUT", UIKit.primary(), UIKit.BG, Vector2(300, 64))
	go.pressed.connect(_roll_out)
	bar.add_child(go)
	_rebuild()


func _rebuild() -> void:
	for child: Node in _columns.get_children():
		_columns.remove_child(child)
		child.queue_free()
	for i: int in _draft.size():
		_columns.add_child(_column(i))


## One machine: whole, on its lift; its name as the frame will give it; its five sockets.
func _column(i: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(COLUMN_WIDTH, 0)
	panel.add_theme_stylebox_override("panel", UIKit.card(UIKit.SURFACE, UIKit.RADIUS_CARD, 0, UIKit.SPACE_SM))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.SPACE_XS)
	panel.add_child(box)
	var portrait: MachinePortrait = _portraits[i]
	if portrait.get_parent() != null:
		portrait.get_parent().remove_child(portrait)
	box.add_child(portrait)
	portrait.show_machine(_draft[i], 0, true, i + 1)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", UIKit.SPACE_XS)
	var margin := MarginContainer.new()
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, UIKit.SPACE_MD)
	margin.add_child(inner)
	box.add_child(margin)
	var member := {"name": "", "parts": _draft[i], "alive": true, "hp": 0, "level": 0}
	var unit: GridUnit = RunSim.preview_machine(Run.setup, member)
	inner.add_child(_label("%s  ·  %d HP  ·  MOVE %d" % [_name_of(i), unit.max_hp, unit.move], UIKit.SIZE_HEADING, UIKit.TEXT, UIKit.font_strong()))
	for s: int in 5:
		inner.add_child(_socket_row(i, s))
	return panel


func _socket_row(i: int, s: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.SPACE_SM)
	var part: String = String(_draft[i][s])
	var back := _button("<", UIKit.secondary(), UIKit.TEXT, Vector2(48, 58))
	back.pressed.connect(_step.bind(i, s, -1))
	row.add_child(back)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	text.add_child(_label("%s  ·  %s" % [SOCKET_NAMES[s], PartText.name_of(Run.db.parts, part)], UIKit.SIZE_BODY,
		PartText.rarity_colour(Run.db.parts, part).lightened(0.3), UIKit.font_strong()))
	var summary := _label(PartText.summary(Run.db.parts, part, Run.db.combat_abilities), UIKit.SIZE_LABEL, UIKit.TEXT_DIM)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.custom_minimum_size = Vector2(COLUMN_WIDTH - 170, 0)
	summary.max_lines_visible = 1
	text.add_child(summary)
	var next := _button(">", UIKit.secondary(), UIKit.TEXT, Vector2(48, 58))
	next.pressed.connect(_step.bind(i, s, 1))
	row.add_child(next)
	return row


## The next part on the bench for this socket, skipping any the other machines have
## already used up (the once-only extras).
func _step(i: int, s: int, by: int) -> void:
	var options: Array[String] = _options(s)
	if options.is_empty():
		return
	var at: int = options.find(String(_draft[i][s]))
	for tries: int in options.size():
		at = (at + by + options.size()) % options.size()
		if _available(options[at], i, s):
			_draft[i][s] = options[at]
			break
	Audio.play("cycle", -18.0)
	_status.text = ""
	_rebuild()


func _options(s: int) -> Array[String]:
	var out: Array[String] = []
	var slot: String = RunSetup.socket_slot(s)
	for id: Variant in Run.db.parts:
		var part: Dictionary = Run.db.parts[id]
		if String(part.get("slot", "")) == slot and RunSim.bench_count(Run.setup, String(id)) != 0:
			out.append(String(id))
	out.sort_custom(func(a: String, b: String) -> bool:
		var ra: int = Run.setup.rarity(a)
		var rb: int = Run.setup.rarity(b)
		return ra < rb or (ra == rb and PartText.name_of(Run.db.parts, a) < PartText.name_of(Run.db.parts, b)))
	return out


## Whether `part` can go in socket `s` of machine `i` without overdrawing the bench.
func _available(part: String, i: int, s: int) -> bool:
	var limit: int = RunSim.bench_count(Run.setup, part)
	if limit < 0:
		return true
	var used: int = 0
	for m: int in _draft.size():
		for k: int in 5:
			if (m != i or k != s) and String(_draft[m][k]) == part:
				used += 1
	return used < limit


## The name the frame will give this machine (the sim decides it on ROLL OUT; this only
## shows it): the frame's name, "II" for a second machine on the same frame.
func _name_of(i: int) -> String:
	var base: String = PartText.name_of(Run.db.parts, String(_draft[i][0])).replace(" Frame", "")
	var same: int = 0
	for m: int in i + 1:
		if PartText.name_of(Run.db.parts, String(_draft[m][0])).replace(" Frame", "") == base:
			same += 1
	return base.to_upper() + ("" if same == 1 else (" II" if same == 2 else " III"))


## A random legal build: presentation randomness is fine here -- only the chosen build
## reaches the run, as one action.
func _randomise() -> void:
	for i: int in _draft.size():
		for s: int in 5:
			var options: Array[String] = _options(s)
			options.shuffle()
			for part: String in options:
				if _available(part, i, s):
					_draft[i][s] = part
					break
	Audio.play("cycle", -14.0)
	_rebuild()


func _roll_out() -> void:
	if Run.apply([RunSim.ASSEMBLE, _draft.duplicate(true)]):
		Audio.play("ui_confirm", -8.0)
		done.emit()
	else:
		Audio.play("ui_deny", -8.0)
		_status.text = "That build is not possible from the bench."


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
