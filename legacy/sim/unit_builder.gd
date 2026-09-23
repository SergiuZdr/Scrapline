class_name UnitBuilder
extends RefCounted

## Assembles a runtime SimUnit from a build spec plus the content database.
##
## This is the mechanical heart of the collection game: a construct is nothing but
## the parts bolted to it, so stats, abilities and (later) the 3D model all come from
## the same five ids. Building must be deterministic, because the server rebuilds
## every submitted squad from these specs before re-simulating the battle.
##
## Missing or unknown part ids fall back to neutral defaults instead of failing. A
## player whose save references a part removed in a patch gets a weaker unit, not a
## crashed battle.

const SLOT_KEYS: PackedStringArray = ["chassis", "core", "arm_l", "arm_r", "module"]


static func build(spec: Dictionary, content: Dictionary, team: int, slot: int) -> SimUnit:
	var parts_db: Dictionary = content.get("parts", {})
	var abilities_db: Dictionary = content.get("abilities", {})
	var part_ids: Dictionary = spec.get("parts", {})

	var u := SimUnit.new()
	u.team = team
	u.slot = slot
	u.unit_ref = SimDefs.unit_ref(team, slot)
	u.display_name = String(spec.get("name", "Unit %d" % slot))

	# Neutral baseline, used when a slot is empty or its part id is unknown.
	u.hp_max = 100
	u.attack = 10
	u.armor = 0
	u.speed = Balance.SCALE
	u.heat_max = 100
	u.vent_rate = 2
	u.heat_per_attack = 8
	u.weapon_range = 0

	var chassis: Dictionary = _part(parts_db, part_ids, "chassis")
	if not chassis.is_empty():
		u.hp_max = int(chassis.get("hp", u.hp_max))
		u.armor = int(chassis.get("armor", u.armor))
		u.speed = int(chassis.get("speed", u.speed))
		u.heat_max = int(chassis.get("heat_max", u.heat_max))
		u.vent_rate = int(chassis.get("vent_rate", u.vent_rate))
		u.armor_type = SimDefs.armor_type_id(String(chassis.get("armor_type", "plate")))
		# The chassis decides how the construct wants to fight, and therefore how it
		# moves. Role and foot speed are separate from attack speed on purpose: a
		# frame can be quick across the ground and slow to swing, or the reverse.
		u.role = SimDefs.role_id(String(chassis.get("role", "line")))
		u.move_speed = int(chassis.get("move_speed", u.move_speed))
		u.charge_reduction = int(chassis.get("charge_reduction", -1))
		# A frame can carry its own sighting gear, which is how an anchor makes standing
		# still pay against a map full of high ground.
		u.weapon_range += int(chassis.get("range_bonus", 0))

	var core: Dictionary = _part(parts_db, part_ids, "core")
	if not core.is_empty():
		u.damage_type = SimDefs.damage_type_id(String(core.get("damage_type", "kinetic")))
		u.heat_per_attack = int(core.get("heat_per_attack", u.heat_per_attack))
		u.attack += int(core.get("attack", 0))

	# Arms carry the weapons and the abilities. Arm L grants ability 0, arm R grants
	# ability 1 -- which is why a chain like "ability:1 > attack" only exists on a
	# construct wearing the right arm.
	for i: int in 2:
		var arm: Dictionary = _part(parts_db, part_ids, SLOT_KEYS[i + 2])
		if arm.is_empty():
			u.abilities.append({})
			continue
		u.attack += int(arm.get("attack", 0))
		u.heat_per_attack += int(arm.get("heat_per_attack", 0))
		# A construct engages at the reach of its longest arm. Mixing a lance with a
		# claw buys reach without giving up the brawl.
		u.weapon_range = maxi(u.weapon_range, int(arm.get("range", 0)))
		var ability_id: String = String(arm.get("ability", ""))
		u.abilities.append(_ability(abilities_db, ability_id))

	var module: Dictionary = _part(parts_db, part_ids, "module")
	if not module.is_empty():
		u.hp_max += int(module.get("hp", 0))
		u.attack += int(module.get("attack", 0))
		u.armor += int(module.get("armor", 0))
		u.speed += int(module.get("speed", 0))
		u.vent_rate += int(module.get("vent_rate", 0))
		u.heat_max += int(module.get("heat_max", 0))
		# A module can extend reach, which is the only way a short-armed frame ever
		# threatens a marksman without closing.
		u.weapon_range += int(module.get("range_bonus", 0))
		u.can_overdrive = bool(module.get("can_overdrive", false))

	# Guard rails so a badly authored part can never make the sim misbehave.
	u.hp_max = maxi(1, u.hp_max)
	u.speed = maxi(1, u.speed)
	u.heat_max = maxi(1, u.heat_max)
	u.attack = maxi(0, u.attack)
	u.armor = maxi(0, u.armor)
	u.move_speed = maxi(1, u.move_speed)
	# An armless construct still has to be able to reach something, or it would walk
	# at the enemy forever without ever being able to swing.
	u.weapon_range = maxi(120, u.weapon_range)

	# A per-unit power multiplier, in percent. This is how a part's level and tier
	# reach the battlefield, and how the Gauntlet keeps scaling past the point where
	# better parts exist to hand out. Kept as one number on the spec so the simulation
	# never has to know what a "level" is.
	var power: int = int(spec.get("power", Balance.SCALE))
	if power != Balance.SCALE:
		u.hp_max = maxi(1, (u.hp_max * power) / Balance.SCALE)
		u.attack = maxi(0, (u.attack * power) / Balance.SCALE)
		u.armor = maxi(0, (u.armor * power) / Balance.SCALE)

	u.hp = u.hp_max
	u.heat = 0
	u.alive = true

	for key: String in SLOT_KEYS:
		u.part_ids.append(String(part_ids.get(key, "")))

	return u


