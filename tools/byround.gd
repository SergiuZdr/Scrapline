extends SceneTree

## How a fight's rounds feel, by round number (087): the bot plays whole runs (as `run_bot.gd`) and
## every fight they meet is played again with the crew's choices measured at the start of each of
## its turns, for every machine:
##
##   godot --headless --path . --script res://tools/byround.gd -- [--runs 40] [--from 0] [--jobs N]
##       [--set path=json ...] [--b path=json ...]
##
## Per round (1..7, 8+, and 4+ together):
##   targets  -- distinct enemies the machine could hit this turn (from any hex it can reach, any arm it
##               can fire, `strike_plan` hits that hurt them); 0 for a machine that cannot attack.
##   forced   -- turns with at most one enemy to hit from a SAFE hex (one obvious answer, or none).
##   safe     -- reachable hexes (its own included) where the enemy's volley and the next round's start
##               would cost it no HP: the real rules on a copy (`_fire_intents`, `_round_hazards`), so a
##               tracker's lock and a flood count. `cool` also leaves out hexes whose path is hot ground.
##   no safe  -- turns with no safe hex at all.
##   land     -- enemy intents whose shot hurt the crew (a machine or a cache), of those set.
## Per fight: rounds, win rate, by act and kind; waves, blocks, hot ground.
## `--set` / `--b` as `run_bot.gd` (`tools/stats.gd`): `--b` plays variant B on the same seeds.

const Jobs = preload("res://tools/jobs.gd")
const Stats = preload("res://tools/stats.gd")
const BUCKETS: int = 8


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var runs: int = _arg_int(args, "--runs", 40)
	var first: int = _arg_int(args, "--from", 0)
	var slice: Array = Jobs.slice(args)
	var quiet: bool = not slice.is_empty()
	var dbs: Array[ContentDB] = [ContentDB.load_all()]
	for setting: String in Stats.all_after(args, "--set"):
		Stats.override(dbs[0], setting, quiet)
	var b_settings: PackedStringArray = Stats.all_after(args, "--b")
	if not b_settings.is_empty():
		dbs.append(ContentDB.load_all())
		for setting: String in Stats.all_after(args, "--set"):
			Stats.override(dbs[1], setting, true)
		for setting: String in b_settings:
			Stats.override(dbs[1], setting, quiet)
	var items: int = runs * dbs.size()
	var jobs: int = clampi(_arg_int(args, "--jobs", Jobs.default_count()), 1, maxi(1, items))
	var start_ms: int = Time.get_ticks_msec()
	var numbers: Dictionary = {"A": _new(), "B": _new()}
	if slice.is_empty() and jobs > 1:
		for part: Dictionary in Jobs.run("res://tools/byround.gd", args, jobs, items, "won"):
			_merge(numbers, part)
	else:
		for item: int in items:
			if not Jobs.mine(slice, item):
				continue
			var v: int = item % dbs.size()
			var line: String = _run(dbs[v], 1000 + first + item / dbs.size(), numbers["A" if v == 0 else "B"])
			if slice.is_empty():
				print("  %d/%d %s" % [item + 1, items, line])
			Jobs.progress(slice, line)
		if not slice.is_empty():
			Jobs.finish(slice, numbers)
			quit(0)
			return
	print("")
	print("##### A: the game%s" % ("" if Stats.all_after(args, "--set").is_empty() else " with " + ", ".join(Stats.all_after(args, "--set"))))
	_report(numbers["A"])
	if dbs.size() > 1:
		print("##### B: A with %s" % ", ".join(b_settings))
		_report(numbers["B"])
	print("(%.0fs)" % ((Time.get_ticks_msec() - start_ms) / 1000.0))
	quit(0)


func _new() -> Dictionary:
	var rounds: Dictionary = {}
	for b: int in BUCKETS + 1:   # BUCKETS = "4+"
		rounds[str(b)] = {"turns": 0, "targets": 0, "forced": 0, "safe": 0, "cool": 0, "nosafe": 0, "reach": 0,
			"set": 0, "land": 0}
	return {"runs": 0, "won": 0, "rounds": rounds, "fights": 0, "fight_won": 0, "fight_rounds": 0, "fight_rounds_sq": 0,
		"by_act": {}, "by_kind": {}, "waves_marked": 0, "arrived": 0, "blocked": 0, "block_hurt": 0, "ground": 0,
		"ground_heat": 0, "lost_intents": 0, "trackers": 0, "enemies": 0}


func _merge(into: Dictionary, part: Dictionary) -> void:
	for v: String in ["A", "B"]:
		_add(into[v], part[v])


func _add(a: Dictionary, b: Dictionary) -> void:
	for k: Variant in b:
		if b[k] is Dictionary:
			if not a.has(k):
				a[k] = {}
			_add(a[k], b[k])
		else:
			a[k] = int(a.get(k, 0)) + int(b[k])


