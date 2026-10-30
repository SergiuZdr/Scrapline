extends Control

## The yard board (085): today's daily yard and this week's contract, side by side. Opened from the
## title with
##     (load("res://scripts/ui/yard_board.gd") as GDScript).call("open", host)
## No class_name on purpose: it reads `Run` and `Profile`, and `--script` tools compile screens
## before the autoloads exist.
##
##   TODAY'S YARD     one run everyone plays today, one attempt (abandoning counts): PLAY once, then
##                    its result; the best daily ever, and the streak of days in a row.
##   THIS WEEK        a harder contract with a fixed crew and rung and its twists listed; any number
##                    of attempts, the best kept, and a PLATE (cosmetic only) for clearing it.
##
## Neither counts on the ladder or toward unlocks; both go to the run history marked DAILY/WEEKLY.
## Starting either is refused over a live run, as a seed is. The day and week come from the local
## clock in UTC (`Run.today`), never from inside the sim.

const GROUP: String = "yard_board"
const COLUMN: float = 700.0

var _problem: Label
var _body: HBoxContainer


static func open(host: Control) -> Control:
	if host == null or not host.is_inside_tree() or host.get_tree().get_first_node_in_group(GROUP) != null:
		return null
	var board: Control = (load("res://scripts/ui/yard_board.gd") as GDScript).new()
	host.add_child(board)
	return board


func _ready() -> void:
	add_to_group(GROUP)
	name = "yard_board"
	UIKit.apply(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(UIKit.BG, 0.86)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.ink_card(UIKit.PAPER_CARD, UIKit.SPACE_XXL, UIKit.SPACE_XL, 8))
	centre.add_child(card)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", UIKit.SPACE_LG)
	card.add_child(page)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIKit.SPACE_LG)
	page.add_child(head)
	head.add_child(UIKit.caption_title("THE YARD BOARD", 44))
	var note := UIKit.fit(_label("Posted for everyone by the date. Neither counts on the ladder or toward unlocks: they are for the score.",
		UIKit.SIZE_BODY, UIKit.INK_DIM, UIKit.font_strong()), 820, 2, 12)
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(note)
	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", UIKit.SPACE_XL)
	page.add_child(_body)
	_body.add_child(_daily())
	_body.add_child(_weekly())
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", UIKit.SPACE_LG)
	page.add_child(foot)
	_problem = _label("", UIKit.SIZE_BODY, UIKit.INK_RED, UIKit.font_strong())
	_problem.name = "yard_problem"
	_problem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_problem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	foot.add_child(_problem)
	var close := _button("CLOSE", UIKit.secondary(), Vector2(200, 60))
	close.pressed.connect(queue_free)
	foot.add_child(close)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()


# --- Today's yard -------------------------------------------------------------------

func _daily() -> Control:
	var day: int = Run.today()
	var yard: Dictionary = Run.daily_options(day)
	var played: Dictionary = Profile.daily(day)
	var box: VBoxContainer = _column("daily", "TODAY'S YARD", Time.get_date_string_from_unix_time(day * 86400))
	box.add_child(_wrap("One region for everyone today, its deals fixed, any crew. ONE attempt: abandoning it counts.", UIKit.SIZE_BODY, UIKit.INK))
	if yard.is_empty():
		box.add_child(_wrap("No yard is posted today.", UIKit.SIZE_HEADING, UIKit.INK_DIM))
	else:
		var crew: String = String(yard.get("crew_id", Profile.run_choice()["crew"]))
		box.add_child(_fact("CREW", "%s%s" % [_crew_name(crew), "" if yard.has("crew_id") else "  (yours: change it at NEW RUN)"]))
		if int(yard.get("rung", 0)) > 0:
			box.add_child(_fact("RUNG", _rung_text(int(yard["rung"]))))
		for line: String in _twists(yard):
			box.add_child(_bullet(line))
	box.add_child(_gap())
	if played.is_empty():
		if not yard.is_empty():
			var play := _button("PLAY TODAY'S YARD", UIKit.choice(), Vector2(420, 64))
			play.name = "play_daily"
			play.pressed.connect(func() -> void: _start(Run.new_daily()))
			box.add_child(play)
	elif String(played.get("ended", "")).is_empty():
		var out := _wrap("TODAY'S ATTEMPT IS OUT: CONTINUE it from the title.", UIKit.SIZE_HEADING, UIKit.INK)
		out.name = "daily_result"
		box.add_child(out)
	else:
		var done := _wrap("PLAYED TODAY:  %s" % _result_text(played), UIKit.SIZE_HEADING, UIKit.INK)
		done.name = "daily_result"
		box.add_child(done)
		box.add_child(_wrap("The next yard opens in %s." % _until_tomorrow(), UIKit.SIZE_BODY, UIKit.INK_DIM))
	var best: Dictionary = Profile.daily_best()
	box.add_child(_fact("BEST", ("%s  (%s)" % [_result_text(best), Time.get_date_string_from_unix_time(int(best.get("day", 0)) * 86400)])
		if not best.is_empty() else "none yet"))
	var streak: int = Profile.daily_streak(day)
	var streak_line := _fact("STREAK", "%d DAY%s IN A ROW" % [streak, "" if streak == 1 else "S"] if streak > 0 else "none: play today's to start one")
	streak_line.name = "daily_streak"
	box.add_child(streak_line)
	return _framed(box)


