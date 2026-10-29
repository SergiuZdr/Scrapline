class_name RunSetup
extends RefCounted

## Everything a run needs that never changes during it: the seed and the content it is
## played against. `RunSim` reads these and nothing else, so a run is fully determined by
## `RunSetup` plus its action list -- the same property that makes a fight replayable.

var rng_seed: int = 0
## `data/run/run.json`.
var rules: Dictionary = {}
## `data/combat/rules.json`.
var combat_rules: Dictionary = {}
## ContentDB.parts / tiles / fights, and `ContentDB.effectiveness`.
var parts: Dictionary = {}
var tiles: Array = []
var fights: Dictionary = {}
var wheel: Array = []

## Part ids by slot ("chassis", "core", "arm", "module"), each sorted, so a roll over a
## pool never depends on dictionary order.
var pools: Dictionary = {}


## What the run was started with (022, `Meta.options`): `crew` (starting crew specs), `rules`
## (a tier's overlay) and `locked` (part ids out of the pools). Empty = the default crew, the
## first tier, everything unlocked -- what the tests and the run bot play.
var options: Dictionary = {}


## `over` laid on `base` one level deep: a key holding a dictionary is merged, anything else
## replaces. How acts (021) and tiers (022) change the rules without code.
static func overlay(base: Dictionary, over: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate()
	for key: Variant in over:
		if over[key] is Dictionary and out.get(key) is Dictionary:
			var merged: Dictionary = (out[key] as Dictionary).duplicate()
			merged.merge(over[key], true)
			out[key] = merged
		else:
			out[key] = over[key]
	return out


## 082 (B1): a tier's `adds` -- `{path, delta}` or `{path, set}`, `path` dotted ("enemies.bonus.damage")
## -- applied to `base` AFTER the act's overlay, so a tier stacks on every act. Integers only; a
## missing number counts as 0 and missing dictionaries are made. Applied sorted by path (then by
## list position), never in dictionary order. Copy on write: `base` is never changed. 085's rungs
## are each one such list.
## 085: an add may name the acts it holds in (`"acts": [1]`, a deal's "in Act 1" cost); it is skipped
## in any other act, and everywhere when `act` is 0.
static func apply_adds(base: Dictionary, adds: Array, act: int = 0) -> Dictionary:
	var order: Array = []
	for i: int in adds.size():
		var only: Variant = (adds[i] as Dictionary).get("acts")
		if only is Array and not (only as Array).any(func(a: Variant) -> bool: return int(a) == act):
			continue
		order.append([String((adds[i] as Dictionary).get("path", "")), i])
	order.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] if a[0] != b[0] else int(a[1]) < int(b[1]))
	var out: Dictionary = base.duplicate()
	for entry: Array in order:
		var add: Dictionary = adds[int(entry[1])]
		var keys: PackedStringArray = String(entry[0]).split(".")
		if String(entry[0]).is_empty():
			continue
		var node: Dictionary = out
		for k: int in keys.size() - 1:
			var child: Variant = node.get(keys[k])
			var copy: Dictionary = (child as Dictionary).duplicate() if child is Dictionary else {}
			node[keys[k]] = copy
			node = copy
		var last: String = keys[keys.size() - 1]
		if add.has("set"):
			node[last] = int(add["set"])
		else:
			node[last] = int(node.get(last, 0)) + int(add.get("delta", 0))
	return out


static func create(content_parts: Dictionary, content_tiles: Array, content_fights: Dictionary,
		run_rules: Dictionary, combat_rules_in: Dictionary, wheel_in: Array, seed_value: int,
		options_in: Dictionary = {}) -> RunSetup:
	var setup := RunSetup.new()
	setup.rng_seed = seed_value
	setup.options = options_in
	setup.rules = run_rules
	if options_in.has("rules"):
		setup.rules = overlay(setup.rules, options_in["rules"])
	if options_in.has("crew"):
		setup.rules = setup.rules.duplicate()
		setup.rules["starting_crew"] = options_in["crew"]
	var locked: Array = options_in.get("locked", [])
	setup.combat_rules = combat_rules_in
	setup.parts = content_parts
	setup.tiles = content_tiles
	setup.fights = content_fights
	setup.wheel = wheel_in
	var ids: Array = content_parts.keys()
	ids.sort()
	for slot: String in ["chassis", "core", "arm", "module"]:
		setup.pools[slot] = []
	for id: Variant in ids:
		# Tuned parts are made at a workshop, never found: they stay out of every pool.
		if (content_parts[id] as Dictionary).has("base") or locked.has(String(id)):
			continue
		var slot: String = String((content_parts[id] as Dictionary).get("slot", ""))
		if setup.pools.has(slot):
			(setup.pools[slot] as Array).append(String(id))
	return setup


