extends SceneTree

## 082 (A24): a screenshot of the settings sheet over the title, on the tool profile (never the
## player's). `--confirm` shows the ABANDON RUN question; a run is started on the tool save so
## the run section shows.
##
##   godot --path . --resolution 1920x1080 --script res://tools/shot_settings.gd -- --out shots/082/settings.png [--confirm]

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[args.find("--out") + 1] if args.has("--out") else "shots/082/settings.png"
	var run: Node = root.get_node("Run")
	if not bool(run.call("has_saved")):
		run.call("new_run", 3)
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(2.0).timeout
	(load("res://scripts/ui/settings_sheet.gd") as GDScript).call("open", current_scene as Control)
	await create_timer(0.5).timeout
	var sheet: Node = get_first_node_in_group("settings_sheet")
	if args.has("--confirm") and sheet != null:
		(sheet.find_child("abandon", true, false) as Button).pressed.emit()
	await create_timer(1.0).timeout
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out.get_base_dir()))
	root.get_texture().get_image().save_png("res://" + out)
	print("saved ", out)
	quit(0)
