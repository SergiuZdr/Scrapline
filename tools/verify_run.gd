extends SceneTree

## Run rules: generation, travel and the front, every site type, fights feeding back into
## the run, wrecks and rebuilds, refits, determinism and the save round trip.
##
##   godot --headless --path . --script res://tools/verify_run.gd

var _db: ContentDB
## 085: the seeds of the daily of 2026-10-24 and the contract of its week, pinned: every player gets
## these, so changing the formula changes the yard for everyone.
const DAILY_20750_SEED: int = 16423198
const WEEKLY_2963_SEED: int = 12004024
var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_db = ContentDB.load_all()
	print("")
	print("=== run ===")
	_timed(_test_generation)
	_timed(_test_travel_and_front)
	_timed(_test_sites)
	_timed(_test_fight_feeds_the_run)
	_timed(_test_wreck_and_rebuild)
	_timed(_test_boss_held)
	_timed(_test_acts)
	_timed(_test_tiers_stack)
	_timed(_test_names)
	_timed(_test_objectives_rolled)
	_timed(_test_bigger_boards)
	_timed(_test_legendaries)
	_timed(_test_warlords)
	_timed(_test_new_sites)
	_timed(_test_levels)
	_timed(_test_perks)
	_timed(_test_tuning)
	_timed(_test_sets)
	_timed(_test_salvage)
	_timed(_test_defend_partial)
	_timed(_test_wreck_recovery)
	_timed(_test_gate_and_reach)
	_timed(_test_trader)
	_timed(_test_tower)
	_timed(_test_signals)
	_timed(_test_recap_and_preview)
	_timed(_test_assembly)
	_timed(_test_refit)
	_timed(_test_determinism_and_save)
	_timed(_test_agent_playtest)
	_timed(_test_front_pace)
	_timed(_test_fight_preview)
	_timed(_test_act_conditions)
	_timed(_test_seed_codes)
	_timed(_test_rung_rules)
	_timed(_test_deals)
	_timed(_test_deal_effects)
	_timed(_test_challenges)
	_timed(_test_crew_rules)
	_timed(_test_medals)
	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	print("")
	quit(1 if _failed > 0 else 0)


func _setup(seed_value: int) -> RunSetup:
	return RunSetup.create(_db.parts, _db.tiles, _db.fights, _db.run_rules, _db.combat_rules,
		_db.effectiveness, seed_value)


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
	_check("every fight has an objective", ["rout", "defend", "salvage", "hold", "hack", "survive"].has(String(state.pending["fight"]["objective"]["type"])))
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
	# 034: the run's feats are a count over the fight's own events.
	var destroyed: int = 0
	for e: Array in result.events:
		if int(e[GridEv.F_KIND]) == GridEv.DESTROYED and result.unit(int(e[GridEv.F_TARGET])) != null \
				and result.unit(int(e[GridEv.F_TARGET])).team == GridUnit.TEAM_ENEMY:
			destroyed += 1
	_check("feats: kills are the enemies the fight destroyed (%d / %d)" % [int(state.feats.get("kills", 0)), destroyed],
		int(state.feats.get("kills", 0)) == destroyed and destroyed > 0)
	# 083: guarded wrecks come first; what follows them is what the fight itself pays.
	var after: Dictionary = state.pending
	while String(after.get("kind", "")) == "wreck":
		after = after.get("next", {})
	if result.outcome == CombatState.WON:
		_check("a won fight offers salvage", String(after.get("kind", "")) == "reward")
	else:
		_check("a lost objective with the crew alive moves on with no salvage", after.is_empty() or state.outcome != RunState.ONGOING)


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


## 028: every objective and every yard condition is rolled somewhere, and each fight builds.
func _test_objectives_rolled() -> void:
	var seen: Dictionary = {}
	var mods: Dictionary = {}
	var errors: Array = []
	for seed_value: int in 40:
		var setup: RunSetup = _setup(300 + seed_value)
		var state: RunState = RunSim.start(setup)
		for id: int in state.sites.size() - 1:
			if int(state.sites[id]["col"]) == 0:
				continue
			var f: Dictionary = RunSim._make_fight(state, setup, id, "skirmish")
			seen[String((f["objective"] as Dictionary)["type"])] = true
			for m: Variant in (f.get("modifiers", []) as Array):
				mods[String(m)] = true
			var built: CombatSetup = CombatSetup.build(f, setup.combat_rules, setup.parts, setup.tiles, setup.wheel, 1)
			if not built.errors.is_empty():
				errors.append(built.errors)
	_check("all six objectives are rolled %s" % [seen.keys()], seen.size() == 6)
	_check("all four yard conditions are rolled %s" % [mods.keys()], mods.size() == 4)
	_check("and every such fight builds %s" % [errors.slice(0, 2)], errors.is_empty())


## 032 (play-test 10: "make the battlefield bigger"): a run board is its template plus
## `board.rows` and `board.cols`; everything placed on it is on an open hex.
func _test_bigger_boards() -> void:
	var setup: RunSetup = _setup(5)
	var board: Dictionary = setup.rules.get("board", {})
	var tpl: Dictionary = setup.fights["crane_legs"]
	var wide: Dictionary = RunSim.widen(tpl, board)
	_check("a widened board is board.rows deeper and board.cols wider (%d x %d)" % [String(wide["rows"][0]).length(), (wide["rows"] as Array).size()],
		(wide["rows"] as Array).size() == (tpl["rows"] as Array).size() + int(board.get("rows", 0))
		and String(wide["rows"][0]).length() == String(tpl["rows"][0]).length() + int(board.get("cols", 0)))
	_check("the template itself is untouched", int((tpl["player"][0] as Dictionary)["y"]) == 7)
	var bad: Array = []
	var gaps: Array = []
	for seed_value: int in 30:
		var s2: RunSetup = _setup(900 + seed_value)
		var state: RunState = RunSim.start(s2)
		for id: int in state.sites.size():
			var kind: String = String(state.sites[id]["type"])
			if not ["skirmish", "elite", "arena", "boss", "warlord"].has(kind):
				continue
			var f: Dictionary = RunSim._make_fight(state, s2, id, kind)
			var rows: Array = f["rows"]
			var cells: Array = []
			for spec: Dictionary in (f["player"] as Array) + (f["enemy"] as Array):
				cells.append(Vector2i(int(spec["x"]), int(spec["y"])))
			var o: Dictionary = f["objective"]
			for key: String in ["cells", "caches", "piles"]:
				for c: Variant in (o.get(key, []) as Array):
					cells.append(Vector2i(int((c as Dictionary)["x"]), int((c as Dictionary)["y"])))
			for cell: Vector2i in cells:
				if cell.y < 0 or cell.y >= rows.size() or cell.x < 0 or cell.x >= String(rows[cell.y]).length() \
						or not [".", "w", "r"].has(String(rows[cell.y])[cell.x]) and kind != "boss" and kind != "warlord":
					bad.append([kind, cell])
			# The two sides start further apart than on any template (4 rows at the nearest): at
			# least 6 rows now.
			var top: int = 99
			var low: int = -1
			for spec: Dictionary in (f["player"] as Array):
				top = mini(top, int(spec["y"]))
			for spec: Dictionary in (f["enemy"] as Array):
				low = maxi(low, int(spec["y"]))
			if kind != "boss" and kind != "warlord" and top - low < 6:
				gaps.append([kind, top, low])
	_check("every start and objective hex is on the board and open %s" % [bad.slice(0, 3)], bad.is_empty())
	_check("the two sides start at least 6 rows apart %s" % [gaps.slice(0, 3)], gaps.is_empty())


## 029: a broken gate's hoard holds a legendary; legendaries never reach enemies or the bench.
func _test_legendaries() -> void:
	var setup: RunSetup = _setup(77)
	var state: RunState = RunSim.start(setup)
	var hoard: Dictionary = RunSim.hoard(state, setup)
	_check("a gate's hoard offers a legendary %s" % [hoard["options"]], setup.rarity(String((hoard["options"] as Array)[0])) == 4)
	state.pending = hoard
	var act: int = state.act
	_check("picking from the hoard moves the crew on to the next act", RunSim.apply(state, setup, [RunSim.PICK, 0]) and state.act == act + 1)
	var on_enemies: bool = false
	for seed_value: int in 30:
		var s2: RunSetup = _setup(500 + seed_value)
		var st: RunState = RunSim.start(s2)
		for id: int in st.sites.size():
			for e: Dictionary in (RunSim._make_fight(st, s2, id, "elite")["enemy"] as Array):
				for p: Variant in (e["parts"] as Array):
					if s2.rarity(String(p)) >= 4 or String(p) == "ar_shieldcaster":
						on_enemies = true
	_check("no enemy carries a legendary or a shield caster", not on_enemies)
	_check("no legendary is on the bench", setup.parts.keys().filter(func(id: Variant) -> bool:
		return setup.rarity(String(id)) >= 4 and RunSim.bench_count(setup, String(id)) != 0).is_empty())


## 030: every act has one warlord, its board is the act's, and its hoard keeps the act.
func _test_warlords() -> void:
	var setup: RunSetup = _setup(91)
	var state: RunState = RunSim.start(setup)
	var boards: Array = []
	for act: int in 3:
		var lords: Array = state.sites.filter(func(s: Dictionary) -> bool: return String(s["type"]) == "warlord")
		_check("Act %d has one warlord, known from the start" % (act + 1), lords.size() == 1 and RunSim.revealed(state, int(lords[0]["id"])))
		if lords.size() == 1:
			var f: Dictionary = RunSim._make_fight(state, setup, int(lords[0]["id"]), "warlord")
			boards.append(String(f["name"]))
		if act < 2:
			RunSim._next_act(state, setup)
	# 084 (B7 a'): the three warlords are dealt to the acts in a seeded order, each once.
	var sorted_boards: Array = boards.duplicate()
	sorted_boards.sort()
	_check("each act's warlord is its own, all three dealt once %s" % [boards],
		sorted_boards == ["The Grinder's Yard", "The Magnet King's Lot", "The Twin Furnaces"])
	var hoard: Dictionary = RunSim.hoard(state, setup, false)
	state.pending = hoard
	var act_now: int = state.act
	_check("a warlord's hoard has a rare or better and keeps the act", setup.rarity(String((hoard["options"] as Array)[0])) >= 3
		and RunSim.apply(state, setup, [RunSim.PICK, 0]) and state.act == act_now)
	# 032: a legendary only some of the time (play-test 10: rare+ everywhere by Act 3).
	var legends: int = 0
	for n: int in 60:
		state.current = n % state.sites.size()
		state.moves = n
		# The chance, not the run: 046 makes each legendary come up once a run.
		state.legends.clear()
		state.offered.clear()
		if setup.rarity(String((RunSim.hoard(state, setup, false)["options"] as Array)[0])) == 4:
			legends += 1
	_check("a warlord's hoard holds a legendary some of the time, not always (%d of 60)" % legends, legends > 5 and legends < 45)


