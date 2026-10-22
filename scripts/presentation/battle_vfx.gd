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

func setup(camera_rig: Node3D) -> void:
	_camera_rig = camera_rig


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
	# 078: a jagged drawn star in the shot's colour that erodes (was a soft glowing quad).
	var direction: Vector3 = (toward - from).normalized()
	var tex: Texture2D = Grit.star_texture("muzzle_" + colour.to_html(), colour, colour.lerp(Color("fff6dc"), 0.62), 991)
	var flash: Sprite3D = _sprite(tex, from + Vector3(0, 0.75, 0) + direction * 0.45, 0.0048)
	flash.rotate_z(randf_range(-0.5, 0.5))
	flash.scale = Vector3.ONE * 0.5
	var tween := create_tween()
	tween.tween_property(flash, "scale", Vector3.ONE * 1.1, 0.04).set_ease(Tween.EASE_OUT)
	Grit.erode(self, flash, 0.05, MUZZLE_LIFETIME + 0.04)


## Sparks at the point of impact, plus a flash. Count and speed scale with how hard the
## hit was, so a chip and a killing blow do not look the same.
func impact(at: Vector3, colour: Color, severity: float) -> void:
	var count: int = int(lerpf(6.0, float(SPARK_COUNT) * 2.0, clampf(severity, 0.0, 1.0)))
	var origin: Vector3 = at + Vector3(0, 0.7, 0)
	sparks(origin, colour, count, 1.0 + severity)

	# 023: the hit is DRAWN -- a spiked star, flat amber in an ink edge, that pops and is gone.
	# The glow flash it replaces belonged to the photographed look.
	star(origin, lerpf(0.0035, 0.0075, clampf(severity, 0.0, 1.0)))


## The impact star at `at`, `px` metres per texel (067: deaths use the hit's own star).
func star(at: Vector3, px: float, hold: float = 0.07) -> void:
	var s := Sprite3D.new()
	s.texture = Grit.star_texture("impact", Ink.ACTION, Ink.PAPER, 4242, 12, 46.0, 92.0)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.no_depth_test = true
	s.render_priority = 3
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.flip_h = _star_flip
	_star_flip = not _star_flip
	s.pixel_size = px
	s.position = at
	s.scale = Vector3.ONE * 0.5
	add_child(s)
	var pop := create_tween()
	pop.tween_property(s, "scale", Vector3.ONE * 1.15, 0.06)
	pop.tween_property(s, "scale", Vector3.ONE, 0.05)
	# 078: it erodes into grit instead of shrinking.
	Grit.erode(self, s, 0.11 + hold, 0.1)


var _star_flip: bool = false


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
	for i: int in count:
		var shard: Sprite3D = _sprite(Grit.shard_texture(i % 3), at, randf_range(0.0028, 0.0045))
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


## 067: a death in the hit's language. `what` is what ConstructRig.on_break reports: an arm or
## a part snapping off, the module or the core blowing, the wreck landing, a loose part clanking.
## The fight adds the sound word and the shake; the reel calls this alone.
func on_break(at: Vector3, what: String) -> void:
	match what:
		"clank":
			star(at + Vector3(0, 0.15, 0), 0.0016, 0.02)
		"explode_core":
			star(at, 0.0085, 0.1)
			fireball(at - Vector3(0, 0.3, 0), 0.6)
			sparks(at, Color("ffd27a"), 26, 1.8)
			shards(at, 6, 1.3)
		"explode_module":
			star(at, 0.006, 0.08)
			fireball(at - Vector3(0, 0.35, 0), 0.4)
			sparks(at, Color("ffb070"), 18, 1.4)
		"land":
			var floor_at := Vector3(at.x, 0.06, at.z)
			ground_lines(floor_at, 1.0)
			dust(floor_at, 7, 0.55)
			shards(floor_at + Vector3(0, 0.15, 0), 4, 0.8)
		_:
			star(at, 0.0045)
			sparks(at, Color("ffb070"), 14, 1.2)
			shards(at, 3, 0.8)


