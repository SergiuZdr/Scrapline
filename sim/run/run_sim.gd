class_name RunSim
extends RefCounted

## The rules of a run: the region, travel, the Reclaimer front, what each site does,
## salvage, the workshop, refits and how a run ends.
##
## Like `CombatSim`, a run is `start(setup)` plus `apply` for every action, and nothing
## else changes a `RunState`. A fight's result is not reported to the run -- the run
## REPLAYS the fight's own action log through `CombatSim` and reads the result off that.
## So a whole run, fights included, is one list of plain actions: that list is the save
## file, and a run cannot be told it won a fight it did not win.
##
## Actions:
##   [TRAVEL,  site_id]
##   [FIGHT,   combat_actions]           resolves a pending fight
##   [PICK,    index]                    reward / scrapyard; -1 = take nothing (or the scrap)
##   [REPAIR]                            workshop: patch every machine
##   [REBUILD, crew_index]               workshop: rebuild a wreck
##   [LEAVE]                             leave the workshop
##   [REFIT,   crew_index, socket, cargo_index]   swap a socket with cargo; -1 = unfit into cargo
##   [SCRAP_PART, cargo_index]           break a part in the hold down for scrap (any time but a fight)
##   [EXPAND_HOLD]                       workshop: buy more room in the hold
##   [LEVEL_UP, crew_index, perk]        garage: the next level, keeping perk `perk` (0-2) of its offer
##   [ASSEMBLE, loadouts]                before the first move: build the crew from the bench
##   [TUNE, where, index, option]        workshop: tune a part once, option 0 or 1; `where` is a
##                                       crew index (then `index` is a socket) or -1 (the hold)
##   [BUY, index]                        trader: buy part `index` of its stock
##   [SELL, cargo_index]                 trader: sell a part from the hold
##   [CHOOSE, option]                    signal: take one of the event's options
##   [RENAME, crew_index, name]          give a machine its own name (027), any time but a fight

const TRAVEL: int = 0
const FIGHT: int = 1
const PICK: int = 2
const REPAIR: int = 3
const REBUILD: int = 4
const LEAVE: int = 5
const REFIT: int = 6
const SCRAP_PART: int = 7
const EXPAND_HOLD: int = 8
const LEVEL_UP: int = 9
const ASSEMBLE: int = 10
const TUNE: int = 11
const BUY: int = 12
const SELL: int = 13
const CHOOSE: int = 14
const RENAME: int = 15
## How long a machine's name may be (027): it has to fit a card and a tab.
const NAME_MAX: int = 12
## Site panels LEAVE closes (a signal is closed by one of its own options).
const LEAVABLE: PackedStringArray = ["workshop", "trader", "tower"]

const FIGHT_TYPES: PackedStringArray = ["skirmish", "elite", "boss"]


static func start(setup: RunSetup) -> RunState:
	var state := RunState.new()
	var rules: Dictionary = setup.rules
	state.scrap = int(rules.get("starting_scrap", 0))
	state.hold_size = int((rules.get("hold", {}) as Dictionary).get("start", 8))
	for spec: Dictionary in (rules.get("starting_crew", []) as Array):
		var parts: Array = []
		for id: Variant in spec.get("parts", []):
			parts.append(String(id))
		var member: Dictionary = {"name": String(spec.get("name", "")), "parts": parts, "alive": true, "hp": 0, "level": 0, "perks": []}
		member["hp"] = max_hp(setup, member)
		state.crew.append(member)
	_generate_region(state, setup)
	state.current = 0
	state.sites[0]["visited"] = true
	state.log.append("The crew rolls into the yard. The Reclaimer is somewhere behind.")
	return state


static func replay(setup: RunSetup, actions: Array) -> RunState:
	var state: RunState = start(setup)
	for action: Array in actions:
		apply(state, setup, action)
	return state


## Applies one action. Returns false, and changes nothing, if it is not legal now.
static func apply(state: RunState, setup: RunSetup, action: Array) -> bool:
	if state.outcome != RunState.ONGOING or action.is_empty():
		return false
	match int(action[0]):
		TRAVEL:
			return _travel(state, setup, int(action[1]))
		FIGHT:
			return _fight(state, setup, action[1] as Array)
		PICK:
			return _pick(state, setup, int(action[1]))
		REPAIR:
			return _repair(state, setup)
		REBUILD:
			return _rebuild(state, setup, int(action[1]))
		LEAVE:
			if not LEAVABLE.has(String(state.pending.get("kind", ""))):
				return false
			state.pending = {}
			return true
		BUY:
			return _buy(state, setup, int(action[1]))
		SELL:
			return _sell(state, setup, int(action[1]))
		CHOOSE:
			return _choose(state, setup, int(action[1]))
		REFIT:
			return _refit(state, setup, int(action[1]), int(action[2]), int(action[3]))
		SCRAP_PART:
			return _scrap_part(state, setup, int(action[1]))
		EXPAND_HOLD:
			return _expand_hold(state, setup)
		LEVEL_UP:
			return action.size() >= 3 and _level_up(state, setup, int(action[1]), int(action[2]))
		ASSEMBLE:
			return _assemble(state, setup, action[1] as Array)
		TUNE:
			return action.size() >= 4 and _tune(state, setup, int(action[1]), int(action[2]), int(action[3]))
		RENAME:
			return action.size() >= 3 and _rename(state, int(action[1]), String(action[2]))
	return false


## A machine's name, as the player typed it (027): trimmed, 1 to NAME_MAX letters, digits,
## spaces or dashes, never while a fight is pending (the fight already carries its names).
static func clean_name(text: String) -> String:
	var out: String = ""
	for c: String in text.strip_edges():
		if c == " " or c == "-" or c == "'" or c.to_upper() != c.to_lower() or (c >= "0" and c <= "9"):
			out += c
	return out.strip_edges().left(NAME_MAX)


static func _rename(state: RunState, crew: int, text: String) -> bool:
	var name: String = clean_name(text)
	if crew < 0 or crew >= state.crew.size() or name.is_empty() or name != text:
		return false
	if String(state.pending.get("kind", "")) == "fight":
		return false
	state.crew[crew]["name"] = name
	return true


# --- Queries -----------------------------------------------------------------

## Sites the crew can travel to right now.
static func destinations(state: RunState) -> Array[int]:
	var out: Array[int] = []
	if not state.pending.is_empty() or state.outcome != RunState.ONGOING or state.overfull():
		return out
	for id: Variant in (state.site(state.current)["links"] as Array):
		if not state.consumed(int(id)):
			out.append(int(id))
	out.sort()
	return out


## Whether the player knows what a site is. Fog lifts from every site next to one the
## crew has visited.
static func revealed(state: RunState, id: int) -> bool:
	var s: Dictionary = state.site(id)
	if bool(s["visited"]) or String(s["type"]) == "boss" or state.scouted.has(id):
		return true
	for other: Variant in (s["links"] as Array):
		if bool(state.site(int(other))["visited"]):
			return true
	return false


## The CombatSetup for the pending fight, or null.
static func fight_setup(state: RunState, setup: RunSetup) -> CombatSetup:
	if String(state.pending.get("kind", "")) != "fight":
		return null
	return CombatSetup.build(state.pending["fight"], setup.combat_rules, setup.parts, setup.tiles,
		setup.wheel, IntentAI.mix(setup.rng_seed, state.current, 17, 0))


## A machine's full HP, read off the unit a fight would field -- parts, sets, levels and
## perks all included -- so the run, the garage and the fight cannot disagree about it.
static func max_hp(setup: RunSetup, member: Dictionary) -> int:
	return preview_machine(setup, member).max_hp


