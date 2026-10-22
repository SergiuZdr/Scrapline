extends SceneTree

## Onboarding (012): the profile, the glossary, first-time hints, and the shakedown played
## start to finish through real clicks -- each step moving on because the thing it asked for
## actually happened on the board.
##
##   godot --headless --path . --script res://tools/verify_onboarding.gd
##
## Uses a test profile, never the player's.

const PROFILE_PATH: String = "user://test_profile_onboarding.json"
## 082: hints whose screens belong to other work: the words exist, the call site does not yet.
## Each leaves this list the day its screen calls it (the coverage check then holds it).
const HINTS_WAITING: Array = ["ladder", "new_part"]

var _passed: int = 0
var _failed: int = 0
var _scene: Node
var _db: ContentDB


func _initialize() -> void:
	print("")
	print("=== onboarding ===")
	create_timer(300.0).timeout.connect(func() -> void:
		print("  FAIL  watchdog: the test did not finish (a script error above?)")
		quit(1))
	_run.call_deferred()


func _run() -> void:
	_db = ContentDB.load_all()
	var profile: Node = root.get_node("Profile")
	_clean()
	profile.call("use_path", PROFILE_PATH)
	_test_profile(profile)
	_test_glossary()
	_test_content()
	_test_copy()
	_test_coverage()
	await _test_hints(profile)
	await _test_rooted()
	await _test_shakedown(profile)
	_clean()
	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	print("")
	quit(1 if _failed > 0 else 0)


func _test_profile(profile: Node) -> void:
	_check("a fresh profile has not played the shakedown", not bool(profile.call("tutorial_done")))
	profile.call("mark_seen", "map")
	profile.call("mark_seen", "map")
	profile.call("finish_tutorial")
	profile.call("use_path", PROFILE_PATH)
	_check("the tutorial flag and a hint survive a reload", bool(profile.call("tutorial_done")) and bool(profile.call("seen", "map")))
	var saved: Dictionary = SaveFile.load_from(PROFILE_PATH).data
	_check("marking a hint twice stores it once", (saved["seen_tips"] as Array).count("map") == 1)
	profile.call("reset_hints")
	_check("reset brings the hints and the shakedown back", not bool(profile.call("seen", "map")) and not bool(profile.call("tutorial_done")))


func _test_glossary() -> void:
	var words: Dictionary = _db.glossary
	var text: String = Glossary.linkify("A piercing shot at a scrap pile, [boxed] heat.", words)
	_check("terms become links (pierce, shot)", text.contains("[url=pierce]") and text.contains("[url=shot]"))
	_check("the longest form wins (scrap pile, not scrap)", text.contains("[url=pile]") and not text.contains("[url=scrap]"))
	_check("brackets in the text are escaped", text.contains("[lb]boxed[rb]"))
	_check("words inside other words are not links (Plating is not plate)",
		not Glossary.linkify("Extra Plating", words).contains("[url="))
	var lance: PackedStringArray = Glossary.terms_in(PartText.summary(_db.parts, "ar_lance", _db.combat_abilities), words)
	_check("a part's summary links its terms %s" % [lance], lance.has("shot") and lance.has("pierce") and lance.has("heat"))
	var forms: Dictionary = {}
	var clash: String = ""
	var groups: Array = words.get("groups", [])
	var grouped: bool = true
	for id: Variant in (words["terms"] as Dictionary):
		var term: Dictionary = words["terms"][id]
		grouped = grouped and groups.has(String(term.get("group", "")))
		for form: Variant in (term.get("forms", []) as Array):
			if forms.has(String(form).to_lower()):
				clash = String(form)
			forms[String(form).to_lower()] = id
	_check("no spelling links to two terms %s" % clash, clash.is_empty())
	_check("every term sits in a listed group", grouped)
	# Every ability, enemy kind and perk the game names is explained somewhere.
	var missing: PackedStringArray = []
	for id: Variant in _db.combat_abilities:
		if not String(id).begins_with("_") and not forms.has(String((_db.combat_abilities[id] as Dictionary).get("name", id)).to_lower()):
			missing.append(String(id))
	for id: Variant in _db.enemy_kinds:
		if not String(id).begins_with("_") and not forms.has(String(id).to_lower()):
			missing.append(String(id))
	_check("every ability and enemy kind has a glossary card %s" % [missing], missing.is_empty())


