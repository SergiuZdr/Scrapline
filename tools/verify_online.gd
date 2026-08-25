extends SceneTree

## The Phase 4 kill gate, as a script: **can two accounts fight through a real server
## without desync, without a cheat getting through, and without a lost save?**
##
## Everything else in `tools/` runs offline against itself. This one needs the stack up:
##
##   cd server && docker compose up -d
##   godot --headless --path . --script res://tools/verify_online.gd
##
## It plays the whole loop as the game plays it — authenticate, publish a defence, fetch
## an opponent, fight the battle with the real simulation, submit it, run the worker,
## and read the ladder back. Then it tries to cheat, six ways, and checks the server
## refuses each one.
##
## The offline tests cannot cover any of this, because the thing being tested is the
## boundary between two processes. `verify_anticheat.gd` proves the verifier rejects a
## forgery; only this proves the forgery never reaches a rating.

const BASE_URL: String = "http://127.0.0.1:7350"
const SERVER_KEY: String = "defaultkey"
const HTTP_KEY: String = "defaulthttpkey"

var _http: NakamaHttp
var _content: ContentDB
var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_content = ContentDB.load_all()
	if not _content.errors.is_empty():
		for e: String in _content.errors:
			printerr("content: ", e)
		quit(2)
		return
	_http = NakamaHttp.open(BASE_URL)
	# A real client applies the live patch before it plays. Without this the test fights
	# on shipped content while the worker verifies on patched content, and every
	# submission is correctly rejected as a content mismatch -- which is the pipeline
	# working, and the test being wrong.
	var live: Dictionary = _http.rpc_as_server(HTTP_KEY, "sync_content", {})
	if not live.has("error") and live.get("patch") != null:
		var patch: ContentPatch = ContentPatch.from_dict(live["patch"] as Dictionary)
		patch.apply_to(_content)
		print("  (content patch v%d applied: %s)" % [patch.version, _content.content_version()])

	print("")
	print("=== online: server-verified pvp ===")

	# A fresh pair of accounts per run. Reusing ids would mean the ladder carries state
	# from the last run and a rating assertion would pass for the wrong reason.
	var stamp: int = int(Time.get_unix_time_from_system())
	# Usernames are unique server-wide, so they carry the stamp as well as the device id.
	var attacker: String = _sign_in("dev-att-%d" % stamp, "Attacker-%d" % stamp)
	var defender: String = _sign_in("dev-def-%d" % stamp, "Defender-%d" % stamp)
	if attacker.is_empty() or defender.is_empty():
		printerr("could not sign in -- is the stack up? (cd server && docker compose up -d)")
		quit(2)
		return

	_test_publish_and_find(attacker, defender)
	_test_honest_match_scores(attacker, defender)
	_test_bot_match_verifies(attacker)
	_test_forgeries_are_refused(attacker, defender)
	_test_colossus_pool_is_server_owned(attacker)
	_test_receipts_cannot_be_replayed(attacker, defender)
	_test_guilds_scope_the_colossus(attacker, defender, stamp)
	_test_tournament_ranks_the_same_fight(attacker, defender, stamp)
	_test_worker_endpoints_are_not_client_callable(attacker)

	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _sign_in(device: String, name: String) -> String:
	return _http.authenticate(SERVER_KEY, device, name)


# --- The loop ----------------------------------------------------------------

func _test_publish_and_find(attacker: String, defender: String) -> void:
	print("\n  publishing and finding")

	var published: Dictionary = _http.rpc_as_user(defender, "publish_defence", {
		"name": "Defender", "power": 100,
		"squad": _squad(), "doctrine": Doctrine.default_doctrine().to_array(),
	})
	_check("the defender published a defence", bool(published.get("ok", false)))

	_http.rpc_as_user(attacker, "publish_defence", {
		"name": "Attacker", "power": 100,
		"squad": _squad(), "doctrine": Doctrine.default_doctrine().to_array(),
	})

	var found: Dictionary = _http.rpc_as_user(attacker, "find_opponents", {"count": 5})
	var opponents: Array = found.get("opponents", [])
	_check("the attacker was offered opponents (%d)" % opponents.size(), not opponents.is_empty())
	_check("the attacker is not offered themselves", _none_is(opponents, attacker))
	# The defender's doctrine comes from THEIR record. An attacker who could choose it
	# could hand their opponent a doctrine that does nothing.
	# Checked across the whole list rather than on whoever happens to top it: the point
	# is that no defence is ever offered without the behaviour it will fight with.
	var all_have_doctrine: bool = true
	for entry: Variant in opponents:
		if (entry as Dictionary).get("doctrine", []).is_empty():
			all_have_doctrine = false
	_check("every offer carries that player's own doctrine", all_have_doctrine)