## A crew member as a fight's unit spec: parts, HP now, and its levels and perks as one
## bonus block (`CombatSetup.apply_bonus`).
static func machine_spec(setup: RunSetup, member: Dictionary) -> Dictionary:
	return {"name": String(member["name"]), "parts": (member["parts"] as Array).duplicate(),
		"hp_now": maxi(1, int(member["hp"])), "bonus": bonus_of(setup, member),
		"level": int(member.get("level", 0))}


## Everything a machine's levels and perks add, summed into one additive block.
static func bonus_of(setup: RunSetup, member: Dictionary) -> Dictionary:
	var total: Dictionary = {}
	var steps: Array = (setup.rules.get("levels", {}) as Dictionary).get("bonus", [])
	for n: int in mini(int(member.get("level", 0)), steps.size()):
		_add_grid(total, steps[n])
	var perks: Dictionary = setup.rules.get("perks", {})
	for id: Variant in (member.get("perks", []) as Array):
		_add_grid(total, (perks.get(String(id), {}) as Dictionary).get("grid", {}))
	return total


static func _add_grid(total: Dictionary, grid: Dictionary) -> void:
	var keys: Array = grid.keys()
	keys.sort()
	for key: Variant in keys:
		total[key] = int(total.get(key, 0)) + int(grid[key])


## The machine as the next fight will field it, for the garage's numbers.
static func preview_machine(setup: RunSetup, member: Dictionary) -> GridUnit:
	return CombatSetup.unit_from(machine_spec(setup, member), setup.combat_rules, setup.parts)


## What a machine's levels add up to: `what` is "hp" or "damage" (`run.json` `levels.bonus`,
## one entry per level).
static func level_bonus(setup: RunSetup, member: Dictionary, what: String) -> int:
	var steps: Array = (setup.rules.get("levels", {}) as Dictionary).get("bonus", [])
	var total: int = 0
	for n: int in mini(int(member.get("level", 0)), steps.size()):
		total += int((steps[n] as Dictionary).get(what, 0))
	return total


## What machine `index`'s NEXT level adds, `{ "hp", "damage" }` (empty at the top).
static func next_level_bonus(state: RunState, setup: RunSetup, index: int) -> Dictionary:
	var steps: Array = (setup.rules.get("levels", {}) as Dictionary).get("bonus", [])
	var level: int = int(state.crew[index].get("level", 0))
	return steps[level] if level < steps.size() else {}


## Scrap for machine `index`'s next level, or -1 when it is at the top.
static func level_cost(state: RunState, setup: RunSetup, index: int) -> int:
	var costs: Array = (setup.rules.get("levels", {}) as Dictionary).get("costs", [])
	var level: int = int(state.crew[index].get("level", 0))
	return int(costs[level]) if level < costs.size() else -1


## The three perks machine `index`'s next level offers (011): the ones it has not taken that
## would do something for it as it is built now, in an order seeded by the run, the machine
## and the level -- the same offer on every replay. Empty at the top level.
static func perk_offer(state: RunState, setup: RunSetup, index: int) -> Array[String]:
	var out: Array[String] = []
	if index < 0 or index >= state.crew.size() or level_cost(state, setup, index) < 0:
		return out
	var member: Dictionary = state.crew[index]
	var unit: GridUnit = preview_machine(setup, member)
	var perks: Dictionary = setup.rules.get("perks", {})
	var level: int = int(member.get("level", 0))
	var taken: Array = member.get("perks", [])
	var eligible: Array = []
	var ids: Array = perks.keys()
	ids.sort()
	for id: Variant in ids:
		if taken.has(String(id)) or not _perk_fits(unit, String((perks[id] as Dictionary).get("needs", ""))):
			continue
		eligible.append([IntentAI.mix(setup.rng_seed, index, level, _text_hash(String(id))), String(id)])
	eligible.sort_custom(func(a: Array, b: Array) -> bool:
		return int(a[0]) < int(b[0]) or (int(a[0]) == int(b[0]) and String(a[1]) < String(b[1])))
	for pair: Array in eligible.slice(0, int((setup.rules.get("levels", {}) as Dictionary).get("perk_choices", 3))):
		out.append(String(pair[1]))
	return out


## Whether a perk would do anything for this machine (`needs` in perks.json).
static func _perk_fits(u: GridUnit, needs: String) -> bool:
	match needs:
		"melee", "ranged", "chain":
			for w: Dictionary in u.weapons:
				if bool(w["empty"]):
					continue
				var shape: String = String(w["shape"])
				if (needs == "melee" and shape == "melee") or (needs == "ranged" and shape != "melee") \
						or (needs == "chain" and int(w["chain"]) > 0):
					return true
			return false
		"ability":
			return not u.abilities.is_empty()
		"shovable":
			return not u.unshovable
		"stops":
			return not u.move_after_attack
	return true


## FNV-1a of a string, for seeding by name: a real hash, never a sum of characters.
static func _text_hash(text: String) -> int:
	var h: int = 0x811C9DC5
	for byte: int in text.to_utf8_buffer():
		h = ((h ^ byte) * 0x01000193) & 0xFFFFFFFF
	return h


## Scrap to tune `part` at a workshop (`workshop.tune_costs`, by rarity).
static func tune_cost(setup: RunSetup, part: String) -> int:
	var costs: Array = (setup.rules.get("workshop", {}) as Dictionary).get("tune_costs", [6, 10, 14])
	return int(costs[clampi(setup.rarity(part) - 1, 0, costs.size() - 1)])


## The makers the crew is building sets from: every maker with two or more parts on one
## living machine. Salvage leans toward these, so a set can be finished on purpose.
static func crew_makers(state: RunState, setup: RunSetup) -> Array:
	var out: Array = []
	for member: Dictionary in state.crew:
		if not bool(member["alive"]):
			continue
		var counts: Dictionary = {}
		for id: Variant in (member["parts"] as Array):
			var maker: String = String((setup.parts.get(String(id), {}) as Dictionary).get("maker", ""))
			if not maker.is_empty():
				counts[maker] = int(counts.get(maker, 0)) + 1
		for maker: Variant in counts:
			if int(counts[maker]) >= 2 and not out.has(maker):
				out.append(maker)
	out.sort()
	return out


static func can_refit(state: RunState) -> bool:
	return state.outcome == RunState.ONGOING and String(state.pending.get("kind", "")) != "fight"


# --- Actions -----------------------------------------------------------------

