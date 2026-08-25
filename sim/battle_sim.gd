class_name BattleSim
extends RefCounted

## The battle simulation. Pure logic, no scene tree, no engine RNG, no floats.
##
## Structure of a battle: the fight runs continuously on a fixed 20 Hz tick, and
## every `cycle_ticks` it freezes into an Order Phase where each unit receives a
## chain of up to three actions. Units then act on their own attack timers during the
## window, which is why Speed is a real stat -- a light scout swings three times in
## the time a siege chassis swings once.
##
## The whole design rests on this class being reproducible. The same
## (setup, order_log, content, balance) must yield a byte-identical event stream on a
## player's phone and on the Linux server that re-runs it to check for cheating.

## Where a cycle's chain came from, reported in the ORDERS_SET event so the UI can
## show at a glance which units the player actually touched.
const ORDER_NEW: int = 0       ## the player issued it this cycle
const ORDER_STANDING: int = 1  ## carried over from a previous cycle
const ORDER_AUTO: int = 2      ## chosen by the team's doctrine

var units: Array[SimUnit] = []
var field: Battlefield = null
var rng: SimRNG = null
var events: EventStream = null
var balance: Balance = null
var doctrines: Array[Doctrine] = []

var tick: int = 0
var cycle: int = 0
## Stop early after this many cycles; -1 runs to a natural conclusion.
var _cycle_limit: int = -1
## Per-battle salt for speed-tie ordering, derived from the seed.
var _tie_salt: int = 0
var _damage_dealt: Array[int] = [0, 0]
## Linkage lookup, indexed [previous_action_kind][next_action_kind].
var _linkages: Dictionary = {}
## Set for the duration of one action when a Linkage waives its heat cost.
var _free_heat: bool = false
## Damage multiplier granted to the current action by a Linkage, in percent.
var _linked_power: int = Balance.SCALE


## The single entry point. `order_log[cycle]` maps a unit_ref to its chain; any unit
## without an explicit order is played by its team's doctrine, which is how
## auto-battle and async PvP opponents work.
##
## `stop_after_cycles` lets interactive play reuse this exact function instead of
## needing a stepping API. The player fills in cycle N's orders, the whole battle is
## re-simulated from tick 0 with the orders known so far, and the presentation layer
## plays only the events it has not shown yet. The event stream is prefix-stable --
## adding orders for cycle N+1 cannot change what happened in cycles 0..N -- so this
## is safe, and it means live play, replays, and server verification all run one code
## path. Re-simulating a full battle costs ~30 ms, so the redundancy is free.
static func simulate(
	setup: BattleSetup,
	order_log: Array,
	content: Dictionary,
	balance: Balance,
	team_doctrines: Array = [],
	stop_after_cycles: int = -1
) -> BattleResult:
	var sim := BattleSim.new()
	sim._cycle_limit = stop_after_cycles
	return sim._run(setup, order_log, content, balance, team_doctrines)


func _run(
	setup: BattleSetup,
	order_log: Array,
	content: Dictionary,
	balance_in: Balance,
	team_doctrines: Array
) -> BattleResult:
	balance = balance_in
	_tie_salt = (setup.seed_value * 2246822519) & 0xFFFFFFFF
	rng = SimRNG.new(setup.seed_value)
	events = EventStream.new()
	field = build_field(setup, content)
	units = UnitBuilder.build_squads(setup, content, balance, field)
	_build_linkages(content)

	doctrines = []
	for team: int in 2:
		if team < team_doctrines.size() and team_doctrines[team] != null:
			doctrines.append(team_doctrines[team])
		else:
			doctrines.append(Doctrine.default_doctrine())

	_apply_condition(setup.condition_id, content)

	events.emit(0, SimEv.BATTLE_START, -1, -1, setup.seed_value, units.size(), setup.condition_id)

	var cycle_cap: int = balance.max_cycles
	if _cycle_limit >= 0:
		cycle_cap = mini(cycle_cap, _cycle_limit)

	while cycle < cycle_cap and not _battle_over():
		events.emit(tick, SimEv.CYCLE_START, -1, -1, cycle)
		_order_phase(order_log)

		var window_end: int = tick + balance.cycle_ticks
		while tick < window_end and not _battle_over():
			_advance_tick()
			tick += 1

		events.emit(tick, SimEv.CYCLE_END, -1, -1, cycle)
		cycle += 1

	return _finish()


