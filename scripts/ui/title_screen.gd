extends Control

## Title: CONTINUE (when a run is saved), NEW RUN, PRACTICE FIGHT, TUTORIAL, GLOSSARY, QUIT.
##
## CONTINUE is not drawn at all without a save rather than drawn disabled: a button that
## can never be pressed is a label. The first NEW RUN on a profile offers the shakedown (012).

var _problem: Label
var _column: VBoxContainer


func _ready() -> void:
	UIKit.apply(self)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# 010: a scene, not a gradient -- the crew in the yard at night, the Reclaimer's
	# beacons on the horizon. The menu sits over its dark left side.
	var stage := TitleStage.new()
	add_child(stage)
	stage.build(Run.db, Run.db.run_rules.get("starting_crew", []))
	# 036: the yard printed on paper, under the menu (layer -1: the menu's controls are layer 0).
	Ink.print_pass(self, -1)
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
	_column = column
	column.position = Vector2(120, 250)
	column.custom_minimum_size = Vector2(620, 0)
	column.add_theme_constant_override("separation", UIKit.SPACE_LG)
	add_child(column)

	# Ink & Rust (016): the wordmark is comic lettering, paper on a heavy ink edge.
	var wordmark := Label.new()
	wordmark.text = "SCRAPLINE"
	wordmark.add_theme_font_override("font", UIKit.font_letters())
	wordmark.add_theme_font_size_override("font_size", 150)
	UIKit.on_page(wordmark, 30)
	column.add_child(wordmark)

	var tagline := Label.new()
	tagline.text = "Three free machines. Three yards. Carry the key to the Crucible before the Reclaimer catches you."
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tagline.custom_minimum_size = Vector2(600, 0)
	tagline.add_theme_font_size_override("font_size", UIKit.SIZE_HEADING)
	tagline.add_theme_font_override("font", UIKit.font_strong())
	UIKit.on_page(tagline, 6)
	column.add_child(tagline)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24)
	column.add_child(gap)

	# CONTINUE is the primary action when there is a run to go back to; otherwise NEW RUN.
	var saved: bool = Run.has_saved()
	if saved:
		column.add_child(_menu_button("CONTINUE", true, _continue_run))
	column.add_child(_menu_button("NEW RUN", not saved, _new_run))
	column.add_child(_menu_button("PRACTICE FIGHT", false, func() -> void:
		get_tree().change_scene_to_file("res://scenes/combat.tscn")))

	# 022: what the runs so far have opened; 027: always shown, with the next goal and how far.
	var total: int = (Run.db.meta.get("unlocks", []) as Array).size()
	if total > 0:
		var next: Dictionary = Meta.next_unlock(Profile.unlocked(), Run.db.meta)
		var line: String = "UNLOCKED %d / %d" % [Profile.unlocked().size(), total]
		if not next.is_empty():
			var p: Array = Meta.progress(Profile.stats(), next)
			line += "  ·  next: %s (%d / %d)" % [String(next.get("text", "")).to_lower(), int(p[0]), int(p[1])]
		var progress := Label.new()
		progress.text = line
		progress.add_theme_font_override("font", UIKit.font_strong())
		progress.add_theme_font_size_override("font_size", UIKit.SIZE_BODY)
		UIKit.on_page(progress, 5)
		column.add_child(progress)

	_problem = Label.new()
	_problem.add_theme_font_size_override("font_size", UIKit.SIZE_BODY)
	UIKit.on_page(_problem, 6)
	_problem.add_theme_color_override("font_color", Ink.DANGER)
	column.add_child(_problem)

	var extras := HBoxContainer.new()
	extras.add_theme_constant_override("separation", UIKit.SPACE_MD)
	column.add_child(extras)
	var shakedown := _menu_button("TUTORIAL", false, _play_shakedown)
	shakedown.custom_minimum_size = Vector2(164, 52)
	extras.add_child(shakedown)
	# Play-test 11: what is new since the screen was last opened is counted on the button and
	# marked NEW inside; opening it marks it seen.
	var unseen: Array = Profile.unseen_unlocks()
	var goals := _menu_button("UNLOCKS  ·  %d NEW" % unseen.size() if not unseen.is_empty() else "UNLOCKS", false, func() -> void:
		UnlocksPanel.open(self, Run.db, Profile.unlocked(), Profile.stats(), Profile.unseen_unlocks())
		Profile.mark_unlocks_seen())
	goals.custom_minimum_size = Vector2(250 if not unseen.is_empty() else 164, 52)
	extras.add_child(goals)
	var words := _menu_button("GLOSSARY", false, func() -> void: Glossary.open(self, Run.db.glossary))
	words.custom_minimum_size = Vector2(164, 52)
	extras.add_child(words)

	var sound := _menu_button("SOUND: ON" if Profile.sound_on() else "SOUND: OFF", false, func() -> void:
		Profile.set_sound(not Profile.sound_on())
		Audio.play("ui_confirm")
		get_tree().reload_current_scene())
	sound.custom_minimum_size = Vector2(164, 52)
	extras.add_child(sound)

	var quit := _menu_button("QUIT", false, func() -> void: get_tree().quit())
	quit.custom_minimum_size = Vector2(220, 52)
	column.add_child(quit)