static func _travel(state: RunState, setup: RunSetup, to: int) -> bool:
	if not destinations(state).has(to):
		return false
	var front: Dictionary = rules_of(state, setup).get("front", {})
	# Lingering in consumed ground costs the whole crew, move by move. It wears machines
	# down but never finishes one: the front pushes, it does not execute.
	if state.consumed(state.current):
		var bite: int = int(front.get("damage", 2))
		for member: Dictionary in state.crew:
			if bool(member["alive"]):
				member["hp"] = maxi(1, int(member["hp"]) - bite)
		state.log.append("The Reclaimer tears at the crew as it pulls out: -%d each." % bite)
	state.current = to
	state.moves += 1
	if state.moves % maxi(1, int(front.get("every", 2))) == 0:
		state.front_col += 1
		state.log.append("The Reclaimer swallows column %d." % (state.front_col + 1))
	var s: Dictionary = state.sites[to]
	if bool(s["visited"]):
		return true
	s["visited"] = true
	var kind: String = String(s["type"])
	if FIGHT_TYPES.has(kind):
		_start_fight(state, setup, to, kind)
		state.log.append("%s at site %d." % ["The act boss" if kind == "boss" else kind.capitalize(), to])
	elif kind == "scrapyard":
		var rewards: Dictionary = rules_of(state, setup).get("rewards", {})
		state.pending = {"kind": "scrapyard", "options": _roll_parts(setup, _rng(setup, to, 3, state.act), 1, crew_makers(state, setup),
			rules_of(state, setup).get("rewards", {})),
			"scrap": int(rewards.get("scrapyard_scrap", 15))}
		state.log.append("A scrapyard. Something in here still works.")
	elif kind == "workshop":
		state.pending = {"kind": "workshop"}
		state.log.append("A workshop with the lights still on.")
	elif kind == "trader":
		var stock: Array = _roll_parts(setup, _rng(setup, to, 8, state.act), 1, crew_makers(state, setup),
			rules_of(state, setup).get("rewards", {}))
		# The rarest in the stock comes tuned: a trader is where tuned parts can be bought.
		var best: int = 0
		for i: int in stock.size():
			if setup.rarity(String(stock[i])) > setup.rarity(String(stock[best])):
				best = i
		if not stock.is_empty() and PartTuning.can_tune(setup.parts, String(stock[best])):
			stock[best] = PartTuning.variant(String(stock[best]), _rng(setup, to, 9, state.act).range_int(0, 1))
		state.pending = {"kind": "trader", "stock": stock, "sold": []}
		state.log.append("A trader's container, lamps on.")
	elif kind == "tower":
		var seen: int = _scout(state, setup, to, int((setup.rules.get("tower", {}) as Dictionary).get("radius", 2)))
		state.pending = {"kind": "tower", "scouted": seen}
		state.log.append("From the tower: %d sites scouted." % seen)
	elif kind == "signal":
		state.pending = {"kind": "signal", "event": _pick_event(state, setup, to)}
		state.seen_events.append(String(state.pending["event"]))
		state.log.append("A signal.")
	return true


## A fight at site `to`; if it is in the column the Reclaimer takes next, its drones reach
## in (013: lingering by the line costs inside fights too).
static func _start_fight(state: RunState, setup: RunSetup, to: int, kind: String) -> void:
	var fight: Dictionary = _make_fight(state, setup, to, kind)
	if reclaimer_reaches(state, to):
		fight["reclaimer"] = (setup.rules.get("reclaimer_reach", {"round": 3, "count": 2}) as Dictionary).duplicate()
	state.pending = {"kind": "fight", "site_type": kind, "fight": fight}


## What a move to `to` costs and gives up (014, review point R5-3): whether the Reclaimer
## advances with it and the column it takes, the unvisited sites it swallows there for good,
## whether its drones would reach into a fight at `to`, and for a fight how many enemies.
static func move_preview(state: RunState, setup: RunSetup, to: int) -> Dictionary:
	var front: Dictionary = rules_of(state, setup).get("front", {})
	var advances: bool = (state.moves + 1) % maxi(1, int(front.get("every", 2))) == 0
	var front_after: int = state.front_col + (1 if advances else 0)
	var site: Dictionary = state.site(to)
	var lost: Array = []
	if advances:
		for s: Dictionary in state.sites:
			if int(s["col"]) == front_after and not bool(s["visited"]) and int(s["id"]) != to:
				lost.append(int(s["id"]))
	var kind: String = String(site.get("type", ""))
	var enemies: int = 0
	if FIGHT_TYPES.has(kind):
		var rules: Dictionary = rules_of(state, setup).get("enemies", {})
		var counts: Array = rules.get("count_by_column", [3])
		enemies = int(counts[mini(int(site["col"]), counts.size() - 1)])
		if kind == "elite":
			enemies += int(rules.get("elite_extra", 1))
		elif kind == "boss":
			enemies = 1 + int(rules.get("boss_escorts", 3))
	return {"advances": advances, "front_after": front_after, "lost": lost, "enemies": enemies,
		"reach": FIGHT_TYPES.has(kind) and int(site.get("col", -9)) == front_after + 1,
		"leaving_costs": state.consumed(state.current)}


## Whether a fight at `id` would have the Reclaimer's drones: it stands in the column the
## Reclaimer takes next.
static func reclaimer_reaches(state: RunState, id: int) -> bool:
	return int(state.site(id).get("col", -9)) == state.front_col + 1


## Scouts every site within `radius` columns of `id`. Returns how many it newly revealed.
static func _scout(state: RunState, setup: RunSetup, id: int, radius: int) -> int:
	var col: int = int(state.site(id)["col"])
	var fresh: int = 0
	for s: Dictionary in state.sites:
		if absi(int(s["col"]) - col) <= radius and not revealed(state, int(s["id"])):
			state.scouted.append(int(s["id"]))
			fresh += 1
	state.scouted.sort()
	return fresh


## The price of part `index` of the trader's stock, or -1 if it is gone.
static func trader_price(state: RunState, setup: RunSetup, index: int) -> int:
	var stock: Array = state.pending.get("stock", [])
	if index < 0 or index >= stock.size() or (state.pending.get("sold", []) as Array).has(index):
		return -1
	var trader: Dictionary = setup.rules.get("trader", {})
	var prices: Array = trader.get("prices", [12, 20, 32])
	var part: String = String(stock[index])
	return int(prices[clampi(setup.rarity(part) - 1, 0, prices.size() - 1)]) \
		+ (int(trader.get("tuned_extra", 6)) if PartTuning.is_tuned(part) else 0)


## What a trader pays for a part from the hold: a multiple of its scrap value.
static func trader_offer(setup: RunSetup, part: String) -> int:
	return scrap_value(setup, part) * int((setup.rules.get("trader", {}) as Dictionary).get("buy_multiplier", 2))


static func _buy(state: RunState, setup: RunSetup, index: int) -> bool:
	if String(state.pending.get("kind", "")) != "trader":
		return false
	var price: int = trader_price(state, setup, index)
	if price < 0 or state.scrap < price:
		return false
	var part: String = String((state.pending["stock"] as Array)[index])
	state.scrap -= price
	state.cargo.append(part)
	(state.pending["sold"] as Array).append(index)
	state.log.append("Bought %s for %d scrap." % [String((setup.parts[part] as Dictionary).get("name", part)), price])
	return true


static func _sell(state: RunState, setup: RunSetup, index: int) -> bool:
	if String(state.pending.get("kind", "")) != "trader" or index < 0 or index >= state.cargo.size():
		return false
	var part: String = state.cargo[index]
	var value: int = trader_offer(setup, part)
	state.cargo.remove_at(index)
	state.scrap += value
	state.log.append("Sold %s for %d scrap." % [String((setup.parts[part] as Dictionary).get("name", part)), value])
	return true


## The signal's event for site `id`: seeded, and never one already seen this run while an
## unseen one is left.
static func _pick_event(state: RunState, setup: RunSetup, id: int) -> String:
	var events: Dictionary = setup.rules.get("events", {})
	var ids: Array = events.keys()
	ids.sort()
	if ids.is_empty():
		return ""
	var fresh: Array = ids.filter(func(e: String) -> bool: return not state.seen_events.has(e))
	var pool: Array = fresh if not fresh.is_empty() else ids
	return String(pool[_rng(setup, id, 10, state.act).range_int(0, pool.size() - 1)])


## Whether option `index` of the pending signal can be taken: its scrap cost is affordable.
static func can_choose(state: RunState, setup: RunSetup, index: int) -> bool:
	if String(state.pending.get("kind", "")) != "signal":
		return false
	var options: Array = ((setup.rules.get("events", {}) as Dictionary).get(String(state.pending["event"]), {}) as Dictionary).get("options", [])
	if index < 0 or index >= options.size():
		return false
	var cost: int = -int(((options[index] as Dictionary).get("effects", {}) as Dictionary).get("scrap", 0))
	return cost <= 0 or state.scrap >= cost


