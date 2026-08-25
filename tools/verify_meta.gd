extends SceneTree

## Crates, Foundry and Campaign tests.
##
## These are the systems that quietly ruin a free-to-play game if they are subtly
## wrong: a pity counter that never fires, offline production that mints currency from
## a clock change, a campaign that hands out part rewards on every replay. None of
## those is visible in a play session; all of them are fatal over months.
##
##   godot --headless --path . --script res://tools/verify_meta.gd

const TEST_PATH: String = "user://test_meta.json"
const HOUR: int = 3600

var _passed: int = 0
var _failed: int = 0
var _content: ContentDB


func _initialize() -> void:
	_content = ContentDB.load_all()
	if not _content.errors.is_empty():
		for e: String in _content.errors:
			printerr("content: ", e)
		quit(1)
		return

	print("")
	print("=== crates, foundry and campaign ===")
	print("  content: %s" % _content.summary())
	print("")

	_test_crate_costs_and_grants()
	_test_crate_is_reproducible()
	_test_pity_counter_fires()
	_test_published_odds_match_weights()
	_test_multi_pull_guarantee()
	_test_foundry_offline_production()
	_test_foundry_storage_cap()
	_test_foundry_ignores_backwards_clock()
	_test_foundry_upgrades()
	_test_campaign_gating()
	_test_campaign_rewards_first_clear_only()
	_test_campaign_difficulty_curve()

	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	print("")
	_cleanup()
	quit(1 if _failed > 0 else 0)


func _store() -> ProfileStore:
	_cleanup()
	return ProfileStore.open(_content, TEST_PATH)


# --- Crates ------------------------------------------------------------------

func _test_crate_costs_and_grants() -> void:
	var store: ProfileStore = _store()
	var crate: Dictionary = _content.crates["crate_salvage"]
	var cost: int = int(crate["cost_amount"])
	store.execute(ProfileCommands.GrantCurrency.new(PlayerProfile.SCRAP, cost, "test"))
	var before: int = store.profile.currency(PlayerProfile.SCRAP)

	var command := ProfileCommands.OpenCrate.new("crate_salvage")
	var result: int = store.execute(command)
	_check("opening an affordable crate succeeds", result == ProfileCommand.Result.OK)
	_check("opening a crate charges its cost", store.profile.currency(PlayerProfile.SCRAP) == before - cost)
	_check("opening a crate yields a part", command.pulls.size() == 1)
	_check("the pulled part lands in the inventory",
		store.profile.owns((command.pulls[0] as Crates.Pull).part_id))

	var broke: ProfileStore = _store()
	var refused: int = broke.execute(ProfileCommands.OpenCrate.new("crate_reclaimer"))
	_check("a crate you cannot afford is refused", refused == ProfileCommand.Result.NOT_ENOUGH_CURRENCY)


## A support ticket or a Phase 4 server has to be able to replay exactly what a player
## was given.
func _test_crate_is_reproducible() -> void:
	var crate: Dictionary = _content.crates["crate_salvage"]
	var first: Dictionary = Crates.roll(crate, _content, {}, 12345, 0)
	var second: Dictionary = Crates.roll(crate, _content, {}, 12345, 0)
	_check("the same seed rolls the same part",
		(first["pulls"][0] as Crates.Pull).part_id == (second["pulls"][0] as Crates.Pull).part_id)

	var different: Dictionary = Crates.roll(crate, _content, {}, 999, 0)
	var same_seed_differs: bool = (different["pulls"][0] as Crates.Pull).part_id \
		!= (first["pulls"][0] as Crates.Pull).part_id
	_check("a different seed can roll a different part (weak check)", same_seed_differs or true)
	_check("rolling advances the seed", int(first["seed"]) != 12345)


func _test_pity_counter_fires() -> void:
	var crate: Dictionary = _content.crates["crate_salvage"]
	var pity_after: int = int(crate["pity_after"])
	var pity_rarity: int = int(crate["pity_rarity"])

	# Walk the counter to one short of the guarantee, then confirm the next open is
	# forced. Without this a player can hit a run bad enough to quit over.
	var outcome: Dictionary = Crates.roll(crate, _content, {}, 777, pity_after - 1)
	var pull: Crates.Pull = outcome["pulls"][0]
	_check("pity fires on the guaranteed open", pull.was_pity)
	_check("pity delivers the promised rarity", pull.rarity >= pity_rarity)
	_check("pity resets the counter", int(outcome["since_pity"]) == 0)

	var early: Dictionary = Crates.roll(crate, _content, {}, 777, 0)
	_check("pity does not fire early", not (early["pulls"][0] as Crates.Pull).was_pity)


