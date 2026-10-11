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
## without editing the data: `--set enemies.count_by_column=[3,3,3,3,4,4,5,5,5]`. Several
## variants can then run side by side.
##
## The test that plays the real game. Reports the win rate, where and why runs end, how
## many fights a run takes, and the crew's HP at the boss -- the numbers that say
## whether a run is too long, too short, too easy or a wall.

const Jobs = preload("res://tools/jobs.gd")


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var runs: int = _arg_int(args, "--runs", 100)
	var first_seed: int = _arg_int(args, "--from", 0)
	var slice: Array = Jobs.slice(args)
	var jobs: int = clampi(_arg_int(args, "--jobs", Jobs.default_count()), 1, maxi(1, runs))
	var db: ContentDB = ContentDB.load_all()
	for i: int in args.size() - 1:
		if args[i] == "--set":
			_override(db, args[i + 1])
	var start_ms: int = Time.get_ticks_msec()
	var stats: Dictionary = _new_stats()
	if slice.is_empty() and jobs > 1:
		for part: Dictionary in Jobs.run("res://tools/run_bot.gd", args, jobs, runs, "won"):
			Jobs.merge(stats, part)
		_report(db, stats, int(stats["runs"]), Time.get_ticks_msec() - start_ms)
		quit(1 if int(stats["errors"]) > 0 or int(stats["runs"]) < runs else 0)
		return
	for r: int in runs:
		if not Jobs.mine(slice, r):
			continue
		var line: String = _play(db, 1000 + first_seed + r, stats)
		if slice.is_empty():
			print("  run %d/%d  %s  (%.0fs)" % [r + 1, runs, line, (Time.get_ticks_msec() - start_ms) / 1000.0])
		Jobs.progress(slice, line)
	if not slice.is_empty():
		Jobs.finish(slice, stats)
		quit(0)
		return
	_report(db, stats, runs, Time.get_ticks_msec() - start_ms)
	quit(1 if int(stats["errors"]) > 0 else 0)


func _new_stats() -> Dictionary:
	return {"runs": 0, "won": 0, "fights": 0, "moves": 0, "boss_hp": 0, "reached_boss": 0, "errors": 0,
		"levels": 0, "tunes": 0, "scrap_left": 0, "last_gate_scrap": 0, "last_gate_runs": 0,
		"last_gate_rares": 0, "reasons": {}, "ended_col": {}, "ended_act": {}, "reached_act": {},
		"gate_lost": {}}


## Plays one run to its end and counts it into `stats`. Returns a line about it ("+" if won).
func _play(db: ContentDB, seed_value: int, stats: Dictionary) -> String:
	var setup: RunSetup = RunSetup.create(db.parts, db.tiles, db.fights, db.run_rules,
		db.combat_rules, db.effectiveness, seed_value)
	var state: RunState = RunSim.start(setup)
	var guard: int = 0
	while state.outcome == RunState.ONGOING and guard < 400:
		var action: Array = RunBot.next_action(state, setup)
		var was_boss: bool = String(state.pending.get("site_type", "")) == "boss"
		var hp_before: int = 0
		for member: Dictionary in state.crew:
			hp_before += int(member["hp"])
		if not RunSim.apply(state, setup, action):
			stats["errors"] += 1
			print("  seed %d: illegal bot action %s (pending %s)" % [seed_value, str(action).left(80), state.pending.get("kind", "")])
			break
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
	stats["fights"] += state.fights_won
	stats["moves"] += state.moves
	stats["scrap_left"] += state.scrap
	return line


func _report(db: ContentDB, s: Dictionary, runs: int, ms: int) -> void:
	var n: float = maxf(1.0, runs)
	print("")
	print("=== %d bot runs (%.1fs) ===" % [runs, ms / 1000.0])
	print("  won %d (%.1f%%)   illegal actions %d" % [s["won"], 100.0 * s["won"] / n, s["errors"]])
	print("  per run: %.1f moves, %.1f fights won" % [s["moves"] / n, s["fights"] / n])
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
	for a: int in range(1, RunSim.act_count(RunSetup.create(db.parts, db.tiles, db.fights, db.run_rules,
			db.combat_rules, db.effectiveness, 1000)) + 1):
		acts.append("act %d: reached %d, lost %d, at its gate %d" % [a, int(s["reached_act"].get(str(a), 0)),
			int(s["ended_act"].get(str(a), 0)), int(s["gate_lost"].get(str(a), 0))])
	print("  by act: %s" % ", ".join(acts))
	print("  scrap held going into the last gate: %.1f avg over %d runs" % [
		float(s["last_gate_scrap"]) / maxf(1.0, s["last_gate_runs"]), s["last_gate_runs"]])
	print("  rare+ parts fitted at the last gate: %.1f avg of 15 over %d runs" % [
		float(s["last_gate_rares"]) / maxf(1.0, s["last_gate_runs"]), s["last_gate_runs"]])
	print("")



func _count(table: Dictionary, key: String) -> void:
	table[key] = int(table.get(key, 0)) + 1


## `path=json` into run.json; `combat.path=json` into the combat rules (enemy kinds included);
## `fight.<id>.path=json` into one fight map (014: the gate's variants).
func _override(db: ContentDB, setting: String) -> void:
	var pair: PackedStringArray = setting.split("=", true, 1)
	var keys: PackedStringArray = pair[0].split(".")
	var node: Dictionary = db.run_rules
	var first: int = 0
	if keys[0] == "combat":
		node = db.combat_rules
		first = 1
	elif keys[0] == "fight":
		node = db.fights[keys[1]]
		first = 2
	for k: int in range(first, keys.size() - 1):
		node = node[keys[k]]
	node[keys[keys.size() - 1]] = JSON.parse_string(pair[1])
	print("  override %s = %s" % [pair[0], pair[1]])



func _arg(args: PackedStringArray, name: String, fallback: String) -> String:
	var at: int = args.find(name)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else fallback


func _arg_int(args: PackedStringArray, name: String, fallback: int) -> int:
	var value: String = _arg(args, name, "")
	return fallback if value.is_empty() else value.to_int()
