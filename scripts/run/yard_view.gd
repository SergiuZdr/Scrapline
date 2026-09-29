class_name YardView
extends Node3D

## The region as a place you travel through (play-tests 3 and 4).
##
## A camera close over the yard, following the crew -- three machines standing on the site
## they are at and walking the road when they travel. Everything not yet scouted is under
## fog; the gate's beacon shows through it. Each site is a landmark from the arena kit on a
## pad whose ring says what it is to you (amber here, blue reachable, grey done). The
## Reclaimer is a wall of harvester rigs across the map with red beacons over red dust,
## the ground behind it stripped; a ghost of it stands where it will be next, brighter as
## that gets closer. Its scout drones sweep searchlights over the yard; wrecks smoke; a
## dead-industry skyline stands behind it all.
##
## Display only: it is told the state and asked where things are on screen. The map screen
## does the input and every rule question goes to `RunSim`.

const SPACING_X: float = 8.5       # metres between columns
const DEPTH: float = 30.0          # metres across the rows (site y 0..100)
const RECLAIMER_RED := Color("ff3b24")
## Ink & Rust (016): the rings are signals -- amber where the crew is (your action), your blue
## where it can go, grey for the rest.
const RING_HERE := Color("ffc43d")
const RING_GO := Color("33c8e0")
const RING_DONE := Color("4a4a50")
const RING_FAR := Color("7c7a78")
## Each site's landmark wears one livery, so a kind of place has a colour of its own.
const SITE_LIVERY: Dictionary = {"start": Color("d9a441"), "skirmish": Color("8a8f8c"), "elite": Color("9c3b2e"),
	"scrapyard": Color("b4532a"), "workshop": Color("d9a441"), "trader": Color("6e7443"),
	"tower": Color("8a8f8c"), "signal": Color("6e7443"), "boss": Color("2a2628")}
const LANDMARK_SCALE: float = 0.46
const PICK_RADIUS: float = 70.0
const PITCH_DEG: float = 56.0
const ZOOM_MIN: float = 15.0
const ZOOM_MAX: float = 46.0
const ZOOM_DEFAULT: float = 32.0
const CREW_SCALE: float = 2.0
const WALK_SPEED: float = 5.0      # metres a second on the road
const SIGHT: float = 9.5           # metres of fog cleared around a scouted site
const FOG_PX_PER_M: float = 0.5   # the shader filters it; a finer mask only costs time
## Where the three stand on a site: in front of its landmark, toward the camera.
const FORMATION: Array = [Vector3(-1.1, 0, 1.3), Vector3(1.1, 0, 1.3), Vector3(0.0, 0, 1.9)]

var _state: RunState
## Content, handed in (a display class must not reach for the `Run` autoload: a `--script`
## tool that names this class compiles it before autoloads exist).
var _db: ContentDB
var _setup_every: int = 2
var _columns: int = 9
var _camera: Camera3D
var _focus := Vector3.ZERO
var _focus_goal := Vector3.ZERO
var _zoom: float = ZOOM_DEFAULT
var _zoom_goal: float = ZOOM_DEFAULT
var _follow: bool = true
var _sites: Dictionary = {}        # id -> { "root", "ring", "icon", "landmark", "type", "smoke" }
var _roads: Node3D
var _road_marks: Node3D
var _reclaimer: Node3D
var _ghost: Node3D
var _ghost_material: StandardMaterial3D
var _reclaimed: MeshInstance3D
var _next_zone: MeshInstance3D
var _next_material: StandardMaterial3D
var _front_x: float = 0.0
var _hover: int = -1
var _urgent: bool = false
var _hover_triggers: bool = false
var _time: float = 0.0
var _materials: Dictionary = {}
var _crew: Array[Dictionary] = []  # { "root", "rig", "key" }
var _walking: bool = false
var _fog_image: Image
var _fog_texture: ImageTexture
var _fog_rect: Rect2
var _fog_planes: Array[MeshInstance3D] = []
## What the fog was last painted for; it is repainted only when that changes.
var _fog_key: String = ""
var _drones: Array[Dictionary] = []
## Roads and loose junk, each with what decides whether it is out of the fog.
var _road_nodes: Array[Dictionary] = []    # { "node", "a", "b" } site ids
var _clutter_nodes: Array[Node3D] = []
var _blinkers: Array[StandardMaterial3D] = []


## Builds the yard once for this run's region. `every`: moves between the front's steps.
func build(state: RunState, columns: int, every: int, db: ContentDB) -> void:
	_state = state
	_db = db
	_columns = columns
	_setup_every = maxi(1, every)
	_build_world()
	_build_ground()
	_build_skyline()
	_roads = Node3D.new()
	add_child(_roads)
	_road_marks = Node3D.new()
	add_child(_road_marks)
	for site: Dictionary in state.sites:
		_build_site(site)
	_build_roads()
	_build_clutter()
	_build_reclaimer()
	_build_drones()
	_build_fog()
	_front_x = _front_target()
	_place_front(_front_x)
	_focus = _crew_centre(state.current)
	_focus_goal = _focus
	_place_camera()


