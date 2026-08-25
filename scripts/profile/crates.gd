class_name Crates
extends RefCounted

## Salvage crates: the part faucet.
##
## Three properties this had to have from the start, because retrofitting any of them
## into a live economy is painful:
##
##   - **Published odds.** `rates` are weights out of 1000 and `odds_text()` renders
##     them for display. Several jurisdictions require this and every app store's
##     policy does; a game that cannot show its rates cannot ship.
##   - **A pity counter.** Guaranteed rare after N unlucky opens. Without one, a small
##     fraction of players hit a run so bad they quit, and they are exactly the
##     players who were engaged enough to keep pulling.
##   - **Reproducibility.** Every open is driven by a seed stored in the profile and
##     advanced deterministically, so a support ticket or a Phase 4 server can replay
##     precisely what a player got.
##
## No real money is involved yet. `cores` is earned in Phase 2 and only becomes a
## purchasable currency in Phase 6.


## What a single open produced.
class Pull extends RefCounted:
	var part_id: String
	var rarity: int
	var was_pity: bool
	var was_duplicate: bool

	func _init(id: String, r: int, pity: bool, duplicate: bool) -> void:
		part_id = id
		rarity = r
		was_pity = pity
		was_duplicate = duplicate


## Human-readable odds, for the mandatory rates screen.
static func odds_text(crate: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	var total: int = 0
	for entry: Variant in crate.get("rates", []):
		total += int((entry as Dictionary).get("weight", 0))
	if total <= 0:
		return lines
	for entry: Variant in crate.get("rates", []):
		var row: Dictionary = entry as Dictionary
		var weight: int = int(row.get("weight", 0))
		# Rendered from the same weights the roll uses, so the displayed odds cannot
		# drift away from the real ones.
		lines.append("rarity %d — %d.%d%%" % [
			int(row.get("rarity", 1)),
			(weight * 100) / total,
			((weight * 1000) / total) % 10,
		])
	var pity_after: int = int(crate.get("pity_after", 0))
	if pity_after > 0:
		lines.append("guaranteed rarity %d within %d opens" % [
			int(crate.get("pity_rarity", 3)), pity_after])
	return lines


## Rolls a crate. Pure: it takes the counters it needs and returns the pulls plus the
## updated counters, so the caller (a command) owns every mutation.
##
## Returns {"pulls": Array[Pull], "seed": int, "since_pity": int}
static func roll(
	crate: Dictionary, content: ContentDB, owned: Dictionary,
	seed_value: int, since_pity: int
) -> Dictionary:
	var rng := SimRNG.new(seed_value)
	var pulls: Array[Pull] = []
	var counter: int = since_pity
	var pity_rarity: int = int(crate.get("pity_rarity", 3))
	var pity_after: int = int(crate.get("pity_after", 0))
	var guarantee: int = int(crate.get("guarantee_rarity", 0))
	var count: int = maxi(1, int(crate.get("pulls", 1)))
	var best_rarity: int = 0

	for index: int in count:
		var forced: bool = pity_after > 0 and counter + 1 >= pity_after
		var rarity: int

		if forced:
			rarity = pity_rarity
		elif guarantee > 0 and index == count - 1 and best_rarity < guarantee:
			# Multi-pull guarantee, applied on the last pull only if nothing already
			# met the bar -- so the guarantee is a floor, never an extra reward.
			rarity = guarantee
		else:
			rarity = _roll_rarity(crate, rng)

		var part_id: String = _pick_part(content, rarity, rng)
		if part_id.is_empty():
			# No part exists at that rarity. Fall back rather than dropping the pull,
			# because a player who paid must always receive something.
			part_id = _pick_any(content, rng)
			rarity = int((content.parts.get(part_id, {}) as Dictionary).get("rarity", 1))

		pulls.append(Pull.new(part_id, rarity, forced, owned.has(part_id)))
		best_rarity = maxi(best_rarity, rarity)
		counter = 0 if rarity >= pity_rarity else counter + 1

	return {
		"pulls": pulls,
		"seed": rng.next_u32(),
		"since_pity": counter,
	}


## A part for a battle-pass tier. Uses the same pool the crates draw from, at a fixed
## rarity, so pass rewards cannot become a second loot table with unpublished odds.
static func pass_part(content: ContentDB, rng: SimRNG, rarity: int = 2) -> String:
	var part_id: String = _pick_part(content, rarity, rng)
	return part_id if not part_id.is_empty() else _pick_any(content, rng)


static func _roll_rarity(crate: Dictionary, rng: SimRNG) -> int:
	var rates: Array = crate.get("rates", [])
	var total: int = 0
	for entry: Variant in rates:
		total += int((entry as Dictionary).get("weight", 0))
	if total <= 0:
		return 1

	var roll_value: int = rng.range_int(1, total)
	var running: int = 0
	for entry: Variant in rates:
		var row: Dictionary = entry as Dictionary
		running += int(row.get("weight", 0))
		if roll_value <= running:
			return int(row.get("rarity", 1))
	return int((rates[rates.size() - 1] as Dictionary).get("rarity", 1))


## Candidates are collected in sorted id order before the draw, so the same seed picks
## the same part regardless of how the content files happen to load.
static func _pick_part(content: ContentDB, rarity: int, rng: SimRNG) -> String:
	var candidates: PackedStringArray = []
	var ids: Array = content.parts.keys()
	ids.sort()
	for id: Variant in ids:
		if int((content.parts[id] as Dictionary).get("rarity", 1)) == rarity:
			candidates.append(String(id))
	if candidates.is_empty():
		return ""
	return candidates[rng.range_int(0, candidates.size() - 1)]


static func _pick_any(content: ContentDB, rng: SimRNG) -> String:
	var ids: Array = content.parts.keys()
	ids.sort()
	if ids.is_empty():
		return ""
	return String(ids[rng.range_int(0, ids.size() - 1)])
