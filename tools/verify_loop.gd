extends SceneTree

## End-to-end loop test: campaign node -> battle -> rewards -> progression.
##
## Every other test checks a system in isolation. This one asks the question that
## actually decides whether Phase 2 works: **can the squad the game hands a new player
## beat the campaign it puts in front of them, and does clearing nodes pay for the
## upgrades the next ones require?**
##
## A game can pass every unit test and still be unplayable because node 1 is
## unwinnable or the scrap curve starves the player at node 6. That is only visible
## from here.
##
##   godot --headless --path . --script res://tools/verify_loop.gd

const TEST_PATH: String = "user://test_loop.json"

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
	print("=== full loop: can a new player actually play this? ===")

	var store: ProfileStore = _fresh_store()
	_grant_starter(store)

	print("")
	print("  starting out: %s" % store.profile.summary())
	print("")
	print("  %-4s %-14s %-7s %-8s %-9s %-7s %s" % [
		"node", "name", "enemies", "result", "cycles", "scrap", "running total"])

	var cleared: int = 0
	var attempted: int = 0
	var first_loss: int = -1

	for definition: Variant in Campaign.ordered_nodes(_content):
		var d: Dictionary = definition as Dictionary
		var node_id: String = String(d["id"])
		if not Campaign.is_unlocked(store.profile, _content, node_id):
			break
		attempted += 1

		# The player's squad on Auto against the node. Auto is the honest floor: if the
		# doctrine cannot clear it, a player still learning the Order Phase cannot.
		var setup: BattleSetup = Campaign.build_setup(
			store.profile, _content, node_id, "main", 7000 + attempted)
		var result: BattleResult = BattleSim.simulate(setup, [], _content.to_sim_content(), _content.balance)
		var won: bool = result.winner == SimDefs.TEAM_A

		var before: int = store.profile.currency(PlayerProfile.SCRAP)
		if won:
			store.execute_batch(Campaign.reward_commands(store.profile, _content, node_id))
			cleared += 1
		else:
			store.award_battle(false, result.cycles, "")
			if first_loss < 0:
				first_loss = attempted

		print("  %-4d %-14s %-7d %-8s %-9d %-7d %d" % [
			attempted, String(d["name"]), (d["enemy"] as Array).size(),
			"WIN" if won else "loss", result.cycles,
			store.profile.currency(PlayerProfile.SCRAP) - before,
			store.profile.currency(PlayerProfile.SCRAP)])

		# Spend winnings the way a player would: level the squad's parts when affordable.
		if won:
			_spend_on_squad(store)

		if not won:
			break
		if attempted >= 12:
			break

	print("")
	_check("the starter squad wins node 1 on Auto", cleared >= 1)
	_check("it clears at least the first five nodes", cleared >= 5)
	_check("progress is recorded", int(Campaign.progress(store.profile, _content)["cleared"]) == cleared)
	_check("the player is not bankrupt after clearing", store.profile.currency(PlayerProfile.SCRAP) >= 0)

	if first_loss > 0:
		print("  first loss at node %d — that is the difficulty wall to tune." % first_loss)
	else:
		print("  no loss in the first %d nodes." % attempted)

	_test_foundry_pays_for_progress(store)
	_test_squad_survives_a_refit(store)

	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	print("")
	_cleanup()
	quit(1 if _failed > 0 else 0)


## The upgrade loop has to be reachable from play, not just from a debug grant.
func _test_foundry_pays_for_progress(store: ProfileStore) -> void:
	var now: int = 2_000_000
	(store.profile.data["foundry"] as Dictionary)["last_collected"] = now
	var overnight: Dictionary = Foundry.pending(store.profile, _content, now + 8 * 3600)
	_check("a night away banks meaningful scrap", int(overnight.get("scrap", 0)) > 200)

	var before: int = store.profile.currency(PlayerProfile.SCRAP)
	store.execute(ProfileCommands.CollectFoundry.new(now + 8 * 3600))
	_check("collecting it works", store.profile.currency(PlayerProfile.SCRAP) > before)


## A Refit consumes duplicates. If that could invalidate the active squad, a player
## would be locked out of the campaign by using a system the game told them to use.
func _test_squad_survives_a_refit(store: ProfileStore) -> void:
	_check("the squad is still valid after a play session",
		store.profile.squad_is_valid("main"))

	var part_id: String = "ch_brute"
	for _i: int in 6:
		store.execute(ProfileCommands.GrantPart.new(part_id))
	store.execute(ProfileCommands.GrantCurrency.new(PlayerProfile.ALLOY, 4000, "test"))
	store.execute(ProfileCommands.RefitPart.new(part_id))
	_check("a squad part stays usable after being refit",
		store.profile.owns(part_id) and store.profile.squad_is_valid("main"))


## Levels whatever in the active squad is affordable, cheapest first — a reasonable
## model of how a player actually spends.
func _spend_on_squad(store: ProfileStore) -> void:
	var ids: PackedStringArray = []
	for spec: Variant in store.profile.squad("main"):
		for key: Variant in ((spec as Dictionary).get("parts", {}) as Dictionary).values():
			var id: String = String(key)
			if not id.is_empty() and not ids.has(id):
				ids.append(id)

	var guard: int = 0
	while guard < 12:
		guard += 1
		var cheapest: String = ""
		var cheapest_cost: int = 0
		for id: String in ids:
			if store.profile.is_max_level(id):
				continue
			var cost: int = Economy.level_cost(store.profile, id, _content)
			if cheapest.is_empty() or cost < cheapest_cost:
				cheapest = id
				cheapest_cost = cost
		if cheapest.is_empty() or not store.profile.can_afford(PlayerProfile.SCRAP, cheapest_cost):
			return
		if store.execute(ProfileCommands.LevelPart.new(cheapest)) != ProfileCommand.Result.OK:
			return


# --- Setup -------------------------------------------------------------------

func _fresh_store() -> ProfileStore:
	_cleanup()
	return ProfileStore.open(_content, TEST_PATH)


## Mirrors what `Session` grants a brand-new player, so this test measures the real
## starting position rather than an invented one.
func _grant_starter(store: ProfileStore) -> void:
	var starter: PackedStringArray = [
		"ch_brute", "ch_skirmisher", "ch_hauler",
		"co_slug", "co_dynamo", "co_furnace",
		"ar_ripper", "ar_hammer", "ar_pulse", "ar_scanner", "ar_lance",
		"mo_governor", "mo_ablative",
	]
	var commands: Array = []
	for part_id: String in starter:
		commands.append(ProfileCommands.GrantPart.new(part_id))
	store.execute_batch(commands)
	store.execute(ProfileCommands.SetSquad.new("main", [
		_spec("Anvil", "ch_hauler", "co_slug", "ar_hammer", "ar_hammer", "mo_ablative"),
		_spec("Grinder", "ch_brute", "co_furnace", "ar_ripper", "ar_ripper", "mo_governor"),
		_spec("Ledger", "ch_hauler", "co_slug", "ar_ripper", "ar_hammer", "mo_ablative"),
		_spec("Sparrow", "ch_skirmisher", "co_dynamo", "ar_pulse", "ar_lance", "mo_governor"),
	]))
	store.execute(ProfileCommands.UpgradeBuilding.new("salvage_yard"))


func _spec(name: String, chassis: String, core: String, arm_l: String, arm_r: String, module: String) -> Dictionary:
	return {"name": name, "parts": {
		"chassis": chassis, "core": core, "arm_l": arm_l, "arm_r": arm_r, "module": module}}


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
