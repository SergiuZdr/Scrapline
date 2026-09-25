extends Control

## The region map: where the crew is, where it can go, and how long before the Reclaimer
## takes the ground it stands on.
##
## Rebuilt after play-tests 1 and 2 ("you cannot tell when you need to move ahead or can
## move sideways"). The map now answers that question directly:
##   - the region is drawn as ZONES (columns), named across the top;
##   - the Reclaimer is a wall over the zones it has taken, with the NEXT zone to fall
##     striped and a countdown in moves;
##   - every site you can reach is labelled FORWARD, SIDEWAYS or BACK;
##   - tapping a site previews it -- what it is, and what this move costs -- before TRAVEL.
##
## Reads `Run.state`; changes it only through `Run.apply`. Every panel is rebuilt from the
## state after each action, so nothing on screen can disagree with the run.

const RefitPanel := preload("res://scripts/run/refit_panel.gd")

const MAP_RECT := Rect2(40, 150, 1250, 780)
const MAP_PAD := Vector2(90, 110)
const NODE_SIZE: float = 96.0
const SIDE_X: float = 1320.0
const SIDE_W: float = 560.0

## `type -> [name, icon, colour, what it is]`.
const SITES: Dictionary = {
	"start":     ["START", "yard", Color("3a362d"), "Where the crew rolled in."],
	"skirmish":  ["FIGHT", "fight", Color("7a3a2a"), "A fight. Win for scrap and a pick of salvage."],
	"elite":     ["ELITE", "colossus", Color("9c2f22"), "A hard fight. One salvage pick is guaranteed uncommon or better."],
	"scrapyard": ["SCRAPYARD", "scrap", Color("3f5a2e"), "No fight. Take one part, or strip the yard for scrap."],
	"workshop":  ["WORKSHOP", "foundry", Color("2e4f66"), "Repair the crew, rebuild a wreck, or buy room in the hold."],
	"boss":      ["THE GATE", "gauntlet", Color("5c1f1a"), "The act boss. Win to clear the act."],
}

var _map: Control
var _site_buttons: Dictionary = {}
var _side: VBoxContainer
var _top_hp: ProgressBar
var _top_hp_label: Label
var _top_scrap: Label
var _front_label: Label
var _overlay: Control
var _refit: Control
## The site tapped but not yet travelled to, or -1.
var _chosen: int = -1


func _ready() -> void:
	UIKit.apply(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not Run.active and not Run.continue_run():
		Run.new_run()
	add_child(UIKit.backdrop())
	_build_top_bar()
	_map = Control.new()
	_map.position = MAP_RECT.position
	_map.size = MAP_RECT.size
	_map.draw.connect(_draw_map)
	add_child(_map)
	var side_scroll := ScrollContainer.new()
	side_scroll.position = Vector2(SIDE_X, 118)
	side_scroll.size = Vector2(SIDE_W, 1080 - 118 - 30)
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(side_scroll)
	_side = VBoxContainer.new()
	_side.custom_minimum_size = Vector2(SIDE_W - 16, 0)
	_side.add_theme_constant_override("separation", UIKit.SPACE_MD)
	side_scroll.add_child(_side)
	_refresh()


# --- Top bar ------------------------------------------------------------------

func _build_top_bar() -> void:
	var title := _label("ACT 1  ·  THE CRANE YARDS", 40, UIKit.TEXT, UIKit.font_display())
	title.position = Vector2(40, 26)
	add_child(title)
	_front_label = _label("", UIKit.SIZE_HEADING, UIKit.RED.lightened(0.2), UIKit.font_strong())
	_front_label.position = Vector2(40, 84)
	add_child(_front_label)
	var bar := HBoxContainer.new()
	bar.position = Vector2(1060, 36)
	bar.add_theme_constant_override("separation", UIKit.SPACE_LG)
	add_child(bar)
	var hp_box := VBoxContainer.new()
	hp_box.custom_minimum_size = Vector2(320, 0)
	bar.add_child(hp_box)
	_top_hp_label = _label("", UIKit.SIZE_LABEL, UIKit.TEXT, UIKit.font_strong())
	hp_box.add_child(_top_hp_label)
	_top_hp = ProgressBar.new()
	_top_hp.show_percentage = false
	_top_hp.custom_minimum_size = Vector2(0, 12)
	_top_hp.add_theme_stylebox_override("background", UIKit.plain(UIKit.SURFACE_SUNK, 2))
	hp_box.add_child(_top_hp)
	_top_scrap = _label("", UIKit.SIZE_TITLE, UIKit.TEXT, UIKit.font_numbers())
	bar.add_child(_top_scrap)
	var quit := _button("TITLE", UIKit.secondary(), UIKit.TEXT, Vector2(130, 48))
	quit.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))
	bar.add_child(quit)