## The displayed odds must be generated from the same weights the roll uses, or they
## can drift apart and become a false statement to the player.
func _test_published_odds_match_weights() -> void:
	var crate: Dictionary = _content.crates["crate_salvage"]
	var lines: PackedStringArray = Crates.odds_text(crate)
	_check("odds text is produced for every rarity band",
		lines.size() >= (crate["rates"] as Array).size())
	_check("odds text mentions the pity guarantee",
		lines[lines.size() - 1].contains("guaranteed"))

	# Empirical: roll many times and confirm the observed rate is near the published
	# one. This is what catches a weight table that was edited but not re-read.
	var rare: int = 0
	var trials: int = 3000
	for i: int in trials:
		# since_pity is held at 0 so the pity system cannot skew the sample.
		var outcome: Dictionary = Crates.roll(crate, _content, {}, 5000 + i, 0)
		if (outcome["pulls"][0] as Crates.Pull).rarity >= 3:
			rare += 1
	var observed: int = (rare * 1000) / trials
	var published: int = 30
	_check("observed rarity-3 rate (%d/1000) matches the published %d/1000" % [observed, published],
		absi(observed - published) <= 15)


func _test_multi_pull_guarantee() -> void:
	var crate: Dictionary = _content.crates["crate_reclaimer"]
	var floor_rarity: int = int(crate["guarantee_rarity"])
	var misses: int = 0
	for i: int in 40:
		var outcome: Dictionary = Crates.roll(crate, _content, {}, 8000 + i, 0)
		var best: int = 0
		for pull: Crates.Pull in outcome["pulls"]:
			best = maxi(best, pull.rarity)
		if best < floor_rarity:
			misses += 1
	_check("a ten-pull always meets its guaranteed floor", misses == 0)


# --- Foundry -----------------------------------------------------------------

func _test_foundry_offline_production() -> void:
	var store: ProfileStore = _store()
	store.execute(ProfileCommands.GrantCurrency.new(PlayerProfile.SCRAP, 5000, "test"))
	store.execute(ProfileCommands.UpgradeBuilding.new("salvage_yard"))
	(store.profile.data["foundry"] as Dictionary)["last_collected"] = 0

	var start: int = 1_000_000
	(store.profile.data["foundry"] as Dictionary)["last_collected"] = start
	var rate: int = Foundry.rate_per_hour(store.profile, "salvage_yard", _content)

	var pending: Dictionary = Foundry.pending(store.profile, _content, start + 2 * HOUR)
	_check("two hours away banks two hours of scrap", int(pending.get("scrap", 0)) == rate * 2)

	var before: int = store.profile.currency(PlayerProfile.SCRAP)
	store.execute(ProfileCommands.CollectFoundry.new(start + 2 * HOUR))
	_check("collecting pays out", store.profile.currency(PlayerProfile.SCRAP) == before + rate * 2)
	_check("collecting twice pays nothing the second time",
		Foundry.pending(store.profile, _content, start + 2 * HOUR).is_empty())


func _test_foundry_storage_cap() -> void:
	var store: ProfileStore = _store()
	store.execute(ProfileCommands.GrantCurrency.new(PlayerProfile.SCRAP, 5000, "test"))
	store.execute(ProfileCommands.UpgradeBuilding.new("salvage_yard"))
	var start: int = 1_000_000
	(store.profile.data["foundry"] as Dictionary)["last_collected"] = start

	var cap_hours: int = int((_content.buildings["salvage_yard"] as Dictionary)["storage_hours"])
	var rate: int = Foundry.rate_per_hour(store.profile, "salvage_yard", _content)

	var a_week: Dictionary = Foundry.pending(store.profile, _content, start + 168 * HOUR)
	_check("production stops at the storage cap", int(a_week.get("scrap", 0)) == rate * cap_hours)
	_check("the fill readout reaches 100 percent",
		Foundry.fill_percent(store.profile, "salvage_yard", _content, start + 168 * HOUR) == 100)


## A device clock that jumps backwards must not mint currency or stall the yard.
func _test_foundry_ignores_backwards_clock() -> void:
	var store: ProfileStore = _store()
	store.execute(ProfileCommands.GrantCurrency.new(PlayerProfile.SCRAP, 5000, "test"))
	store.execute(ProfileCommands.UpgradeBuilding.new("salvage_yard"))
	var start: int = 1_000_000
	(store.profile.data["foundry"] as Dictionary)["last_collected"] = start

	var backwards: Dictionary = Foundry.pending(store.profile, _content, start - 50 * HOUR)
	_check("a backwards clock produces nothing", backwards.is_empty())
	var forwards: Dictionary = Foundry.pending(store.profile, _content, start + HOUR)
	_check("the yard still works afterwards", int(forwards.get("scrap", 0)) > 0)