## Re-colours the yard for the state now; the Reclaimer slides to its new front; the fog
## lifts wherever the crew can now see.
func refresh(state: RunState, targets: Array[int], hover: int) -> void:
	_state = state
	_hover = hover
	for id: int in _sites:
		_style_site(id, targets)
	_mark_roads(targets)
	var left: int = _setup_every - state.moves % _setup_every
	_urgent = left == 1
	_hover_triggers = _urgent and hover >= 0 and targets.has(hover)
	var goal: float = _front_target()
	if not is_equal_approx(goal, _front_x):
		var tween := create_tween()
		tween.tween_method(_place_front, _front_x, goal, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_front_x = goal
	else:
		_place_front(_front_x)
	_update_fog()
	if _follow and not _walking:
		_focus_goal = _crew_centre(state.current)


## The crew as machines on the map: rebuilt when a machine's parts, level or life change.
func set_crew(crew: Array) -> void:
	var alive: Array[int] = []
	for i: int in crew.size():
		if bool((crew[i] as Dictionary)["alive"]):
			alive.append(i)
	while _crew.size() > alive.size():
		(_crew.pop_back()["root"] as Node3D).queue_free()
	for slot: int in alive.size():
		var member: Dictionary = crew[alive[slot]]
		var key: String = "%s:%d" % [",".join(member["parts"]), int(member.get("level", 0))]
		if slot < _crew.size() and String(_crew[slot]["key"]) == key:
			continue
		if slot < _crew.size():
			(_crew[slot]["root"] as Node3D).queue_free()
		var root := Node3D.new()
		add_child(root)
		var model: Node3D = ConstructView.build_parts(PackedStringArray(member["parts"]), _db,
			Color("4fa8d8"), int(member.get("level", 0)), alive[slot] + 1)
		Ink.dress_machine(model, PackedStringArray(member["parts"]), Ink.YOURS)
		model.scale = Vector3.ONE * CREW_SCALE
		root.add_child(model)
		var rig := ConstructRig.new()
		rig.bind(model)
		var entry: Dictionary = {"root": root, "rig": rig, "key": key}
		if slot < _crew.size():
			_crew[slot] = entry
		else:
			_crew.append(entry)
	if not _walking:
		_stand_crew(_state.current)


## Walks the crew down the road from one site to the next. The map waits for it.
func travel(from: int, to: int) -> void:
	_walking = true
	_follow = true
	var a: Vector3 = site_world(from)
	var b: Vector3 = site_world(to)
	var flat := Vector3(b.x - a.x, 0, b.z - a.z)
	var seconds: float = clampf(flat.length() / WALK_SPEED, 0.8, 2.6)
	var yaw: float = atan2(flat.x, flat.z)
	var tween := create_tween().set_parallel(true)
	for slot: int in _crew.size():
		var root: Node3D = _crew[slot]["root"]
		var offset: Vector3 = FORMATION[slot % FORMATION.size()]
		root.rotation.y = yaw
		(_crew[slot]["rig"] as ConstructRig).set_moving(true)
		# The leader goes first; the others follow a beat behind.
		tween.tween_property(root, "position", b + offset, seconds).set_delay(0.12 * float(slot)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	while tween.is_running():
		_focus_goal = _crew_lead_position()
		await get_tree().process_frame
	for entry: Dictionary in _crew:
		(entry["rig"] as ConstructRig).set_moving(false)
	_walking = false


func site_world(id: int) -> Vector3:
	var site: Dictionary = _state.site(id)
	return _map_point(float(site["x"]), float(site["y"]))


## Where site `id` is on screen (its pad), for labels and picking.
func screen_pos(id: int, lift: float = 0.0) -> Vector2:
	return _camera.unproject_position(site_world(id) + Vector3(0, lift, 0))


## Just below a site's pad on screen, where its label goes.
func label_pos(id: int) -> Vector2:
	return _camera.unproject_position(site_world(id) + Vector3(0, 0, 1.7))


## The site under a screen point, or -1. Sites still under fog cannot be picked.
func pick(point: Vector2) -> int:
	var best: int = -1
	var best_d: float = PICK_RADIUS
	for id: int in _sites:
		if not RunSim.revealed(_state, id):
			continue
		for lift: float in [0.0, 1.6]:
			var d: float = screen_pos(id, lift).distance_to(point)
			if d < best_d:
				best_d = d
				best = id
	return best


## Looking around: drag, keys and wheel move the camera; the crew stays where it is.
func pan(screen_delta: Vector2) -> void:
	var per_px: float = 2.0 * _zoom * tan(deg_to_rad(_camera.fov * 0.5)) / maxf(1.0, get_viewport().get_visible_rect().size.y)
	_focus_goal += Vector3(-screen_delta.x * per_px, 0, -screen_delta.y * per_px / sin(deg_to_rad(PITCH_DEG)))
	_follow = false
	_clamp_focus()


func zoom_by(step: float) -> void:
	_zoom_goal = clampf(_zoom_goal + step, ZOOM_MIN, ZOOM_MAX)


func recentre() -> void:
	_follow = true
	_focus_goal = _crew_centre(_state.current)


## Snaps the camera to where it is heading (screenshots and tests, which do not wait).
func settle_camera() -> void:
	_focus = _focus_goal
	_zoom = _zoom_goal
	_place_camera()


func _process(delta: float) -> void:
	_time += delta
	for entry: Dictionary in _crew:
		(entry["rig"] as ConstructRig).update(delta)
	var k: float = 1.0 - exp(-delta * 5.0)
	_focus = _focus.lerp(_focus_goal, k)
	_zoom = lerpf(_zoom, _zoom_goal, k)
	_place_camera()
	if _next_material != null:
		_next_material.albedo_color.a = 0.10 + 0.08 * sin(_time * 2.4)
	if _ghost_material != null:
		var strength: float = 0.5 if _hover_triggers else (0.3 if _urgent else 0.1)
		var pulse: float = (0.5 + 0.5 * sin(_time * (6.0 if _hover_triggers else 3.0))) if _urgent else 0.5
		_ghost_material.albedo_color.a = strength * (0.55 + 0.45 * pulse)
	for id: int in _sites:
		var icon: Sprite3D = _sites[id]["icon"]
		if icon != null:
			icon.position.y = 2.25 + (0.1 * sin(_time * 2.0 + float(id)) if id == _hover else 0.0)
	for drone: Dictionary in _drones:
		_fly(drone)
	var on: bool = fmod(_time, 1.6) < 0.18
	for blink: StandardMaterial3D in _blinkers:
		blink.emission_energy_multiplier = 5.0 if on else 0.3


# --- World --------------------------------------------------------------------

func _build_world() -> void:
	# Ink & Rust (016): the fight's light -- a flat night, one hard key from the camera's left.
	var env := WorldEnvironment.new()
	env.environment = Ink.environment(Color("10131a"))
	add_child(env)
	add_child(Ink.key_light(Vector3(-48, -36, 0), 110.0))

	_camera = Camera3D.new()
	_camera.fov = 38.0
	_camera.far = 400.0
	add_child(_camera)
	_camera.current = true


func _place_camera() -> void:
	var pitch: float = deg_to_rad(PITCH_DEG)
	_camera.position = _focus + Vector3(0.0, sin(pitch) * _zoom, cos(pitch) * _zoom)
	_camera.look_at(_focus, Vector3.UP)


func _clamp_focus() -> void:
	var width: float = SPACING_X * float(_columns - 1)
	_focus_goal.x = clampf(_focus_goal.x, -width * 0.5 - 6.0, width * 0.5 + 6.0)
	_focus_goal.z = clampf(_focus_goal.z, -DEPTH * 0.5, DEPTH * 0.5)


func _build_ground() -> void:
	var width: float = SPACING_X * float(_columns - 1)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(width + 140.0, DEPTH + 120.0)
	ground.mesh = plane
	# The yard floor: night ground with a drawn grain.
	ground.material_override = Ink.patterned(Color("20232b"), 2, Color("1a1d24"), 1.1, 0.22)
	add_child(ground)
	# The zones: a faint seam between columns and a name on the far edge.
	for col: int in _columns:
		var x: float = _column_x(col)
		if col > 0:
			var seam := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.1, 0.02, DEPTH + 6.0)
			seam.mesh = box
			seam.position = Vector3(x - SPACING_X * 0.5, 0.01, 0.0)
			seam.material_override = Ink.flat(Color("2c2f38"))
			add_child(seam)
		var name := Label3D.new()
		name.text = "CAMP" if col == 0 else ("GATE" if col == _columns - 1 else "ZONE %d" % (col + 1))
		name.font = UIKit.font_comic()
		name.font_size = 96
		name.pixel_size = 0.012
		name.modulate = Color(Ink.PAPER, 0.5)
		name.outline_size = 0
		name.rotation_degrees = Vector3(-90, 0, 0)
		name.position = Vector3(x, 0.03, -DEPTH * 0.5 - 2.2)
		add_child(name)

	_reclaimed = MeshInstance3D.new()
	_reclaimed.mesh = PlaneMesh.new()
	# Reclaimed ground: taken, and drawn as such -- hatched in the danger red.
	_reclaimed.material_override = Ink.patterned(Color("2a1614"), 2, Color("6a1f17"), 1.4, 0.3)
	add_child(_reclaimed)
	_next_zone = MeshInstance3D.new()
	var next_plane := PlaneMesh.new()
	next_plane.size = Vector2(SPACING_X, DEPTH + 6.0)
	_next_zone.mesh = next_plane
	_next_material = StandardMaterial3D.new()
	_next_material.albedo_color = Color(RECLAIMER_RED, 0.12)
	_next_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_next_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_next_zone.material_override = _next_material
	add_child(_next_zone)


## The dead valley around the yards: factory blocks, chimneys and tanks as dark shapes on
## the horizon, red lamps blinking on the stacks, and the Crucible's glow beyond the gate
## (the story: "the Crucible's glow on the clouds"). Kenney's CC0 shapes, re-materialed:
## their own toy palette is never seen (art-sourcing.md).
func _build_skyline() -> void:
	var width: float = SPACING_X * float(_columns - 1)
	var names: PackedStringArray = ["building-a", "building-c", "building-f", "building-q", "water-tower", "detail-tank-large", "chimney-large"]
	var dark: Material = Ink.toon(Color("121419"), "clean")
	var x: float = -width * 0.5 - 18.0
	var i: int = 0
	while x < width * 0.5 + 24.0:
		var name: String = names[_h(i, 5) % names.size()]
		var packed: PackedScene = load("res://art/thirdparty/kenney/city-kit-industrial/%s.glb" % name)
		if packed != null:
			var block: Node3D = packed.instantiate()
			for mesh: MeshInstance3D in ConstructView.meshes_of(block):
				mesh.material_override = dark
				Ink.line(mesh, Ink.LINE_WORLD * 0.7, Color("252a38"))
			var s: float = 4.5 + float(_h(i, 9) % 100) / 40.0
			block.scale = Vector3.ONE * s
			block.position = Vector3(x, 0, -DEPTH * 0.5 - 20.0 - float(_h(i, 13) % 100) / 12.0)
			block.rotation.y = float(_h(i, 17) % 4) * PI * 0.5
			add_child(block)
			if name.begins_with("chimney") or name == "water-tower" or i % 3 == 0:
				var lamp := MeshInstance3D.new()
				var ball := SphereMesh.new()
				ball.radius = 0.35
				ball.height = 0.7
				lamp.mesh = ball
				var blink := StandardMaterial3D.new()
				blink.albedo_color = RECLAIMER_RED
				blink.emission_enabled = true
				blink.emission = RECLAIMER_RED
				blink.emission_energy_multiplier = 0.3
				lamp.material_override = blink
				_blinkers.append(blink)
				lamp.position = block.position + Vector3(0, _model_height(block) * s + 0.5, 0)
				add_child(lamp)
		x += 9.0 + float(_h(i, 21) % 60) / 10.0
		i += 1



## The unscaled height of a prop from its meshes' own bounds (it is not in the tree yet).
func _model_height(node: Node3D) -> float:
	var top: float = 0.0
	for mesh: MeshInstance3D in ConstructView.meshes_of(node):
		top = maxf(top, mesh.get_aabb().end.y)
	return top


# --- Sites --------------------------------------------------------------------

func _build_site(site: Dictionary) -> void:
	var id: int = int(site["id"])
	var root := Node3D.new()
	root.position = site_world(id)
	add_child(root)
	var pad := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.35
	disc.bottom_radius = 1.5
	disc.height = 0.16
	pad.mesh = disc
	pad.position.y = 0.08
	pad.material_override = Ink.toon(Color("3a3b41"))
	Ink.line(pad, Ink.LINE_WORLD)
	root.add_child(pad)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.38
	torus.outer_radius = 1.55
	ring.mesh = torus
	ring.position.y = 0.17
	ring.scale = Vector3(1, 0.5, 1)
	ring.material_override = Ink.flat(RING_FAR)
	Ink.line(ring, Ink.LINE_WORLD)
	root.add_child(ring)
	var icon := Sprite3D.new()
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.pixel_size = 0.009
	icon.no_depth_test = true
	icon.shaded = false
	icon.render_priority = 10
	icon.position.y = 2.25
	root.add_child(icon)
	# The glyph on an ink disc: a badge, readable over anything behind it.
	var badge := Sprite3D.new()
	badge.texture = _disc_texture()
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	badge.pixel_size = 0.0145
	badge.no_depth_test = true
	badge.shaded = false
	badge.render_priority = 9
	badge.name = "disc"
	icon.add_child(badge)
	_sites[id] = {"root": root, "ring": ring, "icon": icon, "landmark": null, "type": "", "smoke": null}
	if String(site["type"]) == "boss":
		# The gate's beacon: the one thing that shows through the fog, so the goal is always
		# on the horizon.
		var beam := MeshInstance3D.new()
		var column := CylinderMesh.new()
		column.top_radius = 0.25
		column.bottom_radius = 0.6
		column.height = 22.0
		beam.mesh = column
		beam.position.y = 11.0
		var beam_material := StandardMaterial3D.new()
		beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		beam_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		beam_material.albedo_color = Color(1.0, 0.35, 0.2, 0.35)
		beam_material.render_priority = 5
		beam.material_override = beam_material
		root.add_child(beam)


func _style_site(id: int, targets: Array[int]) -> void:
	var entry: Dictionary = _sites[id]
	var site: Dictionary = _state.site(id)
	var known: bool = RunSim.revealed(_state, id)
	var root: Node3D = entry["root"]
	# Not scouted: nothing stands there but fog -- not even its pad, which would give its
	# place away. The gate stays (its beacon is the goal on the horizon).
	root.visible = known or String(site["type"]) == "boss"
	(entry["ring"] as MeshInstance3D).visible = known
	(entry["icon"] as Sprite3D).visible = known
	var type: String = String(site["type"]) if known else "?"
	if String(entry["type"]) != type:
		entry["type"] = type
		if entry["landmark"] != null:
			(entry["landmark"] as Node3D).queue_free()
		entry["landmark"] = null
		if known:
			var landmark: Node3D = _landmark(type, id)
			root.add_child(landmark)
			entry["landmark"] = landmark
		var icon: Sprite3D = entry["icon"]
		var icon_name: String = String(_ICONS.get(type, ""))
		icon.texture = load("res://art/icons/%s.svg" % icon_name) if not icon_name.is_empty() else null
	var colour: Color = RING_FAR
	var glow: float = 0.4
	if id == _state.current:
		colour = RING_HERE
		glow = 2.2
	elif targets.has(id):
		colour = RING_GO
		glow = 2.6 if id == _hover else 1.4
	elif bool(site["visited"]):
		colour = RING_DONE
		glow = 0.2
	# Flat signal colour, a touch of glow only where the crew is or could go.
	(entry["ring"] as MeshInstance3D).material_override = Ink.glow(colour, 0.35 if glow >= 1.4 else 0.0)
	var icon: Sprite3D = entry["icon"]
	var faded: bool = _state.consumed(id) or (bool(site["visited"]) and id != _state.current)
	icon.modulate = Color(Ink.PAPER, 0.45) if faded else Ink.PAPER
	icon.pixel_size = 0.012 if id == _hover else 0.009
	var disc: Sprite3D = icon.get_node_or_null("disc")
	if disc != null:
		# The disc's ring says what the ring on the ground says.
		disc.modulate = Color(colour, 0.6) if faded else colour
		disc.pixel_size = icon.pixel_size * 1.6
	# A cleared fight leaves its wrecks smoking.
	var fought: bool = bool(site["visited"]) and ["skirmish", "elite", "boss"].has(String(site["type"])) and id != 0
	if fought and entry["smoke"] == null:
		entry["smoke"] = _smoke(root)


const _ICONS: Dictionary = {"start": "yard", "skirmish": "fight", "elite": "colossus",
	"scrapyard": "scrap", "workshop": "foundry", "boss": "gauntlet",
	"trader": "store", "tower": "yardview", "signal": "doctrine"}


## What stands on a site. Built from the arena kit, so the map is made of the same
## things the fights are.
func _landmark(type: String, id: int) -> Node3D:
	var root := Node3D.new()
	_livery = SITE_LIVERY.get(type, Ink.STEEL)
	match type:
		"start":
			_prop(root, "container_0", Vector3(-0.3, 0, -0.9), 12.0)
			_prop(root, "container_1", Vector3(0.2, 0, 0.5), -8.0)
			_lamp(root, Vector3(1.1, 0, -0.2), Color("ffc27a"), 3.0)
		"skirmish":
			_prop(root, "car_stack_0", Vector3(-0.4, 0, -0.3), float(_h(id, 1) % 60))
			_prop(root, "tyre_stack_0", Vector3(0.8, 0, 0.6), 0.0)
		"elite":
			_prop(root, "car_stack_2", Vector3(-0.3, 0, -0.2), 20.0, 0.62)
			_prop(root, "car_stack_0", Vector3(0.7, 0, 0.7), -30.0)
		"scrapyard":
			_prop(root, "tyre_stack_1", Vector3(-0.6, 0, -0.3), 0.0)
			_prop(root, "tyre_stack_2", Vector3(0.5, 0, -0.5), 0.0)
			_prop(root, "car_stack_1", Vector3(0.1, 0, 0.6), 70.0)
		"workshop":
			# 017: a generated landmark (route C) when the new models are asked for; its work
			# lamp hangs over the roof, where the kit's hung inside the gantry.
			if _generated(root, "workshop", 35.0):
				_lamp(root, Vector3(0.0, 1.1, 0.0), Color("ffc27a"), 4.0)
			else:
				_prop(root, "service_gantry", Vector3(0, 0, 0), 90.0, 0.6)
				_lamp(root, Vector3(0.0, 0, 0.0), Color("ffc27a"), 4.0)
		"trader":
			# A container shop: doors open, a warm lamp over the counter.
			_prop(root, "container_0", Vector3(-0.2, 0, -0.3), 25.0, 0.62)
			_prop(root, "tyre_stack_0", Vector3(0.9, 0, 0.5), 0.0)
			_lamp(root, Vector3(0.4, 0, 0.4), Color("ffd08a"), 3.5)
		"tower":
			# A lookout: the tallest thing near the road, lit at the top.
			_prop(root, "floodlight", Vector3(0, 0, 0), float(_h(id, 2) % 90), 1.1)
			_prop(root, "barrier_0", Vector3(0.7, 0, 0.5), 30.0)
		"signal":
			# Something out of place by the road, and a blinking mast over it.
			_prop(root, "car_stack_1", Vector3(-0.4, 0, 0.2), float(_h(id, 3) % 120), 0.55)
			_prop(root, "floodlight", Vector3(0.6, 0, -0.4), 180.0, 0.7)
			_lamp(root, Vector3(0.6, 0, -0.4), Color("9ad0ff"), 2.5)
		"boss":
			_prop(root, "gantry", Vector3(0, 0, 0), 0.0, 0.7)
			for i: int in 4:
				_prop(root, "barrier_%d" % (i % 2), Vector3(0.0, 0, -2.6 - float(i) * 0.8), 90.0, 0.8)
				_prop(root, "barrier_%d" % ((i + 1) % 2), Vector3(0.0, 0, 2.6 + float(i) * 0.8), 90.0, 0.8)
			_lamp(root, Vector3(0.0, 0, 0.0), RECLAIMER_RED, 3.0)
	_livery = Color(0, 0, 0, 0)
	return root


## The livery the landmark being built wears (016); clear while building clutter.
var _livery: Color = Color(0, 0, 0, 0)


## A generated set piece (`Models.site`, 017) in place of the kit landmark: built at map size
## by `tools/blender/clean_generated.py` and zoned like the kit, so it is dressed the same way.
func _generated(parent: Node3D, kind: String, yaw: float) -> bool:
	var packed: PackedScene = Models.site(kind)
	if packed == null:
		return false
	var piece: Node3D = packed.instantiate() as Node3D
	piece.rotation_degrees.y = yaw
	Ink.dress_prop(piece, _livery)
	parent.add_child(piece)
	return true


func _prop(parent: Node3D, name: String, at: Vector3, yaw: float, scale_by: float = LANDMARK_SCALE,
		dim: float = 0.12) -> Node3D:
	var prop: Node3D = Surfaces.kit(name, dim)
	if prop == null:
		return null
	prop.position = at
	prop.rotation_degrees.y = yaw
	prop.scale = Vector3.ONE * scale_by
	# A landmark is a place, drawn in its own colours; everything else is scenery.
	if _livery.a > 0.0:
		Ink.dress_prop(prop, _livery)
	else:
		Ink.dress_scenery(prop, dim)
	parent.add_child(prop)
	return prop


func _lamp(parent: Node3D, at: Vector3, colour: Color, energy: float) -> void:
	# Ink (016): a lamp is a lit bulb, not a light -- the toon ramp is drawn by the key alone.
	var bulb := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.12
	ball.height = 0.24
	bulb.mesh = ball
	bulb.material_override = Ink.glow(colour, clampf(energy * 0.4, 0.8, 1.6))
	bulb.position = at + Vector3(0, 1.4, 0)
	parent.add_child(bulb)


func _smoke(parent: Node3D) -> CPUParticles3D:
	var smoke := CPUParticles3D.new()
	smoke.amount = 26
	smoke.lifetime = 6.0
	smoke.preprocess = 6.0
	smoke.local_coords = true
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.4
	smoke.direction = Vector3(0.25, 1, 0)
	smoke.spread = 12.0
	smoke.gravity = Vector3.ZERO
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 0.9
	smoke.scale_amount_min = 0.8
	smoke.scale_amount_max = 2.2
	var puff := QuadMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.albedo_texture = _soft_texture()
	material.albedo_color = Color(0.09, 0.09, 0.11, 0.55)
	material.vertex_color_use_as_albedo = true
	puff.material = material
	smoke.mesh = puff
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	smoke.color_ramp = fade
	smoke.position = Vector3(0.2, 0.6, 0)
	parent.add_child(smoke)
	return smoke


# --- Roads --------------------------------------------------------------------

func _build_roads() -> void:
	for a: Dictionary in _state.sites:
		for other: Variant in (a["links"] as Array):
			if int(other) < int(a["id"]):
				continue
			var road: MeshInstance3D = _strip(site_world(int(a["id"])), site_world(int(other)), 1.1, 0.03, Ink.toon(Color("3b3e47")))
			Ink.line(road, Ink.LINE_WORLD)
			_roads.add_child(road)
			_road_nodes.append({"node": road, "a": int(a["id"]), "b": int(other)})


func _mark_roads(targets: Array[int]) -> void:
	for child: Node in _road_marks.get_children():
		child.queue_free()
	var here: Vector3 = site_world(_state.current)
	for id: int in targets:
		var hot: bool = id == _hover
		var mark: MeshInstance3D = _strip(here, site_world(id), 0.28 if hot else 0.2, 0.05,
			Ink.glow(RING_HERE if hot else RING_GO, 0.5 if hot else 0.0))
		Ink.line(mark, Ink.LINE_WORLD)
		_road_marks.add_child(mark)


## A flat strip on the ground from `a` to `b`, stopping short of the pads.
func _strip(a: Vector3, b: Vector3, width: float, height: float, material: Material) -> MeshInstance3D:
	var flat_a := Vector3(a.x, 0, a.z)
	var flat_b := Vector3(b.x, 0, b.z)
	var length: float = maxf(0.1, flat_a.distance_to(flat_b) - 3.6)
	var strip := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(length, height, width)
	strip.mesh = box
	strip.material_override = material
	strip.position = (flat_a + flat_b) * 0.5 + Vector3(0, height * 0.5 + 0.01, 0)
	strip.rotation.y = -atan2(flat_b.z - flat_a.z, flat_b.x - flat_a.x)
	return strip


## Loose junk between the sites, so the yard is a yard and not a diagram.
func _build_clutter() -> void:
	var names: PackedStringArray = ["tyre_stack_0", "tyre_stack_1", "car_stack_1", "container_0", "container_1", "barrier_0"]
	var width: float = SPACING_X * float(_columns - 1)
	var placed: int = 0
	var tries: int = 0
	while placed < 70 and tries < 600:
		tries += 1
		var x: float = -width * 0.5 - 6.0 + float(_h(tries, 7) % 1000) / 1000.0 * (width + 12.0)
		var z: float = -DEPTH * 0.5 - 3.0 + float(_h(tries, 11) % 1000) / 1000.0 * (DEPTH + 6.0)
		var spot := Vector3(x, 0, z)
		# Keep clear of the sites, the roads and the zone names on the far edge.
		if _near_site_or_road(spot) or z < -DEPTH * 0.5 - 0.5:
			continue
		var junk: Node3D = _prop(self, names[_h(tries, 13) % names.size()], spot, float(_h(tries, 17) % 360), 0.34, 0.45)
		if junk != null:
			_clutter_nodes.append(junk)
		placed += 1


func _near_site_or_road(p: Vector3) -> bool:
	for id: int in _sites:
		if Vector2(p.x, p.z).distance_to(Vector2(site_world(id).x, site_world(id).z)) < 3.2:
			return true
	for a: Dictionary in _state.sites:
		for other: Variant in (a["links"] as Array):
			var s: Vector3 = site_world(int(a["id"]))
			var e: Vector3 = site_world(int(other))
			if Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), Vector2(s.x, s.z), Vector2(e.x, e.z)).distance_to(Vector2(p.x, p.z)) < 1.6:
				return true
	return false


