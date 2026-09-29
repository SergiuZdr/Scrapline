class_name Hints
extends RefCounted

## First-time hints (012): one callout per screen, the first time it opens, saying the one
## thing that screen is for. GOT IT dismisses it for good -- the `Profile` remembers.
## The words are `data/tutorial.json` `hints`; their terms are glossary links.
##
## Uses the `Profile` autoload, so only screens call it (a `--script` tool that named this
## class would compile it before the autoloads exist).


## Shows hint `id` on `parent` at `at` unless it was seen; returns the callout or null.
static func show_once(parent: Control, id: String, db: ContentDB, at: Vector2, width: float = 440.0) -> Control:
	if parent.has_node("hint_" + id):
		return parent.get_node("hint_" + id)
	var profile: Node = parent.get_tree().root.get_node_or_null("Profile") if parent.is_inside_tree() else null
	var hint: Dictionary = (db.tutorial.get("hints", {}) as Dictionary).get(id, {})
	if profile == null or hint.is_empty() or bool(profile.call("seen", id)):
		return null
	var panel := PanelContainer.new()
	panel.name = "hint_" + id
	# Ink & Rust (016): a hint is the narrator speaking -- the pale caption box, like the coach.
	var style: InkBox = UIKit.ink_caption(UIKit.SPACE_LG, UIKit.SPACE_MD)
	style.border_width = 3.0
	style.shadow = Vector2(5, 5)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(width, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.SPACE_SM)
	panel.add_child(box)
	var title := Label.new()
	title.text = String(hint.get("title", ""))
	title.add_theme_font_override("font", UIKit.font_comic())
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", UIKit.TEXT)
	box.add_child(title)
	box.add_child(Glossary.label(String(hint.get("text", "")), UIKit.SIZE_BODY, UIKit.TEXT, db.glossary, width - UIKit.SPACE_LG * 2))
	var ok := Button.new()
	ok.name = "got_it"
	ok.text = "GOT IT"
	ok.focus_mode = Control.FOCUS_NONE
	ok.custom_minimum_size = Vector2(140, 44)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	ok.add_theme_font_override("font", UIKit.font_comic())
	ok.add_theme_font_size_override("font_size", UIKit.SIZE_HEADING)
	var ok_style: StyleBoxFlat = UIKit.secondary()
	for key: String in ["normal", "hover", "focus"]:
		ok.add_theme_stylebox_override(key, ok_style)
	ok.add_theme_stylebox_override("pressed", UIKit.pressed(ok_style))
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		ok.add_theme_color_override(key, UIKit.TEXT)
	ok.pressed.connect(func() -> void:
		profile.call("mark_seen", id)
		panel.queue_free())
	box.add_child(ok)
	parent.add_child(panel)
	panel.position = at
	return panel