## 031: the refinery, the auction and the arena; signals never hand out a legendary by accident.
func _test_new_sites() -> void:
	var setup: RunSetup = _setup(64)
	var state: RunState = RunSim.start(setup)
	state.scrap = 200
	state.cargo.append("ar_ripper")
	var c: int = state.cargo.size() - 1
	state.pending = {"kind": "refinery", "used": false}
	_check("a refinery refines a common into an uncommon of the same slot", RunSim.apply(state, setup, [RunSim.REFINE, c])
		and setup.rarity(state.cargo[c]) == 2 and String((setup.parts[state.cargo[c]] as Dictionary)["slot"]) == "arm" and state.scrap == 185)
	_check("once a visit", not RunSim.apply(state, setup, [RunSim.REFINE, c]))
	state.pending = {"kind": "auction", "used": false}
	var held: int = state.cargo.size()
	_check("an auction crate costs its price and gives an uncommon or better", RunSim.apply(state, setup, [RunSim.BID, 0])
		and state.cargo.size() == held + 1 and setup.rarity(state.cargo[held]) >= 2 and state.scrap == 160)
	_check("once a visit too", not RunSim.apply(state, setup, [RunSim.BID, 1]))
	var kinds: Dictionary = {}
	for seed_value: int in 30:
		var st: RunState = RunSim.start(_setup(700 + seed_value))
		for site: Dictionary in st.sites:
			kinds[String(site["type"])] = true
	_check("refineries, auctions and arenas appear on maps", kinds.has("refinery") and kinds.has("auction") and kinds.has("arena"))
	var rng := SimRNG.new(5)
	var legend: bool = false
	for i: int in 300:
		legend = legend or setup.rarity(RunSim._roll_at_least(setup, rng, 2)) >= 4
	_check("an uncommon-or-better roll never gives a legendary", not legend)


## 027: the default crew's names, and a machine renamed by the player.
func _test_names() -> void:
	var setup: RunSetup = _setup(5)
	var state: RunState = RunSim.start(setup)
	var names: Array = state.crew.map(func(m: Dictionary) -> String: return String(m["name"]))
	_check("the default crew is Knuckles, Needle and Relay %s" % [names], names == ["Knuckles", "Needle", "Relay"])
	var actions: Array = [[RunSim.RENAME, 1, "Old Betty"]]
	_check("a machine can be renamed", RunSim.apply(state, setup, actions[0]) and String(state.crew[1]["name"]) == "Old Betty")
	_check("an empty or overlong name is refused", not RunSim.apply(state, setup, [RunSim.RENAME, 0, "  "])
		and not RunSim.apply(state, setup, [RunSim.RENAME, 0, "A name far too long for a card"]))
	var decoded: Array = RunStore.decode(JSON.stringify({"version": 1, "seed": 5, "actions": actions}))["actions"]
	_check("the rename is saved and replays", String(RunSim.replay(setup, decoded).crew[1]["name"]) == "Old Betty")


## 082 (B1): a tier stacks on every act. Its `adds` are applied after the act's overlay, so
## FOREMAN in Act 2 is Act 2's numbers plus FOREMAN's, never Act 2's numbers alone.
## 085 (B4): the ladder is cumulative (`Meta.rung_adds`): rung N is rung N-1 plus its own adds, every
## one of which makes its number harder in every act (`harder: down` for the ones that fall), and
## nothing else moves.
func _test_tiers_stack() -> void:
	var tiers: Array = _db.meta.get("tiers", [])
	# Every key any tier touches, plus the ones the acts set that a tier might shadow.
	var keys: Array = ["enemies.hp_all", "enemies.bonus.damage", "front.damage", "front.every"]
	var down: Dictionary = {}
	for tier: Dictionary in tiers:
		for add: Dictionary in ((tier.get("rules", {}) as Dictionary).get("adds", []) as Array):
			if not keys.has(String(add["path"])):
				keys.append(String(add["path"]))
			if String(add.get("harder", "up")) == "down":
				down[String(add["path"])] = true
	keys.sort()
	var table: Array = []  # [tier][act] -> {path: value}
	for t: int in tiers.size():
		var options: Dictionary = {}
		if t > 0:
			options["rules"] = {"adds": Meta.rung_adds(_db.meta, t)}
		var setup: RunSetup = RunSetup.create(_db.parts, _db.tiles, _db.fights, _db.run_rules,
			_db.combat_rules, _db.effectiveness, 7, options)
		var row: Array = []
		for act: int in range(1, RunSim.act_count(setup) + 1):
			var state := RunState.new()
			state.act = act
			var rules: Dictionary = RunSim.rules_of(state, setup)
			var values: Dictionary = {}
			for path: String in keys:
				values[path] = _dig(rules, path) if _has_path(rules, path) else _default_of(path)
			row.append(values)
		table.append(row)
	for t: int in table.size():
		var line: String = "  rung %2d %-16s" % [t, String(tiers[t]["name"])]
		for act: int in (table[t] as Array).size():
			var parts: PackedStringArray = []
			for path: String in keys:
				if t == 0 or int(table[t][act][path]) != int(table[0][act][path]):
					parts.append("%s=%d" % [path.trim_prefix("enemies."), int(table[t][act][path])])
			line += "  | act %d: %s" % [act + 1, " ".join(parts) if t > 0 else "%d keys" % keys.size()]
		print(line)
	var monotone: bool = true
	var where: String = ""
	for t: int in range(1, table.size()):
		var own: Array = (((tiers[t] as Dictionary).get("rules", {}) as Dictionary).get("adds", []) as Array).map(
			func(a: Dictionary) -> String: return String(a["path"]))
		for path: String in keys:
			var moved: bool = false
			for act: int in (table[t] as Array).size():
				var now: int = int(table[t][act][path])
				var before: int = int(table[t - 1][act][path])
				moved = moved or now != before
				var ok: bool = (now <= before if down.has(path) else now >= before) if own.has(path) else now == before
				if not ok:
					monotone = false
					where = "rung %d act %d %s %d after %d" % [t, act + 1, path, now, before]
			if own.has(path) and not moved:
				monotone = false
				where = "rung %d %s changes nothing" % [t, path]
	_check("%d rungs: each is the one below plus its own adds, each harder in every act, nothing else moves%s" % [
		tiers.size(), "" if monotone else " (FAILS at %s)" % where], monotone)
	# The bug B1 fixes: the act's own enemies block replaced the tier's, so tiers did nothing past Act 1.
	var stacks: bool = table.size() >= 2
	for act: int in (table[0] as Array).size():
		stacks = stacks and int(table[1][act]["enemies.hp_all"]) == int(table[0][act]["enemies.hp_all"]) + 2
	_check("FOREMAN adds 2 HP on top of EVERY act (%s vs %s)" % [table[1].map(func(v: Dictionary) -> int: return int(v["enemies.hp_all"])),
		table[0].map(func(v: Dictionary) -> int: return int(v["enemies.hp_all"]))], stacks)
	var bites: bool = table.size() >= 3
	for act: int in (table[0] as Array).size():
		bites = bites and int(table[2][act]["enemies.bonus.damage"]) == int(table[0][act]["enemies.bonus.damage"]) + 1 \
			and int(table[2][act]["enemies.hp_all"]) == int(table[0][act]["enemies.hp_all"]) + 2 and int(table[2][act]["front.damage"]) == 3
	_check("RECLAIMED (rung 2) is FOREMAN plus 1 damage and a bite of 3, on top of every act: the old tier exactly", bites)
	# And it reaches an Act 2 fight: the same rolled squad, every enemy 2 HP tougher on FOREMAN.
	var hp: Array = []
	for t: int in 2:
		var options: Dictionary = {} if t == 0 else {"rules": ((tiers[t] as Dictionary)["rules"] as Dictionary).duplicate(true)}
		var setup: RunSetup = RunSetup.create(_db.parts, _db.tiles, _db.fights, _db.run_rules,
			_db.combat_rules, _db.effectiveness, 7, options)
		var state: RunState = RunSim.start(setup)
		RunSim._next_act(state, setup)
		var fight: Dictionary = RunSim._make_fight(state, setup, 1, "skirmish")
		hp.append((fight["enemy"] as Array).map(func(e: Dictionary) -> int: return int(e.get("hp", 0))))
	_check("FOREMAN reaches an Act 2 fight (enemy HP %s, was %s)" % [hp[1], hp[0]], (hp[0] as Array).size() > 0
		and range((hp[0] as Array).size()).all(func(i: int) -> bool: return int(hp[1][i]) == int(hp[0][i]) + 2))
	# apply_adds: sorted by path, copy on write, set and delta, missing paths made.
	var base: Dictionary = {"a": {"x": 1}, "b": 4}
	var got: Dictionary = RunSetup.apply_adds(base, [{"path": "a.y.z", "delta": 3}, {"path": "a.x", "set": 9},
		{"path": "a.x", "delta": 2}, {"path": "b", "delta": -1}])
	_check("apply_adds: set then delta on one path in list order, new paths made, base untouched (%s)" % [got],
		got == {"a": {"x": 11, "y": {"z": 3}}, "b": 3} and base == {"a": {"x": 1}, "b": 4})
	_check("apply_adds holds integers only", typeof(RunSetup.apply_adds({}, [{"path": "q", "delta": 2.0}])["q"]) == TYPE_INT)


## Whether a dotted path exists in the rules.
func _has_path(rules: Dictionary, path: String) -> bool:
	var node: Variant = rules
	for key: String in path.split("."):
		if not (node is Dictionary) or not (node as Dictionary).has(key):
			return false
		node = (node as Dictionary)[key]
	return true


## What the game reads for a path the rules do not hold (the code's own fallback).
func _default_of(path: String) -> int:
	match path:
		"fight_rules.pile_heal":
			return int(_db.combat_rules.get("pile_heal", 2))
		"start.hp_pct":
			return 100
	return 0


