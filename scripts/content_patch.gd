class_name ContentPatch
extends RefCounted

## Server-delivered content and balance, applied over what shipped in the build.
##
## A live free-to-play game retunes constantly. Waiting on a store review to change one
## number is how a broken meta lasts three weeks, so balance has to move without a client
## update. Every number in `data/` is already data rather than code, which is what makes
## this a small class instead of a rewrite.
##
## ## The determinism problem, which is the whole design
##
## Two clients on different content **cannot fight**. Their simulations diverge, the
## server's re-run disagrees with both, and every honest player starts getting rejected —
## the exact failure the integer maths and seeded PRNG exist to prevent. So:
##
##   - a patch has a **version**, and the content it produces has a **content hash**
##   - every submission carries that hash
##   - the verifier compares it **before anything else** and rejects a mismatch with a
##     verdict that says "out of date", not "cheat"
##
## The client caches the last patch it saw, so an offline launch plays the same game it
## played yesterday rather than silently reverting to the shipped numbers.

const CACHE_PATH: String = "user://content_patch.json"

## Bumped when the patch FORMAT changes (not its contents). A client that does not
## understand a patch ignores it and keeps playing on shipped content, which is always
## a valid game.
const PATCH_FORMAT: int = 1

var format: int = PATCH_FORMAT
## Monotonic, set by whoever publishes. Shown to players in the "out of date" message.
var version: int = 0
var notes: String = ""
## `{part_id: {field: value}}` — merged field by field over the shipped definition, so a
## patch that changes one number does not have to restate the whole part.
var parts: Dictionary = {}
var abilities: Dictionary = {}
var conditions: Dictionary = {}
## Flat `{field: value}` over `Balance`.
var balance: Dictionary = {}


static func from_dict(d: Dictionary) -> ContentPatch:
	var patch := ContentPatch.new()
	patch.format = int(d.get("format", 0))
	patch.version = int(d.get("version", 0))
	patch.notes = String(d.get("notes", ""))
	patch.parts = d.get("parts", {}) as Dictionary
	patch.abilities = d.get("abilities", {}) as Dictionary
	patch.conditions = d.get("conditions", {}) as Dictionary
	patch.balance = d.get("balance", {}) as Dictionary
	return patch


func to_dict() -> Dictionary:
	return {
		"format": format, "version": version, "notes": notes,
		"parts": parts, "abilities": abilities,
		"conditions": conditions, "balance": balance,
	}


func is_empty() -> bool:
	return parts.is_empty() and abilities.is_empty() \
		and conditions.is_empty() and balance.is_empty()


func is_supported() -> bool:
	return format == PATCH_FORMAT


## Applies the patch in place. Unknown ids are **added**, known ids are merged field by
## field. Adding is deliberate: a new Condition is a season of live-ops content that
## costs one JSON object, which is the cheapest content this game has.
func apply_to(db: ContentDB) -> void:
	if not is_supported():
		push_warning("content patch format %d not understood; ignoring" % format)
		return

	_merge(db.parts, parts)
	_merge(db.abilities, abilities)
	_merge(db.conditions, conditions)

	for field: Variant in _sorted(balance.keys()):
		var name: String = String(field)
		if not (name in db.balance):
			push_warning("content patch: no balance field '%s'" % name)
			continue
		# Every Balance field is an integer. Assigning a float here would put a float
		# into the simulation, which is the one thing `sim/` may never contain.
		db.balance.set(name, int(balance[field]))

	db.patch_version = version


func _merge(target: Dictionary, overrides: Dictionary) -> void:
	for id: Variant in _sorted(overrides.keys()):
		var key: String = String(id)
		var fields: Dictionary = overrides[id] as Dictionary
		if not target.has(key):
			target[key] = fields.duplicate(true)
			continue
		var entry: Dictionary = (target[key] as Dictionary).duplicate(true)
		for field: Variant in _sorted(fields.keys()):
			entry[String(field)] = fields[field]
		target[key] = entry


## Sorted so applying a patch is deterministic regardless of dictionary order. Content
## feeds the simulation, and the simulation's whole contract is that it does not depend
## on iteration order anywhere.
static func _sorted(keys: Array) -> Array:
	var out: Array = keys.duplicate()
	out.sort()
	return out


# --- Cache -------------------------------------------------------------------

## The last patch this device saw. Read at boot before any network call, so a player
## with no signal plays yesterday's balance rather than the build's.
static func load_cached() -> ContentPatch:
	if not FileAccess.file_exists(CACHE_PATH):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(CACHE_PATH)) != OK:
		return null
	if not (json.data is Dictionary):
		return null
	return ContentPatch.from_dict(json.data as Dictionary)


func cache() -> void:
	var file: FileAccess = FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
