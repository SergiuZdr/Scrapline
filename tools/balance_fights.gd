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
##
## `--arms N` (072) runs the ARM TRIAL instead: N scenarios (a map, a random crew, a random enemy
## squad made tougher by `--arm-hp` / `--arm-damage` so the crew can lose), each played once per arm
## with that arm fitted to every crew machine's left socket and nothing else changed. Every arm meets
## the same scenarios, so each is ranked against the average of all arms on the same fights.
##
## `--boss DIR` (083) plays the boss and warlord fights a run built (`dump_boss_fights.gd --per N
## --out DIR`), `--seeds` times each, and reports per act and kind: win rate, rounds, crew HP lost,
## rounds played after the last keeper fell, and losses in which the crew ended with MORE HP than it
## started with (the heal-farm). `boss.<key>=json` in `--set` / `--b` lays a key over every such
## fight (`boss.pile_heal=0`, `boss.escort_waves=[]`; `boss.keeper=false` strips the keeper flags;
## `boss.keeper_hp=60` sets every keeper's HP).
## `all.<key>=json` (084) lays a key over every fight: `--b 'all.modifiers=["dust"]'` judges a yard
## condition on the same fights; `all.enemy_bonus={"hp":20,"damage":2}` makes them losable.

const Jobs = preload("res://tools/jobs.gd")
const Stats = preload("res://tools/stats.gd")

## The arm trial's default enemy toughening (072). Measured over 15 scenarios: +8 HP +2 damage still
## let the crew win 93% (the bot dodges nearly every telegraphed shot); +40 HP +5 damage, 66%, with
## 14 of 15 scenarios going either way by the arm -- where one arm against another shows most.
const ARM_HP: int = 40
const ARM_DAMAGE: int = 5

var _db: ContentDB


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var count: int = _arg_int(args, "--fights", 300)
	var seeds: int = _arg_int(args, "--seeds", 5)
	var slice: Array = Jobs.slice(args)
	var quiet: bool = not slice.is_empty()
	var dbs: Array[ContentDB] = [ContentDB.load_all()]
	for setting: String in Stats.all_after(args, "--set"):
		if not setting.begins_with("boss.") and not setting.begins_with("all."):
			Stats.override(dbs[0], setting, quiet)
	dbs[0].set_meta("all_fight", _all_settings(Stats.all_after(args, "--set")))
	var b_settings: PackedStringArray = Stats.all_after(args, "--b")
	if not b_settings.is_empty():
		dbs.append(ContentDB.load_all())
		for setting: String in Stats.all_after(args, "--set"):
			if not setting.begins_with("boss.") and not setting.begins_with("all."):
				Stats.override(dbs[1], setting, true)
		if not quiet:
			print("  variant B:")
		for setting: String in b_settings:
			if not setting.begins_with("boss.") and not setting.begins_with("all."):
				Stats.override(dbs[1], setting, quiet)
		var both: Dictionary = _all_settings(Stats.all_after(args, "--set"))
		both.merge(_all_settings(b_settings), true)
		dbs[1].set_meta("all_fight", both)
	_db = dbs[0]
	if args.has("--boss"):
		_boss_trial(args, slice, dbs, b_settings)
		return
	if args.has("--arms"):
		_arm_trial(args, slice)
		return

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