## The first NEW RUN on a profile offers the shakedown first (play-test 1: "a tutorial at
## the start would solve most of it"). Skipping counts: it is offered once, then lives on
## the title as TUTORIAL.
func _new_run() -> void:
	if Profile.tutorial_done():
		_begin()
		return
	for child: Node in _column.get_children():
		child.queue_free()
	var head := Label.new()
	head.text = "FIRST TIME IN THE YARD?"
	head.add_theme_font_override("font", UIKit.font_display())
	head.add_theme_font_size_override("font_size", 64)
	UIKit.on_page(head, 12)
	_column.add_child(head)
	var line := Label.new()
	line.text = "The shakedown is one short, guided fight: moving, reading the enemy, attacking, heat, the yard's drums and scrap. About five minutes."
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size = Vector2(600, 0)
	line.add_theme_font_size_override("font_size", UIKit.SIZE_HEADING)
	line.add_theme_font_override("font", UIKit.font_strong())
	UIKit.on_page(line, 6)
	_column.add_child(line)
	_column.add_child(_menu_button("PLAY THE SHAKEDOWN", true, _play_shakedown))
	_column.add_child(_menu_button("SKIP TO THE RUN", false, func() -> void:
		Profile.finish_tutorial()
		_begin()))


## Starts a run -- straight away on a profile with nothing to choose between, through the
## crew and tier choice once something is unlocked (022).
func _begin() -> void:
	var meta: Dictionary = Run.db.meta
	var held: Array = Profile.unlocked()
	if Meta.opened(held, meta, "crew").is_empty() and Meta.opened(held, meta, "tier").is_empty():
		_go()
		return
	_choose_run()


func _go() -> void:
	Run.new_run_from_profile()
	get_tree().change_scene_to_file("res://scenes/run_map.tscn")


func _choose_run() -> void:
	for child: Node in _column.get_children():
		child.queue_free()
	var meta: Dictionary = Run.db.meta
	var held: Array = Profile.unlocked()
	var choice: Dictionary = Profile.run_choice()
	var head := Label.new()
	head.text = "THE NEXT RUN"
	head.add_theme_font_override("font", UIKit.font_display())
	head.add_theme_font_size_override("font_size", 64)
	UIKit.on_page(head, 12)
	_column.add_child(head)
	var crews: Array = ["salvagers"] + Meta.opened(held, meta, "crew")
	_column.add_child(_choice_caption("CREW"))
	for id: Variant in crews:
		var crew: Dictionary = (meta["crews"] as Dictionary)[id]
		_column.add_child(_choice_button("%s  ·  %s" % [crew["name"], crew["text"]], String(id) == String(choice["crew"]),
			func() -> void:
				Profile.choose_run(String(id), int(Profile.run_choice()["tier"]))
				_choose_run()))
	var tiers: Array = [0] + Meta.opened(held, meta, "tier").map(func(t: Variant) -> int: return int(t))
	if tiers.size() > 1:
		_column.add_child(_choice_caption("TIER"))
		for t: Variant in tiers:
			var tier: Dictionary = (meta["tiers"] as Array)[int(t)]
			_column.add_child(_choice_button("%s  ·  %s" % [tier["name"], tier["text"]], int(t) == int(choice["tier"]),
				func() -> void:
					Profile.choose_run(String(Profile.run_choice()["crew"]), int(t))
					_choose_run()))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	_column.add_child(gap)
	_column.add_child(_menu_button("START", true, _go))


func _choice_caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UIKit.font_comic())
	label.add_theme_font_size_override("font_size", 26)
	UIKit.on_page(label, 6)
	return label


## One option of several equals: an ordinary button, the chosen one ringed in amber.
func _choice_button(text: String, chosen: bool, on_press: Callable) -> Button:
	var button: Button = _menu_button(text, false, on_press)
	button.custom_minimum_size = Vector2(820, 56)
	button.add_theme_font_override("font", UIKit.font_strong())
	button.add_theme_font_size_override("font_size", UIKit.SIZE_HEADING)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if chosen:
		var ring: InkBox = UIKit.choice()
		for state: String in ["normal", "hover", "focus", "pressed"]:
			button.add_theme_stylebox_override(state, ring)
	return button


func _play_shakedown() -> void:
	get_tree().change_scene_to_file("res://scenes/shakedown.tscn")


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
	button.add_theme_font_override("font", UIKit.font_comic())
	button.add_theme_font_size_override("font_size", 30 if primary else 24)
	var ink: Color = UIKit.TEXT
	var up: InkBox = UIKit.primary() if primary else UIKit.secondary()
	for state: String in ["normal", "hover", "focus"]:
		button.add_theme_stylebox_override(state, up)
	button.add_theme_stylebox_override("pressed", UIKit.pressed(up))
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, ink)
	button.pressed.connect(on_press)
	return button
