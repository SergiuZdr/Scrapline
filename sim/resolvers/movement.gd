class_name MovementResolver
extends RefCounted

## How constructs move across the map.
##
## Nothing here is ordered directly. The player sets intent -- engage, advance, hold,
## fall back -- and the construct's chassis role and weapon reach decide what that
## actually means on the ground. A brawler told to engage sprints into contact; a
## marksman told the same thing walks backwards until it has the room to shoot. That
## is the Rivals at War promise: you give orders, not inputs.
##
## Terrain is the counterweight. Rubble and scrap slow a unit but shelter it, ridges
## extend reach, slag cooks anything that lingers -- so the shortest path to a target
## is frequently the wrong one.

## How close a unit tries to sit inside its maximum reach, in percent. Standing at the
## very edge of range means one step by the enemy breaks the engagement.
const COMFORT_PERCENT: int = 85
## Movement inside this fraction of a step is treated as arrived, to stop units
## jittering back and forth around their preferred distance forever.
const DEADZONE: int = 12


## Where this unit wants to be relative to its target, in sim units.
static func preferred_range(unit: SimUnit, field: Battlefield) -> int:
	var reach: int = unit.weapon_range + field.range_bonus_at(unit.pos_x, unit.pos_z)
	match unit.role:
		SimDefs.ROLE_BRAWLER:
			# Brawlers want contact regardless of what their arms could reach.
			return mini(reach, 130)
		SimDefs.ROLE_MARKSMAN:
			return (reach * COMFORT_PERCENT) / 100
		SimDefs.ROLE_ANCHOR:
			return (reach * 70) / 100
		_:
			return (reach * 75) / 100


## Effective attack reach from where the unit is standing right now.
static func effective_range(unit: SimUnit, field: Battlefield) -> int:
	return unit.weapon_range + field.range_bonus_at(unit.pos_x, unit.pos_z)


static func in_range_of(unit: SimUnit, target: SimUnit, field: Battlefield) -> bool:
	var reach: int = effective_range(unit, field)
	return SimMath.distance_squared(unit.pos_x, unit.pos_z, target.pos_x, target.pos_z) <= reach * reach


## One tick of movement. Returns true if the unit actually moved.
##
## `intent` is the movement flavour derived from the unit's current order:
## ACT_ADVANCE pushes into contact, ACT_FALL_BACK retreats toward the deployment
## anchor, ACT_HOLD roots the unit, and everything else means "take up a good firing
## position".
## Computes this tick's movement **without applying it**.
##
## Separating computation from application is not tidiness -- it is a fairness
## requirement. Applying moves as they are computed means team A (built first) moves
## against team B's stale positions while team B moves against A's updated ones, which
## hands one side a consistent edge in every engagement. Both teams must plan against
## the same snapshot.
static func compute_step(
	unit: SimUnit, target: SimUnit, intent: int,
	field: Battlefield, balance: Balance, stride: int = 1,
	units: Array[SimUnit] = []
) -> Array[int]:
	if unit.seize_ticks > 0 or not unit.alive:
		return [0, 0]
	if intent == SimDefs.ACT_HOLD:
		# Even a unit holding position shuffles out of an ally's way. Without this,
		# constructs that have arrived simply stack on the same tile.
		return _separation(unit, units, balance)
	# An anchor holds the ground it deployed to and will not drift forward looking for
	# a better firing position. It still withdraws, and it still commits when the
	# order is explicitly Advance -- which is what makes Advance meaningful for a
	# short-reach wall that would otherwise never reach anything at all.
	if unit.role == SimDefs.ROLE_ANCHOR \
			and intent != SimDefs.ACT_FALL_BACK \
			and intent != SimDefs.ACT_ADVANCE:
		return [0, 0]

	# `stride` is how many ticks' worth of movement this call covers, so a coarser
	# movement beat travels the same distance per second.
	var speed: int = (unit.move_speed * stride * field.move_percent(unit.pos_x, unit.pos_z)) / 100
	if unit.has_state(SimDefs.STATE_GROUNDED):
		speed = (speed * balance.grounded_speed) / Balance.SCALE
	speed = maxi(1, speed)

	var delta: Array[int]

	if intent == SimDefs.ACT_FALL_BACK:
		# Retreat toward where this unit deployed. Falling back is a real withdrawal
		# across the map now, not a slot swap.
		if SimMath.distance_squared(unit.pos_x, unit.pos_z, unit.slot_home_x, unit.slot_home_z) <= speed * speed:
			return [0, 0]
		delta = SimMath.step_toward(unit.pos_x, unit.pos_z, unit.slot_home_x, unit.slot_home_z, speed)
	elif target == null:
		delta = [0, 0]
	else:
		var distance: int = SimMath.distance(unit.pos_x, unit.pos_z, target.pos_x, target.pos_z)
		var wanted: int = 130 if intent == SimDefs.ACT_ADVANCE else preferred_range(unit, field)
		var gap: int = distance - wanted

		if absi(gap) <= maxi(DEADZONE, speed / 2):
			# In position. Now -- and only now -- look for better ground nearby.
			delta = _reposition_to_cover(unit, field, balance, speed)
		elif gap > 0:
			# While still crossing, steer down this construct's own lane rather than
			# straight at the target. Squads then advance as a line and meet across
			# the whole width of the map, instead of funnelling into one brawl.
			var aim_x: int = target.pos_x
			if gap > balance.lane_lock_distance:
				aim_x = unit.lane_x
			delta = SimMath.step_toward(unit.pos_x, unit.pos_z, aim_x, target.pos_z, mini(speed, gap))
		else:
			# Too close. Only units that actually want space give it up; a brawler
			# never backs off, which is what makes crowding one a commitment.
			if unit.role == SimDefs.ROLE_BRAWLER or intent == SimDefs.ACT_ADVANCE:
				delta = [0, 0]
			else:
				delta = SimMath.step_away(unit.pos_x, unit.pos_z, target.pos_x, target.pos_z, mini(speed, -gap))

	var push: Array[int] = _separation(unit, units, balance)
	delta = [delta[0] + push[0], delta[1] + push[1]]

	# Separation can only nudge; it must never let a unit outrun its own legs.
	var magnitude: int = SimMath.isqrt(delta[0] * delta[0] + delta[1] * delta[1])
	if magnitude > speed and magnitude > 0:
		delta = [(delta[0] * speed) / magnitude, (delta[1] * speed) / magnitude]

	return delta


