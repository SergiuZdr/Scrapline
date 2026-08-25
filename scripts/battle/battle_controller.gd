class_name BattleController
extends RefCounted

## Drives an interactive battle: Order Phase, resolve, repeat.
##
## It owns the order log and nothing else. Every time the player commits a cycle it
## re-runs the whole simulation from tick 0 with the orders known so far, then hands
## the presentation layer only the events it has not seen. Because the event stream
## is prefix-stable, replaying from scratch is safe and costs about 30 ms -- which is
## why live play, replays, and the server's anti-cheat check can all share one code
## path instead of three that drift apart.

signal cycle_resolved(new_events: Array)
signal battle_finished(result: BattleResult)

var setup: BattleSetup = null
var content: Dictionary = {}
var balance: Balance = null
var doctrines: Array = []

## order_log[cycle] maps unit_ref -> chain (or the string "auto").
var order_log: Array = []
var result: BattleResult = null

var player_team: int = SimDefs.TEAM_A
var cycle: int = 0
var _events_played: int = 0


func start(setup_in: BattleSetup, content_in: Dictionary, balance_in: Balance, doctrines_in: Array = []) -> void:
	setup = setup_in
	content = content_in
	balance = balance_in
	doctrines = doctrines_in
	order_log = []
	cycle = 0
	_events_played = 0
	# Cycle 0 has not been ordered yet, so this run resolves nothing. It exists to
	# build the roster the Order Phase panel is about to display.
	result = BattleSim.simulate(setup, order_log, content, balance, doctrines, 0)


## The squads as freshly assembled, before a shot is fired.
func starting_units() -> Array[SimUnit]:
	return UnitBuilder.build_squads(setup, content, balance, battlefield())


## The map this battle is fought on. Built the same way the simulation builds it, so
## the 3D view and the sim can never disagree about where the terrain is.
func battlefield() -> Battlefield:
	return BattleSim.build_field(setup, content)


## Commits the player's orders for the current cycle and resolves it.
## `orders` maps unit_ref -> Array of action codes, or the string "auto".
func commit_cycle(orders: Dictionary) -> void:
	if is_finished():
		return

	while order_log.size() <= cycle:
		order_log.append({})
	order_log[cycle] = orders.duplicate()

	cycle += 1
	result = BattleSim.simulate(setup, order_log, content, balance, doctrines, cycle)

	var new_events: Array = []
	var all: Array = result.events.events
	for i: int in range(_events_played, all.size()):
		new_events.append(all[i])
	_events_played = all.size()

	cycle_resolved.emit(new_events)
	if result.concluded:
		battle_finished.emit(result)


func is_finished() -> bool:
	return result != null and result.concluded


## The state of every unit at the end of what has been resolved so far. Rebuilt by
## replaying rather than cached, so it can never drift from the simulation.
func current_units() -> Array[SimUnit]:
	var sim := BattleSim.new()
	sim._cycle_limit = cycle
	sim._run(setup, order_log, content, balance, doctrines)
	return sim.units


func player_units(units: Array[SimUnit]) -> Array[SimUnit]:
	var out: Array[SimUnit] = []
	for u: SimUnit in units:
		if u.team == player_team:
			out.append(u)
	return out


## Ticks of simulated time in one cycle -- what the presentation layer needs to know
## to play the new events back at the right pace.
func cycle_tick_span() -> int:
	return balance.cycle_ticks
