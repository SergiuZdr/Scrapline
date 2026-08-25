extends SceneTree

## Mass battle simulator for balance work.
##
## Scrapline stacks chains, Linkages, cross-unit Synergy detonations, a damage-vs-armor
## wheel and rotating Conditions on top of a 20-part pool. That interaction space is
## far past what anyone can hold in their head, so balance is measured here rather
## than argued about. This tool is not optional tooling -- it is the only reason the
## deepest combo option in the design is survivable.
##
##   godot --headless --path . --script res://tools/balance_sim.gd -- --battles 2000
##   godot --headless --path . --script res://tools/balance_sim.gd -- --battles 20000 --out tools/out/balance.csv
##   godot --headless --path . --script res://tools/balance_sim.gd -- --battles 5000 --condition cond_ion_storm
##
## Reading the output: a part's win rate is the share of battles won by squads
## containing it. Because squads are drawn uniformly, a balanced part sits near 50%.
## Anything outside 45-55% is flagged -- either it is doing too much for its slot, or
## nobody would ever choose it.

const DEFAULT_BATTLES: int = 2000
const FLAG_LOW: int = 45
const FLAG_HIGH: int = 55

var _slot_pools: Dictionary = {}   ## slot key -> Array of part ids, in stable order
var _stats: Dictionary = {}        ## part id -> {appearances, wins}
var _db: ContentDB = null


func _initialize() -> void:
	var opts: Dictionary = _parse_args(OS.get_cmdline_user_args())

	_db = ContentDB.load_all()
	if not _db.errors.is_empty():
		for e: String in _db.errors:
			printerr("content error: ", e)
		quit(1)
		return

	_build_pools()
	if not _pools_are_usable():
		quit(1)
		return

	var battles: int = maxi(1, int(opts.get("battles", DEFAULT_BATTLES)))
	var base_seed: int = int(opts.get("seed", 1))
	var condition: String = String(opts.get("condition", ""))
	var mirror: bool = opts.has("mirror")
	var map_id: String = String(opts.get("map", ""))
	var content: Dictionary = _db.to_sim_content()

	print("")
	print("=== SCRAPLINE balance run ===")
	print("battles %d   condition %s   parts %d%s" % [
		battles, condition if not condition.is_empty() else "(none)", _db.parts.size(),
		"   MIRROR" if mirror else ""])

	var wins: Array[int] = [0, 0]
	var draws: int = 0
	var total_cycles: int = 0
	var total_ticks: int = 0
	var cycle_histogram: Dictionary = {}
	var combo_counts: Dictionary = {"linkage": 0, "detonation": 0, "overdrive": 0, "seize": 0}
	var type_stats: Dictionary = {}
	var started: int = Time.get_ticks_msec()

	for i: int in battles:
		# Squad generation gets its own stream, seeded per battle, so a run is
		# reproducible and any single battle can be replayed on its own.
		var gen := SimRNG.new(base_seed + i)
		var team_a: Array = _random_squad(gen)
		# --mirror gives both sides the SAME randomly generated squad. Across thousands
		# of different matchups this is the only sound test for simulation-level bias:
		# a single mirror fixture is one deterministic battle, not a sample, because
		# the damage variance is far too small to make repeated runs independent.
		var team_b: Array = team_a.duplicate(true) if mirror else _random_squad(gen)
		var setup: BattleSetup = BattleSetup.make(base_seed + i, team_a, team_b, condition, map_id)

		var result: BattleResult = BattleSim.simulate(setup, [], content, _db.balance)

		if result.winner == SimDefs.TEAM_A:
			wins[0] += 1
		elif result.winner == SimDefs.TEAM_B:
			wins[1] += 1
		else:
			draws += 1

		total_cycles += result.cycles
		total_ticks += result.ticks
		cycle_histogram[result.cycles] = int(cycle_histogram.get(result.cycles, 0)) + 1

		_tally_squad(team_a, result.winner == SimDefs.TEAM_A, type_stats)
		_tally_squad(team_b, result.winner == SimDefs.TEAM_B, type_stats)
		_tally_combos(result, combo_counts)

		if battles >= 5000 and i > 0 and i % 2500 == 0:
			print("  ... %d / %d" % [i, battles])

	var elapsed: int = Time.get_ticks_msec() - started
	_report(battles, wins, draws, total_cycles, total_ticks, cycle_histogram, combo_counts, type_stats, elapsed)
	_write_csv(String(opts.get("out", "tools/out/balance.csv")), battles)
	quit(0)


