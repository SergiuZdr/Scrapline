class_name DoctrineEditor
extends PanelContainer

## The gambit editor: the player writes the rules their squad fights by.
##
## Rules are evaluated top down, first match wins, so **ordering is the whole skill** —
## "attack" at the top means nothing below it ever fires. The editor makes that
## visible: rules are numbered, reorderable, and the fallback is pinned last and cannot
## be deleted, because a doctrine that matches nothing would leave a unit standing
## still.
##
## What is written here is exactly what the simulation reads (`sim/doctrine/`), so
## there is no translation layer to drift. One system, three payoffs: it plays units
## left on Auto during a manual fight, it drives auto-battle, and in Phase 4 it becomes
## the async PvP defence AI.

signal doctrine_saved(rules: Array)

const MAX_RULES: int = 10

const COL_BG := Color("13161c")
const COL_ROW := Color("1c2129")
const COL_TEXT := Color("d7dde6")
const COL_DIM := Color("7c8697")
const COL_ACCENT := Color("9a7fd0")

## Condition templates offered in the picker, in the order they appear.
const CONDITIONS: Array = [
	{"label": "always", "cond": null},
	{"label": "my heat is high", "cond": {"subject": "self", "field": "heat_pct", "op": ">=", "value": 75}},
	{"label": "I am badly hurt", "cond": {"subject": "self", "field": "hp_pct", "op": "<=", "value": 25}},
	{"label": "I am healthy", "cond": {"subject": "self", "field": "hp_pct", "op": ">=", "value": 70}},
	{"label": "nothing is in reach", "cond": {"subject": "self", "field": "in_range", "op": "==", "value": 0}},
	{"label": "an enemy is Exposed", "cond": {"subject": "enemy", "field": "state", "op": "has", "value": "exposed"}},
	{"label": "an enemy is Fractured", "cond": {"subject": "enemy", "field": "state", "op": "has", "value": "fractured"}},
	{"label": "an ally is badly hurt", "cond": {"subject": "ally", "field": "hp_pct", "op": "<=", "value": 30}},
]

const ACTIONS: PackedStringArray = [
	"attack", "ability:0", "ability:1", "brace", "vent", "advance", "fall_back", "hold",
]

var _rules: Array = []
var _rows: VBoxContainer
var _status: Label


func _ready() -> void:
	add_theme_stylebox_override("panel", _flat(COL_BG, 0))

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)
	header.add_child(_label("DOCTRINE", 20, COL_TEXT))
	var hint := _label("   Checked top to bottom. The first rule that matches wins.", 14, COL_DIM)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)

	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 4)
	scroll.add_child(_rows)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	outer.add_child(footer)

	var add := Button.new()
	add.text = "+ Add rule"
	add.pressed.connect(_on_add)
	footer.add_child(add)

	var reset := Button.new()
	reset.text = "Reset to default"
	reset.pressed.connect(_on_reset)
	footer.add_child(reset)

	_status = _label("", 14, COL_DIM)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_status)

	if _rules.is_empty():
		_rules = Doctrine.default_doctrine().to_array()

	var save := Button.new()
	save.text = "SAVE DOCTRINE"
	save.custom_minimum_size = Vector2(180, 40)
	save.pressed.connect(_on_save)
	footer.add_child(save)

	_rebuild()


## Safe to call before the editor is in the tree: callers routinely build a page, load
## it, and only then parent it, at which point `_ready` has not run and the containers
## do not exist yet. The rules are held and drawn once they do.
func load_rules(rules: Array) -> void:
	_rules = rules.duplicate(true) if not rules.is_empty() else Doctrine.default_doctrine().to_array()
	if _rows != null:
		_rebuild()


func rules() -> Array:
	return _rules.duplicate(true)


# --- Rows --------------------------------------------------------------------

func _rebuild() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()
	for index: int in _rules.size():
		_rows.add_child(_build_row(index))
	_status.text = "%d of %d rules" % [_rules.size(), MAX_RULES]


