class_name InkBox
extends StyleBox

## Ink & Rust (015): a comic panel. A flat fill inside a heavy ink border, and a HARD offset
## shadow -- a solid ink block, no blur -- so a panel sits on the page like a cut-out rather
## than floating over it the way every generated dashboard's cards do.
##
## `StyleBoxFlat` cannot draw this: its shadow is always blurred, and a blurred shadow under a
## flat ink panel is exactly the mix of two languages the style exists to avoid.

var fill: Color = Color("f7efdc")
var border: Color = Color("14110f")
var border_width: float = 3.0
## The shadow's offset in pixels; zero for none.
var shadow: Vector2 = Vector2(5, 5)
var shadow_colour: Color = Color("14110f")
## A band of colour down the left edge (the selection mark, an ability's blue), 0 for none.
var band_width: float = 0.0
var band: Color = Color("ffc43d")
## How far the panel leans: the top edge shifts right by `skew * height`.
var skew: float = 0.0
## A halftone dot screen over the fill, in this colour (alpha = strength); clear for none.
var dots: Color = Color(0, 0, 0, 0)

static var _dot_texture: ImageTexture


func _init(fill_colour: Color = Color("f7efdc"), margin_x: float = 14.0, margin_y: float = 10.0) -> void:
	fill = fill_colour
	content_margin_left = margin_x
	content_margin_right = margin_x
	content_margin_top = margin_y
	content_margin_bottom = margin_y


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
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
