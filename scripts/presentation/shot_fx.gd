class_name ShotFX
extends RefCounted

## 074-075: the trail each ranged arm leaves (`data/fx/weapons.json` `trail`), so a shot says which gun
## fired it. Told where the shot leaves and where it lands; decides nothing.
##
## 075 (the user: "more detailed, and in the game's style"): every piece is DRAWN, like the blasts and
## sparks of `BattleVFX` -- an ink edge, flat bands of colour, half-tone dots in the shade, a paper
## highlight -- and nothing glows or fades: a piece pops in, holds, and shrinks or snaps away. Beams,
## tails and chains are ribbons turned to the camera about their own line; balls, stars and nets are
## sprites. 076 ("too cartoony -- like Borderlands and comics"): drawn in the `Grit` vocabulary --
## jagged edges, hatched shade, grain; flashes, fire and smoke erode into grit. Textures are painted once per colour (`Ink.texture`), materials held (`Ink.hold`), and one of
## every trail in every arm's colour is fired behind the opening card (`warm`).
##
## `play` returns the seconds until the shot ARRIVES, so the fight shows the hit then.

const KINDS: PackedStringArray = ["needle", "scan", "pulse", "pellets", "shell", "rail", "flame", "hook",
	"aegis", "arc", "sun", "bola", "mine", "swing"]


## Draws trail `kind` from `from` to `to` under `parent`. `extra.cells` (world points) spreads a flame
## over a wedge. Returns the travel time in seconds.
static func play(kind: String, parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color,
		extra: Dictionary = {}) -> float:
	if parent == null or not parent.is_inside_tree():
		return 0.0
	match kind:
		"needle": return _needle(parent, vfx, from, to, colour)
		"scan": return _scan(parent, vfx, from, to, colour)
		"pulse": return _pulse(parent, vfx, from, to, colour)
		"pellets": return _pellets(parent, vfx, from, to, colour)
		"shell": return _shell(parent, vfx, from, to, colour)
		"rail": return _rail(parent, vfx, from, to, colour)
		"flame": return _flame(parent, vfx, from, to, colour, extra.get("cells", []))
		"hook": return _hook(parent, vfx, from, to, colour)
		"aegis": return _aegis(parent, vfx, from, to, colour)
		"arc": return _arc(parent, vfx, from, to, colour)
		"sun": return _sun(parent, vfx, from, to, colour)
		"bola": return _bola(parent, vfx, from, to, colour)
		"mine": return _mine(parent, vfx, from, to, colour)
		"swing": return _swing(parent, vfx, from, to, colour, extra.get("cells", []), extra.get("centre", from))
	return 0.0


## Every arm's trail, in its own colour, at `at`, under a holder of its own: the textures are painted and
## the shaders compiled behind the opening card, and hiding the holder hides what a trail shows later
## (its tweens keep running). Freed in 3 s.
static func warm(parent: Node3D, vfx: BattleVFX, at: Vector3) -> Node3D:
	var holder := Node3D.new()
	parent.add_child(holder)
	var looks: Dictionary = WeaponFX.table()
	for arm: Variant in looks:
		var look: Dictionary = looks[arm]
		play(String(look.get("trail", "")), holder, vfx, at + Vector3(0, 0.6, 0), at + Vector3(1.2, 0.6, 0.3),
			WeaponFX.colour(String(arm), Ink.ACTION), {"cells": [at + Vector3(1.0, 0.3, 0.0)]})
	_later(holder, 3.0, holder.queue_free, true)
	return holder


# --- The trails ----------------------------------------------------------------

## The Rail Lance: a white-hot dart with speed lines, gone in a blink; a hair-thin rail left hanging that
## thins away, and three rings punched along it as the dart goes through.
static func _needle(parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color) -> float:
	var travel: float = 0.08
	var dir: Vector3 = (to - from).normalized()
	_muzzle(parent, from, colour, 0.34)
	var dart: MeshInstance3D = _ribbon(parent, _tex_dart(colour), from, from + dir * 0.55, 0.13)
	var t := parent.create_tween()
	t.tween_method(func(k: float) -> void:
		var head: Vector3 = from.lerp(to, k)
		_lay(dart, head - dir * 0.55, head), 0.0, 1.0, travel)
	t.tween_callback(dart.queue_free)
	var rail: MeshInstance3D = _ribbon(parent, _tex_beam(colour), from, to, 0.07, 0.28)
	_thin(parent, rail, 0.09, 0.2)
	for i: int in 3:
		var at: Vector3 = from.lerp(to, 0.25 * (i + 1))
		var ring: MeshInstance3D = _disc(parent, _tex_ring(colour), at, dir, 0.24)
		_pop_disc(parent, ring, travel * (i + 1) / 3.0, 0.12, 1.5)
	_speed_lines(parent, from, to, 0.0, 3)
	_hit(parent, vfx, to, colour, travel, 0.0045, 6)
	return travel


