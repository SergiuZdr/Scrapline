class_name BattleVFX
extends Node3D

## Impact effects for the battle view.
##
## Everything here is triggered by an event the simulation already emitted. Nothing in
## this file decides anything — it is told what happened and makes it look like it hurt.
##
## Three principles, in priority order:
##
##   1. **Readability before spectacle.** The player has to see who hit whom and how
##      hard, on a phone, while twelve constructs are moving. Effects are colour-coded
##      by damage type and scaled by damage, and nothing lingers long enough to
##      obscure the next hit.
##   2. **Hitstop over particles.** A two-frame freeze on a heavy hit does more for
##      impact than any amount of sparks, and it costs nothing.
##   3. **Everything is pooled or self-freeing.** A battle emits thousands of events;
##      leaking a node per hit would end the fight in a stutter.

const SPARK_COUNT: int = 10
const IMPACT_LIFETIME: float = 0.42
const MUZZLE_LIFETIME: float = 0.09

## Damage above this fraction of the target's maximum counts as a heavy hit and earns
## hitstop plus a shake. Small hits must NOT shake, or the screen never settles.
const HEAVY_FRACTION: float = 0.12

## The shortest gap between two freezes. Long enough that a hit-stop is an event rather
## than a texture.
const HITSTOP_COOLDOWN: float = 0.62

var _shake_strength: float = 0.0
var _shake_time: float = 0.0
var _hitstop_remaining: float = 0.0
var _hitstop_cooldown: float = 0.0
var _camera_rig: Node3D

## Reused mesh and material resources. One sphere and one quad serve every effect.
static var _spark_mesh: SphereMesh
static var _flash_mesh: QuadMesh
## One soft radial falloff for every glow, puff and fireball (010): a bare quad is a square,
## and a square flash reads as a UI glitch, not as fire.
static var _soft: GradientTexture2D


func setup(camera_rig: Node3D) -> void:
	_camera_rig = camera_rig
	if _spark_mesh == null:
		_spark_mesh = SphereMesh.new()
		_spark_mesh.radius = 0.045
		_spark_mesh.height = 0.09
		_spark_mesh.radial_segments = 5
		_spark_mesh.rings = 3
	if _flash_mesh == null:
		_flash_mesh = QuadMesh.new()
		_flash_mesh.size = Vector2(0.55, 0.55)
	if _soft == null:
		_soft = GradientTexture2D.new()
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(1.0, 0.5)
		var falloff := Gradient.new()
		falloff.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		falloff.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		_soft.gradient = falloff


func _process(delta: float) -> void:
	if _hitstop_remaining > 0.0:
		_hitstop_remaining = maxf(0.0, _hitstop_remaining - delta)
	if _hitstop_cooldown > 0.0:
		_hitstop_cooldown = maxf(0.0, _hitstop_cooldown - delta)

	if _shake_time > 0.0 and _camera_rig != null:
		_shake_time = maxf(0.0, _shake_time - delta)
		var amount: float = _shake_strength * (_shake_time / 0.22)
		# Rotational shake, not positional. Moving the rig would fight the player's own
		# panning; rotating the gimbal by a fraction of a degree does not.
		_camera_rig.rotation.z = randf_range(-amount, amount) * 0.02
		if _shake_time <= 0.0:
			_camera_rig.rotation.z = 0.0


## True while a heavy hit is freezing playback. The battle scene checks this and holds
## the event queue, which is what makes a big hit land instead of sliding past.
func is_frozen() -> bool:
	return _hitstop_remaining > 0.0


# --- Effects -----------------------------------------------------------------

## Drops every effect in flight and any shake or freeze: after the fight's warm-up (play-test 7),
## which fires one of everything behind the opening card so its shaders compile there.
func settle() -> void:
	for child: Node in get_children():
		child.queue_free()
	_shake_time = 0.0
	_shake_strength = 0.0
	_hitstop_remaining = 0.0
	_hitstop_cooldown = 0.0
	if _camera_rig != null:
		_camera_rig.rotation.z = 0.0