## Takes a signal's option: exactly the effects it states, in the order events.json lists.
static func _choose(state: RunState, setup: RunSetup, index: int) -> bool:
	if not can_choose(state, setup, index):
		return false
	var site: int = state.current
	var event: Dictionary = (setup.rules.get("events", {}) as Dictionary).get(String(state.pending["event"]), {})
	var effects: Dictionary = ((event["options"] as Array)[index] as Dictionary).get("effects", {})
	state.pending = {}
	state.scrap = maxi(0, state.scrap + int(effects.get("scrap", 0)))
	var hp: int = int(effects.get("hp", 0))
	var first: bool = true
	for member: Dictionary in state.crew:
		if not bool(member["alive"]):
			continue
		var change: int = hp + (int(effects.get("hp_one", 0)) if first else 0)
		first = false
		member["hp"] = clampi(int(member["hp"]) + change, 1, max_hp(setup, member))
	var rng: SimRNG = _rng(setup, site, 11, state.act)
	if effects.has("part"):
		state.cargo.append(_roll_at_least(setup, rng, int(effects["part"])))
	if effects.has("tuned_part"):
		var part: String = _roll_at_least(setup, rng, int(effects["tuned_part"]))
		state.cargo.append(PartTuning.variant(part, rng.range_int(0, 1)) if PartTuning.can_tune(setup.parts, part) else part)
	if effects.has("reveal"):
		_scout(state, setup, site, int(effects["reveal"]))
	if int(effects.get("front", 0)) > 0:
		state.front_col += int(effects["front"])
		state.log.append("The Reclaimer lurches forward.")
	if effects.has("fight"):
		_start_fight(state, setup, site, String(effects["fight"]))
	state.log.append("%s: %s" % [String(event.get("title", "")), String(((event["options"] as Array)[index] as Dictionary).get("label", ""))])
	return true


## One part of at least `min_rarity`, from every slot's pool.
static func _roll_at_least(setup: RunSetup, rng: SimRNG, min_rarity: int) -> String:
	var all: Array = []
	for slot: String in ["chassis", "core", "arm", "module"]:
		for id: Variant in (setup.pools[slot] as Array):
			if setup.rarity(String(id)) >= min_rarity:
				all.append(id)
	return String(rng.pick(all)) if not all.is_empty() else ""


static func _fight(state: RunState, setup: RunSetup, combat_actions: Array) -> bool:
	var combat_setup: CombatSetup = fight_setup(state, setup)
	if combat_setup == null:
		return false
	var result: CombatState = CombatSim.replay(combat_setup, combat_actions)
	if result.outcome == CombatState.ONGOING:
		return false   # a fight is only reported once it has ended
	var kind: String = String(state.pending["site_type"])

	# HP carries: each machine leaves with what the fight left it. Torn arms are bolted back
	# on. A machine DESTROYED in the fight is a wreck: it keeps its chassis, nothing else.
	var fielded: Array = _fielded_crew(state)
	for slot: int in fielded.size():
		var unit: GridUnit = result.unit(slot)
		var member: Dictionary = state.crew[int(fielded[slot])]
		if unit == null:
			continue
		if unit.alive:
			member["hp"] = unit.hp
		else:
			member["alive"] = false
			member["hp"] = 0
			member["parts"] = [String(member["parts"][0]), "", "", "", ""]
			state.log.append("%s was wrecked. Its parts are gone." % member["name"])
	# Scrap piles collected during the fight are banked whatever the outcome.
	state.scrap += result.scrap_collected

	if state.alive_crew() == 0:
		_end(state, RunState.LOST, "The whole crew is wrecked.")
		return true
	if result.outcome == CombatState.LOST and kind == "boss":
		# There is no road past the gate to go on along, and the road back is reclaimed:
		# a crew that survives but does not win here is stranded, so the run ends.
		_end(state, RunState.LOST, "The gate held: the crew could not break through in time.")
		return true
	if result.outcome == CombatState.LOST:
		# The objective failed but the crew lives: no salvage, and the road goes on.
		state.pending = {}
		state.log.append("Driven off. No salvage from this one.")
		return true
	state.fights_won += 1
	if kind == "boss":
		if state.act < act_count(setup):
			_next_act(state, setup)
			return true
		_end(state, RunState.WON, "The last gate is broken: the run is won.")
		return true
	var rewards: Dictionary = rules_of(state, setup).get("rewards", {})
	var gained: int = int(rewards.get("elite_scrap" if kind == "elite" else "skirmish_scrap", 10))
	gained += result.caches().size() * int(rewards.get("cache_scrap", 6))
	state.scrap += gained
	state.pending = salvage(state, setup, kind)
	state.log.append("Won. +%d scrap%s, and salvage to pick through." % [gained,
		" (+%d from piles)" % result.scrap_collected if result.scrap_collected > 0 else ""])
	return true


## What a won fight at the current site offers: three parts or `salvage_scrap` scrap. An
## elite's guaranteed part comes off the wreck already tuned.
static func salvage(state: RunState, setup: RunSetup, kind: String) -> Dictionary:
	# Play-test 8: the act's own rewards -- later acts lean rare, or a built crew finds nothing.
	var rewards: Dictionary = rules_of(state, setup).get("rewards", {})
	var min_rarity: int = int(rewards.get("elite_min_rarity", 2)) if kind == "elite" else 1
	var rng: SimRNG = _rng(setup, state.current, 5, state.act)
	var options: Array = _roll_parts(setup, rng, min_rarity, crew_makers(state, setup), rewards)
	if kind == "elite" and not options.is_empty() and PartTuning.can_tune(setup.parts, String(options[0])):
		options[0] = PartTuning.variant(String(options[0]), rng.range_int(0, 1))
	return {"kind": "reward", "options": options, "scrap": int(rewards.get("salvage_scrap", 8))}


static func _pick(state: RunState, setup: RunSetup, index: int) -> bool:
	var kind: String = String(state.pending.get("kind", ""))
	if kind != "reward" and kind != "scrapyard":
		return false
	var options: Array = state.pending["options"]
	if index < -1 or index >= options.size():
		return false
	if index == -1:
		# Every salvage screen has a scrap alternative, so leaving the parts is a choice too.
		var value: int = int(state.pending.get("scrap", 0))
		state.scrap += value
		if value > 0:
			state.log.append("Stripped the %s for %d scrap." % ["yard" if kind == "scrapyard" else "wrecks", value])
		state.pending = {}
		return true
	# Always allowed. If the hold goes over, travel waits until something is fitted or
	# scrapped -- the choice is made with the new part in hand, not before (play-test 2).
	var part: String = String(options[index])
	state.cargo.append(part)
	state.log.append("Loaded %s into the hold." % String((setup.parts[part] as Dictionary).get("name", part)))
	state.pending = {}
	return true


## Patches every living machine by `repair_amount`, for one price.
static func _repair(state: RunState, setup: RunSetup) -> bool:
	var shop: Dictionary = setup.rules.get("workshop", {})
	var cost: int = int(shop.get("repair_cost", 8))
	if String(state.pending.get("kind", "")) != "workshop" or state.scrap < cost or not needs_repair(state, setup):
		return false
	state.scrap -= cost
	for member: Dictionary in state.crew:
		if bool(member["alive"]):
			member["hp"] = mini(max_hp(setup, member), int(member["hp"]) + int(shop.get("repair_amount", 3)))
	state.log.append("Patched the crew.")
	return true


