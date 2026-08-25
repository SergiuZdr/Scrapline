class_name Colossus
extends RefCounted

## The co-op boss: one enormous construct that a whole guild chips away at.
##
## ## Why it is built out of ordinary parts
##
## The colossus is five `SimUnit`s in a cluster — four limbs and a core — assembled from
## the same chassis, cores, arms and modules the players use. That is not a shortcut; it
## is the reason this feature is small. Every system already built applies to it: damage
## types, armour types, Heat, terrain, doctrine, and the verifier. A bespoke boss entity
## would have needed all of that again, and would have drifted from it within a month.
##
## Two simulation fields make it a boss rather than a squad of five:
##
##   - the core is **vital**: destroy it and the fight ends, however many limbs stand
##   - the core is **guarded**: while any limb lives it takes 82% less damage
##
## Together those turn a health bar into a target-priority puzzle. A squad that opens on
## the core wastes the fight. A squad that strips the arms first stops taking the heavy
## hits and *then* opens the core. That decision is the content.
##
## ## Why the HP pool is not the unit's HP
##
## A guild boss has millions of hit points; a single battle lasts twelve cycles. So each
## attempt fights a **scaled instance** of the boss, and the damage that attempt deals is
## subtracted from a shared pool held by the server. Twenty players each doing 4% is what
## kills it. The instance a player fights is always winnable-looking, and the pool is
## what makes it a guild-sized problem.

const DEFAULT_DURATION_HOURS: int = 168


## What a player is fighting right now: the boss, and how much of it is left.
class Encounter extends RefCounted:
	var boss_id: String = ""
	var name: String = ""
	var brief: String = ""
	var hp_pool: int = 0
	var hp_remaining: int = 0
	var ends_at: int = 0
	## Damage this player has contributed to the current pool.
	var contributed: int = 0
	var contributors: int = 0

	func percent_remaining() -> int:
		if hp_pool <= 0:
			return 0
		return SimMath.clamp_int(hp_remaining * 100 / hp_pool, 0, 100)

	func is_defeated() -> bool:
		return hp_remaining <= 0

	func to_dict() -> Dictionary:
		return {
			"boss": boss_id, "name": name, "brief": brief,
			"pool": hp_pool, "remaining": hp_remaining, "ends_at": ends_at,
			"contributed": contributed, "contributors": contributors,
		}

	static func from_dict(d: Dictionary) -> Encounter:
		var e := Encounter.new()
		e.boss_id = String(d.get("boss", ""))
		e.name = String(d.get("name", ""))
		e.brief = String(d.get("brief", ""))
		e.hp_pool = int(d.get("pool", 0))
		e.hp_remaining = int(d.get("remaining", 0))
		e.ends_at = int(d.get("ends_at", 0))
		e.contributed = int(d.get("contributed", 0))
		e.contributors = int(d.get("contributors", 0))
		return e


## Builds the squad specs for one attempt. `power` scales every part exactly the way a
## player's own levelled parts do, so a colossus is legible: it is a squad, built like
## any other squad, just far above your weight.
static func build_specs(boss: Dictionary) -> Array:
	var specs: Array = []
	var entries: Array = boss.get("parts", []) as Array
	var power: int = int(boss.get("power", 200))

	# Sorted by slot rather than trusting file order: slot is what `guarded_by` refers
	# to, and a boss whose limbs load in a different order would guard the wrong piece.
	var sorted: Array = entries.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("slot", 0)) < int(b.get("slot", 0)))

	# One attempt's worth of colossus. The shared pool is millions; this is the slice a
	# single squad actually shoots at, split across the segments by their authored share
	# so a designer sets how long each limb lasts rather than inheriting it from
	# whichever chassis looked right.
	var instance_hp: int = int(boss.get("instance_hp", 0))

	for entry: Variant in sorted:
		var part: Dictionary = entry as Dictionary
		var spec: Dictionary = {
			"name": String(part.get("name", "Segment")),
			"power": power,
			"parts": part.get("parts", {}),
		}
		if instance_hp > 0:
			spec["hp"] = maxi(1, instance_hp * int(part.get("hp_share", 20)) / 100)
		if bool(part.get("vital", false)):
			spec["vital"] = true
		if part.has("guarded_by"):
			spec["guarded_by"] = part["guarded_by"]
			spec["guarded_reduction"] = int(part.get("guarded_reduction", 80))
		specs.append(spec)
	return specs


## The battle one player fights. Seeded from the attempt so two players attacking the
## same boss do not fight byte-identical battles -- and so the server can re-run this
## one exactly.
static func build_setup(
	boss: Dictionary, squad: Array, seed_value: int, content: ContentDB
) -> BattleSetup:
	return BattleSetup.make(
		seed_value, squad, build_specs(boss),
		String(boss.get("condition", "")), _map_for(boss, content))


## Damage a finished attempt contributed. **Taken from the simulation's own tally, never
## from the client** -- the server recomputes this from its re-run, and the number the
## player's screen showed is only ever a preview.
static func damage_from(result: BattleResult) -> int:
	if result == null:
		return 0
	return maxi(0, result.damage_dealt[SimDefs.TEAM_A])


## A fresh encounter for a boss, starting a new window.
static func open(boss: Dictionary, now: int) -> Encounter:
	var e := Encounter.new()
	e.boss_id = String(boss.get("id", ""))
	e.name = String(boss.get("name", "Colossus"))
	e.brief = String(boss.get("brief", ""))
	e.hp_pool = int(boss.get("hp_pool", 100000))
	e.hp_remaining = e.hp_pool
	e.ends_at = now + int(boss.get("duration_hours", DEFAULT_DURATION_HOURS)) * 3600
	return e


## Reward for a share of the kill. Everyone who landed a hit is paid; the size of the
## share follows the damage. Paying only the killing blow would make the last hour of a
## week-long fight the only hour that mattered.
static func reward_scrap(contributed: int, hp_pool: int, defeated: bool) -> int:
	if contributed <= 0 or hp_pool <= 0:
		return 0
	var share: int = SimMath.clamp_int(contributed * 1000 / hp_pool, 0, 1000)
	var base: int = 400 + share * 12
	return base if defeated else base / 3


static func _map_for(boss: Dictionary, content: ContentDB) -> String:
	var wanted: String = String(boss.get("map", ""))
	if not wanted.is_empty() and content.maps.has(wanted):
		return wanted
	return ""
