class_name LoadoutScreen
extends VBoxContainer

## The parts screen: pick a construct, pick a socket, pick a part, see it on the model.
##
## What this replaces
## ------------------
## A flat list of every owned part with LEVEL and REFIT buttons on each row. It let you
## upgrade parts and gave you no way to EQUIP one, so the thing the whole modular system
## exists for -- deciding what a construct is built from -- happened nowhere in the game.
##
## The shape is a mech-garage layout: the construct is the subject, in 3D, and it updates
## the instant a part changes. A loadout editor that describes a machine in text is asking
## the player to imagine the thing the game is already capable of drawing.
##
## **Every change goes through `ProfileCommands.SetSquad`.** Writing into `profile.data`
## directly typechecks, runs, and evaporates at the next launch, because
## `ProfileStore.save()` returns early unless a command marked the profile dirty.
## Refusals are surfaced rather than dead-buttoned, so a player who cannot equip
## something is told why.

const SLOTS: Array[String] = ["chassis", "core", "arm_l", "arm_r", "module"]
const SLOT_LABELS: Dictionary = {
	"chassis": "CHASSIS", "core": "CORE", "arm_l": "LEFT ARM",
	"arm_r": "RIGHT ARM", "module": "MODULE",
}
## The part `slot` field each socket accepts. Both arms take the same parts.
const SLOT_ACCEPTS: Dictionary = {
	"chassis": "chassis", "core": "core", "arm_l": "arm",
	"arm_r": "arm", "module": "module",
}
const PREVIEW_SIZE: Vector2 = Vector2(420, 460)
const THUMB_DIR: String = "res://art/thumbs"
## Where the preview rests: a three-quarter view, the angle that shows a silhouette and
## both arms at once. The model does NOT spin on its own -- a constantly turning object
## is one you have to wait for before you can read it, and comparing two loadouts means
## catching both at the same moment. The player drags to turn it.
const REST_YAW: float = -0.62
const DRAG_SPEED: float = 0.011

signal changed

## Emitted with the five part ids whenever the edited construct changes, but only in
## external-preview mode. The yard hub listens to this and rebuilds the machine hanging
## in the service gantry, which is the whole point of a station: the thing you are
## editing is the thing standing in front of you, not a thumbnail of it.
signal preview_changed(part_ids: PackedStringArray)

## When true this screen draws NO preview of its own.
##
## Inside the yard the panel sat two metres from a full-size, lit construct in a gantry
## and still drew its own little dark viewport of the same machine -- two pictures of one
## object, the worse one nearer the eye. Set before the node enters the tree.
var external_preview: bool = false

var _squad_name: String = "main"
var _unit_index: int = 0
var _slot: String = "chassis"

var _preview_root: Node3D
var _model: Node3D
var _viewport: SubViewport
var _slot_column: VBoxContainer
var _catalogue: GridContainer
var _unit_row: HBoxContainer
var _status: Label
var _thumb_cache: Dictionary = {}
## Kept across rebuilds so swapping a part does not throw the view back to the default.
var _yaw: float = REST_YAW


func _ready() -> void:
	add_theme_constant_override("separation", UIKit.SPACE_MD)
	_build()
	refresh()


## Drag anywhere on the preview to turn the construct. Held, not spun, and the angle
## persists across part changes so a swap is judged from the same viewpoint.
##
## The sign is NOT arbitrary. The camera sits on +Z looking back at the origin, so a
## positive yaw carries the model's front face toward +X, which is screen right -- the
## direction the finger went. Negated, as it was, the construct turned away from the
## drag, which reads as the control being broken rather than inverted.
func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_yaw += motion.relative.x * DRAG_SPEED
			_apply_yaw()
	elif event is InputEventScreenDrag:
		_yaw += (event as InputEventScreenDrag).relative.x * DRAG_SPEED
		_apply_yaw()


func _apply_yaw() -> void:
	if _model != null and is_instance_valid(_model):
		_model.rotation.y = _yaw


# --- Layout ------------------------------------------------------------------

func _build() -> void:
	if external_preview:
		# The picker sits above the columns instead of under a picture that is not here.
		add_child(_build_unit_row())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", UIKit.SPACE_LG)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(body)

	if not external_preview:
		body.add_child(_build_preview())
	body.add_child(_build_sockets())
	body.add_child(_build_catalogue())

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", UIKit.SIZE_LABEL)
	_status.add_theme_color_override("font_color", UIKit.TEXT_DIM)
	add_child(_status)


