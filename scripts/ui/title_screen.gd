extends Control

## Title: CONTINUE (when a run is saved), NEW RUN, PRACTICE FIGHT, TUTORIAL, GLOSSARY, QUIT.
##
## CONTINUE is not drawn at all without a save rather than drawn disabled: a button that
## can never be pressed is a label. The first NEW RUN on a profile offers the shakedown (012).

var _problem: Label
var _column: VBoxContainer
## 084 (B8): NEW RUN's seed field -- empty for a fresh seed, or a code typed or pasted.
var _seed_field: LineEdit
## The seed NEW RUN will play (-1: a fresh one), read from the field when NEW RUN is pressed.
var _seed: int = -1


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
	column.position = Vector2(120, 210)
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
	column.add_child(_seed_row())
	# 043 (play-test 13: no click-through after NEW RUN): the next run's crew and tier are said
	# here, and changed here, before NEW RUN -- which then starts at once.
	column.add_child(_next_run_line())
	# 085: the yard board -- today's daily and this week's contract -- beside PRACTICE FIGHT.
	var more := HBoxContainer.new()
	more.add_theme_constant_override("separation", UIKit.SPACE_MD)
	column.add_child(more)
	var practice := _menu_button("PRACTICE FIGHT", false, func() -> void:
		get_tree().change_scene_to_file("res://scenes/combat.tscn"))
	practice.custom_minimum_size = Vector2(300, 64)
	more.add_child(practice)
	var yard := _menu_button("DAILY  ·  WEEKLY", false, func() -> void:
		(load("res://scripts/ui/yard_board.gd") as GDScript).call("open", self))
	yard.name = "yard_button"
	yard.custom_minimum_size = Vector2(300, 64)
	more.add_child(yard)
	var today: Dictionary = Profile.daily(Run.today())
	var streak: int = Profile.daily_streak(Run.today())
	var status := Label.new()
	status.name = "yard_status"
	status.text = ("TODAY'S YARD IS OPEN" if today.is_empty() else "TODAY'S YARD PLAYED") + \
		("  ·  STREAK %d" % streak if streak > 0 else "")
	status.add_theme_font_override("font", UIKit.font_comic())
	status.add_theme_font_size_override("font_size", 18)
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UIKit.on_page(status, 5)
	more.add_child(status)

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
		UnlocksPanel.open(self, Run.db, Profile.unlocked(), Profile.stats(), Profile.unseen_unlocks(), Profile.run_history(),
			func(entry: Dictionary) -> String:
				if not Run.play_entry(entry):
					return Run.problem
				get_tree().change_scene_to_file("res://scenes/run_map.tscn")
				return "", Profile.crew_marks())
		Profile.mark_unlocks_seen())
	goals.custom_minimum_size = Vector2(250 if not unseen.is_empty() else 164, 52)
	extras.add_child(goals)
	var words := _menu_button("GLOSSARY", false, func() -> void: Glossary.open(self, Run.db.glossary))
	words.custom_minimum_size = Vector2(164, 52)
	extras.add_child(words)

	# 082 (A24): SOUND became the settings sheet -- playback speed, volume (OFF included), abandon run.
	var settings := _menu_button("SETTINGS", false, _open_settings)
	settings.name = "settings"
	settings.custom_minimum_size = Vector2(164, 52)
	extras.add_child(settings)
	if OS.get_cmdline_user_args().has("--settings"):
		_open_settings.call_deferred()

	var quit := _menu_button("QUIT", false, func() -> void: get_tree().quit())
	quit.custom_minimum_size = Vector2(130, 52)
	extras.add_child(quit)


## The first NEW RUN on a profile offers the shakedown first (play-test 1: "a tutorial at
## the start would solve most of it"). Skipping counts: it is offered once, then lives on
## the title as TUTORIAL.
func _new_run() -> void:
	_seed = -1
	if _seed_field != null and not _seed_field.text.strip_edges().is_empty():
		var read: Dictionary = Run.read_code(_seed_field.text)
		if read.has("error"):
			_problem.text = String(read["error"])
			return
		# A seeded run never overwrites a live save (084): it refuses while one is saved.
		if Run.has_saved():
			_problem.text = "A run is in progress. Finish it, or abandon it in SETTINGS, before playing a seed."
			return
		_seed = int(read["seed"])
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


## Starts a run straight away with the crew and tier the title shows (043: the choice is made
## beforehand, with CHANGE, never in the way of NEW RUN).
func _begin() -> void:
	_go()


