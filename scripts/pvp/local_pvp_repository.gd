class_name LocalPvpRepository
extends PvpRepository

## The offline implementation: defences on disk, plus a generated bot ladder.
##
## This exists so async PvP is playable and testable before a server exists, and so the
## Nakama swap is a one-line change rather than a rewrite. It is also what a player gets
## when they are offline, which is the normal state of a mobile game on a train.
##
## **The bot ladder is the important part.** A new competitive mode has no players in
## it, and "no opponents found" on day one kills the mode permanently. Bots are
## generated from a seeded ladder so every player meets the same opponent at the same
## rating, which keeps early ranked play fair and comparable.

const DIR: String = "user://pvp"
const DEFENCE_PATH: String = "user://pvp/defences.json"
const BOT_COUNT: int = 60
const BOT_MIN_RATING: int = 700
const BOT_MAX_RATING: int = 2200

var _content: ContentDB
var _defences: Dictionary = {}
var _loaded: bool = false


static func open(content: ContentDB) -> LocalPvpRepository:
	var repo := LocalPvpRepository.new()
	repo._content = content
	repo._load()
	return repo


func is_online() -> bool:
	return false


func publish_defence(defence: Defence) -> void:
	defence.updated_at = int(Time.get_unix_time_from_system())
	# There is exactly one human on a local ladder. A defence published under a previous
	# profile id is an orphan the player would otherwise meet -- and be able to attack
	# themselves, for rating. Drop them rather than leave them lying in the file.
	if not defence.is_bot:
		for id: Variant in _defences.keys():
			if String(id) != defence.id and not (_defences[id] as Defence).is_bot:
				_defences.erase(id)
	_defences[defence.id] = defence
	_save()


func get_defence(id: String) -> Defence:
	return _defences.get(id)


## Opponents nearest the given rating. Sorted by rating distance so a player always
## faces someone plausible, with the id tiebreak keeping the list stable.
func find_opponents(rating: int, count: int, exclude_id: String) -> Array:
	var candidates: Array = []
	for id: Variant in _defences.keys():
		if String(id) == exclude_id:
			continue
		candidates.append(_defences[id])

	candidates.sort_custom(func(a: Defence, b: Defence) -> bool:
		var da: int = absi(a.rating - rating)
		var db: int = absi(b.rating - rating)
		if da != db:
			return da < db
		return a.id < b.id)

	return candidates.slice(0, mini(count, candidates.size()))


func record_result(attacker_id: String, defender_id: String, won: bool, rating_delta: int) -> void:
	# A defender's rating moves when they are attacked, even though they were not
	# present. That is what makes an idle ladder still a ladder.
	var defender: Defence = _defences.get(defender_id)
	if defender != null:
		defender.rating = maxi(0, defender.rating - rating_delta if won else defender.rating + rating_delta)
		_save()
	var _unused: String = attacker_id


func leaderboard(count: int) -> Array:
	var all: Array = _defences.values()
	all.sort_custom(func(a: Defence, b: Defence) -> bool:
		if a.rating != b.rating:
			return a.rating > b.rating
		return a.id < b.id)
	return all.slice(0, mini(count, all.size()))


# --- Storage -----------------------------------------------------------------

func _load() -> void:
	if _loaded:
		return
	_loaded = true

	if FileAccess.file_exists(DEFENCE_PATH):
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(DEFENCE_PATH)) == OK and json.data is Array:
			for entry: Variant in (json.data as Array):
				var defence: Defence = Defence.from_dict(entry as Dictionary)
				_defences[defence.id] = defence

	# Top up with bots if the ladder is thin. Runs on first launch and any time bots
	# have been beaten off the bottom of the table.
	if _defences.size() < BOT_COUNT:
		_seed_bots()
		_save()


func _save() -> void:
	if not DirAccess.dir_exists_absolute(DIR):
		DirAccess.make_dir_recursive_absolute(DIR)
	var out: Array = []
	var ids: Array = _defences.keys()
	ids.sort()
	for id: Variant in ids:
		out.append((_defences[id] as Defence).to_dict())
	var file: FileAccess = FileAccess.open(DEFENCE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(out, "\t"))
		file.close()