## The construct itself, live in 3D.
##
## `own_world_3d` matters: without it the SubViewport shares the hub's world, which has
## no camera and no lights, and the panel renders as a grey rectangle.
func _build_preview() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", UIKit.SPACE_SM)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel",
		UIKit.inset(UIKit.SURFACE_SUNK, UIKit.RADIUS_CARD, 0, 0))
	column.add_child(frame)

	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = PREVIEW_SIZE
	container.gui_input.connect(_on_preview_input)
	frame.add_child(container)

	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.size = Vector2i(PREVIEW_SIZE)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_viewport)

	_preview_root = Node3D.new()
	_viewport.add_child(_preview_root)

	# The battlefield's own rig, so a part looks in the garage the way it will look in
	# the fight -- warm key, cold fill.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 142, 0)
	key.light_energy = 1.5
	key.light_color = Color("ffd3a4")
	_preview_root.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-24, -40, 0)
	fill.light_energy = 0.9
	fill.light_color = Color("8aa3de")
	_preview_root.add_child(fill)

	# Pulled back far enough that the construct stays inside the frame through a full
	# turn. Weapons project a long way forward, so the widest moment of the spin -- not
	# the front view -- is what sets the distance.
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 0.92, 3.45)
	camera.look_at_from_position(camera.position, Vector3(0, 0.60, 0), Vector3.UP)
	camera.fov = 32.0
	_preview_root.add_child(camera)

	column.add_child(_build_unit_row())
	return column


## The construct picker. Lives outside `_build_preview` because external-preview mode
## still needs it -- which construct you are editing is not a property of the picture.
func _build_unit_row() -> Control:
	_unit_row = HBoxContainer.new()
	_unit_row.add_theme_constant_override("separation", UIKit.SPACE_XS)
	return _unit_row


func _build_sockets() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 0)
	panel.add_theme_stylebox_override("panel", UIKit.card())

	_slot_column = VBoxContainer.new()
	_slot_column.add_theme_constant_override("separation", UIKit.SPACE_XS)
	panel.add_child(_slot_column)
	return panel


func _build_catalogue() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UIKit.card())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	_catalogue = GridContainer.new()
	_catalogue.columns = 4
	_catalogue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catalogue.add_theme_constant_override("h_separation", UIKit.SPACE_SM)
	_catalogue.add_theme_constant_override("v_separation", UIKit.SPACE_SM)
	scroll.add_child(_catalogue)
	return panel


# --- Refresh -----------------------------------------------------------------

func refresh() -> void:
	_refresh_units()
	_refresh_sockets()
	_refresh_catalogue()
	_refresh_model()


func _refresh_units() -> void:
	for child: Node in _unit_row.get_children():
		child.queue_free()
	var squad: Array = Session.profile().squad(_squad_name)
	for index: int in maxi(squad.size(), 1):
		var button := Button.new()
		button.text = str(index + 1)
		button.custom_minimum_size = Vector2(62, 34)
		button.toggle_mode = true
		button.button_pressed = index == _unit_index
		button.pressed.connect(_on_unit.bind(index))
		_unit_row.add_child(button)


## One row per socket, showing what is fitted. The selected socket carries the amber edge
## the hub's nav and the battle HUD both use for "this is the thing you are changing".
func _refresh_sockets() -> void:
	for child: Node in _slot_column.get_children():
		child.queue_free()

	_slot_column.add_child(_heading("SOCKETS"))
	var parts: Dictionary = _current_parts()
	for slot: String in SLOTS:
		var part_id: String = String(parts.get(slot, ""))
		var definition: Dictionary = Session.content.parts.get(part_id, {})

		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 54)
		button.toggle_mode = true
		button.button_pressed = slot == _slot
		button.text = ""
		var style: StyleBoxFlat = UIKit.plain(
			UIKit.SURFACE_HIGH if slot == _slot else UIKit.SURFACE,
			UIKit.RADIUS_CONTROL, UIKit.SPACE_MD, UIKit.SPACE_SM)
		if slot == _slot:
			style.border_width_left = 3
			style.border_color = UIKit.AMBER
			style.corner_radius_top_left = 0
			style.corner_radius_bottom_left = 0
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.pressed.connect(_on_slot.bind(slot))
		_slot_column.add_child(button)

		var inner := VBoxContainer.new()
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.offset_left = UIKit.SPACE_MD
		inner.add_theme_constant_override("separation", 0)
		inner.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.add_child(inner)
		inner.add_child(_text(String(SLOT_LABELS[slot]), UIKit.SIZE_MICRO, UIKit.TEXT_DIM))
		inner.add_child(_text(
			String(definition.get("name", "— empty —")), UIKit.SIZE_BODY,
			UIKit.TEXT if not part_id.is_empty() else UIKit.TEXT_FAINT))


