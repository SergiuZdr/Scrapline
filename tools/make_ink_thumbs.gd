extends SceneTree

## Part thumbnails in Ink & Rust (016), rendered by the GAME: every part built the way
## `ConstructView` builds it, dressed by `Ink` exactly as the fight dresses it, photographed at
## a three-quarter angle on a clear background into `art/thumbs_ink/<id>.png`. `PartText.thumb`
## prefers these, so a card pictures a part as the board draws it (CLAUDE.md: "a thumbnail must
## wear the same livery the game draws" -- rendering it in the game is the one way to be sure).
##
##   godot --path . --script res://tools/make_ink_thumbs.gd [-- --only ar_saw,ar_hammer]
##   godot --path . --script res://tools/make_ink_thumbs.gd -- --models new --out res://art/thumbs_new \
##       --only ch_brute,co_slug,ar_saw,ar_hammer        # the new set's pictures (017)
##
## Not headless: it has to render.

const OUT := "res://art/thumbs_ink"
const SIZE := 384
## Thicker than on the board: a thumbnail is shown at a fifth of its size on a card.
const LINE_PX: float = 9.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var db: ContentDB = ContentDB.load_all()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var only: PackedStringArray = args[args.find("--only") + 1].split(",") if args.has("--only") else PackedStringArray()
	var out: String = args[args.find("--out") + 1] if args.has("--out") else OUT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env := WorldEnvironment.new()
	var environment: Environment = Ink.environment()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.glow_enabled = false
	env.environment = environment
	viewport.add_child(env)
	viewport.add_child(Ink.key_light(Vector3(-32, -28, 0), 10.0))
	var camera := Camera3D.new()
	camera.fov = 28.0
	viewport.add_child(camera)
	camera.current = true
	var ids: Array = db.parts.keys()
	ids.sort()
	var made: int = 0
	for id: Variant in ids:
		var part_id: String = String(id)
		if PartTuning.is_tuned(part_id) or (not only.is_empty() and not only.has(part_id)):
			continue
		var model: Node3D = ConstructView._instance(part_id)
		if model == null:
			continue
		var pivot := Node3D.new()
		viewport.add_child(pivot)
		pivot.add_child(model)
		_dress(model, part_id)
		var bounds: AABB = _bounds(model)
		var centre: Vector3 = bounds.get_center()
		var radius: float = maxf(0.05, bounds.size.length() * 0.5)
		# Three-quarter, a little from above: the angle every card shows.
		var dir := Vector3(sin(deg_to_rad(-35.0)), 0.36, cos(deg_to_rad(-35.0))).normalized()
		var distance: float = radius / tan(deg_to_rad(camera.fov * 0.5)) * 1.12
		camera.look_at_from_position(centre + dir * distance, centre, Vector3.UP)
		for i: int in 4:
			await process_frame
		var image: Image = viewport.get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path("%s/%s.png" % [out, part_id]))
		pivot.queue_free()
		made += 1
	print("ink thumbs: %d written to %s" % [made, out])
	quit()


## A lone part in ink: every surface by its zone and the part's own livery, and a line.
func _dress(node: Node, part_id: String) -> void:
	for mesh: MeshInstance3D in ConstructView.meshes_of(node):
		if mesh.mesh == null:
			continue
		for s: int in mesh.mesh.get_surface_count():
			var zone: String = PartMaterials.zone_of(mesh.mesh.surface_get_material(s))
			mesh.set_surface_override_material(s, Ink.zone_material(zone, Ink.livery_of(part_id), Ink.YOURS))
		Ink.line(mesh, LINE_PX)


## The model's bounds from its real vertices in world space (CLAUDE.md: never
## `global_transform * get_aabb()` -- a tilted box overstates).
func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first: bool = true
	for mesh: MeshInstance3D in ConstructView.meshes_of(node):
		if mesh.mesh == null:
			continue
		var xf: Transform3D = mesh.global_transform
		for s: int in mesh.mesh.get_surface_count():
			var verts: PackedVector3Array = mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for v: Vector3 in verts:
				var p: Vector3 = xf * v
				if first:
					box = AABB(p, Vector3.ZERO)
					first = false
				else:
					box = box.expand(p)
	return box
