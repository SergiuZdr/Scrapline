extends Control

## The settings sheet (082, A24 minimal): playback speed, volume, and ABANDON RUN. Opened from the
## title, the map and the fight with
##     (load("res://scripts/ui/settings_sheet.gd") as GDScript).call("open", host)
## No class_name on purpose: `--script` tools compile screens before the autoloads exist, and this
## sheet calls `Profile` and `Run`.
##
## Every change goes through a `Profile` command (they save at once). Abandoning asks again in the
## sheet itself, never through an OS dialog. Escape or CLOSE puts the sheet away; while it is open
## it takes every key, so SPACE cannot end a turn behind it.

const GROUP: String = "settings_sheet"
const SPEEDS: Array[int] = [1, 2, 3]
const VOLUMES: Array[int] = [0, 25, 50, 75, 100]

var _body: VBoxContainer
var _confirming: bool = false


## Opens the sheet over `host`'s screen. A second open while one is up does nothing.
static func open(host: Control) -> void:
	if host == null or not host.is_inside_tree():
		return
	if host.get_tree().get_first_node_in_group(GROUP) != null:
		return
	# A menu opening stops any fast playback behind it (the fight also checks the group).
	Engine.time_scale = 1.0
	var layer := CanvasLayer.new()
	layer.name = "settings_sheet"
	layer.layer = 60
	var sheet: Control = (load("res://scripts/ui/settings_sheet.gd") as GDScript).new()
	layer.add_child(sheet)
	sheet.tree_exited.connect(layer.queue_free)
	host.get_tree().root.add_child(layer)
	Audio.play("ui_confirm", -10.0)


func _ready() -> void:
	add_to_group(GROUP)
	UIKit.apply(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(UIKit.BG, 0.84)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	card.name = "card"
	card.add_theme_stylebox_override("panel", UIKit.ink_card(UIKit.PAPER_CARD, UIKit.SPACE_XXL, UIKit.SPACE_XL, 7))
	centre.add_child(card)
	_body = VBoxContainer.new()
	_body.custom_minimum_size = Vector2(720, 0)
	_body.add_theme_constant_override("separation", UIKit.SPACE_MD)
	card.add_child(_body)
	_rebuild()


## The sheet takes every key while it is up; Escape closes it.
func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	var key := event as InputEventKey
	if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		close()


func close() -> void:
	queue_free()


func _rebuild() -> void:
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_body.add_child(UIKit.caption_title("SETTINGS", 44))

	_body.add_child(_heading("PLAYBACK SPEED"))
	_body.add_child(_line("How fast the enemy's turn plays. Your own moves run at most 2x. Hold SPACE (or hold a press on the board) to hurry any playback to 3x."))
	var speeds := HBoxContainer.new()
	speeds.name = "speeds"
	speeds.add_theme_constant_override("separation", UIKit.SPACE_MD)
	for speed: int in SPEEDS:
		speeds.add_child(_choice("%dx" % speed, Profile.playback() == speed, func() -> void:
			Profile.set_playback(speed)
			Audio.play("ui_confirm", -10.0)
			_rebuild()))
	_body.add_child(speeds)

	_body.add_child(_gap(6))
	_body.add_child(_heading("VOLUME"))
	var volumes := HBoxContainer.new()
	volumes.name = "volumes"
	volumes.add_theme_constant_override("separation", UIKit.SPACE_MD)
	var level: int = Profile.volume() if Profile.sound_on() else 0
	for v: int in VOLUMES:
		volumes.add_child(_choice("OFF" if v == 0 else "%d%%" % v, level == v, func() -> void:
			if v == 0:
				Profile.set_sound(false)
			else:
				Profile.set_volume(v)
				if not Profile.sound_on():
					Profile.set_sound(true)
				Audio.play("ui_confirm", -6.0)
			_rebuild()))
	_body.add_child(volumes)

	if Run.active or Run.has_saved():
		_body.add_child(_gap(6))
		_body.add_child(_heading("THE RUN"))
		if _confirming:
			var warn: Label = _line("Abandon this run? The save is deleted and the crew is lost. This cannot be undone.")
			warn.add_theme_color_override("font_color", UIKit.INK_RED)
			_body.add_child(warn)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", UIKit.SPACE_MD)
			var yes: Button = _button("ABANDON", UIKit.secondary(UIKit.RED), UIKit.PAPER, _abandon)
			yes.name = "abandon_confirm"
			row.add_child(yes)
			var no: Button = _button("KEEP THE RUN", UIKit.secondary(), UIKit.TEXT, func() -> void:
				_confirming = false
				_rebuild())
			no.name = "abandon_cancel"
			row.add_child(no)
			_body.add_child(row)
		else:
			var drop: Button = _button("ABANDON RUN", UIKit.secondary(), UIKit.INK_RED, func() -> void:
				_confirming = true
				Audio.play("ui_deny", -10.0)
				_rebuild())
			drop.name = "abandon"
			drop.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			_body.add_child(drop)

	_body.add_child(_gap(10))
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	var done: Button = _button("CLOSE", UIKit.primary(), UIKit.TEXT, close)
	done.name = "close"
	bottom.add_child(done)
	_body.add_child(bottom)


func _abandon() -> void:
	Run.abandon()
	Audio.play("ui_deny", -6.0)
	var tree: SceneTree = get_tree()
	queue_free()
	tree.change_scene_to_file("res://scenes/main.tscn")


# --- Pieces -------------------------------------------------------------------

func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UIKit.font_comic())
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", UIKit.TEXT)
	return label


func _line(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(720, 0)
	label.add_theme_font_override("font", UIKit.font_strong())
	label.add_theme_font_size_override("font_size", UIKit.SIZE_BODY)
	label.add_theme_color_override("font_color", UIKit.INK_DIM)
	return label


func _gap(height: int) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	return gap


## One of several equal options: paper, the chosen one ringed in amber (`UIKit.choice`).
func _choice(text: String, chosen: bool, on_press: Callable) -> Button:
	var button: Button = _button(text, UIKit.choice() if chosen else UIKit.secondary(), UIKit.TEXT, on_press)
	button.custom_minimum_size = Vector2(124, 58)
	if chosen:
		button.add_theme_font_override("font", UIKit.font_comic())
	return button


func _button(text: String, style: InkBox, ink: Color, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(220, 58)
	button.add_theme_font_override("font", UIKit.font_strong())
	button.add_theme_font_size_override("font_size", UIKit.SIZE_HEADING + 4)
	for state: String in ["normal", "hover", "focus"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_stylebox_override("pressed", UIKit.pressed(style))
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, ink)
	button.pressed.connect(on_press)
	return button
