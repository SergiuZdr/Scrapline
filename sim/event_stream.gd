class_name EventStream
extends RefCounted

## An ordered, hashable log of everything that happened in a battle.
##
## The hash is the contract between client and server. A client submits
## {setup, seed, order_log}; the server re-runs the simulation and compares stream
## hashes. Identical hash means the client is honest; anything else is rejected.
##
## The hash is FNV-1a computed by hand rather than Godot's `hash()`, because
## `hash()` carries no cross-version or cross-platform stability guarantee and this
## value has to mean the same thing on a macOS dev box and a Linux server forever.

const FNV_OFFSET: int = 0x811C9DC5
const FNV_PRIME: int = 16777619
const MASK32: int = 0xFFFFFFFF

var events: Array[Array] = []


func emit(tick: int, kind: int, actor: int = -1, target: int = -1, v1: int = 0, v2: int = 0, sid: String = "") -> void:
	events.append([tick, kind, actor, target, v1, v2, sid])


func size() -> int:
	return events.size()


func is_empty() -> bool:
	return events.is_empty()


## Every event whose kind matches. Used by the presentation layer to build per-unit
## animation timelines without walking the whole stream repeatedly.
func of_kind(kind: int) -> Array[Array]:
	var out: Array[Array] = []
	for e: Array in events:
		if e[SimEv.F_KIND] == kind:
			out.append(e)
	return out


## The verification hash. Field order is fixed and every field participates, so any
## divergence anywhere in the battle changes the result.
func stream_hash() -> int:
	var h: int = FNV_OFFSET
	for e: Array in events:
		h = _mix_int(h, e[SimEv.F_TICK])
		h = _mix_int(h, e[SimEv.F_KIND])
		h = _mix_int(h, e[SimEv.F_ACTOR])
		h = _mix_int(h, e[SimEv.F_TARGET])
		h = _mix_int(h, e[SimEv.F_V1])
		h = _mix_int(h, e[SimEv.F_V2])
		h = _mix_string(h, String(e[SimEv.F_SID]))
	return h


func hash_hex() -> String:
	return "%08x" % stream_hash()


## Folds a 64-bit-capable int in as four bytes. Negative values are masked into the
## same 32-bit space rather than being sign-extended, so -1 hashes identically
## everywhere.
func _mix_int(h: int, value: int) -> int:
	var v: int = value & MASK32
	for shift: int in [0, 8, 16, 24]:
		h = (h ^ ((v >> shift) & 0xFF)) & MASK32
		h = (h * FNV_PRIME) & MASK32
	return h


func _mix_string(h: int, value: String) -> int:
	for byte: int in value.to_utf8_buffer():
		h = (h ^ byte) & MASK32
		h = (h * FNV_PRIME) & MASK32
	# Length is folded in too, so "ab"+"c" can never collide with "a"+"bc".
	return _mix_int(h, value.length())


## Human-readable log. Debug and design tool only -- never parsed by anything.
func to_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for e: Array in events:
		lines.append(format_event(e))
	return lines


static func format_event(e: Array) -> String:
	var kind: int = e[SimEv.F_KIND]
	var actor: String = SimEv.ref_name(e[SimEv.F_ACTOR])
	var target: String = SimEv.ref_name(e[SimEv.F_TARGET])
	var sid: String = e[SimEv.F_SID]
	var detail: String = ""

	match kind:
		SimEv.BATTLE_START:
			detail = "seed=%d" % e[SimEv.F_V1]
		SimEv.BATTLE_END:
			var winner: int = e[SimEv.F_V1]
			var who: String = "draw" if winner < 0 else ("team A" if winner == 0 else "team B")
			detail = "%s after %d cycles" % [who, e[SimEv.F_V2]]
		SimEv.CYCLE_START, SimEv.CYCLE_END:
			detail = "cycle %d" % e[SimEv.F_V1]
		SimEv.ORDERS_SET:
			var source: String = ["new", "standing", "auto"][clampi(e[SimEv.F_V2], 0, 2)]
			detail = "%s <- %s  (%s)" % [actor, sid, source]
		SimEv.ACTION_BEGIN:
			detail = "%s begins %s" % [actor, sid]
		SimEv.ATTACK:
			detail = "%s -> %s (%s, x%d%%)" % [actor, target, sid, e[SimEv.F_V2]]
		SimEv.DAMAGE:
			detail = "%s takes %d (hp %d)" % [target, e[SimEv.F_V1], e[SimEv.F_V2]]
		SimEv.HEAL:
			detail = "%s heals %d (hp %d)" % [target, e[SimEv.F_V1], e[SimEv.F_V2]]
		SimEv.HEAT_CHANGED:
			detail = "%s heat %d" % [actor, e[SimEv.F_V1]]
		SimEv.OVERDRIVE:
			detail = "%s OVERDRIVES" % actor
		SimEv.SEIZE:
			detail = "%s seizes (out for %d ticks)" % [actor, e[SimEv.F_V1]]
		SimEv.BRACE:
			detail = "%s braces (-%d%% damage)" % [actor, e[SimEv.F_V1]]
		SimEv.VENT:
			detail = "%s vents %d heat" % [actor, e[SimEv.F_V1]]
		SimEv.FALL_BACK:
			detail = "%s falls back from (%d, %d)" % [actor, e[SimEv.F_V1], e[SimEv.F_V2]]
		SimEv.STATE_APPLIED:
			detail = "%s applies %s to %s (%d ticks)" % [actor, sid, target, e[SimEv.F_V1]]
		SimEv.STATE_EXPIRED:
			detail = "%s loses %s" % [target, sid]
		SimEv.DETONATION:
			detail = "%s detonates %s on %s (+%d)" % [actor, sid, target, e[SimEv.F_V1]]
		SimEv.LINKAGE:
			detail = "%s links %s" % [actor, sid]
		SimEv.DESTROYED:
			detail = "%s destroyed" % target
		SimEv.NO_TARGET:
			detail = "%s has no target" % actor
		SimEv.MOVED:
			detail = "%s moves to (%d, %d) %s" % [actor, e[SimEv.F_V1], e[SimEv.F_V2], sid]
		SimEv.OUT_OF_RANGE:
			detail = "%s closing on %s (%d away)" % [actor, target, e[SimEv.F_V1]]
		_:
			detail = "%s %s %d %d %s" % [actor, target, e[SimEv.F_V1], e[SimEv.F_V2], sid]

	return "[t%4d] %-14s %s" % [e[SimEv.F_TICK], SimEv.kind_name(kind), detail]
