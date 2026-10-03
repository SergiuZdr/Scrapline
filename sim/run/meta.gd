class_name Meta
extends RefCounted

## Between-run progression (022), as pure rules over `data/meta.json`. Unlocks only: nothing
## here makes a machine's numbers bigger. The profile holds the stats and what is unlocked; a
## run is started from `options`, resolved once and saved with it, so it replays the same
## whatever unlocks later.

## Lifetime stats after a finished run: `{ runs, fights, act, wins }`.
## 034: plus every feat the run tallied (kills, flawless, warlords...), added up -- an unlock
## mission is an ordinary condition on these.
## 043: and a win is counted per tier too (`wins_t<tier>`): the tier ladder climbs on these.
static func stats_after(stats: Dictionary, state: RunState, tier: int = 0) -> Dictionary:
	var out: Dictionary = stats.duplicate()
	out["runs"] = int(stats.get("runs", 0)) + 1
	out["fights"] = int(stats.get("fights", 0)) + state.fights_won
	out["act"] = maxi(int(stats.get("act", 1)), state.act)
	out["wins"] = int(stats.get("wins", 0)) + (1 if state.outcome == RunState.WON else 0)
	if state.outcome == RunState.WON:
		var key: String = "wins_t%d" % tier
		out[key] = int(stats.get(key, 0)) + 1
	for key: Variant in state.feats:
		out[key] = int(stats.get(key, 0)) + int(state.feats[key])
	return out


## The ids of every unlock these stats have earned, in table order.
static func earned(stats: Dictionary, rules: Dictionary) -> Array:
	var out: Array = []
	for entry: Dictionary in (rules.get("unlocks", []) as Array):
		var met: bool = true
		var when: Dictionary = entry.get("when", {})
		for key: Variant in when:
			met = met and int(stats.get(key, 0)) >= int(when[key])
		if met:
			out.append(String(entry["id"]))
	return out


## The next unlock not yet held, or `{}`: what the run-over screen points at.
static func next_unlock(unlocked: Array, rules: Dictionary) -> Dictionary:
	for entry: Dictionary in (rules.get("unlocks", []) as Array):
		if not unlocked.has(String(entry["id"])):
			return entry
	return {}


## How far these stats are toward an unlock (027): `[have, need]` for the condition furthest
## from done (every condition must be met), capped at `need`.
static func progress(stats: Dictionary, entry: Dictionary) -> Array:
	var best: Array = [1, 1]
	var worst: float = 2.0
	var when: Dictionary = entry.get("when", {})
	for key: Variant in when:
		var need: int = maxi(1, int(when[key]))
		var have: int = mini(need, int(stats.get(key, 1 if String(key) == "act" else 0)))
		var ratio: float = float(have) / float(need)
		if ratio < worst:
			worst = ratio
			best = [have, need]
	return best


## The highest tier these unlocks have opened (0 when none): where the ladder stands.
static func top_tier(unlocked: Array, rules: Dictionary) -> int:
	var top: int = 0
	for t: Variant in opened(unlocked, rules, "tier"):
		top = maxi(top, int(t))
	return top


## Whether the game's ending is held (043): the top tier has been won.
static func finished(unlocked: Array, rules: Dictionary) -> bool:
	return not opened(unlocked, rules, "ending").is_empty()


## What `kind` of thing these unlock ids have opened: part ids, crew ids or tier numbers.
static func opened(unlocked: Array, rules: Dictionary, kind: String) -> Array:
	var out: Array = []
	for entry: Dictionary in (rules.get("unlocks", []) as Array):
		if String(entry.get("kind", "")) == kind and unlocked.has(String(entry["id"])):
			out.append(entry["what"])
	return out


## The options a run starts with: the crew's specs (or none for the default), the tier's rules
## overlay, and the part ids still locked. Everything resolved, so the save needs no meta file.
static func options(rules: Dictionary, unlocked: Array, crew_id: String, tier: int) -> Dictionary:
	var out: Dictionary = {"crew_id": crew_id, "tier": tier}
	var crews: Dictionary = rules.get("crews", {})
	var crew: Dictionary = crews.get(crew_id, {})
	if crew.has("crew") and (crew_id == "salvagers" or opened(unlocked, rules, "crew").has(crew_id)):
		out["crew"] = (crew["crew"] as Array).duplicate(true)
	var tiers: Array = rules.get("tiers", [])
	var open_tiers: Array = opened(unlocked, rules, "tier").map(func(t: Variant) -> int: return int(t))
	if tier > 0 and tier < tiers.size() and open_tiers.has(tier):
		out["rules"] = ((tiers[tier] as Dictionary).get("rules", {}) as Dictionary).duplicate(true)
	else:
		out["tier"] = 0
	var open: Array = opened(unlocked, rules, "part")
	var locked: Array = []
	for id: Variant in (rules.get("locked", []) as Array):
		if not open.has(id):
			locked.append(String(id))
	locked.sort()
	out["locked"] = locked
	# 040 (play-test 12: "unlocked parts do not show in the starting-robot screen"): what this
	# profile has unlocked joins the assembly bench, once each.
	var earned: Array = []
	for id: Variant in open:
		earned.append(String(id))
	earned.sort()
	out["unlocked"] = earned
	return out
