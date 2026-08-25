class_name ProfileCommand
extends RefCounted

## Every change to a player's profile is a command.
##
## The pattern is carried over from Flock, and it earns its keep three times here:
##
##   - **Saving** is just "apply commands, then serialise" -- there is no separate
##     write path that can forget a field.
##   - **Server reconciliation** (Phase 4) becomes replaying a command log against the
##     server's copy, rather than diffing two dictionaries and hoping.
##   - **Auditing** an economy needs a record of what was granted and spent. A
##     free-to-play game that cannot answer "where did this player's premium currency
##     come from" cannot handle a refund dispute or spot an exploit.
##
## Commands validate first and mutate second, so a rejected command leaves the profile
## exactly as it was.

## Why a command was refused. Callers show these to the player, so they are reasons,
## not error codes.
enum Result { OK, NOT_ENOUGH_CURRENCY, NOT_OWNED, ALREADY_MAX, NOT_ENOUGH_COPIES, INVALID }

var kind: String = ""


## Checks whether this command could be applied, without changing anything.
func validate(_profile: PlayerProfile, _content: ContentDB) -> int:
	return Result.INVALID


## Applies the command. Callers must have validated first; implementations may assume
## validation passed, but should still be safe if it did not.
func apply(_profile: PlayerProfile, _content: ContentDB) -> void:
	pass


## Serialised form, for the command log and later for server submission.
func to_dict() -> Dictionary:
	return {"kind": kind}


static func result_name(result: int) -> String:
	match result:
		Result.OK: return "ok"
		Result.NOT_ENOUGH_CURRENCY: return "not enough currency"
		Result.NOT_OWNED: return "part not owned"
		Result.ALREADY_MAX: return "already at maximum"
		Result.NOT_ENOUGH_COPIES: return "not enough duplicates"
		_: return "invalid"


# --- Shared helpers ----------------------------------------------------------

## Writes a currency change straight into the profile dictionary. Only commands call
## this; nothing else in the codebase may touch currency.
static func adjust_currency(profile: PlayerProfile, kind_name: String, delta: int) -> void:
	var currencies: Dictionary = profile.data["currencies"]
	currencies[kind_name] = maxi(0, int(currencies.get(kind_name, 0)) + delta)


static func ensure_entry(profile: PlayerProfile, part_id: String) -> Dictionary:
	var inventory: Dictionary = profile.inventory()
	if not inventory.has(part_id):
		inventory[part_id] = {"level": 1, "copies": 0, "tier": 0}
	return inventory[part_id]
