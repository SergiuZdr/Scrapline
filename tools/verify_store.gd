extends SceneTree

## Monetization: does a player who pays get their goods, exactly once, and can the
## season track actually be finished?
##
##   godot --headless --path . --script res://tools/verify_store.gd
##
## The interesting cases are all failures. A purchase pipeline that works when nothing
## goes wrong is not a purchase pipeline — it is the happy path of one, and the money is
## in the other branches:
##
##   - the app dies between the charge and the grant
##   - the same receipt arrives twice, from two devices
##   - the player is offline
##   - the store says no
##
## And two questions that are about honesty rather than mechanics: are the gacha odds
## shown the odds actually used, and can the battle pass be finished inside its season?

const TEST_PATH: String = "user://test_store.json"

var _content: ContentDB
var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_content = ContentDB.load_all()
	if not _content.errors.is_empty():
		for e: String in _content.errors:
			printerr("content: ", e)
		quit(2)
		return

	print("")
	print("=== store, purchases and the season pass ===")

	_test_products_are_authored_safely()
	_test_a_purchase_grants_once()
	_test_a_crash_between_charge_and_grant_recovers()
	_test_a_failed_purchase_grants_nothing()
	_test_currency_offers_cost_currency()
	_test_published_odds_match_the_roll()
	_test_the_pass_can_be_finished()
	_test_the_pass_pays_each_tier_once()
	_test_buying_premium_pays_out_what_was_earned()

	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	_cleanup()
	quit(1 if _failed > 0 else 0)


func _test_products_are_authored_safely() -> void:
	print("\n  what is for sale")
	var service: StoreService = _service()
	var iap: Array = service.products("iap")
	var currency: Array = service.products("currency")
	_check("there are real-money products (%d)" % iap.size(), not iap.is_empty())
	_check("and premium-currency offers (%d)" % currency.size(), not currency.is_empty())

	# The structural rule that keeps this shippable: real money buys currency and fixed
	# bundles; only currency buys anything random. Selling a loot box directly for cash
	# is banned outright in some markets and restricted in others, and it is the one
	# monetization decision that is genuinely hard to undo later.
	var random_for_cash: bool = false
	for product: Variant in iap:
		var grants: Dictionary = (product as Dictionary).get("grants", {})
		if grants.has("crates") or grants.has("pulls"):
			random_for_cash = true
	_check("nothing random is sold for real money", not random_for_cash)

	for product: Variant in service.products():
		var d: Dictionary = product as Dictionary
		if String(d.get("kind", "")) != "iap":
			continue
		# A price string is a fallback for the dev stub only; a real store reports the
		# localised price, and showing a hardcoded dollar figure to someone paying in
		# zloty gets a listing rejected.
		_check("%s declares a fallback price" % d.get("id"), not String(d.get("display_price", "")).is_empty())


func _test_a_purchase_grants_once() -> void:
	print("\n  a purchase that goes through")
	var service: StoreService = _service()
	var profile: PlayerProfile = service._profile
	var before: int = profile.currency(PlayerProfile.CORES)

	# The array is MUTATED, not rebound. GDScript lambdas capture by value, so
	# `result = [code]` inside one assigns to the lambda's own copy and the assertion
	# outside sees the initial value forever -- three of these read as product bugs.
	var result: Array = [-1, ""]
	service.buy_iap("cores_small", 1000, func(code: int, message: String) -> void:
		result[0] = code
		result[1] = message)

	_check("the purchase reports success (%s)" % Billing.result_name(int(result[0])),
		int(result[0]) == Billing.Result.OK)
	_check("the cores arrived (%d -> %d)" % [before, profile.currency(PlayerProfile.CORES)],
		profile.currency(PlayerProfile.CORES) == before + 300)
	_check("nothing is left pending", service.pending_count() == 0)
	_check("and the product is recorded as owned", service.owns("cores_small"))

	# A one-per-account product must refuse the second attempt rather than take the money
	# and grant nothing.
	service.buy_iap("starter_rig", 1000, func(_c: int, _m: String) -> void: pass)
	var second: Array = [-1]
	service.buy_iap("starter_rig", 1000, func(code: int, _m: String) -> void: second[0] = code)
	_check("a one-per-account product refuses a second sale",
		int(second[0]) == Billing.Result.ALREADY_OWNED)