# --- Setup -------------------------------------------------------------------

## Battlefield Conditions are global modifiers that make a squad right for one arena
## and wrong for another. They rotate every ranked season, which is what keeps a deep
## parts collection worth more than one maxed squad.
func _apply_condition(condition_id: String, content: Dictionary) -> void:
	if condition_id.is_empty():
		return
	var conditions: Dictionary = content.get("conditions", {})
	var cond: Dictionary = conditions.get(condition_id, {})
	if cond.is_empty():
		return
	var mods: Dictionary = cond.get("modifiers", {})
	var type_bonus: Dictionary = mods.get("damage_type_pct", {})

	for u: SimUnit in units:
		if mods.has("speed_pct"):
			u.speed = maxi(1, (u.speed * int(mods["speed_pct"])) / Balance.SCALE)
		if mods.has("heat_per_attack_pct"):
			u.heat_per_attack = (u.heat_per_attack * int(mods["heat_per_attack_pct"])) / Balance.SCALE
		if mods.has("vent_rate_add"):
			u.vent_rate = maxi(0, u.vent_rate + int(mods["vent_rate_add"]))
		if mods.has("armor_add"):
			u.armor = maxi(0, u.armor + int(mods["armor_add"]))
		# A flat percentage on a damage type is identical to scaling the unit's attack,
		# so it is baked in here rather than threaded through the damage resolver.
		var type_key: String = SimDefs.DMG_TYPE_NAMES[u.damage_type]
		if type_bonus.has(type_key):
			u.attack = maxi(0, (u.attack * int(type_bonus[type_key])) / Balance.SCALE)


## Static so the order panel, the 3D view and the headless tools can all build the
## same battlefield the simulation will build, without instantiating a sim.
static func build_field(setup: BattleSetup, content: Dictionary) -> Battlefield:
	var maps: Dictionary = content.get("maps", {})
	var tile_types: Array = content.get("tiles", [])
	var map_data: Dictionary = maps.get(setup.map_id, {})
	if map_data.is_empty() and not maps.is_empty():
		# Fall back to the first REAL map rather than failing the battle. Diagnostic
		# maps are excluded on purpose: sorted alphabetically `map_blank` came first,
		# so every battle that did not name a map was silently fought on a featureless
		# test plate -- including every balance run.
		# A map flagged `default` wins. Falling back alphabetically silently made the
		# cover-heavy Cooling Yard the arena every unmapped battle -- including every
		# balance run -- was fought on, which is not a decision anyone made.
		var keys: Array = []
		for id: Variant in maps.keys():
			var name: String = String(id)
			if bool((maps[id] as Dictionary).get("default", false)):
				map_data = maps[id]
				break
			if not name.begins_with("map_blank") and not name.begins_with("map_swapped"):
				keys.append(name)
		if map_data.is_empty():
			keys.sort()
			if keys.is_empty():
				keys = maps.keys()
				keys.sort()
			map_data = maps[keys[0]]
	if map_data.is_empty():
		map_data = {"id": "blank", "rows": ["............"], "deploy": {}}
	return Battlefield.from_data(map_data, tile_types)


func _build_linkages(content: Dictionary) -> void:
	_linkages = {}
	var list: Array = content.get("linkages", [])
	for entry: Variant in list:
		var link: Dictionary = entry as Dictionary
		var from_kind: int = SimDefs.action_kind(Doctrine.parse_action(String(link.get("from", ""))))
		var to_kind: int = SimDefs.action_kind(Doctrine.parse_action(String(link.get("to", ""))))
		if not _linkages.has(from_kind):
			_linkages[from_kind] = {}
		_linkages[from_kind][to_kind] = link


