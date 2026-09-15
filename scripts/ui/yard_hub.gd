extends Node3D

## The yard hub: the menu as a PLACE you move through, not a document with a 3D wallpaper.
##
## The previous attempt rendered one scene and moved the camera between sections, which
## is not "every tab has its own place" -- it is the same photograph from four angles,
## and it read exactly as cheap as it was. Here each section is a STATION: a real object
## standing somewhere in the yard, with its own silhouette, its own light and its own
## reason to exist in a scrapyard. The camera travels to it and its panel opens beside
## it.
##
## There is no navigation rail and no currency bar. Navigation is the yard. Currencies
## appear only inside a station that spends them, which is why PARTS -- which spends
## nothing, it only fits blueprints a player already owns -- shows none at all.
##
## Built alongside the old hub rather than replacing it. A half-finished 3D hub is worse
## than a working list, so `scenes/ui/hub.tscn` stays reachable and correct until every
## station here exists.

const COL_TEAM := Color("4fa8d8")

## Where the camera rests when no station is selected. Wide enough to see the yard is a
## place, close enough that the stations in it are legible rather than dioramic.
const ESTABLISHING := {
	"pos": Vector3(1.85, 1.06, 2.60),
	"look": Vector3(-0.10, 0.58, -0.30),
	"fov": 42.0,
}

## Screen-space radius, in pixels, within which the pointer counts as being on a station.
## A generous target on purpose: this ships on phones in landscape, where a fingertip is
## about 9 mm and precise 3D picking is not a thing that happens.
const HOVER_RADIUS: float = 190.0

## The service gantry is authored at 2.62 m in the arena kit's own scale. A construct is
## 0.84 m, so at full size the portal stood three times the height of the thing it lifts
## and the machine read as a toy hanging in a building. Two-to-one is the ratio that says
## "this services that".
const GANTRY_SCALE: float = 0.66

var _camera: Camera3D
var _overlay: CanvasLayer
var _label: Control
var _label_name: Label
var _label_purpose: Label
var _panel: PanelContainer
var _panel_body: VBoxContainer
var _back: Button
var _prop_cache: Dictionary = {}

## id -> { name, purpose, anchor (Vector3), shot {pos,look,fov}, marker (Node3D) }
var _stations: Dictionary = {}
var _hovered: String = ""
var _entered: String = ""
var _pulse: float = 0.0

## The construct hanging in the service gantry, and the angle it rests at.
##
## The angle survives a part swap on purpose: comparing two loadouts means seeing both
## from the same side, and a preview that snaps back to front-on every time you fit
## something makes that impossible.
var _slung: Node3D
var _slung_yaw: float = deg_to_rad(202.0)
var _dragging: bool = false


func _ready() -> void:
	_build_environment()
	_build_yard()
	_build_stations()
	_build_overlay()
	_look(ESTABLISHING)
	_maybe_capture()


# --- Interaction -------------------------------------------------------------

func _process(delta: float) -> void:
	_pulse += delta
	if _entered.is_empty():
		_update_hover()
	_animate_markers(delta)


## Hover by screen distance rather than by a physics ray.
##
## Picking a station does not need colliders, and adding them would mean every prop
## carries a shape that exists only so the mouse can find it. Projecting the anchor and
## measuring pixels is exact enough for objects metres apart, and it behaves identically
## under a finger and a cursor.
func _update_hover() -> void:
	var pointer: Vector2 = get_viewport().get_mouse_position()
	var best: String = ""
	var best_distance: float = HOVER_RADIUS
	for id: Variant in _stations:
		var station: Dictionary = _stations[id]
		var anchor: Vector3 = station["anchor"]
		if _camera.is_position_behind(anchor):
			continue
		var screen: Vector2 = _camera.unproject_position(anchor)
		var distance: float = screen.distance_to(pointer)
		if distance < best_distance:
			best_distance = distance
			best = String(id)
	if best != _hovered:
		_hovered = best
		if not best.is_empty():
			Audio.play("ui_move", -22.0)
	_place_label()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT:
			if click.pressed and _entered.is_empty() and not _hovered.is_empty():
				_enter(_hovered)
				return
			# Dragging the yard turns the machine in the cradle. Reaching this handler at
			# all means the pointer was NOT over the panel, so the drag can never fight
			# the catalogue's own scrolling.
			_dragging = click.pressed and _entered == "parts"
			return
	if event is InputEventMouseMotion and _dragging:
		_turn_slung((event as InputEventMouseMotion).relative.x)
		return
	if event is InputEventScreenDrag and _entered == "parts":
		_turn_slung((event as InputEventScreenDrag).relative.x)
		return
	if event.is_action_pressed("ui_cancel") and not _entered.is_empty():
		_leave()


