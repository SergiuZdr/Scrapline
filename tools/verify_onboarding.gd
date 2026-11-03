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
const HINTS_WAITING: Array = []

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
	await _test_skip(profile)
	await _test_objectives(profile)
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
		# 086: `elite_affixes` is not a kind (its affixes are checked below).
		if not String(id).begins_with("_") and String(id) != "elite_affixes" and not forms.has(String(id).to_lower()):
			missing.append(String(id))
	_check("every ability and enemy kind has a glossary card %s" % [missing], missing.is_empty())
	# 086: every elite affix, every rule a perk or a full set gives, and the words of builds that
	# change rules (spoils, rule perks, set rules, drawbacks) each have a card a screen links to.
	var text_script: Script = load("res://scripts/ui/part_text.gd")
	var bare: PackedStringArray = []
	var affixes: Dictionary = _db.enemy_kinds.get("elite_affixes", {})
	for id: Variant in affixes:
		var tag: String = String((text_script.call("affix", _db.enemy_kinds, words, String(id)) as Dictionary)["name"])
		if String(id).begins_with("_"):
			continue
		if not (words["terms"] as Dictionary).has(String(id)) or not Glossary.terms_in("ELITE: " + tag, words).has(String(id)):
			bare.append("affix " + String(id))
	var verbs: Dictionary = {}
	for id: Variant in _db.perks:
		var perk: Variant = _db.perks[id]
		if perk is Dictionary and bool(text_script.call("is_rule_perk", perk)):
			for line: String in (text_script.call("verb_lines", (perk as Dictionary).get("grid", {})) as PackedStringArray):
				verbs[line] = "perk " + String(id)
	for maker: Variant in _db.makers:
		if String(maker).begins_with("_"):
			continue
		var rule: Array = text_script.call("set_rule", _db.makers, String(maker))
		if not rule.is_empty():
			var sets: Dictionary = (_db.makers[maker] as Dictionary).get("sets", {})
			for line: String in (text_script.call("verb_lines", sets.get(str(rule[0]), {})) as PackedStringArray):
				verbs[line] = "set " + String(maker)
	for line: Variant in verbs:
		if Glossary.terms_in(String(line), words).is_empty():
			bare.append("%s (%s)" % [verbs[line], line])
	for pair: Array in [["spoils", "TORN FROM THE TRACKER"], ["rule_perk", "NEW RULE"], ["set_rule", "full set"], ["drawback", "DRAWBACK: it hits your own too"],
			["affix", "elite affix"]]:
		if not Glossary.terms_in(String(pair[1]), words).has(String(pair[0])):
			bare.append(String(pair[0]))
	_check("086: every affix (%d), every rule verb a perk or set gives (%d) and spoils, rule perks, set rules and drawbacks have a linked card %s" % [
		affixes.size(), verbs.size(), bare], bare.is_empty() and verbs.size() >= 5)


## The shakedown's data is well formed: every step's `until` is one the coach knows.
func _test_content() -> void:
	var known: Array = ["next", "selected", "moved", "armed", "attacked", "ability", "heat_choice", "cancelled", "fell", "torn",
		"prop", "round", "won"]
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
		if used.has(id) or String(id).begins_with("obj_"):
			continue   # 088: the objective callouts are shown by objective_callout.gd (checked in _test_objectives)
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


