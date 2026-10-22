extends SceneTree
## Saves the boss and warlord fights a bot run actually reaches (051): the fight dict the run built
## (its crew with their parts, levels and perks; the gate's escorts and arena) and the combat seed,
## so `play_fight.gd --fight-file F --seed S` plays the real thing by hand.
##   godot --headless --path . --script res://tools/dump_boss_fights.gd -- [--from SEED] [--out res://shots/play] [--per N]
##
## `--per N` (083) keeps N of each (`real_act2_boss_3.json`, from N different runs), for
## `balance_fights.gd --boss DIR`; each file also carries its combat seed as `_combat_seed`.


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var db: ContentDB = ContentDB.load_all()
	var out: String = args[args.find("--out") + 1] if args.has("--out") else "res://shots/play"
	var first: int = args[args.find("--from") + 1].to_int() if args.has("--from") else 0
	var per: int = args[args.find("--per") + 1].to_int() if args.has("--per") else 1
	var found: Dictionary = {}
	for r: int in 40 * per:
		var setup: RunSetup = RunSetup.create(db.parts, db.tiles, db.fights, db.run_rules,
			db.combat_rules, db.effectiveness, 1000 + first + r)
		var state: RunState = RunSim.start(setup)
		var guard: int = 0
		while state.outcome == RunState.ONGOING and guard < 400:
			var kind: String = String(state.pending.get("site_type", ""))
			if String(state.pending.get("kind", "")) == "fight" and (kind == "boss" or kind == "warlord"):
				var key: String = "act%d_%s" % [state.act, kind]
				var have: int = int(found.get(key, 0))
				if have < per and not found.has("%s@%d" % [key, r]):
					var seed_value: int = IntentAI.mix(setup.rng_seed, state.current, 17, 0)
					found[key] = have + 1
					found["%s@%d" % [key, r]] = true
					var name: String = key if per == 1 else "%s_%d" % [key, have + 1]
					var fight: Dictionary = (state.pending["fight"] as Dictionary).duplicate(true)
					fight["_combat_seed"] = seed_value
					var file := FileAccess.open("%s/real_%s.json" % [out, name], FileAccess.WRITE)
					file.store_string(JSON.stringify(fight))
					print("%s: run %d, combat seed %d" % [name, 1000 + first + r, seed_value])
			RunSim.apply(state, setup, RunBot.next_action(state, setup))
			guard += 1
		var full: int = 0
		for k: Variant in found:
			if not String(k).contains("@") and int(found[k]) >= per:
				full += 1
		if full >= 6:
			break
	quit()
