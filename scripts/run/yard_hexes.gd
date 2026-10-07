class_name YardHexes
extends RefCounted
## The run map's ground as hexes (049, play-test 14: "the hex diorama look, with the comic
## aesthetics like in battle"). Odd-r pointy-top cells like the fight board (`Hex`), at map
## scale: `cell_of` / `centre` convert between metres and cells, `path` is the hex line a road
## is paved along, `band_of` says which zone (run column) a hex belongs to, so the Reclaimer can
## eat the ground a zone at a time. Presentation only: nothing here reaches the sim.

## Circumradius of one map hex, metres. Three hexes to a zone (`YardView.SPACING_X` 8.5 m).
const R: float = 1.62
const SQRT3: float = 1.7320508

var origin: Vector2       ## world (x, z) of cell (0, 0)
var width: int            ## cells across
var height: int           ## cells down
var spacing_x: float      ## metres between run columns
var first_column_x: float ## world x of run column 0


func _init(area: Rect2, column_spacing: float, column0_x: float) -> void:
	spacing_x = column_spacing
	first_column_x = column0_x
	origin = area.position
	width = int(ceil(area.size.x / (SQRT3 * R))) + 1
	height = int(ceil(area.size.y / (1.5 * R))) + 1
	# Even row count keeps odd-r parity the same at both edges.
	height += height % 2


func centre(cell: Vector2i) -> Vector3:
	return Vector3(origin.x + SQRT3 * R * (float(cell.x) + 0.5 * float(cell.y & 1)), 0.0, origin.y + 1.5 * R * float(cell.y))


func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


## The cell whose hex holds the world point (x, z).
func cell_of(world: Vector3) -> Vector2i:
	# Fractional axial from the point, then the cube rounding `Hex` uses.
	var px: float = (world.x - origin.x) / R
	var pz: float = (world.z - origin.y) / R
	var r: float = pz * 2.0 / 3.0
	var q: float = px / SQRT3 - r * 0.5
	var cube: Vector3i = _round_cube(q, -q - r, r)
	return _to_offset(cube)


## The hexes a road runs over from `a` to `b`, both ends included, one cell per step.
func path(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var ca: Vector3i = _to_cube(a)
	var cb: Vector3i = _to_cube(b)
	var n: int = maxi(absi(ca.x - cb.x), maxi(absi(ca.y - cb.y), absi(ca.z - cb.z)))
	var out: Array[Vector2i] = []
	for i: int in n + 1:
		var t: float = float(i) / float(maxi(1, n))
		# A small nudge so a line along an edge always falls the same way.
		var cell: Vector2i = _to_offset(_round_cube(lerpf(ca.x, cb.x, t) + 1e-4, lerpf(ca.y, cb.y, t) + 2e-4, lerpf(ca.z, cb.z, t) - 3e-4))
		if out.is_empty() or out[out.size() - 1] != cell:
			out.append(cell)
	return out


## Which run column (zone) the hex's centre is in: -1 left of the first, up to the last.
func band_of(cell: Vector2i, columns: int) -> int:
	var x: float = centre(cell).x
	return clampi(int(floor((x - first_column_x + spacing_x * 0.5) / spacing_x)), -1, columns)


## Cheap stable hash of a cell (presentation dressing only).
static func mix(cell: Vector2i, salt: int) -> int:
	var x: int = (cell.x * 73856093) ^ (cell.y * 19349663) ^ (salt * 83492791)
	x = (x ^ (x >> 13)) * 1274126177
	x = x ^ (x >> 16)
	return absi(x)


func _to_cube(cell: Vector2i) -> Vector3i:
	var q: int = cell.x - (cell.y - (cell.y & 1)) / 2
	return Vector3i(q, -q - cell.y, cell.y)


func _to_offset(cube: Vector3i) -> Vector2i:
	return Vector2i(cube.x + (cube.z - (cube.z & 1)) / 2, cube.z)


func _round_cube(x: float, y: float, z: float) -> Vector3i:
	var rx: float = round(x)
	var ry: float = round(y)
	var rz: float = round(z)
	var dx: float = absf(rx - x)
	var dy: float = absf(ry - y)
	var dz: float = absf(rz - z)
	if dx > dy and dx > dz:
		rx = -ry - rz
	elif dy > dz:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector3i(int(rx), int(ry), int(rz))