static func needs_repair(state: RunState, setup: RunSetup) -> bool:
	for member: Dictionary in state.crew:
		if bool(member["alive"]) and int(member["hp"]) < max_hp(setup, member):
			return true
	return false


static func _rebuild(state: RunState, setup: RunSetup, index: int) -> bool:
	var cost: int = int((setup.rules.get("workshop", {}) as Dictionary).get("rebuild_cost", 20))
	if String(state.pending.get("kind", "")) != "workshop" or index < 0 or index >= state.crew.size():
		return false
	var member: Dictionary = state.crew[index]
	if bool(member["alive"]) or state.scrap < cost:
		return false
	state.scrap -= cost
	member["alive"] = true
	member["hp"] = maxi(1, max_hp(setup, member) / 2)
	state.log.append("Rebuilt %s on its old frame at half strength. Its sockets are empty." % member["name"])
	return true


static func _refit(state: RunState, setup: RunSetup, index: int, socket: int, cargo_index: int) -> bool:
	if not can_refit(state) or index < 0 or index >= state.crew.size() or socket < 0 or socket > 4:
		return false
	var member: Dictionary = state.crew[index]
	if not bool(member["alive"]):
		return false
	var parts: Array = member["parts"]
	var old: String = String(parts[socket])
	if cargo_index == -1:
		# Unfit into the hold. A machine cannot give up its chassis.
		if socket == 0 or old.is_empty():
			return false
		parts[socket] = ""
		state.cargo.append(old)
		_clamp_hp(setup, member)
		return true
	if cargo_index < 0 or cargo_index >= state.cargo.size():
		return false
	var incoming: String = state.cargo[cargo_index]
	if String((setup.parts.get(incoming, {}) as Dictionary).get("slot", "")) != RunSetup.socket_slot(socket):
		return false
	parts[socket] = incoming
	if old.is_empty():
		state.cargo.remove_at(cargo_index)
	else:
		state.cargo[cargo_index] = old
	_clamp_hp(setup, member)
	return true


## A refit can lower a machine's full HP (a lighter chassis, losing an HP module).
static func _clamp_hp(setup: RunSetup, member: Dictionary) -> void:
	member["hp"] = mini(int(member["hp"]), max_hp(setup, member))


## Scrap a part from the hold, by rarity (`scrap_value.by_rarity`).
static func scrap_value(setup: RunSetup, part: String) -> int:
	var values: Array = (setup.rules.get("scrap_value", {}) as Dictionary).get("by_rarity", [3, 6, 10])
	return int(values[clampi(setup.rarity(part) - 1, 0, values.size() - 1)])


static func _scrap_part(state: RunState, setup: RunSetup, index: int) -> bool:
	if not can_refit(state) or index < 0 or index >= state.cargo.size():
		return false
	var part: String = state.cargo[index]
	var value: int = scrap_value(setup, part)
	state.cargo.remove_at(index)
	state.scrap += value
	state.log.append("Broke down %s for %d scrap." % [String((setup.parts[part] as Dictionary).get("name", part)), value])
	return true


## The price of the next hold expansion, or -1 when there are no more.
static func expand_cost(state: RunState, setup: RunSetup) -> int:
	var hold: Dictionary = setup.rules.get("hold", {})
	var bought: int = (state.hold_size - int(hold.get("start", 8))) / maxi(1, int(hold.get("expand_by", 2)))
	var costs: Array = hold.get("expand_costs", [])
	return int(costs[bought]) if bought < costs.size() else -1


## Scrap buys a machine a level: its HP (and that HP now) and one perk of three (011). Play-
## test 3: scrap had nothing to buy; play-test 4: a level did not feel like the machine
## becoming something. The perk is the part of the level that is a decision.
static func _level_up(state: RunState, setup: RunSetup, index: int, choice: int) -> bool:
	if not can_refit(state) or index < 0 or index >= state.crew.size():
		return false
	var member: Dictionary = state.crew[index]
	var cost: int = level_cost(state, setup, index)
	if not bool(member["alive"]) or cost < 0 or state.scrap < cost:
		return false
	var offer: Array[String] = perk_offer(state, setup, index)
	if offer.is_empty() or choice < 0 or choice >= offer.size():
		return false
	var before: int = max_hp(setup, member)
	state.scrap -= cost
	member["level"] = int(member.get("level", 0)) + 1
	var perks: Array = member.get("perks", [])
	perks.append(offer[choice])
	member["perks"] = perks
	# The new HP arrives now as well as at full: a level-up is a repair of what it adds.
	member["hp"] = int(member["hp"]) + maxi(0, max_hp(setup, member) - before)
	state.log.append("%s is overhauled to level %d: %s." % [member["name"], int(member["level"]),
		String(((setup.rules.get("perks", {}) as Dictionary).get(offer[choice], {}) as Dictionary).get("name", offer[choice]))])
	return true


## Tunes a part at a workshop, once: option 0 or 1 of its two (`PartTuning`). `where` is a
## crew index and `index` a socket, or `where` is -1 and `index` is a place in the hold.
static func _tune(state: RunState, setup: RunSetup, where: int, index: int, option: int) -> bool:
	if String(state.pending.get("kind", "")) != "workshop" or option < 0 or option >= PartTuning.OPTIONS.size():
		return false
	var part: String = ""
	if where == -1:
		if index < 0 or index >= state.cargo.size():
			return false
		part = state.cargo[index]
	else:
		if where < 0 or where >= state.crew.size() or index < 0 or index > 4 or not bool(state.crew[where]["alive"]):
			return false
		part = String((state.crew[where]["parts"] as Array)[index])
	if not PartTuning.can_tune(setup.parts, part):
		return false
	var tuned: String = PartTuning.variant(part, option)
	var cost: int = tune_cost(setup, part)
	if not setup.parts.has(tuned) or state.scrap < cost:
		return false
	state.scrap -= cost
	if where == -1:
		state.cargo[index] = tuned
	else:
		var member: Dictionary = state.crew[where]
		var before: int = max_hp(setup, member)
		(member["parts"] as Array)[index] = tuned
		# A tuning that adds HP adds it now, like a level.
		member["hp"] = mini(max_hp(setup, member), int(member["hp"]) + maxi(0, max_hp(setup, member) - before))
	state.log.append("Tuned %s: %s." % [String((setup.parts[part] as Dictionary).get("name", part)),
		String((setup.parts[tuned] as Dictionary).get("tune", ""))])
	return true


## Whether the crew can still be built from the bench: before the first move, once.
static func can_assemble(state: RunState) -> bool:
	return state.outcome == RunState.ONGOING and state.moves == 0 and not state.assembled \
		and state.pending.is_empty()


## How many of a part the bench holds: every common part without limit (-1), the listed
## extras (the defaults' uncommons) once each, anything else not at all (0).
static func bench_count(setup: RunSetup, part: String) -> int:
	var bench: Dictionary = setup.rules.get("assembly", {})
	if part.is_empty() or not setup.parts.has(part) or PartTuning.is_tuned(part):
		return 0
	if setup.rarity(part) <= int(bench.get("free_rarity", 1)):
		return -1
	return int((bench.get("extra", {}) as Dictionary).get(part, 0))