func _test_honest_match_scores(attacker: String, defender: String) -> void:
	print("\n  an honest match")

	var before: int = _rating_of(attacker)
	var opponent: Dictionary = _first_opponent(attacker)
	if opponent.is_empty():
		_check("an opponent to fight", false)
		return

	var submission: BattleSubmission = _fight(opponent)
	var accepted: Dictionary = _http.rpc_as_user(attacker, "submit_match", submission.to_dict())
	_check("the server accepted the submission for verification",
		String(accepted.get("state", "")) == "pending")
	_check("the submission is orders, not events (%d bytes)" % submission.size_bytes(),
		submission.size_bytes() < 8192)

	# Nothing has moved yet, and that is the point: a submitted match is a claim.
	_check("the rating has NOT moved before verification", _rating_of(attacker) == before)

	var run: Dictionary = _run_worker()
	_check("the worker processed the match (%d)" % int(run["processed"]),
		int(run["processed"]) >= 1)
	_check("the worker's verdict was acceptance (%s)" % String((run["verdicts"] as Array)[0]),
		String((run["verdicts"] as Array)[0]) == "accepted")

	var after: int = _rating_of(attacker)
	_check("the rating moved once the worker verified it (%d -> %d)" % [before, after],
		after != before)
	# The player who was ACTUALLY fought -- `find_opponents` returns whoever is nearest
	# in rating, which on a ladder with more than two accounts on it is not necessarily
	# the defender this test created.
	var opponent_after: int = _rating_of_owner(attacker, String(opponent.get("id", "")))
	_check("the fought opponent's rating moved too, without them being present (%d)"
		% opponent_after, opponent_after != 1000)


## A new player's first ranked matches are against the generated bot ladder, and those
## have to count -- otherwise the ladder is decorative until enough real players exist.
##
## The server cannot verify them alone: it has no record of a bot's squad, and generating
## bots in TypeScript would be a second implementation of something that must agree with
## the client exactly. So the worker rebuilds the bot from the same seed and checks.
func _test_bot_match_verifies(attacker: String) -> void:
	print("\n  a match against the bot ladder")
	var bots: LocalPvpRepository = LocalPvpRepository.open(_content)
	var bot: PvpRepository.Defence = bots.get_defence("bot_012")
	if bot == null:
		_check("the bot ladder exists", false)
		return

	var before: int = _rating_of(attacker)
	var setup: BattleSetup = BattleSetup.make(4242, _squad(), bot.squad, "", "")
	var result: BattleResult = BattleSim.simulate(
		setup, [], _content.to_sim_content(), _content.balance, [null, bot.doctrine()])
	var submission: BattleSubmission = BattleSubmission.from_result(
		setup, [], result, "pvp:" + bot.id, _content.content_version())

	_http.rpc_as_user(attacker, "submit_match", submission.to_dict())
	var run: Dictionary = _run_worker()
	var verdicts: Array = run.get("verdicts", [])
	_check("the worker rebuilt the bot and accepted the match (%s)"
		% (String(verdicts[-1]) if not verdicts.is_empty() else "none"),
		not verdicts.is_empty() and String(verdicts[-1]) == "accepted")
	_check("a bot match moves the ranked rating (%d -> %d)" % [before, _rating_of(attacker)],
		_rating_of(attacker) != before)

	# A bot squad the player invented must fail the same way a real opponent's would.
	var faked: BattleSetup = BattleSetup.make(4242, _squad(), [
		_unit("ch_skirmisher", "co_arc", "ar_scatter")], "", "")
	var faked_result: BattleResult = BattleSim.simulate(
		faked, [], _content.to_sim_content(), _content.balance, [null, bot.doctrine()])
	var faked_submission: BattleSubmission = BattleSubmission.from_result(
		faked, [], faked_result, "pvp:" + bot.id, _content.content_version())
	_check("an invented bot squad is caught too",
		_reject_reason(attacker, faked_submission) == "DEFENCE_MISMATCH")