## Positive drag turns the machine to follow the finger. The camera sits in front of the
## gantry looking back at it, so a positive yaw carries the construct's front toward
## screen right -- the same geometry the loadout panel's own drag got backwards once.
func _turn_slung(motion: float) -> void:
	_slung_yaw += motion * 0.011
	if _slung != null and is_instance_valid(_slung):
		_slung.rotation.y = _slung_yaw


func _enter(id: String) -> void:
	_entered = id
	_hovered = ""
	Audio.play("ui_confirm", -14.0)
	_look_to(_stations[id]["shot"])
	_label.visible = false
	_open_panel(id)


func _leave() -> void:
	_entered = ""
	Audio.play("ui_back", -18.0)
	_look_to(ESTABLISHING)
	_panel.visible = false
	_back.visible = false


# --- Camera ------------------------------------------------------------------

func _look(shot: Dictionary) -> void:
	_camera.fov = float(shot["fov"])
	_camera.position = shot["pos"]
	_camera.look_at_from_position(shot["pos"], shot["look"], Vector3.UP)


## Travels rather than cuts. A cut between two views of the same yard reads as a glitch;
## a move tells the player the place is continuous and that they went somewhere.
func _look_to(shot: Dictionary) -> void:
	var target: Vector3 = shot["pos"]
	var look: Vector3 = shot["look"]
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(at: Vector3) -> void:
			_camera.position = at
			_camera.look_at_from_position(at, look, Vector3.UP),
		_camera.position, target, 0.62)
	tween.parallel().tween_property(_camera, "fov", float(shot["fov"]), 0.62)


# --- Stations ----------------------------------------------------------------

func _build_stations() -> void:
	_add_station("parts", "PARTS", "build your constructs",
		Vector3(0.0, 1.05, 0.0),
		# Aimed to the RIGHT of the construct, which pushes it into the left half of the
		# frame -- the half the station panel leaves free. Framing a station centred and
		# then covering it with its own panel is how you end up looking at a machine's
		# knees while editing its arms.
		{"pos": Vector3(0.92, 1.06, 3.05), "look": Vector3(0.66, 0.74, 0.0), "fov": 34.0})


func _add_station(id: String, name: String, purpose: String, anchor: Vector3,
		shot: Dictionary) -> void:
	# A lit ring on the ground under the station. Something has to say "this is a thing
	# you can go to" before the player has hovered anything, and a ring on the floor does
	# it without putting a floating icon over a scrapyard.
	var marker := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.74
	ring.outer_radius = 0.82
	ring.rings = 28
	ring.ring_segments = 6
	marker.mesh = ring
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ffb04a")
	material.emission_enabled = true
	material.emission = Color("ffb04a")
	material.emission_energy_multiplier = 1.4
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker.material_override = material
	marker.position = Vector3(anchor.x, 0.04, anchor.z)
	add_child(marker)

	_stations[id] = {
		"name": name, "purpose": purpose, "anchor": anchor, "shot": shot,
		"marker": marker, "material": material,
	}


func _animate_markers(_delta: float) -> void:
	for id: Variant in _stations:
		var station: Dictionary = _stations[id]
		var material: StandardMaterial3D = station["material"]
		var lit: bool = String(id) == _hovered
		var base: float = 0.34 if _entered.is_empty() else 0.10
		# Breathing, not blinking. A steady ring goes unnoticed on a static screen and a
		# flashing one reads as an error state.
		var breath: float = 0.06 * sin(_pulse * 2.1)
		var alpha: float = (0.95 if lit else base + breath)
		material.albedo_color.a = alpha
		material.emission_energy_multiplier = 2.6 if lit else 1.1


