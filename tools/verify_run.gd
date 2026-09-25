extends SceneTree

## Run rules: generation, travel and the front, every site type, fights feeding back into
## the run, wrecks and rebuilds, refits, determinism and the save round trip.
##
##   godot --headless --path . --script res://tools/verify_run.gd

var _db: ContentDB
var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_db = ContentDB.load_all()
	print("")
	print("=== run ===")
	_test_generation()
	_test_travel_and_front()
	_test_sites()
	_test_fight_feeds_the_run()
	_test_wreck_and_rebuild()
	_test_boss_held()
	_test_levels()
	_test_assembly()
	_test_refit()
	_test_determinism_and_save()
	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	print("")
	quit(1 if _failed > 0 else 0)


func _setup(seed_value: int) -> RunSetup:
	return RunSetup.create(_db.parts, _db.tiles, _db.fights, _db.run_rules, _db.combat_rules,
		_db.balance.effectiveness, seed_value)


func _test_generation() -> void:
	var all_connected: bool = true
	var all_one_boss: bool = true
	var all_have_shop: bool = true
	var sizes: Dictionary = {}
	for s: int in 200:
		var state: RunState = RunSim.start(_setup(s))
		sizes[state.sites.size()] = true
		# Boss reachable from start by breadth-first search.
		var seen: Dictionary = {0: true}
		var queue: Array = [0]
		while not queue.is_empty():
			var id: int = queue.pop_front()
			for n: Variant in (state.site(id)["links"] as Array):
				if not seen.has(int(n)):
					seen[int(n)] = true
					queue.append(int(n))
		all_connected = all_connected and seen.size() == state.sites.size()
		var bosses: int = 0
		var shops: int = 0
		for site: Dictionary in state.sites:
			bosses += 1 if String(site["type"]) == "boss" else 0
			shops += 1 if String(site["type"]) == "workshop" else 0
		all_one_boss = all_one_boss and bosses == 1
		all_have_shop = all_have_shop and shops >= 1
	_check("200 regions: every site reachable from the start", all_connected)
	_check("200 regions: exactly one boss gate each", all_one_boss)
	_check("200 regions: at least one workshop each", all_have_shop)
	_check("regions vary in size across seeds", sizes.size() > 1)

	# Every generated fight builds cleanly: no two things on one hex, nothing on scrap.
	var bad: PackedStringArray = []
	var built: int = 0
	for s: int in 40:
		var setup: RunSetup = _setup(s)
		var state: RunState = RunSim.start(setup)
		for site: Dictionary in state.sites:
			if not RunSim.FIGHT_TYPES.has(String(site["type"])):
				continue
			var fight: Dictionary = RunSim._make_fight(state, setup, int(site["id"]), String(site["type"]))
			var combat: CombatSetup = CombatSetup.build(fight, setup.combat_rules, setup.parts, setup.tiles, setup.wheel, 1)
			built += 1
			if not combat.errors.is_empty():
				bad.append("seed %d site %d: %s" % [s, site["id"], combat.errors[0]])
	_check("%d generated fights all build with no errors %s" % [built, bad.slice(0, 2)], bad.is_empty())
	var a: RunState = RunSim.start(_setup(42))
	var b: RunState = RunSim.start(_setup(42))
	_check("the same seed gives the same region", _region_text(a) == _region_text(b))
	_check("a different seed gives a different region", _region_text(a) != _region_text(RunSim.start(_setup(43))))


func _region_text(state: RunState) -> String:
	var parts: PackedStringArray = []
	for site: Dictionary in state.sites:
		parts.append("%d:%s:%s" % [site["id"], site["type"], str(site["links"])])
	return " ".join(parts)