func _test_forgeries_are_refused(attacker: String, defender: String) -> void:
	print("\n  forgeries")
	var opponent: Dictionary = _first_opponent(attacker)
	if opponent.is_empty():
		_check("an opponent to forge against", false)
		return

	# 1. A lied winner, with otherwise honest inputs. This is the one that used to pass:
	#    comparing the hash first and returning early accepted it.
	var lied: BattleSubmission = _fight(opponent)
	lied.claimed_winner = SimDefs.TEAM_A if lied.claimed_winner != SimDefs.TEAM_A else SimDefs.TEAM_B
	var lied_verdict: String = _reject_reason(attacker, lied)
	_check("a lied winner is caught (%s)" % lied_verdict,
		lied_verdict == "rejected: winner differs")

	# 2. A battle fought against a squad the defender never published.
	var invented: BattleSubmission = _fight(opponent)
	invented.setup.team_specs[SimDefs.TEAM_B] = [_unit("ch_skirmisher", "co_arc", "ar_scatter")]
	var invented_verdict: String = _reject_reason(attacker, invented)
	_check("a battle against an invented opponent is caught (%s)" % invented_verdict,
		invented_verdict == "DEFENCE_MISMATCH")

	# 3. A battle fought on content the server has moved past. Not a forgery -- a player
	#    who was mid-session when a balance patch shipped -- and the verdict has to say so.
	var stale_content: BattleSubmission = _fight(opponent)
	stale_content.content_version = "deadbeef"
	var content_verdict: String = _reject_reason(attacker, stale_content)
	_check("a battle on stale content is rejected as a mismatch, not a cheat (%s)"
		% content_verdict, content_verdict == "rejected: different content version")

	# 4. A bad format version. A client on last month's rules must not be scored on them.
	var stale: BattleSubmission = _fight(opponent)
	var payload: Dictionary = stale.to_dict()
	payload["format"] = 99
	var refused: Dictionary = _http.rpc_as_user(attacker, "submit_match", payload)
	_check("an unsupported submission format is refused outright", refused.has("error"))

	var _unused: String = defender


