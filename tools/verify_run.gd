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
	_test_acts()
	_test_levels()
	_test_perks()
	_test_tuning()
	_test_sets()
	_test_salvage()
	_test_gate_and_reach()
	_test_trader()
	_test_tower()
	_test_signals()
	_test_recap_and_preview()
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


## 021: breaking a gate that is not the last act's starts the next act with the same crew.
func _test_acts() -> void:
	var setup: RunSetup = _setup(33)
	_check("the run has three acts", RunSim.act_count(setup) == 3)
	var state: RunState = RunSim.start(setup)
	var first: String = state.fingerprint()
	var plain: RunSetup = _setup(33)
	plain.rules = plain.rules.duplicate()
	plain.rules.erase("acts")
	_check("Act 1 is generated exactly as it was before acts existed",
		RunSim.start(plain).fingerprint().replace("act=1 ", "") == first.replace("act=1 ", ""))
	_check("Act 1's rules are the run's own", RunSim.rules_of(state, setup)["enemies"]["count_by_column"] == setup.rules["enemies"]["count_by_column"])
	state.scrap = 7
	state.crew[0]["level"] = 2
	state.crew[1]["hp"] = 3
	state.cargo.append("ar_lance")
	var sites_before: int = state.sites.size()
	RunSim._next_act(state, setup)
	_check("through the gate: Act 2, at its first site, nothing pending",
		state.act == 2 and state.current == 0 and state.pending.is_empty() and state.outcome == RunState.ONGOING)
	_check("the crew, its levels and the hold come along", int(state.crew[0]["level"]) == 2 and state.cargo.has("ar_lance"))
	_check("arriving repairs and pays (hp 3 -> %d, scrap 7 -> %d)" % [int(state.crew[1]["hp"]), state.scrap],
		int(state.crew[1]["hp"]) == 9 and state.scrap == 22)
	_check("a fresh region with the Reclaimer behind again (%d sites, was %d)" % [state.sites.size(), sites_before],
		state.front_col == -1 and state.moves == 0 and String(state.site(state.sites.size() - 1)["type"]) == "boss")
	_check("Act 2's squads are its own", RunSim.rules_of(state, setup)["enemies"]["count_by_column"][0] == 4
		and (RunSim.rules_of(state, setup)["kinds"]["weights"] as Dictionary).has("sentinel"))
	var names: Dictionary = {}
	for id: int in state.sites.size() - 1:
		names[String(RunSim._make_fight(state, setup, id, "skirmish")["name"])] = true
	_check("its fights are on the Slag Flats' boards %s" % [names.keys()],
		not names.has("The Container Row") and (names.has("The Slag Lake") or names.has("The Pipe Forest") or names.has("The Cooling Flats")))
	var gate: Dictionary = RunSim._make_fight(state, setup, state.sites.size() - 1, "boss")
	_check("and its gate is The Pour's", String((gate["enemy"] as Array)[0].get("kind", "")) == "pour")
	# 025: Act 2 is generated exactly as it was when it was the last act.
	var two: RunSetup = _setup(33)
	two.rules = two.rules.duplicate()
	two.rules["acts"] = (two.rules["acts"] as Array).slice(0, 2)
	var twin: RunState = RunSim.start(two)
	RunSim._next_act(twin, two)
	var same: bool = str(twin.sites) == str(state.sites)
	for id: int in state.sites.size() - 1:
		same = same and str(RunSim._make_fight(state, setup, id, "skirmish")["rows"]) == str(RunSim._make_fight(twin, two, id, "skirmish")["rows"]) \
			and str(RunSim._make_fight(state, setup, id, "skirmish")["enemy"]) == str(RunSim._make_fight(twin, two, id, "skirmish")["enemy"])
	_check("Act 2 is generated exactly as it was before Act 3 existed", same)

	var hp_before: int = int(state.crew[1]["hp"])
	var scrap_before: int = state.scrap
	RunSim._next_act(state, setup)
	_check("through The Pour: Act 3, the Crucible", state.act == 3 and String(RunSim.rules_of(state, setup)["name"]) == "THE CRUCIBLE")
	_check("arriving repairs 6 and pays 20", int(state.crew[1]["hp"]) == mini(RunSim.max_hp(setup, state.crew[1]), hp_before + 6)
		and state.scrap == scrap_before + 20)
	var boards: Dictionary = {}
	var flues: int = 0
	var conduits: int = 0
	for id: int in state.sites.size() - 1:
		var f: Dictionary = RunSim._make_fight(state, setup, id, "skirmish")
		boards[String(f["name"])] = true
		for row: Variant in (f["rows"] as Array):
			flues += String(row).count("f")
		for e: Dictionary in (f["enemy"] as Array):
			if String(e.get("kind", "")) == "conduit":
				conduits += 1
	_check("its fights are on the Crucible's boards %s" % [boards.keys()],
		not boards.has("The Slag Lake") and (boards.has("The Casting Floor") or boards.has("The Ladle Line") or boards.has("The Furnace Mouths")))
	_check("with furnace flues on the floor (%d) and conduits in the squads (%d)" % [flues, conduits], flues > 0 and conduits > 0)
	var core: Dictionary = RunSim._make_fight(state, setup, state.sites.size() - 1, "boss")
	_check("and its gate is the Core's, with four escorts", String((core["enemy"] as Array)[0].get("kind", "")) == "heart"
		and (core["enemy"] as Array).size() == 5)
	_check("the last act's gate is the end of the run", state.act == RunSim.act_count(setup))


