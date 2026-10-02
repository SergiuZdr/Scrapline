extends SceneTree

## A button under the cursor, then pressed (035): the interactive pass in two frames.
##   godot --path . --resolution 1920x1080 --script res://tools/shot_hover.gd -- --button "NEW RUN" --out shots/hover

func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var label: String = args[args.find("--button") + 1] if args.has("--button") else "NEW RUN"
	var out: String = args[args.find("--out") + 1] if args.has("--out") else "shots/hover"
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(1.5).timeout
	var button: Button = _find(root, label)
	if button == null:
		print("no button '%s'" % label)
		quit(1)
		return
	var at: Vector2 = button.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	root.push_input(move, true)
	await create_timer(0.3).timeout
	_save(out + "_hover.png")
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = at
	down.global_position = at
	root.push_input(down, true)
	await create_timer(0.06).timeout
	_save(out + "_press.png")
	quit()


func _find(node: Node, label: String) -> Button:
	if node is Button and (node as Button).text.strip_edges() == label and (node as Button).is_visible_in_tree():
		return node
	for child: Node in node.get_children():
		var found: Button = _find(child, label)
		if found != null:
			return found
	return null


func _save(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	print("shot: %s (%s)" % [path, error_string(root.get_texture().get_image().save_png(path))])
