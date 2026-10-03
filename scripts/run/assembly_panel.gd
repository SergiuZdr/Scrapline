extends Control

## The assembly bay (play-test 4: "at the start of the run there should be a way to
## customise the initial robots from basic parts"). Play-test 9 asked for a new approach:
##
##   THE CREW (left)   three cards -- each machine's picture, its name (editable), its numbers;
##                     the one being built is ringed in amber.
##   THE LIFT (middle) the machine being built, big, with what it adds up to: HP, move, role,
##                     armour, damage, and its maker sets.
##   THE BENCH (right) the five sockets as tabs, and every part the bench has for the chosen
##                     socket as cards: tap one to fit it. Parts the bench has once say so.
##
## The draft is only a draft until ROLL OUT, which is one `RunSim.ASSEMBLE` (and a RENAME for
## each name changed) -- so the build is part of the run's action list like everything else.

signal done

const SOCKET_NAMES: PackedStringArray = ["FRAME", "CORE", "LEFT ARM", "RIGHT ARM", "MODULE"]
## 043 (play-test 13: "problems with column spacing"): three columns on one grid -- the crew,
## the lift, the bench -- each with its own width and a clear gutter between them.
const CREW_CARD := Vector2(400, 236)
const PORTRAIT := Vector2i(168, 220)
const PART_CARD := Vector2(198, 226)
const LIFT := Vector2i(690, 580)
const MARGIN: float = 40.0
const GUTTER: float = 40.0
const COLUMN_X: Array[float] = [MARGIN, MARGIN + 400.0 + GUTTER, MARGIN + 400.0 + GUTTER + 714.0 + GUTTER]
const BENCH_WIDTH: float = 1920.0 - MARGIN - (MARGIN + 400.0 + GUTTER + 714.0 + GUTTER)
const COLUMN_TOP: float = 168.0

## One five-part list per machine, in socket order.
var _draft: Array = []
var _defaults: Array = []
## The names as typed (027), one per machine.
var _names: Array = []
var _machine: int = 0
var _socket: int = 0
var _crew_box: VBoxContainer
var _lift_box: VBoxContainer
var _bench_box: VBoxContainer
var _portraits: Array[MachinePortrait] = []
var _lift: MachinePortrait
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
		_names.append(String(member["name"]))

	var story: Dictionary = Run.db.story.get("briefing", {})
	var title := UIKit.on_page(_label(String(story.get("bay", "THE ASSEMBLY BAY")), UIKit.SIZE_DISPLAY, UIKit.PAGE_TEXT, UIKit.font_display()), 10)
	title.position = Vector2(40, 16)
	add_child(title)
	var line := UIKit.on_page(_label(String(story.get("bay_text", "")) + "  Pick a machine on the left, a socket on the right, then a part.",
		UIKit.SIZE_BODY, UIKit.PAGE_TEXT, UIKit.font_strong()), 5)
	line.position = Vector2(42, 80)
	add_child(line)

	for c: int in 3:
		var head := UIKit.on_page(_label(["THE CREW", "ON THE LIFT", "THE BENCH"][c], 28, UIKit.PAGE_TEXT, UIKit.font_comic()), 6)
		head.position = Vector2(COLUMN_X[c], 120)
		add_child(head)

	_crew_box = VBoxContainer.new()
	_crew_box.position = Vector2(COLUMN_X[0], COLUMN_TOP)
	_crew_box.add_theme_constant_override("separation", UIKit.SPACE_MD)
	add_child(_crew_box)
	for i: int in _draft.size():
		_portraits.append(MachinePortrait.new(PORTRAIT, "full", true))

	var lift_panel := PanelContainer.new()
	lift_panel.position = Vector2(COLUMN_X[1], COLUMN_TOP)
	lift_panel.custom_minimum_size = Vector2(714, 0)
	lift_panel.add_theme_stylebox_override("panel", UIKit.ink_card(UIKit.PAPER_CARD, UIKit.SPACE_MD, UIKit.SPACE_SM, 6))
	add_child(lift_panel)
	_lift_box = VBoxContainer.new()
	_lift_box.add_theme_constant_override("separation", UIKit.SPACE_XS)
	lift_panel.add_child(_lift_box)
	_lift = MachinePortrait.new(LIFT, "full", true)

	_bench_box = VBoxContainer.new()
	_bench_box.position = Vector2(COLUMN_X[2], COLUMN_TOP)
	_bench_box.add_theme_constant_override("separation", UIKit.SPACE_SM)
	add_child(_bench_box)

	var bar := HBoxContainer.new()
	bar.position = Vector2(MARGIN, 1080 - 92)
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
	_status = _label("", UIKit.SIZE_BODY, Ink.DANGER, UIKit.font_strong())
	_status.custom_minimum_size = Vector2(1060, 0)
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_status)
	var go := _button("ROLL OUT", UIKit.primary(), UIKit.BG, Vector2(300, 64))
	go.pressed.connect(_roll_out)
	bar.add_child(go)
	_rebuild()
	Hints.show_once(self, "bay", Run.db, Vector2(1440, 16))


