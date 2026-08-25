class_name Balance
extends RefCounted

## Every tunable number the simulation reads.
##
## Nothing in `sim/` may hardcode a balance value. They all live here, they are all
## loaded from `data/balance.json`, and the defaults below exist only so the sim can
## run before the data file is authored. Keeping them in one loadable object is what
## later allows the server to ship a balance patch without a client update.

## Fixed-point scale. A multiplier of 1.35x is stored as the integer 135.
const SCALE: int = 100

# --- Time --------------------------------------------------------------------
var tick_hz: int = 20            ## logical ticks per simulated second
var cycle_ticks: int = 120       ## 6 seconds between Order Phases
var max_cycles: int = 12         ## hard cap so a stalemate cannot run forever

# --- Combat ------------------------------------------------------------------
var base_attack_ticks: int = 20  ## ticks between attacks at speed == SCALE
## Ticks of spin-up per row at the opening bell. Without it all twelve constructs act
## on tick 0 in one indecipherable burst; with it the front rank engages first and the
## back rank follows, which is both readable and true to the formation.
var engage_stagger_ticks: int = 4
var min_damage: int = 1          ## an attack always does something
## Percent scatter applied to every damage roll, drawn from the seeded stream.
## Zero makes combat fully deterministic; small values stop rematches between the
## same two squads from playing out identically every time.
var damage_variance_pct: int = 8
var brace_reduction: int = 40    ## percent damage reduction while braced
## Percent damage reduction for a brawler that has not yet closed to its own reach.
## The role's compensation for spending the opening of every fight walking.
var brawler_charge_reduction: int = 32
var brace_ticks: int = 8         ## recovery before the next action
var vent_amount: int = 35        ## heat shed by a deliberate Vent
var vent_ticks: int = 8
var fall_back_ticks: int = 16
var passive_vent_interval: int = 20  ## ticks between free heat bleed-offs
## Retry delay when a construct has nothing in reach and must close first. Short, so
## crossing the map is a cost in tempo rather than a lost cycle.
var reposition_ticks: int = 6

# --- Spacing -----------------------------------------------------------------
#
# Without these three, every construct picks the same nearest enemy and walks
# straight at it, and the whole battle collapses into one knot in the middle of the
# map. Together they produce a line that advances and engages in several places at
# once, which is the shape a squad battle is supposed to have.

## How much more lateral distance counts than depth when choosing a target, in
## percent. Above 100 a construct prefers whatever is in front of it over something
## equally close but off to the side.
var lane_weight: int = 320
## Beyond this gap a unit advances down its own deployment lane instead of homing
## straight at its target, so squads arrive as a line rather than a column.
var lane_lock_distance: int = 300
# --- Terrain seeking ---------------------------------------------------------
#
# How much a construct in position cares about the ground under it. Set the margin to
# zero to switch terrain seeking off entirely.
var terrain_cover_weight: int = 100
var terrain_high_ground_weight: int = 45
var terrain_hazard_weight: int = 260
## Minimum improvement before a unit will move for it, so nobody jitters between two
## tiles of near-equal value.
var terrain_seek_margin: int = 8

## Personal space, in sim units. Allies inside this push each other apart.
var separation_radius: int = 105
## How hard that push is, in percent of the overlap.
var separation_push: int = 85
## Ticks between movement resolutions. Combat still runs every tick; only walking is
## coarsened, which cut simulation cost by roughly half with no visible difference.
var movement_interval: int = 2
## How far a unit must travel before its position is written to the event stream.
## Per-tick reporting would triple the stream that gets submitted for verification.
var move_report_distance: int = 18

# --- Heat --------------------------------------------------------------------
var seize_ticks: int = 40        ## time lost when a unit cooks itself
var seize_heat_after: int = 50   ## heat retained after seizing
var overdrive_multiplier: int = 200  ## percent damage on a charged strike

# --- States ------------------------------------------------------------------
var exposed_damage_bonus: int = 130   ## percent damage taken while Exposed
var fractured_armor: int = 40         ## percent of armor remaining while Fractured
var overheated_heat_gain: int = 150   ## percent heat gained while Overheated
var grounded_speed: int = 65          ## percent speed while Grounded
var detonation_bonus: int = 150       ## percent bonus damage on a detonation

# --- Damage type vs armor type ----------------------------------------------
## Percent effectiveness, indexed [damage_type][armor_type]. This is the counter
## wheel: every damage type beats one armor and is blunted by another, so no single
## squad composition answers everything.
var effectiveness: Array[PackedInt32Array] = [
	PackedInt32Array([100, 130,  70, 100]),  # kinetic
	PackedInt32Array([ 70, 100, 130, 100]),  # thermal
	PackedInt32Array([100,  70, 100, 130]),  # emp
	PackedInt32Array([130, 100, 100,  70]),  # corrosive
]