# --- This week's contract -------------------------------------------------------------

func _weekly() -> Control:
	var week: int = Run.this_week()
	var yard: Dictionary = Run.weekly_options(week)
	var record: Dictionary = Profile.weekly(week)
	var monday: String = Time.get_date_string_from_unix_time((week * 7 + 4) * 86400)
	var box: VBoxContainer = _column("weekly", "THIS WEEK'S CONTRACT", "week of " + monday)
	box.add_child(_wrap("Harder: a fixed crew, a fixed rung and its twists. Any number of attempts; the best is kept. Clear it for the week's TROPHY and its LIVERY.",
		UIKit.SIZE_BODY, UIKit.INK))
	if yard.is_empty():
		box.add_child(_wrap("No contract is posted this week.", UIKit.SIZE_HEADING, UIKit.INK_DIM))
	else:
		box.add_child(_fact("CREW", _crew_name(String(yard.get("crew_id", "salvagers")))))
		box.add_child(_fact("RUNG", _rung_text(int(yard.get("rung", 0)))))
		var twists: PackedStringArray = _twists(yard)
		if not twists.is_empty():
			box.add_child(_label("TWISTS", 22, UIKit.INK, UIKit.font_comic()))
		for line: String in twists:
			box.add_child(_bullet(line))
	box.add_child(_gap())
	var attempts: int = int(record["attempts"])
	box.add_child(_fact("ATTEMPTS", str(attempts)))
	var best: Dictionary = record["best"]
	box.add_child(_fact("BEST", _result_text(best) if not best.is_empty() else "none yet"))
	# 085: the week's reward -- a trophy for the garage's wall and a livery any machine can wear.
	var reward: Dictionary = Run.weekly_reward(week)
	var earned: bool = bool(record["cleared"])
	var reward_row := HBoxContainer.new()
	reward_row.name = "weekly_reward"
	reward_row.add_theme_constant_override("separation", UIKit.SPACE_MD)
	box.add_child(reward_row)
	var picture: Texture2D = WeeklyRewards.picture(String(reward.get("trophy", "")))
	if picture != null:
		var art := TextureRect.new()
		art.name = "weekly_trophy"
		art.texture = picture
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2(96, 96)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reward_row.add_child(art)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 2)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reward_row.add_child(words)
	words.add_child(_label("TROPHY  ·  " + String(reward.get("name", "")).to_upper(), 22, UIKit.INK, UIKit.font_comic()))
	var paint := HBoxContainer.new()
	paint.add_theme_constant_override("separation", UIKit.SPACE_SM)
	words.add_child(paint)
	paint.add_child((load("res://scripts/ui/trophy_wall.gd") as GDScript).call("swatch", String(reward.get("livery", "")), Vector2(44, 20)))
	paint.add_child(_label("LIVERY  ·  " + Ink.livery_name(String(reward.get("livery", ""))), 18, UIKit.INK, UIKit.font_comic()))
	words.add_child(_label("EARNED: on the trophy wall, the livery in the garage" if earned else "clear the contract to earn both (paint only, no power)",
		UIKit.SIZE_BODY, UIKit.INK_GREEN if earned else UIKit.INK_DIM, UIKit.font_strong()))
	if not yard.is_empty():
		var play := _button("TAKE THE CONTRACT" if attempts == 0 else "TRY AGAIN", UIKit.choice(), Vector2(420, 64))
		play.name = "play_weekly"
		play.pressed.connect(func() -> void: _start(Run.new_weekly()))
		box.add_child(play)
	return _framed(box)


