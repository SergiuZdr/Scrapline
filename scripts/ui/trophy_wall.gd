extends Control

## 085: the TROPHY WALL (the user, 2026-10-29): what the weekly contracts gave. One hook per trophy in
## the rotation (`data/weekly_rewards.json`): an earned trophy hangs on its hook with its week and its
## livery; one not earned is an empty hook with the week it was last offered. Cosmetic only.
##
## A display class: it is handed what it shows (`build`) and never reads the `Run` autoload.

signal closed

const CARD := Vector2(452, 318)
const PICTURE: float = 196.0
## How far back to look for the week a trophy was last offered.
const LOOK_BACK: int = 104


## The wall over `parent`. `this_week`: weeks since 1970-01-05; `reward_of(week) -> {id, trophy, livery,
## name}`; `held`: `Profile.trophies()`.
static func build(parent: Control, this_week: int, reward_of: Callable, held: Array) -> Control:
	var wall: Control = (load("res://scripts/ui/trophy_wall.gd") as GDScript).new()
	wall.name = "trophy_wall"
	parent.add_child(wall)
	wall.call("_fill", this_week, reward_of, held)
	return wall


func _fill(this_week: int, reward_of: Callable, held: Array) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.78)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.SPACE_MD)
	center.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", UIKit.SPACE_LG)
	box.add_child(head)
	head.add_child(UIKit.caption_title("TROPHY WALL", 40))
	var count: int = _unique(held).size()
	var all: Array = WeeklyRewards.list()
	var tally := UIKit.on_page(_label("%d OF %d HUNG" % [count, all.size()], 26, UIKit.PAGE_TEXT, UIKit.font_comic()), 6)
	tally.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tally)
	var line := UIKit.on_page(_label("Clear a weekly contract to hang its trophy. Each one also gives a LIVERY any machine can wear (LIVERY, under the machine).",
		UIKit.SIZE_BODY, UIKit.PAGE_TEXT, UIKit.font_strong()), 5)
	box.add_child(line)

	var offered: Dictionary = _last_offered(this_week, reward_of, all.size())
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", UIKit.SPACE_LG)
	grid.add_theme_constant_override("v_separation", UIKit.SPACE_LG)
	box.add_child(grid)
	for reward: Dictionary in all:
		var id: String = String(reward["id"])
		var won: Array = held.filter(func(t: Dictionary) -> bool: return String(t.get("id", "")) == id)
		grid.add_child(_hook(reward, won, int(offered.get(id, -1)), this_week))

	var close := Button.new()
	close.name = "close_wall"
	close.text = "BACK TO THE GARAGE"
	close.custom_minimum_size = Vector2(320, 56)
	close.focus_mode = Control.FOCUS_NONE
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.add_theme_font_override("font", UIKit.font_comic())
	close.add_theme_font_size_override("font_size", 22)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		close.add_theme_color_override(key, UIKit.BG)
	for key: String in ["normal", "hover", "focus"]:
		close.add_theme_stylebox_override(key, UIKit.primary())
	close.add_theme_stylebox_override("pressed", UIKit.pressed(UIKit.primary()))
	close.pressed.connect(func() -> void:
		closed.emit()
		queue_free())
	box.add_child(close)


