class_name SimUnit
extends RefCounted

## One construct's runtime state inside a battle.
##
## Everything here is an integer. Values that represent a fraction are scaled by
## Balance.SCALE (100), so a 1.35x multiplier is stored as 135. No floats reach the
## simulation, because float accumulation drifts differently between macOS and Linux
## and the server has to reproduce a client's battle exactly.

var unit_ref: int = -1
var team: int = 0
var slot: int = 0
var display_name: String = ""   ## logs and UI only; never read by the resolvers

# Assembled from parts at setup time.
var hp: int = 0
var hp_max: int = 0
var attack: int = 0
var armor: int = 0
var speed: int = 100            ## percent; 200 means twice the attacks per cycle
var damage_type: int = SimDefs.DMG_KINETIC
var armor_type: int = SimDefs.ARM_PLATE
var abilities: Array[Dictionary] = []
var can_overdrive: bool = false
var part_ids: PackedStringArray = []

# --- Position and movement ---------------------------------------------------
#
# Fixed-point, in sim units (SimMath.UNIT per world metre). Never floats: the server
# re-simulates every submitted battle and has to agree on positions exactly.

var pos_x: int = 0
var pos_z: int = 0
var move_speed: int = 6         ## sim units per tick on open ground
var role: int = SimDefs.ROLE_LINE
## Percent damage reduction while this unit is still closing to its own reach.
## Set from the chassis; falls back to Balance.brawler_charge_reduction.
var charge_reduction: int = -1
var weapon_range: int = 400     ## the reach of this construct's best arm
var min_range: int = 0          ## marksmen back off inside this
## Where this unit last emitted a MOVED event, so the stream only carries meaningful
## movement rather than a position every tick.
var last_reported_x: int = 0
var last_reported_z: int = 0
var slot_home_x: int = 0        ## deployment anchor, used when falling back
var slot_home_z: int = 0
## The lateral corridor this construct advances down. Holding it while closing is
## what makes a squad arrive as a line instead of a column funnelling into one point.
var lane_x: int = 0

# Heat: the risk dial. Pushing hard fills it; at the top the unit either overdrives
# for a burst or seizes and loses time.
var heat: int = 0
var heat_max: int = 100
var heat_per_attack: int = 0
var vent_rate: int = 0          ## heat shed per second of simulated time
var overdrive_charged: bool = false  ## next offensive action is amplified

# Per-tick scheduling.
var attack_timer: int = 0       ## ticks until this unit's next auto-attack lands
var seize_ticks: int = 0        ## ticks remaining disabled; 0 means active
var last_action_kind: int = SimDefs.ACT_HOLD  ## previous link in the chain, for Linkage checks

# Per-cycle, cleared at every Order Phase.
## Colossus support. While ANY unit listed here is alive, this one takes
## `guarded_reduction` percent less damage. It is what turns a boss from a big health
## bar into a target-priority puzzle: break the limbs, or waste every shot on the core.
var guard_refs: PackedInt32Array = PackedInt32Array()
var guarded_reduction: int = 0
## A unit whose destruction ends the battle for its whole team, however much of the rest
## of that team is still standing.
var is_vital: bool = false

var brace_pct: int = 0
var chain: Array[int] = []
var chain_index: int = 0

## Standing orders. A unit repeats `standing_chain` every cycle until the player
## changes it; a unit `on_auto` is played by its team's doctrine instead. Without
## this, six units times three actions times eight cycles is roughly 150 taps per
## battle, which is unplayable on a phone. With it, a typical cycle costs 0-3 taps.
##
## Units start on Auto, so a player who never opens the order panel still fights.
var standing_chain: Array[int] = []
var on_auto: bool = true

## Remaining duration in ticks for each state, indexed by SimDefs.STATE_*.
## A fixed-length array rather than a Dictionary, so iteration order can never vary.
var states: PackedInt32Array = PackedInt32Array()

var alive: bool = true


func _init() -> void:
	states.resize(SimDefs.STATE_COUNT)
	states.fill(0)


func row() -> int:
	return SimDefs.row_of_slot(slot)


func has_state(state: int) -> bool:
	return states[state] > 0


func apply_state(state: int, ticks: int) -> void:
	# Refresh rather than stack: the longer of the two durations wins. Stacking
	# durations is how a debuff becomes permanent and a control build becomes
	# unbeatable.
	if ticks > states[state]:
		states[state] = ticks


func clear_state(state: int) -> void:
	states[state] = 0


## The ability at a chain argument index, or an empty Dictionary if the unit's parts
## do not grant one there. Ordering an ability a unit does not have is a no-op rather
## than an error -- a stale standing order must never desync a battle.
func ability_at(index: int) -> Dictionary:
	if index < 0 or index >= abilities.size():
		return {}
	return abilities[index]


func is_active() -> bool:
	return alive and seize_ticks <= 0


func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	if hp == 0:
		alive = false


func add_heat(amount: int) -> void:
	heat = clampi(heat + amount, 0, heat_max)


## Called at every Order Phase boundary. Chains do not carry across cycles; an
## unfinished chain is discarded and replaced by the new order.
func begin_cycle(new_chain: Array[int]) -> void:
	chain.assign(new_chain)
	chain_index = 0
	brace_pct = 0


func snapshot() -> Dictionary:
	return {
		"ref": unit_ref,
		"name": display_name,
		"hp": hp,
		"hp_max": hp_max,
		"heat": heat,
		"slot": slot,
		"alive": alive,
		"x": pos_x,
		"z": pos_z,
		"role": role,
	}
