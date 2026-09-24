extends Control

## The region map: where the Crawler is, where it can go, what the Reclaimer has eaten, and
## whatever the current site is asking for (a fight, salvage, a workshop).
##
## Reads `Run.state`; changes it only through `Run.apply`. Every panel is rebuilt from the
## state after each action, so nothing on screen can disagree with the run.

const MAP_RECT := Rect2(40, 118, 1250, 800)
const MAP_PAD: float = 80.0
const NODE_SIZE: float = 92.0
const SIDE_X: float = 1320.0
const SIDE_W: float = 560.0

const SITE_LOOK: Dictionary = {
	"start":     ["START", Color("3a362d")],
	"skirmish":  ["FIGHT", Color("7a3a2a")],
	"elite":     ["ELITE", Color("9c2f22")],
	"scrapyard": ["SCRAPYARD", Color("3f5a2e")],
	"workshop":  ["WORKSHOP", Color("2e4f66")],
	"boss":      ["BOSS", Color("5c1f1a")],
}

var _map: Control
var _site_buttons: Dictionary = {}
var _side: VBoxContainer
var _top_hp: ProgressBar
var _top_hp_label: Label
var _top_scrap: Label
var _overlay: Control
var _refit_open: bool = false
## The socket picked on the refit screen: `[crew_index, socket]`, or empty.
var _refit_socket: Array = []


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
	side_scroll.position = Vector2(SIDE_X, MAP_RECT.position.y)
	side_scroll.size = Vector2(SIDE_W, MAP_RECT.size.y)
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(side_scroll)
	_side = VBoxContainer.new()
	_side.custom_minimum_size = Vector2(SIDE_W - 16, 0)
	_side.add_theme_constant_override("separation", UIKit.SPACE_MD)
	side_scroll.add_child(_side)
	_refresh()


# --- Building ---------------------------------------------------------------

func _build_top_bar() -> void:
	var title := _label("ACT 1  ·  THE CRANE YARDS", 40, UIKit.TEXT, UIKit.font_display())
	title.position = Vector2(40, 30)
	add_child(title)
	var bar := HBoxContainer.new()
	bar.position = Vector2(1060, 40)
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
	_build_site_buttons()
	_map.queue_redraw()
	_build_side()
	_show_overlay()


func _to_map(site: Dictionary) -> Vector2:
	var w: float = MAP_RECT.size.x - MAP_PAD * 2.0
	var h: float = MAP_RECT.size.y - MAP_PAD * 2.0
	return Vector2(MAP_PAD + float(site["x"]) / 100.0 * w, MAP_PAD + float(site["y"]) / 100.0 * h)


func _build_site_buttons() -> void:
	for child: Node in _map.get_children():
		child.queue_free()
	_site_buttons.clear()
	var state: RunState = Run.state
	var targets: Array[int] = RunSim.destinations(state)
	for site: Dictionary in state.sites:
		var id: int = int(site["id"])
		var known: bool = RunSim.revealed(state, id)
		var look: Array = SITE_LOOK.get(String(site["type"]), ["?", UIKit.SURFACE_HIGH]) if known else ["?", UIKit.SURFACE_HIGH]
		var button := Button.new()
		button.text = String(look[0])
		button.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
		button.size = Vector2(NODE_SIZE, NODE_SIZE)
		button.position = _to_map(site) - Vector2(NODE_SIZE, NODE_SIZE) * 0.5
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_override("font", UIKit.font_strong())
		button.add_theme_font_size_override("font_size", UIKit.SIZE_LABEL)
		var style := UIKit.plain(look[1] as Color, int(NODE_SIZE / 2.0))
		style.set_border_width_all(2)
		style.border_color = UIKit.HAIRLINE
		if id == state.current:
			style.border_color = UIKit.AMBER
			style.set_border_width_all(4)
		elif targets.has(id):
			style.border_color = UIKit.BLUE
			style.set_border_width_all(3)
		if bool(site["visited"]) and id != state.current:
			style.bg_color = style.bg_color.darkened(0.45)
		for key: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(key, style)
		button.add_theme_color_override("font_color", UIKit.TEXT)
		button.add_theme_color_override("font_disabled_color", UIKit.TEXT_DIM)
		# Only somewhere the Crawler can go is a button; everywhere else is a marker.
		button.disabled = not targets.has(id)
		if state.consumed(id):
			button.modulate = Color(1, 1, 1, 0.35)
		button.pressed.connect(_travel.bind(id))
		_map.add_child(button)
		_site_buttons[id] = button


