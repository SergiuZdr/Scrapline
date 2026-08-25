class_name PvpService
extends RefCounted

## Ties the pieces together: publish a defence, pick an opponent, fight, verify, score.
##
## The verification step runs **on every result, even offline**. That is deliberate: it
## is the same code the server will run, so a determinism regression is caught during
## development rather than the day players go online and honest submissions start
## getting rejected.

var repository: PvpRepository
var content: ContentDB
var _profile: PlayerProfile
## The store, so ranked state is written through the command layer like everything else.
## Optional: the balance and ladder tools drive this class with a bare profile.
var _store: ProfileStore


static func open(
	content_in: ContentDB, profile: PlayerProfile, repository_in: PvpRepository = null,
	store: ProfileStore = null
) -> PvpService:
	var service := PvpService.new()
	service.content = content_in
	service._profile = profile
	service._store = store
	# The transport is the caller's choice. Nothing else in this class knows or cares
	# which one it got, which is the only reason the Nakama swap is a line rather than
	# a rewrite.
	service.repository = repository_in if repository_in != null else LocalPvpRepository.open(content_in)
	return service


## Adopts the server's user id once the player authenticates. The local id is a
## placeholder minted before any server existed; keeping both would mean the player's
## own server-side defence stops being recognised as theirs and shows up as an opponent
## they can farm.
func adopt_server_id(server_id: String) -> bool:
	if server_id.is_empty() or player_id() == server_id:
		return false
	_pvp()["id"] = server_id
	_commit()
	return true


func player_id() -> String:
	var id: String = String(_pvp().get("id", ""))
	if id.is_empty():
		# Stable per-profile id. Replaced by the Nakama user id once accounts exist.
		# get_unix_time_from_system() returns a FLOAT; the bitwise mask needs an int, and
		# without the cast this whole script fails to compile.
		id = "local_%d" % (int(Time.get_unix_time_from_system()) & 0xFFFFFF)
		_pvp()["id"] = id
		_commit()
	return id


## The id this installation authenticates with, kept SEPARATE from `player_id()`.
##
## They started as the same value and that was a bug with a long fuse: `player_id()`
## becomes the server's user id once the player signs in, so the next launch tried to
## authenticate a device whose id was a user uuid, under a username that account already
## held -- and every sign-in after the first failed with "username is already in use",
## silently, leaving the game offline forever.
func device_id() -> String:
	var pvp: Dictionary = _pvp()
	var id: String = String(pvp.get("device", ""))
	if id.is_empty():
		# Time alone is not enough: two installs first launched in the same second would
		# collide and share an account.
		id = "dev_%x%x" % [int(Time.get_unix_time_from_system()), randi()]
		pvp["device"] = id
		_commit()
	return id


func rating() -> int:
	return int(_pvp().get("rating", Ranked.BASE_RATING))


## Takes the server's standing as the truth. The client's own number is a prediction
## made before the worker has verified anything, and a match the server rejects must not
## leave a rating behind that no ladder agrees with.
func adopt_server_standing() -> bool:
	if not (repository is NakamaPvpRepository):
		return false
	var repo: NakamaPvpRepository = repository as NakamaPvpRepository
	if repo.server_rating < 0 or repo.server_rating == rating():
		return false
	var pvp: Dictionary = _pvp()
	pvp["rating"] = repo.server_rating
	if repo.server_matches >= 0:
		pvp["matches"] = maxi(matches_played(), repo.server_matches)
	_commit()
	return true


func matches_played() -> int:
	return int(_pvp().get("matches", 0))


func record() -> Dictionary:
	return {"wins": int(_pvp().get("wins", 0)), "losses": int(_pvp().get("losses", 0))}


## Publishes the player's current squad and doctrine as the thing others fight.
## Called whenever either changes -- a defence nobody updated is a free win.
func publish_defence() -> void:
	var defence := PvpRepository.Defence.new()
	defence.id = player_id()
	defence.display_name = String((_profile.data.get("player", {}) as Dictionary).get("name", "Reclaimer"))
	defence.rating = rating()
	defence.squad = Economy.squad_with_power(_profile, content, "main")
	# The EFFECTIVE doctrine, not the stored one. A player who has never opened the
	# editor has no rules saved, and publishing an empty list left the server holding a
	# defence with no described behaviour -- which then had to be guessed at, differently,
	# in two places.
	var rules: Array = (_profile.data.get("doctrines", {}) as Dictionary).get("main", []) as Array
	defence.doctrine_rules = rules if not rules.is_empty() else Doctrine.default_doctrine().to_array()
	defence.power = Economy.squad_power(_profile, content)
	defence.is_bot = false
	repository.publish_defence(defence)