func _build_row(index: int) -> PanelContainer:
	var rule: Dictionary = _rules[index]
	# The last rule is the catch-all. It is pinned and undeletable, because a doctrine
	# that matches nothing leaves a construct standing still in a fight.
	var is_fallback: bool = index == _rules.size() - 1

	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _flat(COL_ROW, 5))

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	row.add_child(line)

	var number := _label("%d." % (index + 1), 16, COL_ACCENT)
	number.custom_minimum_size = Vector2(28, 0)
	line.add_child(number)

	line.add_child(_label("IF", 14, COL_DIM))

	var condition := OptionButton.new()
	condition.custom_minimum_size = Vector2(240, 0)
	for entry: Variant in CONDITIONS:
		condition.add_item(String((entry as Dictionary)["label"]))
	condition.selected = _condition_index(rule)
	condition.disabled = is_fallback
	condition.item_selected.connect(_on_condition_changed.bind(index))
	line.add_child(condition)

	line.add_child(_label("THEN", 14, COL_DIM))

	# Three action slots: the chain. "—" means the chain ends there.
	var chain: Array = rule.get("then", ["attack"])
	for slot: int in SimDefs.CHAIN_MAX:
		var action := OptionButton.new()
		action.custom_minimum_size = Vector2(120, 0)
		action.add_item("—")
		for name: String in ACTIONS:
			action.add_item(name)
		action.selected = 0 if slot >= chain.size() else ACTIONS.find(String(chain[slot])) + 1
		action.item_selected.connect(_on_action_changed.bind(index, slot))
		line.add_child(action)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(spacer)

	var up := Button.new()
	up.text = "▲"
	up.disabled = index == 0 or is_fallback
	up.pressed.connect(_on_move.bind(index, -1))
	line.add_child(up)

	var down := Button.new()
	down.text = "▼"
	down.disabled = index >= _rules.size() - 2
	down.pressed.connect(_on_move.bind(index, 1))
	line.add_child(down)

	var remove := Button.new()
	remove.text = "✕"
	remove.disabled = is_fallback
	remove.pressed.connect(_on_remove.bind(index))
	line.add_child(remove)

	if is_fallback:
		line.add_child(_label("fallback", 12, COL_DIM))

	return row


# --- Editing -----------------------------------------------------------------

func _condition_index(rule: Dictionary) -> int:
	if not rule.has("if"):
		return 0
	var cond: Dictionary = rule["if"]
	for index: int in CONDITIONS.size():
		var candidate: Variant = (CONDITIONS[index] as Dictionary)["cond"]
		if candidate == null:
			continue
		var c: Dictionary = candidate as Dictionary
		if String(c.get("field", "")) == String(cond.get("field", "")) \
				and String(c.get("subject", "")) == String(cond.get("subject", "")) \
				and String(c.get("op", "")) == String(cond.get("op", "")):
			return index
	return 0


func _on_condition_changed(selection: int, index: int) -> void:
	var template: Variant = (CONDITIONS[selection] as Dictionary)["cond"]
	if template == null:
		_rules[index].erase("if")
	else:
		_rules[index]["if"] = (template as Dictionary).duplicate(true)
	_rebuild()


func _on_action_changed(selection: int, index: int, slot: int) -> void:
	var chain: Array = (_rules[index].get("then", []) as Array).duplicate()
	while chain.size() <= slot:
		chain.append("attack")
	if selection == 0:
		# Clearing a slot truncates the chain rather than leaving a hole in it.
		chain = chain.slice(0, slot)
	else:
		chain[slot] = ACTIONS[selection - 1]
	if chain.is_empty():
		chain = ["attack"]
	_rules[index]["then"] = chain
	_rebuild()


func _on_move(index: int, direction: int) -> void:
	var target: int = index + direction
	if target < 0 or target >= _rules.size() - 1:
		return
	var moved: Dictionary = _rules[index]
	_rules.remove_at(index)
	_rules.insert(target, moved)
	_rebuild()


func _on_remove(index: int) -> void:
	if _rules.size() <= 1:
		return
	_rules.remove_at(index)
	_rebuild()


func _on_add() -> void:
	if _rules.size() >= MAX_RULES:
		_status.text = "a doctrine is capped at %d rules" % MAX_RULES
		return
	# Inserted above the fallback, because a rule added below it could never fire.
	_rules.insert(maxi(0, _rules.size() - 1),
		{"if": (CONDITIONS[1] as Dictionary)["cond"].duplicate(true), "then": ["attack"]})
	_rebuild()


func _on_reset() -> void:
	_rules = Doctrine.default_doctrine().to_array()
	_rebuild()


func _on_save() -> void:
	doctrine_saved.emit(rules())
	_status.text = "saved"


# --- Helpers -----------------------------------------------------------------

func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l


func _flat(colour: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
