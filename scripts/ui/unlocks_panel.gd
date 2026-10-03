class_name UnlocksPanel
extends Control

## Every between-run unlock as a goal (027, play-test 9: "it is unclear when the new bonuses
## come"): what it gives, what earns it, how far the player is, and which are held. Opened from
## the title and from the end of a run. Display only: it reads the profile and changes nothing.

signal closed

var _meta: Dictionary
var _db: ContentDB
var _held: Array
var _stats: Dictionary
## Unlock ids the run just earned, ringed as new.
var _fresh: Array


static func open(parent: Node, db: ContentDB, held: Array, stats: Dictionary, fresh: Array = []) -> UnlocksPanel:
	var panel := UnlocksPanel.new()
	panel._db = db
	panel._meta = db.meta
	panel._held = held
	panel._stats = stats
	panel._fresh = fresh
	parent.add_child(panel)
	return panel


func _ready() -> void:
	UIKit.apply(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.03, 0.05, 0.86)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.ink_card(UIKit.PAPER_CARD, UIKit.SPACE_XL, UIKit.SPACE_LG, 8))
	card.position = Vector2(200, 24)
	card.custom_minimum_size = Vector2(1520, 1030)
	add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.SPACE_SM)
	card.add_child(box)

	var head := HBoxContainer.new()
	box.add_child(head)
	head.add_child(UIKit.caption_title("UNLOCKS", 44))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var entries: Array = _meta.get("unlocks", [])
	var held_count: int = entries.filter(func(e: Dictionary) -> bool: return _held.has(String(e["id"]))).size()
	head.add_child(_label("%d of %d held  ·  %d runs  ·  %d fights won  ·  furthest act %d  ·  %d won" % [held_count, entries.size(),
		int(_stats.get("runs", 0)), int(_stats.get("fights", 0)), int(_stats.get("act", 1)), int(_stats.get("wins", 0))],
		UIKit.SIZE_BODY, UIKit.INK_DIM, UIKit.font_strong()))
	box.add_child(UIKit.fit(_label("Runs leave these behind. Each is earned at the END of a run, when its numbers are reached; a new run then has it. Parts join the salvage, scrapyards and traders; crews and tiers are chosen at NEW RUN.",
		UIKit.SIZE_BODY, UIKit.INK_DIM, UIKit.font_strong()), 1440, 2, 12))

	# Play-test 11: what is new is said first, by name, in the gain colour.
	if not _fresh.is_empty():
		var names: PackedStringArray = []
		for entry: Dictionary in entries:
			if _fresh.has(String(entry["id"])):
				names.append(_gives(entry).get_slice("  (", 0))
		box.add_child(UIKit.fit(_label("NEW SINCE YOU LAST LOOKED:  " + ",  ".join(names), 24, UIKit.INK_GREEN, UIKit.font_comic()), 1440, 2, 14))
	# 034: three columns -- milestones (runs, fights, acts) down the first two, MISSIONS (feats
	# in fights) in the third, each under its own heading.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", UIKit.SPACE_LG)
	# 040: rows say what a part does now, so the list scrolls rather than run off the card.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1460, 780)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	scroll.add_child(columns)
	var cols: Array[VBoxContainer] = []
	for c: int in 3:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", UIKit.SPACE_XS)
		columns.add_child(col)
		cols.append(col)
	var milestones: Array = entries.filter(func(e: Dictionary) -> bool: return not bool(e.get("mission", false)))
	var missions: Array = entries.filter(func(e: Dictionary) -> bool: return bool(e.get("mission", false)))
	cols[0].add_child(_label("MILESTONES", 24, UIKit.INK, UIKit.font_comic()))
	cols[1].add_child(_label(" ", 24, UIKit.INK, UIKit.font_comic()))
	cols[2].add_child(_label("MISSIONS  ·  do it in a fight", 24, UIKit.INK, UIKit.font_comic()))
	var half: int = (milestones.size() + 1) / 2
	var next_id: String = String(Meta.next_unlock(_held, _meta).get("id", ""))
	for i: int in milestones.size():
		cols[0 if i < half else 1].add_child(_row(milestones[i], String(milestones[i]["id"]) == next_id))
	for entry: Dictionary in missions:
		cols[2].add_child(_row(entry, false))

	var close := Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size = Vector2(220, 60)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_override("font", UIKit.font_comic())
	close.add_theme_font_size_override("font_size", 24)
	for state: String in ["normal", "hover", "focus"]:
		close.add_theme_stylebox_override(state, UIKit.ink_button(Ink.ACTION))
	close.add_theme_stylebox_override("pressed", UIKit.ink_button(Ink.ACTION, true))
	for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		close.add_theme_color_override(key, UIKit.INK)
	close.pressed.connect(func() -> void:
		closed.emit()
		queue_free())
	box.add_child(close)