## Tournaments: does everyone fight the same battle, and does the table rank it?
func _test_tournament_ranks_the_same_fight(attacker: String, defender: String, stamp: int) -> void:
	print("\n  tournaments")
	var id: String = "proving_%d" % stamp
	var opened: Dictionary = _http.rpc_as_server(HTTP_KEY, "open_tournament", {
		"id": id, "title": "Proving Ground", "description": "for the test",
		"durationHours": 24, "attempts": 5})
	_check("a tournament opens", bool(opened.get("ok", false)))

	var state: Dictionary = _http.rpc_as_user(attacker, "tournament_state", {"id": id})
	var tournament: Dictionary = state.get("tournament", {}) as Dictionary
	_check("and is visible to players", not tournament.is_empty())
	_check("with an attempt limit (%d)" % int(tournament.get("max_attempts", 0)),
		int(tournament.get("max_attempts", 0)) == 5)

	var start_time: int = int(tournament.get("start_time", 0))
	# The whole premise: the challenge is a function of the id and start time, so two
	# entrants -- and the verifying worker -- generate the identical squad.
	var mine: Array = Tournament.challenge_squad(id, start_time, _content)
	var theirs: Array = Tournament.challenge_squad(id, start_time, _content)
	_check("every entrant faces an identical generated squad",
		JSON.stringify(mine) == JSON.stringify(theirs) and mine.size() == SimDefs.SQUAD_SIZE)

	# A score before entering must not stick: the attempt limit is the tournament's, and
	# a client that could write scores without joining would make it meaningless.
	var setup: BattleSetup = Tournament.build_setup(id, start_time, _squad(), _content)
	var result: BattleResult = BattleSim.simulate(
		setup, [], _content.to_sim_content(), _content.balance, [])
	var score: int = Tournament.score_of(result, _content.balance)
	_check("an attempt produces a score (%d)" % score, score > 0)

	_http.rpc_as_user(attacker, "submit_match", BattleSubmission.from_result(
		setup, [], result, "tourney:" + id, _content.content_version()).to_dict())
	_run_worker()
	var before_entry: Dictionary = _http.rpc_as_user(attacker, "tournament_state", {"id": id})
	_check("a score from somebody who never entered does not rank",
		before_entry.get("own") == null)

	_http.rpc_as_user(attacker, "tournament_join", {"id": id})
	_http.rpc_as_user(attacker, "submit_match", BattleSubmission.from_result(
		setup, [], result, "tourney:" + id, _content.content_version()).to_dict())
	var run: Dictionary = _run_worker()
	var verdicts: Array = run.get("verdicts", [])
	_check("an entrant's verified attempt is accepted (%s)"
		% (String(verdicts[-1]) if not verdicts.is_empty() else "none"),
		not verdicts.is_empty() and String(verdicts[-1]) == "accepted")

	var ranked: Dictionary = _http.rpc_as_user(attacker, "tournament_state", {"id": id})
	var own: Dictionary = (ranked.get("own", {}) if ranked.get("own") != null else {}) as Dictionary
	_check("and it lands on the table (%d points, rank %d)" % [
		int(own.get("score", 0)), int(own.get("rank", 0))],
		int(own.get("score", 0)) == score and int(own.get("rank", 0)) >= 1)

	# A forged attempt against a squad the tournament never generated must not score.
	var faked: BattleSetup = BattleSetup.make(
		setup.seed_value, _squad(), [_unit("ch_skirmisher", "co_arc", "ar_scatter")],
		setup.condition_id, setup.map_id)
	var faked_result: BattleResult = BattleSim.simulate(
		faked, [], _content.to_sim_content(), _content.balance, [])
	_http.rpc_as_user(attacker, "submit_match", BattleSubmission.from_result(
		faked, [], faked_result, "tourney:" + id, _content.content_version()).to_dict())
	var faked_run: Dictionary = _run_worker()
	var faked_verdicts: Array = faked_run.get("verdicts", [])
	_check("an invented challenge squad is caught (%s)"
		% (String(faked_verdicts[-1]) if not faked_verdicts.is_empty() else "none"),
		not faked_verdicts.is_empty() and String(faked_verdicts[-1]) == "DEFENCE_MISMATCH")

	var _unused: String = defender


