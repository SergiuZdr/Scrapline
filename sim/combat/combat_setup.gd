class_name CombatSetup
extends RefCounted

## Everything a fight needs before its first turn, resolved from content into plain
## numbers. `CombatSim.start` builds a fresh `CombatState` from this every time, which is
## what makes replay (and so undo and save) exact: the setup never changes.
##
## A construct is its parts. Every stat below comes from the `grid` block of one of the
## five parts it is built from, plus its chassis role's trait from the rules. There is no
## per-unit stat sheet anywhere.
##
## Pure: it takes dictionaries that `ContentDB` loaded outside `sim/`, and reads no files.

var fight_id: String = ""
var rng_seed: int = 0
var width: int = 0
var height: int = 0
## Tile type per cell (index into the tiles list), row-major, `y * width + x`.
var tiles: PackedInt32Array = []
## Per-cell terrain, resolved from each tile's `grid` block.
var blocks: PackedByteArray = []
var move_cost: PackedByteArray = []
var cover: PackedByteArray = []
var range_bonus: PackedByteArray = []
var hazard: PackedByteArray = []

var max_rounds: int = 20
var min_damage: int = 1
var tear_threshold: int = 5
var bump_damage: int = 1
var mark_bonus: int = 2
## Percent effectiveness, `[damage_type][armor_type]`.
var wheel: Array = []
var units: Array[GridUnit] = []
var errors: PackedStringArray = []


## `fight`: a `data/fights/*.json` record. `rules`: `data/combat/rules.json`.
## `parts`: ContentDB.parts. `tile_defs`: ContentDB.tiles (file order = tile id).
## `wheel`: `Balance.effectiveness`.
static func build(fight: Dictionary, rules: Dictionary, parts: Dictionary, tile_defs: Array,
		wheel: Array, seed_value: int) -> CombatSetup:
	var setup := CombatSetup.new()
	setup.fight_id = String(fight.get("id", ""))
	setup.rng_seed = seed_value
	setup.max_rounds = int(rules.get("max_rounds", 20))
	setup.min_damage = int(rules.get("min_damage", 1))
	setup.tear_threshold = int(rules.get("tear_threshold", 5))
	setup.bump_damage = int(rules.get("bump_damage", 1))
	setup.mark_bonus = int(rules.get("mark_bonus", 2))
	setup.wheel = wheel

	var glyph_to_tile: Dictionary = {}
	for index: int in tile_defs.size():
		glyph_to_tile[String((tile_defs[index] as Dictionary).get("glyph", ""))] = index

	var rows: Array = fight.get("rows", [])
	setup.height = rows.size()
	setup.width = String(rows[0]).length() if not rows.is_empty() else 0
	var cells: int = setup.width * setup.height
	setup.blocks.resize(cells)
	setup.move_cost.resize(cells)
	setup.cover.resize(cells)
	setup.range_bonus.resize(cells)
	setup.hazard.resize(cells)
	setup.tiles.resize(cells)
	for y: int in setup.height:
		var row: String = String(rows[y])
		if row.length() != setup.width:
			setup.errors.append("row %d is %d wide, expected %d" % [y, row.length(), setup.width])
			continue
		for x: int in setup.width:
			var glyph: String = row[x]
			if not glyph_to_tile.has(glyph):
				setup.errors.append("unknown glyph '%s' at (%d,%d)" % [glyph, x, y])
			var tile: int = int(glyph_to_tile.get(glyph, 0))
			var def: Dictionary = tile_defs[tile]
			var grid: Dictionary = def.get("grid", {})
			var i: int = y * setup.width + x
			setup.tiles[i] = tile
			setup.blocks[i] = 1 if bool(def.get("blocks", false)) else 0
			setup.move_cost[i] = maxi(1, int(grid.get("move_cost", 1)))
			setup.cover[i] = int(grid.get("cover", 0))
			setup.range_bonus[i] = int(grid.get("range", 0))
			setup.hazard[i] = int(grid.get("hazard", 0))

	var damage_types: Array = rules.get("damage_types", [])
	var armor_types: Array = rules.get("armor_types", [])
	var roles: Dictionary = rules.get("roles", {})
	var slot_lists: Array = [fight.get("player", []), fight.get("enemy", [])]
	for team: int in 2:
		var specs: Array = slot_lists[team]
		for slot: int in specs.size():
			setup.units.append(_build_unit(specs[slot], team, slot, parts, roles,
				damage_types, armor_types, setup.errors))

	var crawler_spec: Dictionary = fight.get("crawler", {})
	if not crawler_spec.is_empty():
		setup.units.append(_build_crawler(crawler_spec, (slot_lists[0] as Array).size(),
			int(crawler_spec.get("hp", rules.get("crawler_hp", 12))), rules))
	return setup