## The rarity of a part, 1..3.
func rarity(part_id: String) -> int:
	return int((parts.get(part_id, {}) as Dictionary).get("rarity", 1))


## The slot a socket index takes: 0 chassis, 1 core, 2-3 arms, 4 module.
static func socket_slot(socket: int) -> String:
	match socket:
		0:
			return "chassis"
		1:
			return "core"
		2, 3:
			return "arm"
		_:
			return "module"


## 084 (B8): a seed code is three words and a number, "CRANE-SLAG-RUST-4721". The words carry
## the seed (8 bits each, through a keyed shuffle so neighbouring seeds look nothing alike); the
## number carries a 7-bit tag of the content version and a 6-bit check. So a seed must fit
## SEED_MASK: the run session draws fresh seeds inside it. Never reorder SEED_WORDS (old codes).
const SEED_MASK: int = 0xFFFFFF
const SEED_WORDS: PackedStringArray = [
	"ANVIL", "ARC", "ASH", "AXLE", "BALE", "BARGE", "BARREL", "BEAM", "BELL", "BELT", "BOLT", "BONE",
	"BOOM", "BOX", "BRACE", "BRASS", "BRICK", "BRINE", "BUCKET", "BULB", "BUMP", "BURN", "BURR",
	"CABLE", "CAGE", "CAN", "CARGO", "CART", "CHAIN", "CHALK", "CHUTE", "CINDER", "CLAMP", "CLAW",
	"CLOCK", "COAL", "COG", "COIL", "COKE", "CONE", "COPPER", "CORD", "CORE", "CRANE", "CRATE",
	"CREEK", "CROW", "CRUSH", "CUP", "DENT", "DIAL", "DIESEL", "DOCK", "DRAIN", "DRILL", "DRUM",
	"DUCT", "DUSK", "DUST", "ECHO", "EMBER", "ENGINE", "FAN", "FENDER", "FERRY", "FILE", "FLARE",
	"FLINT", "FLUE", "FOG", "FORGE", "FORK", "FRAME", "FUEL", "FUSE", "GAP", "GATE", "GAUGE", "GEAR",
	"GIRDER", "GLASS", "GLOVE", "GRATE", "GRIME", "GRIT", "HATCH", "HAUL", "HEAP", "HELM", "HINGE",
	"HOIST", "HOOK", "HORN", "HOSE", "HULL", "HUSK", "INGOT", "IRON", "JACK", "JAR", "JOLT", "KEEL",
	"KETTLE", "KEY", "KILN", "KNOB", "LADDER", "LAMP", "LATCH", "LEAD", "LEVER", "LID", "LIME",
	"LINK", "LOCK", "LOG", "LOOM", "LUG", "MAST", "MESH", "MILL", "MINE", "MOLD", "MOTOR", "MUD",
	"NAIL", "NEEDLE", "NET", "NICKEL", "NUT", "OAR", "OIL", "ORE", "OVEN", "PAIL", "PAN", "PANEL",
	"PATCH", "PEG", "PIER", "PIN", "PIPE", "PISTON", "PIT", "PITCH", "PLANK", "PLATE", "PLUG", "POLE",
	"PORT", "POST", "POT", "PULLEY", "PUMP", "RACK", "RAFT", "RAIL", "RAKE", "RAMP", "RASP", "REEL",
	"RIDGE", "RIG", "RIM", "RIVET", "ROD", "ROPE", "ROTOR", "RUNG", "RUST", "SACK", "SAND", "SAW",
	"SCALE", "SCOOP", "SCRAP", "SCREW", "SEAM", "SHAFT", "SHED", "SHELL", "SHIM", "SHOVEL", "SIGNAL",
	"SILO", "SINK", "SKID", "SLAB", "SLAG", "SLATE", "SLED", "SLOT", "SMOKE", "SOCKET", "SOOT",
	"SPADE", "SPAN", "SPARK", "SPIKE", "SPOKE", "SPOOL", "SPRING", "SPROCKET", "STACK", "STAKE",
	"STEAM", "STEEL", "STOVE", "STRAP", "STUD", "SUMP", "TANK", "TAR", "TIN", "TONGS", "TOOTH",
	"TORCH", "TOWER", "TRACK", "TRAM", "TRAP", "TRAY", "TRUSS", "TUB", "TUBE", "TURBINE", "TYRE",
	"VALVE", "VAN", "VENT", "VICE", "VOLT", "WAGON", "WASHER", "WEDGE", "WELD", "WHEEL", "WHISTLE",
	"WICK", "WIDGET", "WINCH", "WIRE", "WRENCH", "YARD", "ZINC", "BLADE", "BRAKE", "BUOY", "CASK",
	"CHISEL", "COMB", "FLASK", "GRIND", "HAMMER", "HOPPER", "JIB"
]


