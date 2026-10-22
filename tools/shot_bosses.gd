extends SceneTree

## 083 (A19): stills of a boss fight for the before/after sheet, and the keeper's height measured
## against the crew's (real vertices, in each machine's root space, scale and all).
##
##   godot --path . --resolution 1920x1080 --script res://tools/shot_bosses.gd -- \
##       --fight the_pour --out shots/083/pour        board still after the opening: <out>_board.png
##       --push      the opening push-in ON: <out>_push0.png (start), _push1.png (mid), _push2.png (end)
##       --fall      stage the keeper at 1 HP beside Knuckles and strike it: <out>_fall0..3.png (the beat, the
##                   collapse, the end, the result)
##       --ends N    end the turn N times first (escort marks show the round before they land)
##       --legacy    the keeper at the pre-083 scale and tag (the "before" column)
##       --height H  every keeper H times the crew's tallest machine (else its kind's `view_scale`)
##
## Prints `height: keeper K crew C ratio R` for each keeper. Not headless: it has to render.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = _arg(args, "--out", "shots/083/boss")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var scene: Node = (load("res://scenes/combat.tscn") as PackedScene).instantiate()
	scene.set("boss_push_in", args.has("--push"))
	scene.set("legacy_boss_look", args.has("--legacy"))
	scene.set("keeper_height", float(_arg(args, "--height", "0")))
	if args.has("--lift"):
		scene.set("keeper_paint_lift", float(_arg(args, "--lift", "0")))
	root.add_child(scene)
	var taken: Array[bool] = [false, false, false]
	var began: bool = false
	for i: int in 3000:
		await process_frame
		var phase: float = float(scene.get("_push_phase"))
		if args.has("--push"):
			if phase >= 0.0 and not taken[0]:
				taken[0] = true
				await _save(out + "_push0.png")
			if phase >= 0.5 and not taken[1]:
				taken[1] = true
				await _save(out + "_push1.png")
			if phase >= 1.0 and not taken[2]:
				taken[2] = true
				await _save(out + "_push2.png")
		began = began or bool(scene.get("_busy"))
		if began and not bool(scene.get("_busy")) and i > 10:
			break
	for i: int in 20:
		await process_frame
	# --ends N: end the turn N times (the crew stands still), each enemy turn played out in full.
	for n: int in int(_arg(args, "--ends", "0")):
		scene.call("_end_turn")
		var calm: int = 0
		for i: int in 600:
			await create_timer(0.1).timeout
			calm = calm + 1 if not bool(scene.get("_busy")) else 0
			if calm >= 8:
				break
	_measure(scene)
	await _save(out + "_board.png")

	if args.has("--fall"):
		# The real thing on a staged board (as verify_combat stages it): Knuckles beside the keeper,
		# the keeper at 1 HP, one blow through the scene's own `_act` -- KEEPERS_FALL, the rest's
		# collapse and the result all come from the sim's events.
		var state: CombatState = scene.get("_state")
		var keeper: GridUnit = null
		for u: GridUnit in state.units:
			if u.alive and bool(scene.call("_is_keeper", u)):
				keeper = u
		var hitter: GridUnit = state.unit(0)
		var melee: int = -1
		for w: int in hitter.weapons.size():
			if String(hitter.weapons[w]["shape"]) == "melee":
				melee = w
		if keeper != null and melee >= 0:
			for n: Vector2i in Hex.neighbors(Vector2i(keeper.x, keeper.y)):
				if state.inside(n) and not state.solid(n) and not state.is_pit(n) and state.unit_at(n.x, n.y) == null:
					hitter.x = n.x
					hitter.y = n.y
					break
			hitter.acted = false
			keeper.hp = 1
			scene.call("_resync_units")
			for i: int in 5:
				await process_frame
			scene.call("_act", [CombatSim.ACT_ATTACK, hitter.ref, melee, keeper.x, keeper.y])
			var marks: Array[float] = [0.9, 1.6, 3.2]
			var at: float = 0.0
			for k: int in marks.size():
				await create_timer(marks[k] - at).timeout
				at = marks[k]
				await _save(out + "_fall%d.png" % k)
				print("  t=%.1f shown %d of %d busy %s time_scale %.2f" % [at, int(scene.get("_shown")), state.events.size(), scene.get("_busy"), Engine.time_scale])
			print("fall: outcome %d, KEEPERS_FALL events %d" % [state.outcome,
				state.events.filter(func(e: Array) -> bool: return int(e[0]) == GridEv.KEEPERS_FALL).size()])
			for i: int in 600:
				await process_frame
				if not bool(scene.get("_busy")):
					break
			await create_timer(1.0).timeout
			await _save(out + "_fall3.png")
	quit()


func _measure(scene: Node) -> void:
	var state: Object = scene.get("_state")
	var views: Dictionary = scene.get("_views")
	var crew: float = 0.0
	var keepers: Array = []
	for u: Object in state.get("units"):
		var ref: int = int(u.get("ref"))
		if not views.has(ref):
			continue
		var h: float = _height((views[ref] as Dictionary)["model"], (views[ref] as Dictionary)["root"])
		if int(u.get("team")) == GridUnit.TEAM_PLAYER and not bool(u.get("objective")):
			crew = maxf(crew, h)
		elif bool(scene.call("_is_keeper", u)):
			keepers.append([String(u.get("name")), h])
	for k: Array in keepers:
		print("height: keeper %s %.2f  crew (tallest) %.2f  ratio %.2f" % [k[0], k[1], crew, float(k[1]) / maxf(0.01, crew)])


func _height(model: Node3D, space: Node3D) -> float:
	var top: float = 0.0
	for v: Vector3 in ConstructView._vertices(model, space):
		top = maxf(top, v.y)
	return top


func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	print("shot: %s (%s)" % [path, error_string(image.save_png(path))])


func _arg(args: PackedStringArray, name: String, fallback: String) -> String:
	var at: int = args.find(name)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else fallback
