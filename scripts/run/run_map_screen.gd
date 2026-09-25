extends Control

## The region map: a 3D yard (`YardView`) under a thin layer of interface.
##
## Play-test 3 rebuilt it again: the 2D diagram had dead space and a crew HP total nobody
## used, and a site took two clicks. Now:
##   - the yard is a place: landmarks, roads, and the Reclaimer as a wall you watch advance;
##   - ONE click travels. Hovering (PC) shows what a site is and what the move costs; the
##     direction and any cost are also written on the site itself, for touch;
##   - the crew is a strip of machines with their own HP and level, each opening the garage;
##   - the story: a briefing on a new run, the act and mission on screen, site text and
##     endings in the world's voice (`data/run/story.json`).
##
## Reads `Run.state`; changes it only through `Run.apply`.

const GaragePanel := preload("res://scripts/run/garage_panel.gd")

const SITE_NAMES: Dictionary = {"start": "CAMP", "skirmish": "FIGHT", "elite": "ELITE",
	"scrapyard": "SCRAPYARD", "workshop": "WORKSHOP", "boss": "THE GATE"}
const RECLAIMER_RED := Color("ff5a3d")

var _yard: YardView
var _labels: Control
var _site_labels: Dictionary = {}     # id -> Control
var _preview: PanelContainer
var _front_label: Label
var _scrap_label: Label
var _garage_button: Button
var _warning: PanelContainer
var _crew_strip: HBoxContainer
var _overlay: Control
var _garage: Control
var _hover: int = -1


func _ready() -> void:
	UIKit.apply(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not Run.active and not Run.continue_run():
		Run.new_run()
	_yard = YardView.new()
	add_child(_yard)
	_yard.build(Run.state, int((Run.setup.rules.get("region", {}) as Dictionary).get("columns", 7)))
	_labels = Control.new()
	_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_labels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_labels)
	_build_top_bar()
	_build_crew_strip()
	_preview = PanelContainer.new()
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.add_theme_stylebox_override("panel", UIKit.card(UIKit.SURFACE))
	_preview.custom_minimum_size = Vector2(380, 0)
	_preview.visible = false
	add_child(_preview)
	_refresh()


# --- Input: hover previews, one click travels ---------------------------------

func _gui_input(event: InputEvent) -> void:
	if _overlay != null or _garage != null:
		return
	if event is InputEventMouseMotion:
		var over: int = _yard.pick((event as InputEventMouseMotion).position)
		if over != _hover:
			_hover = over
			_yard.refresh(Run.state, RunSim.destinations(Run.state), _hover)
			_show_preview()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var id: int = _yard.pick((event as InputEventMouseButton).position)
		if id >= 0:
			_choose(id)


## One click (or tap): travel there if the road allows.
func _choose(id: int) -> void:
	if RunSim.destinations(Run.state).has(id):
		_apply([RunSim.TRAVEL, id])
	elif id != Run.state.current:
		Audio.play("ui_deny", -14.0)


func _process(_delta: float) -> void:
	# The camera is still, but the window may not be: keep the labels on their sites.
	for id: int in _site_labels:
		var label: Control = _site_labels[id]
		label.position = _yard.label_pos(id) + Vector2(-label.size.x * 0.5, 2)
	if _preview.visible and _hover >= 0:
		var at: Vector2 = _yard.screen_pos(_hover, 1.0) + Vector2(70, -80)
		at.x = minf(at.x, size.x - _preview.size.x - 20)
		at.y = clampf(at.y, 130, size.y - _preview.size.y - 170)
		_preview.position = at


# --- Top bar ------------------------------------------------------------------

