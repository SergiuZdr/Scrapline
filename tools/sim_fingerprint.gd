extends SceneTree

## One hash for how the sim plays (070): every fight file played by the bot on a few seeds, and a
## few whole bot runs. A change meant only to make the sim FASTER must leave it unchanged.
##
##   godot --headless --path . --script res://tools/sim_fingerprint.gd -- [--seeds 3] [--runs 4] [--jobs N]
##
## Prints one line per fight and run, then the total. `tools/check.sh --fingerprint` keeps the last
## one and says which fight or run changed; or compare two outputs with `diff`.

const Jobs = preload("res://tools/jobs.gd")


func _initialize() -> void:
	var db: ContentDB = ContentDB.load_all()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seeds: int = _arg(args, "--seeds", 3)
	var runs: int = _arg(args, "--runs", 4)
	var slice: Array = Jobs.slice(args)
	var start_ms: int = Time.get_ticks_msec()
	var ids: Array = db.fights.keys()
	ids.sort()
	var items: int = ids.size() * seeds + runs
	var lines: Dictionary = {}
	if slice.is_empty() and _arg(args, "--jobs", Jobs.default_count()) > 1:
		for part: Dictionary in Jobs.run("res://tools/sim_fingerprint.gd", args, mini(items, _arg(args, "--jobs", Jobs.default_count())), items):
			lines.merge(part["lines"])
	else:
		for item: int in items:
			if not Jobs.mine(slice, item):
				continue
			lines[str(item)] = _fight_line(db, String(ids[item / seeds]), item % seeds) if item < ids.size() * seeds \
				else _run_line(db, item - ids.size() * seeds)
			Jobs.progress(slice, "+")
		if not slice.is_empty():
			Jobs.finish(slice, {"lines": lines})
			quit()
			return
	var total: PackedStringArray = []
	for item: int in items:
		total.append(String(lines.get(str(item), "item %d MISSING" % item)))
		print(total[-1])
	print("TOTAL %08x  (%d lines, %.1fs)" % [hash("\n".join(total)) & 0xFFFFFFFF, total.size(),
		(Time.get_ticks_msec() - start_ms) / 1000.0])
	quit()


func _fight_line(db: ContentDB, id: String, s: int) -> String:
	var setup: CombatSetup = CombatSetup.build(db.fights[id], db.combat_rules, db.parts, db.tiles,
		db.effectiveness, 1000 + s)
	if not setup.errors.is_empty():
		return "fight %s/%d setup errors" % [id, s]
	var state: CombatState = CombatSim.start(setup)
	var guard: int = 0
	while state.outcome == CombatState.ONGOING and guard < 60:
		CombatBot.take_turn(state)
		guard += 1
	return "fight %s/%d %s r%d %s" % [id, s, state.outcome, state.round_number, state.event_hash()]


func _run_line(db: ContentDB, r: int) -> String:
	var setup: RunSetup = RunSetup.create(db.parts, db.tiles, db.fights, db.run_rules, db.combat_rules,
		db.effectiveness, 1000 + r)
	var state: RunState = RunSim.start(setup)
	var actions: Array = []
	var guard: int = 0
	while state.outcome == RunState.ONGOING and guard < 400:
		var action: Array = RunBot.next_action(state, setup)
		if not RunSim.apply(state, setup, action):
			break
		actions.append(action)
		guard += 1
	return "run %d %s act %d moves %d fights %d scrap %d actions %08x" % [r, state.outcome,
		state.act, state.moves, state.fights_won, state.scrap, hash(var_to_str(actions)) & 0xFFFFFFFF]


func _arg(args: PackedStringArray, name: String, fallback: int) -> int:
	var at: int = args.find(name)
	return args[at + 1].to_int() if at >= 0 and at + 1 < args.size() else fallback