## The Spotter Array: a dashed sight line ticks out diamond by diamond, a reticle snaps shut on the target
## and blinks twice.
static func _scan(parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color) -> float:
	var travel: float = 0.22
	var dots: int = maxi(4, int(from.distance_to(to) / 0.24))
	var line: MeshInstance3D = _ribbon(parent, _tex_dash(colour), from, from, 0.05, 0.16)
	var g := parent.create_tween()
	g.tween_method(func(k: float) -> void: _lay(line, from, from.lerp(to, k)), 0.0, 1.0, travel)
	g.tween_interval(0.3)
	g.tween_method(func(k: float) -> void: _lay(line, from.lerp(to, k), to), 0.0, 1.0, 0.12)
	g.tween_callback(line.queue_free)
	for i: int in dots:
		var dot: Sprite3D = _sprite(parent, _tex_diamond(colour), from.lerp(to, float(i + 1) / dots), 0.11)
		_pop(parent, dot, travel * float(i) / dots, 0.3, 1.0)
	var reticle: Sprite3D = _sprite(parent, _tex_reticle(colour), to, 0.9)
	reticle.visible = false
	var r := parent.create_tween()
	r.tween_interval(travel * 0.55)
	r.tween_callback(func() -> void: reticle.visible = true)
	r.tween_property(reticle, "scale", Vector3.ONE * 0.5, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	for blink: int in 2:
		r.tween_callback(func() -> void: reticle.visible = false)
		r.tween_interval(0.05)
		r.tween_callback(func() -> void: reticle.visible = true)
		r.tween_interval(0.07)
	r.tween_property(reticle, "scale", Vector3.ZERO, 0.08)
	r.tween_callback(reticle.queue_free)
	return travel


## The Pulse Emitter: three inked bolts in a row, each dragging a comet tail and a stepped after-image,
## a ring popping at the barrel for each.
static func _pulse(parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color) -> float:
	var flight: float = 0.14
	var dir: Vector3 = (to - from).normalized()
	for i: int in 3:
		var delay: float = 0.09 * i
		var bolt: Sprite3D = _sprite(parent, _tex_ball(colour), from, 0.2)
		var tail: MeshInstance3D = _ribbon(parent, _tex_tail(colour), from, from, 0.2)
		bolt.visible = false
		tail.visible = false
		var ring: MeshInstance3D = _disc(parent, _tex_ring(colour), from + dir * 0.1, dir, 0.3)
		_pop_disc(parent, ring, delay, 0.08, 1.4)
		var t := parent.create_tween()
		t.tween_interval(delay)
		t.tween_callback(func() -> void: bolt.visible = true)
		var echoes: Array = [0.35, 0.7]
		t.tween_method(func(k: float) -> void:
			var head: Vector3 = from.lerp(to, k)
			bolt.position = head
			_lay(tail, from.lerp(to, maxf(0.0, k - 0.32)), head)
			if not echoes.is_empty() and k >= float(echoes[0]):
				echoes.pop_front()
				var echo: Sprite3D = _sprite(parent, _tex_ball(colour), head - dir * 0.18, 0.13)
				_pop(parent, echo, 0.0, 0.04, 0.6), 0.0, 1.0, flight)
		t.tween_callback(func() -> void:
			bolt.queue_free()
			tail.queue_free())
		_hit(parent, vfx, to, colour, delay + flight, 0.003, 3)
	return flight


## The Scattergun: a big muzzle star and a smoke cloud; a fan of inked slugs with speed lines, a spark
## where each lands.
static func _pellets(parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color) -> float:
	var travel: float = 0.12
	_muzzle(parent, from, colour, 0.5)
	if parent.is_visible_in_tree():
		vfx.smoke(from, 4, 0.55)
	var side: Vector3 = (to - from).cross(Vector3.UP).normalized()
	for i: int in 7:
		var spread: Vector3 = side * (float(i) - 3.0) * 0.12 + Vector3(0, (float(i % 3) - 1.0) * 0.09, 0)
		var end: Vector3 = to + spread
		var slug: MeshInstance3D = _ribbon(parent, _tex_slug(colour), from, from, 0.13)
		var dir: Vector3 = (end - from).normalized()
		var t := parent.create_tween()
		t.tween_method(func(k: float) -> void:
			var head: Vector3 = from.lerp(end, k)
			_lay(slug, head - dir * 0.42, head), 0.0, 1.0, travel + 0.015 * (i % 3))
		t.tween_callback(func() -> void:
			slug.queue_free()
			if parent.is_visible_in_tree():
				vfx.sparks(end, colour, 2, 0.6))
	_speed_lines(parent, from, to, 0.02, 4)
	_hit(parent, vfx, to, colour, travel, 0.0042, 0)
	return travel


## The Slag Mortar: the tube coughs a star and a cloud; an inked iron shell arcs high, a dotted line of
## its path drawn behind it and smoke balls left in the air.
static func _shell(parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color) -> float:
	var travel: float = 0.55
	_muzzle(parent, from, colour, 0.45)
	if parent.is_visible_in_tree():
		vfx.smoke(from, 4, 0.7)
	var shell: Sprite3D = _sprite(parent, _tex_shell(colour), from, 0.38)
	var arc_height: float = 1.4 + from.distance_to(to) * 0.25
	var path := func(k: float) -> Vector3: return from.lerp(to, k) + Vector3(0, sin(k * PI) * arc_height, 0)
	var t := parent.create_tween()
	t.tween_method(func(k: float) -> void: shell.position = path.call(k), 0.0, 1.0, travel) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(shell.queue_free)
	for i: int in 9:
		var k: float = 0.08 + 0.1 * i
		var dot: Sprite3D = _sprite(parent, _tex_diamond(Ink.PAPER), path.call(k), 0.12)
		_pop(parent, dot, travel * k, 0.35, 1.0)
	for i: int in 4:
		var k: float = 0.15 + 0.2 * i
		_later(parent, travel * k, func() -> void:
			if is_instance_valid(shell):
				vfx.smoke(shell.position, 1, 0.35))
	return travel


## The Rail Driver: a fat inked beam -- a pale core in bands of colour, notched along its length -- with
## rings corkscrewing down it; it holds a beat and snaps thin; smoke left hanging along the line.
static func _rail(parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color) -> float:
	var dir: Vector3 = (to - from).normalized()
	_muzzle(parent, from, colour, 0.6)
	var beam: MeshInstance3D = _ribbon(parent, _tex_beam(colour), from, to, 0.24, 0.5)
	_thin(parent, beam, 0.14, 0.12)
	var rings: int = maxi(5, int(from.distance_to(to) / 0.3))
	for i: int in rings:
		var at: Vector3 = from.lerp(to, float(i + 1) / (rings + 1))
		var ring: MeshInstance3D = _disc(parent, _tex_ring(colour), at, dir, 0.36)
		ring.rotate_object_local(Vector3.FORWARD, float(i) * 0.7)
		_pop_disc(parent, ring, 0.015 * i, 0.12, 1.6)
	_speed_lines(parent, from, to, 0.0, 4)
	for i: int in 4:
		_later(parent, 0.1, func() -> void: vfx.smoke(from.lerp(to, 0.2 + 0.2 * i), 1, 0.4))
	if parent.is_visible_in_tree():
		vfx.shake(0.5)
	_hit(parent, vfx, to, colour, 0.03, 0.0065, 10)
	return 0.03


## The Slag Flamer (078; 079, the user: "the attack in the shape of an ARC, not straight lines"): the
## hose SWEEPS -- flame tongues thrown one after another across the wedge from one side to the other,
## each on a curving path that bows against the sweep, so the fire draws an arc over the hexes it
## burns; each tongue swells as it goes and burns down into grit; embers, then smoke.
static func _flame(parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color, cells: Array) -> float:
	var travel: float = 0.2
	var count: int = 18
	var sweep: float = 0.022
	_muzzle(parent, from, colour, 0.3)
	# The arc: from the first cell's bearing to the last's (sorted round the muzzle), at the wedge's reach.
	var flat_from := Vector3(from.x, 0.0, from.z)
	var bearings: Array = []
	for c: Variant in (cells if not cells.is_empty() else [to]):
		var d: Vector3 = (c as Vector3) - flat_from
		bearings.append(atan2(d.x, d.z))
	var aim: Vector3 = to - flat_from
	var mid: float = atan2(aim.x, aim.z)
	var spread: float = 0.0
	for b: Variant in bearings:
		spread = maxf(spread, absf(wrapf(float(b) - mid, -PI, PI)))
	spread = maxf(spread, 0.5) + 0.12
	var reach: float = Vector2(aim.x, aim.z).length()
	for i: int in count:
		var s: float = float(i) / float(count - 1)
		var bearing: float = mid - spread + 2.0 * spread * s
		var end: Vector3 = flat_from + Vector3(sin(bearing), 0.0, cos(bearing)) * reach + Vector3(0, 0.25, 0)
		var dir: Vector3 = (end - from).normalized()
		var side: Vector3 = dir.cross(Vector3.UP).normalized()
		# Bows against the sweep, the way a hose's stream lags behind its nozzle.
		var bow: Vector3 = from.lerp(end, 0.5) + side * 0.22 * from.distance_to(end) + Vector3(0, 0.12, 0)
		var path := func(k: float) -> Vector3: return from.lerp(bow, k).lerp(bow.lerp(end, k), k)
		var tongue: MeshInstance3D = _ribbon(parent, _tex_jet(colour), from, from, 0.1)
		tongue.visible = false
		var t := parent.create_tween()
		t.tween_interval(sweep * i)
		t.tween_method(func(k: float) -> void:
			tongue.set_meta("width", 0.1 + 0.3 * k)
			_lay(tongue, path.call(maxf(0.0, k - 0.35)), path.call(k)), 0.0, 1.0, travel)
		t.tween_callback(func() -> void: _burn(parent, tongue, 0.03 + sweep * float(count - i) * 0.8, 0.16))
	_later(parent, travel * 0.6, func() -> void: vfx.sparks(from.lerp(to, 0.5), colour, 6, 0.9))
	_later(parent, travel + sweep * count, func() -> void: vfx.smoke(to, 4, 0.7))
	return travel + sweep * count * 0.5


## The Hook Harpoon: an inked barbed head flies out paying a chain of drawn links behind it, bites with a
## star, hangs a beat, and the chain reels back in.
static func _hook(parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color) -> float:
	var travel: float = 0.16
	var dir: Vector3 = (to - from).normalized()
	_muzzle(parent, from, colour, 0.3)
	var chain: MeshInstance3D = _ribbon(parent, _tex_chain(), from, from, 0.09, 0.18)
	var head: MeshInstance3D = _ribbon(parent, _tex_hook(colour), from, from + dir * 0.3, 0.22)
	var t := parent.create_tween()
	t.tween_method(func(k: float) -> void:
		var tip: Vector3 = from.lerp(to, k)
		_lay(head, tip - dir * 0.3, tip)
		_lay(chain, from, tip - dir * 0.24), 0.0, 1.0, travel)
	t.tween_interval(0.2)
	t.tween_method(func(k: float) -> void:
		var tip: Vector3 = to.lerp(from + dir * 0.3, k)
		_lay(head, tip - dir * 0.3, tip)
		_lay(chain, from, tip - dir * 0.24), 0.0, 1.0, 0.24).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		head.queue_free()
		chain.queue_free())
	_hit(parent, vfx, to, colour, travel, 0.0045, 5)
	return travel


