class_name Doctrine
extends RefCounted

## A player-authored rules list that turns battle state into orders.
##
## Rules are evaluated top to bottom and the first match wins, exactly like Final
## Fantasy XII's gambits. Ordering is the whole skill: "attack" first means nothing
## below it ever fires.
##
## One engine, three jobs:
##   - it runs the opponent's squad in async PvP, so a defence is only as good as
##     the doctrine its owner wrote;
##   - it drives auto-battle for grinding;
##   - it fills in orders for any unit the player left on Auto during a manual fight.
##
## It lives inside `sim/` and obeys every rule that implies: pure integers, fixed
## iteration order, no engine RNG.

var display_name: String = "Default"
var rules: Array[Dictionary] = []


static func from_array(rule_list: Array, name: String = "Custom") -> Doctrine:
	var d := Doctrine.new()
	d.display_name = name
	for r: Variant in rule_list:
		d.rules.append(r as Dictionary)
	return d


## The fallback every new player starts with: vent before cooking, pull a dying unit
## out, close the gap when nothing is in reach, punish anything already Exposed.
## Rules, or the default when there are none.
##
## **Every side of a verified battle must resolve an empty rule list the same way.** The
## client treated empty as "the default", the verification worker treated it as "no
## doctrine at all", and those are different opponents: honest battles against a player
## who had never opened the doctrine editor replayed differently on the server and were
## rejected as forged event streams.
static func from_array_or_default(rule_list: Array, name: String = "Custom") -> Doctrine:
	if rule_list.is_empty():
		return default_doctrine()
	return from_array(rule_list, name)


static func default_doctrine() -> Doctrine:
	return from_array([
		{"if": {"subject": "self", "field": "heat_pct", "op": ">=", "value": 75}, "then": ["vent", "attack"]},
		{"if": {"subject": "self", "field": "hp_pct", "op": "<=", "value": 25}, "then": ["fall_back", "brace"]},
		# Nothing in reach: shut up and walk. Without this, short-ranged constructs
		# stand at the far end of the map swinging at air.
		{"if": {"subject": "self", "field": "in_range", "op": "==", "value": 0}, "then": ["advance", "attack"]},
		# A state is up on something: try BOTH abilities, because which slot holds the
		# detonator depends on the arms bolted to this frame. Only ever firing ability:1
		# meant cross-unit Synergy triggered roughly once every five battles -- the
		# deepest mechanic in the design, almost never firing.
		{"if": {"subject": "enemy", "field": "state", "op": "has", "value": "exposed"},
		 "then": ["ability:0", "ability:1", "attack"]},
		{"if": {"subject": "enemy", "field": "state", "op": "has", "value": "fractured"},
		 "then": ["ability:1", "ability:0", "attack"]},
		{"if": {"subject": "self", "field": "hp_pct", "op": ">=", "value": 70}, "then": ["ability:0", "attack", "attack"]},
		{"then": ["attack"]},
	], "Default")


## Distance from the deciding unit to its nearest enemy, and whether anything is in
## reach. Computed once per decision and read by the positional rule fields.
var _distance_to_enemy: int = 0
var _has_target_in_range: bool = false


## Chooses this unit's chain for the coming cycle. `field` may be null for callers
## that have no battlefield, in which case the positional fields read as "in reach".
func decide(unit: SimUnit, units: Array[SimUnit], field: Battlefield = null) -> Array[int]:
	var nearest: SimUnit = TargetResolver.nearest_enemy(units, unit)
	if nearest == null:
		_distance_to_enemy = 0
		_has_target_in_range = true
	else:
		_distance_to_enemy = SimMath.distance(unit.pos_x, unit.pos_z, nearest.pos_x, nearest.pos_z)
		_has_target_in_range = field == null or MovementResolver.in_range_of(unit, nearest, field)

	for rule: Dictionary in rules:
		if not rule.has("if") or _evaluate(rule["if"] as Dictionary, unit, units):
			return parse_chain(rule.get("then", ["attack"]) as Array)
	return parse_chain(["attack"])


func _evaluate(cond: Dictionary, unit: SimUnit, units: Array[SimUnit]) -> bool:
	var subject: String = String(cond.get("subject", "self"))
	match subject:
		"self":
			return _test_unit(cond, unit)
		"enemy":
			var enemy_team: int = SimDefs.TEAM_B if unit.team == SimDefs.TEAM_A else SimDefs.TEAM_A
			return _any_matching(cond, units, enemy_team)
		"ally":
			return _any_matching(cond, units, unit.team)
	return false


## "any enemy is Exposed", "any ally is below 30%". Units are walked in the order
## they were built -- ascending team then slot -- so this never varies.
func _any_matching(cond: Dictionary, units: Array[SimUnit], team: int) -> bool:
	for u: SimUnit in units:
		if u.team == team and u.alive and _test_unit(cond, u):
			return true
	return false


func _test_unit(cond: Dictionary, u: SimUnit) -> bool:
	var field: String = String(cond.get("field", "hp_pct"))
	var op: String = String(cond.get("op", ">="))

	if field == "state":
		var sid: int = SimDefs.state_id(String(cond.get("value", "")))
		if sid < 0:
			return false
		var present: bool = u.has_state(sid)
		return present if op == "has" else not present

	var lhs: int = 0
	match field:
		"hp_pct":
			lhs = (u.hp * Balance.SCALE) / maxi(1, u.hp_max)
		"heat_pct":
			lhs = (u.heat * Balance.SCALE) / maxi(1, u.heat_max)
		"row":
			lhs = u.row()
		"slot":
			lhs = u.slot
		"hp":
			lhs = u.hp
		"distance":
			lhs = _distance_to_enemy
		"in_range":
			lhs = 1 if _has_target_in_range else 0
		"role":
			lhs = u.role
		_:
			return false

	var rhs: int = int(cond.get("value", 0))
	match op:
		"<": return lhs < rhs
		"<=": return lhs <= rhs
		">": return lhs > rhs
		">=": return lhs >= rhs
		"==": return lhs == rhs
		"!=": return lhs != rhs
	return false


## "vent", "attack", "ability:1" -> packed action codes. An unrecognised token
## becomes a plain attack rather than an error: a doctrine authored against a part
## the player has since sold must degrade quietly, never desync a battle.
static func parse_chain(tokens: Array) -> Array[int]:
	var chain: Array[int] = []
	for t: Variant in tokens:
		chain.append(parse_action(String(t)))
		if chain.size() >= SimDefs.CHAIN_MAX:
			break
	return chain


static func parse_action(token: String) -> int:
	var arg: int = 0
	var name: String = token
	var colon: int = token.find(":")
	if colon >= 0:
		name = token.substr(0, colon)
		arg = token.substr(colon + 1).to_int()

	match name:
		"attack": return SimDefs.action(SimDefs.ACT_ATTACK)
		"ability": return SimDefs.action(SimDefs.ACT_ABILITY, arg)
		"brace": return SimDefs.action(SimDefs.ACT_BRACE)
		"vent": return SimDefs.action(SimDefs.ACT_VENT)
		"fall_back": return SimDefs.action(SimDefs.ACT_FALL_BACK)
		"advance": return SimDefs.action(SimDefs.ACT_ADVANCE)
		"hold": return SimDefs.action(SimDefs.ACT_HOLD)
	return SimDefs.action(SimDefs.ACT_ATTACK)


func to_array() -> Array:
	return rules.duplicate(true)