func _build_top_bar() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.03, 0.035, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.position = Vector2.ZERO
	shade.size = Vector2(1920, 118)
	add_child(shade)
	var act: Dictionary = _act()
	var title := _label("ACT 1  ·  %s" % String(act.get("name", "THE CRANE YARDS")), 44, UIKit.TEXT, UIKit.font_display())
	title.position = Vector2(40, 16)
	add_child(title)
	var mission := _label(String(act.get("mission", "")), UIKit.SIZE_BODY, UIKit.TEXT_DIM)
	mission.position = Vector2(42, 74)
	add_child(mission)

	var front := PanelContainer.new()
	var style := UIKit.card(Color("2a1210"))
	style.border_color = RECLAIMER_RED.darkened(0.3)
	style.set_border_width_all(2)
	front.add_theme_stylebox_override("panel", style)
	front.position = Vector2(760, 22)
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(front)
	_front_label = _label("", UIKit.SIZE_HEADING, RECLAIMER_RED, UIKit.font_strong())
	front.add_child(_front_label)

	var right := HBoxContainer.new()
	right.position = Vector2(1320, 28)
	right.add_theme_constant_override("separation", UIKit.SPACE_LG)
	add_child(right)
	_scrap_label = _label("", UIKit.SIZE_TITLE, UIKit.TEXT, UIKit.font_numbers())
	_scrap_label.custom_minimum_size = Vector2(170, 0)
	right.add_child(_scrap_label)
	_garage_button = _button("GARAGE", UIKit.secondary(), UIKit.TEXT, Vector2(200, 56))
	_garage_button.pressed.connect(_open_garage.bind(0))
	right.add_child(_garage_button)
	var quit := _button("TITLE", UIKit.secondary(), UIKit.TEXT, Vector2(130, 56))
	quit.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))
	right.add_child(quit)

	_warning = PanelContainer.new()
	_warning.add_theme_stylebox_override("panel", UIKit.card(UIKit.RED.darkened(0.55)))
	_warning.position = Vector2(760, 130)
	_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_warning)


func _act() -> Dictionary:
	var acts: Array = Run.db.story.get("acts", [])
	return acts[0] if not acts.is_empty() else {}


func _front_text() -> String:
	var state: RunState = Run.state
	var every: int = maxi(1, int((Run.setup.rules["front"] as Dictionary)["every"]))
	var left: int = every - state.moves % every
	var zone: int = state.front_col + 2
	var name: String = String((Run.db.story.get("reclaimer", {}) as Dictionary).get("name", "THE RECLAIMER"))
	var text: String = "%s TAKES %s IN %d MOVE%s" % [name, "THE CAMP" if zone == 1 else "ZONE %d" % zone, left, "" if left == 1 else "S"]
	if state.consumed(state.current):
		text += "\nYOU ARE IN ITS GROUND: LEAVING COSTS EVERY MACHINE %d HP" % int((Run.setup.rules["front"] as Dictionary)["damage"])
	return text


# --- Crew strip ---------------------------------------------------------------

func _build_crew_strip() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.03, 0.035, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.position = Vector2(0, 1080 - 150)
	shade.size = Vector2(1920, 150)
	add_child(shade)
	_crew_strip = HBoxContainer.new()
	_crew_strip.position = Vector2(40, 1080 - 136)
	_crew_strip.add_theme_constant_override("separation", UIKit.SPACE_MD)
	add_child(_crew_strip)


func _refresh_crew() -> void:
	for child: Node in _crew_strip.get_children():
		child.queue_free()
	for i: int in Run.state.crew.size():
		_crew_strip.add_child(_crew_card(i))
	var hint := _label("Hover a site to see what it is. Click to go.", UIKit.SIZE_LABEL, UIKit.TEXT_FAINT)
	hint.custom_minimum_size = Vector2(300, 0)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_crew_strip.add_child(hint)


## A machine in the strip: its frame, name, level and HP. Opens the garage on it.
func _crew_card(i: int) -> Control:
	var member: Dictionary = Run.state.crew[i]
	var alive: bool = bool(member["alive"])
	var card := Button.new()
	card.custom_minimum_size = Vector2(430, 120)
	card.focus_mode = Control.FOCUS_NONE
	var style := UIKit.card(UIKit.SURFACE)
	for key: String in ["normal", "pressed", "focus"]:
		card.add_theme_stylebox_override(key, style)
	var hover: StyleBoxFlat = style.duplicate()
	hover.border_color = UIKit.AMBER
	hover.set_border_width_all(2)
	card.add_theme_stylebox_override("hover", hover)
	card.tooltip_text = "Open %s in the garage" % String(member["name"])
	card.pressed.connect(_open_garage.bind(i))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UIKit.SPACE_MD)
	card.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, UIKit.SPACE_SM)
	var portrait := TextureRect.new()
	portrait.texture = PartText.thumb(String(member["parts"][0]))
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(96, 96)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not alive:
		portrait.modulate = Color(1, 0.4, 0.35, 0.6)
	row.add_child(portrait)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var level: int = int(member.get("level", 0))
	text.add_child(_label("%s%s" % [String(member["name"]).to_upper(), ("   LV %d" % level) if level > 0 else ""],
		UIKit.SIZE_HEADING, UIKit.TEXT if alive else UIKit.RED, UIKit.font_strong()))
	if alive:
		var full: int = RunSim.max_hp(Run.setup, member)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(280, 12)
		bar.max_value = full
		bar.value = int(member["hp"])
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", UIKit.plain(UIKit.SURFACE_SUNK, 2))
		bar.add_theme_stylebox_override("fill", UIKit.plain(UIKit.GREEN if int(member["hp"]) * 3 > full else UIKit.RED, 2))
		text.add_child(bar)
		text.add_child(_label("%d / %d HP" % [int(member["hp"]), full], UIKit.SIZE_LABEL, UIKit.TEXT_DIM, UIKit.font_numbers()))
	else:
		text.add_child(_label("WRECK · rebuild at a workshop", UIKit.SIZE_LABEL, UIKit.RED))
	return card


