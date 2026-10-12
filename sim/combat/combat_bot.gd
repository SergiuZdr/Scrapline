class_name CombatBot
extends RefCounted

## Plays the player's side of a fight with `IntentAI`. Used by tests and the balance
## tool (a fight has to be finishable, the same way twice) and by the `--bot` demo.
##
## Beyond what an enemy considers, the bot reads the telegraphed intents: hexes that will
## be hit are DANGER, and hexes on a shot's line in front of a salvage cache are SHIELD --
## a machine standing there takes the shot instead. That trade is the puzzle a defend
## fight exists to create, so a bot that ignored it would be measuring a different game.

## Worth of shielding a cache, per point of damage the shot would do to it. Higher than
## `IntentAI.SCORE_DANGER` per point, because the shielding hex is also a danger hex.
const SHIELD_PER_DAMAGE: int = 20


## 073: the bot plays every ability and the Shield Caster. Off (`--set bot.abilities=false` in the
## bot tools) it plays exactly as before 073 -- so the two can be compared on the same fights.
static var use_abilities: bool = true

## Untargeted abilities are used on the machine's own hex.
const TAKES_ACTION: Array[String] = ["charge", "grapple", "barricade", "shield"]


## Plays one whole player turn on `state`, ending it. Returns the actions it applied, in
## order, so a caller can append them to an action log and replay them later.
static func take_turn(state: CombatState) -> Array:
	var taken: Array = []
	for ref: int in turn_order(state):
		if state.outcome != CombatState.ONGOING:
			return taken
		taken.append_array(plan_unit(state, ref, true))
	if state.outcome == CombatState.ONGOING:
		var end: Array = [CombatSim.ACT_END, -1, 0, 0]
		CombatSim.apply(state, end)
		taken.append(end)
	return taken


## The crew in the order the bot moves them: a machine that protects others (a shield arm, Shield,
## Barricade) goes last, once the others stand where they will take the volley.
static func turn_order(state: CombatState) -> Array[int]:
	var first: Array[int] = []
	var last: Array[int] = []
	for u: GridUnit in state.units:
		if not u.alive or u.objective or u.team != GridUnit.TEAM_PLAYER:
			continue
		if use_abilities and _protects(u):
			last.append(u.ref)
		else:
			first.append(u.ref)
	first.append_array(last)
	return first


static func _protects(u: GridUnit) -> bool:
	for weapon: Dictionary in u.weapons:
		if String(weapon["shape"]) == "shield":
			return true
	for ability: Dictionary in u.abilities:
		if ["shield", "barricade"].has(String(ability["kind"])):
			return true
	return false


## The actions one unit would take. If `apply` is true they are applied to `state` as
## they are chosen; otherwise they are chosen on a copy and `state` is left as it was.
static func plan_unit(state: CombatState, ref: int, apply: bool) -> Array:
	if not apply:
		return plan_unit(state.clone(), ref, true)
	var u: GridUnit = state.unit(ref)
	var out: Array = []
	if u == null or not u.alive or u.objective or u.acted:
		return out
	if use_abilities:
		_flush(state, u, out, false)
	var ctx: Dictionary = context(state)
	var plan: Dictionary = IntentAI.plan(state, u, ctx)
	var dest: Vector2i = plan["dest"]
	if dest != Vector2i(u.x, u.y):
		_do(state, out, [CombatSim.ACT_MOVE, ref, dest.x, dest.y])
	var w: int = int(plan["w"])
	var pick: Array = _best_ability(state, u, context(state)) if use_abilities else []
	if not pick.is_empty() and int(pick[2]) > (int(plan.get("attack", 0)) if w >= 0 else 0):
		if String(u.abilities[int(pick[0])]["kind"]) == "charge":
			_boost(state, u, out)
		var cell: Vector2i = pick[1]
		_do(state, out, [CombatSim.ACT_ABILITY, ref, int(pick[0]), cell.x, cell.y])
	elif w >= 0:
		_boost(state, u, out)
		var target: Vector2i = plan["target"]
		_do(state, out, [CombatSim.ACT_ATTACK, ref, w, target.x, target.y])
	elif u.heat > 0 and not u.seized:
		# Nothing worth hitting: bank the turn as cooling instead of wasting it.
		_do(state, out, [CombatSim.ACT_VENT, ref, 0, 0])
	if use_abilities and u.alive and state.outcome == CombatState.ONGOING:
		_flush(state, u, out, true)
		_dash(state, u, out)
		_magnet(state, u, out)
	return out


