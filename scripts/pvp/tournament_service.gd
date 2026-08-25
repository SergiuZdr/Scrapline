class_name TournamentService
extends RefCounted

## The player's side of a scheduled tournament: what is running, how they are placed,
## and how many attempts they have left.
##
## Thin, like `GuildService`, and for the same reason: Nakama owns the schedule, the
## join requirement, the attempt limit and the record table. This fetches and caches.
##
## **Online only, and that is not a compromise.** A tournament is a ranking against other
## people; there is nothing coherent to show for it offline, so the screen says so
## instead of inventing a local one.

var client: NakamaClient
var content: ContentDB

var tournament: Dictionary = {}
var own: Dictionary = {}
var top: Array = []

signal changed


static func open(client_in: NakamaClient, content_in: ContentDB) -> TournamentService:
	var service := TournamentService.new()
	service.client = client_in
	service.content = content_in
	return service


func is_online() -> bool:
	return client != null and client.online


func is_running(now: int) -> bool:
	return not tournament.is_empty() and ends_at() > now


## Numbers from the server, read safely. A JSON `null` reaching `int()` is a crash, not a
## zero, and a tournament with no end date sends exactly that.
static func number(source: Dictionary, key: String) -> int:
	var value: Variant = source.get(key)
	return 0 if value == null else int(value)


func ends_at() -> int:
	return number(tournament, "end_time")


func started_at() -> int:
	return number(tournament, "start_time")


func max_attempts() -> int:
	return number(tournament, "max_attempts")


func attempts_left() -> int:
	if tournament.is_empty():
		return 0
	return maxi(0, max_attempts() - number(own, "attempts"))


func has_entered() -> bool:
	return not own.is_empty()


func refresh(reply: Callable = Callable()) -> void:
	if not is_online():
		return
	client.rpc_call("tournament_state", {}, func(ok: bool, response: Dictionary) -> void:
		if not ok:
			return
		var found: Variant = response.get("tournament")
		tournament = (found as Dictionary) if found != null else {}
		var mine: Variant = response.get("own")
		own = (mine as Dictionary) if mine != null else {}
		top = response.get("top", []) as Array
		changed.emit()
		if reply.is_valid():
			reply.call(true))


func enter(reply: Callable = Callable()) -> void:
	if tournament.is_empty() or not is_online():
		if reply.is_valid():
			reply.call(false, "no tournament is running")
		return
	client.rpc_call("tournament_join", {"id": String(tournament.get("id", ""))},
		func(ok: bool, response: Dictionary) -> void:
			if ok:
				refresh()
			if reply.is_valid():
				reply.call(ok, String(response.get("error", "")))) 


## The battle. Identical for every entrant -- the challenge, the map and the Condition all
## come from the tournament's id and start time, so the ranking compares squads rather
## than who drew the kinder opponent.
func build_setup(profile: PlayerProfile) -> BattleSetup:
	if tournament.is_empty():
		return null
	return Tournament.build_setup(
		String(tournament.get("id", "")), started_at(),
		Economy.squad_with_power(profile, content, "main"), content)
