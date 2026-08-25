class_name Ranked
extends RefCounted

## Rating, tiers and seasons.
##
## Elo, with the K-factor tapering as a player settles. New accounts move fast so they
## reach roughly the right rung in a handful of matches instead of grinding up from the
## bottom — placement by play rather than by a placement questionnaire.
##
## Seasons rotate the **Battlefield Condition** every ranked match is fought under. That
## is the mechanism that keeps a deep parts collection worth more than one maxed squad:
## the arena that decides the meta changes on a schedule, so the answer to the ladder
## changes with it. It is also free live-ops content — a new season costs one line of
## data, not a content drop.

const SEASON_LENGTH: int = 2419200  ## 28 days
const BASE_RATING: int = 1000
const PLACEMENT_MATCHES: int = 10

## Elo K-factor: high while placing, then settling, then stable.
const K_PLACEMENT: int = 48
const K_SETTLING: int = 32
const K_STABLE: int = 20

## Tier thresholds, low to high. The names are the ladder's vocabulary, so they are
## short enough to fit a chip in the UI.
const TIERS: Array = [
	{"name": "Scrapper", "at": 0},
	{"name": "Reclaimer", "at": 900},
	{"name": "Foreman", "at": 1150},
	{"name": "Overseer", "at": 1400},
	{"name": "Ironwright", "at": 1650},
	{"name": "Foundry Lord", "at": 1900},
]


static func season_of(now: int) -> int:
	return now / SEASON_LENGTH


static func seconds_until_season_end(now: int) -> int:
	return SEASON_LENGTH - (now % SEASON_LENGTH)


## The Condition every ranked match this season is fought under. Rotates through the
## authored list, so a squad built for Ion Storm is a liability the season it turns to
## Ashfall.
static func season_condition(now: int, content: ContentDB) -> String:
	var ids: Array = content.conditions.keys()
	ids.sort()
	if ids.is_empty():
		return ""
	return String(ids[season_of(now) % ids.size()])


static func season_map(now: int, content: ContentDB) -> String:
	var ids: Array = []
	for id: Variant in content.maps.keys():
		var name: String = String(id)
		if not name.begins_with("map_blank") and not name.begins_with("map_swapped"):
			ids.append(name)
	ids.sort()
	if ids.is_empty():
		return ""
	return String(ids[season_of(now) % ids.size()])


static func tier_of(rating: int) -> Dictionary:
	var current: Dictionary = TIERS[0]
	for entry: Variant in TIERS:
		if rating >= int((entry as Dictionary)["at"]):
			current = entry as Dictionary
	return current


static func tier_name(rating: int) -> String:
	return String(tier_of(rating)["name"])


## Progress toward the next tier, 0-100, for a progress bar that means something.
static func tier_progress(rating: int) -> int:
	var current: Dictionary = tier_of(rating)
	var floor_rating: int = int(current["at"])
	var ceiling: int = -1
	for entry: Variant in TIERS:
		var at: int = int((entry as Dictionary)["at"])
		if at > floor_rating:
			ceiling = at
			break
	if ceiling < 0:
		return 100
	return SimMath.clamp_int((rating - floor_rating) * 100 / maxi(1, ceiling - floor_rating), 0, 100)


## Standard Elo. `matches_played` only tapers the K-factor.
static func rating_delta(own: int, opponent: int, won: bool, matches_played: int) -> int:
	var k: int = K_STABLE
	if matches_played < PLACEMENT_MATCHES:
		k = K_PLACEMENT
	elif matches_played < PLACEMENT_MATCHES * 4:
		k = K_SETTLING

	# Expected score, scaled by 1000 to stay in integers. Beating someone far above you
	# is worth nearly the full K; beating someone far below is worth almost nothing,
	# which is what stops farming the bottom of the ladder.
	var expected: int = _expected_x1000(own, opponent)
	var actual: int = 1000 if won else 0
	var delta: int = (k * (actual - expected)) / 1000
	# A win always gains at least one point and a loss always costs one, or a heavy
	# favourite could win and move nowhere, which reads as a bug to the player.
	if won:
		return maxi(1, delta)
	return mini(-1, delta)


## 1 / (1 + 10^((opponent - own) / 400)), in thousandths, without floats leaving this
## function. Ranked rating is not part of `sim/`, so a float here is safe — but the
## integer form keeps rating changes identical across platforms anyway, which matters
## the day a server recomputes them.
static func _expected_x1000(own: int, opponent: int) -> int:
	var exponent: float = float(opponent - own) / 400.0
	var expected: float = 1.0 / (1.0 + pow(10.0, exponent))
	return int(round(expected * 1000.0))


## Seasonal soft reset: everyone is pulled toward the base rating rather than wiped.
## A hard reset throws away placement work and makes the first week of every season
## a scramble; a soft one keeps the ladder meaningful from day one.
static func season_reset_rating(rating: int) -> int:
	return BASE_RATING + (rating - BASE_RATING) / 2