static func from_dict(d: Dictionary) -> Balance:
	var b := Balance.new()
	if d.is_empty():
		return b

	b.tick_hz = _int_or(d, "tick_hz", b.tick_hz)
	b.cycle_ticks = _int_or(d, "cycle_ticks", b.cycle_ticks)
	b.max_cycles = _int_or(d, "max_cycles", b.max_cycles)
	b.base_attack_ticks = _int_or(d, "base_attack_ticks", b.base_attack_ticks)
	b.engage_stagger_ticks = _int_or(d, "engage_stagger_ticks", b.engage_stagger_ticks)
	b.min_damage = _int_or(d, "min_damage", b.min_damage)
	b.damage_variance_pct = _int_or(d, "damage_variance_pct", b.damage_variance_pct)
	b.brace_reduction = _int_or(d, "brace_reduction", b.brace_reduction)
	b.brawler_charge_reduction = _int_or(d, "brawler_charge_reduction", b.brawler_charge_reduction)
	b.brace_ticks = _int_or(d, "brace_ticks", b.brace_ticks)
	b.vent_amount = _int_or(d, "vent_amount", b.vent_amount)
	b.vent_ticks = _int_or(d, "vent_ticks", b.vent_ticks)
	b.fall_back_ticks = _int_or(d, "fall_back_ticks", b.fall_back_ticks)
	b.passive_vent_interval = _int_or(d, "passive_vent_interval", b.passive_vent_interval)
	b.reposition_ticks = _int_or(d, "reposition_ticks", b.reposition_ticks)
	b.lane_weight = _int_or(d, "lane_weight", b.lane_weight)
	b.lane_lock_distance = _int_or(d, "lane_lock_distance", b.lane_lock_distance)
	b.terrain_cover_weight = _int_or(d, "terrain_cover_weight", b.terrain_cover_weight)
	b.terrain_high_ground_weight = _int_or(d, "terrain_high_ground_weight", b.terrain_high_ground_weight)
	b.terrain_hazard_weight = _int_or(d, "terrain_hazard_weight", b.terrain_hazard_weight)
	b.terrain_seek_margin = _int_or(d, "terrain_seek_margin", b.terrain_seek_margin)
	b.separation_radius = _int_or(d, "separation_radius", b.separation_radius)
	b.separation_push = _int_or(d, "separation_push", b.separation_push)
	b.movement_interval = maxi(1, _int_or(d, "movement_interval", b.movement_interval))
	b.move_report_distance = _int_or(d, "move_report_distance", b.move_report_distance)
	b.seize_ticks = _int_or(d, "seize_ticks", b.seize_ticks)
	b.seize_heat_after = _int_or(d, "seize_heat_after", b.seize_heat_after)
	b.overdrive_multiplier = _int_or(d, "overdrive_multiplier", b.overdrive_multiplier)
	b.exposed_damage_bonus = _int_or(d, "exposed_damage_bonus", b.exposed_damage_bonus)
	b.fractured_armor = _int_or(d, "fractured_armor", b.fractured_armor)
	b.overheated_heat_gain = _int_or(d, "overheated_heat_gain", b.overheated_heat_gain)
	b.grounded_speed = _int_or(d, "grounded_speed", b.grounded_speed)
	b.detonation_bonus = _int_or(d, "detonation_bonus", b.detonation_bonus)

	if d.has("effectiveness"):
		var rows: Array = d["effectiveness"]
		var table: Array[PackedInt32Array] = []
		for row: Variant in rows:
			var packed := PackedInt32Array()
			for v: Variant in (row as Array):
				packed.append(int(v))
			table.append(packed)
		if table.size() == SimDefs.DMG_TYPE_COUNT:
			b.effectiveness = table

	return b


## Every tunable as a plain dictionary, for hashing and for a patch to write into.
##
## Built from the object's own properties rather than a hand-maintained list: a field
## added above but forgotten here would be a number that a content patch cannot reach and
## that the content hash cannot see -- so two clients could disagree about it silently.
func to_dict() -> Dictionary:
	var out: Dictionary = {}
	for property: Dictionary in get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var name: String = String(property["name"])
		if name == "effectiveness":
			continue
		out[name] = get(name)
	var rows: Array = []
	for row: PackedInt32Array in effectiveness:
		rows.append(Array(row))
	out["effectiveness"] = rows
	return out


## Percent effectiveness of a damage type against an armor type.
func effectiveness_of(damage_type: int, armor_type: int) -> int:
	if damage_type < 0 or damage_type >= effectiveness.size():
		return SCALE
	var row: PackedInt32Array = effectiveness[damage_type]
	if armor_type < 0 or armor_type >= row.size():
		return SCALE
	return row[armor_type]


static func _int_or(d: Dictionary, key: String, fallback: int) -> int:
	return int(d[key]) if d.has(key) else fallback