## Applies a previously computed delta. Returns true if the unit actually moved.
static func apply_step(unit: SimUnit, delta: Array[int], field: Battlefield) -> bool:
	return _apply(unit, delta, field)


## How much this construct wants to be standing on a given tile.
##
## Without this, terrain is scenery: units walk straight at their preferred range and
## whether they end up in cover or in a slag pool is pure accident. Three maps with
## completely different layouts measured as playing identically, which is the clearest
## possible sign that a system is not connected to anything.
##
## Marksmen value elevation because it extends their reach; everyone values cover; and
## nobody wants to stand in slag.
static func tile_value(unit: SimUnit, x: int, z: int, field: Battlefield, balance: Balance) -> int:
	var score: int = field.cover_at(x, z) * balance.terrain_cover_weight / Balance.SCALE
	if unit.role == SimDefs.ROLE_MARKSMAN or unit.role == SimDefs.ROLE_ANCHOR:
		score += field.range_bonus_at(x, z) * balance.terrain_high_ground_weight / Balance.SCALE
	# Heat hazard is a flat, heavy penalty. Standing in slag is never the right answer;
	# crossing it sometimes is, which the movement path still allows.
	score -= field.heat_at(x, z) * balance.terrain_hazard_weight / Balance.SCALE
	return score


## A short sidestep toward better ground, taken only by a unit that is already in
## position. A unit still closing has somewhere more important to be.
static func _reposition_to_cover(
	unit: SimUnit, field: Battlefield, balance: Balance, speed: int
) -> Array[int]:
	if balance.terrain_seek_margin <= 0:
		return [0, 0]
	var here: int = tile_value(unit, unit.pos_x, unit.pos_z, field, balance)
	var best_gain: int = balance.terrain_seek_margin
	var best: Array[int] = [0, 0]

	# Four neighbours at one tile out. Cheap, and enough to walk a unit uphill toward
	# good ground over a few ticks rather than teleporting it there.
	for offset: Array in [[Battlefield.TILE, 0], [-Battlefield.TILE, 0],
			[0, Battlefield.TILE], [0, -Battlefield.TILE]]:
		var nx: int = unit.pos_x + offset[0]
		var nz: int = unit.pos_z + offset[1]
		var gain: int = tile_value(unit, nx, nz, field, balance) - here
		if gain > best_gain:
			best_gain = gain
			var step: Array[int] = SimMath.step_toward(unit.pos_x, unit.pos_z, nx, nz, speed)
			best = step
	return best


## Keeps allies out of each other's tiles. Deterministic: allies are visited in build
## order and the push is pure integer arithmetic.
static func _separation(unit: SimUnit, units: Array[SimUnit], balance: Balance) -> Array[int]:
	var push_x: int = 0
	var push_z: int = 0
	var radius: int = balance.separation_radius
	if radius <= 0 or units.is_empty():
		return [0, 0]

	for other: SimUnit in units:
		if other == unit or not other.alive or other.team != unit.team:
			continue
		var dx: int = unit.pos_x - other.pos_x
		var dz: int = unit.pos_z - other.pos_z
		var distance_squared: int = dx * dx + dz * dz
		if distance_squared >= radius * radius:
			continue
		if distance_squared == 0:
			# Exactly stacked, so there is no direction to push apart along. The nudge
			# is derived from the formation SLOT and is purely lateral: keyed to
			# unit_ref it differed between the teams, and any fixed z component means
			# shoving team A forward into fire while shoving team B back to safety.
			push_x += (SimDefs.slot_of_ref(unit.unit_ref) % 3) - 1
			continue
		var distance: int = maxi(1, SimMath.isqrt(distance_squared))
		var overlap: int = radius - distance
		push_x += (dx * overlap) / distance
		push_z += (dz * overlap) / distance

	return [(push_x * balance.separation_push) / Balance.SCALE,
			(push_z * balance.separation_push) / Balance.SCALE]


static func _apply(unit: SimUnit, delta: Array[int], field: Battlefield) -> bool:
	if delta[0] == 0 and delta[1] == 0:
		return false
	var placed: Array[int] = field.clamp_position(unit.pos_x + delta[0], unit.pos_z + delta[1])
	if placed[0] == unit.pos_x and placed[1] == unit.pos_z:
		return false
	unit.pos_x = placed[0]
	unit.pos_z = placed[1]
	return true


## Movement intent implied by the action a unit is currently carrying out.
static func intent_for_action(action_kind: int) -> int:
	match action_kind:
		SimDefs.ACT_ADVANCE: return SimDefs.ACT_ADVANCE
		SimDefs.ACT_FALL_BACK: return SimDefs.ACT_FALL_BACK
		SimDefs.ACT_BRACE, SimDefs.ACT_HOLD: return SimDefs.ACT_HOLD
		_: return SimDefs.ACT_ATTACK
