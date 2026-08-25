extends SceneTree

## Proves the claim the interactive battle rests on.
##
## BattleController plays a battle one cycle at a time, re-simulating from tick 0
## after every Order Phase and handing the presentation layer only the events it has
## not shown yet. That is only sound if the event stream is PREFIX-STABLE: adding
## orders for cycle N+1 must never change a single event from cycles 0..N. If it can,
## the 3D view would have to retract animations it already played, and -- far worse --
## the server's re-simulation could disagree with an honest client.
##
## So this test plays a battle incrementally, concatenates every batch of new events
## it was handed, and asserts the result is byte-identical to simulating the whole
## battle in one shot with the same order log.
##
##   godot --headless --path . --script res://tools/verify_interactive.gd

const FIXTURE_PATH: String = "res://tools/fixtures/battle_01.json"


func _initialize() -> void:
	var db: ContentDB = ContentDB.load_all()
	if not db.errors.is_empty():
		for e: String in db.errors:
			printerr("content: ", e)
		quit(1)
		return

	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string(FIXTURE_PATH))
	var setup: BattleSetup = BattleSetup.from_dict(json.data as Dictionary)
	var content: Dictionary = db.to_sim_content()

	var failures: int = 0
	print("")
	print("=== interactive playback verification ===")

	for trial: int in 8:
		setup.seed_value = 4000 + trial
		failures += _run_trial(setup, content, db, trial)

	print("")
	if failures > 0:
		printerr("FAILED: %d of 8 trials diverged" % failures)
		quit(1)
		return
	print("  8/8 trials: incremental playback matches one-shot simulation exactly.")
	print("")
	quit(0)


func _run_trial(setup: BattleSetup, content: Dictionary, db: ContentDB, trial: int) -> int:
	var controller := BattleController.new()
	var collected: Array = []
	controller.cycle_resolved.connect(func(new_events: Array) -> void:
		collected.append_array(new_events))
	controller.start(setup, content, db.balance)

	# A scripted stand-in for a player: orders on some cycles, silence on others so
	# standing orders and Auto both get exercised.
	var guard: int = 0
	while not controller.is_finished() and guard < db.balance.max_cycles + 2:
		controller.commit_cycle(_orders_for_cycle(controller.cycle, trial))
		guard += 1

	# The same order log, simulated in one go.
	var one_shot: BattleResult = BattleSim.simulate(setup, controller.order_log, content, db.balance)

	var incremental_hash: int = _hash_of(collected)
	var one_shot_hash: int = one_shot.events.stream_hash()
	var ok: bool = incremental_hash == one_shot_hash and collected.size() == one_shot.events.size()

	print("  trial %d  seed %-5d cycles %-3d events %-5d incremental %08x  one-shot %08x  %s" % [
		trial, setup.seed_value, one_shot.cycles, one_shot.events.size(),
		incremental_hash, one_shot_hash, "ok" if ok else "DIVERGED"])

	if not ok and collected.size() != one_shot.events.size():
		printerr("    event count differs: incremental %d vs one-shot %d" % [
			collected.size(), one_shot.events.size()])
	return 0 if ok else 1


func _orders_for_cycle(cycle: int, trial: int) -> Dictionary:
	match (cycle + trial) % 4:
		0:
			return {0: ["brace", "attack"], 4: ["ability:0", "attack"]}
		1:
			return {1: ["ability:0", "ability:1"], 2: ["vent", "ability:0"]}
		2:
			return {}  # nobody touched: standing orders and Auto carry the cycle
		_:
			return {3: "auto", 5: ["ability:0", "attack", "attack"]}


## Rebuilds a stream from the collected batches and hashes it the same way the
## simulation does, so the two numbers are directly comparable.
func _hash_of(events: Array) -> int:
	var stream := EventStream.new()
	for e: Variant in events:
		stream.events.append(e as Array)
	return stream.stream_hash()
