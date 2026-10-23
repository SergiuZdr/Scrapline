extends SceneTree

## Plays whole runs with the bot and reports how they go.
##
##   godot --headless --path . --script res://tools/run_bot.gd -- [--runs 100] [--jobs N] [--set path=json ...]
##
## `--jobs N` (070) splits the runs over N Godot processes (`tools/jobs.gd`) and sums them into one
## report; the default is one per core but one. `--jobs 1` plays them in this process. Progress is
## printed as runs finish. `--from N` starts at seed 1000 + N.
##
## `--set` overrides one run.json number for this run of the bot only, to try a balance dial
## without editing the data: `--set enemies.count_by_column=[3,3,3,3,4,4,5,5,5]` (`combat.<path>`
## and `fight.<id>.<path>` reach the combat rules and one map). A misspelt path is an error.
##
## `--set bot.route="explorer"` (084) plays the explorer, who takes every site it can reach before
## going on; `--b bot.route="explorer"` compares it with the forward bot on the same seeds.
##
## `--b path=json` (071, repeatable) plays a variant B on the SAME seeds as A (A is the game, or the
## game with the `--set`s) and reports B - A with a verdict: real, or no detectable difference and how
## big it could still be. Same seeds cancel the luck of the draw, so A/B needs far fewer runs than two
## separate batches. Every rate is printed with its 95% interval (`tools/stats.gd`).
##
## The test that plays the real game. Reports the win rate, where and why runs end, how
## many fights a run takes, and the crew's HP at the boss -- the numbers that say
## whether a run is too long, too short, too easy or a wall.

const Jobs = preload("res://tools/jobs.gd")
const Stats = preload("res://tools/stats.gd")


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var runs: int = _arg_int(args, "--runs", 100)
	var first_seed: int = _arg_int(args, "--from", 0)
	var slice: Array = Jobs.slice(args)
	var quiet: bool = not slice.is_empty()
	# Variant A: the game with every `--set`. Variant B (071): A plus every `--b`.
	var dbs: Array[ContentDB] = [ContentDB.load_all()]
	for setting: String in Stats.all_after(args, "--set"):
		Stats.override(dbs[0], setting, quiet)
	var b_settings: PackedStringArray = Stats.all_after(args, "--b")
	if not b_settings.is_empty():
		dbs.append(ContentDB.load_all())
		for setting: String in Stats.all_after(args, "--set"):
			Stats.override(dbs[1], setting, true)
		for setting: String in b_settings:
			if not quiet:
				print("  variant B:")
			Stats.override(dbs[1], setting, quiet)
	var items: int = runs * dbs.size()
	var jobs: int = clampi(_arg_int(args, "--jobs", Jobs.default_count()), 1, maxi(1, items))
	var start_ms: int = Time.get_ticks_msec()
	var stats: Dictionary = {"A": _new_stats(), "B": _new_stats(), "pairs": {}}
	if slice.is_empty() and jobs > 1:
		for part: Dictionary in Jobs.run("res://tools/run_bot.gd", args, jobs, items, "won"):
			Jobs.merge(stats, part)
	else:
		for item: int in items:
			if not Jobs.mine(slice, item):
				continue
			var r: int = item / dbs.size()
			var v: int = item % dbs.size()
			var seed_value: int = 1000 + first_seed + r
			var line: String = _play(dbs[v], seed_value, stats["A" if v == 0 else "B"])
			# Who won each seed, by variant: [A, B], summed across processes.
			var pair: Array = [0, 0]
			pair[v] = 1 if line.begins_with("+") else 0
			stats["pairs"][str(seed_value)] = pair
			if slice.is_empty():
				print("  %d/%d  %s%s  (%.0fs)" % [item + 1, items, "" if dbs.size() == 1 else "AB"[v] + " ", line,
					(Time.get_ticks_msec() - start_ms) / 1000.0])
			Jobs.progress(slice, line)
		if not slice.is_empty():
			Jobs.finish(slice, stats)
			quit(0)
			return
	var ms: int = Time.get_ticks_msec() - start_ms
	if dbs.size() == 1:
		_report(dbs[0], stats["A"], ms)
	else:
		print("")
		print("##### A: the game%s" % ("" if Stats.all_after(args, "--set").is_empty() else " with the --set overrides"))
		_report(dbs[0], stats["A"], ms)
		print("##### B: A with %s" % ", ".join(b_settings))
		_report(dbs[1], stats["B"], ms)
		_compare(stats, runs, ms)
	var errors: int = int(stats["A"]["errors"]) + int(stats["B"]["errors"])
	var played: int = int(stats["A"]["runs"]) + int(stats["B"]["runs"])
	quit(1 if errors > 0 or played < items else 0)


