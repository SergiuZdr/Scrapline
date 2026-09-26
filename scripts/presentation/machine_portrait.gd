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


func _init(size: Vector2i = Vector2i(112, 112), frame: String = "portrait") -> void:
	framing = frame
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
	environment.ambient_light_color = Color("3a4258")
	environment.ambient_light_energy = 0.9
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = environment
	_viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 35, 0)
	key.light_energy = 1.3
	key.light_color = Color("ffd3a4")
	_viewport.add_child(key)
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
func show_machine(parts: Array, level: int, alive: bool = true, number: int = -1) -> void:
	var key: String = "%s:%d:%s:%d" % [",".join(parts), level, alive, number]
	if key == _key:
		return
	_key = key
	for child: Node in _pivot.get_children():
		child.queue_free()
	# No content needed (build_parts ignores it), and none taken from the `Run` autoload: a
	# display class that names an autoload cannot be compiled by a `--script` tool (012 found
	# this one through CombatHUD).
	var model: Node3D = ConstructView.build_parts(PackedStringArray(parts), null, Color("4fa8d8"), level, number)
	_pivot.add_child(model)
	var h: float = ConstructView.height_of(model)
	# Head and shoulders, the way a crew photo is framed: the top two thirds of the machine.
	# (Not `look_at`: the portrait may not be in the tree yet when it is filled.)
	if framing == "full":
		_camera.look_at_from_position(Vector3(0.0, h * 0.6, h * 2.75), Vector3(0.0, h * 0.5, 0.0))
	else:
		_camera.look_at_from_position(Vector3(0.0, h * 0.62, h * 2.1), Vector3(0.0, h * 0.55, 0.0))
	modulate = Color(1, 1, 1) if alive else Color(1.0, 0.45, 0.4, 0.55)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
