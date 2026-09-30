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


## Plays one whole player turn on `state`, ending it. Returns the actions it applied, in
## order, so a caller can append them to an action log and replay them later.
static func take_turn(state: CombatState) -> Array:
	var taken: Array = []
	for u: GridUnit in state.units:
		if state.outcome != CombatState.ONGOING:
			return taken
		if not u.alive or u.objective or u.team != GridUnit.TEAM_PLAYER:
			continue
		taken.append_array(plan_unit(state, u.ref, true))
	if state.outcome == CombatState.ONGOING:
		var end: Array = [CombatSim.ACT_END, -1, 0, 0]
		CombatSim.apply(state, end)
		taken.append(end)
	return taken


## The actions one unit would take. If `apply` is true they are applied to `state` as
## they are chosen; otherwise the attack is planned from the destination as if the move
## had happened.
static func plan_unit(state: CombatState, ref: int, apply: bool) -> Array:
	var u: GridUnit = state.unit(ref)
	var out: Array = []
	if u == null or not u.alive or u.objective or u.acted:
		return out
	var plan: Dictionary = IntentAI.plan(state, u, context(state))
	var dest: Vector2i = plan["dest"]
	if dest != Vector2i(u.x, u.y):
		var move: Array = [CombatSim.ACT_MOVE, ref, dest.x, dest.y]
		if not apply or CombatSim.apply(state, move):
			out.append(move)
	var w: int = int(plan["w"])
	if w >= 0:
		# A ready boost (Focus, Overdrive) is free damage on an attack about to happen.
		for i: int in u.abilities.size():
			if String(u.abilities[i]["kind"]) == "boost" and u.ability_ready(i) and u.heat + 4 < u.heat_cap:
				var boost: Array = [CombatSim.ACT_ABILITY, ref, i, 0, 0]
				if not apply or CombatSim.apply(state, boost):
					out.append(boost)
				break
		var target: Vector2i = plan["target"]
		out.append([CombatSim.ACT_ATTACK, ref, w, target.x, target.y])
	elif u.heat > 0 and not u.seized:
		# Nothing worth hitting: bank the turn as cooling instead of wasting it.
		out.append([CombatSim.ACT_VENT, ref, 0, 0])
	if apply and out.size() > 0 and int(out[-1][0]) != CombatSim.ACT_MOVE:
		if not CombatSim.apply(state, out[-1]):
			out.pop_back()
	return out


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
	return {"danger": danger, "shield": shield}
