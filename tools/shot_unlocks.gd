extends SceneTree

## The UNLOCKS panel (027) with a made-up profile, for a screenshot:
##   godot --path . --resolution 1920x1080 --script res://tools/shot_unlocks.gd -- --out shots/unlocks.png

func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var db: ContentDB = ContentDB.load_all()
	var stats: Dictionary = {"runs": 4, "fights": 13, "act": 2, "wins": 0}
	var held: Array = Meta.earned(stats, db.meta)
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	host.add_child(UIKit.backdrop())
	UnlocksPanel.open(host, db, held, stats, [held[-1]] if not held.is_empty() else [])
	for i: int in 20:
		await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[args.find("--out") + 1] if args.has("--out") else "shots/unlocks.png"
	print("shot: %s (%s)" % [out, error_string(root.get_texture().get_image().save_png(out))])
	quit()