## The shakedown's data is well formed: every step's `until` is one the coach knows.
func _test_content() -> void:
	var known: Array = ["next", "selected", "moved", "armed", "attacked", "ability", "prop", "round", "won"]
	var ok: bool = true
	for step: Dictionary in (_db.tutorial.get("steps", []) as Array):
		ok = ok and known.has(String(step.get("until", "next")))
	_check("every shakedown step ends on something the coach can see", ok)
	_check("the shakedown is never a run's fight", bool((_db.fights["shakedown"] as Dictionary).get("tutorial", false)))
	var hints: Dictionary = _db.tutorial.get("hints", {})
	var full: bool = true
	for id: Variant in hints:
		full = full and not String((hints[id] as Dictionary).get("title", "")).is_empty() and not String((hints[id] as Dictionary).get("text", "")).is_empty()
	_check("%d first-time hints, each with a title and text" % hints.size(), hints.size() >= 8 and full)


## 082 (A11, A13): the words the player reads tell the truth and carry no developer notes.
## A machine is ROOTED once it attacks (only a LINE moves after), so "in any order" is a lie;
## "(050)" is an iteration number that leaked into a card.
func _test_copy() -> void:
	var texts: Array = []   # [where, text]
	for step: Dictionary in (_db.tutorial.get("steps", []) as Array):
		texts.append(["tutorial " + String(step.get("id", "?")), String(step.get("title", "")) + " " + String(step.get("text", ""))])
	var hints: Dictionary = _db.tutorial.get("hints", {})
	for id: Variant in hints:
		texts.append(["hint " + String(id), String((hints[id] as Dictionary).get("title", "")) + " " + String((hints[id] as Dictionary).get("text", ""))])
	var terms: Dictionary = _db.glossary.get("terms", {})
	for id: Variant in terms:
		texts.append(["glossary " + String(id), String((terms[id] as Dictionary).get("name", "")) + " " + String((terms[id] as Dictionary).get("text", ""))])
	var leak := RegEx.create_from_string("\\(\\d{3}\\)")
	var lies: PackedStringArray = []
	var leaks: PackedStringArray = []
	for entry: Array in texts:
		if String(entry[1]).to_lower().contains("any order"):
			lies.append(String(entry[0]))
		if leak.search(String(entry[1])) != null:
			leaks.append(String(entry[0]))
	_check("no player text says MOVE and ATTACK go \"in any order\" %s" % [lies], lies.is_empty() and texts.size() > 50)
	_check("no (NNN) developer leaks in tutorial, hint or glossary text %s" % [leaks], leaks.is_empty())
	var rooted: Dictionary = terms.get("rooted", {})
	_check("ROOTED has its own glossary card, linked from the word",
		not rooted.is_empty() and (rooted.get("forms", []) as Array).has("rooted") and String(rooted.get("text", "")).contains("LINE")
		and Glossary.linkify("it is rooted", _db.glossary).contains("[url=rooted]"))
	_check("the welcome and the turn card teach the rooted rule",
		String(((_db.tutorial["steps"] as Array)[0] as Dictionary)["text"]).contains("rooted")
		and String((terms["turn"] as Dictionary)["text"]).contains("rooted"))