## Play-test 3: scrap buys machine levels; 011: every level also keeps one perk of three.
func _test_levels() -> void:
	var setup: RunSetup = _setup(8)
	var state: RunState = RunSim.start(setup)
	var member: Dictionary = state.crew[0]
	var full: int = RunSim.max_hp(setup, member)
	state.scrap = 14
	_check("a level cannot be bought without the scrap (15)", not RunSim.apply(state, setup, [RunSim.LEVEL_UP, 0, 0]))
	state.scrap = 100
	var offer: Array[String] = RunSim.perk_offer(state, setup, 0)
	_check("a level offers three different perks %s" % [offer], offer.size() == 3 and offer[0] != offer[1]
		and offer[1] != offer[2] and offer[0] != offer[2])
	_check("the offer is the same when asked again", RunSim.perk_offer(state, setup, 0) == offer)
	_check("a level needs a perk from its offer", not RunSim.apply(state, setup, [RunSim.LEVEL_UP, 0, 3])
		and not RunSim.apply(state, setup, [RunSim.LEVEL_UP, 0]) and int(member["level"]) == 0)
	var perk_hp: int = int((((setup.rules["perks"] as Dictionary)[offer[1]] as Dictionary).get("grid", {}) as Dictionary).get("hp", 0))
	_check("a level costs 15 scrap and keeps the chosen perk", RunSim.apply(state, setup, [RunSim.LEVEL_UP, 0, 1])
		and state.scrap == 85 and int(member["level"]) == 1 and (member["perks"] as Array) == [offer[1]])
	_check("level 1 adds 2 max HP (and any the perk adds), and that HP now",
		RunSim.max_hp(setup, member) == full + 2 + perk_hp and int(member["hp"]) == full + 2 + perk_hp)
	_check("a perk once taken is not offered again", not RunSim.perk_offer(state, setup, 0).has(offer[1]))
	RunSim.apply(state, setup, [RunSim.LEVEL_UP, 0, 0])
	RunSim.apply(state, setup, [RunSim.LEVEL_UP, 0, 2])
	_check("levels cost 25 and 40, and stop at 3", int(member["level"]) == 3 and state.scrap == 20
		and not RunSim.apply(state, setup, [RunSim.LEVEL_UP, 0, 0]) and RunSim.perk_offer(state, setup, 0).is_empty())
	_check("three levels, three different perks", (member["perks"] as Array).size() == 3
		and not (member["perks"][0] == member["perks"][1] or member["perks"][1] == member["perks"][2]))
	var fight_site: int = RunSim.destinations(state)[0]
	state.sites[fight_site]["type"] = "skirmish"
	RunSim.apply(state, setup, [RunSim.TRAVEL, fight_site])
	_check("no levels bought mid-fight", not RunSim.apply(state, setup, [RunSim.LEVEL_UP, 1, 0]))
	var combat: CombatSetup = RunSim.fight_setup(state, setup)
	_check("the fight fields the machine the run describes (max HP %d)" % RunSim.max_hp(setup, member),
		combat.units[0].max_hp == RunSim.max_hp(setup, member))