# --- Overlay -----------------------------------------------------------------

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	add_child(_overlay)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.apply(root)
	_overlay.add_child(root)

	# The hover label. Follows the station in screen space, so it reads as belonging to
	# the object rather than as a tooltip the interface decided to show.
	_label = PanelContainer.new()
	_label.visible = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label_style := UIKit.card(UIKit.SURFACE, UIKit.RADIUS_CONTROL,
		UIKit.SPACE_LG, UIKit.SPACE_SM)
	label_style.border_color = UIKit.AMBER
	_label.add_theme_stylebox_override("panel", label_style)
	root.add_child(_label)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 0)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_child(stack)
	_label_name = _text("", UIKit.SIZE_HEADING, UIKit.TEXT)
	_label_purpose = _text("", UIKit.SIZE_LABEL, UIKit.TEXT_DIM)
	stack.add_child(_label_name)
	stack.add_child(_label_purpose)

	# The station panel: anchored to one side, never full screen. A panel that covers the
	# view puts the player back in a document and throws away the place they walked to.
	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_panel.offset_left = -880.0
	_panel.offset_right = -24.0
	_panel.offset_top = 24.0
	_panel.offset_bottom = -24.0
	var panel_style := UIKit.card(UIKit.SURFACE, UIKit.RADIUS_CARD,
		UIKit.SPACE_LG, UIKit.SPACE_LG)
	panel_style.bg_color = Color(UIKit.SURFACE.r, UIKit.SURFACE.g, UIKit.SURFACE.b, 0.96)
	_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(_panel)

	_panel_body = VBoxContainer.new()
	_panel_body.add_theme_constant_override("separation", UIKit.SPACE_MD)
	_panel.add_child(_panel_body)

	# Leaving the yard entirely. Without it the only way out of a half-built hub is to
	# kill the process, which is not a state to leave a player in.
	var quit := Button.new()
	quit.text = "◀  HUB"
	quit.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	quit.offset_left = -150.0
	quit.offset_right = -24.0
	quit.offset_top = 24.0
	quit.custom_minimum_size = Vector2(126, 44)
	quit.add_theme_stylebox_override("normal", UIKit.secondary())
	quit.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/ui/hub.tscn"))
	root.add_child(quit)

	_back = Button.new()
	_back.visible = false
	_back.text = "◀  THE YARD"
	_back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_back.offset_left = 24.0
	_back.offset_top = 24.0
	_back.custom_minimum_size = Vector2(180, 44)
	_back.add_theme_stylebox_override("normal", UIKit.secondary())
	_back.pressed.connect(_leave)
	root.add_child(_back)


func _place_label() -> void:
	if _hovered.is_empty():
		_label.visible = false
		return
	var station: Dictionary = _stations[_hovered]
	_label_name.text = String(station["name"])
	_label_purpose.text = String(station["purpose"])
	_label.visible = true
	var screen: Vector2 = _camera.unproject_position(station["anchor"])
	# Centred over the anchor and lifted clear of it, so the label never covers the thing
	# it is naming.
	_label.position = screen - Vector2(_label.size.x * 0.5, _label.size.y + 26.0)


func _open_panel(id: String) -> void:
	for child: Node in _panel_body.get_children():
		child.queue_free()
	_panel.visible = true
	_back.visible = true

	var station: Dictionary = _stations[id]
	_panel_body.add_child(_text(String(station["name"]), UIKit.SIZE_DISPLAY, UIKit.TEXT))
	_panel_body.add_child(_text(String(station["purpose"]), UIKit.SIZE_LABEL,
		UIKit.TEXT_DIM))

	match id:
		"parts":
			var loadout := LoadoutScreen.new()
			# The machine in the gantry IS this screen's preview. The panel draws none of
			# its own, and every fit rebuilds the construct hanging two metres away.
			loadout.external_preview = true
			loadout.preview_changed.connect(_set_slung_construct)
			loadout.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_panel_body.add_child(loadout)