## B - A on the same seeds (071).
func _compare(stats: Dictionary, runs: int, ms: int) -> void:
	var only_a: int = 0
	var only_b: int = 0
	var both: int = 0
	for seed_key: Variant in stats["pairs"]:
		var pair: Array = stats["pairs"][seed_key]
		if int(pair[0]) == 1 and int(pair[1]) == 1:
			both += 1
		elif int(pair[0]) == 1:
			only_a += 1
		elif int(pair[1]) == 1:
			only_b += 1
	var a: Dictionary = stats["A"]
	var b: Dictionary = stats["B"]
	print("=== B - A on the same %d seeds (%.1fs) ===" % [runs, ms / 1000.0])
	print("  win rate: A %s, B %s" % [Stats.rate(int(a["won"]), int(a["runs"])), Stats.rate(int(b["won"]), int(b["runs"]))])
	print("  B - A: %s" % Stats.verdict(Stats.paired(only_b, only_a, runs)))
	print("    seeds both won %d, only A %d, only B %d, neither %d" % [both, only_a, only_b, runs - both - only_a - only_b])
	print("  fights won per run: A %s, B %s" % [Stats.mean_text(a["fights"], a["fights_sq"], int(a["runs"])),
		Stats.mean_text(b["fights"], b["fights_sq"], int(b["runs"]))])
	print("  fights fought per run: A %s, B %s" % [Stats.mean_text(a["fought"], a["fought_sq"], int(a["runs"])),
		Stats.mean_text(b["fought"], b["fought_sq"], int(b["runs"]))])
	print("  acts bitten or reached: A %s, B %s" % [Stats.rate(int(a["pressed_acts"]), int(a["acts"])),
		Stats.rate(int(b["pressed_acts"]), int(b["acts"]))])
	for act: int in range(1, 4):
		var key: String = str(act)
		if int(a["reached_act"].get(key, 0)) + int(b["reached_act"].get(key, 0)) == 0:
			continue
		print("  lost in act %d: A %s of %d, B %s of %d" % [act,
			Stats.rate(int(a["ended_act"].get(key, 0)), int(a["reached_act"].get(key, 0))), int(a["reached_act"].get(key, 0)),
			Stats.rate(int(b["ended_act"].get(key, 0)), int(b["reached_act"].get(key, 0))), int(b["reached_act"].get(key, 0))])
	print("")


func _new_stats() -> Dictionary:
	return {"runs": 0, "won": 0, "fights": 0, "moves": 0, "boss_hp": 0, "reached_boss": 0, "errors": 0,
		"levels": 0, "tunes": 0, "scrap_left": 0, "last_gate_scrap": 0, "last_gate_runs": 0,
		"last_gate_rares": 0, "reasons": {}, "ended_col": {}, "ended_act": {}, "reached_act": {},
		"gate_lost": {}, "fights_sq": 0, "fought": 0, "fought_sq": 0, "acts": 0, "bitten_acts": 0, "reached_acts": 0,
		"pressed_acts": 0, "bites": 0, "reaches": 0, "conditions": {}}


