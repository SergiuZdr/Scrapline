extends Control

## The GLOSSARY screen (012): every word the game uses, by group. Opened from the title, the
## map, the garage and the fight with `Glossary.open`; CLOSE (or Escape) goes back to where
## the player was. The same words are also links wherever they appear in running text.

var glossary: Dictionary = {}
var _group: String = ""
var _tabs: VBoxContainer
var _list: VBoxContainer


func _ready() -> void:
	UIKit.apply(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Opaque: a menu showing through the glossary reads as a second set of buttons.
	var shade := ColorRect.new()
	shade.color = UIKit.BG
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop: Control = UIKit.backdrop()
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var title := UIKit.on_page(_label("GLOSSARY", UIKit.SIZE_DISPLAY, UIKit.PAGE_TEXT, UIKit.font_display()), 10)
	title.position = Vector2(120, 60)
	add_child(title)
	var line := UIKit.on_page(_label("Every word the game uses. In running text they are links: tap one for its card.", UIKit.SIZE_BODY, UIKit.PAGE_TEXT, UIKit.font_strong()), 5)
	line.position = Vector2(122, 124)
	add_child(line)
	_tabs = VBoxContainer.new()
	_tabs.position = Vector2(120, 180)
	_tabs.add_theme_constant_override("separation", UIKit.SPACE_SM)
	add_child(_tabs)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(470, 180)
	scroll.size = Vector2(1330, 800)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(1300, 0)
	_list.add_theme_constant_override("separation", UIKit.SPACE_LG)
	scroll.add_child(_list)
	var close := Button.new()
	close.name = "close"
	close.text = "CLOSE"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(240, 60)
	close.position = Vector2(1560, 60)
	close.add_theme_font_override("font", UIKit.font_strong())
	close.add_theme_font_size_override("font_size", UIKit.SIZE_HEADING)
	for key: String in ["normal", "hover", "pressed", "focus"]:
		close.add_theme_stylebox_override(key, UIKit.primary())
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		close.add_theme_color_override(key, UIKit.BG)
	close.pressed.connect(queue_free)
	add_child(close)
	var groups: Array = glossary.get("groups", [])
	_group = String(groups[0]) if not groups.is_empty() else ""
	_rebuild()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		queue_free()


func _rebuild() -> void:
	for box: Node in [_tabs, _list]:
		for child: Node in box.get_children():
			box.remove_child(child)
			child.queue_free()
	for group: Variant in (glossary.get("groups", []) as Array):
		var chosen: bool = String(group) == _group
		var tab := Button.new()
		tab.text = String(group)
		tab.focus_mode = Control.FOCUS_NONE
		tab.custom_minimum_size = Vector2(300, 56)
		tab.add_theme_font_override("font", UIKit.font_comic())
		tab.add_theme_font_size_override("font_size", 22)
		var style: InkBox = UIKit.choice() if chosen else UIKit.secondary()
		for key: String in ["normal", "hover", "focus"]:
			tab.add_theme_stylebox_override(key, style)
		tab.add_theme_stylebox_override("pressed", UIKit.pressed(style))
		for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			tab.add_theme_color_override(key, UIKit.TEXT)
		tab.pressed.connect(func() -> void:
			_group = String(group)
			_rebuild())
		_tabs.add_child(tab)
	# Play-test 11: the damage-type wheel as a chart, at the top of its own tab.
	if _group == "DAMAGE TYPES":
		_list.add_child(TypeChart.build())
	var terms: Dictionary = glossary.get("terms", {})
	var ids: Array = terms.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return String((terms[a] as Dictionary).get("name", a)) < String((terms[b] as Dictionary).get("name", b)))
	for id: Variant in ids:
		var term: Dictionary = terms[id]
		if String(term.get("group", "")) != _group:
			continue
		# Each word on its own paper card (016): ink text needs paper under it.
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UIKit.card(UIKit.SURFACE, 0, UIKit.SPACE_LG, UIKit.SPACE_SM))
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 2)
		card.add_child(entry)
		entry.add_child(_label(String(term.get("name", id)).to_upper(), 26, UIKit.TEXT, UIKit.font_comic()))
		var text := _label(String(term.get("text", "")), UIKit.SIZE_BODY, UIKit.TEXT_DIM)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(1220, 0)
		entry.add_child(text)
		_list.add_child(card)


func _label(text: String, font_size: int, colour: Color, face: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	if face != null:
		label.add_theme_font_override("font", face)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
