extends SceneTree

## Async PvP and ranked-ladder tests.
##
## The questions that matter here are not "does the code run" but:
##
##   - **Is there anyone to fight on day one?** A competitive mode that opens with "no
##     opponents found" is dead permanently, so the ladder ships with its own.
##   - **Does the ladder actually rank?** If a bad squad climbs, the rating means
##     nothing and neither does the leaderboard.
##   - **Does every result verify?** Offline, a rejection is impossible unless
##     determinism has regressed — which is precisely when we want to hear about it,
##     rather than the day real players go online.
##
##   godot --headless --path . --script res://tools/verify_pvp.gd

const TEST_PATH: String = "user://test_pvp.json"

var _passed: int = 0
var _failed: int = 0
var _content: ContentDB


func _initialize() -> void:
	_content = ContentDB.load_all()
	if not _content.errors.is_empty():
		for e: String in _content.errors:
			printerr("content: ", e)
		quit(1)
		return

	print("")
	print("=== async pvp and ranked ===")

	_test_ladder_is_populated()
	_test_opponents_match_rating()
	_test_rating_maths()
	_test_tiers()
	_test_seasons()
	_test_defence_publishing()
	_test_full_match_verifies()
	_test_ladder_ranks_honestly()
	_test_offline_transport()
	_test_token_parsing()

	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	print("")
	_cleanup()
	quit(1 if _failed > 0 else 0)


# --- The ladder --------------------------------------------------------------

func _test_ladder_is_populated() -> void:
	_cleanup_pvp()
	var repo: LocalPvpRepository = LocalPvpRepository.open(_content)
	var opponents: Array = repo.find_opponents(1000, 5, "nobody")
	_check("a brand new player has opponents to fight", opponents.size() == 5)
	_check("the ladder spans a range of ratings",
		repo.leaderboard(100).size() >= LocalPvpRepository.BOT_COUNT)

	var top: Array = repo.leaderboard(3)
	var bottom: Array = repo.find_opponents(0, 3, "nobody")
	_check("the top of the ladder is much stronger than the bottom",
		(top[0] as PvpRepository.Defence).power > (bottom[0] as PvpRepository.Defence).power + 30)

	# Every player must meet the same opponent at the same rung, or early ranked
	# results cannot be compared between players.
	var again: LocalPvpRepository = LocalPvpRepository.open(_content)
	_check("the bot ladder is deterministic",
		_squad_fingerprint(again.get_defence("bot_030")) == _squad_fingerprint(repo.get_defence("bot_030")))


func _test_opponents_match_rating() -> void:
	var repo: LocalPvpRepository = LocalPvpRepository.open(_content)
	for target: int in [800, 1200, 1800]:
		var found: Array = repo.find_opponents(target, 3, "nobody")
		var worst: int = 0
		for defence: PvpRepository.Defence in found:
			worst = maxi(worst, absi(defence.rating - target))
		_check("opponents near %d are actually near it (worst gap %d)" % [target, worst], worst < 160)


# --- Rating ------------------------------------------------------------------

func _test_rating_maths() -> void:
	_check("beating an equal opponent gains points",
		Ranked.rating_delta(1000, 1000, true, 50) > 0)
	_check("losing to an equal opponent costs points",
		Ranked.rating_delta(1000, 1000, false, 50) < 0)
	_check("beating someone far above you is worth more",
		Ranked.rating_delta(1000, 1600, true, 50) > Ranked.rating_delta(1000, 1000, true, 50))
	# Without this, farming the bottom of the ladder is the fastest way up.
	_check("beating someone far below you is worth almost nothing",
		Ranked.rating_delta(1600, 1000, true, 50) <= 2)
	_check("losing to someone far below you hurts",
		Ranked.rating_delta(1600, 1000, false, 50) < -15)
	_check("a new account moves faster than a settled one",
		absi(Ranked.rating_delta(1000, 1000, true, 1)) > absi(Ranked.rating_delta(1000, 1000, true, 200)))
	_check("a win never gains zero", Ranked.rating_delta(2400, 400, true, 200) >= 1)
	_check("a loss never costs zero", Ranked.rating_delta(400, 2400, false, 200) <= -1)


func _test_tiers() -> void:
	_check("a new player starts in the bottom tier", Ranked.tier_name(1000) == "Reclaimer")
	_check("the top tier is reachable", Ranked.tier_name(2000) == "Foundry Lord")
	_check("tier progress runs 0-100",
		Ranked.tier_progress(900) == 0 and Ranked.tier_progress(2500) == 100)
	var rising: bool = Ranked.tier_progress(1000) < Ranked.tier_progress(1100)
	_check("tier progress rises with rating", rising)