## The arm trial (072). Item `s * arms + a`: scenario `s` with arm `a` on every crew machine's left.
func _arm_trial(args: PackedStringArray, slice: Array) -> void:
	var scenarios: int = _arg_int(args, "--arms", 100)
	var bonus: Dictionary = {"hp": _arg_int(args, "--arm-hp", ARM_HP), "damage": _arg_int(args, "--arm-damage", ARM_DAMAGE)}
	var arms: Array = []
	for id: Variant in _db.parts:
		if String((_db.parts[id] as Dictionary).get("slot", "")) == "arm" and not PartTuning.is_tuned(String(id)):
			arms.append(String(id))
	arms.sort()
	var ids: Array = _db.fights.keys()
	ids.sort()
	var pool: Array = ids.filter(func(id: Variant) -> bool:
		var map: Dictionary = _db.fights[id]
		return not bool(map.get("tutorial", false)) and not bool(map.get("boss", false)))
	var items: int = scenarios * arms.size()
	var jobs: int = _arg_int(args, "--jobs", Jobs.default_count())
	var results: Dictionary = {}
	var uses: Dictionary = {}
	if slice.is_empty() and jobs > 1:
		for part: Dictionary in Jobs.run("res://tools/balance_fights.gd", args, jobs, items, "won"):
			results.merge(part["trial"])
			Jobs.merge(uses, part.get("uses", {}))
	else:
		for item: int in items:
			if not Jobs.mine(slice, item):
				continue
			var s: int = item / arms.size()
			var arm: String = arms[item % arms.size()]
			var template: Dictionary = _db.fights[pool[s % pool.size()]]
			# The scenario's dice are the scenario's alone: every arm meets the same crew and enemy.
			var rng := SimRNG.new(104729 * (s + 1))
			var fight: Dictionary = template.duplicate(true)
			fight["player"] = _random_squad(rng, template["player"])
			fight["enemy"] = _random_squad(rng, template["enemy"])
			for spec: Dictionary in fight["enemy"]:
				spec["bonus"] = bonus
			for spec: Dictionary in fight["player"]:
				spec["parts"][2] = arm
			var stats: Dictionary = _new_stats()
			var won: bool = _play(_db, fight, s, stats)
			Jobs.merge(uses, stats["uses"])
			var cause: int = 0 if won else (1 if int(stats["lost_crew"]) > 0 else (2 if int(stats["timeout"]) > 0 else 3))
			results[str(item)] = [1 if won else 0, int(stats["crew_hp_lost"]), int(stats["rounds"]), cause]
			Jobs.progress(slice, ("+ " if won else "- ") + str(item))
		if not slice.is_empty():
			Jobs.finish(slice, {"trial": results, "uses": uses})
			quit()
			return

	# Per scenario, the average over every arm; each arm is scored by how far it sits from it.
	var a_n: int = arms.size()
	var won_total: int = 0
	var decisive: int = 0
	var base_win: Array = []
	var base_hp: Array = []
	var base_rounds: Array = []
	var causes: Array = [0, 0, 0, 0]
	for s: int in scenarios:
		var w: float = 0.0
		var h: float = 0.0
		var rd: float = 0.0
		for a: int in a_n:
			var r: Array = results.get(str(s * a_n + a), [0, 0, 0, 0])
			w += int(r[0])
			h += int(r[1])
			rd += int(r[2])
			causes[int(r[3])] += 1
		base_win.append(w / a_n)
		base_hp.append(h / a_n)
		base_rounds.append(rd / a_n)
		won_total += int(w)
		decisive += 1 if w > 0.0 and w < a_n else 0
	var z: float = Stats.z_for(a_n)
	var rows: Array = []
	for a: int in a_n:
		var won: int = 0
		var dw: float = 0.0
		var dw2: float = 0.0
		var dh: float = 0.0
		var dh2: float = 0.0
		var dr: float = 0.0
		var dr2: float = 0.0
		for s: int in scenarios:
			var r: Array = results.get(str(s * a_n + a), [0, 0, 0, 0])
			var q: float = int(r[2]) - float(base_rounds[s])
			dr += q
			dr2 += q * q
			won += int(r[0])
			var x: float = int(r[0]) - float(base_win[s])
			dw += x
			dw2 += x * x
			var y: float = int(r[1]) - float(base_hp[s])
			dh += y
			dh2 += y * y
		var win_ci: Array = Stats.mean_ci(dw, dw2, scenarios, z)
		var hp_ci: Array = Stats.mean_ci(dh, dh2, scenarios, z)
		var rounds_ci: Array = Stats.mean_ci(dr, dr2, scenarios, z)
		rows.append([win_ci[0], arms[a], won, win_ci[1], hp_ci[0], hp_ci[1], rounds_ci[0], rounds_ci[1]])
	rows.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]) or (float(x[0]) == float(y[0]) and String(x[1]) < String(y[1])))
	print("")
	print("=== arm trial: %d scenarios x %d arms, enemies +%d HP +%d damage ===" % [scenarios, a_n, bonus["hp"], bonus["damage"]])
	print("  the crew won %s of all fights; %d of %d scenarios went either way depending on the arm" % [
		Stats.rate(won_total, scenarios * a_n), decisive, scenarios])
	print("  losses: crew wrecked %d, out of rounds %d, objective lost %d" % [causes[1], causes[2], causes[3]])
	print("  the bot used: %s" % _uses_text(uses))
	print("  (a crew win rate of 50-75% separates arms best: tune with --arm-hp / --arm-damage; intervals are sized")
	print("   for %d arms judged at once, so a verdict is wrong at most 1 batch in 20)" % a_n)
	print("")
	print("  %-15s %-6s %-20s %-30s %-20s %s" % ["arm", "rarity", "won", "won vs the average", "rounds vs average", "crew HP lost vs average"])
	for row: Array in rows:
		var id: String = row[1]
		var part: Dictionary = _db.parts[id]
		# Wins first; failing that, how fast it ends the fight (fewer rounds is stronger).
		var marks: PackedStringArray = []
		if float(row[0]) - float(row[3]) > 0.0:
			marks.append("wins more")
		elif float(row[0]) + float(row[3]) < 0.0:
			marks.append("wins less")
		if float(row[6]) + float(row[7]) < 0.0:
			marks.append("faster")
		elif float(row[6]) - float(row[7]) > 0.0:
			marks.append("slower")
		var verdict: String = "" if marks.is_empty() else "   <- " + ", ".join(marks)
		print("  %-15s r%-5d %-20s %+6.1f pts (%+5.1f to %+5.1f)  %+5.2f (+-%.2f)      %+5.1f HP (+-%.1f)%s" % [id, int(part.get("rarity", 0)),
			Stats.rate(int(row[2]), scenarios), 100.0 * row[0], 100.0 * (row[0] - row[3]), 100.0 * (row[0] + row[3]),
			row[6], row[7], row[4], row[5], verdict])
	print("")
	quit()


