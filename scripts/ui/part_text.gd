class_name PartText
extends RefCounted

## One line describing what a part DOES on the grid, read from its `grid` block.
##
## Every screen that shows a part -- salvage picks, the refit screen, the crew list --
## describes it through here, so a part cannot read as two different things on two screens.

## Ink & Rust (016): thumbnails rendered by the game in the game's own look
## (`tools/make_ink_thumbs.gd`).
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
			# 029: the new families say what they do.
			if shape == "cone":
				line = "flame cone · %d dmg to 4 hexes" % int(g.get("damage", 0))
			elif shape == "shield":
				line = "shields an ally %d · -%d per hit" % [int(g.get("range", 1)), int(g.get("damage", 0))]
			elif shape == "sweep":
				line = "flail · %d dmg to 3 hexes" % int(g.get("damage", 0))
			elif shape == "mine":
				line = "lays a mine %d-%d · %d dmg" % [int(g.get("range_min", 1)), int(g.get("range", 1)), int(g.get("damage", 0))]
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
			if int(g.get("pull", 0)) > 0:
				extra.append("drags")
			if int(g.get("snare", 0)) > 0:
				extra.append("snares")
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
			# 033: what a core does beyond its numbers (pierce, arcs, hp...).
			var more: Dictionary = {}
			for key: Variant in g.keys():
				if not ["damage", "heat", "vent", "ability"].has(String(key)):
					more[key] = g[key]
			if not more.is_empty():
				bits.append(bonus_text(more))
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
## The legendary tier (029): a hot orange-red, nothing else on a card is.
const LEGENDARY := Color("e0552a")


static func rarity_colour(parts: Dictionary, id: String) -> Color:
	match int((parts.get(id, {}) as Dictionary).get("rarity", 1)):
		2:
			return UIKit.BLUE
		3:
			return UIKit.GOLD
		4:
			return LEGENDARY
	return UIKit.TEXT_DIM


## A tuned part wears its base part's picture: a tuning is a number, not a new model.
static func thumb(id: String) -> Texture2D:
	id = Models.draw_id(id)
	if id.is_empty():
		return null
	if not _thumbs.has(id):
		var path: String = Models.thumb_path(id)
		if path.is_empty():
			path = INK_THUMBS % id
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
	return "upgraded: %s (%s)" % [String(part.get("tune", "")), bonus_text(part.get("tune_grid", {}))]


## The order a bonus block is read out in: what it survives, how it moves, what it hits.
const BONUS_ORDER: PackedStringArray = ["hp", "armor", "move", "damage", "melee", "range", "range_min", "pierce",
	"chain", "arc", "mark", "shove", "tears", "heat", "heat_cap", "vent", "cooldown", "unshovable", "move_after_attack",
	"thorns", "regen", "kill_heal", "last_stand"]


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
				bits.append("%s pierce on shots" % _signed(n))
			"chain":
				bits.append("%s chain jump" % _signed(n))
			"arc":
				bits.append("shots arc to %d more" % n)
			"mark":
				bits.append("every hit marks")
			"shove":
				bits.append("melee shoves")
			"tears":
				# 086: `tears N` (N > 1) tears at N damage instead of the rule's own threshold.
				bits.append("melee tears arms off" if n <= 1 else "melee hits of %d+ tear an arm off" % n)
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
			"thorns":
				bits.append("melee attackers take %d" % n)
			"regen":
				bits.append("repairs %d HP a round" % n)
			"kill_heal":
				bits.append("+%d HP per kill" % n)
			"last_stand":
				bits.append("survives its first wreck at 1 HP")
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


# --- 086: rules, not numbers ---------------------------------------------------

## The verb each rule key gives a machine, said in one word on cards, perks and sets.
const RULE_VERBS: Dictionary = {"tears": "TEARS", "pierce": "PIERCES", "arc": "ARCS", "mark": "MARKS",
	"kill_heal": "SCAVENGES", "thorns": "THORNS", "unshovable": "ANCHORED", "shove": "SHOVES",
	"chain": "CHAINS", "move_after_attack": "FIRES ON THE MOVE", "regen": "REPAIRS", "last_stand": "LAST STAND"}
## The keys that make a perk a RULE perk (A8): what it does changes, not how much.
const RULE_PERK_KEYS: PackedStringArray = ["tears", "pierce", "arc", "mark", "kill_heal", "thorns"]


