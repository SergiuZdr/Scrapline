extends Node

## The running game: content, the player's profile, and the handoff between screens.
##
## An autoload rather than a passed-around object because the hub and the battle scene
## are separate scenes and one of them has to survive the transition. It owns nothing
## it can compute -- content and profile are loaded once and handed out.

var content: ContentDB
var store: ProfileStore
var pvp: PvpService
var coop: CoopService
var guilds: GuildService
var tournaments: TournamentService
var store_service: StoreService
var pass_service: PassService
var net: NakamaClient

## Set by the hub before launching a battle, read by the battle scene.
var pending_node_id: String = ""
## The PvP defence being attacked, when this battle is a ranked match.
var pending_defence: PvpRepository.Defence = null
## True when this battle is an attempt on the co-op boss.
var pending_boss: bool = false
## True when this battle is a tournament attempt.
var pending_tournament: bool = false

## The battle the ranked screen just fought, as orders rather than events. Handed to the
## transport for server verification; nothing offline needs it, but the ladder is only
## honest because this exists.
var pending_submission: BattleSubmission = null
## Gauntlet floor when > 0; a node battle otherwise. The two are mutually exclusive.
var pending_floor: int = 0
var pending_squad: String = "main"
## Set by the battle scene on the way back, read by the hub for the results screen.
var last_result_won: bool = false
var last_result_cycles: int = 0
## Damage the player's team dealt, from the simulation's own tally. Carried out of the
## battle scene because a colossus attempt is scored on damage, not on winning.
var last_battle_damage: int = 0
## Tournament score for the last battle, by the same rules the server applies.
var last_battle_score: int = 0
## Season XP the last battle earned. Zero once the daily cap is reached, which the
## results toast says out loud -- silently awarding nothing looks like a bug.
var last_pass_xp: int = 0
var last_rewards: Dictionary = {}
var has_result: bool = false

## A newer balance patch has been downloaded and takes effect at the next launch.
signal content_updated(version: int)
var content_update_pending: int = 0


func _ready() -> void:
	content = ContentDB.load_all()
	for e: String in content.errors:
		push_error("content: " + e)
	# The last patch this device saw, applied before anything reads a balance number.
	# Offline that means yesterday's balance rather than the build's, which is the one
	# every other player is on.
	var cached: ContentPatch = ContentPatch.load_cached()
	if cached != null:
		cached.apply_to(content)
	store = ProfileStore.open(content)
	_grant_starter_squad()

	net = NakamaClient.new()
	net.name = "NakamaClient"
	add_child(net)
	# Online is an upgrade, never a gate. The ladder, the bots and every screen work
	# with no server in existence; authentication happens in the background and swaps
	# the transport underneath when it lands.
	pvp = PvpService.open(content, store.profile,
		NakamaPvpRepository.open(net, content) if net.enabled else null, store)
	# A season boundary crossed while the player was away is applied before their first
	# match, so they are placed correctly rather than after losing a few.
	pvp.apply_season_rollover(now())
	pvp.publish_defence()
	# Both ids are minted on first read. Unsaved, the next launch mints new ones -- and
	# because the device id IS the account, every launch would sign in as a brand-new
	# player with a fresh rating.
	var _ladder_id: String = pvp.player_id()
	var _device: String = pvp.device_id()

	coop = CoopService.open(content, store.profile, store, net)
	coop.refresh_local(now())
	guilds = GuildService.open(net)
	tournaments = TournamentService.open(net, content)

	store_service = StoreService.open(content, store.profile, store, LocalBilling.new(), net)
	# Anything paid for but not delivered -- because the app was killed between the
	# charge and the grant -- is finished here, before the player sees a screen.
	store_service.process_pending(now())

	pass_service = PassService.open(content, store.profile, store)
	pass_service.apply_season_rollover(now())

	# ONE save, after every service has had its say. Saving halfway through startup wrote
	# the ladder's state and dropped the season track's, because the services that had not
	# been created yet had not marked the profile dirty.
	store.save()
	if pvp.repository is NakamaPvpRepository:
		(pvp.repository as NakamaPvpRepository).published.connect(_on_ladder_arrived)
	_connect()


## The server's standing is authoritative; the client's is a prediction made before any
## verification happened. Applied here rather than on a screen, because the correction
## has to land whether or not the player is looking at the ladder.
func _on_ladder_arrived(_changed: bool) -> void:
	if pvp.adopt_server_standing():
		store.save()


## Signs in with an id stored in the save, so the account follows the save rather than
## the machine. Failure is silent by design -- a player with no signal is not
## shown an error for a mode they can still play.
func _connect() -> void:
	if not net.enabled:
		return
	net.authenticate(pvp.device_id(), func(ok: bool, payload: Dictionary) -> void:
		if not ok:
			push_warning("pvp: offline (" + String(payload.get("error", "")) + ")")
			return
		if pvp.adopt_server_id(net.user_id):
			store.save()
		# The defence was published to the local file before the connection existed.
		# Publish again now it can reach the server.
		pvp.publish_defence()
		_sync_content()
		# The boss pool is shared, so the server's copy replaces the local one. A client
		# that kept its own count would show every member a different boss.
		coop.sync()
		guilds.refresh()
		tournaments.refresh())


