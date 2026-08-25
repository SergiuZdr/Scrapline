extends SceneTree

## Anti-cheat tests: forge a battle result every way a client could, and prove the
## verifier rejects each one.
##
## This is the payoff for every constraint `sim/` has been held to since the first
## commit — integer maths, a seeded PRNG, fixed iteration order, no engine RNG. All of
## it exists so a server can recompute a player's battle and get the same answer.
##
## A test suite that only checks the happy path proves nothing here. The interesting
## question is not "does an honest submission pass" — it is "does every dishonest one
## fail", and the ways to lie are enumerable: claim a different winner, claim fewer
## cycles, swap in a stronger squad, edit the seed, doctor the orders, or forge the hash
## while leaving the inputs honest.
##
##   godot --headless --path . --script res://tools/verify_anticheat.gd

var _passed: int = 0
var _failed: int = 0
var _content: ContentDB
var _sim_content: Dictionary


func _initialize() -> void:
	_content = ContentDB.load_all()
	if not _content.errors.is_empty():
		for e: String in _content.errors:
			printerr("content: ", e)
		quit(1)
		return
	_sim_content = _content.to_sim_content()

	print("")
	print("=== anti-cheat: can a forged battle get through? ===")

	_test_honest_submission_passes()
	_test_forged_winner_rejected()
	_test_forged_cycles_rejected()
	_test_forged_hash_rejected()
	_test_swapped_squad_rejected()
	_test_edited_seed_rejected()
	_test_doctored_orders_rejected()
	_test_upgraded_parts_rejected()
	_test_wrong_format_rejected()
	_test_payload_is_small()
	_test_serialisation_round_trip()

	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	print("")
	quit(1 if _failed > 0 else 0)


# --- The honest case ---------------------------------------------------------

func _honest() -> Dictionary:
	var attacker: Array = [
		_spec("A1", "ch_brute", "co_mag", "ar_ripper", "ar_ripper", "mo_servo"),
		_spec("A2", "ch_hauler", "co_slug", "ar_hammer", "ar_hammer", "mo_ablative"),
		_spec("A3", "ch_lancer", "co_arc", "ar_lance", "ar_scanner", "mo_targeting"),
		_spec("A4", "ch_skirmisher", "co_dynamo", "ar_pulse", "ar_ripper", "mo_governor"),
	]
	var defender: Array = [
		_spec("D1", "ch_dredge", "co_bile", "ar_saw", "ar_maul", "mo_reactive"),
		_spec("D2", "ch_bulwark", "co_furnace", "ar_hammer", "ar_hammer", "mo_coolant"),
		_spec("D3", "ch_strider", "co_tesla", "ar_railgun", "ar_railgun", "mo_capacitor"),
		_spec("D4", "ch_courier", "co_null", "ar_scatter", "ar_pulse", "mo_scavenger"),
	]
	var setup: BattleSetup = BattleSetup.make(20260810, attacker, defender, "cond_ashfall", "map_foundry_yard")
	var orders: Array = [
		{0: ["ability:0", "attack"], 2: ["advance", "attack"]},
		{1: ["brace", "attack"], 3: ["ability:1", "attack"]},
		{},
		{0: ["vent", "ability:0"]},
	]
	var result: BattleResult = BattleSim.simulate(setup, orders, _sim_content, _content.balance)
	return {"setup": setup, "orders": orders, "result": result}


func _test_honest_submission_passes() -> void:
	var h: Dictionary = _honest()
	var submission: BattleSubmission = BattleSubmission.from_result(
		h["setup"], h["orders"], h["result"], "pvp:test")
	var report: BattleVerifier.Report = BattleVerifier.verify(submission, _sim_content, _content.balance)
	_check("an honest submission is accepted", report.accepted())
	_check("verification is fast enough to run per match (%d ms)" % report.elapsed_ms,
		report.elapsed_ms < 400)


# --- Every way to lie --------------------------------------------------------

## The obvious cheat: lose the fight, report a win.
func _test_forged_winner_rejected() -> void:
	var h: Dictionary = _honest()
	var submission: BattleSubmission = BattleSubmission.from_result(h["setup"], h["orders"], h["result"])
	submission.claimed_winner = 1 - (h["result"] as BattleResult).winner
	var report: BattleVerifier.Report = BattleVerifier.verify(submission, _sim_content, _content.balance)
	_check("a flipped winner is rejected", not report.accepted())
	_check("  and the reason names the winner", report.verdict == BattleVerifier.Verdict.WINNER_MISMATCH)


## Subtler: same winner, claim a faster clear to farm a time-based reward.
func _test_forged_cycles_rejected() -> void:
	var h: Dictionary = _honest()
	var submission: BattleSubmission = BattleSubmission.from_result(h["setup"], h["orders"], h["result"])
	submission.claimed_cycles = 1
	var report: BattleVerifier.Report = BattleVerifier.verify(submission, _sim_content, _content.balance)
	_check("a shortened battle is rejected", not report.accepted())
	_check("  and the reason names the length", report.verdict == BattleVerifier.Verdict.CYCLES_MISMATCH)