## The verbs a bonus block adds, in the describer's order: ["THORNS", "ANCHORED"].
static func rule_verbs(grid: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for key: String in BONUS_ORDER:
		if RULE_VERBS.has(key) and grid.has(key) and _on(grid[key]):
			out.append(String(RULE_VERBS[key]))
	return out


## Each verb with what it does: ["+ TEARS: melee hits of 4+ tear an arm off"].
static func verb_lines(grid: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for key: String in BONUS_ORDER:
		if RULE_VERBS.has(key) and grid.has(key) and _on(grid[key]):
			out.append("+ %s: %s" % [String(RULE_VERBS[key]), bonus_text({key: grid[key]})])
	return out


## A perk that changes a rule (`"rule": true`, or a rule key in its grid), not only a number.
static func is_rule_perk(perk: Dictionary) -> bool:
	if bool(perk.get("rule", false)):
		return true
	var g: Dictionary = perk.get("grid", {})
	for key: String in RULE_PERK_KEYS:
		if g.has(key) and _on(g[key]):
			return true
	return false


static func _on(value: Variant) -> bool:
	return bool(value) if value is bool else int(value) != 0


## A legendary's rule and its drawback (A9), from the part's data; "" when it has none. A tuned
## legendary speaks with its base part's.
static func rule_of(parts: Dictionary, id: String) -> String:
	return _legend_text(parts, id, "rule")


static func drawback_of(parts: Dictionary, id: String) -> String:
	return _legend_text(parts, id, "drawback")


static func _legend_text(parts: Dictionary, id: String, key: String) -> String:
	for which: String in [id, PartTuning.base_of(id)]:
		var v: Variant = (parts.get(which, {}) as Dictionary).get(key, "")
		if v is String and not String(v).is_empty():
			return String(v)
		if v is Dictionary and not String((v as Dictionary).get("text", "")).is_empty():
			return String((v as Dictionary)["text"])
	return ""


## A maker's set rule: the verbs of the tier that has any (the 3-piece, A10), or [] for none.
## `[tier, verbs]`.
static func set_rule(makers: Dictionary, maker: String) -> Array:
	var sets: Dictionary = (makers.get(maker, {}) as Dictionary).get("sets", {})
	var tiers: Array = sets.keys()
	tiers.sort_custom(func(a: Variant, b: Variant) -> bool: return int(str(a)) > int(str(b)))
	for tier: Variant in tiers:
		var verbs: PackedStringArray = rule_verbs(sets[tier] as Dictionary)
		if not verbs.is_empty():
			return [int(str(tier)), verbs]
	return []


## Per maker on a loadout, how far its set has come (A10): `{maker, short, count, full, verbs,
## complete}` sorted by maker id; `full` is the tier its rule needs (3 when it has none).
static func set_progress(parts: Dictionary, makers: Dictionary, part_ids: Array) -> Array:
	var counts: Dictionary = {}
	for id: Variant in part_ids:
		var maker: String = String((parts.get(String(id), {}) as Dictionary).get("maker", ""))
		if not String(id).is_empty() and makers.has(maker):
			counts[maker] = int(counts.get(maker, 0)) + 1
	var names: Array = counts.keys()
	names.sort()
	var out: Array = []
	for maker: Variant in names:
		var rule: Array = set_rule(makers, String(maker))
		var full: int = int(rule[0]) if not rule.is_empty() else 3
		out.append({"maker": String(maker), "short": String((makers[maker] as Dictionary).get("short", String(maker).to_upper())),
			"count": int(counts[maker]), "full": full, "verbs": rule[1] if not rule.is_empty() else PackedStringArray(),
			"complete": int(counts[maker]) >= full})
	return out


## "KESSLER 2/3 · at 3: THORNS + ANCHORED", or "KESSLER 3/3 · THORNS + ANCHORED" once complete.
static func set_progress_line(entry: Dictionary) -> String:
	var verbs: PackedStringArray = entry["verbs"]
	var head: String = "%s %d/%d" % [String(entry["short"]), mini(int(entry["count"]), int(entry["full"])), int(entry["full"])]
	if verbs.is_empty():
		return head
	return "%s  ·  %s%s" % [head, "" if bool(entry["complete"]) else "at %d: " % int(entry["full"]), " + ".join(verbs)]


## 086 (A5): an elite affix's `{name, text}`, from enemy_kinds.json's `elite_affixes` block, else from
## its glossary card; the id in capitals when neither knows it.
static func affix(enemy_kinds: Dictionary, glossary: Dictionary, id: String) -> Dictionary:
	var own: Dictionary = (enemy_kinds.get("elite_affixes", {}) as Dictionary).get(id, {})
	var term: Dictionary = (glossary.get("terms", {}) as Dictionary).get(id, {})
	return {"name": String(own.get("name", term.get("name", id.capitalize()))).to_upper(),
		"text": String(own.get("text", term.get("text", "")))}


## The affixes a fight spec or a unit carries: `affix` (one id) or `affixes` (a list), [] for none.
static func affixes_of(carrier: Variant) -> PackedStringArray:
	var out: PackedStringArray = []
	var one: Variant = null
	var many: Variant = null
	if carrier is Dictionary:
		one = (carrier as Dictionary).get("affix", null)
		many = (carrier as Dictionary).get("affixes", null)
	elif carrier is Object:
		one = (carrier as Object).get("affix")
		many = (carrier as Object).get("affixes")
	if one is String and not String(one).is_empty():
		out.append(String(one))
	if many is Array or many is PackedStringArray:
		for id: Variant in many:
			if not String(id).is_empty() and not out.has(String(id)):
				out.append(String(id))
	return out