## Pulls the live balance patch. A change takes effect at the NEXT launch rather than
## mid-session: swapping the numbers under a battle in progress would desync it from the
## server's re-run, and the player would lose a fight they had already won.
func _sync_content() -> void:
	net.rpc_call("sync_content", {}, func(ok: bool, response: Dictionary) -> void:
		if not ok or response.get("patch") == null:
			return
		var patch: ContentPatch = ContentPatch.from_dict(response["patch"] as Dictionary)
		if not patch.is_supported() or patch.version <= content.patch_version:
			return
		patch.cache()
		content_update_pending = patch.version
		content_updated.emit(patch.version))


## A brand-new profile owns nothing, and a squad of nothing cannot fight. This hands
## over a working starter loadout the first time the game runs -- through commands, so
## even the tutorial grant is in the audit log.
func _grant_starter_squad() -> void:
	if not store.profile.inventory().is_empty():
		return

	var starter: PackedStringArray = [
		"ch_brute", "ch_skirmisher", "ch_hauler",
		"co_slug", "co_dynamo", "co_furnace",
		"ar_ripper", "ar_hammer", "ar_pulse", "ar_scanner", "ar_lance",
		"mo_governor", "mo_ablative",
	]
	var commands: Array = []
	for part_id: String in starter:
		commands.append(ProfileCommands.GrantPart.new(part_id))
	store.execute_batch(commands)

	var squad: Array = [
		_spec("Anvil", "ch_hauler", "co_slug", "ar_hammer", "ar_hammer", "mo_ablative"),
		_spec("Grinder", "ch_brute", "co_furnace", "ar_ripper", "ar_ripper", "mo_governor"),
		_spec("Ledger", "ch_hauler", "co_slug", "ar_ripper", "ar_hammer", "mo_ablative"),
		_spec("Sparrow", "ch_skirmisher", "co_dynamo", "ar_pulse", "ar_lance", "mo_governor"),
	]
	store.execute(ProfileCommands.SetSquad.new("main", squad))
	store.execute(ProfileCommands.UpgradeBuilding.new("salvage_yard"))
	(store.profile.data["foundry"] as Dictionary)["last_collected"] = now()
	store.save()


func _spec(name: String, chassis: String, core: String, arm_l: String, arm_r: String, module: String) -> Dictionary:
	return {"name": name, "parts": {
		"chassis": chassis, "core": core, "arm_l": arm_l, "arm_r": arm_r, "module": module}}


func now() -> int:
	return int(Time.get_unix_time_from_system())


func profile() -> PlayerProfile:
	return store.profile


## Called by the battle scene when a fight ends. Pays out through the command layer, so
## a win recorded here is a win in the audit log and in the save.
func report_battle(node_id: String, won: bool, cycles: int) -> void:
	last_result_won = won
	last_result_cycles = cycles
	last_rewards = {}
	has_result = true

	# Season XP for every battle, whatever kind it was. A pass that only counted campaign
	# fights would quietly tell ranked and co-op players their time did not count.
	last_pass_xp = pass_service.award_battle(won, now())

	if pending_tournament:
		pending_tournament = false
		# Scored on the server from the worker's re-run. The number shown here is the
		# client's own arithmetic on its own battle, and is replaced by the ranking as
		# soon as the verdict lands.
		if pending_submission != null:
			pvp.repository.submit_match(pending_submission, "tournament")
			pending_submission = null
		last_rewards = {"score": last_battle_score}
		store.save()
		return

	if pending_boss:
		pending_boss = false
		var outcome: Dictionary = coop.resolve_attempt(last_battle_damage, now())
		if pending_submission != null:
			pvp.repository.submit_match(pending_submission, "boss")
			pending_submission = null
		last_rewards = {
			"scrap": int(outcome.get("scrap", 0)),
			"boss_damage": int(outcome.get("damage", 0)),
			"boss_percent": int(outcome.get("percent", 100)),
		}
		store.save()
		return

	if pending_defence != null:
		var defence: PvpRepository.Defence = pending_defence
		pending_defence = null
		var outcome: Dictionary = pvp.resolve_from_result(defence, cycles, won, now())
		if pending_submission != null:
			pvp.repository.submit_match(pending_submission, defence.id)
			pending_submission = null
		last_rewards = {"rating": int(outcome.get("delta", 0)), "tier": String(outcome.get("tier", ""))}
		store.save()
		return

	if pending_floor > 0:
		var floor_number: int = pending_floor
		pending_floor = 0
		var before: int = store.profile.currency(PlayerProfile.SCRAP)
		var commands: Array = [ProfileCommands.RecordGauntlet.new(floor_number, won, now())]
		if won:
			commands.append(ProfileCommands.GrantCurrency.new(
				PlayerProfile.SCRAP, Gauntlet.floor_reward(floor_number), "gauntlet"))
		store.execute_batch(commands)
		last_rewards = {"scrap": store.profile.currency(PlayerProfile.SCRAP) - before,
			"floor": floor_number}
		store.save()
		return

	if won and not node_id.is_empty():
		var before_scrap: int = store.profile.currency(PlayerProfile.SCRAP)
		var before_alloy: int = store.profile.currency(PlayerProfile.ALLOY)
		var before_parts: int = store.profile.inventory().size()

		store.execute_batch(Campaign.reward_commands(store.profile, content, node_id))

		last_rewards = {
			"scrap": store.profile.currency(PlayerProfile.SCRAP) - before_scrap,
			"alloy": store.profile.currency(PlayerProfile.ALLOY) - before_alloy,
			"new_parts": store.profile.inventory().size() - before_parts,
		}
	else:
		store.award_battle(false, cycles, "")

	store.save()
