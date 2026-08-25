class_name ProfileCommands
extends RefCounted

## The concrete profile commands. Grouped in one file because they are small and
## always change together; the economy reads better as a single page than as eight.
##
## Costs live in `data/economy.json`, never here -- the same rule that keeps balance
## numbers out of `sim/`, for the same reason: a live game needs to retune an economy
## without shipping a client.


## Adds a part, or a duplicate of one already owned. The only way parts enter a
## profile -- crates, campaign rewards and refunds all route through it.
class GrantPart extends ProfileCommand:
	var part_id: String

	func _init(id: String) -> void:
		kind = "grant_part"
		part_id = id

	func validate(_profile: PlayerProfile, content: ContentDB) -> int:
		return Result.OK if content.parts.has(part_id) else Result.INVALID

	func apply(profile: PlayerProfile, _content: ContentDB) -> void:
		if profile.owns(part_id):
			var existing: Dictionary = profile.inventory()[part_id]
			existing["copies"] = int(existing.get("copies", 0)) + 1
		else:
			profile.inventory()[part_id] = {"level": 1, "copies": 0, "tier": 0}

	func to_dict() -> Dictionary:
		return {"kind": kind, "part": part_id}


## Currency in. Every grant is logged, which is what makes an economy auditable.
class GrantCurrency extends ProfileCommand:
	var currency: String
	var amount: int
	var reason: String

	func _init(currency_kind: String, value: int, why: String = "") -> void:
		kind = "grant_currency"
		currency = currency_kind
		amount = value
		reason = why

	func validate(_profile: PlayerProfile, _content: ContentDB) -> int:
		return Result.OK if amount > 0 else Result.INVALID

	func apply(profile: PlayerProfile, _content: ContentDB) -> void:
		ProfileCommand.adjust_currency(profile, currency, amount)

	func to_dict() -> Dictionary:
		return {"kind": kind, "currency": currency, "amount": amount, "reason": reason}


## Currency out. Refuses rather than going negative.
class SpendCurrency extends ProfileCommand:
	var currency: String
	var amount: int
	var reason: String

	func _init(currency_kind: String, value: int, why: String = "") -> void:
		kind = "spend_currency"
		currency = currency_kind
		amount = value
		reason = why

	func validate(profile: PlayerProfile, _content: ContentDB) -> int:
		if amount <= 0:
			return Result.INVALID
		return Result.OK if profile.can_afford(currency, amount) else Result.NOT_ENOUGH_CURRENCY

	func apply(profile: PlayerProfile, _content: ContentDB) -> void:
		ProfileCommand.adjust_currency(profile, currency, -amount)

	func to_dict() -> Dictionary:
		return {"kind": kind, "currency": currency, "amount": amount, "reason": reason}


## Spends scrap to raise a part one level, up to the ceiling its tier allows.
class LevelPart extends ProfileCommand:
	var part_id: String
	var cost: int = 0

	func _init(id: String) -> void:
		kind = "level_part"
		part_id = id

	func validate(profile: PlayerProfile, content: ContentDB) -> int:
		if not profile.owns(part_id):
			return Result.NOT_OWNED
		if profile.is_max_level(part_id):
			return Result.ALREADY_MAX
		cost = Economy.level_cost(profile, part_id, content)
		return Result.OK if profile.can_afford(PlayerProfile.SCRAP, cost) else Result.NOT_ENOUGH_CURRENCY

	func apply(profile: PlayerProfile, content: ContentDB) -> void:
		if cost <= 0:
			cost = Economy.level_cost(profile, part_id, content)
		ProfileCommand.adjust_currency(profile, PlayerProfile.SCRAP, -cost)
		var e: Dictionary = ProfileCommand.ensure_entry(profile, part_id)
		e["level"] = int(e.get("level", 1)) + 1

	func to_dict() -> Dictionary:
		return {"kind": kind, "part": part_id}