## Builds the three machines from the bench (play-test 4: "a way to customise the starting
## robots from basic parts"). `loadouts`: one five-part list per crew member, in socket
## order. The frame names the machine; a second machine on the same frame is "II".
static func _assemble(state: RunState, setup: RunSetup, loadouts: Array) -> bool:
	if not can_assemble(state) or loadouts.size() != state.crew.size():
		return false
	var used: Dictionary = {}
	for loadout: Variant in loadouts:
		var parts: Array = loadout as Array
		if parts.size() != 5 or String(parts[0]).is_empty():
			return false
		for s: int in 5:
			var part: String = String(parts[s])
			if part.is_empty():
				continue
			if String((setup.parts.get(part, {}) as Dictionary).get("slot", "")) != RunSetup.socket_slot(s):
				return false
			var limit: int = bench_count(setup, part)
			used[part] = int(used.get(part, 0)) + 1
			if limit == 0 or (limit > 0 and int(used[part]) > limit):
				return false
	# Each machine keeps its crew's name whatever frame it is built on (play-test 7: a machine
	# named after its default frame read as the frame, not as a member of the crew).
	for i: int in state.crew.size():
		var parts: Array = []
		for id: Variant in (loadouts[i] as Array):
			parts.append(String(id))
		var member: Dictionary = state.crew[i]
		member["parts"] = parts
		member["hp"] = max_hp(setup, member)
	state.assembled = true
	state.log.append("The crew is built from the bench.")
	return true


static func _expand_hold(state: RunState, setup: RunSetup) -> bool:
	var cost: int = expand_cost(state, setup)
	if String(state.pending.get("kind", "")) != "workshop" or cost < 0 or state.scrap < cost:
		return false
	state.scrap -= cost
	state.hold_size += int((setup.rules.get("hold", {}) as Dictionary).get("expand_by", 2))
	state.log.append("Welded more racks into the hold: room for %d." % state.hold_size)
	return true


static func _end(state: RunState, outcome: int, reason: String) -> void:
	state.outcome = outcome
	state.end_reason = reason
	state.pending = {}
	state.log.append(reason)


# --- Generation --------------------------------------------------------------

## An RNG for one purpose at one site, independent of the order anything else was rolled
## in: a site's fight is the same whether the player got there first or last.
static func _rng(setup: RunSetup, site_id: int, salt: int, act: int = 1) -> SimRNG:
	# Act 1 rolls exactly as it did before acts existed; later acts shift the salt.
	return SimRNG.new(IntentAI.mix(setup.rng_seed, site_id, salt + (act - 1) * 131, 0x5C4A))


## How many acts a run has (021), and the rules of the act the crew is in: the run's rules
## with that act's overrides laid over them, one level deep (`acts[i].enemies.count_by_column`
## replaces only that number list).
static func act_count(setup: RunSetup) -> int:
	return maxi(1, (setup.rules.get("acts", []) as Array).size())


static func rules_of(state: RunState, setup: RunSetup) -> Dictionary:
	var acts: Array = setup.rules.get("acts", [])
	if state.act < 1 or state.act > acts.size():
		return setup.rules
	var over: Dictionary = acts[state.act - 1]
	return setup.rules if over.size() <= 1 else RunSetup.overlay(setup.rules, over)


## The gate is broken and there is another act: a new region, the same crew. What arriving
## gives (`acts[i].arrive`: a repair, scrap) is the gate's reward.
static func _next_act(state: RunState, setup: RunSetup) -> void:
	state.act += 1
	state.sites.clear()
	state.scouted.clear()
	state.front_col = -1
	state.moves = 0
	state.assembled = true
	state.pending = {}
	_generate_region(state, setup)
	state.current = 0
	state.sites[0]["visited"] = true
	var arrive: Dictionary = rules_of(state, setup).get("arrive", {})
	state.scrap += int(arrive.get("scrap", 0))
	var patch: int = int(arrive.get("repair", 0))
	for member: Dictionary in state.crew:
		if bool(member["alive"]) and patch > 0:
			member["hp"] = mini(max_hp(setup, member), int(member["hp"]) + patch)
	state.log.append("Through the gate: %s. The Reclaimer is behind again." % String(rules_of(state, setup).get("name", "Act %d" % state.act)))


static func _generate_region(state: RunState, setup: RunSetup) -> void:
	var rules: Dictionary = rules_of(state, setup)
	var region: Dictionary = rules.get("region", {})
	var columns: int = maxi(3, int(region.get("columns", 7)))
	var rng: SimRNG = _rng(setup, -1, 1, state.act)
	var by_col: Array = []
	for col: int in columns:
		var rows: int = 1 if col == 0 or col == columns - 1 else rng.range_int(int(region.get("rows_min", 2)), int(region.get("rows_max", 3)))
		var ids: Array = []
		for row: int in rows:
			var id: int = state.sites.size()
			var y: int = (row * 2 + 1) * 100 / (rows * 2)
			if rows > 1:
				y = clampi(y + rng.range_int(-8, 8), 8, 92)
			state.sites.append({"id": id, "col": col, "row": row, "x": col * 100 / (columns - 1),
				"y": y, "type": "", "links": [], "visited": false})
			ids.append(id)
		by_col.append(ids)

	# Forward links: each site to its nearest neighbour in the next column (sometimes also
	# the second nearest), then every site with no way in gets one from its nearest.
	for col: int in columns - 1:
		var here: Array = by_col[col]
		var next: Array = by_col[col + 1]
		for id: Variant in here:
			var ranked: Array = next.duplicate()
			var y: int = int(state.sites[id]["y"])
			ranked.sort_custom(func(a: int, b: int) -> bool:
				var da: int = absi(int(state.sites[a]["y"]) - y)
				var db: int = absi(int(state.sites[b]["y"]) - y)
				return da < db or (da == db and a < b))
			_link(state, int(id), int(ranked[0]))
			if ranked.size() > 1 and rng.chance_percent(40):
				_link(state, int(id), int(ranked[1]))
		for id: Variant in next:
			var has_in: bool = false
			for other: Variant in (state.sites[id]["links"] as Array):
				if int(state.sites[other]["col"]) == col:
					has_in = true
			if not has_in:
				var best: int = int(here[0])
				for candidate: Variant in here:
					if absi(int(state.sites[candidate]["y"]) - int(state.sites[id]["y"])) < absi(int(state.sites[best]["y"]) - int(state.sites[id]["y"])):
						best = int(candidate)
				_link(state, best, int(id))
		# Sideways: neighbours in the same column, so the map is a region and not a tree.
		for i: int in range(1, next.size()):
			if col + 1 < columns - 1:
				_link(state, int(next[i - 1]), int(next[i]))

	# Site types.
	var weights: Dictionary = rules.get("site_weights", {})
	var kinds: Array = weights.keys()
	kinds.sort()
	for col: int in columns:
		for id: Variant in by_col[col]:
			var kind: String
			if col == 0:
				kind = "start"
			elif col == columns - 1:
				kind = "boss"
			elif col == 1:
				# The first step is always a fight or a scrapyard: something happens at once.
				kind = "skirmish" if rng.chance_percent(70) else "scrapyard"
			else:
				kind = _weighted(rng, kinds, weights, col >= int(rules.get("elite_from_column", 2)))
			state.sites[id]["type"] = kind
	for col: Variant in (rules.get("workshop_guaranteed_columns", []) as Array):
		var ids: Array = by_col[clampi(int(col), 1, columns - 2)]
		var has_shop: bool = false
		for id: Variant in ids:
			has_shop = has_shop or String(state.sites[id]["type"]) == "workshop"
		if not has_shop:
			state.sites[int(ids[rng.range_int(0, ids.size() - 1)])]["type"] = "workshop"


static func _link(state: RunState, a: int, b: int) -> void:
	if a == b:
		return
	var la: Array = state.sites[a]["links"]
	var lb: Array = state.sites[b]["links"]
	if not la.has(b):
		la.append(b)
		la.sort()
	if not lb.has(a):
		lb.append(a)
		lb.sort()