# --- Order Phase -------------------------------------------------------------

func _order_phase(order_log: Array) -> void:
	var orders: Dictionary = {}
	if cycle < order_log.size() and order_log[cycle] != null:
		orders = order_log[cycle] as Dictionary

	for u: SimUnit in units:
		if not u.alive:
			continue

		# An entry in the log is the player touching this unit. Everything else is
		# either a standing order carried over or a unit left on Auto -- which is why
		# a quiet cycle costs no taps at all.
		var source: int = ORDER_STANDING
		if orders.has(u.unit_ref):
			var raw: Variant = orders[u.unit_ref]
			if raw is String and String(raw) == "auto":
				u.on_auto = true
				u.standing_chain.clear()
			else:
				u.standing_chain = _coerce_chain(raw)
				u.on_auto = false
			source = ORDER_NEW

		var chain: Array[int]
		if u.on_auto:
			# The same path an async PvP defence squad takes: the owner's doctrine
			# plays the unit.
			chain = doctrines[u.team].decide(u, units, field)
			if source != ORDER_NEW:
				source = ORDER_AUTO
		else:
			chain = u.standing_chain

		u.begin_cycle(chain)
		events.emit(tick, SimEv.ORDERS_SET, u.unit_ref, -1, chain.size(), source, SimDefs.chain_name(chain))


## Orders arriving from JSON or the network may be ints or strings; both normalise to
## packed action codes here so the rest of the sim only ever sees ints.
func _coerce_chain(raw: Variant) -> Array[int]:
	var chain: Array[int] = []
	if raw is Array:
		for item: Variant in (raw as Array):
			if item is String:
				chain.append(Doctrine.parse_action(item as String))
			else:
				chain.append(int(item))
			if chain.size() >= SimDefs.CHAIN_MAX:
				break
	return chain


# --- Tick --------------------------------------------------------------------

func _advance_tick() -> void:
	_tick_states()
	_tick_seize()
	_tick_passive_heat()
	_tick_movement()
	_tick_actions()


## Constructs cross the map every tick according to their role and their orders. This
## runs before actions so a unit that closes into range this tick can fire this tick.
func _tick_movement() -> void:
	# Movement resolves on a coarser beat than combat. At 20 Hz nobody can perceive
	# the difference between stepping every tick and stepping every second tick with
	# a double-length stride, and the nearest-enemy scan plus integer square root per
	# unit per tick was costing more than the rest of the simulation combined.
	if balance.movement_interval > 1 and tick % balance.movement_interval != 0:
		return

	# Two phases, and the split is a fairness requirement rather than tidiness. Moving
	# each unit as it is computed means team A (built first) plans against team B's
	# stale positions while team B plans against A's updated ones -- a consistent edge
	# to one side in every engagement, invisible against random squads and decisive in
	# a mirror match.
	var deltas: Array[Array] = []
	for u: SimUnit in units:
		if not u.is_active():
			deltas.append([0, 0])
			continue
		var intent: int = MovementResolver.intent_for_action(_current_intent(u))
		var target: SimUnit = TargetResolver.preferred_target(units, u, balance)
		# Holding still to cash in a detonation beats shuffling into cover. Terrain
		# seeking cut cross-unit Synergy from 3.0 detonations a battle to 1.4 by walking
		# units out of range of the target they had just marked.
		#
		# This appends a zero delta rather than `continue`-ing: the two-phase loop keeps
		# one entry per unit and every later index is read positionally, so skipping the
		# append silently hands every subsequent construct somebody else's movement.
		if _has_detonation_ready(u):
			deltas.append([0, 0])
			continue
		deltas.append(MovementResolver.compute_step(
			u, target, intent, field, balance, balance.movement_interval, units))

	for index: int in units.size():
		var u: SimUnit = units[index]
		if not u.is_active():
			continue
		var delta: Array[int] = []
		delta.assign(deltas[index])
		if not MovementResolver.apply_step(u, delta, field):
			continue

		# Positions are reported periodically rather than every tick. At 20 Hz with
		# twelve constructs, per-tick reporting would triple the event stream that
		# has to be submitted for server verification, for motion the eye cannot
		# resolve anyway.
		var moved: int = SimMath.distance(u.last_reported_x, u.last_reported_z, u.pos_x, u.pos_z)
		if moved >= balance.move_report_distance:
			u.last_reported_x = u.pos_x
			u.last_reported_z = u.pos_z
			events.emit(tick, SimEv.MOVED, u.unit_ref, -1, u.pos_x, u.pos_z, field.tile_id_at(u.pos_x, u.pos_z))