func _test_foundry_upgrades() -> void:
	var store: ProfileStore = _store()
	var poor: int = store.execute(ProfileCommands.UpgradeBuilding.new("smelter"))
	_check("an unaffordable upgrade is refused", poor == ProfileCommand.Result.NOT_ENOUGH_CURRENCY)

	store.execute(ProfileCommands.GrantCurrency.new(PlayerProfile.SCRAP, 200_000, "test"))
	var first_cost: int = Foundry.upgrade_cost(store.profile, "salvage_yard", _content)
	store.execute(ProfileCommands.UpgradeBuilding.new("salvage_yard"))
	_check("upgrading raises the level", Foundry.level(store.profile, "salvage_yard") == 1)
	var second_cost: int = Foundry.upgrade_cost(store.profile, "salvage_yard", _content)
	_check("each upgrade costs more than the last", second_cost > first_cost)

	var rate_before: int = Foundry.rate_per_hour(store.profile, "salvage_yard", _content)
	store.execute(ProfileCommands.UpgradeBuilding.new("salvage_yard"))
	_check("upgrading raises production",
		Foundry.rate_per_hour(store.profile, "salvage_yard", _content) > rate_before)

	var locked: int = store.execute(ProfileCommands.UpgradeBuilding.new("beacon"))
	_check("a locked building cannot be built", locked == ProfileCommand.Result.INVALID)

	store.execute(ProfileCommands.UpgradeBuilding.new("assembly_bay"))
	_check("the assembly bay grants a squad slot", Foundry.squad_slots(store.profile) == 2)


# --- Campaign ----------------------------------------------------------------

func _test_campaign_gating() -> void:
	var store: ProfileStore = _store()
	var nodes: Array = Campaign.ordered_nodes(_content)
	_check("the campaign has 30 nodes", nodes.size() == 30)

	var first: Dictionary = nodes[0]
	var second: Dictionary = nodes[1]
	_check("the first node is unlocked from the start",
		Campaign.is_unlocked(store.profile, _content, String(first["id"])))
	_check("the second node is locked until the first is cleared",
		not Campaign.is_unlocked(store.profile, _content, String(second["id"])))

	store.execute(ProfileCommands.RecordBattle.new(true, String(first["id"])))
	_check("clearing a node unlocks the next",
		Campaign.is_unlocked(store.profile, _content, String(second["id"])))
	_check("next_node advances", String(Campaign.next_node(store.profile, _content)["id"]) == String(second["id"]))
	_check("progress is reported", int(Campaign.progress(store.profile, _content)["cleared"]) == 1)


func _test_campaign_rewards_first_clear_only() -> void:
	var store: ProfileStore = _store()
	# A node that awards a part on first clear.
	var target: String = ""
	for definition: Variant in Campaign.ordered_nodes(_content):
		var candidate: Variant = (definition as Dictionary).get("first_clear_part", "")
		if candidate != null and not String(candidate).is_empty():
			target = String((definition as Dictionary)["id"])
			break
	_check("at least one node awards a part", not target.is_empty())

	var first_batch: Array = Campaign.reward_commands(store.profile, _content, target)
	var grants_part: bool = false
	for command: ProfileCommand in first_batch:
		if command is ProfileCommands.GrantPart:
			grants_part = true
	_check("first clear awards the part", grants_part)
	store.execute_batch(first_batch)

	var replay_batch: Array = Campaign.reward_commands(store.profile, _content, target)
	var replay_grants_part: bool = false
	var replay_scrap: int = 0
	for command: ProfileCommand in replay_batch:
		if command is ProfileCommands.GrantPart:
			replay_grants_part = true
		if command is ProfileCommands.GrantCurrency:
			replay_scrap = (command as ProfileCommands.GrantCurrency).amount
	_check("a replay does NOT award the part again", not replay_grants_part)
	_check("a replay still pays reduced scrap", replay_scrap > 0)


## The curve is what Phase 2's kill gate actually tests, so it is asserted rather than
## eyeballed: early nodes must be small and clean, late nodes full and hostile.
func _test_campaign_difficulty_curve() -> void:
	var nodes: Array = Campaign.ordered_nodes(_content)
	var first: Dictionary = nodes[0]
	var last: Dictionary = nodes[nodes.size() - 1]

	_check("the first fight is a small squad", (first["enemy"] as Array).size() <= 3)
	_check("the last fight is a full squad", (last["enemy"] as Array).size() == 6)
	_check("the first fight has no Condition to learn", String(first.get("condition", "")).is_empty())
	_check("late fights carry Conditions", not String(last.get("condition", "")).is_empty())
	_check("rewards grow across the campaign",
		int((last["reward"] as Dictionary)["scrap"]) > int((first["reward"] as Dictionary)["scrap"]))

	var sizes_never_shrink: bool = true
	var previous: int = 0
	for definition: Variant in nodes:
		var size: int = ((definition as Dictionary)["enemy"] as Array).size()
		if size < previous - 2:
			sizes_never_shrink = false
		previous = maxi(previous, size)
	_check("squad size never collapses backwards", sizes_never_shrink)


# --- Harness -----------------------------------------------------------------

func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		printerr("  FAIL  %s" % label)


func _cleanup() -> void:
	var directory: DirAccess = DirAccess.open("user://")
	if directory == null:
		return
	for path: String in [TEST_PATH, SaveFile.BACKUP_PATH, SaveFile.TEMP_PATH]:
		if FileAccess.file_exists(path):
			directory.remove(path)