# --- Squad generation --------------------------------------------------------

func _build_pools() -> void:
	_slot_pools = {"chassis": [], "core": [], "arm": [], "module": []}
	# Ids are collected then sorted, because Dictionary key order reflects file load
	# order. Sorting makes the pools -- and therefore every generated squad -- stable
	# regardless of how the content files happen to be arranged.
	var ids: Array = _db.parts.keys()
	ids.sort()
	for id: Variant in ids:
		var part: Dictionary = _db.parts[id]
		var slot: String = String(part.get("slot", ""))
		if _slot_pools.has(slot):
			(_slot_pools[slot] as Array).append(String(id))
		_stats[String(id)] = {"appearances": 0, "wins": 0}


func _pools_are_usable() -> bool:
	for slot: String in ["chassis", "core", "arm", "module"]:
		if (_slot_pools[slot] as Array).is_empty():
			printerr("no parts found for slot '%s' -- check the 'slot' field in data/parts/" % slot)
			return false
	return true


func _random_squad(gen: SimRNG) -> Array:
	var squad: Array = []
	for slot_index: int in SimDefs.SQUAD_SIZE:
		squad.append({
			"name": "U%d" % slot_index,
			"parts": {
				"chassis": _pick(gen, "chassis"),
				"core": _pick(gen, "core"),
				"arm_l": _pick(gen, "arm"),
				"arm_r": _pick(gen, "arm"),
				"module": _pick(gen, "module"),
			},
		})
	return squad


func _pick(gen: SimRNG, slot: String) -> String:
	var pool: Array = _slot_pools[slot]
	return String(pool[gen.range_int(0, pool.size() - 1)])


# --- Tallying ----------------------------------------------------------------

func _tally_squad(squad: Array, won: bool, type_stats: Dictionary) -> void:
	for entry: Variant in squad:
		var parts: Dictionary = (entry as Dictionary)["parts"]
		for key: String in ["chassis", "core", "arm_l", "arm_r", "module"]:
			var id: String = String(parts[key])
			var row: Dictionary = _stats[id]
			row["appearances"] = int(row["appearances"]) + 1
			if won:
				row["wins"] = int(row["wins"]) + 1

		# Damage and armour types are tracked separately: a lopsided type is a
		# problem with the effectiveness wheel, not with any individual part.
		var core: Dictionary = _db.parts.get(String(parts["chassis"]), {})
		_bump(type_stats, "armor:" + String(core.get("armor_type", "?")), won)
		var core_part: Dictionary = _db.parts.get(String(parts["core"]), {})
		_bump(type_stats, "damage:" + String(core_part.get("damage_type", "?")), won)


func _bump(stats: Dictionary, key: String, won: bool) -> void:
	if not stats.has(key):
		stats[key] = {"appearances": 0, "wins": 0}
	var row: Dictionary = stats[key]
	row["appearances"] = int(row["appearances"]) + 1
	if won:
		row["wins"] = int(row["wins"]) + 1


func _tally_combos(result: BattleResult, counts: Dictionary) -> void:
	for e: Array in result.events.events:
		match e[SimEv.F_KIND]:
			SimEv.LINKAGE: counts["linkage"] = int(counts["linkage"]) + 1
			SimEv.DETONATION: counts["detonation"] = int(counts["detonation"]) + 1
			SimEv.OVERDRIVE: counts["overdrive"] = int(counts["overdrive"]) + 1
			SimEv.SEIZE: counts["seize"] = int(counts["seize"]) + 1


# --- Reporting ---------------------------------------------------------------