## Plays one run to its end and counts it into `stats`. Returns a line about it ("+" if won).
func _play(db: ContentDB, seed_value: int, stats: Dictionary) -> String:
	var setup: RunSetup = RunSetup.create(db.parts, db.tiles, db.fights, db.run_rules,
		db.combat_rules, db.effectiveness, seed_value)
	Stats.bot_for(db)
	var state: RunState = RunSim.start(setup)
	var guard: int = 0
	# 084 (B3): per act, whether the Reclaimer bit (a move out of consumed ground) or its drones
	# reached into a fight; fights fought, won or not.
	var bitten: Dictionary = {}
	var reached: Dictionary = {}
	var fought: int = 0
	while state.outcome == RunState.ONGOING and guard < 400:
		var action: Array = RunBot.next_action(state, setup)
		var act_now: int = state.act
		var bites: bool = int(action[0]) == RunSim.TRAVEL and state.consumed(state.current)
		if int(action[0]) == RunSim.FIGHT:
			fought += 1
		var was_boss: bool = String(state.pending.get("site_type", "")) == "boss"
		var hp_before: int = 0
		for member: Dictionary in state.crew:
			hp_before += int(member["hp"])
		if not RunSim.apply(state, setup, action):
			stats["errors"] += 1
			print("  seed %d: illegal bot action %s (pending %s)" % [seed_value, str(action).left(80), state.pending.get("kind", "")])
			break
		if bites:
			bitten[act_now] = true
			stats["bites"] += 1
		if int(action[0]) == RunSim.TRAVEL and (state.pending.get("fight", {}) as Dictionary).has("reclaimer"):
			reached[act_now] = true
			stats["reaches"] += 1
		if int(action[0]) == RunSim.LEVEL_UP:
			stats["levels"] += 1
		elif int(action[0]) == RunSim.TUNE:
			stats["tunes"] += 1
		if was_boss and int(action[0]) == RunSim.FIGHT:
			stats["reached_boss"] += 1
			stats["boss_hp"] += hp_before
			if state.act == RunSim.act_count(setup):
				stats["last_gate_runs"] += 1
				stats["last_gate_scrap"] += state.scrap
				## 032 (play-test 10): how many of the crew's fitted parts are rare or better.
				for member: Dictionary in state.crew:
					for part: Variant in (member["parts"] as Array):
						if not String(part).is_empty() and setup.rarity(PartTuning.base_of(String(part))) >= 3:
							stats["last_gate_rares"] += 1
		guard += 1
	stats["runs"] += 1
	var line: String = ""
	if state.outcome == RunState.WON:
		stats["won"] += 1
		line = "+ won, seed %d" % seed_value
	else:
		_count(stats["reasons"], state.end_reason)
		_count(stats["ended_col"], str(int(state.site(state.current)["col"])))
		_count(stats["ended_act"], str(state.act))
		if String(state.site(state.current)["type"]) == "boss":
			_count(stats["gate_lost"], str(state.act))
		line = "- lost in act %d, seed %d: %s" % [state.act, seed_value, state.end_reason]
	for a: int in range(1, state.act + 1):
		_count(stats["reached_act"], str(a))
	for a: int in range(1, state.act + 1):
		stats["acts"] += 1
		stats["bitten_acts"] += 1 if bitten.has(a) else 0
		stats["reached_acts"] += 1 if reached.has(a) else 0
		stats["pressed_acts"] += 1 if bitten.has(a) or reached.has(a) else 0
		_count(stats["conditions"], RunSim.act_condition(state, setup, a))
	stats["fought"] += fought
	stats["fought_sq"] += fought * fought
	stats["fights"] += state.fights_won
	stats["fights_sq"] += state.fights_won * state.fights_won
	stats["moves"] += state.moves
	stats["scrap_left"] += state.scrap
	return line


