extends SceneTree

## The verification worker: the server side of the anti-cheat.
##
## Nakama cannot run the battle simulation — its runtime is TypeScript and the
## simulation is GDScript. Re-implementing the rules there would be the worst possible
## choice: two implementations of a deterministic simulation drift, and the day they
## disagree every honest player starts being rejected.
##
## So this is a headless Godot process running the REAL simulation, consuming submissions
## and writing verdicts. One implementation of the rules, ever.
##
##   godot --headless --path . --script res://tools/verify_worker.gd -- --file one.json
##   godot --headless --path . --script res://tools/verify_worker.gd -- --in queue/ --out verdicts/
##   godot --headless --path . --script res://tools/verify_worker.gd -- \
##       --nakama http://127.0.0.1:7350 --http-key defaulthttpkey --once
##
## The Nakama mode is the real one: it claims pending submissions, re-runs each battle,
## and posts a verdict. **The rating only ever moves when a verdict lands**, so a client
## that never submits, or submits something that does not verify, gains nothing. The
## file modes exist because they are trivially testable and drive the integration test.

var _content: ContentDB
## The generated bot ladder, rebuilt from the same seed the game uses. It is how the
## worker verifies a match fought against a bot: the server has no record of a bot's
## squad, and re-implementing bot generation server-side would be a second source of
## truth for something that must match the client exactly.
var _bots: LocalPvpRepository


func _initialize() -> void:
	var opts: Dictionary = _parse_args(OS.get_cmdline_user_args())
	_content = ContentDB.load_all()
	if not _content.errors.is_empty():
		for e: String in _content.errors:
			printerr("content: ", e)
		quit(2)
		return

	if opts.has("nakama"):
		_sync_content(String(opts["nakama"]), String(opts.get("http-key", "defaulthttpkey")))
		quit(_serve(String(opts["nakama"]), String(opts.get("http-key", "defaulthttpkey")),
			not opts.has("once"), int(String(opts.get("interval", "5")))))
		return

	if opts.has("file"):
		var report: Dictionary = _verify_file(String(opts["file"]))
		print(JSON.stringify(report, "\t"))
		quit(0 if bool(report.get("accepted", false)) else 1)
		return

	var in_dir: String = String(opts.get("in", "user://queue"))
	var out_dir: String = String(opts.get("out", "user://verdicts"))
	quit(_drain(in_dir, out_dir))


## Verifies every submission in a directory. Returns a process exit code: zero when
## everything was processed, non-zero when something could not be read -- so a
## supervisor can tell "all rejected" (fine, that is the job) from "worker broken".
func _drain(in_dir: String, out_dir: String) -> int:
	var dir: DirAccess = DirAccess.open(in_dir)
	if dir == null:
		printerr("cannot open queue: ", in_dir)
		return 2
	if not DirAccess.dir_exists_absolute(out_dir):
		DirAccess.make_dir_recursive_absolute(out_dir)

	var accepted: int = 0
	var rejected: int = 0
	var unreadable: int = 0

	for name: String in dir.get_files():
		if not name.ends_with(".json"):
			continue
		var report: Dictionary = _verify_file(in_dir.path_join(name))
		if report.has("error"):
			unreadable += 1
		elif bool(report["accepted"]):
			accepted += 1
		else:
			rejected += 1

		var out: FileAccess = FileAccess.open(out_dir.path_join(name), FileAccess.WRITE)
		if out != null:
			out.store_string(JSON.stringify(report, "\t"))
			out.close()

	print("verified %d: %d accepted, %d rejected, %d unreadable" % [
		accepted + rejected + unreadable, accepted, rejected, unreadable])
	return 0 if unreadable == 0 else 3


# --- Nakama mode -------------------------------------------------------------

