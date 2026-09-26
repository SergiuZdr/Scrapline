class_name RunState
extends RefCounted

## The whole state of one run. Built by `RunSim.start`, changed only by `RunSim.apply`.

const ONGOING: int = 0
const WON: int = 1
const LOST: int = 2

## `{ "id", "col", "row", "x", "y" (0..100), "type", "links": [ids], "visited": bool }`,
## indexed by id. Links are two-way: the region is a graph, not a one-way tree.
var sites: Array[Dictionary] = []
var current: int = 0
var moves: int = 0
## Columns at or below this are consumed by the Reclaimer.
var front_col: int = -1

var scrap: int = 0
## `{ "name", "parts": [chassis, core, arm_l, arm_r, module], "alive": bool, "hp": int, "level": int,
##    "perks": [perk ids, one per level] }`.
## "" is an empty socket. A wreck keeps only its chassis. HP carries from fight to fight:
## it is the run's health, now that there is no Crawler.
var crew: Array[Dictionary] = []
var cargo: Array[String] = []
## How many parts the hold takes. Salvage can push it over; travel then waits.
var hold_size: int = 8

## What the player must resolve before travelling on, or `{}`:
##   { "kind": "fight", "site_type", "fight": {fight dict} }
##   { "kind": "reward", "options": [part ids], "scrap": int }
##   { "kind": "scrapyard", "options": [part ids], "scrap": int }
##   { "kind": "workshop" }
##   { "kind": "trader", "stock": [part ids], "sold": [stock indices] }
##   { "kind": "tower", "scouted": int }
##   { "kind": "signal", "event": event id }
var pending: Dictionary = {}

var outcome: int = ONGOING
## Why the run ended, for the run-over screen.
var end_reason: String = ""
var fights_won: int = 0
## Whether the crew was built from the bench at the start (play-test 4). Once only.
var assembled: bool = false
## Sites a watchtower or a signal scouted (013), sorted.
var scouted: Array = []
## Signal events already met this run, so the next picks a fresh one.
var seen_events: Array = []
## Human-readable history, newest last. Deterministic like everything else.
var log: PackedStringArray = []


func site(id: int) -> Dictionary:
	return sites[id] if id >= 0 and id < sites.size() else {}


func consumed(id: int) -> bool:
	return int(site(id).get("col", 99)) <= front_col


func overfull() -> bool:
	return cargo.size() > hold_size


func alive_crew() -> int:
	var n: int = 0
	for member: Dictionary in crew:
		if bool(member["alive"]):
			n += 1
	return n


## A canonical string of everything that matters, for comparing two states.
func fingerprint() -> String:
	var crew_text: PackedStringArray = []
	for member: Dictionary in crew:
		crew_text.append("%s:%s:%s:%d:L%d:%s" % [member["name"], ",".join(member["parts"]), member["alive"], int(member["hp"]),
			int(member.get("level", 0)), ",".join(member.get("perks", []))])
	var visited: PackedStringArray = []
	for s: Dictionary in sites:
		visited.append("1" if bool(s["visited"]) else "0")
	return "cur=%d moves=%d front=%d scrap=%d hold=%d crew=[%s] cargo=[%s] visited=%s pending=%s outcome=%d built=%s scouted=%s events=%s" % [
		current, moves, front_col, scrap, hold_size, ";".join(crew_text),
		",".join(cargo), "".join(visited), str(pending.get("kind", "")), outcome, assembled, str(scouted), ",".join(PackedStringArray(seen_events))]
