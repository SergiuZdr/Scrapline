extends SceneTree

## 082 (A16): how long the enemy's turn takes to play back on screen, per speed.
##
##   godot --headless --path . --script res://tools/probe_playback.gd -- --fight slag_pit --rounds 2
##
## Plays the fight with the scene's own bot (`_bot_turn`) at 1x, 2x and 3x and prints the wall time
## of each enemy turn (from the END action to the end of its playback). Headless: the animation
## clock is real, the drawing is not, so a windowed game takes at least this long.

var _scene: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var fight: String = args[args.find("--fight") + 1] if args.has("--fight") else "slag_pit"
	var rounds: int = int(args[args.find("--rounds") + 1]) if args.has("--rounds") else 2
	var profile: Node = root.get_node("Profile")
	profile.call("use_path", "user://tool_probe_playback.json")
	var packed: PackedScene = load("res://scenes/combat.tscn")
	for speed: int in [1, 2, 3]:
		profile.call("set_playback", speed)
		_scene = packed.instantiate()
		_scene.set("_fight_id", fight)
		root.add_child(_scene)
		await _settle()
		_scene.set("_bot", true)
		_scene.call("_bot_turn")
		var times: Array = []
		var seen: int = 0
		var t0: int = 0
		for frame: int in 100000:
			await process_frame
			var actions: Array = _scene.get("_actions")
			var ends: int = actions.filter(func(a: Array) -> bool: return int(a[0]) == CombatSim.ACT_END).size()
			var busy: bool = bool(_scene.get("_busy"))
			if ends > seen:
				seen = ends
				t0 = Time.get_ticks_usec()
			if t0 > 0 and not busy:
				times.append((Time.get_ticks_usec() - t0) / 1000)
				t0 = 0
				if times.size() >= rounds:
					_scene.set("_bot", false)
			var state: CombatState = _scene.get("_state")
			if (times.size() >= rounds or state.outcome != CombatState.ONGOING) and t0 == 0 and not busy:
				break
		await _settle()
		print("%s %dx: enemy turns %s ms" % [fight, speed, str(times)])
		_scene.queue_free()
		await process_frame
	profile.call("set_playback", 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://tool_probe_playback.json"))
	quit(0)


func _settle() -> void:
	for i: int in 4000:
		await process_frame
		if not bool(_scene.get("_busy")) and i > 5:
			break
	await process_frame