func _text(value: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# --- Scene -------------------------------------------------------------------

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("0d1017")
	sky_material.sky_horizon_color = Color("39312e")
	sky_material.sky_curve = 0.18
	sky_material.ground_bottom_color = Color("0c0a09")
	sky_material.ground_horizon_color = Color("332820")
	sky_material.ground_curve = 0.08
	sky_material.energy_multiplier = 0.7
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.35
	environment.ambient_light_color = Color("2f3a52")
	environment.ambient_light_energy = 1.05
	environment.fog_enabled = true
	environment.fog_light_color = Color("241f26")
	environment.fog_light_energy = 0.7
	environment.fog_sun_scatter = 0.10
	environment.fog_density = 0.022
	environment.fog_sky_affect = 0.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.05
	environment.tonemap_white = 3.0
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.12
	environment.glow_enabled = true
	environment.glow_intensity = 0.34
	environment.glow_bloom = 0.10
	environment.glow_hdr_threshold = 1.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.environment = environment
	add_child(env)

	# The yard's own moonlight: cold, weak, and the only thing lighting the ground away
	# from a lamp. The WARM light in this scene comes from the station fixtures, not from
	# a global key -- that is what makes travelling to a station read as arriving
	# somewhere lit rather than as panning across an evenly-lit set.
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-38, -28, 0)
	moon.light_energy = 0.95
	moon.light_color = Color("8aa3de")
	moon.shadow_enabled = true
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	moon.directional_shadow_max_distance = 32.0
	moon.shadow_bias = 0.04
	moon.shadow_normal_bias = 1.4
	add_child(moon)

	_camera = Camera3D.new()
	add_child(_camera)


func _build_yard() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color("221b16")
	dirt.roughness = 0.98
	dirt.metallic = 0.0
	ground.material_override = dirt
	add_child(ground)

	# The wall that makes this a yard rather than a plain. Behind the stations and only
	# behind: a full enclosure would put steel between the camera and everything.
	for index: int in 11:
		var hash_value: int = _scatter(index * 7 + 3)
		var container: Node3D = _prop("container_%d" % (hash_value % 2))
		if container == null:
			continue
		container.position = Vector3(-15.0 + 3.1 * index, 0.0, -11.0 - float(hash_value % 4))
		container.rotation.y = deg_to_rad(float(hash_value % 7) - 3.0)
		add_child(container)
		if hash_value % 3 == 0:
			var stacked: Node3D = _prop("container_%d" % ((hash_value + 1) % 2))
			if stacked != null:
				stacked.position = container.position + Vector3(0.0, 2.55, 0.0)
				stacked.rotation.y = container.rotation.y + deg_to_rad(2.0)
				add_child(stacked)

	for entry: Variant in [[Vector3(-13.5, 0.0, -19.0), 24.0], [Vector3(12.0, 0.0, -23.0), -16.0]]:
		var pair: Array = entry as Array
		var gantry: Node3D = _prop("gantry")
		if gantry != null:
			gantry.position = pair[0]
			gantry.rotation.y = deg_to_rad(float(pair[1]))
			add_child(gantry)

	for entry: Variant in [["car_stack_0", Vector3(-6.4, 0.0, -4.6)],
			["tyre_stack_0", Vector3(5.6, 0.0, -4.0)],
			["car_stack_2", Vector3(7.8, 0.0, -7.4)],
			["tyre_stack_0", Vector3(-7.9, 0.0, -7.2)]]:
		var pair: Array = entry as Array
		var prop: Node3D = _prop(String(pair[0]))
		if prop == null:
			continue
		prop.position = pair[1]
		prop.rotation.y = deg_to_rad(float(_scatter(int((pair[1] as Vector3).x * 10.0)) % 90))
		add_child(prop)

	_build_parts_station()


