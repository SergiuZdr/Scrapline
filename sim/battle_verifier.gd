class_name BattleVerifier
extends RefCounted

## Re-runs a submitted battle and decides whether to believe it.
##
## This is the anti-cheat, and it is the reason `sim/` has been held to integer maths,
## a seeded PRNG and fixed iteration order since the first commit. The server does not
## inspect the client's claim for plausibility — it **recomputes the entire battle** from
## the setup, seed and order log and compares event-stream hashes. A forged result
## cannot survive that, because producing a matching hash would require producing a real
## battle that genuinely ends the way the cheater claimed.
##
## Runs identically on a player's device and on a headless Linux server. That is the
## whole point: the same code path, so there is nothing to keep in sync.
##
## What this does NOT protect against, stated plainly so nobody assumes otherwise:
##
##   - **A player submitting a battle they could legitimately have fought but did not.**
##     Verification proves the battle is real, not that the player played it. An
##     auto-clicker submitting genuine wins is a rate-limiting problem, not a
##     verification one.
##   - **A doctored client that plays perfectly.** The orders are legal; a bot just
##     picks good ones. That is a behavioural-detection problem.
##   - **A tampered local save.** Cloud-authoritative profile state is what covers that,
##     which is why the roster lives on the server in Phase 4.

enum Verdict {
	OK,                 ## re-run matches the claim exactly
	HASH_MISMATCH,      ## the battle did not play out the way the client said
	WINNER_MISMATCH,    ## the re-run produced a different winner
	CYCLES_MISMATCH,    ## same winner, different length -- still a forged log
	BAD_FORMAT,         ## payload from a client version this server cannot verify
	CONTENT_MISMATCH,   ## fought under different balance data -- not a lie, a mismatch
	MALFORMED,          ## unusable setup or orders
}


class Report extends RefCounted:
	var verdict: int = Verdict.MALFORMED
	var actual_winner: int = BattleResult.WINNER_DRAW
	var actual_cycles: int = 0
	var actual_hash: String = ""
	## Damage the attacking team dealt in the re-run. The colossus is scored on this, so
	## it must come from here and never from the submission.
	var damage_dealt: int = 0
	## The re-run itself. Held so a caller that needs more than a verdict -- a tournament
	## score, say -- reads it from here rather than simulating the same battle again.
	var result: BattleResult = null
	var claimed_hash: String = ""
	var elapsed_ms: int = 0
	var detail: String = ""

	func accepted() -> bool:
		return verdict == Verdict.OK

	func verdict_name() -> String:
		match verdict:
			Verdict.OK: return "accepted"
			Verdict.HASH_MISMATCH: return "rejected: event stream differs"
			Verdict.WINNER_MISMATCH: return "rejected: winner differs"
			Verdict.CYCLES_MISMATCH: return "rejected: length differs"
			Verdict.BAD_FORMAT: return "rejected: unsupported payload version"
			Verdict.CONTENT_MISMATCH: return "rejected: different content version"
			Verdict.MALFORMED: return "rejected: malformed payload"
		return "rejected"

	func summary() -> String:
		return "%s  (claimed %s / actual %s, %d ms)%s" % [
			verdict_name(), claimed_hash, actual_hash, elapsed_ms,
			"  " + detail if not detail.is_empty() else ""]


## Verifies one submission. `defender_doctrine` is supplied by the server from the
## defending player's stored profile -- never from the attacker's payload, or an
## attacker could hand their opponent a deliberately useless doctrine.
static func verify(
	submission: BattleSubmission,
	content: Dictionary,
	balance: Balance,
	defender_doctrine: Doctrine = null,
	content_version: String = ""
) -> Report:
	var report := Report.new()
	report.claimed_hash = submission.claimed_hash

	if submission.format != BattleSubmission.FORMAT_VERSION:
		report.verdict = Verdict.BAD_FORMAT
		report.detail = "payload format %d, server verifies %d" % [
			submission.format, BattleSubmission.FORMAT_VERSION]
		return report

	# Before anything else, and before the simulation runs at all: were both sides
	# playing the same game? A balance patch lands while somebody is mid-battle, and
	# their honest submission then replays differently here. That is not cheating, and
	# calling it cheating is how a live-ops patch turns into a wave of false positives.
	# Empty means the caller opted out of the check, which is what the offline tools do.
	if not content_version.is_empty() and submission.content_version != content_version:
		report.verdict = Verdict.CONTENT_MISMATCH
		report.detail = "submitted on content %s, server runs %s" % [
			submission.content_version if not submission.content_version.is_empty() else "(none)",
			content_version]
		return report

	if submission.setup == null or submission.setup.specs_for(0).is_empty():
		report.verdict = Verdict.MALFORMED
		report.detail = "no attacking squad"
		return report

	var started: int = Time.get_ticks_msec()
	var doctrines: Array = [null, defender_doctrine]
	var result: BattleResult = BattleSim.simulate(
		submission.setup, submission.order_log, content, balance, doctrines)
	report.elapsed_ms = Time.get_ticks_msec() - started

	report.actual_winner = result.winner
	report.actual_cycles = result.cycles
	report.actual_hash = result.hash_hex()
	report.damage_dealt = result.damage_dealt[SimDefs.TEAM_A]
	report.result = result

	# Every claim is checked against the re-run, and the ORDER matters. Checking the
	# hash first and returning early let a client send honest inputs while lying about
	# the winner: the hash matched, so the submission was accepted with a false claim
	# attached. A caller that then trusted `claimed_winner` would score it wrong.
	#
	# The recomputed result is the truth. Any disagreement means the client lied, even
	# when the inputs it also sent were genuine.
	if report.actual_winner != submission.claimed_winner:
		report.verdict = Verdict.WINNER_MISMATCH
		report.detail = "claimed %d, actually %d" % [submission.claimed_winner, report.actual_winner]
		return report

	if report.actual_cycles != submission.claimed_cycles:
		report.verdict = Verdict.CYCLES_MISMATCH
		report.detail = "claimed %d cycles, actually %d" % [submission.claimed_cycles, report.actual_cycles]
		return report

	if report.actual_hash != submission.claimed_hash:
		report.verdict = Verdict.HASH_MISMATCH
		report.detail = "inputs replay to a different battle"
		return report

	report.verdict = Verdict.OK
	return report


## Convenience for the offline path: verify a battle the client just fought against
## itself. Catches determinism regressions during development, where a real desync
## would otherwise only surface once players were online.
static func self_check(
	setup: BattleSetup, order_log: Array, result: BattleResult,
	content: Dictionary, balance: Balance
) -> bool:
	var submission: BattleSubmission = BattleSubmission.from_result(setup, order_log, result)
	return verify(submission, content, balance).accepted()