## Guilds, and the one thing they do: scope the colossus pool.
##
## The question is not "can a group be created" — Nakama does that — but whether two
## members are chipping at the SAME bar while an outsider is not.
func _test_guilds_scope_the_colossus(attacker: String, defender: String, stamp: int) -> void:
	print("\n  guilds")
	var name: String = "Yard %d" % (stamp % 100000)

	var created: Dictionary = _http.rpc_as_user(attacker, "guild_create", {
		"name": name, "description": "for the test"})
	_check("a guild is created", bool(created.get("ok", false)))

	var twice: Dictionary = _http.rpc_as_user(attacker, "guild_create", {"name": name + " II"})
	# One guild per player: splitting a small population across memberships makes every
	# one of them feel empty.
	_check("but not a second one while already in one", twice.has("error"))

	var listed: Dictionary = _http.rpc_as_user(defender, "guild_list", {"count": 20})
	var found: bool = false
	var guild_id: String = ""
	for entry: Variant in (listed.get("guilds", []) as Array):
		if String((entry as Dictionary).get("name", "")) == name:
			found = true
			guild_id = String((entry as Dictionary).get("id", ""))
	_check("and it is findable by another player", found)

	_http.rpc_as_user(defender, "guild_join", {"guildId": guild_id})
	var state: Dictionary = _http.rpc_as_user(defender, "guild_state", {})
	var members: Array = state.get("members", []) as Array
	_check("who can join it (%d members)" % members.size(), members.size() == 2)
	_check("and the roster carries ladder ratings",
		not members.is_empty() and int((members[0] as Dictionary).get("rating", 0)) > 0)

	# The pool. Both members must see one bar, and a third party must not be on it.
	_http.rpc_as_server(HTTP_KEY, "open_boss", {
		"bossId": "boss_kiln_walker", "hpPool": 500000, "durationHours": 168})

	var mine: Dictionary = _http.rpc_as_user(attacker, "boss_state", {})
	var theirs: Dictionary = _http.rpc_as_user(defender, "boss_state", {})
	_check("both members see a guild-scoped pool",
		String((mine.get("encounter", {}) as Dictionary).get("scope", "")) == "guild"
			and String((theirs.get("encounter", {}) as Dictionary).get("scope", "")) == "guild")

	var boss: Dictionary = _content.bosses["boss_kiln_walker"] as Dictionary
	var setup: BattleSetup = Colossus.build_setup(boss, _squad(), 606, _content)
	var result: BattleResult = BattleSim.simulate(
		setup, [], _content.to_sim_content(), _content.balance, [])
	_http.rpc_as_user(attacker, "submit_match", BattleSubmission.from_result(
		setup, [], result, "boss:boss_kiln_walker", _content.content_version()).to_dict())
	_run_worker()

	var after_theirs: Dictionary = _http.rpc_as_user(defender, "boss_state", {})
	var moved: int = 500000 - int((after_theirs.get("encounter", {}) as Dictionary).get("remaining", 500000))
	_check("one member's damage moves the other's bar (%d)" % moved, moved > 0)

	# A player with no guild has their own copy, so the mode is never gated behind
	# finding people to play with.
	var loner: String = _sign_in("dev-loner-%d" % stamp, "Loner-%d" % stamp)
	var alone: Dictionary = _http.rpc_as_user(loner, "boss_state", {})
	var alone_encounter: Dictionary = alone.get("encounter", {}) as Dictionary
	_check("a player with no guild fights their own copy",
		String(alone_encounter.get("scope", "")) == "solo"
			and int(alone_encounter.get("remaining", 0)) == 500000)

	_http.rpc_as_user(defender, "guild_leave", {})
	_http.rpc_as_user(attacker, "guild_leave", {})


## Receipt validation. The client-side guard is a convenience; **this** is the defence,
## because a determined player owns both ends of the client conversation.
func _test_receipts_cannot_be_replayed(attacker: String, defender: String) -> void:
	print("\n  purchase receipts")
	var order: String = "TEST.%d" % int(Time.get_unix_time_from_system())

	var first: Dictionary = _http.rpc_as_user(attacker, "validate_purchase", {
		"product": "cores_small", "order": order, "token": "t", "real": false})
	_check("a receipt validates once (%s)" % first.get("valid"), bool(first.get("valid", false)))
	_check("and is not flagged as a duplicate", not bool(first.get("duplicate", false)))

	var again: Dictionary = _http.rpc_as_user(attacker, "validate_purchase", {
		"product": "cores_small", "order": order, "token": "t", "real": false})
	_check("the same receipt again is a duplicate", bool(again.get("duplicate", false)))

	# The order id is stored under the SERVER, not the player. A per-player key would let
	# the same receipt be redeemed once on each of a hundred accounts, which is the whole
	# attack.
	var stolen: Dictionary = _http.rpc_as_user(defender, "validate_purchase", {
		"product": "cores_small", "order": order, "token": "t", "real": false})
	_check("and another account cannot redeem it either",
		bool(stolen.get("duplicate", false)))

	var malformed: Dictionary = _http.rpc_as_user(attacker, "validate_purchase", {
		"product": "cores_small", "real": false})
	_check("a receipt with no order id is refused", not bool(malformed.get("valid", false)))

	# The store validator is not implemented, so a receipt CLAIMING to be real must fail.
	# An unimplemented validator that accepts everything is worse than none at all.
	var pretend_real: Dictionary = _http.rpc_as_user(attacker, "validate_purchase", {
		"product": "cores_small", "order": order + ".real", "token": "forged", "real": true})
	_check("a receipt claiming to be real is refused until store validation exists (%s)"
		% String(pretend_real.get("reason", "")), not bool(pretend_real.get("valid", false)))