func _refresh() -> void:
	var state: RunState = Run.state
	var hp: int = 0
	var full: int = 0
	for member: Dictionary in state.crew:
		if bool(member["alive"]):
			hp += int(member["hp"])
			full += RunSim.max_hp(Run.setup, member)
	_top_hp_label.text = "CREW HP  %d / %d" % [hp, full]
	_top_hp.max_value = maxi(1, full)
	_top_hp.value = hp
	_top_hp.add_theme_stylebox_override("fill", UIKit.plain(UIKit.RED if hp * 3 <= full else UIKit.GREEN, 2))
	_top_scrap.text = "SCRAP %d" % state.scrap
	_front_label.text = _front_text()
	if _chosen >= 0 and not RunSim.destinations(state).has(_chosen):
		_chosen = -1
	_build_site_buttons()
	_map.queue_redraw()
	_build_side()
	_show_overlay()


## "The Reclaimer takes ZONE 3 in 2 moves." The one number that says how long you have.
func _front_text() -> String:
	var state: RunState = Run.state
	var every: int = maxi(1, int((Run.setup.rules["front"] as Dictionary)["every"]))
	var left: int = every - state.moves % every
	var zone: int = state.front_col + 2
	var text: String = "THE RECLAIMER TAKES %s IN %d MOVE%s" % ["THE START" if zone == 1 else "ZONE %d" % zone, left, "" if left == 1 else "S"]
	if state.consumed(state.current):
		text += "  ·  YOU ARE IN ITS GROUND: LEAVING COSTS EVERY MACHINE %d HP" % int((Run.setup.rules["front"] as Dictionary)["damage"])
	return text


# --- The map ------------------------------------------------------------------

func _columns() -> int:
	return int((Run.setup.rules.get("region", {}) as Dictionary).get("columns", 7))


func _to_map(site: Dictionary) -> Vector2:
	var w: float = MAP_RECT.size.x - MAP_PAD.x * 2.0
	var h: float = MAP_RECT.size.y - MAP_PAD.y - 60.0
	return Vector2(MAP_PAD.x + float(site["x"]) / 100.0 * w, MAP_PAD.y + float(site["y"]) / 100.0 * h)


func _column_x(col: float) -> float:
	return MAP_PAD.x + col / float(_columns() - 1) * (MAP_RECT.size.x - MAP_PAD.x * 2.0)


func _direction(to: int) -> String:
	var here: int = int(Run.state.site(Run.state.current)["col"])
	var there: int = int(Run.state.site(to)["col"])
	return "FORWARD" if there > here else ("SIDEWAYS" if there == here else "BACK")


