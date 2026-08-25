class_name OrderPanel
extends PanelContainer

## The Order Phase. Six units, a chain of up to three actions each, once every cycle.
##
## The whole panel is designed around one number: taps per cycle. Six units times a
## three-action chain is ~18 interactions, and across eight cycles that is 150 taps a
## battle -- unplayable on a phone. So the default is always "change nothing":
## untouched units keep their standing order and never appear in the committed
## orders dictionary at all. A typical cycle should cost 0-3 taps, and Resume is
## reachable without opening a single card.

signal orders_committed(orders: Dictionary)

const CARD_WIDTH: int = 244
## Edge of one part thumbnail on a unit card. Five of these plus separations sit inside
## CARD_WIDTH with room to spare.
const THUMB_SIZE: int = 38

## part id -> Texture2D, shared by every card. See `_thumb`.
static var _thumb_cache: Dictionary = {}
const PANEL_HEIGHT: int = 330

## Aliases onto the shared palette -- see `UIKit`. Heat keeps its own two-stop ramp
## because it is a gauge, not a surface, and amber-to-red is what the player is reading.
const COL_BG := UIKit.BG
const COL_CARD := UIKit.SURFACE
const COL_CARD_SEL := UIKit.SURFACE_HIGH
const COL_TEXT := UIKit.TEXT
const COL_DIM := UIKit.TEXT_DIM
const COL_HP := UIKit.GREEN
const COL_HEAT := UIKit.AMBER
const COL_HEAT_HOT := UIKit.RED
const COL_ACCENT := UIKit.BLUE
const COL_AUTO := Color("9a7fd0")

var _units: Array[SimUnit] = []
## unit_ref -> Array[int] chain, or the String "auto". Only units the player actually
## touched appear here; everything else is left to its standing order.
var _pending: Dictionary = {}
var _selected_ref: int = -1

var _cards_row: HBoxContainer
var _action_box: VBoxContainer
var _chain_row: HBoxContainer
var _selected_label: Label
var _resume_button: Button
var _cycle_label: Label
var _card_nodes: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(0, PANEL_HEIGHT)
	add_theme_stylebox_override("panel", _flat(COL_BG, 0))

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	add_child(outer)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	outer.add_child(header)

	_cycle_label = _label("", 20, COL_TEXT)
	header.add_child(_cycle_label)

	var hint := _label("Untouched units keep their standing order.", 14, COL_DIM)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(hint)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)

	_cards_row = HBoxContainer.new()
	_cards_row.add_theme_constant_override("separation", 8)
	_cards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_cards_row)

	_action_box = _build_action_box()
	body.add_child(_action_box)


# --- Public API --------------------------------------------------------------

func show_cycle(units: Array[SimUnit], player_team: int, cycle: int, condition_name: String) -> void:
	_units = []
	for u: SimUnit in units:
		if u.team == player_team:
			_units.append(u)
	_pending.clear()
	_selected_ref = -1

	var suffix: String = "   %s" % condition_name if not condition_name.is_empty() else ""
	_cycle_label.text = "ORDER PHASE  ·  CYCLE %d%s" % [cycle + 1, suffix]

	_rebuild_cards()
	_refresh_action_box()


func set_enabled(enabled: bool) -> void:
	modulate = Color(1, 1, 1, 1.0 if enabled else 0.45)
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	_resume_button.disabled = not enabled


# --- Cards -------------------------------------------------------------------

func _rebuild_cards() -> void:
	for child: Node in _cards_row.get_children():
		child.queue_free()
	_card_nodes.clear()

	for u: SimUnit in _units:
		var card := _build_card(u)
		_cards_row.add_child(card)
		_card_nodes[u.unit_ref] = card