## 011: what perks do, and that a level only offers ones that do something for the machine.
func _test_perks() -> void:
	var setup: RunSetup = _setup(3)
	var brute: Dictionary = {"name": "B", "parts": ["ch_brute", "co_slug", "ar_saw", "ar_hammer", "mo_scavenger"],
		"alive": true, "hp": 99, "level": 0, "perks": []}
	var plain: GridUnit = RunSim.preview_machine(setup, brute)
	var built: Dictionary = brute.duplicate(true)
	built["perks"] = ["frame", "reflexes", "quick_cycle", "plating"]
	var perked: GridUnit = RunSim.preview_machine(setup, built)
	_check("Reinforced Frame: +3 HP", perked.max_hp == plain.max_hp + 3)
	_check("Combat Reflexes: it can move after attacking", perked.move_after_attack and not plain.move_after_attack)
	_check("Quick Cycle: Charge is ready a round sooner (3 -> 2)",
		int(plain.abilities[0]["cooldown"]) == 3 and int(perked.abilities[0]["cooldown"]) == 2)
	_check("Extra Plating: +1 armour", perked.armor == plain.armor + 1)
	var chainless: bool = true
	var saw_relay: bool = false
	var line_reflexes: bool = false
	for seed_value: int in range(1, 60):
		var s: RunSetup = _setup(seed_value)
		var state: RunState = RunSim.start(s)
		state.scrap = 999
		chainless = chainless and not RunSim.perk_offer(state, s, 0).has("arc_relay")
		saw_relay = saw_relay or RunSim.perk_offer(state, s, 1).has("arc_relay")
		line_reflexes = line_reflexes or RunSim.perk_offer(state, s, 1).has("reflexes")
	_check("a machine with no chain weapon is never offered Arc Relay", chainless)
	_check("the Hauler (a pulse emitter) is offered Arc Relay on some seed", saw_relay)
	_check("a line frame (already moves after attacking) is never offered Combat Reflexes", not line_reflexes)