func _start(started: bool) -> void:
	if not started:
		_problem.text = Run.problem
		Audio.play("ui_deny", -10.0)
		return
	get_tree().change_scene_to_file("res://scenes/run_map.tscn")


# --- Words ---------------------------------------------------------------------------------

## "WRECKED IN ACT 2  ·  1 act cleared  ·  6 fights won  ·  0 HP left".
static func _result_text(result: Dictionary) -> String:
	var ended: String = String(result.get("ended", ""))
	var how: String = {"won": "WON", "wrecked": "WRECKED", "gate": "THE GATE HELD", "abandoned": "ABANDONED"}.get(ended, ended.to_upper())
	var acts: int = int(result.get("acts", 0))
	return "%s  ·  %d act%s cleared  ·  %d fights won  ·  %d HP left" % [how, acts, "" if acts == 1 else "s",
		int(result.get("fights", 0)), int(result.get("hp", 0))]


func _until_tomorrow() -> String:
	var left: int = 86400 - int(Time.get_unix_time_from_system()) % 86400
	return "%dh %02dm" % [left / 3600, (left % 3600) / 60]


func _crew_name(id: String) -> String:
	return String(((Run.db.meta.get("crews", {}) as Dictionary).get(id, {}) as Dictionary).get("name", id.to_upper()))


## "RUNG 4 · NO FREE REPAIRS": the rung's number and its rule (the ladder's own words).
func _rung_text(rung: int) -> String:
	var rungs: Array = Run.db.meta.get("tiers", [])
	if rungs.is_empty():
		return "RUNG %d" % rung
	var entry: Dictionary = rungs[clampi(rung, 0, rungs.size() - 1)]
	return "RUNG %d  ·  %s" % [rung, String(entry.get("name", ""))]


## What the yard changes, one line each: its twists, and the condition fixed for each act.
func _twists(yard: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for twist: Variant in (yard.get("twists", []) as Array):
		out.append(String((twist as Dictionary).get("text", (twist as Dictionary).get("id", ""))) if twist is Dictionary else String(twist))
	var modifiers: Dictionary = Run.db.combat_rules.get("modifiers", {})
	for key: String in ["act_conditions", "modifiers_acts", "conditions"]:
		var list: Variant = yard.get(key)
		if list is Array:
			for a: int in (list as Array).size():
				var id: String = String((list as Array)[a])
				if not id.is_empty():
					out.append("ACT %d: %s" % [a + 1, String((modifiers.get(id, {}) as Dictionary).get("name", id)).to_upper()])
			break
	return out


# --- Building blocks -------------------------------------------------------------------

func _column(id: String, title: String, sub: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = id
	box.custom_minimum_size = Vector2(COLUMN, 560)
	box.add_theme_constant_override("separation", UIKit.SPACE_SM)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIKit.SPACE_MD)
	box.add_child(head)
	head.add_child(_label(title, 34, UIKit.INK, UIKit.font_display()))
	var when := _label(sub.to_upper(), 20, UIKit.INK_DIM, UIKit.font_comic())
	when.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(when)
	return box


func _framed(box: Control) -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UIKit.ink_card(UIKit.PAPER, UIKit.SPACE_LG, UIKit.SPACE_LG, 4))
	frame.add_child(box)
	return frame


func _fact(caption: String, text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.SPACE_MD)
	var head := _label(caption, 22, UIKit.INK, UIKit.font_comic())
	head.custom_minimum_size = Vector2(130, 0)
	row.add_child(head)
	row.add_child(UIKit.fit(_label(text, UIKit.SIZE_HEADING, UIKit.INK, UIKit.font_strong()), COLUMN - 150.0, 2, 12))
	return row


func _bullet(text: String) -> Control:
	return UIKit.fit(_label("·  " + text, UIKit.SIZE_HEADING, UIKit.INK_RED, UIKit.font_strong()), COLUMN, 2, 12)


func _gap() -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return gap


func _wrap(text: String, size: int, colour: Color) -> Label:
	var label := _label(text, size, colour, UIKit.font_strong())
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(COLUMN, 0)
	return label


func _label(text: String, size: int, colour: Color, face: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", face)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, style: InkBox, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", UIKit.font_comic())
	button.add_theme_font_size_override("font_size", 24)
	for state: String in ["normal", "hover", "focus"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("pressed", UIKit.pressed(style))
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, UIKit.INK)
	return button
