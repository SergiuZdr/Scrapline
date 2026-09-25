class_name CombatAbilities
extends RefCounted

## The active abilities parts give a player's machine (see `data/combat/abilities.json`).
##
## An ability is used with `[ACT_ABILITY, ref, index, x, y]` through `CombatSim.apply`.
## Some take a target hex; the rest ignore x and y. `free` abilities do not use the
## machine's action. Every ability waits `cooldown` rounds before it can be used again.
##
## Like attacks, abilities are previewed by running them for real on a copy
## (`CombatSim.dry_run`), so a grapple over a pit or a charge into a barrel shows its
## true outcome before the player commits.


## Does ability `i` of `u` need a target hex?
static func needs_target(ability: Dictionary) -> bool:
	return ["charge", "grapple", "barricade", "dash", "magnet"].has(String(ability["kind"]))


## Every hex ability `i` could be used on now (empty for untargeted abilities).
static func targets(state: CombatState, u: GridUnit, i: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not usable(state, u, i):
		return out
	var ability: Dictionary = u.abilities[i]
	var here := Vector2i(u.x, u.y)
	var reach: int = int(ability.get("range", 1))
	match String(ability["kind"]):
		"dash":
			for cell: Variant in CombatSim.paths_from(state, u, reach):
				out.append(cell)
		"charge":
			for dir: int in 6:
				var cell: Vector2i = here
				for step: int in reach:
					cell = Hex.neighbor(cell, dir)
					if not state.inside(cell) or state.is_pit(cell):
						break
					out.append(cell)
					if state.solid(cell) or state.unit_at(cell.x, cell.y) != null:
						break
		"grapple":
			# Free aim, like a shot: any unit in reach the hook can see (nothing solid or
			# standing between), 2+ hexes away. Anchored frames cannot be moved at all.
			for cell: Vector2i in Hex.within(here, reach):
				if not state.inside(cell) or Hex.distance(here, cell) < 2:
					continue
				var other: GridUnit = state.unit_at(cell.x, cell.y)
				if other == null or other.unshovable or not _clear_line(state, here, cell):
					continue
				out.append(cell)
		"barricade":
			for n: Vector2i in Hex.neighbors(here):
				if state.inside(n) and not state.solid(n) and not state.is_pit(n) \
						and state.unit_at(n.x, n.y) == null and not state.piles.has(n):
					out.append(n)
		"magnet":
			for cell: Variant in state.pile_cells():
				if Hex.distance(here, cell) <= reach and cell != here:
					out.append(cell)
	return out


## Can `u` use ability `i` at all right now (ignoring the target)?
static func usable(state: CombatState, u: GridUnit, i: int) -> bool:
	if state.outcome != CombatState.ONGOING or u == null or not u.alive or u.objective:
		return false
	if u.team != GridUnit.TEAM_PLAYER or not u.ability_ready(i):
		return false
	var ability: Dictionary = u.abilities[i]
	if not bool(ability["free"]) and u.acted:
		return false
	match String(ability["kind"]):
		"charge":
			# Usable after a move (play-test 3: charging INSTEAD of moving made it weak).
			return not u.seized
		"boost":
			# A boost only matters if the machine still has an attack to spend it on.
			return not u.acted and not u.seized
		"flush":
			return u.heat > 0 or u.overheated
	return true


static func use(state: CombatState, ref: int, i: int, target: Vector2i) -> bool:
	var u: GridUnit = state.unit(ref)
	if u == null or i < 0 or i >= u.abilities.size() or not usable(state, u, i):
		return false
	var ability: Dictionary = u.abilities[i]
	if needs_target(ability) and not targets(state, u, i).has(target):
		return false
	var here := Vector2i(u.x, u.y)
	state.emit(GridEv.ABILITY, u.ref, -1, target.x if needs_target(ability) else here.x,
		target.y if needs_target(ability) else here.y, i)
	match String(ability["kind"]):
		"dash":
			var path: Array = CombatSim.paths_from(state, u, int(ability.get("range", 2)))[target]
			for cell: Vector2i in path:
				state.emit(GridEv.STEP, u.ref, -1, cell.x, cell.y)
			u.x = target.x
			u.y = target.y
			state.emit(GridEv.MOVED, u.ref, -1, u.x, u.y, here.x, here.y)
			CombatSim.collect_path(state, u, path)
		"charge":
			_charge(state, u, target, ability)
		"grapple":
			_grapple(state, u, target)
		"barricade":
			state.props[target] = {"kind": "crate", "hp": int(ability.get("hp", state.setup.crate_hp))}
			state.emit(GridEv.PROP_PLACED, u.ref, -1, target.x, target.y, 0)
		"boost":
			u.boost_damage += int(ability.get("damage", 2))
			u.boost_heat += int(ability.get("heat", 0))
		"flush":
			u.heat = 0
			u.overheated = false
			state.emit(GridEv.VENTED, u.ref, -1, u.x, u.y, 0)
		"shield":
			var armor: int = int(ability.get("armor", 2))
			var covered: Array[GridUnit] = [u]
			for n: Vector2i in Hex.neighbors(here):
				var ally: GridUnit = state.unit_at(n.x, n.y) if state.inside(n) else null
				if ally != null and ally.team == u.team:
					covered.append(ally)
			for ally: GridUnit in covered:
				ally.shield = maxi(ally.shield, armor)
				state.emit(GridEv.SHIELDED, u.ref, ally.ref, ally.x, ally.y, armor)
		"magnet":
			CombatSim.collect_at(state, u, target)
	ability["wait"] = int(ability["cooldown"])
	if not bool(ability["free"]):
		u.acted = true
		if not u.move_after_attack:
			u.moved = true
	return true


## Straight at `target` until something is in the way: a unit takes the hit and a shove,
## a prop takes the hit (a barrel goes off), a pit or the edge simply stops the run.
static func _charge(state: CombatState, u: GridUnit, target: Vector2i, ability: Dictionary) -> void:
	var here := Vector2i(u.x, u.y)
	var dir: int = Hex.direction(here, target)
	# Focus / Overdrive boost the next damaging action, and a charge is one.
	# The further the run, the harder the hit: `damage` + `per_hex` for every hex run first.
	var dmg: int = int(ability.get("damage", 3)) + u.boost_damage + u.damage_bonus
	u.heat += u.boost_heat
	u.boost_damage = 0
	u.boost_heat = 0
	var cell: Vector2i = here
	var run: Array[Vector2i] = []
	for step: int in int(ability.get("range", 3)):
		var next: Vector2i = Hex.neighbor(cell, dir)
		if not state.inside(next) or state.is_pit(next):
			break
		var other: GridUnit = state.unit_at(next.x, next.y)
		dmg += int(ability.get("per_hex", 0)) if step > 0 else 0
		if other != null:
			var hit: int = CombatSim.damage_to(state, u, other, dmg, false)
			CombatSim.hurt(state, u.ref, other, hit)
			if other.alive:
				CombatSim.shove(state, u.ref, other, dir)
			break
		if state.solid(next):
			CombatSim.damage_prop(state, u.ref, next, dmg)
			break
		cell = next
		run.append(cell)
		state.emit(GridEv.STEP, u.ref, -1, cell.x, cell.y)
	if cell != here:
		u.x = cell.x
		u.y = cell.y
		state.emit(GridEv.MOVED, u.ref, -1, u.x, u.y, here.x, here.y)
		CombatSim.collect_path(state, u, run)


## Drag the unit on `target` toward `u` along the line between them, until it is adjacent
## or something stops it. Over a pit, it falls.
static func _grapple(state: CombatState, u: GridUnit, target: Vector2i) -> void:
	var victim: GridUnit = state.unit_at(target.x, target.y)
	if victim == null:
		return
	var here := Vector2i(u.x, u.y)
	var from := Vector2i(victim.x, victim.y)
	var cell: Vector2i = from
	for next: Vector2i in Hex.line(from, here):
		if Hex.distance(cell, here) <= 1 or next == here:
			break
		if state.is_pit(next):
			CombatSim.fall(state, u.ref, victim, next)
			return
		if state.solid(next) or state.unit_at(next.x, next.y) != null:
			break
		cell = next
	if cell != from:
		victim.x = cell.x
		victim.y = cell.y
		state.emit(GridEv.PULLED, u.ref, victim.ref, cell.x, cell.y, from.x, from.y)


## Nothing solid and nobody standing between `a` and `b` (exclusive).
static func _clear_line(state: CombatState, a: Vector2i, b: Vector2i) -> bool:
	for c: Vector2i in Hex.line(a, b):
		if c == b:
			return true
		if state.solid(c) or state.unit_at(c.x, c.y) != null:
			return false
	return true
