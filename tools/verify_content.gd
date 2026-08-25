extends SceneTree

## The live-content pipeline: can balance change without a client update, and without
## breaking verification for everyone mid-patch?
##
##   godot --headless --path . --script res://tools/verify_content.gd
##
## The question that matters here is not "does a patch apply" — it is **what happens to
## the player who was mid-session when it shipped.** Their honest battle replays
## differently on a patched server, and if that is treated as a forged result then every
## balance change costs a wave of false cheat rejections. So the content version travels
## with the submission and is checked first, and the verdict says "out of date".
##
## The second question is the one that is easy to forget: a patch must reach the
## VERIFICATION WORKER too. A server shipping new numbers while its worker verifies
## against the old ones rejects the entire player base at once.

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	print("")
	print("=== live content and balance patches ===")

	_test_hash_is_stable_and_sensitive()
	_test_patch_merges_rather_than_replaces()
	_test_patch_adds_new_content()
	_test_bad_patch_is_ignored()
	_test_mismatched_content_is_not_called_cheating()
	_test_matched_content_still_verifies()
	_test_cache_round_trip()

	print("")
	print("  %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_hash_is_stable_and_sensitive() -> void:
	print("\n  the content hash")
	var a: ContentDB = ContentDB.load_all()
	var b: ContentDB = ContentDB.load_all()
	_check("two loads of the same data hash identically", a.content_version() == b.content_version())

	# Economy and campaign are not simulation inputs. A price change must not invalidate
	# every battle in flight, or routine live-ops becomes impossible.
	b.economy["scrap_per_level"] = 999999
	b.campaign["z1_01"] = {"id": "z1_01"}
	_check("a non-simulation change does not move the hash",
		a.content_version() == b.content_version())

	b.balance.min_damage += 1
	_check("a balance change does move it", a.content_version() != b.content_version())


func _test_patch_merges_rather_than_replaces() -> void:
	print("\n  merging")
	var db: ContentDB = ContentDB.load_all()
	var part_id: String = "ar_lance"
	var original: Dictionary = (db.parts[part_id] as Dictionary).duplicate(true)
	if original.is_empty():
		_check("a part to patch", false)
		return

	var patch := ContentPatch.from_dict({
		"format": 1, "version": 5, "parts": {part_id: {"rarity": 4}},
	})
	patch.apply_to(db)

	var patched: Dictionary = db.parts[part_id]
	_check("the patched field changed", int(patched.get("rarity", -1)) == 4)
	# The whole point of merging: a patch that restates a part is a patch that silently
	# reverts every field somebody forgot to include.
	var kept: bool = true
	for field: Variant in original.keys():
		if String(field) == "rarity":
			continue
		if str(patched.get(field)) != str(original[field]):
			kept = false
	_check("every other field survived", kept)
	_check("the patch version is recorded", db.patch_version == 5)


func _test_patch_adds_new_content() -> void:
	print("\n  adding content")
	var db: ContentDB = ContentDB.load_all()
	var before: int = db.conditions.size()
	var patch := ContentPatch.from_dict({
		"format": 1, "version": 6,
		"conditions": {"cond_test_storm": {
			"id": "cond_test_storm", "name": "Test Storm", "text": "for the test",
		}},
	})
	patch.apply_to(db)
	_check("a new Condition is added, not rejected", db.conditions.size() == before + 1)
	# A season of live-ops content costs one JSON object. That is the whole argument for
	# rotating Conditions rather than shipping new parts every month.
	_check("and it is reachable by id", db.conditions.has("cond_test_storm"))


func _test_bad_patch_is_ignored() -> void:
	print("\n  a patch this build does not understand")
	var db: ContentDB = ContentDB.load_all()
	var before: String = db.content_version()
	var patch := ContentPatch.from_dict({
		"format": 99, "version": 7, "balance": {"min_damage": 50},
	})
	patch.apply_to(db)
	# Playing on shipped content is always a valid game. Guessing at a patch format from
	# the future is not.
	_check("an unsupported format changes nothing", db.content_version() == before)

	var unknown: ContentDB = ContentDB.load_all()
	ContentPatch.from_dict({
		"format": 1, "version": 8, "balance": {"no_such_field": 3},
	}).apply_to(unknown)
	_check("an unknown balance field is skipped rather than invented",
		not ("no_such_field" in unknown.balance))


func _test_mismatched_content_is_not_called_cheating() -> void:
	print("\n  a player who was mid-session when the patch shipped")
	var old: ContentDB = ContentDB.load_all()
	var submission: BattleSubmission = _fight(old)

	var patched: ContentDB = ContentDB.load_all()
	ContentPatch.from_dict({
		"format": 1, "version": 9, "balance": {"base_attack_ticks": 30},
	}).apply_to(patched)

	var report: BattleVerifier.Report = BattleVerifier.verify(
		submission, patched.to_sim_content(), patched.balance, null, patched.content_version())
	_check("the submission is rejected", not report.accepted())
	_check("as a content mismatch, NOT as a forgery (%s)" % report.verdict_name(),
		report.verdict == BattleVerifier.Verdict.CONTENT_MISMATCH)
	_check("and the message names both versions",
		report.detail.contains(old.content_version()) and report.detail.contains(patched.content_version()))


func _test_matched_content_still_verifies() -> void:
	print("\n  once both sides are on the patch")
	var db: ContentDB = ContentDB.load_all()
	ContentPatch.from_dict({
		"format": 1, "version": 9, "balance": {"base_attack_ticks": 30},
	}).apply_to(db)

	var submission: BattleSubmission = _fight(db)
	var report: BattleVerifier.Report = BattleVerifier.verify(
		submission, db.to_sim_content(), db.balance, null, db.content_version())
	_check("a battle fought under the patch verifies against the patch (%s)"
		% report.verdict_name(), report.accepted())

	# The number really reached the simulation, rather than only the hash.
	var shipped: ContentDB = ContentDB.load_all()
	_check("and the patched battle is a different battle",
		_fight(shipped).claimed_hash != submission.claimed_hash)


func _test_cache_round_trip() -> void:
	print("\n  the offline cache")
	var patch := ContentPatch.from_dict({
		"format": 1, "version": 11, "notes": "cached",
		"balance": {"min_damage": 2}, "parts": {"ar_lance": {"rarity": 3}},
	})
	patch.cache()
	var loaded: ContentPatch = ContentPatch.load_cached()
	_check("a cached patch reloads", loaded != null and loaded.version == 11)

	var db: ContentDB = ContentDB.load_all()
	loaded.apply_to(db)
	_check("and applies the same way", db.balance.min_damage == 2)

	if FileAccess.file_exists(ContentPatch.CACHE_PATH):
		DirAccess.open("user://").remove(ContentPatch.CACHE_PATH)


func _fight(db: ContentDB) -> BattleSubmission:
	var squad: Array = [
		{"name": "a", "power": 100, "parts": {"chassis": "ch_brute", "core": "co_ember",
			"arm_l": "ar_hammer", "arm_r": "ar_hammer", "module": "mo_plate"}},
		{"name": "b", "power": 100, "parts": {"chassis": "ch_lancer", "core": "co_mag",
			"arm_l": "ar_lance", "arm_r": "ar_lance", "module": "mo_plate"}},
	]
	var setup: BattleSetup = BattleSetup.make(777, squad, squad, "", "")
	var result: BattleResult = BattleSim.simulate(
		setup, [], db.to_sim_content(), db.balance, [])
	return BattleSubmission.from_result(setup, [], result, "test", db.content_version())


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("  ok    %s" % label)
	else:
		_failed += 1
		printerr("  FAIL  %s" % label)
