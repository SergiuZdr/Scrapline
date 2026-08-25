class_name Battlefield
extends RefCounted

## The map: a grid of terrain tiles the constructs fight across.
##
## Terrain is what stops movement from being decoration. A tile can slow a unit down,
## shelter it, lift its weapons' reach, or cook it alive -- so where a construct
## chooses to stand is a decision, and a brawler crossing open ground to reach a
## marksman on a ridge is paying a real price for it.
##
## Tiles are authored as rows of characters in `data/maps/*.json`, which makes a map
## readable and editable as text.

## World size of one tile, in sim units (see SimMath.UNIT).
const TILE: int = 100

var width: int = 0        ## tiles
var depth: int = 0        ## tiles
var id: String = ""
var display_name: String = ""

## Row-major tile-type indices, `depth` rows of `width` entries.
var tiles: PackedInt32Array = PackedInt32Array()
## Tile type index -> definition dictionary.
var types: Array[Dictionary] = []
## Legend character -> tile type index.
var _legend: Dictionary = {}

## Deployment anchors in sim units, per team, indexed by formation row.
var deploy_z: Array = [[], []]
var deploy_x: PackedInt32Array = PackedInt32Array()
var slot_x: PackedInt32Array = PackedInt32Array()


static func from_data(map_data: Dictionary, tile_types: Array) -> Battlefield:
	var field := Battlefield.new()
	field.id = String(map_data.get("id", ""))
	field.display_name = String(map_data.get("name", ""))

	# Tile type 0 is always the fallback, so an unknown legend character degrades to
	# open ground instead of crashing a battle.
	for entry: Variant in tile_types:
		var definition: Dictionary = entry as Dictionary
		field._legend[String(definition.get("glyph", "."))] = field.types.size()
		field.types.append(definition)
	if field.types.is_empty():
		field.types.append({"id": "open", "glyph": ".", "move_pct": 100, "cover": 0, "range_bonus": 0, "heat_per_tick": 0})

	var rows: Array = map_data.get("rows", [])
	field.depth = rows.size()
	field.width = String(rows[0]).length() if field.depth > 0 else 0
	field.tiles.resize(field.width * field.depth)
	field.tiles.fill(0)

	for row_index: int in field.depth:
		var row: String = String(rows[row_index])
		for column: int in mini(field.width, row.length()):
			field.tiles[row_index * field.width + column] = int(field._legend.get(row[column], 0))

	var deploy: Dictionary = map_data.get("deploy", {})
	field.deploy_x = PackedInt32Array(deploy.get("columns_x", [440, 760]))
	field.deploy_z = [
		deploy.get("team_a_z", [500, 350, 200]),
		deploy.get("team_b_z", [1300, 1450, 1600]),
	]
	# Per-slot lateral offsets, so a formation can be staggered across the width of
	# the map rather than stacked in two straight files. Six entries, one per slot.
	field.slot_x = PackedInt32Array(deploy.get("slot_x", []))
	return field


# --- Queries -----------------------------------------------------------------

func type_at(x: int, z: int) -> Dictionary:
	var column: int = SimMath.clamp_int(x / TILE, 0, maxi(0, width - 1))
	var row: int = SimMath.clamp_int(z / TILE, 0, maxi(0, depth - 1))
	var index: int = row * width + column
	if index < 0 or index >= tiles.size():
		return types[0]
	return types[tiles[index]]


## Percent multiplier on movement speed for the tile under a unit.
func move_percent(x: int, z: int) -> int:
	return int(type_at(x, z).get("move_pct", 100))


## Percent damage reduction granted to whatever is standing here.
func cover_at(x: int, z: int) -> int:
	return int(type_at(x, z).get("cover", 0))


## Extra weapon reach from elevation, in sim units.
func range_bonus_at(x: int, z: int) -> int:
	return int(type_at(x, z).get("range_bonus", 0))


## Heat forced on anything standing here, per passive-vent interval.
func heat_at(x: int, z: int) -> int:
	return int(type_at(x, z).get("heat_per_tick", 0))


func tile_id_at(x: int, z: int) -> String:
	return String(type_at(x, z).get("id", "open"))


func max_x() -> int:
	return maxi(0, width * TILE - 1)


func max_z() -> int:
	return maxi(0, depth * TILE - 1)


## Keeps a unit on the map. Constructs may push each other around, but nothing walks
## off the edge of the world.
func clamp_position(x: int, z: int) -> Array[int]:
	return [SimMath.clamp_int(x, 0, max_x()), SimMath.clamp_int(z, 0, max_z())]


## Where a unit starts, from its team and formation slot. Row 0 is the front rank and
## deploys closest to the enemy.
func spawn_position(team: int, slot: int) -> Array[int]:
	var row: int = SimDefs.row_of_slot(slot)
	var column: int = slot % 2
	var x: int
	if slot < slot_x.size():
		x = slot_x[slot]
	elif column < deploy_x.size():
		x = deploy_x[column]
	else:
		x = (width * TILE) / 2
	var lane: Array = deploy_z[team]
	var z: int = int(lane[row]) if row < lane.size() else (depth * TILE) / 2
	return [x, z]
