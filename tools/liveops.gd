extends SceneTree

## The operator's tool: open a colossus, start a tournament, see what is running.
##
## Everything a live game needs somebody to *do* on a schedule, in one place, so it is a
## command rather than a remembered curl. All of it goes through the worker endpoints,
## which is why none of it is reachable from a client.
##
##   godot --headless --path . --script res://tools/liveops.gd -- --status
##   godot --headless --path . --script res://tools/liveops.gd -- --open-boss
##   godot --headless --path . --script res://tools/liveops.gd -- --open-tournament
##   godot --headless --path . --script res://tools/liveops.gd -- --open-tournament \
##       --id proving_march --title "March Proving Ground" --hours 72 --attempts 5
##
## `--nakama <url>` and `--http-key <key>` point it at a server other than the local one.

const DEFAULT_URL: String = "http://127.0.0.1:7350"
const DEFAULT_KEY: String = "defaulthttpkey"

var _content: ContentDB
var _http: NakamaHttp


func _initialize() -> void:
	var opts: Dictionary = _parse_args(OS.get_cmdline_user_args())
	_content = ContentDB.load_all()
	if not _content.errors.is_empty():
		for e: String in _content.errors:
			printerr("content: ", e)
		quit(2)
		return

	_http = NakamaHttp.open(String(opts.get("nakama", DEFAULT_URL)))
	var key: String = String(opts.get("http-key", DEFAULT_KEY))

	if opts.has("open-boss"):
		quit(_open_boss(key, opts))
		return
	if opts.has("open-tournament"):
		quit(_open_tournament(key, opts))
		return
	quit(_status(key))


## What is running right now, from the server rather than from anybody's memory.
func _status(key: String) -> int:
	var content_state: Dictionary = _http.rpc_as_server(key, "sync_content", {})
	if content_state.has("error"):
		printerr("cannot reach the server: ", content_state["error"])
		return 2

	print("")
	print("=== live ===")
	var patch: Variant = content_state.get("patch")
	if patch == null:
		print("  content    shipped (no patch)")
	else:
		var applied: ContentPatch = ContentPatch.from_dict(patch as Dictionary)
		print("  content    patch v%d — %s" % [applied.version, applied.notes])

	# Read as a player would, because that is the view that matters: an encounter the
	# server knows about but nobody can see is not running.
	var token: String = _http.authenticate("defaultkey", "liveops-observer-01", "")
	if token.is_empty():
		print("  (could not sign in an observer; boss and tournament state unavailable)")
		return 0

	var boss: Dictionary = _http.rpc_as_user(token, "boss_state", {})
	var encounter: Variant = boss.get("encounter")
	if encounter == null:
		print("  colossus   nothing open")
	else:
		var e: Dictionary = encounter as Dictionary
		print("  colossus   %s — %d of %d hull, %s pool" % [
			e.get("boss", "?"), int(e.get("remaining", 0)), int(e.get("pool", 0)),
			e.get("scope", "?")])

	var tournament: Dictionary = _http.rpc_as_user(token, "tournament_state", {})
	var open: Variant = tournament.get("tournament")
	if open == null:
		print("  tournament nothing open")
	else:
		var t: Dictionary = open as Dictionary
		var hours: int = maxi(0, int(t.get("end_time", 0)) - int(Time.get_unix_time_from_system())) / 3600
		print("  tournament %s — %s, %d attempts, %dh left, %d entrants" % [
			t.get("id", "?"), t.get("title", ""), int(t.get("max_attempts", 0)),
			hours, int(t.get("size", 0))])
	print("")
	return 0


func _open_boss(key: String, opts: Dictionary) -> int:
	var ids: Array = _content.bosses.keys()
	ids.sort()
	if ids.is_empty():
		printerr("no bosses are authored")
		return 2
	var boss: Dictionary = _content.bosses[String(opts.get("id", ids[0]))]
	if boss.is_empty():
		printerr("no such boss")
		return 2

	var response: Dictionary = _http.rpc_as_server(key, "open_boss", {
		"bossId": String(boss["id"]),
		"hpPool": int(opts.get("pool", str(boss.get("hp_pool", 900000)))),
		"durationHours": int(opts.get("hours", str(boss.get("duration_hours", 168)))),
	})
	if response.has("error"):
		printerr("could not open: ", response["error"])
		return 1
	print("opened %s with %d hull" % [response.get("boss"), int(response.get("pool", 0))])
	print("  every guild gets its own pool, created the first time a member looks")
	return 0


func _open_tournament(key: String, opts: Dictionary) -> int:
	# Dated by default, so running this twice in a week does not silently reuse last
	# week's tournament -- and its scores.
	var stamp: int = int(Time.get_unix_time_from_system()) / 86400
	var id: String = String(opts.get("id", "proving_%d" % stamp))

	var response: Dictionary = _http.rpc_as_server(key, "open_tournament", {
		"id": id,
		"title": String(opts.get("title", "Proving Ground")),
		"description": String(opts.get("description",
			"One squad, one challenge, everybody's best attempt.")),
		"durationHours": int(opts.get("hours", "72")),
		"attempts": int(opts.get("attempts", str(Tournament.ENTRY_ATTEMPTS))),
	})
	if response.has("error"):
		printerr("could not open: ", response["error"])
		return 1

	print("opened tournament %s" % response.get("id"))
	# Printed so whoever runs it can see the fight before players do, and pull it if the
	# generated squad is a joke.
	var squad: Array = Tournament.challenge_squad(id, int(Time.get_unix_time_from_system()), _content)
	print("  the challenge squad:")
	for entry: Variant in squad:
		var parts: Dictionary = (entry as Dictionary)["parts"]
		print("    %-14s %s / %s / %s" % [
			(entry as Dictionary)["name"], parts["chassis"], parts["core"], parts["arm_l"]])
	return 0


func _parse_args(args: PackedStringArray) -> Dictionary:
	var opts: Dictionary = {}
	var i: int = 0
	while i < args.size():
		if not args[i].begins_with("--"):
			i += 1
			continue
		var key: String = args[i].substr(2)
		if i + 1 < args.size() and not args[i + 1].begins_with("--"):
			opts[key] = args[i + 1]
			i += 2
		else:
			opts[key] = true
			i += 1
	return opts
