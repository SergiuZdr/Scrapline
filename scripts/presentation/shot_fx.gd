class_name ShotFX
extends RefCounted

## 074: the trail each ranged arm leaves (`data/fx/weapons.json` `trail`), so a shot says which gun
## fired it. Told where the shot leaves and where it lands; decides nothing. Every piece frees itself,
## and every material goes through `Ink.hold` (one shader variant per kind of material, compiled behind
## the opening card -- `warm`).
##
## `play` returns the seconds until the shot ARRIVES, so the fight shows the hit then.

const KINDS: PackedStringArray = ["needle", "scan", "pulse", "pellets", "shell", "rail", "flame", "hook",
	"aegis", "arc", "sun", "bola", "mine"]


## Draws trail `kind` from `from` to `to` under `parent`. `extra.cells` (world points) spreads a flame
## over a wedge. Returns the travel time in seconds.
static func play(kind: String, parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color,
		extra: Dictionary = {}) -> float:
	if parent == null or not parent.is_inside_tree():
		return 0.0
	match kind:
		"needle": return _needle(parent, vfx, from, to, colour)
		"scan": return _scan(parent, from, to, colour)
		"pulse": return _pulse(parent, vfx, from, to, colour)
		"pellets": return _pellets(parent, vfx, from, to, colour)
		"shell": return _shell(parent, vfx, from, to, colour)
		"rail": return _rail(parent, vfx, from, to, colour)
		"flame": return _flame(parent, vfx, from, to, colour, extra.get("cells", []))
		"hook": return _hook(parent, vfx, from, to, colour)
		"aegis": return _aegis(parent, from, to, colour)
		"arc": return _arc(parent, vfx, from, to, colour)
		"sun": return _sun(parent, vfx, from, to, colour)
		"bola": return _bola(parent, vfx, from, to, colour)
		"mine": return _mine(parent, vfx, from, to, colour)
	return 0.0


## One of every trail at `at`, under a holder of its own: their shaders compile behind the opening card,
## and hiding the holder hides pieces a trail shows later (its tweens keep running). Freed in 3 s.
static func warm(parent: Node3D, vfx: BattleVFX, at: Vector3) -> Node3D:
	var holder := Node3D.new()
	parent.add_child(holder)
	for kind: String in KINDS:
		play(kind, holder, vfx, at + Vector3(0, 0.6, 0), at + Vector3(1.2, 0.6, 0.3), Color("ffd28a"),
			{"cells": [at + Vector3(1.0, 0.3, 0.0)]})
	_later(holder, 3.0, holder.queue_free, true)
	return holder


# --- The trails ----------------------------------------------------------------

## The Rail Lance: a white-hot dart, gone in a blink, a hair-thin line left hanging and three rings
## popping along it.
static func _needle(parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color) -> float:
	var travel: float = 0.07
	_flash(parent, from, colour, 0.16)
	var dart: MeshInstance3D = _bar(parent, from, from + (to - from).normalized() * 0.5, 0.05, colour, 3.0)
	var t := parent.create_tween()
	t.tween_method(func(k: float) -> void:
		var head: Vector3 = from.lerp(to, k)
		_aim_bar(dart, head - (to - from).normalized() * 0.5, head), 0.0, 1.0, travel)
	t.tween_callback(dart.queue_free)
	var line: MeshInstance3D = _bar(parent, from, to, 0.018, colour, 2.2)
	_fade(parent, line, 0.55, travel)
	for i: int in 3:
		var at: Vector3 = from.lerp(to, 0.25 * (i + 1))
		var ring: MeshInstance3D = _ring(parent, at, to - from, 0.06, colour, 1.6)
		_grow_fade(parent, ring, 3.5, 0.3, travel * (i + 1) / 3.0)
	_later(parent, travel, func() -> void: vfx.sparks(to, colour, 6, 0.8))
	return travel


