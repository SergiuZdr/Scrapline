extends SceneTree

## Checks that the loadout screen actually CHANGES the squad, and that the change sticks.
##
##     $GODOT --headless --path . --script res://tools/verify_loadout.gd
##
## `verify_ui.gd` presses every button and reports that nothing crashed. That is not the
## same as the button doing its job: a FIT that silently wrote nowhere would pass it
## cleanly. This drives the real screen and then reads the profile back off disk.
##
## The specific thing being guarded is a known trap -- a direct write
## to `profile.data` typechecks, runs, and evaporates at the next launch, because
## `ProfileStore.save()` returns early unless a command marked the profile dirty. The
## reload at the end is the only way to catch that.

var _passed: int = 0
var _failed: int = 0


## The engine's autoload under `name`, or a stand-in built from `path` if this run has
## none. Never a duplicate of one that already exists.
func _autoload(name: String, path: String) -> Node:
	var existing: Node = root.get_node_or_null(NodePath(name))
	if existing != null:
		return existing
	var node: Node = load(path).new()
	node.name = name
	root.add_child(node)
	return node


func _check(what: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("  ok    %s" % what)
	else:
		_failed += 1
		print("  FAIL  %s" % what)


func _initialize() -> void:
	print("\n=== loadout screen ===")
	_run.call_deferred()


func _run() -> void:
	# Reuse the ENGINE's autoloads if they exist, and only build stand-ins if they do not.
	#
	# This is the trap that made the first version of this test lie. `loadout_screen.gd`
	# resolves `Session` to the autoload singleton; creating a second node also called
	# "Session" gives the test its own store over the same save file. The screen then
	# wrote through one profile and the test read the other, so an equip that genuinely
	# worked was reported as doing nothing -- while the on-disk check passed, which is
	# exactly the contradiction that gave it away.
	var session: Node = _autoload("Session", "res://scripts/autoload/session.gd")
	var audio: Node = _autoload("Audio", "res://scripts/autoload/audio.gd")
	audio.call("set_enabled", false)
	_autoload("Analytics", "res://scripts/autoload/analytics.gd")

	await process_frame

	# Use whatever store Session built for itself, rather than opening a second one. Two
	# stores over one save file are two divergent copies of the profile, and the screen
	# only ever writes through Session's.
	var content: ContentDB = session.get("content")
	if content == null:
		content = ContentDB.load_all()
		session.set("content", content)
	var store: ProfileStore = session.get("store")
	if store == null:
		store = ProfileStore.open(content)
		session.set("store", store)
	var profile: PlayerProfile = store.profile

	# A core the player owns and is NOT already wearing, so a successful fit is provable.
	var fitted_core: String = String(
		((profile.squad("main")[0] as Dictionary).get("parts", {}) as Dictionary).get("core", ""))
	var target: String = ""
	for part_id: String in profile.owned_part_ids():
		var definition: Dictionary = content.parts.get(part_id, {})
		if String(definition.get("slot", "")) == "core" and part_id != fitted_core:
			target = part_id
			break
	if target.is_empty():
		print("  skip  the profile owns only one core; nothing to swap to")
		quit()
		return

	# Loaded at RUNTIME, not referenced by class name. A static `LoadoutScreen` reference
	# makes Godot compile that script while resolving this one -- before the autoload
	# nodes above exist -- and every `Session.` in it fails to compile. `verify_ui.gd`
	# loads the hub the same way for the same reason.
	var screen: Control = load("res://scripts/ui/loadout_screen.gd").new()
	root.add_child(screen)
	await process_frame

	screen._on_slot("core")
	_check("selecting a socket does not disturb the squad",
		String(((profile.squad("main")[0] as Dictionary).get("parts", {})
			as Dictionary).get("core", "")) == fitted_core)

	screen._on_fit(target)
	# Read through the same accessor the SCREEN uses. `Session` builds its own store in
	# `_ready`, so a store this test opened separately is a different object holding a
	# different copy of the profile -- comparing against it tests the wrong thing.
	var after: String = String(((session.call("profile").squad("main")[0] as Dictionary)
		.get("parts", {}) as Dictionary).get("core", ""))
	_check("fitting a part changes the squad in memory (%s -> %s)" % [fitted_core, after],
		after == target)

	# The real test: reopen the profile from disk. A write that never reached a command
	# looks identical to a real one until this line.
	var reopened: ProfileStore = ProfileStore.open(content)
	var persisted: String = String(((reopened.profile.squad("main")[0] as Dictionary)
		.get("parts", {}) as Dictionary).get("core", ""))
	_check("the change survives a reload", persisted == target)
	_check("the squad is still valid after the swap", reopened.profile.squad_is_valid("main"))

	# Put it back, so running the checks does not quietly rearrange the player's squad.
	screen._on_fit(fitted_core)
	var restored: ProfileStore = ProfileStore.open(content)
	_check("the original loadout is restored",
		String(((restored.profile.squad("main")[0] as Dictionary).get("parts", {})
			as Dictionary).get("core", "")) == fitted_core)

	print("\n  %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
