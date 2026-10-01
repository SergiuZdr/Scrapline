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
## The board's name, for the opening card.
var fight_name: String = ""
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
## A furnace flue's blast (025): what it does to whatever stands on it when it blows, every
## `flue_every` rounds. 0 off the flues.
var flue: PackedByteArray = []
var flue_every: int = 2
## Objects on the board at the start: `[{ "x", "y", "kind": "barrel"|"crate", "hp" }]`.
var start_props: Array = []
var barrel_damage: int = 3
var crate_hp: int = 3
## `data/combat/enemy_kinds.json`, for the rules that need a kind's numbers.
var kinds: Dictionary = {}
## What a hive builds, resolved from its parts once so a spawn is a copy, not a lookup.
var drone: GridUnit = null
## The Reclaimer reaching into a fight near its line (013): `reclaimer_count` of its drones
## arrive on the player's back row at round `reclaimer_round` (0 = not this fight).
var reclaimer_round: int = 0
var reclaimer_count: int = 0
var reclaimer_drone: GridUnit = null

var max_rounds: int = 20
var min_damage: int = 1
var tear_threshold: int = 5
var bump_damage: int = 1
var mark_bonus: int = 2
## A destroyed machine's scrap pile: what it is worth, and what collecting it patches.
var pile_value: int = 4
var pile_heal: int = 2
## Chance (percent) that an enemy carries scrap; see `GridUnit.carries_scrap`.
var pile_drop_pct: int = 55
## A piercing shot's overshoot past its range, and the damage it keeps there (percent).
var pierce_overshoot: int = 2
var pierce_overshoot_pct: int = 50
## `{ "type": "rout"|"defend"|"salvage", "rounds": int, "need": int }` -- see CombatSim.
var objective: Dictionary = {"type": "rout"}
## The yard's conditions this fight (028): `modifiers` ids, and what they change -- every shot and
## lob `range_mod` longer (DUST STORM: -1), and the crew's vent `vent_mod` (HEAT WAVE: -1).
var modifiers: PackedStringArray = []
var range_mod: int = 0
var vent_mod: int = 0
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
	setup.fight_name = String(fight.get("name", ""))
	setup.rng_seed = seed_value
	# A fight may set its own limit (014: the gate closes sooner than an ordinary fight ends).
	setup.max_rounds = int(fight.get("max_rounds", rules.get("max_rounds", 20)))
	setup.min_damage = int(rules.get("min_damage", 1))
	setup.tear_threshold = int(rules.get("tear_threshold", 5))
	setup.bump_damage = int(rules.get("bump_damage", 1))
	setup.mark_bonus = int(rules.get("mark_bonus", 2))
	setup.pile_value = int(rules.get("pile_value", 4))
	setup.pile_heal = int(rules.get("pile_heal", 2))
	setup.pile_drop_pct = int(rules.get("pile_drop_pct", 55))
	setup.pierce_overshoot = int(rules.get("pierce_overshoot", 2))
	setup.pierce_overshoot_pct = int(rules.get("pierce_overshoot_pct", 50))
	setup.wheel = wheel
	setup.barrel_damage = int(rules.get("barrel_damage", 3))
	setup.crate_hp = int(rules.get("crate_hp", 3))
	setup.flue_every = maxi(1, int(rules.get("flue_every", 2)))
	setup.kinds = rules.get("enemy_kinds", {})
	var objective: Dictionary = fight.get("objective", {"type": "rout"})
	setup.objective = {"type": String(objective.get("type", "rout")),
		"rounds": int(objective.get("rounds", 0)), "need": int(objective.get("need", 0)),
		"every": int(objective.get("every", 2)), "count": int(objective.get("count", 2)), "cells": []}
	# 028: HOLD's zone and HACK's terminals.
	for c: Variant in (objective.get("cells", []) as Array):
		(setup.objective["cells"] as Array).append(Vector2i(int((c as Dictionary)["x"]), int((c as Dictionary)["y"])))
	# 028: the yard's conditions, read from the combat rules' table.
	var table: Dictionary = rules.get("modifiers", {})
	for id: Variant in (fight.get("modifiers", []) as Array):
		var m: Dictionary = table.get(String(id), {})
		setup.modifiers.append(String(id))
		setup.range_mod += int(m.get("range", 0))
		setup.vent_mod += int(m.get("vent", 0))
		setup.pile_value *= maxi(1, int(m.get("pile_mult", 1)))
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
	setup.flue.resize(cells)
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
			setup.flue[i] = int(grid.get("flue", 0))
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
				damage_types, armor_types, setup.errors, rules.get("abilities", {}), rules.get("makers", {})))

	# Which enemies carry scrap: a real hash of the fight's seed and the unit, so it is
	# fixed from the first frame and the same on every replay.
	for u: GridUnit in setup.units:
		if u.team == GridUnit.TEAM_ENEMY:
			u.carries_scrap = IntentAI.mix(seed_value, u.ref, 0, 53) % 100 < setup.pile_drop_pct
			# An authored fight may say for itself (012: the shakedown teaches piles with a
			# runner it knows will drop one).
			var spec: Dictionary = (slot_lists[1] as Array)[u.slot]
			if spec.has("carries"):
				u.carries_scrap = bool(spec["carries"])

	# A kind may plate and anchor its machine (021: the yard sentinels).
	for u: GridUnit in setup.units:
		var kind_rules: Dictionary = setup.kinds.get(u.kind, {}) if not u.kind.is_empty() else {}
		u.armor += int(kind_rules.get("plate", 0))
		if bool(kind_rules.get("anchored", false)):
			u.unshovable = true
	var drone_spec: Dictionary = (setup.kinds.get("hive", {}) as Dictionary).get("drone", {})
	if not drone_spec.is_empty():
		setup.drone = _build_unit(drone_spec, GridUnit.TEAM_ENEMY, 9, parts, roles, damage_types,
			armor_types, setup.errors)
		setup.drone.name = String(drone_spec.get("name", "Drone"))
		setup.drone.carries_scrap = false

	var reclaimer: Dictionary = fight.get("reclaimer", {})
	var reclaimer_spec: Dictionary = (setup.kinds.get("reclaimer", {}) as Dictionary).get("drone", {})
	if not reclaimer.is_empty() and not reclaimer_spec.is_empty():
		setup.reclaimer_round = int(reclaimer.get("round", 3))
		setup.reclaimer_count = int(reclaimer.get("count", 2))
		setup.reclaimer_drone = _build_unit(reclaimer_spec, GridUnit.TEAM_ENEMY, 9, parts, roles, damage_types,
			armor_types, setup.errors)
		setup.reclaimer_drone.name = String(reclaimer_spec.get("name", "Reclaimer Drone"))
		setup.reclaimer_drone.kind = "reclaimer"
		setup.reclaimer_drone.carries_scrap = false

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
	# HEAT WAVE (028): the crew sheds heat slower.
	if setup.vent_mod != 0:
		for u: GridUnit in setup.units:
			if u.team == GridUnit.TEAM_PLAYER and not u.objective:
				u.vent = maxi(0, u.vent + setup.vent_mod)
	return setup