## Consumes duplicates and alloy to raise a part's rarity tier, which raises its level
## ceiling. This is the sink that makes duplicate parts worth pulling rather than
## worthless -- the failure mode every collection game has to design against.
class RefitPart extends ProfileCommand:
	var part_id: String
	var copies_needed: int = 0
	var alloy_cost: int = 0

	func _init(id: String) -> void:
		kind = "refit_part"
		part_id = id

	func validate(profile: PlayerProfile, content: ContentDB) -> int:
		if not profile.owns(part_id):
			return Result.NOT_OWNED
		if profile.part_tier(part_id) >= PlayerProfile.MAX_TIER:
			return Result.ALREADY_MAX
		copies_needed = Economy.refit_copies(profile, part_id)
		alloy_cost = Economy.refit_alloy(profile, part_id, content)
		if profile.part_copies(part_id) < copies_needed:
			return Result.NOT_ENOUGH_COPIES
		return Result.OK if profile.can_afford(PlayerProfile.ALLOY, alloy_cost) else Result.NOT_ENOUGH_CURRENCY

	func apply(profile: PlayerProfile, content: ContentDB) -> void:
		if copies_needed <= 0:
			copies_needed = Economy.refit_copies(profile, part_id)
			alloy_cost = Economy.refit_alloy(profile, part_id, content)
		ProfileCommand.adjust_currency(profile, PlayerProfile.ALLOY, -alloy_cost)
		var e: Dictionary = ProfileCommand.ensure_entry(profile, part_id)
		e["copies"] = int(e.get("copies", 0)) - copies_needed
		e["tier"] = int(e.get("tier", 0)) + 1

	func to_dict() -> Dictionary:
		return {"kind": kind, "part": part_id}


## Replaces a named squad's loadout. Refuses a squad referencing parts the player does
## not own, so a Refit that consumed a duplicate cannot leave an unfightable squad.
class SetSquad extends ProfileCommand:
	var squad_name: String
	var specs: Array

	func _init(name: String, loadout: Array) -> void:
		kind = "set_squad"
		squad_name = name
		specs = loadout

	func validate(profile: PlayerProfile, content: ContentDB) -> int:
		if specs.size() > SimDefs.SQUAD_SIZE:
			return Result.INVALID
		for spec: Variant in specs:
			var parts: Dictionary = (spec as Dictionary).get("parts", {})
			for key: Variant in parts.keys():
				var id: String = String(parts[key])
				if id.is_empty():
					continue
				if not content.parts.has(id):
					return Result.INVALID
				if not profile.owns(id):
					return Result.NOT_OWNED
		return Result.OK

	func apply(profile: PlayerProfile, _content: ContentDB) -> void:
		(profile.data["squads"] as Dictionary)[squad_name] = specs.duplicate(true)

	func to_dict() -> Dictionary:
		return {"kind": kind, "squad": squad_name, "specs": specs}


## Records a finished battle. Kept as a command so win counts, currency rewards and
## campaign progress all land in the log together and can be replayed as one unit.
class RecordBattle extends ProfileCommand:
	var won: bool
	var node_id: String

	func _init(victory: bool, campaign_node: String = "") -> void:
		kind = "record_battle"
		won = victory
		node_id = campaign_node

	func validate(_profile: PlayerProfile, _content: ContentDB) -> int:
		return Result.OK

	func apply(profile: PlayerProfile, _content: ContentDB) -> void:
		var stats: Dictionary = profile.data["stats"]
		stats["battles"] = int(stats.get("battles", 0)) + 1
		if won:
			stats["wins"] = int(stats.get("wins", 0)) + 1
		if won and not node_id.is_empty():
			var campaign: Dictionary = profile.data["campaign"]
			var cleared: Array = campaign["cleared"]
			if not cleared.has(node_id):
				cleared.append(node_id)

	func to_dict() -> Dictionary:
		return {"kind": kind, "won": won, "node": node_id}


## Opens a crate. The roll itself lives in `Crates` and is pure; this command owns the
## payment, the pity counter and the seed advance, so every pull is reproducible from
## the profile alone.
class OpenCrate extends ProfileCommand:
	var crate_id: String
	## Filled in by apply(), for the reveal screen.
	var pulls: Array = []

	func _init(id: String) -> void:
		kind = "open_crate"
		crate_id = id

	func validate(profile: PlayerProfile, content: ContentDB) -> int:
		var crate: Dictionary = content.crates.get(crate_id, {})
		if crate.is_empty():
			return Result.INVALID
		var currency: String = String(crate.get("cost_currency", "scrap"))
		var amount: int = int(crate.get("cost_amount", 0))
		return Result.OK if profile.can_afford(currency, amount) else Result.NOT_ENOUGH_CURRENCY

	func apply(profile: PlayerProfile, content: ContentDB) -> void:
		var crate: Dictionary = content.crates[crate_id]
		ProfileCommand.adjust_currency(profile,
			String(crate.get("cost_currency", "scrap")), -int(crate.get("cost_amount", 0)))

		var crates: Dictionary = profile.data["crates"]
		var counters: Dictionary = crates["counters"]
		var counter: Dictionary = counters.get(crate_id, {"opened": 0, "since_pity": 0})

		var outcome: Dictionary = Crates.roll(
			crate, content, profile.inventory(),
			int(crates.get("seed", 1)), int(counter.get("since_pity", 0)))

		for pull: Crates.Pull in outcome["pulls"]:
			if profile.owns(pull.part_id):
				var existing: Dictionary = profile.inventory()[pull.part_id]
				existing["copies"] = int(existing.get("copies", 0)) + 1
			else:
				profile.inventory()[pull.part_id] = {"level": 1, "copies": 0, "tier": 0}
			pulls.append(pull)

		crates["seed"] = int(outcome["seed"])
		counter["opened"] = int(counter.get("opened", 0)) + int(crate.get("pulls", 1))
		counter["since_pity"] = int(outcome["since_pity"])
		counters[crate_id] = counter

	func to_dict() -> Dictionary:
		return {"kind": kind, "crate": crate_id}


