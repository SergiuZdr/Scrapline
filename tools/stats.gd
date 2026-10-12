extends SceneTree

## How sure a bot number is (071). A win rate from 45 runs is a range, not a number: 62% is
## "somewhere from 48 to 75". These helpers put that range on every rate the bot tools print, and
## judge a difference between two variants against its own noise.
##
##   const Stats = preload("res://tools/stats.gd")
##   godot --headless --path . --script res://tools/stats.gd -- --self-check
##
## 95% intervals throughout. Floats are fine here: this is a tool, not the sim.

const Z: float = 1.96


## Wilson score interval for `k` successes in `n`, as [low, high] in 0..1. Unlike the textbook
## p +- z*se it never leaves 0..1 and stays honest at 0% or 100% (a fight won 5 of 5 is 57-100%).
static func wilson(k: int, n: int, z: float = Z) -> Array:
	if n <= 0:
		return [0.0, 1.0]
	var p: float = float(k) / n
	var denom: float = 1.0 + z * z / n
	var centre: float = (p + z * z / (2.0 * n)) / denom
	var half: float = z * sqrt(p * (1.0 - p) / n + z * z / (4.0 * n * n)) / denom
	return [maxf(0.0, centre - half), minf(1.0, centre + half)]


## "62.2% (48-75)": a rate in percent with its interval.
static func rate(k: int, n: int) -> String:
	var ci: Array = wilson(k, n)
	return "%.1f%% (%.0f-%.0f)" % [100.0 * k / maxi(1, n), 100.0 * ci[0], 100.0 * ci[1]]


## Mean and half-width of the interval for a mean, from the sum and the sum of squares.
static func mean_ci(total: float, squares: float, n: int) -> Array:
	if n <= 0:
		return [0.0, 0.0]
	var mean: float = total / n
	if n < 2:
		return [mean, 0.0]
	var variance: float = maxf(0.0, (squares - total * total / n) / (n - 1))
	return [mean, Z * sqrt(variance / n)]


## "13.7 +-0.6"
static func mean_text(total: float, squares: float, n: int) -> String:
	var m: Array = mean_ci(total, squares, n)
	return "%.1f +-%.1f" % [m[0], m[1]]


## B - A for two variants played on the SAME seeds: `only_b` seeds B won and A lost, `only_a` the
## reverse, of `n` pairs. Pairing cancels the luck of the draw, so it needs far fewer runs than two
## separate batches. Returns [difference, low, high] in -1..1.
static func paired(only_b: int, only_a: int, n: int) -> Array:
	if n <= 0:
		return [0.0, -1.0, 1.0]
	var d: float = float(only_b - only_a) / n
	var variance: float = (only_b + only_a - float(only_b - only_a) * (only_b - only_a) / n) / (float(n) * n)
	var half: float = Z * sqrt(maxf(0.0, variance))
	# With few disagreeing seeds the normal approximation is too sure of itself: never claim a
	# difference narrower than one disagreeing seed either way.
	if only_a + only_b > 0:
		half = maxf(half, 1.0 / n)
	return [d, d - half, d + half]


## Difference of two independent rates, k1/n1 - k2/n2, as [difference, low, high] -- Newcombe's
## interval from the two Wilson intervals. The textbook one (p1 - p2 +- z*se) collapses when a rate
## is 0% or 100% and called a 100%-vs-97% arm "real" on its first try (071).
static func unpaired(k1: int, n1: int, k2: int, n2: int, z: float = Z) -> Array:
	if n1 <= 0 or n2 <= 0:
		return [0.0, -1.0, 1.0]
	var p1: float = float(k1) / n1
	var p2: float = float(k2) / n2
	var w1: Array = wilson(k1, n1, z)
	var w2: Array = wilson(k2, n2, z)
	var d: float = p1 - p2
	return [d, d - sqrt(pow(p1 - w1[0], 2) + pow(w2[1] - p2, 2)), d + sqrt(pow(w1[1] - p1, 2) + pow(p2 - w2[0], 2))]


## The z for `tests` comparisons made at once, so that all of them together are wrong no more than
## one time in twenty (Bonferroni). Ten arms judged at 95% each flag one by chance about 40% of the
## time; at `z_for(10)` (2.81) about 5%. Abramowitz & Stegun 26.2.23, good to 0.0005.
static func z_for(tests: int) -> float:
	var p: float = 0.025 / maxi(1, tests)
	var t: float = sqrt(-2.0 * log(p))
	return t - (2.515517 + 0.802853 * t + 0.010328 * t * t) / (1.0 + 1.432788 * t + 0.189269 * t * t + 0.001308 * t * t * t)


