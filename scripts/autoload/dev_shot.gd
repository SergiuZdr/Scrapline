extends Node

## Dev-only: `-- --shot <path> [--after <frames>]` renders the running scene, writes a PNG
## and quits. Any scene gets this for free.
##
## The old game parsed `--shot` separately in every scene that wanted it, which meant a
## new screen could not be photographed until someone remembered to copy the handler in.

var _path: String = ""
var _after: int = 30
var _frame: int = 0


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find("--shot")
	if index < 0 or index + 1 >= args.size():
		set_process(false)
		return
	_path = args[index + 1]
	var after: int = args.find("--after")
	if after >= 0 and after + 1 < args.size():
		_after = maxi(1, args[after + 1].to_int())


func _process(_delta: float) -> void:
	_frame += 1
	if _frame < _after:
		return
	set_process(false)
	var image: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_path.get_base_dir())
	var error: Error = image.save_png(_path)
	print("shot: %s (%s)" % [_path, error_string(error)])
	get_tree().quit()
