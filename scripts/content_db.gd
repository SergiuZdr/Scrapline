class_name ContentDB
extends RefCounted

## Loads every piece of game content from `data/` into plain dictionaries.
##
## This lives outside `sim/` on purpose: the simulation is not allowed to touch the
## filesystem, so content is loaded once out here and handed in. That separation is
## what lets headless tools (tests, the run bot) feed the sim exactly the content the
## game has.
##
## It is a plain RefCounted rather than an autoload so that headless tools run with
## `--script` (which does not instantiate autoloads) can use it directly.

const DATA_ROOT: String = "res://data"

## Part id -> part definition, flattened across every part-type file.
var parts: Dictionary = {}
var abilities: Dictionary = {}
var conditions: Dictionary = {}
var maps: Dictionary = {}
## Terrain tile definitions, in file order -- the index IS the tile type id a map grid
## stores, so this array's order must stay stable.
var tiles: Array = []
var linkages: Array = []
## `data/combat/rules.json`: grid combat tunables.
var combat_rules: Dictionary = {}
## Fight id -> fight definition, one file per fight in `data/fights/`.
var fights: Dictionary = {}
## `data/run/run.json`: every number a run reads.
var run_rules: Dictionary = {}
## The world's words (`data/run/story.json`): briefing, acts, site text, endings. Text only,
## so it is NOT in the content hash -- rewording a line must not refuse to resume a run.
var story: Dictionary = {}
## `data/combat/abilities.json` and `data/combat/enemy_kinds.json`.
var combat_abilities: Dictionary = {}
var enemy_kinds: Dictionary = {}
var bosses: Dictionary = {}
var balance: Balance = null

var errors: PackedStringArray = []


static func load_all(root: String = DATA_ROOT) -> ContentDB:
	var db := ContentDB.new()

	for file_name: String in ["chassis", "cores", "arms", "modules"]:
		db._load_into(db.parts, "%s/parts/%s.json" % [root, file_name], "id")

	db._load_into(db.abilities, "%s/abilities/abilities.json" % root, "id")
	db._load_into(db.conditions, "%s/conditions/conditions.json" % root, "id")
	db._load_into(db.maps, "%s/maps/foundry_yard.json" % root, "id")
	db._load_into(db.bosses, "%s/bosses.json" % root, "id")


	var tile_data: Variant = db._read_json("%s/terrain/tiles.json" % root)
	if tile_data is Array:
		db.tiles = tile_data as Array

	var link_data: Variant = db._read_json("%s/linkages.json" % root)
	if link_data is Array:
		db.linkages = link_data as Array


	var run_data: Variant = db._read_json("%s/run/run.json" % root)
	if run_data is Dictionary:
		db.run_rules = run_data as Dictionary
	var story_data: Variant = db._read_json("%s/run/story.json" % root)
	if story_data is Dictionary:
		db.story = story_data as Dictionary

	for pair: Array in [["abilities", "combat_abilities"], ["enemy_kinds", "enemy_kinds"]]:
		var data: Variant = db._read_json("%s/combat/%s.json" % [root, pair[0]])
		if data is Dictionary:
			db.set(pair[1], data)

	var rules_data: Variant = db._read_json("%s/combat/rules.json" % root)
	if rules_data is Dictionary:
		db.combat_rules = rules_data as Dictionary
	# Abilities and enemy kinds travel inside the combat rules, so the sim reads them from
	# the one dictionary it is already handed.
	db.combat_rules["abilities"] = db.combat_abilities
	db.combat_rules["enemy_kinds"] = db.enemy_kinds

	# Sorted, so which file wins a duplicate id never depends on the filesystem.
	var fight_files: PackedStringArray = DirAccess.get_files_at("%s/fights" % root)
	fight_files.sort()
	for file_name: String in fight_files:
		if not file_name.ends_with(".json"):
			continue
		var fight: Variant = db._read_json("%s/fights/%s" % [root, file_name])
		if fight is Dictionary:
			db.fights[String((fight as Dictionary).get("id", file_name.get_basename()))] = fight

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


## A hash of everything the simulation reads. A saved run stores its seed and action
## log, not its state, so it only replays correctly against the content it was played
## with; the save records this hash so an update that changes the rules can be detected
## instead of silently replaying a different fight.
##
## Deterministic: keys are sorted, and only sim-relevant content is included. Cosmetic
## data and text change nothing about how a fight plays and must not invalidate a save.
func content_version() -> String:
	var hash_value: int = 0x811C9DC5
	for section: Variant in ["parts", "abilities", "conditions", "linkages", "maps", "tiles"]:
		hash_value = _hash_string(hash_value, String(section))
		hash_value = _hash_value(hash_value, to_sim_content()[section])
	hash_value = _hash_value(hash_value, combat_rules)
	hash_value = _hash_value(hash_value, fights)
	hash_value = _hash_value(hash_value, run_rules)
	hash_value = _hash_value(hash_value, combat_abilities)
	hash_value = _hash_value(hash_value, enemy_kinds)
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
	return "content=%s parts=%d abilities=%d conditions=%d linkages=%d maps=%d tiles=%d bosses=%d" % [
		content_version(), parts.size(), abilities.size(), conditions.size(),
		linkages.size(), maps.size(), tiles.size(), bosses.size()
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