## Generates the bot ladder. Deterministic in the bot index, so every player faces the
## same opponent at the same rung and early ranked results are comparable between
## players -- which matters once there is a real leaderboard to sit alongside it.
func _seed_bots() -> void:
	var names: PackedStringArray = [
		"Tallow", "Verge", "Kiln Rat", "Offcut", "Deadweight", "Ninefold", "Cinderhand",
		"Bracket", "Longtooth", "Muster", "Cold Iron", "Halfpenny", "Ratchet Kate",
		"Sump", "Overburden", "Ashfall", "Tap Six", "Gantry", "Bell", "Quench",
	]
	for index: int in BOT_COUNT:
		var id: String = "bot_%03d" % index
		if _defences.has(id):
			continue

		var rng := SimRNG.new(0xB07 + index * 7919)
		# Rating climbs smoothly across the ladder so there is always someone slightly
		# above the player to chase, at every level.
		var rating: int = BOT_MIN_RATING + (BOT_MAX_RATING - BOT_MIN_RATING) * index / maxi(1, BOT_COUNT - 1)
		# Bot power tracks its rating: a 2200 defence is genuinely a stronger squad, not
		# the same squad with a bigger number next to it.
		var power: int = 100 + (rating - BOT_MIN_RATING) * 90 / maxi(1, BOT_MAX_RATING - BOT_MIN_RATING)

		var defence := Defence.new()
		defence.id = id
		defence.display_name = "%s" % names[index % names.size()] if index < names.size() \
			else "%s %d" % [names[index % names.size()], index / names.size() + 1]
		defence.rating = rating
		defence.power = power
		defence.is_bot = true
		defence.squad = _bot_squad(rng, power, rating)
		defence.doctrine_rules = Doctrine.default_doctrine().to_array()
		defence.updated_at = 0
		_defences[id] = defence


func _bot_squad(rng: SimRNG, power: int, rating: int) -> Array:
	var pools: Dictionary = {}
	for slot: String in ["chassis", "core", "arm", "module"]:
		pools[slot] = _pool(slot)

	# Squad size and part quality both rise with rating, so climbing the ladder means
	# meeting more constructs AND better ones.
	var size: int = SimMath.clamp_int(3 + (rating - BOT_MIN_RATING) * 3 / maxi(1, BOT_MAX_RATING - BOT_MIN_RATING),
		3, SimDefs.SQUAD_SIZE)
	var band: int = SimMath.clamp_int(
		2 + (rating - BOT_MIN_RATING) * 8 / maxi(1, BOT_MAX_RATING - BOT_MIN_RATING), 2, 10)

	var squad: Array = []
	for slot_index: int in size:
		squad.append({
			"name": "Unit %d" % (slot_index + 1),
			"power": power,
			"parts": {
				"chassis": _pick(rng, pools["chassis"], band),
				"core": _pick(rng, pools["core"], band),
				"arm_l": _pick(rng, pools["arm"], band),
				"arm_r": _pick(rng, pools["arm"], band),
				"module": _pick(rng, pools["module"], band),
			},
		})
	return squad


## Part ids for a slot, sorted by rarity then id -- so `band` means "the commonest N"
## and the ladder cannot shift when content files are reordered.
func _pool(slot: String) -> PackedStringArray:
	var entries: Array = []
	for id: Variant in _content.parts.keys():
		var part: Dictionary = _content.parts[id]
		if String(part.get("slot", "")) == slot:
			entries.append([int(part.get("rarity", 1)), String(id)])
	entries.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] < b[0]
		return String(a[1]) < String(b[1]))
	var out: PackedStringArray = []
	for entry: Variant in entries:
		out.append(String((entry as Array)[1]))
	return out


func _pick(rng: SimRNG, pool: PackedStringArray, band: int) -> String:
	if pool.is_empty():
		return ""
	return pool[rng.range_int(0, mini(band, pool.size()) - 1)]
