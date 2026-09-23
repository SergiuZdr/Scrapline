class_name CombatBot
extends RefCounted

## Plays the player's side of a fight with `IntentAI`. Used by tests (a fight has to be
## finishable, and finishable the same way twice) and by the `--bot` demo mode.


## Plays one whole player turn on `state`, ending it. Returns the actions it applied, in
## order, so a caller can append them to an action log and replay them later.
static func take_turn(state: CombatState) -> Array:
	var taken: Array = []
	for u: GridUnit in state.units:
		if state.outcome != CombatState.ONGOING:
			return taken
		if not u.alive or u.team != GridUnit.TEAM_PLAYER:
			continue
		taken.append_array(plan_unit(state, u.ref, true))
	if state.outcome == CombatState.ONGOING:
		var end: Array = [CombatSim.ACT_END, -1, 0, 0]
		CombatSim.apply(state, end)
		taken.append(end)
	return taken


## The move and attack one unit would make. If `apply` is true they are applied to
## `state` as they are chosen.
static func plan_unit(state: CombatState, ref: int, apply: bool) -> Array:
	var u: GridUnit = state.unit(ref)
	var out: Array = []
	if u == null or not u.alive or u.acted:
		return out
	var plan: Dictionary = IntentAI.plan(state, u, danger_tiles(state))
	var dest: Vector2i = plan["dest"]
	if dest != Vector2i(u.x, u.y) and not u.moved:
		var move: Array = [CombatSim.ACT_MOVE, ref, dest.x, dest.y]
		if not apply or CombatSim.apply(state, move):
			out.append(move)
	var dir: int = int(plan["dir"])
	if dir >= 0:
		var attack: Array = [CombatSim.ACT_ATTACK, ref, dir, 0]
		if not apply or CombatSim.apply(state, attack):
			out.append(attack)
	return out


static func danger_tiles(state: CombatState) -> Dictionary:
	var out: Dictionary = {}
	var all: Dictionary = CombatSim.threats(state)
	for ref: Variant in all:
		for cell: Vector2i in ((all[ref] as Dictionary)["tiles"] as Array):
			out[cell] = true
	return out
