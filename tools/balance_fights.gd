extends SceneTree

## Bot fights in bulk: does the enemy threaten anything, and does the player ever lose?
##
##   godot --headless --path . --script res://tools/balance_fights.gd -- [--fights 300] [--seeds 5]
##       [--jobs N] [--set path=json ...] [--b path=json ...]
##
## `--jobs` (070): over N processes, one per core but one by default (`tools/jobs.gd`).
## `--set` changes a number for this batch (`combat.<path>`, `fight.<id>.<path>`, as `run_bot.gd`);
## `--b` (071) plays a variant B on exactly the same fights and squads and reports B - A.
##
## Two kinds of fight:
##   authored  -- each fight file as written, `--seeds` times. Seeds break ties, so they do change
##                the fight (different rounds, different events), but the squads are fixed: a
##                small sample of one fight each, with its interval.
##   random    -- each fight file's MAP and positions, with both squads rolled from the
##                whole parts pool by SimRNG. This is the real measurement.
##
## The numbers that matter:
##   enemy share   -- enemy damage / player damage. Iteration 002 measured 6/42 = 14%.
##   loss causes   -- a lost objective means the pressure works; all-timeout means stalemate.
##   arms          -- per weapon class on the PLAYER side (071): the win rate of the random fights
##                    with that arm against those without it, flagged only when the difference is
##                    bigger than its own noise (the old fixed "6 points" flagged noise at n = 38).
## Every rate carries its 95% interval (`tools/stats.gd`).

const Jobs = preload("res://tools/jobs.gd")
const Stats = preload("res://tools/stats.gd")

var _db: ContentDB


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var count: int = _arg_int(args, "--fights", 300)
	var seeds: int = _arg_int(args, "--seeds", 5)
	var slice: Array = Jobs.slice(args)
	var quiet: bool = not slice.is_empty()
	var dbs: Array[ContentDB] = [ContentDB.load_all()]
	for setting: String in Stats.all_after(args, "--set"):
		Stats.override(dbs[0], setting, quiet)
	var b_settings: PackedStringArray = Stats.all_after(args, "--b")
	if not b_settings.is_empty():
		dbs.append(ContentDB.load_all())
		for setting: String in Stats.all_after(args, "--set"):
			Stats.override(dbs[1], setting, true)
		if not quiet:
			print("  variant B:")
		for setting: String in b_settings:
			Stats.override(dbs[1], setting, quiet)
	_db = dbs[0]

	var ids: Array = _db.fights.keys()
	ids.sort()
	# The run's own maps only: the tutorial's board and the gate are not where squads meet
	# at random (013), and counting them skews the comparison with earlier iterations.
	var pool: Array = ids.filter(func(id: Variant) -> bool:
		var map: Dictionary = _db.fights[id]
		return not bool(map.get("tutorial", false)) and not bool(map.get("boss", false)))
	# Work items, numbered so `--jobs` (070) can share them out: `seeds` of every authored fight,
	# then the random fights; each played once per variant.
	var authored_items: int = ids.size() * seeds
	var base_items: int = authored_items + count
	var items: int = base_items * dbs.size()
	var jobs: int = _arg_int(args, "--jobs", Jobs.default_count())
	var numbers: Dictionary = {"A": _new_numbers(), "B": _new_numbers(), "pairs": {}}
	if slice.is_empty() and jobs > 1:
		for part: Dictionary in Jobs.run("res://tools/balance_fights.gd", args, jobs, items, "won"):
			Jobs.merge(numbers, part)
	else:
		for item: int in items:
			if not Jobs.mine(slice, item):
				continue
			var base: int = item / dbs.size()
			var v: int = item % dbs.size()
			var db: ContentDB = dbs[v]
			var mine: Dictionary = numbers["A" if v == 0 else "B"]
			var won: bool = false
			if base < authored_items:
				var id: String = String(ids[base / seeds])
				if not (mine["authored"] as Dictionary).has(id):
					mine["authored"][id] = _new_stats()
				won = _play(db, db.fights[id], 1000 + base % seeds, mine["authored"][id])
			else:
				var i: int = base - authored_items
				var template: Dictionary = db.fights[pool[i % pool.size()]]
				var rng := SimRNG.new(7919 * (i + 1))
				var fight: Dictionary = template.duplicate(true)
				fight["player"] = _random_squad(rng, template["player"])
				fight["enemy"] = _random_squad(rng, template["enemy"])
				won = _play(db, fight, i, mine["random"])
				# 071: by FIGHT -- did the crew carry this arm class at all -- so a fight counts once.
				var carried: Dictionary = {}
				for spec: Dictionary in fight["player"]:
					for arm: String in [String(spec["parts"][2]), String(spec["parts"][3])]:
						carried[String((db.parts[arm] as Dictionary).get("weapon_class", ""))] = true
				for cls: Variant in carried:
					var row: Array = mine["arms"].get(cls, [0, 0])
					row[0] += 1 if won else 0
					row[1] += 1
					mine["arms"][cls] = row
			var pair: Array = [0, 0]
			pair[v] = 1 if won else 0
			numbers["pairs"][str(base)] = pair
			Jobs.progress(slice, ("+ " if won else "- ") + str(item))
		if not slice.is_empty():
			Jobs.finish(slice, numbers)
			quit()
			return

	if dbs.size() == 1:
		_report_all(ids, numbers["A"], count)
	else:
		print("")
		print("##### A: the game%s" % ("" if Stats.all_after(args, "--set").is_empty() else " with the --set overrides"))
		_report_all(ids, numbers["A"], count)
		print("##### B: A with %s" % ", ".join(b_settings))
		_report_all(ids, numbers["B"], count)
		_compare(numbers, authored_items, count)
	quit()


