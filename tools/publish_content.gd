extends SceneTree

## Ships a balance patch to live players. No client update, no store review.
##
##   godot --headless --path . --script res://tools/publish_content.gd -- \
##       --file patches/2026-08-nerf-lance.json --nakama http://127.0.0.1:7350
##
##   godot --headless --path . --script res://tools/publish_content.gd -- --show
##   godot --headless --path . --script res://tools/publish_content.gd -- --clear
##
## A patch looks like this — only what changes, nothing restated:
##
## ```json
## {
##   "format": 1,
##   "version": 3,
##   "notes": "ar_lance was 58% presence-weighted; cost it reach.",
##   "parts": { "ar_lance": { "reach": 340, "damage": 44 } },
##   "conditions": { "cond_rust_squall": { "id": "cond_rust_squall",
##       "name": "Rust Squall", "text": "Corrosive bites deeper." } },
##   "balance": { "overdrive_multiplier": 190 }
## }
## ```
##
## **It dry-runs before it publishes.** The patch is applied to a local copy of the
## content and a battle is simulated under it, because a patch that crashes the
## simulation would take every player's game down at once and there is no way to take it
## back quickly. A published patch that does not run is the worst outcome this pipeline
## has, so the check is not optional.

const DEFAULT_URL: String = "http://127.0.0.1:7350"
const HTTP_KEY: String = "defaulthttpkey"


func _initialize() -> void:
	var opts: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var url: String = String(opts.get("nakama", DEFAULT_URL))
	var key: String = String(opts.get("http-key", HTTP_KEY))
	var http: NakamaHttp = NakamaHttp.open(url)

	if opts.has("show"):
		var live: Dictionary = http.rpc_as_server(key, "sync_content", {})
		print(JSON.stringify(live, "\t"))
		quit(0)
		return

	if opts.has("clear"):
		# Version 0 is "shipped content, nothing on top". Clients compare versions, so
		# there has to be a patch that means "revert" rather than an absent one.
		var reverted: Dictionary = http.rpc_as_server(key, "publish_content", {
			"format": ContentPatch.PATCH_FORMAT, "version": int(opts.get("version", "0")),
			"notes": "reverted to shipped content",
		})
		print(JSON.stringify(reverted))
		quit(1 if reverted.has("error") else 0)
		return

	if not opts.has("file"):
		printerr("usage: --file <patch.json> [--nakama <url>] [--dry-run]")
		quit(2)
		return

	var path: String = String(opts["file"])
	if not FileAccess.file_exists(path):
		printerr("no such file: ", path)
		quit(2)
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		printerr("%s: line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		quit(2)
		return

	var patch: ContentPatch = ContentPatch.from_dict(json.data as Dictionary)
	if not patch.is_supported():
		printerr("patch format %d, this build writes %d" % [patch.format, ContentPatch.PATCH_FORMAT])
		quit(2)
		return
	if patch.version <= 0:
		printerr("a patch needs a version above zero; clients ignore anything older than what they have")
		quit(2)
		return

	if not _dry_run(patch):
		quit(3)
		return

	if opts.has("dry-run"):
		print("dry run only; nothing published")
		quit(0)
		return

	var response: Dictionary = http.rpc_as_server(key, "publish_content", patch.to_dict())
	if response.has("error"):
		printerr("publish failed: ", response["error"])
		quit(1)
		return
	print("published v%d" % patch.version)
	print("  players pick it up at their next launch; the worker at its next start")
	quit(0)


## Applies the patch locally and fights a battle under it. Reports what moved, so the
## person publishing sees the consequence rather than trusting the diff.
func _dry_run(patch: ContentPatch) -> bool:
	var before: ContentDB = ContentDB.load_all()
	if not before.errors.is_empty():
		for e: String in before.errors:
			printerr("content: ", e)
		return false

	var after: ContentDB = ContentDB.load_all()
	patch.apply_to(after)

	print("patch v%d  %s" % [patch.version, patch.notes])
	print("  content %s -> %s" % [before.content_version(), after.content_version()])
	print("  parts touched: %d   abilities: %d   conditions: %d   balance fields: %d" % [
		patch.parts.size(), patch.abilities.size(), patch.conditions.size(), patch.balance.size()])

	for id: Variant in patch.parts.keys():
		if not before.parts.has(String(id)):
			print("  + new part %s" % String(id))
	for id: Variant in patch.conditions.keys():
		if not before.conditions.has(String(id)):
			print("  + new condition %s" % String(id))

	if before.content_version() == after.content_version():
		printerr("  this patch changes nothing the simulation reads")
		return false

	var squad: Array = [
		_unit("ch_brute", "co_ember", "ar_hammer"),
		_unit("ch_bulwark", "co_slug", "ar_ripper"),
		_unit("ch_lancer", "co_mag", "ar_lance"),
	]
	var setup: BattleSetup = BattleSetup.make(20260811, squad, squad, "", "")
	var result: BattleResult = BattleSim.simulate(
		setup, [], after.to_sim_content(), after.balance, [])
	if result == null or result.cycles <= 0:
		printerr("  a battle under this patch does not run -- refusing to publish")
		return false
	print("  a battle under it runs: %d cycles, winner %d" % [result.cycles, result.winner])
	return true


func _unit(chassis: String, core: String, arm: String) -> Dictionary:
	return {"name": chassis, "power": 100, "parts": {
		"chassis": chassis, "core": core, "arm_l": arm, "arm_r": arm, "module": "mo_plate"}}


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
