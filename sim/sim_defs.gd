class_name SimDefs
extends RefCounted

## Shared enumerations and encodings for the battle simulation.
##
## These integers are written into replays and PvP submissions, so their values are
## frozen once shipped. Append, never renumber.

# --- Teams and formation -----------------------------------------------------

const TEAM_A: int = 0
const TEAM_B: int = 1
const SQUAD_SIZE: int = 6

const ROW_FRONT: int = 0
const ROW_MID: int = 1
const ROW_BACK: int = 2
const ROW_COUNT: int = 3

## Slots 0-1 are front, 2-3 mid, 4-5 back. The front row screens the rows behind it,
## which is what makes Fall Back a real decision rather than a retreat button.
static func row_of_slot(slot: int) -> int:
	return slot / 2


static func unit_ref(team: int, slot: int) -> int:
	return team * 10 + slot


static func team_of_ref(unit_ref_value: int) -> int:
	return unit_ref_value / 10


static func slot_of_ref(unit_ref_value: int) -> int:
	return unit_ref_value % 10


# --- Damage and armor --------------------------------------------------------

const DMG_KINETIC: int = 0
const DMG_THERMAL: int = 1
const DMG_EMP: int = 2
const DMG_CORROSIVE: int = 3
const DMG_TYPE_COUNT: int = 4

const ARM_PLATE: int = 0
const ARM_COMPOSITE: int = 1
const ARM_REACTIVE: int = 2
const ARM_SHIELDED: int = 3
const ARM_TYPE_COUNT: int = 4

const DMG_TYPE_NAMES: PackedStringArray = ["kinetic", "thermal", "emp", "corrosive"]
const ARM_TYPE_NAMES: PackedStringArray = ["plate", "composite", "reactive", "shielded"]


static func damage_type_id(name: String) -> int:
	var i: int = DMG_TYPE_NAMES.find(name)
	return i if i >= 0 else DMG_KINETIC


static func armor_type_id(name: String) -> int:
	var i: int = ARM_TYPE_NAMES.find(name)
	return i if i >= 0 else ARM_PLATE


# --- States ------------------------------------------------------------------
#
# States are stored per unit in a fixed-length array indexed by these ids, never in
# a Dictionary. A Dictionary would iterate in insertion order, which differs between
# a live battle and a server re-simulation and would silently break verification.

const STATE_EXPOSED: int = 0     ## takes extra damage
const STATE_FRACTURED: int = 1   ## armor stripped
const STATE_OVERHEATED: int = 2  ## builds heat faster
const STATE_GROUNDED: int = 3    ## attacks slower
const STATE_COUNT: int = 4

const STATE_NAMES: PackedStringArray = ["exposed", "fractured", "overheated", "grounded"]


static func state_id(name: String) -> int:
	var i: int = STATE_NAMES.find(name)
	return i if i >= 0 else -1


static func state_name(id: int) -> String:
	if id < 0 or id >= STATE_NAMES.size():
		return "state(%d)" % id
	return STATE_NAMES[id]


# --- Actions -----------------------------------------------------------------
#
# An order is a chain of up to CHAIN_MAX actions. Each action packs a kind and an
# argument (which ability slot) into one int so a whole chain serialises as a plain
# array of numbers.

const ACT_HOLD: int = 0
const ACT_ATTACK: int = 1
const ACT_ABILITY: int = 2
const ACT_BRACE: int = 3
const ACT_VENT: int = 4
const ACT_FALL_BACK: int = 5
const ACT_ADVANCE: int = 6

const ACT_NAMES: PackedStringArray = ["hold", "attack", "ability", "brace", "vent", "fall_back", "advance"]


# --- Roles -------------------------------------------------------------------
#
# A construct's chassis decides how it wants to fight, and that is what drives its
# movement across the map. A brawler crossing open ground to reach a marksman on a
# ridge is the shape of most interesting fights.

const ROLE_BRAWLER: int = 0    ## closes all the way in and stays there
const ROLE_LINE: int = 1       ## holds the middle distance, gives ground slowly
const ROLE_MARKSMAN: int = 2   ## keeps its distance and backs off when crowded
const ROLE_ANCHOR: int = 3     ## barely moves; holds the position it deployed to
const ROLE_COUNT: int = 4

const ROLE_NAMES: PackedStringArray = ["brawler", "line", "marksman", "anchor"]


static func role_id(name: String) -> int:
	var i: int = ROLE_NAMES.find(name)
	return i if i >= 0 else ROLE_LINE


static func role_name(id: int) -> String:
	if id < 0 or id >= ROLE_NAMES.size():
		return "role(%d)" % id
	return ROLE_NAMES[id]

const CHAIN_MAX: int = 3
const ACT_ARG_BITS: int = 4
const ACT_ARG_MASK: int = 0x0F


static func action(kind: int, arg: int = 0) -> int:
	return (kind << ACT_ARG_BITS) | (arg & ACT_ARG_MASK)


static func action_kind(code: int) -> int:
	return code >> ACT_ARG_BITS


static func action_arg(code: int) -> int:
	return code & ACT_ARG_MASK


static func action_name(code: int) -> String:
	var kind: int = action_kind(code)
	var base: String = ACT_NAMES[kind] if kind < ACT_NAMES.size() else "act(%d)" % kind
	if kind == ACT_ABILITY:
		return "%s:%d" % [base, action_arg(code)]
	return base


static func chain_name(chain: Array) -> String:
	if chain.is_empty():
		return "(none)"
	var parts: PackedStringArray = []
	for code: int in chain:
		parts.append(action_name(code))
	return " > ".join(parts)
