extends SceneTree

## Screenshots of onboarding (012), in a real state:
##
##   godot --path . --resolution 1920x1080 --script res://tools/shot_onboarding.gd -- --what coach --out shots/coach.png
##
## `--what`: coach (the shakedown on its MOVE step, marker and all), drum (its drum step, the
## Strider picked), glossary (the GLOSSARY screen over the title), card (a glossary card over
## a fight's info panel), hint (the map's first-time hint), newrun (the title's first-run offer).
## Uses a scratch profile, never the player's.

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
	match what:
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


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _arg(args: PackedStringArray, name: String, fallback: String) -> String:
	var at: int = args.find(name)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else fallback