## The Aegis Caster: drawn hexagon rings roll out to the ally, a hex-panelled bubble pops round it, holds,
## and breaks into hex shards.
static func _aegis(parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color) -> float:
	var travel: float = 0.26
	var dir: Vector3 = (to - from).normalized()
	for i: int in 4:
		var ring: MeshInstance3D = _disc(parent, _tex_hex(colour), from, dir, 0.3)
		ring.visible = false
		var t := parent.create_tween()
		t.tween_interval(0.06 * i)
		t.tween_callback(func() -> void: ring.visible = true)
		t.tween_method(func(k: float) -> void:
			ring.position = from.lerp(to, k)
			ring.scale = Vector3.ONE * (1.0 + 1.8 * k), 0.0, 1.0, travel - 0.06 * i)
		t.tween_property(ring, "scale", Vector3.ZERO, 0.06)
		t.tween_callback(ring.queue_free)
	var bubble: Sprite3D = _sprite(parent, _tex_bubble(colour), to, 1.25)
	_pop(parent, bubble, travel, 0.32, 1.0)
	for i: int in 6:
		var shard: Sprite3D = _sprite(parent, _tex_hex(colour), to, 0.16)
		shard.visible = false
		var away: Vector3 = Vector3(cos(TAU * i / 6.0), 0.4 + 0.3 * (i % 2), sin(TAU * i / 6.0)) * 0.7
		var s := parent.create_tween()
		s.tween_interval(travel + 0.48)
		s.tween_callback(func() -> void: shard.visible = true)
		s.tween_property(shard, "position", to + away, 0.22).set_ease(Tween.EASE_OUT)
		s.parallel().tween_property(shard, "scale", Vector3.ZERO, 0.22).set_ease(Tween.EASE_IN)
		s.tween_callback(shard.queue_free)
	return travel


## The Arc Coilgun: a jagged inked lightning bolt with a forked branch, redrawn three times as it
## flickers, a zap star at the end.
static func _arc(parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color) -> float:
	_muzzle(parent, from, colour, 0.36)
	var side: Vector3 = (to - from).cross(Vector3.UP).normalized()
	for flick: int in 3:
		var points: Array = [from]
		var steps: int = 8
		for i: int in steps - 1:
			points.append(from.lerp(to, float(i + 1) / steps) + side * randf_range(-0.2, 0.2)
				+ Vector3(0, randf_range(-0.16, 0.16), 0))
		points.append(to)
		var pieces: Array = []
		for i: int in points.size() - 1:
			pieces.append(_ribbon(parent, _tex_beam(colour), points[i], points[i + 1], 0.11 if flick == 0 else 0.08))
		# A fork off the middle that dies in the air.
		var root_at: Vector3 = points[3]
		var fork_end: Vector3 = root_at + (to - from).normalized() * 0.5 + side * (0.35 if flick % 2 == 0 else -0.35)
		pieces.append(_ribbon(parent, _tex_beam(colour), root_at, fork_end, 0.06))
		for piece: Variant in pieces:
			var p: MeshInstance3D = piece
			p.visible = false
			var t := parent.create_tween()
			t.tween_interval(0.06 * flick)
			t.tween_callback(func() -> void: p.visible = true)
			t.tween_interval(0.055)
			t.tween_callback(p.queue_free)
	_hit(parent, vfx, to, colour, 0.02, 0.0055, 9)
	return 0.02


## The Sunspear (078, the user: "too thick and cartoony"): a jagged star at the barrel; a narrow,
## hard spear of light -- a white core in a hatched gold band with a serrated ink edge -- that stabs out,
## burns a beat while crackles of energy jump along it, and is cut thin.
static func _sun(parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color) -> float:
	_muzzle(parent, from, colour, 0.5)
	var beam: MeshInstance3D = _ribbon(parent, _tex_sunbeam(colour), from, to, 0.05, 0.45)
	var t := parent.create_tween()
	t.tween_method(func(w: float) -> void: _width(beam, w), 0.05, 0.17, 0.05).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.3)
	t.tween_callback(func() -> void: _width(beam, 0.1))
	t.tween_interval(0.05)
	t.tween_callback(func() -> void: _width(beam, 0.04))
	t.tween_interval(0.05)
	t.tween_callback(beam.queue_free)
	var side: Vector3 = (to - from).cross(Vector3.UP).normalized()
	for flick: int in 4:
		var a: float = randf_range(0.15, 0.75)
		var start: Vector3 = from.lerp(to, a)
		var points: Array = [start]
		for i: int in 4:
			points.append(from.lerp(to, a + 0.05 * (i + 1)) + side * randf_range(-0.14, 0.14)
				+ Vector3(0, randf_range(-0.12, 0.12), 0))
		for i: int in points.size() - 1:
			var piece: MeshInstance3D = _ribbon(parent, _tex_beam(colour), points[i], points[i + 1], 0.04)
			piece.visible = false
			var c := parent.create_tween()
			c.tween_interval(0.06 + 0.07 * flick)
			c.tween_callback(func() -> void: piece.visible = true)
			c.tween_interval(0.06)
			c.tween_callback(piece.queue_free)
	for i: int in 6:
		_later(parent, 0.05 * i, func() -> void: vfx.sparks(from.lerp(to, randf_range(0.2, 1.0)), colour, 3, 0.7))
	_speed_lines(parent, from, to, 0.0, 4)
	if parent.is_visible_in_tree():
		vfx.shake(0.4)
	_hit(parent, vfx, to, colour, 0.05, 0.0065, 8)
	return 0.05


## The Snare Launcher: a bola -- two inked iron weights on a cord -- whirls out and wraps into a drawn
## net over the target.
static func _bola(parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color) -> float:
	var travel: float = 0.26
	var a: Sprite3D = _sprite(parent, _tex_shell(colour), from, 0.22)
	var b: Sprite3D = _sprite(parent, _tex_shell(colour), from, 0.22)
	var cord: MeshInstance3D = _ribbon(parent, _tex_cord(colour), from, from, 0.09)
	var side: Vector3 = (to - from).cross(Vector3.UP).normalized()
	var t := parent.create_tween()
	t.tween_method(func(k: float) -> void:
		var centre: Vector3 = from.lerp(to, k) + Vector3(0, sin(k * PI) * 0.3, 0)
		var spin: float = k * TAU * 3.0
		var arm: Vector3 = (side * cos(spin) + Vector3.UP * sin(spin)) * 0.24
		a.position = centre + arm
		b.position = centre - arm
		_lay(cord, a.position, b.position), 0.0, 1.0, travel)
	t.tween_callback(func() -> void:
		a.queue_free()
		b.queue_free()
		cord.queue_free())
	var net: Sprite3D = _sprite(parent, _tex_net(colour), to, 0.95)
	_pop(parent, net, travel, 0.55, 1.0)
	_hit(parent, vfx, to, colour, travel, 0.0035, 3)
	return travel