## The Spotter Array: a dotted green line ticks out to the target, a reticle closes on it and blinks.
static func _scan(parent: Node3D, from: Vector3, to: Vector3, colour: Color) -> float:
	var travel: float = 0.2
	var dots: int = maxi(4, int(from.distance_to(to) / 0.22))
	for i: int in dots:
		var dot: MeshInstance3D = _ball(parent, from.lerp(to, float(i + 1) / dots), 0.03, colour, 2.0)
		dot.visible = false
		var t := parent.create_tween()
		t.tween_interval(travel * float(i) / dots)
		t.tween_callback(func() -> void: dot.visible = true)
		t.tween_interval(0.25)
		t.tween_property(dot, "scale", Vector3.ZERO, 0.12)
		t.tween_callback(dot.queue_free)
	var reticle: MeshInstance3D = _ring(parent, to, Vector3.UP, 0.5, colour, 2.0)
	reticle.visible = false
	var r := parent.create_tween()
	r.tween_interval(travel * 0.6)
	r.tween_callback(func() -> void: reticle.visible = true)
	r.tween_property(reticle, "scale", Vector3.ONE * 0.4, 0.14).set_ease(Tween.EASE_IN)
	for blink: int in 2:
		r.tween_callback(func() -> void: reticle.visible = false)
		r.tween_interval(0.05)
		r.tween_callback(func() -> void: reticle.visible = true)
		r.tween_interval(0.06)
	r.tween_callback(reticle.queue_free)
	return travel


## The Pulse Emitter: three blue bolts in a row, each with a short glowing tail.
static func _pulse(parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color) -> float:
	var flight: float = 0.13
	for i: int in 3:
		var delay: float = 0.09 * i
		var bolt: MeshInstance3D = _ball(parent, from, 0.08, colour, 2.6)
		var tail: MeshInstance3D = _bar(parent, from, from, 0.06, colour, 1.4)
		bolt.visible = false
		tail.visible = false
		var t := parent.create_tween()
		t.tween_interval(delay)
		t.tween_callback(func() -> void:
			bolt.visible = true
			tail.visible = true
			_flash(parent, from, colour, 0.12))
		t.tween_method(func(k: float) -> void:
			var head: Vector3 = from.lerp(to, k)
			bolt.position = head
			_aim_bar(tail, from.lerp(to, maxf(0.0, k - 0.3)), head), 0.0, 1.0, flight)
		t.tween_callback(func() -> void:
			if parent.is_visible_in_tree():
				vfx.sparks(to, colour, 4, 0.7)
			bolt.queue_free()
			tail.queue_free())
	return flight


## The Scattergun: a fan of short pellet streaks, a smoke puff at the barrel, sparks where they land.
static func _pellets(parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color) -> float:
	var travel: float = 0.12
	_flash(parent, from, colour, 0.22)
	vfx.smoke(from, 3, 0.5)
	var side: Vector3 = (to - from).cross(Vector3.UP).normalized()
	for i: int in 7:
		var spread: Vector3 = side * (float(i) - 3.0) * 0.11 + Vector3(0, (float(i % 3) - 1.0) * 0.08, 0)
		var end: Vector3 = to + spread
		var streak: MeshInstance3D = _bar(parent, from, from, 0.045, colour, 2.6)
		var t := parent.create_tween()
		t.tween_method(func(k: float) -> void:
			var head: Vector3 = from.lerp(end, k)
			_aim_bar(streak, from.lerp(end, maxf(0.0, k - 0.4)), head), 0.0, 1.0, travel + 0.02 * (i % 3))
		t.tween_callback(func() -> void:
			if parent.is_visible_in_tree():
				vfx.sparks(end, colour, 2, 0.6)
			streak.queue_free())
	return travel