func _build_site_buttons() -> void:
	for child: Node in _map.get_children():
		child.queue_free()
	_site_buttons.clear()
	var state: RunState = Run.state
	var targets: Array[int] = RunSim.destinations(state)
	for site: Dictionary in state.sites:
		var id: int = int(site["id"])
		var known: bool = RunSim.revealed(state, id)
		var look: Array = SITES.get(String(site["type"]), ["?", "", UIKit.SURFACE_HIGH, ""]) if known \
			else ["UNKNOWN", "", UIKit.SURFACE_HIGH, ""]
		var at: Vector2 = _to_map(site)
		var button := Button.new()
		button.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
		button.size = Vector2(NODE_SIZE, NODE_SIZE)
		button.position = at - Vector2(NODE_SIZE, NODE_SIZE) * 0.5
		button.focus_mode = Control.FOCUS_NONE
		var style := UIKit.plain(look[2] as Color, int(NODE_SIZE / 2.0))
		style.set_border_width_all(2)
		style.border_color = UIKit.HAIRLINE
		if id == state.current:
			style.border_color = UIKit.AMBER
			style.set_border_width_all(5)
		elif id == _chosen:
			style.border_color = UIKit.AMBER
			style.set_border_width_all(4)
		elif targets.has(id):
			style.border_color = UIKit.BLUE
			style.set_border_width_all(4)
		if bool(site["visited"]) and id != state.current:
			style.bg_color = style.bg_color.darkened(0.5)
		for key: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(key, style)
		button.disabled = not targets.has(id)
		if state.consumed(id):
			button.modulate = Color(1, 1, 1, 0.3)
		button.pressed.connect(_choose.bind(id))
		_map.add_child(button)
		_site_buttons[id] = button
		if known and not String(look[1]).is_empty():
			var icon: TextureRect = UIKit.icon(String(look[1]), 52, UIKit.TEXT if not bool(site["visited"]) or id == state.current else UIKit.TEXT_FAINT)
			button.add_child(icon)
			icon.position = Vector2(NODE_SIZE - 52, NODE_SIZE - 52) * 0.5
		elif not known:
			var q := _label("?", 40, UIKit.TEXT_FAINT, UIKit.font_display())
			button.add_child(q)
			q.size = Vector2(NODE_SIZE, NODE_SIZE)
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# Name under the circle; the direction above it for every site you can go to.
		var done: bool = bool(site["visited"]) and id != state.current and String(site["type"]) != "start"
		var name := _label(String(look[0]) + ("  ·  DONE" if done else ""),
			UIKit.SIZE_LABEL, UIKit.TEXT if targets.has(id) or id == state.current else UIKit.TEXT_DIM, UIKit.font_strong())
		name.position = at + Vector2(-70, NODE_SIZE * 0.5 + 2)
		name.custom_minimum_size = Vector2(140, 0)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_map.add_child(name)
		var over: String = ""
		if targets.has(id):
			over = _direction(id)
		elif id == state.current:
			over = "YOU ARE HERE"
		if not over.is_empty():
			var tag := _label(over, UIKit.SIZE_LABEL, UIKit.AMBER if id == state.current else UIKit.BLUE.lightened(0.3), UIKit.font_strong())
			tag.position = at + Vector2(-70, -NODE_SIZE * 0.5 - 24)
			tag.custom_minimum_size = Vector2(140, 0)
			tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_map.add_child(tag)


