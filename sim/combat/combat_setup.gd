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
## 1 on a pit: nothing walks in, shots pass over, anything shoved in is destroyed.
var pit: PackedByteArray = []
## Objects on the board at the start: `[{ "x", "y", "kind": "barrel"|"crate", "hp" }]`.
var start_props: Array = []
var barrel_damage: int = 3
var crate_hp: int = 3
## `data/combat/enemy_kinds.json`, for the rules that need a kind's numbers.
var kinds: Dictionary = {}
## What a hive builds, resolved from its parts once so a spawn is a copy, not a lookup.
var drone: GridUnit = null

var max_rounds: int = 20
var min_damage: int = 1
var tear_threshold: int = 5
var bump_damage: int = 1
var mark_bonus: int = 2
## A destroyed machine's scrap pile: what it is worth, and what collecting it patches.
var pile_value: int = 4
var pile_heal: int = 2
## `{ "type": "rout"|"defend"|"salvage", "rounds": int, "need": int }` -- see CombatSim.
var objective: Dictionary = {"type": "rout"}
## Scrap piles on the board at the start: `[{ "x", "y", "value" }]`.
var start_piles: Array = []
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
	setup.pile_value = int(rules.get("pile_value", 4))
	setup.pile_heal = int(rules.get("pile_heal", 2))
	setup.wheel = wheel
	setup.barrel_damage = int(rules.get("barrel_damage", 3))
	setup.crate_hp = int(rules.get("crate_hp", 3))
	setup.kinds = rules.get("enemy_kinds", {})
	var objective: Dictionary = fight.get("objective", {"type": "rout"})
	setup.objective = {"type": String(objective.get("type", "rout")),
		"rounds": int(objective.get("rounds", 0)), "need": int(objective.get("need", 0))}
	for pile: Dictionary in (objective.get("piles", []) as Array):
		setup.start_piles.append({"x": int(pile["x"]), "y": int(pile["y"]),
			"value": int(pile.get("value", setup.pile_value))})

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
	setup.pit.resize(cells)
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
			setup.pit[i] = int(grid.get("pit", 0))
			var prop: String = String(grid.get("prop", ""))
			if not prop.is_empty():
				var prop_hp: int = int(rules.get("%s_hp" % prop, 1))
				setup.start_props.append({"x": x, "y": y, "kind": prop, "hp": prop_hp})

	var damage_types: Array = rules.get("damage_types", [])
	var armor_types: Array = rules.get("armor_types", [])
	var roles: Dictionary = rules.get("roles", {})
	var slot_lists: Array = [fight.get("player", []), fight.get("enemy", [])]
	for team: int in 2:
		var specs: Array = slot_lists[team]
		for slot: int in specs.size():
			setup.units.append(_build_unit(specs[slot], team, slot, parts, roles,
				damage_types, armor_types, setup.errors, rules.get("abilities", {})))

	var drone_spec: Dictionary = (setup.kinds.get("hive", {}) as Dictionary).get("drone", {})
	if not drone_spec.is_empty():
		setup.drone = _build_unit(drone_spec, GridUnit.TEAM_ENEMY, 9, parts, roles, damage_types,
			armor_types, setup.errors)
		setup.drone.name = String(drone_spec.get("name", "Drone"))

	# Salvage caches (the defend objective): immobile, unarmed, on the player's side. They
	# take refs after the crew, so the crew's refs are always 0..2.
	var caches: Array = objective.get("caches", [])
	for i: int in caches.size():
		setup.units.append(_build_cache(caches[i], (slot_lists[0] as Array).size() + i,
			int((caches[i] as Dictionary).get("hp", rules.get("cache_hp", 5))), rules))

	# Two things on one hex is a broken fight file, not a rule: say so instead of letting a
	# cache and a machine share a hex and draw two health tags on top of each other.
	var seen: Dictionary = {}
	for prop: Dictionary in setup.start_props:
		seen[Vector2i(int(prop["x"]), int(prop["y"]))] = String(prop["kind"])
	for u: GridUnit in setup.units:
		var cell := Vector2i(u.x, u.y)
		if seen.has(cell):
			setup.errors.append("%s and %s both start on (%d,%d)" % [seen[cell], u.name, cell.x, cell.y])
		seen[cell] = u.name
		if setup.width > 0 and (cell.x < 0 or cell.y < 0 or cell.x >= setup.width or cell.y >= setup.height):
			setup.errors.append("%s starts off the board at (%d,%d)" % [u.name, cell.x, cell.y])
		elif setup.width > 0 and (setup.blocks[cell.y * setup.width + cell.x] == 1 or setup.pit[cell.y * setup.width + cell.x] == 1):
			setup.errors.append("%s starts on a blocking hex or a pit at (%d,%d)" % [u.name, cell.x, cell.y])
	return setup


