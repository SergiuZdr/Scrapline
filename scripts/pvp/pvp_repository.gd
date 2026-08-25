class_name PvpRepository
extends RefCounted

## Where defence squads and match results live.
##
## An interface with two implementations: local files today, Nakama once a server
## exists. Async PvP is the same game either way — you fight a *snapshot* of somebody's
## squad, run by *their* doctrine, and nobody has to be online. The transport is a
## detail, so it is kept behind this boundary rather than smeared through the UI.
##
## The thing that makes this shippable on day one is that the ladder is seeded with
## generated opponents. A PvP mode with no players in it is dead on arrival, and the
## first player should never see an empty ladder — so the game brings its own.

## A defence entry: whose squad, how strong, and how to fight it.
class Defence extends RefCounted:
	var id: String = ""
	var display_name: String = ""
	var rating: int = 1000
	var squad: Array = []
	var doctrine_rules: Array = []
	var power: int = 100
	var is_bot: bool = false
	var updated_at: int = 0

	func to_dict() -> Dictionary:
		return {
			"id": id, "name": display_name, "rating": rating, "squad": squad,
			"doctrine": doctrine_rules, "power": power, "bot": is_bot, "at": updated_at,
		}

	static func from_dict(d: Dictionary) -> Defence:
		var entry := Defence.new()
		entry.id = String(d.get("id", ""))
		entry.display_name = String(d.get("name", "Reclaimer"))
		entry.rating = int(d.get("rating", 1000))
		entry.squad = d.get("squad", [])
		entry.doctrine_rules = d.get("doctrine", [])
		entry.power = int(d.get("power", 100))
		entry.is_bot = bool(d.get("bot", false))
		entry.updated_at = int(d.get("at", 0))
		return entry

	## The doctrine this defence fights by. Always built from the DEFENDER's stored
	## rules -- never from anything the attacker sends, or an attacker could hand their
	## opponent a deliberately useless one.
	func doctrine() -> Doctrine:
		return Doctrine.from_array_or_default(doctrine_rules, display_name)


# --- Interface ---------------------------------------------------------------

func publish_defence(_defence: Defence) -> void:
	push_error("PvpRepository is abstract")


## Opponents near a rating. Returns at most `count`, nearest first.
func find_opponents(_rating: int, _count: int, _exclude_id: String) -> Array:
	push_error("PvpRepository is abstract")
	return []


func get_defence(_id: String) -> Defence:
	return null


func record_result(_attacker_id: String, _defender_id: String, _won: bool, _rating_delta: int) -> void:
	pass


func leaderboard(_count: int) -> Array:
	return []


## Hands a fought battle to the server for re-simulation. Offline this is a no-op: the
## client already verified itself, and there is nobody to lie to. Online it is the ONLY
## thing that makes a reported win real.
func submit_match(_submission: BattleSubmission, _defender_id: String) -> void:
	pass


func is_online() -> bool:
	return false
