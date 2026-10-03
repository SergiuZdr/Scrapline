class_name MachinePortrait
extends SubViewportContainer

## A crew machine's portrait: the real model, levels and all, in a tiny studio of its own,
## drawn once and redrawn only when the machine changes. Play-test 4 called the crew list
## on the map bad; part thumbnails of a chassis were never a picture of THE machine.
##
## One SubViewport per portrait, updated once (`UPDATE_ONCE`), so three of them cost three
## frames of rendering in total rather than three every frame.

var _viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _key: String = ""
## "portrait": head and shoulders (the crew dock). "full": the whole machine, feet to
## antenna (the assembly bay, where the whole build is the point).
var framing: String = "portrait"
## Ink & Rust (015): drawn like the fight -- toon zones, ink lines, one hard key -- for the
## combat HUD's cards. The map and the bay keep the old look until the frame is approved.
var ink: bool = false


func _init(size: Vector2i = Vector2i(112, 112), frame: String = "portrait", inked: bool = false) -> void:
	framing = frame
	ink = inked
	stretch = true
	custom_minimum_size = Vector2(size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.size = size
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_viewport)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	if ink:
		# The fight's light: a flat night ambient under one key from the camera's left.
		environment.ambient_light_color = Color("6b7390")
		environment.ambient_light_energy = 1.0
		environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	else:
		environment.ambient_light_color = Color("3a4258")
		environment.ambient_light_energy = 0.9
		environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	_viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 35, 0) if not ink else Vector3(-32, -20, 0)
	key.light_energy = 1.3 if not ink else 1.0
	key.light_color = Color("ffd3a4") if not ink else Color("fff0da")
	_viewport.add_child(key)
	if not ink:
		var rim := DirectionalLight3D.new()
		rim.rotation_degrees = Vector3(-15, -150, 0)
		rim.light_energy = 1.1
		rim.light_color = Color("8aa3de")
		_viewport.add_child(rim)
	_pivot = Node3D.new()
	_pivot.rotation.y = 0.55
	_viewport.add_child(_pivot)
	_camera = Camera3D.new()
	_camera.fov = 30.0
	_viewport.add_child(_camera)
	_camera.current = true


## Shows this machine; does nothing if it is the one already shown.
func show_machine(parts: Array, level: int, alive: bool = true, paint: Color = Color(0, 0, 0, 0)) -> void:
	var key: String = "%s:%d:%s:%s" % [",".join(parts), level, alive, paint.to_html()]
	if key == _key:
		return
	_key = key
	for child: Node in _pivot.get_children():
		child.queue_free()
	# No content needed (build_parts ignores it), and none taken from the `Run` autoload: a
	# display class that names an autoload cannot be compiled by a `--script` tool (012 found
	# this one through CombatHUD).
	var model: Node3D = ConstructView.build_parts(PackedStringArray(parts), null, Color("4fa8d8"), level)
	if ink and not parts.is_empty():
		Ink.dress_machine(model, PackedStringArray(parts), Ink.YOURS, paint)
	_pivot.add_child(model)
	var h: float = ConstructView.height_of(model)
	# Play-test 11: a wide frame (an anchor, a big arm) was cut at the sides -- frame the larger of
	# the machine's height and its width, so the whole silhouette fits.
	h = maxf(h, _width_of(model) * 0.92)
	# Head and shoulders, the way a crew photo is framed: the top two thirds of the machine.
	# (Not `look_at`: the portrait may not be in the tree yet when it is filled.)
	if framing == "full":
		_frame_whole(model)
	else:
		_camera.look_at_from_position(Vector3(0.0, h * 0.62, h * 2.1), Vector3(0.0, h * 0.55, 0.0))
	modulate = Color(1, 1, 1) if alive else Color(1.0, 0.45, 0.4, 0.55)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## 043 (play-test 13: "the crew view does not show the entire robot if its arms are too big"):
## the whole machine, as the camera sees it -- its bounds measured after the three-quarter turn,
## the camera centred on them and backed off until both the height and the width fit the frame.
func _frame_whole(model: Node3D) -> void:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var stack: Array[Node] = [model]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var mesh := node as MeshInstance3D
			var box: AABB = mesh.mesh.get_aabb()
			var t: Transform3D = _pivot.transform * model.transform * _relative(mesh, model)
			for i: int in 8:
				var p: Vector3 = t * box.get_endpoint(i)
				lo = lo.min(p)
				hi = hi.max(p)
	if lo.x == INF:
		return
	var centre: Vector3 = (lo + hi) * 0.5
	var span: Vector3 = hi - lo
	var aspect: float = float(_viewport.size.x) / maxf(1.0, float(_viewport.size.y))
	var tan_half: float = tan(deg_to_rad(_camera.fov * 0.5))
	var distance: float = maxf(span.y / (2.0 * tan_half), span.x / (2.0 * tan_half * aspect)) * 1.12 + span.z * 0.5
	_camera.look_at_from_position(centre + Vector3(0.0, span.y * 0.12, distance), centre)


## The machine's width across x, from its meshes' bounds (framing only: a rough box is enough).
func _width_of(model: Node3D) -> float:
	var lo: float = 0.0
	var hi: float = 0.0
	var stack: Array[Node] = [model]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var mesh := node as MeshInstance3D
			var box: AABB = mesh.mesh.get_aabb()
			var t: Transform3D = _relative(mesh, model)
			for i: int in 8:
				var p: Vector3 = t * box.get_endpoint(i)
				lo = minf(lo, p.x)
				hi = maxf(hi, p.x)
	return hi - lo


func _relative(node: Node3D, root: Node3D) -> Transform3D:
	var t: Transform3D = node.transform
	var parent: Node = node.get_parent()
	while parent != null and parent != root and parent is Node3D:
		t = (parent as Node3D).transform * t
		parent = parent.get_parent()
	return t
