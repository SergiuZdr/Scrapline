extends Control

## Refit, by hand: drag a part from the hold onto a socket, from a socket back into the
## hold or onto another machine, or onto SCRAP to break it down. Play-test 1 and 2 asked
## for exactly this ("take a part and hover it where I want to equip it").
##
## Tap-then-tap does the same for anyone who does not drag: tap a part (it lifts, and the
## sockets it fits light up), then tap where it goes.
##
## Every change goes through `Run.apply`, so a refit is saved like everything else.

signal closed

const SOCKET_NAMES: PackedStringArray = ["FRAME", "CORE", "LEFT ARM", "RIGHT ARM", "MODULE"]
const CARD := Vector2(188, 212)

## What is being moved: `{ "from": "hold", "index" }` or `{ "from": "socket", "crew", "socket" }`.
var _held: Dictionary = {}
var _status: Label
var _body: VBoxContainer
## `[button, crew, socket]` for every socket on screen, so a drag can light the ones that fit.
var _sockets: Array = []
## The result of the last change, shown after the rebuild.
var _message: String = ""


func _ready() -> void:
	UIKit.apply(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = UIKit.BG
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Its own screen, not a sheet over the map: the map's labels showing through read as clutter.
	add_child(UIKit.backdrop())
	var scroll := ScrollContainer.new()
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 30)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", UIKit.SPACE_MD)
	scroll.add_child(_body)
	_rebuild()


func _notification(what: int) -> void:
	# A drag that is dropped nowhere (or cancelled) puts the part back down.
	if what == NOTIFICATION_DRAG_END and not _held.is_empty():
		_held = {}
		_restyle_sockets()


func _rebuild() -> void:
	for child: Node in _body.get_children():
		child.queue_free()
	_sockets = []
	var state: RunState = Run.state

	var head := HBoxContainer.new()
	_body.add_child(head)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_box)
	title_box.add_child(_label("REFIT", UIKit.SIZE_DISPLAY, UIKit.TEXT, UIKit.font_display()))
	title_box.add_child(_label("Drag a part onto a socket to fit it. Drag a fitted part back to the hold, onto another machine, or onto SCRAP. (Or tap a part, then tap where it goes.)",
		UIKit.SIZE_BODY, UIKit.TEXT_DIM))
	var done := _button("BACK TO MAP", UIKit.primary(), UIKit.BG, Vector2(280, 64))
	done.pressed.connect(func() -> void: closed.emit())
	head.add_child(done)

	_status = _label(_message if _held.is_empty() and not _message.is_empty() else _status_text(), UIKit.SIZE_BODY, UIKit.AMBER, UIKit.font_strong())
	_message = ""
	_body.add_child(_status)

	# The three machines, each a column of five sockets.
	var machines := HBoxContainer.new()
	machines.add_theme_constant_override("separation", UIKit.SPACE_LG)
	_body.add_child(machines)
	for i: int in state.crew.size():
		machines.add_child(_machine_column(i))

	# The hold and the scrap bin.
	var lower := HBoxContainer.new()
	lower.add_theme_constant_override("separation", UIKit.SPACE_LG)
	_body.add_child(lower)
	var hold_box := VBoxContainer.new()
	hold_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lower.add_child(hold_box)
	var over: bool = state.overfull()
	hold_box.add_child(_label("HOLD  %d / %d%s" % [state.cargo.size(), state.hold_size,
		"   OVER -- fit or scrap %d before moving on" % (state.cargo.size() - state.hold_size) if over else ""],
		UIKit.SIZE_HEADING, UIKit.RED if over else UIKit.TEXT, UIKit.font_strong()))
	var hold_drop := PanelContainer.new()
	hold_drop.add_theme_stylebox_override("panel", UIKit.inset(UIKit.SURFACE, UIKit.RADIUS_CARD, UIKit.SPACE_MD, UIKit.SPACE_MD))
	hold_drop.custom_minimum_size = Vector2(0, CARD.y + UIKit.SPACE_MD * 2)
	hold_drop.set_drag_forwarding(Callable(), _can_drop_hold, _drop_hold)
	hold_box.add_child(hold_drop)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", UIKit.SPACE_SM)
	grid.add_theme_constant_override("v_separation", UIKit.SPACE_SM)
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	hold_drop.add_child(grid)
	for c: int in state.cargo.size():
		var card: Button = PartCard.build(Run.db, state.cargo[c], CARD, state.crew)
		var from: Dictionary = {"from": "hold", "index": c}
		card.set_drag_forwarding(_drag_from.bind(from), _can_drop_hold, _drop_hold)
		card.pressed.connect(_tap_source.bind(from))
		if _held == from:
			card.modulate = Color(1.2, 1.1, 0.7)
		grid.add_child(card)
	if state.cargo.is_empty():
		grid.add_child(_label("Empty. Salvage from fights and scrapyards lands here.", UIKit.SIZE_BODY, UIKit.TEXT_FAINT))

	lower.add_child(_scrap_bin())