## 085 (B4): "NEXT RUN:  RUNG 5 · TRACKERS LOCK ON  ·  THE WALL  [CHANGE]", the rung's rule under it,
## and the ladder as pips. Always shown: rung 0 is a rung too. CHANGE only while there is a choice.
func _next_run_line() -> Control:
	var meta: Dictionary = Run.db.meta
	var held: Array = Profile.unlocked()
	var choice: Dictionary = Profile.run_choice()
	var crew_id: String = String(choice["crew"])
	var crew: Dictionary = (meta["crews"] as Dictionary).get(crew_id, (meta["crews"] as Dictionary)["salvagers"])
	var rungs: Array = meta.get("tiers", [])
	var rung: int = clampi(int(choice["tier"]), 0, maxi(0, rungs.size() - 1))
	var entry: Dictionary = rungs[rung] if not rungs.is_empty() else {}
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.SPACE_MD)
	var text := Label.new()
	text.name = "next_run"
	text.text = "NEXT RUN:  RUNG %d  ·  %s  ·  %s" % [rung, String(entry.get("name", "")), String(crew["name"])]
	text.add_theme_font_override("font", UIKit.font_comic())
	text.add_theme_font_size_override("font_size", 24)
	UIKit.on_page(text, 6)
	row.add_child(text)
	var stamp: Control = _record_stamp(crew_id)
	if stamp != null:
		row.add_child(stamp)
	if not Meta.opened(held, meta, "crew").is_empty() or not Meta.opened(held, meta, "tier").is_empty():
		var change := _menu_button("CHANGE", false, _choose_run)
		change.custom_minimum_size = Vector2(130, 44)
		change.add_theme_font_size_override("font_size", 20)
		row.add_child(change)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.SPACE_XS)
	box.add_child(row)
	var rule := Label.new()
	rule.name = "next_rule"
	rule.text = String(entry.get("text", ""))
	rule.add_theme_font_override("font", UIKit.font_strong())
	rule.add_theme_font_size_override("font_size", UIKit.SIZE_BODY)
	UIKit.on_page(rule, 5)
	UIKit.fit(rule, 900, 2, 12)
	box.add_child(rule)
	box.add_child(_ladder_line(meta, held))
	# 082 (A13): the first time the ladder shows, a hint says what it is.
	if rungs.size() > 1 and not Meta.opened(held, meta, "tier").is_empty():
		Hints.show_once(self, "ladder", Run.db, Vector2(1180, 330), 440.0)
	return box


## The ladder as one pip per rung (won, open, shut) and a count -- ten rungs do not fit as words.
func _ladder_line(meta: Dictionary, held: Array) -> Control:
	var stats: Dictionary = Profile.stats()
	var top: int = Meta.top_tier(held, meta)
	var rungs: Array = meta.get("tiers", [])
	var row := HBoxContainer.new()
	row.name = "ladder"
	row.add_theme_constant_override("separation", UIKit.SPACE_SM)
	var caption := Label.new()
	caption.text = "THE LADDER"
	caption.add_theme_font_override("font", UIKit.font_comic())
	caption.add_theme_font_size_override("font_size", 20)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UIKit.on_page(caption, 5)
	row.add_child(caption)
	var won_top: int = -1
	for t: int in rungs.size():
		var won: bool = int(stats.get("wins_t%d" % t, 0)) > 0 or (t == 0 and int(stats.get("wins", 0)) > 0)
		if won:
			won_top = t
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(26, 18)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.mouse_filter = Control.MOUSE_FILTER_PASS
		pip.tooltip_text = "RUNG %d  ·  %s%s" % [t, String((rungs[t] as Dictionary).get("name", "")), "  (won)" if won else ("" if t <= top else "  (shut)")]
		var box := UIKit.plain(Ink.GAIN if won else (UIKit.AMBER if t <= top else UIKit.SURFACE_SUNK), 0)
		box.border_color = UIKit.HAIRLINE
		box.set_border_width_all(2)
		box.skew = Vector2(0.3, 0.0)
		pip.add_theme_stylebox_override("panel", box)
		row.add_child(pip)
	var count := Label.new()
	count.text = "%d OF %d OPEN  ·  %s" % [top + 1, rungs.size(), "THE LINE IS CUT" if Meta.finished(held, meta)
		else ("best won: RUNG %d" % won_top if won_top >= 0 else "win a run to open the next rung")]
	count.add_theme_font_override("font", UIKit.font_strong())
	count.add_theme_font_size_override("font_size", UIKit.SIZE_BODY)
	count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UIKit.on_page(count, 5)
	row.add_child(count)
	return row


## 085: a crew's record stamp (the highest rung it has won) and its medals, as a small ink badge;
## null while it has neither.
func _record_stamp(crew_id: String) -> Control:
	var record: int = Profile.crew_record(crew_id)
	var medals: int = Profile.medals(crew_id).size()
	var total: int = UnlocksPanel.crew_medals(Run.db.meta, crew_id).size()
	if record < 0 and medals == 0:
		return null
	var badge := PanelContainer.new()
	badge.name = "record_stamp"
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: InkBox = UIKit.ink_button(Ink.DANGER)
	style.jag = 3.0
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	badge.add_theme_stylebox_override("panel", style)
	var bits: PackedStringArray = []
	if record >= 0:
		bits.append("RECORD: RUNG %d" % record)
	if total > 0:
		bits.append("MEDALS %d/%d" % [medals, total])
	var mark := Label.new()
	mark.text = "  ·  ".join(bits)
	mark.add_theme_font_override("font", UIKit.font_comic())
	mark.add_theme_font_size_override("font_size", 16)
	mark.add_theme_color_override("font_color", UIKit.PAPER)
	badge.add_child(mark)
	return badge