## Builds or upgrades a Foundry building.
class UpgradeBuilding extends ProfileCommand:
	var building_id: String
	var cost: int = 0
	var currency: String = "scrap"

	func _init(id: String) -> void:
		kind = "upgrade_building"
		building_id = id

	func validate(profile: PlayerProfile, content: ContentDB) -> int:
		var definition: Dictionary = content.buildings.get(building_id, {})
		if definition.is_empty() or not bool(definition.get("unlocked", true)):
			return Result.INVALID
		if Foundry.at_max_level(profile, building_id, content):
			return Result.ALREADY_MAX
		cost = Foundry.upgrade_cost(profile, building_id, content)
		currency = Foundry.upgrade_currency(building_id, content)
		return Result.OK if profile.can_afford(currency, cost) else Result.NOT_ENOUGH_CURRENCY

	func apply(profile: PlayerProfile, content: ContentDB) -> void:
		if cost <= 0:
			cost = Foundry.upgrade_cost(profile, building_id, content)
			currency = Foundry.upgrade_currency(building_id, content)
		ProfileCommand.adjust_currency(profile, currency, -cost)
		var buildings: Dictionary = (profile.data["foundry"] as Dictionary)["buildings"]
		var entry: Dictionary = buildings.get(building_id, {"level": 0})
		entry["level"] = int(entry.get("level", 0)) + 1
		buildings[building_id] = entry

	func to_dict() -> Dictionary:
		return {"kind": kind, "building": building_id}


## Banks everything the Foundry has produced since the last collection.
##
## `now` is passed in rather than read from the clock, so offline accrual is testable
## and a device clock that jumps cannot mint currency.
class CollectFoundry extends ProfileCommand:
	var now: int
	var collected: Dictionary = {}

	func _init(timestamp: int) -> void:
		kind = "collect_foundry"
		now = timestamp

	func validate(profile: PlayerProfile, content: ContentDB) -> int:
		return Result.OK if not Foundry.pending(profile, content, now).is_empty() else Result.INVALID

	func apply(profile: PlayerProfile, content: ContentDB) -> void:
		collected = Foundry.pending(profile, content, now)
		var currencies: Array = collected.keys()
		currencies.sort()
		for currency: Variant in currencies:
			ProfileCommand.adjust_currency(profile, String(currency), int(collected[currency]))
		(profile.data["foundry"] as Dictionary)["last_collected"] = now

	func to_dict() -> Dictionary:
		return {"kind": kind, "at": now, "collected": collected}


## Saves a player-authored doctrine. Stored as the same rule dictionaries the
## simulation's `Doctrine` reads, so what the editor writes is exactly what fights.
class SetDoctrine extends ProfileCommand:
	var doctrine_name: String
	var rules: Array

	func _init(name: String, rule_list: Array) -> void:
		kind = "set_doctrine"
		doctrine_name = name
		rules = rule_list

	func validate(_profile: PlayerProfile, _content: ContentDB) -> int:
		if rules.size() > 12:
			return Result.INVALID
		for rule: Variant in rules:
			if not (rule is Dictionary) or not (rule as Dictionary).has("then"):
				return Result.INVALID
		return Result.OK

	func apply(profile: PlayerProfile, _content: ContentDB) -> void:
		(profile.data["doctrines"] as Dictionary)[doctrine_name] = rules.duplicate(true)

	func to_dict() -> Dictionary:
		return {"kind": kind, "doctrine": doctrine_name, "rules": rules}


