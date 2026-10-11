extends SceneTree

## Where a bot fight's time goes (070): every fight file played once by the bot, timed by phase --
## the crew's planning (`IntentAI` through `CombatBot`), the enemy turn (`ACT_END`: the volley, the
## round's hazards and every enemy planning its next intent) -- and the calls the AI makes most.
##
##   godot --headless --path . --script res://tools/profile_bot.gd -- [--seed 1001] [--fight id]
##
## Measure on a quiet machine, and compare builds with the same tool. 070 started at about 57 ms
## per machine planned and 135 ms per enemy turn (both under load); `sim_fingerprint.gd` says
## whether a faster build still plays the same game.

func _initialize() -> void:
	var db: ContentDB = ContentDB.load_all()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--seed")
	var seed_value: int = args[at + 1].to_int() if at >= 0 else 1001
	at = args.find("--fight")
	var ids: Array = [args[at + 1]] if at >= 0 else db.fights.keys()
	ids.sort()
	var plan_us: int = 0
	var plans: int = 0
	var end_us: int = 0
	var ends: int = 0
	print("%-18s %6s %10s %12s" % ["fight", "rounds", "ms/plan", "ms/enemy turn"])
	for id: Variant in ids:
		var setup: CombatSetup = CombatSetup.build(db.fights[id], db.combat_rules, db.parts, db.tiles, db.effectiveness, seed_value)
		if not setup.errors.is_empty():
			continue
		var state: CombatState = CombatSim.start(setup)
		var fp: int = 0
		var fn: int = 0
		var fe: int = 0
		var fen: int = 0
		var guard: int = 0
		while state.outcome == CombatState.ONGOING and guard < 60:
			guard += 1
			for u: GridUnit in state.units:
				if state.outcome != CombatState.ONGOING:
					break
				if not u.alive or u.objective or u.team != GridUnit.TEAM_PLAYER:
					continue
				var a: int = Time.get_ticks_usec()
				CombatBot.plan_unit(state, u.ref, true)
				fp += Time.get_ticks_usec() - a
				fn += 1
			if state.outcome == CombatState.ONGOING:
				var a: int = Time.get_ticks_usec()
				CombatSim.apply(state, [CombatSim.ACT_END, -1, 0, 0])
				fe += Time.get_ticks_usec() - a
				fen += 1
		print("%-18s %6d %10.1f %12.1f" % [id, state.round_number, fp / 1000.0 / maxi(1, fn), fe / 1000.0 / maxi(1, fen)])
		plan_us += fp
		plans += fn
		end_us += fe
		ends += fen
	print("%-18s %6s %10.1f %12.1f" % ["ALL", "", plan_us / 1000.0 / maxi(1, plans), end_us / 1000.0 / maxi(1, ends)])
	print("")
	_bench(db)
	quit()


## The AI's most frequent calls, one board, microseconds each.
func _bench(db: ContentDB) -> void:
	var setup: CombatSetup = CombatSetup.build(db.fights["slag_pit"], db.combat_rules, db.parts, db.tiles, db.effectiveness, 1001)
	var state: CombatState = CombatSim.start(setup)
	var u: GridUnit = state.units[0]
	var foe: GridUnit = state.living(GridUnit.TEAM_ENEMY)[0]
	var here := Vector2i(u.x, u.y)
	var there := Vector2i(foe.x, foe.y)
	print("calls on slag_pit, us each:")
	_time("Hex.neighbors", func() -> void: Hex.neighbors(here), 20000)
	_time("Hex.distance", func() -> void: Hex.distance(here, there), 20000)
	_time("Hex.line", func() -> void: Hex.line(here, there), 20000)
	_time("state.unit_at", func() -> void: state.unit_at(0, 0), 20000)
	_time("damage_to", func() -> void: CombatSim.damage_to(state, u, foe, 5, true), 20000)
	_time("strike_plan", func() -> void: CombatSim.strike_plan(state, u, 0, there), 5000)
	_time("paths_from", func() -> void: CombatSim.paths_from(state, u, u.move), 500)
	_time("state.clone", func() -> void: state.clone(), 1000)


func _time(label: String, f: Callable, times: int) -> void:
	var a: int = Time.get_ticks_usec()
	for i: int in times:
		f.call()
	print("  %-16s %8.2f" % [label, float(Time.get_ticks_usec() - a) / times])