## The Mine Layer: an inked mine hops out along a dotted arc, bounces once, and its red eye blinks.
static func _mine(parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color) -> float:
	var travel: float = 0.38
	var mine: Sprite3D = _sprite(parent, _tex_mine(colour, false), from, 0.36)
	var path := func(k: float) -> Vector3: return from.lerp(to, k) + Vector3(0, sin(k * PI) * 0.7, 0)
	for i: int in 6:
		var k: float = 0.1 + 0.15 * i
		var dot: Sprite3D = _sprite(parent, _tex_diamond(Ink.PAPER), path.call(k), 0.11)
		_pop(parent, dot, travel * 0.8 * k, 0.3, 1.0)
	var t := parent.create_tween()
	t.tween_method(func(k: float) -> void: mine.position = path.call(k), 0.0, 1.0, travel * 0.8)
	t.tween_callback(func() -> void:
		if parent.is_visible_in_tree():
			vfx.dust(to, 3, 0.5))
	t.tween_property(mine, "position", to + Vector3(0, 0.15, 0), travel * 0.1).set_ease(Tween.EASE_OUT)
	t.tween_property(mine, "position", to, travel * 0.1).set_ease(Tween.EASE_IN)
	for blink: int in 3:
		t.tween_callback(func() -> void: mine.texture = _tex_mine(colour, true))
		t.tween_interval(0.08)
		t.tween_callback(func() -> void: mine.texture = _tex_mine(colour, false))
		t.tween_interval(0.08)
	t.tween_property(mine, "scale", Vector3.ZERO, 0.08)
	t.tween_callback(mine.queue_free)
	return travel


## The Chain Flail (079): a swoosh drawn round the machine across the arc it sweeps -- a crescent of motion
## strokes that grows from thin to thick as the head comes round, a star and a spray of grit on every
## hex it crosses, burning down into grit behind it.
static func _swing(parent: Node3D, vfx: BattleVFX, from: Vector3, to: Vector3, colour: Color, cells: Array,
		centre: Vector3) -> float:
	var travel: float = 0.16
	var flat := Vector3(centre.x, 0.0, centre.z)
	var aim: Vector3 = Vector3(to.x, 0.0, to.z) - flat
	var mid: float = atan2(aim.x, aim.z)
	var spread: float = 0.5
	for c: Variant in cells:
		var d: Vector3 = (c as Vector3) - flat
		spread = maxf(spread, absf(wrapf(atan2(d.x, d.z) - mid, -PI, PI)) + 0.15)
	var reach: float = maxf(0.6, Vector2(aim.x, aim.z).length())
	var height: float = from.y
	var pieces: int = 14
	var arc := func(s: float) -> Vector3:
		var b: float = mid - spread + 2.0 * spread * s
		return flat + Vector3(sin(b), 0.0, cos(b)) * reach + Vector3(0, height - 0.25 * s, 0)
	for i: int in pieces:
		var s0: float = float(i) / pieces
		var s1: float = float(i + 1) / pieces
		var piece: MeshInstance3D = _ribbon(parent, _tex_swoosh(colour), arc.call(s0), arc.call(s1), 0.05 + 0.3 * s1)
		piece.visible = false
		var t := parent.create_tween()
		t.tween_interval(travel * s0)
		t.tween_callback(func() -> void: piece.visible = true)
		t.tween_interval(0.08)
		t.tween_callback(func() -> void: _burn(parent, piece, 0.0, 0.18))
	for c: Variant in cells:
		var at: Vector3 = c as Vector3
		var d: Vector3 = at - flat
		var s: float = clampf((wrapf(atan2(d.x, d.z) - mid, -PI, PI) + spread) / (2.0 * spread), 0.0, 1.0)
		_later(parent, travel * s, func() -> void:
			vfx.star(at + Vector3(0, 0.45, 0), 0.0045, 0.04)
			vfx.sparks(at + Vector3(0, 0.4, 0), colour, 6, 1.1)
			vfx.dust(Vector3(at.x, 0.06, at.z), 3, 0.5))
	return travel


# --- Shared beats --------------------------------------------------------------

## The muzzle: a spiky drawn star in the shot's colour that pops and is gone.
static func _muzzle(parent: Node3D, at: Vector3, colour: Color, size: float) -> void:
	var star: Sprite3D = _sprite(parent, _tex_muzzle(colour), at, size * 1.3)
	star.flip_h = randf() < 0.5
	star.rotate_z(randf_range(-0.5, 0.5))
	star.scale = Vector3.ONE * 0.5
	var t := parent.create_tween()
	t.tween_property(star, "scale", Vector3.ONE * 1.1, 0.04).set_ease(Tween.EASE_OUT)
	Grit.erode(parent, star, 0.05, 0.12)


## Where it lands: the game's impact star and drawn sparks, `delay` seconds from now.
static func _hit(parent: Node3D, vfx: BattleVFX, at: Vector3, colour: Color, delay: float, star: float, sparks: int) -> void:
	_later(parent, delay, func() -> void:
		if star > 0.0:
			vfx.star(at, star, 0.05)
		if sparks > 0:
			vfx.sparks(at, colour, sparks, 1.0))


## Comic speed lines: short ink strokes beside the path, drawn the moment the shot passes.
static func _speed_lines(parent: Node3D, from: Vector3, to: Vector3, delay: float, count: int) -> void:
	var dir: Vector3 = (to - from).normalized()
	var side: Vector3 = dir.cross(Vector3.UP).normalized()
	for i: int in count:
		var k: float = 0.15 + 0.7 * float(i) / maxf(1.0, float(count - 1))
		var off: Vector3 = side * (0.16 if i % 2 == 0 else -0.16) + Vector3(0, 0.1 * float(i % 3 - 1), 0)
		var start: Vector3 = from.lerp(to, k) + off
		var stroke: MeshInstance3D = _ribbon(parent, _tex_speed(), start, start + dir * 0.6, 0.12)
		stroke.visible = false
		var t := parent.create_tween()
		t.tween_interval(delay + 0.02 * i)
		t.tween_callback(func() -> void: stroke.visible = true)
		t.tween_interval(0.12)
		t.tween_method(func(w: float) -> void: _width(stroke, w), 0.12, 0.0, 0.08)
		t.tween_callback(stroke.queue_free)


# --- Pieces --------------------------------------------------------------------