func _test_travel_and_front() -> void:
	var setup: RunSetup = _setup(7)
	var state: RunState = RunSim.start(setup)
	_check("the run starts at the start site with nothing pending", state.current == 0 and state.pending.is_empty())
	var far: int = state.sites.size() - 1
	_check("cannot travel to a site that is not linked", not RunSim.apply(state, setup, [RunSim.TRAVEL, far]))
	var first: int = RunSim.destinations(state)[0]
	_check("can travel to a linked site", RunSim.apply(state, setup, [RunSim.TRAVEL, first]))
	_check("arriving at an unvisited site sets something pending", not state.pending.is_empty())
	_check("cannot travel on while something is pending", RunSim.destinations(state).is_empty())

	# The front: consumed sites are closed, and lingering in consumed ground bites.
	var s2: RunState = RunSim.start(setup)
	s2.front_col = 0
	_check("the start column can be consumed", s2.consumed(0))
	var hp: int = int(s2.crew[0]["hp"])
	RunSim.apply(s2, setup, [RunSim.TRAVEL, RunSim.destinations(s2)[0]])
	_check("leaving consumed ground costs every machine front damage",
		int(s2.crew[0]["hp"]) == hp - int((_db.run_rules["front"] as Dictionary)["damage"]))
	s2.crew[1]["hp"] = 1
	s2.pending = {}
	s2.front_col = 5
	s2.current = RunSim.destinations(s2)[0] if not RunSim.destinations(s2).is_empty() else s2.current
	_check("the front never finishes a machine off", int(s2.crew[1]["hp"]) >= 1)
	s2.pending = {}
	s2.front_col = 1
	_check("consumed sites are not destinations",
		RunSim.destinations(s2).all(func(id: int) -> bool: return int(s2.site(id)["col"]) > 1))


func _test_sites() -> void:
	var setup: RunSetup = _setup(11)
	var state: RunState = RunSim.start(setup)
	# Scrapyard: take a part, or take the scrap.
	state.pending = {"kind": "scrapyard", "options": ["ar_railgun", "co_mag", "mo_servo"], "scrap": 15}
	var scrap: int = state.scrap
	_check("scrapyard: taking the scrap instead", RunSim.apply(state, setup, [RunSim.PICK, -1]) and state.scrap == scrap + 15)
	state.pending = {"kind": "reward", "options": ["ar_railgun", "co_mag", "mo_servo"]}
	_check("reward: picking a part puts it in the hold", RunSim.apply(state, setup, [RunSim.PICK, 0]) and state.cargo.has("ar_railgun"))
	_check("the hold starts at 8", state.hold_size == 8)
	state.pending = {"kind": "reward", "options": ["ar_railgun"]}
	while state.cargo.size() < state.hold_size:
		state.cargo.append("mo_servo")
	_check("reward: a full hold still takes the part (play-test 2)", RunSim.apply(state, setup, [RunSim.PICK, 0]) and state.overfull())
	_check("an overfull hold blocks travel", RunSim.destinations(state).is_empty())
	var before_scrap: int = state.scrap
	_check("scrapping a part pays by rarity (servo, uncommon: 6)", RunSim.apply(state, setup, [RunSim.SCRAP_PART, 1])
		and state.scrap == before_scrap + 6)
	_check("and once the hold fits, travel is open again", not state.overfull() and not RunSim.destinations(state).is_empty())
	state.pending = {"kind": "reward", "options": ["ar_railgun"]}
	_check("reward: skipping is always allowed", RunSim.apply(state, setup, [RunSim.PICK, -1]) and state.pending.is_empty())
	# Workshop.
	state.pending = {"kind": "workshop"}
	state.crew[0]["hp"] = 5
	state.crew[1]["hp"] = 5
	state.scrap = 100
	_check("workshop: repair patches every machine for one price", RunSim.apply(state, setup, [RunSim.REPAIR])
		and int(state.crew[0]["hp"]) == 8 and int(state.crew[1]["hp"]) == 8 and state.scrap == 92)
	for member: Dictionary in state.crew:
		member["hp"] = RunSim.max_hp(setup, member)
	_check("workshop: nothing to repair at full HP", not RunSim.apply(state, setup, [RunSim.REPAIR]))
	state.scrap = 50
	_check("workshop: expanding the hold costs 10 and adds 2", RunSim.apply(state, setup, [RunSim.EXPAND_HOLD])
		and state.hold_size == 10 and state.scrap == 40)
	_check("workshop: the next expansion costs more (16)", RunSim.expand_cost(state, setup) == 16)
	_check("workshop: leave", RunSim.apply(state, setup, [RunSim.LEAVE]) and state.pending.is_empty())