## The Slag Mortar: a glowing shell lobbed high, dropping cartoon smoke all along its arc.
static func _shell(parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color) -> float:
	var travel: float = 0.55
	_flash(parent, from, colour, 0.25)
	vfx.smoke(from, 3, 0.6)
	var shell: MeshInstance3D = _ball(parent, from, 0.1, colour, 1.8)
	var arc_height: float = 1.4 + from.distance_to(to) * 0.25
	var t := parent.create_tween()
	t.tween_method(func(k: float) -> void:
		shell.position = from.lerp(to, k) + Vector3(0, sin(k * PI) * arc_height, 0), 0.0, 1.0, travel) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(shell.queue_free)
	for i: int in 5:
		var k: float = 0.15 + 0.16 * i
		_later(parent, travel * k, func() -> void:
			if is_instance_valid(shell):
				vfx.smoke(shell.position, 1, 0.35))
	return travel


## The Rail Driver: a thick beam with a white core, rings spiralling down it, a smoke line left hanging.
static func _rail(parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color) -> float:
	_flash(parent, from, colour, 0.35)
	var glow: MeshInstance3D = _bar(parent, from, to, 0.16, colour, 0.9)
	var core: MeshInstance3D = _bar(parent, from, to, 0.05, Color.WHITE, 3.0)
	_fade(parent, glow, 0.35)
	_fade(parent, core, 0.22)
	var rings: int = maxi(5, int(from.distance_to(to) / 0.3))
	for i: int in rings:
		var at: Vector3 = from.lerp(to, float(i + 1) / (rings + 1))
		var ring: MeshInstance3D = _ring(parent, at, to - from, 0.09, colour, 1.8)
		ring.rotate_object_local(Vector3.FORWARD, float(i) * 0.7)
		_grow_fade(parent, ring, 2.2, 0.4, 0.02 * i)
	for i: int in 4:
		vfx.smoke(from.lerp(to, 0.2 + 0.2 * i), 1, 0.4)
	vfx.shake(0.5)
	vfx.sparks(to, colour, 10, 1.4)
	return 0.03


## The Slag Flamer: a stream of fire balls rolling out of the nozzle and spreading over the wedge.
static func _flame(parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color, cells: Array) -> float:
	var travel: float = 0.22
	var ends: Array = cells if not cells.is_empty() else [to]
	for i: int in 12:
		var end: Vector3 = (ends[i % ends.size()] as Vector3) + Vector3(0, 0.25, 0)
		var heat: Color = colour.lerp(Color("ffe38a"), 0.5) if i % 3 == 0 else colour
		var puff: MeshInstance3D = _ball(parent, from, 0.07, heat, 1.6)
		puff.visible = false
		var t := parent.create_tween()
		t.tween_interval(0.025 * i)
		t.tween_callback(func() -> void: puff.visible = true)
		t.tween_method(func(k: float) -> void:
			puff.position = from.lerp(end, k) + Vector3(0, sin(k * PI) * 0.12, 0)
			puff.scale = Vector3.ONE * (1.0 + 2.6 * k), 0.0, 1.0, travel)
		t.tween_property(puff, "scale", Vector3.ZERO, 0.1)
		t.tween_callback(puff.queue_free)
	_later(parent, travel + 0.25, func() -> void: vfx.smoke(to, 3, 0.6))
	return travel


## The Hook Harpoon: the hook flies out paying a chain behind it, bites, and the chain reels back in.
static func _hook(parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color) -> float:
	var travel: float = 0.16
	var dir: Vector3 = (to - from).normalized()
	var head: MeshInstance3D = _bar(parent, from, from + dir * 0.18, 0.09, colour, 1.6)
	var links: Array = []
	var count: int = maxi(4, int(from.distance_to(to) / 0.13))
	for i: int in count:
		var at: Vector3 = from.lerp(to, float(i) / count)
		var link: MeshInstance3D = _bar(parent, at, at + dir * 0.08, 0.035, colour.darkened(0.2), 1.2)
		link.rotate_object_local(Vector3.FORWARD, PI * 0.5 * (i % 2))
		link.visible = false
		links.append(link)
	var t := parent.create_tween()
	t.tween_method(func(k: float) -> void:
		var tip: Vector3 = from.lerp(to, k)
		_aim_bar(head, tip - dir * 0.18, tip)
		for i: int in links.size():
			(links[i] as Node3D).visible = float(i) / links.size() <= k, 0.0, 1.0, travel)
	t.tween_callback(func() -> void:
		if parent.is_visible_in_tree():
			vfx.sparks(to, colour, 5, 0.8))
	t.tween_interval(0.18)
	t.tween_method(func(k: float) -> void:
		var tip: Vector3 = to.lerp(from, k)
		_aim_bar(head, tip - dir * 0.18, tip)
		for i: int in links.size():
			(links[i] as Node3D).visible = float(i) / links.size() <= 1.0 - k, 0.0, 1.0, 0.24)
	t.tween_callback(func() -> void:
		head.queue_free()
		for link: Variant in links:
			(link as Node).queue_free())
	return travel


