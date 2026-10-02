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
	head.add_child(_label("UNLOCKS", 48, UIKit.INK, UIKit.font_comic()))
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

	# 034: three columns -- milestones (runs, fights, acts) down the first two, MISSIONS (feats
	# in fights) in the third, each under its own heading.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", UIKit.SPACE_LG)
	box.add_child(columns)
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
	row.custom_minimum_size = Vector2(476, 76)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", UIKit.SPACE_MD)
	row.add_child(line)
	var picture := TextureRect.new()
	picture.custom_minimum_size = Vector2(58, 58)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if String(entry.get("kind", "")) == "part":
		picture.texture = PartText.thumb(String(entry["what"]))
	picture.modulate = Color(1, 1, 1, 1.0 if held else 0.45)
	line.add_child(picture)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	line.add_child(text)
	var status: String = "NEW  ·  " if fresh else ("" if held else ("NEXT  ·  " if is_next else ""))
	text.add_child(UIKit.fit(_label(status + _gives(entry), 20, UIKit.INK if held else UIKit.INK_DIM, UIKit.font_comic()), 270, 1, 12))
	text.add_child(UIKit.fit(_label(String(entry.get("text", "")), UIKit.SIZE_LABEL, UIKit.INK_DIM, UIKit.font_strong()), 270, 2, 11))
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_child(right)
	if held:
		right.add_child(_label("HELD", 22, UIKit.INK_GREEN, UIKit.font_comic()))
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


## What an unlock gives, in words: a part (and its slot), a crew, a tier.
func _gives(entry: Dictionary) -> String:
	match String(entry.get("kind", "")):
		"part":
			var part: Dictionary = _db.parts.get(entry["what"], {})
			return "%s  (%s)" % [String(part.get("name", entry["what"])).to_upper(), String(part.get("slot", "part"))]
		"crew":
			return "%s  (starting crew)" % String(((_meta.get("crews", {}) as Dictionary).get(entry["what"], {}) as Dictionary).get("name", ""))
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
