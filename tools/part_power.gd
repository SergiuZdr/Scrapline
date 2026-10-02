extends SceneTree

## What each part is worth in a fight, measured (033, play-test 10: "analyse how the power spike
## goes for each category and between categories").
##
##   godot --headless --path . --script res://tools/part_power.gd -- [--trials 40] [--only ids,...]
##       [--enemies 5] [--hp 4] [--damage 0] [--json out.json]
##
## A PAIRED test: every trial is one fight (a run board, widened as the run widens it, and a
## rolled enemy squad of commons and uncommons), played twice by the bot -- once with the
## reference crew below, once with the part under test fitted to the FIRST machine in its slot
## (an arm on both arms: on one, the bot may simply fire the other). The difference is the part's effect, with the fight, the
## enemies and the seed held still. Reported per part:
##   win   -- change in fights won, in points
##   net   -- change in (enemy HP destroyed - crew HP lost) per fight
## The reference parts measure 0 by construction; that is the check the harness works.

const REFERENCE: Array = [
	["ch_brute", "co_slug", "ar_hammer", "ar_scatter", "mo_plating"],
	["ch_hauler", "co_furnace", "ar_pulse", "ar_cleaver", "mo_ablative"],
	["ch_skirmisher", "co_dynamo", "ar_scanner", "ar_harpoon", "mo_governor"],
]
const SLOT_INDEX: Dictionary = {"chassis": 0, "core": 1, "arm": 2, "module": 4}

var _db: ContentDB


func _initialize() -> void:
	_db = ContentDB.load_all()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var trials: int = int(_arg(args, "--trials", "40"))
	var only: String = _arg(args, "--only", "")
	var ids: Array = []
	for id: Variant in _db.parts.keys():
		if PartTuning.is_tuned(String(id)) or not SLOT_INDEX.has(String((_db.parts[id] as Dictionary).get("slot", ""))):
			continue
		if not only.is_empty() and not only.split(",").has(String(id)):
			continue
		ids.append(String(id))
	ids.sort()
	var boards: Array = []
	for id: Variant in _db.fights.keys():
		var map: Dictionary = _db.fights[id]
		if not bool(map.get("tutorial", false)) and not bool(map.get("boss", false)) and not bool(map.get("warlord", false)):
			boards.append(String(id))
	boards.sort()
	var board_rules: Dictionary = _db.run_rules.get("board", {})

	# The trials: a board and an enemy squad each, and the reference result.
	var fights: Array = []
	var base: Array = []
	for t: int in trials:
		var rng := SimRNG.new(104729 * (t + 1))
		var template: Dictionary = RunSim.widen(_db.fights[boards[t % boards.size()]], board_rules)
		var fight: Dictionary = template.duplicate(true)
		fight["objective"] = {"type": "rout"}
		fight["enemy"] = _enemies(rng, template, int(_arg(args, "--enemies", "5")), int(_arg(args, "--hp", "4")), int(_arg(args, "--damage", "0")))
		fights.append(fight)
		base.append(_play(_with(fight, ""), 5000 + t))

	var out: Dictionary = {}
	for id: String in ids:
		var won: int = 0
		var net: int = 0
		for t: int in trials:
			var r: Array = _play(_with(fights[t], id), 5000 + t)
			won += int(r[0]) - int(base[t][0])
			net += int(r[1]) - int(base[t][1])
		var part: Dictionary = _db.parts[id]
		out[id] = {"slot": String(part.get("slot", "")), "rarity": int(part.get("rarity", 1)), "maker": String(part.get("maker", "")),
			"win": 100.0 * won / trials, "net": float(net) / trials}
		print("%-16s %-8s r%d  win %+6.1f  net %+6.2f" % [id, String(part.get("slot", "")), int(part.get("rarity", 1)),
			100.0 * won / trials, float(net) / trials])
	var base_won: int = 0
	for r: Array in base:
		base_won += int(r[0])
	print("reference crew wins %.1f%% of %d trials" % [100.0 * base_won / maxf(1.0, trials), trials])
	var json_path: String = _arg(args, "--json", "")
	if not json_path.is_empty():
		var file := FileAccess.open(json_path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"trials": trials, "reference_win": 100.0 * base_won / maxf(1.0, trials), "parts": out}, "\t"))
	quit()


