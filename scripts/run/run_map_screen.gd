extends Control

## The region map: a 3D yard (`YardView`) under a thin layer of interface.
##
## Play-tests 3 and 4 rebuilt it twice. Now:
##   - the yard is a place: landmarks, roads, fog over everything not yet scouted, and the
##     Reclaimer as a wall you watch advance, its ghost standing where it will be next;
##   - the crew stands on the map and walks the road when it travels; the camera follows it
##     (drag, keys and the wheel to look around; C to come back);
##   - ONE click travels. Hovering (PC) shows what a site is and what the move costs; the
##     direction and any cost are also written on the site itself, for touch;
##   - how the Reclaimer moves is a GAUGE, not a sentence: a pip per move, the last one
##     pulsing when your next move brings it;
##   - a dock of crew portraits (the real machines, levels and all) opens the garage;
##   - the story: a briefing on a new run, the act and mission on screen, site text and
##     endings in the world's voice (`data/run/story.json`).
##
## Reads `Run.state`; changes it only through `Run.apply`.

const GaragePanel := preload("res://scripts/run/garage_panel.gd")
const AssemblyPanel := preload("res://scripts/run/assembly_panel.gd")
const TunePanel := preload("res://scripts/run/tune_panel.gd")

const SITE_NAMES: Dictionary = {"start": "CAMP", "skirmish": "FIGHT", "elite": "ELITE", "warlord": "WARLORD",
	"refinery": "REFINERY", "auction": "AUCTION", "arena": "ARENA",
	"scrapyard": "SCRAPYARD", "workshop": "WORKSHOP", "boss": "THE GATE",
	"trader": "TRADER", "tower": "WATCHTOWER", "signal": "SIGNAL"}
const RECLAIMER_RED := Color("ff5a3d")

var _yard: YardView
var _labels: Control
var _site_labels: Dictionary = {}     # id -> Control
var _preview: PanelContainer
var _gauge_pips: HBoxContainer
var _ground_chip: PanelContainer
var _scrap_label: Label
var _garage_button: Button
var _warning: PanelContainer
var _dock: VBoxContainer
var _portraits: Array[MachinePortrait] = []
var _overlay: Control
var _garage: Control
## The workshop's TUNE bench (011), open over the workshop panel.
var _tuner: Control
var _hover: int = -1
## Left-button press on the map: a click if it ends where it began, a pan if it moved.
var _press_at := Vector2(-1, -1)
var _panning: bool = false
var _drag_pan: bool = false
## True while the crew walks a road: the map takes no input until they arrive.
var _busy: bool = false


func _ready() -> void:
	Audio.ambience(true)
	UIKit.apply(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not Run.active and not Run.continue_run():
		Run.new_run()
	_yard = YardView.new()
	add_child(_yard)
	_yard.build(Run.state, int((Run.setup.rules.get("region", {}) as Dictionary).get("columns", 9)),
		int((Run.setup.rules.get("front", {}) as Dictionary).get("every", 2)), Run.db)
	# Every part model starts loading now, so the garage never waits for one.
	ConstructView.warm(Run.db.parts.keys())
	_labels = Control.new()
	_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_labels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_labels)
	_build_top_bar()
	_build_crew_dock()
	var hint := UIKit.on_page(_label("Click a site to go  ·  drag to look around  ·  wheel to zoom  ·  C to come back",
		UIKit.SIZE_LABEL, UIKit.PAGE_TEXT, UIKit.font_strong()), 5)
	hint.position = Vector2(760, 1080 - 44)
	add_child(hint)
	_preview = PanelContainer.new()
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.add_theme_stylebox_override("panel", UIKit.card(UIKit.SURFACE))
	_preview.custom_minimum_size = Vector2(380, 0)
	_preview.visible = false
	add_child(_preview)
	_refresh()


# --- Input: hover previews, one click travels ---------------------------------