func _draw_map() -> void:
	var state: RunState = Run.state
	_map.draw_style_box(UIKit.card(UIKit.SURFACE.darkened(0.1)), Rect2(Vector2.ZERO, MAP_RECT.size))
	# The Reclaimer: everything up to the column it has swallowed.
	if state.front_col >= 0:
		var columns: int = int((Run.setup.rules.get("region", {}) as Dictionary).get("columns", 7))
		var edge: float = (float(state.front_col) + 0.5) / float(columns - 1)
		var w: float = MAP_PAD + edge * (MAP_RECT.size.x - MAP_PAD * 2.0)
		_map.draw_rect(Rect2(0, 0, w, MAP_RECT.size.y), Color(0.55, 0.12, 0.08, 0.28))
		_map.draw_line(Vector2(w, 0), Vector2(w, MAP_RECT.size.y), Color(0.85, 0.3, 0.2, 0.8), 3.0)
		_map.draw_string(UIKit.font_display(), Vector2(18, 44), "THE RECLAIMER", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.9, 0.4, 0.3, 0.9))
	var targets: Array[int] = RunSim.destinations(state)
	for site: Dictionary in state.sites:
		for other: Variant in (site["links"] as Array):
			if int(other) < int(site["id"]):
				continue
			var a: Vector2 = _to_map(site)
			var b: Vector2 = _to_map(state.site(int(other)))
			var live: bool = (int(site["id"]) == state.current and targets.has(int(other))) \
				or (int(other) == state.current and targets.has(int(site["id"])))
			_map.draw_line(a, b, UIKit.BLUE if live else UIKit.EDGE_LIGHT, 4.0 if live else 2.0, true)


func _build_side() -> void:
	for child: Node in _side.get_children():
		child.queue_free()
	var state: RunState = Run.state
	var head := HBoxContainer.new()
	_side.add_child(head)
	head.add_child(_label("CREW", UIKit.SIZE_HEADING, UIKit.TEXT, UIKit.font_display()))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	if RunSim.can_refit(state):
		var refit := _button("REFIT", UIKit.secondary(), UIKit.TEXT, Vector2(140, 48))
		refit.pressed.connect(_open_refit)
		head.add_child(refit)
	for member: Dictionary in state.crew:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UIKit.card())
		_side.add_child(card)
		var box := VBoxContainer.new()
		card.add_child(box)
		var alive: bool = bool(member["alive"])
		box.add_child(_label(String(member["name"]) + (("  ·  %d / %d HP" % [int(member["hp"]), RunSim.max_hp(Run.setup, member)])
			if alive else "  ·  WRECK"), UIKit.SIZE_HEADING, UIKit.TEXT if alive else UIKit.RED, UIKit.font_strong()))
		var parts: Array = member["parts"]
		box.add_child(_label("%s  ·  %s" % [PartText.name_of(Run.db.parts, parts[2]), PartText.name_of(Run.db.parts, parts[3])],
			UIKit.SIZE_BODY, UIKit.TEXT_DIM))
		box.add_child(_label("%s  ·  %s  ·  %s" % [PartText.name_of(Run.db.parts, parts[0]), PartText.name_of(Run.db.parts, parts[1]),
			PartText.name_of(Run.db.parts, parts[4])], UIKit.SIZE_LABEL, UIKit.TEXT_FAINT))
	var hold: PackedStringArray = []
	for id: String in state.cargo:
		hold.append(PartText.name_of(Run.db.parts, id))
	_side.add_child(_label("HOLD  %d / %d" % [state.cargo.size(), int(Run.setup.rules.get("cargo_size", 6))],
		UIKit.SIZE_LABEL, UIKit.TEXT, UIKit.font_strong()))
	var hold_text := _label(", ".join(hold) if not hold.is_empty() else "Empty", UIKit.SIZE_LABEL, UIKit.TEXT_DIM)
	hold_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_side.add_child(hold_text)
	_side.add_child(_label("LOG", UIKit.SIZE_LABEL, UIKit.TEXT, UIKit.font_strong()))
	var start: int = maxi(0, state.log.size() - 6)
	for i: int in range(start, state.log.size()):
		var line := _label(state.log[i], UIKit.SIZE_LABEL, UIKit.TEXT_DIM if i < state.log.size() - 1 else UIKit.TEXT)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_side.add_child(line)
	if RunSim.destinations(state).size() > 0:
		var hint := _label("Tap a blue-ringed site to move there. The Reclaimer advances every %d moves; moving out of ground it has taken damages every machine." % int((Run.setup.rules["front"] as Dictionary)["every"]),
			UIKit.SIZE_LABEL, UIKit.TEXT_FAINT)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_side.add_child(hint)


