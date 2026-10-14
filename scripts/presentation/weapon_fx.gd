class_name WeaponFX
extends RefCounted

## 074: how each ranged arm looks when it fires (`data/fx/weapons.json`): its firing animation
## (`ConstructRig.strike` style), its trail (`ShotFX`), the trail's colour and its sound.
## Presentation only -- not in the content hash -- and read here, not through ContentDB, because the
## classes that draw are display classes that must not reach for an autoload.

const PATH: String = "res://data/fx/weapons.json"

static var _table: Dictionary = {}


static func table() -> Dictionary:
	if _table.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			for key: Variant in parsed:
				if not String(key).begins_with("_"):
					_table[String(key)] = parsed[key]
	return _table


## The look of `arm_id` (a tuned id counts as its base), or {} for an arm without one (melee).
static func of(arm_id: String) -> Dictionary:
	return table().get(PartTuning.base_of(arm_id), {})


static func fire_style(arm_id: String) -> String:
	return String(of(arm_id).get("fire", ""))


static func trail(arm_id: String) -> String:
	return String(of(arm_id).get("trail", ""))


## The trail's colour, or `fallback` (the core's damage colour) when the arm names none.
static func colour(arm_id: String, fallback: Color) -> Color:
	var hex: String = String(of(arm_id).get("colour", ""))
	return Color(hex) if not hex.is_empty() else fallback


## [bank, volume] or [] for the default sound.
static func sound(arm_id: String) -> Array:
	return of(arm_id).get("sound", [])