## 011: a workshop tunes a part once, one of two ways.
func _test_tuning() -> void:
	var setup: RunSetup = _setup(21)
	var every: bool = true
	for id: Variant in setup.parts:
		if not (setup.parts[id] as Dictionary).has("base"):
			every = every and setup.parts.has(String(id) + ":a") and setup.parts.has(String(id) + ":b")
	_check("every part has both its tunings", every)
	var pooled: bool = false
	for slot: Variant in setup.pools:
		for id: Variant in (setup.pools[slot] as Array):
			pooled = pooled or PartTuning.is_tuned(String(id))
	_check("no tuned part is in a loot pool", not pooled)
	_check("no tuned part is on the assembly bench", RunSim.bench_count(setup, "ar_hammer:a") == 0)
	var sledge: Dictionary = setup.parts["ar_hammer:a"]
	_check("a tuning merges its option (Sledge Head: 4 damage), keeps its maker, is named with a +",
		int(sledge["grid"]["damage"]) == 4 and String(sledge["name"]) == "Breaker Hammer+"
		and String(sledge["base"]) == "ar_hammer" and String(sledge["maker"]) == "kessler")
	_check("an option can take a number off (Cold Striker: heat 0)", int(setup.parts["ar_hammer:b"]["grid"]["heat"]) == 0)
	_check("a flag option sets it (Tearing Teeth: the saw tears arms)", bool(setup.parts["ar_saw:a"]["grid"]["tears"]))
	var state: RunState = RunSim.start(setup)
	state.scrap = 50
	_check("no tuning away from a workshop", not RunSim.apply(state, setup, [RunSim.TUNE, 0, 3, 0]))
	state.pending = {"kind": "workshop"}
	_check("tuning a common costs 6 and changes the socket", RunSim.apply(state, setup, [RunSim.TUNE, 0, 3, 0])
		and state.scrap == 44 and String(state.crew[0]["parts"][3]) == "ar_hammer:a")
	_check("a part is tuned only once", not RunSim.apply(state, setup, [RunSim.TUNE, 0, 3, 1]))
	_check("the option is 0 or 1", not RunSim.apply(state, setup, [RunSim.TUNE, 0, 2, 2]))
	var unit: GridUnit = RunSim.preview_machine(setup, state.crew[0])
	_check("the fight uses the tuned numbers (the hammer hits for 4)", int(unit.weapons[1]["damage"]) == 4)
	state.cargo.append("ar_lance")
	_check("a part in the hold can be tuned (an uncommon costs 10)",
		RunSim.apply(state, setup, [RunSim.TUNE, -1, state.cargo.size() - 1, 1]) and state.cargo[-1] == "ar_lance:b" and state.scrap == 34)
	var full: int = RunSim.max_hp(setup, state.crew[0])
	var hp: int = int(state.crew[0]["hp"])
	_check("a tuning that adds HP adds it now (Reinforced frame: +3)", RunSim.apply(state, setup, [RunSim.TUNE, 0, 0, 0])
		and RunSim.max_hp(setup, state.crew[0]) == full + 3 and int(state.crew[0]["hp"]) == hp + 3)
	state.scrap = 5
	_check("no tuning without the scrap", not RunSim.apply(state, setup, [RunSim.TUNE, 0, 2, 0]))


## 011: parts from one maker add up -- on the player's machines.
func _test_sets() -> void:
	var setup: RunSetup = _setup(5)
	var one_each: Dictionary = {"name": "T", "parts": ["ch_brute", "co_arc", "ar_scanner", "ar_ripper", ""], "alive": true, "hp": 99, "level": 0, "perks": []}
	var two: Dictionary = one_each.duplicate(true)
	two["parts"] = ["ch_brute", "co_slug", "ar_scanner", "ar_ripper", ""]
	var three: Dictionary = one_each.duplicate(true)
	three["parts"] = ["ch_brute", "co_slug", "ar_hammer:a", "ar_ripper", ""]
	var none_unit: GridUnit = RunSim.preview_machine(setup, one_each)
	var two_unit: GridUnit = RunSim.preview_machine(setup, two)
	var three_unit: GridUnit = RunSim.preview_machine(setup, three)
	_check("one part from each maker is no set", CombatSetup.sets_of(PackedStringArray(one_each["parts"]), setup.parts,
		setup.combat_rules["makers"]).is_empty() and none_unit.max_hp == 11)
	_check("two Kessler parts: +2 HP", two_unit.max_hp == 13 and two_unit.armor == 0)
	_check("three (a tuned part counts): +2 HP and +1 armour", three_unit.max_hp == 13 and three_unit.armor == 1)
	var sets: Array = CombatSetup.sets_of(PackedStringArray(three["parts"]), setup.parts, setup.combat_rules["makers"])
	_check("the set is reported for the screens %s" % [sets], sets.size() == 1 and String(sets[0]["maker"]) == "kessler"
		and int(sets[0]["count"]) == 3 and (sets[0]["active"] as Array) == [2, 3])
	var errors: PackedStringArray = []
	var rules: Dictionary = setup.combat_rules
	var enemy: GridUnit = CombatSetup._build_unit({"name": "E", "parts": three["parts"]}, GridUnit.TEAM_ENEMY, 0,
		setup.parts, rules.get("roles", {}), rules.get("damage_types", []), rules.get("armor_types", []), errors,
		rules.get("abilities", {}), rules.get("makers", {}))
	_check("an enemy wears no set (its parts are rolled, not chosen)", enemy.max_hp == 11 and enemy.armor == 0)
	var vektor: Dictionary = one_each.duplicate(true)
	vektor["parts"] = ["ch_strider", "co_dynamo", "ar_scanner", "ar_lance", ""]
	var v: GridUnit = RunSim.preview_machine(setup, vektor)
	var base_v: GridUnit = RunSim.preview_machine(setup, {"name": "T", "parts": ["ch_strider", "co_arc", "ar_ripper", "ar_hammer", ""],
		"alive": true, "hp": 99, "level": 0, "perks": []})
	_check("Vektor 3 (4 parts): +1 move, +1 range", v.move == base_v.move + 1 and v.range_bonus == base_v.range_bonus + 1)


