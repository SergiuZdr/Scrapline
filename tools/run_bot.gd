extends SceneTree

## Plays whole runs with the bot and reports how they go.
##
##   godot --headless --path . --script res://tools/run_bot.gd -- [--runs 100] [--set path=json ...]
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
			db.combat_rules, db.balance.effectiveness, 1000 + r)
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
			guard += 1
		if state.outcome == RunState.WON:
			won += 1
		else:
			reasons[state.end_reason] = int(reasons.get(state.end_reason, 0)) + 1
			var col: int = int(state.site(state.current)["col"])
			ended_col[col] = int(ended_col.get(col, 0)) + 1
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
	print("")
	quit(1 if errors > 0 else 0)
