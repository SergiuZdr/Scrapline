extends SceneTree

## Plays a fight with the scene's own bot and reports every frame that took too long, with
## the event that was being played -- "it lags when a lot happens at once" (play-test 7) as a
## number. Not headless: a hitch is a draw cost (a first-use shader compile, a burst of nodes).
##
##   godot --path . --resolution 1920x1080 --script res://tools/measure_hitches.gd -- \
##       --bot --fight slag_pit [--seed 3] [--seconds 40] [--over 40]

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seconds: float = float(_arg(args, "--seconds", "40"))
	var over: float = float(_arg(args, "--over", "40"))
	var scene: Node = (load("res://scenes/combat.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	var vp: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var started: int = Time.get_ticks_msec()
	var last: int = Time.get_ticks_usec()
	var frames: int = 0
	var slow: int = 0
	var worst: float = 0.0
	while float(Time.get_ticks_msec() - started) / 1000.0 < seconds:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var ms: float = float(now - last) / 1000.0
		last = now
		frames += 1
		# The opening card (024) is where shaders compile: count from when it has gone.
		if bool(scene.get("_busy")) and int(scene.get("_shown")) == 0:
			continue
		if ms > over:
			slow += 1
			worst = maxf(worst, ms)
			var state: CombatState = scene.get("_state")
			var shown: int = int(scene.get("_shown"))
			var kind: int = int(state.events[shown - 1][GridEv.F_KIND]) if shown > 0 and shown <= state.events.size() else -1
			print("  %.0f ms at %.1fs, event kind %d  (process %.0f ms, render cpu %.0f gpu %.0f)" % [ms,
				float(Time.get_ticks_msec() - started) / 1000.0, kind,
				Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
				RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu(),
				RenderingServer.viewport_get_measured_render_time_gpu(vp)])
		var ended: CombatState = scene.get("_state")
		if ended != null and ended.outcome != CombatState.ONGOING and not bool(scene.get("_busy")):
			break
	print("frames %d, over %.0f ms: %d, worst %.0f ms" % [frames, over, slow, worst])
	quit()


func _arg(args: PackedStringArray, name: String, fallback: String) -> String:
	var at: int = args.find(name)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else fallback
