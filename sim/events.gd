class_name SimEv
extends RefCounted

## Event kinds emitted by the battle simulation.
##
## The event stream is the ONLY channel between `sim/` and everything else. The 3D
## presentation layer animates it, replays re-play it, and the server hashes it to
## verify a client's reported result. Nothing downstream is allowed to recompute an
## outcome -- it may only render what these events say happened.
##
## Numeric values are frozen once shipped: a replay recorded by an old client must
## still decode correctly. Append new kinds at the end, never renumber.

const BATTLE_START: int = 0
const BATTLE_END: int = 1
const CYCLE_START: int = 2
const CYCLE_END: int = 3
const ORDERS_SET: int = 4
const ACTION_BEGIN: int = 5
const ATTACK: int = 6
const DAMAGE: int = 7
const HEAL: int = 8
const HEAT_CHANGED: int = 9
const OVERDRIVE: int = 10
const SEIZE: int = 11
const BRACE: int = 12
const VENT: int = 13
const FALL_BACK: int = 14
const STATE_APPLIED: int = 15
const STATE_EXPIRED: int = 16
const DETONATION: int = 17
const LINKAGE: int = 18
const DESTROYED: int = 19
const NO_TARGET: int = 20
## Position update: v1 = x, v2 = z, in sim units. Emitted periodically while a unit
## is actually moving, rather than every tick, so the stream stays compact enough to
## submit for server verification.
const MOVED: int = 21
const OUT_OF_RANGE: int = 22

## Field indices into an event record. A record is a flat Array of exactly 7 slots:
## [tick, kind, actor, target, v1, v2, sid]. Flat arrays keep the stream cheap to
## build, cheap to hash, and trivial to serialise for a replay.
const F_TICK: int = 0
const F_KIND: int = 1
const F_ACTOR: int = 2
const F_TARGET: int = 3
const F_V1: int = 4
const F_V2: int = 5
const F_SID: int = 6
const FIELD_COUNT: int = 7

const KIND_NAMES: PackedStringArray = [
	"BATTLE_START", "BATTLE_END", "CYCLE_START", "CYCLE_END", "ORDERS_SET",
	"ACTION_BEGIN", "ATTACK", "DAMAGE", "HEAL", "HEAT_CHANGED",
	"OVERDRIVE", "SEIZE", "BRACE", "VENT", "FALL_BACK",
	"STATE_APPLIED", "STATE_EXPIRED", "DETONATION", "LINKAGE", "DESTROYED",
	"NO_TARGET", "MOVED", "OUT_OF_RANGE",
]


static func kind_name(kind: int) -> String:
	if kind < 0 or kind >= KIND_NAMES.size():
		return "UNKNOWN(%d)" % kind
	return KIND_NAMES[kind]


## Renders a unit reference (team * 10 + slot) as "A3" / "B0" for logs.
static func ref_name(unit_ref: int) -> String:
	if unit_ref < 0:
		return "--"
	var team: int = unit_ref / 10
	var slot: int = unit_ref % 10
	return "%s%d" % ["A" if team == 0 else "B", slot]
