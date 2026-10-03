extends SceneTree

## The glossary on one tab (037: the damage-type chart):
##   godot --path . --resolution 1920x1080 --script res://tools/shot_glossary.gd -- --group "DAMAGE TYPES" --out shots/g.png

func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var group: String = args[args.find("--group") + 1] if args.has("--group") else "DAMAGE TYPES"
	var out: String = args[args.find("--out") + 1] if args.has("--out") else "shots/glossary.png"
	var db: ContentDB = ContentDB.load_all()
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	var panel: Control = Glossary.open(host, db.glossary)
	panel.set("_group", group)
	panel.call("_rebuild")
	for i: int in 20:
		await process_frame
	print("shot: %s (%s)" % [out, error_string(root.get_texture().get_image().save_png(out))])
	quit()