func _test_fight_feeds_the_run() -> void:
	var setup: RunSetup = _setup(21)
	var state: RunState = RunSim.start(setup)
	var fight_site: int = -1
	for id: int in RunSim.destinations(state):
		if String(state.site(id)["type"]) == "skirmish":
			fight_site = id
	if fight_site < 0:
		fight_site = RunSim.destinations(state)[0]
		state.sites[fight_site]["type"] = "skirmish"
	state.crew[0]["hp"] = 6
	RunSim.apply(state, setup, [RunSim.TRAVEL, fight_site])
	_check("a fight site sets a fight pending", String(state.pending.get("kind", "")) == "fight")
	_check("every fight has an objective", ["rout", "defend", "salvage"].has(String(state.pending["fight"]["objective"]["type"])))
	var combat_setup: CombatSetup = RunSim.fight_setup(state, setup)
	_check("the fight builds with no errors %s" % [combat_setup.errors], combat_setup.errors.is_empty())
	_check("a machine enters the fight with its run HP (6)", combat_setup.units[0].hp == 6)
	_check("an unfinished fight is refused", not RunSim.apply(state, setup, [RunSim.FIGHT, []]))
	var actions: Array = RunBot.play_fight(combat_setup)
	var result: CombatState = CombatSim.replay(combat_setup, actions)
	var scrap_before: int = state.scrap
	_check("a finished fight is accepted", RunSim.apply(state, setup, [RunSim.FIGHT, actions]))
	var first: GridUnit = result.unit(0)
	_check("the run takes each machine's HP from the replayed fight",
		(first.alive and int(state.crew[0]["hp"]) == first.hp) or (not first.alive and not bool(state.crew[0]["alive"])))
	_check("scrap from piles is banked", state.scrap >= scrap_before + result.scrap_collected)
	if result.outcome == CombatState.WON:
		_check("a won fight offers salvage", String(state.pending.get("kind", "")) == "reward")
	else:
		_check("a lost objective with the crew alive moves on with no salvage", state.pending.is_empty() or state.outcome != RunState.ONGOING)


func _test_wreck_and_rebuild() -> void:
	var setup: RunSetup = _setup(5)
	var state: RunState = RunSim.start(setup)
	var member: Dictionary = state.crew[1]
	member["alive"] = false
	member["parts"] = [String(member["parts"][0]), "", "", "", ""]
	state.pending = {"kind": "workshop"}
	state.scrap = 50
	_check("a wreck cannot be refitted", not RunSim.apply(state, setup, [RunSim.REFIT, 1, 2, 0]))
	_check("the workshop rebuilds a wreck for scrap", RunSim.apply(state, setup, [RunSim.REBUILD, 1]) and bool(member["alive"]) and state.scrap == 30)
	_check("the rebuilt machine keeps its chassis and nothing else, at half HP",
		String(member["parts"][0]) != "" and String(member["parts"][2]) == "" and int(member["hp"]) == RunSim.max_hp(setup, member) / 2)
	state.pending = {}
	var fight: Dictionary = RunSim._make_fight(state, setup, 1, "skirmish")
	var built: CombatSetup = CombatSetup.build(fight, setup.combat_rules, setup.parts, setup.tiles, setup.wheel, 1)
	_check("a construct with empty sockets still builds into a fight %s" % [built.errors], built.errors.is_empty())
	_check("its empty arms cannot fire", not built.units[1].has_weapon())