static func _weighted(rng: SimRNG, kinds: Array, weights: Dictionary, allow_elite: bool) -> String:
	var total: int = 0
	for kind: Variant in kinds:
		if String(kind) != "elite" or allow_elite:
			total += int(weights[kind])
	var roll: int = rng.range_int(1, maxi(1, total))
	for kind: Variant in kinds:
		if String(kind) == "elite" and not allow_elite:
			continue
		roll -= int(weights[kind])
		if roll <= 0:
			return String(kind)
	return "skirmish"


## Crew members that take the field, in order: the living ones.
static func _fielded_crew(state: RunState) -> Array:
	var out: Array = []
	for i: int in state.crew.size():
		if bool(state.crew[i]["alive"]):
			out.append(i)
	return out


## A fight for a site: an authored map, the crew in its player slots, the Crawler as it is
## now, and an enemy squad rolled from the parts pool by column and site type.
static func _make_fight(state: RunState, setup: RunSetup, site_id: int, kind: String) -> Dictionary:
	var rng: SimRNG = _rng(setup, site_id, 2, state.act)
	var ids: Array = []
	var gate: String = ""
	for id: Variant in setup.fights:
		var map: Dictionary = setup.fights[id]
		# The shakedown (012) is the tutorial's own board and the gate's (013) the boss's.
		# A map names the acts it belongs to (021); one that names none is Act 1's.
		if not (map.get("acts", [1]) as Array).has(float(state.act)) and not (map.get("acts", [1]) as Array).has(state.act):
			continue
		if bool(map.get("boss", false)):
			gate = String(id)
		elif not bool(map.get("tutorial", false)):
			ids.append(id)
	ids.sort()
	var template: Dictionary = setup.fights[ids[rng.range_int(0, ids.size() - 1)]]
	if kind == "boss" and not gate.is_empty():
		return _make_gate_fight(state, setup, site_id, setup.fights[gate], rng)
	var col: int = int(state.sites[site_id]["col"])
	var enemies_rules: Dictionary = rules_of(state, setup).get("enemies", {})
	var counts: Array = enemies_rules.get("count_by_column", [3])
	var caps: Array = enemies_rules.get("rarity_cap_by_column", [3])
	var count: int = int(counts[mini(col, counts.size() - 1)])
	var cap: int = int(caps[mini(col, caps.size() - 1)])
	var hp_bonus: int = 0
	if kind == "elite":
		count += int(enemies_rules.get("elite_extra", 1))
		hp_bonus = int(enemies_rules.get("elite_hp_bonus", 3))
	elif kind == "boss":
		count = int(enemies_rules.get("boss_count", 5))
		hp_bonus = int(enemies_rules.get("boss_hp_bonus", 4))
		cap = 3

	var fight: Dictionary = {"id": "run_site_%d" % site_id, "name": String(template.get("name", "")),
		"rows": _scatter_terrain(rules_of(state, setup).get("terrain", {}), rng, template)}
	var laid: Dictionary = template.duplicate()
	laid["rows"] = fight["rows"]
	fight["objective"] = _roll_objective(setup, rng, laid, kind)

	var player: Array = []
	var slots: Array = template.get("player", [])
	var fielded: Array = _fielded_crew(state)
	for i: int in mini(fielded.size(), slots.size()):
		var member: Dictionary = state.crew[int(fielded[i])]
		var spec: Dictionary = machine_spec(setup, member)
		spec["x"] = int(slots[i]["x"])
		spec["y"] = int(slots[i]["y"])
		player.append(spec)
	fight["player"] = player

	var positions: Array = _enemy_positions(template, count)
	var enemy: Array = []
	for i: int in positions.size():
		var parts: Array = [_roll_slot(setup, rng, "chassis", cap), _roll_slot(setup, rng, "core", cap),
			_roll_slot(setup, rng, "arm", cap), _roll_slot(setup, rng, "arm", cap), _roll_slot(setup, rng, "module", cap)]
		var spec: Dictionary = {"name": String((setup.parts[parts[0]] as Dictionary).get("name", "")).replace(" Frame", ""),
			"parts": parts, "x": int(positions[i].x), "y": int(positions[i].y)}
		var kind_rules: Dictionary = rules_of(state, setup).get("kinds", {})
		var chances: Array = kind_rules.get("chance_by_column", [0])
		if rng.chance_percent(int(chances[mini(col, chances.size() - 1)])):
			spec["kind"] = _weighted(rng, (kind_rules.get("weights", {}) as Dictionary).keys(), kind_rules.get("weights", {}), true)
		# An act may arm every rolled enemy (021: `enemies.bonus`, the block levels use).
		if enemies_rules.has("bonus"):
			spec["bonus"] = (enemies_rules["bonus"] as Dictionary).duplicate()
		# An act may toughen every rolled enemy (021: `enemies.hp_all`).
		var hp_all: int = int(enemies_rules.get("hp_all", 0))
		if hp_all > 0:
			var base_c: Dictionary = (setup.parts[parts[0]] as Dictionary).get("grid", {})
			var base_m: Dictionary = (setup.parts[parts[4]] as Dictionary).get("grid", {})
			spec["hp"] = int(base_c.get("hp", 8)) + int(base_m.get("hp", 0)) + hp_all
		if hp_bonus > 0 and i == 0:
			var cg: Dictionary = (setup.parts[parts[0]] as Dictionary).get("grid", {})
			var mg: Dictionary = (setup.parts[parts[4]] as Dictionary).get("grid", {})
			spec["hp"] = int(cg.get("hp", 8)) + int(mg.get("hp", 0)) + hp_bonus + hp_all
			spec["name"] = String(spec["name"]) + (" Warlord" if kind == "boss" else " Veteran")
		enemy.append(spec)
	fight["enemy"] = enemy
	return fight


## The act's gate (013): its authored map and keeper, escorts rolled at its other positions.
static func _make_gate_fight(state: RunState, setup: RunSetup, site_id: int, template: Dictionary, rng: SimRNG) -> Dictionary:
	var enemies_rules: Dictionary = rules_of(state, setup).get("enemies", {})
	var fight: Dictionary = {"id": "run_site_%d" % site_id, "name": String(template.get("name", "")),
		"rows": (template["rows"] as Array).duplicate(), "objective": {"type": "rout"}}
	if template.has("max_rounds"):
		fight["max_rounds"] = int(template["max_rounds"])
	var player: Array = []
	var slots: Array = template.get("player", [])
	var fielded: Array = _fielded_crew(state)
	for i: int in mini(fielded.size(), slots.size()):
		var spec: Dictionary = machine_spec(setup, state.crew[int(fielded[i])])
		spec["x"] = int(slots[i]["x"])
		spec["y"] = int(slots[i]["y"])
		player.append(spec)
	fight["player"] = player
	var positions: Array = template.get("enemy", [])
	var enemy: Array = [(positions[0] as Dictionary).duplicate(true)]
	# Play-test 8: the later keepers were easier than the Sorter; the act's arming reaches them too.
	if enemies_rules.has("bonus"):
		(enemy[0] as Dictionary)["bonus"] = (enemies_rules["bonus"] as Dictionary).duplicate()
	var escorts: int = int(enemies_rules.get("boss_escorts", 3))
	for i: int in range(1, mini(escorts + 1, positions.size())):
		var parts: Array = [_roll_slot(setup, rng, "chassis", 3), _roll_slot(setup, rng, "core", 3),
			_roll_slot(setup, rng, "arm", 3), _roll_slot(setup, rng, "arm", 3), _roll_slot(setup, rng, "module", 3)]
		var escort: Dictionary = {"name": String((setup.parts[parts[0]] as Dictionary).get("name", "")).replace(" Frame", ""),
			"parts": parts, "x": int(positions[i]["x"]), "y": int(positions[i]["y"])}
		if enemies_rules.has("bonus"):
			escort["bonus"] = (enemies_rules["bonus"] as Dictionary).duplicate()
		enemy.append(escort)
	fight["enemy"] = enemy
	return fight


