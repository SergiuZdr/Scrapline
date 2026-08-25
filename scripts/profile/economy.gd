class_name Economy
extends RefCounted

## Every cost curve in the game, read from `data/economy.json`.
##
## Same rule as `sim/`: no economy number is hardcoded. A live free-to-play game
## retunes prices constantly -- in response to inflation, to a new part tier, to a
## drop-rate change -- and each of those must be a data patch, not a client release.
##
## The curves are deliberately simple and multiplicative rather than hand-authored
## tables, because a table with 20 parts x 20 levels is 400 numbers nobody will keep
## consistent, and the balance simulator can only reason about a curve.

const DEFAULTS: Dictionary = {
	"level_base_cost": 60,
	"level_growth_pct": 135,      # each level costs 1.35x the previous
	"level_rarity_pct": 45,       # +45% per rarity step of the part
	"refit_base_copies": 2,       # duplicates consumed for the first refit
	"refit_copies_growth": 1,     # +1 duplicate per tier thereafter
	"refit_base_alloy": 120,
	"refit_alloy_growth_pct": 180,
	"salvage_scrap_per_battle": 45,
	"salvage_alloy_per_battle": 4,
}

static var _values: Dictionary = {}


static func configure(values: Dictionary) -> void:
	_values = values


static func value(key: String) -> int:
	if _values.has(key):
		return int(_values[key])
	return int(DEFAULTS.get(key, 0))


## Scrap to take a part from its current level to the next.
##
## Growth is compounding, so late levels cost far more than early ones. That is what
## makes a wide, shallow collection a genuine alternative to one maxed part rather
## than a strictly worse choice.
static func level_cost(profile: PlayerProfile, part_id: String, content: ContentDB) -> int:
	var level: int = maxi(1, profile.part_level(part_id))
	var rarity: int = int((content.parts.get(part_id, {}) as Dictionary).get("rarity", 1))

	var cost: int = value("level_base_cost")
	for _step: int in level - 1:
		cost = (cost * value("level_growth_pct")) / Balance.SCALE
	# Rarer parts cost more per level, so rarity is an ongoing commitment rather than
	# a one-off windfall.
	cost = (cost * (Balance.SCALE + (rarity - 1) * value("level_rarity_pct"))) / Balance.SCALE
	return maxi(1, cost)


## Duplicates consumed by the next Refit.
static func refit_copies(profile: PlayerProfile, part_id: String) -> int:
	var tier: int = profile.part_tier(part_id)
	return value("refit_base_copies") + tier * value("refit_copies_growth")


## Alloy consumed by the next Refit.
static func refit_alloy(profile: PlayerProfile, part_id: String, content: ContentDB) -> int:
	var tier: int = profile.part_tier(part_id)
	var rarity: int = int((content.parts.get(part_id, {}) as Dictionary).get("rarity", 1))

	var cost: int = value("refit_base_alloy")
	for _step: int in tier:
		cost = (cost * value("refit_alloy_growth_pct")) / Balance.SCALE
	cost = (cost * (Balance.SCALE + (rarity - 1) * value("level_rarity_pct"))) / Balance.SCALE
	return maxi(1, cost)


## What a part's level and tier are actually worth in battle. Applied to the built
## SimUnit, so progression is felt without touching the base part data.
static func stat_multiplier(level: int, tier: int) -> int:
	# +6% per level and +15% per tier, compounding neither -- a linear curve keeps the
	# power gap between a new player and a veteran readable, which matters a great
	# deal for matchmaking later.
	return Balance.SCALE + (maxi(0, level - 1) * 6) + (tier * 15)


## Rewards for finishing a battle. Kept here so the faucet sits next to the sinks and
## the two can be read against each other.
static func battle_reward_scrap(won: bool, cycles: int) -> int:
	var base: int = value("salvage_scrap_per_battle")
	if not won:
		base = base / 3
	# A longer fight salvages more wreckage, which gently rewards a close match over
	# farming a trivial one.
	return maxi(1, base + cycles * 4)


static func battle_reward_alloy(won: bool) -> int:
	return value("salvage_alloy_per_battle") if won else 0


## Bakes a squad's part levels and tiers into per-unit power multipliers.
##
## Without this, levelling a part changes a number on a screen and nothing else --
## which was true until it was added. A unit's power is the average of its five parts'
## multipliers, so upgrading any one part helps and no single slot dominates.
static func squad_with_power(profile: PlayerProfile, content: ContentDB, squad_name: String = "main") -> Array:
	var out: Array = []
	for entry: Variant in profile.squad(squad_name):
		var spec: Dictionary = (entry as Dictionary).duplicate(true)
		var parts: Dictionary = spec.get("parts", {})

		var total: int = 0
		var counted: int = 0
		for key: Variant in ["chassis", "core", "arm_l", "arm_r", "module"]:
			var part_id: String = String(parts.get(key, ""))
			if part_id.is_empty() or not content.parts.has(part_id):
				continue
			total += stat_multiplier(profile.part_level(part_id), profile.part_tier(part_id))
			counted += 1

		spec["power"] = (total / counted) if counted > 0 else Balance.SCALE
		out.append(spec)
	return out


## Average power of a squad, for the UI to show alongside an enemy's.
static func squad_power(profile: PlayerProfile, content: ContentDB, squad_name: String = "main") -> int:
	var specs: Array = squad_with_power(profile, content, squad_name)
	if specs.is_empty():
		return Balance.SCALE
	var total: int = 0
	for spec: Variant in specs:
		total += int((spec as Dictionary).get("power", Balance.SCALE))
	return total / specs.size()