# --- Refresh ------------------------------------------------------------------

func _refresh() -> void:
	var state: RunState = Run.state
	_front_label.text = _front_text()
	_scrap_label.text = "SCRAP %d" % state.scrap
	var over: bool = state.overfull()
	_garage_button.text = "GARAGE  %d/%d" % [state.cargo.size(), state.hold_size]
	for key: String in ["normal", "hover", "pressed", "focus"]:
		_garage_button.add_theme_stylebox_override(key, UIKit.primary() if over else UIKit.secondary())
	for key: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		_garage_button.add_theme_color_override(key, UIKit.BG if over else UIKit.TEXT)
	for child: Node in _warning.get_children():
		child.queue_free()
	_warning.visible = over
	if over:
		_warning.add_child(_label("HOLD OVERFULL (%d / %d): fit or scrap %d in the GARAGE before moving on" % [
			state.cargo.size(), state.hold_size, state.cargo.size() - state.hold_size], UIKit.SIZE_BODY, UIKit.TEXT))
	if _hover >= 0 and not RunSim.destinations(state).has(_hover) and _hover != state.current:
		_hover = -1
	_yard.refresh(state, RunSim.destinations(state), _hover)
	_build_site_labels()
	_refresh_crew()
	_show_preview()
	_show_overlay()


## Under every site: its name; for the ones you can reach, the direction and any cost.
func _build_site_labels() -> void:
	for child: Node in _labels.get_children():
		child.queue_free()
	_site_labels.clear()
	var state: RunState = Run.state
	var targets: Array[int] = RunSim.destinations(state)
	for site: Dictionary in state.sites:
		var id: int = int(site["id"])
		var known: bool = RunSim.revealed(state, id)
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.custom_minimum_size = Vector2(170, 0)
		box.add_theme_constant_override("separation", 0)
		var name: String = String(SITE_NAMES.get(String(site["type"]), "?")) if known else ""
		if bool(site["visited"]) and id != state.current and String(site["type"]) != "start":
			name += " · DONE"
		var reachable: bool = targets.has(id)
		box.add_child(_centred(name, UIKit.SIZE_LABEL, UIKit.TEXT if reachable or id == state.current else UIKit.TEXT_FAINT))
		if id == state.current:
			box.add_child(_centred("YOU ARE HERE", UIKit.SIZE_MICRO, UIKit.AMBER))
		elif reachable:
			box.add_child(_centred(_direction(id), UIKit.SIZE_MICRO, UIKit.BLUE.lightened(0.35)))
			var cost: String = _cost_tag()
			if not cost.is_empty():
				box.add_child(_centred(cost, UIKit.SIZE_MICRO, RECLAIMER_RED))
		_labels.add_child(box)
		_site_labels[id] = box


func _centred(text: String, font_size: int, colour: Color) -> Label:
	var label := _label(text, font_size, colour, UIKit.font_strong())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	return label


func _direction(to: int) -> String:
	var here: int = int(Run.state.site(Run.state.current)["col"])
	var there: int = int(Run.state.site(to)["col"])
	return "FORWARD" if there > here else ("SIDEWAYS" if there == here else "BACK")


## What any move from here costs, short enough to sit under a site.
func _cost_tag() -> String:
	var bits: PackedStringArray = []
	var front: Dictionary = Run.setup.rules["front"]
	if Run.state.consumed(Run.state.current):
		bits.append("-%d HP EACH" % int(front["damage"]))
	if (Run.state.moves + 1) % maxi(1, int(front["every"])) == 0:
		bits.append("RECLAIMER ADVANCES")
	return " · ".join(bits)