func _machine_column(i: int) -> Control:
	var member: Dictionary = Run.state.crew[i]
	var alive: bool = bool(member["alive"])
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(560, 0)
	col.add_theme_constant_override("separation", UIKit.SPACE_XS)
	col.add_child(_label("%s  ·  %s" % [String(member["name"]).to_upper(),
		("%d / %d HP" % [int(member["hp"]), RunSim.max_hp(Run.setup, member)]) if alive else "WRECK: rebuild it at a workshop"],
		UIKit.SIZE_HEADING, UIKit.TEXT if alive else UIKit.RED, UIKit.font_strong()))
	for s: int in 5:
		col.add_child(_socket(i, s, alive))
	return col


func _socket(i: int, s: int, alive: bool) -> Control:
	var part: String = String((Run.state.crew[i]["parts"] as Array)[s])
	var button := Button.new()
	button.custom_minimum_size = Vector2(560, 72)
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = not alive
	var style: StyleBoxFlat = _socket_style(i, s)
	_sockets.append([button, i, s])
	for key: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(key, style)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UIKit.SPACE_MD)
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, UIKit.SPACE_SM)
	var picture := TextureRect.new()
	picture.texture = PartText.thumb(part)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(56, 56)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	text.add_child(_label("%s  ·  %s" % [SOCKET_NAMES[s], PartText.name_of(Run.db.parts, part)], UIKit.SIZE_BODY,
		PartText.rarity_colour(Run.db.parts, part).lightened(0.3) if not part.is_empty() else UIKit.RED, UIKit.font_strong()))
	var summary := _label(PartText.summary(Run.db.parts, part, Run.db.combat_abilities), UIKit.SIZE_LABEL, UIKit.TEXT_DIM)
	summary.custom_minimum_size = Vector2(470, 0)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.max_lines_visible = 2
	text.add_child(summary)
	if alive:
		var source: Dictionary = {"from": "socket", "crew": i, "socket": s}
		button.set_drag_forwarding(_drag_from.bind(source) if not part.is_empty() and s != 0 else Callable(),
			_can_drop_socket.bind(i, s), _drop_socket.bind(i, s))
		button.pressed.connect(_tap_socket.bind(i, s))
	return button