## The co-op boss through the real server: one shared pool, moved only by damage the
## worker recomputed itself.
func _test_colossus_pool_is_server_owned(attacker: String) -> void:
	print("\n  the colossus pool")
	var ids: Array = _content.bosses.keys()
	ids.sort()
	if ids.is_empty():
		_check("a boss is authored", false)
		return
	var boss: Dictionary = _content.bosses[ids[0]] as Dictionary

	var opened: Dictionary = _http.rpc_as_server(HTTP_KEY, "open_boss", {
		"bossId": String(boss["id"]), "hpPool": int(boss.get("hp_pool", 900000)),
		"durationHours": 168,
	})
	_check("the encounter opens", bool(opened.get("ok", false)))

	var before: Dictionary = _http.rpc_as_user(attacker, "boss_state", {})
	var start: int = int((before.get("encounter", {}) as Dictionary).get("remaining", 0))
	_check("the pool starts full (%s)" % start, start == int(boss.get("hp_pool", 0)))

	var setup: BattleSetup = Colossus.build_setup(boss, _squad(), 8181, _content)
	var result: BattleResult = BattleSim.simulate(
		setup, [], _content.to_sim_content(), _content.balance, [])
	var dealt: int = Colossus.damage_from(result)
	var submission: BattleSubmission = BattleSubmission.from_result(
		setup, [], result, "boss:" + String(boss["id"]), _content.content_version())

	_http.rpc_as_user(attacker, "submit_match", submission.to_dict())
	var run: Dictionary = _run_worker()
	var verdicts: Array = run.get("verdicts", [])
	_check("the worker verified the attempt (%s)"
		% (String(verdicts[-1]) if not verdicts.is_empty() else "none"),
		not verdicts.is_empty() and String(verdicts[-1]) == "accepted")

	var after: Dictionary = _http.rpc_as_user(attacker, "boss_state", {})
	var encounter: Dictionary = after.get("encounter", {}) as Dictionary
	var moved: int = start - int(encounter.get("remaining", start))
	# The number that matters is the worker's, not the client's. They agree here because
	# the client was honest; the test is that the SERVER produced it.
	_check("the pool moved by the verified damage (%d of %d)" % [moved, dealt],
		moved == dealt and moved > 0)
	_check("and the player's contribution is recorded",
		int(encounter.get("contributed", 0)) == moved)

	# The colossus is scored on damage, so an attempt that LOSES still has to count --
	# otherwise a guild boss is a boss only its strongest members ever touch.
	_check("an attempt is scored on damage, not on winning",
		result.winner != SimDefs.TEAM_A and moved > 0)


func _test_worker_endpoints_are_not_client_callable(attacker: String) -> void:
	print("\n  the worker endpoints")
	var claim: Dictionary = _http.rpc_as_user(attacker, "worker_claim", {"count": 1})
	_check("a signed-in client cannot claim submissions", claim.has("error"))
	var verdict: Dictionary = _http.rpc_as_user(attacker, "worker_verdict", {
		"matchId": "x", "submitter": "y", "accepted": true, "won": true})
	_check("a signed-in client cannot write a verdict", verdict.has("error"))


# --- Helpers -----------------------------------------------------------------

## Submits, runs the worker, and reports what the worker decided -- AND whether the
## rating moved. Both matter: a verdict of "rejected" that still paid out would be worse
## than no verdict at all.
func _reject_reason(token: String, submission: BattleSubmission) -> String:
	var response: Dictionary = _http.rpc_as_user(token, "submit_match", submission.to_dict())
	if response.has("error"):
		return "REFUSED"
	var before: int = _rating_of(token)
	var run: Dictionary = _run_worker()
	if _rating_of(token) != before:
		return "SCORED"
	var verdicts: Array = run.get("verdicts", [])
	return String(verdicts[-1]) if not verdicts.is_empty() else "NO_VERDICT"