## 083: the run-built boss fights (see the header). Item `(f * seeds + k) * variants + v`.
func _boss_trial(args: PackedStringArray, slice: Array, dbs: Array[ContentDB], b_settings: PackedStringArray) -> void:
	var dir: String = args[args.find("--boss") + 1]
	var seeds: int = _arg_int(args, "--seeds", 5)
	var files: Array = []
	for f: String in DirAccess.get_files_at(dir):
		if f.begins_with("real_") and f.ends_with(".json"):
			files.append(f)
	files.sort()
	var overlays: Array = [_boss_overlay(Stats.all_after(args, "--set")), _boss_overlay(Stats.all_after(args, "--set"))]
	overlays[1].merge(_boss_overlay(b_settings), true)
	var variants: int = dbs.size()
	var items: int = files.size() * seeds * variants
	var jobs: int = _arg_int(args, "--jobs", Jobs.default_count())
	var numbers: Dictionary = {"A": {}, "B": {}, "pairs": {}}
	if slice.is_empty() and jobs > 1:
		for part: Dictionary in Jobs.run("res://tools/balance_fights.gd", args, jobs, items, "won"):
			Jobs.merge(numbers, part)
	else:
		for item: int in items:
			if not Jobs.mine(slice, item):
				continue
			var v: int = item % variants
			var base: int = item / variants
			var file: String = files[base / seeds]
			# JSON has no integers: every number back to an int, as a resumed run reads its save.
			var fight: Dictionary = RunStore._ints(JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(file))))
			for key: String in (overlays[v] as Dictionary):
				if key == "keeper":
					for spec: Dictionary in fight["enemy"]:
						if not bool(overlays[v]["keeper"]):
							spec.erase("keeper")
				elif key == "keeper_hp":
					for spec: Dictionary in fight["enemy"]:
						if bool(spec.get("keeper", false)):
							spec["hp"] = int(overlays[v]["keeper_hp"])
				else:
					fight[key] = overlays[v][key]
			var group: String = file.trim_prefix("real_").trim_suffix(".json")
			group = group.substr(0, group.rfind("_")) if group.count("_") >= 2 else group
			var seed_value: int = int(fight.get("_combat_seed", 1000)) + base % seeds
			var row: Dictionary = _boss_play(dbs[v], fight, seed_value)
			var mine: Dictionary = numbers["A" if v == 0 else "B"]
			if not mine.has(group):
				mine[group] = {"fights": 0, "won": 0, "rounds": 0, "hp_lost": 0, "hp_lost_sq": 0, "after_keeper": 0,
					"keeper_fell": 0, "heal_losses": 0, "lost": 0, "timeout": 0}
			for key: String in row:
				mine[group][key] = int(mine[group][key]) + int(row[key])
			var pair: Array = numbers["pairs"].get(str(base), [0, 0])
			pair[v] = int(row["won"])
			numbers["pairs"][str(base)] = pair
			Jobs.progress(slice, ("+ " if int(row["won"]) > 0 else "- ") + str(item))
		if not slice.is_empty():
			Jobs.finish(slice, numbers)
			quit()
			return
	print("")
	print("=== run-built boss fights: %d files x %d seeds, from %s ===" % [files.size(), seeds, dir])
	for v: int in variants:
		var label: String = "A" if v == 0 else "B (%s)" % ", ".join(b_settings)
		print("##### %s" % label)
		_boss_report(numbers["A" if v == 0 else "B"])
	if variants > 1:
		var t: Array = [0, 0, 0]
		for key: Variant in numbers["pairs"]:
			var pair: Array = numbers["pairs"][key]
			t[2] += 1
			if int(pair[0]) == 1 and int(pair[1]) == 0:
				t[0] += 1
			elif int(pair[1]) == 1 and int(pair[0]) == 0:
				t[1] += 1
		print("  boss fights won, B - A: %s" % Stats.verdict(Stats.paired(t[1], t[0], t[2])))
	print("")
	quit()