func _dig(rules: Dictionary, path: String) -> int:
	var node: Variant = rules
	for key: String in path.split("."):
		if not (node is Dictionary) or not (node as Dictionary).has(key):
			return 0
		node = (node as Dictionary)[key]
	return int(node)


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
	_check("and its gate is the Core's, with its two conduits and three escorts (038)", String((core["enemy"] as Array)[0].get("kind", "")) == "heart"
		and (core["enemy"] as Array).size() == 6)
	_check("the last act's gate is the end of the run", state.act == RunSim.act_count(setup))

	# 026 (play-test 8): later acts pay in rare parts; caches stand apart.
	var rares: int = 0
	var offered: int = 0
	for id: int in state.sites.size() - 1:
		state.current = id
		for part: Variant in (RunSim.salvage(state, setup, "skirmish")["options"] as Array):
			offered += 1
			rares += 1 if setup.rarity(String(part)) >= 3 else 0
	# 032 (play-test 10: "most parts were rare+ by Act 3"): rares are there, but a minority.
	_check("Act 3's salvage offers rares, as a minority (%d of %d offered)" % [rares, offered], rares > 0 and rares * 2 < offered)
	var elite: Array = RunSim.salvage(state, setup, "elite")["options"]
	_check("and an Act 3 elite offers an uncommon or better", setup.rarity(PartTuning.base_of(String(elite[0]))) >= 2)
	var apart: bool = true
	var defends: int = 0
	for seed_value: int in 60:
		var rng := SimRNG.new(seed_value)
		var o: Dictionary = RunSim._roll_objective(setup, rng, setup.fights["proto_yard"], "skirmish")
		if String(o["type"]) != "defend":
			continue
		defends += 1
		var c: Array = o["caches"]
		if c.size() == 2 and Hex.distance(Vector2i(int(c[0]["x"]), int(c[0]["y"])), Vector2i(int(c[1]["x"]), int(c[1]["y"]))) < 3:
			apart = false
	_check("defend caches stand at least 3 hexes apart (%d defend fights)" % defends, apart and defends > 5)


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
	_check("levels cost 25 and 40", int(member["level"]) == 3 and state.scrap == 20)
	# 027: two more levels (65, 95) as somewhere for late scrap to go; then the top.
	state.scrap = 160
	RunSim.apply(state, setup, [RunSim.LEVEL_UP, 0, 0])
	RunSim.apply(state, setup, [RunSim.LEVEL_UP, 0, 0])
	_check("levels 4 and 5 cost 65 and 95, and stop at 5", int(member["level"]) == 5 and state.scrap == 0
		and not RunSim.apply(state, setup, [RunSim.LEVEL_UP, 0, 0]) and RunSim.perk_offer(state, setup, 0).is_empty())
	var kept: Array = member["perks"]
	var distinct: Dictionary = {}
	for k: Variant in kept:
		distinct[k] = true
	_check("five levels, five different perks", kept.size() == 5 and distinct.size() == 5)
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
	# 047: the hammer is uncommon now -- 10, not 6.
	_check("tuning an uncommon costs 10 and changes the socket", RunSim.apply(state, setup, [RunSim.TUNE, 0, 3, 0])
		and state.scrap == 40 and String(state.crew[0]["parts"][3]) == "ar_hammer:a")
	_check("a part is tuned only once", not RunSim.apply(state, setup, [RunSim.TUNE, 0, 3, 1]))
	_check("the option is 0 or 1", not RunSim.apply(state, setup, [RunSim.TUNE, 0, 2, 2]))
	var unit: GridUnit = RunSim.preview_machine(setup, state.crew[0])
	_check("the fight uses the tuned numbers (the hammer hits for 4)", int(unit.weapons[1]["damage"]) == 4)
	state.cargo.append("ar_lance")
	_check("a part in the hold can be tuned (an uncommon costs 10)",
		RunSim.apply(state, setup, [RunSim.TUNE, -1, state.cargo.size() - 1, 1]) and state.cargo[-1] == "ar_lance:b" and state.scrap == 30)
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


## 083 (A7-defend): a won DEFEND pays its salvage in proportion to the caches still standing.
func _test_defend_partial() -> void:
	var full: Dictionary = RunSim.salvage(RunSim.start(_setup(12)), _setup(12), "skirmish", 2, 2)
	var half: Dictionary = RunSim.salvage(RunSim.start(_setup(12)), _setup(12), "skirmish", 1, 2)
	var plain: Dictionary = RunSim.salvage(RunSim.start(_setup(12)), _setup(12), "skirmish")
	_check("a DEFEND with both caches standing pays the full salvage (3 parts, 8 scrap)",
		(full["options"] as Array).size() == 3 and int(full["scrap"]) == 8 and full["options"] == plain["options"])
	_check("1 of 2 caches standing: 2 of the same 3 parts and 4 scrap (%s, %d)" % [half["options"], int(half["scrap"])],
		(half["options"] as Array).size() == 2 and int(half["scrap"]) == 4 and half["options"] == (full["options"] as Array).slice(0, 2)
		and half["caches"] == [1, 2])
	var off: RunSetup = _setup(12)
	off.rules = off.rules.duplicate(true)
	off.rules["rewards"]["defend_partial"] = false
	var old: Dictionary = RunSim.salvage(RunSim.start(off), off, "skirmish", 1, 2)
	_check("defend_partial false pays it all, as before 083", (old["options"] as Array).size() == 3 and int(old["scrap"]) == 8)
	# Through the real fight: DEFEND fights the bot wins with a cache broken (caches at 2 HP here,
	# so they break), reported to the run and replayed.
	var seen: int = 0
	var right: bool = true
	var losses_clear: bool = true
	var lost: int = 0
	for seed_value: int in range(1, 160):
		if seen >= 3 and lost >= 1:
			break
		var setup: RunSetup = _setup(seed_value)
		setup.combat_rules = setup.combat_rules.duplicate(true)
		setup.combat_rules["cache_hp"] = 2
		var state: RunState = RunSim.start(setup)
		var site: int = RunSim.destinations(state)[0]
		state.sites[site]["type"] = "skirmish"
		RunSim.apply(state, setup, [RunSim.TRAVEL, site])
		if String(state.pending.get("kind", "")) != "fight" or String(state.pending["fight"]["objective"]["type"]) != "defend":
			continue
		var combat_setup: CombatSetup = RunSim.fight_setup(state, setup)
		var actions: Array = RunBot.play_fight(combat_setup)
		if lost == 0 and seed_value % 2 == 0:
			# Every other DEFEND the crew only ends its turns, so the caches are left to break.
			actions = []
			var idle: CombatState = CombatSim.start(combat_setup)
			while idle.outcome == CombatState.ONGOING and actions.size() < 40:
				actions.append([CombatSim.ACT_END, 0, 0, 0])
				CombatSim.apply(idle, [CombatSim.ACT_END, 0, 0, 0])
		var result: CombatState = CombatSim.replay(combat_setup, actions)
		var placed: int = int(CombatSim.objective_status(result)["caches_total"])
		var saved: int = result.caches().size()
		if result.outcome == CombatState.LOST and state.alive_crew() > 0 and saved == 0:
			RunSim.apply(state, setup, [RunSim.FIGHT, actions])
			var next: Dictionary = state.pending
			while String(next.get("kind", "")) == "wreck":
				next = next.get("next", {})
			losses_clear = losses_clear and (next.is_empty() or state.outcome != RunState.ONGOING)
			lost += 1
			continue
		if result.outcome != CombatState.WON or saved == placed:
			continue
		RunSim.apply(state, setup, [RunSim.FIGHT, actions])
		var pending: Dictionary = state.pending
		while String(pending.get("kind", "")) == "wreck":
			pending = pending.get("next", {})
		right = right and String(pending.get("kind", "")) == "reward" \
			and (pending["options"] as Array).size() == maxi(1, (3 * saved + placed - 1) / placed) \
			and int(pending["scrap"]) == (8 * saved + placed - 1) / placed
		seen += 1
	_check("DEFEND fights won with caches broken pay scaled salvage (%d fights)" % seen, seen > 0 and right)
	_check("a DEFEND with every cache broken is still lost, no salvage (%d fights)" % lost, lost > 0 and losses_clear)


