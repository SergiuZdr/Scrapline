class_name BalloonTail
extends Control

## 039, the comic: the tail that turns a panel into a SPEECH BALLOON -- a paper wedge in an ink
## outline from the panel's nearest edge to what the panel talks about (`target`, in this
## control's coordinates). Added BEFORE its panel, so the panel covers the tail's root and the two
## read as one shape. `target` null hides it.

var panel: Control
var target: Variant = null
var fill: Color = UIKit.PAPER_CARD
## How far short of the target the tip stops, so it points rather than covers.
var gap: float = 34.0
## The longest the tail grows: long enough to say where, short enough to cover nothing.
var max_length: float = 110.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func point_at(where: Variant) -> void:
	target = where
	queue_redraw()


func _process(_delta: float) -> void:
	# The panel can change size as its text does; keep the root on its edge.
	if target != null and panel != null:
		queue_redraw()


func _draw() -> void:
	if target == null or panel == null or not panel.visible:
		return
	var tip: Vector2 = target
	var rect := Rect2(panel.global_position - global_position, panel.size)
	if rect.has_point(tip):
		return
	var centre: Vector2 = rect.get_center()
	# The root sits on the edge facing the target, 44 px wide, kept inside the panel's side.
	var base_a: Vector2
	var base_b: Vector2
	var dx: float = tip.x - centre.x
	var dy: float = tip.y - centre.y
	if absf(dx) * rect.size.y >= absf(dy) * rect.size.x:
		var x: float = rect.position.x if dx < 0.0 else rect.end.x
		var y: float = clampf(tip.y, rect.position.y + 40.0, rect.end.y - 40.0)
		base_a = Vector2(x, y - 22.0)
		base_b = Vector2(x, y + 22.0)
	else:
		var y2: float = rect.position.y if dy < 0.0 else rect.end.y
		var x2: float = clampf(tip.x, rect.position.x + 40.0, rect.end.x - 40.0)
		base_a = Vector2(x2 - 22.0, y2)
		base_b = Vector2(x2 + 22.0, y2)
	var root: Vector2 = (base_a + base_b) * 0.5
	# A balloon's tail POINTS; it never runs across the board to its subject.
	var end: Vector2 = root + (tip - root).normalized() * minf(root.distance_to(tip) - gap, max_length)
	if root.distance_to(end) < 12.0:
		return
	var points := PackedVector2Array([base_a, end, base_b])
	draw_colored_polygon(points, fill)
	draw_line(base_a, end, UIKit.INK, 3.0, true)
	draw_line(end, base_b, UIKit.INK, 3.0, true)