# --- Overlays ---------------------------------------------------------------

func _show_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null
	var state: RunState = Run.state
	if state.outcome != RunState.ONGOING:
		_run_over()
		return
	if _refit_open:
		_refit()
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
		var sub := _label(subtitle, UIKit.SIZE_BODY, UIKit.TEXT_DIM)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(sub)
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
	var titles: Dictionary = {"skirmish": "SKIRMISH", "elite": "ELITE WRECK-FIELD", "boss": "THE GATE"}
	var enemies: PackedStringArray = []
	for spec: Dictionary in (fight["enemy"] as Array):
		enemies.append(String(spec["name"]))
	var objective: Dictionary = fight.get("objective", {"type": "rout"})
	var goals: Dictionary = {
		"rout": "ROUT: destroy every enemy.",
		"defend": "DEFEND: keep the salvage caches standing for %d rounds (or destroy every enemy). Each cache you save pays out scrap." % int(objective.get("rounds", 0)),
		"salvage": "SALVAGE: collect %d scrap piles before the enemy carries them off (or destroy every enemy)." % int(objective.get("need", 0)),
	}
	var box := _modal(String(titles.get(kind, "FIGHT")),
		"%s\n\n%s.  %d enemies: %s.\nDamage your machines take here stays with them after the fight." % [
			String(goals.get(String(objective.get("type", "rout")), "")), String(fight.get("name", "")),
			enemies.size(), ", ".join(enemies)], 900)
	if Run.fight_actions.size() > 0:
		box.add_child(_label("This fight is in progress. It resumes where you left it.", UIKit.SIZE_BODY, UIKit.GOLD))
	var row := _row(box)
	var go := _button("ENTER FIGHT" if Run.fight_actions.is_empty() else "RESUME FIGHT", UIKit.primary(), UIKit.BG, Vector2(300, 64))
	go.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/combat.tscn"))
	row.add_child(go)


func _pick_panel() -> void:
	var state: RunState = Run.state
	var scrapyard: bool = String(state.pending["kind"]) == "scrapyard"
	var full: bool = state.cargo.size() >= int(Run.setup.rules.get("cargo_size", 6))
	var box := _modal("SCRAPYARD" if scrapyard else "SALVAGE",
		("Take one part into the hold, or strip the yard for scrap." if scrapyard else "Pick one part off the wrecks.")
		+ ("\nThe hold is full: refit something out of it first, or leave this." if full else ""))
	var row := _row(box)
	var options: Array = state.pending["options"]
	for i: int in options.size():
		row.add_child(_part_card(String(options[i]), Vector2(330, 300), not full, _pick.bind(i)))
	var actions := _row(box)
	var skip := _button(("TAKE %d SCRAP" % int(state.pending["scrap"])) if scrapyard else "LEAVE IT",
		UIKit.secondary(), UIKit.TEXT, Vector2(260, 60))
	skip.pressed.connect(_pick.bind(-1))
	actions.add_child(skip)
	var refit := _button("REFIT", UIKit.secondary(), UIKit.TEXT, Vector2(160, 60))
	refit.pressed.connect(_open_refit)
	actions.add_child(refit)