func _draw_map() -> void:
	var state: RunState = Run.state
	var columns: int = _columns()
	_map.draw_style_box(UIKit.card(UIKit.SURFACE.darkened(0.15)), Rect2(Vector2.ZERO, MAP_RECT.size))
	var half: float = (_column_x(1) - _column_x(0)) * 0.5
	var here_col: int = int(state.site(state.current)["col"])
	# Zones: one band per column, named across the top.
	for col: int in columns:
		var x0: float = _column_x(col) - half
		var band := Rect2(x0, 50, half * 2.0, MAP_RECT.size.y - 60)
		if col % 2 == 0:
			_map.draw_rect(band, Color(1, 1, 1, 0.025))
		if col == here_col:
			_map.draw_rect(band, Color(0.9, 0.7, 0.24, 0.05))
		var zone: String = "START" if col == 0 else ("GATE" if col == columns - 1 else "ZONE %d" % (col + 1))
		_map.draw_string(UIKit.font_strong(), Vector2(x0, 36), zone, HORIZONTAL_ALIGNMENT_CENTER, half * 2.0, 16,
			UIKit.AMBER if col == here_col else UIKit.TEXT_DIM)
	# The Reclaimer: a wall over what it has taken, and stripes over what it takes next.
	var taken_to: float = _column_x(state.front_col) + half if state.front_col >= 0 else _column_x(0) - half
	if state.front_col >= 0:
		_map.draw_rect(Rect2(0, 50, taken_to, MAP_RECT.size.y - 60), Color(0.55, 0.12, 0.08, 0.35))
		_map.draw_string(UIKit.font_display(), Vector2(14, MAP_RECT.size.y - 24), "RECLAIMED", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.95, 0.45, 0.35, 0.9))
	if state.front_col + 1 < columns - 1:
		var next := Rect2(maxf(taken_to, 0.0), 50, half * 2.0, MAP_RECT.size.y - 60)
		var y: float = next.position.y - next.size.x
		while y < next.end.y:
			var a := Vector2(next.position.x, maxf(y, next.position.y))
			var b := Vector2(minf(next.end.x, next.position.x + (next.end.y - y)), minf(y + next.size.x, next.end.y))
			if y < next.position.y:
				a = Vector2(next.position.x + (next.position.y - y), next.position.y)
			_map.draw_line(a, b, Color(0.9, 0.35, 0.2, 0.2), 6.0)
			y += 30.0
		_map.draw_string(UIKit.font_strong(), Vector2(next.position.x, MAP_RECT.size.y - 24), "FALLS NEXT", HORIZONTAL_ALIGNMENT_CENTER, next.size.x, 16, Color(0.95, 0.5, 0.35))
	if taken_to > 0.0:
		_map.draw_line(Vector2(taken_to, 50), Vector2(taken_to, MAP_RECT.size.y - 10), Color(0.95, 0.35, 0.2, 0.9), 4.0)
	# Roads: thick, and the ones you can take now in blue.
	var targets: Array[int] = RunSim.destinations(state)
	for site: Dictionary in state.sites:
		for other: Variant in (site["links"] as Array):
			if int(other) < int(site["id"]):
				continue
			var a: Vector2 = _to_map(site)
			var b: Vector2 = _to_map(state.site(int(other)))
			var live: bool = (int(site["id"]) == state.current and targets.has(int(other))) \
				or (int(other) == state.current and targets.has(int(site["id"])))
			var chosen: bool = live and (int(site["id"]) == _chosen or int(other) == _chosen)
			_map.draw_line(a, b, Color(0.05, 0.05, 0.05, 0.6), 12.0, true)
			_map.draw_line(a, b, UIKit.AMBER if chosen else (UIKit.BLUE if live else UIKit.EDGE_LIGHT), 6.0 if live else 3.0, true)


# --- Side panel ---------------------------------------------------------------

func _build_side() -> void:
	for child: Node in _side.get_children():
		child.queue_free()
	var state: RunState = Run.state
	if state.overfull():
		var warn := _plate(UIKit.RED.darkened(0.55))
		var over: int = state.cargo.size() - state.hold_size
		warn.add_child(_wrap("HOLD OVERFULL (%d / %d). Fit or scrap %d part%s in REFIT before moving on." % [
			state.cargo.size(), state.hold_size, over, "" if over == 1 else "s"], UIKit.SIZE_BODY, UIKit.TEXT))
		_side.add_child(warn)
	_side.add_child(_preview_plate())

	var head := HBoxContainer.new()
	_side.add_child(head)
	head.add_child(_label("CREW", UIKit.SIZE_HEADING, UIKit.TEXT, UIKit.font_display()))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	if RunSim.can_refit(state):
		var refit := _button("REFIT  ·  HOLD %d/%d" % [state.cargo.size(), state.hold_size],
			UIKit.primary() if state.overfull() else UIKit.secondary(), UIKit.BG if state.overfull() else UIKit.TEXT, Vector2(260, 48))
		refit.add_theme_font_size_override("font_size", UIKit.SIZE_BODY)
		refit.pressed.connect(_open_refit)
		head.add_child(refit)
	for member: Dictionary in state.crew:
		_side.add_child(_crew_card(member))