## Every hint id the screens ask for has words, every hint has a screen that asks for it, and
## every site on the map has a glossary card.
func _test_coverage() -> void:
	var used: Dictionary = {}
	var call := RegEx.create_from_string("Hints\\.show_(?:once|with)\\([^,]+,\\s*\"([a-z_]+)\"")
	for path: String in _scripts("res://scripts"):
		for found: RegExMatch in call.search_all(FileAccess.get_file_as_string(path)):
			used[found.get_string(1)] = path.get_file()
	var hints: Dictionary = _db.tutorial.get("hints", {})
	var unknown: PackedStringArray = []
	for id: Variant in used:
		if not hints.has(id):
			unknown.append(String(id))
	_check("every hint a screen shows has its words in tutorial.json %s" % [unknown], unknown.is_empty() and used.size() >= 8)
	var unused: PackedStringArray = []
	var waiting: PackedStringArray = []
	for id: Variant in hints:
		if used.has(id):
			continue
		if HINTS_WAITING.has(id):
			waiting.append(String(id))
		else:
			unused.append(String(id))
	_check("every hint in tutorial.json is shown by some screen %s" % [unused], unused.is_empty())
	if not waiting.is_empty():
		print("  note  hints with words but no call site yet: %s" % [waiting])
	var terms: Dictionary = _db.glossary.get("terms", {})
	var bare: PackedStringArray = []
	for site: Variant in (_db.run_rules.get("site_weights", {}) as Dictionary):
		var named: bool = terms.has(site)
		for id: Variant in terms:
			named = named or String((terms[id] as Dictionary).get("name", "")).to_lower().contains(String(site))
		if not named:
			bare.append(String(site))
	_check("every site type on the map has a glossary card %s" % [bare], bare.is_empty())


