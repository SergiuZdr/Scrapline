class_name HeatResolver
extends RefCounted

## Heat is the risk dial. Acting builds it; filling the bar is either the best or the
## worst thing that can happen to a unit, depending on whether its module can vent
## the surge. That fork is what makes an aggressive chain a gamble rather than a
## strictly correct choice.


static func add(unit: SimUnit, amount: int, balance: Balance, events: EventStream, tick: int) -> void:
	if amount == 0:
		return
	var gain: int = amount
	if unit.has_state(SimDefs.STATE_OVERHEATED):
		gain = (gain * balance.overheated_heat_gain) / Balance.SCALE

	var before: int = unit.heat
	unit.add_heat(gain)
	if unit.heat != before:
		events.emit(tick, SimEv.HEAT_CHANGED, unit.unit_ref, -1, unit.heat, unit.heat_max)

	if unit.heat >= unit.heat_max:
		_resolve_threshold(unit, balance, events, tick)


## Deliberate venting: the player spent an action to avoid the threshold.
static func vent(unit: SimUnit, balance: Balance, events: EventStream, tick: int) -> void:
	var before: int = unit.heat
	unit.heat = maxi(0, unit.heat - balance.vent_amount)
	events.emit(tick, SimEv.VENT, unit.unit_ref, -1, before - unit.heat, unit.heat)


## Free heat bleed-off that runs on a timer regardless of orders, so a unit that
## simply attacks at a sane pace never seizes.
static func passive_bleed(unit: SimUnit, events: EventStream, tick: int) -> void:
	if unit.vent_rate <= 0 or unit.heat <= 0:
		return
	var before: int = unit.heat
	unit.heat = maxi(0, unit.heat - unit.vent_rate)
	if unit.heat != before:
		events.emit(tick, SimEv.HEAT_CHANGED, unit.unit_ref, -1, unit.heat, unit.heat_max)


static func _resolve_threshold(unit: SimUnit, balance: Balance, events: EventStream, tick: int) -> void:
	if unit.can_overdrive:
		# The payoff: a module that can dump the surge converts it into one amplified
		# strike instead of downtime.
		unit.overdrive_charged = true
		unit.heat = 0
		events.emit(tick, SimEv.OVERDRIVE, unit.unit_ref, -1, balance.overdrive_multiplier)
		events.emit(tick, SimEv.HEAT_CHANGED, unit.unit_ref, -1, unit.heat, unit.heat_max)
	else:
		# The punishment: the unit cooks itself and loses most of a cycle.
		unit.seize_ticks = balance.seize_ticks
		unit.heat = balance.seize_heat_after
		unit.chain_index = unit.chain.size()  # a seized unit's queued chain is lost
		events.emit(tick, SimEv.SEIZE, unit.unit_ref, -1, balance.seize_ticks)
		events.emit(tick, SimEv.HEAT_CHANGED, unit.unit_ref, -1, unit.heat, unit.heat_max)