## A muzzle flash at the attacker, oriented toward the target. Sells that a shot was
## fired even when the projectile itself is instantaneous.
func muzzle_flash(from: Vector3, toward: Vector3, colour: Color) -> void:
	var flash := MeshInstance3D.new()
	flash.mesh = _flash_mesh
	# Blown toward white. At full damage-type chroma the flash is a solid block of the
	# same colour the construct is painted, which is why a frozen one was mistaken for
	# part of the construct; fire reads as fire because its core is hotter than its edge.
	flash.material_override = Ink.hold(_unshaded_billboard(colour.lerp(Color.WHITE, 0.55), 2.6))
	var direction: Vector3 = (toward - from).normalized()
	flash.position = from + Vector3(0, 0.75, 0) + direction * 0.45
	add_child(flash)

	var tween := create_tween()
	tween.tween_property(flash, "scale", Vector3(1.9, 1.9, 1.9), MUZZLE_LIFETIME)
	tween.parallel().tween_property(flash.material_override, "albedo_color:a", 0.0, MUZZLE_LIFETIME)
	tween.tween_callback(flash.queue_free)


## Sparks at the point of impact, plus a flash. Count and speed scale with how hard the
## hit was, so a chip and a killing blow do not look the same.
func impact(at: Vector3, colour: Color, severity: float) -> void:
	var count: int = int(lerpf(6.0, float(SPARK_COUNT) * 2.0, clampf(severity, 0.0, 1.0)))
	var origin: Vector3 = at + Vector3(0, 0.7, 0)
	sparks(origin, colour, count, 1.0 + severity)

	# 023: the hit is DRAWN -- a spiked star, flat amber in an ink edge, that pops and is gone.
	# The glow flash it replaces belonged to the photographed look.
	var star := Sprite3D.new()
	star.texture = _star_texture()
	star.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	star.shaded = false
	star.no_depth_test = true
	star.render_priority = 3
	star.flip_h = _star_flip
	_star_flip = not _star_flip
	star.pixel_size = lerpf(0.0035, 0.0075, clampf(severity, 0.0, 1.0))
	star.position = origin
	star.scale = Vector3.ONE * 0.5
	add_child(star)
	var pop := create_tween()
	pop.tween_property(star, "scale", Vector3.ONE * 1.15, 0.06)
	pop.tween_property(star, "scale", Vector3.ONE, 0.05)
	pop.tween_interval(0.07)
	pop.tween_property(star, "modulate:a", 0.0, 0.06)
	pop.tween_callback(star.queue_free)


var _star_flip: bool = false


## The impact star: twelve uneven spikes, amber with a paper heart and an ink edge, drawn once.
func _star_texture() -> ImageTexture:
	return Ink.texture("impact_star", Vector2i(192, 192), func(image: Image) -> void:
		var centre := Vector2(96, 96)
		for y: int in 192:
			for x: int in 192:
				var d: Vector2 = Vector2(x, y) - centre
				var spoke: float = absf(fposmod(d.angle() / TAU * 12.0, 1.0) - 0.5) * 2.0
				var long_spoke: float = 1.0 if int(floor(fposmod(d.angle() / TAU * 12.0, 12.0))) % 2 == 0 else 0.78
				var edge: float = lerpf(92.0 * long_spoke, 46.0, spoke)
				var r: float = d.length()
				if r > edge:
					image.set_pixel(x, y, Color(0, 0, 0, 0))
				elif r > edge - 7.0:
					image.set_pixel(x, y, Ink.INK)
				elif r < edge * 0.45:
					image.set_pixel(x, y, Ink.PAPER)
				else:
					image.set_pixel(x, y, Ink.ACTION))


## A destroyed construct throws debris. This is the one effect allowed to be loud --
## a kill is the most important thing that happens in a cycle.
## 066: DRAWN, like the rest of the game (the user: comic, Borderlands -- not realistic): ink-edged
## shards that pop out of a cartoon blast and shrink away.
func destruction(at: Vector3, colour: Color) -> void:
	shards(at + Vector3(0, 0.5, 0), 9, 1.2)
	fireball(at, 0.55)
	shake(1.0)
	hitstop(0.09)


