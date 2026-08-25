extends SceneTree

## Mirror-symmetry probe.
##
## On a symmetric map with identical squads, team B's state should be the exact mirror
## of team A's: same lateral position, same distance from its own baseline. Any drift
## is a directional bias in the simulation -- and a directional bias means one side of
## every competitive PvP match is playing a different game.
##
##   godot --headless --path . --script res://tools/verify_symmetry.gd

const FIXTURE: String = "res://tools/fixtures/battle_mirror.json"


func _initialize() -> void:
	var db: ContentDB = ContentDB.load_all()
	var json := JSON.new()
	json.parse(FileAccess.get_file_as_string(FIXTURE))
	var setup: BattleSetup = BattleSetup.from_dict(json.data as Dictionary)
	setup.seed_value = 4242
	var content: Dictionary = db.to_sim_content()

	# Variance off: any drift left is structural, not luck.
	db.balance.damage_variance_pct = 0

	print("")
	print("=== when does mirror symmetry break? (damage variance disabled) ===")
	print("  %6s %10s %10s %10s" % ["cycles", "hp A", "hp B", "pos drift"])
	for limit: int in range(1, 7):
		var probe := BattleSim.new()
		probe._cycle_limit = limit
		probe._run(setup, [], content, db.balance, [])
		var d: int = 0
		for slot: int in SimDefs.SQUAD_SIZE:
			var pa: SimUnit = _find(probe.units, SimDefs.TEAM_A, slot)
			var pb: SimUnit = _find(probe.units, SimDefs.TEAM_B, slot)
			if pa == null or pb == null:
				continue
			d += absi(pa.pos_z - (probe.field.max_z() - pb.pos_z)) + absi(pa.pos_x - pb.pos_x)
		print("  %6d %10d %10d %10d" % [limit, _hp(probe.units, SimDefs.TEAM_A), _hp(probe.units, SimDefs.TEAM_B), d])

	var sim := BattleSim.new()
	sim._cycle_limit = 3
	sim._run(setup, [], content, db.balance, [])

	var field: Battlefield = sim.field
	var depth: int = field.max_z()

	print("")
	print("=== mirror symmetry after 3 cycles ===")
	print("  a unit's 'advance' is its distance from its own baseline; the two teams")
	print("  should match slot for slot.")
	print("")
	print("  %-5s %8s %8s   %-5s %8s %8s   %s" % ["A", "x", "advance", "B", "x", "advance", "drift"])

	var total_drift: int = 0
	for slot: int in SimDefs.SQUAD_SIZE:
		var a: SimUnit = _find(sim.units, SimDefs.TEAM_A, slot)
		var b: SimUnit = _find(sim.units, SimDefs.TEAM_B, slot)
		if a == null or b == null:
			continue
		# Team A advances up the z axis from 0; team B advances down from max.
		var a_advance: int = a.pos_z
		var b_advance: int = depth - b.pos_z
		var drift: int = absi(a_advance - b_advance) + absi(a.pos_x - b.pos_x)
		total_drift += drift
		print("  %-5s %8d %8d   %-5s %8d %8d   %d" % [
			SimEv.ref_name(a.unit_ref), a.pos_x, a_advance,
			SimEv.ref_name(b.unit_ref), b.pos_x, b_advance, drift])

	print("")
	print("  total drift: %d sim units  (%d hp lost: A %d / B %d)" % [
		total_drift, 0, _hp(sim.units, SimDefs.TEAM_A), _hp(sim.units, SimDefs.TEAM_B)])

	# Reported, never asserted. A single mirror battle is ONE deterministic scenario,
	# not a sample: with damage variance this small, re-running it with a different
	# seed reproduces almost the same fight. Treating it as a pass/fail fairness test
	# sent this project chasing three wrong hypotheses.
	#
	# The authoritative bias test is many DIFFERENT mirror matchups:
	#   balance_sim.gd -- --battles 2400 --mirror
	# which should land inside 48-52%.
	print("")
	print("  Diagnostic only -- this is one battle, not a sample.")
	print("  For a real fairness verdict run: balance_sim.gd -- --battles 2400 --mirror")
	print("")
	quit(0)


func _find(units: Array[SimUnit], team: int, slot: int) -> SimUnit:
	for u: SimUnit in units:
		if u.team == team and u.unit_ref == SimDefs.unit_ref(team, slot):
			return u
	return null


func _hp(units: Array[SimUnit], team: int) -> int:
	var total: int = 0
	for u: SimUnit in units:
		if u.team == team:
			total += u.hp
	return total
