extends SceneTree

## Which maps a bot run's fights are played on (088, A6). One JSON line per run:
##   {"seed", "act" (reached), "won", "fights": [[act, site type, map name, won 0/1, rounds], ...]}
##
##   godot --headless --path . --script res://tools/map_census.gd -- --runs 40 --from 0
##
## Run several at once with different `--from` and add the lines up with any script: a map
## "repeats" in an act when that act's ordinary fights (skirmish, elite, arena) meet it twice.
## `--summary` prints the act-3 repeat count and each map's act-3 record at the end.


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var runs: int = _arg_int(args, "--runs", 20)
	var first: int = _arg_int(args, "--from", 0)
	var db: ContentDB = ContentDB.load_all()
	var reached3: int = 0
	var repeated3: int = 0
	var fights3: int = 0
	var seen_again3: int = 0
	var per_map: Dictionary = {}
	for i: int in runs:
		var seed_value: int = 1000 + first + i
		var setup: RunSetup = RunSetup.create(db.parts, db.tiles, db.fights, db.run_rules,
			db.combat_rules, db.effectiveness, seed_value)
		var state: RunState = RunSim.start(setup)
		var fights: Array = []
		var guard: int = 0
		while state.outcome == RunState.ONGOING and guard < 400:
			var action: Array = RunBot.next_action(state, setup)
			if int(action[0]) == RunSim.FIGHT:
				var fight: Dictionary = state.pending.get("fight", {})
				var played: CombatState = CombatSim.replay(RunSim.fight_setup(state, setup), action[1])
				fights.append([state.act, String(state.pending.get("site_type", "")), String(fight.get("name", "")),
					1 if played.outcome == CombatState.WON else 0, played.round_number])
			if not RunSim.apply(state, setup, action):
				break
			guard += 1
		print(JSON.stringify({"seed": seed_value, "act": state.act, "won": state.outcome == RunState.WON, "fights": fights}))
		if state.act >= 3:
			reached3 += 1
			var seen: Dictionary = {}
			var rep: bool = false
			for f: Array in fights:
				if int(f[0]) != 3 or not ["skirmish", "elite", "arena"].has(String(f[1])):
					continue
				fights3 += 1
				var rec: Array = per_map.get(String(f[2]), [0, 0, 0])
				rec[0] += int(f[3])
				rec[1] += 1
				rec[2] += int(f[4])
				per_map[String(f[2])] = rec
				if seen.has(f[2]):
					rep = true
					seen_again3 += 1
				seen[f[2]] = true
			repeated3 += 1 if rep else 0
	if args.has("--summary"):
		print("act 3: runs reaching it %d, with a repeated map %d; ordinary fights %d, on a map already met that act %d" % [
			reached3, repeated3, fights3, seen_again3])
		var names: Array = per_map.keys()
		names.sort()
		for n: Variant in names:
			var r: Array = per_map[n]
			print("  %-24s won %d of %d, %.1f rounds" % [n, r[0], r[1], float(r[2]) / maxi(1, int(r[1]))])
	quit()


func _arg_int(args: PackedStringArray, name: String, fallback: int) -> int:
	var at: int = args.find(name)
	return args[at + 1].to_int() if at >= 0 and at + 1 < args.size() else fallback