## The Aegis Caster: ripples roll out to the ally and a bubble swells round it.
static func _aegis(parent: Node3D, from: Vector3, to: Vector3, colour: Color) -> float:
	var travel: float = 0.26
	for i: int in 4:
		var ring: MeshInstance3D = _ring(parent, from, to - from, 0.12, colour, 1.6)
		ring.visible = false
		var t := parent.create_tween()
		t.tween_interval(0.06 * i)
		t.tween_callback(func() -> void: ring.visible = true)
		t.tween_method(func(k: float) -> void:
			ring.position = from.lerp(to, k)
			ring.scale = Vector3.ONE * (1.0 + 2.0 * k), 0.0, 1.0, travel - 0.06 * i)
		t.tween_callback(ring.queue_free)
	var bubble: MeshInstance3D = _ball(parent, to, 0.55, colour, 0.5)
	bubble.scale = Vector3.ZERO
	var b := parent.create_tween()
	b.tween_interval(travel)
	b.tween_property(bubble, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	b.tween_interval(0.2)
	b.tween_property(bubble.material_override, "albedo_color:a", 0.0, 0.3)
	b.tween_callback(bubble.queue_free)
	return travel


## The Arc Coilgun: a jagged lightning bolt, redrawn three times as it flickers.
static func _arc(parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color) -> float:
	_flash(parent, from, colour, 0.2)
	var side: Vector3 = (to - from).cross(Vector3.UP).normalized()
	for flick: int in 3:
		var pieces: Array = []
		var last: Vector3 = from
		var steps: int = 7
		for i: int in steps:
			var k: float = float(i + 1) / steps
			var next: Vector3 = from.lerp(to, k)
			if i < steps - 1:
				next += side * randf_range(-0.18, 0.18) + Vector3(0, randf_range(-0.14, 0.14), 0)
			pieces.append(_bar(parent, last, next, 0.03 if flick > 0 else 0.045, colour, 3.0))
			last = next
		for piece: Variant in pieces:
			var p: MeshInstance3D = piece
			p.visible = false
			var t := parent.create_tween()
			t.tween_interval(0.06 * flick)
			t.tween_callback(func() -> void: p.visible = true)
			t.tween_interval(0.06)
			t.tween_callback(p.queue_free)
	vfx.sparks(to, colour, 8, 1.2)
	return 0.02


## The Sunspear: a golden beam that swells fat, burns a beat, and thins away; sparks along it.
static func _sun(parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color) -> float:
	_flash(parent, from, colour, 0.4)
	var glow: MeshInstance3D = _bar(parent, from, to, 0.1, colour, 1.2)
	var core: MeshInstance3D = _bar(parent, from, to, 0.06, colour.lerp(Color.WHITE, 0.6), 3.0)
	# A bar's length is its z scale: only its thickness swells.
	var length: float = glow.scale.z
	glow.scale = Vector3(0.3, 0.3, length)
	var t := parent.create_tween()
	t.tween_property(glow, "scale", Vector3(3.5, 3.5, length), 0.08).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.28)
	t.tween_property(glow, "scale", Vector3(0.1, 0.1, length), 0.18).set_ease(Tween.EASE_IN)
	t.tween_callback(glow.queue_free)
	var c := parent.create_tween()
	c.tween_interval(0.36)
	c.tween_property(core, "scale", Vector3(0.1, 0.1, length), 0.16)
	c.tween_callback(core.queue_free)
	for i: int in 5:
		_later(parent, 0.05 * i, func() -> void: vfx.sparks(from.lerp(to, randf_range(0.2, 1.0)), colour, 3, 0.7))
	vfx.shake(0.4)
	return 0.05