func _refresh_catalogue() -> void:
	for child: Node in _catalogue.get_children():
		child.queue_free()

	var profile: PlayerProfile = Session.profile()
	var accepts: String = String(SLOT_ACCEPTS[_slot])
	var fitted: String = String(_current_parts().get(_slot, ""))

	var any: bool = false
	for part_id: String in profile.owned_part_ids():
		var definition: Dictionary = Session.content.parts.get(part_id, {})
		if String(definition.get("slot", "")) != accepts:
			continue
		any = true
		_catalogue.add_child(_part_card(part_id, definition, profile, part_id == fitted))

	if not any:
		_catalogue.add_child(_text(
			"no %s parts owned yet — open a crate" % accepts, UIKit.SIZE_BODY,
			UIKit.TEXT_DIM))


## A part as a CARD, and the card IS the button.
##
## Every card used to carry its own FIT button, which put eleven or more controls on a
## screen that offers exactly one kind of choice -- pick a part. That is what made the
## screen hard to read: a wall of small identical buttons gives no clue which one is the
## thing to press, and on a phone each was a 30 px target sitting under a 210 px card
## that did nothing when tapped. Tapping the part you want is the obvious gesture, so
## the card takes the press and the button is gone.
func _part_card(part_id: String, definition: Dictionary, profile: PlayerProfile,
		fitted: bool) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(168, 206)
	card.toggle_mode = false
	card.text = ""

	var style: StyleBoxFlat = UIKit.card(
		UIKit.SURFACE_HIGH if fitted else UIKit.SURFACE, UIKit.RADIUS_CARD,
		UIKit.SPACE_SM, UIKit.SPACE_SM)
	if fitted:
		# Amber marks the SELECTION here -- the other job the palette gives it. The
		# equipped part is the one thing on this screen the eye should find first.
		style.border_color = UIKit.AMBER
		style.set_border_width_all(2)
	card.add_theme_stylebox_override("normal", style)
	card.add_theme_stylebox_override("hover", UIKit.card(
		UIKit.SURFACE_HIGH.lightened(0.08), UIKit.RADIUS_CARD,
		UIKit.SPACE_SM, UIKit.SPACE_SM))
	card.add_theme_stylebox_override("pressed", UIKit.card(
		UIKit.SURFACE_HIGH.darkened(0.14), UIKit.RADIUS_CARD,
		UIKit.SPACE_SM, UIKit.SPACE_SM))
	card.add_theme_stylebox_override("focus", UIKit.plain(Color(0, 0, 0, 0)))
	if fitted:
		card.disabled = true
		card.add_theme_stylebox_override("disabled", style)
	else:
		card.pressed.connect(_on_fit.bind(part_id))

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.offset_left = UIKit.SPACE_SM
	column.offset_right = -UIKit.SPACE_SM
	column.offset_top = UIKit.SPACE_SM
	column.offset_bottom = -UIKit.SPACE_SM
	column.add_theme_constant_override("separation", UIKit.SPACE_XS)
	card.add_child(column)

	var picture := TextureRect.new()
	picture.custom_minimum_size = Vector2(0, 112)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture = _thumb(part_id)
	column.add_child(picture)

	column.add_child(_text(String(definition.get("name", part_id)), UIKit.SIZE_LABEL,
		UIKit.TEXT))
	column.add_child(_text(_headline_stat(definition), UIKit.SIZE_MICRO, UIKit.BLUE))
	column.add_child(_text("LVL %d · TIER %d" % [
		profile.part_level(part_id), profile.part_tier(part_id)],
		UIKit.SIZE_MICRO, UIKit.TEXT_DIM))

	# The equipped card says so; the others say nothing, because "tap it to fit it" is
	# what a card affords and does not need writing on every tile.
	if fitted:
		var marker := _text("FITTED", UIKit.SIZE_MICRO, UIKit.AMBER)
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(marker)

	return card


