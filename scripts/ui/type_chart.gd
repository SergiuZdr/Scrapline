class_name TypeChart
extends RefCounted

## The damage-type wheel as a chart (play-test 11: "there is still no clear, visual explanation of
## how damage types work against armour"): damage types down the side, armour types across the
## top, each cell x1.3 (green, STRONG), x0.7 (red, WEAK) or an even dash. Read from the same
## files the fight reads (`balance.json` effectiveness, `rules.json` type names), so the chart
## cannot disagree with a hit. A display class: it takes nothing from the `Run` autoload.

const CELL := Vector2(150, 44)


static func build() -> Control:
	var rules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat/rules.json"))
	var balance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	var types: Array = rules.get("damage_types", [])
	var armours: Array = rules.get("armor_types", [])
	var wheel: Array = balance.get("effectiveness", [])
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.SPACE_SM)
	var grid := GridContainer.new()
	grid.columns = armours.size() + 1
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	grid.add_child(_cell("DAMAGE \\ ARMOUR", UIKit.PAGE_TEXT, Color(0, 0, 0, 0), 15))
	for a: Variant in armours:
		grid.add_child(_cell(String(a).to_upper(), UIKit.INK, UIKit.PAPER_DIM, 18))
	for t: int in types.size():
		grid.add_child(_cell(String(types[t]).to_upper(), UIKit.INK, UIKit.PAPER_DIM, 18))
		for a: int in armours.size():
			var pct: int = int((wheel[t] as Array)[a]) if t < wheel.size() else 100
			if pct > 100:
				grid.add_child(_cell("x%.1f  STRONG" % (float(pct) / 100.0), UIKit.PAPER, Ink.GAIN.darkened(0.25), 17))
			elif pct < 100:
				grid.add_child(_cell("x%.1f  WEAK" % (float(pct) / 100.0), UIKit.PAPER, Ink.DANGER, 17))
			else:
				grid.add_child(_cell("—", UIKit.INK_DIM, UIKit.PAPER, 17))
	var note := Label.new()
	note.text = "A machine's core sets its damage type; the Flamer and Sunspear always burn (THERMAL), the Pulse Emitter and Coilgun are always EMP. Its frame sets its armour. Aim at something and the preview says STRONG or WEAK."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(CELL.x * float(armours.size() + 1), 0)
	note.add_theme_font_override("font", UIKit.font_strong())
	note.add_theme_font_size_override("font_size", UIKit.SIZE_BODY)
	note.add_theme_color_override("font_color", UIKit.PAGE_TEXT)
	box.add_child(note)
	return box


static func _cell(text: String, ink: Color, fill: Color, size: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = CELL
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	if fill.a > 0.0:
		style.border_color = UIKit.INK
		style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UIKit.font_comic())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", ink)
	panel.add_child(label)
	return panel