func _rebuild() -> void:
	# The portraits are kept (each renders its machine once) and only re-seated.
	for portrait: MachinePortrait in _portraits + [_lift]:
		if portrait.get_parent() != null:
			portrait.get_parent().remove_child(portrait)
	for box: Node in [_crew_box, _lift_box, _bench_box]:
		for child: Node in box.get_children():
			box.remove_child(child)
			child.queue_free()
	for i: int in _draft.size():
		_crew_box.add_child(_crew_card(i))
	_build_lift()
	_build_bench()


# --- The crew ----------------------------------------------------------------

func _crew_card(i: int) -> Control:
	var card := Button.new()
	card.custom_minimum_size = CREW_CARD
	card.focus_mode = Control.FOCUS_NONE
	var style: InkBox = UIKit.ink_card(UIKit.PAPER_CARD, 0, 0, 7 if i == _machine else 4)
	if i == _machine:
		style.band_width = 9.0
		style.band = Ink.ACTION
	for key: String in ["normal", "hover", "pressed", "focus"]:
		card.add_theme_stylebox_override(key, style)
	card.pressed.connect(func() -> void:
		_machine = i
		Audio.play("ui_confirm", -16.0)
		_rebuild())
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UIKit.SPACE_SM)
	card.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, UIKit.SPACE_SM)
	row.offset_left = UIKit.SPACE_MD + 6
	var portrait: MachinePortrait = _portraits[i]
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait)
	portrait.show_machine(_draft[i], 0, true)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", 2)
	row.add_child(text)
	var unit: GridUnit = _unit(i)
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_child(UIKit.fit(_label(String(_names[i]).to_upper(), 30, UIKit.INK, UIKit.font_comic()), 196, 1, 16))
	text.add_child(UIKit.fit(_label("%s frame  ·  %s" % [_frame_name(i), unit.role.capitalize()], UIKit.SIZE_LABEL, UIKit.INK_DIM, UIKit.font_strong()), 196, 1, 11))
	text.add_child(_label("%d HP  ·  MOVE %d" % [unit.max_hp, unit.move], UIKit.SIZE_BODY, UIKit.INK, UIKit.font_comic()))
	for set_line: String in PartText.set_lines(Run.db.parts, Run.db.makers, _draft[i]):
		text.add_child(UIKit.fit(_label(set_line, UIKit.SIZE_MICRO, UIKit.INK_GREEN, UIKit.font_strong()), 196, 2, 9))
	return card


# --- The lift ----------------------------------------------------------------

func _build_lift() -> void:
	var i: int = _machine
	var unit: GridUnit = _unit(i)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIKit.SPACE_SM)
	_lift_box.add_child(head)
	# The name is the player's (027): typed here, it goes in with ROLL OUT.
	var name_edit := LineEdit.new()
	name_edit.text = String(_names[i])
	name_edit.max_length = RunSim.NAME_MAX
	name_edit.custom_minimum_size = Vector2(420, 54)
	name_edit.add_theme_font_override("font", UIKit.font_comic())
	name_edit.add_theme_font_size_override("font_size", 34)
	name_edit.tooltip_text = "This machine's name -- type to change it"
	for key: String in ["normal", "focus", "read_only"]:
		name_edit.add_theme_stylebox_override(key, UIKit.ink_card(UIKit.PAPER, UIKit.SPACE_SM, 2, 3))
	name_edit.add_theme_color_override("font_color", UIKit.INK)
	name_edit.add_theme_color_override("caret_color", UIKit.INK)
	name_edit.text_changed.connect(func(text: String) -> void:
		var clean: String = RunSim.clean_name(text)
		if not clean.is_empty():
			_names[i] = clean
			var card: Button = _crew_box.get_child(i) as Button
			if card != null:
				# Only the card's name changes: a full rebuild would take the caret away.
				var label: Label = card.get_child(0).get_child(1).get_child(0) as Label
				label.text = clean.to_upper())
	head.add_child(name_edit)
	var hint := _label("<  CLICK THE NAME TO RENAME", UIKit.SIZE_LABEL, UIKit.INK_DIM, UIKit.font_comic())
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hint)
	_lift_box.add_child(_lift)
	_lift.show_machine(_draft[i], 0, true)
	var rules: Dictionary = Run.setup.combat_rules
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", UIKit.SPACE_SM)
	_lift_box.add_child(chips)
	for chip: Array in [["HP", str(unit.max_hp)], ["MOVE", str(unit.move)], ["HEAT CAP", str(unit.heat_cap)],
			["ROLE", unit.role.to_upper()], ["ARMOUR", String((rules.get("armor_types", []) as Array)[unit.armor_type]).to_upper()],
			["DAMAGE", String((rules.get("damage_types", []) as Array)[unit.damage_type]).to_upper()]]:
		chips.add_child(_chip(String(chip[0]), String(chip[1])))
	var sets: PackedStringArray = PartText.set_lines(Run.db.parts, Run.db.makers, _draft[i])
	_lift_box.add_child(UIKit.fit(_label("  ·  ".join(sets) if not sets.is_empty() else "No maker set yet: two parts from one maker add a bonus.",
		UIKit.SIZE_LABEL, UIKit.INK_GREEN if not sets.is_empty() else UIKit.INK_DIM, UIKit.font_strong()), float(LIFT.x), 1, 10))