## Fights the battle for real, with both sides on doctrine, and packages it the way the
## game does. This is the same simulation the worker will re-run -- which is the whole
## reason a submission can be 1 KB instead of a megabyte of events.
func _fight(opponent: Dictionary) -> BattleSubmission:
	var setup: BattleSetup = BattleSetup.make(
		int(Time.get_unix_time_from_system()), _squad(),
		opponent.get("squad", []) as Array, "", "")
	var doctrine: Doctrine = Doctrine.from_array_or_default(
		opponent.get("doctrine", []) as Array, "defender")
	var result: BattleResult = BattleSim.simulate(
		setup, [], _content.to_sim_content(), _content.balance, [null, doctrine])
	return BattleSubmission.from_result(
		setup, [], result, "pvp:" + String(opponent.get("id", "")), _content.content_version())


## Runs the verification worker as a separate process, exactly as production would, and
## reports what it decided about each match it claimed.
func _run_worker() -> Dictionary:
	var output: Array = []
	var exe: String = OS.get_executable_path()
	OS.execute(exe, [
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tools/verify_worker.gd", "--",
		"--nakama", BASE_URL, "--http-key", HTTP_KEY, "--once",
	], output, true)
	var processed: int = 0
	var verdicts: Array = []
	for line: String in "\n".join(output).split("\n"):
		if line.begins_with("processed "):
			processed = int(line.substr(10))
		elif line.begins_with("  "):
			# "  <match>  <verdict>  <outcome>"
			var fields: PackedStringArray = line.strip_edges().split("  ", false)
			if fields.size() >= 2:
				verdicts.append(fields[1].strip_edges())
	return {"processed": processed, "verdicts": verdicts}


func _first_opponent(token: String) -> Dictionary:
	var found: Dictionary = _http.rpc_as_user(token, "find_opponents", {"count": 5})
	var opponents: Array = found.get("opponents", [])
	return opponents[0] as Dictionary if not opponents.is_empty() else {}


func _rating_of(token: String) -> int:
	var board: Dictionary = _http.get_json("/v2/leaderboard/ranked?limit=100", token)
	var me: Dictionary = _http.get_json("/v2/account", token)
	var id: String = String((me.get("user", {}) as Dictionary).get("id", ""))
	for record: Variant in (board.get("records", []) as Array):
		if String((record as Dictionary).get("owner_id", "")) == id:
			return int(String((record as Dictionary).get("score", "0")))
	return 0


## Any player's rating, read from the ladder with someone else's token. Public data --
## a leaderboard nobody else can read is not a leaderboard.
func _rating_of_owner(token: String, owner_id: String) -> int:
	var board: Dictionary = _http.get_json("/v2/leaderboard/ranked?limit=100", token)
	for record: Variant in (board.get("records", []) as Array):
		if String((record as Dictionary).get("owner_id", "")) == owner_id:
			return int(String((record as Dictionary).get("score", "0")))
	return 0


func _none_is(opponents: Array, token: String) -> bool:
	var me: Dictionary = _http.get_json("/v2/account", token)
	var id: String = String((me.get("user", {}) as Dictionary).get("id", ""))
	for entry: Variant in opponents:
		if String((entry as Dictionary).get("id", "")) == id:
			return false
	return true


func _squad() -> Array:
	return [
		_unit("ch_brute", "co_ember", "ar_hammer"),
		_unit("ch_bulwark", "co_slug", "ar_ripper"),
		_unit("ch_lancer", "co_mag", "ar_lance"),
	]


func _unit(chassis: String, core: String, arm: String) -> Dictionary:
	return {"name": chassis, "power": 100, "parts": {
		"chassis": chassis, "core": core, "arm_l": arm, "arm_r": arm, "module": "mo_plate"}}


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		printerr("  FAIL  %s" % label)