## Whether a run was started from a typed or replayed seed (B8): `options.seeded`. Such a run is a
## replay, not a climb -- 085 keeps its wins off the ladder and the unlocks.
## 085: so is a daily yard or a weekly contract (`options.mode`): they keep their own score.
static func is_seeded(options_in: Dictionary) -> bool:
	return bool(options_in.get("seeded", false)) or not String(options_in.get("mode", "")).is_empty()


## A content version's 7-bit tag in a seed code, as two hex digits.
static func version_tag(version: String) -> String:
	return "%02x" % _version_bits(version)


static func _version_bits(version: String) -> int:
	var h: int = 0x811C9DC5
	for b: int in version.to_utf8_buffer():
		h = ((h ^ b) * 0x01000193) & 0xFFFFFFFF
	return IntentAI.mix(h, 0, 0x5EED, 7) & 0x7F


static func _check(seed_value: int, tag: int) -> int:
	return IntentAI.mix(seed_value, tag, 0x5EED, 11) & 0x3F


## The keyed 24-bit shuffle (a 4-round Feistel net over two 12-bit halves) and its inverse.
static func _scramble(x: int, back: bool) -> int:
	var l: int = (x >> 12) & 0xFFF
	var r: int = x & 0xFFF
	for i: int in 4:
		if back:
			var prev_r: int = l
			l = r ^ (IntentAI.mix(prev_r, 3 - i, 0x5EED, 3) & 0xFFF)
			r = prev_r
		else:
			var next_l: int = r
			r = l ^ (IntentAI.mix(r, i, 0x5EED, 3) & 0xFFF)
			l = next_l
	return (l << 12) | r


## A run's seed as a short word code that carries the content version, and back.
## "" when the seed does not fit SEED_MASK.
static func seed_code(seed_value: int, version: String) -> String:
	if seed_value < 0 or seed_value > SEED_MASK:
		return ""
	var x: int = _scramble(seed_value, false)
	var tag: int = _version_bits(version)
	return "%s-%s-%s-%04d" % [SEED_WORDS[(x >> 16) & 0xFF], SEED_WORDS[(x >> 8) & 0xFF], SEED_WORDS[x & 0xFF],
		tag * 64 + _check(seed_value, tag)]


## {"seed": int, "version": String (the code's version tag, `version_tag`), "stale": bool}, or {} when
## the code does not parse or its check fails (a typo). Case, spaces, dots and dashes do not matter.
## Given the game's `version`, "stale" says the code was made by another content version: the same
## seed would make a different region, so the screen refuses it and says why.
static func parse_seed_code(code: String, version: String = "") -> Dictionary:
	var clean: String = code.strip_edges().to_upper()
	for sep: String in [" ", ".", "_", ",", "/", ":"]:
		clean = clean.replace(sep, "-")
	var parts: PackedStringArray = []
	for token: String in clean.split("-"):
		if not token.is_empty():
			parts.append(token)
	if parts.size() != 4 or not parts[3].is_valid_int() or parts[3].length() > 4:
		return {}
	var x: int = 0
	for i: int in 3:
		var at: int = SEED_WORDS.find(parts[i])
		if at < 0:
			return {}
		x = (x << 8) | at
	var number: int = parts[3].to_int()
	if number < 0 or number > 0x1FFF:
		return {}
	var seed_value: int = _scramble(x, true)
	var tag: int = number / 64
	if number % 64 != _check(seed_value, tag):
		return {}
	return {"seed": seed_value, "version": "%02x" % tag,
		"stale": not version.is_empty() and _version_bits(version) != tag}


## 085: the three deal ids a run with this seed offers, from `rules.deals` (`data/run/deals.json`):
## one soft deal (`soft: true`) and `offer - 1` others, each pool in file order, picked by a SimRNG of
## the seed alone -- so a seed code, the daily and the weekly offer the same three -- then dealt into
## a seeded order. [] when there is no pool.
static func roll_deals(rules: Dictionary, seed_value: int) -> Array:
	var pool: Dictionary = rules.get("deals", {})
	var soft: Array = []
	var hard: Array = []
	for entry: Variant in (pool.get("deals", []) as Array):
		var d: Dictionary = entry
		(soft if bool(d.get("soft", false)) else hard).append(String(d["id"]))
	if soft.is_empty() and hard.is_empty():
		return []
	var rng := SimRNG.new(IntentAI.mix(seed_value, 0xDEA1, 0x5EED, 29))
	var out: Array = []
	if not soft.is_empty():
		out.append(soft[rng.range_int(0, soft.size() - 1)])
	var want: int = maxi(1, int(pool.get("offer", 3)))
	while out.size() < want and not hard.is_empty():
		out.append(hard.pop_at(rng.range_int(0, hard.size() - 1)))
	for i: int in range(out.size() - 1, 0, -1):
		var j: int = rng.range_int(0, i)
		var t: Variant = out[i]
		out[i] = out[j]
		out[j] = t
	return out