## The action a unit is about to take, without consuming it -- movement needs to know
## the intent before the action fires.
## True when this construct is carrying a detonator and something in reach is already
## marked for it. Such a unit should stand still and fire.
func _has_detonation_ready(u: SimUnit) -> bool:
	for index: int in u.abilities.size():
		var ability: Dictionary = u.ability_at(index)
		if ability.is_empty():
			continue
		var detonates: String = String(ability.get("detonates", ""))
		if detonates.is_empty():
			continue
		var state: int = SimDefs.state_id(detonates)
		if state >= 0 and TargetResolver.target_with_state(units, u, field, balance, state) != null:
			return true
	return false


func _current_intent(u: SimUnit) -> int:
	if u.chain_index < u.chain.size():
		return SimDefs.action_kind(u.chain[u.chain_index])
	return SimDefs.ACT_ATTACK


func _tick_states() -> void:
	for u: SimUnit in units:
		if not u.alive:
			continue
		for state: int in SimDefs.STATE_COUNT:
			if u.states[state] <= 0:
				continue
			u.states[state] -= 1
			if u.states[state] == 0:
				events.emit(tick, SimEv.STATE_EXPIRED, -1, u.unit_ref, state, 0, SimDefs.state_name(state))


func _tick_seize() -> void:
	for u: SimUnit in units:
		if u.alive and u.seize_ticks > 0:
			u.seize_ticks -= 1


func _tick_passive_heat() -> void:
	if balance.passive_vent_interval <= 0:
		return
	if tick % balance.passive_vent_interval != 0:
		return
	for u: SimUnit in units:
		if not u.alive:
			continue
		# Slag radiates. Standing in it is a slow cook, which is what stops the
		# shortest path across the map from always being the right one.
		var terrain_heat: int = field.heat_at(u.pos_x, u.pos_z)
		if terrain_heat > 0:
			HeatResolver.add(u, terrain_heat, balance, events, tick)
		HeatResolver.passive_bleed(u, events, tick)


## Within a single tick, units act fastest-first rather than in build order.
##
## Build order looked harmless and was not: it handed team A a free first strike on
## every tick where both sides came up together, and it made setup-then-payoff
## impossible in one tick, because a back-row Spotter (slot 4) always moved after the
## front rank had already spent its attacks. Sorting by speed fixes both and makes
## Speed matter twice -- how often you act, and whether you act first.
func _tick_actions() -> void:
	var ready: Array[SimUnit] = []
	for u: SimUnit in units:
		if not u.is_active():
			continue
		if u.attack_timer > 0:
			u.attack_timer -= 1
		else:
			ready.append(u)

	if ready.is_empty():
		return
	if ready.size() > 1:
		ready.sort_custom(_faster_first)

	for u: SimUnit in ready:
		# An earlier action this tick may have destroyed or seized this unit.
		if not u.is_active():
			continue
		_perform_next_action(u)
		if _battle_over():
			return


