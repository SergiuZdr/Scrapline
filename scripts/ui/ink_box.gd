class_name InkBox
extends StyleBox

## Ink & Rust (015): a comic panel. A flat fill inside a heavy ink border, and a HARD offset
## shadow -- a solid ink block, no blur -- so a panel sits on the page like a cut-out rather
## than floating over it the way every generated dashboard's cards do.
##
## `StyleBoxFlat` cannot draw this: its shadow is always blurred, and a blurred shadow under a
## flat ink panel is exactly the mix of two languages the style exists to avoid.

@export var fill: Color = Color("f7efdc")
@export var border: Color = Color("14110f")
@export var border_width: float = 3.0
## The shadow's offset in pixels; zero for none.
@export var shadow: Vector2 = Vector2(5, 5)
@export var shadow_colour: Color = Color("14110f")
## A band of colour down the left edge (the selection mark, an ability's blue), 0 for none.
@export var band_width: float = 0.0
@export var band: Color = Color("ffc43d")
## How far the panel leans: the top edge shifts right by `skew * height`.
@export var skew: float = 0.0
## A halftone dot screen over the fill, in this colour (alpha = strength); clear for none.
@export var dots: Color = Color(0, 0, 0, 0)
## 041, comic panels (options): a hand-drawn border -- the edge wanders by up to `wobble` px; a
## halftone RAMP of dots growing into the bottom-right corner (`ramp`, alpha = strength); a
## jagged BURST edge (`jag` px spikes) for the loudest buttons; a second thin inner line
## (`double_line`), as an inked panel's border often has.
@export var wobble: float = 0.0
@export var ramp: Color = Color(0, 0, 0, 0)
@export var jag: float = 0.0
@export var double_line: bool = false
## Where the whole box is drawn relative to its rect: a pressed button drops into its shadow.
@export var nudge: Vector2 = Vector2.ZERO

## 043: the names `StyleBoxFlat` uses, so every screen that tweaks a UIKit style keeps working
## now that UIKit hands out InkBoxes (the variables above are exported so `duplicate()` copies them).
var bg_color: Color:
	get: return fill
	set(value): fill = value
var border_color: Color:
	get: return border
	set(value): border = value
var shadow_offset: Vector2:
	get: return shadow
	set(value): shadow = value
var shadow_color: Color:
	get: return shadow_colour
	set(value): shadow_colour = value
## Zero takes the shadow away, as it does on a StyleBoxFlat.
var shadow_size: int:
	get: return 0 if shadow == Vector2.ZERO else 1
	set(value):
		if value <= 0:
			shadow = Vector2.ZERO


func set_border_width_all(width: int) -> void:
	border_width = float(width)


## Comic panels have square corners; kept so a call written for StyleBoxFlat still runs.
func set_corner_radius_all(_radius: int) -> void:
	pass


static var _dot_texture: ImageTexture


func _init(fill_colour: Color = Color("f7efdc"), margin_x: float = 14.0, margin_y: float = 10.0) -> void:
	fill = fill_colour
	content_margin_left = margin_x
	content_margin_right = margin_x
	content_margin_top = margin_y
	content_margin_bottom = margin_y


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	rect.position += nudge
	if wobble > 0.0 or jag > 0.0:
		_draw_drawn(to_canvas_item, rect)
		return
	if shadow != Vector2.ZERO:
		_quad(to_canvas_item, Rect2(rect.position + shadow, rect.size), shadow_colour)
	_quad(to_canvas_item, rect, border)
	var inner: Rect2 = rect.grow(-border_width)
	_quad(to_canvas_item, inner, fill)
	if dots.a > 0.0:
		RenderingServer.canvas_item_add_texture_rect(to_canvas_item, inner, _dots().get_rid(), true, dots)
	if band_width > 0.0:
		_quad(to_canvas_item, Rect2(inner.position, Vector2(band_width, inner.size.y)), band)


