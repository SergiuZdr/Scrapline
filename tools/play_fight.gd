extends SceneTree
## Plays a fight by hand, as text (051, the agent playing the bosses): replays an action log and
## prints the board, the machines, what the enemy will do, the keepers' tricks and what the last
## turn did -- so a fight can be played one turn at a time by appending actions to the log.
##   godot --headless --path . --script res://tools/play_fight.gd -- --fight-file res://f.json \
##       [--seed N] [--log res://log.json] [--arena]
## `--arena`: the fight as a run builds a gate's (padded by run.json `board`, `arena_terrain`).
## The log is a JSON array of actions `[kind, ref, a, b(, c)]` (CombatSim.ACT_*).

const LETTERS: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var db: ContentDB = ContentDB.load_all()
	var fight: Dictionary = {}
	if args.has("--fight-file"):
		fight = JSON.parse_string(FileAccess.get_file_as_string(args[args.find("--fight-file") + 1]))
	else:
		fight = (db.fights[args[args.find("--fight") + 1]] as Dictionary).duplicate(true)
	if args.has("--escorts"):
		# As a run fields it (`RunSim._make_gate_fight`): the keepers, then this many escorts.
		var keep: int = maxi(1, int(fight.get("keepers", 1))) + args[args.find("--escorts") + 1].to_int()
		fight["enemy"] = (fight["enemy"] as Array).slice(0, keep)
	if args.has("--arena"):
		fight = RunSim.widen(fight, db.run_rules.get("board", {}))
		fight["rows"] = RunSim._scatter_terrain(db.run_rules.get("arena_terrain", {}), SimRNG.new(11), fight)
		if args.has("--save-fight"):
			var out := FileAccess.open(args[args.find("--save-fight") + 1], FileAccess.WRITE)
			out.store_string(JSON.stringify(fight))
	var seed_value: int = args[args.find("--seed") + 1].to_int() if args.has("--seed") else 2026
	var setup: CombatSetup = CombatSetup.build(fight, db.combat_rules, db.parts, db.tiles, db.effectiveness, seed_value)
	var actions: Array = []
	if args.has("--log"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[args.find("--log") + 1]))
		if parsed is Array:
			for a: Variant in parsed:
				var ints: Array = []
				for v: Variant in (a as Array):
					ints.append(int(v))
				actions.append(ints)
	var state: CombatState = CombatSim.start(setup)
	var last_end: int = 0
	for i: int in actions.size():
		var before: int = state.events.size()
		if not CombatSim.apply(state, actions[i]):
			print("ILLEGAL action %d: %s" % [i, str(actions[i])])
		if int(actions[i][0]) == CombatSim.ACT_END:
			last_end = before
	# `--bot N`: the crew is played by `CombatBot` for N more turns (the agent watching a keeper).
	if args.has("--bot"):
		for i: int in args[args.find("--bot") + 1].to_int():
			if state.outcome != CombatState.ONGOING:
				break
			last_end = state.events.size()
			CombatBot.take_turn(state)
		var tricks: Array[int] = [GridEv.EXPOSED, GridEv.CHARGED, GridEv.GRABBED, GridEv.PROP_MOVED, GridEv.QUENCHED,
			GridEv.REBUILD_MARKED, GridEv.REBUILT, GridEv.ENRAGED, GridEv.DESTROYED, GridEv.FIGHT_END]
		print("-- trick events over the whole fight")
		var round: int = 0
		for e: Array in state.events:
			if int(e[0]) == GridEv.ROUND_START:
				round = int(e[5])
			if tricks.has(int(e[0])):
				print("  r%d %s %s" % [round, GridEv.NAMES[int(e[0])], e.slice(1)])
	_print_events(state, last_end)
	_print_board(state)
	_print_units(state)
	_print_threats(state)
	_print_tricks(state)
	_print_options(state)
	quit()


func _tag(state: CombatState, u: GridUnit) -> String:
	if u.team == GridUnit.TEAM_PLAYER:
		return LETTERS[u.slot]
	return "%d" % (u.ref % 10)


func _print_board(state: CombatState) -> void:
	print("\n== ROUND %d  outcome %d  (cols 0..%d)" % [state.round_number, state.outcome, state.width - 1])
	var header: String = "     "
	for x: int in state.width:
		header += "%-2d" % (x % 10)
	print(header)
	for y: int in state.height:
		var line: String = "%2d  %s" % [y, " " if y % 2 == 1 else ""]
		for x: int in state.width:
			var c := Vector2i(x, y)
			var u: GridUnit = state.unit_at(x, y)
			var ch: String = "."
			if u != null:
				ch = _tag(state, u)
			elif state.props.has(c):
				ch = String((state.props[c] as Dictionary)["kind"]).substr(0, 1).to_upper()
				if ch == "B":
					ch = "D"   # drum
				if ch == "C" and String((state.props[c] as Dictionary)["kind"]) == "coolant":
					ch = "K"
			elif state.is_pit(c):
				ch = "o"
			elif state.tile_blocks(x, y):
				ch = "#"
			elif state.flooded.has(c):
				ch = "~"
			elif state.ground_hazard(x, y) > 0:
				ch = "l"
			elif state.cover(x, y) > 0:
				ch = "r"
			elif state.flue(x, y) > 0:
				ch = "f"
			elif state.piles.has(c):
				ch = "$"
			line += ch + " "
		print(line)


