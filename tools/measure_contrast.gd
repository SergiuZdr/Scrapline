extends SceneTree

## Do the machines stay the brightest solid things on the board? (docs/plans/art-and-audio.md:
## "that margin may only grow"). A number, so a texture pass cannot quietly sink the units
## into the ground while every screenshot still "looks fine".
##
##   godot --path . --resolution 960x540 --script res://tools/measure_contrast.gd -- --fight slag_pit
##       [--legacy | --height H]   083: the keeper at its pre-083 look, or H times the crew
##
## Renders the fight twice from the same camera: as it is (overlays and HUD hidden), then
## with everything but the machines hidden against black. The second render is the mask;
## the first gives the numbers:
##   machines  -- mean luminance of machine pixels
##   surround  -- mean luminance of the pixels within a ring around them (what they must
##                stand out from)
##   board     -- mean luminance of everything else in view
## and the margin and ratio of machines over surround.
##
## 087 (A20, "red means danger"): a RED CENSUS of the same frame. Red is reserved for danger -- enemy
## intents, the hexes something will hit, enemy rings (docs/plans/art-and-audio.md). The census
## counts the strongly red pixels (`_is_red`) of the frame as the player sees it and tells apart
##   world    -- the board, props, yard, floor marks and tags: OUTSIDE the danger marks and the
##               machines. This is the number that should be about 0.
##   machines -- red on the machines' paint (liveries, oxide plates): reported, not a signal
##   danger   -- red inside the danger marks (threat hexes, intent marks, enemy rings): allowed
##   hud      -- red the interface adds over the world (the card shadows are the user's pick: kept)
## Each in per mille of the frame. The danger mask is a third render: only the threat hexes, the
## nodes marked "intent" and the enemy rings, against black, widened by `DANGER_GROW_PX`.

const RING_PX: int = 14
## 087: a strongly red pixel -- hue within RED_HUE_DEG of pure red, saturated and lit enough to read
## as a signal (UIKit.GOLD b4532a, at 17.8 degrees, is copper, not red; Ink.DANGER ff3b30 is 3.5).
const RED_HUE_DEG: float = 15.0
const RED_SAT: float = 0.55
const RED_VAL: float = 0.40
const DANGER_GROW_PX: int = 3


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scene: Node = (load("res://scenes/combat.tscn") as PackedScene).instantiate()
	# 083: --legacy measures the pre-083 keeper (scale and tag) on the same build, --height H a
	# keeper H times the crew -- so a look change is judged apart from what the sim changed.
	scene.set("legacy_boss_look", args.has("--legacy"))
	scene.set("keeper_height", float(_arg(args, "--height", "0")))
	if args.has("--lift"):
		scene.set("keeper_paint_lift", float(_arg(args, "--lift", "0")))
	root.add_child(scene)
	# 081: wait for the opening to START and then end. With the effects baked the scene can still be
	# loading at frame 10, not yet busy, and the old "not busy after frame 10" measured a blank screen.
	# The opening card holds for real seconds (`OPENING_SECONDS`), so this polls the clock, not frames.
	var began: bool = false
	for i: int in 300:
		await create_timer(0.1).timeout
		began = began or bool(scene.get("_busy"))
		if began and not bool(scene.get("_busy")):
			break
	if OS.get_cmdline_user_args().has("--dump"):
		print("began ", began, " busy ", scene.get("_busy"))
	# 087: the frame as the player sees it (HUD on), then the world alone (HUD off), for the census.
	for i: int in 12:
		await process_frame
	var seen: Image = root.get_texture().get_image()
	var layers: Array[CanvasLayer] = []
	for node: Node in _all(scene):
		if node is CanvasLayer and (node as CanvasLayer).visible:
			layers.append(node)
			(node as CanvasLayer).visible = false
	for i: int in 12:
		await process_frame
	var world: Image = root.get_texture().get_image()
	for layer: CanvasLayer in layers:
		layer.visible = true
	_hide_overlays(scene)
	for i: int in 12:
		await process_frame
	var full: Image = root.get_texture().get_image()

	(scene.get("_board") as Node3D).visible = false
	# 081: props and piles stand in the units' root but are ground the machines stand out from, not
	# machines: out of the mask (a big generated wall block counted as a "machine" before).
	for views: String in ["_prop_views", "_pile_views"]:
		for node: Variant in (scene.get(views) as Dictionary).values():
			(node as Node3D).visible = false
	for view: Variant in (scene.get("_views") as Dictionary).values():
		for key: String in ["ring", "tag"]:
			if (view as Dictionary).has(key):
				((view as Dictionary)[key] as Node3D).visible = false
	for node: Node in _all(scene):
		if node is WorldEnvironment:
			var environment: Environment = (node as WorldEnvironment).environment
			environment.background_mode = Environment.BG_COLOR
			environment.background_color = Color.BLACK
			environment.fog_enabled = false
			environment.glow_enabled = false
	for i: int in 12:
		await process_frame
	var solo: Image = root.get_texture().get_image()
	if OS.get_cmdline_user_args().has("--dump"):
		full.save_png("shots/contrast_full.png")
		solo.save_png("shots/contrast_solo.png")

	var result: Dictionary = _measure(full, solo)
	print("contrast: machines %.3f  surround %.3f  board %.3f  margin %+.3f  ratio %.2f  (%d machine px)" % [
		result["machines"], result["surround"], result["board"], result["margin"], result["ratio"], result["pixels"]])

	# 087: the danger mask -- only what is ALLOWED to be red, against the black the solo render left.
	_show_danger_only(scene)
	for i: int in 12:
		await process_frame
	var danger: Image = root.get_texture().get_image()
	if OS.get_cmdline_user_args().has("--dump"):
		seen.save_png("shots/contrast_seen.png")
		danger.save_png("shots/contrast_danger.png")
	var census: Dictionary = _census(seen, world, solo, danger)
	result.merge(census)
	print("red census (per mille of the frame): world %.2f  machines %.2f  danger %.2f  hud %.2f  (world %d px of %d)" % [
		census["red_world"], census["red_machines"], census["red_danger"], census["red_hud"],
		census["red_world_px"], census["frame_px"]])
	var out: String = _arg(args, "--json", "")
	if not out.is_empty():
		var file := FileAccess.open(out, FileAccess.WRITE)
		file.store_string(JSON.stringify(result))
	quit()


