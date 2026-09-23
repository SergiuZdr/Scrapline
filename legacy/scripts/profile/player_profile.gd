class_name PlayerProfile
extends RefCounted

## Typed access to everything the player owns.
##
## The underlying store is the plain Dictionary that `SaveFile` reads and writes, so
## there is exactly one representation of a profile and no serialisation step that can
## drift out of sync with the live object. This class only puts names and types on it.
##
## Nothing here mutates. Every change goes through a command (see
## `scripts/commands/`), which is what keeps saving, undo, and later server
## reconciliation a single problem rather than three separate ones.

const SCRAP: String = "scrap"
const ALLOY: String = "alloy"
const CORES: String = "cores"

## Rarity tiers a part can be refit up to. Tier 0 is as-found.
const MAX_TIER: int = 4
## A part's level ceiling rises with its tier, so refitting is what unlocks headroom
## rather than being a separate power track.
const LEVELS_PER_TIER: int = 5

var data: Dictionary


func _init(profile_data: Dictionary = {}) -> void:
	data = profile_data if not profile_data.is_empty() else SaveFile.default_profile()


static func from_save(file: SaveFile) -> PlayerProfile:
	return PlayerProfile.new(file.data)


# --- Currencies --------------------------------------------------------------

func currency(kind: String) -> int:
	return int((data["currencies"] as Dictionary).get(kind, 0))


func can_afford(kind: String, amount: int) -> bool:
	return amount >= 0 and currency(kind) >= amount


# --- Inventory ---------------------------------------------------------------

func inventory() -> Dictionary:
	return data["inventory"] as Dictionary


func owns(part_id: String) -> bool:
	return inventory().has(part_id)


func entry(part_id: String) -> Dictionary:
	return inventory().get(part_id, {"level": 0, "copies": 0, "tier": 0})


func part_level(part_id: String) -> int:
	return int(entry(part_id).get("level", 0))


func part_copies(part_id: String) -> int:
	return int(entry(part_id).get("copies", 0))


func part_tier(part_id: String) -> int:
	return int(entry(part_id).get("tier", 0))


## Level ceiling for a part at its current tier. Refit raises the ceiling; scrap
## raises the level toward it.
func level_cap(part_id: String) -> int:
	return (part_tier(part_id) + 1) * LEVELS_PER_TIER


func is_max_level(part_id: String) -> bool:
	return part_level(part_id) >= level_cap(part_id)


## Owned part ids, sorted. Sorted because Dictionary key order reflects insertion
## order, and any UI list or server payload built from this must be stable.
func owned_part_ids() -> PackedStringArray:
	var ids: Array = inventory().keys()
	ids.sort()
	var out: PackedStringArray = []
	for id: Variant in ids:
		out.append(String(id))
	return out


func owned_in_slot(slot: String, content: ContentDB) -> PackedStringArray:
	var out: PackedStringArray = []
	for id: String in owned_part_ids():
		var part: Dictionary = content.parts.get(id, {})
		if String(part.get("slot", "")) == slot:
			out.append(id)
	return out


# --- Squads ------------------------------------------------------------------

func squad(name: String = "main") -> Array:
	return (data["squads"] as Dictionary).get(name, [])


func squad_names() -> PackedStringArray:
	var names: Array = (data["squads"] as Dictionary).keys()
	names.sort()
	var out: PackedStringArray = []
	for n: Variant in names:
		out.append(String(n))
	return out


## True when every part a squad references is actually owned. A squad can go invalid
## when a part is consumed by a Refit, so this is checked before a battle rather than
## trusted.
func squad_is_valid(name: String = "main") -> bool:
	for spec: Variant in squad(name):
		var parts: Dictionary = (spec as Dictionary).get("parts", {})
		for key: Variant in parts.keys():
			var id: String = String(parts[key])
			if not id.is_empty() and not owns(id):
				return false
	return true


# --- Progress ----------------------------------------------------------------

func stat(key: String) -> int:
	return int((data["stats"] as Dictionary).get(key, 0))


func cleared_nodes() -> Array:
	return (data["campaign"] as Dictionary).get("cleared", [])


func has_cleared(node_id: String) -> bool:
	return cleared_nodes().has(node_id)


func summary() -> String:
	return "scrap %d  alloy %d  cores %d  parts %d  battles %d (%d won)" % [
		currency(SCRAP), currency(ALLOY), currency(CORES),
		inventory().size(), stat("battles"), stat("wins"),
	]