## A boss fight that ends without a win (out of rounds) must end the run. It used to leave
## the crew at the gate with no road forward and the road back reclaimed (bot: 3 in 150).
func _test_boss_held() -> void:
	var setup: RunSetup = _setup(33)
	setup.combat_rules = setup.combat_rules.duplicate(true)
	setup.combat_rules["max_rounds"] = 1
	var state: RunState = RunSim.start(setup)
	var boss: int = state.sites.size() - 1
	_check("the last site is the boss", String(state.site(boss)["type"]) == "boss")
	state.current = boss
	state.site(boss)["visited"] = true
	state.pending = {"kind": "fight", "site_type": "boss", "fight": RunSim._make_fight(state, setup, boss, "boss")}
	var combat_setup: CombatSetup = RunSim.fight_setup(state, setup)
	var actions: Array = [[CombatSim.ACT_END, 0, 0, 0]]
	var result: CombatState = CombatSim.replay(combat_setup, actions)
	_check("the boss fight times out with the crew alive (precondition)",
		result.outcome == CombatState.LOST and not result.crew(GridUnit.TEAM_PLAYER).is_empty())
	RunSim.apply(state, setup, [RunSim.FIGHT, actions])
	_check("a boss fight that is not won ends the run", state.outcome == RunState.LOST)


## Play-test 3: scrap buys machine levels.
func _test_levels() -> void:
	var setup: RunSetup = _setup(8)
	var state: RunState = RunSim.start(setup)
	var member: Dictionary = state.crew[0]
	var full: int = RunSim.max_hp(setup, member)
	state.scrap = 14
	_check("a level cannot be bought without the scrap (15)", not RunSim.apply(state, setup, [RunSim.LEVEL_UP, 0]))
	state.scrap = 100
	_check("a level costs 15 scrap", RunSim.apply(state, setup, [RunSim.LEVEL_UP, 0]) and state.scrap == 85 and int(member["level"]) == 1)
	_check("level 1 adds 2 max HP and 2 HP now", RunSim.max_hp(setup, member) == full + 2 and int(member["hp"]) == full + 2)
	RunSim.apply(state, setup, [RunSim.LEVEL_UP, 0])
	RunSim.apply(state, setup, [RunSim.LEVEL_UP, 0])
	_check("levels cost 25 and 40, and stop at 3", int(member["level"]) == 3 and state.scrap == 20
		and not RunSim.apply(state, setup, [RunSim.LEVEL_UP, 0]))
	var fight_site: int = RunSim.destinations(state)[0]
	state.sites[fight_site]["type"] = "skirmish"
	RunSim.apply(state, setup, [RunSim.TRAVEL, fight_site])
	_check("no levels bought mid-fight", not RunSim.apply(state, setup, [RunSim.LEVEL_UP, 1]))
	var combat: CombatSetup = RunSim.fight_setup(state, setup)
	_check("a level-3 machine fights with +7 max HP and +1 damage (2 + 2 + 3; damage at level 2)",
		combat.units[0].max_hp == full + 7 and RunSim.level_bonus(setup, member, "damage") == 1)


