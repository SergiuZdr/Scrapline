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


static func neighbor(c: Vector2i, dir: int) -> Vector2i:
	return from_cube(to_cube(c) + CUBE_DIRS[dir])


static func neighbors(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dir: int in 6:
		out.append(neighbor(c, dir))
	return out


static func distance(a: Vector2i, b: Vector2i) -> int:
	var d: Vector3i = to_cube(a) - to_cube(b)
	return maxi(absi(d.x), maxi(absi(d.y), absi(d.z)))


## The hexes a straight line passes through from `a` to `b`, excluding `a`, including `b`.
## Cube lerp in fixed point with a constant nudge, rounded back to the nearest hex.
static func line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var n: int = distance(a, b)
	if n == 0:
		return out
	var ca: Vector3i = to_cube(a)
	var cb: Vector3i = to_cube(b)
	var m: int = n * LINE_SCALE
	for i: int in range(1, n + 1):
		# Scaled cube coordinates: exact integers, sum zero, nudged (+1, +1, -2).
		var x: int = ca.x * m + (cb.x - ca.x) * i * LINE_SCALE + 1
		var y: int = ca.y * m + (cb.y - ca.y) * i * LINE_SCALE + 1
		var z: int = ca.z * m + (cb.z - ca.z) * i * LINE_SCALE - 2
		out.append(from_cube(_round(x, y, z, m)))
	return out


## Extends the line from `a` through `b` out to `reach` hexes from `a`: where a piercing
## shot aimed at `b` actually travels.
static func ray(a: Vector2i, b: Vector2i, reach: int) -> Array[Vector2i]:
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
		var x: int = ca.x * m + (far.x - ca.x * n) * i * LINE_SCALE + 1
		var y: int = ca.y * m + (far.y - ca.y * n) * i * LINE_SCALE + 1
		var z: int = ca.z * m + (far.z - ca.z * n) * i * LINE_SCALE - 2
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


## Every hex within `radius` of `c` (excluding `c`), in a fixed order.
static func within(c: Vector2i, radius: int) -> Array[Vector2i]:
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