# --- The crew on the map ------------------------------------------------------

func _crew_centre(id: int) -> Vector3:
	return site_world(id)


func _crew_lead_position() -> Vector3:
	if _crew.is_empty():
		return _crew_centre(_state.current)
	return (_crew[0]["root"] as Node3D).position


func _stand_crew(id: int) -> void:
	var at: Vector3 = site_world(id)
	for slot: int in _crew.size():
		var root: Node3D = _crew[slot]["root"]
		root.position = at + FORMATION[slot % FORMATION.size()]
		# Facing the way they will go: forward, toward the gate.
		root.rotation.y = PI * 0.5


# --- The Reclaimer ------------------------------------------------------------

func _build_reclaimer() -> void:
	_reclaimer = Node3D.new()
	add_child(_reclaimer)
	# Ink (016): a black shape edged in dark red -- lit by nothing but its own teeth and beacons.
	var dark: Material = Ink.toon(Color("161214"), "clean")
	var edge := Color("6a1c16")
	# The mouth: a long low harvester blade across the whole map, lit red along its teeth.
	var blade := MeshInstance3D.new()
	var blade_box := BoxMesh.new()
	blade_box.size = Vector3(1.4, 0.9, DEPTH + 12.0)
	blade.mesh = blade_box
	blade.position = Vector3(-0.6, 0.45, 0)
	blade.material_override = dark
	Ink.line(blade, Ink.LINE_ACT, edge)
	_reclaimer.add_child(blade)
	var teeth := MeshInstance3D.new()
	var teeth_box := BoxMesh.new()
	teeth_box.size = Vector3(0.12, 0.14, DEPTH + 12.0)
	teeth.mesh = teeth_box
	teeth.position = Vector3(0.12, 0.25, 0)
	teeth.material_override = Ink.glow(RECLAIMER_RED, 1.6)
	_reclaimer.add_child(teeth)
	var z: float = -DEPTH * 0.5 - 5.0
	var i: int = 0
	while z <= DEPTH * 0.5 + 5.0:
		var name: String = "gantry" if i % 2 == 0 else "service_gantry"
		var rig: Node3D = Surfaces.kit(name, 0.0)
		if rig != null:
			for mesh: MeshInstance3D in ConstructView.meshes_of(rig):
				mesh.material_override = dark
				Ink.line(mesh, Ink.LINE_WORLD, edge)
			rig.position = Vector3(-2.2 - float(_h(i, 3) % 100) / 100.0, 0, z)
			rig.rotation_degrees.y = 90.0 if name == "service_gantry" else 0.0
			rig.scale = Vector3.ONE * (0.62 if name == "gantry" else 0.75)
			_reclaimer.add_child(rig)
		var beacon := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.16
		ball.height = 0.32
		beacon.mesh = ball
		beacon.material_override = Ink.glow(RECLAIMER_RED, 2.0)
		beacon.position = Vector3(-2.2, 5.2 if name == "gantry" else 2.5, z)
		_reclaimer.add_child(beacon)
		z += 3.4
		i += 1
	var dust := CPUParticles3D.new()
	dust.amount = 90
	dust.lifetime = 5.0
	dust.preprocess = 5.0
	dust.local_coords = true
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(1.5, 0.3, DEPTH * 0.5 + 6.0)
	dust.direction = Vector3(0.3, 1, 0)
	dust.spread = 25.0
	dust.initial_velocity_min = 0.4
	dust.initial_velocity_max = 1.0
	dust.gravity = Vector3.ZERO
	dust.scale_amount_min = 2.0
	dust.scale_amount_max = 4.0
	var puff := QuadMesh.new()
	var puff_material := StandardMaterial3D.new()
	puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	puff_material.billboard_keep_scale = true
	puff_material.albedo_texture = _soft_texture()
	puff_material.albedo_color = Color(0.55, 0.2, 0.14, 0.16)
	puff_material.vertex_color_use_as_albedo = true
	puff.material = puff_material
	dust.mesh = puff
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.3, Color(1, 1, 1, 1))
	dust.color_ramp = fade
	dust.position = Vector3(-1.5, 0.5, 0)
	_reclaimer.add_child(dust)

	# Its ghost: where it will stand after its next step (play-test 4: show how it moves,
	# don't write it). Faint far off; pulsing when the next move brings it; brighter still
	# while hovering a move that would.
	_ghost = Node3D.new()
	add_child(_ghost)
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.albedo_color = Color(RECLAIMER_RED, 0.12)
	var ghost_wall := MeshInstance3D.new()
	var wall_box := BoxMesh.new()
	wall_box.size = Vector3(0.16, 3.2, DEPTH + 10.0)
	ghost_wall.mesh = wall_box
	ghost_wall.position = Vector3(0, 1.6, 0)
	ghost_wall.material_override = _ghost_material
	_ghost.add_child(ghost_wall)
	var ghost_base := MeshInstance3D.new()
	var base_box := BoxMesh.new()
	base_box.size = Vector3(1.4, 0.05, DEPTH + 10.0)
	ghost_base.mesh = base_box
	ghost_base.position = Vector3(-0.6, 0.03, 0)
	ghost_base.material_override = _ghost_material
	_ghost.add_child(ghost_base)


