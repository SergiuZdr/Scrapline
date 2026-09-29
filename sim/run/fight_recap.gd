class_name FightRecap
extends RefCounted

## What a fight did, read off its event stream (014, review point R5-1): per machine the damage
## dealt and taken, kills and torn arms; and **the build at work** -- every set, perk and tuning
## that changed a number this fight, with what it added. Builds (011) are invisible in the
## fight that uses them; this makes them legible without a new system.
##
## Pure: the finished fight, the run's crew and content in, a plain dictionary out. It counts,
## it never decides anything.

## At most this many "build at work" lines, the largest first.
const MAX_BUILDS: int = 4


## `state`: the finished fight. `crew`: the run's crew members in the order they were fielded
## (unit ref = index). `setup`: the run's setup (parts, makers, perks, levels).
static func build(state: CombatState, setup: RunSetup, crew: Array) -> Dictionary:
	var stats: Dictionary = {}
	for i: int in crew.size():
		stats[i] = {"dealt": 0, "taken": 0, "kills": 0, "torn": 0, "hits": 0, "melee_hits": 0,
			"hits_taken": 0, "by_weapon": [0, 0]}
	# What caused each DAMAGE: the last ATTACK, EXPLOSION, BUMP or ability before it.
	var cause: Dictionary = {}
	for e: Array in state.events:
		var kind: int = int(e[GridEv.F_KIND])
		var actor: int = int(e[GridEv.F_ACTOR])
		var target: int = int(e[GridEv.F_TARGET])
		match kind:
			GridEv.ATTACK:
				cause = {"kind": "attack", "actor": actor, "w": int(e[GridEv.F_V1])}
			GridEv.EXPLOSION, GridEv.BUMP, GridEv.WRECK_THROWN, GridEv.ABILITY:
				cause = {"kind": "other", "actor": actor}
			GridEv.TURN_END, GridEv.ROUND_START:
				cause = {}
			GridEv.DAMAGE:
				var dmg: int = int(e[GridEv.F_V1])
				var by_attack: bool = String(cause.get("kind", "")) == "attack" and int(cause.get("actor", -1)) == actor
				# Dealt is damage to the other side: a drum a machine sets off beside itself
				# hurts it, and that is not damage it dealt.
				if stats.has(actor) and target >= GridUnit.TEAM_ENEMY * 10:
					stats[actor]["dealt"] += dmg
					if by_attack:
						stats[actor]["hits"] += 1
						var w: int = int(cause["w"])
						if w >= 0 and w < 2:
							stats[actor]["by_weapon"][w] += 1
						var unit: GridUnit = state.unit(actor)
						if unit != null and w >= 0 and w < unit.weapons.size() and String(unit.weapons[w]["shape"]) == "melee":
							stats[actor]["melee_hits"] += 1
				if stats.has(target):
					stats[target]["taken"] += dmg
					if by_attack:
						stats[target]["hits_taken"] += 1
			GridEv.DESTROYED:
				if stats.has(actor) and target >= GridUnit.TEAM_ENEMY * 10:
					stats[actor]["kills"] += 1
			GridEv.PART_TORN:
				if stats.has(target):
					stats[target]["torn"] += 1

	var machines: Array = []
	var builds: Array = []
	for i: int in crew.size():
		var member: Dictionary = crew[i]
		var unit: GridUnit = state.unit(i)
		var s: Dictionary = stats[i]
		machines.append({"name": String(member.get("name", "")), "dealt": int(s["dealt"]), "taken": int(s["taken"]),
			"kills": int(s["kills"]), "torn": int(s["torn"]), "wrecked": unit != null and not unit.alive})
		for source: Array in _sources(setup, member):
			var effect: Array = _effect(source[1], s, int(source[2]), unit)
			if int(effect[0]) > 0:
				builds.append({"who": String(member.get("name", "")), "what": String(source[0]), "text": String(effect[1]),
					"size": int(effect[0])})
	builds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["size"]) > int(b["size"]) or (int(a["size"]) == int(b["size"]) and String(a["what"]) < String(b["what"])))
	return {"machines": machines, "builds": builds.slice(0, MAX_BUILDS), "scrap": state.scrap_collected,
		"piles": state.piles_collected, "rounds": state.round_number}


## `[label, grid, weapon]` for every set, perk and tuning on a machine. `weapon` is the arm a
## tuned weapon's bonus belongs to (0 or 1), or -1 for the whole machine.
static func _sources(setup: RunSetup, member: Dictionary) -> Array:
	var out: Array = []
	var parts: Array = member.get("parts", [])
	var makers: Dictionary = setup.combat_rules.get("makers", {})
	for entry: Dictionary in CombatSetup.sets_of(PackedStringArray(parts), setup.parts, makers):
		var maker: Dictionary = makers.get(String(entry["maker"]), {})
		for tier: Variant in (entry["active"] as Array):
			out.append(["%s x%d" % [String(maker.get("short", entry["maker"])), int(tier)],
				((maker.get("sets", {}) as Dictionary).get(str(tier), {})) as Dictionary, -1])
	var perks: Dictionary = setup.rules.get("perks", {})
	for id: Variant in (member.get("perks", []) as Array):
		var perk: Dictionary = perks.get(String(id), {})
		out.append([String(perk.get("name", id)), perk.get("grid", {}), -1])
	for socket: int in parts.size():
		var part: Dictionary = setup.parts.get(String(parts[socket]), {})
		if part.has("tune_grid"):
			out.append(["%s (%s)" % [String(part.get("tune", "")), String(part.get("name", ""))], part["tune_grid"],
				socket - 2 if socket == 2 or socket == 3 else -1])
	return out


## `[size, text]`: what one source's bonus did this fight, measured on the machine's hits.
## Only numbers the event stream can back: damage and melee on hits landed, armour on hits
## taken, HP that kept a machine standing.
static func _effect(grid: Dictionary, s: Dictionary, weapon: int, unit: GridUnit) -> Array:
	var hits: int = int(s["hits"]) if weapon < 0 else int((s["by_weapon"] as Array)[weapon])
	if int(grid.get("damage", 0)) > 0 and hits > 0:
		var added: int = int(grid["damage"]) * hits
		return [added, "added %d damage over %d hit%s" % [added, hits, "" if hits == 1 else "s"]]
	if int(grid.get("melee", 0)) > 0 and int(s["melee_hits"]) > 0:
		var added: int = int(grid["melee"]) * int(s["melee_hits"])
		return [added, "added %d melee damage" % added]
	if int(grid.get("armor", 0)) > 0 and int(s["hits_taken"]) > 0:
		var saved: int = int(grid["armor"]) * int(s["hits_taken"])
		return [saved, "took up to %d off %d hit%s" % [saved, int(s["hits_taken"]), "" if int(s["hits_taken"]) == 1 else "s"]]
	if int(grid.get("hp", 0)) > 0 and unit != null and unit.alive and unit.hp <= int(grid["hp"]):
		return [int(grid["hp"]), "+%d HP kept it standing" % int(grid["hp"])]
	return [0, ""]