func _build_card(u: SimUnit) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	card.add_theme_stylebox_override("panel", _flat(COL_CARD, 6))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	var title := HBoxContainer.new()
	box.add_child(title)
	var name_label := _label(u.display_name, 17, COL_TEXT if u.alive else COL_DIM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(name_label)
	title.add_child(_label(_row_name(u.row()), 13, COL_DIM))

	if not u.alive:
		box.add_child(_label("DESTROYED", 14, COL_HEAT_HOT))
		return card

	box.add_child(_part_strip(u))
	box.add_child(_bar(u.hp, u.hp_max, COL_HP))
	box.add_child(_label("HP %d / %d" % [u.hp, u.hp_max], 12, COL_DIM))

	var heat_colour: Color = COL_HEAT_HOT if u.heat * 100 / maxi(1, u.heat_max) >= 75 else COL_HEAT
	box.add_child(_bar(u.heat, u.heat_max, heat_colour))
	var heat_text: String = "HEAT %d / %d" % [u.heat, u.heat_max]
	if u.can_overdrive:
		heat_text += "  · overdrive"
	box.add_child(_label(heat_text, 12, COL_DIM))

	var states: String = _state_text(u)
	box.add_child(_label(states if not states.is_empty() else " ", 12, COL_ACCENT))

	# The standing order, shown on the face of the card. A player must be able to see
	# what a unit will do without opening anything.
	box.add_child(_label(_order_text(u), 13, COL_AUTO if _is_auto(u) else COL_TEXT))

	var select := Button.new()
	select.text = "Orders"
	select.pressed.connect(_on_card_pressed.bind(u.unit_ref))
	box.add_child(select)

	return card


func _on_card_pressed(unit_ref: int) -> void:
	_selected_ref = -1 if _selected_ref == unit_ref else unit_ref
	_refresh_card_highlights()
	_refresh_action_box()


## The selected construct gets an amber edge, the same marker the hub's nav uses for the
## current screen. A slightly lighter card was the old cue and it did not survive being
## glanced at mid-battle, which is the only way this panel is ever read.
func _refresh_card_highlights() -> void:
	for unit_ref: Variant in _card_nodes.keys():
		var card: PanelContainer = _card_nodes[unit_ref]
		var selected: bool = int(unit_ref) == _selected_ref
		var style: StyleBoxFlat = _flat(COL_CARD_SEL if selected else COL_CARD, 6)
		if selected:
			style.border_width_top = 2
			style.border_color = UIKit.AMBER
		card.add_theme_stylebox_override("panel", style)


# --- Action palette ----------------------------------------------------------

func _build_action_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 6)

	_selected_label = _label("Select a unit to change its orders", 16, COL_DIM)
	box.add_child(_selected_label)

	_chain_row = HBoxContainer.new()
	_chain_row.add_theme_constant_override("separation", 6)
	box.add_child(_chain_row)

	box.add_child(_build_action_grid())

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	box.add_child(footer)

	var clear := Button.new()
	clear.text = "Clear"
	clear.pressed.connect(_on_clear)
	footer.add_child(clear)

	var auto := Button.new()
	auto.text = "Auto (doctrine)"
	auto.pressed.connect(_on_auto)
	footer.add_child(auto)

	_resume_button = Button.new()
	_resume_button.text = "RESUME  ▶"
	_resume_button.custom_minimum_size = Vector2(160, 44)
	_resume_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resume_button.pressed.connect(_on_resume)
	footer.add_child(_resume_button)

	return box


func _build_action_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.name = "ActionGrid"
	return grid


func _refresh_action_box() -> void:
	var grid: GridContainer = _action_box.get_node("ActionGrid") as GridContainer
	for child: Node in grid.get_children():
		child.queue_free()
	for child: Node in _chain_row.get_children():
		child.queue_free()

	var u: SimUnit = _find_unit(_selected_ref)
	if u == null or not u.alive:
		_selected_label.text = "Select a unit to change its orders"
		return

	_selected_label.text = "%s  ·  %s" % [u.display_name, _order_text(u)]

	# Chain slots, so the queue is visible while it is being built.
	var chain: Array = _chain_for(u)
	for i: int in SimDefs.CHAIN_MAX:
		var slot := _label("%d. %s" % [i + 1, SimDefs.action_name(chain[i]) if i < chain.size() else "—"],
			14, COL_TEXT if i < chain.size() else COL_DIM)
		slot.custom_minimum_size = Vector2(130, 0)
		_chain_row.add_child(slot)

	_add_action_button(grid, u, SimDefs.action(SimDefs.ACT_ATTACK), "Attack")
	for i: int in 2:
		var ability: Dictionary = u.ability_at(i)
		if ability.is_empty():
			continue
		_add_action_button(grid, u, SimDefs.action(SimDefs.ACT_ABILITY, i), String(ability.get("name", "Ability %d" % i)))
	_add_action_button(grid, u, SimDefs.action(SimDefs.ACT_BRACE), "Brace")
	_add_action_button(grid, u, SimDefs.action(SimDefs.ACT_VENT), "Vent")
	_add_action_button(grid, u, SimDefs.action(SimDefs.ACT_FALL_BACK), "Fall Back")


func _add_action_button(grid: GridContainer, u: SimUnit, code: int, text: String) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 38)
	button.disabled = _chain_for(u).size() >= SimDefs.CHAIN_MAX
	button.pressed.connect(_on_action_pressed.bind(code))
	grid.add_child(button)


func _on_action_pressed(code: int) -> void:
	var u: SimUnit = _find_unit(_selected_ref)
	if u == null:
		return
	var chain: Array = _chain_for(u).duplicate()
	if chain.size() >= SimDefs.CHAIN_MAX:
		return
	chain.append(code)
	_pending[u.unit_ref] = chain
	_refresh_selected_card()
	_refresh_action_box()


func _on_clear() -> void:
	if _selected_ref < 0:
		return
	_pending[_selected_ref] = []
	_refresh_selected_card()
	_refresh_action_box()


func _on_auto() -> void:
	if _selected_ref < 0:
		return
	_pending[_selected_ref] = "auto"
	_refresh_selected_card()
	_refresh_action_box()


