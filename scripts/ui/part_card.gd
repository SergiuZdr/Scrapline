class_name PartCard
extends RefCounted

## A part as a card, the same on every screen: a RARITY BANNER (not just an edge colour --
## play-test 2 could not tell rarity from the edge), the picture, the name, what it does,
## and whether it would beat anything the crew has fitted.

const RARITY_NAMES: PackedStringArray = ["COMMON", "UNCOMMON", "RARE", "LEGENDARY"]
const SOCKET_NAMES: PackedStringArray = ["frame", "core", "left arm", "right arm", "module"]
const SOCKETS: Dictionary = {"chassis": [0], "core": [1], "arm": [2, 3], "module": [4]}

## 082 (A22): the flavour line's face -- the body face, slanted, since no italic is bundled.
static var _italic: FontVariation


## A Button holding the card. `compare_crew`: the run's crew, to say whether the part is
## an upgrade; pass [] to skip the comparison.
static func build(db: ContentDB, id: String, size: Vector2, compare_crew: Array = []) -> Button:
	var parts: Dictionary = db.parts
	var rarity: int = clampi(int((parts.get(id, {}) as Dictionary).get("rarity", 1)), 1, 4)
	var colour: Color = PartText.rarity_colour(parts, id)
	var button := Button.new()
	button.custom_minimum_size = size
	button.focus_mode = Control.FOCUS_NONE
	var style := UIKit.card(UIKit.SURFACE, 0, 0, 0)
	style.border_color = UIKit.HAIRLINE
	style.set_border_width_all(3)
	style.shadow_offset = Vector2(4, 4)
	for key: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(key, style)
	var hover: InkBox = style.duplicate()
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
	# Play-test 8: every line on a card is fitted to its width (`UIKit.fit`), none runs past it.
	var inner_w: float = size.x - UIKit.SPACE_SM * 2 - 6
	var rarity_label: Label = _label(RARITY_NAMES[rarity - 1], UIKit.SIZE_MICRO, UIKit.PAGE_TEXT, UIKit.font_comic())
	var rarity_w: float = UIKit.font_comic().get_string_size(rarity_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.SIZE_MICRO).x + 2
	banner_row.add_child(UIKit.fit(rarity_label, rarity_w))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_row.add_child(spacer)
	# Who made it, then what it is: "KESSLER ARM" (011: parts from one maker add up).
	var made: Label = _label(("%s %s" % [PartText.maker_short(db.makers, parts, id), PartText.slot_label(parts, id)]).strip_edges(),
		UIKit.SIZE_MICRO, Color(UIKit.PAGE_TEXT, 0.75), UIKit.font_comic())
	made.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	banner_row.add_child(UIKit.fit(made, maxf(40.0, inner_w - rarity_w - UIKit.SPACE_SM), 1, 9))

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
		# 086: a card with a drawback strip gives its picture less height, so nothing runs off the card.
		picture.custom_minimum_size = Vector2(0, size.y * (0.18 if not PartText.drawback_of(parts, id).is_empty() else 0.3))
		# The picture takes whatever height the text leaves, so a tall card is not half empty.
		picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(picture)
	inner.add_child(UIKit.fit(_label(PartText.name_of(parts, id), 20, colour, UIKit.font_comic()), inner_w, 1, 13))
	inner.add_child(UIKit.fit(_label(PartText.summary(parts, id, db.combat_abilities), UIKit.SIZE_MICRO, UIKit.TEXT_DIM), inner_w, 2, 10))
	# 086 (A9): a legendary's rule, then its drawback on a line of its own, never folded into the summary.
	var rule: String = PartText.rule_of(parts, id)
	var drawback: String = PartText.drawback_of(parts, id)
	if not rule.is_empty():
		var rule_line := UIKit.fit(_label("RULE: " + rule, UIKit.SIZE_MICRO, colour, UIKit.font_strong()), inner_w, 2, 9)
		rule_line.name = "rule"
		inner.add_child(rule_line)
	# 086 (A10): the rule its maker's full set gives ("KESSLER SET (3): THORNS + ANCHORED").
	var set_line: String = set_rule_line(db, id)
	if not set_line.is_empty():
		var verb := UIKit.fit(_label(set_line, UIKit.SIZE_MICRO, UIKit.GREEN, UIKit.font_strong()), inner_w, 1, 9)
		verb.name = "set_rule"
		inner.add_child(verb)
	# 082 (A22): the line the part's maker would say about it, in italics. 086: a legendary's card
	# keeps it in the tooltip only -- its rule and drawback need the room.
	var said: String = flavour(parts, id)
	if not said.is_empty():
		button.tooltip_text = said
	if not said.is_empty() and drawback.is_empty():
		var lines: int = 2 if size.y >= 220.0 and rule.is_empty() else 1
		var line := UIKit.fit(_label(said, UIKit.SIZE_MICRO, UIKit.TEXT_DIM, italic()), inner_w, lines, 9)
		line.name = "flavour"
		inner.add_child(line)
	if not compare_crew.is_empty():
		var verdict: Array = compare(parts, id, compare_crew)
		if not String(verdict[0]).is_empty():
			inner.add_child(UIKit.fit(_label(String(verdict[0]), UIKit.SIZE_MICRO, verdict[1], UIKit.font_strong()), inner_w, 1, 9))
		var completes: String = set_verdict(db, id, compare_crew)
		if not completes.is_empty():
			inner.add_child(UIKit.fit(_label(completes, UIKit.SIZE_MICRO, UIKit.GREEN, UIKit.font_strong()), inner_w, 1, 9))
	# 086 (A9, the user): a legendary's drawback in its own red-edged strip along the card's foot.
	if not drawback.is_empty():
		var strip := PanelContainer.new()
		strip.name = "drawback_strip"
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var edge := InkBox.new(UIKit.SURFACE_SUNK, UIKit.SPACE_SM, 3)
		edge.border = UIKit.RED
		edge.border_width = 3.0
		edge.shadow = Vector2.ZERO
		strip.add_theme_stylebox_override("panel", edge)
		var cost_line := UIKit.fit(_label("DRAWBACK: " + drawback, UIKit.SIZE_MICRO, UIKit.RED, UIKit.font_strong()),
			size.x - UIKit.SPACE_SM * 2 - 12, 2, 9)
		cost_line.name = "drawback"
		strip.add_child(cost_line)
		box.add_child(strip)
	return button


