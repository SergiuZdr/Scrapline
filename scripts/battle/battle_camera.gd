class_name BattleCamera
extends Node3D

## An orbit rig for the battle view.
##
## Structure is a gimbal: this node holds the focus point and yaw, a child holds the
## pitch, and the camera sits at a distance along the child's local -Z. Moving the rig
## rather than the camera means orbit, zoom and pan never fight each other, and the
## camera cannot end up inside the ground.
##
## Controls are deliberately identical in intent across input types, because this ships
## on phones and on desktop from the same build:
##
##   drag / one finger      orbit
##   right-drag / two finger pan across the ground
##   wheel / pinch          zoom
##   middle-click / --      recentre
##
## Limits matter more than range here. Pitch is clamped well above the horizon so the
## player can never look up into an empty skybox and lose the battle off-screen, and
## panning is bounded to the map so the arena cannot be left behind.

const PITCH_MIN: float = 18.0
const PITCH_MAX: float = 78.0
const ZOOM_MIN: float = 6.0
const ZOOM_MAX: float = 44.0
const ORBIT_SPEED: float = 0.32
const PAN_SPEED: float = 0.016
const ZOOM_STEP: float = 1.18
const SMOOTHING: float = 12.0

## Auto-framing. The rig follows the live fight rather than sitting at a fixed distance
## from the whole map: constructs spread out at deployment and converge as they close,
## and a camera pinned to map size renders them ~20 px tall for the entire battle, which
## is too small to read a silhouette, a weapon or a damage type on a phone.
##
## Framing is only automatic until the player touches the camera. From the first orbit,
## pan or zoom the view is theirs, and RECENTRE hands it back -- an auto-camera that
## fights the player for control is worse than no auto-camera at all.
## Generous, because the order panel owns the bottom third of the screen: the shot has to
## fit the fight into the strip ABOVE it, not into the viewport.
const FRAME_MARGIN: float = 6.0
const FRAME_SMOOTHING: float = 2.6
## Units clustered tighter than this stop pulling the camera closer, so a duel at the
## end of a battle does not end up in an extreme close-up.
const FRAME_MIN_SPREAD: float = 5.0

var _pitch_node: Node3D
var _camera: Camera3D

var _target_yaw: float = 0.0
var _target_pitch: float = 58.0
var _target_zoom: float = 20.0
var _target_focus: Vector3 = Vector3.ZERO

var _home_yaw: float = 0.0
var _home_pitch: float = 58.0
var _home_zoom: float = 20.0
var _home_focus: Vector3 = Vector3.ZERO

## Half-extents of the map, so panning stays over the battlefield.
var _bounds: Vector2 = Vector2(12, 14)

## True until the player takes the camera. See FRAME_MARGIN above.
var _auto_frame: bool = true

var _orbiting: bool = false
var _panning: bool = false
## Active touches, for pinch-zoom and two-finger pan.
var _touches: Dictionary = {}
var _pinch_distance: float = 0.0


func setup(field: Battlefield, fov: float = 42.0) -> void:
	_bounds = Vector2(float(field.width) * 0.5, float(field.depth) * 0.5)

	_pitch_node = Node3D.new()
	add_child(_pitch_node)

	_camera = Camera3D.new()
	_camera.fov = fov
	_pitch_node.add_child(_camera)

	# Yaw 180 puts the camera on the PLAYER's side of the map. At yaw 0 the rig sat
	# behind the enemy line and the player watched their own squad from the back,
	# which is disorienting and was not obvious until it was rendered.
	_target_yaw = 180.0
	# A low angle. Looking down at 58 degrees showed the tops of twelve constructs and
	# nothing else; from here they stand against the horizon, which is where a
	# silhouette -- the whole reason the frames differ by role -- actually reads.
	_target_pitch = 38.0
	# Opening distance only. `frame()` takes over on the first tick and fits the shot to
	# where the constructs actually are.
	_target_zoom = clampf(maxf(_bounds.x, _bounds.y) * 1.7, ZOOM_MIN, ZOOM_MAX)
	# Focus pulled toward the CAMERA, not away from it. The rig position is the focus,
	# so shifting it toward the player's own line slides the whole view window down the
	# map and lifts the near rank out from behind the panel. Pushing it the other way
	# does the opposite, which is what the first attempt did.
	_target_focus = Vector3(0, 0, -_bounds.y * 0.34)
	_home_yaw = _target_yaw
	_home_pitch = _target_pitch
	_home_zoom = _target_zoom
	_home_focus = _target_focus

	_apply(true)