func _test_seasons() -> void:
	var now: int = 40 * Ranked.SEASON_LENGTH + 5000
	_check("seasons advance", Ranked.season_of(now + Ranked.SEASON_LENGTH) == Ranked.season_of(now) + 1)
	_check("a season has a Condition", not Ranked.season_condition(now, _content).is_empty())
	# The whole point of rotating Conditions: the squad that answered last season is
	# not automatically the answer to this one.
	var this_season: String = Ranked.season_condition(now, _content)
	var next_season: String = Ranked.season_condition(now + Ranked.SEASON_LENGTH, _content)
	_check("the Condition changes between seasons", this_season != next_season)
	_check("a soft reset pulls toward the middle, not to zero",
		Ranked.season_reset_rating(2000) > Ranked.BASE_RATING
		and Ranked.season_reset_rating(2000) < 2000)
	_check("a soft reset lifts a low rating", Ranked.season_reset_rating(600) > 600)


# --- End to end --------------------------------------------------------------

func _test_defence_publishing() -> void:
	var store: ProfileStore = _fresh_store()
	_grant_squad(store)
	var service: PvpService = PvpService.open(_content, store.profile)
	service.publish_defence()

	var mine: PvpRepository.Defence = service.repository.get_defence(service.player_id())
	_check("publishing stores your squad as a defence", mine != null and mine.squad.size() == 4)
	_check("your own defence is excluded from your opponent list", _none_match(
		service.find_opponents(8), service.player_id()))


## The important one: fight a real ladder opponent, verify the result the way a server
## would, and confirm the rating moved.
func _test_full_match_verifies() -> void:
	var store: ProfileStore = _fresh_store()
	_grant_squad(store)
	var service: PvpService = PvpService.open(_content, store.profile)
	service.publish_defence()
	var now: int = 41 * Ranked.SEASON_LENGTH + 9000

	var opponents: Array = service.find_opponents(3)
	_check("found an opponent", opponents.size() > 0)
	if opponents.is_empty():
		return

	var defence: PvpRepository.Defence = opponents[0]
	var setup: BattleSetup = service.build_setup(defence, now, 12345)
	var orders: Array = [{0: ["ability:0", "attack"]}, {}, {1: ["advance", "attack"]}]

	var before: int = service.rating()
	var outcome: Dictionary = service.resolve(defence, setup, orders, now)

	_check("the match verified against a server-style re-run", bool(outcome["verified"]))
	_check("the rating moved", service.rating() != before)
	_check("the match was counted", service.matches_played() == 1)
	_check("the season's Condition was applied",
		setup.condition_id == Ranked.season_condition(now, _content))

	var submission: BattleSubmission = outcome["submission"]
	var report: BattleVerifier.Report = BattleVerifier.verify(
		submission, _content.to_sim_content(), _content.balance, defence.doctrine())
	_check("re-verifying the stored submission still passes", report.accepted())


## A ladder where a weak squad climbs is not a ladder. Plays a strong and a weak squad
## against the same rung and checks they end up on opposite sides of it.
func _test_ladder_ranks_honestly() -> void:
	var strong: int = _simulate_climb(_strong_squad(), 120)
	var weak: int = _simulate_climb(_weak_squad(), 120)
	print("    strong squad settled at %d, weak squad at %d" % [strong, weak])
	_check("a strong squad ends up rated above a weak one (%d vs %d)" % [strong, weak],
		strong > weak + 120)
	_check("the weak squad does not climb out of the bottom", weak < 1300)


## Plays a fixed squad up the ladder against real bot defences and returns its rating.
func _simulate_climb(squad: Array, matches: int) -> int:
	_cleanup_pvp()
	var store: ProfileStore = _fresh_store()
	_grant_all_parts(store)
	var applied: int = store.execute(ProfileCommands.SetSquad.new("main", squad))
	if applied != ProfileCommand.Result.OK:
		# Ignoring a command result is how this test silently fought with an empty
		# squad and reported both sides at rating zero.
		printerr("  climb setup failed: ", ProfileCommand.result_name(applied))
	var service: PvpService = PvpService.open(_content, store.profile)
	var now: int = 42 * Ranked.SEASON_LENGTH + 1000

	for i: int in matches:
		var opponents: Array = service.find_opponents(3)
		if opponents.is_empty():
			break
		var defence: PvpRepository.Defence = opponents[i % opponents.size()]
		var setup: BattleSetup = service.build_setup(defence, now, 7000 + i)
		service.resolve(defence, setup, [], now)
	return service.rating()


func _strong_squad() -> Array:
	var out: Array = []
	for i: int in 6:
		out.append(_spec("S%d" % i, "ch_citadel", "co_mag", "ar_maul", "ar_ripper", "mo_reactive"))
	return out


func _weak_squad() -> Array:
	var out: Array = []
	for i: int in 3:
		out.append(_spec("W%d" % i, "ch_courier", "co_null", "ar_scanner", "ar_scanner", "mo_scavenger"))
	return out


# --- Harness -----------------------------------------------------------------

func _fresh_store() -> ProfileStore:
	_cleanup()
	return ProfileStore.open(_content, TEST_PATH)


