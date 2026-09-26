extends SceneTree

## Bot fights in bulk: does the enemy threaten anything, and does the player ever lose?
##
##   godot --headless --path . --script res://tools/balance_fights.gd -- [--fights 300]
##
## Two kinds of fight:
##   authored  -- each fight file as written, once per seed (seeds only break ties, so
##                this is close to one sample per fight; it is a smoke test, not a rate)
##   random    -- each fight file's MAP and positions, with both squads rolled from the
##                whole parts pool by SimRNG. This is the real measurement.
##
## The numbers that matter:
##   enemy share   -- enemy damage / player damage. Iteration 002 measured 6/42 = 14%.
##   loss causes   -- a lost objective means the pressure works; all-timeout means stalemate.
##   arm win rate  -- per weapon class on the PLAYER side, against the average. More than
##                    6 points off in random fights is a tuning target.

var _db: ContentDB


func _initialize() -> void:
	_db = ContentDB.load_all()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var count: int = 300
	var at: int = args.find("--fights")
	if at >= 0 and at + 1 < args.size():
		count = args[at + 1].to_int()

	var ids: Array = _db.fights.keys()
	ids.sort()

	print("")
	print("=== authored fights (bot as player) ===")
	for id: Variant in ids:
		var stats: Dictionary = _new_stats()
		for s: int in 5:
			_play(_db.fights[id], 1000 + s, stats)
		_report(String(id), stats)

	print("")
	print("=== random squads on authored maps (%d fights) ===" % count)
	var total: Dictionary = _new_stats()
	var arm_wins: Dictionary = {}
	for i: int in count:
		var template: Dictionary = _db.fights[ids[i % ids.size()]]
		var rng := SimRNG.new(7919 * (i + 1))
		var fight: Dictionary = template.duplicate(true)
		fight["player"] = _random_squad(rng, template["player"])
		fight["enemy"] = _random_squad(rng, template["enemy"])
		var won: bool = _play(fight, i, total)
		for spec: Dictionary in fight["player"]:
			for arm: String in [String(spec["parts"][2]), String(spec["parts"][3])]:
				var cls: String = String((_db.parts[arm] as Dictionary).get("weapon_class", ""))
				var row: Array = arm_wins.get(cls, [0, 0])
				row[0] += 1 if won else 0
				row[1] += 1
				arm_wins[cls] = row
	_report("random", total)

	print("")
	# Relative to the overall rate: with the player bot winning most fights every arm's raw
	# rate sits near that average, and a fixed 40-60 band would flag all of them. What
	# matters is how far an arm moves the result from the average.
	var average: float = 100.0 * total["won"] / maxf(1.0, total["fights"])
	print("  player arm win rates (random fights), against the %.1f%% average:" % average)
	var classes: Array = arm_wins.keys()
	classes.sort()
	for cls: Variant in classes:
		var row: Array = arm_wins[cls]
		var rate: float = 100.0 * row[0] / maxf(1.0, row[1])
		print("    %-11s %5.1f%%  %+5.1f  (%d)%s" % [cls, rate, rate - average, row[1],
			"   <- more than 6 points off" if absf(rate - average) > 6.0 else ""])
	print("")
	quit()


func _new_stats() -> Dictionary:
	return {"fights": 0, "won": 0, "lost_objective": 0, "lost_crew": 0, "timeout": 0, "rounds": 0,
		"player_dmg": 0, "enemy_dmg": 0, "crew_hp_lost": 0, "intents": 0, "intents_hit": 0}


## Plays one fight with the bot. Returns true on a win.
func _play(fight: Dictionary, seed_value: int, stats: Dictionary) -> bool:
	var setup: CombatSetup = CombatSetup.build(fight, _db.combat_rules, _db.parts, _db.tiles, _db.balance.effectiveness, seed_value)
	if not setup.errors.is_empty():
		push_error("setup errors: %s" % [setup.errors])
		return false
	var state: CombatState = CombatSim.start(setup)
	var guard: int = 0
	while state.outcome == CombatState.ONGOING and guard < 60:
		CombatBot.take_turn(state)
		guard += 1
	stats["fights"] += 1
	stats["rounds"] += state.round_number
	for u: GridUnit in state.units:
		if u.team == GridUnit.TEAM_PLAYER and not u.objective:
			stats["crew_hp_lost"] += u.max_hp - (u.hp if u.alive else 0)
	if state.outcome == CombatState.WON:
		stats["won"] += 1
	elif state.crew(GridUnit.TEAM_PLAYER).is_empty():
		stats["lost_crew"] += 1
	elif state.round_number >= setup.max_rounds:
		stats["timeout"] += 1
	else:
		stats["lost_objective"] += 1
	# Damage by side, and how many enemy intents actually landed on something.
	var fired_by_enemy: bool = false
	for e: Array in state.events:
		var kind: int = int(e[GridEv.F_KIND])
		var actor: int = int(e[GridEv.F_ACTOR])
		if kind == GridEv.INTENT_SET:
			stats["intents"] += 1
		elif kind == GridEv.ATTACK:
			fired_by_enemy = actor >= 10
		elif kind == GridEv.DAMAGE and actor >= 0:
			if actor >= 10:
				stats["enemy_dmg"] += int(e[GridEv.F_V1])
				if fired_by_enemy:
					stats["intents_hit"] += 1
					fired_by_enemy = false
			else:
				stats["player_dmg"] += int(e[GridEv.F_V1])
	return state.outcome == CombatState.WON


func _report(label: String, s: Dictionary) -> void:
	var n: float = maxf(1.0, s["fights"])
	print("  %-14s win %5.1f%%  | lost: objective %d, crew %d, timeout %d | rounds %.1f | dmg player %.1f enemy %.1f (share %d%%) | intents landing %d%% | crew HP lost per fight %.1f" % [
		label, 100.0 * s["won"] / n, s["lost_objective"], s["lost_crew"], s["timeout"],
		s["rounds"] / n, s["player_dmg"] / n, s["enemy_dmg"] / n,
		int(100.0 * s["enemy_dmg"] / maxf(1.0, s["player_dmg"])),
		int(100.0 * s["intents_hit"] / maxf(1.0, s["intents"])), s["crew_hp_lost"] / n])


## A squad the same size and positions as `template`, every part rolled from the pool.
func _random_squad(rng: SimRNG, template: Array) -> Array:
	var pools: Dictionary = {"chassis": [], "core": [], "arm": [], "module": []}
	var ids: Array = _db.parts.keys()
	ids.sort()
	for id: Variant in ids:
		# Tuned parts (011) are workshop-made, not rolled.
		if PartTuning.is_tuned(String(id)):
			continue
		var slot: String = String((_db.parts[id] as Dictionary).get("slot", ""))
		if pools.has(slot):
			(pools[slot] as Array).append(id)
	var out: Array = []
	for spec: Dictionary in template:
		out.append({
			"name": String(spec.get("name", "")),
			"x": int(spec["x"]), "y": int(spec["y"]),
			"parts": [rng.pick(pools["chassis"]), rng.pick(pools["core"]), rng.pick(pools["arm"]),
				rng.pick(pools["arm"]), rng.pick(pools["module"])],
		})
	return out