## A rect, leaned by `skew` (the top edge further right than the bottom).
func _quad(item: RID, r: Rect2, colour: Color) -> void:
	if skew == 0.0:
		RenderingServer.canvas_item_add_rect(item, r, colour)
		return
	var lean: float = skew * r.size.y
	var points := PackedVector2Array([
		r.position + Vector2(lean, 0), r.position + Vector2(r.size.x + lean, 0),
		r.position + Vector2(r.size.x, r.size.y), r.position + Vector2(0, r.size.y)])
	RenderingServer.canvas_item_add_polygon(item, points, PackedColorArray([colour]))


## An 8 px halftone cell: one soft dot, tiled.
static func _dots() -> ImageTexture:
	if _dot_texture == null:
		var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		for y: int in 8:
			for x: int in 8:
				var r: float = Vector2(float(x) - 3.5, float(y) - 3.5).length()
				image.set_pixel(x, y, Color(1, 1, 1, clampf(2.2 - r, 0.0, 1.0)))
		_dot_texture = ImageTexture.create_from_image(image)
	return _dot_texture


## The hand-drawn and burst forms: the outline as a polygon walked round the rect, each point
## nudged (wobble, a stable hash of where it is) or pushed out in spikes (jag).
func _draw_drawn(item: RID, rect: Rect2) -> void:
	var outer: PackedVector2Array = _outline(rect, 0.0)
	if shadow != Vector2.ZERO:
		var shade := PackedVector2Array()
		for p: Vector2 in outer:
			shade.append(p + shadow)
		RenderingServer.canvas_item_add_polygon(item, shade, PackedColorArray([shadow_colour]))
	RenderingServer.canvas_item_add_polygon(item, outer, PackedColorArray([border]))
	var inner: PackedVector2Array = _outline(rect.grow(-border_width), 0.5)
	RenderingServer.canvas_item_add_polygon(item, inner, PackedColorArray([fill]))
	var box: Rect2 = rect.grow(-border_width - 1.0)
	if dots.a > 0.0:
		RenderingServer.canvas_item_add_texture_rect(item, box, _dots().get_rid(), true, dots)
	if ramp.a > 0.0:
		_ramp(item, box)
	if double_line:
		var line: PackedVector2Array = _outline(rect.grow(-border_width - 5.0), 0.25)
		line.append(line[0])
		RenderingServer.canvas_item_add_polyline(item, line, PackedColorArray([border]), 1.5)
	if band_width > 0.0:
		RenderingServer.canvas_item_add_rect(item, Rect2(box.position, Vector2(band_width, box.size.y)), band)


func _outline(r: Rect2, seed_shift: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var corners: Array = [r.position + Vector2(skew * r.size.y, 0), Vector2(r.end.x + skew * r.size.y, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for c: int in 4:
		var a: Vector2 = corners[c]
		var b: Vector2 = corners[(c + 1) % 4]
		var length: float = a.distance_to(b)
		var steps: int = maxi(2, int(length / (14.0 if jag > 0.0 else 22.0)))
		var normal: Vector2 = (b - a).orthogonal().normalized()
		for i: int in steps:
			var t: float = float(i) / float(steps)
			var p: Vector2 = a.lerp(b, t)
			if jag > 0.0:
				p += normal * (jag if i % 2 == 1 else 0.0)
			if wobble > 0.0:
				var h: float = sin(p.x * 12.9898 + p.y * 78.233 + seed_shift * 37.0) * 43758.5453
				p += normal * (h - floor(h) - 0.5) * 2.0 * wobble
			points.append(p)
	return points


## Dots that grow toward the bottom-right corner, the way a comic shades a panel's corner.
func _ramp(item: RID, box: Rect2) -> void:
	var cell: float = 9.0
	var reach: float = minf(box.size.x, box.size.y) * 0.9
	var corner: Vector2 = box.end
	var y: float = box.end.y - cell * 0.5
	while y > box.position.y:
		var x: float = box.end.x - cell * 0.5
		while x > box.position.x:
			var d: float = Vector2(x, y).distance_to(corner)
			if d < reach:
				var r: float = (1.0 - d / reach) * cell * 0.48
				if r > 0.6:
					RenderingServer.canvas_item_add_circle(item, Vector2(x, y), r, ramp)
			x -= cell
		y -= cell
