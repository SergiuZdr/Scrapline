extends SceneTree

## The run driven through its screens: map taps, the fight handing back to the run,
## salvage, refit, and quitting mid-fight then resuming.
##
##   godot --headless --path . --script res://tools/verify_run_ui.gd
##
## `verify_run.gd` proves the rules through `RunSim`. This proves the buttons reach them,
## and that the save written between screens is the one the next screen reads.
## It deletes `user://run.json` before and after.

var _passed: int = 0
var _failed: int = 0
var _run: Node


func _initialize() -> void:
	print("")
	print("=== run through its screens ===")
	create_timer(300.0).timeout.connect(func() -> void:
		print("  FAIL  watchdog: the test did not finish (a script error above?)")
		quit(1))
	_go.call_deferred()


func _go() -> void:
	_run = root.get_node("Run")
	# A test profile with every first-time hint seen, so no callout sits over a click, and
	# the player's own profile is never touched (012).
	var profile: Node = root.get_node("Profile")
	# A fresh file every time: names a previous run of this test gave the crew (027) would come
	# back as RENAME actions.
	for path: String in ["user://test_profile_ui.json", SaveFile.backup_of("user://test_profile_ui.json")]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	profile.call("use_path", "user://test_profile_ui.json")
	for id: Variant in ((_run.get("db") as ContentDB).tutorial.get("hints", {}) as Dictionary):
		profile.call("mark_seen", String(id))
	RunStore.clear()
	_run.call("new_run", 4242)
	var state: RunState = _run.get("state")

	# --- Map: the briefing, then hover and ONE click on the 3D yard.
	var map: Node = await _open("res://scenes/run_map.tscn")
	_check("a new run opens on the briefing", _find_button(map, "TO THE BAY") != null)
	_press(_find_button(map, "TO THE BAY"))
	await _frames(3)
	_check("TO THE BAY closes it", _find_button(map, "TO THE BAY") == null and bool(_run.get("briefed")))

	# --- The assembly bay (play-test 4): build the crew, then roll out.
	var bay: Node = map.get("_overlay")
	_check("then the assembly bay opens", bay != null and _find_button(bay, "ROLL OUT") != null)
	var before_parts: String = str(state.crew[0]["parts"])
	bay.call("_step", 0, 3, 1)
	await _frames(2)
	var draft: Array = bay.get("_draft")
	_check("stepping a socket changes the draft, not the run", str(draft[0]) != before_parts and str(state.crew[0]["parts"]) == before_parts)
	_press(_find_button(bay, "ROLL OUT"))
	await _frames(3)
	state = _run.get("state")
	_check("ROLL OUT builds the crew as drafted (one ASSEMBLE action)", state.assembled and str(state.crew[0]["parts"]) == str(draft[0])
		and RunStore.load_saved()["actions"].size() == 1)
	_check("and the bay closes onto the map", map.get("_overlay") == null)
	var targets: Array[int] = RunSim.destinations(state)
	var fight_site: int = -1
	for id: int in targets:
		if String(state.site(id)["type"]) == "skirmish":
			fight_site = id
	if fight_site < 0:
		fight_site = targets[0]
		state.sites[fight_site]["type"] = "skirmish"
	var start_site: int = state.current
	var yard: YardView = map.get("_yard")
	var at: Vector2 = yard.screen_pos(fight_site)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion, true)
	await _frames(3)
	state = _run.get("state")
	_check("hovering a site previews it without moving", state.current == start_site and int(map.get("_hover")) == fight_site
		and (map.get("_preview") as Control).visible)
	_check("the preview says which way the move goes", _find_label_prefix(map.get("_preview"), "FORWARD") != null)
	_click(at)
	await _frames(3)
	state = _run.get("state")
	_check("one click travels there", state.current == fight_site)
	_check("the crew walks the road before the site opens", bool(map.get("_busy")))
	# The walk is tweened in real time; headless frames can run far faster than that.
	for i: int in 80:
		if not bool(map.get("_busy")):
			break
		await create_timer(0.1).timeout
	_check("(the walk ends)", not bool(map.get("_busy")))
	_check("the fight panel offers ENTER FIGHT", _find_button(map, "ENTER FIGHT") != null)
	_check("the move was saved", RunStore.load_saved()["actions"].size() == 2)

	# --- Fight: enter, act once, "quit", resume.
	_press(_find_button(map, "ENTER FIGHT"))
	await _frames(5)
	var combat: Node = current_scene
	_check("ENTER FIGHT opens the combat scene in run mode", combat != null and bool(combat.get("_run_mode")))
	await _settle(combat)
	var combat_state: CombatState = combat.get("_state")
	_check("each machine arrives with its run HP", combat_state.unit(0).hp == int(state.crew[0]["hp"]))
	var opening: Array = CombatBot.plan_unit(combat_state, 0, false)
	if not opening.is_empty():
		combat.call("_act", opening[0])
		await _settle(combat)
	var progressed: int = (combat.get("_actions") as Array).size()
	_check("combat actions are saved as they happen", RunStore.load_saved()["fight"].size() == progressed and progressed > 0)

	# Quit to title and CONTINUE: the run and the fight come back from disk.
	_run.set("active", false)
	_check("CONTINUE reloads the saved run", bool(_run.call("continue_run")))
	combat = await _open("res://scenes/combat.tscn")
	await _settle(combat)
	_check("the fight resumes with the same actions", (combat.get("_actions") as Array).size() == progressed)
	# The agent play-test (2026-10-05): a resumed fight stayed `_busy` with END TURN greyed, and
	# this test did not notice -- `_settle` just ran out of frames.
	_check("the resumed fight can be played (not busy, END TURN live)", not bool(combat.get("_busy"))
		and not ((combat.get("_hud") as Node).get("_end_turn") as Button).disabled)

	# Finish the fight with the bot, then report through CONTINUE as a player would.
	var resumed: CombatState = combat.get("_state")
	var actions: Array = (combat.get("_actions") as Array).duplicate(true)
	var guard: int = 0
	while resumed.outcome == CombatState.ONGOING and guard < 60:
		actions.append_array(CombatBot.take_turn(resumed))
		guard += 1
	combat.set("_actions", actions)
	combat.set("_state", resumed)
	combat.call("_after_events")
	await _frames(3)
	var hud: Node = combat.get("_hud")
	_press(hud.get("_continue"))
	await _frames(5)
	state = _run.get("state")
	_check("the finished fight is reported back to the run", String(state.pending.get("kind", "")) != "fight")
	map = current_scene

	if state.outcome != RunState.ONGOING:
		_check("(run ended in the fight; salvage and refit checks skipped)", true)
	else:
		# --- Salvage: tap a part card.
		var cargo_before: int = state.cargo.size()
		var card: Button = _find_part_card(map)
		_check("the salvage panel shows part cards", card != null)
		if card != null:
			_press(card)
			await _frames(3)
			state = _run.get("state")
			_check("tapping a card loads the part into the hold", state.cargo.size() == cargo_before + 1)

		# --- Garage: tap a hold card, then tap a lit socket; drops; sort; stats; level up.
		if not state.cargo.is_empty():
			_press(_find_button_prefix(map, "GARAGE"))
			await _frames(3)
			var panel: Node = map.get("_garage")
			_check("GARAGE opens the garage", panel != null)
			# 035: every button on the map and in the garage answers the hand (the Juice autoload).
			await create_timer(0.3).timeout
			var plain: Array = []
			var counted: Array = [0]
			_juiced(root, plain, counted)
			_check("every button on screen is juiced (%d buttons, %d not)" % [counted[0], plain.size()], counted[0] > 10 and plain.is_empty())
			var part: String = state.cargo[0]
			var slot: String = String((_run.get("db").parts[part] as Dictionary)["slot"])
			var socket: int = {"chassis": 0, "core": 1, "arm": 3, "module": 4}[slot]
			var old: String = String(state.crew[0]["parts"][socket])
			_press(_find_part_card(panel, part))
			await _frames(2)
			_check("tapping a hold card lifts it", not (panel.get("_held") as Dictionary).is_empty())
			panel.call("_tap_socket", 0, socket)
			await _frames(3)
			state = _run.get("state")
			_check("tap card, tap socket fits the part and the old one goes to the hold",
				String(state.crew[0]["parts"][socket]) == part and (old.is_empty() or state.cargo.has(old)))
			panel.call("_focus_socket", 3)
			await _frames(2)
			var arm: Node3D = panel.call("_part_node", 3)
			_check("hovering a part lights it on the machine", arm != null
				and (panel.call("_part_meshes", arm) as Array).any(func(m: MeshInstance3D) -> bool: return m.material_overlay != null))
			var cargo_now: int = state.cargo.size()
			panel.call("_drop_hold", Vector2.ZERO, {"from": "socket", "crew": 1, "socket": 2})
			await _frames(3)
			state = _run.get("state")
			_check("dropping a fitted part on the hold unfits it", state.cargo.size() == cargo_now + 1
				and String(state.crew[1]["parts"][2]).is_empty())
			panel.set("_sort", "RARITY")
			var order: Array[int] = panel.call("_sorted_hold")
			var parts: Dictionary = _run.get("db").parts
			var sorted_ok: bool = true
			for k: int in range(1, order.size()):
				if int(parts[state.cargo[order[k - 1]]].get("rarity", 1)) < int(parts[state.cargo[order[k]]].get("rarity", 1)):
					sorted_ok = false
			_check("SORT: RARITY puts the rarest first", sorted_ok and order.size() == state.cargo.size())
			var dropped: int = state.cargo.size()
			panel.call("_drop_tab", Vector2.ZERO, {"from": "socket", "crew": 1, "socket": 3}, 1)
			await _frames(3)
			state = _run.get("state")
			_check("a part dropped on a crew tab fits that machine (arm to its empty left socket)",
				not String(state.crew[1]["parts"][2]).is_empty() and state.cargo.size() == dropped)
			var scrap_before: int = state.scrap
			var doomed: String = state.cargo[state.cargo.size() - 1]
			panel.call("_drop_bin", Vector2.ZERO, {"from": "hold", "index": state.cargo.size() - 1})
			await _frames(3)
			state = _run.get("state")
			_check("dropping a part on SCRAP breaks it down for scrap",
				state.scrap == scrap_before + RunSim.scrap_value(_run.get("setup"), doomed))
			# Play-test 4: the SCRAP square is itself the button -- pick a part, click it.
			var held_part: String = state.cargo[0]
			var scrap_now: int = state.scrap
			_press(_find_part_card(panel, held_part))
			await _frames(2)
			_press(_find_button_with_label(panel, "SCRAP"))
			await _frames(3)
			state = _run.get("state")
			_check("pick a part, click SCRAP: it is broken down", state.scrap == scrap_now + RunSim.scrap_value(_run.get("setup"), held_part))
			_check("NUMBERS shows the machine's numbers beside its loadout (027)", _find_label_prefix(panel, "HEALTH") != null)
			# 027: RENAME in the garage is an action in the run, and the crew's next run keeps it.
			panel.call("_rename", "Rusty")
			await _frames(2)
			state = _run.get("state")
			_check("RENAME renames the machine", String(state.crew[int(panel.get("selected"))]["name"]) == "Rusty")
			state.scrap = 100
			panel.call("_rebuild")
			await _frames(2)
			var shown: int = int(panel.get("selected"))
			var level_before: int = int(state.crew[shown].get("level", 0))
			var offer: Array[String] = RunSim.perk_offer(state, _run.get("setup"), shown)
			_press(_find_button_prefix(panel, "LEVEL UP"))
			await _frames(3)
			var pick: Node = panel.get("_picker")
			_check("LEVEL UP opens the perk pick: three perks", pick != null and pick.find_child("perk_2", true, false) != null)
			_check("nothing is bought until a perk is picked", int(state.crew[shown].get("level", 0)) == level_before)
			if pick != null:
				_press(pick.find_child("perk_1", true, false))
			await _frames(3)
			state = _run.get("state")
			_check("picking a perk buys the level and keeps that perk", int(state.crew[shown].get("level", 0)) == level_before + 1
				and (state.crew[shown]["perks"] as Array).back() == offer[1] and panel.get("_picker") == null)
			await create_timer(2.0).timeout
			_press(_find_button(panel, "BACK TO MAP"))
			await _frames(3)
			_check("BACK TO MAP closes the garage", map.get("_garage") == null)

		# --- 011: the workshop's TUNE bench, and salvage left for scrap.
		state = _run.get("state")
		if state.outcome == RunState.ONGOING and state.pending.is_empty():
			state.pending = {"kind": "workshop"}
			state.scrap = 60
			map.call("_refresh")
			await _frames(3)
			var tune_button: Button = _find_button_prefix(map, "UPGRADE A PART")
			_check("a workshop offers UPGRADE A PART", tune_button != null)
			_press(tune_button)
			await _frames(3)
			var tuner: Node = map.get("_tuner")
			_check("UPGRADE A PART opens the upgrade bench", tuner != null)
			if tuner != null:
				var socket: int = -1
				for s: int in 5:
					if socket < 0 and PartTuning.can_tune(_run.get("db").parts, String(state.crew[int(tuner.get("_tab"))]["parts"][s])):
						socket = s
				var machine: int = int(tuner.get("_tab"))
				var part: String = String(state.crew[machine]["parts"][socket])
				_press(tuner.find_child("tune_row_%d" % socket, true, false))
				await _frames(3)
				_check("choosing a part shows its two tunings", tuner.find_child("tune_option_1", true, false) != null)
				var scrap_before: int = state.scrap
				_press(tuner.find_child("tune_option_1", true, false))
				await _frames(3)
				state = _run.get("state")
				_check("pressing an option tunes the part and charges for it",
					String(state.crew[machine]["parts"][socket]) == PartTuning.variant(part, 1)
					and state.scrap == scrap_before - RunSim.tune_cost(_run.get("setup"), part))
				_check("a tuned part is a label, not a button", tuner.find_child("tune_row_%d" % socket, true, false) == null)
				_press(_find_button(tuner, "BACK TO WORKSHOP"))
				await _frames(3)
				_check("BACK TO WORKSHOP closes the bench", map.get("_tuner") == null and _find_button(map, "MOVE ON") != null)
			_press(_find_button(map, "MOVE ON"))
			await _frames(3)
			state = _run.get("state")
			state.pending = RunSim.salvage(state, _run.get("setup"), "skirmish")
			map.call("_refresh")
			await _frames(3)
			var scrap_now: int = state.scrap
			_press(_find_button(map, "TAKE 8 SCRAP INSTEAD"))
			await _frames(3)
			state = _run.get("state")
			_check("salvage can be left for scrap", state.scrap == scrap_now + 8 and state.pending.is_empty())

			# --- 013: a trader, a watchtower and a signal, through their panels.
			state.pending = {"kind": "trader", "stock": ["ar_hammer", "co_slug", "mo_governor:a"], "sold": []}
			state.scrap = 100
			map.call("_refresh")
			await _frames(3)
			var stock_card: Node = map.find_child("stock_0", true, false)
			_check("a trader shows its stock as cards to buy", stock_card != null)
			var cargo: int = state.cargo.size()
			_press(stock_card)
			await _frames(3)
			state = _run.get("state")
			_check("pressing a card buys it (12 scrap)", state.cargo.size() == cargo + 1 and state.scrap == 88)
			var sold: String = state.cargo[0]
			_press(map.find_child("sell_0", true, false))
			await _frames(3)
			state = _run.get("state")
			_check("SELL pays twice the scrap value", state.scrap == 88 + 2 * RunSim.scrap_value(_run.get("setup"), sold))
			_press(_find_button(map, "MOVE ON"))
			await _frames(3)
			state = _run.get("state")
			_check("MOVE ON leaves the trader", state.pending.is_empty())
			state.pending = {"kind": "tower", "scouted": 3}
			map.call("_refresh")
			await _frames(3)
			_press(_find_button(map, "CLIMB DOWN"))
			await _frames(3)
			state = _run.get("state")
			_check("a watchtower's panel closes with CLIMB DOWN", state.pending.is_empty())
			state.pending = {"kind": "signal", "event": "fuel_cache"}
			var scrap_signal: int = state.scrap
			map.call("_refresh")
			await _frames(3)
			_press(map.find_child("option_1", true, false))
			await _frames(3)
			state = _run.get("state")
			_check("a signal's option does what its button says (SELL THE DRUMS: +14)", state.scrap == scrap_signal + 14 and state.pending.is_empty())

	RunStore.clear()
	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	print("")
	quit(1 if _failed > 0 else 0)