func _grant_squad(store: ProfileStore) -> void:
	var parts: PackedStringArray = [
		"ch_brute", "ch_hauler", "ch_lancer", "ch_skirmisher",
		"co_slug", "co_mag", "co_arc", "co_dynamo",
		"ar_ripper", "ar_hammer", "ar_lance", "ar_scanner", "ar_pulse",
		"mo_servo", "mo_ablative", "mo_targeting", "mo_governor",
	]
	var commands: Array = []
	for id: String in parts:
		commands.append(ProfileCommands.GrantPart.new(id))
	store.execute_batch(commands)
	store.execute(ProfileCommands.SetSquad.new("main", [
		_spec("A1", "ch_brute", "co_mag", "ar_ripper", "ar_ripper", "mo_servo"),
		_spec("A2", "ch_hauler", "co_slug", "ar_hammer", "ar_hammer", "mo_ablative"),
		_spec("A3", "ch_lancer", "co_arc", "ar_lance", "ar_scanner", "mo_targeting"),
		_spec("A4", "ch_skirmisher", "co_dynamo", "ar_pulse", "ar_ripper", "mo_governor"),
	]))


## Everything in the catalogue, so a test squad can use any part.
func _grant_all_parts(store: ProfileStore) -> void:
	var commands: Array = []
	var ids: Array = _content.parts.keys()
	ids.sort()
	for id: Variant in ids:
		commands.append(ProfileCommands.GrantPart.new(String(id)))
	store.execute_batch(commands)


## Identity of a squad by what it is made of, immune to JSON number widening.
func _squad_fingerprint(defence: PvpRepository.Defence) -> String:
	if defence == null:
		return "<none>"
	var out: PackedStringArray = []
	for entry: Variant in defence.squad:
		var parts: Dictionary = (entry as Dictionary).get("parts", {})
		var keys: Array = parts.keys()
		keys.sort()
		for key: Variant in keys:
			out.append("%s=%s" % [String(key), String(parts[key])])
		out.append("p%d" % int((entry as Dictionary).get("power", 100)))
	return "|".join(out)


func _spec(name: String, ch: String, co: String, al: String, ar: String, mo: String) -> Dictionary:
	return {"name": name, "parts": {
		"chassis": ch, "core": co, "arm_l": al, "arm_r": ar, "module": mo}}


func _none_match(defences: Array, id: String) -> bool:
	for defence: PvpRepository.Defence in defences:
		if defence.id == id:
			return false
	return true


## The online transport with no server behind it. This is the state a phone spends most
## of its life in, and everything the mode needs must still work: opponents to fight,
## a defence that persists, and submissions that WAIT rather than vanish.
func _test_offline_transport() -> void:
	print("\n  offline behaviour of the online transport")
	_cleanup_pvp()

	var client := NakamaClient.new()
	client.enabled = false
	var repo: NakamaPvpRepository = NakamaPvpRepository.open(client, _content)

	_check("reports itself offline", not repo.is_online())

	var opponents: Array = repo.find_opponents(1000, 5, "me")
	_check("still finds opponents with no server (%d)" % opponents.size(), opponents.size() == 5)
	_check("the leaderboard is not empty either", repo.leaderboard(8).size() == 8)

	var defence := PvpRepository.Defence.new()
	defence.id = "me"
	defence.display_name = "Tester"
	defence.squad = [_spec("A", "ch_brute", "co_cell", "ar_hammer", "ar_hammer", "mo_plate")]
	repo.publish_defence(defence)
	_check("a defence published offline is still readable", repo.get_defence("me") != null)

	# A match fought on a train must be scored when the signal returns, not dropped.
	var setup: BattleSetup = BattleSetup.make(99, defence.squad, defence.squad, "", "")
	var result: BattleResult = BattleSim.simulate(
		setup, [], _content.to_sim_content(), _content.balance, [])
	repo.submit_match(BattleSubmission.from_result(setup, [], result, "pvp:test"), "them")
	_check("an unsent submission is queued, not lost", repo._queued.size() == 1)

	client.free()


## The session token carries the user id. Parsing it wrong means every defence is
## published under an empty owner, which no offline test would ever notice.
func _test_token_parsing() -> void:
	print("\n  session token")
	var client := NakamaClient.new()

	# A JWT whose payload deliberately uses base64url characters and needs padding.
	var payload: String = Marshalls.utf8_to_base64(
		JSON.stringify({"uid": "b7c3f2ae-0000-4a1b-9f77-2d8e6c1a5b40", "exp": 1})
	).replace("+", "-").replace("/", "_").replace("=", "")
	_check("reads the user id out of a token",
		client._user_id_from_token("header.%s.signature" % payload)
			== "b7c3f2ae-0000-4a1b-9f77-2d8e6c1a5b40")
	_check("a malformed token yields no id, rather than junk",
		client._user_id_from_token("not-a-token") == "")
	_check("no token means not authenticated", not client.is_authenticated())

	client.free()


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		printerr("  FAIL  %s" % label)


func _cleanup_pvp() -> void:
	if FileAccess.file_exists(LocalPvpRepository.DEFENCE_PATH):
		DirAccess.open("user://pvp").remove(LocalPvpRepository.DEFENCE_PATH)


func _cleanup() -> void:
	_cleanup_pvp()
	var directory: DirAccess = DirAccess.open("user://")
	if directory == null:
		return
	for path: String in [TEST_PATH, SaveFile.BACKUP_PATH, SaveFile.TEMP_PATH]:
		if FileAccess.file_exists(path):
			directory.remove(path)