## Applies the live content patch before verifying anything.
##
## **The worker must run exactly what the players run.** If the server ships a balance
## change and the worker keeps verifying against the build's numbers, every honest
## submission replays to a different battle and the whole player base starts getting
## rejected — the loudest possible failure, caused by the quietest possible oversight.
func _sync_content(base_url: String, http_key: String) -> void:
	var http: NakamaHttp = NakamaHttp.open(base_url)
	var response: Dictionary = http.rpc_as_server(http_key, "sync_content", {})
	if response.has("error") or response.get("patch") == null:
		return
	var patch: ContentPatch = ContentPatch.from_dict(response["patch"] as Dictionary)
	if not patch.is_supported():
		printerr("worker: content patch format %d not understood; refusing to verify" % patch.format)
		quit(2)
		return
	patch.apply_to(_content)
	print("worker: content patch v%d applied (content %s)" % [
		patch.version, _content.content_version()])

## Claims, verifies and reports, forever (or once, with `--once`).
func _serve(base_url: String, http_key: String, forever: bool, interval: int) -> int:
	print("worker: %s (%s)" % [base_url, "polling" if forever else "single pass"])
	var http: NakamaHttp = NakamaHttp.open(base_url)
	while true:
		var claim: Dictionary = http.rpc_as_server(http_key, "worker_claim", {"count": 20})
		if claim.has("error"):
			printerr("claim failed: ", claim["error"])
			if not forever:
				return 2
		else:
			var matches: Array = claim.get("matches", [])
			for entry: Variant in matches:
				_handle(http, http_key, entry as Dictionary)
			if not matches.is_empty():
				print("processed %d" % matches.size())

		if not forever:
			return 0
		OS.delay_msec(maxi(1, interval) * 1000)
	return 0


## One claimed match: re-run it, check it was fought against the real defender, report.
func _handle(http: NakamaHttp, http_key: String, entry: Dictionary) -> void:
	var submission: BattleSubmission = BattleSubmission.from_dict(
		entry.get("submission", {}) as Dictionary)
	var defender_id: String = String(entry.get("defenderId", ""))

	var doctrine: Doctrine = null
	var rules: Array = entry.get("defenderDoctrine", []) as Array
	var stored_squad: Variant = entry.get("defenderSquad")
	var defender_rating: int = 0

	var tournament_id: String = String(entry.get("tournamentId", ""))
	var score: int = 0
	if not tournament_id.is_empty():
		# Regenerated, not trusted. The challenge is a function of the tournament id and
		# its start time, so the worker can rebuild the exact squad the entrant claims to
		# have fought -- and reject anything else.
		var start_time: int = int(entry.get("tournamentStart", 0))
		stored_squad = Tournament.challenge_squad(tournament_id, start_time, _content)
		defender_id = ""

	var boss_id: String = String(entry.get("bossId", ""))
	if not boss_id.is_empty():
		# The colossus is authored content, so the worker rebuilds it from the same data
		# the player's client used -- exactly like a bot, and for the same reason: one
		# implementation of what the boss IS.
		var boss: Dictionary = _content.bosses.get(boss_id, {}) as Dictionary
		if not boss.is_empty():
			stored_squad = Colossus.build_specs(boss)
		defender_id = ""
	elif bool(entry.get("isBot", false)):
		if _bots == null:
			_bots = LocalPvpRepository.open(_content)
		var bot: PvpRepository.Defence = _bots.get_defence(defender_id)
		if bot != null:
			stored_squad = bot.squad
			rules = bot.doctrine_rules
			defender_rating = bot.rating

	# Empty means the default, exactly as it does on the client. Treating it as "no
	# doctrine" here is what made honest battles fail with a hash mismatch.
	doctrine = Doctrine.from_array_or_default(rules, "defender")

	var accepted: bool = false
	var verdict: String = ""
	var won: bool = false
	## Damage the re-run says the player dealt. A colossus attempt is scored on this, and
	## it comes from the simulation here rather than from anything the client sent.
	var damage: int = 0

	# Before re-running anything: was this fought against the squad the defender
	# actually published? A battle can be perfectly honest about its own rules and still
	# be a fiction, if the opponent in it never existed.
	if stored_squad == null:
		verdict = "NO_DEFENCE"
	elif not _same_squad(submission.setup.specs_for(SimDefs.TEAM_B), stored_squad as Array):
		verdict = "DEFENCE_MISMATCH"
	else:
		var report: BattleVerifier.Report = BattleVerifier.verify(
			submission, _content.to_sim_content(), _content.balance, doctrine,
			_content.content_version())
		accepted = report.accepted()
		verdict = report.verdict_name()
		won = report.actual_winner == SimDefs.TEAM_A
		damage = report.damage_dealt
		score = Tournament.score_of(report.result, _content.balance)

	var response: Dictionary = http.rpc_as_server(http_key, "worker_verdict", {
		"matchId": String(entry.get("matchId", "")),
		"submitter": String(entry.get("submitter", "")),
		"accepted": accepted, "verdict": verdict,
		"defenderId": defender_id, "won": won, "defenderRating": defender_rating,
		"bossId": boss_id, "damage": damage,
		"tournamentId": tournament_id, "score": score,
	})
	if not tournament_id.is_empty():
		print("  %s  %s  %s" % [
			String(entry.get("matchId", "")).substr(0, 8), verdict,
			"score %d" % int(response.get("score", 0)) if accepted else "no score"])
		return
	if not boss_id.is_empty():
		print("  %s  %s  %s" % [
			String(entry.get("matchId", "")).substr(0, 8), verdict,
			"boss damage %d" % int(response.get("damage", 0)) if accepted else "no damage"])
		return
	print("  %s  %s  %s" % [
		String(entry.get("matchId", "")).substr(0, 8),
		verdict,
		"delta %d" % int(response.get("delta", 0)) if accepted else "no change"])