## The hover card: what the site is, in the world's words, and what going there costs.
func _show_preview() -> void:
	for child: Node in _preview.get_children():
		child.queue_free()
	var state: RunState = Run.state
	_preview.visible = _hover >= 0 and _overlay == null
	if not _preview.visible:
		return
	var site: Dictionary = state.site(_hover)
	var known: bool = RunSim.revealed(state, _hover)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UIKit.SPACE_XS)
	_preview.add_child(box)
	var reachable: bool = RunSim.destinations(state).has(_hover)
	var head: String = String(SITE_NAMES.get(String(site["type"]), "?")) if known else "NOT SCOUTED"
	if reachable:
		head = "%s  ·  %s" % [_direction(_hover), head]
	box.add_child(_label(head, UIKit.SIZE_HEADING, UIKit.AMBER if reachable else UIKit.TEXT, UIKit.font_strong()))
	var text: String = String((Run.db.story.get("sites", {}) as Dictionary).get(String(site["type"]), "")) if known \
		else "Nobody has looked yet. You find out when you get there."
	if bool(site["visited"]) and _hover != state.current:
		text = "Already cleared. Nothing happens there now."
	box.add_child(_wrap(text, UIKit.SIZE_BODY, UIKit.TEXT, 340))
	if reachable:
		for line: String in _move_costs(_hover):
			box.add_child(_wrap(line, UIKit.SIZE_LABEL, RECLAIMER_RED, 340))
		box.add_child(_label("CLICK TO GO", UIKit.SIZE_LABEL, UIKit.BLUE.lightened(0.35), UIKit.font_strong()))
	elif _hover == state.current:
		box.add_child(_label("YOU ARE HERE", UIKit.SIZE_LABEL, UIKit.AMBER, UIKit.font_strong()))
	else:
		box.add_child(_label("No road from here.", UIKit.SIZE_LABEL, UIKit.TEXT_FAINT))


func _move_costs(to: int) -> PackedStringArray:
	var state: RunState = Run.state
	var front: Dictionary = Run.setup.rules["front"]
	var every: int = maxi(1, int(front["every"]))
	var out: PackedStringArray = []
	if state.consumed(state.current):
		out.append("Leaving reclaimed ground: every machine loses %d HP." % int(front["damage"]))
	if (state.moves + 1) % every == 0:
		var zone: int = state.front_col + 2
		out.append("This move lets the Reclaimer take %s." % ("the camp" if zone == 1 else "ZONE %d" % zone))
		if int(state.site(to)["col"]) <= state.front_col + 1:
			out.append("You will be standing in its ground: the next move out costs %d HP each." % int(front["damage"]))
	return out


# --- Site panels --------------------------------------------------------------

func _show_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	var state: RunState = Run.state
	if state.outcome != RunState.ONGOING:
		_run_over()
		return
	if not Run.briefed:
		_briefing()
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
	shade.color = Color(0, 0, 0, 0.62)
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
	_preview.visible = false
	return box


func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.SPACE_MD)
	parent.add_child(row)
	return row


## The story, once, at the start of a run.
func _briefing() -> void:
	var brief: Dictionary = Run.db.story.get("briefing", {})
	var box := _modal(String(brief.get("title", "THE KEY")), "", 1000)
	for line: Variant in (brief.get("lines", []) as Array):
		box.add_child(_wrap(String(line), UIKit.SIZE_HEADING, UIKit.TEXT, 900))
	var go := _button(String(brief.get("go", "ROLL OUT")), UIKit.primary(), UIKit.BG, Vector2(280, 64))
	go.pressed.connect(func() -> void:
		Run.briefed = true
		_refresh())
	_row(box).add_child(go)


func _fight_panel() -> void:
	var state: RunState = Run.state
	var kind: String = String(state.pending["site_type"])
	var fight: Dictionary = state.pending["fight"]
	var titles: Dictionary = {"skirmish": "FIGHT", "elite": "ELITE FIGHT", "boss": String(_act().get("gate", "THE GATE"))}
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
	var flavour: String = String((Run.db.story.get("sites", {}) as Dictionary).get(kind, ""))
	var box := _modal(String(titles.get(kind, "FIGHT")),
		"%s\n\n%s\n\n%d enemies: %s.\nDamage your machines take here stays with them after the fight." % [
			flavour, String(goals.get(String(objective.get("type", "rout")), "")), enemies.size(), ", ".join(enemies)], 960)
	if Run.fight_actions.size() > 0:
		box.add_child(_label("This fight is in progress. It resumes where you left it.", UIKit.SIZE_BODY, UIKit.GOLD))
	var go := _button("ENTER FIGHT" if Run.fight_actions.is_empty() else "RESUME FIGHT", UIKit.primary(), UIKit.BG, Vector2(300, 64))
	go.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/combat.tscn"))
	_row(box).add_child(go)


