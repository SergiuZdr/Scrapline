extends SceneTree

## Records a fight playing itself (045): the combat scene with the bot on the player side, for
## Godot's movie writer. A tool (`--script`), so the player's profile is never touched.
##
##   godot --path . --resolution 1280x720 --write-movie shots/round.avi --fixed-fps 30 \
##       --script res://tools/record_round.gd -- --fight-file res://tools/frames/045_brute.json \
##       --bot --models gen --seconds 40
##   ffmpeg -i shots/round.avi -vf scale=1280:-2 -c:v libx264 -pix_fmt yuv420p shots/round.mp4

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--seconds")
	var seconds: float = args[at + 1].to_float() if at >= 0 and at + 1 < args.size() else 40.0
	root.add_child((load("res://scenes/combat.tscn") as PackedScene).instantiate())
	await create_timer(seconds).timeout
	quit()
