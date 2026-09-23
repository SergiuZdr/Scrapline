extends Control

## Placeholder title screen for the roguelike rebuild.
##
## FIGHT opens the Iteration 002 prototype fight. New Run and Continue arrive with the run
## loop (Iteration 004). Until then they are not drawn at all rather than drawn disabled:
## a button that can never be pressed is a label.


func _ready() -> void:
	UIKit.apply(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UIKit.backdrop())

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", UIKit.SPACE_LG)
	add_child(column)

	var wordmark := Label.new()
	wordmark.text = "SCRAPLINE"
	wordmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wordmark.add_theme_font_override("font", UIKit.font_display())
	wordmark.add_theme_font_size_override("font_size", UIKit.SIZE_DISPLAY * 2)
	wordmark.add_theme_color_override("font_color", UIKit.TEXT)
	column.add_child(wordmark)

	var tagline := Label.new()
	tagline.text = "Three machines. One scrapyard. Rebuild from what you tear off the enemy."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", UIKit.SIZE_HEADING)
	tagline.add_theme_color_override("font_color", UIKit.TEXT_DIM)
	column.add_child(tagline)

	var status := Label.new()
	status.text = "PROTOTYPE  ·  one fight, no run yet"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", UIKit.SIZE_LABEL)
	status.add_theme_color_override("font_color", UIKit.AMBER)
	column.add_child(status)

	var fight := Button.new()
	fight.text = "FIGHT"
	fight.custom_minimum_size = Vector2(280, 68)
	fight.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	fight.add_theme_font_override("font", UIKit.font_strong())
	fight.add_theme_font_size_override("font_size", UIKit.SIZE_TITLE)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		fight.add_theme_stylebox_override(state, UIKit.primary())
		fight.add_theme_color_override("font_color" if state == "normal" else "font_%s_color" % state, UIKit.BG)
	fight.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/combat.tscn"))
	column.add_child(fight)

	var quit := Button.new()
	quit.text = "QUIT"
	quit.custom_minimum_size = Vector2(220, 56)
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit.add_theme_stylebox_override("normal", UIKit.secondary())
	quit.pressed.connect(func() -> void: get_tree().quit())
	column.add_child(quit)
