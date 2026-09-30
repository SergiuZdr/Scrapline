extends SceneTree

## Old and new models side by side (017), drawn by the game in ink: the machine built by
## `ConstructView` and dressed by `Ink.dress_machine` exactly as a fight dresses it, once from
## the shipped set and once through `Models.use_new(true)`.
##
##   godot --path . --resolution 1600x900 --script res://tools/shot_models.gd -- \
##       --out shots/models [--parts ch_brute,co_slug,ar_saw,ar_hammer,mo_scavenger]
##   godot ... -- --out shots/sites --site workshop     # a map landmark, kit against generated
##
## Writes `<out>_near.png` (garage distance, three-quarter) and `<out>_far.png` (the board's
## own camera pitch and distance, where a machine is 60-80 px tall and only big shapes read).
## A site is shot once, `<out>_site.png`, from the map's pitch. Not headless: it has to render.

const NEAR_DISTANCE: float = 3.2
## The board's camera (`combat_scene.gd`): 56 degrees down, 12.5 m out by default.
const FAR_PITCH: float = 56.0
const FAR_DISTANCE: float = 12.5
const FAR_FOV: float = 38.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[args.find("--out") + 1] if args.has("--out") else "shots/models"
	var parts: PackedStringArray = PackedStringArray(["ch_brute", "co_slug", "ar_saw", "ar_hammer", "mo_scavenger"])
	if args.has("--parts"):
		parts = args[args.find("--parts") + 1].split(",")
	var db: ContentDB = ContentDB.load_all()

	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Ink.environment()
	world.add_child(env)
	world.add_child(Ink.key_light(Vector3(-40, -38, 0), 30.0))
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	ground.material_override = Ink.toon(Ink.BOARD)
	world.add_child(ground)

	if args.has("--site"):
		await _sites(world, args[args.find("--site") + 1], out)
		quit()
		return

	var spacing: float = 1.5
	for i: int in 2:
		Models.use_new(i == 1)
		var model: Node3D = ConstructView.build_parts(parts, db, Ink.YOURS)
		Ink.dress_machine(model, parts, Ink.YOURS)
		model.position = Vector3((float(i) - 0.5) * spacing, 0.0, 0.0)
		# Three-quarter to the camera, as the garage rests it.
		model.rotation_degrees.y = -35.0
		world.add_child(model)
		var tag := Label3D.new()
		tag.text = "SHIPPED" if i == 0 else "NEW (017)"
		tag.font = UIKit.font_display()
		tag.font_size = 48
		tag.pixel_size = 0.004
		tag.modulate = Ink.PAPER
		tag.outline_modulate = Ink.INK
		tag.outline_size = 12
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = model.position + Vector3(0.0, 1.15, 0.0)
		world.add_child(tag)

	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 30.0
	var aim := Vector3(0.0, 0.45, 0.0)
	camera.look_at_from_position(aim + Vector3(0.0, 0.9, NEAR_DISTANCE), aim, Vector3.UP)
	await _settle()
	_save(out + "_near.png")

	camera.fov = FAR_FOV
	var pitch: float = deg_to_rad(FAR_PITCH)
	aim = Vector3(0.0, 0.3, 0.0)
	camera.look_at_from_position(aim + Vector3(0.0, sin(pitch), cos(pitch)) * FAR_DISTANCE, aim, Vector3.UP)
	await _settle()
	_save(out + "_far.png")
	quit()


## The map's landmark for a site kind as the yard builds it: the kit piece (shipped) beside the
## generated one (`Models.site`), both dressed by `Ink.dress_prop` in the site's livery.
func _sites(world: Node3D, kind: String, out: String) -> void:
	var livery: Color = YardView.SITE_LIVERY.get(kind, Ink.STEEL)
	for i: int in 2:
		var piece: Node3D
		if i == 0:
			piece = Surfaces.kit("service_gantry", 0.12)
			piece.scale = Vector3.ONE * 0.6
			piece.rotation_degrees.y = 90.0
		else:
			Models.use_new(true)
			piece = Models.site(kind).instantiate() as Node3D
			piece.rotation_degrees.y = 215.0
		if i == 0:
			Ink.dress_prop(piece, livery)
		else:
			Ink.dress_set_piece(piece, livery)
		piece.position = Vector3((float(i) - 0.5) * 3.6, 0.0, 0.0)
		world.add_child(piece)
		var tag := Label3D.new()
		tag.text = "SHIPPED" if i == 0 else "NEW (017)"
		tag.font = UIKit.font_display()
		tag.font_size = 64
		tag.pixel_size = 0.008
		tag.modulate = Ink.PAPER
		tag.outline_modulate = Ink.INK
		tag.outline_size = 14
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = piece.position + Vector3(0.0, 3.0, 0.0)
		world.add_child(tag)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = FAR_FOV
	var pitch: float = deg_to_rad(FAR_PITCH)
	var aim := Vector3(0.0, 0.8, 0.0)
	camera.look_at_from_position(aim + Vector3(0.0, sin(pitch), cos(pitch)) * 9.5, aim, Vector3.UP)
	await _settle()
	_save(out + "_site.png")


func _settle() -> void:
	for i: int in 6:
		await process_frame


func _save(path: String) -> void:
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://").path_join(path.get_base_dir()))
	image.save_png(path)
	print("shot: ", path)
