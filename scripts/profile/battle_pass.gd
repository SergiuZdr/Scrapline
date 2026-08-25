class_name BattlePass
extends RefCounted

## The season track: play, gain XP, claim rewards on a free lane and a paid one.
##
## Two rules decide whether a pass is a reason to keep playing or a resented paywall,
## and both are pacing rather than code:
##
##   1. **It has to be finishable.** A track that cannot be completed inside its own
##      season is a promise broken on the last day, and the refunds follow. The pacing
##      is asserted by a test, not left to a spreadsheet nobody re-checks.
##   2. **The free lane has to be worth playing.** If the free half is decorative, the
##      pass reads as a paywall with a progress bar on it.
##
## Buying the premium track mid-season pays out **everything already earned**, at once.
## Anything else punishes the player for buying late, which is exactly backwards.

const XP_KEY: String = "xp"
const CLAIMED_FREE: String = "claimed_free"
const CLAIMED_PREMIUM: String = "claimed_premium"


static func definition(content: ContentDB) -> Dictionary:
	return content.battle_pass


## Which season we are in. Derived from the clock rather than stored, so a save that sat
## untouched for three months cannot resume a season that ended in June.
static func season_of(now: int, content: ContentDB) -> int:
	var days: int = maxi(1, int(definition(content).get("duration_days", 28)))
	return now / (days * 86400)


static func seconds_remaining(now: int, content: ContentDB) -> int:
	var days: int = maxi(1, int(definition(content).get("duration_days", 28)))
	var length: int = days * 86400
	return length - (now % length)


static func tiers(content: ContentDB) -> Array:
	return definition(content).get("tiers", []) as Array


static func total_xp(content: ContentDB) -> int:
	var total: int = 0
	for tier: Variant in tiers(content):
		total += int((tier as Dictionary).get("xp", 0))
	return total


## Tier reached for an XP total, and the progress into the next one.
## Returns `{tier, into, needed}` where `tier` 0 means nothing claimed yet.
static func progress(xp: int, content: ContentDB) -> Dictionary:
	var remaining: int = maxi(0, xp)
	var tier: int = 0
	for entry: Variant in tiers(content):
		var need: int = int((entry as Dictionary).get("xp", 0))
		if remaining < need:
			return {"tier": tier, "into": remaining, "needed": need}
		remaining -= need
		tier = int((entry as Dictionary).get("tier", tier + 1))
	return {"tier": tier, "into": 0, "needed": 0}


## XP for one finished battle, respecting the daily cap. The cap is what stops the pass
## being a test of who can grind longest, which is the least interesting way to sell one.
static func xp_for_battle(won: bool, earned_today: int, content: ContentDB) -> int:
	var definition_data: Dictionary = definition(content)
	var amount: int = int(definition_data.get("xp_per_battle", 0))
	if won:
		amount += int(definition_data.get("xp_per_win", 0))
	var cap: int = int(definition_data.get("xp_daily_cap", 0))
	if cap <= 0:
		return amount
	return clampi(cap - earned_today, 0, amount)


## Rewards owed at a tier on a lane, or an empty dictionary.
static func reward_at(tier: int, premium: bool, content: ContentDB) -> Dictionary:
	for entry: Variant in tiers(content):
		var d: Dictionary = entry as Dictionary
		if int(d.get("tier", 0)) == tier:
			return d.get("premium" if premium else "free", {}) as Dictionary
	return {}


## Every tier a player has reached but not yet claimed, on both lanes. Sorted so
## claiming pays out in tier order, which is how a player expects to read it.
static func unclaimed(state: Dictionary, premium_unlocked: bool, content: ContentDB) -> Array:
	var reached: int = int(progress(int(state.get(XP_KEY, 0)), content)["tier"])
	var claimed_free: Array = state.get(CLAIMED_FREE, []) as Array
	var claimed_premium: Array = state.get(CLAIMED_PREMIUM, []) as Array

	var out: Array = []
	for tier: int in range(1, reached + 1):
		if not claimed_free.has(tier):
			out.append({"tier": tier, "premium": false})
		if premium_unlocked and not claimed_premium.has(tier):
			out.append({"tier": tier, "premium": true})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["tier"]) != int(b["tier"]):
			return int(a["tier"]) < int(b["tier"])
		return not bool(a["premium"]))
	return out


## Turns a reward dictionary into commands. `parts: N` means N random parts, drawn from
## the same crate machinery the rest of the game uses -- so pass rewards obey the same
## published odds as everything else rather than having a second, hidden table.
static func reward_commands(
	reward: Dictionary, content: ContentDB, profile: PlayerProfile, rng: SimRNG, source: String
) -> Array:
	var commands: Array = []
	var keys: Array = reward.keys()
	keys.sort()
	for key: Variant in keys:
		var name: String = String(key)
		match name:
			PlayerProfile.SCRAP, PlayerProfile.ALLOY, PlayerProfile.CORES:
				commands.append(ProfileCommands.GrantCurrency.new(name, int(reward[key]), source))
			"parts":
				# A COUNT of random draws, not a list of ids -- the store uses `part_ids`
				# for named bundles, and conflating the two crashed the first screen that
				# tried to render both.
				for _i: int in int(reward[key]):
					var part_id: String = Crates.pass_part(content, rng)
					if not part_id.is_empty():
						commands.append(ProfileCommands.GrantPart.new(part_id))
			_:
				push_warning("battle pass: unknown reward '%s'" % name)
	var _unused: PlayerProfile = profile
	return commands
