extends SceneTree

## Headless battle runner and determinism check.
##
## This one tool serves the whole project. In Phase 0 it is how a battle gets played
## at all. In Phase 4 the exact same code path becomes the server's anti-cheat: a
## client submits {setup, seed, order_log}, the server replays it here, and compares
## the event-stream hash against what the client claimed. So the rule is simple --
## if this tool disagrees with itself, nothing built on top of it can be trusted.
##
##   godot --headless --path . --script res://tools/verify_battle.gd -- --fixture battle_01
##   godot --headless --path . --script res://tools/verify_battle.gd -- --fixture battle_01 --repeat 3
##   godot --headless --path . --script res://tools/verify_battle.gd -- --fixture battle_01 --quiet

const FIXTURE_DIR: String = "res://tools/fixtures"

var _quiet: bool = false


func _initialize() -> void:
	var opts: Dictionary = _parse_args(OS.get_cmdline_user_args())
	_quiet = opts.get("quiet", false)

	var db: ContentDB = ContentDB.load_all()
	if not db.errors.is_empty():
		for e: String in db.errors:
			printerr("content error: ", e)
		_fail("content failed to load")
		return
	_say("content loaded: %s" % db.summary())

	var fixture_name: String = String(opts.get("fixture", "battle_01"))
	var fixture: Dictionary = _load_fixture(fixture_name)
	if fixture.is_empty():
		_fail("fixture '%s' could not be read" % fixture_name)
		return

	var setup: BattleSetup = BattleSetup.from_dict(fixture)
	if opts.has("seed"):
		setup.seed_value = int(opts["seed"])
	# `--condition none` strips the Battlefield Condition, which is how you tell a
	# squad-composition problem apart from a Condition that is swinging too hard.
	if opts.has("condition"):
		var forced: String = String(opts["condition"])
		setup.condition_id = "" if forced == "none" else forced
	# --auto discards the scripted order log so both squads run on doctrine alone.
	# Comparing the two modes separates two very different questions: "is this squad
	# composition balanced?" (auto vs auto should be near 50/50) and "does giving
	# orders beat auto-play?" (if it does not, the Order Phase has no reason to exist).
	var orders: Array = []
	if not opts.has("auto"):
		orders = _convert_orders(fixture.get("orders", []) as Array)
	var content: Dictionary = db.to_sim_content()

	var repeat: int = maxi(1, int(opts.get("repeat", 1)))
	var hashes: PackedStringArray = []
	var first: BattleResult = null

	for run_index: int in repeat:
		var result: BattleResult = BattleSim.simulate(setup, orders, content, db.balance)
		hashes.append(result.hash_hex())
		if run_index == 0:
			first = result

	_report(fixture_name, setup, orders, db, first)

	if repeat > 1:
		_say("")
		_say("--- determinism ---")
		var reference: String = hashes[0]
		var diverged: bool = false
		for i: int in hashes.size():
			var mark: String = "ok" if hashes[i] == reference else "DIVERGED"
			_say("  run %d  %s  %s" % [i + 1, hashes[i], mark])
			if hashes[i] != reference:
				diverged = true
		if diverged:
			_fail("%d runs of the same battle produced different event streams" % repeat)
			return
		_say("  %d runs, identical event streams." % repeat)

	quit(0)


# --- Reporting ---------------------------------------------------------------

func _report(fixture_name: String, setup: BattleSetup, orders: Array, db: ContentDB, result: BattleResult) -> void:
	if _quiet:
		print(result.hash_hex())
		return

	print("")
	print("=== SCRAPLINE :: %s ===" % fixture_name)
	print("seed %d   condition %s   order cycles scripted: %d" % [
		setup.seed_value,
		setup.condition_id if not setup.condition_id.is_empty() else "(none)",
		orders.size(),
	])

	print("")
	print("--- roster (as assembled, before Condition modifiers) ---")
	var content_bundle: Dictionary = db.to_sim_content()
	var arena: Battlefield = BattleSim.build_field(setup, content_bundle)
	var built: Array[SimUnit] = UnitBuilder.build_squads(setup, content_bundle, db.balance, arena)
	print("  map: %s  (%d x %d tiles)" % [arena.display_name, arena.width, arena.depth])
	print("  %-4s %-10s %-9s %5s %5s %5s %6s %5s %6s  %-9s %-10s %s" % [
		"ref", "name", "role", "hp", "atk", "armr", "speed", "move", "reach", "damage", "armor", "start"])
	for u: SimUnit in built:
		print("  %-4s %-10s %-9s %5d %5d %5d %6d %5d %6d  %-9s %-10s (%d,%d) %s" % [
			SimEv.ref_name(u.unit_ref), u.display_name, SimDefs.role_name(u.role),
			u.hp_max, u.attack, u.armor, u.speed, u.move_speed, u.weapon_range,
			SimDefs.DMG_TYPE_NAMES[u.damage_type], SimDefs.ARM_TYPE_NAMES[u.armor_type],
			u.pos_x, u.pos_z, arena.tile_id_at(u.pos_x, u.pos_z),
		])

	print("")
	print("--- event log ---")
	var current_cycle: int = -1
	for e: Array in result.events.events:
		if e[SimEv.F_KIND] == SimEv.CYCLE_START:
			current_cycle = e[SimEv.F_V1]
			print("")
			print("  ......... ORDER PHASE -> cycle %d .........." % current_cycle)
		print("  " + EventStream.format_event(e))

	print("")
	print("--- survivors ---")
	for snap: Dictionary in result.final_units:
		var bar: String = "destroyed" if not snap["alive"] else "hp %d/%d" % [snap["hp"], snap["hp_max"]]
		print("  %-4s %-10s %s" % [SimEv.ref_name(snap["ref"]), snap["name"], bar])

	print("")
	print("--- result ---")
	print("  " + result.summary())
	print("")


func _row_name(row: int) -> String:
	match row:
		SimDefs.ROW_FRONT: return "front"
		SimDefs.ROW_MID: return "mid"
		_: return "back"


# --- Input -------------------------------------------------------------------

func _load_fixture(fixture_name: String) -> Dictionary:
	var path: String = "%s/%s.json" % [FIXTURE_DIR, fixture_name]
	if not FileAccess.file_exists(path):
		printerr("no such fixture: ", path)
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		printerr("%s: line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	if not (json.data is Dictionary):
		printerr(path, ": expected a top-level object")
		return {}
	return json.data as Dictionary


## JSON object keys are always strings, so the order log arrives keyed by "4" rather
## than 4. Keys beginning with an underscore are authoring comments and are dropped.
func _convert_orders(raw: Array) -> Array:
	var out: Array = []
	for entry: Variant in raw:
		var converted: Dictionary = {}
		if entry is Dictionary:
			for key: Variant in (entry as Dictionary).keys():
				var name: String = String(key)
				if name.begins_with("_"):
					continue
				converted[name.to_int()] = (entry as Dictionary)[key]
		out.append(converted)
	return out


func _parse_args(args: PackedStringArray) -> Dictionary:
	var opts: Dictionary = {}
	var i: int = 0
	while i < args.size():
		var arg: String = args[i]
		if not arg.begins_with("--"):
			i += 1
			continue
		var key: String = arg.substr(2)
		if key == "quiet" or key == "auto":
			opts[key] = true
			i += 1
			continue
		if i + 1 < args.size():
			opts[key] = args[i + 1]
			i += 2
		else:
			opts[key] = true
			i += 1
	return opts


func _say(text: String) -> void:
	if not _quiet:
		print(text)


func _fail(reason: String) -> void:
	printerr("FAILED: ", reason)
	quit(1)