static func _build_unit(spec: Dictionary, team: int, slot: int, parts: Dictionary,
		roles: Dictionary, damage_types: Array, armor_types: Array,
		errors: PackedStringArray, ability_defs: Dictionary = {}, rules_makers: Dictionary = {}) -> GridUnit:
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
	u.max_hp = int(spec.get("hp", int(cg.get("hp", 8)) + int(mg.get("hp", 0))))
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

	u.kind = String(spec.get("kind", ""))
	u.level = int(spec.get("level", 0))
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
		# A tuned frame or module can cut its abilities' cooldown (`cooldown` in its grid).
		apply_bonus(u, {"cooldown": int(cg.get("cooldown", 0)) + int(mg.get("cooldown", 0))})
		# Sets: parts from one maker add up (011). Player machines only -- see makers.json.
		for entry: Dictionary in sets_of(u.part_ids, parts, rules_makers):
			for tier: Variant in (entry["active"] as Array):
				apply_bonus(u, (((rules_makers[entry["maker"]] as Dictionary).get("sets", {}) as Dictionary)
					.get(str(tier), {})) as Dictionary)
	# A run machine's levels and perks arrive as one flat block (`RunSim.bonus_of`).
	apply_bonus(u, spec.get("bonus", {}))
	# A run's machine arrives with whatever the last fight left it.
	u.hp = clampi(int(spec.get("hp_now", u.max_hp)), 1, u.max_hp)
	return u