## Whether an interval [d, low, high] leaves zero out.
static func is_real(d: Array) -> bool:
	return d[1] > 0.0 or d[2] < 0.0


## A difference in points with its verdict: real when the interval leaves zero out.
static func verdict(d: Array, unit: String = "points") -> String:
	var text: String = "%+.1f %s (95%%: %+.1f to %+.1f)" % [100.0 * d[0], unit, 100.0 * d[1], 100.0 * d[2]]
	if is_zero_approx(d[0]) and is_zero_approx(d[1]) and is_zero_approx(d[2]):
		return text + " -- no difference at all"
	if is_real(d):
		return text + " -- real"
	return text + " -- no detectable difference (it could be up to %.0f %s either way)" % [
		100.0 * maxf(absf(d[1]), absf(d[2])), unit]


## How many runs it takes to know a rate near `p` to within +-`half` (both 0..1).
static func runs_needed(p: float, half: float) -> int:
	return ceili(Z * Z * maxf(p * (1.0 - p), 0.01) / (half * half))


## `path=json` into run.json; `combat.path=json` into the combat rules (enemy kinds included);
## `fight.<id>.path=json` into one fight map (014). The one parser behind every tool's `--set`/`--b`.
static func override(db: ContentDB, setting: String, quiet: bool = false) -> void:
	var pair: PackedStringArray = setting.split("=", true, 1)
	var keys: PackedStringArray = pair[0].split(".")
	var node: Dictionary = db.run_rules
	var first: int = 0
	if keys[0] == "combat":
		node = db.combat_rules
		first = 1
	elif keys[0] == "fight":
		node = db.fights[keys[1]]
		first = 2
	for k: int in range(first, keys.size() - 1):
		node = node[keys[k]]
	var last: String = keys[keys.size() - 1]
	if not node.has(last):
		push_error("override %s: no such number (a typo would change nothing)" % pair[0])
	node[last] = JSON.parse_string(pair[1])
	if not quiet:
		print("  override %s = %s" % [pair[0], pair[1]])


## Every value following `flag` in `args`.
static func all_after(args: PackedStringArray, flag: String) -> PackedStringArray:
	var out: PackedStringArray = []
	for i: int in args.size() - 1:
		if args[i] == flag:
			out.append(args[i + 1])
	return out


func _initialize() -> void:
	var ok: bool = true
	var w: Array = wilson(7, 10)
	ok = _expect("wilson 7/10", w[0], 0.3968, 0.001) and ok
	ok = _expect("wilson 7/10 high", w[1], 0.8922, 0.001) and ok
	ok = _expect("wilson 5/5 low", wilson(5, 5)[0], 0.5655, 0.001) and ok
	ok = _expect("wilson 0/20 high", wilson(0, 20)[1], 0.1611, 0.001) and ok
	var m: Array = mean_ci(15.0, 55.0, 5)   # 1..5: mean 3, sd 1.581
	ok = _expect("mean of 1..5", m[0], 3.0, 0.0001) and ok
	ok = _expect("its half-width", m[1], 1.96 * 1.5811 / sqrt(5.0), 0.001) and ok
	var p: Array = paired(10, 2, 100)
	ok = _expect("paired difference", p[0], 0.08, 0.0001) and ok
	ok = _expect("paired low", p[1], 0.08 - 1.96 * sqrt((12 - 0.64) / 10000.0), 0.0001) and ok
	# Newcombe (1998), example: 56/70 against 48/80 -> 0.2, 95% 0.0524 to 0.3339.
	var u: Array = unpaired(56, 70, 48, 80)
	ok = _expect("newcombe low", u[1], 0.0524, 0.0005) and ok
	ok = _expect("newcombe high", u[2], 0.3339, 0.0005) and ok
	ok = _expect("z for one test", z_for(1), 1.96, 0.001) and ok
	ok = _expect("z for ten tests", z_for(10), 2.807, 0.001) and ok
	ok = _expect("runs for +-5 at 60%", runs_needed(0.6, 0.05), 369, 0.5) and ok
	print("  %s" % ("all good" if ok else "FAILED"))
	quit(0 if ok else 1)


func _expect(label: String, got: float, want: float, tol: float) -> bool:
	var good: bool = absf(got - want) <= tol
	print("  %s %-24s %.4f (want %.4f)" % ["ok  " if good else "FAIL", label, got, want])
	return good