## A total order, never a partial one. `sort_custom` gives no stability guarantee, so
## the ordering has to be fully determined by the comparator itself.
##
## The tiebreak rotates with the tick, and that matters more than it looks. Breaking
## ties on unit_ref alone let team A act first every time two units had equal speed --
## invisible against random squads, but a guaranteed first-strike advantage in a
## mirror match, which is exactly what competitive PvP produces.
func _faster_first(a: SimUnit, b: SimUnit) -> bool:
	var speed_a: int = DamageResolver.effective_speed(a, balance)
	var speed_b: int = DamageResolver.effective_speed(b, balance)
	if speed_a != speed_b:
		return speed_a > speed_b
	var key_a: int = _tie_key(a)
	var key_b: int = _tie_key(b)
	if key_a != key_b:
		return key_a < key_b
	# unit_ref is unique, so this guarantees a strict total order.
	return a.unit_ref < b.unit_ref


## Deterministic per-battle, per-tick shuffle key.
##
## The salt is essential and its absence was a real bias. Keyed only on unit_ref and
## tick, the tie-break pattern was identical in every battle ever simulated -- so when
## two mirrored units could kill each other on the same tick, the same side won that
## exchange every time, in every match. Measured over 800 mirror matchups that was a
## 37/63 split. Folding the seed in makes the pattern vary per battle while staying
## perfectly reproducible for a given one.
func _tie_key(u: SimUnit) -> int:
	# A full avalanche mix, not a single multiply. The earlier version multiplied
	# unit_ref by a constant and masked to 16 bits, which is not a hash: the products
	# clustered, and team B's refs (10-15) landed systematically lower than team A's
	# (0-5). Lower key acts first, so team B won simultaneous exchanges throughout
	# every battle -- a 38/61 split across 400 mirror matchups. Salting could not fix
	# it, because adding a constant to a clustered distribution leaves it clustered.
	var x: int = ((u.unit_ref + 1) * 2654435761 + tick * 40503 + _tie_salt) & 0xFFFFFFFF
	x = ((x ^ (x >> 16)) * 0x85EBCA6B) & 0xFFFFFFFF
	x = ((x ^ (x >> 13)) * 0xC2B2AE35) & 0xFFFFFFFF
	return (x ^ (x >> 16)) & 0xFFFFFFFF


func _perform_next_action(u: SimUnit) -> void:
	var code: int
	if u.chain_index < u.chain.size():
		code = u.chain[u.chain_index]
		u.chain_index += 1
	else:
		# A finished chain does not mean a passive unit. Once its orders run out a
		# construct keeps swinging until the next Order Phase -- that is the Rivals
		# at War feel: you set intent, they keep fighting.
		code = SimDefs.action(SimDefs.ACT_ATTACK)

	var kind: int = SimDefs.action_kind(code)
	var arg: int = SimDefs.action_arg(code)
	events.emit(tick, SimEv.ACTION_BEGIN, u.unit_ref, -1, kind, arg, SimDefs.action_name(code))

	_resolve_linkage(u, kind)

	match kind:
		SimDefs.ACT_ATTACK:
			_do_attack(u)
		SimDefs.ACT_ABILITY:
			_do_ability(u, arg)
		SimDefs.ACT_BRACE:
			_do_brace(u)
		SimDefs.ACT_VENT:
			_do_vent(u)
		SimDefs.ACT_FALL_BACK:
			_do_fall_back(u)
		SimDefs.ACT_ADVANCE:
			_do_advance(u)
		_:
			_schedule(u, balance.base_attack_ticks)

	u.last_action_kind = kind
	_free_heat = false
	_linked_power = Balance.SCALE


## Linkage: ordering two specific actions back to back on the same unit pays off.
## Which linkages a construct can form depends on the abilities its parts grant, so
## combo access is a collection reward rather than a universal button.
func _resolve_linkage(u: SimUnit, kind: int) -> void:
	_free_heat = false
	_linked_power = Balance.SCALE
	if not _linkages.has(u.last_action_kind):
		return
	var by_next: Dictionary = _linkages[u.last_action_kind]
	if not by_next.has(kind):
		return

	var link: Dictionary = by_next[kind]
	var effect: String = String(link.get("effect", ""))
	var value: int = int(link.get("value", 0))
	match effect:
		"free_heat":
			_free_heat = true
		"damage_pct":
			_linked_power = value
	events.emit(tick, SimEv.LINKAGE, u.unit_ref, -1, value, 0, String(link.get("id", effect)))


