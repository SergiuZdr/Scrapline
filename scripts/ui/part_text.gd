class_name PartText
extends RefCounted

## One line describing what a part DOES on the grid, read from its `grid` block.
##
## Every screen that shows a part -- salvage picks, the refit screen, the crew list --
## describes it through here, so a part cannot read as two different things on two screens.

const THUMBS: String = "res://art/thumbs/%s.png"
## Ink & Rust (016): thumbnails rendered by the game in the game's own look
## (`tools/make_ink_thumbs.gd`); the Blender renders above are the fallback.
const INK_THUMBS: String = "res://art/thumbs_ink/%s.png"
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
			var line: String = "%s · %d dmg" % [reach, int(g.get("damage", 0))]
			# A cold weapon says nothing about heat: "+0 heat" is noise on a card.
			if int(g.get("heat", 0)) > 0:
				line += " · +%d heat" % int(g.get("heat", 0))
			bits.append(line)
			var extra: PackedStringArray = []
			# The numbers are the rule (play-test 5: "how does pierce 2 work?"): pierce N goes
			# through N things, chain N jumps N times.
			for key: String in ["pierce", "chain"]:
				if int(g.get(key, 0)) > 0:
					extra.append("%s %d" % [key, int(g[key])])
			for key: String in ["splash", "shove"]:
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
			var own: Dictionary = {}
			for key: Variant in g.keys():
				if String(key) != "ability":
					own[key] = g[key]
			bits.append(bonus_text(own))
	# The ability is named, never shown as a number ("+0 ability" was play-test 2).
	var ability_id: String = String(g.get("ability", ""))
	if not ability_id.is_empty():
		var ability: Dictionary = abilities.get(ability_id, {})
		bits.append("ability: %s" % String(ability.get("name", ability_id.capitalize())))
	var tuned: String = tune_line(parts, id)
	if not tuned.is_empty():
		bits.append(tuned)
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


## A tuned part wears its base part's picture: a tuning is a number, not a new model.
static func thumb(id: String) -> Texture2D:
	id = PartTuning.base_of(id)
	if id.is_empty():
		return null
	if not _thumbs.has(id):
		var path: String = Models.thumb_path(id)
		if path.is_empty():
			path = INK_THUMBS % id
		if not ResourceLoader.exists(path):
			path = THUMBS % id
		_thumbs[id] = load(path) if ResourceLoader.exists(path) else null
	return _thumbs[id]


## The maker's short name ("KESSLER"), or "" for a part with none.
static func maker_short(makers: Dictionary, parts: Dictionary, id: String) -> String:
	var maker: String = String((parts.get(id, {}) as Dictionary).get("maker", ""))
	return String((makers.get(maker, {}) as Dictionary).get("short", maker.to_upper()))


## "tuned: Sledge Head (+1 damage)" for a tuned part, "" otherwise.
static func tune_line(parts: Dictionary, id: String) -> String:
	var part: Dictionary = parts.get(id, {})
	if not part.has("base"):
		return ""
	return "tuned: %s (%s)" % [String(part.get("tune", "")), bonus_text(part.get("tune_grid", {}))]


## The order a bonus block is read out in: what it survives, how it moves, what it hits.
const BONUS_ORDER: PackedStringArray = ["hp", "armor", "move", "damage", "melee", "range", "range_min", "pierce",
	"chain", "shove", "tears", "heat", "heat_cap", "vent", "cooldown", "unshovable", "move_after_attack"]


## A bonus block -- a tuning, a perk, a set -- in words: "+1 damage, -1 heat per attack".
## The one describer, so the same number reads the same on every screen.
static func bonus_text(grid: Dictionary) -> String:
	var bits: PackedStringArray = []
	for key: String in BONUS_ORDER:
		if not grid.has(key):
			continue
		var value: Variant = grid[key]
		var n: int = int(value) if not (value is bool) else (1 if value else 0)
		if n == 0:
			continue
		match key:
			"hp":
				bits.append("%s HP" % _signed(n))
			"armor":
				bits.append("%s armour" % _signed(n))
			"move":
				bits.append("%s move" % _signed(n))
			"damage":
				bits.append("%s damage" % _signed(n))
			"melee":
				bits.append("%s melee damage" % _signed(n))
			"range":
				bits.append("%s range" % _signed(n))
			"range_min":
				bits.append("lobs %d hex closer" % absi(n))
			"pierce":
				bits.append("%s pierce" % _signed(n))
			"chain":
				bits.append("%s chain jump" % _signed(n))
			"shove":
				bits.append("shoves")
			"tears":
				bits.append("tears arms off")
			"heat":
				bits.append("%s heat per attack" % _signed(n))
			"heat_cap":
				bits.append("%s heat cap" % _signed(n))
			"vent":
				bits.append("vents %d more" % n)
			"cooldown":
				bits.append("abilities ready %d round%s sooner" % [n, "" if n == 1 else "s"])
			"unshovable":
				bits.append("cannot be shoved")
			"move_after_attack":
				bits.append("moves after attacking")
	return ", ".join(bits)


static func _signed(n: int) -> String:
	return ("+%d" % n) if n >= 0 else ("%d" % n)


## One line per maker set a loadout has going: "KESSLER x3 · +2 HP · +1 armour". Read off
## `CombatSetup.sets_of`, the same count the fight applies.
static func set_lines(parts: Dictionary, makers: Dictionary, part_ids: Array) -> PackedStringArray:
	var out: PackedStringArray = []
	for entry: Dictionary in CombatSetup.sets_of(PackedStringArray(part_ids), parts, makers):
		var maker: Dictionary = makers.get(String(entry["maker"]), {})
		var gains: PackedStringArray = []
		for tier: Variant in (entry["active"] as Array):
			gains.append(bonus_text(((maker.get("sets", {}) as Dictionary).get(str(tier), {})) as Dictionary))
		out.append("%s x%d  ·  %s" % [String(maker.get("short", entry["maker"])), int(entry["count"]), "  ·  ".join(gains)])
	return out
