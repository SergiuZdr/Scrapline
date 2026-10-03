extends SceneTree

## 041: three directions for comic panels and buttons, side by side on the same content, for the
## user to choose from:
##   godot --path . --resolution 1920x1080 --script res://tools/shot_ui_options.gd -- --out shots/ui_options.png

func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[args.find("--out") + 1] if args.has("--out") else "shots/ui_options.png"
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	host.add_child(UIKit.backdrop())
	var row := HBoxContainer.new()
	row.position = Vector2(40, 40)
	row.add_theme_constant_override("separation", 40)
	host.add_child(row)
	for option: String in ["A", "B", "C"]:
		row.add_child(_column(option))
	for i: int in 20:
		await process_frame
	print("shot: %s (%s)" % [out, error_string(root.get_texture().get_image().save_png(out))])
	quit()


func _column(option: String) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 26)
	col.custom_minimum_size = Vector2(580, 0)
	var names: Dictionary = {"A": "A  ·  PULP: hand-inked, halftone corners", "B": "B  ·  POP ART: bold, bursts, dots", "C": "C  ·  INKED PANELS: double lines, flat gutters"}
	col.add_child(UIKit.on_page(_label(String(names[option]), 24, UIKit.PAGE_TEXT, UIKit.font_comic()), 6))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(option))
	panel.custom_minimum_size = Vector2(560, 0)
	col.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(UIKit.caption_title("REFINERY", 38))
	var text := _label("A Combine refinery with one furnace still banked. Feed it a part and something better comes out.", 18, UIKit.INK, UIKit.font_strong())
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(500, 0)
	box.add_child(text)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style(option))
	card.custom_minimum_size = Vector2(240, 130)
	box.add_child(card)
	var inner := VBoxContainer.new()
	card.add_child(inner)
	inner.add_child(_label("UNCOMMON", 12, UIKit.BLUE, UIKit.font_comic()))
	inner.add_child(_label("Belt Feeder", 26, UIKit.BLUE, UIKit.font_comic()))
	inner.add_child(_label("+1 pierce on shots", 15, UIKit.INK_DIM, UIKit.font_strong()))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 18)
	box.add_child(buttons)
	buttons.add_child(_button("GARAGE", _button_style(option, false), Vector2(180, 58)))
	buttons.add_child(_button("MOVE ON", _button_style(option, true), Vector2(230, 64)))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 14)
	col.add_child(bar)
	bar.add_child(_button("UNDO", _button_style(option, false), Vector2(170, 58)))
	bar.add_child(_button("END TURN", _button_style(option, true), Vector2(240, 64)))
	return col


func _panel_style(option: String) -> InkBox:
	var s := InkBox.new(UIKit.PAPER_CARD, 26, 20)
	match option:
		"A":
			s.border_width = 4.0
			s.wobble = 1.6
			s.ramp = Color(UIKit.INK, 0.22)
			s.shadow = Vector2(8, 8)
		"B":
			s.fill = Color("fff6d8")
			s.border_width = 6.0
			s.shadow = Vector2(12, 12)
			s.shadow_colour = Color("e0442f")
			s.dots = Color(Color("2f9bd8"), 0.16)
		"C":
			s.border_width = 5.0
			s.double_line = true
			s.wobble = 0.6
			s.shadow = Vector2.ZERO
			s.dots = Color(UIKit.INK, 0.06)
	return s


func _card_style(option: String) -> InkBox:
	var s := _panel_style(option)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.border_width = 3.0
	s.shadow = Vector2(5, 5) if option != "C" else Vector2.ZERO
	return s


func _button_style(option: String, primary: bool) -> InkBox:
	var s := InkBox.new(Ink.ACTION if primary else UIKit.PAPER, 18, 8)
	match option:
		"A":
			s.border_width = 3.5
			s.wobble = 1.4
			s.shadow = Vector2(6, 6)
			if primary:
				s.ramp = Color(UIKit.INK, 0.25)
		"B":
			s.border_width = 5.0
			s.shadow = Vector2(7, 7)
			s.shadow_colour = Color("e0442f") if not primary else UIKit.INK
			if primary:
				s.jag = 7.0
			else:
				s.skew = -0.18
		"C":
			s.border_width = 4.0
			s.double_line = primary
			s.skew = -0.12
			s.shadow = Vector2(4, 4)
			s.fill = Ink.DANGER if primary else UIKit.PAPER
	return s


func _button(text: String, style: InkBox, size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.add_theme_font_override("font", UIKit.font_letters() if style.jag > 0.0 else UIKit.font_comic())
	b.add_theme_font_size_override("font_size", 26)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(key, UIKit.PAPER if style.fill == Ink.DANGER else UIKit.INK)
	for key: String in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(key, style)
	return b


func _label(text: String, size: int, colour: Color, face: Font) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", face)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l
