class_name Models
extends RefCounted

## Which models the game draws (017): the shipped set, or the NEW set under proof.
##
## `-- --models new` swaps in whatever the new set has -- machine parts from
## `art/parts_new/` (route A, `tools/blender/make_ink_parts.py`), their pictures from
## `art/thumbs_new/`, and landmarks from `art/sites/` (route C, `tools/blender/clean_generated.py`)
## -- and falls back to the shipped model for everything it does not have. So a proof can
## stand one new machine among the old ones, in every screen, without the default game
## changing until the user picks (docs/plans/models.md).
##
## Static and read from the command line, because the classes that draw (`ConstructView`,
## `YardView`, `PartText`) are display classes that must not reach for an autoload.

const NEW_PARTS: String = "res://art/parts_new"
const NEW_THUMBS: String = "res://art/thumbs_new"
const SITES: String = "res://art/sites"

## -1 until read, then 0 (shipped) or 1 (new).
static var _new: int = -1


static func new_models() -> bool:
	if _new < 0:
		var args: PackedStringArray = OS.get_cmdline_user_args()
		var at: int = args.find("--models")
		_new = 1 if at >= 0 and at + 1 < args.size() and args[at + 1] == "new" else 0
	return _new == 1


## For tools and tests that compare both sets in one process.
static func use_new(on: bool) -> void:
	_new = 1 if on else 0


## The model file for a part: the new one if asked for and it exists, else the shipped one.
static func part_path(part_id: String) -> String:
	if new_models():
		var path: String = "%s/%s.glb" % [NEW_PARTS, part_id]
		if ResourceLoader.exists(path):
			return path
	return "%s/%s.glb" % [ConstructView.PARTS_DIR, part_id]


## The picture of a new part, or "" to use the shipped pictures.
static func thumb_path(part_id: String) -> String:
	if new_models():
		var path: String = "%s/%s.png" % [NEW_THUMBS, part_id]
		if ResourceLoader.exists(path):
			return path
	return ""


## A generated landmark for a site type, or null to build the kit landmark.
static func site(kind: String) -> PackedScene:
	if not new_models():
		return null
	var path: String = "%s/%s.glb" % [SITES, kind]
	return load(path) as PackedScene if ResourceLoader.exists(path) else null
