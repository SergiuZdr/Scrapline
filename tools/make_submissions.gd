extends SceneTree

## Writes sample submissions into a queue directory, the way a Nakama server would after
## accepting them from clients. Used to drive the verification worker end to end.
##
##   godot --headless --path . --script res://tools/make_submissions.gd -- --out user://queue

func _initialize() -> void:
	var opts: Dictionary = {}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i: int in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			opts["out"] = args[i + 1]
	var out_dir: String = String(opts.get("out", "user://queue"))
	if not DirAccess.dir_exists_absolute(out_dir):
		DirAccess.make_dir_recursive_absolute(out_dir)

	var content: ContentDB = ContentDB.load_all()
	var sim_content: Dictionary = content.to_sim_content()

	var attacker: Array = []
	for i: int in 4:
		attacker.append({"name": "A%d" % i, "parts": {
			"chassis": "ch_brute", "core": "co_mag", "arm_l": "ar_ripper",
			"arm_r": "ar_ripper", "module": "mo_servo"}})
	var defender: Array = []
	for i: int in 4:
		defender.append({"name": "D%d" % i, "parts": {
			"chassis": "ch_hauler", "core": "co_slug", "arm_l": "ar_pulse",
			"arm_r": "ar_pulse", "module": "mo_governor"}})

	var setup: BattleSetup = BattleSetup.make(99001, attacker, defender, "", "map_foundry_yard")
	var orders: Array = [{0: ["ability:0", "attack"]}, {}, {1: ["advance", "attack"]}]
	var result: BattleResult = BattleSim.simulate(setup, orders, sim_content, content.balance)
	var defender_doctrine: Array = Doctrine.default_doctrine().to_array()

	# An honest submission, exactly as a client would send it.
	_write(out_dir, "01_honest.json", BattleSubmission.from_result(
		setup, orders, result, "pvp:honest"), defender_doctrine)

	# A cheat: claim the win regardless of what actually happened.
	var forged: BattleSubmission = BattleSubmission.from_result(setup, orders, result, "pvp:forged_winner")
	forged.claimed_winner = SimDefs.TEAM_A if result.winner != SimDefs.TEAM_A else SimDefs.TEAM_B
	_write(out_dir, "02_forged_winner.json", forged, defender_doctrine)

	# A cheat: honest inputs, invented hash.
	var bad_hash: BattleSubmission = BattleSubmission.from_result(setup, orders, result, "pvp:forged_hash")
	bad_hash.claimed_hash = "00000000"
	_write(out_dir, "03_forged_hash.json", bad_hash, defender_doctrine)

	# A cheat: quietly upgrade the squad after the fact.
	var boosted: BattleSubmission = BattleSubmission.from_result(setup, orders, result, "pvp:boosted")
	var specs: Array = (boosted.setup.specs_for(0) as Array).duplicate(true)
	for spec: Variant in specs:
		(spec as Dictionary)["power"] = 300
	boosted.setup.team_specs[0] = specs
	_write(out_dir, "04_boosted_squad.json", boosted, defender_doctrine)

	print("wrote 4 submissions to %s (1 honest, 3 forged)" % out_dir)
	quit(0)


## The envelope is what the SERVER stores: the client's submission plus the defender's
## doctrine, taken from server-side storage rather than from anything the client sent.
func _write(dir: String, name: String, submission: BattleSubmission, doctrine: Array) -> void:
	var file: FileAccess = FileAccess.open(dir.path_join(name), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"submission": submission.to_dict(),
		"defender_doctrine": doctrine,
	}, "\t"))
	file.close()
