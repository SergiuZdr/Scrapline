class_name SimMath
extends RefCounted

## Integer geometry for the battlefield.
##
## Positions are fixed-point: one world metre is `UNIT` (100) sim units. Floats are
## forbidden inside `sim/`, so distance uses an integer Newton square root rather than
## `sqrt()`. Two machines running the same battle must agree on every position to the
## centimetre, or the server's re-simulation rejects an honest player.

## Sim units per world metre.
const UNIT: int = 100


## Integer square root by Newton's method. Exact for perfect squares, floor otherwise,
## and identical on every platform because it never leaves integer arithmetic.
static func isqrt(value: int) -> int:
	if value <= 0:
		return 0
	if value < 4:
		return 1
	var x: int = value
	var y: int = (x + 1) / 2
	while y < x:
		x = y
		y = (x + value / x) / 2
	return x


## Squared distance. Prefer this for comparisons -- range checks, nearest-target
## searches -- because it skips the square root entirely.
static func distance_squared(ax: int, ay: int, bx: int, by: int) -> int:
	var dx: int = bx - ax
	var dy: int = by - ay
	return dx * dx + dy * dy


static func distance(ax: int, ay: int, bx: int, by: int) -> int:
	return isqrt(distance_squared(ax, ay, bx, by))


## A step of `step` sim units from (ax, ay) toward (bx, by), returned as [dx, dy].
## Truncating division biases movement very slightly toward the dominant axis, which
## is harmless and, more importantly, identical everywhere.
static func step_toward(ax: int, ay: int, bx: int, by: int, step: int) -> Array[int]:
	var dx: int = bx - ax
	var dy: int = by - ay
	var dist: int = isqrt(dx * dx + dy * dy)
	if dist <= 0 or step <= 0:
		return [0, 0]
	if step >= dist:
		return [dx, dy]
	return [(dx * step) / dist, (dy * step) / dist]


## A step of `step` sim units directly away from (bx, by).
static func step_away(ax: int, ay: int, bx: int, by: int, step: int) -> Array[int]:
	var toward: Array[int] = step_toward(ax, ay, bx, by, step)
	return [-toward[0], -toward[1]]


static func clamp_int(value: int, low: int, high: int) -> int:
	return mini(maxi(value, low), high)
