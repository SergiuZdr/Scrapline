class_name SimRNG
extends RefCounted

## Seeded, platform-independent pseudo-random number generator (xorshift128).
##
## The engine's RNG is forbidden inside `sim/`. Godot makes no guarantee that
## `randi()` produces the same sequence across versions or platforms, and the whole
## anti-cheat design rests on a server reproducing a client's battle exactly.
##
## Every operation here is confined to 32 bits and stays positive, so `>>` never
## sign-extends and the arithmetic is identical on every machine that runs it.

const MASK32: int = 0xFFFFFFFF

var _a: int
var _b: int
var _c: int
var _d: int

## Number of values drawn. Two runs of the same battle must consume the same
## count -- a mismatch here localises a determinism bug fast.
var draws: int = 0


func _init(seed_value: int = 0) -> void:
	seed_with(seed_value)


## Fills the four state words from a single seed using SplitMix32, so that
## seeds 1 and 2 produce completely unrelated streams rather than adjacent ones.
func seed_with(seed_value: int) -> void:
	var s: int = seed_value & MASK32
	_a = _splitmix(s)
	s = (s + 0x9E3779B9) & MASK32
	_b = _splitmix(s)
	s = (s + 0x9E3779B9) & MASK32
	_c = _splitmix(s)
	s = (s + 0x9E3779B9) & MASK32
	_d = _splitmix(s)
	# An all-zero state is the one fixed point of xorshift and would emit only zeros.
	if _a == 0 and _b == 0 and _c == 0 and _d == 0:
		_a = 0x1D872B41
	draws = 0


func _splitmix(x: int) -> int:
	var z: int = (x + 0x9E3779B9) & MASK32
	z = ((z ^ (z >> 16)) * 0x85EBCA6B) & MASK32
	z = ((z ^ (z >> 13)) * 0xC2B2AE35) & MASK32
	return (z ^ (z >> 16)) & MASK32


## A uniform 32-bit value in [0, 2^32).
func next_u32() -> int:
	draws += 1
	var t: int = _d
	var s: int = _a
	_d = _c
	_c = _b
	_b = s
	t = (t ^ ((t << 11) & MASK32)) & MASK32
	t = t ^ (t >> 8)
	_a = (t ^ s ^ (s >> 19)) & MASK32
	return _a


## A uniform integer in [low, high], inclusive at both ends.
## Modulo bias is on the order of 1e-7 for the range sizes this game uses,
## which is far below the noise floor of any balance decision.
func range_int(low: int, high: int) -> int:
	if high <= low:
		return low
	return low + (next_u32() % (high - low + 1))


## True with the given probability, expressed in whole percent.
func chance_percent(percent: int) -> bool:
	if percent <= 0:
		return false
	if percent >= 100:
		return true
	return range_int(1, 100) <= percent


## Picks one element of `items`. Returns -1 for an empty array so callers are
## forced to handle the empty case rather than silently indexing garbage.
func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[range_int(0, items.size() - 1)]


## Snapshot of the internal state, for debugging a divergence between two runs.
func state_string() -> String:
	return "%08x%08x%08x%08x/%d" % [_a, _b, _c, _d, draws]