# --- Actions -----------------------------------------------------------------

func _do_attack(u: SimUnit) -> void:
	var target: SimUnit = TargetResolver.target_in_range(units, u, field, balance)
	if target == null:
		# Nothing in reach. The unit keeps closing (movement already ran this tick)
		# and tries again shortly, rather than burning its whole cycle standing still.
		var closest: SimUnit = TargetResolver.nearest_enemy(units, u)
		if closest == null:
			events.emit(tick, SimEv.NO_TARGET, u.unit_ref)
		else:
			events.emit(tick, SimEv.OUT_OF_RANGE, u.unit_ref, closest.unit_ref,
				SimMath.distance(u.pos_x, u.pos_z, closest.pos_x, closest.pos_z))
		_schedule(u, balance.reposition_ticks)
		return

	var overdrive: bool = u.overdrive_charged
	var cover: int = field.cover_at(target.pos_x, target.pos_z)
	var dmg: int = DamageResolver.compute(
		u, target, _linked_power, balance, overdrive, cover, rng,
		_is_charging(target, u), _is_guarded(target))
	if overdrive:
		u.overdrive_charged = false

	events.emit(
		tick, SimEv.ATTACK, u.unit_ref, target.unit_ref,
		u.damage_type, DamageResolver.matchup_percent(u, target, balance),
		SimDefs.DMG_TYPE_NAMES[u.damage_type]
	)
	_apply_damage(u, target, dmg)
	_add_heat(u, u.heat_per_attack)
	_schedule(u, DamageResolver.attack_interval(u, balance))


func _do_ability(u: SimUnit, index: int) -> void:
	var ability: Dictionary = u.ability_at(index)
	# Ordering an ability this construct's parts do not grant degrades to a plain
	# attack. A stale standing order must never stall a unit or desync a battle.
	if ability.is_empty():
		_do_attack(u)
		return

	var targets_self: bool = String(ability.get("target", "enemy")) == "self"
	var detonates: String = String(ability.get("detonates", ""))
	var target: SimUnit
	if targets_self:
		target = u
	elif String(ability.get("reach", "front")) == "any":
		# Reaches across the whole map, ignoring whatever brawl is in the way.
		target = TargetResolver.weakest_enemy(units, u)
	else:
		target = TargetResolver.target_in_range(units, u, field, balance)

	# A detonator aims at whatever is actually MARKED, not merely the nearest enemy.
	# Without this, one construct applies Exposed and the construct meant to cash it in
	# shoots someone else -- which measured as cross-unit Synergy firing about once every
	# five battles, for the deepest mechanic in the design.
	if not detonates.is_empty() and not targets_self:
		var wanted_state: int = SimDefs.state_id(detonates)
		if wanted_state >= 0:
			var marked: SimUnit = TargetResolver.target_with_state(units, u, field, balance, wanted_state)
			if marked != null:
				target = marked

	if target == null:
		var closest: SimUnit = TargetResolver.nearest_enemy(units, u)
		if closest == null:
			events.emit(tick, SimEv.NO_TARGET, u.unit_ref)
		else:
			events.emit(tick, SimEv.OUT_OF_RANGE, u.unit_ref, closest.unit_ref,
				SimMath.distance(u.pos_x, u.pos_z, closest.pos_x, closest.pos_z))
		_schedule(u, balance.reposition_ticks)
		return

	var power: int = int(ability.get("power", Balance.SCALE))
	power = (power * _linked_power) / Balance.SCALE

	# Synergy: one unit applies a State, another cashes it in. The detonation is
	# resolved before the damage so the log reads in causal order and the
	# presentation layer can play the burst before the hit lands.
	if not detonates.is_empty():
		var sid: int = SimDefs.state_id(detonates)
		if sid >= 0 and target.has_state(sid):
			target.clear_state(sid)
			power = (power * balance.detonation_bonus) / Balance.SCALE
			events.emit(tick, SimEv.DETONATION, u.unit_ref, target.unit_ref, balance.detonation_bonus, 0, detonates)

	if power > 0 and not targets_self:
		var overdrive: bool = u.overdrive_charged
		var cover: int = field.cover_at(target.pos_x, target.pos_z)
		var dmg: int = DamageResolver.compute(
			u, target, power, balance, overdrive, cover, rng,
			_is_charging(target, u), _is_guarded(target))
		if overdrive:
			u.overdrive_charged = false
		events.emit(
			tick, SimEv.ATTACK, u.unit_ref, target.unit_ref,
			u.damage_type, DamageResolver.matchup_percent(u, target, balance),
			String(ability.get("id", "ability"))
		)
		_apply_damage(u, target, dmg)

	var heal: int = int(ability.get("heal", 0))
	if heal > 0:
		target.hp = mini(target.hp_max, target.hp + heal)
		events.emit(tick, SimEv.HEAL, u.unit_ref, target.unit_ref, heal, target.hp)

	var applies: String = String(ability.get("applies", ""))
	if not applies.is_empty() and target.alive:
		var applied_state: int = SimDefs.state_id(applies)
		if applied_state >= 0:
			var duration: int = int(ability.get("state_ticks", balance.cycle_ticks / 2))
			target.apply_state(applied_state, duration)
			events.emit(tick, SimEv.STATE_APPLIED, u.unit_ref, target.unit_ref, duration, applied_state, applies)

	_add_heat(u, int(ability.get("heat", u.heat_per_attack)))
	_schedule(u, int(ability.get("cast_ticks", balance.base_attack_ticks)))