func _workshop_panel() -> void:
	var state: RunState = Run.state
	var shop: Dictionary = Run.setup.rules.get("workshop", {})
	var box := _modal("WORKSHOP", "Scrap buys repairs here. You have %d." % state.scrap, 900)
	var cost: int = int(shop["repair_cost"])
	if RunSim.needs_repair(state, Run.setup):
		if state.scrap >= cost:
			var repair := _button("PATCH THE CREW  +%d HP EACH  ·  %d SCRAP" % [int(shop["repair_amount"]), cost], UIKit.choice(), UIKit.TEXT, Vector2(600, 60))
			repair.pressed.connect(func() -> void: _apply([RunSim.REPAIR]))
			box.add_child(repair)
		else:
			box.add_child(_label("Patching the crew costs %d scrap." % cost, UIKit.SIZE_BODY, UIKit.RED))
	else:
		box.add_child(_label("Every machine is in one piece.", UIKit.SIZE_BODY, UIKit.GREEN))
	for i: int in state.crew.size():
		var member: Dictionary = state.crew[i]
		if bool(member["alive"]):
			continue
		var rebuild_cost: int = int(shop["rebuild_cost"])
		if state.scrap >= rebuild_cost:
			var rebuild := _button("REBUILD %s  ·  %d SCRAP" % [String(member["name"]).to_upper(), rebuild_cost], UIKit.choice(), UIKit.TEXT, Vector2(560, 60))
			rebuild.pressed.connect(func() -> void: _apply([RunSim.REBUILD, i]))
			box.add_child(rebuild)
		else:
			box.add_child(_label("Rebuilding %s costs %d scrap." % [member["name"], rebuild_cost], UIKit.SIZE_BODY, UIKit.RED))
	var row := _row(box)
	var refit := _button("REFIT", UIKit.secondary(), UIKit.TEXT, Vector2(160, 60))
	refit.pressed.connect(_open_refit)
	row.add_child(refit)
	var leave := _button("MOVE ON", UIKit.primary(), UIKit.BG, Vector2(240, 60))
	leave.pressed.connect(func() -> void: _apply([RunSim.LEAVE]))
	row.add_child(leave)


func _refit() -> void:
	var state: RunState = Run.state
	var box := _modal("REFIT", "Tap a socket, then a part from the hold that fits it.", 1700)
	var columns := _row(box)
	for i: int in state.crew.size():
		var member: Dictionary = state.crew[i]
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(530, 0)
		col.add_theme_constant_override("separation", UIKit.SPACE_XS)
		columns.add_child(col)
		col.add_child(_label(String(member["name"]).to_upper() + ("" if bool(member["alive"]) else "  ·  WRECK"),
			UIKit.SIZE_HEADING, UIKit.TEXT, UIKit.font_strong()))
		for socket: int in 5:
			var part: String = String(member["parts"][socket])
			var selected: bool = _refit_socket.size() == 2 and int(_refit_socket[0]) == i and int(_refit_socket[1]) == socket
			var slot_name: String = ["CHASSIS", "CORE", "LEFT ARM", "RIGHT ARM", "MODULE"][socket]
			var button := _socket_button(slot_name, part, selected)
			button.disabled = not bool(member["alive"])
			button.pressed.connect(func() -> void:
				_refit_socket = [i, socket]
				_show_overlay())
			col.add_child(button)
	box.add_child(_label("HOLD  %d / %d" % [state.cargo.size(), int(Run.setup.rules.get("cargo_size", 6))],
		UIKit.SIZE_HEADING, UIKit.TEXT, UIKit.font_strong()))
	var hold := _row(box)
	var want: String = RunSetup.socket_slot(int(_refit_socket[1])) if _refit_socket.size() == 2 else ""
	for c: int in state.cargo.size():
		var id: String = state.cargo[c]
		var fits: bool = want.is_empty() or String((Run.db.parts[id] as Dictionary).get("slot", "")) == want
		var card: Control = _part_card(id, Vector2(260, 200), fits and not want.is_empty(), _fit.bind(c))
		card.modulate = Color(1, 1, 1, 1.0 if fits else 0.35)
		hold.add_child(card)
	if state.cargo.is_empty():
		hold.add_child(_label("Nothing in the hold. Salvage from fights and scrapyards ends up here.", UIKit.SIZE_BODY, UIKit.TEXT_DIM))
	var row := _row(box)
	if _refit_socket.size() == 2 and int(_refit_socket[1]) != 0 \
			and not String(state.crew[int(_refit_socket[0])]["parts"][int(_refit_socket[1])]).is_empty():
		var unfit := _button("UNFIT INTO HOLD", UIKit.secondary(), UIKit.TEXT, Vector2(260, 60))
		unfit.pressed.connect(func() -> void: _fit(-1))
		row.add_child(unfit)
	var done := _button("DONE", UIKit.primary(), UIKit.BG, Vector2(220, 60))
	done.pressed.connect(func() -> void:
		_refit_open = false
		_refit_socket = []
		_refresh())
	row.add_child(done)


