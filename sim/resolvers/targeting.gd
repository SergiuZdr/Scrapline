class_name TargetResolver
extends RefCounted

## Who a construct shoots at.
##
## Targeting is now positional: units engage whatever is nearest, not whatever
## occupies some abstract front rank. That single change is what makes movement and
## weapon reach matter -- a marksman holding a ridge is genuinely hard to reach, and a
## brawler that crosses the map to get at it has earned the kill.
##
## Candidates are always scanned in build order -- ascending team then slot -- and
## every comparison ends in a `unit_ref` tiebreak, so two machines pick the same
## target from the same battle state, every time.


static func enemy_team_of(unit: SimUnit) -> int:
	return SimDefs.TEAM_B if unit.team == SimDefs.TEAM_A else SimDefs.TEAM_A


static func living_in_team(units: Array[SimUnit], team: int) -> Array[SimUnit]:
	var out: Array[SimUnit] = []
	for u: SimUnit in units:
		if u.team == team and u.alive:
			out.append(u)
	return out


## Who this construct chooses to fight.
##
## Not simply the nearest enemy: lateral distance is weighted more heavily than depth,
## so a unit prefers whatever is directly in front of it over something equally close
## but off to one flank. That single weighting is most of what stops twelve constructs
## from converging on one target and fighting the entire battle in a single knot --
## instead the two lines meet across their whole width.
static func preferred_target(units: Array[SimUnit], attacker: SimUnit, balance: Balance) -> SimUnit:
	var enemy_team: int = enemy_team_of(attacker)
	var best: SimUnit = null
	var best_score: int = 0
	for u: SimUnit in units:
		if u.team != enemy_team or not u.alive:
			continue
		var dx: int = u.pos_x - attacker.pos_x
		var dz: int = u.pos_z - attacker.pos_z
		var score: int = (dx * dx * balance.lane_weight) / Balance.SCALE + dz * dz
		if best == null or score < best_score or (score == best_score and u.unit_ref < best.unit_ref):
			best = u
			best_score = score
	return best


## The closest living enemy, ignoring lane preference. Used where raw proximity is
## what matters -- charge checks and "how far is the fight" readouts.
static func nearest_enemy(units: Array[SimUnit], attacker: SimUnit) -> SimUnit:
	var enemy_team: int = enemy_team_of(attacker)
	var best: SimUnit = null
	var best_distance: int = 0
	for u: SimUnit in units:
		if u.team != enemy_team or not u.alive:
			continue
		var d: int = SimMath.distance_squared(attacker.pos_x, attacker.pos_z, u.pos_x, u.pos_z)
		if best == null or d < best_distance or (d == best_distance and u.unit_ref < best.unit_ref):
			best = u
			best_distance = d
	return best


## The weakest living enemy anywhere on the map. Only weapons that say they reach
## across the field may use this -- it is the rail lance ignoring the brawl in front
## of it and putting a round through whatever is nearly dead at the back.
static func weakest_enemy(units: Array[SimUnit], attacker: SimUnit) -> SimUnit:
	var enemy_team: int = enemy_team_of(attacker)
	var best: SimUnit = null
	for u: SimUnit in units:
		if u.team != enemy_team or not u.alive:
			continue
		if best == null or u.hp < best.hp or (u.hp == best.hp and u.unit_ref < best.unit_ref):
			best = u
	return best


## The best target already inside this unit's effective reach, or null if it has to
## close first. Uses the same lane weighting as target selection, so a construct
## shoots whatever it advanced to fight rather than swinging at whoever drifted past.
static func target_in_range(
	units: Array[SimUnit], attacker: SimUnit, field: Battlefield, balance: Balance
) -> SimUnit:
	var enemy_team: int = enemy_team_of(attacker)
	var reach: int = MovementResolver.effective_range(attacker, field)
	var reach_squared: int = reach * reach
	var best: SimUnit = null
	var best_score: int = 0
	for u: SimUnit in units:
		if u.team != enemy_team or not u.alive:
			continue
		var dx: int = u.pos_x - attacker.pos_x
		var dz: int = u.pos_z - attacker.pos_z
		if dx * dx + dz * dz > reach_squared:
			continue
		var score: int = (dx * dx * balance.lane_weight) / Balance.SCALE + dz * dz
		if best == null or score < best_score or (score == best_score and u.unit_ref < best.unit_ref):
			best = u
			best_score = score
	return best


## The best in-range enemy that currently carries `state`, or null if none does.
##
## Detonating abilities must aim at the marked target, not merely the nearest one.
## Without this, one construct applies Exposed and the construct meant to cash it in
## fires at whoever happens to be closest -- which measured as cross-unit Synergy
## triggering roughly once every five battles, for the deepest mechanic in the game.
static func target_with_state(
	units: Array[SimUnit], attacker: SimUnit, field: Battlefield, balance: Balance, state: int
) -> SimUnit:
	var enemy_team: int = enemy_team_of(attacker)
	var reach: int = MovementResolver.effective_range(attacker, field)
	var reach_squared: int = reach * reach
	var best: SimUnit = null
	var best_score: int = 0
	for u: SimUnit in units:
		if u.team != enemy_team or not u.alive or not u.has_state(state):
			continue
		var dx: int = u.pos_x - attacker.pos_x
		var dz: int = u.pos_z - attacker.pos_z
		if dx * dx + dz * dz > reach_squared:
			continue
		var score: int = (dx * dx * balance.lane_weight) / Balance.SCALE + dz * dz
		if best == null or score < best_score or (score == best_score and u.unit_ref < best.unit_ref):
			best = u
			best_score = score
	return best


static func any_alive(units: Array[SimUnit], team: int) -> bool:
	for u: SimUnit in units:
		if u.team == team and u.alive:
			return true
	return false


static func count_alive(units: Array[SimUnit], team: int) -> int:
	var n: int = 0
	for u: SimUnit in units:
		if u.team == team and u.alive:
			n += 1
	return n