## Forging only the hash, leaving inputs honest, is the cheat a naive server misses.
func _test_forged_hash_rejected() -> void:
	var h: Dictionary = _honest()
	var submission: BattleSubmission = BattleSubmission.from_result(h["setup"], h["orders"], h["result"])
	submission.claimed_hash = "deadbeef"
	var report: BattleVerifier.Report = BattleVerifier.verify(submission, _sim_content, _content.balance)
	_check("a forged hash is rejected", not report.accepted())
	_check("  and it is caught as a stream mismatch",
		report.verdict == BattleVerifier.Verdict.HASH_MISMATCH)


## The valuable cheat: fight with a stronger squad than you own, report the real result.
## Rejected here because the hash will not match what the honest inputs produce -- and
## in production the server also rebuilds the squad from the roster it stores.
func _test_swapped_squad_rejected() -> void:
	var h: Dictionary = _honest()
	var submission: BattleSubmission = BattleSubmission.from_result(h["setup"], h["orders"], h["result"])
	var boosted: Array = (submission.setup.specs_for(0) as Array).duplicate(true)
	for spec: Variant in boosted:
		(spec as Dictionary)["power"] = 400
	submission.setup.team_specs[0] = boosted
	var report: BattleVerifier.Report = BattleVerifier.verify(submission, _sim_content, _content.balance)
	_check("a boosted squad is rejected", not report.accepted())


func _test_edited_seed_rejected() -> void:
	var h: Dictionary = _honest()
	var submission: BattleSubmission = BattleSubmission.from_result(h["setup"], h["orders"], h["result"])
	submission.setup.seed_value += 1
	var report: BattleVerifier.Report = BattleVerifier.verify(submission, _sim_content, _content.balance)
	_check("re-rolling the seed is rejected", not report.accepted())


## Replaying a lost battle with better orders and the original result.
func _test_doctored_orders_rejected() -> void:
	var h: Dictionary = _honest()
	var submission: BattleSubmission = BattleSubmission.from_result(h["setup"], h["orders"], h["result"])
	submission.order_log = [
		{0: ["ability:0", "ability:1"], 1: ["ability:0", "attack"],
		 2: ["ability:0", "attack"], 3: ["ability:0", "attack"]},
	]
	var report: BattleVerifier.Report = BattleVerifier.verify(submission, _sim_content, _content.balance)
	_check("rewritten orders are rejected", not report.accepted())


## Claiming higher part levels than the roster grants.
func _test_upgraded_parts_rejected() -> void:
	var h: Dictionary = _honest()
	var submission: BattleSubmission = BattleSubmission.from_result(h["setup"], h["orders"], h["result"])
	var specs: Array = (submission.setup.specs_for(0) as Array).duplicate(true)
	(specs[0] as Dictionary)["parts"]["chassis"] = "ch_citadel"
	submission.setup.team_specs[0] = specs
	var report: BattleVerifier.Report = BattleVerifier.verify(submission, _sim_content, _content.balance)
	_check("swapping in a part you may not own is rejected", not report.accepted())


func _test_wrong_format_rejected() -> void:
	var h: Dictionary = _honest()
	var submission: BattleSubmission = BattleSubmission.from_result(h["setup"], h["orders"], h["result"])
	submission.format = BattleSubmission.FORMAT_VERSION + 7
	var report: BattleVerifier.Report = BattleVerifier.verify(submission, _sim_content, _content.balance)
	_check("a payload this server cannot verify is refused, not guessed at",
		report.verdict == BattleVerifier.Verdict.BAD_FORMAT)


## The payload carries ORDERS, not events. If it ever starts carrying the event stream
## instead, submissions become tens of kilobytes and the design has quietly regressed.
func _test_payload_is_small() -> void:
	var h: Dictionary = _honest()
	var submission: BattleSubmission = BattleSubmission.from_result(h["setup"], h["orders"], h["result"])
	var bytes: int = submission.size_bytes()
	var events: int = (h["result"] as BattleResult).events.size()
	_check("a submission is small (%d bytes for a %d-event battle)" % [bytes, events], bytes < 6000)


func _test_serialisation_round_trip() -> void:
	var h: Dictionary = _honest()
	var original: BattleSubmission = BattleSubmission.from_result(
		h["setup"], h["orders"], h["result"], "pvp:round-trip")
	var json: String = JSON.stringify(original.to_dict())
	var parsed := JSON.new()
	parsed.parse(json)
	var restored: BattleSubmission = BattleSubmission.from_dict(parsed.data as Dictionary)

	var report: BattleVerifier.Report = BattleVerifier.verify(restored, _sim_content, _content.balance)
	_check("a submission survives a JSON round trip and still verifies", report.accepted())
	_check("  context is preserved", restored.context == "pvp:round-trip")


# --- Harness -----------------------------------------------------------------

func _spec(name: String, ch: String, co: String, al: String, ar: String, mo: String) -> Dictionary:
	return {"name": name, "parts": {
		"chassis": ch, "core": co, "arm_l": al, "arm_r": ar, "module": mo}}


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		printerr("  FAIL  %s" % label)