func _report(
	battles: int, wins: Array[int], draws: int,
	total_cycles: int, total_ticks: int,
	cycle_histogram: Dictionary, combo_counts: Dictionary,
	type_stats: Dictionary, elapsed_ms: int
) -> void:
	print("")
	print("--- outcomes ---")
	print("  team A %d (%d%%)   team B %d (%d%%)   draws %d (%d%%)" % [
		wins[0], _pct(wins[0], battles), wins[1], _pct(wins[1], battles), draws, _pct(draws, battles)])
	print("  avg cycles %.2f   avg ticks %d   (%.1f s of simulated combat per battle)" % [
		float(total_cycles) / battles, total_ticks / battles,
		float(total_ticks) / battles / maxi(1, _db.balance.tick_hz)])

	print("")
	print("--- battle length ---")
	var lengths: Array = cycle_histogram.keys()
	lengths.sort()
	for c: Variant in lengths:
		var n: int = cycle_histogram[c]
		print("  %2d cycles  %-5d %s" % [c, n, "#".repeat(maxi(1, (n * 40) / battles))])

	print("")
	print("--- combo frequency (per battle) ---")
	for key: String in ["linkage", "detonation", "overdrive", "seize"]:
		print("  %-11s %.2f" % [key, float(combo_counts[key]) / battles])

	print("")
	print("--- damage and armour types ---")
	var type_keys: Array = type_stats.keys()
	type_keys.sort()
	for key: Variant in type_keys:
		var row: Dictionary = type_stats[key]
		var pct: int = _pct(int(row["wins"]), int(row["appearances"]))
		print("  %-20s %5d uses  %3d%%  %s" % [key, row["appearances"], pct, _flag(pct)])

	print("")
	print("--- parts, worst to best ---")
	var rows: Array = []
	for id: Variant in _stats.keys():
		var row: Dictionary = _stats[id]
		if int(row["appearances"]) == 0:
			continue
		rows.append({
			"id": String(id),
			"pct": _pct(int(row["wins"]), int(row["appearances"])),
			"uses": int(row["appearances"]),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["pct"] != b["pct"]:
			return a["pct"] < b["pct"]
		return String(a["id"]) < String(b["id"]))

	var flagged: int = 0
	for row: Dictionary in rows:
		var part: Dictionary = _db.parts.get(row["id"], {})
		var flag: String = _flag(row["pct"])
		if not flag.is_empty():
			flagged += 1
		print("  %-14s %-9s %6d uses  %3d%%  %s" % [
			row["id"], String(part.get("slot", "?")), row["uses"], row["pct"], flag])

	print("")
	print("  %d of %d parts outside the %d-%d%% band." % [flagged, rows.size(), FLAG_LOW, FLAG_HIGH])
	print("  %d battles in %.1f s (%.1f ms each)" % [battles, elapsed_ms / 1000.0, float(elapsed_ms) / battles])


func _write_csv(path: String, battles: int) -> void:
	var dir: String = path.get_base_dir()
	if not dir.is_empty() and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("could not write ", path)
		return

	file.store_line("part_id,name,slot,rarity,appearances,wins,win_pct,battles")
	var ids: Array = _stats.keys()
	ids.sort()
	for id: Variant in ids:
		var row: Dictionary = _stats[id]
		if int(row["appearances"]) == 0:
			continue
		var part: Dictionary = _db.parts.get(id, {})
		file.store_line("%s,%s,%s,%d,%d,%d,%d,%d" % [
			String(id),
			String(part.get("name", "")).replace(",", " "),
			String(part.get("slot", "")),
			int(part.get("rarity", 1)),
			int(row["appearances"]),
			int(row["wins"]),
			_pct(int(row["wins"]), int(row["appearances"])),
			battles,
		])
	file.close()
	print("  csv -> %s" % path)
	print("")


func _pct(part: int, whole: int) -> int:
	if whole <= 0:
		return 0
	return (part * 100) / whole


func _flag(pct: int) -> String:
	if pct > FLAG_HIGH:
		return "<-- too strong"
	if pct < FLAG_LOW:
		return "<-- too weak"
	return ""


func _parse_args(args: PackedStringArray) -> Dictionary:
	var opts: Dictionary = {}
	var i: int = 0
	while i < args.size():
		if not args[i].begins_with("--"):
			i += 1
			continue
		var key: String = args[i].substr(2)
		if i + 1 < args.size() and not args[i + 1].begins_with("--"):
			opts[key] = args[i + 1]
			i += 2
		else:
			opts[key] = true
			i += 1
	return opts
