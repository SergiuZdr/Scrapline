class_name ComicStrip
extends RefCounted

## 039, the comic's story beats: a row (or grid) of panels, each with a caption box at a slant and
## its words lettered inside -- `[{ caption, text, big }]`. The run's briefing and an act's arrival
## are told this way. Panels land one after another, like reading a strip.

static func build(panels: Array, columns: int = 4, panel_size: Vector2 = Vector2(400, 300)) -> Control:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", UIKit.SPACE_LG)
	grid.add_theme_constant_override("v_separation", UIKit.SPACE_LG)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i: int in panels.size():
		var data: Dictionary = panels[i]
		var panel := PanelContainer.new()
		panel.custom_minimum_size = panel_size
		var red: bool = bool(data.get("red", false))
		panel.add_theme_stylebox_override("panel", UIKit.ink_card(Ink.DANGER if red else UIKit.PAPER_CARD, UIKit.SPACE_LG, UIKit.SPACE_MD, 7))
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(panel)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", UIKit.SPACE_MD)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(box)
		if not String(data.get("caption", "")).is_empty():
			box.add_child(UIKit.caption_title(String(data["caption"]), 20, -1.5 if i % 2 == 0 else 1.2))
		var ink: Color = UIKit.PAPER if red else UIKit.INK
		if not String(data.get("big", "")).is_empty():
			var big := Label.new()
			big.text = String(data["big"])
			big.add_theme_font_override("font", UIKit.font_letters())
			big.add_theme_font_size_override("font_size", 46)
			big.add_theme_color_override("font_color", ink)
			big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			big.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			big.custom_minimum_size = Vector2(panel_size.x - 40.0, 0)
			box.add_child(big)
		var text := Label.new()
		text.text = String(data.get("text", ""))
		text.add_theme_font_override("font", UIKit.font_comic())
		text.add_theme_font_size_override("font_size", int(data.get("size", 21)))
		text.add_theme_color_override("font_color", ink)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(panel_size.x - 40.0, 0)
		text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(text)
		panel.modulate.a = 0.0
		var tween := panel.create_tween()
		tween.tween_interval(0.15 + 0.35 * float(i))
		tween.tween_property(panel, "modulate:a", 1.0, 0.18)
	return grid