func _run_over() -> void:
	var state: RunState = Run.state
	var won: bool = state.outcome == RunState.WON
	var box := _modal("ACT 1 CLEARED" if won else "RUN OVER",
		"%s\n\n%d fights won  ·  %d moves  ·  %d scrap" % [state.end_reason, state.fights_won,
			state.moves, state.scrap], 900)
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


# --- Actions ----------------------------------------------------------------

func _travel(id: int) -> void:
	_apply([RunSim.TRAVEL, id])


func _pick(index: int) -> void:
	_apply([RunSim.PICK, index])


func _fit(cargo_index: int) -> void:
	if _refit_socket.size() != 2:
		return
	if Run.apply([RunSim.REFIT, int(_refit_socket[0]), int(_refit_socket[1]), cargo_index]):
		Audio.play("ui_confirm", -12.0)
	else:
		Audio.play("ui_deny", -10.0)
	_refresh()


func _open_refit() -> void:
	_refit_open = true
	_refit_socket = []
	_show_overlay()


func _apply(action: Array) -> void:
	if Run.apply(action):
		Audio.play("ui_confirm", -12.0)
	else:
		Audio.play("ui_deny", -10.0)
	_refresh()


# --- Pieces -----------------------------------------------------------------

## A part as a card: picture, name in its rarity colour, slot, and what it does.
## `on_press` is null for a card that is only shown.
func _part_card(id: String, size: Vector2, enabled: bool, on_press: Callable) -> Control:
	var button := Button.new()
	button.custom_minimum_size = size
	button.focus_mode = Control.FOCUS_NONE
	var style := UIKit.inset(UIKit.SURFACE_HIGH, UIKit.RADIUS_CARD, UIKit.SPACE_MD, UIKit.SPACE_MD)
	style.border_color = PartText.rarity_colour(Run.db.parts, id).darkened(0.2)
	for key: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(key, style)
	button.disabled = not enabled
	if enabled:
		button.pressed.connect(on_press)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, UIKit.SPACE_MD)
	var tex := PartText.thumb(id)
	if tex != null:
		var picture := TextureRect.new()
		picture.texture = tex
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(0, size.y * 0.42)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(picture)
	box.add_child(_label(PartText.name_of(Run.db.parts, id), UIKit.SIZE_HEADING, PartText.rarity_colour(Run.db.parts, id).lightened(0.2), UIKit.font_strong()))
	box.add_child(_label(PartText.slot_label(Run.db.parts, id), UIKit.SIZE_MICRO, UIKit.TEXT_FAINT, UIKit.font_strong()))
	var text := _label(PartText.summary(Run.db.parts, id), UIKit.SIZE_LABEL, UIKit.TEXT_DIM)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	return button


func _socket_button(slot_name: String, part: String, selected: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(520, 76)
	button.focus_mode = Control.FOCUS_NONE
	var style := UIKit.inset(UIKit.SURFACE_HIGH if selected else UIKit.SURFACE, UIKit.RADIUS_CONTROL, UIKit.SPACE_MD, UIKit.SPACE_SM)
	if selected:
		style.border_color = UIKit.AMBER
		style.set_border_width_all(2)
	for key: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(key, style)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", UIKit.SPACE_MD)
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_KEEP_SIZE, UIKit.SPACE_SM)
	var picture := TextureRect.new()
	picture.texture = PartText.thumb(part)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(60, 60)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(picture)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	text.add_child(_label("%s  ·  %s" % [slot_name, PartText.name_of(Run.db.parts, part)], UIKit.SIZE_BODY,
		PartText.rarity_colour(Run.db.parts, part).lightened(0.3) if not part.is_empty() else UIKit.RED, UIKit.font_strong()))
	text.add_child(_label(PartText.summary(Run.db.parts, part), UIKit.SIZE_LABEL, UIKit.TEXT_DIM))
	return button


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