## 088 (A15): the shakedown played start to finish by real clicks, every coached mark followed as the
## player would: the scripted line must cancel an intent, drop a runner into the pit, pay heat for a
## tear and win, and no move ring may ever stand on a hex an intent aims at.
func _test_shakedown(profile: Node) -> void:
	var packed: PackedScene = load("res://scenes/shakedown.tscn")
	_scene = packed.instantiate()
	root.add_child(_scene)
	await _settle()
	var coach: Node = _scene.get("_coach")
	_check("the shakedown opens with its coach on the first step", coach != null and String(coach.call("current_id")) == "welcome")
	_check("its board is the tutorial's", (_scene.get("_setup") as CombatSetup).fight_id == "shakedown")
	var steps: Array = _db.tutorial.get("steps", [])
	_check("it has 12 steps (%d)" % steps.size(), steps.size() == 12)
	_check("its first card has NEXT and SKIP", _find_button(coach, "NEXT") != null and _find_button(coach, "SKIP") != null)
	var names: PackedStringArray = []
	for step: Dictionary in steps:
		for crew: String in ["Knuckles", "Needle", "Relay"]:
			if String(step.get("text", "")).contains(crew) and not names.has(crew):
				names.append(crew)
	_check("the coach calls the crew by name %s" % [names], names.size() == 3)
	_press_text(coach, "NEXT")
	await _settle()
	var state: CombatState = _scene.get("_state")
	_check("NEXT moves to READ THE ENEMY", String(coach.call("current_id")) == "threat")
	var incoming: Dictionary = CombatSim.incoming(state)
	var relay_dies: bool = false
	for hurt: Dictionary in (incoming["units"] as Array):
		relay_dies = relay_dies or (int(hurt["ref"]) == 2 and bool(hurt["killed"]))
	_check("a real threat: ending the turn now would wreck Relay", relay_dies)
	var gunner: GridUnit = state.unit(11)
	_check("the marker stands on the Yard Gunner", coach.call("_board_target") == Vector2i(gunner.x, gunner.y)
		and (_scene.get("_coach_marker") as Node3D).visible)
	_press_text(coach, "NEXT")
	await _settle()
	_check("then BREAK IT FIRST", String(coach.call("current_id")) == "arm")
	_rings = 0
	_ring_on_red = []
	await _drive(coach, "arm")
	_check("picking Needle and its Rail Lance passes it", String(coach.call("current_id")) == "cancel"
		and int(_scene.get("_selected")) == 1 and int(_scene.get("_weapon")) == 1)
	await _drive(coach, "cancel")
	state = _scene.get("_state")
	_check("Needle's shot kills the Yard Gunner before it fires: its intent is CANCELLED (INTENT_LOST)",
		not state.unit(11).alive and _event(state, GridEv.INTENT_LOST, 11, 1))
	_check("then MOVE", String(coach.call("current_id")) == "move")
	await _drive(coach, "move")
	state = _scene.get("_state")
	_check("Knuckles walks to the ring (%d,%d)" % [state.unit(0).x, state.unit(0).y], Vector2i(state.unit(0).x, state.unit(0).y) == Vector2i(2, 4))
	await _drive(coach, "pit")
	state = _scene.get("_state")
	_check("the hammer shoves the Yard Runner into the pit (FELL), and tears nothing on it",
		_event(state, GridEv.FELL, 0, 10) and not _event(state, GridEv.PART_TORN, 0, 10))
	_check("then HEAT IS A CHOICE", String(coach.call("current_id")) == "heat")
	await _drive(coach, "heat")
	state = _scene.get("_state")
	_check("Relay pays for FOCUS", _event(state, GridEv.ABILITY, 2, -1))
	await _drive(coach, "tear")
	state = _scene.get("_state")
	var boss: GridUnit = state.unit(12)
	_check("the focused Scattergun tears the Runner Boss's lance off, cancelling its shot too (%d HP left)" % boss.hp,
		boss.alive and _event(state, GridEv.PART_TORN, 2, 12) and _event(state, GridEv.INTENT_LOST, 12, 2))
	_check("the heat was paid: Relay is at %d heat (FOCUS 1 + the shot 1)" % state.unit(2).heat, state.unit(2).heat == 2)
	_check("then END TURN", String(coach.call("current_id")) == "end")
	await _drive(coach, "end")
	state = _scene.get("_state")
	_check("END TURN passes it (round %d) and the crew took nothing: every shot was cancelled" % state.round_number,
		String(coach.call("current_id")) == "piles" and _crew_hp(state) == _crew_max(state))
	_check("%d move rings, none on an aimed hex %s" % [_rings, _ring_on_red], _rings >= 2 and _ring_on_red.is_empty())
	_check("the fuel drum (no step of its own) still stands at (0,4) after the coached round",
		String((state.props.get(Vector2i(0, 4), {}) as Dictionary).get("kind", "")) == "barrel")
	_press_text(coach, "NEXT")
	await _settle()
	_check("then FINISH IT", String(coach.call("current_id")) == "rout")
	# The rest is ordinary combat: the combat bot picks the moves, each one made by real clicks.
	var guard: int = 0
	state = _scene.get("_state")
	while state.outcome == CombatState.ONGOING and guard < 6:
		for action: Array in CombatBot.take_turn(CombatSim.replay(_scene.get("_setup"), _scene.get("_actions"))):
			await _click_action(action)
			state = _scene.get("_state")
			if state.outcome != CombatState.ONGOING:
				break
		guard += 1
	_check("the shakedown is won by clicks (round %d)" % state.round_number, state.outcome == CombatState.WON)
	_check("winning brings up the last step", String(coach.call("current_id")) == "done")
	_press_text(coach, "TITLE")
	await _settle()
	_check("finishing marks the shakedown played", bool(profile.call("tutorial_done")))
	if is_instance_valid(_scene):
		_scene.queue_free()
	_scene = null
	await create_timer(0.3).timeout
	if current_scene != null:
		current_scene.queue_free()
	await process_frame