## The one number that decides whether you want this part in this socket. A card that
## lists every stat is a spreadsheet cell with a picture on top.
func _headline_stat(definition: Dictionary) -> String:
	match String(definition.get("slot", "")):
		"chassis":
			return "%d HP · %s" % [int(definition.get("hp", 0)),
				String(definition.get("role", ""))]
		"arm":
			return "%d ATK · %d reach" % [int(definition.get("attack", 0)),
				int(definition.get("range", 0))]
		"core":
			return String(definition.get("damage_type", ""))
		_:
			return String(definition.get("ability", ""))


func _refresh_model() -> void:
	if _model != null and is_instance_valid(_model):
		_model.queue_free()
	_model = null

	var parts: Dictionary = _current_parts()
	if String(parts.get("chassis", "")).is_empty():
		if external_preview:
			preview_changed.emit(PackedStringArray())
		return

	var unit := SimUnit.new()
	unit.unit_ref = 0
	unit.team = SimDefs.TEAM_A
	# Same order the runtime uses: chassis, core, arm_l, arm_r, module.
	var ids: PackedStringArray = []
	for slot: String in SLOTS:
		ids.append(String(parts.get(slot, "")))
	unit.part_ids = ids

	# Hand the ids over rather than a built model. The yard mounts its construct in a
	# gantry, at its own scale, under its own lights -- none of which this screen knows
	# about, and none of which it should have to.
	if external_preview:
		preview_changed.emit(ids)
		return

	_model = ConstructView.build(unit, Session.content, Color("4fa8d8"))
	_preview_root.add_child(_model)
	_apply_yaw()


# --- Actions -----------------------------------------------------------------

func _on_unit(index: int) -> void:
	_unit_index = index
	Audio.play("ui_move", -20.0)
	refresh()


func _on_slot(slot: String) -> void:
	_slot = slot
	Audio.play("ui_move", -20.0)
	_refresh_sockets()
	_refresh_catalogue()


## Fits a part and writes the squad back through a command.
func _on_fit(part_id: String) -> void:
	var squad: Array = Session.profile().squad(_squad_name).duplicate(true)
	while squad.size() <= _unit_index:
		squad.append({"parts": {}})

	var spec: Dictionary = squad[_unit_index]
	if not spec.has("parts"):
		spec["parts"] = {}
	(spec["parts"] as Dictionary)[_slot] = part_id

	var result: int = Session.store.execute(
		ProfileCommands.SetSquad.new(_squad_name, squad))
	if result != ProfileCommand.Result.OK:
		# Told, not dead-buttoned: a refusal the player cannot see is a bug report.
		_status.text = "could not fit that part — %s" % ProfileCommand.result_name(result)
		_status.add_theme_color_override("font_color", UIKit.RED)
		Audio.play("ui_deny", -16.0)
		return

	Session.store.save()
	_status.text = "%s fitted to %s of construct %d" % [
		String((Session.content.parts.get(part_id, {}) as Dictionary).get("name", part_id)),
		String(SLOT_LABELS[_slot]).to_lower(), _unit_index + 1]
	_status.add_theme_color_override("font_color", UIKit.GREEN)
	Audio.play("ui_confirm", -16.0)
	refresh()
	changed.emit()


# --- Internals ---------------------------------------------------------------

func _current_parts() -> Dictionary:
	var squad: Array = Session.profile().squad(_squad_name)
	if _unit_index >= squad.size():
		return {}
	return (squad[_unit_index] as Dictionary).get("parts", {})


## Cached: a catalogue of forty cards must not load the same PNG forty times.
func _thumb(part_id: String) -> Texture2D:
	if _thumb_cache.has(part_id):
		return _thumb_cache[part_id]
	var path: String = "%s/%s.png" % [THUMB_DIR, part_id]
	var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_thumb_cache[part_id] = texture
	return texture


func _heading(text: String) -> Label:
	var label := _text(text, UIKit.SIZE_MICRO, UIKit.TEXT_DIM)
	return label


func _text(value: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
