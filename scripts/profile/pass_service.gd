class_name PassService
extends RefCounted

## The player's own progress through the season track.
##
## Splits from `BattlePass` for the same reason `PvpService` splits from `Ranked`: the
## static class holds the rules and can be reasoned about in a test with no save file,
## while this one owns the mutation and goes through the command layer.

var content: ContentDB
var _profile: PlayerProfile
var _store: ProfileStore

signal changed


static func open(
	content_in: ContentDB, profile: PlayerProfile, store: ProfileStore = null
) -> PassService:
	var service := PassService.new()
	service.content = content_in
	service._profile = profile
	service._store = store
	return service


## Rolls the season over if the stored one has ended. **Unclaimed rewards are lost**, and
## that is stated on the screen rather than discovered — a track that silently banked
## everything would have no reason to be a season at all.
func apply_season_rollover(now: int) -> bool:
	var state: Dictionary = _state()
	var season: int = BattlePass.season_of(now, content)
	if int(state.get("season", -1)) == season:
		return false
	state["season"] = season
	state["xp"] = 0
	state["claimed_free"] = []
	state["claimed_premium"] = []
	state["premium"] = false
	state["day"] = 0
	state["today"] = 0
	_commit()
	changed.emit()
	return true


func xp() -> int:
	return int(_state().get("xp", 0))


func premium_unlocked() -> bool:
	return bool(_state().get("premium", false))


func tier() -> int:
	return int(BattlePass.progress(xp(), content)["tier"])


func progress() -> Dictionary:
	return BattlePass.progress(xp(), content)


func earned_today(now: int) -> int:
	var state: Dictionary = _state()
	if int(state.get("day", -1)) != now / 86400:
		return 0
	return int(state.get("today", 0))


## Credits a finished battle. Returns the XP actually awarded, which is zero once the
## daily cap is reached -- and the screen says so, because silently awarding nothing is
## indistinguishable from a bug.
func award_battle(won: bool, now: int) -> int:
	var state: Dictionary = _state()
	var day: int = now / 86400
	if int(state.get("day", -1)) != day:
		state["day"] = day
		state["today"] = 0

	var amount: int = BattlePass.xp_for_battle(won, int(state.get("today", 0)), content)
	if amount <= 0:
		return 0

	state["xp"] = xp() + amount
	state["today"] = int(state.get("today", 0)) + amount
	_commit()
	changed.emit()
	return amount


func unclaimed() -> Array:
	return BattlePass.unclaimed(_state(), premium_unlocked(), content)


## Claims everything currently owed, in tier order, in one batch. All-or-nothing: a
## partial payout would leave tiers marked claimed that were never paid.
func claim_all(now: int) -> Dictionary:
	var owed: Array = unclaimed()
	if owed.is_empty():
		return {"claimed": 0}

	var state: Dictionary = _state()
	var rng := SimRNG.new(int(state.get("seed", 0)) ^ (now & 0xFFFF) ^ (xp() * 31))
	var commands: Array = []
	var claimed_free: Array = state.get("claimed_free", []) as Array
	var claimed_premium: Array = state.get("claimed_premium", []) as Array

	for entry: Variant in owed:
		var d: Dictionary = entry as Dictionary
		var reward: Dictionary = BattlePass.reward_at(int(d["tier"]), bool(d["premium"]), content)
		commands.append_array(BattlePass.reward_commands(
			reward, content, _profile, rng, "pass:%d" % int(d["tier"])))
		if bool(d["premium"]):
			claimed_premium.append(int(d["tier"]))
		else:
			claimed_free.append(int(d["tier"]))

	var before_parts: int = _profile.inventory().size()
	var before_scrap: int = _profile.currency(PlayerProfile.SCRAP)
	var before_alloy: int = _profile.currency(PlayerProfile.ALLOY)
	var before_cores: int = _profile.currency(PlayerProfile.CORES)

	if not commands.is_empty() and _store.execute_batch(commands) != ProfileCommand.Result.OK:
		return {"claimed": 0, "error": "could not pay out"}

	state["claimed_free"] = claimed_free
	state["claimed_premium"] = claimed_premium
	state["seed"] = rng.next_u32()
	_commit()
	changed.emit()

	return {
		"claimed": owed.size(),
		"scrap": _profile.currency(PlayerProfile.SCRAP) - before_scrap,
		"alloy": _profile.currency(PlayerProfile.ALLOY) - before_alloy,
		"cores": _profile.currency(PlayerProfile.CORES) - before_cores,
		"parts": _profile.inventory().size() - before_parts,
	}


func _state() -> Dictionary:
	if not _profile.data.has("pass"):
		_profile.data["pass"] = {
			"season": -1, "xp": 0, "claimed_free": [], "claimed_premium": [],
			"premium": false, "day": 0, "today": 0, "seed": 0,
		}
	return _profile.data["pass"] as Dictionary


func _commit() -> void:
	if _store == null:
		return
	var result: int = _store.execute(ProfileCommands.SetPassState.new(_state()))
	if result != ProfileCommand.Result.OK:
		push_warning("pass: state rejected (" + ProfileCommand.result_name(result) + ")")