## Compares the submitted enemy squad against the stored one. Only the build matters --
## names are cosmetic and power is a stat the server already knows.
func _same_squad(submitted: Array, stored: Array) -> bool:
	if submitted.size() != stored.size():
		return false
	for index: int in submitted.size():
		var a: Dictionary = submitted[index] as Dictionary
		var b: Dictionary = stored[index] as Dictionary
		if int(a.get("power", 100)) != int(b.get("power", 100)):
			return false
		var parts_a: Dictionary = a.get("parts", {}) as Dictionary
		var parts_b: Dictionary = b.get("parts", {}) as Dictionary
		var slots: Array = parts_a.keys()
		slots.sort()
		var other: Array = parts_b.keys()
		other.sort()
		if slots != other:
			return false
		for slot: Variant in slots:
			if String(parts_a[slot]) != String(parts_b[slot]):
				return false
	return true


func _verify_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "not found", "path": path}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"error": "bad json", "path": path}
	if not (json.data is Dictionary):
		return {"error": "expected an object", "path": path}

	var envelope: Dictionary = json.data
	var submission: BattleSubmission = BattleSubmission.from_dict(
		envelope.get("submission", envelope) as Dictionary)

	# The defender's doctrine comes from the envelope the SERVER built, never from the
	# submitting client. An attacker who could choose their opponent's doctrine could
	# hand them one that does nothing.
	var doctrine: Doctrine = null
	if envelope.has("defender_doctrine"):
		var rules: Array = envelope["defender_doctrine"]
		if not rules.is_empty():
			doctrine = Doctrine.from_array(rules, "defender")

	var report: BattleVerifier.Report = BattleVerifier.verify(
		submission, _content.to_sim_content(), _content.balance, doctrine)

	return {
		"accepted": report.accepted(),
		"verdict": report.verdict_name(),
		"claimed_hash": report.claimed_hash,
		"actual_hash": report.actual_hash,
		"actual_winner": report.actual_winner,
		"actual_cycles": report.actual_cycles,
		"elapsed_ms": report.elapsed_ms,
		"detail": report.detail,
		"context": submission.context,
	}


func _parse_args(args: PackedStringArray) -> Dictionary:
	var opts: Dictionary = {}
	var i: int = 0
	while i < args.size():
		if not args[i].begins_with("--"):
			i += 1
			continue
		var key: String = args[i].substr(2)
		if i + 1 < args.size() and not args[i + 1].begins_with("--"):
			opts[key] = args[i + 1]
			i += 2
		else:
			opts[key] = true
			i += 1
	return opts
