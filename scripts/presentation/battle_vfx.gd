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

## Clears every transient effect immediately.
##
## Called when the Order Phase opens. Playback stops there, so anything still alive --
## a muzzle flash mid-fade, a spark, a chunk of debris -- freezes on screen as a small
## coloured shape sitting beside a construct, for as long as the player takes to think.
## Frozen, an effect stops reading as an effect and starts reading as a piece of the
## machine that has come off, which is exactly how it was being read.
func clear_transients() -> void:
	for child: Node in get_children():
		if child is MeshInstance3D:
			child.queue_free()


## A muzzle flash at the attacker, oriented toward the target. Sells that a shot was
## fired even when the projectile itself is instantaneous.
func muzzle_flash(from: Vector3, toward: Vector3, colour: Color) -> void:
	var flash := MeshInstance3D.new()
	flash.mesh = _flash_mesh
	# Blown toward white. At full damage-type chroma the flash is a solid block of the
	# same colour the construct is painted, which is why a frozen one was mistaken for
	# part of the construct; fire reads as fire because its core is hotter than its edge.
	flash.material_override = _unshaded_billboard(colour.lerp(Color.WHITE, 0.55), 2.6)
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
	var count: int = int(lerpf(4.0, float(SPARK_COUNT), clampf(severity, 0.0, 1.0)))
	var origin: Vector3 = at + Vector3(0, 0.7, 0)

	for i: int in count:
		var spark := MeshInstance3D.new()
		spark.mesh = _spark_mesh
		spark.material_override = _unshaded(colour, 1.6)
		spark.position = origin
		add_child(spark)

		var direction := Vector3(
			randf_range(-1.0, 1.0), randf_range(0.25, 1.0), randf_range(-1.0, 1.0)).normalized()
		var distance: float = randf_range(0.35, 0.85) * (0.6 + severity)
		var tween := create_tween()
		tween.tween_property(spark, "position", origin + direction * distance, IMPACT_LIFETIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(spark, "scale", Vector3.ZERO, IMPACT_LIFETIME)
		tween.tween_callback(spark.queue_free)

	if severity >= 0.5:
		var flash := MeshInstance3D.new()
		flash.mesh = _flash_mesh
		flash.material_override = _unshaded_billboard(colour, 2.4)
		flash.position = origin
		add_child(flash)
		var flash_tween := create_tween()
		flash_tween.tween_property(flash, "scale", Vector3(2.4, 2.4, 2.4), 0.16)
		flash_tween.parallel().tween_property(flash.material_override, "albedo_color:a", 0.0, 0.16)
		flash_tween.tween_callback(flash.queue_free)


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
		chunk.material_override = material
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
	ring.material_override = _unshaded(colour, 2.6)
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
	return material


func _unshaded(colour: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(colour.r * energy, colour.g * energy, colour.b * energy, 1.0)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	material.disable_receive_shadows = true
	return material
