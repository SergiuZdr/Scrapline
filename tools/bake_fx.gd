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
	# 078: every BattleVFX drawing too (their colours as the fight uses them).
	var at := Vector3.ZERO
	# The fight's damage colours (`combat_scene.DAMAGE_COLOURS`) and every colour it bursts in.
	var damage: Array = [Color("ffcf9a"), Color("ff7a3c"), Color("7fd4ff"), Color("b5e05a")]
	for colour: Color in damage:
		vfx.muzzle_flash(at, at + Vector3(1, 0, 0), colour.lightened(0.5))
		vfx.burst(at, colour, 1.0)
	for colour: Color in [Color("ff7a3c"), Color("ff8a3c"), Color("ffb060"), Color("c9a2ff"), Color("e8f0ee"),
			Ink.ACTION, Ink.DANGER]:
		vfx.muzzle_flash(at, at + Vector3(1, 0, 0), colour)
		vfx.burst(at, colour, 1.0)
	vfx.impact(at, Color("ffb070"), 1.0)
	vfx.fireball(at, 1.0)
	vfx.dust(at, 6, 1.0)
	vfx.ground_lines(at, 1.0)
	for i: int in 3:
		Grit.blast_texture(i)
		Grit.shard_texture(i)
	# Fire the tweens that paint later (a mine's lit eye).
	for i: int in 90:
		await process_frame
	print("baked %d drawings into %s" % [Ink.painted.size(), Ink.BAKED])
	quit()