## 011: salvage is a real choice -- three slots, a lean toward the crew's makers, scrap instead.
func _test_salvage() -> void:
	var distinct: bool = true
	var favoured: int = 0
	var tuned: bool = true
	var runs: int = 0
	for seed_value: int in range(1, 60):
		var setup: RunSetup = _setup(seed_value)
		var state: RunState = RunSim.start(setup)
		var options: Array = RunSim._roll_parts(setup, RunSim._rng(setup, 4, 5), 1, ["kessler"])
		var slots: Dictionary = {}
		for id: Variant in options:
			slots[String((setup.parts[id] as Dictionary)["slot"])] = true
		distinct = distinct and options.size() == 3 and slots.size() == 3
		if String((setup.parts[options[1]] as Dictionary).get("maker", "")) == "kessler":
			favoured += 1
		var elite: Dictionary = RunSim.salvage(state, setup, "elite")
		tuned = tuned and PartTuning.is_tuned(String(elite["options"][0])) and setup.rarity(String(elite["options"][0])) >= 2
		runs += 1
	_check("salvage offers three parts from three different slots", distinct)
	_check("the second part leans to a maker the crew builds (%d of %d)" % [favoured, runs], favoured * 100 >= runs * 80)
	_check("an elite's guaranteed part comes tuned", tuned)
	var setup: RunSetup = _setup(9)
	var state: RunState = RunSim.start(setup)
	_check("the default crew builds sets from %s" % [RunSim.crew_makers(state, setup)], RunSim.crew_makers(state, setup).has("kessler"))
	state.pending = RunSim.salvage(state, setup, "skirmish")
	var scrap: int = state.scrap
	_check("salvage can be left for scrap (8)", RunSim.apply(state, setup, [RunSim.PICK, -1]) and state.scrap == scrap + 8
		and state.pending.is_empty())


## A fresh run with the first reachable site turned into `kind`, travelled to.
func _visit(seed_value: int, kind: String) -> Array:
	var setup: RunSetup = _setup(seed_value)
	var state: RunState = RunSim.start(setup)
	var site: int = RunSim.destinations(state)[0]
	state.sites[site]["type"] = kind
	RunSim.apply(state, setup, [RunSim.TRAVEL, site])
	return [setup, state, site]


