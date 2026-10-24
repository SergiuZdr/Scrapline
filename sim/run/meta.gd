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
## 085 (B4): with `crew_id`, a win also raises that crew's record stamp, `best_<crew>`: the highest
## rung it has won (display only; absent until its first win).
static func stats_after(stats: Dictionary, state: RunState, tier: int = 0, crew_id: String = "") -> Dictionary:
	var out: Dictionary = stats.duplicate()
	if state.outcome == RunState.WON and not crew_id.is_empty():
		var best: String = "best_%s" % crew_id
		out[best] = maxi(int(stats.get(best, -1)), tier)
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


## 085 (B4): the ladder is cumulative -- rung N carries the adds of rungs 1..N, in rung order.
static func rung_adds(rules: Dictionary, rung: int) -> Array:
	var out: Array = []
	var tiers: Array = rules.get("tiers", [])
	for t: int in range(1, mini(rung, tiers.size() - 1) + 1):
		for add: Variant in (((tiers[t] as Dictionary).get("rules", {}) as Dictionary).get("adds", []) as Array):
			out.append((add as Dictionary).duplicate(true))
	return out


## 085 (B9): a crew's own run rule, `crews.<id>.rules` -- `adds` (on top of every act, like a rung's)
## and plain keys laid over run.json once (`crew_bonus`: a bonus block on every crew machine).
static func crew_rules(rules: Dictionary, crew_id: String) -> Dictionary:
	return (((rules.get("crews", {}) as Dictionary).get(crew_id, {}) as Dictionary).get("rules", {}) as Dictionary).duplicate(true)


## 085 (B10): a crew's three medals, `crews.<id>.medals`.
static func medals(rules: Dictionary, crew_id: String) -> Array:
	return (((rules.get("crews", {}) as Dictionary).get(crew_id, {}) as Dictionary).get("medals", []) as Array).duplicate(true)


## Two run-rule overlays as one: `adds` lists joined (a's first), every other key from b over a.
static func join_rules(a: Dictionary, b: Dictionary) -> Dictionary:
	var out: Dictionary = a.duplicate(true)
	for key: Variant in b:
		if String(key) == "adds":
			var adds: Array = (out.get("adds", []) as Array).duplicate(true)
			adds.append_array((b["adds"] as Array).duplicate(true))
			out["adds"] = adds
		else:
			out[key] = b[key] if not (b[key] is Dictionary) else (b[key] as Dictionary).duplicate(true)
	return out


## The options a run starts with: the crew's specs (or none for the default), the tier's rules
## overlay, and the part ids still locked. Everything resolved, so the save needs no meta file.
## 084 (B8): `seeded` marks a run started from a seed code (`RunSetup.is_seeded`): its wins stay off
## the ladder and the unlocks.
static func options(rules: Dictionary, unlocked: Array, crew_id: String, tier: int, seeded: bool = false) -> Dictionary:
	var out: Dictionary = {"crew_id": crew_id, "tier": tier}
	if seeded:
		out["seeded"] = true
	var crews: Dictionary = rules.get("crews", {})
	var crew: Dictionary = crews.get(crew_id, {})
	if crew.has("crew") and (crew_id == "salvagers" or opened(unlocked, rules, "crew").has(crew_id)):
		out["crew"] = (crew["crew"] as Array).duplicate(true)
	else:
		out["crew_id"] = "salvagers"
	var tiers: Array = rules.get("tiers", [])
	var open_tiers: Array = opened(unlocked, rules, "tier").map(func(t: Variant) -> int: return int(t))
	var run_rules: Dictionary = {}
	if tier > 0 and tier < tiers.size() and open_tiers.has(tier):
		run_rules["adds"] = rung_adds(rules, tier)
	else:
		out["tier"] = 0
	# 085: the crew's own rule (B9), its medals (B10), and the three deals at the start.
	run_rules = join_rules(run_rules, crew_rules(rules, String(out["crew_id"])))
	if not run_rules.is_empty():
		out["rules"] = run_rules
	out["medals"] = medals(rules, String(out["crew_id"]))
	out["deals"] = true
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


## 085: a daily yard or weekly contract (`RunSetup.daily_options` / `weekly_options`) as a run's
## options. The same for every profile: the crew (`base.crew_id`, else `crew_id`, the player's pick
## for a daily) with its rule, the rung's adds then the base's (twists, fixed conditions), the deals
## it fixes, and the pools of a fresh profile (`locked` in full, nothing extra on the bench). Its
## `mode` keeps it off the ladder and the unlocks (`RunSetup.is_seeded`). No medals.
static func challenge_options(rules: Dictionary, base: Dictionary, crew_id: String = "salvagers") -> Dictionary:
	var crew: String = String(base.get("crew_id", crew_id))
	var out: Dictionary = base.duplicate(true)
	out.erase("seed")
	out["crew_id"] = crew
	var spec: Dictionary = (rules.get("crews", {}) as Dictionary).get(crew, {})
	if spec.has("crew"):
		out["crew"] = (spec["crew"] as Array).duplicate(true)
	var tier: int = clampi(int(base.get("tier", 0)), 0, maxi(0, (rules.get("tiers", []) as Array).size() - 1))
	out["tier"] = tier
	var run_rules: Dictionary = {"adds": rung_adds(rules, tier)} if tier > 0 else {}
	run_rules = join_rules(run_rules, crew_rules(rules, crew))
	run_rules = join_rules(run_rules, base.get("rules", {}))
	if not run_rules.is_empty():
		out["rules"] = run_rules
	var locked: Array = (rules.get("locked", []) as Array).map(func(id: Variant) -> String: return String(id))
	locked.sort()
	out["locked"] = locked
	out["unlocked"] = []
	return out