func _do_brace(u: SimUnit) -> void:
	u.brace_pct = balance.brace_reduction
	events.emit(tick, SimEv.BRACE, u.unit_ref, -1, u.brace_pct)
	_schedule(u, balance.brace_ticks)


func _do_vent(u: SimUnit) -> void:
	HeatResolver.vent(u, balance, events, tick)
	_schedule(u, balance.vent_ticks)


## Withdraw toward the deployment anchor. The retreat itself happens in the movement
## tick; this order sets the intent and buys a short breather.
func _do_fall_back(u: SimUnit) -> void:
	events.emit(tick, SimEv.FALL_BACK, u.unit_ref, -1, u.pos_x, u.pos_z)
	_schedule(u, balance.fall_back_ticks)


## Push into contact regardless of what this construct's arms would prefer. Costly
## for a marksman, decisive for a brawler.
func _do_advance(u: SimUnit) -> void:
	var target: SimUnit = TargetResolver.target_in_range(units, u, field, balance)
	if target != null:
		_do_attack(u)
		return
	events.emit(tick, SimEv.MOVED, u.unit_ref, -1, u.pos_x, u.pos_z, "advance")
	_schedule(u, balance.reposition_ticks)


# --- Helpers -----------------------------------------------------------------

## True while a brawler is still crossing the ground to reach its own weapon range.
func _is_charging(target: SimUnit, attacker: SimUnit) -> bool:
	if target.role != SimDefs.ROLE_BRAWLER:
		return false
	return SimMath.distance(attacker.pos_x, attacker.pos_z, target.pos_x, target.pos_z) > target.weapon_range


## True while any of a unit's listed guards is still standing. Visiting `units` in its
## fixed order keeps this identical on every machine, which matters because it feeds a
## damage number.
func _is_guarded(target: SimUnit) -> bool:
	if target.guarded_reduction <= 0 or target.guard_refs.is_empty():
		return false
	for u: SimUnit in units:
		if u.alive and target.guard_refs.has(u.unit_ref):
			return true
	return false