## What the chosen site is and what travelling there costs, with TRAVEL. Without a
## choice, how to make one.
func _preview_plate() -> Control:
	var state: RunState = Run.state
	var plate := _plate(UIKit.SURFACE)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.SPACE_SM)
	plate.add_child(box)
	if _chosen < 0:
		var targets: Array[int] = RunSim.destinations(state)
		box.add_child(_label("WHERE NEXT?", UIKit.SIZE_HEADING, UIKit.TEXT, UIKit.font_strong()))
		box.add_child(_wrap("Tap a blue-ringed site to see what it is and what the move costs. FORWARD heads for the gate; SIDEWAYS and BACK spend a move while the Reclaimer keeps coming."
			if not targets.is_empty() else "Nowhere to go right now.", UIKit.SIZE_LABEL, UIKit.TEXT_DIM))
		return plate
	var site: Dictionary = state.site(_chosen)
	var known: bool = RunSim.revealed(state, _chosen)
	var look: Array = SITES.get(String(site["type"]), ["?", "", UIKit.SURFACE_HIGH, ""]) if known \
		else ["UNKNOWN", "", UIKit.SURFACE_HIGH, "Not scouted yet: you find out when you get there."]
	box.add_child(_label("%s  ·  %s" % [_direction(_chosen), String(look[0])], UIKit.SIZE_HEADING, UIKit.AMBER, UIKit.font_strong()))
	box.add_child(_wrap(String(look[3]) if not bool(site["visited"]) else "Already cleared: nothing happens there now.", UIKit.SIZE_BODY, UIKit.TEXT))
	for line: String in _move_costs(_chosen):
		box.add_child(_wrap(line, UIKit.SIZE_LABEL, UIKit.RED.lightened(0.25)))
	var go := _button("TRAVEL", UIKit.primary(), UIKit.BG, Vector2(220, 60))
	go.pressed.connect(func() -> void: _apply([RunSim.TRAVEL, _chosen]))
	box.add_child(go)
	return plate


## What this move does to the crew and the front, in words.
func _move_costs(to: int) -> PackedStringArray:
	var state: RunState = Run.state
	var front: Dictionary = Run.setup.rules["front"]
	var every: int = maxi(1, int(front["every"]))
	var out: PackedStringArray = []
	if state.consumed(state.current):
		out.append("Leaving reclaimed ground: every machine loses %d HP." % int(front["damage"]))
	if (state.moves + 1) % every == 0:
		var zone: int = state.front_col + 2
		out.append("This move lets the Reclaimer take %s." % ("the start" if zone == 1 else "ZONE %d" % zone))
		if int(state.site(to)["col"]) <= state.front_col + 1:
			out.append("You will be standing in its ground: your next move out costs every machine %d HP." % int(front["damage"]))
	return out


func _crew_card(member: Dictionary) -> Control:
	var plate := _plate(UIKit.SURFACE)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.SPACE_XS)
	plate.add_child(box)
	var alive: bool = bool(member["alive"])
	var full: int = RunSim.max_hp(Run.setup, member)
	box.add_child(_label(String(member["name"]) + ("" if alive else "  ·  WRECK: rebuild at a workshop"), UIKit.SIZE_HEADING,
		UIKit.TEXT if alive else UIKit.RED, UIKit.font_strong()))
	if alive:
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		bar.max_value = full
		bar.value = int(member["hp"])
		bar.add_theme_stylebox_override("background", UIKit.plain(UIKit.SURFACE_SUNK, 2))
		bar.add_theme_stylebox_override("fill", UIKit.plain(UIKit.GREEN if int(member["hp"]) * 3 > full else UIKit.RED, 2))
		box.add_child(bar)
		box.add_child(_label("%d / %d HP" % [int(member["hp"]), full], UIKit.SIZE_LABEL, UIKit.TEXT_DIM, UIKit.font_numbers()))
	var thumbs := HBoxContainer.new()
	thumbs.add_theme_constant_override("separation", UIKit.SPACE_XS)
	box.add_child(thumbs)
	for part: Variant in (member["parts"] as Array):
		var well := PanelContainer.new()
		well.custom_minimum_size = Vector2(90, 64)
		well.add_theme_stylebox_override("panel", UIKit.inset(UIKit.SURFACE_HIGH, UIKit.RADIUS_CONTROL, 2, 2))
		well.tooltip_text = PartText.name_of(Run.db.parts, String(part))
		thumbs.add_child(well)
		var tex := TextureRect.new()
		tex.texture = PartText.thumb(String(part))
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		well.add_child(tex)
	return plate


# --- Site panels --------------------------------------------------------------

func _show_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	var state: RunState = Run.state
	if state.outcome != RunState.ONGOING:
		_run_over()
		return
	match String(state.pending.get("kind", "")):
		"fight":
			_fight_panel()
		"reward", "scrapyard":
			_pick_panel()
		"workshop":
			_workshop_panel()