func _gui_input(event: InputEvent) -> void:
	if _overlay != null or _garage != null or _busy:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_LEFT:
				if button.pressed:
					_press_at = button.position
					_panning = false
				else:
					if not _panning and _press_at.x >= 0.0:
						var id: int = _yard.pick(button.position)
						if id >= 0:
							_choose(id)
					_press_at = Vector2(-1, -1)
					_panning = false
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_drag_pan = button.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if button.pressed:
					_yard.zoom_by(-2.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					_yard.zoom_by(2.0)
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var left_held: bool = (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
		if left_held and _press_at.x >= 0.0 and motion.position.distance_to(_press_at) > 10.0:
			_panning = true
		if _panning or _drag_pan:
			_yard.pan(motion.relative)
			return
		var over: int = _yard.pick(motion.position)
		if over != _hover:
			_hover = over
			_yard.refresh(Run.state, RunSim.destinations(Run.state), _hover)
			_show_preview()
	elif event is InputEventMagnifyGesture:
		_yard.zoom_by((1.0 - (event as InputEventMagnifyGesture).factor) * 20.0)
	elif event is InputEventPanGesture:
		_yard.pan(-(event as InputEventPanGesture).delta * 8.0)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_C:
		_yard.recentre()


## One click (or tap): travel there if the road allows. The crew walks the road first;
## whatever waits at the site opens when they arrive.
func _choose(id: int) -> void:
	if _busy:
		return
	if not RunSim.destinations(Run.state).has(id):
		if id != Run.state.current:
			Audio.play("ui_deny", -14.0)
		return
	var from: int = Run.state.current
	if not Run.apply([RunSim.TRAVEL, id]):
		Audio.play("ui_deny", -10.0)
		return
	Audio.play("ui_confirm", -12.0)
	_busy = true
	_hover = -1
	_preview.visible = false
	for child: Node in _labels.get_children():
		(child as CanvasItem).visible = false
	Audio.play("travel", -10.0)
	await _yard.travel(from, id)
	_busy = false
	_refresh()


func _process(_delta: float) -> void:
	# The camera moves now: keep every label on its site, and off the screen's furniture.
	for id: int in _site_labels:
		var label: Control = _site_labels[id]
		var at: Vector2 = _yard.label_pos(id)
		label.position = at + Vector2(-label.size.x * 0.5, 2)
		label.visible = not _busy and at.y > 120.0 and at.y < size.y - 60.0 and at.x > 360.0 and at.x < size.x + 40.0
	if not _busy and _overlay == null and _garage == null:
		var keys := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if keys != Vector2.ZERO:
			_yard.pan(-keys * 14.0)
	if _preview.visible and _hover >= 0:
		var at: Vector2 = _yard.screen_pos(_hover, 1.0) + Vector2(70, -80)
		at.x = minf(at.x, size.x - _preview.size.x - 20)
		at.y = clampf(at.y, 130, size.y - _preview.size.y - 170)
		_preview.position = at


# --- Top bar ------------------------------------------------------------------

func _build_top_bar() -> void:
	var shade := ColorRect.new()
	shade.color = Color(UIKit.BG, 0.92)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.position = Vector2.ZERO
	shade.size = Vector2(1920, 118)
	add_child(shade)
	var rule := ColorRect.new()
	rule.color = UIKit.HAIRLINE
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.position = Vector2(0, 118)
	rule.size = Vector2(1920, 4)
	add_child(rule)
	var act: Dictionary = _act()
	# Ink & Rust (016): the act's name lettered on the page, paper on an ink edge.
	var title := UIKit.on_page(_label("ACT %d  ·  %s" % [Run.state.act, String(act.get("name", "THE CRANE YARDS"))], 44, UIKit.PAGE_TEXT, UIKit.font_display()), 10)
	title.position = Vector2(40, 12)
	add_child(title)
	var mission := UIKit.on_page(_label(String(act.get("mission", "")), UIKit.SIZE_BODY, UIKit.PAGE_TEXT, UIKit.font_strong()), 5)
	mission.position = Vector2(42, 76)
	add_child(mission)

	# The Reclaimer as a gauge (play-test 4: "should not come from text"): its name, and one
	# pip per move of its step. Pips fill as you move; the last pulses when your next move
	# brings it forward -- and on the map its ghost pulses on the line it will take.
	var gauge := PanelContainer.new()
	var style := UIKit.card(UIKit.SURFACE, 0, UIKit.SPACE_LG, UIKit.SPACE_SM)
	style.border_color = Ink.DANGER
	style.set_border_width_all(4)
	gauge.add_theme_stylebox_override("panel", style)
	gauge.position = Vector2(760, 20)
	gauge.tooltip_text = "The Reclaimer takes one zone every %d moves. Each lit pip is one of your moves; when the last lights, it advances to its red ghost line." \
		% int((Run.setup.rules.get("front", {}) as Dictionary).get("every", 2))
	add_child(gauge)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.SPACE_MD)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge.add_child(row)
	row.add_child(_label(String((Run.db.story.get("reclaimer", {}) as Dictionary).get("name", "THE RECLAIMER")), 28,
		UIKit.RED, UIKit.font_display()))
	_gauge_pips = HBoxContainer.new()
	_gauge_pips.add_theme_constant_override("separation", UIKit.SPACE_SM)
	_gauge_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge_pips.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_gauge_pips)
	_ground_chip = PanelContainer.new()
	_ground_chip.add_theme_stylebox_override("panel", UIKit.card(Ink.DANGER, 0, UIKit.SPACE_MD, UIKit.SPACE_XS))
	_ground_chip.position = Vector2(760, 92)
	_ground_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ground_chip.add_child(_label("IN RECLAIMED GROUND  ·  -%d HP EACH PER MOVE" % int((Run.setup.rules["front"] as Dictionary)["damage"]),
		UIKit.SIZE_LABEL, UIKit.TEXT, UIKit.font_comic()))
	add_child(_ground_chip)

	var right := HBoxContainer.new()
	right.position = Vector2(1246, 28)
	right.add_theme_constant_override("separation", UIKit.SPACE_LG)
	add_child(right)
	_scrap_label = UIKit.on_page(_label("", 30, UIKit.PAGE_TEXT, UIKit.font_comic()), 8)
	_scrap_label.custom_minimum_size = Vector2(170, 0)
	right.add_child(_scrap_label)
	_garage_button = _button("GARAGE", UIKit.secondary(), UIKit.TEXT, Vector2(200, 56))
	_garage_button.pressed.connect(_open_garage.bind(0))
	right.add_child(_garage_button)
	# Every word the game uses (012).
	var words := _button("?", UIKit.secondary(), UIKit.TEXT, Vector2(56, 56))
	words.name = "glossary_button"
	words.tooltip_text = "Glossary"
	words.pressed.connect(func() -> void: Glossary.open(self, Run.db.glossary))
	right.add_child(words)
	var quit := _button("TITLE", UIKit.secondary(), UIKit.TEXT, Vector2(130, 56))
	quit.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))
	right.add_child(quit)

	_warning = PanelContainer.new()
	_warning.add_theme_stylebox_override("panel", UIKit.card(Ink.DANGER, 0, UIKit.SPACE_LG, UIKit.SPACE_SM))
	_warning.position = Vector2(760, 140)
	_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_warning)