## 083 (wreck recovery): a wreck whose pile still stands at the fight's end gives back one part.
func _test_wreck_recovery() -> void:
	# Staged: crew 1 was wrecked, its pile held; the salvage waits behind it.
	var setup: RunSetup = _setup(8)
	var state: RunState = RunSim.start(setup)
	var member: Dictionary = state.crew[1]
	var lost: Array = (member["parts"] as Array).slice(1)
	member["alive"] = false
	member["hp"] = 0
	member["parts"] = [String(member["parts"][0]), "", "", "", ""]
	state.pending = RunSim.salvage(state, setup, "skirmish")
	var salvage: Dictionary = state.pending
	var parts: Array = lost.filter(func(p: Variant) -> bool: return not String(p).is_empty())
	var pull: Dictionary = RunSim.wreck_pull(state, setup, [0, 1, 2], {1: lost}, [1])
	_check("a guarded wreck gives back one of the parts it lost (%s)" % [pull],
		int(pull.get("crew", -1)) == 1 and parts.has(String(pull.get("part", ""))))
	_check("and the same one every time (SimRNG, not Dictionary order)",
		RunSim.wreck_pull(state, setup, [0, 1, 2], {1: lost}, [1]) == pull)
	_check("a wreck whose pile is gone gives nothing", RunSim.wreck_pull(state, setup, [0, 1, 2], {1: lost}, []).is_empty())
	_check("an enemy ref or a living machine is never a wreck",
		RunSim.wreck_pull(state, setup, [0, 1, 2], {1: lost}, [11]).is_empty() and RunSim.wreck_pull(state, setup, [0, 1, 2], {0: lost}, [0]).is_empty())
	# Two guarded wrecks still give ONE part, drawn over both wrecks' parts (refs in any order).
	var both: RunState = RunSim.start(setup)
	var lost0: Array = (both.crew[0]["parts"] as Array).slice(1)
	var lost1: Array = (both.crew[1]["parts"] as Array).slice(1)
	both.crew[0]["alive"] = false
	both.crew[1]["alive"] = false
	var drawn: Dictionary = {}
	var spread: bool = true
	for site: int in 30:
		both.current = site
		var one: Dictionary = RunSim.wreck_pull(both, setup, [0, 1, 2], {0: lost0, 1: lost1}, [1, 0])
		spread = spread and one == RunSim.wreck_pull(both, setup, [0, 1, 2], {0: lost0, 1: lost1}, [0, 1]) \
			and (lost0 if int(one["crew"]) == 0 else lost1).has(String(one["part"]))
		drawn[int(one["crew"])] = true
	_check("two guarded wrecks give one part, from either wreck (%s over 30 sites)" % [drawn.keys()], spread and drawn.size() == 2)
	both.crew[0]["alive"] = true
	both.crew[1]["alive"] = true
	RunSim._queue_wreck(state, pull)
	_check("the wreck comes before the salvage, one part on it", String(state.pending.get("kind", "")) == "wreck"
		and state.pending["options"] == [String(pull["part"])] and state.pending["next"] == salvage)
	_check("the salvage cannot be picked while the wreck waits", not RunSim.apply(state, setup, [RunSim.PICK, 0]))
	_check("RECOVER 1 is refused (there is one part)", not RunSim.apply(state, setup, [RunSim.RECOVER, 1]))
	var hold: int = state.cargo.size()
	_check("RECOVER 0 takes the part into the hold, then the salvage shows",
		RunSim.apply(state, setup, [RunSim.RECOVER, 0]) and state.cargo.size() == hold + 1 and state.cargo[-1] == String(pull["part"])
		and state.pending == salvage)
	_check("RECOVER with no wreck waiting is refused", not RunSim.apply(state, setup, [RunSim.RECOVER, 0]))
	var left: RunState = RunSim.start(setup)
	left.crew[0]["alive"] = false
	RunSim._queue_wreck(left, {"crew": 0, "part": "co_slug"})
	_check("RECOVER -1 leaves it and goes on", RunSim.apply(left, setup, [RunSim.RECOVER, -1]) and left.pending.is_empty() and not left.cargo.has("co_slug"))
	left.pending = {"kind": "wreck", "crew": 0, "options": ["co_slug"], "next": {}}
	_check("the bot takes the part when the hold has room", RunBot.next_action(left, setup) == [RunSim.RECOVER, 0])
	while left.cargo.size() < left.hold_size:
		left.cargo.append("ar_railgun")
	_check("and leaves it when the hold is full of rarer parts", RunBot.next_action(left, setup) == [RunSim.RECOVER, -1])

	# Through the real fight: a machine wrecked with its pile standing at the end (enemies hit
	# harder here so wrecks happen), the wreck offered, the run replayed from its actions and saved.
	var found: bool = false
	for seed_value: int in range(1, 120):
		var hard: RunSetup = _setup(seed_value)
		hard.rules = hard.rules.duplicate(true)
		hard.rules["enemies"]["bonus"] = {"damage": 3}
		var run: RunState = RunSim.start(hard)
		var site: int = RunSim.destinations(run)[0]
		# 084: a site as generated, never retyped -- the replay below regenerates the region.
		if String(run.sites[site]["type"]) != "skirmish":
			continue
		var log: Array = [[RunSim.TRAVEL, site]]
		RunSim.apply(run, hard, log[0])
		if String(run.pending.get("kind", "")) != "fight":
			continue
		var combat_setup: CombatSetup = RunSim.fight_setup(run, hard)
		var actions: Array = RunBot.play_fight(combat_setup)
		var result: CombatState = CombatSim.replay(combat_setup, actions)
		var saved: Array = CombatSim.saved_wrecks(result)
		if saved.is_empty() or result.crew(GridUnit.TEAM_PLAYER).is_empty():
			continue
		var before: Array = []
		for m: Dictionary in run.crew:
			before.append((m["parts"] as Array).duplicate())
		log.append([RunSim.FIGHT, actions])
		RunSim.apply(run, hard, log[1])
		var offered: bool = String(run.pending.get("kind", "")) == "wreck" and saved.has(int(run.pending["crew"])) \
			and (run.pending["options"] as Array).size() == 1 \
			and (before[int(run.pending["crew"])] as Array).slice(1).has(String(run.pending["options"][0]))
		_check("a wreck pile standing at the fight's end gives back one of that machine's parts (seed %d, %s from %s)" % [seed_value,
			run.pending.get("options", []), run.pending.get("crew", -1)], offered)
		var take: Array = RunBot.next_action(run, hard)
		log.append(take)
		var taken: String = String(run.pending["options"][int(take[1])]) if offered else ""
		RunSim.apply(run, hard, take)
		_check("the pulled part is in the hold (%s)" % taken, offered and run.cargo.has(taken))
		var again: RunState = RunSim.replay(hard, RunStore.decode(RunStore.encode(seed_value, "test", log, []))["actions"])
		_check("the save replays the wreck pick exactly", again.fingerprint() == run.fingerprint() and again.cargo == run.cargo)
		found = true
		break
	_check("a run-built fight leaves a guarded wreck (CombatSim.saved_wrecks)", found)


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
	# 084 (the user: "MORE DRONES"): lingering -- moves this act beyond the site's column -- sends more.
	var reach_rules: Dictionary = setup.rules["reclaimer_reach"]
	var per: int = int(reach_rules["per_linger"])
	var counts: Array = []
	for extra: int in [0, per - 1, per, per * 2, per * 50]:
		counts.append(RunSim.reach_drones(setup, 3 + extra, 3))
	_check("drones grow with lingering, one per %d extra moves, capped at %d %s" % [per, int(reach_rules["max"]), counts],
		int(counts[0]) == int(reach_rules["count"]) and int(counts[1]) == int(counts[0]) and int(counts[2]) == int(counts[0]) + 1
		and int(counts[3]) == int(counts[0]) + 2 and int(counts[4]) == int(reach_rules["max"]))
	state.pending = {}
	state.moves = 2 + per * 2
	RunSim._start_fight(state, setup, near, "skirmish")
	var lingered: Dictionary = (state.pending["fight"] as Dictionary).get("reclaimer", {})
	_check("a fight reached after lingering carries the bigger count and the earlier round (%s)" % [lingered],
		int(lingered.get("count", 0)) == RunSim.reach_drones(setup, state.moves, int(state.site(near)["col"]))
		and int(lingered.get("round", 0)) == RunSim.reach_round(setup, state.moves, int(state.site(near)["col"]))
		and int(lingered.get("count", 0)) > int(reach_rules["count"]))
	var round_per: int = int(reach_rules["round_per_linger"])
	var rounds: Array = []
	for extra: int in [0, round_per - 1, round_per, round_per * 50]:
		rounds.append(RunSim.reach_round(setup, 3 + extra, 3))
	_check("lingering brings the drones a round earlier per %d steps, never before round %d %s" % [round_per, int(reach_rules["round_min"]), rounds],
		int(rounds[0]) == int(reach_rules["round"]) and int(rounds[1]) == int(rounds[0]) and int(rounds[2]) == int(rounds[0]) - 1
		and int(rounds[3]) == int(reach_rules["round_min"]))
	# The drones really come in at round 2: a fight built from such a reach marks them in round 1.
	var early: Dictionary = (state.pending["fight"] as Dictionary).duplicate(true)
	early["reclaimer"] = {"round": int(reach_rules["round_min"]), "count": 3}
	var early_combat: CombatState = CombatSim.start(CombatSetup.build(early, setup.combat_rules, setup.parts, setup.tiles, setup.wheel, 1))
	var marked: int = 0
	for e: Array in early_combat.events:
		marked += 1 if int(e[GridEv.F_KIND]) == GridEv.ARRIVAL_MARKED else 0
	_check("drones due at round %d are marked from the first round (%d marks)" % [int(reach_rules["round_min"]), marked], marked == 3)


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
			ok = ok and int(((run.pending["fight"] as Dictionary).get("reclaimer", {}) as Dictionary).get("count", 0)) == int(move["drones"])
			if bool(move["reach"]):
				ok = ok and int(((run.pending["fight"] as Dictionary)["reclaimer"] as Dictionary)["round"]) == int(move["drones_round"])
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
	# 040: a part the profile unlocked is on the bench, once.
	var opened: RunSetup = RunSetup.create(_db.parts, _db.tiles, _db.fights, _db.run_rules, _db.combat_rules, _db.effectiveness, 12,
		{"unlocked": ["ar_maul", "mo_repair"]})
	_check("unlocked parts join the assembly bench, once each (maul %d, repair drone %d; elsewhere %d)" % [RunSim.bench_count(opened, "ar_maul"),
		RunSim.bench_count(opened, "mo_repair"), RunSim.bench_count(setup, "mo_repair")],
		RunSim.bench_count(opened, "ar_maul") == 1 and RunSim.bench_count(opened, "mo_repair") == 1 and RunSim.bench_count(setup, "mo_repair") == 0)
	# 047: the shove arms are uncommon -- the bench has ONE (the hammer), the scattergun none.
	var shoves: Array = []
	for id: Variant in setup.pools["arm"]:
		if int(((setup.parts[id] as Dictionary).get("grid", {}) as Dictionary).get("shove", 0)) > 0 and RunSim.bench_count(setup, String(id)) != 0:
			shoves.append([id, RunSim.bench_count(setup, String(id))])
	_check("the bench offers exactly one shove arm, once %s" % [shoves], shoves == [["ar_hammer", 1]])
	var two_hammers: Array = [["ch_brute", "co_slug", "ar_hammer", "ar_ripper", "mo_scavenger"], defaults[1],
		["ch_courier", "co_dynamo", "ar_scanner", "ar_hammer", "mo_governor"]]
	_check("and not a second hammer", not RunSim.apply(RunSim.start(setup), setup, [RunSim.ASSEMBLE, two_hammers]))
	var twin: Array = [["ch_brute", "co_slug", "ar_ripper", "ar_ripper", "mo_scavenger"],
		["ch_brute", "co_arc", "ar_pulse", "ar_flail", "mo_ablative"],
		["ch_courier", "co_dynamo", "ar_scanner", "ar_flail", "mo_governor"]]
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
	# Replayed by hand so the halfway point is kept for the save check below.
	var half: Array = actions.slice(0, actions.size() / 2)
	var again_setup: RunSetup = _setup(99)
	var again: RunState = RunSim.start(again_setup)
	var half_print: String = again.fingerprint()
	for i: int in actions.size():
		RunSim.apply(again, again_setup, actions[i])
		if i + 1 == half.size():
			half_print = again.fingerprint()
	_check("replaying the run's actions reproduces it exactly", again.fingerprint() == state.fingerprint())
	_check("and its feats (%s)" % [state.feats], not state.feats.is_empty() and again.feats == state.feats)

	# The save format: the actions through JSON and back. JSON turns every int into a
	# float, and a run must survive that or no save would ever load.
	# 070: compared as text, which tells 1 from 1.0 (`==` does not) -- stricter than replaying the
	# whole run again, and the replay above already shows the same actions give the same run.
	var text: String = RunStore.encode(99, "test", actions, [])
	var loaded: Dictionary = RunStore.decode(text)
	_check("a run survives the JSON round trip (every action, every int)",
		int(loaded["seed"]) == 99 and var_to_str(loaded["actions"]) == var_to_str(actions))
	var partial_text: String = RunStore.encode(99, "test", half, [])
	var partial_loaded: RunState = RunSim.replay(_setup(99), RunStore.decode(partial_text)["actions"])
	_check("a run saved halfway resumes at the same point", partial_loaded.fingerprint() == half_print
		and var_to_str(RunStore.decode(partial_text)["actions"]) == var_to_str(half))