func _modal(title: String, subtitle: String, width: float = 1100.0) -> VBoxContainer:
	_overlay = Control.new()
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	_overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.add_theme_stylebox_override("panel", UIKit.card(UIKit.SURFACE, UIKit.RADIUS_CARD, UIKit.SPACE_XXL, UIKit.SPACE_XL))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.SPACE_LG)
	panel.add_child(box)
	box.add_child(_label(title, UIKit.SIZE_DISPLAY, UIKit.TEXT, UIKit.font_display()))
	if not subtitle.is_empty():
		box.add_child(_wrap(subtitle, UIKit.SIZE_BODY, UIKit.TEXT_DIM, width - 100))
	return box


func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.SPACE_MD)
	parent.add_child(row)
	return row


func _fight_panel() -> void:
	var state: RunState = Run.state
	var kind: String = String(state.pending["site_type"])
	var fight: Dictionary = state.pending["fight"]
	var titles: Dictionary = {"skirmish": "FIGHT", "elite": "ELITE FIGHT", "boss": "THE GATE"}
	var enemies: PackedStringArray = []
	for spec: Dictionary in (fight["enemy"] as Array):
		var kind_name: String = String(spec.get("kind", ""))
		enemies.append(String(spec["name"]) + ((" (%s)" % kind_name.to_upper()) if not kind_name.is_empty() else ""))
	var objective: Dictionary = fight.get("objective", {"type": "rout"})
	var goals: Dictionary = {
		"rout": "ROUT: destroy every enemy.",
		"defend": "DEFEND: keep the salvage caches standing for %d rounds (or destroy every enemy). Each cache you save pays out scrap." % int(objective.get("rounds", 0)),
		"salvage": "SALVAGE: collect %d scrap piles before the enemy carries them off (or destroy every enemy)." % int(objective.get("need", 0)),
	}
	var box := _modal(String(titles.get(kind, "FIGHT")),
		"%s\n\n%d enemies: %s.\nDamage your machines take here stays with them after the fight." % [
			String(goals.get(String(objective.get("type", "rout")), "")), enemies.size(), ", ".join(enemies)], 960)
	if Run.fight_actions.size() > 0:
		box.add_child(_label("This fight is in progress. It resumes where you left it.", UIKit.SIZE_BODY, UIKit.GOLD))
	var row := _row(box)
	var go := _button("ENTER FIGHT" if Run.fight_actions.is_empty() else "RESUME FIGHT", UIKit.primary(), UIKit.BG, Vector2(300, 64))
	go.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/combat.tscn"))
	row.add_child(go)


func _pick_panel() -> void:
	var state: RunState = Run.state
	var scrapyard: bool = String(state.pending["kind"]) == "scrapyard"
	var note: String = ("Take one part into the hold, or strip the yard for scrap." if scrapyard else "Take one part off the wrecks.")
	note += "  Hold: %d / %d." % [state.cargo.size(), state.hold_size]
	if state.cargo.size() >= state.hold_size:
		note += "  It is full: you can still take a part, then fit or scrap something in REFIT before moving on."
	var box := _modal("SCRAPYARD" if scrapyard else "SALVAGE", note, 1240)
	var row := _row(box)
	var options: Array = state.pending["options"]
	for i: int in options.size():
		var card: Button = PartCard.build(Run.db, String(options[i]), Vector2(380, 236), state.crew)
		card.pressed.connect(_pick.bind(i))
		row.add_child(card)
	var actions := _row(box)
	var skip := _button(("TAKE %d SCRAP INSTEAD" % int(state.pending["scrap"])) if scrapyard else "LEAVE IT",
		UIKit.secondary(), UIKit.TEXT, Vector2(320, 60))
	skip.pressed.connect(_pick.bind(-1))
	actions.add_child(skip)