## A site's line in the world's voice. The gate is each act's own (025: the story's `acts[i].boss`).
func _site_text(kind: String) -> String:
	if kind == "boss" and _act().has("boss"):
		return String(_act()["boss"])
	return String((Run.db.story.get("sites", {}) as Dictionary).get(kind, ""))


func _act() -> Dictionary:
	var acts: Array = Run.db.story.get("acts", [])
	return acts[clampi(Run.state.act - 1, 0, acts.size() - 1)] if not acts.is_empty() else {}


func _refresh_gauge() -> void:
	for child: Node in _gauge_pips.get_children():
		child.queue_free()
	var every: int = maxi(1, int((Run.setup.rules["front"] as Dictionary)["every"]))
	var done: int = Run.state.moves % every
	for i: int in every:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(26, 26)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lit: bool = i < done
		var next: bool = i == done and done == every - 1
		var style := UIKit.plain(Ink.DANGER if lit else UIKit.SURFACE, 0)
		style.border_color = UIKit.RED if next else UIKit.HAIRLINE
		style.set_border_width_all(4 if next else 3)
		pip.add_theme_stylebox_override("panel", style)
		_gauge_pips.add_child(pip)
		if next:
			# The one that fills on your next move, and brings it forward.
			var pulse := pip.create_tween().set_loops()
			pulse.tween_property(pip, "modulate", Color(1.6, 0.7, 0.6), 0.4)
			pulse.tween_property(pip, "modulate", Color(1, 1, 1), 0.4)
	_ground_chip.visible = Run.state.consumed(Run.state.current)


# --- Crew dock ----------------------------------------------------------------

func _build_crew_dock() -> void:
	_dock = VBoxContainer.new()
	_dock.position = Vector2(24, 140)
	_dock.add_theme_constant_override("separation", UIKit.SPACE_SM)
	add_child(_dock)


func _refresh_crew() -> void:
	# The portraits outlive the cards (each is a small studio worth keeping): lift them out
	# before the old cards go, then deal fresh cards around them.
	for portrait: MachinePortrait in _portraits:
		if portrait.get_parent() != null:
			portrait.get_parent().remove_child(portrait)
	for child: Node in _dock.get_children():
		_dock.remove_child(child)
		child.queue_free()
	for i: int in Run.state.crew.size():
		_dock.add_child(_crew_card(i))


## One machine in the dock: its portrait (the real model), name, level marks and HP as
## pips. Opens the garage on that machine.
func _crew_card(i: int) -> Control:
	var member: Dictionary = Run.state.crew[i]
	var alive: bool = bool(member["alive"])
	var card := Button.new()
	card.custom_minimum_size = Vector2(340, 124)
	card.focus_mode = Control.FOCUS_NONE
	var style := UIKit.card(UIKit.SURFACE, 0, UIKit.SPACE_SM, UIKit.SPACE_SM)
	for key: String in ["normal", "focus"]:
		card.add_theme_stylebox_override(key, style)
	card.add_theme_stylebox_override("pressed", UIKit.pressed(style))
	var hover: StyleBoxFlat = style.duplicate()
	hover.border_color = UIKit.AMBER_DEEP
	hover.set_border_width_all(4)
	card.add_theme_stylebox_override("hover", hover)
	card.tooltip_text = "Open %s in the garage" % String(member["name"])
	card.pressed.connect(_open_garage.bind(i))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UIKit.SPACE_SM)
	card.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, UIKit.SPACE_XS)
	while _portraits.size() <= i:
		_portraits.append(MachinePortrait.new(Vector2i(112, 112), "portrait", true))
	var portrait: MachinePortrait = _portraits[i]
	if portrait.get_parent() != null:
		portrait.get_parent().remove_child(portrait)
	row.add_child(portrait)
	portrait.show_machine(member["parts"], int(member.get("level", 0)), alive)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", 2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(_label(String(member["name"]).to_upper(), 22, UIKit.TEXT if alive else UIKit.RED, UIKit.font_comic()))
	text.add_child(_level_marks(int(member.get("level", 0))))
	if alive:
		var full: int = RunSim.max_hp(Run.setup, member)
		text.add_child(_hp_pips(int(member["hp"]), full))
		text.add_child(_label("%d / %d HP" % [int(member["hp"]), full], UIKit.SIZE_LABEL, UIKit.TEXT_DIM, UIKit.font_numbers()))
	else:
		text.add_child(_label("WRECK · rebuild at a workshop", UIKit.SIZE_LABEL, UIKit.RED))
	return card


