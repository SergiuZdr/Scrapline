class_name Campaign
extends RefCounted

## The PvE ladder: thirty nodes across three zones.
##
## Its job in Phase 2 is to teach. Squads start at three units and grow to six,
## Conditions only appear once the basics are established, and every third node hands
## out a specific part rather than currency — so progress is felt as *new options*
## rather than only as bigger numbers, which is what keeps a collection game from
## reading as a treadmill in its first hour.
##
## Nodes are strictly sequential for now. That is deliberate for a first pass: a linear
## spine is the easiest thing to tune difficulty against, and branching can be added
## once the curve is known to work.


static func node(content: ContentDB, node_id: String) -> Dictionary:
	return content.campaign.get(node_id, {})


## All nodes in play order. Sorted by id, which encodes zone and step, so this never
## depends on Dictionary key order.
static func ordered_nodes(content: ContentDB) -> Array:
	var ids: Array = content.campaign.keys()
	ids.sort()
	var out: Array = []
	for id: Variant in ids:
		out.append(content.campaign[id])
	return out


static func is_unlocked(profile: PlayerProfile, content: ContentDB, node_id: String) -> bool:
	var definition: Dictionary = node(content, node_id)
	if definition.is_empty():
		return false
	for required: Variant in definition.get("requires", []):
		if not profile.has_cleared(String(required)):
			return false
	return true


## The furthest node the player can attempt: the first unlocked node not yet cleared.
## This is what the campaign screen should open on.
static func next_node(profile: PlayerProfile, content: ContentDB) -> Dictionary:
	for definition: Variant in ordered_nodes(content):
		var d: Dictionary = definition as Dictionary
		var id: String = String(d["id"])
		if not profile.has_cleared(id) and is_unlocked(profile, content, id):
			return d
	return {}


static func progress(profile: PlayerProfile, content: ContentDB) -> Dictionary:
	var total: int = content.campaign.size()
	var cleared: int = 0
	for definition: Variant in ordered_nodes(content):
		if profile.has_cleared(String((definition as Dictionary)["id"])):
			cleared += 1
	return {"cleared": cleared, "total": total, "percent": (cleared * 100) / maxi(1, total)}


## Builds the battle for a node: the player's squad against the node's, on its map and
## under its Condition.
static func build_setup(
	profile: PlayerProfile, content: ContentDB, node_id: String,
	squad_name: String = "main", seed_value: int = 0
) -> BattleSetup:
	var definition: Dictionary = node(content, node_id)
	if definition.is_empty():
		return null
	return BattleSetup.make(
		seed_value,
		Economy.squad_with_power(profile, content, squad_name),
		definition.get("enemy", []),
		String(definition.get("condition", "")),
		String(definition.get("map", "")))


## Everything a first clear pays out. Returned as commands so the whole payout lands in
## the log as one atomic batch alongside the win record.
static func reward_commands(
	profile: PlayerProfile, content: ContentDB, node_id: String
) -> Array:
	var definition: Dictionary = node(content, node_id)
	if definition.is_empty():
		return []

	var first_clear: bool = not profile.has_cleared(node_id)
	var commands: Array = []
	var reward: Dictionary = definition.get("reward", {})

	# Replays pay a fraction. Enough that grinding a cleared node is a real option when
	# you are short of scrap, not so much that it beats pushing forward.
	var scale: int = 100 if first_clear else 30

	var scrap: int = (int(reward.get("scrap", 0)) * scale) / 100
	if scrap > 0:
		commands.append(ProfileCommands.GrantCurrency.new(PlayerProfile.SCRAP, scrap, "campaign:" + node_id))

	var alloy: int = (int(reward.get("alloy", 0)) * scale) / 100
	if alloy > 0:
		commands.append(ProfileCommands.GrantCurrency.new(PlayerProfile.ALLOY, alloy, "campaign:" + node_id))

	# Part rewards are first clear only. A repeatable part faucet would make crates
	# pointless and flood the Refit economy with duplicates.
	if first_clear:
		var reward_part: Variant = definition.get("first_clear_part", "")
		var part_id: String = String(reward_part) if reward_part != null else ""
		if not part_id.is_empty() and content.parts.has(part_id):
			commands.append(ProfileCommands.GrantPart.new(part_id))

	commands.append(ProfileCommands.RecordBattle.new(true, node_id))
	return commands
