class_name BattleSubmission
extends RefCounted

## What a client sends when it claims to have won a battle.
##
## This is the anti-cheat contract, and it is deliberately tiny: the setup, the seed,
## and the orders the player gave. **The result is not trusted and barely matters** —
## the server re-runs the simulation from these three things and computes the outcome
## itself. A client that lies about its result is caught because the honest inputs it
## must also send do not produce the outcome it claimed.
##
## Every rule in `sim/` exists to make this work. Integer maths, a seeded PRNG, fixed
## iteration order and no engine RNG are all in service of one property: the server's
## re-run must produce a byte-identical event stream, or an honest player gets rejected.
##
## The payload is small — orders, not events. A twelve-cycle battle is a few hundred
## bytes, so submitting one costs nothing even on a bad connection.

## Bumped when the payload shape changes, so a server can refuse a client it cannot
## verify rather than silently mis-scoring it.
const FORMAT_VERSION: int = 2

var format: int = FORMAT_VERSION
## Hash of the content this battle was fought under (see `ContentDB.content_version`).
## A server on different content cannot verify it, and must say so rather than treat the
## difference as a lie -- a player mid-session when a balance patch ships is not a cheat.
var content_version: String = ""
var setup: BattleSetup = null
var order_log: Array = []
## What the client says happened. Compared against the re-run; never believed.
var claimed_winner: int = BattleResult.WINNER_DRAW
var claimed_cycles: int = 0
var claimed_hash: String = ""
## Identifies the fight this settles: a campaign node, a gauntlet floor, a PvP defender.
var context: String = ""
var submitted_at: int = 0


static func from_result(
	setup_in: BattleSetup, order_log_in: Array, result: BattleResult, context_in: String = "",
	content_version_in: String = ""
) -> BattleSubmission:
	var s := BattleSubmission.new()
	s.content_version = content_version_in
	s.setup = setup_in
	s.order_log = order_log_in.duplicate(true)
	s.claimed_winner = result.winner
	s.claimed_cycles = result.cycles
	s.claimed_hash = result.hash_hex()
	s.context = context_in
	s.submitted_at = int(Time.get_unix_time_from_system())
	return s


func to_dict() -> Dictionary:
	return {
		"format": format,
		"setup": setup.to_dict(),
		# Order-log keys are ints; JSON turns them into strings on the way out, so the
		# reader converts them back rather than trusting the round trip.
		"orders": _orders_to_json(),
		"claimed": {
			"winner": claimed_winner,
			"cycles": claimed_cycles,
			"hash": claimed_hash,
		},
		"context": context,
		"content": content_version,
		"at": submitted_at,
	}


static func from_dict(d: Dictionary) -> BattleSubmission:
	var s := BattleSubmission.new()
	s.format = int(d.get("format", 0))
	s.setup = BattleSetup.from_dict(d.get("setup", {}) as Dictionary)
	s.order_log = _orders_from_json(d.get("orders", []) as Array)
	var claimed: Dictionary = d.get("claimed", {})
	s.claimed_winner = int(claimed.get("winner", BattleResult.WINNER_DRAW))
	s.claimed_cycles = int(claimed.get("cycles", 0))
	s.claimed_hash = String(claimed.get("hash", ""))
	s.context = String(d.get("context", ""))
	s.content_version = String(d.get("content", ""))
	s.submitted_at = int(d.get("at", 0))
	return s


func _orders_to_json() -> Array:
	var out: Array = []
	for entry: Variant in order_log:
		var converted: Dictionary = {}
		if entry is Dictionary:
			for key: Variant in (entry as Dictionary).keys():
				converted[str(key)] = (entry as Dictionary)[key]
		out.append(converted)
	return out


static func _orders_from_json(raw: Array) -> Array:
	var out: Array = []
	for entry: Variant in raw:
		var converted: Dictionary = {}
		if entry is Dictionary:
			for key: Variant in (entry as Dictionary).keys():
				converted[String(key).to_int()] = (entry as Dictionary)[key]
		out.append(converted)
	return out


func size_bytes() -> int:
	return JSON.stringify(to_dict()).to_utf8_buffer().size()