func _apply_damage(source: SimUnit, target: SimUnit, amount: int) -> void:
	target.take_damage(amount)
	_damage_dealt[source.team] += amount
	events.emit(tick, SimEv.DAMAGE, source.unit_ref, target.unit_ref, amount, target.hp)
	if not target.alive:
		events.emit(tick, SimEv.DESTROYED, source.unit_ref, target.unit_ref)


func _add_heat(u: SimUnit, amount: int) -> void:
	if _free_heat:
		return
	HeatResolver.add(u, amount, balance, events, tick)


## Schedules a unit's next action. The -1 makes the gap exactly `ticks`, because the
## acting tick itself counts toward the interval.
func _schedule(u: SimUnit, ticks: int) -> void:
	u.attack_timer = maxi(0, ticks - 1)


func _battle_over() -> bool:
	if _vital_lost(SimDefs.TEAM_A) or _vital_lost(SimDefs.TEAM_B):
		return true
	return not TargetResolver.any_alive(units, SimDefs.TEAM_A) \
		or not TargetResolver.any_alive(units, SimDefs.TEAM_B)


## A colossus dies when its core dies, not when the last piece of it stops moving. Any
## unit may be marked vital; ordinary squads have none, so this is false for them.
func _vital_lost(team: int) -> bool:
	for u: SimUnit in units:
		if u.team == team and u.is_vital and not u.alive:
			return true
	return false


func _finish() -> BattleResult:
	var a_alive: int = TargetResolver.count_alive(units, SimDefs.TEAM_A)
	var b_alive: int = TargetResolver.count_alive(units, SimDefs.TEAM_B)

	# A destroyed core loses the battle for its team even with limbs still standing --
	# checked before the survivor counts, which would otherwise hand the colossus a win
	# on points while its core lay in pieces.
	var a_vital_lost: bool = _vital_lost(SimDefs.TEAM_A)
	var b_vital_lost: bool = _vital_lost(SimDefs.TEAM_B)

	var winner: int = BattleResult.WINNER_DRAW
	if b_vital_lost and not a_vital_lost:
		winner = SimDefs.TEAM_A
	elif a_vital_lost and not b_vital_lost:
		winner = SimDefs.TEAM_B
	elif a_alive > 0 and b_alive == 0:
		winner = SimDefs.TEAM_A
	elif b_alive > 0 and a_alive == 0:
		winner = SimDefs.TEAM_B
	elif a_alive > 0 and b_alive > 0:
		# Time ran out. Whoever has more of their squad standing takes it; a true tie
		# on survivors falls through to total damage, and only then to a draw.
		if a_alive != b_alive:
			winner = SimDefs.TEAM_A if a_alive > b_alive else SimDefs.TEAM_B
		elif _damage_dealt[0] != _damage_dealt[1]:
			winner = SimDefs.TEAM_A if _damage_dealt[0] > _damage_dealt[1] else SimDefs.TEAM_B

	# Only a genuinely finished battle gets a BATTLE_END. When interactive play stops
	# early at a cycle limit, emitting one would break prefix stability: the next
	# re-simulation would have to retract an event the presentation layer already
	# played.
	var concluded: bool = _battle_over() or cycle >= balance.max_cycles
	if concluded:
		events.emit(tick, SimEv.BATTLE_END, -1, -1, winner, cycle)
	else:
		winner = BattleResult.WINNER_DRAW

	var result := BattleResult.new()
	result.concluded = concluded
	result.winner = winner
	result.cycles = cycle
	result.ticks = tick
	result.events = events
	result.rng_draws = rng.draws
	# Element-wise, because assigning an untyped literal to a typed Array[int] is a
	# runtime error in GDScript.
	result.survivors[0] = a_alive
	result.survivors[1] = b_alive
	result.damage_dealt[0] = _damage_dealt[0]
	result.damage_dealt[1] = _damage_dealt[1]
	for u: SimUnit in units:
		result.final_units.append(u.snapshot())
	return result
