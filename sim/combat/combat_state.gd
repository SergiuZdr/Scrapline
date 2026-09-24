class_name CombatState
extends RefCounted

## The whole state of one fight. Built fresh by `CombatSim.start`, changed only by
## `CombatSim.apply`.

const ONGOING: int = 0
const WON: int = 1
const LOST: int = 2

## Directions, in the order everything iterates them: north (toward row 0), east, south, west.
const DX: Array[int] = [0, 1, 0, -1]
const DY: Array[int] = [-1, 0, 1, 0]

var setup: CombatSetup
var width: int = 0
var height: int = 0
## Sorted by ref, always. Destroyed units stay in the list as wrecks.
var units: Array[GridUnit] = []
var round_number: int = 0
var outcome: int = ONGOING
## Enemy intents for the current round, in firing order:
## `{ "ref": int, "w": weapon index, "dir": int, "dist": int, "order": int }`.
var intents: Array[Dictionary] = []
## Every event since the fight began. See `GridEv`.
var events: Array = []
## Number of actions applied so far.
var action_count: int = 0


func emit(kind: int, actor: int = -1, target: int = -1, x: int = -1, y: int = -1,
		v1: int = 0, v2: int = 0) -> void:
	events.append([kind, actor, target, x, y, v1, v2])


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


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
	return setup.hazard[y * width + x]


func unit(ref: int) -> GridUnit:
	for u: GridUnit in units:
		if u.ref == ref:
			return u
	return null


## The unit or wreck standing on (x, y), or null.
func unit_at(x: int, y: int) -> GridUnit:
	for u: GridUnit in units:
		if u.x == x and u.y == y:
			return u
	return null


func living(team: int) -> Array[GridUnit]:
	var out: Array[GridUnit] = []
	for u: GridUnit in units:
		if u.alive and u.team == team:
			out.append(u)
	return out


## Living constructs of a team, without the Crawler.
func crew(team: int) -> Array[GridUnit]:
	var out: Array[GridUnit] = []
	for u: GridUnit in units:
		if u.alive and u.team == team and not u.objective:
			out.append(u)
	return out


func crawler() -> GridUnit:
	for u: GridUnit in units:
		if u.objective:
			return u
	return null


func intent_of(ref: int) -> Dictionary:
	for intent: Dictionary in intents:
		if int(intent["ref"]) == ref:
			return intent
	return {}


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
