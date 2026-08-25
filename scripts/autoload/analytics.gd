extends Node

## Local funnel analytics.
##
## Phase 3's kill gate is *"give it to five strangers — do three reach the Foundry
## without being told how?"*. That is only answerable if the game records where people
## actually stop, so this exists to make the gate measurable rather than a feeling.
##
## Everything is written to a local JSONL file. **Nothing leaves the device.** There is
## no network here and there should not be one until there is a privacy policy and a
## consent prompt to go with it — which is Phase 6 work, not Phase 3.
##
## The funnel is deliberately short. Five or six events you will actually read beat
## fifty you will not, and every extra event is another thing to keep correct.

const LOG_PATH: String = "user://analytics.jsonl"
const MAX_LINES: int = 4000

## The steps a new player has to walk through. Order matters: `funnel()` reports the
## furthest step reached, which is the number the kill gate actually asks for.
const FUNNEL: PackedStringArray = [
	"app_open",
	"battle_started",
	"battle_won",
	"foundry_opened",
	"collected",
	"part_levelled",
	"crate_opened",
	"node_2_cleared",
]

var _seen: Dictionary = {}
var _session_start: int = 0


func _ready() -> void:
	_session_start = int(Time.get_unix_time_from_system())
	_load_seen()
	track("app_open")


## Records an event. `once` marks milestones that should only ever fire the first time,
## which is what keeps a funnel readable -- a player who opens forty crates should not
## drown the log.
func track(event: String, data: Dictionary = {}, once: bool = false) -> void:
	if once and _seen.has(event):
		return
	_seen[event] = true

	var record: Dictionary = {
		"t": int(Time.get_unix_time_from_system()),
		"session_s": int(Time.get_unix_time_from_system()) - _session_start,
		"event": event,
	}
	if not data.is_empty():
		record["data"] = data

	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(record))
	file.close()


## Milestones fire once per player, ever. They are the funnel.
func milestone(event: String, data: Dictionary = {}) -> void:
	track(event, data, true)


## How far the player got. This is the kill-gate answer.
func funnel() -> Dictionary:
	var reached: int = 0
	var steps: Dictionary = {}
	for index: int in FUNNEL.size():
		var step: String = FUNNEL[index]
		var hit: bool = _seen.has(step)
		steps[step] = hit
		if hit:
			reached = index + 1
	return {"reached": reached, "of": FUNNEL.size(), "steps": steps}


func summary() -> String:
	var f: Dictionary = funnel()
	var line: String = "funnel %d/%d" % [int(f["reached"]), int(f["of"])]
	for step: String in FUNNEL:
		line += "\n  %s %s" % ["x" if bool((f["steps"] as Dictionary)[step]) else " ", step]
	return line


func reset() -> void:
	_seen.clear()
	if FileAccess.file_exists(LOG_PATH):
		DirAccess.open("user://").remove(LOG_PATH)


## Rebuilds the seen-set from the log so milestones stay once-per-player across
## sessions rather than once-per-launch.
func _load_seen() -> void:
	if not FileAccess.file_exists(LOG_PATH):
		return
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.READ)
	if file == null:
		return
	var lines: int = 0
	while not file.eof_reached():
		var line: String = file.get_line()
		lines += 1
		if line.is_empty():
			continue
		var json := JSON.new()
		if json.parse(line) == OK and json.data is Dictionary:
			_seen[String((json.data as Dictionary).get("event", ""))] = true
	file.close()

	# A log this long is a dev machine, not a player. Truncating keeps the file from
	# growing without bound during development.
	if lines > MAX_LINES:
		DirAccess.open("user://").remove(LOG_PATH)
