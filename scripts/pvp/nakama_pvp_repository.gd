class_name NakamaPvpRepository
extends PvpRepository

## The online transport: defences and results live on the server.
##
## ## Why this caches instead of blocking
##
## `PvpRepository` is a synchronous interface and HTTP is not. Rather than infect every
## caller with `await` — which would mean a hub screen that can freeze on a slow train —
## this holds the last known ladder and refreshes it in the background. `find_opponents`
## always answers instantly with the freshest thing it has, and `refresh()` tells the UI
## when there is something newer to draw.
##
## ## Why it still carries the local repository
##
## Two reasons, both load-bearing:
##
##   1. **Bots.** A real server starts with no players on it. The first person to open
##      Ranked must not see an empty ladder, so server opponents are topped up from the
##      generated bot ladder — the same one, at the same ratings, so nothing about the
##      early climb changes when players do arrive.
##   2. **Offline.** A phone loses signal. The mode keeps working against bots, and the
##      submissions queue until it is back.
##
## Rating changes are **still the server's** — `submit_match` sends orders for
## re-simulation, and a result the server rejects never becomes a rating on the ladder.

## Emitted when the ladder changes underneath whatever is on screen.
signal published(changed: bool)

const REFRESH_INTERVAL_SEC: int = 60

var client: NakamaClient
var fallback: LocalPvpRepository

var _defences: Dictionary = {}
var _leaderboard: Array = []
## The server's view of the player's own standing, from the last refresh. The client
## predicts a rating the instant a match ends so the screen is not blank; this is the
## one that is true, and it wins as soon as it arrives.
var server_rating: int = -1
var server_matches: int = -1
var _fetched_at: int = 0
var _in_flight: bool = false
## Submissions the server has not accepted yet. Kept so a match fought on a train is
## still scored when the signal comes back, rather than silently lost.
var _queued: Array = []


static func open(client_in: NakamaClient, content: ContentDB) -> NakamaPvpRepository:
	var repo := NakamaPvpRepository.new()
	repo.client = client_in
	repo.fallback = LocalPvpRepository.open(content)
	return repo


func is_online() -> bool:
	return client != null and client.online


# --- Reads -------------------------------------------------------------------

## Server opponents first, topped up with bots. Sorted the same way the local ladder
## sorts, so the two sources interleave by rating rather than appearing as two lists.
func find_opponents(rating: int, count: int, exclude_id: String) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for id: Variant in _sorted_ids(rating):
		if String(id) == exclude_id:
			continue
		out.append(_defences[id])
		seen[String(id)] = true
		if out.size() >= count:
			return out

	for entry: Variant in fallback.find_opponents(rating, count, exclude_id):
		var defence: Defence = entry
		if seen.has(defence.id):
			continue
		out.append(defence)
		if out.size() >= count:
			break
	return out


func get_defence(id: String) -> Defence:
	if _defences.has(id):
		return _defences[id]
	return fallback.get_defence(id)


func leaderboard(count: int) -> Array:
	# The server's board is the real one. Bots fill it only while it is short, so a live
	# ladder stops showing them as soon as there are enough people on it.
	var out: Array = _leaderboard.duplicate()
	if out.size() < count:
		for entry: Variant in fallback.leaderboard(count):
			out.append(entry)
	out.sort_custom(func(a: Defence, b: Defence) -> bool:
		if a.rating != b.rating:
			return a.rating > b.rating
		return a.id < b.id)
	return out.slice(0, mini(count, out.size()))


# --- Writes ------------------------------------------------------------------

