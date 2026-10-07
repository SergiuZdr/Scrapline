class_name CombatState
extends RefCounted

## The whole state of one fight. Built fresh by `CombatSim.start`, changed only by
## `CombatSim.apply`. Cells are hex offsets (see `Hex`).

const ONGOING: int = 0
const WON: int = 1
const LOST: int = 2

var setup: CombatSetup
var width: int = 0
var height: int = 0
## Sorted by ref, always. Destroyed units stay in the list (alive = false) but no longer
## occupy their hex: they became a scrap pile.
var units: Array[GridUnit] = []
var round_number: int = 0
var outcome: int = ONGOING
## Enemy intents for the current round, in firing order:
## `{ "ref": int, "w": weapon index, "x": int, "y": int, "order": int }` -- the hex it will hit.
var intents: Array[Dictionary] = []
## Scrap piles on the board: `Vector2i -> scrap value`.
var piles: Dictionary = {}
## Objects: `Vector2i -> { "kind": "barrel"|"crate", "hp": int }`. They block movement and
## shots, take damage, and a barrel explodes when it breaks.
var props: Dictionary = {}
## A hive's fabricator pad, set down once and never moved: `hive ref -> Vector2i`.
var spawn_marks: Dictionary = {}
## Hive ref -> the round its pad builds the next drone.
var spawn_due: Dictionary = {}
## Where the Reclaimer's drones will come in next round (013), marked a round ahead.
var arrivals: Array = []
## The Pour (021): hexes marked to flood at the start of the next enemy phase, and the hexes
## already flooded (`Vector2i -> hazard`). Both copied by `clone()`.
var pour_marks: Array = []
var flooded: Dictionary = {}
## The Core (025): the ring it pulses at the start of the next round, and which unit marked it.
var pulse_marks: Array = []
var pulse_by: int = -1
## Keepers past half HP (027): ref -> true; and guards they called, arriving next round.
var enraged: Dictionary = {}
var summons: Dictionary = {}
## 028: HOLD's score, HACK's taken terminals, SURVIVE's next wave (hexes marked a round ahead).
var hold_score: int = 0
## 047: mines on the board, `{ Vector2i: damage }`. Each goes off once, on whatever starts a
## round on it.
var mines: Dictionary = {}
var hacked: Array = []
var wave_marks: Array = []
## What the player has collected this fight.
var piles_collected: int = 0
var scrap_collected: int = 0
## Every event since the fight began. See `GridEv`.
## 050 (boss tricks): keepers open to a heavy blow -- ref -> the crew's turns left (they take
## `exposed_pct` and none of their pylon / conduit / twin cover).
var exposed: Dictionary = {}
## 050: the Grinder's charge, marked a round ahead: ref -> {"dir": int, "cells": Array}.
var charges: Dictionary = {}
## 050: the Sorter's claw, marked a round ahead: keeper ref -> the machine it will throw.
var grabs: Dictionary = {}
## 050: the Core's open side: ref -> hex direction 0..5.
var facing: Dictionary = {}
## 050: a fallen twin being rebuilt: its ref -> rounds left.
var rebuilds: Dictionary = {}

var events: Array = []
var action_count: int = 0


func emit(kind: int, actor: int = -1, target: int = -1, x: int = -1, y: int = -1,
		v1: int = 0, v2: int = 0) -> void:
	events.append([kind, actor, target, x, y, v1, v2])


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func inside(c: Vector2i) -> bool:
	return in_bounds(c.x, c.y)


func tile_blocks(x: int, y: int) -> bool:
	return setup.blocks[y * width + x] == 1


func tile_at(x: int, y: int) -> int:
	return setup.tiles[y * width + x]


func move_cost(x: int, y: int) -> int:
	return setup.move_cost[y * width + x]


func cover(x: int, y: int) -> int:
	return setup.cover[y * width + x]


func range_bonus(x: int, y: int) -> int:
	return setup.range_bonus[y * width + x]


func hazard(x: int, y: int) -> int:
	# 047: a mine counts as a hazard for everything that weighs one -- the AI's steps, the
	# board's incoming totals. It is set off by `CombatSim._round_hazards`, not as ground.
	return maxi(ground_hazard(x, y), int(mines.get(Vector2i(x, y), 0)))


## What the ground itself does to whatever starts a round on (x, y): slag, flooded hexes.
func ground_hazard(x: int, y: int) -> int:
	var base: int = setup.hazard[y * width + x]
	# A hex The Pour flooded (021) is slag for the rest of the fight.
	return maxi(base, int(flooded.get(Vector2i(x, y), 0)))