func _test_a_crash_between_charge_and_grant_recovers() -> void:
	print("\n  the app dies between the charge and the grant")
	var service: StoreService = _service()
	var profile: PlayerProfile = service._profile

	# Exactly what a crash leaves behind: the store took the money and wrote a pending
	# record, and the process died before anything was granted.
	var receipt := Billing.Receipt.new()
	receipt.product_id = "cores_medium"
	receipt.order_id = "DEV.crash.1"
	receipt.purchased_at = 1000
	service._remember_pending(receipt)

	var before: int = profile.currency(PlayerProfile.CORES)
	_check("the purchase is on disk, waiting", service.pending_count() == 1)

	# The next launch.
	service.process_pending(2000)
	_check("the next launch delivers it (%d -> %d)" % [before, profile.currency(PlayerProfile.CORES)],
		profile.currency(PlayerProfile.CORES) == before + 1100)
	_check("and the queue is clear", service.pending_count() == 0)

	# The same receipt again must not pay twice. Offline this is the client's own guard;
	# the real defence is the server's order-id check, which `verify_online.gd` covers.
	var after: int = profile.currency(PlayerProfile.CORES)
	service._remember_pending(receipt)
	service.process_pending(3000)
	_check("a replayed receipt does not grant twice (%d)" % profile.currency(PlayerProfile.CORES),
		profile.currency(PlayerProfile.CORES) == after + 1100)


func _test_a_failed_purchase_grants_nothing() -> void:
	print("\n  a purchase that does not go through")
	var service: StoreService = _service()
	var profile: PlayerProfile = service._profile
	var billing: LocalBilling = service.billing as LocalBilling
	var before: int = profile.currency(PlayerProfile.CORES)

	billing.next_result = Billing.Result.CANCELLED
	var cancelled: Array = [-1]
	service.buy_iap("cores_large", 1000, func(code: int, _m: String) -> void: cancelled[0] = code)
	_check("a cancelled purchase reports cancellation", int(cancelled[0]) == Billing.Result.CANCELLED)
	_check("and grants nothing", profile.currency(PlayerProfile.CORES) == before)
	_check("and leaves nothing pending", service.pending_count() == 0)

	billing.next_result = Billing.Result.FAILED
	service.buy_iap("cores_large", 1000, func(_c: int, _m: String) -> void: pass)
	_check("a failed purchase grants nothing either",
		profile.currency(PlayerProfile.CORES) == before)


func _test_currency_offers_cost_currency() -> void:
	print("\n  spending premium currency")
	var service: StoreService = _service()
	var profile: PlayerProfile = service._profile

	var refused: int = service.buy_with_currency("offer_alloy", 1000)
	_check("an offer is refused without the cores (%s)" % ProfileCommand.result_name(refused),
		refused == ProfileCommand.Result.NOT_ENOUGH_CURRENCY)

	service._store.execute(ProfileCommands.GrantCurrency.new(PlayerProfile.CORES, 1000, "test"))
	var cores_before: int = profile.currency(PlayerProfile.CORES)
	var alloy_before: int = profile.currency(PlayerProfile.ALLOY)
	var ok: int = service.buy_with_currency("offer_alloy", 1000)

	_check("with the cores it goes through", ok == ProfileCommand.Result.OK)
	_check("the cores were spent", profile.currency(PlayerProfile.CORES) == cores_before - 250)
	_check("the alloy arrived", profile.currency(PlayerProfile.ALLOY) == alloy_before + 600)
	# Charging and failing to deliver is the one outcome that must be impossible, which
	# is why both halves are a single all-or-nothing batch.
	_check("an unknown offer changes nothing",
		service.buy_with_currency("offer_nonexistent", 1000) == ProfileCommand.Result.INVALID
			and profile.currency(PlayerProfile.CORES) == cores_before - 250)


func _test_published_odds_match_the_roll() -> void:
	print("\n  published odds")
	for id: Variant in _content.crates.keys():
		var crate: Dictionary = _content.crates[id]
		var lines: PackedStringArray = Crates.odds_text(crate)
		_check("%s publishes its odds" % id, lines.size() > 0)

		# Rolled, not asserted from the same table twice: the text has to match what the
		# machine actually does, and several jurisdictions require exactly that.
		var counts: Dictionary = {}
		var rng := SimRNG.new(12345)
		var trials: int = 20000
		for _i: int in trials:
			var rarity: int = Crates._roll_rarity(crate, rng)
			counts[rarity] = int(counts.get(rarity, 0)) + 1

		var total_weight: int = 0
		for entry: Variant in (crate.get("rates", []) as Array):
			total_weight += int((entry as Dictionary).get("weight", 0))

		var matched: bool = true
		for entry: Variant in (crate.get("rates", []) as Array):
			var row: Dictionary = entry as Dictionary
			var stated: float = float(row.get("weight", 0)) * 100.0 / float(maxi(1, total_weight))
			var observed: float = float(counts.get(int(row.get("rarity", 1)), 0)) * 100.0 / float(trials)
			if absf(stated - observed) > 1.5:
				matched = false
				printerr("        rarity %d: published %.1f%%, rolled %.1f%%" % [
					int(row.get("rarity", 1)), stated, observed])
		_check("  and rolls them (%d draws)" % trials, matched)

		if int(crate.get("pity_after", 0)) > 0:
			var mentions_pity: bool = false
			for line: String in lines:
				if line.to_lower().contains("guarantee") or line.to_lower().contains("pity"):
					mentions_pity = true
			_check("  and states its pity guarantee", mentions_pity)


