class_name CombatSetup
extends RefCounted

## Everything a fight needs before its first turn, resolved from content into plain
## numbers. `CombatSim.start` builds a fresh `CombatState` from this every time, which is
## what makes replay (and so undo and save) exact: the setup never changes.
##
## Pure: it takes dictionaries that `ContentDB` loaded outside `sim/`, and reads no files.

var fight_id: String = ""
var rng_seed: int = 0
var width: int = 0
var height: int = 0
## Tile type per cell (index into the tiles list), row-major, `y * width + x`.
var tiles: PackedInt32Array = []
## 1 where the tile type blocks movement and shots.
var blocks: PackedByteArray = []
var max_rounds: int = 20
var units: Array[GridUnit] = []
var errors: PackedStringArray = []


## `fight`: a `data/fights/*.json` record. `rules`: `data/combat/prototype.json`.
## `parts`: ContentDB.parts. `tiles`: ContentDB.tiles (file order = tile id).
static func build(fight: Dictionary, rules: Dictionary, parts: Dictionary, tile_defs: Array,
		seed_value: int) -> CombatSetup:
	var setup := CombatSetup.new()
	setup.fight_id = String(fight.get("id", ""))
	setup.rng_seed = seed_value
	setup.max_rounds = int(rules.get("max_rounds", 20))

	var glyph_to_tile: Dictionary = {}
	for index: int in tile_defs.size():
		var def: Dictionary = tile_defs[index]
		glyph_to_tile[String(def.get("glyph", ""))] = index

	var rows: Array = fight.get("rows", [])
	setup.height = rows.size()
	setup.width = String(rows[0]).length() if not rows.is_empty() else 0
	setup.tiles.resize(setup.width * setup.height)
	setup.blocks.resize(setup.width * setup.height)
	for y: int in setup.height:
		var row: String = String(rows[y])
		if row.length() != setup.width:
			setup.errors.append("row %d is %d wide, expected %d" % [y, row.length(), setup.width])
			continue
		for x: int in setup.width:
			var glyph: String = row[x]
			var tile: int = int(glyph_to_tile.get(glyph, 0))
			if not glyph_to_tile.has(glyph):
				setup.errors.append("unknown glyph '%s' at (%d,%d)" % [glyph, x, y])
			setup.tiles[y * setup.width + x] = tile
			setup.blocks[y * setup.width + x] = 1 if bool((tile_defs[tile] as Dictionary).get("blocks", false)) else 0

	var slot_lists: Array = [fight.get("player", []), fight.get("enemy", [])]
	for team: int in 2:
		var specs: Array = slot_lists[team]
		for slot: int in specs.size():
			var unit: GridUnit = _build_unit(specs[slot], team, slot, rules, parts, setup.errors)
			setup.units.append(unit)
	return setup


static func _build_unit(spec: Dictionary, team: int, slot: int, rules: Dictionary,
		parts: Dictionary, errors: PackedStringArray) -> GridUnit:
	var u := GridUnit.new()
	u.team = team
	u.slot = slot
	u.ref = team * 10 + slot
	u.name = String(spec.get("name", "Unit %d" % u.ref))
	for id: Variant in spec.get("parts", []):
		u.part_ids.append(String(id))
	u.x = int(spec.get("x", 0))
	u.y = int(spec.get("y", 0))

	var chassis: Dictionary = parts.get(u.part_ids[0] if u.part_ids.size() > 0 else "", {})
	var role: String = String(chassis.get("role", "line"))
	var role_stats: Dictionary = (rules.get("roles", {}) as Dictionary).get(role, {})
	if role_stats.is_empty():
		errors.append("%s: no stats for role '%s'" % [u.name, role])
	u.max_hp = int(spec.get("hp", role_stats.get("hp", 10)))
	u.hp = u.max_hp
	u.move = int(role_stats.get("move", 3))

	var arm: Dictionary = parts.get(u.part_ids[3] if u.part_ids.size() > 3 else "", {})
	u.weapon_class = String(arm.get("weapon_class", ""))
	var weapons: Dictionary = rules.get("weapons", {})
	var found: bool = false
	# Sorted, so a class listed under two groups resolves the same way every run.
	var group_names: Array = weapons.keys()
	group_names.sort()
	for group_name: Variant in group_names:
		var group: Dictionary = weapons[group_name]
		if (group.get("classes", []) as Array).has(u.weapon_class):
			u.attack_range = int(group.get("range", 1))
			u.damage = int(group.get("damage", 1))
			found = true
			break
	if not found:
		errors.append("%s: weapon class '%s' is in no weapon group" % [u.name, u.weapon_class])
	return u