## A furnace flue's blast on (x, y), or 0 (025).
func flue(x: int, y: int) -> int:
	return setup.flue[y * width + x] if not setup.flue.is_empty() else 0


func is_pit(c: Vector2i) -> bool:
	return setup.pit[c.y * width + c.x] == 1


## Anything that stops a shot or a walker on this hex that is not a unit: scrap or a prop.
func solid(c: Vector2i) -> bool:
	return tile_blocks(c.x, c.y) or props.has(c)


func unit(ref: int) -> GridUnit:
	for u: GridUnit in units:
		if u.ref == ref:
			return u
	return null


## The LIVING unit on (x, y), or null. The dead are scrap piles, not obstacles.
func unit_at(x: int, y: int) -> GridUnit:
	for u: GridUnit in units:
		if u.alive and u.x == x and u.y == y:
			return u
	return null


func living(team: int) -> Array[GridUnit]:
	var out: Array[GridUnit] = []
	for u: GridUnit in units:
		if u.alive and u.team == team:
			out.append(u)
	return out


## Living fighters of a team, without caches.
func crew(team: int) -> Array[GridUnit]:
	var out: Array[GridUnit] = []
	for u: GridUnit in units:
		if u.alive and u.team == team and not u.objective:
			out.append(u)
	return out


## Salvage caches still standing (the defend objective).
func caches() -> Array[GridUnit]:
	var out: Array[GridUnit] = []
	for u: GridUnit in units:
		if u.alive and u.objective:
			out.append(u)
	return out


func objective() -> Dictionary:
	return setup.objective


func intent_of(ref: int) -> Dictionary:
	for intent: Dictionary in intents:
		if int(intent["ref"]) == ref:
			return intent
	return {}


## Piles in a fixed order (row, then column), since a Dictionary's order is not a rule.
func pile_cells() -> Array:
	var cells: Array = piles.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return cells


## A copy to try something on: the dry-run preview executes a real attack or ability here
## and reports what changed. Everything the rules touch is copied; the event log starts
## empty so the preview reads only what it caused.
func clone() -> CombatState:
	var c := CombatState.new()
	c.setup = setup
	c.width = width
	c.height = height
	for u: GridUnit in units:
		c.units.append(u.copy())
	c.round_number = round_number
	c.outcome = outcome
	for intent: Dictionary in intents:
		c.intents.append(intent.duplicate())
	c.piles = piles.duplicate()
	c.props = props.duplicate(true)
	c.spawn_marks = spawn_marks.duplicate()
	c.spawn_due = spawn_due.duplicate()
	c.arrivals = arrivals.duplicate()
	c.pour_marks = pour_marks.duplicate()
	c.flooded = flooded.duplicate()
	c.pulse_marks = pulse_marks.duplicate()
	c.pulse_by = pulse_by
	c.enraged = enraged.duplicate()
	c.hold_score = hold_score
	c.mines = mines.duplicate()
	c.hacked = hacked.duplicate()
	c.wave_marks = wave_marks.duplicate()
	c.summons = summons.duplicate()
	c.piles_collected = piles_collected
	c.scrap_collected = scrap_collected
	c.exposed = exposed.duplicate()
	c.charges = charges.duplicate(true)
	c.grabs = grabs.duplicate()
	c.facing = facing.duplicate()
	c.rebuilds = rebuilds.duplicate()
	return c


## A copy with its history (play-test 14): the scene keeps one from the start of each turn, so
## UNDO applies the turn's own actions to it instead of replaying the fight from round 1 (which
## took over a second by round 8). `verify_combat` plays every fight on from snapshots and
## requires the full fight's hash, so a field `clone` forgets fails there, not in someone's undo.
func snapshot() -> CombatState:
	var c: CombatState = clone()
	c.events = events.duplicate()
	c.action_count = action_count
	return c


## FNV-1a over the whole event stream. Two runs of the same fight with the same actions
## must produce the same value, on every machine.
func event_hash() -> String:
	var h: int = 0x811C9DC5
	for e: Array in events:
		for value: Variant in e:
			var v: int = int(value) & 0xFFFFFFFF
			for shift: int in [0, 8, 16, 24]:
				h = (h ^ ((v >> shift) & 0xFF)) & 0xFFFFFFFF
				h = (h * 16777619) & 0xFFFFFFFF
	return "%08x" % h