## Records a Gauntlet floor attempt. Advancing on a win and resetting to floor 1 on a
## loss is what makes a run a run -- there is no grinding one floor until it falls.
## Writes the ranked block: ids, rating, record, season.
##
## PvP state used to be written straight into `profile.data`, which typechecked, ran,
## and never saved a single byte of it -- `ProfileStore.save()` returns early unless a
## command marked the profile dirty. The player's rating, their match record and the id
## their account is keyed on all silently evaporated on every launch.
class SetPvpState extends ProfileCommand:
	var state: Dictionary

	func _init(new_state: Dictionary) -> void:
		kind = "set_pvp_state"
		state = new_state.duplicate(true)

	func validate(_profile: PlayerProfile, _content: ContentDB) -> int:
		if int(state.get("rating", 0)) < 0:
			return Result.INVALID
		if int(state.get("matches", 0)) < 0:
			return Result.INVALID
		return Result.OK

	func apply(profile: PlayerProfile, _content: ContentDB) -> void:
		profile.data["pvp"] = state


## Writes the co-op block: which encounter is open, and what this player has done to it.
class SetCoopState extends ProfileCommand:
	var state: Dictionary

	func _init(new_state: Dictionary) -> void:
		kind = "set_coop_state"
		state = new_state.duplicate(true)

	func validate(_profile: PlayerProfile, _content: ContentDB) -> int:
		if int(state.get("attempts", 0)) < 0:
			return Result.INVALID
		return Result.OK

	func apply(profile: PlayerProfile, _content: ContentDB) -> void:
		profile.data["coop"] = state


## Store state: what has been bought, and what has been paid for but not yet delivered.
class SetStoreState extends ProfileCommand:
	var state: Dictionary

	func _init(new_state: Dictionary) -> void:
		kind = "set_store_state"
		state = new_state.duplicate(true)

	func validate(_profile: PlayerProfile, _content: ContentDB) -> int:
		return Result.OK

	func apply(profile: PlayerProfile, _content: ContentDB) -> void:
		profile.data["store"] = state


## Battle-pass state: XP, which tiers have been claimed, and whether the paid lane is on.
class SetPassState extends ProfileCommand:
	var state: Dictionary

	func _init(new_state: Dictionary) -> void:
		kind = "set_pass_state"
		state = new_state.duplicate(true)

	func validate(_profile: PlayerProfile, _content: ContentDB) -> int:
		if int(state.get("xp", 0)) < 0:
			return Result.INVALID
		return Result.OK

	func apply(profile: PlayerProfile, _content: ContentDB) -> void:
		profile.data["pass"] = state


## Turns on the paid lane of the current season. Separate from `SetPassState` because it
## is the thing a player pays money for: it belongs in the audit log under its own name.
class UnlockPassPremium extends ProfileCommand:
	func _init() -> void:
		kind = "unlock_pass_premium"

	func validate(_profile: PlayerProfile, _content: ContentDB) -> int:
		return Result.OK

	func apply(profile: PlayerProfile, _content: ContentDB) -> void:
		if not profile.data.has("pass"):
			profile.data["pass"] = {"xp": 0, "claimed_free": [], "claimed_premium": []}
		(profile.data["pass"] as Dictionary)["premium"] = true


class RecordGauntlet extends ProfileCommand:
	var floor_number: int
	var won: bool
	var now: int

	func _init(floor_value: int, victory: bool, timestamp: int) -> void:
		kind = "record_gauntlet"
		floor_number = floor_value
		won = victory
		now = timestamp

	func validate(_profile: PlayerProfile, _content: ContentDB) -> int:
		return Result.OK

	func apply(profile: PlayerProfile, _content: ContentDB) -> void:
		var g: Dictionary = profile.data["gauntlet"]
		var week: int = now / Gauntlet.SECONDS_PER_WEEK
		if int(g.get("week", -1)) != week:
			# A new week wipes the run and the weekly record, never the all-time best.
			g["week"] = week
			g["week_best"] = 0
			g["floor"] = 1

		if won:
			g["week_best"] = maxi(int(g.get("week_best", 0)), floor_number)
			g["best_depth"] = maxi(int(g.get("best_depth", 0)), floor_number)
			g["floor"] = floor_number + 1
		else:
			g["floor"] = 1

		var stats: Dictionary = profile.data["stats"]
		stats["battles"] = int(stats.get("battles", 0)) + 1
		if won:
			stats["wins"] = int(stats.get("wins", 0)) + 1

	func to_dict() -> Dictionary:
		return {"kind": kind, "floor": floor_number, "won": won}