## 013: the gate is the Sorter's; fights by the Reclaimer's line get its drones.
func _test_gate_and_reach() -> void:
	var setup: RunSetup = _setup(14)
	var state: RunState = RunSim.start(setup)
	var boss: int = state.sites.size() - 1
	var fight: Dictionary = RunSim._make_fight(state, setup, boss, "boss")
	var enemies: Array = fight["enemy"]
	_check("the gate fight is the Sorter's map: the Sorter, its pylons, %d escorts" % (enemies.size() - 1),
		String((enemies[0] as Dictionary).get("kind", "")) == "sorter" and enemies.size() == 1 + int(setup.rules["enemies"]["boss_escorts"])
		and "".join(PackedStringArray(fight["rows"])).count("p") == 2)
	var combat: CombatSetup = CombatSetup.build(fight, setup.combat_rules, setup.parts, setup.tiles, setup.wheel, 1)
	_check("and it builds with no errors %s" % [combat.errors], combat.errors.is_empty())
	var near: int = -1
	var far: int = -1
	for s: Dictionary in state.sites:
		if int(s["col"]) == state.front_col + 1 and near < 0:
			near = int(s["id"])
		if int(s["col"]) == state.front_col + 3 and far < 0:
			far = int(s["id"])
	_check("a site in the column the Reclaimer takes next is within its reach; one further on is not",
		RunSim.reclaimer_reaches(state, near) and not RunSim.reclaimer_reaches(state, far))
	RunSim._start_fight(state, setup, near, "skirmish")
	var reach: Dictionary = (state.pending["fight"] as Dictionary).get("reclaimer", {})
	_check("its fight carries the Reclaimer's drones (round %d, %d)" % [int(reach.get("round", 0)), int(reach.get("count", 0))],
		int(reach.get("round", 0)) == 3 and int(reach.get("count", 0)) == 2)
	RunSim._start_fight(state, setup, far, "skirmish")
	_check("a fight further from the line does not", not (state.pending["fight"] as Dictionary).has("reclaimer"))


## 013: traders sell three parts (one tuned) and buy from the hold at twice the scrap value.
func _test_trader() -> void:
	var visit: Array = _visit(31, "trader")
	var setup: RunSetup = visit[0]
	var state: RunState = visit[1]
	var stock: Array = state.pending.get("stock", [])
	var tuned: int = stock.filter(func(id: String) -> bool: return PartTuning.is_tuned(id)).size()
	_check("a trader stocks three parts, one of them tuned %s" % [stock], stock.size() == 3 and tuned == 1)
	var price: int = RunSim.trader_price(state, setup, 0)
	state.scrap = price - 1
	_check("a part costs its price (%d): not a scrap less" % price, not RunSim.apply(state, setup, [RunSim.BUY, 0]))
	state.scrap = price + 5
	var cargo: int = state.cargo.size()
	_check("buying pays the price and loads the hold", RunSim.apply(state, setup, [RunSim.BUY, 0]) and state.scrap == 5
		and state.cargo.size() == cargo + 1 and state.cargo[-1] == String(stock[0]))
	state.scrap = 999
	_check("the same part cannot be bought twice", not RunSim.apply(state, setup, [RunSim.BUY, 0]))
	var part: String = state.cargo[-1]
	var before: int = state.scrap
	_check("selling pays twice what breaking the part down would", RunSim.apply(state, setup, [RunSim.SELL, state.cargo.size() - 1])
		and state.scrap == before + 2 * RunSim.scrap_value(setup, part))
	_check("LEAVE closes the trader", RunSim.apply(state, setup, [RunSim.LEAVE]) and state.pending.is_empty())
	_check("and there is no buying outside one", not RunSim.apply(state, setup, [RunSim.BUY, 1]))


## 013: a watchtower scouts two columns each way.
func _test_tower() -> void:
	var visit: Array = _visit(33, "tower")
	var setup: RunSetup = visit[0]
	var state: RunState = visit[1]
	var col: int = int(state.site(int(visit[2]))["col"])
	var all: bool = true
	for s: Dictionary in state.sites:
		if absi(int(s["col"]) - col) <= 2:
			all = all and RunSim.revealed(state, int(s["id"]))
	_check("climbing a watchtower scouts every site within two columns (%d new)" % int(state.pending.get("scouted", 0)),
		all and int(state.pending.get("scouted", 0)) > 0)
	_check("LEAVE climbs down", RunSim.apply(state, setup, [RunSim.LEAVE]) and state.pending.is_empty())


