extends Control

## Title: CONTINUE (when a run is saved), NEW RUN, PRACTICE FIGHT, QUIT.
##
## CONTINUE is not drawn at all without a save rather than drawn disabled: a button that
## can never be pressed is a label.

var _problem: Label


func _ready() -> void:
	UIKit.apply(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# 010: a scene, not a gradient -- the crew in the yard at night, the Reclaimer's
	# beacons on the horizon. The menu sits over its dark left side.
	var stage := TitleStage.new()
	add_child(stage)
	stage.build(Run.db, Run.db.run_rules.get("starting_crew", []))
	var shade := TextureRect.new()
	var fade := GradientTexture2D.new()
	fade.fill_from = Vector2(0, 0)
	fade.fill_to = Vector2(1, 0)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.42, 0.7])
	ramp.colors = PackedColorArray([Color(0.03, 0.03, 0.04, 0.92), Color(0.03, 0.03, 0.04, 0.55), Color(0.03, 0.03, 0.04, 0.0)])
	fade.gradient = ramp
	shade.texture = fade
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var column := VBoxContainer.new()
	column.position = Vector2(120, 250)
	column.custom_minimum_size = Vector2(620, 0)
	column.add_theme_constant_override("separation", UIKit.SPACE_LG)
	add_child(column)

	var wordmark := Label.new()
	wordmark.text = "SCRAPLINE"
	wordmark.add_theme_font_override("font", UIKit.font_display())
	wordmark.add_theme_font_size_override("font_size", 132)
	wordmark.add_theme_color_override("font_color", UIKit.TEXT)
	column.add_child(wordmark)

	var tagline := Label.new()
	tagline.text = "Three free machines. Three yards. Carry the key to the Crucible before the Reclaimer catches you."
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tagline.custom_minimum_size = Vector2(600, 0)
	tagline.add_theme_font_size_override("font_size", UIKit.SIZE_HEADING)
	tagline.add_theme_color_override("font_color", UIKit.TEXT_DIM)
	column.add_child(tagline)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24)
	column.add_child(gap)

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
	_problem.add_theme_font_size_override("font_size", UIKit.SIZE_BODY)
	_problem.add_theme_color_override("font_color", UIKit.RED)
	column.add_child(_problem)

	var quit := _menu_button("QUIT", false, func() -> void: get_tree().quit())
	quit.custom_minimum_size = Vector2(220, 52)
	column.add_child(quit)


func _continue_run() -> void:
	if Run.continue_run():
		get_tree().change_scene_to_file("res://scenes/run_map.tscn")
	else:
		_problem.text = Run.problem


func _menu_button(text: String, primary: bool, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(340, 64)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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