## Adds a flat bonus block -- a set, a perk, a machine's levels -- to a built unit. The keys
## are a module grid's (`hp, move, heat_cap, vent, armor, damage, heat, range`) plus `melee`
## (melee damage), `cooldown` (every ability ready that many rounds sooner, never below 1),
## `chain` (more jumps on a weapon that already arcs), and the flags `unshovable` and
## `move_after_attack`. One function, so a number means the same thing wherever it comes from.
static func apply_bonus(u: GridUnit, grid: Dictionary) -> void:
	if grid.is_empty():
		return
	u.max_hp += int(grid.get("hp", 0))
	u.move += int(grid.get("move", 0))
	u.heat_cap += int(grid.get("heat_cap", 0))
	u.vent += int(grid.get("vent", 0))
	u.armor += int(grid.get("armor", 0))
	u.damage_bonus += int(grid.get("damage", 0))
	u.heat_bonus += int(grid.get("heat", 0))
	u.range_bonus += int(grid.get("range", 0))
	u.melee_bonus += int(grid.get("melee", 0))
	if int(grid.get("unshovable", 0)) > 0:
		u.unshovable = true
	if int(grid.get("move_after_attack", 0)) > 0:
		u.move_after_attack = true
	var chain: int = int(grid.get("chain", 0))
	for weapon: Dictionary in u.weapons:
		if chain != 0 and int(weapon["chain"]) > 0:
			weapon["chain"] = int(weapon["chain"]) + chain
	var cut: int = int(grid.get("cooldown", 0))
	for ability: Dictionary in u.abilities:
		if cut != 0:
			ability["cooldown"] = maxi(1, int(ability["cooldown"]) - cut)


## The makers a loadout carries two or more parts from, in maker order:
## `[{ "maker", "count", "active": [2] or [2, 3] }]`. The one place a set is counted -- the
## fight applies it, the garage shows it.
static func sets_of(part_ids: PackedStringArray, parts: Dictionary, makers: Dictionary) -> Array:
	var counts: Dictionary = {}
	for id: String in part_ids:
		var maker: String = String((parts.get(id, {}) as Dictionary).get("maker", ""))
		if not id.is_empty() and makers.has(maker):
			counts[maker] = int(counts.get(maker, 0)) + 1
	var names: Array = counts.keys()
	names.sort()
	var out: Array = []
	for maker: Variant in names:
		var count: int = int(counts[maker])
		var tiers: Array = []
		var defined: Array = ((makers[maker] as Dictionary).get("sets", {}) as Dictionary).keys()
		defined.sort_custom(func(a: Variant, b: Variant) -> bool: return int(str(a)) < int(str(b)))
		for tier: Variant in defined:
			if count >= int(str(tier)):
				tiers.append(int(str(tier)))
		if not tiers.is_empty():
			out.append({"maker": String(maker), "count": count, "active": tiers})
	return out


## One player machine built exactly as a fight would build it, for screens that show its
## numbers (the garage). Showing the sim's own unit means the garage cannot disagree with
## the fight.
static func unit_from(spec: Dictionary, rules: Dictionary, parts: Dictionary) -> GridUnit:
	var errors: PackedStringArray = []
	return _build_unit(spec, GridUnit.TEAM_PLAYER, 0, parts, rules.get("roles", {}),
		rules.get("damage_types", []), rules.get("armor_types", []), errors, rules.get("abilities", {}),
		rules.get("makers", {}))


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