func _scripts(dir: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var access: DirAccess = DirAccess.open(dir)
	if access == null:
		return out
	for file: String in access.get_files():
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	for sub: String in access.get_directories():
		out.append_array(_scripts(dir.path_join(sub)))
	return out


## 082 (A11): Knuckles (a BRAWLER) armed before it has moved warns that firing ends its move;
## Needle (a LINE) does not; a machine that has attacked shows ROOTED on its card.
func _test_rooted() -> void:
	var packed: PackedScene = load("res://scenes/combat.tscn")
	_scene = packed.instantiate()
	root.add_child(_scene)
	await _settle()
	await create_timer(0.6).timeout
	await _settle()
	var state: CombatState = _scene.get("_state")
	var hud: CombatHUD = _scene.get("_hud")
	var knuckles: GridUnit = state.unit(0)
	_check("the practice fight's first machine is Knuckles, a brawler", knuckles.name == "Knuckles" and not knuckles.move_after_attack)
	_click_tile(Vector2i(knuckles.x, knuckles.y))
	await _settle()
	_check("no warning while nothing is armed", String(hud.call("warning_text")).is_empty())
	_click_control(hud.control_for("weapon"))
	await _settle()
	var armed: bool = bool(_scene.get("_armed"))
	var warning: String = String(hud.call("warning_text"))
	_check("arming Knuckles before it moves says \"%s\"" % warning, armed and warning.begins_with("Firing ends Knuckles's move"))
	var line: RichTextLabel = hud.find_child("rooted_warning", true, false)
	_check("the warning is on screen, and \"rooted\" in it is a glossary link",
		line != null and line.is_visible_in_tree() and line.text.contains("[url=rooted]"))
	_click_control(hud.control_for("weapon"))   # the same weapon again: back to moving
	await _settle()
	_check("disarming clears it", not bool(_scene.get("_armed")) and String(hud.call("warning_text")).is_empty())
	var needle: GridUnit = state.unit(1)
	_click_tile(Vector2i(needle.x, needle.y))
	await _settle()
	_click_control(hud.control_for("weapon"))
	await _settle()
	_check("arming Needle, a LINE machine, warns of nothing (it moves after firing)",
		needle.move_after_attack and bool(_scene.get("_armed")) and String(hud.call("warning_text")).is_empty())
	var settings: Control = hud.find_child("settings_button", true, false)
	_check("the HUD has its settings gear (shown once the sheet exists: %s)" % ResourceLoader.exists("res://scripts/ui/settings_sheet.gd"),
		settings != null and settings.visible == ResourceLoader.exists("res://scripts/ui/settings_sheet.gd"))
	_scene.queue_free()
	_scene = null
	await process_frame
	# The card: a machine that attacked and cannot move reads ROOTED where MOVE was; a LINE never does.
	var solo: CombatHUD = CombatHUD.new()
	solo.glossary = _db.glossary
	root.add_child(solo)
	var card: Dictionary = {"ref": 0, "name": "Knuckles", "detail": "Brute  ·  Brawler  ·  move 3", "hp": 9, "max_hp": 9,
		"alive": true, "can_move": false, "can_act": false, "acted": true, "move_after_attack": false, "selected": true}
	solo.set_crew([card])
	var chip: String = _card_chip(solo)
	var line_card: Dictionary = card.duplicate()
	line_card["move_after_attack"] = true
	solo.set_crew([line_card])
	_check("a card that has attacked reads ROOTED (%s); a LINE's does not (%s)" % [chip, _card_chip(solo)],
		chip == "ROOTED" and _card_chip(solo) == "MOVE")
	solo.queue_free()


func _card_chip(hud: CombatHUD) -> String:
	for label: Node in hud.find_children("*", "Label", true, false):
		if (label as Label).text in ["MOVE", "ROOTED"]:
			return (label as Label).text
	return "?"


func _test_hints(profile: Node) -> void:
	var host := Control.new()
	host.size = Vector2(1920, 1080)
	root.add_child(host)
	var shown: Control = Hints.show_once(host, "map", _db, Vector2(100, 100))
	_check("a hint shows the first time", shown != null and host.has_node("hint_map"))
	var again: Control = Hints.show_once(host, "map", _db, Vector2(100, 100))
	# 039: a hint is a balloon -- the panel and its tail.
	_check("asking again does not stack a second one", again == shown
		and host.get_child_count() == 2 and host.has_node("hint_tail_map"))
	(shown.find_child("got_it", true, false) as Button).pressed.emit()
	await process_frame
	await process_frame
	_check("GOT IT closes it and the profile remembers", not host.has_node("hint_map") and bool(profile.call("seen", "map")))
	_check("once seen, it never shows again", Hints.show_once(host, "map", _db, Vector2(100, 100)) == null)
	host.queue_free()
	# The rest of the test plays the shakedown: no callout may sit over its clicks.
	for id: Variant in (_db.tutorial.get("hints", {}) as Dictionary):
		profile.call("mark_seen", String(id))


func _test_shakedown(profile: Node) -> void:
	var packed: PackedScene = load("res://scenes/shakedown.tscn")
	_scene = packed.instantiate()
	root.add_child(_scene)
	await _settle()
	var coach: Node = _scene.get("_coach")
	_check("the shakedown opens with its coach on the first step", coach != null and String(coach.call("current_id")) == "welcome")
	_check("its board is the tutorial's", (_scene.get("_setup") as CombatSetup).fight_id == "shakedown")
	_press_text(coach, "NEXT")
	await _settle()
	_check("NEXT moves to MOVE", String(coach.call("current_id")) == "move")

	var target: Variant = coach.call("_board_target")
	_check("MOVE marks a hex beside a runner %s" % [target], target != null)
	if target != null:
		var marker: Node3D = _scene.get("_coach_marker")
		_check("the marker stands on that hex", marker != null and marker.visible)
		_click_tile(target)
		await _settle()
	_check("walking there passes MOVE", String(coach.call("current_id")) == "intents")
	_press_text(coach, "NEXT")
	await _settle()
	_check("then ARM A WEAPON", String(coach.call("current_id")) == "arm")
	var hud: CombatHUD = _scene.get("_hud")
	_click_control(hud.control_for("weapon"))
	await _settle()
	_check("clicking a weapon passes ARM", String(coach.call("current_id")) == "fire")
	target = coach.call("_board_target")
	_check("FIRE marks the nearest runner", target != null)
	if target != null:
		_click_tile(target)
		await _settle()
		_click_tile(target)
		await _settle()
	_check("aiming and firing passes FIRE", String(coach.call("current_id")) == "heat")
	_press_text(coach, "NEXT")
	await _settle()
	_check("then ABILITIES", String(coach.call("current_id")) == "focus")
	var strider: GridUnit = (_scene.get("_state") as CombatState).unit(2)
	_click_tile(Vector2i(strider.x, strider.y))
	await _settle()
	_check("clicking the Strider picks it, and the marker moves to the ability button",
		int(_scene.get("_selected")) == 2 and coach.call("_button_target") != null)
	_click_control(hud.control_for("ability"))
	await _settle()
	_check("FOCUS passes ABILITIES", String(coach.call("current_id")) == "drum")
	_click_control(hud.control_for("weapon"))
	await _settle()
	target = coach.call("_board_target")
	_check("the drum is marked %s" % [target], target != null)
	if target != null:
		_click_tile(target)
		await _settle()
		_click_tile(target)
		await _settle()
	_check("shooting the drum passes USE THE YARD", String(coach.call("current_id")) == "end")
	_click_control(hud.control_for("end_turn"))
	await _settle()
	var state: CombatState = _scene.get("_state")
	_check("END TURN passes it (round %d)" % state.round_number, String(coach.call("current_id")) == "piles")
	_press_text(coach, "NEXT")
	await _settle()
	_check("then FINISH IT", String(coach.call("current_id")) == "rout")

	# Finish the fight with the combat bot on a replay, then hand the scene the result, the
	# way verify_run_ui finishes a run fight: the rest of the shakedown is ordinary combat.
	var actions: Array = (_scene.get("_actions") as Array).duplicate(true)
	var finishing: CombatState = CombatSim.replay(_scene.get("_setup"), actions)
	var guard: int = 0
	while finishing.outcome == CombatState.ONGOING and guard < 40:
		actions.append_array(CombatBot.take_turn(finishing))
		guard += 1
	_scene.set("_actions", actions)
	_scene.set("_state", finishing)
	_scene.call("_after_events")
	await _settle()
	state = finishing
	_check("the shakedown can be won (%d rounds)" % state.round_number, state.outcome == CombatState.WON)
	_check("winning brings up the last step", String(coach.call("current_id")) == "done")
	_press_text(coach, "TITLE")
	await _settle()
	_check("finishing marks the shakedown played", bool(profile.call("tutorial_done")))


func _press_text(node: Node, text: String) -> void:
	var button: Button = _find_button(node, text)
	if button == null:
		_check("(button %s found)" % text, false)
		return
	_click_control(button)


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text and not node.is_queued_for_deletion() and (node as Button).is_visible_in_tree():
		return node
	for child: Node in node.get_children():
		var found: Button = _find_button(child, text)
		if found != null:
			return found
	return null


func _settle() -> void:
	for i: int in 2400:
		await process_frame
		if _scene == null or not is_instance_valid(_scene) or (not bool(_scene.get("_busy")) and i > 5):
			break
	await process_frame


func _click_tile(cell: Vector2i) -> void:
	var camera: Camera3D = _scene.get("_camera")
	var world: Vector3 = _scene.call("_to_world", cell.x, cell.y)
	_click(camera.unproject_position(world))


func _click_control(control: Control) -> void:
	if control == null:
		_check("(control to click exists)", false)
		return
	_click(control.get_global_rect().get_center())


func _click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		root.push_input(event, true)


func _clean() -> void:
	var directory: DirAccess = DirAccess.open("user://")
	for path: String in [PROFILE_PATH, SaveFile.backup_of(PROFILE_PATH), SaveFile.temp_of(PROFILE_PATH)]:
		if directory != null and FileAccess.file_exists(path):
			directory.remove(path)


func _check(label: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s" % label)
