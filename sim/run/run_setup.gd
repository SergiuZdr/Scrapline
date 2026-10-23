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
static func apply_adds(base: Dictionary, adds: Array) -> Dictionary:
	var order: Array = []
	for i: int in adds.size():
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


## 084 (B8): a run's seed as a short word code that carries the content version, and back.
static func seed_code(seed_value: int, version: String) -> String:
	return ""


## {"seed": int, "version": String}, or {} when the code does not parse.
static func parse_seed_code(code: String) -> Dictionary:
	return {}
