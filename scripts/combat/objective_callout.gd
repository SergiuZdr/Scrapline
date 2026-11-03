extends Node

## 088 (A14): the first time each objective appears, one coach callout on the board -- the amber
## ring on the objective's piece (a cache, a pile, the zone, a terminal, a wave's mark) and a
## balloon saying what to do with it. No strip (the user).
##
## Shown once per objective per profile: it is the hint `obj_<kind>` (`Profile.mark_seen` on GOT
## IT), its words in `data/run/story.json` `objectives` (ContentDB hands them to the hints). It
## waits for the turn: nothing playing back, and the fight's own first hint gone.
##
## It never reads the `Run` autoload and never computes an outcome: it reads the state the scene
## shows. `target` is static so a test can ask it about any board.

## The objectives that get a callout. ROUT is the shakedown's; a boss fight (`keeper`) opens with its
## own comic strip.
const KINDS: Array = ["defend", "salvage", "hold", "hack", "survive"]
const WIDTH: float = 420.0

var _scene: Node
var _db: ContentDB
var _kind: String = ""
var _panel: Control
var _shown: bool = false
## Where the piece is on screen (null: nothing on the board yet), and whether the balloon has been
## set over it (it is placed a frame after it is made, once it knows its own height).
var _point: Variant = null
var _placed: bool = false


## Hangs the callout on the HUD if this fight's objective has not been pointed out on this profile.
static func attach(scene: Node, hud: Control, db: ContentDB) -> void:
	if hud.has_node("objective_callout") or not hud.is_inside_tree():
		return
	var state: CombatState = scene.get("_state")
	if state == null or state.outcome != CombatState.ONGOING:
		return
	var found: Dictionary = target(state)
	if found.is_empty():
		return
	var profile: Node = hud.get_tree().root.get_node_or_null("Profile")
	if profile == null or bool(profile.call("seen", "obj_" + String(found["kind"]))):
		return
	var node: Node = (load("res://scripts/combat/objective_callout.gd") as GDScript).new()
	node.name = "objective_callout"
	node.set("_scene", scene)
	node.set("_db", db)
	node.set("_kind", String(found["kind"]))
	hud.add_child(node)


## The objective and its piece: `{ "kind", "cell" }` (cell null when nothing stands for it yet, as
## a SURVIVE fight before its first wave is marked); {} for an objective with no callout.
static func target(state: CombatState) -> Dictionary:
	var o: Dictionary = state.objective()
	var kind: String = String(o.get("type", "rout"))
	if not KINDS.has(kind) or not state.setup.keepers.is_empty():
		return {}
	var cell: Variant = null
	match kind:
		"defend":
			var caches: Array[GridUnit] = state.caches()
			if not caches.is_empty():
				cell = Vector2i(caches[0].x, caches[0].y)
		"salvage":
			var piles: Array = state.pile_cells()
			if not piles.is_empty():
				cell = piles[0]
		"hold":
			var zone: Array = o.get("cells", [])
			if not zone.is_empty():
				cell = zone[0]
		"hack":
			var terminals: Array = (o.get("cells", []) as Array).filter(func(c: Vector2i) -> bool: return not state.hacked.has(c))
			terminals.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
			if not terminals.is_empty():
				cell = terminals[0]
		"survive":
			var marks: Array = state.wave_marks.duplicate()
			marks.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
			if not marks.is_empty():
				cell = marks[0]
	return {"kind": kind, "cell": cell}


func _process(_delta: float) -> void:
	if _shown:
		if _panel == null or not is_instance_valid(_panel) or _panel.is_queued_for_deletion():
			_scene.call("coach_point", null)
			queue_free()
		elif not _placed and _point != null:
			_place(get_parent())
		return
	var hud: Control = get_parent()
	var state: CombatState = _scene.get("_state")
	if bool(_scene.get("_busy")) or hud.has_node("hint_fight") or state == null:
		return
	if state.outcome != CombatState.ONGOING:
		queue_free()
		return
	_show(hud, state)


func _show(hud: Control, state: CombatState) -> void:
	_shown = true
	var found: Dictionary = target(state)
	var cell: Variant = found.get("cell") if not found.is_empty() else null
	var screen: Variant = null
	var at := Vector2(80, 150)
	if cell != null:
		_scene.call("coach_point", cell)
		var camera: Camera3D = _scene.get("_camera")
		var world: Vector3 = _scene.call("_to_world", (cell as Vector2i).x, (cell as Vector2i).y)
		var point: Vector2 = camera.unproject_position(world)
		screen = point
		_point = point
		at = Vector2(clampf(point.x - 120.0, 24.0, 1920.0 - WIDTH - 24.0), maxf(130.0, point.y - 420.0))
	else:
		# Nothing on the board yet: the balloon points at the objective line, top left.
		screen = Vector2(260, 60)
	var id: String = "obj_" + _kind
	_panel = Hints.show_once(hud, id, _db, at, WIDTH, screen)
	if _panel == null:
		_scene.call("coach_point", null)
		queue_free()


## Sets the balloon just over the piece (its tail straight down onto it), on the screen, and lets
## the tail reach it.
func _place(hud: Control) -> void:
	_placed = true
	var point: Vector2 = _point
	var size: Vector2 = hud.size if hud.size.x > 0.0 else Vector2(1920, 1080)
	var height: float = _panel.size.y
	var y: float = point.y - 150.0 - height
	if y < 120.0:
		# No room over it: hang it below instead.
		y = point.y + 90.0
	_panel.position = Vector2(clampf(point.x - 140.0, 24.0, size.x - WIDTH - 24.0), clampf(y, 110.0, size.y - height - 20.0))
	var tail: Node = hud.get_node_or_null("hint_tail_obj_" + _kind)
	if tail != null:
		tail.set("max_length", 130.0)
		tail.set("gap", 26.0)
