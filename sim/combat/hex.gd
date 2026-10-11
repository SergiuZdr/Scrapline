class_name Hex
extends RefCounted

## Hex-grid geometry: pointy-top hexes stored in "odd-r" offset coordinates, so a map is
## still authored as rows of glyphs -- odd rows simply sit half a hex to the right.
##
## Offset `(x, y)` is how cells are STORED; cube `(q, r, s)` with q + r + s = 0 is how they
## are REASONED about (neighbours, distance, lines). Integer-only, like everything in `sim/`:
## the line between two hexes is drawn with scaled integers, not floats, so two machines
## can never disagree about what a shot passes through.

## The six cube directions, in the fixed order everything iterates them:
## east, north-east, north-west, west, south-west, south-east.
const CUBE_DIRS: Array[Vector3i] = [
	Vector3i(1, -1, 0), Vector3i(1, 0, -1), Vector3i(0, 1, -1),
	Vector3i(-1, 1, 0), Vector3i(-1, 0, 1), Vector3i(0, -1, 1),
]

## Scale of the fixed-point line walk; the nudge breaks exact ties the same way every time.
const LINE_SCALE: int = 1000


static func to_cube(c: Vector2i) -> Vector3i:
	var q: int = c.x - (c.y - (c.y & 1)) / 2
	var r: int = c.y
	return Vector3i(q, -q - r, r)


static func from_cube(h: Vector3i) -> Vector2i:
	var r: int = h.z
	return Vector2i(h.x + (r - (r & 1)) / 2, r)


## `CUBE_DIRS` as offset steps, one table per row parity (odd rows sit half a hex right). The
## same six in the same order; `verify_combat` checks them against the cube walk. Neighbours are
## asked for millions of times in a bot batch, and the cube round trip was most of their cost.
const _STEP_EVEN: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1),
]
const _STEP_ODD: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1),
]


static func neighbor(c: Vector2i, dir: int) -> Vector2i:
	return c + (_STEP_ODD[dir] if c.y & 1 else _STEP_EVEN[dir])


static func neighbors(c: Vector2i) -> Array[Vector2i]:
	var steps: Array[Vector2i] = _STEP_ODD if c.y & 1 else _STEP_EVEN
	return [c + steps[0], c + steps[1], c + steps[2], c + steps[3], c + steps[4], c + steps[5]]


## The cube walk the tables stand for (the reference `verify_combat` checks them against).
static func neighbor_by_cube(c: Vector2i, dir: int) -> Vector2i:
	return from_cube(to_cube(c) + CUBE_DIRS[dir])


static func distance(a: Vector2i, b: Vector2i) -> int:
	# `to_cube` inlined: the hottest function in the sim.
	var dq: int = (a.x - (a.y - (a.y & 1)) / 2) - (b.x - (b.y - (b.y & 1)) / 2)
	var dr: int = a.y - b.y
	return maxi(absi(dq), maxi(absi(dr), absi(dq + dr)))


## The hexes a straight line passes through from `a` to `b`, excluding `a`, including `b`.
## Cube lerp in fixed point with a constant nudge, rounded back to the nearest hex.
##
## `lean` (+1 or -1) is which way that nudge pushes. A line that runs exactly along the
## edge between two hexes has two equally good paths, and the nudge alone picks one.
## Play-test 4 found shots always leaning the same way -- into a scrap heap or an ally --
## so rules that care ask for both leanings and take the better (`CombatSim.best_line`).
static func line(a: Vector2i, b: Vector2i, lean: int = 1) -> Array[Vector2i]:
	var key: int = _line_key(a, b, 0, lean)
	var known: Variant = _lines.get(key)
	if known != null:
		return known
	var out: Array[Vector2i] = _walk(a, b, lean)
	out.make_read_only()
	_lines[key] = out
	return out


## Lines and rays already walked, read-only (a caller that tried to change one would change it for
## every later caller). Pure geometry, so a cache cannot make two runs disagree; the AI asks for the
## same few hundred lines thousands of times a fight.
static var _lines: Dictionary = {}


static func _line_key(a: Vector2i, b: Vector2i, reach: int, lean: int) -> int:
	return (((((a.x & 255) << 8 | (a.y & 255)) << 8 | (b.x & 255)) << 8 | (b.y & 255)) << 8 | (reach & 255)) << 1 \
		| (1 if lean > 0 else 0)