func _check(label: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		print("  FAIL  %s" % label)


## 046 (the agent's Act 1, 2026-10-05): rewards that do not repeat, map rules, refit HP.
func _test_agent_playtest() -> void:
	# Rewards: play many bot runs to their end and watch every offer as it is made.
	var repeats: Array = []
	var legend_twice: Array = []
	var offers: int = 0
	for s: int in 4:
		var setup: RunSetup = _setup(700 + s)
		var state: RunState = RunSim.start(setup)
		var seen_legends: Array = []
		for step: int in 400:
			if state.outcome != RunState.ONGOING:
				break
			var avoid: Array = RunSim.avoided(state, setup)
			var before: int = state.offered.size()
			var held: Array = state.cargo.map(func(p: String) -> String: return PartTuning.base_of(p))
			if not RunSim.apply(state, setup, RunBot.next_action(state, setup)):
				break
			var fresh: Array = state.offered.slice(before)
			offers += fresh.size()
			for base: Variant in fresh:
				# A reward may fall back to a repeat only when its pool had nothing else; the
				# pools are big, so in practice that never happens. Count it either way.
				if avoid.has(base) and not seen_legends.has(base):
					repeats.append([s, base, held.has(base)])
				if setup.rarity(String(base)) >= 4:
					if seen_legends.has(base):
						legend_twice.append([s, base])
					seen_legends.append(base)
	_check("4 bot runs, %d parts offered: none in the hold or among the last offers %s" % [offers, repeats.slice(0, 3)],
		offers > 40 and repeats.is_empty())
	_check("no legendary offered twice in a run %s" % [legend_twice.slice(0, 3)], legend_twice.is_empty())

	# Map rules, over 200 regions in every act.
	var calm_first: bool = true
	var shop_before_gate: bool = true
	var linked_repeat: Array = []
	var services: Array = _db.run_rules.get("no_linked_repeat", [])
	for s: int in 200:
		var setup: RunSetup = _setup(s)
		var state: RunState = RunSim.start(setup)
		for act: int in RunSim.act_count(setup):
			var last: int = 0
			for site: Dictionary in state.sites:
				last = maxi(last, int(site["col"]))
			var col1: Array = state.sites.filter(func(x: Dictionary) -> bool: return int(x["col"]) == 1)
			calm_first = calm_first and not col1.all(func(x: Dictionary) -> bool: return RunSim.FIGHT_TYPES.has(String(x["type"])))
			shop_before_gate = shop_before_gate and state.sites.any(func(x: Dictionary) -> bool:
				return int(x["col"]) == last - 1 and String(x["type"]) == "workshop")
			for site: Dictionary in state.sites:
				var kind: String = String(site["type"])
				if services.has(kind) and RunSim._linked_to(state, int(site["id"]), kind):
					linked_repeat.append([s, act + 1, kind])
			if act + 1 < RunSim.act_count(setup):
				RunSim._next_act(state, setup)
	_check("200 regions x every act: the first step always offers a non-fight", calm_first)
	_check("200 regions x every act: a workshop in the column before the gate", shop_before_gate)
	_check("200 regions x every act: no two linked sites the same service %s" % [linked_repeat.slice(0, 3)], linked_repeat.is_empty())

	# Refit keeps the missing HP: a full machine on a bigger frame is still full.
	var setup2: RunSetup = _setup(5)
	var st: RunState = RunSim.start(setup2)
	var needle: Dictionary = st.crew[1]
	st.cargo.append("ch_bulwark")
	var full: bool = int(needle["hp"]) == RunSim.max_hp(setup2, needle)
	RunSim.apply(st, setup2, [RunSim.REFIT, 1, 0, st.cargo.size() - 1])
	_check("a full machine refitted onto a bigger frame is still full (%d / %d)" % [int(needle["hp"]), RunSim.max_hp(setup2, needle)],
		full and String(needle["parts"][0]) == "ch_bulwark" and int(needle["hp"]) == RunSim.max_hp(setup2, needle))
	needle["hp"] = int(needle["hp"]) - 4
	var hauler_at: int = st.cargo.find("ch_hauler")
	RunSim.apply(st, setup2, [RunSim.REFIT, 1, 0, hauler_at])
	_check("and one 4 short stays 4 short on the way back", int(needle["hp"]) == RunSim.max_hp(setup2, needle) - 4)


## Runs one test and names it if it took over a second, so a slow suite says where its time goes.
func _timed(test: Callable) -> void:
	var start: int = Time.get_ticks_msec()
	test.call()
	var ms: int = Time.get_ticks_msec() - start
	if ms >= 1000:
		print("  time  %5.1fs  %s%s" % [ms / 1000.0, test.get_method(), "" if test.get_bound_arguments().is_empty() else " " + str(test.get_bound_arguments()[0])])


## 084 (B3): the Reclaimer's pace -- moves per column x100 -- and what the move preview says of it.
func _test_front_pace() -> void:
	var at: PackedStringArray = []
	var col: int = -1
	for moves: int in range(1, 13):
		if RunSim.front_due({"pace": 150}, moves, col):
			col += 1
			at.append(str(moves))
	_check("pace 150 takes a column on moves %s (every move and a half)" % ",".join(at), ",".join(at) == "2,3,5,6,8,9,11,12")
	var same: bool = true
	col = -1
	var col_b: int = -1
	for moves: int in range(1, 30):
		var a: bool = RunSim.front_due({"pace": 200}, moves, col)
		var b: bool = RunSim.front_due({"every": 2}, moves, col_b)
		same = same and a == b
		col += 1 if a else 0
		col_b += 1 if b else 0
	_check("pace 200 is the old `every 2`, and `every` is the fallback with no pace", same)
	_check("the default rules carry a pace (the user: wandering costs at rung 0)", int((_db.run_rules["front"] as Dictionary).get("pace", 0)) > 0)
	# front_in against what the moves then do, over a bot's route: after a move that promised n,
	# exactly n more moves pass before the front takes a column (signals that push it aside).
	var setup: RunSetup = _setup(23)
	var run: RunState = RunSim.start(setup)
	var waits: Array = []
	var honest: bool = true
	var guard: int = 0
	var promised: int = -1
	var waited: int = 0
	while run.outcome == RunState.ONGOING and run.act == 1 and guard < 200:
		guard += 1
		var action: Array = RunBot.next_action(run, setup)
		if int(action[0]) != RunSim.TRAVEL:
			RunSim.apply(run, setup, action)
			continue
		var before: int = run.front_col
		var move: Dictionary = RunSim.move_preview(run, setup, int(action[1]))
		RunSim.apply(run, setup, action)
		if promised >= 0:
			if run.front_col != before:
				honest = honest and waited == promised
				waits.append(waited)
				promised = -1
			else:
				waited += 1
		if promised < 0 or run.front_col != before:
			promised = int(move["front_in"])
			waited = 0
	_check("move_preview's front_in held on a bot's road %s" % [waits], honest and waits.size() >= 3)
	# Simple direct check: front_in = n means the next n moves leave the front, the one after takes.
	var ok: bool = true
	for pace: int in [130, 150, 167, 200]:
		var f: Dictionary = {"pace": pace}
		for moves: int in range(0, 12):
			for c: int in range(-1, 6):
				var n: int = RunSim.front_in(f, moves, c)
				for k: int in n:
					ok = ok and not RunSim.front_due(f, moves + 1 + k, c)
				ok = ok and RunSim.front_due(f, moves + 1 + n, c)
	_check("front_in counts the moves the front waits, at paces 130/150/167/200", ok)


## 084 (B2): the fight card on the map is the fight that travel then makes -- over 300 regions (100
## seeds x 3 acts), on a hashed route that damages and wrecks the crew and lets the front move.
func _test_fight_preview() -> void:
	var compared: int = 0
	var mismatch: String = ""
	var hidden_ok: bool = true
	var conditions_ok: bool = true
	for seed_value: int in 100:
		var setup: RunSetup = _setup(seed_value)
		var state: RunState = RunSim.start(setup)
		for act: int in range(1, 4):
			if act > 1:
				for member: Dictionary in state.crew:
					member["alive"] = true
					member["hp"] = RunSim.max_hp(setup, member)
				RunSim._next_act(state, setup)
			# Unscouted sites stay "?"; scouted, every fight site's card from the start of the act.
			for s: Dictionary in state.sites:
				if not RunSim.revealed(state, int(s["id"])) and not RunSim.fight_preview(state, setup, int(s["id"])).is_empty():
					hidden_ok = false
			var cards: Dictionary = {}
			var full: Dictionary = {}
			for s: Dictionary in state.sites:
				var id: int = int(s["id"])
				if RunSim.FIGHT_TYPES.has(String(s["type"])):
					if not state.scouted.has(id):
						state.scouted.append(id)
					cards[id] = RunSim.fight_preview(state, setup, id)
					var f: Dictionary = RunSim._make_fight(state, setup, id, String(s["type"]))
					full[id] = var_to_str([f["enemy"], f["objective"], f["rows"], f.get("modifiers", [])])
			state.scouted.sort()
			var steps: int = 0
			while steps < 30 and state.outcome == RunState.ONGOING:
				steps += 1
				var options: Array[int] = RunSim.destinations(state)
				if options.is_empty():
					break
				var to: int = options[IntentAI.mix(seed_value, act, steps, 77) % options.size()]
				RunSim.apply(state, setup, [RunSim.TRAVEL, to])
				if String(state.pending.get("kind", "")) == "fight":
					var kind: String = String(state.pending["site_type"])
					var fight: Dictionary = state.pending["fight"]
					var got: Dictionary = RunSim.fight_summary(setup, fight, kind)
					var made: String = var_to_str([fight["enemy"], fight["objective"], fight["rows"], fight.get("modifiers", [])])
					compared += 1
					if got != cards.get(to, {}) or made != full.get(to, ""):
						mismatch = "seed %d act %d site %d: %s vs %s" % [seed_value, act, to, got, cards.get(to, {})]
					var cond: String = RunSim.act_condition(state, setup, act)
					if kind != "boss" and kind != "warlord" and String(got["condition"]) != cond:
						conditions_ok = false
					# Change the crew along the way: hurt everyone, wreck one now and then.
					for member: Dictionary in state.crew:
						member["hp"] = maxi(1, int(member["hp"]) - 3)
					if steps % 3 == 0 and state.alive_crew() > 1:
						state.crew[steps % 3]["alive"] = false
					if kind == "boss":
						break
				state.pending = {}
			state.pending = {}
	_check("unscouted fight sites show no card", hidden_ok)
	_check("every card equals the fight made after travel: %d fights over 300 regions %s" % [compared, mismatch],
		mismatch.is_empty() and compared > 600)
	_check("every fight of an act (not the gate or warlord) carries the act's condition", conditions_ok)
	# The card's shape: what the map shows.
	var setup2: RunSetup = _setup(5)
	var st: RunState = RunSim.start(setup2)
	var shown: Dictionary = {}
	for id: int in RunSim.destinations(st):
		if RunSim.FIGHT_TYPES.has(String(st.site(id)["type"])):
			shown = RunSim.fight_preview(st, setup2, id)
	var lord: int = -1
	for s: Dictionary in st.sites:
		if String(s["type"]) == "warlord":
			lord = int(s["id"])
	var lord_card: Dictionary = RunSim.fight_preview(st, setup2, lord)
	_check("a card has objective, condition, enemies [[name, count]] and elite %s" % [shown],
		shown.has("objective") and shown.has("condition") and shown.has("elite") and not (shown["enemies"] as Array).is_empty())
	_check("the warlord's card is known from the start and names its keeper %s" % [lord_card],
		not lord_card.is_empty() and (lord_card["enemies"] as Array).any(func(e: Array) -> bool:
			return ["grinder", "magnet", "twin"].has(String(e[0]))))
	_check("a non-fight site has no card", RunSim.fight_preview(st, setup2, 0).is_empty())


## 084 (B7): one condition per act from the seed, each in 20-35% of acts; the warlords dealt in a
## seeded order; the same seed gives the same region, conditions and warlords.
func _test_act_conditions() -> void:
	var counts: Dictionary = {}
	var orders: Dictionary = {}
	var acts: int = 0
	for seed_value: int in 300:
		var setup: RunSetup = _setup(seed_value)
		var order: PackedStringArray = []
		for act: int in range(1, 4):
			var c: String = RunSim.act_condition(null, setup, act)
			counts[c] = int(counts.get(c, 0)) + 1
			acts += 1
			order.append(RunSim.act_warlord(setup, act))
		orders[",".join(order)] = true
	var shares: PackedStringArray = []
	var in_band: bool = counts.size() == 4
	for c: String in ["dust", "heat_wave", "scrap_rain", "wires"]:
		var pct: int = int(counts.get(c, 0)) * 100 / acts
		shares.append("%s %d%%" % [c, pct])
		in_band = in_band and pct >= 20 and pct <= 35
	_check("each condition in 20-35%% of 900 acts (%s)" % ", ".join(shares), in_band)
	_check("all six warlord orders turn up over 300 seeds (%d)" % orders.size(), orders.size() == 6)
	var same: bool = true
	for seed_value: int in [3, 41, 977]:
		var a: RunState = RunSim.start(_setup(seed_value))
		var b: RunState = RunSim.start(_setup(seed_value))
		var sa: RunSetup = _setup(seed_value)
		var sb: RunSetup = _setup(seed_value)
		for act: int in range(1, 4):
			same = same and _region_text(a) == _region_text(b)
			same = same and RunSim.act_condition(a, sa, act) == RunSim.act_condition(b, sb, act)
			same = same and RunSim.act_warlord(sa, act) == RunSim.act_warlord(sb, act)
			if act < 3:
				RunSim._next_act(a, sa)
				RunSim._next_act(b, sb)
	_check("the same seed gives the same region, conditions and warlord order", same)
	# A fixed list (085's daily) overrides the roll; a tier's adds still reach every act.
	var fixed: RunSetup = RunSetup.create(_db.parts, _db.tiles, _db.fights, _db.run_rules, _db.combat_rules,
		_db.effectiveness, 7, {"rules": {"modifiers": {"acts": ["wires", "", "dust"]}}})
	_check("modifiers.acts fixes each act's condition (wires, none, dust)",
		RunSim.act_condition(null, fixed, 1) == "wires" and RunSim.act_condition(null, fixed, 2) == ""
		and RunSim.act_condition(null, fixed, 3) == "dust")
	var tiered: RunSetup = RunSetup.create(_db.parts, _db.tiles, _db.fights, _db.run_rules, _db.combat_rules,
		_db.effectiveness, 7, {"rules": {"adds": [{"path": "enemies.bonus.damage", "delta": 1}, {"path": "front.pace", "delta": -20}]}})
	var stacked: bool = true
	for act: int in range(1, 4):
		var st := RunState.new()
		st.act = act
		var plain: Dictionary = RunSim.rules_for_act(_setup(7), act)
		var with: Dictionary = RunSim.rules_of(st, tiered)
		stacked = stacked and _dig(with, "enemies.bonus.damage") == _dig(plain, "enemies.bonus.damage") + 1
		stacked = stacked and _dig(with, "front.pace") == _dig(plain, "front.pace") - 20
		stacked = stacked and var_to_str(RunSim.rules_for_act(tiered, act)) == var_to_str(with)
	_check("a tier's adds (damage, the front's pace) still stack on every act", stacked)
	# Warlords away from home: keepers' HP by the act, escorts by the act's rules.
	var hp: Dictionary = {}
	for act: int in range(1, 4):
		for id: String in ["warlord_grinder", "warlord_magnet", "warlord_twins"]:
			hp["%s@%d" % [id.trim_prefix("warlord_"), act]] = int(((RunSim._warlord_for_act(_setup(1), id, act)["enemy"] as Array)[0] as Dictionary)["hp"])
	_check("a warlord's keeper HP follows the act it is dealt to %s" % [hp],
		int(hp["grinder@1"]) == 26 and int(hp["grinder@3"]) > 26 and int(hp["twins@3"]) == 34 and int(hp["twins@1"]) < 34
		and int(_db.fights["warlord_twins"]["enemy"][0]["hp"]) == 34)


## 084 (B8): seed codes -- round trip, typos, other versions, and the same run from the code.
func _test_seed_codes() -> void:
	var version: String = _db.content_version()
	var round_trip: bool = true
	var codes: Dictionary = {}
	var seeds: Dictionary = {}
	for i: int in 3000:
		var seed_value: int = IntentAI.mix(i, 1, 2, 3) & RunSetup.SEED_MASK if i > 2 else [0, 1, RunSetup.SEED_MASK][i]
		var code: String = RunSetup.seed_code(seed_value, version)
		var back: Dictionary = RunSetup.parse_seed_code(code, version)
		round_trip = round_trip and not back.is_empty() and int(back["seed"]) == seed_value and not bool(back["stale"])
		codes[code] = seed_value
		seeds[seed_value] = true
	_check("3000 seed codes read back to their seeds, one code per seed", round_trip and codes.size() == seeds.size() and seeds.size() > 2990)
	var sample: String = RunSetup.seed_code(4242, version)
	_check("a code is three words and a number (%s); case and separators do not matter" % sample,
		sample.split("-").size() == 4 and int(RunSetup.parse_seed_code(sample.to_lower().replace("-", " "), version).get("seed", -1)) == 4242
		and int(RunSetup.parse_seed_code(" " + sample.replace("-", ". ") + " ", version).get("seed", -1)) == 4242)
	var other: Dictionary = RunSetup.parse_seed_code(sample, "0000beef" if RunSetup.version_tag("0000beef") != RunSetup.version_tag(version) else "0000cafe")
	_check("a code from another content version is read but marked stale", not other.is_empty() and bool(other["stale"]))
	var caught: int = 0
	var tried: int = 0
	var words: PackedStringArray = sample.split("-")
	for w: int in 3:
		for k: int in 40:
			var typo: PackedStringArray = words.duplicate()
			typo[w] = RunSetup.SEED_WORDS[(RunSetup.SEED_WORDS.find(words[w]) + 1 + k) % 256]
			tried += 1
			caught += 1 if RunSetup.parse_seed_code("-".join(typo), version).is_empty() else 0
	_check("a wrong word is caught by the check %d of %d times" % [caught, tried], caught * 100 >= tried * 90)
	_check("nonsense is not a code", RunSetup.parse_seed_code("", version).is_empty()
		and RunSetup.parse_seed_code("CRANE SLAG", version).is_empty() and RunSetup.parse_seed_code("FOO-BAR-BAZ-1234", version).is_empty())
	_check("a seed over SEED_MASK has no code", RunSetup.seed_code(RunSetup.SEED_MASK + 1, version).is_empty())
	# The code to the identical run: the same RunState after the same bot actions, fights included.
	var seed_value: int = 1234567
	var code: String = RunSetup.seed_code(seed_value, version)
	var a_setup: RunSetup = _setup(seed_value)
	var b_setup: RunSetup = RunSetup.create(_db.parts, _db.tiles, _db.fights, _db.run_rules, _db.combat_rules,
		_db.effectiveness, int(RunSetup.parse_seed_code(code, version)["seed"]), {"seeded": true})
	var a: RunState = RunSim.start(a_setup)
	var b: RunState = RunSim.start(b_setup)
	var same: bool = a.fingerprint() == b.fingerprint()
	var fights: int = 0
	for n: int in 40:
		var action: Array = RunBot.next_action(a, a_setup)
		if action.is_empty():
			break
		fights += 1 if int(action[0]) == RunSim.FIGHT else 0
		RunSim.apply(a, a_setup, action)
		RunSim.apply(b, b_setup, action)
		same = same and a.fingerprint() == b.fingerprint() and var_to_str(a.pending) == var_to_str(b.pending)
	_check("a run started from its code is the identical run (%s, %d fights)" % [code, fights], same and fights >= 2)
	_check("a seeded run is marked so (options.seeded)", RunSetup.is_seeded(b_setup.options) and not RunSetup.is_seeded(a_setup.options))


# --- 085 ---------------------------------------------------------------------

func _opts_setup(seed_value: int, options: Dictionary) -> RunSetup:
	return RunSetup.create(_db.parts, _db.tiles, _db.fights, _db.run_rules, _db.combat_rules,
		_db.effectiveness, seed_value, options)


func _all_unlocked() -> Array:
	return (_db.meta["unlocks"] as Array).map(func(e: Dictionary) -> String: return String(e["id"]))


## 085 (B4): the rungs' rules reach the game: piles, the start, workshops, the gates, the front.
func _test_rung_rules() -> void:
	var top: int = (_db.meta["tiers"] as Array).size() - 1
	var plain: RunSetup = _setup(21)
	var hard: RunSetup = _opts_setup(21, {"tier": top, "rules": {"adds": Meta.rung_adds(_db.meta, top)}})
	var a: RunState = RunSim.start(plain)
	var b: RunState = RunSim.start(hard)
	_check("rung 0's fights carry no pile rule of their own; the top rung's heal 1 (%s)" % str(RunSim._make_fight(b, hard, 1, "skirmish").get("pile_heal")),
		not RunSim._make_fight(a, plain, 1, "skirmish").has("pile_heal") and int(RunSim._make_fight(b, hard, 1, "skirmish")["pile_heal"]) == 1)
	_check("and a gate that heals nothing still heals nothing (%s)" % str(RunSim._make_fight(b, hard, a.sites.size() - 1, "boss").get("pile_heal")),
		int(RunSim._make_fight(b, hard, b.sites.size() - 1, "boss").get("pile_heal", -1)) == mini(1, int(_db.fights["sorting_gate"].get("pile_heal", 2))))
	_check("the top rung starts the crew on 80%% HP (%d of %d)" % [int(b.crew[0]["hp"]), RunSim.max_hp(hard, b.crew[0])],
		int(b.crew[0]["hp"]) == RunSim.max_hp(hard, b.crew[0]) * 80 / 100 and int(a.crew[0]["hp"]) == RunSim.max_hp(plain, a.crew[0]))
	for st: RunState in [a, b]:
		for member: Dictionary in st.crew:
			member["hp"] = 1
		st.scrap = 50
		st.pending = {"kind": "workshop"}
	RunSim.apply(a, plain, [RunSim.REPAIR])
	RunSim.apply(b, hard, [RunSim.REPAIR])
	_check("a workshop patches 3 on rung 0, 2 on the top rung (%d, %d)" % [int(a.crew[0]["hp"]), int(b.crew[0]["hp"])],
		int(a.crew[0]["hp"]) == 4 and int(b.crew[0]["hp"]) == 3)
	var hs: RunState = RunSim.start(hard)
	var ps: RunState = RunSim.start(plain)
	var lord: Dictionary = RunSim._make_fight(hs, hard, 1, "warlord")
	var lord0: Dictionary = RunSim._make_fight(ps, plain, 1, "warlord")
	var gate: Dictionary = RunSim._make_fight(hs, hard, hs.sites.size() - 1, "boss")
	var gate0: Dictionary = RunSim._make_fight(ps, plain, ps.sites.size() - 1, "boss")
	_check("a warlord brings one more escort on the top rung (%d vs %d), a gate the same (%d vs %d)" % [(lord["enemy"] as Array).size(),
		(lord0["enemy"] as Array).size(), (gate["enemy"] as Array).size(), (gate0["enemy"] as Array).size()],
		(lord["enemy"] as Array).size() == (lord0["enemy"] as Array).size() + 1 and (gate["enemy"] as Array).size() == (gate0["enemy"] as Array).size())


## 085: the start deals -- the same seed offers the same three, one soft; the bay stays open while
## they wait, WALK ON shuts it; the save replays the pick.
func _test_deals() -> void:
	var pool: Array = (_db.run_rules["deals"] as Dictionary)["deals"]
	var soft: Array = pool.filter(func(d: Dictionary) -> bool: return bool(d.get("soft", false))).map(func(d: Dictionary) -> String: return String(d["id"]))
	var seen: Dictionary = {}
	var shaped: bool = true
	var same: bool = true
	for seed_value: int in 300:
		var offer: Array = RunSetup.roll_deals(_db.run_rules, seed_value)
		same = same and offer == RunSetup.roll_deals(_db.run_rules, seed_value)
		var softs: int = offer.filter(func(id: String) -> bool: return soft.has(id)).size()
		var unique: Dictionary = {}
		for id: String in offer:
			unique[id] = true
			seen[id] = int(seen.get(id, 0)) + 1
		shaped = shaped and offer.size() == 3 and softs == 1 and unique.size() == 3
	_check("300 seeds: three distinct deals, exactly one soft, the same three for the same seed", shaped and same)
	_check("every deal turns up (%s)" % [seen], seen.size() == pool.size())
	_check("ContentDB carries the pool in the run rules (so the content hash covers it)", _db.run_rules.has("deals") and not pool.is_empty())
	_check("every cost and gift has words", pool.all(func(d: Dictionary) -> bool:
		return not String(d.get("gift", "")).is_empty() and not String(d.get("cost", "")).is_empty()))
	var setup: RunSetup = _opts_setup(31, {"deals": true})
	var state: RunState = RunSim.start(setup)
	var on_offer: Array = RunSim.deals_on_offer(state, setup)
	_check("a run with deals starts on them: %s" % [on_offer.map(func(d: Dictionary) -> String: return String(d["id"]))],
		String(state.pending.get("kind", "")) == "deals" and on_offer.size() == 3
		and on_offer.map(func(d: Dictionary) -> String: return String(d["id"])) == RunSetup.roll_deals(_db.run_rules, 31)
		and RunSim.destinations(state).is_empty())
	_check("a run with no deals in its options has none (the bot tools, old saves)", RunSim.start(_setup(31)).pending.is_empty())
	var defaults: Array = state.crew.map(func(m: Dictionary) -> Array: return (m["parts"] as Array).duplicate())
	_check("the bay stays open while the deals wait", RunSim.can_assemble(state) and RunSim.apply(state, setup, [RunSim.ASSEMBLE, defaults])
		and String(state.pending.get("kind", "")) == "deals")
	_check("a deal out of range is refused", not RunSim.apply(state, setup, [RunSim.DEAL, 3]) and not RunSim.apply(state, setup, [RunSim.DEAL, -2]))
	var walk: RunState = RunSim.start(setup)
	_check("WALK ON: no gift, no cost, the bay shut, the road open", RunSim.apply(walk, setup, [RunSim.DEAL, -1]) and walk.deal == "walk"
		and walk.pending.is_empty() and not RunSim.can_assemble(walk) and not RunSim.destinations(walk).is_empty()
		and RunSim.deals_on_offer(walk, setup).is_empty() and RunSim.active_costs(walk, setup).is_empty()
		and _region_text(walk) == _region_text(RunSim.start(_setup(31))) and not RunSim.apply(walk, setup, [RunSim.DEAL, 0]))
	# The save replays the pick: a bot run with deals, through the save's JSON and back.
	for policy: String in ["best", "walk"]:
		RunBot.deals = policy
		var live: RunState = RunSim.start(setup)
		var actions: Array = []
		for n: int in 60:
			var action: Array = RunBot.next_action(live, setup)
			if action.is_empty() or not RunSim.apply(live, setup, action):
				break
			actions.append(action)
		var back: Dictionary = RunStore.decode(RunStore.encode(31, "v", actions, [], setup.options))
		var again: RunSetup = _opts_setup(31, back["options"])
		var replayed: RunState = RunSim.replay(again, back["actions"])
		_check("the save replays a run that took a deal (%s: %s, %d actions)" % [policy, live.deal, actions.size()],
			replayed.fingerprint() == live.fingerprint() and int(actions[0][0]) == RunSim.DEAL and actions.size() > 20)
	RunBot.deals = "best"


## 085: what each deal gives and takes, and that its cost is on the map or the HUD.
func _test_deal_effects() -> void:
	var take: Callable = func(id: String, seed_value: int = 41) -> Array:
		var setup: RunSetup = _opts_setup(seed_value, {"deals": true, "deal_offer": [id]})
		var state: RunState = RunSim.start(setup)
		var ok: bool = RunSim.apply(state, setup, [RunSim.DEAL, 0])
		return [state, setup, ok, RunSim.start(_setup(seed_value)), _setup(seed_value)]
	var r: Array = take.call("rare_arm")
	var st: RunState = r[0]
	var rares: int = 0
	for member: Dictionary in st.crew:
		for socket: int in [2, 3]:
			rares += 1 if (r[1] as RunSetup).rarity(String(member["parts"][socket])) == 3 else 0
	_check("rare_arm: a rare arm fitted, the old one in the hold, the Reclaimer a column ahead (%d rare, hold %s, head %d)" % [
		rares, st.cargo, int((RunSim.rules_of(st, r[1])["front"] as Dictionary).get("head", 0))],
		r[2] and rares == 1 and st.cargo.size() == 1 and bool(RunSim.move_preview(st, r[1], RunSim.destinations(st)[0])["advances"])
		and not bool(RunSim.move_preview(r[3], r[4], RunSim.destinations(r[3])[0])["advances"]) and RunSim.active_costs(st, r[1]).size() == 1)
	r = take.call("plating")
	st = r[0]
	var shops: int = st.sites.filter(func(s: Dictionary) -> bool: return String(s["type"]) == "workshop").size()
	var shops0: int = (r[3] as RunState).sites.filter(func(s: Dictionary) -> bool: return String(s["type"]) == "workshop").size()
	_check("plating: every machine +3 max HP and HP, no workshop in Act 1 (%d, was %d)" % [shops, shops0],
		r[2] and shops == 0 and shops0 > 0 and RunSim.max_hp(r[1], st.crew[0]) == RunSim.max_hp(r[4], (r[3] as RunState).crew[0]) + 3
		and int(st.crew[0]["hp"]) == RunSim.max_hp(r[1], st.crew[0]))
	RunSim._next_act(st, r[1])
	_check("and the cost ends with Act 1 (Act 2's weights keep their workshops; the line is off the map)",
		int((RunSim.rules_of(st, r[1])["site_weights"] as Dictionary)["workshop"]) > 0 and RunSim.active_costs(st, r[1]).is_empty())
	r = take.call("scrap")
	st = r[0]
	_check("scrap: +60, enemies +1 damage in Act 1 only", r[2] and st.scrap == (r[3] as RunState).scrap + 60
		and int(((RunSim.rules_of(st, r[1])["enemies"] as Dictionary).get("bonus", {}) as Dictionary).get("damage", 0)) == 1
		and RunSim._make_fight(st, r[1], 1, "skirmish")["enemy"][0]["bonus"]["damage"] == 1)
	r = take.call("module")
	st = r[0]
	var picks: Array = st.pending.get("options", [])
	_check("module: a pick of three uncommon modules (%s), then salvage thinned for three wins" % [picks],
		r[2] and String(st.pending.get("kind", "")) == "reward" and picks.size() == 3
		and picks.all(func(id: String) -> bool: return (r[1] as RunSetup).rarity(id) == 2 and String((_db.parts[id] as Dictionary)["slot"]) == "module")
		and st.thin_salvage == 3 and RunSim.apply(st, r[1], [RunSim.PICK, 0]) and st.cargo.has(String(picks[0])))
	r = take.call("scout")
	st = r[0]
	var hidden: int = 0
	var skirmish: int = -1
	for site: Dictionary in st.sites:
		hidden += 0 if RunSim.revealed(st, int(site["id"])) else 1
		if skirmish < 0 and String(site["type"]) == "skirmish":
			skirmish = int(site["id"])
	_check("scout: every site of Act 1 shown (%d hidden); the next skirmish is an elite on its card" % hidden,
		r[2] and hidden == 0 and skirmish >= 0 and bool(RunSim.fight_preview(st, r[1], skirmish).get("elite", false)))
	var guard: int = 0
	while not String(st.pending.get("kind", "")) == "fight" and guard < 20:
		RunSim.apply(st, r[1], RunBot.next_action(st, r[1]))
		guard += 1
	_check("and the first fight is one (%s), after which the rule is spent" % String(st.pending.get("site_type", "")),
		["elite", "arena", "warlord", "boss"].has(String(st.pending.get("site_type", ""))) and not st.elite_next)
	r = take.call("free_level")
	st = r[0]
	var offer: Array = RunSim.perk_offer(st, r[1], 0)
	var scrap_before: int = st.scrap
	_check("free_level: the next level costs nothing and offers 2 cards (%s)" % [offer], r[2] and RunSim.level_cost(st, r[1], 0) == 0
		and offer.size() == 2 and RunSim.apply(st, r[1], [RunSim.LEVEL_UP, 0, 0]) and st.scrap == scrap_before
		and RunSim.level_cost(st, r[1], 1) > 0 and RunSim.perk_offer(st, r[1], 1).size() == 3 and int(st.crew[0]["level"]) == 1)
	r = take.call("swap_arm")
	st = r[0]
	var changed: Array = []
	for i: int in st.crew.size():
		for socket: int in 5:
			if String(st.crew[i]["parts"][socket]) != String((r[3] as RunState).crew[i]["parts"][socket]):
				changed.append([i, socket, String(st.crew[i]["parts"][socket])])
	_check("swap_arm: exactly one arm became an uncommon (%s), nothing into the hold" % [changed], r[2] and changed.size() == 1
		and [2, 3].has(int(changed[0][1])) and (r[1] as RunSetup).rarity(String(changed[0][2])) == 2 and st.cargo.is_empty())
	var costs: bool = true
	for id: String in ["rare_arm", "plating", "scrap", "module", "scout", "free_level"]:
		var t: Array = take.call(id)
		costs = costs and RunSim.active_costs(t[0], t[1]).size() == 1
	_check("every lasting cost is on the map's line as soon as it is taken (RunSim.active_costs)", costs)


## 085: the daily yard and the weekly contract -- a fixed day or week gives fixed options and region.
func _test_challenges() -> void:
	var day: int = 20750   # 2026-10-24
	var d1: Dictionary = RunSetup.daily_options(_db.run_rules, day)
	var d2: Dictionary = RunSetup.daily_options(_db.run_rules, day)
	var next: Dictionary = RunSetup.daily_options(_db.run_rules, day + 1)
	print("  daily %d: seed %d, conditions %s, deals %s" % [day, int(d1["seed"]), d1["conditions"], d1["deal_offer"]])
	_check("a day gives one daily, the same twice; the next day another", d1 == d2 and int(d1["seed"]) != int(next["seed"])
		and String(d1["mode"]) == "daily" and int(d1["tier"]) == 0)
	_check("the daily's seed is pinned to the day (a change here changes everyone's daily)", int(d1["seed"]) == DAILY_20750_SEED)
	var opts: Dictionary = Meta.challenge_options(_db.meta, d1, "wall")
	var a: RunSetup = _opts_setup(int(d1["seed"]), opts)
	var b: RunSetup = _opts_setup(int(d2["seed"]), Meta.challenge_options(_db.meta, d2, "wall"))
	var conds: Array = []
	for act: int in range(1, 4):
		conds.append(RunSim.act_condition(null, a, act))
	_check("its region and conditions are the same for every player (%s)" % [conds], _region_text(RunSim.start(a)) == _region_text(RunSim.start(b))
		and conds == d1["conditions"] and conds.all(func(c: String) -> bool: return not c.is_empty()))
	_check("the daily offers its fixed deals, any crew, rung 0, and counts for nothing on the ladder",
		RunSim.start(a).deal_offer == d1["deal_offer"] and RunSetup.is_seeded(opts) and int(opts["tier"]) == 0
		and Array(RunSim.start(a).crew[0]["parts"])[0] == "ch_bulwark" and (opts["locked"] as Array).size() == (_db.meta["locked"] as Array).size())
	var conditions: Dictionary = {}
	for n: int in 200:
		for c: Variant in (RunSetup.daily_options(_db.run_rules, day + n)["conditions"] as Array):
			conditions[c] = int(conditions.get(c, 0)) + 1
	_check("over 200 days every condition turns up (%s)" % [conditions], conditions.size() == 4)
	var week: int = 2963
	var w1: Dictionary = RunSetup.weekly_options(_db.run_rules, week)
	print("  weekly %d: seed %d, crew %s, rung %d, twists %s" % [week, int(w1["seed"]), w1["crew_id"], int(w1["rung"]),
		(w1["twists"] as Array).map(func(t: Dictionary) -> String: return String(t["id"]))])
	_check("a week gives one contract, the same twice: a fixed crew, rung 4, three twists",
		w1 == RunSetup.weekly_options(_db.run_rules, week) and int(w1["seed"]) == WEEKLY_2963_SEED and int(w1["rung"]) == 4
		and (w1["twists"] as Array).size() == 3 and String(w1["mode"]) == "weekly")
	var plates: Array = _db.meta.get("plates", [])
	var turn: Array = []
	for n: int in 6:
		turn.append(String((RunSetup.weekly_options(_db.run_rules, week + n, plates).get("plate", {}) as Dictionary).get("id", "")))
	_check("the weekly plates come in turn, week %% 5 (%s)" % [turn], plates.size() == 5 and turn[5] == turn[0]
		and turn.slice(0, 5).all(func(id: String) -> bool: return not id.is_empty()) and turn[0] == String(plates[posmod(week, 5)]["id"])
		and RunSetup.weekly_options(_db.run_rules, 0, plates)["plate"]["id"] == "pl_name" and RunSetup.weekly_options(_db.run_rules, 4, plates)["plate"]["id"] == "pl_hubcap")
	var crews: Dictionary = {}
	var twists: Dictionary = {}
	for n: int in 30:
		var w: Dictionary = RunSetup.weekly_options(_db.run_rules, week + n)
		crews[w["crew_id"]] = true
		for t: Dictionary in (w["twists"] as Array):
			twists[t["id"]] = true
	_check("weeks rotate the crews (%d) and draw every twist (%d of %d)" % [crews.size(), twists.size(),
		(_db.run_rules["challenges"]["twists"] as Dictionary).size()], crews.size() == 3
		and twists.size() == (_db.run_rules["challenges"]["twists"] as Dictionary).size())
	var wo: Dictionary = Meta.challenge_options(_db.meta, w1, "salvagers")
	var ws: RunSetup = _opts_setup(int(w1["seed"]), wo)
	var wstate: RunState = RunSim.start(ws)
	var rungs: int = Meta.rung_adds(_db.meta, 4).size()
	_check("the contract plays rung 4's adds, its crew's rule and its twists, and says so (%s)" % [RunSim.active_costs(wstate, ws)],
		String(wo["crew_id"]) == String(w1["crew_id"]) and (ws.rules["adds"] as Array).size() >= rungs + 3
		and RunSim.active_costs(wstate, ws).size() == 3 and RunSetup.is_seeded(wo))
	var no_shop: RunSetup = _opts_setup(5, Meta.challenge_options(_db.meta,
		{"seed": 5, "mode": "weekly", "tier": 4, "rules": {"adds": (_db.run_rules["challenges"]["twists"]["no_workshops"]["adds"] as Array).duplicate(true)}}))
	var nst: RunState = RunSim.start(no_shop)
	var shops: int = 0
	for act: int in range(1, 4):
		shops += nst.sites.filter(func(s: Dictionary) -> bool: return String(s["type"]) == "workshop").size()
		if act < 3:
			RunSim._next_act(nst, no_shop)
	_check("a twist is a real rule: no workshops means none in any act (%d)" % shops, shops == 0)


## 085 (B9): each crew changes one run rule.
func _test_crew_rules() -> void:
	var all: Array = _all_unlocked()
	var sal: RunSetup = _opts_setup(9, Meta.options(_db.meta, all, "salvagers", 0))
	var plain: RunSetup = _setup(9)
	var st: RunState = RunSim.start(sal)
	st.pending = {}
	st.current = 1
	var offered: int = (RunSim.salvage(st, sal, "skirmish")["options"] as Array).size()
	var st3: RunState = RunSim.start(sal)
	st3.act = 3
	_check("the Salvagers see 4 salvage parts, in every act (%d; act 3 %d; plain %d)" % [offered,
		(RunSim.salvage(st3, sal, "skirmish")["options"] as Array).size(), (RunSim.salvage(RunSim.start(plain), plain, "skirmish")["options"] as Array).size()],
		offered == 4 and (RunSim.salvage(st3, sal, "skirmish")["options"] as Array).size() == 4
		and (RunSim.salvage(RunSim.start(plain), plain, "skirmish")["options"] as Array).size() == 3)
	var wall: RunSetup = _opts_setup(9, Meta.options(_db.meta, all, "wall", 0))
	var slab: GridUnit = RunSim.preview_machine(wall, RunSim.start(wall).crew[0])
	var bare_opts: Dictionary = Meta.options(_db.meta, all, "wall", 0)
	bare_opts.erase("rules")
	var bare: RunSetup = _opts_setup(9, bare_opts)
	var cooldowns: Array = []
	var sooner: bool = true
	for i: int in 3:
		var with: GridUnit = RunSim.preview_machine(wall, RunSim.start(wall).crew[i])
		var without: GridUnit = RunSim.preview_machine(bare, RunSim.start(bare).crew[i])
		for k: int in with.abilities.size():
			cooldowns.append("%s %d (was %d)" % [with.abilities[k]["id"], int(with.abilities[k]["cooldown"]), int(without.abilities[k]["cooldown"])])
			sooner = sooner and int(with.abilities[k]["cooldown"]) == maxi(1, int(without.abilities[k]["cooldown"]) - 1)
	_check("the Wall's abilities come back a round sooner (%s)" % [cooldowns], not slab.abilities.is_empty() and sooner)
	var run: RunSetup = _opts_setup(9, Meta.options(_db.meta, all, "runners", 0))
	var pace: int = int((RunSim.rules_of(RunSim.start(run), run)["front"] as Dictionary)["pace"])
	_check("the Runners have a slower Reclaimer behind them (pace %d)" % pace, pace == int(_db.run_rules["front"]["pace"]) + 25)
	_check("every crew names its rule for the crew card", (_db.meta["crews"] as Dictionary).values().all(func(c: Dictionary) -> bool:
		return not String(c.get("rule", "")).is_empty() and not (c.get("rules", {}) as Dictionary).is_empty()))


## 085 (B10): medals, read off staged runs.
func _test_medals() -> void:
	var ids: Dictionary = {}
	var shaped: bool = true
	for crew: Variant in (_db.meta["crews"] as Dictionary):
		var medals: Array = Meta.medals(_db.meta, String(crew))
		shaped = shaped and medals.size() == 3
		for m: Dictionary in medals:
			shaped = shaped and not ids.has(m["id"]) and not String(m.get("text", "")).is_empty() and not String(m.get("name", "")).is_empty()
			ids[m["id"]] = true
	_check("three medals per crew, every id unique, every one worded (%d)" % ids.size(), shaped and ids.size() == 9)
	var all: Array = _all_unlocked()
	var stage: Callable = func(crew: String, tier: int, won: bool, feats: Dictionary, workshops: int, legend: bool) -> Array:
		var setup: RunSetup = _opts_setup(3, Meta.options(_db.meta, all, crew, tier))
		var state: RunState = RunSim.start(setup)
		state.outcome = RunState.WON if won else RunState.LOST
		state.feats = feats
		state.visits = {"workshop": workshops} if workshops > 0 else {}
		if legend:
			state.crew[0]["parts"][2] = "ar_sunspear" if _db.parts.has("ar_sunspear") else String((setup.pools["arm"] as Array).filter(
				func(id: String) -> bool: return setup.rarity(id) == 4)[0])
		return RunSim.medals_earned(state, setup)
	_check("a clean win with no legendary on rung 2: NOTHING FANCY and CLEAN SHEET; on rung 0 only NOTHING FANCY",
		stage.call("salvagers", 2, true, {}, 1, false) == ["sal_clean", "sal_plain"] and stage.call("salvagers", 0, true, {}, 1, false) == ["sal_plain"])
	_check("with a legendary fitted and a fight lost: neither", stage.call("salvagers", 2, true, {"fights_lost": 1}, 1, true).is_empty())
	_check("five pit kills in a lost run: GRAVEDIGGER (four: no)", stage.call("salvagers", 0, false, {"pit_kills": 5}, 0, false) == ["sal_pits"]
		and stage.call("salvagers", 0, false, {"pit_kills": 4}, 0, false).is_empty())
	_check("the Wall on rung 4, no workshop, nothing wrecked: NO PIT STOPS and NOT A DENT",
		stage.call("wall", 4, true, {}, 0, false) == ["wall_dry", "wall_whole"])
	_check("the same on rung 3: only NOT A DENT; a workshop on rung 4: only NOT A DENT; rung 1: neither",
		stage.call("wall", 3, true, {}, 0, false) == ["wall_whole"] and stage.call("wall", 4, true, {}, 2, false) == ["wall_whole"]
		and stage.call("wall", 1, true, {}, 0, false).is_empty())
	_check("the Runners: 8 flawless fights and a win with a machine wrecked on rung 5: GHOSTS, TRAVEL LIGHT",
		stage.call("runners", 5, true, {"flawless": 8, "wrecked": 1}, 0, false) == ["run_ghost", "run_light"])
	_check("a run still going has earned nothing", RunSim.medals_earned(RunSim.start(_setup(3)), _setup(3)).is_empty())