func _front_target() -> float:
	return _column_x(_state.front_col) + SPACING_X * 0.5


func _place_front(x: float) -> void:
	_reclaimer.position.x = x
	var left: float = _column_x(0) - SPACING_X * 0.5 - 60.0
	var taken: float = maxf(0.01, x - left)
	(_reclaimed.mesh as PlaneMesh).size = Vector2(taken, DEPTH + 120.0)
	_reclaimed.position = Vector3(left + taken * 0.5, 0.015, 0)
	var next_col: int = _state.front_col + 1
	_next_zone.visible = next_col < _columns - 1
	_next_zone.position = Vector3(_column_x(next_col), 0.02, 0)
	_ghost.visible = next_col < _columns - 1
	_ghost.position.x = _column_x(next_col) + SPACING_X * 0.5


# --- The Reclaimer's scouts ----------------------------------------------------

func _build_drones() -> void:
	var dark: Material = Ink.toon(Color("1b1719"), "clean")
	for i: int in 3:
		var drone := Node3D.new()
		# Small and low: at camera height a scout the size of a car reads as a blot.
		drone.scale = Vector3.ONE * 0.55
		add_child(drone)
		var body := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.7, 0.22, 0.5)
		body.mesh = box
		body.material_override = dark
		Ink.line(body, Ink.LINE_WORLD, Color("6a1c16"))
		drone.add_child(body)
		var rotors: Array[Node3D] = []
		for corner: Vector3 in [Vector3(0.45, 0.1, 0.35), Vector3(-0.45, 0.1, 0.35), Vector3(0.45, 0.1, -0.35), Vector3(-0.45, 0.1, -0.35)]:
			var rotor := MeshInstance3D.new()
			var disc := CylinderMesh.new()
			disc.top_radius = 0.28
			disc.bottom_radius = 0.28
			disc.height = 0.02
			rotor.mesh = disc
			rotor.material_override = Ink.toon(Color("2a2628"), "clean")
			rotor.position = corner
			drone.add_child(rotor)
			rotors.append(rotor)
		var eye := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.09
		ball.height = 0.18
		eye.mesh = ball
		eye.material_override = Ink.glow(RECLAIMER_RED, 2.0)
		eye.position = Vector3(0, -0.12, 0.2)
		drone.add_child(eye)
		_drones.append({"node": drone, "phase": float(i) * 2.1, "speed": 0.16 + 0.04 * float(i),
			"lane": -DEPTH * 0.3 + float(i) * DEPTH * 0.3, "rotors": rotors})


