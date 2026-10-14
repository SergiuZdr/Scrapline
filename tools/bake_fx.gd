extends SceneTree

## 076: paints every effect drawing once and writes it to `art/fx/<name>.png`, which `Ink.texture` then
## loads instead of painting (the gritty drawings take seconds). Run after changing a drawing in
## `ShotFX`, `Grit` or `BattleVFX`, or a colour in `data/fx/weapons.json`, then `--import`:
##
##   godot --headless --path . --script res://tools/bake_fx.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Ink.BAKED))
	Ink.bake_to = ProjectSettings.globalize_path(Ink.BAKED)
	var holder := Node3D.new()
	root.add_child(holder)
	var camera := Camera3D.new()
	holder.add_child(camera)
	var vfx := BattleVFX.new()
	holder.add_child(vfx)
	vfx.setup(camera)
	ShotFX.warm(holder, vfx, Vector3.ZERO)
	for i: int in 4:
		Grit.smoke_texture(i)
	# Fire the tweens that paint later (a mine's lit eye).
	for i: int in 90:
		await process_frame
	print("baked %d drawings into %s" % [Ink.painted.size(), Ink.BAKED])
	quit()