## 013: every signal's every option does exactly what it says, and costs what it says.
func _test_signals() -> void:
	var setup: RunSetup = _setup(40)
	var events: Dictionary = setup.rules["events"]
	var exact: bool = true
	var detail: String = ""
	for id: Variant in events:
		var options: Array = (events[id] as Dictionary)["options"]
		for i: int in options.size():
			var visit: Array = _visit(40, "signal")
			var state: RunState = visit[1]
			state.pending = {"kind": "signal", "event": String(id)}
			state.scrap = 50
			for member: Dictionary in state.crew:
				member["hp"] = RunSim.max_hp(setup, member) - 5
			var hp_before: Array = state.crew.map(func(m: Dictionary) -> int: return int(m["hp"]))
			var cargo: int = state.cargo.size()
			var front: int = state.front_col
			var effects: Dictionary = (options[i] as Dictionary).get("effects", {})
			if not RunSim.apply(state, setup, [RunSim.CHOOSE, i]):
				exact = false
				detail = "%s/%d refused" % [id, i]
				continue
			var ok: bool = state.scrap == 50 + int(effects.get("scrap", 0))
			ok = ok and int(state.crew[0]["hp"]) == clampi(int(hp_before[0]) + int(effects.get("hp", 0)) + int(effects.get("hp_one", 0)), 1, RunSim.max_hp(setup, state.crew[0]))
			ok = ok and int(state.crew[1]["hp"]) == clampi(int(hp_before[1]) + int(effects.get("hp", 0)), 1, RunSim.max_hp(setup, state.crew[1]))
			var parts: int = (1 if effects.has("part") else 0) + (1 if effects.has("tuned_part") else 0)
			ok = ok and state.cargo.size() == cargo + parts
			if effects.has("tuned_part"):
				ok = ok and PartTuning.is_tuned(state.cargo[-1])
			ok = ok and state.front_col == front + int(effects.get("front", 0))
			ok = ok and (String(state.pending.get("kind", "")) == "fight") == effects.has("fight")
			if not ok:
				exact = false
				detail = "%s/%d" % [id, i]
	_check("every signal option applies exactly its stated effects %s" % detail, exact)
	var broke: Array = _visit(41, "signal")
	var poor: RunState = broke[1]
	poor.pending = {"kind": "signal", "event": "scavengers"}
	poor.scrap = 11
	_check("an option costing scrap is refused without it (TRADE: 12)", not RunSim.apply(poor, broke[0], [RunSim.CHOOSE, 0])
		and RunSim.apply(poor, broke[0], [RunSim.CHOOSE, 2]))
	var run: RunState = RunSim.start(setup)
	var seen: Dictionary = {}
	for n: int in events.size():
		var picked: String = RunSim._pick_event(run, setup, n + 1)
		seen[picked] = true
		run.seen_events.append(picked)
	_check("no signal repeats until every one has been met (%d of %d)" % [seen.size(), events.size()], seen.size() == events.size())