func _workshop_panel() -> void:
	var state: RunState = Run.state
	var shop: Dictionary = Run.setup.rules.get("workshop", {})
	var box := _modal("WORKSHOP", "Scrap buys work here. You have %d." % state.scrap, 960)
	if RunSim.needs_repair(state, Run.setup):
		box.add_child(_offer("PATCH THE CREW  +%d HP EACH" % int(shop["repair_amount"]), int(shop["repair_cost"]), state.scrap, [RunSim.REPAIR]))
	else:
		box.add_child(_label("Every machine is in one piece.", UIKit.SIZE_BODY, UIKit.GREEN))
	for i: int in state.crew.size():
		var member: Dictionary = state.crew[i]
		if not bool(member["alive"]):
			box.add_child(_offer("REBUILD %s AT HALF HP (sockets empty)" % String(member["name"]).to_upper(),
				int(shop["rebuild_cost"]), state.scrap, [RunSim.REBUILD, i]))
	var expand: int = RunSim.expand_cost(state, Run.setup)
	if expand >= 0:
		box.add_child(_offer("MORE ROOM IN THE HOLD  %d TO %d" % [state.hold_size,
			state.hold_size + int((Run.setup.rules["hold"] as Dictionary)["expand_by"])], expand, state.scrap, [RunSim.EXPAND_HOLD]))
	var row := _row(box)
	var refit := _button("REFIT", UIKit.secondary(), UIKit.TEXT, Vector2(160, 60))
	refit.pressed.connect(_open_refit)
	row.add_child(refit)
	var leave := _button("MOVE ON", UIKit.primary(), UIKit.BG, Vector2(240, 60))
	leave.pressed.connect(func() -> void: _apply([RunSim.LEAVE]))
	row.add_child(leave)


## A priced offer: a button when affordable, a label saying what it would cost when not.
func _offer(text: String, cost: int, scrap: int, action: Array) -> Control:
	if scrap < cost:
		return _label("%s  ·  %d SCRAP (you have %d)" % [text, cost, scrap], UIKit.SIZE_BODY, UIKit.TEXT_FAINT)
	var button := _button("%s  ·  %d SCRAP" % [text, cost], UIKit.choice(), UIKit.TEXT, Vector2(700, 60))
	button.pressed.connect(func() -> void: _apply(action))
	return button


func _run_over() -> void:
	var state: RunState = Run.state
	var won: bool = state.outcome == RunState.WON
	var box := _modal("ACT 1 CLEARED" if won else "RUN OVER",
		"%s\n\n%d fights won  ·  %d moves  ·  %d scrap" % [state.end_reason, state.fights_won, state.moves, state.scrap], 900)
	var row := _row(box)
	var title := _button("TITLE", UIKit.secondary(), UIKit.TEXT, Vector2(200, 64))
	title.pressed.connect(func() -> void:
		Run.end_run()
		get_tree().change_scene_to_file("res://scenes/main.tscn"))
	row.add_child(title)
	var again := _button("NEW RUN", UIKit.primary(), UIKit.BG, Vector2(260, 64))
	again.pressed.connect(func() -> void:
		Run.end_run()
		Run.new_run()
		_refresh())
	row.add_child(again)


# --- Actions ------------------------------------------------------------------

## First tap previews a site; the TRAVEL button (or a second tap) goes.
func _choose(id: int) -> void:
	if _chosen == id:
		_apply([RunSim.TRAVEL, id])
		return
	_chosen = id
	Audio.play("ui_confirm", -16.0)
	_refresh()


func _travel(id: int) -> void:
	_apply([RunSim.TRAVEL, id])


func _pick(index: int) -> void:
	_apply([RunSim.PICK, index])


func _open_refit() -> void:
	if _refit != null:
		return
	_refit = RefitPanel.new()
	add_child(_refit)
	_refit.closed.connect(func() -> void:
		_refit.queue_free()
		_refit = null
		_refresh())


func _apply(action: Array) -> void:
	if Run.apply(action):
		Audio.play("ui_confirm", -12.0)
		if int(action[0]) == RunSim.TRAVEL:
			_chosen = -1
	else:
		Audio.play("ui_deny", -10.0)
	_refresh()


# --- Pieces -------------------------------------------------------------------

func _plate(fill: Color) -> PanelContainer:
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UIKit.card(fill))
	return plate


func _wrap(text: String, size: int, colour: Color, width: float = SIDE_W - 60) -> Label:
	var label := _label(text, size, colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	return label


func _label(text: String, size: int, colour: Color, face: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	if face != null:
		label.add_theme_font_override("font", face)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, style: StyleBoxFlat, ink: Color, size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", UIKit.font_strong())
	button.add_theme_font_size_override("font_size", UIKit.SIZE_HEADING)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, ink)
	for key: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(key, style)
	return button