## The reference crew at the template's starts, with `part` (if any) on the first machine.
func _with(fight: Dictionary, part: String) -> Dictionary:
	var f: Dictionary = fight.duplicate(true)
	var crew: Array = []
	var starts: Array = f["player"]
	for i: int in mini(3, starts.size()):
		var parts: Array = (REFERENCE[i] as Array).duplicate()
		if i == 0 and not part.is_empty():
			var slot: String = String((_db.parts[part] as Dictionary)["slot"])
			parts[int(SLOT_INDEX[slot])] = part
			# An arm goes on BOTH arms: on one, the bot may simply fire the other.
			if slot == "arm":
				parts[3] = part
		crew.append({"name": "M%d" % i, "parts": parts, "x": int(starts[i]["x"]), "y": int(starts[i]["y"])})
	f["player"] = crew
	return f


## `count` enemies at the template's enemy starts, parts rolled from commons and uncommons.
func _enemies(rng: SimRNG, template: Dictionary, count: int, hp: int, damage: int) -> Array:
	var starts: Array = RunSim._enemy_positions(template, count)
	var pools: Dictionary = {"chassis": [], "core": [], "arm": [], "module": []}
	var ids: Array = _db.parts.keys()
	ids.sort()
	for id: Variant in ids:
		var part: Dictionary = _db.parts[id]
		if PartTuning.is_tuned(String(id)) or int(part.get("rarity", 1)) > 2 or not bool(part.get("enemy", true)):
			continue
		if pools.has(String(part.get("slot", ""))):
			(pools[String(part["slot"])] as Array).append(id)
	var out: Array = []
	for i: int in starts.size():
		var parts: Array = [rng.pick(pools["chassis"]), rng.pick(pools["core"]), rng.pick(pools["arm"]), rng.pick(pools["arm"]), rng.pick(pools["module"])]
		var spec: Dictionary = {"name": "E%d" % i, "x": int((starts[i] as Vector2i).x), "y": int((starts[i] as Vector2i).y), "parts": parts}
		# Tough enough that the reference crew wins about half its fights: a part's effect can
		# only show where the result is in doubt.
		if hp > 0:
			spec["hp"] = int(((_db.parts[parts[0]] as Dictionary).get("grid", {}) as Dictionary).get("hp", 8)) \
				+ int(((_db.parts[parts[4]] as Dictionary).get("grid", {}) as Dictionary).get("hp", 0)) + hp
		if damage > 0:
			spec["bonus"] = {"damage": damage}
		out.append(spec)
	return out


## [won 0/1, enemy HP destroyed - crew HP lost].
func _play(fight: Dictionary, seed_value: int) -> Array:
	var setup: CombatSetup = CombatSetup.build(fight, _db.combat_rules, _db.parts, _db.tiles, _db.balance.effectiveness, seed_value)
	if not setup.errors.is_empty():
		push_error("setup errors: %s" % [setup.errors])
		return [0, 0]
	var state: CombatState = CombatSim.start(setup)
	var guard: int = 0
	while state.outcome == CombatState.ONGOING and guard < 60:
		CombatBot.take_turn(state)
		guard += 1
	var net: int = 0
	for u: GridUnit in state.units:
		if u.objective:
			continue
		var lost: int = u.max_hp - (u.hp if u.alive else 0)
		net += lost if u.team == GridUnit.TEAM_ENEMY else -lost
	return [1 if state.outcome == CombatState.WON else 0, net]


func _arg(args: PackedStringArray, key: String, fallback: String) -> String:
	var at: int = args.find(key)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else fallback