## `boss.<key>=json` settings as `{key: value}`.
func _boss_overlay(settings: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for setting: String in settings:
		if not setting.begins_with("boss."):
			continue
		var pair: PackedStringArray = setting.trim_prefix("boss.").split("=", true, 1)
		out[pair[0]] = JSON.parse_string(pair[1])
	return out


## One run-built boss fight played by the bot: the numbers `_boss_trial` adds up.
func _boss_play(db: ContentDB, fight: Dictionary, seed_value: int) -> Dictionary:
	var setup: CombatSetup = CombatSetup.build(fight, db.combat_rules, db.parts, db.tiles, db.effectiveness, seed_value)
	if not setup.errors.is_empty():
		push_error("setup errors: %s" % [setup.errors])
	Stats.bot_for(db)
	var state: CombatState = CombatSim.start(setup)
	var start_hp: int = 0
	for u: GridUnit in state.units:
		if u.team == GridUnit.TEAM_PLAYER and not u.objective:
			start_hp += u.hp
	var guard: int = 0
	while state.outcome == CombatState.ONGOING and guard < 60:
		CombatBot.take_turn(state)
		guard += 1
	var end_hp: int = 0
	for u: GridUnit in state.units:
		if u.team == GridUnit.TEAM_PLAYER and not u.objective and u.alive:
			end_hp += u.hp
	# The keepers by the fight's own flags, so the old rules (no keepers) are measured the same way.
	var keepers: Array = []
	for slot: int in (fight["enemy"] as Array).size():
		if bool((fight["enemy"][slot] as Dictionary).get("keeper", false)):
			keepers.append(GridUnit.TEAM_ENEMY * 10 + slot)
	var dead: Dictionary = {}
	var round: int = 0
	var fell_at: int = -1
	for e: Array in state.events:
		var kind: int = int(e[GridEv.F_KIND])
		if kind == GridEv.ROUND_START:
			round = int(e[GridEv.F_V1])
		elif kind == GridEv.DESTROYED and keepers.has(int(e[GridEv.F_TARGET])):
			dead[int(e[GridEv.F_TARGET])] = true
			if dead.size() == keepers.size() and fell_at < 0:
				fell_at = round
		elif kind == GridEv.REBUILT and dead.has(int(e[GridEv.F_TARGET])):
			dead.erase(int(e[GridEv.F_TARGET]))
			fell_at = -1
	var won: bool = state.outcome == CombatState.WON
	var lost_hp: int = start_hp - end_hp
	return {"fights": 1, "won": 1 if won else 0, "rounds": state.round_number, "hp_lost": lost_hp, "hp_lost_sq": lost_hp * lost_hp,
		"keeper_fell": 1 if fell_at >= 0 else 0, "after_keeper": state.round_number - fell_at if fell_at >= 0 else 0,
		"heal_losses": 1 if not won and end_hp > start_hp else 0, "lost": 0 if won else 1,
		"timeout": 1 if not won and not state.crew(GridUnit.TEAM_PLAYER).is_empty() else 0}


func _boss_report(groups: Dictionary) -> void:
	var keys: Array = groups.keys()
	keys.sort()
	var all: Dictionary = {}
	for key: Variant in keys:
		_boss_line(String(key), groups[key])
		Jobs.merge(all, groups[key])
	if not all.is_empty():
		_boss_line("all", all)


func _boss_line(label: String, g: Dictionary) -> void:
	var n: int = maxi(1, int(g["fights"]))
	print("  %-13s win %-17s | rounds %4.1f | crew HP lost %s | keeper fell %d/%d, rounds after it %.2f | lost %d (timeout %d, with HP risen %d)" % [
		label, Stats.rate(int(g["won"]), int(g["fights"])), float(g["rounds"]) / n,
		Stats.mean_text(g["hp_lost"], g["hp_lost_sq"], int(g["fights"])), int(g["keeper_fell"]), int(g["fights"]),
		float(g["after_keeper"]) / maxi(1, int(g["keeper_fell"])), int(g["lost"]), int(g["timeout"]), int(g["heal_losses"])])


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
	print("  the bot used: %s" % _uses_text(total["uses"]))

	print("")
	var fights: int = int(total["fights"])
	var arm_wins: Dictionary = numbers["arms"]
	var classes: Array = arm_wins.keys()
	classes.sort()
	# Judged together: with ten arms, ten 95% intervals flag one by chance most batches.
	var z: float = Stats.z_for(classes.size())
	print("  player arms (random fights): win rate with the arm, and its difference from the fights without it")
	print("  (intervals sized for %d arms judged at once, so a \"real\" is wrong at most 1 batch in 20;" % classes.size())
	print("   a class mixes unlike arms and the crew rarely loses here: rank arms with --arms 150):")
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
	print("  the bot used: A %s" % _uses_text(a["uses"]))
	print("                B %s" % _uses_text(b["uses"]))
	print("")


## "charge 41, dash 230, ..." -- abilities by kind and casts of a shield arm (073), per fight played.
func _uses_text(uses: Dictionary) -> String:
	if uses.is_empty():
		return "no ability"
	var kinds: Array = uses.keys()
	kinds.sort()
	var parts: PackedStringArray = []
	for kind: Variant in kinds:
		parts.append("%s %d" % [kind, int(uses[kind])])
	return ", ".join(parts)


func _new_stats() -> Dictionary:
	return {"fights": 0, "won": 0, "lost_objective": 0, "lost_crew": 0, "timeout": 0, "rounds": 0,
		"player_dmg": 0, "enemy_dmg": 0, "crew_hp_lost": 0,
		"crew_hp_lost_sq": 0, "intents": 0, "intents_hit": 0, "uses": {}}


## Plays one fight with the bot. Returns true on a win.
func _play(db: ContentDB, fight: Dictionary, seed_value: int, stats: Dictionary) -> bool:
	fight = _lay_all(db, fight, seed_value)
	var setup: CombatSetup = CombatSetup.build(fight, db.combat_rules, db.parts, db.tiles, db.effectiveness, seed_value)
	if not setup.errors.is_empty():
		push_error("setup errors: %s" % [setup.errors])
		return false
	Stats.bot_for(db)
	var state: CombatState = CombatSim.start(setup)
	var guard: int = 0
	var uses: Dictionary = stats["uses"]
	while state.outcome == CombatState.ONGOING and guard < 60:
		for action: Array in CombatBot.take_turn(state):
			# 073: what the bot used, by ability kind (and casts of a shield arm).
			var u: GridUnit = state.unit(int(action[1]))
			if int(action[0]) == CombatSim.ACT_ABILITY:
				var kind: String = String(u.abilities[int(action[2])]["kind"])
				uses[kind] = int(uses.get(kind, 0)) + 1
			elif int(action[0]) == CombatSim.ACT_ATTACK and String(u.weapons[int(action[2])]["shape"]) == "shield":
				uses["shield arm"] = int(uses.get("shield arm", 0)) + 1
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


## 084 (B7): `all.<key>=json` in `--set` / `--b` lays a key over every fight played (authored and
## random). `all.modifiers=["wires"]` also lays the cables the way a run does (`RunSim.lay_wires`);
## `all.enemy_bonus={"hp":20,"damage":2}` arms every enemy, so a condition is judged on fights the
## crew can lose (a test the crew always wins cannot show a 5-point change).
static func _all_settings(settings: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	for setting: String in settings:
		if setting.begins_with("all."):
			var pair: PackedStringArray = setting.split("=", true, 1)
			out[pair[0].trim_prefix("all.")] = JSON.parse_string(pair[1])
	return out


func _lay_all(db: ContentDB, fight: Dictionary, seed_value: int) -> Dictionary:
	var lay: Dictionary = db.get_meta("all_fight", {})
	if lay.is_empty():
		return fight
	var out: Dictionary = fight.duplicate(true)
	var keys: Array = lay.keys()
	keys.sort()
	for key: Variant in keys:
		if String(key) == "enemy_bonus":
			for spec: Dictionary in out.get("enemy", []):
				var bonus: Dictionary = spec.get("bonus", {})
				for k: Variant in lay[key]:
					bonus[k] = int(bonus.get(k, 0)) + int(lay[key][k])
				spec["bonus"] = bonus
		else:
			out[key] = lay[key]
	if (out.get("modifiers", []) as Array).has("wires") and not "".join(PackedStringArray(out["rows"])).contains("w"):
		out["rows"] = (out["rows"] as Array).duplicate()
		RunSim.lay_wires(db.run_rules.get("modifiers", {}), SimRNG.new(7907 * (seed_value + 1)), out, fight)
	return out