## A lazy figure-eight ahead of the front: scouts watch the ground the Reclaimer takes next.
func _fly(drone: Dictionary) -> void:
	var t: float = _time * float(drone["speed"]) + float(drone["phase"])
	var ahead: float = _front_x + SPACING_X * 1.2
	var node: Node3D = drone["node"]
	node.position = Vector3(ahead + cos(t) * SPACING_X * 1.4, 5.0 + sin(t * 1.7) * 0.5,
		float(drone["lane"]) + sin(t * 2.0) * 4.0)
	var heading := Vector3(-sin(t) * SPACING_X * 1.4, 0, cos(t * 2.0) * 8.0)
	if heading.length() > 0.01:
		node.rotation.y = atan2(heading.x, heading.z)
	for rotor: Node3D in (drone["rotors"] as Array):
		rotor.rotation.y += 0.9


# --- Fog of war ---------------------------------------------------------------

func _build_fog() -> void:
	var width: float = SPACING_X * float(_columns - 1)
	_fog_rect = Rect2(Vector2(-width * 0.5 - 24.0, -DEPTH * 0.5 - 16.0), Vector2(width + 48.0, DEPTH + 32.0))
	var size := Vector2i(int(_fog_rect.size.x * FOG_PX_PER_M), int(_fog_rect.size.y * FOG_PX_PER_M))
	_fog_image = Image.create(size.x, size.y, false, Image.FORMAT_L8)
	_fog_image.fill(Color(1, 1, 1))
	_fog_texture = ImageTexture.create_from_image(_fog_image)
	# Ink (016): one layer of unfinished drawing over what is not scouted (`ink_fog.gdshader`),
	# high enough to cover every landmark and prop under it.
	var shader: Shader = load("res://scripts/presentation/ink_fog.gdshader")
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = _fog_rect.size
	plane.mesh = mesh
	plane.position = Vector3(_fog_rect.position.x + _fog_rect.size.x * 0.5, 3.4,
		_fog_rect.position.y + _fog_rect.size.y * 0.5)
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("mask", _fog_texture)
	material.set_shader_parameter("origin", _fog_rect.position)
	material.set_shader_parameter("extent", _fog_rect.size)
	# Drawn AFTER the other see-through things (ground labels, smoke), so it covers them.
	material.render_priority = 2
	plane.material_override = material
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(plane)
	_fog_planes.append(plane)