static func _walk(a: Vector2i, b: Vector2i, lean: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var n: int = distance(a, b)
	if n == 0:
		return out
	var ca: Vector3i = to_cube(a)
	var cb: Vector3i = to_cube(b)
	var m: int = n * LINE_SCALE
	for i: int in range(1, n + 1):
		# Scaled cube coordinates: exact integers, sum zero, nudged (+1, +1, -2).
		var x: int = ca.x * m + (cb.x - ca.x) * i * LINE_SCALE + lean
		var y: int = ca.y * m + (cb.y - ca.y) * i * LINE_SCALE + lean
		var z: int = ca.z * m + (cb.z - ca.z) * i * LINE_SCALE - 2 * lean
		out.append(from_cube(_round(x, y, z, m)))
	return out


## Extends the line from `a` through `b` out to `reach` hexes from `a`: where a piercing
## shot aimed at `b` actually travels.
static func ray(a: Vector2i, b: Vector2i, reach: int, lean: int = 1) -> Array[Vector2i]:
	var key: int = _line_key(a, b, reach + 1, lean)   # + 1: never a `line`'s key
	var known: Variant = _lines.get(key)
	if known != null:
		return known
	var out: Array[Vector2i] = _cast(a, b, reach, lean)
	out.make_read_only()
	_lines[key] = out
	return out


static func _cast(a: Vector2i, b: Vector2i, reach: int, lean: int) -> Array[Vector2i]:
	var n: int = distance(a, b)
	if n == 0:
		return []
	var ca: Vector3i = to_cube(a)
	var cb: Vector3i = to_cube(b)
	var d: Vector3i = cb - ca
	# The far end, scaled up so the extension stays on the same line.
	var far: Vector3i = ca * n + d * reach
	var out: Array[Vector2i] = []
	var m: int = reach * n * LINE_SCALE
	for i: int in range(1, reach + 1):
		var x: int = ca.x * m + (far.x - ca.x * n) * i * LINE_SCALE + lean
		var y: int = ca.y * m + (far.y - ca.y * n) * i * LINE_SCALE + lean
		var z: int = ca.z * m + (far.z - ca.z * n) * i * LINE_SCALE - 2 * lean
		out.append(from_cube(_round(x, y, z, m)))
	return out


## The direction (0..5) that best matches going from `a` toward `b`: shoves push this way.
static func direction(a: Vector2i, b: Vector2i) -> int:
	var d: Vector3i = to_cube(b) - to_cube(a)
	var best: int = 0
	var best_dot: int = -1000000
	for dir: int in 6:
		var v: Vector3i = CUBE_DIRS[dir]
		var dot: int = d.x * v.x + d.y * v.y + d.z * v.z
		if dot > best_dot:
			best_dot = dot
			best = dir
	return best


## The directions -- one, or two on a tie -- that best match going from `a` toward `b`. Off the
## six axes a hex sits exactly between two of them, and `direction` keeps the first.
static func directions(a: Vector2i, b: Vector2i) -> Array[int]:
	var d: Vector3i = to_cube(b) - to_cube(a)
	var best_dot: int = -1000000
	var out: Array[int] = []
	for dir: int in 6:
		var v: Vector3i = CUBE_DIRS[dir]
		var dot: int = d.x * v.x + d.y * v.y + d.z * v.z
		if dot > best_dot:
			best_dot = dot
			out = [dir]
		elif dot == best_dot:
			out.append(dir)
	return out


## Every hex within `radius` of `c` (excluding `c`), in a fixed order.
static func within(c: Vector2i, radius: int) -> Array[Vector2i]:
	var key: int = ((c.x & 1023) << 10 | (c.y & 1023)) << 8 | (radius & 255)
	var known: Variant = _rings.get(key)
	if known != null:
		return known
	var out: Array[Vector2i] = _disc(c, radius)
	out.make_read_only()
	_rings[key] = out
	return out


## `within`'s answers, read-only, cached like `_lines`.
static var _rings: Dictionary = {}


static func _disc(c: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var cc: Vector3i = to_cube(c)
	for dq: int in range(-radius, radius + 1):
		for dr: int in range(maxi(-radius, -dq - radius), mini(radius, -dq + radius) + 1):
			if dq == 0 and dr == 0:
				continue
			out.append(from_cube(Vector3i(cc.x + dq, cc.y - dq - dr, cc.z + dr)))
	return out


static func _round(x: int, y: int, z: int, m: int) -> Vector3i:
	var rx: int = _round_div(x, m)
	var ry: int = _round_div(y, m)
	var rz: int = _round_div(z, m)
	var dx: int = absi(rx * m - x)
	var dy: int = absi(ry * m - y)
	var dz: int = absi(rz * m - z)
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy > dz:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector3i(rx, ry, rz)


## Round-half-up integer division that floors correctly for negatives (GDScript `/`
## truncates toward zero, which would round -0.5 and 0.5 differently).
static func _round_div(v: int, m: int) -> int:
	return _floor_div(2 * v + m, 2 * m)


static func _floor_div(a: int, b: int) -> int:
	var q: int = a / b
	if (a % b != 0) and ((a < 0) != (b < 0)):
		q -= 1
	return q