func _go() -> void:
	if _seed >= 0:
		if not Run.new_seeded_run(_seed, Run.profile_options()):
			_problem.text = Run.problem
			return
	else:
		Run.new_run_from_profile()
	get_tree().change_scene_to_file("res://scenes/run_map.tscn")


## "SEED [ code ]" under NEW RUN (084, B8): NEW RUN plays the code typed here, if any.
func _seed_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.SPACE_MD)
	var caption := Label.new()
	caption.text = "SEED"
	caption.add_theme_font_override("font", UIKit.font_comic())
	caption.add_theme_font_size_override("font_size", 24)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UIKit.on_page(caption, 6)
	row.add_child(caption)
	_seed_field = LineEdit.new()
	_seed_field.name = "seed_field"
	_seed_field.placeholder_text = "empty for a new seed, or paste a code"
	_seed_field.custom_minimum_size = Vector2(420, 48)
	_seed_field.add_theme_font_override("font", UIKit.font_strong())
	_seed_field.add_theme_font_size_override("font_size", UIKit.SIZE_BODY)
	for key: String in ["normal", "focus", "read_only"]:
		_seed_field.add_theme_stylebox_override(key, UIKit.ink_card(UIKit.PAPER, UIKit.SPACE_SM, 2, 3))
	_seed_field.add_theme_color_override("font_color", UIKit.INK)
	_seed_field.add_theme_color_override("font_placeholder_color", UIKit.INK_DIM)
	_seed_field.add_theme_color_override("caret_color", UIKit.INK)
	_seed_field.text_changed.connect(func(_text: String) -> void: _problem.text = "")
	_seed_field.text_submitted.connect(func(_text: String) -> void: _new_run())
	row.add_child(_seed_field)
	return row


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
		var crew_button: Button = _choice_button("%s  ·  %s" % [crew["name"], crew["text"]], String(id) == String(choice["crew"]),
			func() -> void:
				Profile.choose_run(String(id), int(Profile.run_choice()["tier"]))
				_choose_run())
		crew_button.name = "crew_" + String(id)
		_column.add_child(crew_button)
		# 085: the crew card carries its record stamp and medals, at its right edge.
		var stamp: Control = _record_stamp(String(id))
		if stamp != null:
			crew_button.custom_minimum_size.x = 1100
			var holder := HBoxContainer.new()
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.alignment = BoxContainer.ALIGNMENT_END
			crew_button.add_child(holder)
			holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
			holder.add_child(stamp)
	# 085 (B4): ten rungs as a row of small buttons; the chosen one's rule is written under them.
	var tiers: Array = [0] + Meta.opened(held, meta, "tier").map(func(t: Variant) -> int: return int(t))
	if tiers.size() > 1:
		_column.add_child(_choice_caption("RUNG"))
		var grid := GridContainer.new()
		grid.columns = 6
		grid.add_theme_constant_override("h_separation", UIKit.SPACE_SM)
		grid.add_theme_constant_override("v_separation", UIKit.SPACE_SM)
		_column.add_child(grid)
		for t: Variant in tiers:
			var pick: Button = _choice_button("RUNG %d" % int(t), int(t) == int(choice["tier"]),
				func() -> void:
					Profile.choose_run(String(Profile.run_choice()["crew"]), int(t))
					_choose_run())
			pick.name = "rung_%d" % int(t)
			pick.custom_minimum_size = Vector2(160, 52)
			pick.alignment = HORIZONTAL_ALIGNMENT_CENTER
			grid.add_child(pick)
		var chosen: Dictionary = (meta["tiers"] as Array)[clampi(int(choice["tier"]), 0, (meta["tiers"] as Array).size() - 1)]
		var rule := Label.new()
		rule.text = "RUNG %d  ·  %s  ·  %s" % [int(choice["tier"]), chosen["name"], chosen.get("text", "")]
		rule.add_theme_font_override("font", UIKit.font_strong())
		rule.add_theme_font_size_override("font_size", UIKit.SIZE_HEADING)
		UIKit.on_page(rule, 5)
		UIKit.fit(rule, 1100, 2, 12)
		_column.add_child(rule)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 12)
	_column.add_child(gap)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", UIKit.SPACE_MD)
	buttons.add_child(_menu_button("START", true, _go))
	buttons.add_child(_menu_button("BACK", false, func() -> void: get_tree().reload_current_scene()))
	_column.add_child(buttons)


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


func _open_settings() -> void:
	(load("res://scripts/ui/settings_sheet.gd") as GDScript).call("open", self)


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