## One hook: the trophy hung (earned) or the bare hook and when it was offered.
func _hook(reward: Dictionary, won: Array, offered: int, this_week: int) -> Control:
	var earned: bool = not won.is_empty()
	var card := PanelContainer.new()
	card.name = "hook_" + String(reward["id"])
	card.custom_minimum_size = CARD
	card.add_theme_stylebox_override("panel", UIKit.ink_card(UIKit.PAPER_CARD if earned else UIKit.PAPER_DIM, UIKit.SPACE_MD, UIKit.SPACE_SM, 4))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(CARD.x - 2 * UIKit.SPACE_MD, PICTURE + 22)
	box.add_child(stage)
	var nail := HookMark.new()
	nail.earned = earned
	nail.position = Vector2((CARD.x - 2 * UIKit.SPACE_MD) * 0.5 - 20, 0)
	nail.size = Vector2(40, 40)
	stage.add_child(nail)
	var picture: Texture2D = WeeklyRewards.picture(String(reward.get("trophy", "")))
	if earned and picture != null:
		var art := TextureRect.new()
		art.name = "trophy"
		art.texture = picture
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.position = Vector2(0, 20)
		art.size = Vector2(CARD.x - 2 * UIKit.SPACE_MD, PICTURE)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.add_child(art)
	elif not earned:
		# Where it would hang: the trophy's outline, faint, so the wall shows what is missing.
		if picture != null:
			var ghost := TextureRect.new()
			ghost.texture = picture
			ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ghost.position = Vector2(0, 34)
			ghost.size = Vector2(CARD.x - 2 * UIKit.SPACE_MD, PICTURE - 20)
			ghost.modulate = Color(0.08, 0.07, 0.06, 0.16)
			ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stage.add_child(ghost)
	var width: float = CARD.x - 2 * UIKit.SPACE_MD
	box.add_child(UIKit.fit(_label(String(reward.get("name", "")).to_upper(), 24, UIKit.INK if earned else UIKit.INK_DIM, UIKit.font_comic()), width, 1, 14))
	var when: String
	if earned:
		var first: Dictionary = won[0]
		when = "CLEARED WEEK OF %s" % _monday(int(first.get("week", 0)))
		if won.size() > 1:
			when += "  ·  x%d" % won.size()
	elif offered == this_week:
		when = "THIS WEEK'S CONTRACT  ·  not cleared yet"
	elif offered >= 0:
		when = "OFFERED WEEK OF %s  ·  not cleared" % _monday(offered)
	else:
		when = "not offered yet"
	box.add_child(UIKit.fit(_label(when, UIKit.SIZE_LABEL, UIKit.INK_GREEN if earned else UIKit.INK_DIM, UIKit.font_strong()), width, 1, 10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.SPACE_SM)
	box.add_child(row)
	var chip: Control = swatch(String(reward.get("livery", "")), Vector2(54, 22))
	chip.modulate = Color.WHITE if earned else Color(1, 1, 1, 0.45)
	row.add_child(chip)
	row.add_child(_label("LIVERY  ·  " + Ink.livery_name(String(reward.get("livery", ""))), UIKit.SIZE_LABEL,
		UIKit.INK if earned else UIKit.INK_FAINT, UIKit.font_comic()))
	return card


## For each reward id, the latest week up to this one that offered it (-1 if none in `LOOK_BACK` weeks).
static func _last_offered(this_week: int, reward_of: Callable, kinds: int) -> Dictionary:
	var out: Dictionary = {}
	for w: int in range(this_week, maxi(-1, this_week - LOOK_BACK), -1):
		var id: String = String((reward_of.call(w) as Dictionary).get("id", ""))
		if not id.is_empty() and not out.has(id):
			out[id] = w
			if out.size() >= kinds:
				break
	return out


static func _unique(held: Array) -> Array:
	var out: Array = []
	for t: Variant in held:
		var id: String = String((t as Dictionary).get("id", ""))
		if not out.has(id):
			out.append(id)
	return out


static func _monday(week: int) -> String:
	return Time.get_date_string_from_unix_time((week * 7 + 4) * 86400)


## A livery as a chip of paint: the paint, its trim in a slanted band, camo blotches, an ink edge.
## "" is the makers' paint (their yellow and rust).
static func swatch(livery: String, chip_size: Vector2 = Vector2(48, 22)) -> Control:
	var chip := Swatch.new()
	chip.livery = livery
	chip.custom_minimum_size = chip_size
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return chip


func _label(text: String, font_size: int, colour: Color, face: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_font_override("font", face if face != null else UIKit.font())
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


class Swatch:
	extends Control
	var livery: String = ""

	func _draw() -> void:
		var paint: Color = Ink.MUSTARD
		var trim: Color = Ink.RUST
		var camo: float = 0.0
		if Ink.LIVERIES.has(livery):
			var scheme: Array = Ink.LIVERIES[livery]
			paint = scheme[0]
			trim = scheme[1]
			camo = float(scheme[2])
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, paint)
		if camo > 0.0:
			for p: Vector2 in [Vector2(0.18, 0.3), Vector2(0.55, 0.7), Vector2(0.8, 0.25), Vector2(0.38, 0.85)]:
				draw_circle(Vector2(p.x * size.x, p.y * size.y), size.y * 0.28, trim)
		else:
			var a: float = size.x * 0.62
			draw_colored_polygon(PackedVector2Array([Vector2(a, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(a - size.y * 0.6, size.y)]), trim)
		draw_rect(r, Ink.INK, false, 2.0)


## A nail and an iron hook in ink: the trophy hangs from it, or it hangs empty.
class HookMark:
	extends Control
	var earned: bool = false

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, 8)
		draw_circle(c, 6.0, Ink.INK)
		draw_circle(c, 2.5, Color("8a8f8c"))
		if not earned:
			draw_line(c, c + Vector2(0, 16), Ink.INK, 4.0)
			draw_arc(c + Vector2(-6, 16), 6.0, 0.0, PI, 10, Ink.INK, 4.0)
			draw_line(c + Vector2(-12, 16), c + Vector2(-12, 10), Ink.INK, 4.0)