## 085: the daily yard for `day` (days since 1970-01-01, UTC): run options everyone shares that day.
## `rules` is the run rules (`ContentDB.run_rules`, with `challenges` and `deals`). Pure, no clock:
## the day is the caller's. {"seed", "mode": "daily", "day", "tier": 0, "deals": true, "deal_offer",
## "conditions": [one id per act], "rules": {"modifiers": {"acts": [...]}}}; any crew, rung 0.
## `Meta.challenge_options` turns it into a run's options with the crew the player picks.
static func daily_options(rules: Dictionary, day: int) -> Dictionary:
	var daily: Dictionary = (rules.get("challenges", {}) as Dictionary).get("daily", {})
	var seed_value: int = IntentAI.mix(day, 0xDA11, 0x5EED, 23) & SEED_MASK
	var rng := SimRNG.new(IntentAI.mix(day, 0xDA12, 0x5EED, 31))
	var mods: Dictionary = rules.get("modifiers", {})
	var ids: Array = (daily.get("conditions", (mods.get("act_weights", mods.get("weights", {})) as Dictionary).keys()) as Array).duplicate()
	ids = ids.map(func(c: Variant) -> String: return String(c))
	ids.sort()
	var conditions: Array = []
	for act: int in maxi(1, (rules.get("acts", []) as Array).size()):
		conditions.append(String(ids[rng.range_int(0, ids.size() - 1)]) if not ids.is_empty() else "")
	return {"seed": seed_value, "mode": "daily", "day": day, "tier": int(daily.get("rung", 0)), "deals": true,
		"deal_offer": roll_deals(rules, seed_value), "conditions": conditions,
		"rules": {"modifiers": {"acts": conditions.duplicate()}}}


## 085: the weekly contract for `week` (weeks since 1970-01-05, a Monday, UTC): a fixed rung, a fixed
## crew and `challenges.weekly.twists` announced twists from `challenges.twists` (each a list of adds
## on rules the game already has). {"seed", "mode": "weekly", "week", "crew_id", "tier" (= "rung"),
## "rung", "twists": [{"id", "text"}], "deals": true, "deal_offer", "rules": {"adds": the twists'}}.
## `rewards` (`data/weekly_rewards.json`, `ContentDB.weekly_rewards`: {id, trophy, livery, name} each):
## the week's is `rewards[week % n]`, carried as "reward": its id -- the trophy and livery a clear earns.
static func weekly_options(rules: Dictionary, week: int, rewards: Array = []) -> Dictionary:
	var challenges: Dictionary = rules.get("challenges", {})
	var weekly: Dictionary = challenges.get("weekly", {})
	var seed_value: int = IntentAI.mix(week, 0x3EE7, 0x5EED, 23) & SEED_MASK
	var rng := SimRNG.new(IntentAI.mix(week, 0x3EE8, 0x5EED, 31))
	var crews: Array = weekly.get("crews", ["salvagers"])
	var crew_id: String = String(crews[posmod(week, maxi(1, crews.size()))]) if not crews.is_empty() else "salvagers"
	var pool: Dictionary = challenges.get("twists", {})
	var ids: Array = pool.keys().map(func(k: Variant) -> String: return String(k)).filter(func(k: String) -> bool: return not k.begins_with("_"))
	ids.sort()
	var twists: Array = []
	var adds: Array = []
	for n: int in mini(int(weekly.get("twists", 3)), ids.size()):
		var id: String = ids.pop_at(rng.range_int(0, ids.size() - 1))
		var twist: Dictionary = pool[id]
		twists.append({"id": id, "text": String(twist.get("text", id))})
		for add: Variant in (twist.get("adds", []) as Array):
			adds.append((add as Dictionary).duplicate(true))
	twists.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["id"]) < String(b["id"]))
	var rung: int = int(weekly.get("rung", 4))
	var out: Dictionary = {"seed": seed_value, "mode": "weekly", "week": week, "crew_id": crew_id, "tier": rung, "rung": rung,
		"twists": twists, "deals": true, "deal_offer": roll_deals(rules, seed_value), "rules": {"adds": adds}}
	if not rewards.is_empty():
		out["reward"] = String((rewards[posmod(week, rewards.size())] as Dictionary).get("id", ""))
	return out
