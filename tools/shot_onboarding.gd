extends SceneTree

## Screenshots of onboarding (012), in a real state:
##
##   godot --path . --resolution 1920x1080 --script res://tools/shot_onboarding.gd -- --what coach --out shots/coach.png
##
## `--what`: coach (the shakedown on its MOVE step, marker and all), drum (its drum step, the
## Strider picked), glossary (the GLOSSARY screen over the title), card (a glossary card over
## a fight's info panel), hint (the map's first-time hint), newrun (the title's first-run offer).
## 088: step (the shakedown at step `--step <id>`, the coached line played to it; `--phase` mark (the
## step as it opens), aim (its last target aimed, the preview up) or beat (just after the shot)),
## skip (the last card after SKIP on the first), objective (a fight's first objective callout,
## `--fight <id>`, default container_row; `--reinforce` adds a reinforcement wave due in round 2). `--label "AFTER · PIT"` captions the shot.
## Uses a scratch profile, never the player's.

## 088: the coached line, step by step, as the scene's own input methods (the shot, not a test).
const PLAN: Dictionary = {
	"welcome": [["next"]],
	"threat": [["next"]],
	"arm": [["select", 1], ["weapon", 1]],
	"cancel": [["tap_unit", 11], ["tap_unit", 11]],
	"move": [["select", 0], ["tap", 2, 4]],
	"pit": [["weapon", 1], ["tap_unit", 10], ["tap_unit", 10]],
	"heat": [["select", 2], ["ability", 0]],
	"tear": [["tap", 4, 6], ["weapon", 1], ["tap_unit", 12], ["tap_unit", 12]],
	"end": [["end"]],
	"piles": [["next"]],
}

func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var what: String = _arg(args, "--what", "coach")
	var out: String = _arg(args, "--out", "shots/onboarding.png")
	var profile: Node = root.get_node("Profile")
	profile.call("use_path", "user://shot_profile.json")
	profile.call("reset_hints")
	var db: ContentDB = ContentDB.load_all()
	_caption(String(_arg(args, "--label", "")))
	match what:
		"step", "skip":
			for id: Variant in (db.tutorial.get("hints", {}) as Dictionary):
				profile.call("mark_seen", String(id))
			change_scene_to_file("res://scenes/shakedown.tscn")
			await _frames(90)
			var scene: Node = current_scene
			var coach: Node = scene.get("_coach")
			if what == "skip":
				coach.call("skip")
				await _frames(20)
			else:
				await _play_to(scene, coach, _arg(args, "--step", "threat"), _arg(args, "--phase", "mark"))
		"objective":
			for id: Variant in (db.tutorial.get("hints", {}) as Dictionary):
				if not String(id).begins_with("obj_"):
					profile.call("mark_seen", String(id))
			var scene: Node = (load("res://scenes/combat.tscn") as PackedScene).instantiate()
			scene.set("_fight_id", _arg(args, "--fight", "container_row"))
			root.add_child(scene)
			current_scene = scene
			await _seconds(4.0)
			if args.has("--reinforce"):
				# 088: the fight again with one marked reinforcement due next round.
				((scene.get("_db") as ContentDB).fights[_arg(args, "--fight", "container_row")] as Dictionary)["reinforcements"] = \
					{"from_round": 2, "waves": [1]}
				scene.call("_start_fight")
				await _seconds(4.0)
			while bool(scene.get("_busy")):
				await _frames(10)
			await _seconds(1.0)
		"coach", "drum":
			for id: Variant in (db.tutorial.get("hints", {}) as Dictionary):
				profile.call("mark_seen", String(id))
			change_scene_to_file("res://scenes/shakedown.tscn")
			await _frames(90)
			var scene: Node = current_scene
			var coach: Node = scene.get("_coach")
			coach.call("next_step")
			await _frames(20)
			if what == "drum":
				while String(coach.call("current_id")) != "focus":
					coach.call("next_step")
				scene.call("_select", 2)
				await _frames(10)
				coach.call("next_step")
				await _frames(10)
				scene.call("_choose_weapon", 0)
				await _frames(30)
		"glossary":
			change_scene_to_file("res://scenes/main.tscn")
			await _frames(40)
			var panel: Control = Glossary.open(current_scene, db.glossary)
			panel.set("_group", "WEAPONS")
			panel.call("_rebuild")
			await _frames(20)
		"card":
			for id: Variant in (db.tutorial.get("hints", {}) as Dictionary):
				profile.call("mark_seen", String(id))
			change_scene_to_file("res://scenes/combat.tscn")
			await _frames(90)
			var hud: Node = current_scene.get("_hud")
			hud.call("set_info", "RAIL LANCE", "shot 3 · 3 dmg · +1 heat · pierce. A piercing shot carries on through what it hits.")
			await _frames(5)
			Glossary.show_card(hud, "pierce", db.glossary)
			await _frames(20)
		"hint":
			var run: Node = root.get_node("Run")
			run.call("new_run", 7)
			run.set("briefed", true)
			run.set("bay_seen", true)
			change_scene_to_file("res://scenes/run_map.tscn")
			await _frames(60)
		"newrun":
			change_scene_to_file("res://scenes/main.tscn")
			await _frames(40)
			current_scene.call("_new_run")
			await _frames(20)
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	print("shot: %s (%s)" % [out, error_string(image.save_png(out))])
	RunStore.clear()
	for path: String in ["user://shot_profile.json", "user://shot_profile.backup.json"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	quit()


## Plays the coached line up to step `id` (`phase` mark), or into it: every action of the step but
## the last tap (aim: the preview is up), or all of it (beat: a moment after the shot lands).
func _play_to(scene: Node, coach: Node, id: String, phase: String) -> void:
	var guard: int = 0
	while String(coach.call("current_id")) != id and guard < 12:
		await _do_step(scene, coach, PLAN.get(String(coach.call("current_id")), [["next"]]), false)
		guard += 1
	if phase == "mark":
		await _seconds(0.6)
		return
	var plan: Array = PLAN.get(id, [])
	if phase == "aim":
		plan = plan.slice(0, plan.size() - 1)
	await _do_step(scene, coach, plan, phase == "beat")


func _do_step(scene: Node, coach: Node, plan: Array, beat: bool) -> void:
	for i: int in plan.size():
		var step: Array = plan[i]
		var state: CombatState = scene.get("_state")
		match String(step[0]):
			"next":
				coach.call("next_step")
			"select":
				scene.call("_select", int(step[1]))
			"weapon":
				scene.call("_choose_weapon", int(step[1]))
			"ability":
				scene.call("_choose_ability", int(step[1]))
			"tap":
				scene.call("_tap", Vector2i(int(step[1]), int(step[2])))
			"tap_unit":
				var u: GridUnit = state.unit(int(step[1]))
				scene.call("_tap", Vector2i(u.x, u.y))
			"end":
				scene.call("_end_turn")
		if beat and i == plan.size() - 1:
			await _seconds(0.55)
			return
		await _frames(4)
		while bool(scene.get("_busy")):
			await _frames(4)
		await _frames(6)
	await _seconds(0.4)


func _caption(text: String) -> void:
	if text.is_empty():
		return
	var layer := CanvasLayer.new()
	layer.layer = 120
	root.add_child.call_deferred(layer)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color("f4e9c8"))
	label.add_theme_color_override("font_outline_color", Color("15110d"))
	label.add_theme_constant_override("outline_size", 10)
	label.position = Vector2(34, 40)
	layer.add_child(label)


func _seconds(t: float) -> void:
	await create_timer(t).timeout


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _arg(args: PackedStringArray, name: String, fallback: String) -> String:
	var at: int = args.find(name)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else fallback
