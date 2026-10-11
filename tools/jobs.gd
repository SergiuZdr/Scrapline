extends RefCounted

## Splits a headless tool's work over several Godot processes (070). GDScript runs on one core and
## a bot batch is hours of it; this machine has sixteen.
##
## The tool runs itself as children: child `j` of `n` takes the work items `i` with `i % n == j`
## (interleaved, so a slow stretch of seeds is shared out), writes one line per finished item to
## `<out>.progress` (a line starting with "+" counts as a success) and its numbers as JSON to `<out>`.
## The parent prints progress as lines arrive and gets every child's numbers back.
##
##   const Jobs = preload("res://tools/jobs.gd")
##   var slice: Array = Jobs.slice(args)            # [j, n, out] in a child, [] in the parent
##   var parts: Array = Jobs.run("res://tools/x.gd", args, jobs, total)   # in the parent
##
## Loaded with preload, not by class_name: a `--script` tool must not depend on the class cache.

const DIR: String = "user://jobs"


## The default: one process per core but one.
static func default_count() -> int:
	return maxi(1, OS.get_processor_count() - 1)


## `[slice, of, out]` when this process is a child, else [].
static func slice(args: PackedStringArray) -> Array:
	var at: int = args.find("--slice")
	if at < 0:
		return []
	return [args[at + 1].to_int(), args[args.find("--of") + 1].to_int(), args[args.find("--out") + 1]]


## Whether work item `i` belongs to this process (always, when it is not a child).
static func mine(slice_info: Array, i: int) -> bool:
	return slice_info.is_empty() or i % int(slice_info[1]) == int(slice_info[0])


## A child reports one finished item.
static func progress(slice_info: Array, line: String) -> void:
	if slice_info.is_empty():
		return
	var path: String = String(slice_info[2]) + ".progress"
	var f: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	f.seek_end()
	f.store_string(line.replace("\n", " ") + "\n")
	f.close()


## A child hands its numbers back.
static func finish(slice_info: Array, numbers: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(String(slice_info[2]), FileAccess.WRITE)
	f.store_string(JSON.stringify(numbers))
	f.close()


## Runs `script` as `jobs` children with `args` (minus `--jobs`), printing progress until every
## child has exited; `good` names what a "+" progress line counts. Returns each child's numbers
## (JSON: numbers come back as floats); a child that left none (a script error) is reported and skipped.
static func run(script: String, args: PackedStringArray, jobs: int, total: int, good: String = "ok") -> Array:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var tag: String = "%s_%d" % [script.get_file().get_basename(), OS.get_process_id()]
	var passed: PackedStringArray = []
	var i: int = 0
	while i < args.size():
		if ["--jobs", "--slice", "--of", "--out"].has(args[i]):
			i += 2
			continue
		passed.append(args[i])
		i += 1
	var pids: Array[int] = []
	var outs: PackedStringArray = []
	for j: int in jobs:
		var out: String = ProjectSettings.globalize_path("%s/%s_%d.json" % [DIR, tag, j])
		for stale: String in [out, out + ".progress"]:
			if FileAccess.file_exists(stale):
				DirAccess.remove_absolute(stale)
		var child: PackedStringArray = ["--headless", "--no-header", "--path", ProjectSettings.globalize_path("res://"),
			"--script", script, "--"]
		child.append_array(passed)
		child.append_array(["--slice", str(j), "--of", str(jobs), "--out", out])
		pids.append(OS.create_process(OS.get_executable_path(), child))
		outs.append(out)
	print("  %d items over %d processes" % [total, jobs])
	var start_ms: int = Time.get_ticks_msec()
	var shown: int = -1
	var last_print: int = 0
	while true:
		var running: int = 0
		for pid: int in pids:
			if pid > 0 and OS.is_process_running(pid):
				running += 1
		var done: int = 0
		var wins: int = 0
		for out: String in outs:
			for line: String in FileAccess.get_file_as_string(out + ".progress").split("\n", false):
				done += 1
				wins += 1 if line.begins_with("+") else 0
		var now: int = Time.get_ticks_msec()
		# Every item while there are few; at most every five seconds when there are many.
		if done != shown and (total <= 60 or now - last_print >= 5000 or running == 0):
			shown = done
			last_print = now
			var secs: float = (now - start_ms) / 1000.0
			var left: String = "" if done == 0 else ", about %.0fs left" % (secs / done * (total - done))
			print("  %d/%d done, %d %s  (%.0fs%s)" % [done, total, wins, good, secs, left])
		if running == 0:
			break
		OS.delay_msec(400)
	var parts: Array = []
	for j: int in outs.size():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(outs[j]))
		if parsed is Dictionary:
			parts.append(parsed)
		else:
			print("  process %d left no numbers -- run with --jobs 1 to see its error" % j)
		for leftover: String in [outs[j], outs[j] + ".progress"]:
			if FileAccess.file_exists(leftover):
				DirAccess.remove_absolute(leftover)
	return parts


## Adds `part` into `total`, key by key: ints add, dictionaries add per key (recursively), anything
## else is left as `total` has it. JSON turned `part`'s ints into floats; they come back as ints.
static func merge(total: Dictionary, part: Dictionary) -> void:
	for key: Variant in part:
		var value: Variant = part[key]
		if value is Dictionary:
			if not total.has(key) or not total[key] is Dictionary:
				total[key] = {}
			merge(total[key], value)
		elif value is float or value is int:
			total[key] = int(total.get(key, 0)) + int(value)
		elif value is Array:
			var mine: Array = total.get(key, [])
			for k: int in (value as Array).size():
				if k < mine.size():
					mine[k] = int(mine[k]) + int(value[k])
				else:
					mine.append(int(value[k]))
			total[key] = mine