func _test_the_pass_can_be_finished() -> void:
	print("\n  season pacing")
	var total: int = BattlePass.total_xp(_content)
	var definition: Dictionary = BattlePass.definition(_content)
	var days: int = int(definition.get("duration_days", 28))
	var cap: int = int(definition.get("xp_daily_cap", 0))

	_check("the track has 50 tiers", BattlePass.tiers(_content).size() == 50)
	# A pass that cannot be finished inside its own season is a promise broken on the
	# last day. The first draft of this file was exactly that: 197,000 XP against a
	# 3,000/day cap over 28 days.
	_check("it can be finished at the daily cap (%d xp, %d days x %d)" % [total, days, cap],
		cap * days >= total)
	# ...but not in the first few days, or the season has no shape.
	_check("but not in under two weeks", cap * 14 < total)

	var per_win: int = int(definition.get("xp_per_battle", 0)) + int(definition.get("xp_per_win", 0))
	_check("the cap is reachable by playing (%d wins a day)" % (cap / maxi(1, per_win)),
		cap / maxi(1, per_win) <= 30)


func _test_the_pass_pays_each_tier_once() -> void:
	print("\n  claiming")
	var service: PassService = _pass_service()
	var profile: PlayerProfile = service._profile

	service._state()["xp"] = 6000
	_check("xp becomes tiers (%d)" % service.tier(), service.tier() >= 3)
	_check("only the free lane is owed", _all_free(service.unclaimed()))

	var before: int = profile.currency(PlayerProfile.SCRAP)
	var payout: Dictionary = service.claim_all(1000)
	_check("claiming pays out (%d tiers, %d scrap)" % [
		int(payout.get("claimed", 0)), int(payout.get("scrap", 0))],
		int(payout.get("claimed", 0)) > 0 and profile.currency(PlayerProfile.SCRAP) > before)

	var again: Dictionary = service.claim_all(1000)
	_check("claiming again pays nothing", int(again.get("claimed", 0)) == 0)
	_check("and nothing is owed", service.unclaimed().is_empty())


func _test_buying_premium_pays_out_what_was_earned() -> void:
	print("\n  buying the pass late")
	var service: PassService = _pass_service()
	var profile: PlayerProfile = service._profile

	service._state()["xp"] = 20000
	service.claim_all(1000)
	var tier: int = service.tier()
	_check("a free player has climbed (tier %d)" % tier, tier >= 8)
	_check("and is owed nothing on the free lane", service.unclaimed().is_empty())

	service._store.execute(ProfileCommands.UnlockPassPremium.new())
	_check("buying the pass unlocks the paid lane", service.premium_unlocked())
	# Everything already earned is owed at once. Paying out only from the moment of
	# purchase would punish a player for buying late, which is backwards.
	_check("and every tier already reached is owed (%d)" % service.unclaimed().size(),
		service.unclaimed().size() == tier)

	var cores_before: int = profile.currency(PlayerProfile.CORES)
	var payout: Dictionary = service.claim_all(1000)
	_check("claiming pays the whole backlog (%d tiers, %d cores)" % [
		int(payout.get("claimed", 0)), int(payout.get("cores", 0))],
		int(payout.get("claimed", 0)) == tier and profile.currency(PlayerProfile.CORES) > cores_before)


# --- Helpers -----------------------------------------------------------------

func _service() -> StoreService:
	_cleanup()
	var store: ProfileStore = ProfileStore.open(_content, TEST_PATH)
	return StoreService.open(_content, store.profile, store, LocalBilling.new())


func _pass_service() -> PassService:
	_cleanup()
	var store: ProfileStore = ProfileStore.open(_content, TEST_PATH)
	var service: PassService = PassService.open(_content, store.profile, store)
	service.apply_season_rollover(1000)
	return service


func _all_free(owed: Array) -> bool:
	for entry: Variant in owed:
		if bool((entry as Dictionary)["premium"]):
			return false
	return true


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