## Three marks, lit up to the machine's level.
func _level_marks(level: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var steps: int = maxi(3, ((Run.setup.rules.get("levels", {}) as Dictionary).get("costs", []) as Array).size())
	# Ink (016): a level is a filled ink chevron-box; one still to earn is an empty ink outline.
	for n: int in steps:
		var mark := Panel.new()
		mark.custom_minimum_size = Vector2(16, 10)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := UIKit.plain(Ink.ACTION if n < level else UIKit.SURFACE, 0)
		box.border_color = UIKit.HAIRLINE
		box.set_border_width_all(2)
		box.skew = Vector2(0.4, 0.0)
		mark.add_theme_stylebox_override("panel", box)
		row.add_child(mark)
	var caption := _label("LEVEL %d" % level if level > 0 else "LEVEL 0", UIKit.SIZE_MICRO, UIKit.TEXT_DIM, UIKit.font_comic())
	row.add_child(caption)
	return row


## HP as a row of pips, one per point, so a glance counts it.
func _hp_pips(hp: int, full: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var low: bool = hp * 3 <= full
	var width: float = clampf(190.0 / float(maxi(1, full)) - 2.0, 5.0, 14.0)
	for n: int in full:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(width, 12)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The fight's pips: your blue in an ink box, red when low.
		var colour: Color = (Ink.DANGER if low else Ink.YOURS) if n < hp else UIKit.SURFACE
		var box := UIKit.plain(colour, 0)
		box.border_color = UIKit.HAIRLINE
		box.set_border_width_all(1)
		pip.add_theme_stylebox_override("panel", box)
		row.add_child(pip)
	return row


# --- Refresh ------------------------------------------------------------------

func _refresh() -> void:
	var state: RunState = Run.state
	_refresh_gauge()
	_scrap_label.text = "SCRAP %d" % state.scrap
	var over: bool = state.overfull()
	_garage_button.text = "GARAGE  %d/%d" % [state.cargo.size(), state.hold_size]
	var garage_style: StyleBoxFlat = UIKit.primary() if over else UIKit.secondary()
	for key: String in ["normal", "hover", "focus"]:
		_garage_button.add_theme_stylebox_override(key, garage_style)
	_garage_button.add_theme_stylebox_override("pressed", UIKit.pressed(garage_style))
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
	_yard.set_crew(state.crew)
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
		if not known:
			continue   # under fog: nothing to label
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.custom_minimum_size = Vector2(170, 0)
		box.add_theme_constant_override("separation", 0)
		var name: String = String(SITE_NAMES.get(String(site["type"]), "?"))
		if bool(site["visited"]) and id != state.current and String(site["type"]) != "start":
			name += " · DONE"
		var reachable: bool = targets.has(id)
		box.add_child(_centred(name, 20, UIKit.PAGE_TEXT if reachable or id == state.current else Color("9a9384")))
		if id == state.current:
			box.add_child(_centred("YOU ARE HERE", UIKit.SIZE_LABEL, Ink.ACTION))
		elif reachable:
			box.add_child(_centred(_direction(id), UIKit.SIZE_LABEL, Ink.YOURS))
			var cost: String = _cost_tag()
			if not cost.is_empty():
				box.add_child(_centred(cost, UIKit.SIZE_LABEL, Ink.DANGER))
		_labels.add_child(box)
		_site_labels[id] = box


func _centred(text: String, font_size: int, colour: Color) -> Label:
	# Lettered on the yard (016): comic face, a heavy ink edge, the colour its meaning's.
	var label := _label(text, font_size, colour, UIKit.font_comic())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_outline_color", UIKit.HAIRLINE)
	label.add_theme_constant_override("outline_size", 9)
	return label


func _direction(to: int) -> String:
	var here: int = int(Run.state.site(Run.state.current)["col"])
	var there: int = int(Run.state.site(to)["col"])
	return "FORWARD" if there > here else ("SIDEWAYS" if there == here else "BACK")


## What any move from here costs, short enough to sit under a site. (Whether it brings the
## Reclaimer forward is shown by the gauge and its ghost, not written.)
func _cost_tag() -> String:
	var front: Dictionary = Run.setup.rules["front"]
	if Run.state.consumed(Run.state.current):
		return "-%d HP EACH" % int(front["damage"])
	return ""


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
	# A site you can go to carries your action's amber, as a band down the card: amber TEXT
	# does not read on paper.
	var card := InkBox.new(UIKit.SURFACE, UIKit.SPACE_LG + (10 if reachable else 0), UIKit.SPACE_MD)
	if reachable:
		card.band_width = 10.0
		card.band = Ink.ACTION
	_preview.add_theme_stylebox_override("panel", card)
	var head: String = String(SITE_NAMES.get(String(site["type"]), "?")) if known else "NOT SCOUTED"
	if reachable:
		head = "%s  ·  %s" % [_direction(_hover), head]
	box.add_child(_label(head, 24, UIKit.TEXT, UIKit.font_comic()))
	var text: String = _site_text(String(site["type"])) if known \
		else "Nobody has looked yet. You find out when you get there."
	if bool(site["visited"]) and _hover != state.current:
		text = "Already cleared. Nothing happens there now."
	box.add_child(_wrap(text, UIKit.SIZE_BODY, UIKit.TEXT, 340))
	if reachable:
		# 014 (review point R5-3): what the move gives, what it risks, and what it gives up.
		var move: Dictionary = RunSim.move_preview(state, Run.setup, _hover)
		if known and not bool(site["visited"]):
			box.add_child(_wrap(_gives(String(site["type"])), UIKit.SIZE_LABEL, UIKit.GREEN, 340))
			if int(move["enemies"]) > 0:
				box.add_child(_wrap("%d enemies%s" % [int(move["enemies"]), ", the Reclaimer's drones join at round 3" if bool(move["reach"]) else ""],
					UIKit.SIZE_LABEL, UIKit.RED, 340))
		for line: String in _move_costs(_hover):
			box.add_child(_wrap(line, UIKit.SIZE_LABEL, UIKit.RED, 340))
		if bool(move["advances"]):
			var lost: Array = move["lost"]
			var names: PackedStringArray = []
			for id: Variant in lost:
				names.append(String(SITE_NAMES.get(String(state.site(int(id))["type"]), "?")) if RunSim.revealed(state, int(id)) else "UNSCOUTED")
			box.add_child(_wrap("The Reclaimer moves as you go and takes zone %d%s." % [int(move["front_after"]) + 1,
				(": %d unvisited site%s lost there (%s)" % [lost.size(), "" if lost.size() == 1 else "s", ", ".join(names)]) if not lost.is_empty() else ""],
				UIKit.SIZE_LABEL, UIKit.RED, 340))
		box.add_child(_label("CLICK TO GO", UIKit.SIZE_HEADING, UIKit.BLUE, UIKit.font_comic()))
	elif _hover == state.current:
		box.add_child(_label("YOU ARE HERE", UIKit.SIZE_HEADING, UIKit.TEXT, UIKit.font_comic()))
	else:
		box.add_child(_label("No road from here.", UIKit.SIZE_LABEL, UIKit.TEXT_FAINT))


## What a site gives, in a line, from the run's own numbers.
func _gives(kind: String) -> String:
	var rewards: Dictionary = Run.setup.rules.get("rewards", {})
	match kind:
		"skirmish":
			return "A fight: +%d scrap, then 1 of 3 parts or %d scrap." % [int(rewards.get("skirmish_scrap", 10)), int(rewards.get("salvage_scrap", 8))]
		"arena":
			return "A pit fight: one more enemy than an elite, +%d scrap and an uncommon or better part." % int(rewards.get("arena_scrap", 35))
		"refinery":
			return "Turn one part in the hold into a random part of the next rarity, for scrap."
		"auction":
			return "Buy a crate blind: a better part, maybe a legendary."
		"warlord":
			return "The act's warlord, with its own rule: +%d scrap and a hoard with a LEGENDARY part." % int(rewards.get("warlord_scrap", 30))
		"elite":
			return "A hard fight: +%d scrap and an uncommon or better part, already tuned." % int(rewards.get("elite_scrap", 20))
		"scrapyard":
			return "No fight: 1 of 3 parts, or %d scrap." % int(rewards.get("scrapyard_scrap", 15))
		"workshop":
			return "Repairs, rebuilds, room in the hold and tuning, for scrap."
		"trader":
			return "Three parts for sale; your spares sell for twice their scrap."
		"tower":
			return "Scouts every site within two zones."
		"signal":
			return "An event with a choice; each option says what it costs."
		"boss":
			return "The Sorting Gate: the act's last fight."
	return ""


func _move_costs(to: int) -> PackedStringArray:
	var state: RunState = Run.state
	var front: Dictionary = Run.setup.rules["front"]
	var every: int = maxi(1, int(front["every"]))
	var out: PackedStringArray = []
	if state.consumed(state.current):
		out.append("Leaving reclaimed ground: every machine loses %d HP." % int(front["damage"]))
	if (state.moves + 1) % every == 0 and int(state.site(to)["col"]) <= state.front_col + 1:
		out.append("The Reclaimer will take that ground as you arrive: the next move out costs %d HP each." % int(front["damage"]))
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
	if RunSim.can_assemble(state) and not Run.bay_seen:
		_assembly()
		return
	match String(state.pending.get("kind", "")):
		"fight":
			_fight_panel()
		"reward", "scrapyard":
			_pick_panel()
			Hints.show_once(_overlay, "salvage", Run.db, Vector2(40, 140))
		"workshop":
			_workshop_panel()
			Hints.show_once(_overlay, "workshop", Run.db, Vector2(40, 140))
		"trader":
			_trader_panel()
		"refinery":
			_refinery_panel()
		"auction":
			_auction_panel()
		"tower":
			_tower_panel()
		"signal":
			_signal_panel()
		_:
			# First time on the map with nothing to resolve: say what it is for (012).
			Hints.show_once(self, "map", Run.db, Vector2(420, 150))


func _modal(title: String, subtitle: String, width: float = 1100.0) -> VBoxContainer:
	_overlay = Control.new()
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(UIKit.BG, 0.7)
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
		# Rich text: the game's words in it are glossary links (012).
		box.add_child(Glossary.label(subtitle, UIKit.SIZE_BODY, UIKit.TEXT_DIM, Run.db.glossary, width - 100))
	_preview.visible = false
	return box


func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UIKit.SPACE_MD)
	parent.add_child(row)
	return row


## The assembly bay: the crew built from the bench before the first move.
func _assembly() -> void:
	_overlay = AssemblyPanel.new()
	add_child(_overlay)
	_preview.visible = false
	_overlay.done.connect(func() -> void:
		Run.bay_seen = true
		_refresh())


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
	var titles: Dictionary = {"skirmish": "FIGHT", "elite": "ELITE FIGHT", "boss": String(_act().get("gate", "THE GATE")),
		"warlord": String((state.pending["fight"] as Dictionary).get("name", "THE WARLORD")).to_upper()}
	var enemies: PackedStringArray = []
	for spec: Dictionary in (fight["enemy"] as Array):
		var kind_name: String = String(spec.get("kind", ""))
		enemies.append(String(spec["name"]) + ((" (%s)" % kind_name.to_upper()) if not kind_name.is_empty() else ""))
	var objective: Dictionary = fight.get("objective", {"type": "rout"})
	var goals: Dictionary = {
		"rout": "ROUT: destroy every enemy.",
		"defend": "DEFEND: keep the salvage caches standing for %d rounds (or destroy every enemy). Each cache you save pays out scrap." % int(objective.get("rounds", 0)),
		"salvage": "SALVAGE: collect %d scrap piles before the enemy carries them off (or destroy every enemy)." % int(objective.get("need", 0)),
		"hold": "HOLD: start %d rounds with a machine on the zone and no enemy on it (or destroy every enemy)." % int(objective.get("need", 0)),
		"hack": "HACK: end a move on %d of the terminals (or destroy every enemy)." % int(objective.get("need", 0)),
		"survive": "SURVIVE: waves come in every %d rounds; hold out %d rounds (or destroy every enemy)." % [int(objective.get("every", 2)), int(objective.get("rounds", 6))],
	}
	# 028: the yard's condition, if the fight rolled one.
	var yard: PackedStringArray = []
	for id: Variant in ((fight as Dictionary).get("modifiers", []) as Array):
		var m: Dictionary = (Run.db.combat_rules.get("modifiers", {}) as Dictionary).get(String(id), {})
		yard.append("%s: %s" % [String(m.get("name", id)), String(m.get("text", ""))])
	var flavour: String = _site_text(kind)
	var box := _modal(String(titles.get(kind, "FIGHT")),
		"%s\n\n%s\n\n%d enemies: %s.\nDamage your machines take here stays with them after the fight." % [
			flavour, String(goals.get(String(objective.get("type", "rout")), "")) + ("\n" + "\n".join(yard) if not yard.is_empty() else ""),
			enemies.size(), ", ".join(enemies)], 960)
	if (fight as Dictionary).has("reclaimer"):
		# 013: fighting by the line -- say so before the player walks in.
		box.add_child(_label("THE RECLAIMER IS CLOSE: its drones come in behind you at round %d." % int((fight["reclaimer"] as Dictionary).get("round", 3)),
			UIKit.SIZE_HEADING, UIKit.RED, UIKit.font_comic()))
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
	# 011: every salvage screen has a scrap alternative, so leaving the parts is a choice.
	var skip := _button("TAKE %d SCRAP INSTEAD" % int(state.pending.get("scrap", 0)) if int(state.pending.get("scrap", 0)) > 0
		else "LEAVE IT", UIKit.secondary(), UIKit.TEXT, Vector2(320, 60))
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
	var tunable: Array = _tunable_costs()
	if not tunable.is_empty():
		var cheapest: int = tunable.min()
		var label: String = "TUNE A PART  ·  %s SCRAP" % (str(cheapest) if tunable.max() == cheapest else "%d-%d" % [cheapest, tunable.max()])
		if state.scrap < cheapest:
			box.add_child(_label("%s (you have %d)" % [label, state.scrap], UIKit.SIZE_BODY, UIKit.TEXT_FAINT))
		else:
			var tune := _button(label, UIKit.choice(), UIKit.TEXT, Vector2(700, 60))
			tune.pressed.connect(_open_tuner)
			box.add_child(tune)
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


## What tuning would cost for every part the crew or the hold could still have tuned.
func _tunable_costs() -> Array:
	var out: Array = []
	var ids: Array = Run.state.cargo.duplicate()
	for member: Dictionary in Run.state.crew:
		if bool(member["alive"]):
			ids.append_array(member["parts"])
	for id: Variant in ids:
		if PartTuning.can_tune(Run.db.parts, String(id)):
			out.append(RunSim.tune_cost(Run.setup, String(id)))
	return out


func _open_tuner() -> void:
	if _tuner != null:
		return
	_tuner = TunePanel.new()
	add_child(_tuner)
	_preview.visible = false
	_tuner.done.connect(func() -> void:
		_tuner.queue_free()
		_tuner = null
		_refresh())


## A trader (013): three parts for sale, and an offer for anything in the hold.
func _trader_panel() -> void:
	var state: RunState = Run.state
	var box := _modal("TRADER", "%s  You have %d scrap.  Hold: %d / %d." % [String((Run.db.story.get("sites", {}) as Dictionary).get("trader", "")),
		state.scrap, state.cargo.size(), state.hold_size], 1240)
	var row := _row(box)
	var stock: Array = state.pending.get("stock", [])
	for i: int in stock.size():
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", UIKit.SPACE_XS)
		row.add_child(column)
		var price: int = RunSim.trader_price(state, Run.setup, i)
		var card: Button = PartCard.build(Run.db, String(stock[i]), Vector2(380, 236), state.crew)
		column.add_child(card)
		if price < 0:
			card.modulate = Color(1, 1, 1, 0.35)
			column.add_child(_label("SOLD", UIKit.SIZE_HEADING, UIKit.TEXT_FAINT, UIKit.font_strong()))
		elif state.scrap >= price:
			card.name = "stock_%d" % i
			card.pressed.connect(func() -> void: _apply([RunSim.BUY, i]))
			column.add_child(_label("BUY  ·  %d SCRAP" % price, 22, UIKit.TEXT, UIKit.font_comic()))
		else:
			column.add_child(_label("%d SCRAP  (you have %d)" % [price, state.scrap], UIKit.SIZE_HEADING, UIKit.TEXT_FAINT, UIKit.font_strong()))
	if not state.cargo.is_empty():
		box.add_child(_label("SELL FROM THE HOLD  ·  the trader pays twice what breaking a part down would", UIKit.SIZE_BODY, UIKit.TEXT_DIM, UIKit.font_strong()))
		# Play-test 10: the hold as pictures, so it is clear what is being sold.
		_part_grid(box, state.cargo, Vector2(168, 178), 6, 290.0, func(c: int) -> Array:
			return ["SELL  ·  +%d" % RunSim.trader_offer(Run.setup, String(state.cargo[c])), true, "sell_%d" % c],
			func(c: int) -> void: _apply([RunSim.SELL, c]))
	var leave := _button("MOVE ON", UIKit.primary(), UIKit.BG, Vector2(240, 60))
	leave.pressed.connect(func() -> void: _apply([RunSim.LEAVE]))
	_row(box).add_child(leave)


## The refinery (031): every part in the hold that can go up a rarity, with its price.
func _refinery_panel() -> void:
	var state: RunState = Run.state
	var used: bool = bool(state.pending.get("used", false))
	var box := _modal("REFINERY", "%s  You have %d scrap." % [_site_text("refinery"), state.scrap], 1240)
	if used:
		box.add_child(_label("The furnace is spent for today.", UIKit.SIZE_HEADING, UIKit.TEXT_DIM, UIKit.font_strong()))
	else:
		box.add_child(_label("Pick a part: it becomes a random part of the NEXT rarity, the same slot (a rare becomes a legendary). Once.",
			UIKit.SIZE_BODY, UIKit.TEXT_DIM, UIKit.font_strong()))
		# Play-test 10: the hold as part cards, the price under each -- what goes into the furnace
		# is a picture, not a name in a list.
		var refinable: Array = []
		for c: int in state.cargo.size():
			if RunSim.refine_cost(Run.setup, String(state.cargo[c])) >= 0:
				refinable.append(c)
		_part_grid(box, refinable.map(func(c: int) -> String: return String(state.cargo[c])), Vector2(204, 214), 5, 540.0,
			func(k: int) -> Array:
				var cost: int = RunSim.refine_cost(Run.setup, String(state.cargo[int(refinable[k])]))
				return ["REFINE  ·  %d SCRAP" % cost if state.scrap >= cost else "%d SCRAP (you have %d)" % [cost, state.scrap],
					state.scrap >= cost, "refine_%d" % int(refinable[k])],
			func(k: int) -> void: _apply([RunSim.REFINE, int(refinable[k])]))
		if state.cargo.is_empty():
			box.add_child(_label("The hold is empty.", UIKit.SIZE_BODY, UIKit.TEXT_FAINT))
	var leave := _button("MOVE ON", UIKit.primary(), UIKit.BG, Vector2(240, 60))
	leave.pressed.connect(func() -> void: _apply([RunSim.LEAVE]))
	_row(box).add_child(leave)


## The auction (031): two crates, bought blind.
func _auction_panel() -> void:
	var state: RunState = Run.state
	var used: bool = bool(state.pending.get("used", false))
	var box := _modal("SALVAGE AUCTION", "%s  You have %d scrap." % [_site_text("auction"), state.scrap], 1000)
	var row := _row(box)
	var tiers: Array = (Run.setup.rules.get("auction", {}) as Dictionary).get("tiers", [])
	var names: PackedStringArray = ["A DENTED CRATE", "A SEALED CRATE"]
	var rarity: PackedStringArray = ["", "COMMON", "UNCOMMON", "RARE"]
	for t: int in tiers.size():
		var tier: Dictionary = tiers[t]
		var cost: int = int(tier.get("cost", 0))
		var b := _button("%s  ·  %d SCRAP" % [names[mini(t, names.size() - 1)], cost],
			UIKit.choice() if state.scrap >= cost and not used else UIKit.secondary(), UIKit.TEXT, Vector2(440, 64))
		b.disabled = used or state.scrap < cost
		b.tooltip_text = "%s or better; %d%% chance it is a LEGENDARY" % [rarity[clampi(int(tier.get("min", 2)), 1, 3)], int(tier.get("legend_pct", 0))]
		b.pressed.connect(func() -> void: _apply([RunSim.BID, t]))
		row.add_child(b)
	box.add_child(_label("The dented crate: uncommon or better, %d%% legendary.  The sealed crate: rare or better, %d%% legendary.  One crate a visit." % [
		int((tiers[0] as Dictionary).get("legend_pct", 0)) if tiers.size() > 0 else 0, int((tiers[1] as Dictionary).get("legend_pct", 0)) if tiers.size() > 1 else 0],
		UIKit.SIZE_BODY, UIKit.TEXT_DIM, UIKit.font_strong()))
	if used and not state.cargo.is_empty():
		# Play-test 10: the prize as its card -- what came out of the crate.
		var won := _row(box)
		won.add_child(PartCard.build(Run.db, String(state.cargo[state.cargo.size() - 1]), Vector2(300, 300), state.crew))
		won.add_child(_label("IN THE CRATE", UIKit.SIZE_HEADING, UIKit.GREEN, UIKit.font_comic()))
	var leave := _button("MOVE ON", UIKit.primary(), UIKit.BG, Vector2(240, 60))
	leave.pressed.connect(func() -> void: _apply([RunSim.LEAVE]))
	_row(box).add_child(leave)


## A watchtower (013): what it scouted.
func _tower_panel() -> void:
	var seen: int = int(Run.state.pending.get("scouted", 0))
	var box := _modal("WATCHTOWER", "%s  From the cab you scout %s within two zones." % [
		String((Run.db.story.get("sites", {}) as Dictionary).get("tower", "")),
		("%d more site%s" % [seen, "" if seen == 1 else "s"]) if seen > 0 else "nothing new"], 900)
	var leave := _button("CLIMB DOWN", UIKit.primary(), UIKit.BG, Vector2(260, 60))
	leave.pressed.connect(func() -> void: _apply([RunSim.LEAVE]))
	_row(box).add_child(leave)


## A signal (013): a scene and its choices, every cost stated on the button.
func _signal_panel() -> void:
	var state: RunState = Run.state
	var event: Dictionary = (Run.setup.rules.get("events", {}) as Dictionary).get(String(state.pending.get("event", "")), {})
	var box := _modal(String(event.get("title", "SIGNAL")), String(event.get("text", "")), 1000)
	var options: Array = event.get("options", [])
	for i: int in options.size():
		var option: Dictionary = options[i]
		var text: String = "%s  ·  %s" % [String(option.get("label", "")), String(option.get("text", ""))]
		if RunSim.can_choose(state, Run.setup, i):
			var choice := _button(text, UIKit.choice(), UIKit.TEXT, Vector2(900, 60))
			choice.name = "option_%d" % i
			choice.alignment = HORIZONTAL_ALIGNMENT_LEFT
			choice.pressed.connect(func() -> void: _apply([RunSim.CHOOSE, i]))
			box.add_child(choice)
		else:
			box.add_child(_label("%s  (you have %d scrap)" % [text, state.scrap], UIKit.SIZE_BODY, UIKit.TEXT_FAINT, UIKit.font_strong()))


## Parts as cards in a grid of `columns`, each with a caption under it from `caption(i)`:
## `[text, can_press, node_name]`. Pressing a card that can be pressed calls `press(i)`. Taller
## than `max_height`, the grid scrolls (play-test 10: parts at sites are pictures).
func _part_grid(box: Control, ids: Array, card_size: Vector2, columns: int, max_height: float, caption: Callable, press: Callable) -> void:
	var grid := GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", UIKit.SPACE_SM)
	grid.add_theme_constant_override("v_separation", UIKit.SPACE_SM)
	for i: int in ids.size():
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 2)
		grid.add_child(column)
		var said: Array = caption.call(i)
		var card: Button = PartCard.build(Run.db, String(ids[i]), card_size, Run.state.crew)
		column.add_child(card)
		if bool(said[1]):
			card.name = String(said[2])
			card.pressed.connect(func() -> void: press.call(i))
		else:
			card.modulate = Color(1, 1, 1, 0.55)
		var under := UIKit.fit(_label(String(said[0]), UIKit.SIZE_LABEL, UIKit.TEXT if bool(said[1]) else UIKit.TEXT_FAINT, UIKit.font_comic()),
			card_size.x, 1, 11)
		under.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(under)
	var rows: int = (ids.size() + columns - 1) / columns
	var height: float = float(rows) * (card_size.y + 34.0)
	if height <= max_height:
		box.add_child(grid)
		return
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(float(columns) * (card_size.x + UIKit.SPACE_SM) + 20.0, max_height)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(grid)
	box.add_child(scroll)


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
	Audio.play("win" if won else "lose", -6.0, 0.0)
	# 022: what the run leaves behind. Banked once, however often this screen opens.
	var banked: Dictionary = Run.bank()
	var gains: String = ""
	for entry: Dictionary in (banked.get("new", []) as Array):
		gains += "\nUNLOCKED  ·  %s" % _unlock_name(entry)
	var next: Dictionary = banked.get("next", {})
	if not next.is_empty():
		var p: Array = Meta.progress(Profile.stats(), next)
		gains += "\nNext unlock: %s  (%s: %d / %d)" % [_unlock_name(next), String(next.get("text", "")).to_lower(), int(p[0]), int(p[1])]
	var box := _modal("THE RUN IS WON" if won else "RUN OVER",
		"%s\n\n%d fights won  ·  act %d  ·  %d scrap\n%s" % [ending if not ending.is_empty() else state.end_reason,
			state.fights_won, state.act, state.scrap, gains], 900)
	var row := _row(box)
	# 027: every unlock as a goal, the ones this run earned ringed as new.
	var fresh: Array = (banked.get("new", []) as Array).map(func(e: Dictionary) -> String: return String(e["id"]))
	var goals := _button("UNLOCKS", UIKit.secondary(), UIKit.TEXT, Vector2(200, 64))
	goals.pressed.connect(func() -> void: UnlocksPanel.open(self, Run.db, Profile.unlocked(), Profile.stats(), fresh))
	row.add_child(goals)
	var title := _button("TITLE", UIKit.secondary(), UIKit.TEXT, Vector2(200, 64))
	title.pressed.connect(func() -> void:
		Run.end_run()
		get_tree().change_scene_to_file("res://scenes/main.tscn"))
	row.add_child(title)
	var again := _button("NEW RUN", UIKit.primary(), UIKit.BG, Vector2(260, 64))
	again.pressed.connect(func() -> void:
		Run.end_run()
		Run.new_run_from_profile()
		get_tree().reload_current_scene())
	row.add_child(again)