## A sprite (the drawn-effect look of `BattleVFX._sprite`), `size` metres across.
static func _sprite(parent: Node3D, tex: Texture2D, at: Vector3, size: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.no_depth_test = true
	s.render_priority = 2
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.pixel_size = size / float(tex.get_width())
	s.position = at
	parent.add_child(s)
	return s


## A ribbon from `from` to `to`, `width` wide, turned to the camera about its own line. `tile` repeats the
## texture every so many metres along it (a beam, a chain); 0 stretches it once (a dart, a tail).
static func _ribbon(parent: Node3D, tex: Texture2D, from: Vector3, to: Vector3, width: float, tile: float = 0.0) -> MeshInstance3D:
	var ribbon := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	ribbon.mesh = quad
	ribbon.material_override = _flat(tex, tile > 0.0)
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ribbon.set_meta("width", width)
	ribbon.set_meta("tile", tile)
	parent.add_child(ribbon)
	_lay(ribbon, from, to)
	return ribbon


## Lays a ribbon from `from` to `to` (parent space), facing the camera as well as its line allows.
static func _lay(ribbon: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	if not is_instance_valid(ribbon):
		return
	ribbon.set_meta("from", from)
	ribbon.set_meta("to", to)
	var axis: Vector3 = to - from
	var length: float = axis.length()
	var width: float = float(ribbon.get_meta("width", 0.1))
	if length < 0.001 or width <= 0.0001:
		ribbon.visible = false
		return
	ribbon.visible = true
	var dir: Vector3 = axis / length
	var middle: Vector3 = (from + to) * 0.5
	var view: Vector3 = Vector3.UP
	var camera: Camera3D = ribbon.get_viewport().get_camera_3d() if ribbon.is_inside_tree() else null
	if camera != null:
		var parent: Node3D = ribbon.get_parent() as Node3D
		var eye: Vector3 = parent.to_local(camera.global_position) if parent != null else camera.global_position
		view = (eye - middle).normalized()
	var side: Vector3 = dir.cross(view)
	if side.length() < 0.001:
		side = dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT)
	side = side.normalized()
	var normal: Vector3 = dir.cross(side).normalized()
	ribbon.transform = Transform3D(Basis(dir * length, side * width, normal), middle)
	var tile: float = float(ribbon.get_meta("tile", 0.0))
	if tile > 0.0:
		(ribbon.material_override as StandardMaterial3D).uv1_scale = Vector3(length / tile, 1, 1)


## A ribbon's width, keeping where it lies.
static func _width(ribbon: MeshInstance3D, width: float) -> void:
	if not is_instance_valid(ribbon):
		return
	ribbon.set_meta("width", width)
	_lay(ribbon, ribbon.get_meta("from", Vector3.ZERO), ribbon.get_meta("to", Vector3.ZERO))


## A beam holds `hold` seconds, then snaps thin in stepped bites (drawn things do not fade).
static func _thin(parent: Node3D, ribbon: MeshInstance3D, hold: float, time: float) -> void:
	var w: float = float(ribbon.get_meta("width", 0.1))
	var t := parent.create_tween()
	t.tween_interval(hold)
	for i: int in 3:
		var step: float = w * (0.6 - 0.25 * i)
		t.tween_callback(func() -> void: _width(ribbon, step))
		t.tween_interval(time / 3.0)
	t.tween_callback(ribbon.queue_free)


## A ribbon burns down into grit: its alpha cut raised from 0.5 to 1 (erodible textures), then gone.
static func _burn(parent: Node3D, ribbon: MeshInstance3D, delay: float, time: float) -> void:
	var m: StandardMaterial3D = ribbon.material_override
	var t := parent.create_tween()
	t.tween_interval(delay)
	t.tween_property(m, "alpha_scissor_threshold", 1.0, time).set_ease(Tween.EASE_IN)
	t.tween_callback(ribbon.queue_free)


## A flat drawn disc at `at` facing along `normal` (a ring the shot passes through).
static func _disc(parent: Node3D, tex: Texture2D, at: Vector3, normal: Vector3, size: float) -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	disc.mesh = quad
	disc.material_override = _flat(tex, false)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(disc)
	disc.position = at
	var n: Vector3 = normal.normalized() if normal.length() > 0.001 else Vector3.FORWARD
	var up: Vector3 = Vector3.UP if absf(n.y) < 0.95 else Vector3.RIGHT
	disc.basis = Basis.looking_at(-n, up)
	return disc


## Pops a sprite in after `delay`, holds it `hold` seconds, shrinks it away.
static func _pop(parent: Node3D, node: Node3D, delay: float, hold: float, size: float) -> void:
	node.visible = delay <= 0.0
	node.scale = Vector3.ONE * size * 0.3
	var t := parent.create_tween()
	if delay > 0.0:
		t.tween_interval(delay)
		t.tween_callback(func() -> void: node.visible = true)
	t.tween_property(node, "scale", Vector3.ONE * size * 1.15, 0.05).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector3.ONE * size, 0.04)
	t.tween_interval(hold)
	t.tween_property(node, "scale", Vector3.ZERO, 0.08).set_ease(Tween.EASE_IN)
	t.tween_callback(node.queue_free)


## A ring: popped in after `delay`, grown to `grow`, then gone.
static func _pop_disc(parent: Node3D, disc: MeshInstance3D, delay: float, time: float, grow: float) -> void:
	disc.visible = delay <= 0.0
	disc.scale = Vector3.ONE * 0.4
	var t := parent.create_tween()
	if delay > 0.0:
		t.tween_interval(delay)
		t.tween_callback(func() -> void: disc.visible = true)
	t.tween_property(disc, "scale", Vector3.ONE * grow, time).set_ease(Tween.EASE_OUT)
	t.tween_property(disc, "scale", Vector3.ZERO, 0.06)
	t.tween_callback(disc.queue_free)