## Plays one run with the run bot; every fight is played once more, measured.
func _run(db: ContentDB, seed_value: int, n: Dictionary) -> String:
	var setup: RunSetup = RunSetup.create(db.parts, db.tiles, db.fights, db.run_rules,
		db.combat_rules, db.effectiveness, seed_value, Stats.run_options(db))
	Stats.bot_for(db)
	var state: RunState = RunSim.start(setup)
	var guard: int = 0
	var fights: int = 0
	while state.outcome == RunState.ONGOING and guard < 400:
		var action: Array = RunBot.next_action(state, setup)
		if int(action[0]) == RunSim.FIGHT:
			fights += 1
			_fight(RunSim.fight_setup(state, setup), String(state.pending.get("site_type", "")), state.act, n)
		if not RunSim.apply(state, setup, action):
			break
		guard += 1
	n["runs"] += 1
	var won: bool = state.outcome == RunState.WON
	n["won"] += 1 if won else 0
	return "%s seed %d: %d fights" % ["+" if won else "-", seed_value, fights]


func _fight(setup: CombatSetup, kind: String, act: int, n: Dictionary) -> void:
	var state: CombatState = CombatSim.start(setup)
	var guard: int = 0
	while state.outcome == CombatState.ONGOING and guard < 60:
		var bucket: Dictionary = n["rounds"][str(mini(state.round_number, BUCKETS) - 1)]
		var late: Dictionary = n["rounds"][str(BUCKETS)]
		for u: GridUnit in state.units:
			if u.alive and not u.objective and u.team == GridUnit.TEAM_PLAYER:
				var m: Array = _measure(state, u)
				for row: Dictionary in ([bucket, late] if state.round_number >= 4 else [bucket]):
					row["turns"] += 1
					row["targets"] += int(m[0])
					row["forced"] += 1 if int(m[1]) <= 1 else 0
					row["safe"] += int(m[2])
					row["cool"] += int(m[3])
					row["nosafe"] += 1 if int(m[2]) == 0 else 0
					row["reach"] += int(m[4])
		CombatBot.take_turn(state)
		guard += 1
	var won: bool = state.outcome == CombatState.WON
	n["fights"] += 1
	n["fight_won"] += 1 if won else 0
	n["fight_rounds"] += state.round_number
	n["fight_rounds_sq"] += state.round_number * state.round_number
	for pair: Array in [["by_act", str(act)], ["by_kind", kind]]:
		var row: Dictionary = (n[pair[0]] as Dictionary).get(pair[1], {"fights": 0, "won": 0, "rounds": 0})
		row["fights"] += 1
		row["won"] += 1 if won else 0
		row["rounds"] += state.round_number
		n[pair[0]][pair[1]] = row
	for u: GridUnit in setup.units:
		if u.team == GridUnit.TEAM_ENEMY:
			n["enemies"] += 1
			n["trackers"] += 1 if u.kind == "tracker" else 0
	_events(state, n)


## [targets, targets from a safe hex, safe hexes, safe and cool hexes, reachable hexes] for `u` now.
func _measure(state: CombatState, u: GridUnit) -> Array:
	var here := Vector2i(u.x, u.y)
	var paths: Dictionary = CombatSim.reachable(state, u.ref)
	paths[here] = []
	var cells: Array = paths.keys()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var can_attack: bool = not u.acted and not u.seized
	var targets: Dictionary = {}
	var safe_targets: Dictionary = {}
	var safe: int = 0
	var cool: int = 0
	for cell: Vector2i in cells:
		var copy: CombatState = state.clone()
		var me: GridUnit = copy.unit(u.ref)
		me.x = cell.x
		me.y = cell.y
		var hp: int = me.hp
		if not CombatSim._fire_intents(copy) and copy.outcome == CombatState.ONGOING:
			copy.round_number += 1
			CombatSim._round_hazards(copy)
		var is_safe: bool = me.alive and me.hp >= hp
		if is_safe:
			safe += 1
			if CombatSim.path_heat(state, u, paths[cell]) == 0:
				cool += 1
		if not can_attack:
			continue
		u.x = cell.x
		u.y = cell.y
		for w: int in u.weapons.size():
			if not u.can_fire(w):
				continue
			for t: GridUnit in state.units:
				if not t.alive or t.team == u.team:
					continue
				var d: int = Hex.distance(cell, Vector2i(t.x, t.y))
				if d == 0 or d > CombatSim.aim_reach(state, u, w) + 1:
					continue
				for aim: Vector2i in _aims(state, u, w, Vector2i(t.x, t.y)):
					for hit: Dictionary in (CombatSim.strike_plan(state, u, w, aim)["hits"] as Array):
						var hurt: GridUnit = state.unit(int(hit["ref"]))
						if hurt != null and hurt.team != u.team and int(hit["damage"]) > 0:
							targets[hurt.ref] = true
							if is_safe:
								safe_targets[hurt.ref] = true
		u.x = here.x
		u.y = here.y
	return [targets.size(), safe_targets.size(), safe, cool, cells.size()]


