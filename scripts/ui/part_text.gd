class_name PartText
extends RefCounted

## One line describing what a part DOES on the grid, read from its `grid` block.
##
## Every screen that shows a part -- salvage picks, the refit screen, the crew list --
## describes it through here, so a part cannot read as two different things on two screens.

const THUMBS: String = "res://art/thumbs/%s.png"
static var _thumbs: Dictionary = {}


static func name_of(parts: Dictionary, id: String) -> String:
	if id.is_empty():
		return "Empty"
	return String((parts.get(id, {}) as Dictionary).get("name", id))


static func slot_label(parts: Dictionary, id: String) -> String:
	return String((parts.get(id, {}) as Dictionary).get("slot", "")).to_upper()


## `abilities`: ContentDB.combat_abilities, to name the ability a chassis or module gives.
static func summary(parts: Dictionary, id: String, abilities: Dictionary = {}) -> String:
	if id.is_empty():
		return "Nothing fitted"
	var part: Dictionary = parts.get(id, {})
	var g: Dictionary = part.get("grid", {})
	var bits: PackedStringArray = []
	match String(part.get("slot", "")):
		"chassis":
			bits.append("%d HP · move %d · heat cap %d" % [int(g.get("hp", 0)), int(g.get("move", 0)), int(g.get("heat_cap", 0))])
			bits.append("%s · %s" % [String(part.get("role", "")), String(part.get("armor_type", ""))])
		"arm":
			var shape: String = String(g.get("shape", "melee"))
			var reach: String = "melee" if shape == "melee" else ("lob %d-%d" % [int(g.get("range_min", 1)), int(g.get("range", 1))] if shape == "lob"
				else "shot %d" % int(g.get("range", 1)))
			bits.append("%s · %d dmg · +%d heat" % [reach, int(g.get("damage", 0)), int(g.get("heat", 0))])
			var extra: PackedStringArray = []
			for key: String in ["pierce", "splash", "shove", "chain"]:
				if int(g.get(key, 0)) > 0:
					extra.append(key)
			if bool(g.get("mark", false)):
				extra.append("marks")
			if bool(g.get("tears", false)):
				extra.append("tears arms")
			if not extra.is_empty():
				bits.append(", ".join(extra))
		"core":
			bits.append(String(part.get("damage_type", "")))
			if int(g.get("damage", 0)) > 0:
				bits.append("+%d dmg" % int(g.get("damage", 0)))
			if int(g.get("heat", 0)) > 0:
				bits.append("+%d heat" % int(g.get("heat", 0)))
			bits.append("vent %d" % int(g.get("vent", 1)))
		"module":
			for key: Variant in g.keys():
				if String(key) != "ability":
					bits.append("+%d %s" % [int(g[key]), String(key).replace("_", " ")])
	# The ability is named, never shown as a number ("+0 ability" was play-test 2).
	var ability_id: String = String(g.get("ability", ""))
	if not ability_id.is_empty():
		var ability: Dictionary = abilities.get(ability_id, {})
		bits.append("ability: %s" % String(ability.get("name", ability_id.capitalize())))
	return " · ".join(bits)


## Rarity as a colour. Gold was reserved for premium currency; the game has none now,
## so gold marks the rarest salvage instead.
static func rarity_colour(parts: Dictionary, id: String) -> Color:
	match int((parts.get(id, {}) as Dictionary).get("rarity", 1)):
		2:
			return UIKit.BLUE
		3:
			return UIKit.GOLD
	return UIKit.TEXT_DIM


static func thumb(id: String) -> Texture2D:
	if id.is_empty():
		return null
	if not _thumbs.has(id):
		var path: String = THUMBS % id
		_thumbs[id] = load(path) if ResourceLoader.exists(path) else null
	return _thumbs[id]