## Play-test 4: the crew is built from a bench at the start of a run.
func _test_assembly() -> void:
	var setup: RunSetup = _setup(12)
	var state: RunState = RunSim.start(setup)
	var defaults: Array = []
	for member: Dictionary in state.crew:
		defaults.append((member["parts"] as Array).duplicate())
	_check("the default crew is itself a legal build", RunSim.apply(RunSim.start(setup), setup, [RunSim.ASSEMBLE, defaults]))
	var twin: Array = [["ch_brute", "co_slug", "ar_hammer", "ar_ripper", "mo_scavenger"],
		["ch_brute", "co_arc", "ar_pulse", "ar_scatter", "mo_ablative"],
		["ch_courier", "co_dynamo", "ar_scanner", "ar_hammer", "mo_governor"]]
	_check("common parts are on the bench without limit", RunSim.apply(state, setup, [RunSim.ASSEMBLE, twin]))
	_check("the frame names the machine; a second on the same frame is II",
		String(state.crew[0]["name"]) == "Brute" and String(state.crew[1]["name"]) == "Brute II" and String(state.crew[2]["name"]) == "Courier")
	_check("each machine starts at its new full HP", int(state.crew[2]["hp"]) == RunSim.max_hp(setup, state.crew[2]))
	_check("only once", not RunSim.apply(state, setup, [RunSim.ASSEMBLE, twin]))
	var fresh: RunState = RunSim.start(setup)
	var two_saws: Array = [["ch_brute", "co_slug", "ar_saw", "ar_saw", "mo_scavenger"], defaults[1], defaults[2]]
	_check("an uncommon from the defaults is on the bench once, not twice", not RunSim.apply(fresh, setup, [RunSim.ASSEMBLE, two_saws]))
	var rare: Array = [["ch_brute", "co_slug", "ar_railgun", "ar_hammer", "mo_scavenger"], defaults[1], defaults[2]]
	_check("rarer parts are not on the bench", not RunSim.apply(fresh, setup, [RunSim.ASSEMBLE, rare]))
	var wrong_slot: Array = [["ch_brute", "ar_hammer", "ar_hammer", "ar_hammer", "mo_scavenger"], defaults[1], defaults[2]]
	_check("a part must fit its socket", not RunSim.apply(fresh, setup, [RunSim.ASSEMBLE, wrong_slot]))
	var moved: RunState = RunSim.start(setup)
	RunSim.apply(moved, setup, [RunSim.TRAVEL, RunSim.destinations(moved)[0]])
	_check("not after the first move", not RunSim.apply(moved, setup, [RunSim.ASSEMBLE, defaults]))


func _test_refit() -> void:
	var setup: RunSetup = _setup(3)
	var state: RunState = RunSim.start(setup)
	state.cargo.append("ar_railgun")
	state.cargo.append("co_mag")
	var old_arm: String = String(state.crew[0]["parts"][3])
	_check("a part only fits its own slot", not RunSim.apply(state, setup, [RunSim.REFIT, 0, 3, 1]))
	_check("refit swaps a socket with the hold", RunSim.apply(state, setup, [RunSim.REFIT, 0, 3, 0])
		and String(state.crew[0]["parts"][3]) == "ar_railgun" and state.cargo[0] == old_arm)
	_check("unfitting puts the part in the hold", RunSim.apply(state, setup, [RunSim.REFIT, 0, 4, -1])
		and String(state.crew[0]["parts"][4]) == "")
	_check("a chassis cannot be unfitted", not RunSim.apply(state, setup, [RunSim.REFIT, 0, 0, -1]))
	state.pending = {"kind": "fight", "site_type": "skirmish", "fight": {}}
	_check("no refitting in the middle of a fight", not RunSim.apply(state, setup, [RunSim.REFIT, 0, 3, 0]))


func _test_determinism_and_save() -> void:
	var setup: RunSetup = _setup(99)
	var state: RunState = RunSim.start(setup)
	var actions: Array = []
	var guard: int = 0
	while state.outcome == RunState.ONGOING and guard < 400:
		var action: Array = RunBot.next_action(state, setup)
		if not RunSim.apply(state, setup, action):
			break
		actions.append(action)
		guard += 1
	_check("a bot run finishes", state.outcome != RunState.ONGOING)
	var again: RunState = RunSim.replay(_setup(99), actions)
	_check("replaying the run's actions reproduces it exactly", again.fingerprint() == state.fingerprint())

	# The save format: the actions through JSON and back. JSON turns every int into a
	# float, and a run must survive that or no save would ever load.
	var text: String = RunStore.encode(99, "test", actions, [])
	var loaded: Dictionary = RunStore.decode(text)
	var reloaded: RunState = RunSim.replay(_setup(int(loaded["seed"])), loaded["actions"])
	_check("a run survives the JSON round trip", reloaded.fingerprint() == state.fingerprint())
	var partial: RunState = RunSim.replay(setup, actions.slice(0, actions.size() / 2))
	var partial_text: String = RunStore.encode(99, "test", actions.slice(0, actions.size() / 2), [])
	var partial_loaded: RunState = RunSim.replay(setup, RunStore.decode(partial_text)["actions"])
	_check("a run saved halfway resumes at the same point", partial.fingerprint() == partial_loaded.fingerprint())


func _check(label: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s" % label)