## Applies `action` and keeps it if the rules took it.
static func _do(state: CombatState, out: Array, action: Array) -> void:
	if CombatSim.apply(state, action):
		out.append(action)


## A ready boost (Focus, Overdrive) is free damage on an attack about to happen.
static func _boost(state: CombatState, u: GridUnit, out: Array) -> void:
	for i: int in u.abilities.size():
		if String(u.abilities[i]["kind"]) == "boost" and u.ability_ready(i) and u.heat + 4 < u.heat_cap:
			_do(state, out, [CombatSim.ACT_ABILITY, u.ref, i, 0, 0])
			return


## Flush (free): before planning, when the next attack would reach the heat cap; after the action,
## when it did (an overheated machine loses its next attack).
static func _flush(state: CombatState, u: GridUnit, out: Array, after: bool) -> void:
	for i: int in u.abilities.size():
		if String(u.abilities[i]["kind"]) != "flush" or not CombatAbilities.usable(state, u, i):
			continue
		var hot: bool = u.overheated
		if not after:
			for w: int in u.weapons.size():
				if u.can_fire(w) and u.heat + CombatSim.attack_heat(u, u.weapons[w]) >= u.heat_cap:
					hot = true
		if hot:
			_do(state, out, [CombatSim.ACT_ABILITY, u.ref, i, 0, 0])
		return


## The best ability that takes the machine's action, played for real on a copy for every target:
## `[index, target, value]`, or empty. Charge and Grapple are scored like an attack (what they do
## to both sides, and where Charge leaves the machine); Shield and Barricade by what they save the
## crew from the enemy's volley.
static func _best_ability(state: CombatState, u: GridUnit, ctx: Dictionary) -> Array:
	var best: Array = []
	var best_value: int = IntentAI.SCORE_HIT / 2 - 1
	var here := Vector2i(u.x, u.y)
	for i: int in u.abilities.size():
		var ability: Dictionary = u.abilities[i]
		var kind: String = String(ability["kind"])
		if not TAKES_ACTION.has(kind) or not CombatAbilities.usable(state, u, i):
			continue
		var cells: Array[Vector2i] = [here]
		if CombatAbilities.needs_target(ability):
			cells = CombatAbilities.targets(state, u, i)
		for cell: Vector2i in cells:
			var after: CombatState = state.clone()
			if not CombatSim.apply(after, [CombatSim.ACT_ABILITY, u.ref, i, cell.x, cell.y]):
				continue
			var value: int = int(IntentAI.effects_value(state, after, u, ctx)[0])
			if kind == "charge":
				var moved: GridUnit = after.unit(u.ref)
				value += _stand_value(state, u, Vector2i(moved.x, moved.y), 0, ctx) - _stand_value(state, u, here, 0, ctx)
			elif kind == "shield" or kind == "barricade":
				value += protection(state, after)
			if value > best_value:
				best_value = value
				best = [i, cell, value]
	return best


## Dash (free): after the action, two more hexes to wherever is worth standing on more (out of a
## shot, onto a pile or a terminal).
static func _dash(state: CombatState, u: GridUnit, out: Array) -> void:
	for i: int in u.abilities.size():
		if String(u.abilities[i]["kind"]) != "dash" or not CombatAbilities.usable(state, u, i):
			continue
		var ctx: Dictionary = context(state)
		var here := Vector2i(u.x, u.y)
		var paths: Dictionary = CombatSim.paths_from(state, u, int(u.abilities[i].get("range", 2)))
		var cells: Array = paths.keys()
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
		var best: Vector2i = here
		var best_value: int = _stand_value(state, u, here, 0, ctx)
		for cell: Vector2i in cells:
			if cell == here:
				continue
			var value: int = _stand_value(state, u, cell, (paths[cell] as Array).size(), ctx)
			if value > best_value:
				best_value = value
				best = cell
		if best != here:
			_do(state, out, [CombatSim.ACT_ABILITY, u.ref, i, best.x, best.y])
		return


