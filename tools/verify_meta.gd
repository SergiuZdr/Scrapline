extends SceneTree

## Between-run progression (022): the unlock rules, a run's options, the save, the profile.
##
##   godot --headless --path . --script res://tools/verify_meta.gd

var _passed: int = 0
var _failed: int = 0


func _check(what: String, ok: bool) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])


func _initialize() -> void:
	print("\n=== between-run progression ===")
	_run.call_deferred()


func _setup(db: ContentDB, options: Dictionary, seed_value: int = 5) -> RunSetup:
	return RunSetup.create(db.parts, db.tiles, db.fights, db.run_rules, db.combat_rules, db.balance.effectiveness, seed_value, options)


func _run() -> void:
	var db: ContentDB = ContentDB.load_all()
	var meta: Dictionary = db.meta
	var locked: Array = meta["locked"]
	_check("twelve parts start locked, none of them in the default crew or on the bench", locked.size() == 12
		and (db.run_rules["starting_crew"] as Array).all(func(c: Dictionary) -> bool:
			return (c["parts"] as Array).all(func(p: String) -> bool: return not locked.has(p))))
	for entry: Dictionary in (meta["unlocks"] as Array):
		if String(entry["kind"]) == "part":
			_check("unlock %s opens a locked part (%s)" % [entry["id"], entry["what"]], locked.has(entry["what"]))
	for id: String in (meta["crews"] as Dictionary):
		for member: Dictionary in ((meta["crews"][id] as Dictionary).get("crew", []) as Array):
			for part: String in member["parts"]:
				_check("crew %s fields an unlocked, real part (%s)" % [id, part], db.parts.has(part) and not locked.has(part))

	# A fresh profile: everything locked, the default crew, the first tier.
	var fresh: Dictionary = Meta.options(meta, [], "salvagers", 0)
	var setup: RunSetup = _setup(db, fresh)
	var pooled: Array = []
	for slot: String in setup.pools:
		pooled.append_array(setup.pools[slot])
	_check("a fresh profile's pools hold none of the locked parts (%d parts)" % pooled.size(),
		locked.all(func(p: String) -> bool: return not pooled.has(p)) and pooled.size() == 28)
	_check("with no options a run has every part (the tests and the bot)", _pool_size(_setup(db, {})) == 40)
	_check("a crew or tier that is not unlocked is not given", not Meta.options(meta, [], "wall", 2).has("crew")
		and not Meta.options(meta, [], "wall", 2).has("rules"))

	# Milestones, in order.
	var stats: Dictionary = {}
	var seen: Array = []
	var gave: int = 0
	for run: int in 10:
		var state := RunState.new()
		state.fights_won = 5
		state.act = 2 if run >= 3 else 1
		state.outcome = RunState.WON if run == 8 else RunState.LOST
		stats = Meta.stats_after(stats, state)
		var now: Array = Meta.earned(stats, meta)
		gave += 1 if now.size() > seen.size() else 0
		seen = now
	_check("ten runs (five fights each, one won): %d of them unlocked something, %d of 16 held" % [gave, seen.size()],
		gave >= 8 and seen.has("u13") and not seen.has("u16"))
	_check("stats add up: %s" % [stats], int(stats["runs"]) == 10 and int(stats["fights"]) == 50 and int(stats["act"]) == 2 and int(stats["wins"]) == 1)

	# Unlocked things reach the run.
	var opts: Dictionary = Meta.options(meta, seen, "wall", 1)
	var tough: RunSetup = _setup(db, opts)
	_check("an unlocked crew starts the run", String(RunSim.start(tough).crew[0]["name"]) == "Bulwark")
	_check("an unlocked tier's overlay is in the rules", int(tough.rules["enemies"]["hp_all"]) == 2
		and int(db.run_rules["enemies"].get("hp_all", 0)) == 0)
	_check("unlocked parts are back in the pools", (tough.pools["arm"] as Array).has("ar_maul") and (opts["locked"] as Array).is_empty()
		and (Meta.options(meta, ["u01"], "salvagers", 0)["locked"] as Array).size() == 11)
	var state2: RunState = RunSim.start(tough)
	var fight: Dictionary = RunSim._make_fight(state2, tough, 1, "skirmish")
	var plain: Dictionary = RunSim._make_fight(RunSim.start(_setup(db, Meta.options(meta, seen, "wall", 0))), _setup(db, Meta.options(meta, seen, "wall", 0)), 1, "skirmish")
	_check("and the tier reaches the fight (an enemy's HP %d, was %d)" % [int(fight["enemy"][0]["hp"]), int(plain["enemy"][0].get("hp", 0))],
		int(fight["enemy"][0]["hp"]) > 0 and not (plain["enemy"][0] as Dictionary).has("hp"))

	# The save carries the options: the run replays the same whatever unlocks later.
	var text: String = RunStore.encode(5, "v", [], [], opts)
	var back: Dictionary = RunStore.decode(text)
	var replayed: RunSetup = _setup(db, back["options"])
	_check("a saved run's options survive the save", RunSim.start(replayed).fingerprint() == RunSim.start(tough).fingerprint()
		and replayed.pools == tough.pools)

	# The profile banks a run once.
	var profile: Node = root.get_node("Profile")
	var path: String = "user://verify_meta_profile.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	profile.call("use_path", path)
	var done := RunState.new()
	done.fights_won = 4
	done.outcome = RunState.LOST
	var first: Array = profile.call("bank_run", "9:3", done, meta)
	var again: Array = profile.call("bank_run", "9:3", done, meta)
	_check("a first run of four fights unlocks two things %s" % [first], first == ["u01", "u02"])
	_check("banking the same run again counts once", again == first and int((profile.call("stats") as Dictionary)["runs"]) == 1)
	profile.call("use_path", path)
	_check("and it is on disk", (profile.call("unlocked") as Array) == ["u01", "u02"])
	profile.call("choose_run", "wall", 1)
	profile.call("use_path", path)
	_check("the chosen crew and tier are remembered", (profile.call("run_choice") as Dictionary) == {"crew": "wall", "tier": 1})
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	print("\n  %d passed, %d failed\n" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _pool_size(setup: RunSetup) -> int:
	var n: int = 0
	for slot: String in setup.pools:
		n += (setup.pools[slot] as Array).size()
	return n