## Clears the fog around every scouted site and along the roads between them, and over the
## Reclaimer's side of the map (its wall must always be seen). Painted on the CPU into a
## one-pixel-per-metre mask the fog shader reads.
func _update_fog() -> void:
	var seen: PackedStringArray = []
	for id: int in _sites:
		if RunSim.revealed(_state, id):
			seen.append(str(id))
	var key: String = "%s|%d" % [",".join(seen), _state.front_col]
	if key == _fog_key:
		return
	_fog_key = key
	var clear_points: Array[Vector2] = []
	for id: int in _sites:
		if RunSim.revealed(_state, id) and String(_state.site(id)["type"]) != "boss":
			var p: Vector3 = site_world(id)
			clear_points.append(Vector2(p.x, p.z))
	var segments: Array = []
	for a: Dictionary in _state.sites:
		if not RunSim.revealed(_state, int(a["id"])) or String(a["type"]) == "boss":
			continue
		for other: Variant in (a["links"] as Array):
			if RunSim.revealed(_state, int(other)) and String(_state.site(int(other))["type"]) != "boss":
				var s: Vector3 = site_world(int(a["id"]))
				var e: Vector3 = site_world(int(other))
				segments.append([Vector2(s.x, s.z), Vector2(e.x, e.z)])
	var wall_x: float = _front_target() + 1.0
	var w: int = _fog_image.get_width()
	var h: int = _fog_image.get_height()
	for py: int in h:
		for px: int in w:
			var world := Vector2(_fog_rect.position.x + (float(px) + 0.5) / FOG_PX_PER_M,
				_fog_rect.position.y + (float(py) + 0.5) / FOG_PX_PER_M)
			var nearest: float = 1000.0
			for p: Vector2 in clear_points:
				nearest = minf(nearest, world.distance_to(p))
			for seg: Array in segments:
				nearest = minf(nearest, world.distance_to(Geometry2D.get_closest_point_to_segment(world, seg[0], seg[1])) + 4.0)
			var hidden: float = clampf((nearest - SIGHT) / 5.0, 0.0, 1.0)
			if world.x < wall_x:
				hidden = minf(hidden, clampf((world.x - (wall_x - 6.0)) / 6.0, 0.0, 1.0))
			_fog_image.set_pixel(px, py, Color(hidden, hidden, hidden))
	_fog_texture.update(_fog_image)
	# What is deep in the fog is not drawn at all -- a haze thin enough to be beautiful is
	# thin enough to read a road through.
	for road: Dictionary in _road_nodes:
		(road["node"] as Node3D).visible = RunSim.revealed(_state, int(road["a"])) or RunSim.revealed(_state, int(road["b"]))
	for junk: Node3D in _clutter_nodes:
		junk.visible = _fog_at(Vector2(junk.position.x, junk.position.z)) < 0.6