## Ink-edged scrap shards thrown in arcs from `at`; they shrink to nothing where they land.
func shards(at: Vector3, count: int, force: float = 1.0) -> void:
	var tex: Texture2D = _shard_texture()
	for i: int in count:
		var shard: Sprite3D = _sprite(tex, at, randf_range(0.0028, 0.0045))
		shard.flip_h = randf() < 0.5
		shard.flip_v = randf() < 0.5
		var dir := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
		var reach: float = randf_range(0.5, 1.3) * force
		var peak: Vector3 = at + dir * reach * 0.5 + Vector3(0, randf_range(0.4, 0.9) * force, 0)
		var land: Vector3 = at + dir * reach
		land.y = 0.08
		var t := create_tween()
		t.tween_property(shard, "position", peak, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(shard, "position", land, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_interval(0.1)
		t.tween_property(shard, "scale", Vector3.ZERO, 0.12)
		t.tween_callback(shard.queue_free)


## A ring that expands and fades. Used for Overdrive and Detonation -- the two moments
## that most deserve to be noticed.
func burst(at: Vector3, colour: Color, radius: float = 2.0) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.18
	torus.outer_radius = 0.26
	torus.rings = 12
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = Ink.hold(_unshaded(colour, 2.6))
	ring.position = at + Vector3(0, 0.5, 0)
	add_child(ring)

	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector3(radius, radius * 0.4, radius), 0.34) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring.material_override, "albedo_color:a", 0.0, 0.34)
	tween.tween_callback(ring.queue_free)


func shake(strength: float) -> void:
	# Take the strongest shake in flight rather than adding them. Accumulating shake
	# across a busy cycle turns the camera into a blur.
	_shake_strength = maxf(_shake_strength, clampf(strength, 0.0, 1.5))
	_shake_time = 0.22


## Freezes playback briefly so a heavy blow lands instead of sliding past.
##
## Rate limited, and that limit is the feature. Twelve constructs trade blows inside one
## cycle, several of them heavy, and freezing on each turned emphasis into a permanent
## stutter -- the whole battle read as a game struggling to keep up rather than as hits
## with weight behind them. Hit-stop only means "that one hurt" if most hits do not get
## it, so a freeze claims the next HITSTOP_COOLDOWN seconds and every other hit in that
## window plays through at full speed.
func hitstop(duration: float) -> void:
	if _hitstop_cooldown > 0.0:
		return
	_hitstop_remaining = maxf(_hitstop_remaining, duration)
	_hitstop_cooldown = HITSTOP_COOLDOWN


# --- Helpers -----------------------------------------------------------------

## Flashes always face the camera. With a free-orbiting camera a fixed quad is edge-on
## from half the angles the player can choose, which reads as the effect not firing.
func _unshaded_billboard(colour: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = _unshaded(colour, energy)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = _soft
	return material


## Sparks thrown from a point, falling under gravity. 066: drawn sparks -- a flat sliver with an
## ink edge, tinted by `colour`, shrinking to nothing (no glow: the game is a comic, not a photo).
func sparks(at: Vector3, colour: Color, count: int, force: float = 1.0) -> void:
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.amount = maxi(2, count)
	burst.lifetime = 0.45
	burst.explosiveness = 0.95
	burst.direction = Vector3(0, 1, 0)
	burst.spread = 80.0
	burst.initial_velocity_min = 1.6 * force
	burst.initial_velocity_max = 3.6 * force
	burst.gravity = Vector3(0, -9.0, 0)
	burst.particle_flag_align_y = true
	burst.scale_amount_min = 0.7
	burst.scale_amount_max = 1.3
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(0.7, 0.8))
	shrink.add_point(Vector2(1.0, 0.0))
	burst.scale_amount_curve = shrink
	var streak := QuadMesh.new()
	streak.size = Vector2(0.06, 0.2)
	streak.material = _drawn_particle("spark", _spark_texture(), colour.lerp(Color.WHITE, 0.3))
	burst.mesh = streak
	burst.position = at
	add_child(burst)
	burst.emitting = true
	get_tree().create_timer(0.9).timeout.connect(burst.queue_free)