func _pick_panel() -> void:
	var state: RunState = Run.state
	var scrapyard: bool = String(state.pending["kind"]) == "scrapyard"
	var note: String = ("Take one part into the hold, or strip the yard for scrap." if scrapyard else "Take one part off the wrecks.")
	note += "  Hold: %d / %d." % [state.cargo.size(), state.hold_size]
	if state.cargo.size() >= state.hold_size:
		note += "  It is full: you can still take a part, then fit or scrap something in the GARAGE before moving on."
	var box := _modal("SCRAPYARD" if scrapyard else "SALVAGE", note, 1240)
	var row := _row(box)
	var options: Array = state.pending["options"]
	for i: int in options.size():
		var card: Button = PartCard.build(Run.db, String(options[i]), Vector2(380, 236), state.crew)
		card.pressed.connect(_pick.bind(i))
		row.add_child(card)
	var skip := _button(("TAKE %d SCRAP INSTEAD" % int(state.pending["scrap"])) if scrapyard else "LEAVE IT",
		UIKit.secondary(), UIKit.TEXT, Vector2(320, 60))
	skip.pressed.connect(_pick.bind(-1))
	_row(box).add_child(skip)


func _workshop_panel() -> void:
	var state: RunState = Run.state
	var shop: Dictionary = Run.setup.rules.get("workshop", {})
	var box := _modal("WORKSHOP", String((Run.db.story.get("sites", {}) as Dictionary).get("workshop", "")) + "  You have %d scrap." % state.scrap, 960)
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
	var garage := _button("GARAGE", UIKit.secondary(), UIKit.TEXT, Vector2(180, 60))
	garage.pressed.connect(_open_garage.bind(0))
	row.add_child(garage)
	var leave := _button("MOVE ON", UIKit.primary(), UIKit.BG, Vector2(240, 60))
	leave.pressed.connect(func() -> void: _apply([RunSim.LEAVE]))
	row.add_child(leave)


func _offer(text: String, cost: int, scrap: int, action: Array) -> Control:
	if scrap < cost:
		return _label("%s  ·  %d SCRAP (you have %d)" % [text, cost, scrap], UIKit.SIZE_BODY, UIKit.TEXT_FAINT)
	var button := _button("%s  ·  %d SCRAP" % [text, cost], UIKit.choice(), UIKit.TEXT, Vector2(700, 60))
	button.pressed.connect(func() -> void: _apply(action))
	return button


func _run_over() -> void:
	var state: RunState = Run.state
	var won: bool = state.outcome == RunState.WON
	var endings: Dictionary = Run.db.story.get("endings", {})
	var ending: String = String(endings.get("won", "")) if won else (String(endings.get("gate_held", ""))
		if state.end_reason.begins_with("The gate held") else String(endings.get("wrecked", "")))
	var box := _modal("ACT 1 CLEARED" if won else "RUN OVER",
		"%s\n\n%d fights won  ·  %d moves  ·  %d scrap" % [ending if not ending.is_empty() else state.end_reason,
			state.fights_won, state.moves, state.scrap], 900)
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
		get_tree().reload_current_scene())
	row.add_child(again)


# --- Actions ------------------------------------------------------------------

func _pick(index: int) -> void:
	_apply([RunSim.PICK, index])


func _open_garage(crew_index: int = 0) -> void:
	if _garage != null or not RunSim.can_refit(Run.state):
		return
	_garage = GaragePanel.new()
	if "selected" in _garage:
		_garage.set("selected", crew_index)
	add_child(_garage)
	_preview.visible = false
	_garage.closed.connect(func() -> void:
		_garage.queue_free()
		_garage = null
		_refresh())


func _apply(action: Array) -> void:
	if Run.apply(action):
		Audio.play("ui_confirm", -12.0)
		if int(action[0]) == RunSim.TRAVEL:
			_hover = -1
	else:
		Audio.play("ui_deny", -10.0)
	_refresh()


# --- Pieces -------------------------------------------------------------------

func _wrap(text: String, font_size: int, colour: Color, width: float) -> Label:
	var label := _label(text, font_size, colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	return label


func _label(text: String, font_size: int, colour: Color, face: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	if face != null:
		label.add_theme_font_override("font", face)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, style: StyleBoxFlat, ink: Color, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", UIKit.font_strong())
	button.add_theme_font_size_override("font_size", UIKit.SIZE_HEADING)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, ink)
	for key: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(key, style)
	return button