func _hide_overlays(scene: Node) -> void:
	for node: Node in _all(scene):
		if node is CanvasLayer:
			(node as CanvasLayer).visible = false
	var marks: Node3D = scene.get("_marks_root")
	if marks != null:
		marks.visible = false
	# Labels are overlays too (015): a tag's lettering is the machine's caption, not the ground it
	# must stand out from, and counting it as surround made a bigger, brighter tag look like a
	# machine sinking into the board. Tags, badges and marks over units go in both renders.
	var units: Node3D = scene.get("_units_root")
	if units != null:
		for node: Node in _all(units):
			if node is Label3D or node is Sprite3D:
				(node as Node3D).visible = false


## 087: everything hidden but the danger marks -- the threat hexes (only the red ones are red; a
## spawn pad's purple is not), every mark the scene tags "intent" (badges, arrows, bars), the enemy
## rings. The board, props, piles and machines were hidden by the solo render; the machines go now.
func _show_danger_only(scene: Node) -> void:
	var state: Object = scene.get("_state")
	for ref: Variant in (scene.get("_views") as Dictionary):
		var view: Dictionary = (scene.get("_views") as Dictionary)[ref]
		for key: String in ["model", "tag", "affix"]:
			if view.has(key) and view[key] is Node3D:
				(view[key] as Node3D).visible = false
		for extra: Variant in view.get("extras", []):
			if extra is Node3D:
				(extra as Node3D).visible = false
		var u: Object = state.call("unit", int(ref)) if state != null else null
		var enemy: bool = u != null and int(u.get("team")) != 0
		if view.has("ring"):
			(view["ring"] as Node3D).visible = enemy
		var root3d: Node3D = view["root"]
		for child: Node in root3d.get_children():
			if child is Node3D and child != view.get("ring") and child != view.get("model"):
				(child as Node3D).visible = false
	var marks: Node3D = scene.get("_marks_root")
	if marks == null:
		return
	marks.visible = true
	var threat: Array = (scene.get("_threat_quads") as Dictionary).values()
	for child: Node in marks.get_children():
		if child is Node3D and not threat.has(child) and not child.has_meta("intent"):
			(child as Node3D).visible = false