## The Snare Launcher: a bola -- two weights on a cord -- spins out and wraps into a net round the target.
static func _bola(parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color) -> float:
	var travel: float = 0.24
	var a: MeshInstance3D = _ball(parent, from, 0.08, colour, 1.8)
	var b: MeshInstance3D = _ball(parent, from, 0.08, colour, 1.8)
	var cord: MeshInstance3D = _bar(parent, from, from, 0.03, colour, 1.6)
	var side: Vector3 = (to - from).cross(Vector3.UP).normalized()
	var t := parent.create_tween()
	t.tween_method(func(k: float) -> void:
		var centre: Vector3 = from.lerp(to, k) + Vector3(0, sin(k * PI) * 0.25, 0)
		var spin: float = k * TAU * 3.0
		var arm: Vector3 = (side * cos(spin) + Vector3.UP * sin(spin)) * 0.24
		a.position = centre + arm
		b.position = centre - arm
		_aim_bar(cord, a.position, b.position), 0.0, 1.0, travel)
	t.tween_callback(func() -> void:
		a.queue_free()
		b.queue_free()
		cord.queue_free()
		_net(parent, to, colour)
		if parent.is_visible_in_tree():
			vfx.sparks(to, colour, 4, 0.6))
	return travel


## The Mine Layer: a short hop, the mine bounces once and blinks red where it sits.
static func _mine(parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color) -> float:
	var travel: float = 0.38
	var mine: MeshInstance3D = _ball(parent, from, 0.11, colour, 1.6)
	var t := parent.create_tween()
	t.tween_method(func(k: float) -> void:
		mine.position = from.lerp(to, k) + Vector3(0, sin(k * PI) * 0.7, 0), 0.0, 1.0, travel * 0.8)
	t.tween_callback(func() -> void:
		if parent.is_visible_in_tree():
			vfx.dust(to, 3, 0.5))
	t.tween_property(mine, "position", to + Vector3(0, 0.15, 0), travel * 0.1).set_ease(Tween.EASE_OUT)
	t.tween_property(mine, "position", to, travel * 0.1).set_ease(Tween.EASE_IN)
	for blink: int in 3:
		t.tween_callback(func() -> void: mine.scale = Vector3.ONE * 1.6)
		t.tween_interval(0.07)
		t.tween_callback(func() -> void: mine.scale = Vector3.ONE)
		t.tween_interval(0.09)
	t.tween_callback(mine.queue_free)
	return travel


# --- Pieces --------------------------------------------------------------------

## A net thrown over `at`: a ring and four crossing cords, flattened onto the target, then gone.
static func _net(parent: Node3D, at: Vector3, colour: Color) -> void:
	var ring: MeshInstance3D = _ring(parent, at, Vector3.UP, 0.32, colour, 1.4)
	var cords: Array = [ring]
	for i: int in 4:
		var angle: float = PI * 0.25 * i
		var d := Vector3(cos(angle), 0, sin(angle)) * 0.32
		cords.append(_bar(parent, at - d, at + d, 0.015, colour, 1.4))
	for piece: Variant in cords:
		var p: MeshInstance3D = piece
		var size: Vector3 = p.scale
		p.scale = size * 1.6
		var t := parent.create_tween()
		t.tween_property(p, "scale", size, 0.1).set_ease(Tween.EASE_OUT)
		t.tween_interval(0.5)
		t.tween_property(p, "scale", size * 0.01, 0.15)
		t.tween_callback(p.queue_free)