func _report(db: ContentDB, s: Dictionary, ms: int) -> void:
	var runs: int = int(s["runs"])
	var n: float = maxf(1.0, runs)
	print("")
	print("=== %d bot runs (%.1fs) ===" % [runs, ms / 1000.0])
	# 071: every rate with its 95% interval -- 62% of 45 runs is "somewhere from 48 to 75".
	var ci: Array = Stats.wilson(int(s["won"]), runs)
	print("  won %d (%.1f%%, 95%%: %.0f-%.0f)   illegal actions %d" % [s["won"], 100.0 * s["won"] / n,
		100.0 * ci[0], 100.0 * ci[1], s["errors"]])
	var p: float = float(s["won"]) / n
	print("    to know it within +-5 points takes about %d runs, within +-10 about %d" % [
		Stats.runs_needed(p, 0.05), Stats.runs_needed(p, 0.10)])
	print("  per run: %.1f moves, %.1f fights won (+-%.1f)" % [s["moves"] / n, s["fights"] / n,
		Stats.mean_ci(s["fights"], s["fights_sq"], runs)[1]])
	print("  per run: %s fights fought; the Reclaimer bit %.2f times and reached into %.2f fights" % [
		Stats.mean_text(s["fought"], s["fought_sq"], runs), s["bites"] / n, s["reaches"] / n])
	print("    acts played %d: bitten in %s, drones reached in %s, either in %s" % [int(s["acts"]),
		Stats.rate(int(s["bitten_acts"]), int(s["acts"])), Stats.rate(int(s["reached_acts"]), int(s["acts"])),
		Stats.rate(int(s["pressed_acts"]), int(s["acts"]))])
	var conds: PackedStringArray = []
	var names: Array = (s["conditions"] as Dictionary).keys()
	names.sort()
	for c: Variant in names:
		conds.append("%s %d" % ["none" if String(c).is_empty() else String(c), int(s["conditions"][c])])
	print("    act conditions: %s" % ", ".join(conds))
	print("  economy per run: %.1f levels bought, %.1f parts tuned, %.1f scrap unspent at the end" % [
		s["levels"] / n, s["tunes"] / n, s["scrap_left"] / n])
	print("  reached the boss: %d, crew HP going in: %.1f avg (total of the three)" % [s["reached_boss"],
		float(s["boss_hp"]) / maxf(1.0, s["reached_boss"])])
	print("  losses by cause:")
	for reason: Variant in s["reasons"]:
		print("    %3d  %s" % [s["reasons"][reason], reason])
	var cols: Array = (s["ended_col"] as Dictionary).keys().map(func(k: Variant) -> int: return int(k))
	cols.sort()
	var where: PackedStringArray = []
	for col: int in cols:
		where.append("col %d: %d" % [col, s["ended_col"][str(col)]])
	print("  losses by column: %s" % ", ".join(where))
	# 025: by act -- how many runs got there, and how many ended there.
	var acts: PackedStringArray = []
	var act_rates: PackedStringArray = []
	for a: int in range(1, RunSim.act_count(RunSetup.create(db.parts, db.tiles, db.fights, db.run_rules,
			db.combat_rules, db.effectiveness, 1000)) + 1):
		var reached: int = int(s["reached_act"].get(str(a), 0))
		var lost: int = int(s["ended_act"].get(str(a), 0))
		acts.append("act %d: reached %d, lost %d, at its gate %d" % [a, reached, lost, int(s["gate_lost"].get(str(a), 0))])
		act_rates.append("act %d %s" % [a, Stats.rate(lost, reached)])
	print("  by act: %s" % ", ".join(acts))
	print("    lost of those who got there: %s" % ", ".join(act_rates))
	print("  scrap held going into the last gate: %.1f avg over %d runs" % [
		float(s["last_gate_scrap"]) / maxf(1.0, s["last_gate_runs"]), s["last_gate_runs"]])
	print("  rare+ parts fitted at the last gate: %.1f avg of 15 over %d runs" % [
		float(s["last_gate_rares"]) / maxf(1.0, s["last_gate_runs"]), s["last_gate_runs"]])
	print("")


func _count(table: Dictionary, key: String) -> void:
	table[key] = int(table.get(key, 0)) + 1


func _arg(args: PackedStringArray, name: String, fallback: String) -> String:
	var at: int = args.find(name)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else fallback


func _arg_int(args: PackedStringArray, name: String, fallback: int) -> int:
	var value: String = _arg(args, name, "")
	return fallback if value.is_empty() else value.to_int()