## Fits the shot to the living constructs. Called every frame by the battle scene with
## the positions it is already drawing, and ignored once the player has taken control.
##
## The camera tightens as the two lines close, which is what makes the same battle read
## as a skirmish at deployment and a brawl at the end.
func frame(points: PackedVector3Array, delta: float) -> void:
	if not _auto_frame or points.is_empty():
		return

	var centre := Vector3.ZERO
	for point: Vector3 in points:
		centre += point
	centre /= float(points.size())

	# Spread is measured as the furthest construct from the centre, so one marksman
	# holding the back line keeps the rest of its squad in shot.
	var spread: float = FRAME_MIN_SPREAD
	for point: Vector3 in points:
		spread = maxf(spread, Vector2(point.x - centre.x, point.z - centre.z).length())

	var wanted_zoom: float = clampf(spread * 1.12 + FRAME_MARGIN, ZOOM_MIN, ZOOM_MAX)
	# Focus is pulled toward the camera so the near rank clears the order panel, which
	# owns the bottom third of the screen.
	var wanted_focus: Vector3 = _clamp_focus(
		Vector3(centre.x, 0.0, centre.z - wanted_zoom * 0.26))

	# Much slower than the input smoothing. A camera that snaps to the centroid every
	# time a construct dies reads as a bug, not as framing.
	var weight: float = clampf(delta * FRAME_SMOOTHING, 0.0, 1.0)
	_target_zoom = lerpf(_target_zoom, wanted_zoom, weight)
	_target_focus = _target_focus.lerp(wanted_focus, weight)


func camera() -> Camera3D:
	return _camera


## Stops auto-framing and leaves the shot exactly where the caller put it.
##
## Needed by anything that sets the rig's targets by hand -- the dev `--closeup` capture
## does, and without this `frame()` simply overwrote it on the next tick, so every
## close-up screenshot silently came out as the usual wide shot.
func hold() -> void:
	_auto_frame = false


## Recentres on a point without changing the angle -- used when a battle ends, to put
## the surviving squad in frame. Holds the shot rather than letting auto-framing drift
## off it while the result is on screen.
func focus_on(point: Vector3) -> void:
	_auto_frame = false
	_target_focus = _clamp_focus(point)


## Also hands the camera back to auto-framing: RECENTRE is the player saying "stop, put
## it back", and leaving it manual would strand them at a fixed distance for the rest of
## the battle with no way to undo it.
func recentre() -> void:
	_auto_frame = true
	_target_yaw = _home_yaw
	_target_pitch = _home_pitch
	_target_zoom = _home_zoom
	_target_focus = _home_focus


func _process(delta: float) -> void:
	_apply(false, delta)


func _apply(instant: bool, delta: float = 0.0) -> void:
	var weight: float = 1.0 if instant else clampf(delta * SMOOTHING, 0.0, 1.0)
	rotation.y = lerp_angle(rotation.y, deg_to_rad(_target_yaw), weight)
	_pitch_node.rotation.x = lerpf(_pitch_node.rotation.x, deg_to_rad(-_target_pitch), weight)
	position = position.lerp(_target_focus, weight)
	_camera.position = _camera.position.lerp(Vector3(0, 0, _target_zoom), weight)


# --- Input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			_orbiting = event.pressed
		MOUSE_BUTTON_RIGHT:
			_panning = event.pressed
		MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				recentre()
		MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(1.0 / ZOOM_STEP)
		MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(ZOOM_STEP)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _orbiting:
		_orbit(event.relative)
	elif _panning:
		_pan(event.relative)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
	else:
		_touches.erase(event.index)
	# Reset the pinch baseline whenever the finger count changes, or the first frame
	# of a two-finger gesture reads as an enormous zoom.
	_pinch_distance = 0.0


func _handle_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position

	if _touches.size() == 1:
		_orbit(event.relative)
		return

	if _touches.size() >= 2:
		var points: Array = _touches.values()
		var distance: float = (points[0] as Vector2).distance_to(points[1] as Vector2)
		if _pinch_distance > 0.0:
			_zoom_by(_pinch_distance / maxf(1.0, distance))
		_pinch_distance = distance
		# Two fingers moving together pan; moving apart zooms. Both at once is fine.
		_pan(event.relative * 0.5)


func _orbit(motion: Vector2) -> void:
	# Orbiting alone does not surrender auto-framing: the player is choosing an ANGLE,
	# and there is no reason that should also freeze the distance and leave them
	# watching an empty patch of ground once the fight moves.
	_target_yaw -= motion.x * ORBIT_SPEED
	_target_pitch = clampf(_target_pitch + motion.y * ORBIT_SPEED, PITCH_MIN, PITCH_MAX)


## Pans across the ground plane rather than the screen plane, so dragging feels like
## moving the map and not the camera.
func _pan(motion: Vector2) -> void:
	# Panning IS a claim on where the shot sits, so it takes the camera.
	_auto_frame = false
	var yaw: float = deg_to_rad(_target_yaw)
	var right: Vector3 = Vector3(cos(yaw), 0, -sin(yaw))
	var forward: Vector3 = Vector3(sin(yaw), 0, cos(yaw))
	var scale: float = _target_zoom * PAN_SPEED
	_target_focus = _clamp_focus(
		_target_focus - right * motion.x * scale + forward * motion.y * scale)


func _zoom_by(factor: float) -> void:
	_auto_frame = false
	_target_zoom = clampf(_target_zoom * factor, ZOOM_MIN, ZOOM_MAX)


func _clamp_focus(point: Vector3) -> Vector3:
	return Vector3(
		clampf(point.x, -_bounds.x, _bounds.x),
		0.0,
		clampf(point.z, -_bounds.y, _bounds.y))
