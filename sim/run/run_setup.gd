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
## ContentDB.parts / tiles / fights, and `Balance.effectiveness`.
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