## The template's map with barrels, crate walls and pits scattered on open hexes in the
## middle rows, never where anyone starts.
static func _scatter_terrain(terrain: Dictionary, rng: SimRNG, template: Dictionary) -> Array:
	var rows: Array = (template["rows"] as Array).duplicate()
	var taken: Array = []
	for spec: Dictionary in (template.get("player", []) as Array) + (template.get("enemy", []) as Array):
		taken.append(Vector2i(int(spec["x"]), int(spec["y"])))
	for pair: Array in [["barrels", "b"], ["crates", "c"], ["pits", "o"], ["slag", "l"], ["flues", "f"]]:
		# A kind of terrain an act does not name draws nothing from the dice (025: Acts 1 and 2
		# roll exactly as they did before flues existed).
		if pair[0] == "flues" and not terrain.has("flues"):
			continue
		var span: Array = terrain.get(pair[0], [0, 0])
		var count: int = rng.range_int(int(span[0]), int(span[1]))
		for cell: Vector2i in _free_cells(rng, rows, taken, terrain.get("rows", [2, 3, 4, 5]), count):
			var row: String = String(rows[cell.y])
			rows[cell.y] = row.substr(0, cell.x) + String(pair[1]) + row.substr(cell.x + 1)
			taken.append(cell)
	return rows


## What this fight asks for. A boss is always a rout. Otherwise rolled by weight; a defend
## fight puts caches in the player's half, a salvage fight scatters piles in the middle.
static func _roll_objective(setup: RunSetup, rng: SimRNG, template: Dictionary, kind: String) -> Dictionary:
	if kind == "boss":
		return {"type": "rout"}
	var weights: Dictionary = setup.rules.get("objective_weights", {"rout": 1})
	var kinds: Array = weights.keys()
	kinds.sort()
	var total: int = 0
	for k: Variant in kinds:
		total += int(weights[k])
	var roll: int = rng.range_int(1, maxi(1, total))
	var chosen: String = "rout"
	for k: Variant in kinds:
		roll -= int(weights[k])
		if roll <= 0:
			chosen = String(k)
			break
	var o: Dictionary = setup.rules.get("objectives", {})
	var rows: Array = template["rows"]
	var taken: Array = []
	for spec: Dictionary in (template.get("player", []) as Array) + (template.get("enemy", []) as Array):
		taken.append(Vector2i(int(spec["x"]), int(spec["y"])))
	match chosen:
		"defend":
			var caches: Array = []
			# Play-test 8: two caches side by side went to one lob and its splash. They stand at
			# least `cache_spacing` apart when the rows allow it.
			for cell: Vector2i in _free_cells(rng, rows, taken, [rows.size() - 1, rows.size() - 2], int(o.get("defend_caches", 2)),
					int(o.get("cache_spacing", 3))):
				caches.append({"x": cell.x, "y": cell.y})
				taken.append(cell)
			return {"type": "defend", "rounds": int(o.get("defend_rounds", 4)), "caches": caches}
		"salvage":
			var piles: Array = []
			for cell: Vector2i in _free_cells(rng, rows, taken, [2, 3, 4, 5], int(o.get("salvage_piles", 4))):
				piles.append({"x": cell.x, "y": cell.y})
				taken.append(cell)
			return {"type": "salvage", "need": mini(int(o.get("salvage_need", 3)), piles.size()), "piles": piles}
	return {"type": "rout"}


## `count` open cells from the given rows, chosen by the RNG from a sorted candidate list.
static func _free_cells(rng: SimRNG, rows: Array, taken: Array, row_ids: Array, count: int, spacing: int = 0) -> Array:
	var candidates: Array = []
	for y: Variant in row_ids:
		var row: String = String(rows[int(y)])
		for x: int in row.length():
			var cell := Vector2i(x, int(y))
			if row[x] == "." and not taken.has(cell):
				candidates.append(cell)
	var out: Array = []
	while out.size() < count and not candidates.is_empty():
		var pool: Array = candidates
		if spacing > 0 and not out.is_empty():
			pool = candidates.filter(func(c: Vector2i) -> bool:
				return out.all(func(o: Vector2i) -> bool: return Hex.distance(c, o) >= spacing))
			if pool.is_empty():
				pool = candidates
		var pick: Vector2i = pool[rng.range_int(0, pool.size() - 1)]
		candidates.erase(pick)
		out.append(pick)
	return out


## The template's enemy positions, then free cells from the top rows if more are needed.
static func _enemy_positions(template: Dictionary, count: int) -> Array:
	var out: Array = []
	for spec: Dictionary in (template.get("enemy", []) as Array):
		if out.size() < count:
			out.append(Vector2i(int(spec["x"]), int(spec["y"])))
	var rows: Array = template["rows"]
	for y: int in 2:
		for x: int in String(rows[y]).length():
			if out.size() >= count:
				return out
			var cell := Vector2i(x, y)
			if String(rows[y])[x] == "." and not out.has(cell):
				out.append(cell)
	return out


static func _roll_slot(setup: RunSetup, rng: SimRNG, slot: String, cap: int) -> String:
	var pool: Array = []
	for id: Variant in (setup.pools[slot] as Array):
		if setup.rarity(String(id)) <= cap:
			pool.append(id)
	return String(rng.pick(pool))


## Salvage: `choices` parts from as many DIFFERENT slots, so the options pull in different
## directions (011: "rewards that are always a real choice"). Each is weighted by rarity; the
## first is at `min_rarity` or above; the second comes from a maker in `favour` when one
## fits, so a set can be finished on purpose rather than by luck.
static func _roll_parts(setup: RunSetup, rng: SimRNG, min_rarity: int, favour: Array = [], act_rewards: Dictionary = {}) -> Array:
	var rewards: Dictionary = act_rewards if not act_rewards.is_empty() else setup.rules.get("rewards", {})
	var weights: Array = rewards.get("rarity_weights", [60, 30, 10])
	var choices: int = int(rewards.get("choices", 3))
	var slots: Array = []
	var left: Array = ["chassis", "core", "arm", "module"]
	while slots.size() < choices:
		if left.is_empty():
			left = ["chassis", "core", "arm", "module"]
		slots.append(left.pop_at(rng.range_int(0, left.size() - 1)))
	var out: Array = []
	for i: int in slots.size():
		var rarity: int = 1
		var roll: int = rng.range_int(1, 100)
		for r: int in weights.size():
			roll -= int(weights[r])
			if roll <= 0:
				rarity = r + 1
				break
		if i == 0:
			rarity = maxi(rarity, min_rarity)
		var candidates: Array = (setup.pools[slots[i]] as Array).filter(func(id: String) -> bool: return not out.has(id))
		var pool: Array = candidates.filter(func(id: String) -> bool: return setup.rarity(id) == rarity)
		if pool.is_empty():
			pool = candidates
		if i == 1 and not favour.is_empty():
			var theirs: Array = pool.filter(func(id: String) -> bool:
				return favour.has(String((setup.parts[id] as Dictionary).get("maker", ""))))
			if not theirs.is_empty():
				pool = theirs
		if not pool.is_empty():
			out.append(String(rng.pick(pool)))
	return out