func _open(path: String) -> Node:
	change_scene_to_file(path)
	await _frames(5)
	return current_scene


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _settle(scene: Node) -> void:
	for i: int in 3000:
		await process_frame
		if i > 5 and not bool(scene.get("_busy")):
			break
	await process_frame


func _press(button: Variant) -> void:
	if button is Button and is_instance_valid(button):
		(button as Button).pressed.emit()


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text and (node as Button).is_visible_in_tree() and not node.is_queued_for_deletion():
		return node
	for child: Node in node.get_children():
		var found: Button = _find_button(child, text)
		if found != null:
			return found
	return null


func _click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		root.push_input(click, true)


func _find_button_with_label(node: Node, text: String) -> Button:
	if node is Button and not node.is_queued_for_deletion() and _has_label(node, text):
		return node
	for child: Node in node.get_children():
		var found: Button = _find_button_with_label(child, text)
		if found != null:
			return found
	return null


func _find_button_prefix(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text.begins_with(text) and (node as Button).is_visible_in_tree() and not node.is_queued_for_deletion():
		return node
	for child: Node in node.get_children():
		var found: Button = _find_button_prefix(child, text)
		if found != null:
			return found
	return null


func _find_label_prefix(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text.begins_with(text) and not node.is_queued_for_deletion():
		return node
	for child: Node in node.get_children():
		var found: Label = _find_label_prefix(child, text)
		if found != null:
			return found
	return null


## A part card is a Button whose label children name a part; `name_like` narrows it.
func _find_part_card(node: Node, id: String = "") -> Button:
	if node is Button and not node.is_queued_for_deletion() and (node as Button).text.is_empty() \
			and (node as Button).custom_minimum_size.y >= 180 and not (node as Button).disabled:
		if id.is_empty() or _has_label(node, PartText.name_of(_run.get("db").parts, id)):
			return node
	for child: Node in node.get_children():
		var found: Button = _find_part_card(child, id)
		if found != null:
			return found
	return null


func _has_label(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child: Node in node.get_children():
		if _has_label(child, text):
			return true
	return false


func _juiced(node: Node, plain: Array, counted: Array) -> void:
	if node is BaseButton and not node.has_meta("no_juice"):
		counted[0] += 1
		if not node.has_meta("juiced"):
			plain.append(node.name)
	for child: Node in node.get_children():
		_juiced(child, plain, counted)


func _check(label: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s" % label)