## A drawn surface: unshaded, cut out by its alpha, both sides. One held variant per tiling; each piece
## its own copy (a ribbon's tiling is set per length).
static func _flat(tex: Texture2D, tiled: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = tex
	m.texture_repeat = tiled
	m.disable_receive_shadows = true
	m.render_priority = 1
	return Ink.hold(m) as StandardMaterial3D


## `what` after `delay`, unless the trail has been hidden by then (the warm-up's, behind the card).
static func _later(parent: Node3D, delay: float, what: Callable, always: bool = false) -> void:
	var t := parent.create_tween()
	t.tween_interval(maxf(0.0, delay))
	t.tween_callback(func() -> void:
		if always or parent.is_visible_in_tree():
			what.call())


# --- Drawings ------------------------------------------------------------------
# 076: painted once per colour in the `Grit` vocabulary -- jagged edges, a thick wobbling ink line,
# hatched shade (crossed where darkest), grain in the fills, the colour in hard saturated bands with a
# white-hot heart. Fire and flashes are erodible (`Grit.erode_alpha`).

static func _shade(c: Color) -> Color:
	return c.darkened(0.45)


static func _hot(c: Color) -> Color:
	return c.lerp(Color("fff6dc"), 0.62)


## A beam, tiling along x: a wobbling ink edge, the colour hatched toward its rim, a crackle line
## running through it, a grainy hot core and a white heart.
static func _tex_beam(c: Color) -> ImageTexture:
	return Ink.texture("shot2_beam_" + c.to_html(), Vector2i(256, 64), func(image: Image) -> void:
		for y: int in 64:
			for x: int in 256:
				var u: float = TAU * float(x) / 256.0
				var h: float = 25.0 + 3.0 * sin(u * 3.0) + 2.0 * sin(u * 7.0 + 1.0) + 1.2 * sin(u * 17.0)
				var d: float = absf(float(y) - 31.5)
				var col := Color(0, 0, 0, 0)
				if d < h:
					col = Ink.INK
				if d < h - 5.0:
					col = c
					if d > h * 0.55 and Grit.hatch(x, y, 8.0, 2.2):
						col = _shade(c)
					if d < h * 0.4:
						col = _hot(c)
						if Grit.speck(x, y, 0.1):
							col = c
					if d < h * 0.14:
						col = Color.WHITE
					var crack: float = h * 0.62 + 4.0 * sin(u * 11.0) + 2.0 * sin(u * 23.0)
					if absf(d - crack) < 0.9 and sin(u * 5.0) > -0.2:
						col = Ink.INK
				image.set_pixel(x, y, col))


## The muzzle flash: the shared jagged star (`Grit.star_texture`), the same as `BattleVFX.muzzle_flash`.
static func _tex_muzzle(c: Color) -> ImageTexture:
	return Grit.star_texture("muzzle_" + c.to_html(), c, _hot(c), 991)


## An energy bolt: a hot core in a crackling spiky corona, ink edge, hatched shade.
static func _tex_ball(c: Color) -> ImageTexture:
	return Ink.texture("shot2_ball_" + c.to_html(), Vector2i(96, 96), func(image: Image) -> void:
		var centre := Vector2(48, 48)
		for y: int in 96:
			for x: int in 96:
				var d: Vector2 = Vector2(x, y) - centre
				var r: float = d.length()
				var spike: float = absf(sin(d.angle() * 6.0 + 0.7)) * 9.0 + absf(Grit.noise(x, y, 0.12, 9)) * 8.0
				var edge: float = 28.0 + spike
				var col := Color(0, 0, 0, 0)
				if r < edge:
					col = Ink.INK
				if r < edge - 5.0:
					col = c
					if Vector2(x, y).distance_to(centre + Vector2(-8, -8)) > 26.0 and Grit.hatch(x, y, 6.0, 1.8):
						col = _shade(c)
				if r < 18.0:
					col = _hot(c)
				if r < 8.0 or Vector2(x, y).distance_to(centre + Vector2(-7, -7)) < 4.0:
					col = Color.WHITE
				image.set_pixel(x, y, col))


## A tail: a jagged streak, thin and broken at the back (left), full at the head (right).
static func _tex_tail(c: Color) -> ImageTexture:
	return Ink.texture("shot2_tail_" + c.to_html(), Vector2i(192, 32), func(image: Image) -> void:
		for y: int in 32:
			for x: int in 192:
				var u: float = float(x) / 191.0
				var half: float = 15.0 * pow(u, 0.75) + Grit.noise(x, 0.0, 0.08, 12) * 3.0 * u
				var d: float = absf(float(y) - 15.5)
				var broken: bool = u < 0.45 and Grit.noise(x, 0.0, 0.15, 13) > 0.25
				var col := Color(0, 0, 0, 0)
				if d < half and not broken:
					col = Ink.INK
					if d < half - 3.5:
						col = c
						if float(y) > 16.0 and Grit.hatch(x, y, 6.0, 1.6):
							col = _shade(c)
						if d < (half - 3.5) * 0.35:
							col = _hot(c)
				image.set_pixel(x, y, col))


## A dart: a long steel-and-colour needle, pointed at the head (right), notched fletches at the tail,
## hatched underside, a white glint along its top.
static func _tex_dart(c: Color) -> ImageTexture:
	return Ink.texture("shot2_dart_" + c.to_html(), Vector2i(192, 32), func(image: Image) -> void:
		for y: int in 32:
			for x: int in 192:
				var u: float = float(x) / 191.0
				var half: float = 8.0 if u < 0.78 else 8.0 * (1.0 - (u - 0.78) / 0.22)
				if u < 0.16:
					half = 14.0 - fposmod(float(x), 10.0) * 0.6
				var d: float = float(y) - 15.5
				var col := Color(0, 0, 0, 0)
				if absf(d) < half + 1.5:
					col = Ink.INK
				if absf(d) < half - 2.0:
					col = _hot(c)
					if d > 1.0 and Grit.hatch(x, y, 5.0, 1.5):
						col = _shade(c)
					if d < -half * 0.4 and d > -half + 3.0:
						col = Color.WHITE
				image.set_pixel(x, y, col))


## A bullet slug: a hard pointed slug at the head (right) and a ragged streak behind.
static func _tex_slug(c: Color) -> ImageTexture:
	return Ink.texture("shot2_slug_" + c.to_html(), Vector2i(128, 32), func(image: Image) -> void:
		for y: int in 32:
			for x: int in 128:
				var u: float = float(x) / 127.0
				var d: float = float(y) - 15.5
				var half: float = 12.0 * minf(1.0, u / 0.7) + Grit.noise(x, 0.0, 0.2, 14) * 2.5 * (1.0 - u)
				if u > 0.86:
					half = 12.0 * (1.0 - (u - 0.86) / 0.14) + 2.0
				var col := Color(0, 0, 0, 0)
				if absf(d) < half:
					col = Ink.INK
				if absf(d) < half - 3.0:
					col = c if u < 0.72 else _hot(c)
					if d > 1.0 and Grit.hatch(x, y, 5.0, 1.5):
						col = _shade(c)
					if u > 0.72 and d < -3.0:
						col = Color.WHITE
				image.set_pixel(x, y, col))


## A shock ring: a jagged band of the colour between wobbling ink lines, broken in three places,
## hatched.
static func _tex_ring(c: Color) -> ImageTexture:
	return Ink.texture("shot2_ring_" + c.to_html(), Vector2i(128, 128), func(image: Image) -> void:
		var centre := Vector2(64, 64)
		for y: int in 128:
			for x: int in 128:
				var d: Vector2 = Vector2(x, y) - centre
				var r: float = d.length() + Grit.noise(x, y, 0.1, 15) * 4.0
				var gap: bool = fposmod(d.angle() / TAU * 3.0 + 0.1, 1.0) < 0.08
				var col := Color(0, 0, 0, 0)
				if r < 60.0 and r > 40.0 and not gap:
					col = Ink.INK
					if r < 55.0 and r > 45.0:
						col = c
						if Grit.hatch(x, y, 6.0, 1.6):
							col = _shade(c)
						if r > 52.0:
							col = _hot(c)
				image.set_pixel(x, y, col))


## A hexagon ring (the Aegis): a hex band of the colour between ink lines, hatched, a hot inner edge.
static func _tex_hex(c: Color) -> ImageTexture:
	return Ink.texture("shot2_hex_" + c.to_html(), Vector2i(128, 128), func(image: Image) -> void:
		for y: int in 128:
			for x: int in 128:
				var q := Vector2(absf(float(x) - 63.5), absf(float(y) - 63.5))
				var h: float = maxf(q.x * 0.866 + q.y * 0.5, q.y) + Grit.noise(x, y, 0.12, 16) * 2.0
				var col := Color(0, 0, 0, 0)
				if h < 60.0 and h > 38.0:
					col = Ink.INK
				if h < 55.0 and h > 43.0:
					col = c
					if h > 50.0 and Grit.hatch(x, y, 6.0, 1.6):
						col = _shade(c)
					if h < 46.0:
						col = _hot(c)
				image.set_pixel(x, y, col))


## The Aegis bubble: a thick hatched rim, a hex lattice of plates inside (some filled, some open), a
## white glint; grainy.
static func _tex_bubble(c: Color) -> ImageTexture:
	return Ink.texture("shot2_bubble_" + c.to_html(), Vector2i(224, 224), func(image: Image) -> void:
		var centre := Vector2(112, 112)
		for y: int in 224:
			for x: int in 224:
				var p := Vector2(x, y)
				var r: float = p.distance_to(centre) + Grit.noise(x, y, 0.05, 17) * 3.0
				var col := Color(0, 0, 0, 0)
				if r < 108.0:
					var line: bool = false
					var cell: int = 0
					for k: int in 3:
						var a: float = PI / 3.0 * k
						var s: float = (p - centre).dot(Vector2(cos(a), sin(a)))
						cell += int(floor(s / 30.0)) * (k + 3)
						if absf(fposmod(s, 30.0) - 15.0) > 13.2:
							line = true
					if line:
						col = Ink.INK
					elif posmod(cell, 5) == 0 and r < 90.0:
						col = c if Grit.hatch(x, y, 7.0, 2.4) else Color(0, 0, 0, 0)
				if r < 108.0 and r > 92.0:
					col = c
					if r > 99.0 and Grit.hatch(x, y, 6.0, 2.0):
						col = _shade(c)
				if r < 108.0 and (r > 104.0 or (r > 89.0 and r < 93.0)):
					col = Ink.INK
				if p.distance_to(centre + Vector2(-48, -54)) < 11.0 and r < 90.0:
					col = Color.WHITE
				image.set_pixel(x, y, col))


## A diamond: a sharp point of a sight line or a dotted path, ink-edged.
static func _tex_diamond(c: Color) -> ImageTexture:
	return Ink.texture("shot2_diamond_" + c.to_html(), Vector2i(32, 32), func(image: Image) -> void:
		for y: int in 32:
			for x: int in 32:
				var m: float = absf(float(x) - 15.5) * 1.4 + absf(float(y) - 15.5)
				var col := Color(0, 0, 0, 0)
				if m < 15.0:
					col = Ink.INK
				if m < 9.5:
					col = c
				if m < 4.0:
					col = _hot(c)
				image.set_pixel(x, y, col))


## A dashed sight line, tiling along x: hard dashes, ink-edged.
static func _tex_dash(c: Color) -> ImageTexture:
	return Ink.texture("shot2_dash_" + c.to_html(), Vector2i(64, 16), func(image: Image) -> void:
		for y: int in 16:
			for x: int in 64:
				var d: float = absf(float(y) - 7.5)
				var col := Color(0, 0, 0, 0)
				if x < 40:
					if d < 7.0:
						col = Ink.INK
					if d < 3.5 and x > 3 and x < 37:
						col = c
				image.set_pixel(x, y, col))


## The reticle: a broken ring with corner brackets and four ticks, ink-edged, the colour inside the lines.
static func _tex_reticle(c: Color) -> ImageTexture:
	return Ink.texture("shot2_reticle_" + c.to_html(), Vector2i(160, 160), func(image: Image) -> void:
		var centre := Vector2(80, 80)
		for y: int in 160:
			for x: int in 160:
				var d: Vector2 = Vector2(x, y) - centre
				var r: float = d.length()
				var quarter: float = fposmod(d.angle() / TAU * 4.0 + 0.125, 1.0)
				var ring: bool = r > 56.0 and r < 72.0 and absf(quarter - 0.5) < 0.38
				var tick: bool = r > 26.0 and r < 62.0 and (absf(d.x) < 5.0 or absf(d.y) < 5.0)
				var col := Color(0, 0, 0, 0)
				if ring or tick:
					col = Ink.INK
				if (r > 60.0 and r < 68.0 and absf(quarter - 0.5) < 0.34) or (r > 29.0 and r < 59.0 and (absf(d.x) < 2.0 or absf(d.y) < 2.0)):
					col = c
				image.set_pixel(x, y, col))


## a white heart; ink edge; erodible.
static func _tex_flame(c: Color) -> ImageTexture:
	return Ink.texture("shot2_flame_" + c.to_html(), Vector2i(128, 128), func(image: Image) -> void:
		for y: int in 128:
			for x: int in 128:
				var v: float = 1.0 - float(y) / 127.0
				var lick: float = Grit.noise(float(x) * 0.6, float(y) * 0.25, 0.09, 18)
				var half: float = 46.0 * pow(1.0 - v, 0.6) * (0.75 + 0.45 * lick) + 6.0
				var cx: float = 64.0 + Grit.noise(0.0, float(y), 0.04, 19) * 14.0 * v
				var depth: float = half - absf(float(x) - cx)
				if v < 0.12:
					depth = minf(depth, (v / 0.12) * 40.0 - 2.0)
				var col := Color(0, 0, 0, 0)
				if depth > 0.0:
					col = Ink.INK
				if depth > 5.0:
					col = Color("b0301a")
					if Grit.hatch(x, y, 6.0, 2.0):
						col = Color("6e1a0e")
				if depth > 11.0:
					col = c
				if depth > 18.0:
					col = Ink.ACTION
				if depth > 26.0:
					col = Color("fff6dc")
				if col.a > 0.0:
					col.a = Grit.erode_alpha(maxf(depth, 0.0), 30.0, x, y)
				image.set_pixel(x, y, col))


## An iron shell (or a bola weight): riveted steel, its shade hatched and grainy, a band of the colour,
## a glint, a wobbling ink edge.
static func _tex_shell(c: Color) -> ImageTexture:
	return Ink.texture("shot2_shell_" + c.to_html(), Vector2i(64, 64), func(image: Image) -> void:
		var centre := Vector2(32, 32)
		for y: int in 64:
			for x: int in 64:
				var p := Vector2(x, y)
				var r: float = p.distance_to(centre) + Grit.noise(x, y, 0.2, 21) * 1.5
				var col := Color(0, 0, 0, 0)
				if r < 30.0:
					col = Ink.INK
				if r < 25.0:
					col = Ink.STEEL
					if p.distance_to(centre + Vector2(-8, -8)) > 22.0:
						col = Color("4f575c")
						if Grit.hatch(x, y, 5.0, 1.6):
							col = Ink.INK
					if Grit.speck(x, y, 0.12, 22):
						col = col.darkened(0.3)
					var band: float = absf(float(y) - 35.0)
					if band < 4.0:
						col = c
					elif band < 6.0:
						col = Ink.INK
					for rivet: Vector2 in [Vector2(20, 35), Vector2(32, 35), Vector2(44, 35)]:
						if p.distance_to(rivet) < 2.2:
							col = Ink.INK
					if p.distance_to(centre + Vector2(-9, -11)) < 4.5:
						col = Color.WHITE
				image.set_pixel(x, y, col))


## The harpoon head: a barbed steel arrowhead pointing right, hatched underside, a band of the colour,
## ink edge.
static func _tex_hook(c: Color) -> ImageTexture:
	return Ink.texture("shot2_hook_" + c.to_html(), Vector2i(128, 64), func(image: Image) -> void:
		var head := PackedVector2Array([Vector2(126, 32), Vector2(70, 6), Vector2(80, 26), Vector2(4, 26),
			Vector2(4, 38), Vector2(80, 38), Vector2(70, 58)])
		var inner := PackedVector2Array([Vector2(116, 32), Vector2(78, 13), Vector2(85, 29), Vector2(9, 29.5),
			Vector2(9, 34.5), Vector2(85, 35), Vector2(78, 51)])
		for y: int in 64:
			for x: int in 128:
				var p := Vector2(x, y)
				var col := Color(0, 0, 0, 0)
				if Geometry2D.is_point_in_polygon(p, head):
					col = Ink.INK
				if Geometry2D.is_point_in_polygon(p, inner):
					col = Color("aeb8bb") if p.y < 31.0 else Ink.STEEL
					if p.y > 33.0 and Grit.hatch(x, y, 5.0, 1.6):
						col = Ink.INK
					if x > 18 and x < 40:
						col = c
				image.set_pixel(x, y, col))


## A chain, tiling along x: a link side-on, then one edge-on; steel with hatched shade.
static func _tex_chain() -> ImageTexture:
	return Ink.texture("shot2_chain", Vector2i(64, 24), func(image: Image) -> void:
		for y: int in 24:
			for x: int in 64:
				var col := Color(0, 0, 0, 0)
				var q := Vector2((float(x) - 18.0) / 17.0, (float(y) - 11.5) / 10.5)
				var r: float = q.length()
				if r < 1.0 and r > 0.45:
					col = Ink.INK
					if r < 0.85 and r > 0.6:
						col = Ink.STEEL if y < 12 else Color("4f575c")
				if x >= 36 and x < 62 and absf(float(y) - 11.5) < 5.0:
					col = Ink.INK
					if absf(float(y) - 11.5) < 2.0 and x > 38 and x < 60:
						col = Color("aeb8bb")
				image.set_pixel(x, y, col))


## A cord: a twisted rope, ink-edged.
static func _tex_cord(c: Color) -> ImageTexture:
	return Ink.texture("shot2_cord_" + c.to_html(), Vector2i(64, 16), func(image: Image) -> void:
		for y: int in 16:
			for x: int in 64:
				var d: float = absf(float(y) - 7.5)
				var col := Color(0, 0, 0, 0)
				if d < 7.0:
					col = Ink.INK
				if d < 4.0:
					col = c if (x + y) % 8 < 5 else _shade(c)
				image.set_pixel(x, y, col))


## A net: a ragged mesh of cords in the colour, knotted, hung from a weighted rim.
static func _tex_net(c: Color) -> ImageTexture:
	return Ink.texture("shot2_net_" + c.to_html(), Vector2i(192, 192), func(image: Image) -> void:
		var centre := Vector2(96, 96)
		for y: int in 192:
			for x: int in 192:
				var p := Vector2(x, y)
				var w: Vector2 = p + Vector2(Grit.noise(x, y, 0.03, 23), Grit.noise(x, y, 0.03, 24)) * 6.0
				var r: float = p.distance_to(centre) + Grit.noise(x, y, 0.05, 25) * 4.0
				var col := Color(0, 0, 0, 0)
				if r < 88.0:
					var u: float = fposmod(w.x + w.y, 24.0)
					var v: float = fposmod(w.x - w.y + 192.0, 24.0)
					if u < 4.5 or v < 4.5:
						col = Ink.INK
					if (u > 1.0 and u < 3.5) or (v > 1.0 and v < 3.5):
						col = c
					if u < 5.5 and v < 5.5:
						col = Ink.INK
				if r < 92.0 and r > 82.0:
					col = Ink.INK
					if r > 85.0 and r < 89.0:
						col = c
				image.set_pixel(x, y, col))


## A mine: a squat riveted dome, hatched, an eye of the colour, lit or not.
static func _tex_mine(c: Color, lit: bool) -> ImageTexture:
	return Ink.texture("shot2_mine_%s_%s" % [c.to_html(), "lit" if lit else "off"], Vector2i(64, 64), func(image: Image) -> void:
		var centre := Vector2(32, 42)
		for y: int in 64:
			for x: int in 64:
				var p := Vector2(x, y)
				var col := Color(0, 0, 0, 0)
				var q := Vector2(p.x - centre.x, (p.y - centre.y) * 1.3)
				var r: float = q.length()
				if r < 30.0 and p.y < 54.0:
					col = Ink.INK
				if r < 25.0 and p.y < 50.0:
					col = Color("4a4743")
					if p.x > 34.0 and Grit.hatch(x, y, 5.0, 1.6):
						col = Ink.INK
					if Grit.speck(x, y, 0.1, 26):
						col = col.darkened(0.3)
				if p.y > 47.0 and p.y < 50.0 and absf(p.x - 32.0) < 26.0:
					col = Ink.INK
				var eye: float = p.distance_to(Vector2(32, 33))
				if eye < 9.0:
					col = Ink.INK
				if eye < 6.0:
					col = c if lit else _shade(c)
				if lit and eye < 2.5:
					col = Color.WHITE
				image.set_pixel(x, y, col))


## Speed lines: three ragged ink strokes, sharp at the back (left), thick at the front.
static func _tex_speed() -> ImageTexture:
	return Ink.texture("shot2_speed", Vector2i(128, 32), func(image: Image) -> void:
		for y: int in 32:
			for x: int in 128:
				var col := Color(0, 0, 0, 0)
				for line: Array in [[6.0, 0.0], [16.0, 30.0], [26.0, 12.0]]:
					var start: float = float(line[1])
					if float(x) < start:
						continue
					var half: float = 2.8 * (float(x) - start) / (128.0 - start)
					if absf(float(y) - float(line[0]) - Grit.noise(x, line[0], 0.1, 28) * 1.5) < half:
						col = Ink.INK
				image.set_pixel(x, y, col))


## A flame jet laid along the throw (078): a ragged tongue pointing forward (right), thin at the nozzle
## end, swelling, licking ahead in torn tips; dark red hatched rim, orange, yellow, a white core. Erodible.
static func _tex_jet(c: Color) -> ImageTexture:
	return Ink.texture("shot2_jet_" + c.to_html(), Vector2i(192, 64), func(image: Image) -> void:
		for y: int in 64:
			for x: int in 192:
				var u: float = float(x) / 191.0
				var lick: float = Grit.noise(float(x) * 0.35, float(y) * 0.9, 0.09, 41)
				var body: float = sin(PI * pow(u, 0.65))
				if u > 0.8:
					body *= 1.0 - (u - 0.8) / 0.2 * (0.6 + 0.4 * lick)
				var half: float = 30.0 * body * (0.8 + 0.35 * lick) + 1.0
				var d: float = absf(float(y) - 31.5 - Grit.noise(float(x), 0.0, 0.03, 42) * 5.0)
				var depth: float = half - d
				var col := Color(0, 0, 0, 0)
				if depth > 0.0:
					col = Ink.INK
				if depth > 4.0:
					col = Color("b0301a")
					if Grit.hatch(x, y, 6.0, 2.0):
						col = Color("6e1a0e")
				if depth > 9.0:
					col = c
				if depth > 15.0:
					col = Ink.ACTION
				if depth > 21.0:
					col = Color("fff6dc")
				if col.a > 0.0:
					col.a = Grit.erode_alpha(maxf(depth, 0.0), 26.0, x, y)
				image.set_pixel(x, y, col))


## The Sunspear's beam, tiling along x (078): narrow and hard -- a serrated ink edge, a hatched gold
## band, a hot line and a white core.
static func _tex_sunbeam(c: Color) -> ImageTexture:
	return Ink.texture("shot2_sunbeam_" + c.to_html(), Vector2i(128, 48), func(image: Image) -> void:
		for y: int in 48:
			for x: int in 128:
				var saw: float = absf(fposmod(float(x), 10.0) - 5.0) * 0.6
				var h: float = 21.0 - saw
				var d: float = absf(float(y) - 23.5)
				var col := Color(0, 0, 0, 0)
				if d < h:
					col = Ink.INK
				if d < h - 4.0:
					col = c
					if d > 8.0 and Grit.hatch(x, y, 5.0, 1.6, -1.0):
						col = c.darkened(0.5)
					if d < 8.0:
						col = _hot(c)
					if d < 3.5:
						col = Color.WHITE
				image.set_pixel(x, y, col))


## A swoosh, tiling along x (079): motion strokes in a band -- an ink edge, the colour streaked with ink
## speed lines, a hot leading edge. Erodible.
static func _tex_swoosh(c: Color) -> ImageTexture:
	return Ink.texture("shot2_swoosh_" + c.to_html(), Vector2i(128, 48), func(image: Image) -> void:
		for y: int in 48:
			for x: int in 128:
				var d: float = float(y) - 23.5
				var h: float = 21.0 + Grit.noise(float(x), 0.0, 0.08, 43) * 2.5
				var depth: float = h - absf(d)
				var col := Color(0, 0, 0, 0)
				if depth > 0.0:
					col = Ink.INK
				if depth > 4.0:
					col = c.darkened(0.25)
					if fposmod(float(y) * 1.0 + Grit.noise(float(x), float(y), 0.05, 44) * 3.0, 7.0) < 1.6:
						col = Ink.INK
					if d < -h * 0.45:
						col = _hot(c)
				if col.a > 0.0:
					col.a = Grit.erode_alpha(maxf(depth, 0.0), 18.0, x, y)
				image.set_pixel(x, y, col))
