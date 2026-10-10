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
func destruction(at: Vector3, colour: Color) -> void:
	var origin: Vector3 = at + Vector3(0, 0.6, 0)
	for i: int in 14:
		var chunk := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(randf_range(0.05, 0.11), randf_range(0.05, 0.11), randf_range(0.05, 0.11))
		chunk.mesh = box
		# Scorched metal, LIT, with only a trace of team colour -- not an unshaded block
		# of the team's paint. Flat team-coloured cubes lying near a construct are
		# indistinguishable from pieces of that construct that have fallen off, and they
		# were being read as exactly that: the "floating parts" on an intact machine were
		# this effect, not the model.
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("2f2a25").lerp(colour, 0.18).darkened(
			randf_range(0.0, 0.25))
		material.roughness = 0.92
		material.metallic = 0.35
		chunk.material_override = Ink.hold(material)
		chunk.position = origin
		add_child(chunk)

		var direction := Vector3(
			randf_range(-1.0, 1.0), randf_range(0.4, 1.2), randf_range(-1.0, 1.0)).normalized()
		var landing: Vector3 = origin + direction * randf_range(0.7, 1.7)
		landing.y = 0.05

		var tween := create_tween()
		tween.tween_property(chunk, "position", origin + direction * 0.9 + Vector3(0, 0.5, 0), 0.22) \
			.set_ease(Tween.EASE_OUT)
		tween.tween_property(chunk, "position", landing, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(chunk, "rotation", Vector3(
			randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6)), 0.72)
		# Cleared quickly. Debris that lies about on the ground accumulates over a battle
		# into a field of small boxes the player has to mentally filter out of the fight.
		tween.tween_interval(0.15)
		tween.tween_property(chunk, "scale", Vector3.ZERO, 0.22)
		tween.tween_callback(chunk.queue_free)

	# A kill burns: a small fireball and smoke on top of the debris.
	fireball(at, 0.55)
	shake(1.0)
	hitstop(0.09)


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


## Streaks of hot metal thrown from a point, falling under gravity: sparks, not confetti.
func sparks(at: Vector3, colour: Color, count: int, force: float = 1.0) -> void:
	var burst := CPUParticles3D.new()
	burst.one_shot = true
	burst.amount = maxi(2, count)
	burst.lifetime = 0.55
	burst.explosiveness = 0.95
	burst.direction = Vector3(0, 1, 0)
	burst.spread = 80.0
	burst.initial_velocity_min = 1.6 * force
	burst.initial_velocity_max = 3.6 * force
	burst.gravity = Vector3(0, -9.0, 0)
	burst.particle_flag_align_y = true
	burst.scale_amount_min = 0.6
	burst.scale_amount_max = 1.2
	var streak := QuadMesh.new()
	streak.size = Vector2(0.025, 0.14)
	var hot: StandardMaterial3D = _unshaded(colour.lerp(Color.WHITE, 0.45), 2.2)
	hot.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	hot.billboard_keep_scale = true
	streak.material = Ink.hold(hot)
	burst.mesh = streak
	burst.position = at
	add_child(burst)
	burst.emitting = true
	get_tree().create_timer(0.9).timeout.connect(burst.queue_free)


## A fuel drum going up (010): a fireball that swells from white-hot to dark red, a flash of
## light on everything near, smoke rolling up after it, and a scorch left on the ground.
func fireball(at: Vector3, radius: float = 1.0) -> void:
	for layer: int in 3:
		var ball := MeshInstance3D.new()
		ball.mesh = _flash_mesh
		var hot: StandardMaterial3D = _unshaded_billboard(Color("fff1c8") if layer == 0 else Color("ff8a3c"), 2.6 - float(layer) * 0.6)
		ball.material_override = Ink.hold(hot)
		ball.position = at + Vector3(randf_range(-0.12, 0.12), 0.35 + float(layer) * 0.15, randf_range(-0.12, 0.12))
		ball.scale = Vector3.ONE * 0.4
		add_child(ball)
		var grow := create_tween().set_parallel(true)
		grow.tween_property(ball, "scale", Vector3.ONE * radius * (4.6 + 1.4 * float(layer)), 0.3 + float(layer) * 0.06) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		grow.tween_property(hot, "albedo_color", Color(0.6, 0.12, 0.04, 0.0), 0.42 + float(layer) * 0.08).set_delay(0.06)
		grow.chain().tween_callback(ball.queue_free)
	# No light (play-test 7): the toon ramp draws the key alone, so an omni lit nothing -- and
	# every material in its range compiled an omni-light variant of its shader on the spot,
	# which was most of the half-second freeze on a kill.
	smoke(at + Vector3(0, 0.5, 0), 16, radius)
	sparks(at + Vector3(0, 0.4, 0), Color("ffb060"), 24, 1.6)
	scorch(at, radius)


## Dark puffs rolling up and spreading, for fires and wrecks.
func smoke(at: Vector3, count: int, size: float = 1.0) -> void:
	var puffs := CPUParticles3D.new()
	puffs.one_shot = true
	puffs.amount = count
	puffs.lifetime = 1.8
	puffs.explosiveness = 0.7
	puffs.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puffs.emission_sphere_radius = 0.3 * size
	puffs.direction = Vector3(0, 1, 0)
	puffs.spread = 35.0
	puffs.initial_velocity_min = 0.6
	puffs.initial_velocity_max = 1.4
	puffs.gravity = Vector3(0, 0.3, 0)
	puffs.damping_min = 0.8
	puffs.damping_max = 1.4
	puffs.scale_amount_min = 0.7 * size
	puffs.scale_amount_max = 1.6 * size
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.8))
	puffs.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.0))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	fade.add_point(0.15, Color(1, 1, 1, 0.75))
	puffs.color_ramp = fade
	var quad := QuadMesh.new()
	var grey := StandardMaterial3D.new()
	grey.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grey.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grey.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	grey.billboard_keep_scale = true
	grey.vertex_color_use_as_albedo = true
	grey.albedo_texture = _soft
	# Lighter than the ground it rises over, or dark smoke on a dark yard is invisible.
	grey.albedo_color = Color(0.24, 0.22, 0.21, 0.6)
	quad.material = Ink.hold(grey)
	puffs.mesh = quad
	puffs.position = at
	add_child(puffs)
	puffs.emitting = true
	get_tree().create_timer(2.4).timeout.connect(puffs.queue_free)


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
