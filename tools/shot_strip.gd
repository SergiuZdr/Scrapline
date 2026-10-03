extends SceneTree

## The boss opening strip (039), photographed while it is up:
##   godot --path . --resolution 1920x1080 --script res://tools/shot_strip.gd -- --fight the_core --out shots/strip.png

func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[args.find("--out") + 1] if args.has("--out") else "shots/strip.png"
	change_scene_to_file("res://scenes/combat.tscn")
	await create_timer(4.0).timeout
	current_scene.call("_opening", "ROUT  ·  destroy every enemy")
	await create_timer(1.8).timeout
	print("shot: %s (%s)" % [out, error_string(root.get_texture().get_image().save_png(out))])
	quit()