func _new_numbers() -> Dictionary:
	return {"authored": {}, "random": _new_stats(), "arms": {}}


func _report_all(ids: Array, numbers: Dictionary, count: int) -> void:
	print("")
	print("=== authored fights (bot as player) ===")
	for id: Variant in ids:
		if (numbers["authored"] as Dictionary).has(id):
			_report(String(id), numbers["authored"][id])

	print("")
	print("=== random squads on authored maps (%d fights) ===" % count)
	var total: Dictionary = numbers["random"]
	_report("random", total)

	print("")
	var fights: int = int(total["fights"])
	var arm_wins: Dictionary = numbers["arms"]
	var classes: Array = arm_wins.keys()
	classes.sort()
	# Judged together: with ten arms, ten 95% intervals flag one by chance most batches.
	var z: float = Stats.z_for(classes.size())
	print("  player arms (random fights): win rate with the arm, and its difference from the fights without it")
	print("  (intervals sized for %d arms judged at once, so a \"real\" is wrong at most 1 batch in 20):" % classes.size())
	for cls: Variant in classes:
		var row: Array = arm_wins[cls]
		var with_won: int = int(row[0])
		var with_n: int = int(row[1])
		var d: Array = Stats.unpaired(with_won, with_n, int(total["won"]) - with_won, fights - with_n, z)
		var real: bool = Stats.is_real(d) and fights - with_n > 0
		print("    %-11s %-18s %+5.1f (%+.1f to %+.1f)  in %d fights%s" % [cls, Stats.rate(with_won, with_n),
			100.0 * d[0], 100.0 * d[1], 100.0 * d[2], with_n, "   <- real" if real else ""])
	print("")


## B - A over the same fights and squads (071).
func _compare(numbers: Dictionary, authored_items: int, count: int) -> void:
	var tallies: Array = [[0, 0, 0], [0, 0, 0]]   # authored, random: only A, only B, pairs
	for key: Variant in numbers["pairs"]:
		var pair: Array = numbers["pairs"][key]
		var t: Array = tallies[0 if int(key) < authored_items else 1]
		t[2] += 1
		if int(pair[0]) == 1 and int(pair[1]) == 0:
			t[0] += 1
		elif int(pair[1]) == 1 and int(pair[0]) == 0:
			t[1] += 1
	var a: Dictionary = numbers["A"]["random"]
	var b: Dictionary = numbers["B"]["random"]
	print("=== B - A on the same fights ===")
	print("  random fights won: A %s, B %s" % [Stats.rate(int(a["won"]), int(a["fights"])), Stats.rate(int(b["won"]), int(b["fights"]))])
	print("  B - A: %s" % Stats.verdict(Stats.paired(tallies[1][1], tallies[1][0], tallies[1][2])))
	print("  authored fights, B - A: %s" % Stats.verdict(Stats.paired(tallies[0][1], tallies[0][0], tallies[0][2])))
	print("  crew HP lost per random fight: A %s, B %s" % [
		Stats.mean_text(a["crew_hp_lost"], a["crew_hp_lost_sq"], int(a["fights"])),
		Stats.mean_text(b["crew_hp_lost"], b["crew_hp_lost_sq"], int(b["fights"]))])
	print("  enemy share of the damage: A %d%%, B %d%%" % [int(100.0 * a["enemy_dmg"] / maxf(1.0, a["player_dmg"])),
		int(100.0 * b["enemy_dmg"] / maxf(1.0, b["player_dmg"]))])
	print("")


func _new_stats() -> Dictionary:
	return {"fights": 0, "won": 0, "lost_objective": 0, "lost_crew": 0, "timeout": 0, "rounds": 0,
		"player_dmg": 0, "enemy_dmg": 0, "crew_hp_lost": 0,
		"crew_hp_lost_sq": 0, "intents": 0, "intents_hit": 0}


## Plays one fight with the bot. Returns true on a win.
func _play(db: ContentDB, fight: Dictionary, seed_value: int, stats: Dictionary) -> bool:
	var setup: CombatSetup = CombatSetup.build(fight, db.combat_rules, db.parts, db.tiles, db.effectiveness, seed_value)
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
	var lost_hp: int = 0
	for u: GridUnit in state.units:
		if u.team == GridUnit.TEAM_PLAYER and not u.objective:
			lost_hp += u.max_hp - (u.hp if u.alive else 0)
	stats["crew_hp_lost"] += lost_hp
	stats["crew_hp_lost_sq"] += lost_hp * lost_hp
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
	var n: int = maxi(1, int(s["fights"]))
	print("  %-15s win %-17s | lost: objective %d, crew %d, timeout %d | rounds %.1f | dmg player %.1f enemy %.1f (share %d%%) | intents landing %d%% | crew HP lost per fight %s" % [
		label, Stats.rate(int(s["won"]), int(s["fights"])), s["lost_objective"], s["lost_crew"], s["timeout"],
		float(s["rounds"]) / n, float(s["player_dmg"]) / n, float(s["enemy_dmg"]) / n,
		int(100.0 * s["enemy_dmg"] / maxf(1.0, s["player_dmg"])),
		int(100.0 * s["intents_hit"] / maxf(1.0, s["intents"])),
		Stats.mean_text(s["crew_hp_lost"], s["crew_hp_lost_sq"], int(s["fights"]))])


func _arg_int(args: PackedStringArray, name: String, fallback: int) -> int:
	var at: int = args.find(name)
	return args[at + 1].to_int() if at >= 0 and at + 1 < args.size() else fallback


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