## How hidden a point is (0 clear .. 1 fog), read back from the mask.
func _fog_at(world: Vector2) -> float:
	var px: int = clampi(int((world.x - _fog_rect.position.x) * FOG_PX_PER_M), 0, _fog_image.get_width() - 1)
	var py: int = clampi(int((world.y - _fog_rect.position.y) * FOG_PX_PER_M), 0, _fog_image.get_height() - 1)
	return _fog_image.get_pixel(px, py).r


# --- Helpers ------------------------------------------------------------------

func _map_point(x: float, y: float) -> Vector3:
	var width: float = SPACING_X * float(_columns - 1)
	return Vector3(-width * 0.5 + x / 100.0 * width, 0.0, -DEPTH * 0.5 + y / 100.0 * DEPTH)


func _column_x(col: int) -> float:
	return -SPACING_X * float(_columns - 1) * 0.5 + float(col) * SPACING_X


func _soft_texture() -> GradientTexture2D:
	if _materials.has("soft"):
		return _materials["soft"]
	var soft := GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	var falloff := Gradient.new()
	falloff.set_color(0, Color(1, 1, 1, 1))
	falloff.set_color(1, Color(1, 1, 1, 0))
	soft.gradient = falloff
	_materials["soft"] = soft
	return soft


## An ink disc with a white ring (tinted by the sprite's modulate): a site icon's badge.
func _disc_texture() -> Texture2D:
	return Ink.texture("site_disc", Vector2i(96, 96), func(image: Image) -> void:
		image.fill(Color(0, 0, 0, 0))
		for y: int in 96:
			for x: int in 96:
				var r: float = Vector2(float(x) - 47.5, float(y) - 47.5).length()
				if r < 38.0:
					image.set_pixel(x, y, Color(0.08, 0.07, 0.06, 1.0))
				elif r < 46.5:
					image.set_pixel(x, y, Color(1, 1, 1, clampf(46.5 - r, 0.0, 1.0))))


func _flat(colour: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	return material


func _glow(colour: Color, energy: float) -> StandardMaterial3D:
	var key: String = "glow:%s:%.2f" % [colour.to_html(false), energy]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = energy
	_materials[key] = material
	return material


## Integer avalanche for scatter (presentation only, but stable so a region dresses the
## same way every time it is drawn).
func _h(i: int, salt: int) -> int:
	var x: int = (i * 73856093) ^ (salt * 19349663) ^ (_state.sites.size() * 83492791)
	x = (x ^ (x >> 13)) * 1274126177
	x = x ^ (x >> 16)
	return absi(x)