## Magnet (free): pull in the nearest scrap pile in reach -- its scrap and its HP, for nothing.
static func _magnet(state: CombatState, u: GridUnit, out: Array) -> void:
	for i: int in u.abilities.size():
		if String(u.abilities[i]["kind"]) != "magnet":
			continue
		var cells: Array[Vector2i] = CombatAbilities.targets(state, u, i)
		if cells.is_empty():
			return
		var here := Vector2i(u.x, u.y)
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var da: int = Hex.distance(here, a)
			var db: int = Hex.distance(here, b)
			return da < db or (da == db and (a.y < b.y or (a.y == b.y and a.x < b.x))))
		_do(state, out, [CombatSim.ACT_ABILITY, u.ref, i, cells[0].x, cells[0].y])
		return


## How much `u` wants to stand on `cell`, reached in `steps`: the danger map, hazards, piles and the
## objective -- what `IntentAI` weighs a move by.
static func _stand_value(state: CombatState, u: GridUnit, cell: Vector2i, steps: int, ctx: Dictionary) -> int:
	return IntentAI._tile_value(state, cell, steps, ctx.get("danger", {}), ctx.get("shield", {})) \
		+ IntentAI._objective_value(state, u, cell)


## 073: what the change from `before` to `after` saves the crew from the enemy's volley and the next
## round's hazards (`CombatSim.incoming` on both), scored like damage dealt: a point kept is worth a
## point hit, a machine or cache kept alive like a kill.
static func protection(before: CombatState, after: CombatState) -> int:
	var saved: int = _harm(before) - _harm(after)
	return saved + (IntentAI.SCORE_HIT if saved > 0 else 0)


static func _harm(state: CombatState) -> int:
	var harm: int = 0
	for hurt: Dictionary in (CombatSim.incoming(state)["units"] as Array):
		var t: GridUnit = state.unit(int(hurt["ref"]))
		if t.team != GridUnit.TEAM_PLAYER:
			continue
		harm += int(hurt["hp_lost"]) * 10
		if bool(hurt["killed"]):
			harm += -IntentAI.SCORE_OWN_OBJECTIVE if t.objective else IntentAI.SCORE_KILL
	return harm


## Danger and shield maps from the enemy intents as they stand.
static func context(state: CombatState) -> Dictionary:
	var danger: Dictionary = {}
	var shield: Dictionary = {}
	var all: Dictionary = CombatSim.threats(state)
	for ref: Variant in all:
		var threat: Dictionary = all[ref]
		if not bool(threat["legal"]):
			continue
		var shooter: GridUnit = state.unit(int(ref))
		var weapon: Dictionary = shooter.weapons[int(threat["w"])]
		var damage: int = int(weapon["damage"]) + shooter.damage_bonus
		for cell: Vector2i in (threat["tiles"] as Array):
			danger[cell] = int(danger.get(cell, 0)) + damage
		# A shot aimed at a cache can be blocked by standing anywhere on its line in front
		# of it -- unless it pierces, in which case the blocker is simply hit as well.
		if String(weapon["shape"]) != "shot" or int(weapon["pierce"]) > 0:
			continue
		for hit: Dictionary in (threat["hits"] as Array):
			var victim: GridUnit = state.unit(int(hit["ref"]))
			if victim == null or not victim.objective:
				continue
			for cell: Vector2i in (threat["tiles"] as Array):
				if cell == Vector2i(victim.x, victim.y):
					break
				shield[cell] = int(shield.get(cell, 0)) + int(hit["damage"]) * SHIELD_PER_DAMAGE
	# The Core's marked ring (025) pulses before the next turn: as good as a shot there.
	var keeper: GridUnit = state.unit(state.pulse_by)
	if keeper != null and keeper.alive:
		var pulse: int = int((state.setup.kinds.get(keeper.kind, {}) as Dictionary).get("pulse_damage", 4))
		for cell: Vector2i in state.pulse_marks:
			danger[cell] = int(danger.get(cell, 0)) + pulse
	var ctx: Dictionary = {"danger": danger, "shield": shield}
	if use_abilities:
		ctx["guard"] = true
	return ctx