## Something goes up (066: drawn): action lines burst out, a lumpy cartoon blast -- pale heart,
## yellow, orange with half-tone dots, a thick ink edge -- pops big, holds a beat and shrinks
## away into cartoon smoke balls; shards and sparks fly; a scorch is left on the ground.
func fireball(at: Vector3, radius: float = 1.0) -> void:
	var middle: Vector3 = at + Vector3(0, 0.5, 0)
	var rays: Sprite3D = _sprite(_rays_texture(), middle, 0.011 * radius)
	rays.scale = Vector3.ONE * 0.6
	var r := create_tween()
	r.tween_property(rays, "scale", Vector3.ONE * 1.35, 0.1).set_ease(Tween.EASE_OUT)
	r.tween_property(rays, "modulate:a", 0.0, 0.08)
	r.tween_callback(rays.queue_free)
	for layer: int in 2:
		var boom: Sprite3D = _sprite(_boom_texture(), middle + Vector3(randf_range(-0.15, 0.15), 0.12 * layer, 0),
			(0.0085 if layer == 0 else 0.0055) * radius)
		boom.flip_h = randf() < 0.5
		boom.render_priority = 3 + layer
		boom.scale = Vector3.ONE * 0.2
		var t := create_tween()
		t.tween_interval(0.05 * layer)
		t.tween_property(boom, "scale", Vector3.ONE * 1.18, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(boom, "scale", Vector3.ONE, 0.05)
		t.tween_interval(0.16)
		t.tween_property(boom, "scale", Vector3.ZERO, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.tween_callback(boom.queue_free)
	get_tree().create_timer(0.24).timeout.connect(smoke.bind(middle + Vector3(0, 0.2, 0), 7, radius))
	shards(middle, 5, radius * 1.4)
	sparks(middle, Ink.ACTION, 16, 1.5)
	scorch(at, radius)


## Cartoon smoke balls (066): flat grey, a shadow side, a highlight and an ink edge. Each pops in,
## drifts up and SHRINKS out -- drawn smoke does not fade.
func smoke(at: Vector3, count: int, size: float = 1.0) -> void:
	var tex: Texture2D = _puff_texture()
	for i: int in mini(count, 9):
		var start: Vector3 = at + Vector3(randf_range(-0.3, 0.3), randf_range(-0.1, 0.2), randf_range(-0.3, 0.3)) * size
		var puff: Sprite3D = _sprite(tex, start, randf_range(0.0035, 0.006) * size)
		puff.flip_h = randf() < 0.5
		puff.render_priority = 1
		puff.scale = Vector3.ZERO
		var rise: float = randf_range(0.9, 1.4)
		var t := create_tween()
		t.tween_interval(randf_range(0.0, 0.12))
		t.tween_property(puff, "scale", Vector3.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(puff, "position", start + Vector3(randf_range(-0.2, 0.2), randf_range(0.5, 0.9) * size, 0.0), rise) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(puff, "scale", Vector3.ZERO, rise * 0.6).set_delay(rise * 0.4).set_ease(Tween.EASE_IN)
		t.tween_callback(puff.queue_free)


## A drawn effect: a flat billboard over the world (unshaded, in front of the machine it belongs to).
func _sprite(tex: Texture2D, at: Vector3, px: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.no_depth_test = true
	s.render_priority = 2
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.pixel_size = px
	s.position = at
	add_child(s)
	return s


static var _particle_materials: Dictionary = {}


## One held material per drawn particle and tint (a material made per burst recompiled, 024).
func _drawn_particle(name: String, tex: Texture2D, tint: Color) -> StandardMaterial3D:
	var key: String = name + tint.to_html()
	if _particle_materials.has(key):
		return _particle_materials[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.albedo_texture = tex
	m.albedo_color = tint
	m.disable_receive_shadows = true
	_particle_materials[key] = Ink.hold(m)
	return m


## The blast: lumpy lobes (a union of circles), a pale heart, yellow, orange with half-tone dots,
## and a thick ink edge.
func _boom_texture() -> ImageTexture:
	return Ink.texture("comic_boom", Vector2i(256, 256), func(image: Image) -> void:
		var c := Vector2(128, 128)
		var lobes: Array = [[c, 64.0]]
		for k: int in 9:
			var ang: float = TAU * float(k) / 9.0 + 0.3
			lobes.append([c + Vector2(cos(ang), sin(ang)) * (60.0 + 6.0 * float(k % 2)), 40.0 + 7.0 * float(k % 3)])
		var orange := Color("ff7a1f")
		var dots := Color("d8401c")
		var pale := Color("fff4c2")
		for y: int in 256:
			for x: int in 256:
				var p := Vector2(x, y)
				var f: float = -INF
				for lobe: Array in lobes:
					f = maxf(f, float(lobe[1]) - p.distance_to(lobe[0]))
				if f < 0.0:
					image.set_pixel(x, y, Color(0, 0, 0, 0))
					continue
				if f < 9.0:
					image.set_pixel(x, y, Ink.INK)
					continue
				# Bands follow the lumps: how deep inside the outline, not distance from the middle.
				var depth: float = f / 64.0
				var col: Color = orange
				if depth > 0.62:
					col = pale
				elif depth > 0.36:
					col = Ink.ACTION
				else:
					var cell := Vector2(fposmod(float(x), 11.0) - 5.5, fposmod(float(y), 11.0) - 5.5)
					if cell.length() < (0.36 - depth) * 14.0:
						col = dots
				image.set_pixel(x, y, col))


## Action lines: ink strokes bursting out of the middle, thick inside, sharp at the tip.
func _rays_texture() -> ImageTexture:
	return Ink.texture("comic_rays", Vector2i(256, 256), func(image: Image) -> void:
		var c := Vector2(128, 128)
		for y: int in 256:
			for x: int in 256:
				var d: Vector2 = Vector2(x, y) - c
				var r: float = d.length()
				var col := Color(0, 0, 0, 0)
				if r > 72.0 and r < 126.0:
					var n: float = d.angle() / TAU * 16.0
					var off: float = absf(fposmod(n, 1.0) - 0.5) * 2.0
					var spoke: int = int(floor(fposmod(n, 16.0)))
					var outer: float = 126.0 if spoke % 2 == 0 else 108.0
					if r < outer:
						var width: float = 0.2 * (1.0 - (r - 72.0) / (outer - 72.0))
						if 1.0 - off < width:
							col = Ink.INK
				image.set_pixel(x, y, col))


## A smoke ball: grey with a shadow side (lower right), a highlight (upper left) and an ink edge.
func _puff_texture() -> ImageTexture:
	return Ink.texture("comic_puff", Vector2i(128, 128), func(image: Image) -> void:
		var c := Vector2(64, 64)
		for y: int in 128:
			for x: int in 128:
				var p := Vector2(x, y)
				var r: float = p.distance_to(c)
				var col := Color(0, 0, 0, 0)
				if r < 60.0:
					col = Ink.INK
				if r < 54.0:
					col = Color("8f887d")
					if p.distance_to(c + Vector2(-16, -16)) > 50.0:
						col = Color("5f5a53")
					if p.distance_to(c + Vector2(-20, -22)) < 13.0:
						col = Color("cfc6b5")
				image.set_pixel(x, y, col))


## A scrap shard: an uneven dark-rust triangle with an ink edge.
func _shard_texture() -> ImageTexture:
	return Ink.texture("comic_shard", Vector2i(64, 64), func(image: Image) -> void:
		var tri := PackedVector2Array([Vector2(6, 52), Vector2(28, 6), Vector2(58, 42)])
		var inner := PackedVector2Array([Vector2(15, 47), Vector2(28, 18), Vector2(48, 40)])
		for y: int in 64:
			for x: int in 64:
				var p := Vector2(x, y)
				var col := Color(0, 0, 0, 0)
				if Geometry2D.is_point_in_polygon(p, tri):
					col = Ink.INK
				if Geometry2D.is_point_in_polygon(p, inner):
					col = Color("8a5a3a") if p.y > 34.0 else Ink.MUSTARD
				image.set_pixel(x, y, col))


## A spark: a white sliver in an ink edge (tinted by the particle's material).
func _spark_texture() -> ImageTexture:
	return Ink.texture("comic_spark", Vector2i(32, 96), func(image: Image) -> void:
		for y: int in 96:
			for x: int in 32:
				var u: float = absf(float(x) - 15.5) / 16.0
				var v: float = absf(float(y) - 47.5) / 48.0
				var col := Color(0, 0, 0, 0)
				if u + v < 0.98:
					col = Ink.INK
				if u * 1.0 + v < 0.72 and u < 0.42:
					col = Color.WHITE
				image.set_pixel(x, y, col))


## A burn mark left where something blew up, fading over a few seconds.
func scorch(at: Vector3, radius: float = 1.0) -> void:
	var mark := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.7 * radius
	disc.bottom_radius = 0.7 * radius
	disc.height = 0.01
	mark.mesh = disc
	var soot := StandardMaterial3D.new()
	soot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	soot.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	soot.albedo_texture = _soft
	soot.albedo_color = Color(0.02, 0.015, 0.01, 0.7)
	soot.uv1_scale = Vector3(1, 1, 1)
	mark.material_override = Ink.hold(soot)
	mark.position = Vector3(at.x, 0.035, at.z)
	add_child(mark)
	var fade := create_tween()
	fade.tween_interval(2.5)
	fade.tween_property(soot, "albedo_color:a", 0.0, 1.5)
	fade.tween_callback(mark.queue_free)


func _unshaded(colour: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(colour.r * energy, colour.g * energy, colour.b * energy, 1.0)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	material.disable_receive_shadows = true
	return material
