class_name CoopService
extends RefCounted

## Runs the co-op boss: which encounter is open, what the player has contributed, and
## what happens when an attempt ends.
##
## Follows the same shape as `PvpService`, for the same reason: the transport is a
## detail. Offline the pool lives in the player's own save and they are chipping at it
## alone; online it lives on the server and the whole guild is chipping at the same one.
## **Nothing above this class knows which**, so the boss is playable on a train and
## meaningful in a guild without two implementations of the encounter.
##
## The damage that counts is always the server's re-run, never the client's claim. The
## number shown the moment a battle ends is a preview, corrected when the verdict lands.

## Attempts a player may make against one encounter. Without a cap, the boss is a
## question of who can sit and grind the longest, which is the least interesting answer
## a co-op fight can have.
const ATTEMPTS_PER_WINDOW: int = 12

var content: ContentDB
var _profile: PlayerProfile
var _store: ProfileStore
var client: NakamaClient

## The live encounter as last known. Offline this IS the truth; online it is a cache the
## server corrects.
var encounter: Colossus.Encounter = null

signal encounter_changed


static func open(
	content_in: ContentDB, profile: PlayerProfile, store: ProfileStore = null,
	client_in: NakamaClient = null
) -> CoopService:
	var service := CoopService.new()
	service.content = content_in
	service._profile = profile
	service._store = store
	service.client = client_in
	return service


func is_online() -> bool:
	return client != null and client.online


## The boss currently being fought. One at a time by design: two simultaneous bosses
## split a guild's attention and neither dies.
func current_boss() -> Dictionary:
	var ids: Array = content.bosses.keys()
	if ids.is_empty():
		return {}
	ids.sort()
	return content.bosses[ids[0]] as Dictionary


## Ensures there is an open encounter, starting a fresh one when the window has expired.
## Offline this rolls over on the clock; online the server decides and this is a mirror.
func refresh_local(now: int) -> void:
	var boss: Dictionary = current_boss()
	if boss.is_empty():
		return

	var stored: Dictionary = _coop().get("encounter", {}) as Dictionary
	if not stored.is_empty():
		var existing: Colossus.Encounter = Colossus.Encounter.from_dict(stored)
		if existing.ends_at > now and not existing.is_defeated() \
				and existing.boss_id == String(boss.get("id", "")):
			encounter = existing
			return

	encounter = Colossus.open(boss, now)
	_coop()["encounter"] = encounter.to_dict()
	_coop()["attempts"] = 0
	_commit()
	encounter_changed.emit()


func attempts_left() -> int:
	return maxi(0, ATTEMPTS_PER_WINDOW - int(_coop().get("attempts", 0)))


## The battle for one attempt. Seeded per attempt so a player cannot re-fight the same
## favourable roll, and so the server can reproduce this exact battle.
func build_setup(now: int) -> BattleSetup:
	var boss: Dictionary = current_boss()
	if boss.is_empty() or encounter == null:
		return null
	var seed_value: int = (encounter.ends_at * 31 + int(_coop().get("attempts", 0)) * 7919 + now) & 0x7FFFFFFF
	return Colossus.build_setup(
		boss, Economy.squad_with_power(_profile, content, "main"), seed_value, content)


## Applies a finished attempt. `damage` comes from the simulation's own tally.
##
## Offline it is applied immediately, because there is nobody to lie to and no server to
## correct it. Online it is applied optimistically and the server's verdict overwrites
## it -- an attempt that fails verification contributes nothing.
func resolve_attempt(damage: int, now: int) -> Dictionary:
	if encounter == null:
		return {}
	var applied: int = maxi(0, damage)
	encounter.hp_remaining = maxi(0, encounter.hp_remaining - applied)
	encounter.contributed += applied

	var coop: Dictionary = _coop()
	coop["attempts"] = int(coop.get("attempts", 0)) + 1
	coop["encounter"] = encounter.to_dict()

	var defeated: bool = encounter.is_defeated()
	var scrap: int = Colossus.reward_scrap(applied, encounter.hp_pool, defeated)
	_commit()

	if scrap > 0 and _store != null:
		_store.execute(ProfileCommands.GrantCurrency.new(PlayerProfile.SCRAP, scrap, "colossus"))

	var _unused: int = now
	encounter_changed.emit()
	return {
		"damage": applied, "scrap": scrap, "defeated": defeated,
		"remaining": encounter.hp_remaining, "percent": encounter.percent_remaining(),
	}


# --- Server ------------------------------------------------------------------

## Pulls the guild-wide encounter. The server's numbers replace the local ones wholesale:
## a shared pool that each client tracked independently would show every member a
## different boss.
func sync(reply: Callable = Callable()) -> void:
	if not is_online():
		return
	client.rpc_call("boss_state", {}, func(ok: bool, response: Dictionary) -> void:
		if not ok or response.get("encounter") == null:
			return
		encounter = Colossus.Encounter.from_dict(response["encounter"] as Dictionary)
		_coop()["encounter"] = encounter.to_dict()
		_commit()
		encounter_changed.emit()
		if reply.is_valid():
			reply.call(true))


func _coop() -> Dictionary:
	if not _profile.data.has("coop"):
		_profile.data["coop"] = {"encounter": {}, "attempts": 0}
	return _profile.data["coop"] as Dictionary


## Through the command layer, like every other piece of player state. Writing straight
## into the dictionary looks identical and never saves.
func _commit() -> void:
	if _store == null:
		return
	var result: int = _store.execute(ProfileCommands.SetCoopState.new(_coop()))
	if result != ProfileCommand.Result.OK:
		push_warning("coop: state rejected (" + ProfileCommand.result_name(result) + ")")
