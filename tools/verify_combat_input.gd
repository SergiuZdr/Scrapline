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
	create_timer(480.0).timeout.connect(func() -> void:
		print("  FAIL  watchdog: the test did not finish (a script error above?)")
		quit(1))
	_run.call_deferred()


func _run() -> void:
	# A test profile with every first-time hint seen: a hint callout must not sit between the
	# test's clicks and the board, and the player's own profile is never touched (012).
	var profile: Node = root.get_node("Profile")
	profile.call("use_path", "user://test_profile_input.json")
	profile.call("set_playback", 1)
	for id: Variant in (ContentDB.load_all().tutorial.get("hints", {}) as Dictionary):
		profile.call("mark_seen", String(id))
	var packed: PackedScene = load("res://scenes/combat.tscn")
	_scene = packed.instantiate()
	root.add_child(_scene)
	await _settle()

	var state: CombatState = _scene.get("_state")
	_check("fight starts on the player's turn", state.round_number == 1 and not _scene.get("_busy"))

	# --- The board is drawn the way the rules count it (play-test 2: tiles met at their
	# corners). A pointy-top hex reaches further north-south (a corner) than east-west (a
	# side), and two neighbours' centres sit one tile-width apart, so their sides touch.
	var slab: MeshInstance3D = null
	for child: Node in (_scene.get("_board") as Node).get_children():
		if child is MeshInstance3D and child.has_meta("tile"):
			slab = child
			break
	var extent := Vector2.ZERO
	for v: Vector3 in (slab.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		var w: Vector3 = slab.transform.basis * v
		extent = Vector2(maxf(extent.x, absf(w.x)), maxf(extent.y, absf(w.z)))
	_check("tiles are pointy-top: a corner points north (z reach %.2f > x reach %.2f)" % [extent.y, extent.x], extent.y > extent.x + 0.05)
	var a: Vector3 = _scene.call("_to_world", 3, 3)
	var b: Vector3 = _scene.call("_to_world", 4, 3)
	_check("side neighbours sit one tile-width apart, so their sides meet", absf(a.distance_to(b) - extent.x * 2.0 / 0.96) < 0.02)

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
	var untouched: Node = ((_scene.get("_views") as Dictionary)[1] as Dictionary)["model"]
	var moved_model: Node = ((_scene.get("_views") as Dictionary)[0] as Dictionary)["model"]
	_click_control(hud.get("_undo"))
	await _settle()
	state = _scene.get("_state")
	_check("UNDO button puts it back", state.unit(0).x == start.x and state.unit(0).y == start.y)
	_check("UNDO leaves no action in the log", (_scene.get("_actions") as Array).is_empty())
	# Play-test 14: undo used to rebuild every machine. A machine whose look did not change keeps
	# its model -- and the one that moved is snapped back to its hex, not left where it walked.
	var views: Dictionary = _scene.get("_views")
	_check("UNDO keeps the models of machines it did not change (no rebuild)",
		(views[1] as Dictionary)["model"] == untouched and (views[0] as Dictionary)["model"] == moved_model)
	var snapped: Vector3 = ((views[0] as Dictionary)["root"] as Node3D).position
	var home: Vector3 = _scene.call("_to_world", start.x, start.y)
	_check("UNDO snaps the moved machine back onto its hex", Vector2(snapped.x - home.x, snapped.z - home.z).length() < 0.01)

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
		_check("first tap on a target only aims", not state.unit(0).acted and not (_scene.get("_pending") as Dictionary).is_empty())
		_click_tile(target_cell.x, target_cell.y)
		await _settle()
		state = _scene.get("_state")
		_check("second tap on the same target fires", state.unit(0).acted)
		_check("firing added heat", state.unit(0).heat > 0)
		# Play-test 5: UNDO goes back to the machine whose action it took back, weapon armed.
		_click_tile(state.unit(1).x, state.unit(1).y)
		await _settle()
		_check("(precondition) another machine is selected", int(_scene.get("_selected")) == 1)
		_click_control(hud.get("_undo"))
		await _settle()
		state = _scene.get("_state")
		_check("UNDO of an attack selects the machine that made it, its weapon armed again",
			int(_scene.get("_selected")) == 0 and bool(_scene.get("_armed")) and int(_scene.get("_weapon")) == w
			and not state.unit(0).acted)

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

	# --- Play-test 14: an undo in a later turn starts from the turn's snapshot, not round 1.
	state = _scene.get("_state")
	var mover: GridUnit = null
	for u: GridUnit in state.crew(GridUnit.TEAM_PLAYER):
		if not CombatSim.reachable(state, u.ref).is_empty():
			mover = u
			break
	if state.outcome == CombatState.ONGOING and mover != null:
		var from := Vector2i(mover.x, mover.y)
		_click_tile(mover.x, mover.y)
		await _settle()
		var to: Vector2i = CombatSim.reachable(state, mover.ref).keys()[0]
		_click_tile(to.x, to.y)
		await _settle()
		state = _scene.get("_state")
		_check("(precondition) a machine moved in round 2", state.unit(mover.ref).x == to.x and state.unit(mover.ref).y == to.y)
		var t0: int = Time.get_ticks_usec()
		_scene.call("_undo")
		var took: int = Time.get_ticks_usec() - t0
		await _settle()
		state = _scene.get("_state")
		var fresh: CombatState = CombatSim.replay(_scene.get("_setup"), _scene.get("_actions"))
		_check("a round-2 UNDO puts it back, and matches a full replay exactly",
			state.unit(mover.ref).x == from.x and state.unit(mover.ref).y == from.y and fresh.event_hash() == state.event_hash())
		print("    round-2 undo took %d ms" % (took / 1000))
		_check("a round-2 UNDO takes under 150 ms", took < 150000)

	await _playback_speeds(packed)

	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	print("")
	quit(1 if _failed > 0 else 0)


## 082 (A16): the same bot fight on slag_pit at 1x, 2x and 3x. Presentation never computes an
## outcome, so the event stream must not depend on the clock; and the enemy's turn at 2x must be
## over in under 1.5 s.
func _playback_speeds(packed: PackedScene) -> void:
	var profile: Node = root.get_node("Profile")
	var hashes: Array = []
	var logs: Array = []
	var enemy_ms: Dictionary = {}
	for speed: int in [1, 2, 3]:
		profile.call("set_playback", speed)
		_scene.queue_free()
		await process_frame
		_scene = packed.instantiate()
		_scene.set("_fight_id", "slag_pit")
		root.add_child(_scene)
		await _settle()
		var state: CombatState = _scene.get("_state")
		_check("(precondition, %dx) slag_pit opens on the player's turn" % speed,
			state.round_number == 1 and not bool(_scene.get("_busy")) and Engine.time_scale == 1.0)
		_scene.set("_bot", true)
		_scene.call("_bot_turn")
		var t0: int = 0
		var first: int = -1
		var hurried: bool = false
		var recorded: bool = false
		for frame: int in 60000:
			await process_frame
			var actions: Array = _scene.get("_actions")
			var ends: int = actions.filter(func(a: Array) -> bool: return int(a[0]) == CombatSim.ACT_END).size()
			state = _scene.get("_state")
			var busy: bool = bool(_scene.get("_busy"))
			if ends >= 1 and t0 == 0:
				t0 = Time.get_ticks_usec()
			if t0 > 0 and first < 0 and not busy:
				first = (Time.get_ticks_usec() - t0) / 1000
			if not recorded and (ends >= 2 or state.outcome != CombatState.ONGOING):
				recorded = true
				hashes.append(state.event_hash())
				logs.append(actions.duplicate(true))
				_scene.set("_bot", false)
				if speed == 1 and busy:
					# Hold-to-hurry: SPACE held during the enemy's turn runs it at 3x, released it is 1x again.
					_key(KEY_SPACE, true)
					for i: int in 6:
						await process_frame
						hurried = hurried or is_equal_approx(Engine.time_scale, 3.0)
					_key(KEY_SPACE, false)
					await process_frame
					await process_frame
					_check("holding SPACE hurries the enemy's turn to 3x; releasing it goes back to 1x",
						hurried and (not bool(_scene.get("_busy")) or Engine.time_scale <= 1.0))
			if recorded and not busy and first >= 0:
				break
		await _settle()
		enemy_ms[speed] = first
		_check("(%dx) the clock is back to 1x once playback ends" % speed, Engine.time_scale == 1.0)
	print("    enemy turn 1 on slag_pit: %d ms at 1x, %d ms at 2x, %d ms at 3x" % [enemy_ms[1], enemy_ms[2], enemy_ms[3]])
	_check("the bot fight's event stream is identical at 1x, 2x and 3x (%d actions)" % (logs[0] as Array).size(),
		hashes[0] == hashes[1] and hashes[1] == hashes[2] and logs[0] == logs[1] and logs[1] == logs[2])
	_check("and matches a fresh replay of its actions",
		CombatSim.replay(_scene.get("_setup"), logs[0]).event_hash() == hashes[0])
	# The clock scales the whole turn (2x takes at most 0.6 of 1x). 082 shortened the beats themselves
	# (the user: "shorter beats at every speed"): ~5.0 s at 1x became ~3.0 s; the aim is ~1.5 s at 2x,
	# and over 1.8 s fails.
	_check("2x plays the enemy's turn in at most 0.6 of the 1x time, 3x faster still",
		enemy_ms[2] >= 0 and enemy_ms[2] * 10 <= enemy_ms[1] * 6 and enemy_ms[3] < enemy_ms[2])
	_check("the enemy's turn on slag_pit is over in 1.8 s at 2x (%d ms; aim ~1500)" % enemy_ms[2], enemy_ms[2] >= 0 and enemy_ms[2] <= 1800)
	profile.call("set_playback", 1)
	_scene.queue_free()
	await process_frame
	_check("leaving the fight leaves the clock at 1x", Engine.time_scale == 1.0)


func _key(code: Key, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.pressed = pressed
	root.push_input(key)


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
