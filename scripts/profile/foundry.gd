class_name Foundry
extends RefCounted

## The base layer: buildings that produce while the player is away.
##
## This is the retention engine. A free-to-play game needs a reason to open the app on
## a day you do not feel like fighting, and "my yard has been filling up for nine
## hours" is that reason. It is also the honest one — the timer runs whether or not you
## are watching, so opening the app is collecting something you already earned rather
## than being asked to grind.
##
## Two rules keep it from becoming a chore or an exploit:
##
##   - **Storage caps.** Production stops at `storage_hours`, so leaving for a week
##     yields the same as leaving for a day. That is a deliberate ceiling on how much
##     being away can matter, not a punishment for it.
##   - **No clock reads in here.** Every function takes `now` as an argument. Logic
##     that calls `Time` directly cannot be tested, and an offline-accrual bug is
##     exactly the kind that only shows up in production.

const SECONDS_PER_HOUR: int = 3600


static func level(profile: PlayerProfile, building_id: String) -> int:
	var buildings: Dictionary = (profile.data["foundry"] as Dictionary)["buildings"]
	return int((buildings.get(building_id, {}) as Dictionary).get("level", 0))


static func is_built(profile: PlayerProfile, building_id: String) -> bool:
	return level(profile, building_id) > 0


## Production per hour at the building's current level. Level 0 means "not built yet"
## and produces nothing.
static func rate_per_hour(profile: PlayerProfile, building_id: String, content: ContentDB) -> int:
	var definition: Dictionary = content.buildings.get(building_id, {})
	if definition.is_empty():
		return 0
	var current: int = level(profile, building_id)
	if current <= 0:
		return 0
	var rate: int = int(definition.get("rate_per_hour", 0))
	for _step: int in current - 1:
		rate = (rate * int(definition.get("rate_growth_pct", 100))) / Balance.SCALE
	return rate


static func storage_cap(profile: PlayerProfile, building_id: String, content: ContentDB) -> int:
	var definition: Dictionary = content.buildings.get(building_id, {})
	return rate_per_hour(profile, building_id, content) * int(definition.get("storage_hours", 0))


static func upgrade_cost(profile: PlayerProfile, building_id: String, content: ContentDB) -> int:
	var definition: Dictionary = content.buildings.get(building_id, {})
	if definition.is_empty():
		return 0
	var cost: int = int(definition.get("upgrade_base_cost", 0))
	for _step: int in level(profile, building_id):
		cost = (cost * int(definition.get("upgrade_growth_pct", 100))) / Balance.SCALE
	return maxi(1, cost)


static func upgrade_currency(building_id: String, content: ContentDB) -> String:
	return String((content.buildings.get(building_id, {}) as Dictionary).get("upgrade_currency", "scrap"))


static func at_max_level(profile: PlayerProfile, building_id: String, content: ContentDB) -> bool:
	var definition: Dictionary = content.buildings.get(building_id, {})
	return level(profile, building_id) >= int(definition.get("max_level", 1))


## Seconds of production banked, clamped to the storage window.
static func elapsed_seconds(profile: PlayerProfile, now: int, hours_cap: int) -> int:
	var last: int = int((profile.data["foundry"] as Dictionary).get("last_collected", 0))
	if last <= 0:
		return 0
	# Clamped at zero as well as at the cap: a device clock that jumps backwards must
	# not produce negative income or a permanently stuck yard.
	return SimMath.clamp_int(now - last, 0, hours_cap * SECONDS_PER_HOUR)


## Everything waiting to be collected, as currency -> amount.
static func pending(profile: PlayerProfile, content: ContentDB, now: int) -> Dictionary:
	var out: Dictionary = {}
	for building_id: Variant in _sorted_ids(content):
		var id: String = String(building_id)
		var produces: String = String((content.buildings[id] as Dictionary).get("produces", ""))
		if produces.is_empty() or not is_built(profile, id):
			continue
		var hours_cap: int = int((content.buildings[id] as Dictionary).get("storage_hours", 0))
		var seconds: int = elapsed_seconds(profile, now, hours_cap)
		var amount: int = (rate_per_hour(profile, id, content) * seconds) / SECONDS_PER_HOUR
		if amount > 0:
			out[produces] = int(out.get(produces, 0)) + amount
	return out


## How full the yard is, 0-100, for the "come back later" readout.
static func fill_percent(profile: PlayerProfile, building_id: String, content: ContentDB, now: int) -> int:
	var cap: int = storage_cap(profile, building_id, content)
	if cap <= 0:
		return 0
	var hours_cap: int = int((content.buildings[building_id] as Dictionary).get("storage_hours", 0))
	var seconds: int = elapsed_seconds(profile, now, hours_cap)
	var amount: int = (rate_per_hour(profile, building_id, content) * seconds) / SECONDS_PER_HOUR
	return SimMath.clamp_int((amount * 100) / cap, 0, 100)


## Building ids in a stable order. Dictionary key order follows file load order, and
## anything the UI lists or the server receives must not depend on that.
static func _sorted_ids(content: ContentDB) -> Array:
	var ids: Array = content.buildings.keys()
	ids.sort()
	return ids


static func sorted_ids(content: ContentDB) -> Array:
	return _sorted_ids(content)


## Extra part levels granted by the Archive, on top of the tier ceiling. Gives the base
## layer a direct effect on combat power, so it is not a parallel game.
static func archive_level_bonus(profile: PlayerProfile) -> int:
	return level(profile, "archive")


## Squad slots unlocked by the Assembly Bay. One is always available.
static func squad_slots(profile: PlayerProfile) -> int:
	return 1 + level(profile, "assembly_bay")