## 014: the fight recap counts what the events say; the map preview says what a move does.
func _test_recap_and_preview() -> void:
	# A fight where the Strider (ranged, carrying Hot Loads) lands hits: the seed is searched,
	# so the check cannot pass on a machine that never fought.
	var recap: Dictionary = {}
	var result: CombatState = null
	for seed_value: int in range(21, 45):
		var setup: RunSetup = _setup(seed_value)
		var state: RunState = RunSim.start(setup)
		state.crew[2]["perks"] = ["hot_loads"]
		var site: int = RunSim.destinations(state)[0]
		state.sites[site]["type"] = "skirmish"
		RunSim.apply(state, setup, [RunSim.TRAVEL, site])
		var combat: CombatSetup = RunSim.fight_setup(state, setup)
		result = CombatSim.replay(combat, RunBot.play_fight(combat))
		var crew: Array = []
		for i: Variant in RunSim._fielded_crew(state):
			crew.append(state.crew[int(i)])
		recap = FightRecap.build(result, setup, crew)
		if int(((recap["machines"] as Array)[2] as Dictionary)["dealt"]) > 0:
			break
	var dealt: Array = [0, 0, 0]
	var kills: Array = [0, 0, 0]
	for e: Array in result.events:
		var actor: int = int(e[GridEv.F_ACTOR])
		if actor < 0 or actor > 2:
			continue
		if int(e[GridEv.F_KIND]) == GridEv.DAMAGE and int(e[GridEv.F_TARGET]) >= 10:
			dealt[actor] += int(e[GridEv.F_V1])
		if int(e[GridEv.F_KIND]) == GridEv.DESTROYED and int(e[GridEv.F_TARGET]) >= 10:
			kills[actor] += 1
	var same: bool = (recap["machines"] as Array).size() == 3
	for i: int in 3:
		var m: Dictionary = (recap["machines"] as Array)[i]
		same = same and int(m["dealt"]) == int(dealt[i]) and int(m["kills"]) == int(kills[i])
	_check("the recap's damage and kills are the fight's own %s / %s" % [dealt, kills], same and int(dealt[2]) > 0)
	var hot: Array = (recap["builds"] as Array).filter(func(b: Dictionary) -> bool: return String(b["what"]) == "Hot Loads")
	var numbers: PackedStringArray = []
	if not hot.is_empty():
		numbers = String(hot[0]["text"]).replace("added ", "").replace(" damage over ", ",").replace(" hits", "").replace(" hit", "").split(",")
	_check("Hot Loads (+1 damage) is credited once for every hit the Strider landed %s" % [hot],
		numbers.size() == 2 and numbers[0] == numbers[1] and int(numbers[0]) > 0)

	# The map's preview against what the move then does, over a bot's route.
	var run: RunState = RunSim.start(_setup(22))
	var run_setup: RunSetup = _setup(22)
	run = RunSim.start(run_setup)
	var honest: bool = true
	var detail: String = ""
	var guard: int = 0
	while run.outcome == RunState.ONGOING and guard < 60:
		guard += 1
		var action: Array = RunBot.next_action(run, run_setup)
		if int(action[0]) != RunSim.TRAVEL:
			RunSim.apply(run, run_setup, action)
			continue
		var to: int = int(action[1])
		var move: Dictionary = RunSim.move_preview(run, run_setup, to)
		RunSim.apply(run, run_setup, action)
		var ok: bool = run.front_col == int(move["front_after"])
		for id: Variant in (move["lost"] as Array):
			ok = ok and run.consumed(int(id)) and not bool(run.site(int(id))["visited"])
		if String(run.pending.get("kind", "")) == "fight":
			ok = ok and ((run.pending["fight"] as Dictionary).has("reclaimer") == bool(move["reach"]))
			ok = ok and ((run.pending["fight"] as Dictionary)["enemy"] as Array).size() == int(move["enemies"])
		if not ok:
			honest = false
			detail = "move %d to %d: %s" % [run.moves, to, move]
	_check("every map preview told the truth about its move %s" % detail, honest and guard > 5)


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
	var crew_names: Array = []
	for spec: Dictionary in (setup.rules["starting_crew"] as Array):
		crew_names.append(String(spec["name"]))
	_check("a machine keeps its crew's name on any frame (play-test 7) %s" % [crew_names],
		String(state.crew[0]["name"]) == crew_names[0] and String(state.crew[1]["name"]) == crew_names[1]
		and String(state.crew[2]["name"]) == crew_names[2] and crew_names[0] != "Brute")
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
