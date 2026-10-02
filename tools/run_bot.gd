extends SceneTree

## Plays whole runs with the bot and reports how they go.
##
##   godot --headless --path . --script res://tools/run_bot.gd -- [--runs 100] [--set path=json ...]
##
## `--from N` starts at seed 1000 + N: `--runs 38 --from 0`, `--from 38`, ... split 150 runs over
## several processes (a batch of three-act runs takes over half an hour in one).
##
## `--set` overrides one run.json number for this run of the bot only, to try a balance dial
## without editing the data: `--set enemies.count_by_column=[3,3,3,3,4,4,5,5,5]`. Several
## variants can then run side by side.
##
## The test that plays the real game. Reports the win rate, where and why runs end, how
## many fights a run takes, and the Crawler's HP at the boss -- the numbers that say
## whether a run is too long, too short, too easy or a wall.

func _initialize() -> void:
	var db: ContentDB = ContentDB.load_all()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var runs: int = 100
	var at: int = args.find("--runs")
	if at >= 0 and at + 1 < args.size():
		runs = args[at + 1].to_int()
	# `--from N`: start at seed 1000 + N, so one batch can be split across processes.
	var first_seed: int = 0
	at = args.find("--from")
	if at >= 0 and at + 1 < args.size():
		first_seed = args[at + 1].to_int()
	for i: int in args.size() - 1:
		if args[i] == "--set":
			# `path=json` into run.json; `combat.path=json` into the combat rules (enemy kinds
			# included); `fight.<id>.path=json` into one fight map (014: the gate's variants).
			var pair: PackedStringArray = args[i + 1].split("=", true, 1)
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

	var won: int = 0
	var reasons: Dictionary = {}
	var ended_col: Dictionary = {}
	var ended_act: Dictionary = {}
	var reached_act: Dictionary = {}
	var gate_lost: Dictionary = {}
	var last_gate_scrap: int = 0
	var last_gate_runs: int = 0
	## 032 (play-test 10): how many of the crew's fitted parts are rare or better at the last gate.
	var last_gate_rares: int = 0
	var fights: int = 0
	var moves: int = 0
	var boss_hp: int = 0
	var reached_boss: int = 0
	var errors: int = 0
	var levels: int = 0
	var tunes: int = 0
	var scrap_left: int = 0
	var start_ms: int = Time.get_ticks_msec()
	for r: int in runs:
		var setup: RunSetup = RunSetup.create(db.parts, db.tiles, db.fights, db.run_rules,
			db.combat_rules, db.balance.effectiveness, 1000 + first_seed + r)
		var state: RunState = RunSim.start(setup)
		var guard: int = 0
		while state.outcome == RunState.ONGOING and guard < 400:
			var action: Array = RunBot.next_action(state, setup)
			var was_boss: bool = String(state.pending.get("site_type", "")) == "boss"
			var hp_before: int = 0
			for member: Dictionary in state.crew:
				hp_before += int(member["hp"])
			if not RunSim.apply(state, setup, action):
				errors += 1
				print("  run %d: illegal bot action %s (pending %s)" % [r, str(action).left(80), state.pending.get("kind", "")])
				break
			if int(action[0]) == RunSim.LEVEL_UP:
				levels += 1
			elif int(action[0]) == RunSim.TUNE:
				tunes += 1
			if was_boss and int(action[0]) == RunSim.FIGHT:
				reached_boss += 1
				boss_hp += hp_before
				if state.act == RunSim.act_count(setup):
					last_gate_runs += 1
					last_gate_scrap += state.scrap
					for member: Dictionary in state.crew:
						for part: Variant in (member["parts"] as Array):
							if not String(part).is_empty() and setup.rarity(PartTuning.base_of(String(part))) >= 3:
								last_gate_rares += 1
			guard += 1
		if state.outcome == RunState.WON:
			won += 1
		else:
			reasons[state.end_reason] = int(reasons.get(state.end_reason, 0)) + 1
			var col: int = int(state.site(state.current)["col"])
			ended_col[col] = int(ended_col.get(col, 0)) + 1
			ended_act[state.act] = int(ended_act.get(state.act, 0)) + 1
			if String(state.site(state.current)["type"]) == "boss":
				gate_lost[state.act] = int(gate_lost.get(state.act, 0)) + 1
		for a: int in range(1, state.act + 1):
			reached_act[a] = int(reached_act.get(a, 0)) + 1
		fights += state.fights_won
		moves += state.moves
		scrap_left += state.scrap

	print("")
	print("=== %d bot runs (%.1fs) ===" % [runs, (Time.get_ticks_msec() - start_ms) / 1000.0])
	print("  won %d (%.1f%%)   illegal actions %d" % [won, 100.0 * won / maxf(1.0, runs), errors])
	print("  per run: %.1f moves, %.1f fights won" % [float(moves) / runs, float(fights) / runs])
	print("  economy per run: %.1f levels bought, %.1f parts tuned, %.1f scrap unspent at the end" % [
		float(levels) / runs, float(tunes) / runs, float(scrap_left) / runs])
	print("  reached the boss: %d, crew HP going in: %.1f avg (total of the three)" % [reached_boss, float(boss_hp) / maxf(1.0, reached_boss)])
	print("  losses by cause:")
	for reason: Variant in reasons:
		print("    %3d  %s" % [reasons[reason], reason])
	var cols: Array = ended_col.keys()
	cols.sort()
	var where: PackedStringArray = []
	for col: Variant in cols:
		where.append("col %d: %d" % [col, ended_col[col]])
	print("  losses by column: %s" % ", ".join(where))
	# 025: by act -- how many runs got there, and how many ended there.
	var acts: PackedStringArray = []
	for a: int in range(1, RunSim.act_count(RunSetup.create(db.parts, db.tiles, db.fights, db.run_rules,
			db.combat_rules, db.balance.effectiveness, 1000)) + 1):
		acts.append("act %d: reached %d, lost %d, at its gate %d" % [a, int(reached_act.get(a, 0)), int(ended_act.get(a, 0)), int(gate_lost.get(a, 0))])
	print("  by act: %s" % ", ".join(acts))
	print("  scrap held going into the last gate: %.1f avg over %d runs" % [float(last_gate_scrap) / maxf(1.0, last_gate_runs), last_gate_runs])
	print("  rare+ parts fitted at the last gate: %.1f avg of 15 over %d runs" % [float(last_gate_rares) / maxf(1.0, last_gate_runs), last_gate_runs])
	print("")
	quit(1 if errors > 0 else 0)