func _scrap_bin() -> Control:
	var bin := PanelContainer.new()
	bin.custom_minimum_size = Vector2(230, CARD.y + 40)
	var style := UIKit.inset(UIKit.SURFACE_SUNK, UIKit.RADIUS_CARD, UIKit.SPACE_MD, UIKit.SPACE_MD)
	style.border_color = UIKit.RED.darkened(0.2)
	style.set_border_width_all(2)
	bin.add_theme_stylebox_override("panel", style)
	bin.set_drag_forwarding(Callable(), _can_drop_bin, _drop_bin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bin.add_child(box)
	box.add_child(_label("SCRAP", UIKit.SIZE_DISPLAY, UIKit.RED, UIKit.font_display()))
	var value: String = "Drop a part here to break it down.\\nCommon 3 · Uncommon 6 · Rare 10 scrap"
	if not _held.is_empty():
		value = "Break down %s for +%d scrap" % [PartText.name_of(Run.db.parts, _held_part()), RunSim.scrap_value(Run.setup, _held_part())]
	var text := _label(value.replace("\\n", "\n"), UIKit.SIZE_LABEL, UIKit.TEXT_DIM)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(200, 0)
	box.add_child(text)
	var tap := _button("SCRAP IT" if not _held.is_empty() else "", UIKit.secondary(), UIKit.RED, Vector2(180, 48))
	tap.visible = not _held.is_empty()
	tap.pressed.connect(func() -> void: _drop_bin(Vector2.ZERO, _held))
	box.add_child(tap)
	return bin


# --- Drag and drop -----------------------------------------------------------

func _drag_from(_at: Vector2, source: Dictionary) -> Variant:
	_held = source
	var preview := _label(PartText.name_of(Run.db.parts, _held_part()), UIKit.SIZE_HEADING, UIKit.AMBER, UIKit.font_strong())
	set_drag_preview(preview)
	_restyle_sockets.call_deferred()
	return source


func _can_drop_socket(_at: Vector2, data: Variant, i: int, s: int) -> bool:
	if not (data is Dictionary):
		return false
	var ok: bool = _fits(data, i, s)
	if ok:
		_status.text = "Fit %s as %s's %s%s" % [PartText.name_of(Run.db.parts, _part_of(data)), Run.state.crew[i]["name"],
			SOCKET_NAMES[s].to_lower(), "" if String(Run.state.crew[i]["parts"][s]).is_empty()
				else " (the %s goes to the hold)" % PartText.name_of(Run.db.parts, String(Run.state.crew[i]["parts"][s]))]
	return ok


func _drop_socket(_at: Vector2, data: Variant, i: int, s: int) -> void:
	var from: Dictionary = data
	var ok: bool
	if String(from["from"]) == "hold":
		ok = Run.apply([RunSim.REFIT, i, s, int(from["index"])])
	else:
		# Socket to socket: through the hold, as two ordinary refits.
		ok = Run.apply([RunSim.REFIT, int(from["crew"]), int(from["socket"]), -1]) \
			and Run.apply([RunSim.REFIT, i, s, Run.state.cargo.size() - 1])
	_after(ok, "Fitted." if ok else "That part does not fit there.")


func _can_drop_hold(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and String((data as Dictionary).get("from", "")) == "socket"


func _drop_hold(_at: Vector2, data: Variant) -> void:
	var from: Dictionary = data
	var ok: bool = Run.apply([RunSim.REFIT, int(from["crew"]), int(from["socket"]), -1])
	_after(ok, "Moved to the hold.")


func _can_drop_bin(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and not (data as Dictionary).is_empty()


func _drop_bin(_at: Vector2, data: Variant) -> void:
	var from: Dictionary = data
	var part: String = _part_of(from)
	var ok: bool
	if String(from["from"]) == "hold":
		ok = Run.apply([RunSim.SCRAP_PART, int(from["index"])])
	else:
		ok = Run.apply([RunSim.REFIT, int(from["crew"]), int(from["socket"]), -1]) \
			and Run.apply([RunSim.SCRAP_PART, Run.state.cargo.size() - 1])
	_after(ok, "Broke down %s for %d scrap." % [PartText.name_of(Run.db.parts, part), RunSim.scrap_value(Run.setup, part)])


# --- Tap then tap --------------------------------------------------------------

func _tap_source(source: Dictionary) -> void:
	_held = {} if _held == source else source
	Audio.play("ui_confirm", -14.0)
	_rebuild()


func _tap_socket(i: int, s: int) -> void:
	if not _held.is_empty() and _fits(_held, i, s):
		_drop_socket(Vector2.ZERO, _held, i, s)
		return
	if not String(Run.state.crew[i]["parts"][s]).is_empty() and s != 0:
		_tap_source({"from": "socket", "crew": i, "socket": s})


# --- Helpers -------------------------------------------------------------------

func _after(ok: bool, message: String) -> void:
	_held = {}
	Audio.play("ui_confirm" if ok else "ui_deny", -10.0)
	_message = message if ok else "Not possible: " + message
	# Deferred: this runs inside a drop callback, and rebuilding now would free the nodes
	# the engine is still delivering the drop through.
	_rebuild.call_deferred()


## Restyles the sockets in place. Rebuilding under an active drag would free the very node
## being dragged, so a drag only restyles.
func _restyle_sockets() -> void:
	for entry: Array in _sockets:
		var button: Button = entry[0]
		if not is_instance_valid(button):
			continue
		button.add_theme_stylebox_override("normal", _socket_style(int(entry[1]), int(entry[2])))
		button.add_theme_stylebox_override("hover", _socket_style(int(entry[1]), int(entry[2])))


func _socket_style(i: int, s: int) -> StyleBoxFlat:
	var fits: bool = _held_fits(i, s)
	var style := UIKit.inset(UIKit.SURFACE_HIGH if fits else UIKit.SURFACE, UIKit.RADIUS_CONTROL, UIKit.SPACE_MD, UIKit.SPACE_SM)
	if fits:
		style.border_color = UIKit.AMBER
		style.set_border_width_all(2)
	elif _held == {"from": "socket", "crew": i, "socket": s}:
		style.border_color = UIKit.BLUE
		style.set_border_width_all(2)
	return style


func _fits(data: Dictionary, i: int, s: int) -> bool:
	if data.is_empty() or not bool(Run.state.crew[i]["alive"]):
		return false
	if String(data["from"]) == "socket" and int(data["crew"]) == i and int(data["socket"]) == s:
		return false
	var part: String = _part_of(data)
	return String((Run.db.parts.get(part, {}) as Dictionary).get("slot", "")) == RunSetup.socket_slot(s)


func _held_fits(i: int, s: int) -> bool:
	return not _held.is_empty() and _fits(_held, i, s)


func _held_part() -> String:
	return _part_of(_held)


func _part_of(data: Dictionary) -> String:
	if data.is_empty():
		return ""
	if String(data["from"]) == "hold":
		var index: int = int(data["index"])
		return Run.state.cargo[index] if index < Run.state.cargo.size() else ""
	return String(Run.state.crew[int(data["crew"])]["parts"][int(data["socket"])])


func _status_text() -> String:
	if not _held.is_empty():
		return "Holding %s: tap a lit socket to fit it, or SCRAP IT." % PartText.name_of(Run.db.parts, _held_part())
	return ""


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
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, ink)
	for key: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(key, style)
	return button