static func _build_unit(spec: Dictionary, team: int, slot: int, parts: Dictionary,
		roles: Dictionary, damage_types: Array, armor_types: Array,
		errors: PackedStringArray, ability_defs: Dictionary = {}) -> GridUnit:
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

	# A rebuilt wreck arrives with only its chassis: the other four sockets may be "" until
	# the player refits them from cargo, and each empty one simply contributes nothing.
	var chassis: Dictionary = _part(parts, u.part_ids[0], "chassis", u.name, errors)
	var core: Dictionary = _part(parts, u.part_ids[1], "core", u.name, errors)
	var module: Dictionary = _part(parts, u.part_ids[4], "module", u.name, errors)
	var cg: Dictionary = chassis.get("grid", {})
	var og: Dictionary = core.get("grid", {})
	var mg: Dictionary = module.get("grid", {})

	u.role = String(chassis.get("role", "line"))
	# A run machine's levels arrive as flat bonuses (`bonus_hp`, `bonus_damage`).
	u.max_hp = int(spec.get("hp", int(cg.get("hp", 8)) + int(mg.get("hp", 0)) + int(spec.get("bonus_hp", 0))))
	# A run's machine arrives with whatever the last fight left it.
	u.hp = clampi(int(spec.get("hp_now", u.max_hp)), 1, u.max_hp)
	u.move = int(cg.get("move", 3)) + int(mg.get("move", 0))
	u.heat_cap = int(cg.get("heat_cap", 6)) + int(mg.get("heat_cap", 0))
	u.armor = int(mg.get("armor", 0))
	u.armor_type = maxi(0, armor_types.find(String(chassis.get("armor_type", ""))))
	u.damage_type = maxi(0, damage_types.find(String(core.get("damage_type", ""))))
	u.vent = int(og.get("vent", 1)) + int(mg.get("vent", 0))
	u.damage_bonus = int(og.get("damage", 0)) + int(mg.get("damage", 0)) + int(spec.get("bonus_damage", 0))
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

	u.kind = String(spec.get("kind", ""))
	# Abilities: the chassis's, then the module's. Only the player's machines use them --
	# an enemy's threat is its intent, and hidden enemy abilities would break that promise.
	if team == GridUnit.TEAM_PLAYER:
		for grid: Dictionary in [cg, mg]:
			var id: String = String(grid.get("ability", ""))
			if id.is_empty() or not ability_defs.has(id):
				continue
			if u.abilities.any(func(a: Dictionary) -> bool: return String(a["id"]) == id):
				continue
			var ability: Dictionary = (ability_defs[id] as Dictionary).duplicate(true)
			ability["id"] = id
			ability["wait"] = 0
			u.abilities.append(ability)
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
		# An empty socket is a weapon that was never there: it counts as torn, so every
		# rule that skips a torn arm skips it too and nothing needs a second case.
		"torn": arm.is_empty(),
		"empty": arm.is_empty(),
	}


static func _build_cache(spec: Dictionary, slot: int, hp: int, rules: Dictionary) -> GridUnit:
	var u := GridUnit.new()
	u.team = GridUnit.TEAM_PLAYER
	u.slot = slot
	u.ref = slot
	u.name = "Cache"
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
	if id.is_empty() and what != "chassis":
		return {}
	if not parts.has(id):
		errors.append("%s: unknown %s '%s'" % [owner, what, id])
		return {}
	return parts[id]
