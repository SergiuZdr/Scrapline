extends SceneTree

## Drives the fight scene the way a player does: clicks on tiles and buttons, and keys.
##
##   godot --headless --path . --script res://tools/verify_combat_input.gd
##
## `verify_combat.gd` proves the rules through the sim's API, which is the part a player
## never touches. This proves the path a tap actually takes -- screen point, board pick,
## selection, the two-tap attack confirm, the UNDO button -- because a rule that works
## and a control that cannot reach it is still a game that does not work.
##
## The scene is loaded at runtime rather than by class name, so it compiles after the
## autoloads exist (see "The autoload trap" in CLAUDE.md).

var _scene: Node
var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("")
	print("=== combat input ===")
	# A script error inside a coroutine stops `_run` without quitting, and the test would
	# hang forever looking like a slow pass. A watchdog turns that into a failure.
	create_timer(240.0).timeout.connect(func() -> void:
		print("  FAIL  watchdog: the test did not finish (a script error above?)")
		quit(1))
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load("res://scenes/combat.tscn")
	_scene = packed.instantiate()
	root.add_child(_scene)
	await _settle()

	var state: CombatState = _scene.get("_state")
	_check("fight starts on the player's turn", state.round_number == 1 and not _scene.get("_busy"))

	# --- Move by clicking a tile.
	var brute: GridUnit = state.unit(0)
	var start := Vector2i(brute.x, brute.y)
	var options: Array = CombatSim.reachable(state, 0).keys()
	options.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	_click_tile(state.unit(1).x, state.unit(1).y)   # select someone else first
	await _settle()
	_check("tapping a construct selects it", int(_scene.get("_selected")) == 1)
	_click_tile(brute.x, brute.y)                   # then the Brute
	await _settle()
	_check("tapping another construct switches selection", int(_scene.get("_selected")) == 0)
	var dest: Vector2i = options[0]
	_click_tile(dest.x, dest.y)
	await _settle()
	state = _scene.get("_state")
	_check("tapping a blue tile moves the construct there", state.unit(0).x == dest.x and state.unit(0).y == dest.y)

	# --- Undo with the on-screen button.
	var hud: Control = _scene.get("_hud")
	_click_control(hud.get("_undo"))
	await _settle()
	state = _scene.get("_state")
	_check("UNDO button puts it back", state.unit(0).x == start.x and state.unit(0).y == start.y)
	_check("UNDO leaves no action in the log", (_scene.get("_actions") as Array).is_empty())

	# --- An empty hex beside a melee unit is a MOVE when unarmed.
	_click_tile(start.x, start.y)
	await _settle()
	var beside: Vector2i = Vector2i(-1, -1)
	for cell: Vector2i in options:
		if Hex.distance(cell, start) == 1:
			beside = cell
			break
	_click_tile(beside.x, beside.y)
	await _settle()
	state = _scene.get("_state")
	_check("tapping an empty tile beside a melee unit moves it", state.unit(0).x == beside.x and state.unit(0).y == beside.y)

	# --- Weapons come from the arms: the bar's buttons switch between them.
	# The bar is rebuilt on every refresh, so its buttons are looked up again after each tap.
	var buttons: Array = _weapon_buttons(hud)
	_check("the weapon bar offers one button per arm (+ VENT when hot)", buttons.size() >= 2)
	if buttons.size() >= 2:
		_click_control(buttons[1])
		await _settle()
		_check("tapping the second arm's button arms it", int(_scene.get("_weapon")) == 1 and bool(_scene.get("_armed")))
		_click_control(_weapon_buttons(hud)[1])
		await _settle()
		_check("tapping the armed weapon again returns to moving", not bool(_scene.get("_armed")))
		_click_control(_weapon_buttons(hud)[0])
		await _settle()
		_check("the first arm's button arms the first weapon", int(_scene.get("_weapon")) == 0 and bool(_scene.get("_armed")))

	# --- Attack takes two taps on the same target. After moving, every line tile aims.
	var w: int = int(_scene.get("_weapon"))
	var target_cell := Vector2i(-1, -1)
	for aim: Vector2i in CombatSim.aim_options(state, state.unit(0), w):
		var occupant: GridUnit = state.unit_at(aim.x, aim.y)
		if occupant == null or occupant.team != GridUnit.TEAM_PLAYER:
			target_cell = aim
			break
	_check("the Brute has a target that is not an ally", target_cell.x >= 0)
	if target_cell.x >= 0:
		_click_tile(target_cell.x, target_cell.y)
		await _settle()
		state = _scene.get("_state")
		_check("first tap on a target only aims", not state.unit(0).acted and (_scene.get("_pending") as Array).size() == 4)
		_click_tile(target_cell.x, target_cell.y)
		await _settle()
		state = _scene.get("_state")
		_check("second tap on the same target fires", state.unit(0).acted)
		_check("firing added heat", state.unit(0).heat > 0)

	# --- Tapping an ally always selects it, even inside someone's line of fire.
	_click_tile(state.unit(1).x, state.unit(1).y)
	await _settle()
	_check("tapping an ally selects it", int(_scene.get("_selected")) == 1)

	# --- End the turn from the keyboard.
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	root.push_input(key)
	await _settle()
	state = _scene.get("_state")
	_check("SPACE ends the turn and the enemy fires", state.round_number == 2 or state.outcome != CombatState.ONGOING)
	_check("undo cannot cross into the previous turn", int(_scene.get("_turn_start")) == (_scene.get("_actions") as Array).size())

	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	print("")
	quit(1 if _failed > 0 else 0)


func _weapon_buttons(hud: Control) -> Array:
	var bar: Control = hud.get("_weapon_bar")
	return bar.get_children().filter(func(c: Node) -> bool: return c is Button and not c.is_queued_for_deletion())


## Waits until the scene has finished animating, then one frame more for the redraw.
func _settle() -> void:
	for i: int in 2400:
		await process_frame
		if not bool(_scene.get("_busy")) and i > 5:
			break
	await process_frame


func _click_tile(x: int, y: int) -> void:
	var camera: Camera3D = _scene.get("_camera")
	var world: Vector3 = _scene.call("_to_world", x, y)
	_click(camera.unproject_position(world))


func _click_control(control: Control) -> void:
	_click(control.get_global_rect().get_center())


func _click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		# Local coordinates: `unproject_position` and `get_global_rect` both answer in the
		# viewport's own space, and without `true` push_input would run the point through
		# the window's stretch transform first and every click would land somewhere else.
		root.push_input(event, true)


func _check(label: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s" % label)