## The Parts station: a service gantry with the player's lead construct slung in it.
func _build_parts_station() -> void:
	var gantry: Node3D = _prop("service_gantry")
	if gantry != null:
		gantry.position = Vector3.ZERO
		gantry.scale = Vector3.ONE * GANTRY_SCALE
		add_child(gantry)

	# The work lamps are real lights, not just emissive geometry. Emissive alone makes a
	# lamp that glows but lights nothing, and the whole point of the station is that the
	# machine in it is the brightest thing on screen.
	for side: Variant in [-1.0, 1.0]:
		var lamp := SpotLight3D.new()
		lamp.position = Vector3(float(side) * 0.49, 1.52, 0.20)
		lamp.rotation_degrees = Vector3(-58.0, float(side) * 14.0, 0.0)
		lamp.light_color = Color("ffc98a")
		lamp.light_energy = 0.95
		lamp.spot_range = 6.0
		lamp.spot_angle = 42.0
		lamp.spot_angle_attenuation = 0.7
		lamp.shadow_enabled = false
		add_child(lamp)

	var pool := OmniLight3D.new()
	pool.position = Vector3(0.0, 1.05, 0.10)
	pool.light_color = Color("ffb87a")
	pool.light_energy = 0.62
	pool.omni_range = 3.8
	pool.shadow_enabled = false
	add_child(pool)

	var squad: Array = Session.profile().squad("main")
	if squad.is_empty():
		return
	var parts: Dictionary = (squad[0] as Dictionary).get("parts", {}) as Dictionary
	var ids: PackedStringArray = []
	for slot: String in ["chassis", "core", "arm_l", "arm_r", "module"]:
		ids.append(String(parts.get(slot, "")))
	_set_slung_construct(ids)


## Hangs a construct in the gantry, replacing whatever was there.
##
## This is the Parts panel's preview. Fitting a part rebuilds the machine in the cradle
## rather than a thumbnail of it, which is the difference between a station and a
## background: the object you are editing is the object in front of you, at full size,
## under the bay's own lights.
func _set_slung_construct(part_ids: PackedStringArray) -> void:
	if _slung != null and is_instance_valid(_slung):
		_slung.queue_free()
	_slung = null
	if part_ids.is_empty() or String(part_ids[0]).is_empty():
		return

	var unit := SimUnit.new()
	unit.unit_ref = 0
	unit.team = SimDefs.TEAM_A
	unit.part_ids = part_ids

	_slung = ConstructView.build(unit, Session.content, COL_TEAM)
	# Slung, not standing. Feet clear of the ground under the spreader bar is the whole
	# reason the gantry reads as a workshop instead of as a doorway the machine happens
	# to be standing in.
	_slung.position = Vector3(0.0, 0.40, -0.11)
	_slung.rotation.y = _slung_yaw
	add_child(_slung)


func _prop(name: String) -> Node3D:
	if not _prop_cache.has(name):
		var path: String = "res://art/arena/%s.glb" % name
		_prop_cache[name] = load(path) if ResourceLoader.exists(path) else null
	var packed: PackedScene = _prop_cache[name]
	if packed == null:
		return null
	var prop: Node3D = packed.instantiate() as Node3D
	for mesh: MeshInstance3D in ConstructView.meshes_of(prop):
		if mesh.mesh == null:
			continue
		for surface: int in mesh.mesh.get_surface_count():
			var zone: String = PartMaterials.zone_of(mesh.mesh.surface_get_material(surface))
			mesh.set_surface_override_material(surface, _scenery_material(zone))
	return prop


static var _scenery_cache: Dictionary = {}


func _scenery_material(zone: String) -> StandardMaterial3D:
	if _scenery_cache.has(zone):
		return _scenery_cache[zone]
	var source: StandardMaterial3D = PartMaterials.for_zone(zone, COL_TEAM)
	var dimmed: StandardMaterial3D = source.duplicate()
	if not zone.begins_with("glow"):
		dimmed.albedo_color = source.albedo_color.darkened(0.44)
		dimmed.rim_enabled = false
	_scenery_cache[zone] = dimmed
	return dimmed


static func _scatter(index: int) -> int:
	var h: int = (index * 2654435761) & 0x7fffffff
	h ^= (h >> 13)
	return (h * 1274126177) & 0x7fffffff


## Dev: `--shot <path> [--station id] [--after n]`, the same contract the other scenes use.
func _maybe_capture() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find("--shot")
	if index < 0 or index + 1 >= args.size():
		return
	var station: int = args.find("--station")
	if station >= 0 and station + 1 < args.size():
		_enter(args[station + 1])
	var frames: int = 40
	var after: int = args.find("--after")
	if after >= 0 and after + 1 < args.size():
		frames = maxi(3, int(args[after + 1]))
	for _i: int in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(args[index + 1])
	get_tree().quit()