func _chip(caption: String, value: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.ink_card(UIKit.PAPER, UIKit.SPACE_SM, 2, 2))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	panel.add_child(box)
	box.add_child(_label(caption, UIKit.SIZE_MICRO, UIKit.INK_DIM, UIKit.font_comic()))
	box.add_child(UIKit.fit(_label(value, 20, UIKit.INK, UIKit.font_comic()), 96, 1, 11))
	return panel


# --- The bench ---------------------------------------------------------------

func _build_bench() -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", UIKit.SPACE_XS)
	_bench_box.add_child(tabs)
	for s: int in 5:
		var tab := _button(SOCKET_NAMES[s], UIKit.choice() if s == _socket else UIKit.secondary(), UIKit.TEXT, Vector2((BENCH_WIDTH - 4.0 * UIKit.SPACE_XS - 12.0) / 5.0, 48))
		tab.add_theme_font_size_override("font_size", 18)
		tab.pressed.connect(func() -> void:
			_socket = s
			_rebuild())
		tabs.add_child(tab)
	var fitted: String = String(_draft[_machine][_socket])
	_bench_box.add_child(UIKit.on_page(UIKit.fit(_label("%s ON %s: %s" % [SOCKET_NAMES[_socket], String(_names[_machine]).to_upper(),
		PartText.name_of(Run.db.parts, fitted)], UIKit.SIZE_HEADING, UIKit.PAGE_TEXT, UIKit.font_comic()), BENCH_WIDTH - 10.0, 1, 12), 5))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(BENCH_WIDTH, 700)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_bench_box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", UIKit.SPACE_MD)
	grid.add_theme_constant_override("v_separation", UIKit.SPACE_MD)
	scroll.add_child(grid)
	for part: String in _options(_socket):
		var card: Button = PartCard.build(Run.db, part, PART_CARD)
		var free: bool = _available(part, _machine, _socket)
		var limit: int = RunSim.bench_count(Run.setup, part)
		if part == fitted:
			# The fitted one: ringed in amber, the selection.
			var ring: InkBox = UIKit.choice()
			ring.set_border_width_all(5)
			for key: String in ["normal", "hover", "pressed", "focus"]:
				card.add_theme_stylebox_override(key, ring)
		elif not free:
			card.disabled = true
			card.modulate = Color(1, 1, 1, 0.45)
		if limit > 0:
			card.tooltip_text = "The bench has %d of these" % limit
			var note := _label("ONLY %d" % limit if free or part == fitted else "IN USE", UIKit.SIZE_MICRO, Ink.DANGER, UIKit.font_comic())
			card.add_child(note)
			note.position = Vector2(PART_CARD.x - 64, PART_CARD.y - 22)
		card.pressed.connect(func() -> void:
			if part != fitted and free:
				_draft[_machine][_socket] = part
				Audio.play("cycle", -16.0)
				_status.text = ""
				_rebuild())
		grid.add_child(card)


## The next part on the bench for this socket, skipping any the other machines have
## already used up (the once-only extras). Kept for the arrows the tests drive.
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


func _unit(i: int) -> GridUnit:
	return RunSim.preview_machine(Run.setup, {"name": "", "parts": _draft[i], "alive": true, "hp": 0, "level": 0})


func _frame_name(i: int) -> String:
	return PartText.name_of(Run.db.parts, String(_draft[i][0])).replace(" Frame", "")


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
	if not Run.apply([RunSim.ASSEMBLE, _draft.duplicate(true)]):
		Audio.play("ui_deny", -8.0)
		_status.text = "That build is not possible from the bench."
		return
	# Names changed in the bay (027): one RENAME each, remembered for this crew's next run.
	for i: int in _names.size():
		if String(_names[i]) != String(Run.state.crew[i]["name"]):
			Run.rename(i, String(_names[i]))
	Audio.play("ui_confirm", -8.0)
	done.emit()


func _label(text: String, font_size: int, colour: Color, face: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_font_override("font", face if face != null else UIKit.font())
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