## "MAKES KESSLER x3 ON BRUTE" when fitting the part would give a machine a set bonus it does
## not have yet, or "". Asks `CombatSetup.sets_of`, the count the fight itself uses.
static func set_verdict(db: ContentDB, id: String, crew: Array) -> String:
	var parts: Dictionary = db.parts
	var maker: String = String((parts.get(id, {}) as Dictionary).get("maker", ""))
	if maker.is_empty():
		return ""
	var slot: String = String((parts.get(id, {}) as Dictionary).get("slot", ""))
	for member: Dictionary in crew:
		if not bool(member["alive"]):
			continue
		var loadout: Array = member["parts"]
		var before: int = _tiers(db, loadout, maker)
		for s: int in 5:
			if RunSetup.socket_slot(s) != slot:
				continue
			var trial: Array = loadout.duplicate()
			trial[s] = id
			var after: int = _tiers(db, trial, maker)
			if after > before:
				for entry: Dictionary in CombatSetup.sets_of(PackedStringArray(trial), parts, db.makers):
					if String(entry["maker"]) == maker:
						return "MAKES %s x%d ON %s" % [PartText.maker_short(db.makers, parts, id), int(entry["count"]),
							String(member["name"]).to_upper()]
	return ""


## 086 (A10): "KESSLER SET (3): THORNS + ANCHORED" -- the rule this part's maker gives at its full
## set -- or "" for a part without a maker or a maker whose sets add only numbers.
static func set_rule_line(db: ContentDB, id: String) -> String:
	var maker: String = String((db.parts.get(id, {}) as Dictionary).get("maker", ""))
	var rule: Array = PartText.set_rule(db.makers, maker)
	if rule.is_empty():
		return ""
	return "%s SET (%d): %s" % [PartText.maker_short(db.makers, db.parts, id), int(rule[0]), " + ".join(rule[1] as PackedStringArray)]


static func _tiers(db: ContentDB, loadout: Array, maker: String) -> int:
	for entry: Dictionary in CombatSetup.sets_of(PackedStringArray(loadout), db.parts, db.makers):
		if String(entry["maker"]) == maker:
			return (entry["active"] as Array).size()
	return 0


## `[text, colour]`: which fitted part this one would beat, by rarity, or that it beats none.
static func compare(parts: Dictionary, id: String, crew: Array) -> Array:
	var target: Array = fit_target(parts, id, crew)
	if target.is_empty():
		# Play-test 11: "not rarer than yours" said nothing a player could use; say nothing.
		return ["", UIKit.TEXT_FAINT]
	var member: Dictionary = crew[int(target[0])]
	var current: String = String((member["parts"] as Array)[int(target[1])])
	if current.is_empty():
		return ["FILLS %s'S EMPTY %s" % [String(member["name"]).to_upper(), SOCKET_NAMES[int(target[1])].to_upper()], UIKit.GREEN]
	return ["BEATS %s'S %s" % [String(member["name"]).to_upper(), PartText.name_of(parts, current).to_upper()], UIKit.GREEN]


## 082 (A21): `[crew index, socket]` the verdict names -- the first living machine whose socket for
## this slot is empty or holds a part of lower rarity -- or `[]`. FIT IT NOW fits it there.
static func fit_target(parts: Dictionary, id: String, crew: Array) -> Array:
	var slot: String = String((parts.get(id, {}) as Dictionary).get("slot", ""))
	var rarity: int = int((parts.get(id, {}) as Dictionary).get("rarity", 1))
	for i: int in crew.size():
		var member: Dictionary = crew[i]
		if not bool(member["alive"]):
			continue
		for s: int in (SOCKETS.get(slot, []) as Array):
			var current: String = String((member["parts"] as Array)[s])
			if current.is_empty() or rarity > int((parts.get(current, {}) as Dictionary).get("rarity", 1)):
				return [i, s]
	return []


## 082 (A22): the part's flavour line from its JSON, or "". A tuned part speaks with its base's.
static func flavour(parts: Dictionary, id: String) -> String:
	var own: String = String((parts.get(id, {}) as Dictionary).get("flavour", ""))
	return own if not own.is_empty() else String((parts.get(PartTuning.base_of(id), {}) as Dictionary).get("flavour", ""))


## The flavour face: the body face with a slant.
static func italic() -> Font:
	if _italic == null:
		_italic = FontVariation.new()
		_italic.base_font = UIKit.font()
		_italic.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.22, 1), Vector2.ZERO)
	return _italic


static func _label(text: String, size: int, colour: Color, face: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	# Always a face of our own: `UIKit.fit` measures with it, and a card is built before it
	# is in a tree that could lend it the theme's.
	label.add_theme_font_override("font", face if face != null else UIKit.font())
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
