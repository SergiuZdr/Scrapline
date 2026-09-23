class_name ProfileStore
extends RefCounted

## Runs commands against a profile and keeps the log.
##
## This is the only object in the game permitted to change player state. Everything
## else -- UI, campaign, crates, battle rewards -- builds a command and hands it here.
## The single choke point is what makes saving, auditing and (in Phase 4) server
## reconciliation one mechanism instead of three.

signal profile_changed()
signal command_rejected(command: ProfileCommand, result: int)

## Commands applied since load, in order. Phase 4 submits this to the server; until
## then it is an audit trail and a debugging aid.
var command_log: Array[Dictionary] = []

var profile: PlayerProfile
var content: ContentDB
var _save_path: String = SaveFile.SAVE_PATH
var _dirty: bool = false


static func open(content_db: ContentDB, path: String = SaveFile.SAVE_PATH) -> ProfileStore:
	var store := ProfileStore.new()
	store.content = content_db
	store._save_path = path

	var file: SaveFile = SaveFile.load_from(path)
	store.profile = PlayerProfile.from_save(file)
	if not file.message.is_empty():
		print("profile: ", file.message)

	Economy.configure(content_db.economy)
	return store


## Validates and applies a command. Returns the result so callers can show the player
## why something was refused, rather than a button that silently does nothing.
func execute(command: ProfileCommand) -> int:
	var result: int = command.validate(profile, content)
	if result != ProfileCommand.Result.OK:
		command_rejected.emit(command, result)
		return result

	command.apply(profile, content)
	command_log.append(command.to_dict())
	_dirty = true
	profile_changed.emit()
	return ProfileCommand.Result.OK


## Applies several commands as a unit. If any one fails validation, none are applied --
## a battle reward that grants scrap and then fails to record the win would otherwise
## leave the profile in a state no sequence of player actions could produce.
func execute_batch(commands: Array) -> int:
	for command: ProfileCommand in commands:
		var result: int = command.validate(profile, content)
		if result != ProfileCommand.Result.OK:
			command_rejected.emit(command, result)
			return result

	for command: ProfileCommand in commands:
		command.apply(profile, content)
		command_log.append(command.to_dict())

	_dirty = true
	profile_changed.emit()
	return ProfileCommand.Result.OK


## Whether a command would succeed, without doing it. UI uses this to disable a button
## and explain why, instead of letting the player find out by tapping.
func can_execute(command: ProfileCommand) -> int:
	return command.validate(profile, content)


func save() -> bool:
	if not _dirty:
		return true
	var ok: bool = SaveFile.save_to(profile.data, _save_path)
	if ok:
		_dirty = false
	return ok


func is_dirty() -> bool:
	return _dirty


## Convenience for the most common batch in the game: paying out a finished battle.
func award_battle(won: bool, cycles: int, node_id: String = "") -> int:
	var commands: Array = [
		ProfileCommands.GrantCurrency.new(
			PlayerProfile.SCRAP, Economy.battle_reward_scrap(won, cycles), "battle"),
		ProfileCommands.RecordBattle.new(won, node_id),
	]
	var alloy: int = Economy.battle_reward_alloy(won)
	if alloy > 0:
		commands.insert(1, ProfileCommands.GrantCurrency.new(PlayerProfile.ALLOY, alloy, "battle"))
	return execute_batch(commands)
