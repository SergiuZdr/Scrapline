extends SceneTree
## Saves the boss and warlord fights a bot run actually reaches (051): the fight dict the run built
## (its crew with their parts, levels and perks; the gate's escorts and arena) and the combat seed,
## so `play_fight.gd --fight-file F --seed S` plays the real thing by hand.
##   godot --headless --path . --script res://tools/dump_boss_fights.gd -- [--from SEED] [--out res://shots/play]


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var db: ContentDB = ContentDB.load_all()
	var out: String = args[args.find("--out") + 1] if args.has("--out") else "res://shots/play"
	var first: int = args[args.find("--from") + 1].to_int() if args.has("--from") else 0
	var found: Dictionary = {}
	for r: int in 40:
		var setup: RunSetup = RunSetup.create(db.parts, db.tiles, db.fights, db.run_rules,
			db.combat_rules, db.effectiveness, 1000 + first + r)
		var state: RunState = RunSim.start(setup)
		var guard: int = 0
		while state.outcome == RunState.ONGOING and guard < 400:
			var kind: String = String(state.pending.get("site_type", ""))
			if String(state.pending.get("kind", "")) == "fight" and (kind == "boss" or kind == "warlord"):
				var key: String = "act%d_%s" % [state.act, kind]
				if not found.has(key):
					var seed_value: int = IntentAI.mix(setup.rng_seed, state.current, 17, 0)
					found[key] = seed_value
					var file := FileAccess.open("%s/real_%s.json" % [out, key], FileAccess.WRITE)
					file.store_string(JSON.stringify(state.pending["fight"]))
					print("%s: run %d, combat seed %d" % [key, 1000 + first + r, seed_value])
			RunSim.apply(state, setup, RunBot.next_action(state, setup))
			guard += 1
		if found.size() >= 6:
			break
	quit()
