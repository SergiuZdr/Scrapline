class_name ContentDB
extends RefCounted

## Loads every piece of game content from `data/` into plain dictionaries.
##
## This lives outside `sim/` on purpose: the simulation is not allowed to touch the
## filesystem, so content is loaded once out here and handed in. That separation is
## what lets the headless server and the balance tool feed the sim exactly the same
## content the client had, and later lets the server ship a balance patch without a
## client update.
##
## It is a plain RefCounted rather than an autoload so that headless tools run with
## `--script` (which does not instantiate autoloads) can use it directly.

const DATA_ROOT: String = "res://data"

## Part id -> part definition, flattened across every part-type file.
var parts: Dictionary = {}
var abilities: Dictionary = {}
var conditions: Dictionary = {}
var maps: Dictionary = {}
## Terrain tile definitions, in file order -- the index IS the tile type id stored in
## a Battlefield's grid, so this array's order must stay stable.
var tiles: Array = []
var linkages: Array = []
var economy: Dictionary = {}
var crates: Dictionary = {}
var buildings: Dictionary = {}
var campaign: Dictionary = {}
var bosses: Dictionary = {}
var store: Dictionary = {}
var battle_pass: Dictionary = {}
var balance: Balance = null

## Version of the server-delivered patch applied on top of the shipped data, or 0.
var patch_version: int = 0

var errors: PackedStringArray = []


static func load_all(root: String = DATA_ROOT) -> ContentDB:
	var db := ContentDB.new()

	for file_name: String in ["chassis", "cores", "arms", "modules"]:
		db._load_into(db.parts, "%s/parts/%s.json" % [root, file_name], "id")

	db._load_into(db.abilities, "%s/abilities/abilities.json" % root, "id")
	db._load_into(db.conditions, "%s/conditions/conditions.json" % root, "id")
	db._load_into(db.maps, "%s/maps/foundry_yard.json" % root, "id")
	db._load_into(db.crates, "%s/crates.json" % root, "id")
	db._load_into(db.buildings, "%s/buildings.json" % root, "id")
	db._load_into(db.campaign, "%s/campaign.json" % root, "id")
	db._load_into(db.bosses, "%s/bosses.json" % root, "id")
	db._load_into(db.store, "%s/store.json" % root, "id")

	var pass_data: Variant = db._read_json("%s/battle_pass.json" % root)
	if pass_data is Dictionary:
		db.battle_pass = pass_data as Dictionary

	var tile_data: Variant = db._read_json("%s/terrain/tiles.json" % root)
	if tile_data is Array:
		db.tiles = tile_data as Array

	var link_data: Variant = db._read_json("%s/linkages.json" % root)
	if link_data is Array:
		db.linkages = link_data as Array

	var economy_data: Variant = db._read_json("%s/economy.json" % root)
	if economy_data is Dictionary:
		db.economy = economy_data as Dictionary

	var balance_data: Variant = db._read_json("%s/balance.json" % root)
	db.balance = Balance.from_dict(balance_data as Dictionary if balance_data is Dictionary else {})

	return db


## The bundle the simulation expects. Keeping this shape in one place means adding a
## content category is a one-line change here rather than a hunt through callers.
func to_sim_content() -> Dictionary:
	return {
		"parts": parts,
		"abilities": abilities,
		"conditions": conditions,
		"linkages": linkages,
		"maps": maps,
		"tiles": tiles,
	}


## A hash of everything the simulation reads. **This is what makes a live balance patch
## safe.** Two clients whose content hashes differ cannot verify each other's battles, so
## every submission carries this and the verifier checks it first — the difference
## between telling a player "your client is out of date" and accusing them of cheating.
##
## Deterministic: keys are sorted, and only sim-relevant content is included. Cosmetic
## data, campaign text and economy numbers change nothing about how a battle plays and
## must not invalidate one.
func content_version() -> String:
	var hash_value: int = 0x811C9DC5
	for section: Variant in ["parts", "abilities", "conditions", "linkages", "maps", "tiles"]:
		hash_value = _hash_string(hash_value, String(section))
		hash_value = _hash_value(hash_value, to_sim_content()[section])
	hash_value = _hash_value(hash_value, balance.to_dict())
	return "%08x" % hash_value


## FNV-1a over a canonical rendering of a value. Dictionaries are visited in sorted key
## order; anything else is rendered with `str()`, which is stable for the ints, strings
## and arrays content is made of.
static func _hash_value(hash_value: int, value: Variant) -> int:
	if value is Dictionary:
		var keys: Array = (value as Dictionary).keys()
		keys.sort()
		for key: Variant in keys:
			hash_value = _hash_string(hash_value, String(key))
			hash_value = _hash_value(hash_value, (value as Dictionary)[key])
		return hash_value
	if value is Array:
		for entry: Variant in (value as Array):
			hash_value = _hash_value(hash_value, entry)
		return hash_value
	return _hash_string(hash_value, str(value))


static func _hash_string(hash_value: int, text: String) -> int:
	for byte: int in text.to_utf8_buffer():
		hash_value = (hash_value ^ byte) & 0xFFFFFFFF
		hash_value = (hash_value * 16777619) & 0xFFFFFFFF
	return hash_value


func is_valid() -> bool:
	return errors.is_empty() and not parts.is_empty()


func summary() -> String:
	return "patch=%d content=%s " % [patch_version, content_version()] + "parts=%d abilities=%d conditions=%d linkages=%d maps=%d tiles=%d crates=%d buildings=%d nodes=%d bosses=%d" % [
		parts.size(), abilities.size(), conditions.size(), linkages.size(),
		maps.size(), tiles.size(), crates.size(), buildings.size(), campaign.size(),
		bosses.size()
	]


func _load_into(target: Dictionary, path: String, key: String) -> void:
	var data: Variant = _read_json(path)
	if data == null:
		return
	if not (data is Array):
		errors.append("%s: expected a top-level array" % path)
		return
	for entry: Variant in (data as Array):
		if not (entry is Dictionary):
			errors.append("%s: entry is not an object" % path)
			continue
		var d: Dictionary = entry as Dictionary
		if not d.has(key):
			errors.append("%s: entry missing '%s'" % [path, key])
			continue
		var id: String = String(d[key])
		if target.has(id):
			errors.append("%s: duplicate id '%s'" % [path, id])
			continue
		target[id] = d


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("%s: not found" % path)
		return null
	var text: String = FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("%s: line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data
