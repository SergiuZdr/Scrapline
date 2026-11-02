extends SceneTree

## 087 (A20, red means danger): the review sheet's frames. A fight at its opening, then one of
##   --what board    the board as it opens (slag: pick the look with `--slag old|umber|dark|pale`)
##   --what floats   the floats drawn over the machines, frozen: damage the crew DEALS over two
##                   enemies, damage it TAKES over a crew machine, OVERHEATED and SEIZED over two more
##   --what ring     the Core's pulse ring (`--fight the_core`): every ring hex red, or (after) red only
##                   where a crew machine stands, the rest in `--zone <hex colour>` (Ink.ZONE)
## (alternatives: `--dealt paper`, `--copper gold`, `--zone 7d8a8f`)
## with `--look before|after`: before draws the colours combat_scene uses today, after the Ink
## constants it is to switch to (the floats are built here exactly as `_float_text` builds them).
##
##   godot --path . --resolution 1920x1080 --script res://tools/shot_red.gd -- --fight slag_pit \
##       --what floats --look after --out shots/087/floats_after.png
##
## Not headless: it has to render.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scene: Node = (load("res://scenes/combat.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	# The opening card, then (a boss) its introduction: settled once idle for 2 s running.
	var began: bool = false
	var idle: int = 0
	for i: int in 600:
		await create_timer(0.1).timeout
		var busy: bool = bool(scene.get("_busy"))
		began = began or busy
		idle = idle + 1 if began and not busy else 0
		if idle >= 20:
			break
	# A boss's round-1 banner can start after that lull: give it time to clear.
	await create_timer(float(_arg(OS.get_cmdline_user_args(), "--after", "6"))).timeout
	var what: String = _arg(args, "--what", "board")
	var after: bool = _arg(args, "--look", "after") == "after"
	var state: Object = scene.get("_state")
	var views: Dictionary = scene.get("_views")
	var marks: Node3D = scene.get("_marks_root")
	match what:
		"floats":
			var crew: Array = []
			var enemies: Array = []
			for ref: Variant in views:
				var u: Object = state.call("unit", int(ref))
				if u == null or not bool(u.get("alive")):
					continue
				(crew if int(u.get("team")) == 0 else enemies).append(int(ref))
			crew.sort()
			enemies.sort()
			var red: Color = UIKit.RED.lightened(0.25)
			# Alternatives for the sheet: `--dealt paper` (paper letters on the usual ink line) and
			# `--copper gold` (UIKit.GOLD, the HUD's heat colour, instead of the registry's copper).
			var paper: bool = _arg(args, "--dealt", "ink") == "paper"
			var dealt: Color = (Ink.PAPER if paper else Ink.DEALT) if after else red
			var dealt_line: Color = (Ink.INK if paper else Ink.DEALT_LINE) if after else Ink.INK
			var copper: Color = (UIKit.GOLD if _arg(args, "--copper", "") == "gold" else Ink.COPPER) if after else UIKit.RED
			for i: int in mini(2, enemies.size()):
				_float(marks, _pos(views, enemies[i]) + Vector3(0, 1.8, 0), "-%d" % (4 + i), dealt, dealt_line)
			if crew.size() > 0:
				_float(marks, _pos(views, crew[0]) + Vector3(0, 1.8, 0), "-3", red, Ink.INK)
			if crew.size() > 1:
				_float(marks, _pos(views, crew[1]) + Vector3(0, 2.2, 0), "OVERHEATED", copper, Ink.INK)
			if crew.size() > 2:
				_float(marks, _pos(views, crew[2]) + Vector3(0, 2.2, 0), "SEIZED", copper, Ink.INK)
		"ring":
			if after:
				var zone := Color(_arg(args, "--zone", Ink.ZONE.to_html()))
				var quads: Dictionary = scene.get("_threat_quads")
				var hit: Dictionary = {}
				var threats: Dictionary = CombatSim.threats(state)
				for ref: Variant in threats:
					for h: Dictionary in (threats[ref]["hits"] as Array):
						var v: Object = state.call("unit", int(h["ref"]))
						hit[Vector2i(int(v.get("x")), int(v.get("y")))] = true
					hit[threats[ref]["end"]] = true
				for cell: Vector2i in (state.get("pulse_marks") as Array):
					var on: Object = state.call("unit_at", cell.x, cell.y)
					var crew_here: bool = on != null and int(on.get("team")) == 0
					if not crew_here and not hit.has(cell):
						scene.call("_mark", quads, cell, zone)
	for i: int in 20:
		await process_frame
	var out: String = _arg(args, "--out", "shots/red.png")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	root.get_texture().get_image().save_png(out)
	print("shot: %s" % out)
	quit()


func _pos(views: Dictionary, ref: int) -> Vector3:
	return ((views[ref] as Dictionary)["root"] as Node3D).position


## As `combat_scene._float_text` builds a float, held still (no rise, no fade), with its outline colour.
func _float(parent: Node3D, at: Vector3, text: String, colour: Color, line: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = UIKit.font_comic()
	label.font_size = 56
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 18
	label.outline_modulate = line
	label.modulate = colour
	# Beside and above the tag and badges, as a float stands mid-rise (in play it rises 0.9 m).
	label.position = at + Vector3(0.9, 0.6, 0)
	label.render_priority = 10
	label.outline_render_priority = 9
	parent.add_child(label)


func _arg(args: PackedStringArray, name: String, fallback: String) -> String:
	var at: int = args.find(name)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else fallback
