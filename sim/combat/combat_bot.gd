class_name CombatBot
extends RefCounted

## Plays the player's side of a fight with `IntentAI`. Used by tests and the balance
## tool (a fight has to be finishable, the same way twice) and by the `--bot` demo.
##
## Beyond what an enemy considers, the bot reads the telegraphed intents: tiles that will
## be hit are DANGER, and tiles on a line of fire in front of the Crawler are SHIELD -- a
## construct standing there takes the shot instead. That trade is the puzzle the Crawler
## exists to create, so a bot that ignored it would be measuring a different game.

## Worth of shielding the Crawler, per point of damage the shot would do to it. Higher
## than `IntentAI.SCORE_DANGER` per point, because the shielding tile is also a danger tile
## and the Crawler's HP is worth more than a construct's.
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
		out.append([CombatSim.ACT_ATTACK, ref, w, int(plan["dir"]), int(plan["dist"])])
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
	var crawler: GridUnit = state.crawler()
	for ref: Variant in all:
		var threat: Dictionary = all[ref]
		var shooter: GridUnit = state.unit(int(ref))
		var weapon: Dictionary = shooter.weapons[int(threat["w"])]
		var damage: int = int(weapon["damage"]) + shooter.damage_bonus
		for cell: Vector2i in (threat["tiles"] as Array):
			danger[cell] = int(danger.get(cell, 0)) + damage
		# A line aimed at the Crawler can be blocked by standing anywhere in front of it --
		# unless it pierces, in which case the blocker is simply hit as well.
		if crawler == null or String(weapon["shape"]) != "line" or int(weapon["pierce"]) > 0:
			continue
		for hit: Dictionary in (threat["hits"] as Array):
			if int(hit["ref"]) != crawler.ref:
				continue
			for cell: Vector2i in (threat["tiles"] as Array):
				if cell == Vector2i(crawler.x, crawler.y):
					break
				shield[cell] = int(shield.get(cell, 0)) + int(hit["damage"]) * SHIELD_PER_DAMAGE
	return {"danger": danger, "shield": shield}
