extends Control

## Title: CONTINUE (when a run is saved), NEW RUN, PRACTICE FIGHT, QUIT.
##
## CONTINUE is not drawn at all without a save rather than drawn disabled: a button that
## can never be pressed is a label.

var _problem: Label


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

	# CONTINUE is the primary action when there is a run to go back to; otherwise NEW RUN.
	var saved: bool = Run.has_saved()
	if saved:
		column.add_child(_menu_button("CONTINUE", true, _continue_run))
	column.add_child(_menu_button("NEW RUN", not saved, func() -> void:
		Run.new_run()
		get_tree().change_scene_to_file("res://scenes/run_map.tscn")))
	column.add_child(_menu_button("PRACTICE FIGHT", false, func() -> void:
		get_tree().change_scene_to_file("res://scenes/combat.tscn")))

	_problem = Label.new()
	_problem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_problem.add_theme_font_size_override("font_size", UIKit.SIZE_BODY)
	_problem.add_theme_color_override("font_color", UIKit.RED)
	column.add_child(_problem)

	var quit := Button.new()
	quit.text = "QUIT"
	quit.custom_minimum_size = Vector2(220, 56)
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit.add_theme_stylebox_override("normal", UIKit.secondary())
	quit.pressed.connect(func() -> void: get_tree().quit())
	column.add_child(quit)


func _continue_run() -> void:
	if Run.continue_run():
		get_tree().change_scene_to_file("res://scenes/run_map.tscn")
	else:
		_problem.text = Run.problem


func _menu_button(text: String, primary: bool, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 64)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", UIKit.font_strong())
	button.add_theme_font_size_override("font_size", UIKit.SIZE_TITLE if primary else UIKit.SIZE_HEADING)
	var ink: Color = UIKit.BG if primary else UIKit.TEXT
	for state: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, UIKit.primary() if primary else UIKit.secondary())
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, ink)
	button.pressed.connect(on_press)
	return button