## 087: the red census (see the header). `seen` HUD on, `world` HUD off, `solo` the machines alone,
## `danger` the danger marks alone. Per mille of the frame's pixels.
func _census(seen: Image, world: Image, solo: Image, danger: Image) -> Dictionary:
	var w: int = world.get_width()
	var h: int = world.get_height()
	var grow := PackedByteArray()
	grow.resize(w * h)
	for y: int in h:
		for x: int in w:
			if _lum(danger.get_pixel(x, y)) > 0.035:
				for dy: int in range(-DANGER_GROW_PX, DANGER_GROW_PX + 1):
					for dx: int in range(-DANGER_GROW_PX, DANGER_GROW_PX + 1):
						var gx: int = x + dx
						var gy: int = y + dy
						if gx >= 0 and gy >= 0 and gx < w and gy < h:
							grow[gy * w + gx] = 1
	var n_world: int = 0
	var n_machines: int = 0
	var n_danger: int = 0
	var n_hud: int = 0
	for y: int in h:
		for x: int in w:
			var red_world: bool = _is_red(world.get_pixel(x, y))
			if _is_red(seen.get_pixel(x, y)) and not red_world:
				n_hud += 1
			if not red_world:
				continue
			if grow[y * w + x] == 1:
				n_danger += 1
			elif _lum(solo.get_pixel(x, y)) > 0.035:
				n_machines += 1
			else:
				n_world += 1
	var total: float = float(w * h) / 1000.0
	return {"red_world": float(n_world) / total, "red_machines": float(n_machines) / total,
		"red_danger": float(n_danger) / total, "red_hud": float(n_hud) / total,
		"red_world_px": n_world, "frame_px": w * h}


func _is_red(c: Color) -> bool:
	var hue: float = c.h * 360.0
	return (hue <= RED_HUE_DEG or hue >= 360.0 - RED_HUE_DEG) and c.s >= RED_SAT and c.v >= RED_VAL


func _measure(full: Image, solo: Image) -> Dictionary:
	var w: int = full.get_width()
	var h: int = full.get_height()
	# Integral image of the machine mask, so "is there a machine within the ring" is O(1).
	var mask := PackedByteArray()
	mask.resize(w * h)
	var sum := PackedInt32Array()
	sum.resize((w + 1) * (h + 1))
	for y: int in h:
		var row: int = 0
		for x: int in w:
			var m: int = 1 if _lum(solo.get_pixel(x, y)) > 0.035 else 0
			mask[y * w + x] = m
			row += m
			sum[(y + 1) * (w + 1) + x + 1] = sum[y * (w + 1) + x + 1] + row
	var unit_total: float = 0.0
	var unit_n: int = 0
	var ring_total: float = 0.0
	var ring_n: int = 0
	var board_total: float = 0.0
	var board_n: int = 0
	for y: int in h:
		for x: int in w:
			var l: float = _lum(full.get_pixel(x, y))
			if mask[y * w + x] == 1:
				unit_total += l
				unit_n += 1
				continue
			var x0: int = maxi(0, x - RING_PX)
			var y0: int = maxi(0, y - RING_PX)
			var x1: int = mini(w, x + RING_PX + 1)
			var y1: int = mini(h, y + RING_PX + 1)
			var near: int = sum[y1 * (w + 1) + x1] - sum[y0 * (w + 1) + x1] - sum[y1 * (w + 1) + x0] + sum[y0 * (w + 1) + x0]
			if near > 0:
				ring_total += l
				ring_n += 1
			else:
				board_total += l
				board_n += 1
	var machines: float = unit_total / maxf(1.0, float(unit_n))
	var surround: float = ring_total / maxf(1.0, float(ring_n))
	return {"machines": machines, "surround": surround, "board": board_total / maxf(1.0, float(board_n)),
		"margin": machines - surround, "ratio": machines / maxf(0.001, surround), "pixels": unit_n}


func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


func _all(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child: Node in node.get_children():
		out.append_array(_all(child))
	return out


func _arg(args: PackedStringArray, name: String, fallback: String) -> String:
	var at: int = args.find(name)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else fallback
