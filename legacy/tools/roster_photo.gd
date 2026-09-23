extends Control

## Dev-only: a photograph of the roster, standing in the hub's yard under the hub's lights.
##
##     $GODOT --path . res://tools/roster_photo.tscn --resolution 2400x1100 -- \
##         --shot shots/roster_photo.png [--cam 0,0.62,6.8] [--look 0,0.44,0] [--fov 18]
##
## The Blender hero renders in `art/hero/` were made from the previous generator and
## no longer show the machines the game draws. This is the game's own scene with no
## interface over it, so it can never drift from what a player sees.
##
## The camera sits low, at the machines' chest height, and far back on a long lens. From
## a drone's height with a wide lens a 0.85 m construct foreshortens into a squat box --
## which is exactly how the old roster sheet came out.

## Five different frames with arms that suit their role, so one picture shows the range.
const LINEUP: Array = [
	{"chassis": "ch_lancer", "core": "co_tesla", "arm_l": "ar_railgun", "arm_r": "ar_scanner", "module": "mo_targeting"},
	{"chassis": "ch_brute", "core": "co_furnace", "arm_l": "ar_hammer", "arm_r": "ar_saw", "module": "mo_reactive"},
	{"chassis": "ch_citadel", "core": "co_dynamo", "arm_l": "ar_mortar", "arm_r": "ar_pulse", "module": "mo_ablative"},
	{"chassis": "ch_reaper", "core": "co_ember", "arm_l": "ar_maul", "arm_r": "ar_ripper", "module": "mo_servo"},
	{"chassis": "ch_hauler", "core": "co_arc", "arm_l": "ar_scatter", "arm_r": "ar_lance", "module": "mo_coolant"},
]


const FORMATION: Array[Vector3] = [
	Vector3(-1.55, 0.0, -0.70), Vector3(-0.78, 0.0, -0.25), Vector3(0.0, 0.0, 0.25),
	Vector3(0.78, 0.0, -0.25), Vector3(1.55, 0.0, -0.70),
]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var args: PackedStringArray = OS.get_cmdline_user_args()

	var yard := HubYard.new()
	add_child(yard)
	var squad: Array = []
	for parts: Variant in LINEUP:
		squad.append({"parts": parts})
	yard.refresh(squad)

	# A shallow V with the middle machine forward, instead of the hub's straight rank. A
	# rank photographed from the front is five icons in a row; staggered in depth they
	# overlap and the picture gets a foreground.
	var turn: float = float(_arg(args, "--turn", "0"))
	var models: Array[Node] = yard._squad_root.get_children()
	for index: int in models.size():
		var model := models[index] as Node3D
		model.position = FORMATION[index] if index < FORMATION.size() else model.position
		model.rotation.y += deg_to_rad(turn)

	for node: Node in yard._world.get_children():
		if node is WorldEnvironment:
			(node as WorldEnvironment).environment.tonemap_exposure = float(_arg(args, "--exposure", "1.4"))

	yard._camera.fov = float(_arg(args, "--fov", "15"))
	yard._look_from(_vec(_arg(args, "--cam", "0,0.5,6.0")), _vec(_arg(args, "--look", "0,0.42,0")))

	var path: String = _arg(args, "--shot", "")
	if path.is_empty():
		return
	for _i: int in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("roster photo -> ", path)
	get_tree().quit()


func _arg(args: PackedStringArray, name: String, fallback: String) -> String:
	var index: int = args.find(name)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else fallback


func _vec(text: String) -> Vector3:
	var p: PackedStringArray = text.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))