## What an unlock gives, in words: a part's name, a crew's, a tier's.
func _unlock_name(entry: Dictionary) -> String:
	var meta: Dictionary = Run.db.meta
	match String(entry.get("kind", "")):
		"part":
			return "%s (part)" % String((Run.db.parts.get(entry["what"], {}) as Dictionary).get("name", entry["what"]))
		"crew":
			return "%s (starting crew)" % String(((meta.get("crews", {}) as Dictionary).get(entry["what"], {}) as Dictionary).get("name", ""))
		_:
			return "%s (harder tier)" % String(((meta.get("tiers", []) as Array)[int(entry["what"])] as Dictionary).get("name", ""))


# --- Actions ------------------------------------------------------------------

func _pick(index: int) -> void:
	Audio.play("reward", -8.0)
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
	var act: int = Run.state.act
	if Run.apply(action):
		# 029: a pick from a gate's hoard moves the crew into the next act -- a new region, so
		# the whole yard is built again.
		if Run.state.act != act:
			get_tree().reload_current_scene()
			return
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
	button.add_theme_font_override("font", UIKit.font_comic())
	button.add_theme_font_size_override("font_size", 22)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(key, ink)
	for key: String in ["normal", "hover", "focus"]:
		button.add_theme_stylebox_override(key, style)
	button.add_theme_stylebox_override("pressed", UIKit.pressed(style))
	return button
