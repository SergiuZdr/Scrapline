class_name GuildService
extends RefCounted

## Guilds: who you are chipping at the colossus with.
##
## Thin on purpose. Guilds are **Nakama groups** — membership, roles and join requests
## already exist server-side, and rebuilding them on storage would be a week of work and
## a new set of bugs to find in production. This class fetches, caches and reports.
##
## ## Why guilds do so little here
##
## The plan flags it and it is worth restating: an empty guild is worse than no guild. So
## a guild does exactly one thing at launch — it scopes the colossus pool, so the damage
## bar you are moving is the one your friends are moving — and nothing about the rest of
## the game is gated behind having one. A player with no guild fights their own copy of
## the boss and loses nothing else.
##
## Chat, guild wars and roles that mean something wait for a population that makes them
## worth having.

const MAX_MEMBERS: int = 30

var client: NakamaClient

## Last known guild and roster. Null when the player has none, or has never been online.
var guild: Dictionary = {}
var members: Array = []
var browsable: Array = []

signal changed


static func open(client_in: NakamaClient) -> GuildService:
	var service := GuildService.new()
	service.client = client_in
	return service


func is_online() -> bool:
	return client != null and client.online


func has_guild() -> bool:
	return not guild.is_empty()


func member_count() -> int:
	return int(guild.get("members", members.size()))


## Pulls the player's guild and roster.
func refresh(reply: Callable = Callable()) -> void:
	if not is_online():
		return
	client.rpc_call("guild_state", {}, func(ok: bool, response: Dictionary) -> void:
		if not ok:
			return
		var found: Variant = response.get("guild")
		guild = (found as Dictionary) if found != null else {}
		members = response.get("members", []) as Array
		changed.emit()
		if reply.is_valid():
			reply.call(true))


## Guilds a player could join, largest first. An empty guild is the least useful thing
## to put in front of somebody looking for people.
func browse(search: String = "", reply: Callable = Callable()) -> void:
	if not is_online():
		return
	client.rpc_call("guild_list", {"search": search, "count": 20},
		func(ok: bool, response: Dictionary) -> void:
			if not ok:
				return
			browsable = response.get("guilds", []) as Array
			changed.emit()
			if reply.is_valid():
				reply.call(true))


## `reply` receives `(ok: bool, message: String)` for all three of these, because every
## one of them can fail for a reason the player needs to read: a taken name, a full
## guild, or simply being in one already.
func create(name: String, description: String, reply: Callable = Callable()) -> void:
	_act("guild_create", {"name": name, "description": description}, reply)


func join(guild_id: String, reply: Callable = Callable()) -> void:
	_act("guild_join", {"guildId": guild_id}, reply)


func leave(reply: Callable = Callable()) -> void:
	_act("guild_leave", {}, reply)


func _act(rpc: String, payload: Dictionary, reply: Callable) -> void:
	if not is_online():
		if reply.is_valid():
			reply.call(false, "guilds need a connection")
		return
	client.rpc_call(rpc, payload, func(ok: bool, response: Dictionary) -> void:
		if not ok:
			if reply.is_valid():
				reply.call(false, String(response.get("error", "that did not work")))
			return
		refresh()
		if reply.is_valid():
			reply.call(true, ""))