static func _build_unit(spec: Dictionary, team: int, slot: int, parts: Dictionary,
		roles: Dictionary, damage_types: Array, armor_types: Array,
		errors: PackedStringArray) -> GridUnit:
	var u := GridUnit.new()
	u.team = team
	u.slot = slot
	u.ref = team * 10 + slot
	u.name = String(spec.get("name", "Unit %d" % u.ref))
	for id: Variant in spec.get("parts", []):
		u.part_ids.append(String(id))
	u.x = int(spec.get("x", 0))
	u.y = int(spec.get("y", 0))
	if u.part_ids.size() != 5:
		errors.append("%s: needs 5 parts (chassis, core, arm_l, arm_r, module), has %d" % [u.name, u.part_ids.size()])
		return u

	var chassis: Dictionary = _part(parts, u.part_ids[0], "chassis", u.name, errors)
	var core: Dictionary = _part(parts, u.part_ids[1], "core", u.name, errors)
	var module: Dictionary = _part(parts, u.part_ids[4], "module", u.name, errors)
	var cg: Dictionary = chassis.get("grid", {})
	var og: Dictionary = core.get("grid", {})
	var mg: Dictionary = module.get("grid", {})

	u.role = String(chassis.get("role", "line"))
	u.max_hp = int(spec.get("hp", int(cg.get("hp", 8)) + int(mg.get("hp", 0))))
	u.hp = u.max_hp
	u.move = int(cg.get("move", 3)) + int(mg.get("move", 0))
	u.heat_cap = int(cg.get("heat_cap", 6)) + int(mg.get("heat_cap", 0))
	u.armor = int(mg.get("armor", 0))
	u.armor_type = maxi(0, armor_types.find(String(chassis.get("armor_type", ""))))
	u.damage_type = maxi(0, damage_types.find(String(core.get("damage_type", ""))))
	u.vent = int(og.get("vent", 1)) + int(mg.get("vent", 0))
	u.damage_bonus = int(og.get("damage", 0)) + int(mg.get("damage", 0))
	u.heat_bonus = int(og.get("heat", 0)) + int(mg.get("heat", 0))
	u.range_bonus = int(mg.get("range", 0))

	var role_trait: Dictionary = roles.get(u.role, {})
	u.melee_bonus = int(role_trait.get("melee_damage", 0))
	u.range_bonus += int(role_trait.get("line_range", 0))
	u.unshovable = bool(role_trait.get("unshovable", false))
	u.move_after_attack = bool(role_trait.get("move_after_attack", false))

	for index: int in [2, 3]:
		var arm: Dictionary = _part(parts, u.part_ids[index], "arm", u.name, errors)
		u.weapons.append(weapon_from(arm))
	return u


## A weapon is its arm's `grid` block with every key present, so the sim never has to
## guess a default.
static func weapon_from(arm: Dictionary) -> Dictionary:
	var g: Dictionary = arm.get("grid", {})
	return {
		"id": String(arm.get("id", "")),
		"name": String(arm.get("name", "")),
		"class": String(arm.get("weapon_class", "")),
		"shape": String(g.get("shape", "melee")),
		"range_min": int(g.get("range_min", 1)),
		"range": int(g.get("range", 1)),
		"damage": int(g.get("damage", 0)),
		"heat": int(g.get("heat", 0)),
		"shove": int(g.get("shove", 0)),
		"pierce": int(g.get("pierce", 0)),
		"splash": int(g.get("splash", 0)),
		"chain": int(g.get("chain", 0)),
		"mark": bool(g.get("mark", false)),
		"tears": bool(g.get("tears", false)),
		"torn": false,
	}


static func _build_crawler(spec: Dictionary, slot: int, hp: int, rules: Dictionary) -> GridUnit:
	var u := GridUnit.new()
	u.team = GridUnit.TEAM_PLAYER
	u.slot = slot
	u.ref = slot
	u.name = "Crawler"
	u.objective = true
	u.x = int(spec.get("x", 0))
	u.y = int(spec.get("y", 0))
	u.max_hp = hp
	u.hp = hp
	u.move = 0
	u.unshovable = true
	var armor_types: Array = rules.get("armor_types", [])
	u.armor_type = maxi(0, armor_types.find("plate"))
	return u


static func _part(parts: Dictionary, id: String, what: String, owner: String,
		errors: PackedStringArray) -> Dictionary:
	if not parts.has(id):
		errors.append("%s: unknown %s '%s'" % [owner, what, id])
		return {}
	return parts[id]
