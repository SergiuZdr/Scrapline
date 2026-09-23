class_name DamageResolver
extends RefCounted

## Turns an attack into a number.
##
## The order of operations here is part of the game's contract. Two clients that
## apply Exposed before armor and after it will produce different totals, diverge,
## and fail server verification -- so this sequence is fixed and documented:
##
##   1. base power        (attacker's attack, scaled by the ability's power percent)
##   2. type matchup      (damage type vs armor type)
##   3. Exposed           (target takes amplified damage)
##   4. Overdrive         (attacker's charged strike)
##   5. armor subtraction (Fractured reduces the armor first)
##   6. cover             (whatever the defender is standing behind)
##   7. Brace             (the defender's own choice comes last, so it always helps)
##   8. guard             (a colossus core, while its limbs still stand)
##   9. floor at min_damage


static func compute(
	attacker: SimUnit,
	target: SimUnit,
	power_percent: int,
	balance: Balance,
	overdrive: bool = false,
	cover_percent: int = 0,
	rng: SimRNG = null,
	charging: bool = false,
	guarded: bool = false
) -> int:
	var dmg: int = (attacker.attack * power_percent) / Balance.SCALE

	var eff: int = balance.effectiveness_of(attacker.damage_type, target.armor_type)
	dmg = (dmg * eff) / Balance.SCALE

	if target.has_state(SimDefs.STATE_EXPOSED):
		dmg = (dmg * balance.exposed_damage_bonus) / Balance.SCALE

	if overdrive:
		dmg = (dmg * balance.overdrive_multiplier) / Balance.SCALE

	var armor: int = target.armor
	if target.has_state(SimDefs.STATE_FRACTURED):
		armor = (armor * balance.fractured_armor) / Balance.SCALE
	dmg -= armor

	# Terrain the defender chose to stand on. Applied before Brace so a braced unit in
	# hard cover compounds the two rather than one swallowing the other.
	if cover_percent > 0:
		dmg = (dmg * (Balance.SCALE - mini(cover_percent, 80))) / Balance.SCALE

	# Charge armour. A brawler crossing open ground to reach contact is under fire the
	# whole way and cannot shoot back, which made the role strictly worse than standing
	# off with a rifle. Assault frames are plated for exactly that approach, so they
	# take less while they are still closing -- and nothing extra once they arrive.
	if charging:
		var reduction: int = target.charge_reduction
		if reduction < 0:
			reduction = balance.brawler_charge_reduction
		if reduction > 0:
			dmg = (dmg * (Balance.SCALE - mini(reduction, 75))) / Balance.SCALE

	if target.brace_pct > 0:
		dmg = (dmg * (Balance.SCALE - target.brace_pct)) / Balance.SCALE

	# A colossus core behind live limbs. Deliberately applied after Brace and before the
	# variance roll, so it is a wall rather than a rounding error: shooting the core
	# first is meant to feel like a mistake, not a slightly worse option.
	if guarded and target.guarded_reduction > 0:
		dmg = (dmg * (Balance.SCALE - mini(target.guarded_reduction, 95))) / Balance.SCALE

	# A little scatter, drawn from the seeded stream so it stays reproducible. Once
	# targeting became purely positional the simulation used no randomness at all,
	# which made every rematch between two squads play out identically. Set
	# `damage_variance_pct` to 0 in balance.json for a fully deterministic game.
	if rng != null and balance.damage_variance_pct > 0:
		var spread: int = balance.damage_variance_pct
		dmg = (dmg * (Balance.SCALE + rng.range_int(-spread, spread))) / Balance.SCALE

	return maxi(balance.min_damage, dmg)


## Effectiveness as a percent, for the log and for the damage-number colour in the UI.
static func matchup_percent(attacker: SimUnit, target: SimUnit, balance: Balance) -> int:
	return balance.effectiveness_of(attacker.damage_type, target.armor_type)


## A unit's speed after state modifiers. Drives both how often it acts and, when
## several units come up on the same tick, which of them moves first.
static func effective_speed(unit: SimUnit, balance: Balance) -> int:
	var speed: int = unit.speed
	if unit.has_state(SimDefs.STATE_GROUNDED):
		speed = (speed * balance.grounded_speed) / Balance.SCALE
	return maxi(1, speed)


## Ticks between this unit's attacks, after speed modifiers. Always at least 1, or a
## fast unit with a debuff stack could act infinitely often within a single tick.
static func attack_interval(unit: SimUnit, balance: Balance) -> int:
	return maxi(1, (balance.base_attack_ticks * Balance.SCALE) / effective_speed(unit, balance))
