class_name PartCard
extends RefCounted

## A part as a card, the same on every screen: a RARITY BANNER (not just an edge colour --
## play-test 2 could not tell rarity from the edge), the picture, the name, what it does,
## and whether it would beat anything the crew has fitted.

const RARITY_NAMES: PackedStringArray = ["COMMON", "UNCOMMON", "RARE"]


## A Button holding the card. `compare_crew`: the run's crew, to say whether the part is
## an upgrade; pass [] to skip the comparison.
static func build(db: ContentDB, id: String, size: Vector2, compare_crew: Array = []) -> Button:
	var parts: Dictionary = db.parts
	var rarity: int = clampi(int((parts.get(id, {}) as Dictionary).get("rarity", 1)), 1, 3)
	var colour: Color = PartText.rarity_colour(parts, id)
	var button := Button.new()
	button.custom_minimum_size = size
	button.focus_mode = Control.FOCUS_NONE
	var style := UIKit.inset(UIKit.SURFACE_HIGH, UIKit.RADIUS_CARD, 0, 0)
	style.border_color = colour.darkened(0.1)
	style.set_border_width_all(2)
	for key: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(key, style)
	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = UIKit.SURFACE_HIGH.lightened(0.06)
	button.add_theme_stylebox_override("hover", hover)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	button.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# The banner: rarity in words, on the rarity's colour.
	var banner := PanelContainer.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_stylebox_override("panel", UIKit.plain(colour.darkened(0.35), 0, UIKit.SPACE_SM, 2))
	box.add_child(banner)
	var banner_row := HBoxContainer.new()
	banner_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(banner_row)
	banner_row.add_child(_label(RARITY_NAMES[rarity - 1], UIKit.SIZE_MICRO, colour.lightened(0.45), UIKit.font_strong()))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_row.add_child(spacer)
	banner_row.add_child(_label(PartText.slot_label(parts, id), UIKit.SIZE_MICRO, UIKit.TEXT_DIM, UIKit.font_strong()))

	var inner := VBoxContainer.new()
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 2)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, UIKit.SPACE_SM)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_bottom", UIKit.SPACE_SM)
	margin.add_child(inner)
	box.add_child(margin)
	var tex: Texture2D = PartText.thumb(id)
	if tex != null:
		var picture := TextureRect.new()
		picture.texture = tex
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(0, size.y * 0.3)
		# The picture takes whatever height the text leaves, so a tall card is not half empty.
		picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(picture)
	inner.add_child(_label(PartText.name_of(parts, id), UIKit.SIZE_BODY, colour.lightened(0.3), UIKit.font_strong()))
	var text := _label(PartText.summary(parts, id, db.combat_abilities), UIKit.SIZE_MICRO, UIKit.TEXT_DIM)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(size.x - UIKit.SPACE_SM * 2, 0)
	inner.add_child(text)
	if not compare_crew.is_empty():
		var verdict: Array = compare(parts, id, compare_crew)
		inner.add_child(_label(String(verdict[0]), UIKit.SIZE_MICRO, verdict[1], UIKit.font_strong()))
	return button


## `[text, colour]`: which fitted part this one would beat, by rarity, or that it beats none.
static func compare(parts: Dictionary, id: String, crew: Array) -> Array:
	var slot: String = String((parts.get(id, {}) as Dictionary).get("slot", ""))
	var rarity: int = int((parts.get(id, {}) as Dictionary).get("rarity", 1))
	var sockets: Dictionary = {"chassis": [0], "core": [1], "arm": [2, 3], "module": [4]}
	var socket_names: PackedStringArray = ["frame", "core", "left arm", "right arm", "module"]
	for member: Dictionary in crew:
		if not bool(member["alive"]):
			continue
		for s: int in (sockets.get(slot, []) as Array):
			var current: String = String((member["parts"] as Array)[s])
			if current.is_empty():
				return ["FILLS %s'S EMPTY %s" % [String(member["name"]).to_upper(), socket_names[s].to_upper()], UIKit.GREEN]
			if rarity > int((parts.get(current, {}) as Dictionary).get("rarity", 1)):
				return ["BETTER THAN %s'S %s" % [String(member["name"]).to_upper(), PartText.name_of(parts, current).to_upper()], UIKit.GREEN]
	return ["NO RARER THAN WHAT YOU HAVE", UIKit.TEXT_FAINT]


static func _label(text: String, size: int, colour: Color, face: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	if face != null:
		label.add_theme_font_override("font", face)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