## Applies the colossus fields from a spec, if it carries any. Ordinary squads never
## do, so this costs a dictionary lookup and nothing else.
static func apply_colossus_fields(unit: SimUnit, spec: Dictionary) -> void:
	# An explicit HP override. A boss designer needs to set how long a limb lasts
	# without that being a side effect of which chassis looks right on it.
	var hp_override: int = int(spec.get("hp", 0))
	if hp_override > 0:
		unit.hp_max = hp_override
		unit.hp = hp_override

	unit.is_vital = bool(spec.get("vital", false))
	unit.guarded_reduction = int(spec.get("guarded_reduction", 0))
	var guards: Variant = spec.get("guarded_by")
	if guards is Array:
		var refs := PackedInt32Array()
		for slot: Variant in (guards as Array):
			# Guards are named by SLOT in the spec, because whoever authors a boss should
			# not have to know how unit refs are encoded.
			refs.append(unit.team * 10 + int(slot))
		refs.sort()
		unit.guard_refs = refs


## Builds both squads in a fixed order: team 0 slots 0..5, then team 1 slots 0..5.
## Every later loop over units inherits this order, which is what keeps targeting and
## doctrine evaluation identical between a client and the verifying server.
static func build_squads(
	setup: BattleSetup,
	content: Dictionary,
	balance: Balance = null,
	field: Battlefield = null
) -> Array[SimUnit]:
	var units: Array[SimUnit] = []
	var stagger: int = balance.engage_stagger_ticks if balance != null else 0
	for team: int in 2:
		var specs: Array = setup.specs_for(team)
		for slot: int in SimDefs.SQUAD_SIZE:
			if slot >= specs.size():
				break
			var spec: Dictionary = specs[slot]
			if spec.is_empty():
				continue
			var unit: SimUnit = build(spec, content, team, slot)
			apply_colossus_fields(unit, spec)
			# The front rank is already in contact; the ranks behind it need a moment
			# to close. Keyed to row rather than slot so it never disturbs the
			# fastest-first ordering within a rank.
			unit.attack_timer = SimDefs.row_of_slot(slot) * stagger

			if field != null:
				var spawn: Array[int] = field.spawn_position(team, slot)
				unit.pos_x = spawn[0]
				unit.pos_z = spawn[1]
			# The deployment anchor is remembered so Fall Back has somewhere to
			# retreat to rather than just "away".
			unit.slot_home_x = unit.pos_x
			unit.slot_home_z = unit.pos_z
			unit.lane_x = unit.pos_x
			unit.last_reported_x = unit.pos_x
			unit.last_reported_z = unit.pos_z

			units.append(unit)
	return units


static func _part(parts_db: Dictionary, part_ids: Dictionary, key: String) -> Dictionary:
	var id: String = String(part_ids.get(key, ""))
	if id.is_empty():
		return {}
	return parts_db.get(id, {})


static func _ability(abilities_db: Dictionary, ability_id: String) -> Dictionary:
	if ability_id.is_empty():
		return {}
	return abilities_db.get(ability_id, {})
