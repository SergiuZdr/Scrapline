extends Node

## Every button in the game answers the hand (035, play-test 10: "every button and control needs
## to feel more interactive"). An autoload that watches the tree: each BaseButton that enters it
## gets a hover lift, a press squash, a release bounce and a sound, and a disabled one shakes
## "no" when it is clicked. No screen builds this itself, so no screen can forget it -- most
## call sites styled `hover` exactly like `normal`, and that is why nothing seemed to answer.
##
## A control opts out with the meta `no_juice` (a drag source, say, whose scale is its own).

const HOVER_SCALE: float = 1.045
const PRESS_SCALE: float = 0.93
const T_IN: float = 0.09
const T_OUT: float = 0.14


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	_walk(get_tree().root)


func _walk(node: Node) -> void:
	_on_node_added(node)
	for child: Node in node.get_children():
		_walk(child)


func _on_node_added(node: Node) -> void:
	if not (node is BaseButton) or node.has_meta("juiced") or node.has_meta("no_juice"):
		return
	var button: BaseButton = node
	button.set_meta("juiced", true)
	button.mouse_entered.connect(_hover.bind(button, true))
	button.mouse_exited.connect(_hover.bind(button, false))
	button.button_down.connect(_down.bind(button))
	button.button_up.connect(_up.bind(button))
	button.gui_input.connect(_refused.bind(button))
	button.resized.connect(_centre.bind(button))
	_centre.call_deferred(button)


## Scale about the middle, whatever size the container gave it.
func _centre(button: BaseButton) -> void:
	if is_instance_valid(button):
		button.pivot_offset = button.size * 0.5


func _hover(button: BaseButton, on: bool) -> void:
	if not is_instance_valid(button) or button.disabled:
		return
	_to(button, HOVER_SCALE if on else 1.0, T_IN if on else T_OUT)
	if on:
		Audio.play("ui_hover", -18.0, 0.0)


func _down(button: BaseButton) -> void:
	if not is_instance_valid(button) or button.disabled:
		return
	_to(button, PRESS_SCALE, 0.05)
	Audio.play("ui_click", -10.0, 0.0)


func _up(button: BaseButton) -> void:
	if not is_instance_valid(button):
		return
	# Back past where it rests, then home: the bounce is what reads as springy.
	var tween := _tween(button)
	tween.tween_property(button, "scale", Vector2.ONE * (HOVER_SCALE + 0.03), 0.07)
	var home: float = HOVER_SCALE if button.get_global_rect().has_point(button.get_global_mouse_position()) else 1.0
	tween.tween_property(button, "scale", Vector2.ONE * home, 0.12)


## A click on a disabled control shakes it: it is a "no", not a dead spot.
func _refused(event: InputEvent, button: BaseButton) -> void:
	if not button.disabled or not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var tween := _tween(button)
	var x: float = button.position.x
	for step: float in [7.0, -6.0, 4.0, -2.0, 0.0]:
		tween.tween_property(button, "position:x", x + step, 0.035)
	Audio.play("ui_deny", -12.0, 0.0)


func _to(button: BaseButton, s: float, seconds: float) -> void:
	var tween := _tween(button)
	tween.tween_property(button, "scale", Vector2.ONE * s, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## One tween per button at a time: a new gesture replaces the old one instead of fighting it.
func _tween(button: BaseButton) -> Tween:
	var old: Variant = button.get_meta("juice_tween", null)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tween := button.create_tween()
	button.set_meta("juice_tween", tween)
	return tween
