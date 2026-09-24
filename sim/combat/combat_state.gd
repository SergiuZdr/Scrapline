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
## What the player has collected this fight.
var piles_collected: int = 0
var scrap_collected: int = 0
## Every event since the fight began. See `GridEv`.
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
	return setup.hazard[y * width + x]


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