## The last beat of a death (067, replacing a glowing ring): the wreck is crushed into the scrap it
## leaves -- a small cartoon blast low on the hex, shards, dust and a star.
func crush(at: Vector3) -> void:
	star(at + Vector3(0, 0.35, 0), 0.0045)
	fireball(at - Vector3(0, 0.2, 0), 0.3)
	dust(Vector3(at.x, 0.06, at.z), 5, 0.45)
	shards(at + Vector3(0, 0.2, 0), 6, 0.9)


## Drawn dust (067): pale paper-brown balls with an ink edge thrown out sideways along the floor,
## low and wide -- landing smoke that does not hide the wreck. They shrink out, never fade.
func dust(at: Vector3, count: int, size: float = 1.0) -> void:
	for i: int in mini(count, 9):
		var tex: Texture2D = Grit.cloud_texture("dust", i % 3, [Color("e3d4b4"), Color("b49c78"), Color("8a7558")], 1.35)
		var ang: float = TAU * (float(i) + randf_range(-0.3, 0.3)) / float(count)
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var puff: Sprite3D = _sprite(tex, at + dir * 0.15 * size, randf_range(0.0032, 0.005) * size)
		puff.flip_h = randf() < 0.5
		puff.render_priority = 1
		puff.scale = Vector3.ZERO
		var life: float = randf_range(0.45, 0.65)
		var t := create_tween()
		t.tween_property(puff, "scale", Vector3.ONE, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(puff, "position", at + dir * randf_range(0.7, 1.1) * size + Vector3(0, 0.18 * size, 0), life) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# 078: gritty dust that erodes, not balls that shrink.
		Grit.erode(self, puff, life * 0.45, life * 0.55 + 0.02)


## Action lines drawn FLAT on the floor (067): the impact of something heavy landing, read from
## above the way a hit's lines are read from the front.
func ground_lines(at: Vector3, radius: float = 1.0) -> void:
	var s: Sprite3D = _sprite(Grit.rays_texture(), at, 0.009 * radius)
	s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	s.rotation = Vector3(-PI / 2.0, randf() * TAU, 0.0)
	s.render_priority = 0
	s.scale = Vector3.ONE * 0.4
	var t := create_tween()
	t.tween_property(s, "scale", Vector3.ONE * 1.3, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.06)
	t.tween_property(s, "scale", Vector3.ONE * 1.5, 0.08)
	Grit.erode(self, s, 0.18, 0.12)


## A ring that expands and fades. Used for Overdrive and Detonation -- the two moments
## that most deserve to be noticed.
func burst(at: Vector3, colour: Color, radius: float = 2.0) -> void:
	# 078: a drawn shock ring flat on the floor and a jagged star at its heart, both eroding (was a
	# glowing torus).
	var ring: Sprite3D = _sprite(Grit.ring_texture(colour), Vector3(at.x, 0.05, at.z), 0.004)
	ring.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	ring.no_depth_test = false
	ring.rotation = Vector3(-PI / 2.0, randf() * TAU, 0.0)
	ring.render_priority = 0
	ring.scale = Vector3.ONE * 0.3
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * radius * 1.1, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Grit.erode(self, ring, 0.14, 0.22)
	var heart: Sprite3D = _sprite(Grit.star_texture("burst_" + colour.to_html(), colour, colour.lerp(Color("fff6dc"), 0.62), 6161, 7),
		at + Vector3(0, 0.35, 0), 0.0028)
	heart.scale = Vector3.ONE * 0.4
	var h := create_tween()
	h.tween_property(heart, "scale", Vector3.ONE, 0.06).set_ease(Tween.EASE_OUT)
	Grit.erode(self, heart, 0.08, 0.12)


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
## `force` (083): the one beat that must freeze even inside another's cooldown -- the last keeper falling.
func hitstop(duration: float, force: bool = false) -> void:
	if _hitstop_cooldown > 0.0 and not force:
		return
	_hitstop_remaining = maxf(_hitstop_remaining, duration)
	_hitstop_cooldown = HITSTOP_COOLDOWN


# --- Helpers -----------------------------------------------------------------

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
	streak.size = Vector2(0.05, 0.24)
	streak.material = _drawn_particle("spark2", Grit.spark_texture(), colour.lerp(Color.WHITE, 0.3))
	burst.mesh = streak
	burst.position = at
	add_child(burst)
	burst.emitting = true
	get_tree().create_timer(0.9).timeout.connect(burst.queue_free)


## Something goes up (066: drawn): action lines burst out, a lumpy cartoon blast -- pale heart,
## yellow, orange with half-tone dots, a thick ink edge -- pops big, holds a beat and shrinks
## away into cartoon smoke balls; shards and sparks fly; a scorch is left on the ground.
func fireball(at: Vector3, radius: float = 1.0) -> void:
	# 078: ragged ink action lines, a torn fireball with a white heart and hatched soot (two layers),
	# eroding into grit -- not round lobes that shrink.
	var middle: Vector3 = at + Vector3(0, 0.5, 0)
	var rays: Sprite3D = _sprite(Grit.rays_texture(), middle, 0.011 * radius)
	rays.rotate_z(randf() * TAU)
	rays.scale = Vector3.ONE * 0.6
	var r := create_tween()
	r.tween_property(rays, "scale", Vector3.ONE * 1.35, 0.1).set_ease(Tween.EASE_OUT)
	Grit.erode(self, rays, 0.08, 0.1)
	for layer: int in 2:
		var boom: Sprite3D = _sprite(Grit.blast_texture(randi() % 3), middle + Vector3(randf_range(-0.15, 0.15), 0.12 * layer, 0),
			(0.0092 if layer == 0 else 0.006) * radius)
		boom.flip_h = randf() < 0.5
		boom.render_priority = 3 + layer
		boom.scale = Vector3.ONE * 0.2
		var t := create_tween()
		t.tween_interval(0.05 * layer)
		t.tween_property(boom, "scale", Vector3.ONE * 1.18, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(boom, "scale", Vector3.ONE * 1.3, 0.3)
		Grit.erode(self, boom, 0.05 * layer + 0.16, 0.22)
	get_tree().create_timer(0.24).timeout.connect(smoke.bind(middle + Vector3(0, 0.2, 0), 7, radius))
	shards(middle, 5, radius * 1.4)
	sparks(middle, Ink.ACTION, 16, 1.5)
	scorch(at, radius)


## Smoke (076, the user: round cartoon balls were "too cartoony"): jagged billows in sooty greys with
## hatched shade and an ink edge (`Grit.smoke_texture`). Each puffs out, drifts up and swells -- and
## ERODES into grit instead of shrinking.
func smoke(at: Vector3, count: int, size: float = 1.0) -> void:
	for i: int in mini(count, 9):
		var start: Vector3 = at + Vector3(randf_range(-0.3, 0.3), randf_range(-0.1, 0.2), randf_range(-0.3, 0.3)) * size
		var puff: Sprite3D = _sprite(Grit.smoke_texture(randi() % 4), start, randf_range(0.0045, 0.0075) * size)
		puff.flip_h = randf() < 0.5
		puff.render_priority = 1
		puff.scale = Vector3.ONE * 0.4
		var rise: float = randf_range(0.8, 1.2)
		var t := create_tween()
		t.tween_interval(randf_range(0.0, 0.1))
		t.tween_property(puff, "scale", Vector3.ONE * 0.9, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(puff, "position", start + Vector3(randf_range(-0.2, 0.2), randf_range(0.5, 0.9) * size, 0.0), rise) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(puff, "scale", Vector3.ONE * 1.25, rise)
		Grit.erode(self, puff, rise * 0.35 + 0.2, rise * 0.65)


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


## A burn mark left where something blew up, fading over a few seconds.
func scorch(at: Vector3, radius: float = 1.0) -> void:
	# 078: a drawn burn on the floor -- ragged, hatched rim, cracks, embers -- that erodes (was soft soot).
	var mark: Sprite3D = _sprite(Grit.scorch_texture(), Vector3(at.x, 0.035, at.z), 0.0078 * radius)
	mark.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	mark.no_depth_test = false
	mark.rotation = Vector3(-PI / 2.0, randf() * TAU, 0.0)
	mark.render_priority = 0
	Grit.erode(self, mark, 2.5, 1.2)


