class_name Tournament
extends RefCounted

## Scheduled tournaments: everyone fights **the same fight**, best attempt counts.
##
## ## Why a fixed challenge rather than a bracket
##
## A knockout bracket needs everyone present at the same moment, which an async game on
## phones cannot promise, and it needs an even number of entrants who all turn up. A
## fixed challenge needs neither: the enemy squad, the map and the Condition are derived
## from the tournament id and its start time, so **every entrant fights an identical
## battle** and the ranking is a pure comparison of squad building and orders.
##
## It also costs nothing to verify. The worker rebuilds the challenge from the same two
## numbers and re-runs the submission, exactly as it does for a bot or a colossus — no
## new trust, no new anti-cheat.
##
## ## Scoring
##
## Damage dealt, plus a large bonus for winning and for every construct still standing.
## Losing well beats losing badly, and winning beats both — but a scrappy win with one
## survivor does not outrank a clean sweep. The score is an integer computed here, and
## **the server takes it from the worker's re-run**, never from the client.

const ENTRY_ATTEMPTS: int = 5
const WIN_BONUS: int = 20000
const SURVIVOR_BONUS: int = 4000
const CYCLE_BONUS: int = 800


## The enemy squad for a tournament, generated from its id and start time. Deterministic
## in both, so the client, the server and every entrant agree without anyone shipping a
## squad list.
static func challenge_squad(tournament_id: String, start_time: int, content: ContentDB) -> Array:
	var rng := SimRNG.new(_seed_of(tournament_id, start_time))
	var pools: Dictionary = {}
	for slot: String in ["chassis", "core", "arm", "module"]:
		pools[slot] = _pool(content, slot)

	var squad: Array = []
	for index: int in SimDefs.SQUAD_SIZE:
		squad.append({
			"name": "Contender %d" % (index + 1),
			"power": 180,
			"parts": {
				"chassis": _pick(rng, pools["chassis"]),
				"core": _pick(rng, pools["core"]),
				"arm_l": _pick(rng, pools["arm"]),
				"arm_r": _pick(rng, pools["arm"]),
				"module": _pick(rng, pools["module"]),
			},
		})
	return squad


## The battle every entrant fights. The seed is fixed by the tournament, not by the
## attempt: two players who build the same squad and give the same orders must get the
## same result, or the ranking measures luck.
static func build_setup(
	tournament_id: String, start_time: int, squad: Array, content: ContentDB
) -> BattleSetup:
	var seed_value: int = _seed_of(tournament_id, start_time)
	var rng := SimRNG.new(seed_value)
	return BattleSetup.make(
		seed_value, squad, challenge_squad(tournament_id, start_time, content),
		_pick_id(rng, content.conditions), _pick_map(rng, content))


## The score for a finished attempt. Integer, and computed the same way everywhere.
static func score_of(result: BattleResult, balance: Balance) -> int:
	if result == null:
		return 0
	var score: int = result.damage_dealt[SimDefs.TEAM_A]
	if result.winner == SimDefs.TEAM_A:
		score += WIN_BONUS
		score += result.survivors[SimDefs.TEAM_A] * SURVIVOR_BONUS
		# Finishing faster is worth something, but never enough to outrank surviving --
		# otherwise the winning strategy is to throw the squad at it and hope.
		score += maxi(0, balance.max_cycles - result.cycles) * CYCLE_BONUS
	return score


## A readable breakdown, so a player can see why they placed where they did rather than
## being handed a number.
static func score_breakdown(result: BattleResult, balance: Balance) -> PackedStringArray:
	var lines: PackedStringArray = []
	lines.append("%d  damage dealt" % result.damage_dealt[SimDefs.TEAM_A])
	if result.winner == SimDefs.TEAM_A:
		lines.append("%d  for winning" % WIN_BONUS)
		lines.append("%d  for %d construct(s) still standing" % [
			result.survivors[SimDefs.TEAM_A] * SURVIVOR_BONUS, result.survivors[SimDefs.TEAM_A]])
		lines.append("%d  for finishing in %d cycles" % [
			maxi(0, balance.max_cycles - result.cycles) * CYCLE_BONUS, result.cycles])
	else:
		lines.append("no win bonus — the challenge squad was still standing")
	lines.append("%d  total" % score_of(result, balance))
	return lines


static func _seed_of(tournament_id: String, start_time: int) -> int:
	var hash_value: int = 0x811C9DC5
	for byte: int in tournament_id.to_utf8_buffer():
		hash_value = (hash_value ^ byte) & 0xFFFFFFFF
		hash_value = (hash_value * 16777619) & 0xFFFFFFFF
	return (hash_value ^ start_time) & 0x7FFFFFFF


static func _pool(content: ContentDB, slot: String) -> PackedStringArray:
	var entries: Array = []
	for id: Variant in content.parts.keys():
		var part: Dictionary = content.parts[id]
		if String(part.get("slot", "")) == slot:
			entries.append(String(id))
	entries.sort()
	var out: PackedStringArray = []
	for id: Variant in entries:
		out.append(String(id))
	return out


static func _pick(rng: SimRNG, pool: PackedStringArray) -> String:
	if pool.is_empty():
		return ""
	return pool[rng.range_int(0, pool.size() - 1)]


static func _pick_id(rng: SimRNG, source: Dictionary) -> String:
	var ids: Array = source.keys()
	ids.sort()
	if ids.is_empty():
		return ""
	return String(ids[rng.range_int(0, ids.size() - 1)])


static func _pick_map(rng: SimRNG, content: ContentDB) -> String:
	var ids: Array = []
	for id: Variant in content.maps.keys():
		var name: String = String(id)
		# The diagnostic maps are not arenas; a tournament fought on the featureless
		# test plate would be a different game from the one everyone practised.
		if not name.begins_with("map_blank") and not name.begins_with("map_swapped"):
			ids.append(name)
	ids.sort()
	if ids.is_empty():
		return ""
	return String(ids[rng.range_int(0, ids.size() - 1)])
