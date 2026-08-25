class_name Gauntlet
extends RefCounted

## The endless tower: floors that never stop getting harder.
##
## Almost no authored content. A floor's squad is *generated from its number* with a
## seeded PRNG, which means thirty parts produce unlimited floors, every player on
## floor 40 fights exactly the same squad (so the leaderboard is fair), and adding a
## part widens every floor at once.
##
## It exists for three reasons:
##
##   - **A competitive outlet with no server.** Ranked PvP needs a population; a depth
##     record needs nobody. This is the endgame that works on day one.
##   - **A use for a deep collection.** Floors rotate Conditions and enemy archetypes,
##     so the answer to floor 55 is usually a different squad, not a bigger one.
##   - **A difficulty read.** Where a player stalls is a precise measure of their power,
##     which is what a matchmaker will want later.
##
## Runs reset weekly. Your best depth is kept forever; the current run is not.

const SECONDS_PER_WEEK: int = 604800
## Floors between Condition changes. Long enough to adapt, short enough to matter.
const CONDITION_EVERY: int = 5


static func best_depth(profile: PlayerProfile) -> int:
	return int((profile.data.get("gauntlet", {}) as Dictionary).get("best_depth", 0))


static func current_floor(profile: PlayerProfile, now: int) -> int:
	var g: Dictionary = profile.data.get("gauntlet", {})
	if _week_of(now) != int(g.get("week", -1)):
		return 1
	return maxi(1, int(g.get("floor", 1)))


static func week_best(profile: PlayerProfile, now: int) -> int:
	var g: Dictionary = profile.data.get("gauntlet", {})
	if _week_of(now) != int(g.get("week", -1)):
		return 0
	return int(g.get("week_best", 0))


static func seconds_until_reset(now: int) -> int:
	return SECONDS_PER_WEEK - (now % SECONDS_PER_WEEK)


static func _week_of(now: int) -> int:
	return now / SECONDS_PER_WEEK


## Builds a floor's enemy squad. Deterministic in the floor number alone, so every
## player meets the same squad on the same floor and depth records compare honestly.
static func floor_squad(floor_number: int, content: ContentDB) -> Array:
	var rng := SimRNG.new(0x5CAF + floor_number * 7919)

	var chassis: PackedStringArray = _pool(content, "chassis")
	var cores: PackedStringArray = _pool(content, "core")
	var arms: PackedStringArray = _pool(content, "arm")
	var modules: PackedStringArray = _pool(content, "module")

	# Squad size climbs to six over the first ten floors, then stays there and the
	# quality of the parts carries the difficulty from that point on.
	var size: int = SimMath.clamp_int(2 + floor_number / 3, 2, SimDefs.SQUAD_SIZE)
	# How deep into the rarity-sorted pools this floor may draw.
	var band: int = SimMath.clamp_int(1 + floor_number / 3, 1, chassis.size())

	var squad: Array = []
	for slot: int in size:
		squad.append({
			"name": "Floor %d-%d" % [floor_number, slot + 1],
			"parts": {
				"chassis": chassis[rng.range_int(0, mini(band, chassis.size()) - 1)],
				"core": cores[rng.range_int(0, mini(band, cores.size()) - 1)],
				"arm_l": arms[rng.range_int(0, mini(band, arms.size()) - 1)],
				"arm_r": arms[rng.range_int(0, mini(band, arms.size()) - 1)],
				"module": modules[rng.range_int(0, mini(band, modules.size()) - 1)],
			},
		})
	return squad


## Enemy stat multiplier for a floor, in percent. Where the endless part actually comes
## from: past the point where better parts exist to give them, the tower keeps scaling
## the same squads instead.
static func floor_power(floor_number: int) -> int:
	# 4% a floor, not 9%. At 9% the enemy outgrew a fully-levelled squad by floor 5,
	# which makes an "endless" tower a four-floor corridor. A maxed part reaches roughly
	# 300% (level 25 plus tier 4), so this puts the wall for a finished squad somewhere
	# near floor 50 and leaves room for the mode to be a long-term goal.
	return Balance.SCALE + maxi(0, floor_number - 1) * 4


static func floor_condition(floor_number: int, content: ContentDB) -> String:
	if floor_number < CONDITION_EVERY:
		return ""
	var ids: Array = content.conditions.keys()
	ids.sort()
	if ids.is_empty():
		return ""
	return String(ids[(floor_number / CONDITION_EVERY) % ids.size()])


static func floor_map(floor_number: int, content: ContentDB) -> String:
	var ids: Array = []
	for id: Variant in content.maps.keys():
		# Diagnostic maps are not part of the game.
		if not String(id).begins_with("map_blank") and not String(id).begins_with("map_swapped"):
			ids.append(id)
	ids.sort()
	if ids.is_empty():
		return ""
	return String(ids[floor_number % ids.size()])


static func build_setup(
	profile: PlayerProfile, content: ContentDB, floor_number: int,
	squad_name: String = "main", seed_value: int = 0
) -> BattleSetup:
	# The floor's power multiplier is stamped onto every enemy, which is what lets the
	# tower keep climbing after the part pool has been exhausted.
	var enemies: Array = floor_squad(floor_number, content)
	var power: int = floor_power(floor_number)
	for enemy: Variant in enemies:
		(enemy as Dictionary)["power"] = power

	return BattleSetup.make(
		seed_value,
		Economy.squad_with_power(profile, content, squad_name),
		enemies,
		floor_condition(floor_number, content),
		floor_map(floor_number, content))


## Scrap for clearing a floor. Deliberately generous relative to a campaign replay:
## the tower is where a stalled player farms, and it should beat re-grinding node 3.
static func floor_reward(floor_number: int) -> int:
	return 90 + floor_number * 45


static func _pool(content: ContentDB, slot: String) -> PackedStringArray:
	# Sorted by rarity then id, so `band` means "the commonest N parts" and the pool
	# order cannot shift when content files are reordered.
	var entries: Array = []
	for id: Variant in content.parts.keys():
		var part: Dictionary = content.parts[id]
		if String(part.get("slot", "")) == slot:
			entries.append([int(part.get("rarity", 1)), String(id)])
	entries.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] < b[0]
		return String(a[1]) < String(b[1]))
	var out: PackedStringArray = []
	for entry: Variant in entries:
		out.append(String((entry as Array)[1]))
	return out
