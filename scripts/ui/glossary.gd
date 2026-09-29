class_name Glossary
extends RefCounted

## The game's words (012; play-test 1: "names and jargon are explained nowhere").
##
## `linkify` turns every glossary term in a text into a link; `label` is a RichTextLabel that
## opens a term's card when a link is tapped; `open` shows the whole glossary. Tap, never
## hover: every interaction works with tap alone (plans/platform-and-ui.md, rule 1).
##
## The words live in `data/glossary.json` (`ContentDB.glossary`). A term's `forms` are the
## spellings that become links, matched as whole words in any case, longest first -- so
## "scrap pile" wins over "scrap".

static var _regex: RegEx
static var _forms: Dictionary = {}


## `text` with every glossary term wrapped in a link. Brackets in the text are escaped, so
## what comes back is always valid BBCode.
static func linkify(text: String, glossary: Dictionary, link: Color = UIKit.BLUE) -> String:
	_build(glossary)
	var safe: String = text.replace("[", "\u0001").replace("]", "\u0002")
	var out: String = ""
	var last: int = 0
	if _regex != null:
		for found: RegExMatch in _regex.search_all(safe):
			var id: String = String(_forms.get(found.get_string().to_lower(), ""))
			out += safe.substr(last, found.get_start() - last)
			out += "[url=%s][color=#%s]%s[/color][/url]" % [id, link.to_html(false), found.get_string()]
			last = found.get_end()
	out += safe.substr(last)
	return out.replace("\u0001", "[lb]").replace("\u0002", "[rb]")


## The ids of the terms `text` would link, in order of appearance (for tests and screens).
static func terms_in(text: String, glossary: Dictionary) -> PackedStringArray:
	_build(glossary)
	var out: PackedStringArray = []
	if _regex == null:
		return out
	for found: RegExMatch in _regex.search_all(text):
		var id: String = String(_forms.get(found.get_string().to_lower(), ""))
		if not out.has(id):
			out.append(id)
	return out


## A text whose terms can be tapped for their meaning.
static func label(text: String, font_size: int, colour: Color, glossary: Dictionary, width: float = 0.0,
		face: Font = null, link: Color = UIKit.BLUE) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if width > 0.0:
		rich.custom_minimum_size = Vector2(width, 0)
	rich.add_theme_font_override("normal_font", face if face != null else UIKit.font())
	rich.add_theme_font_size_override("normal_font_size", font_size)
	rich.add_theme_color_override("default_color", colour)
	rich.text = linkify(text, glossary, link)
	rich.meta_clicked.connect(func(meta: Variant) -> void: show_card(rich, String(meta), glossary))
	return rich


## A term's card over everything, beside the tap; the next tap anywhere closes it.
static func show_card(from: Node, id: String, glossary: Dictionary) -> Control:
	var term: Dictionary = (glossary.get("terms", {}) as Dictionary).get(id, {})
	if term.is_empty() or from == null or not from.is_inside_tree():
		return null
	var layer := CanvasLayer.new()
	layer.name = "glossary_card"
	layer.layer = 60
	var catcher := Control.new()
	catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			layer.queue_free())
	layer.add_child(catcher)
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = UIKit.card(UIKit.SURFACE_HIGH, UIKit.RADIUS_CARD, UIKit.SPACE_LG, UIKit.SPACE_MD)
	style.border_color = UIKit.BLUE.darkened(0.2)
	style.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", UIKit.SPACE_XS)
	card.add_child(box)
	box.add_child(_text(String(term.get("group", "")), UIKit.SIZE_MICRO, UIKit.TEXT_FAINT, UIKit.font_strong(), 0))
	box.add_child(_text(String(term.get("name", id)).to_upper(), UIKit.SIZE_TITLE, UIKit.TEXT, UIKit.font_strong(), 0))
	box.add_child(_text(String(term.get("text", "")), UIKit.SIZE_BODY, UIKit.TEXT_DIM, null, 440))
	catcher.add_child(card)
	from.get_tree().root.add_child(layer)
	var screen: Vector2 = from.get_viewport().get_visible_rect().size
	var at: Vector2 = from.get_viewport().get_mouse_position() + Vector2(18, 18)
	card.reset_size()
	var size: Vector2 = card.get_combined_minimum_size()
	card.position = Vector2(clampf(at.x, 16.0, screen.x - size.x - 16.0), clampf(at.y, 16.0, screen.y - size.y - 16.0))
	return card


## The whole glossary, over everything, until CLOSE.
static func open(from: Node, glossary: Dictionary) -> Control:
	if from == null or not from.is_inside_tree():
		return null
	var layer := CanvasLayer.new()
	layer.name = "glossary"
	layer.layer = 55
	var panel: Control = (load("res://scripts/ui/glossary_panel.gd") as GDScript).new()
	panel.set("glossary", glossary)
	layer.add_child(panel)
	panel.tree_exited.connect(layer.queue_free)
	from.get_tree().root.add_child(layer)
	return panel


static func _build(glossary: Dictionary) -> void:
	if _regex != null or glossary.is_empty():
		return
	var forms: Array = []
	var terms: Dictionary = glossary.get("terms", {})
	var ids: Array = terms.keys()
	ids.sort()
	for id: Variant in ids:
		for form: Variant in ((terms[id] as Dictionary).get("forms", []) as Array):
			if not _forms.has(String(form).to_lower()):
				_forms[String(form).to_lower()] = String(id)
				forms.append(String(form))
	if forms.is_empty():
		return
	forms.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length() or (a.length() == b.length() and a < b))
	var escaped: PackedStringArray = []
	for form: String in forms:
		escaped.append(_escape(form))
	_regex = RegEx.create_from_string("(?i)\\b(" + "|".join(escaped) + ")\\b")


static func _escape(text: String) -> String:
	var out: String = ""
	for c: String in text:
		out += ("\\" + c) if ".^$*+?()[]{}|\\".contains(c) else c
	return out


static func _text(text: String, size: int, colour: Color, face: Font, width: float) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	if face != null:
		label.add_theme_font_override("font", face)
	if width > 0.0:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(width, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
