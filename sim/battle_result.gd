class_name BattleResult
extends RefCounted

## The outcome of one simulated battle.
##
## `events` is the authoritative record -- the presentation layer animates it and the
## server hashes it. Everything else here is a summary derived from it, kept because
## the balance simulator reads millions of these and should not have to re-walk the
## stream to answer "who won".

const WINNER_DRAW: int = -1

## False when the simulation stopped at an interactive cycle limit rather than at a
## real conclusion. `winner` is only meaningful once this is true.
var concluded: bool = true

var winner: int = WINNER_DRAW
var cycles: int = 0
var ticks: int = 0
var events: EventStream = null
var rng_draws: int = 0

## Per team, the units still standing when it ended.
var survivors: Array[int] = [0, 0]
## Per team, total damage dealt. The single most useful number for balance work.
var damage_dealt: Array[int] = [0, 0]

## End-of-battle snapshot of every unit, in build order. The post-battle screen reads
## this instead of re-walking the event stream, and the balance tool uses it to see
## which parts survive rather than only which team won.
var final_units: Array[Dictionary] = []


func stream_hash() -> int:
	return events.stream_hash() if events != null else 0


func hash_hex() -> String:
	return events.hash_hex() if events != null else "00000000"


func winner_name() -> String:
	match winner:
		SimDefs.TEAM_A: return "A"
		SimDefs.TEAM_B: return "B"
		_: return "draw"


func summary() -> String:
	return "winner=%s cycles=%d ticks=%d survivors=%d/%d damage=%d/%d events=%d rng=%d hash=%s" % [
		winner_name(), cycles, ticks,
		survivors[0], survivors[1],
		damage_dealt[0], damage_dealt[1],
		events.size() if events != null else 0,
		rng_draws,
		hash_hex(),
	]