## One unlock: a mark (held, new, or a progress bar), what it gives, and what earns it.
func _row(entry: Dictionary, is_next: bool) -> Control:
	var id: String = String(entry["id"])
	var held: bool = _held.has(id)
	var fresh: bool = _fresh.has(id)
	var row := PanelContainer.new()
	var style: InkBox = UIKit.ink_card(UIKit.PAPER if held else UIKit.PAPER_DIM, UIKit.SPACE_MD, UIKit.SPACE_XS, 3)
	if fresh or is_next:
		style.band_width = 9.0
		style.band = Ink.GAIN if fresh else Ink.ACTION
	row.add_theme_stylebox_override("panel", style)
	row.custom_minimum_size = Vector2(476, 96)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", UIKit.SPACE_MD)
	row.add_child(line)
	var picture: Control = _picture(entry)
	picture.modulate = Color(1, 1, 1, 1.0 if held else 0.45)
	line.add_child(picture)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	line.add_child(text)
	var status: String = "NEW  ·  " if fresh else ("" if held else ("NEXT  ·  " if is_next else ""))
	text.add_child(UIKit.fit(_label(status + _gives(entry), 20, UIKit.INK if held else UIKit.INK_DIM, UIKit.font_comic()), 270, 1, 12))
	text.add_child(UIKit.fit(_label(String(entry.get("text", "")), UIKit.SIZE_LABEL, UIKit.INK_DIM, UIKit.font_strong()), 270, 2, 11))
	# 040 (play-test 12: "impossible to see what the new parts do"): a part says what it does, in
	# its card's words, and the row opens its card.
	if String(entry.get("kind", "")) == "part":
		text.add_child(UIKit.fit(_label(PartText.summary(_db.parts, String(entry["what"]), _db.combat_abilities),
			UIKit.SIZE_LABEL, UIKit.INK, UIKit.font_strong()), 270, 2, 11))
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.tooltip_text = "Click to see the part's card"
		row.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				_show_card(String(entry["what"])))
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_child(right)
	if held:
		right.add_child(_label("NEW!", 34, UIKit.INK_GREEN, UIKit.font_letters()) if fresh else _label("HELD", 22, UIKit.INK_GREEN, UIKit.font_comic()))
	else:
		var p: Array = Meta.progress(_stats, entry)
		right.add_child(_label("%d / %d" % [int(p[0]), int(p[1])], 20, UIKit.INK, UIKit.font_comic()))
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(96, 12)
		bar.show_percentage = false
		bar.max_value = float(p[1])
		bar.value = float(p[0])
		right.add_child(bar)
	return row


## What an unlock looks like (043, play-test 13: a crew and a tier had an empty square): a part
## its picture; a crew its three frames side by side; a tier a numbered badge; the ending a star.
func _picture(entry: Dictionary) -> Control:
	var kind: String = String(entry.get("kind", ""))
	if kind == "crew":
		var crew: Dictionary = (_meta.get("crews", {}) as Dictionary).get(entry["what"], {})
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(84, 64)
		holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var specs: Array = crew.get("crew", [])
		for i: int in specs.size():
			var thumb := TextureRect.new()
			thumb.texture = PartText.thumb(String(((specs[i] as Dictionary)["parts"] as Array)[0]))
			thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			thumb.size = Vector2(44, 56)
			thumb.position = Vector2(float(i) * 20.0, 4.0 if i == 1 else 8.0)
			thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(thumb)
		if specs.size() == 3:
			holder.move_child(holder.get_child(1), 2)
		return holder
	if kind == "tier" or kind == "ending":
		var badge := PanelContainer.new()
		badge.custom_minimum_size = Vector2(64, 58)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style: InkBox = UIKit.ink_button(Ink.DANGER if kind == "tier" else Ink.ACTION)
		style.jag = 4.0
		style.content_margin_left = 4
		style.content_margin_right = 4
		badge.add_theme_stylebox_override("panel", style)
		var mark := Label.new()
		mark.text = ["I", "II", "III", "IV"][clampi(int(entry["what"]), 0, 3)] if kind == "tier" else "END"
		mark.add_theme_font_override("font", UIKit.font_letters())
		mark.add_theme_font_size_override("font_size", 30 if kind == "tier" else 24)
		mark.add_theme_color_override("font_color", UIKit.PAPER if kind == "tier" else UIKit.INK)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(mark)
		return badge
	var picture := TextureRect.new()
	picture.custom_minimum_size = Vector2(58, 58)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if kind == "part":
		picture.texture = PartText.thumb(String(entry["what"]))
	return picture


## The part's full card over the screen; any click closes it.
func _show_card(id: String) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card: Button = PartCard.build(_db, id, Vector2(380, 470))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(card)
	shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			shade.queue_free())


## What an unlock gives, in words: a part (and its slot), a crew, a tier.
func _gives(entry: Dictionary) -> String:
	match String(entry.get("kind", "")):
		"part":
			var part: Dictionary = _db.parts.get(entry["what"], {})
			return "%s  (%s)" % [String(part.get("name", entry["what"])).to_upper(), String(part.get("slot", "part"))]
		"crew":
			return "%s  (starting crew)" % String(((_meta.get("crews", {}) as Dictionary).get(entry["what"], {}) as Dictionary).get("name", ""))
		"ending":
			return "THE LINE IS CUT  (the ending)"
		_:
			return "%s  (harder tier)" % String(((_meta.get("tiers", []) as Array)[int(entry["what"])] as Dictionary).get("name", ""))


func _label(text: String, size: int, colour: Color, face: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", face)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