## A pop of light at the barrel.
static func _flash(parent: Node3D, at: Vector3, colour: Color, size: float) -> void:
	var flash: MeshInstance3D = _ball(parent, at, size, colour.lerp(Color.WHITE, 0.5), 2.4)
	var t := parent.create_tween()
	t.tween_property(flash, "scale", Vector3.ONE * 1.8, 0.08)
	t.parallel().tween_property(flash.material_override, "albedo_color:a", 0.0, 0.08)
	t.tween_callback(flash.queue_free)


## An additive, unshaded box from `from` to `to`, `width` thick.
static func _bar(parent: Node3D, from: Vector3, to: Vector3, width: float, colour: Color, energy: float) -> MeshInstance3D:
	var bar := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, width, 1.0)
	bar.mesh = box
	bar.material_override = _glow(colour, energy)
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(bar)
	_aim_bar(bar, from, to)
	return bar


## Stretches a unit-long bar from `from` to `to` (keeping its thickness scale).
static func _aim_bar(bar: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	if not is_instance_valid(bar):
		return
	var length: float = from.distance_to(to)
	var thick: Vector2 = Vector2(bar.scale.x, bar.scale.y)
	if length < 0.001:
		bar.visible = false
		return
	var up: Vector3 = Vector3.UP if absf((to - from).normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	# Shown again once it has a length (a bar born at its muzzle is hidden until it grows).
	bar.visible = true
	bar.look_at_from_position((from + to) * 0.5, to, up)
	bar.scale = Vector3(thick.x, thick.y, length)


static func _ball(parent: Node3D, at: Vector3, radius: float, colour: Color, energy: float) -> MeshInstance3D:
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 10
	sphere.rings = 5
	ball.mesh = sphere
	ball.material_override = _glow(colour, energy)
	ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.position = at
	parent.add_child(ball)
	return ball


## A thin ring at `at` facing along `normal`.
static func _ring(parent: Node3D, at: Vector3, normal: Vector3, radius: float, colour: Color, energy: float) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.82
	torus.outer_radius = radius
	torus.rings = 16
	torus.ring_segments = 4
	ring.mesh = torus
	ring.material_override = _glow(colour, energy)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)
	ring.position = at
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.UP
	# A torus lies in its XZ plane: turn its Y onto the normal.
	var axis: Vector3 = Vector3.UP.cross(n)
	if axis.length() > 0.001:
		ring.basis = Basis(axis.normalized(), Vector3.UP.angle_to(n))
	return ring


## Additive and over-bright, not emissive (play-test 7: the emissive transparent material recompiled
## on every shot). One held variant serves every glow; each piece gets its own copy to fade.
static func _glow(colour: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(colour.r * energy, colour.g * energy, colour.b * energy, 1.0)
	material.disable_receive_shadows = true
	return Ink.hold(material) as StandardMaterial3D


static func _fade(parent: Node3D, node: MeshInstance3D, time: float, delay: float = 0.0) -> void:
	var t := parent.create_tween()
	if delay > 0.0:
		t.tween_interval(delay)
	t.tween_property(node.material_override, "albedo_color:a", 0.0, time)
	t.tween_callback(node.queue_free)


static func _grow_fade(parent: Node3D, node: MeshInstance3D, grow: float, time: float, delay: float = 0.0) -> void:
	node.visible = delay <= 0.0
	var t := parent.create_tween()
	if delay > 0.0:
		t.tween_interval(delay)
		t.tween_callback(func() -> void: node.visible = true)
	t.tween_property(node, "scale", node.scale * grow, time).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(node.material_override, "albedo_color:a", 0.0, time)
	t.tween_callback(node.queue_free)


## `what` after `delay`, unless the trail has been hidden by then (the warm-up's, behind the card).
static func _later(parent: Node3D, delay: float, what: Callable, always: bool = false) -> void:
	var t := parent.create_tween()
	t.tween_interval(maxf(0.0, delay))
	t.tween_callback(func() -> void:
		if always or parent.is_visible_in_tree():
			what.call())