func _on_resume() -> void:
	# Only genuine changes are sent. Everything absent is a standing order, which is
	# the entire reason a cycle can cost zero taps.
	var orders: Dictionary = {}
	for unit_ref: Variant in _pending.keys():
		var value: Variant = _pending[unit_ref]
		if value is String:
			orders[int(unit_ref)] = value
		elif (value as Array).size() > 0:
			orders[int(unit_ref)] = value
	orders_committed.emit(orders)


func _refresh_selected_card() -> void:
	var u: SimUnit = _find_unit(_selected_ref)
	if u == null or not _card_nodes.has(u.unit_ref):
		return
	var old: PanelContainer = _card_nodes[u.unit_ref]
	var index: int = old.get_index()
	var fresh := _build_card(u)
	_cards_row.remove_child(old)
	old.queue_free()
	_cards_row.add_child(fresh)
	_cards_row.move_child(fresh, index)
	_card_nodes[u.unit_ref] = fresh
	_refresh_card_highlights()


# --- Helpers -----------------------------------------------------------------

func _chain_for(u: SimUnit) -> Array:
	if _pending.has(u.unit_ref):
		var value: Variant = _pending[u.unit_ref]
		return [] if value is String else (value as Array)
	return u.standing_chain


func _is_auto(u: SimUnit) -> bool:
	if _pending.has(u.unit_ref):
		return _pending[u.unit_ref] is String
	return u.on_auto


func _order_text(u: SimUnit) -> String:
	if _is_auto(u):
		return "AUTO — doctrine"
	var chain: Array = _chain_for(u)
	return "STANDING — %s" % SimDefs.chain_name(chain) if not chain.is_empty() else "AUTO — doctrine"


func _state_text(u: SimUnit) -> String:
	var names: PackedStringArray = []
	for state: int in SimDefs.STATE_COUNT:
		if u.has_state(state):
			names.append(SimDefs.state_name(state))
	return " · ".join(names)


func _find_unit(unit_ref: int) -> SimUnit:
	for u: SimUnit in _units:
		if u.unit_ref == unit_ref:
			return u
	return null


func _row_name(row: int) -> String:
	match row:
		SimDefs.ROW_FRONT: return "FRONT"
		SimDefs.ROW_MID: return "MID"
		_: return "BACK"


func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l


## The construct's five parts, as pictures, on the face of its card.
##
## Six cards of name-plus-two-bars are six identical cards. The player has six machines
## on the field built from different things, and during an Order Phase they have to know
## which one is the hammer and which one is the railgun WITHOUT selecting each in turn --
## the whole point of a modular roster is lost if the loadout is invisible in the fight.
##
## Pictures rather than part names because a name is another line of text on a card that
## already has five, and because the same thumbnails are what the loadout screen uses, so
## a part looks the same in the garage and in the battle.
##
## Deliberately not tooltips: this ships on phones, and there is no hover on a phone.
func _part_strip(u: SimUnit) -> HBoxContainer:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 2)
	for part_id: String in u.part_ids:
		if part_id.is_empty():
			continue
		var texture: Texture2D = _thumb(part_id)
		if texture == null:
			continue
		# A LIGHTER well behind each thumbnail. The parts are dark worn metal, and on the
		# near-black sunk surface the silhouettes disappeared into their own background --
		# which defeats the point of putting a picture there at all.
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel",
			UIKit.plain(UIKit.SURFACE_HIGH.lightened(0.10), 4, 1, 1))
		strip.add_child(frame)

		var picture := TextureRect.new()
		picture.texture = texture
		picture.custom_minimum_size = Vector2(THUMB_SIZE, THUMB_SIZE)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.add_child(picture)
	return strip


## Shared across every card and every rebuild. The Order Phase reopens each cycle, so an
## uncached load here would re-read thirty PNGs every six seconds.
static func _thumb(part_id: String) -> Texture2D:
	if _thumb_cache.has(part_id):
		return _thumb_cache[part_id]
	var path: String = "res://art/thumbs/%s.png" % part_id
	var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_thumb_cache[part_id] = texture
	return texture


func _bar(value: int, maximum: int, colour: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = maxi(1, maximum)
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	# Deliberately NOT a card: a gauge is a measurement, and a bordered, shadowed bar
	# reads as another button in a panel that already has plenty.
	bar.add_theme_stylebox_override("background", UIKit.plain(UIKit.SURFACE_SUNK, 4))
	bar.add_theme_stylebox_override("fill", UIKit.plain(colour, 4))
	return bar


## Routed through UIKit so the unit cards match the hub's cards exactly. A radius of 0
## still means "part of the page" -- the panel background and the progress-bar tracks --
## and stays flat.
func _flat(colour: Color, radius: int) -> StyleBoxFlat:
	if radius <= 0:
		return UIKit.plain(colour, 0, 10, 8)
	return UIKit.inset(colour, maxi(radius, UIKit.RADIUS_CONTROL), 10, 8)