## 088 (the user): SKIP on the first card ends the shakedown as if it were played.
func _test_skip(profile: Node) -> void:
	profile.call("reset_hints")
	for id: Variant in (_db.tutorial.get("hints", {}) as Dictionary):
		profile.call("mark_seen", String(id))
	_check("(a fresh shakedown is owed)", not bool(profile.call("tutorial_done")))
	_scene = (load("res://scenes/shakedown.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	await _settle()
	var coach: Node = _scene.get("_coach")
	_press_text(coach, "SKIP")
	await _settle()
	_check("SKIP on the first card marks the shakedown played, and that it was skipped",
		bool(profile.call("tutorial_done")) and bool(profile.call("seen", "shakedown_skipped")))
	_check("and goes to the last card (START A RUN / TITLE) with the board shut behind it",
		String(coach.call("current_id")) == "done" and _find_button(coach, "START A RUN") != null
		and (coach.get_node("coach_blocker") as Control).visible)
	var actions: int = (_scene.get("_actions") as Array).size()
	var knuckles: GridUnit = (_scene.get("_state") as CombatState).unit(0)
	_click_tile(Vector2i(knuckles.x, knuckles.y - 1))
	await _settle()
	_check("a click on the board does nothing once skipped", (_scene.get("_actions") as Array).size() == actions)
	profile.call("use_path", PROFILE_PATH)
	_check("the profile kept it", bool(profile.call("tutorial_done")))
	_scene.queue_free()
	_scene = null
	await process_frame


## 088 (A14): the first time an objective appears the coach points at its piece, once per profile.
func _test_objectives(profile: Node) -> void:
	var callout: GDScript = load("res://scripts/combat/objective_callout.gd")
	var words: Dictionary = _db.story.get("objectives", {})
	var kinds: Array = callout.get_script_constant_map()["KINDS"]
	var missing: PackedStringArray = []
	for kind: String in kinds:
		var w: Dictionary = words.get(kind, {})
		if String(w.get("title", "")).is_empty() or String(w.get("text", "")).is_empty() \
				or not (_db.tutorial.get("hints", {}) as Dictionary).has("obj_" + kind):
			missing.append(kind)
	_check("every objective callout (%s) has its words in story.json and is a hint" % [kinds], missing.is_empty() and kinds.size() >= 5)
	# What it points at, on each kind of board.
	var cases: Array = [
		["defend", {"type": "defend", "rounds": 4, "caches": [{"x": 2, "y": 6}, {"x": 5, "y": 6}]}, Vector2i(2, 6)],
		["salvage", {"type": "salvage", "need": 2, "piles": [{"x": 6, "y": 7}, {"x": 1, "y": 7}]}, Vector2i(1, 7)],
		["hold", {"type": "hold", "need": 3, "cells": [{"x": 3, "y": 4}, {"x": 4, "y": 4}, {"x": 3, "y": 3}]}, Vector2i(3, 4)],
		["hack", {"type": "hack", "need": 2, "cells": [{"x": 5, "y": 4}, {"x": 2, "y": 3}]}, Vector2i(2, 3)],
		["rout", {"type": "rout"}, null],
	]
	for case: Array in cases:
		var fight: Dictionary = (_db.fights["proto_yard"] as Dictionary).duplicate(true)
		fight["objective"] = case[1]
		var setup: CombatSetup = CombatSetup.build(fight, _db.combat_rules, _db.parts, _db.tiles, _db.effectiveness, 3)
		var found: Dictionary = callout.call("target", CombatSim.start(setup))
		if case[2] == null:
			_check("ROUT gets no callout (the shakedown teaches it)", found.is_empty())
		else:
			_check("%s points at %s (%s)" % [case[0], case[2], found], String(found.get("kind", "")) == case[0] and found.get("cell") == case[2])
	var survive: Dictionary = (_db.fights["proto_yard"] as Dictionary).duplicate(true)
	survive["objective"] = {"type": "survive", "rounds": 6, "every": 2, "count": 2}
	var s_state: CombatState = CombatSim.start(CombatSetup.build(survive, _db.combat_rules, _db.parts, _db.tiles, _db.effectiveness, 3))
	var s_found: Dictionary = callout.call("target", s_state)
	_check("survive points at its first wave mark, or at nothing before one is marked (%s, marks %s)" % [s_found, s_state.wave_marks],
		String(s_found.get("kind", "")) == "survive" and (s_found.get("cell") == null if s_state.wave_marks.is_empty() else s_state.wave_marks.has(s_found.get("cell"))))
	var reinf: Dictionary = (_db.fights["proto_yard"] as Dictionary).duplicate(true)
	reinf["reinforcements"] = {"from_round": 2, "waves": [1]}
	var r_state: CombatState = CombatSim.start(CombatSetup.build(reinf, _db.combat_rules, _db.parts, _db.tiles, _db.effectiveness, 3))
	var r_found: Dictionary = callout.call("reinforcement_target", r_state)
	_check("REINFORCEMENTS point at a wave mark (%s, marks %s), and have their words in story.json" % [r_found, r_state.wave_marks],
		String(r_found.get("kind", "")) == "reinforcements" and r_state.wave_marks.has(r_found.get("cell"))
		and not String((words.get("reinforcements", {}) as Dictionary).get("text", "")).is_empty()
		and (_db.tutorial.get("hints", {}) as Dictionary).has("obj_reinforcements"))
	_check("a SURVIVE fight's own waves are not reinforcements", (callout.call("reinforcement_target", s_state) as Dictionary).is_empty())
	var keeper: Dictionary = callout.call("target", CombatSim.start(CombatSetup.build(_db.fights["sorting_gate"], _db.combat_rules,
		_db.parts, _db.tiles, _db.effectiveness, 3)))
	_check("a boss fight gets no callout (its strip says how to win)", keeper.is_empty())

	# On the board, by real clicks: shown the first time, GOT IT, never again.
	profile.call("reset_hints")
	for id: Variant in (_db.tutorial.get("hints", {}) as Dictionary):
		if not String(id).begins_with("obj_"):
			profile.call("mark_seen", String(id))
	for pass_no: int in 2:
		var scene: Node = await _open_fight("container_row")
		var shown: Control = await _wait_node(_hud_of(scene), "hint_obj_defend", 6.0)
		if pass_no == 0:
			var state: CombatState = scene.get("_state")
			var cache: GridUnit = state.caches()[0]
			var marker: Node3D = scene.get("_coach_marker")
			_check("DEFEND, first time: the callout is up, its ring on the cache (%d,%d)" % [cache.x, cache.y],
				shown != null and marker != null and marker.visible
				and marker.position.distance_to(scene.call("_to_world", cache.x, cache.y)) < 1.0)
			var text: String = ""
			for label: Node in (shown.find_children("*", "RichTextLabel", true, false) if shown != null else []):
				text += (label as RichTextLabel).get_parsed_text()
			_check("its words are story.json's", text.contains("salvage caches"))
			var got: Button = shown.find_child("got_it", true, false) if shown != null else null
			_click_control(got)
			await create_timer(0.3).timeout
			_check("GOT IT clears it and its ring, and the profile remembers obj_defend",
				not _hud_of(scene).has_node("hint_obj_defend") and not marker.visible and bool(profile.call("seen", "obj_defend")))
		else:
			_check("DEFEND, second time: no callout", shown == null and not _hud_of(scene).has_node("objective_callout"))
		scene.queue_free()
		await process_frame
	var salvage: Node = await _open_fight("slag_pit")
	var pile_callout: Control = await _wait_node(_hud_of(salvage), "hint_obj_salvage", 6.0)
	var piles: Array = (salvage.get("_state") as CombatState).pile_cells()
	_check("SALVAGE has its own first time: the callout is up on a pile", pile_callout != null and not piles.is_empty()
		and (salvage.get("_coach_marker") as Node3D).visible)
	salvage.queue_free()
	await process_frame
	profile.call("use_path", PROFILE_PATH)
	_check("only GOT IT marks one seen: salvage is still owed after leaving", not bool(profile.call("seen", "obj_salvage")))
	# 088 (the user): the first marked reinforcements get their own callout, on a mark, once.
	for pass_no: int in 2:
		var scene: Node = await _open_fight("proto_yard")
		((scene.get("_db") as ContentDB).fights["proto_yard"] as Dictionary)["reinforcements"] = {"from_round": 2, "waves": [1]}
		scene.call("_start_fight")
		await create_timer(0.6).timeout
		await _settle()
		var shown: Control = await _wait_node(_hud_of(scene), "hint_obj_reinforcements", 6.0)
		var state: CombatState = scene.get("_state")
		if pass_no == 0:
			var marker: Node3D = scene.get("_coach_marker")
			var on_mark: bool = false
			for cell: Vector2i in state.wave_marks:
				on_mark = on_mark or (marker != null and marker.position.distance_to(scene.call("_to_world", cell.x, cell.y)) < 1.0)
			_check("REINFORCEMENTS, first marks (%s): the callout is up, its ring on a mark" % [state.wave_marks],
				shown != null and not state.wave_marks.is_empty() and marker.visible and on_mark)
			_click_control(shown.find_child("got_it", true, false) if shown != null else null)
			await create_timer(0.3).timeout
			_check("GOT IT remembers obj_reinforcements", bool(profile.call("seen", "obj_reinforcements")) and not marker.visible)
		else:
			_check("REINFORCEMENTS, second time: no callout", shown == null and not state.wave_marks.is_empty())
		scene.queue_free()
		await process_frame


func _open_fight(id: String) -> Node:
	var scene: Node = (load("res://scenes/combat.tscn") as PackedScene).instantiate()
	scene.set("_fight_id", id)
	root.add_child(scene)
	_scene = scene
	await _settle()
	await create_timer(0.6).timeout
	await _settle()
	return scene


func _hud_of(scene: Node) -> Control:
	return scene.get("_hud")


func _wait_node(parent: Node, node_name: String, seconds: float) -> Control:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if parent.has_node(node_name):
			return parent.get_node(node_name)
		await create_timer(0.1).timeout
	return null


var _rings: int = 0
var _ring_on_red: Array = []


## Follows the coach's marks for step `id` the way a player would, one click at a time, until the
## step passes: a machine is picked with its key, a hex or enemy clicked, a button pressed.
func _drive(coach: Node, id: String) -> void:
	for i: int in 10:
		if String(coach.call("current_id")) != id:
			return
		var mark: Dictionary = coach.call("current_mark")
		var state: CombatState = _scene.get("_state")
		var at: Variant = coach.call("_board_target")
		if bool(coach.call("is_move_ring")) and at != null:
			_rings += 1
			if (load("res://scripts/combat/coach.gd") as GDScript).call("aimed", state).has(at):
				_ring_on_red.append(at)
		if mark.has("weapon") or mark.has("ability") or mark.has("button"):
			_click_control(coach.call("_button_target"))
		elif mark.has("enemy") and at != null:
			_click_tile(at)
			await _settle()
			_click_tile(at)
		elif mark.has("unit") and not mark.has("cell"):
			_key(KEY_1 + int(mark["unit"]))
		elif at != null:
			_click_tile(at)
		await _settle()
	_check("(step %s passed by following its marks)" % id, String(coach.call("current_id")) != id)


## One combat action made by real input: the machine picked by its key, then the hex, the button,
## or the target clicked (twice: aim, then fire).
func _click_action(action: Array) -> void:
	var hud: CombatHUD = _scene.get("_hud")
	var kind: int = int(action[0])
	if kind == CombatSim.ACT_END:
		_click_control(hud.control_for("end_turn"))
		await _settle()
		return
	var ref: int = int(action[1])
	_key(KEY_1 + ref)
	await _settle()
	match kind:
		CombatSim.ACT_MOVE:
			_click_tile(Vector2i(int(action[2]), int(action[3])))
		CombatSim.ACT_ATTACK:
			_click_control((load("res://scripts/combat/coach.gd") as GDScript).call("_bar_button", hud.get("_weapon_bar"), int(action[2])))
			await _settle()
			var at := Vector2i(int(action[3]), int(action[4]))
			_click_tile(at)
			await _settle()
			_click_tile(at)
		CombatSim.ACT_VENT:
			_key(KEY_V)
		CombatSim.ACT_ABILITY:
			_click_control((load("res://scripts/combat/coach.gd") as GDScript).call("_bar_button", hud.get("_ability_bar"), int(action[2])))
			await _settle()
			if bool(_scene.get("_armed")):
				var cell := Vector2i(int(action[3]), int(action[4]))
				_click_tile(cell)
				await _settle()
				_click_tile(cell)
	await _settle()


func _event(state: CombatState, kind: int, actor: int, target: int) -> bool:
	for e: Array in state.events:
		if int(e[GridEv.F_KIND]) == kind and int(e[GridEv.F_ACTOR]) == actor and (target < 0 or int(e[GridEv.F_TARGET]) == target):
			return true
	return false


func _crew_hp(state: CombatState) -> int:
	var total: int = 0
	for u: GridUnit in state.crew(GridUnit.TEAM_PLAYER):
		total += u.hp
	return total


func _crew_max(state: CombatState) -> int:
	var total: int = 0
	for u: GridUnit in state.crew(GridUnit.TEAM_PLAYER):
		total += u.max_hp
	return total


func _key(code: int) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)


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