## Where to aim weapon `w` to reach a machine at `at`: the hex itself, and for a lob its neighbours too
## (a splash), when they can be aimed at.
func _aims(state: CombatState, u: GridUnit, w: int, at: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = [at]
	if String(u.weapons[w]["shape"]) == "lob" and int(u.weapons[w]["splash"]) > 0:
		for n: Vector2i in Hex.neighbors(at):
			if state.inside(n):
				out.append(n)
	return out


## Intents set and landed by round, waves, blocks and hot ground, from the fight's events.
func _events(state: CombatState, n: Dictionary) -> void:
	var round: int = 0
	var volley: bool = false
	var firing: int = -1
	var landed: Dictionary = {}
	for e: Array in state.events:
		var kind: int = int(e[GridEv.F_KIND])
		var actor: int = int(e[GridEv.F_ACTOR])
		match kind:
			GridEv.ROUND_START:
				round = int(e[GridEv.F_V1])
				volley = false
				firing = -1
				landed.clear()
			GridEv.TURN_END:
				volley = true
			GridEv.INTENT_SET:
				_bump(n, round, "set")
			GridEv.ATTACK:
				firing = actor if volley else -1
			GridEv.DAMAGE:
				var t: GridUnit = state.unit(int(e[GridEv.F_TARGET]))
				if volley and firing >= 0 and actor == firing and t != null and t.team == GridUnit.TEAM_PLAYER \
						and not landed.has(firing):
					landed[firing] = true
					_bump(n, round, "land")
			GridEv.WAVE_MARKED:
				if int(e[GridEv.F_TARGET]) >= 0:
					n["waves_marked"] += 1
			GridEv.SPAWNED:
				if state.setup.reserve(int(e[GridEv.F_TARGET])) != null:
					n["arrived"] += 1
			GridEv.SPAWN_BLOCKED:
				if int(e[GridEv.F_TARGET]) >= 0 and state.setup.reserve(int(e[GridEv.F_TARGET])) != null:
					n["blocked"] += 1
			GridEv.GROUND_SET:
				n["ground"] += 1
			GridEv.INTENT_LOST:
				n["lost_intents"] += 1


func _bump(n: Dictionary, round: int, key: String) -> void:
	var r: int = maxi(1, round)
	n["rounds"][str(mini(r, BUCKETS) - 1)][key] += 1
	if r >= 4:
		n["rounds"][str(BUCKETS)][key] += 1


func _report(n: Dictionary) -> void:
	print("  runs %d, won %s" % [int(n["runs"]), Stats.rate(int(n["won"]), int(n["runs"]))])
	print("  fights %d, won %s, rounds per fight %s" % [int(n["fights"]), Stats.rate(int(n["fight_won"]), int(n["fights"])),
		Stats.mean_text(float(n["fight_rounds"]), float(n["fight_rounds_sq"]), int(n["fights"]))])
	print("  round   turns  targets  forced   safe   cool  no-safe  reach  intents  land")
	for b: int in BUCKETS + 1:
		var r: Dictionary = n["rounds"][str(b)]
		var t: int = maxi(1, int(r["turns"]))
		var label: String = "4+" if b == BUCKETS else (str(b + 1) + ("+" if b == BUCKETS - 1 else ""))
		print("  %-5s  %6d  %7.2f  %5.1f%%  %5.1f  %5.1f  %6.1f%%  %5.1f  %7d  %4.1f%%" % [label, int(r["turns"]),
			float(r["targets"]) / t, 100.0 * float(r["forced"]) / t, float(r["safe"]) / t, float(r["cool"]) / t,
			100.0 * float(r["nosafe"]) / t, float(r["reach"]) / t, int(r["set"]), 100.0 * float(r["land"]) / maxi(1, int(r["set"]))])
	var all_set: int = 0
	var all_land: int = 0
	for b: int in BUCKETS:
		all_set += int(n["rounds"][str(b)]["set"])
		all_land += int(n["rounds"][str(b)]["land"])
	print("  intents landing, all rounds: %s of %d" % [Stats.rate(all_land, all_set), all_set])
	for key: String in ["by_act", "by_kind"]:
		var keys: Array = (n[key] as Dictionary).keys()
		keys.sort()
		for k: Variant in keys:
			var row: Dictionary = n[key][k]
			print("  %s %-8s fights %4d  won %s  rounds %.2f" % [key.substr(3), String(k), int(row["fights"]),
				Stats.rate(int(row["won"]), int(row["fights"])), float(row["rounds"]) / maxi(1, int(row["fights"]))])
	print("  reinforcements: marked %d, arrived %d, marks blocked %d; hot ground set %d; trackers %d of %d enemies; intents cancelled %d" % [
		int(n["waves_marked"]), int(n["arrived"]), int(n["blocked"]), int(n["ground"]), int(n["trackers"]), int(n["enemies"]),
		int(n["lost_intents"])])
	print("")


func _arg_int(args: PackedStringArray, flag: String, fallback: int) -> int:
	var at: int = args.find(flag)
	return args[at + 1].to_int() if at >= 0 and at + 1 < args.size() else fallback