func find_opponents(count: int = 5) -> Array:
	return repository.find_opponents(rating(), count, player_id())


## Builds the attack. The defender's squad and doctrine come from THEIR stored defence,
## never from anything the attacker supplies.
func build_setup(defence: PvpRepository.Defence, now: int, seed_value: int = 0) -> BattleSetup:
	return BattleSetup.make(
		seed_value if seed_value != 0 else now,
		Economy.squad_with_power(_profile, content, "main"),
		defence.squad,
		Ranked.season_condition(now, content),
		Ranked.season_map(now, content))


## Fights, verifies, and scores. Returns a report the UI can show.
func resolve(
	defence: PvpRepository.Defence, setup: BattleSetup, order_log: Array, now: int
) -> Dictionary:
	var result: BattleResult = BattleSim.simulate(
		setup, order_log, content.to_sim_content(), content.balance, [null, defence.doctrine()])

	var submission: BattleSubmission = BattleSubmission.from_result(
		setup, order_log, result, "pvp:" + defence.id, content.content_version())
	var report: BattleVerifier.Report = BattleVerifier.verify(
		submission, content.to_sim_content(), content.balance, defence.doctrine())

	# A rejected result scores nothing. Offline this should be impossible, so it means
	# a determinism regression -- which is exactly what we want to hear about early.
	if not report.accepted():
		push_warning("pvp: own result failed verification: " + report.summary())
		return {"verified": false, "detail": report.summary(), "result": result}

	var won: bool = result.winner == SimDefs.TEAM_A
	var delta: int = Ranked.rating_delta(rating(), defence.rating, won, matches_played())

	var pvp: Dictionary = _pvp()
	pvp["rating"] = maxi(0, rating() + delta)
	pvp["matches"] = matches_played() + 1
	pvp["wins"] = int(pvp.get("wins", 0)) + (1 if won else 0)
	pvp["losses"] = int(pvp.get("losses", 0)) + (0 if won else 1)
	pvp["season"] = Ranked.season_of(now)
	_commit()

	repository.record_result(player_id(), defence.id, won, absi(delta))

	return {
		"verified": true, "won": won, "delta": delta, "rating": rating(),
		"tier": Ranked.tier_name(rating()), "result": result, "submission": submission,
	}


## Applies the seasonal soft reset if the stored season is stale. Called on load, so a
## player returning after a season boundary is placed correctly before their first match.
func apply_season_rollover(now: int) -> bool:
	var pvp: Dictionary = _pvp()
	var season: int = Ranked.season_of(now)
	if int(pvp.get("season", -1)) == season:
		return false
	pvp["season"] = season
	pvp["rating"] = Ranked.season_reset_rating(rating())
	pvp["matches"] = 0
	_commit()
	return true


func leaderboard(count: int = 20) -> Array:
	return repository.leaderboard(count)


## Scores a match the battle scene already fought and verified. Split out from
## `resolve()` so the interactive path does not simulate the same battle twice.
func resolve_from_result(
	defence: PvpRepository.Defence, cycles: int, won: bool, now: int
) -> Dictionary:
	var delta: int = Ranked.rating_delta(rating(), defence.rating, won, matches_played())
	var pvp: Dictionary = _pvp()
	pvp["rating"] = maxi(0, rating() + delta)
	pvp["matches"] = matches_played() + 1
	pvp["wins"] = int(pvp.get("wins", 0)) + (1 if won else 0)
	pvp["losses"] = int(pvp.get("losses", 0)) + (0 if won else 1)
	pvp["season"] = Ranked.season_of(now)
	_commit()
	repository.record_result(player_id(), defence.id, won, absi(delta))
	var _unused: int = cycles
	return {"won": won, "delta": delta, "rating": rating(), "tier": Ranked.tier_name(rating())}


## Pushes the ranked block through the command layer so it is actually saved.
##
## Writing to `profile.data` directly is not a shortcut -- `ProfileStore` only writes
## the file when a command has marked it dirty, so a direct write is a change that
## disappears at the next launch without any error to notice.
func _commit() -> void:
	if _store == null:
		return
	var result: int = _store.execute(ProfileCommands.SetPvpState.new(_pvp()))
	if result != ProfileCommand.Result.OK:
		push_warning("pvp: state rejected (" + ProfileCommand.result_name(result) + ")")


func _pvp() -> Dictionary:
	if not _profile.data.has("pvp"):
		_profile.data["pvp"] = {
			"id": "", "rating": Ranked.BASE_RATING, "matches": 0,
			"wins": 0, "losses": 0, "season": -1,
		}
	return _profile.data["pvp"]