func publish_defence(defence: Defence) -> void:
	# Locally too, always. It is what the player defends with while offline, and it is
	# what the ladder falls back to if the server never answers.
	fallback.publish_defence(defence)
	_defences[defence.id] = defence
	if not is_online():
		return
	# Publishing is also how a player JOINS the ladder server-side, so the first ladder
	# fetch is chained to its reply rather than fired alongside it. Sent in parallel, the
	# fetch usually arrives first, finds the player not on the ladder yet, and gets back
	# an empty list -- which then looks exactly like "there is nobody to fight".
	client.rpc_call("publish_defence", {
		"name": defence.display_name, "power": defence.power,
		"squad": defence.squad, "doctrine": defence.doctrine_rules,
	}, func(ok: bool, _response: Dictionary) -> void:
		if ok:
			refresh(defence.rating, 8, int(Time.get_unix_time_from_system()), published, true))


func record_result(attacker_id: String, defender_id: String, won: bool, rating_delta: int) -> void:
	# Applied locally so the screen updates immediately. The server's own rating is
	# authoritative and arrives with the next refresh -- if the verifier rejects the
	# match, the number the player briefly saw is corrected rather than kept.
	fallback.record_result(attacker_id, defender_id, won, rating_delta)
	var defender: Defence = _defences.get(defender_id)
	if defender != null:
		defender.rating = maxi(0, defender.rating - rating_delta if won else defender.rating + rating_delta)


## Hands the battle to the server as **orders**, for re-simulation. This is the whole
## anti-cheat: nothing the client says about the outcome is taken on trust.
func submit_match(submission: BattleSubmission, defender_id: String) -> void:
	_queued.append({"submission": submission, "defender": defender_id})
	_drain()


func _drain() -> void:
	if not is_online() or _queued.is_empty():
		return
	var entry: Dictionary = _queued.pop_front()
	var submission: BattleSubmission = entry["submission"]
	client.rpc_call("submit_match", submission.to_dict(),
		func(ok: bool, response: Dictionary) -> void:
			if not ok:
				# Put it back. A submission dropped on a flaky connection is a match the
				# player fought and was never paid for.
				_queued.push_front(entry)
				return
			var _state: String = String(response.get("state", ""))
			_drain())


# --- Refresh -----------------------------------------------------------------

## Pulls the ladder. `reply` fires with `true` when something changed and the caller
## should redraw. Safe to call on every screen open: it rate-limits itself.
##
## `force` skips the rate limit for the fetch chained to publishing, which has just
## changed the ladder and must not be answered from a cache. Zeroing `_fetched_at`
## instead does not work and is worth remembering why: the guard compares `now` against
## it, and the caller in question has no clock to pass.
func refresh(
	rating: int, count: int, now: int, reply: Variant = null, force: bool = false
) -> void:
	if not is_online() or _in_flight:
		return
	if not force and now - _fetched_at < REFRESH_INTERVAL_SEC:
		return
	_in_flight = true
	client.rpc_call("find_opponents", {"count": count},
		func(ok: bool, response: Dictionary) -> void:
			_in_flight = false
			if not ok:
				return
			var own: Dictionary = response.get("self", {}) as Dictionary
			if not own.is_empty():
				server_rating = int(own.get("rating", -1))
				server_matches = int(own.get("matches", -1))
			var opponents: Array = response.get("opponents", []) as Array
			# An empty ladder is not an answer worth caching for a minute -- it is what a
			# player sees in the seconds before their own record exists.
			if not opponents.is_empty():
				_fetched_at = now
			_defences.clear()
			_leaderboard.clear()
			for entry: Variant in opponents:
				var defence: Defence = Defence.from_dict(entry as Dictionary)
				_defences[defence.id] = defence
				_leaderboard.append(defence)
			_drain()
			if reply is Callable and (reply as Callable).is_valid():
				(reply as Callable).call(true)
			elif reply is Signal:
				(reply as Signal).emit(true))
	var _unused: int = rating


func _sorted_ids(rating: int) -> Array:
	var ids: Array = _defences.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool:
		var da: int = absi((_defences[a] as Defence).rating - rating)
		var db: int = absi((_defences[b] as Defence).rating - rating)
		if da != db:
			return da < db
		return String(a) < String(b))
	return ids