func _print_units(state: CombatState) -> void:
	print("\n-- units")
	for u: GridUnit in state.units:
		if not u.alive:
			continue
		var weapons: PackedStringArray = []
		for w: int in u.weapons.size():
			var wp: Dictionary = u.weapons[w]
			weapons.append("%d:%s%s(dmg %d, %s)" % [w, String(wp.get("name", "?")), " TORN" if not u.can_fire(w) else "",
				int(wp.get("damage", 0)), String(wp.get("shape", wp.get("class", "")))])
		var extra: String = ""
		if u.team == GridUnit.TEAM_PLAYER:
			extra = " heat %d/%d moved %s acted %s" % [u.heat, u.heat_cap, u.moved, u.acted]
			for i: int in u.abilities.size():
				extra += " | ab%d %s wait %d" % [i, String(u.abilities[i].get("name", "?")), int(u.abilities[i]["wait"])]
		if u.team == GridUnit.TEAM_PLAYER and not u.moved:
			var cells: Array = CombatSim.reachable(state, u.ref).keys()
			cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
			extra += "\n     reach: " + " ".join(cells.map(func(c: Vector2i) -> String: return "%d,%d" % [c.x, c.y]))
		print("%s ref %d %-14s %s hp %d/%d at %s move %d%s  %s" % [_tag(state, u), u.ref, u.name if u.kind.is_empty() else u.kind,
			"" if not state.exposed.has(u.ref) else "EXPOSED%d" % int(state.exposed[u.ref]), u.hp, u.max_hp,
			Vector2i(u.x, u.y), u.move, extra, ", ".join(weapons)])


func _print_threats(state: CombatState) -> void:
	print("\n-- enemy fire next (intents) and what END TURN does")
	var t: Dictionary = CombatSim.threats(state)
	for ref: Variant in t:
		var plan: Dictionary = t[ref]
		var hits: PackedStringArray = []
		for h: Dictionary in (plan["hits"] as Array):
			hits.append("%s-%d" % [_tag(state, state.unit(int(h["ref"]))), int(h["damage"])])
		print("  %s w%d -> %s legal %s hits %s" % [_tag(state, state.unit(int(ref))), int(plan["w"]), str(plan.get("end", plan.get("aim"))), plan["legal"], hits])
	var inc: Dictionary = CombatSim.incoming(state)
	for e: Dictionary in (inc["units"] as Array):
		print("  incoming: %s loses %d%s" % [_tag(state, state.unit(int(e["ref"]))), int(e["hp_lost"]), " KILLED" if bool(e["killed"]) else ""])


func _print_tricks(state: CombatState) -> void:
	print("\n-- tricks: exposed %s charges %s grabs %s facing %s rebuilds %s pour_marks %s pulse %s spawn_marks %s" % [
		state.exposed, state.charges, state.grabs, state.facing, state.rebuilds, state.pour_marks, state.pulse_marks.size(), state.spawn_marks])


func _print_options(state: CombatState) -> void:
	print("\n-- your options (best preview per weapon against enemies/props in reach now)")
	for u: GridUnit in state.crew(GridUnit.TEAM_PLAYER):
		if u.acted:
			continue
		for w: int in u.weapons.size():
			if not u.can_fire(w):
				continue
			var best: Array = []
			for aim: Vector2i in CombatSim.aim_options(state, u, w):
				if not CombatSim.can_attack(state, u.ref, w, aim):
					continue
				var p: Dictionary = CombatSim.preview_attack(state, u.ref, w, aim)
				var total: int = 0
				var desc: PackedStringArray = []
				for h: Dictionary in (p.get("hits", []) as Array):
					var t: GridUnit = state.unit(int(h["ref"]))
					var sign: int = 1 if t.team != u.team else -2
					total += sign * int(h["damage"])
					desc.append("%s%+d" % [_tag(state, t), -int(h["damage"])])
				for pr: Dictionary in (p.get("props", []) as Array):
					desc.append("prop%s" % str(pr.get("cell", "")))
					total += 1
				if not desc.is_empty():
					best.append([total, aim, desc])
			best.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
			for i: int in mini(3, best.size()):
				print("  %s w%d at %s: %s" % [_tag(state, u), w, str(best[i][1]), " ".join(best[i][2])])


func _print_events(state: CombatState, since: int) -> void:
	print("-- last turn's events")
	var skip: Array[int] = [GridEv.STEP, GridEv.HEAT, GridEv.INTENT_SET]
	for i: int in range(since, state.events.size()):
		var e: Array = state.events[i]
		if skip.has(int(e[0])):
			continue
		print("  ", GridEv.NAMES[int(e[0])], " ", e.slice(1))
