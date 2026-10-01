class_name PartTuning
extends RefCounted

## Tuned parts (011). A workshop can re-cut a part ONE of two ways, once
## (`docs/plans/constructs-and-parts.md`): every part carries its two options in its JSON as
## `"tuning": [{ "name", "grid" }, { "name", "grid" }]`.
##
## A tuned part is content, not state. `expand` turns each option into a real part entry --
## `ar_hammer:a`, `ar_hammer:b` -- with the option's grid merged in, so every lookup that
## already works on a part id (the fight's numbers, the part's text, its rarity, its slot, its
## maker) works on a tuned one unchanged. Pools and the assembly bench leave them out; the
## visuals draw the base part (`base_of`).
##
## Pure: called by `ContentDB` on the dictionaries it loaded.

const OPTIONS: PackedStringArray = ["a", "b"]


## Adds every part's tuned variants to `parts`, in place. Numbers in an option's grid are
## ADDED to the part's (a negative number takes off: "heat": -1); anything else is set.
static func expand(parts: Dictionary) -> void:
	var ids: Array = parts.keys()
	ids.sort()
	for id: Variant in ids:
		var part: Dictionary = parts[id]
		if part.has("base"):
			continue
		var options: Array = part.get("tuning", [])
		for index: int in mini(options.size(), OPTIONS.size()):
			var option: Dictionary = options[index]
			var tuned: Dictionary = part.duplicate(true)
			var grid: Dictionary = tuned.get("grid", {})
			var delta: Dictionary = option.get("grid", {})
			var keys: Array = delta.keys()
			keys.sort()
			for key: Variant in keys:
				var value: Variant = delta[key]
				if (value is int or value is float) and not (value is bool):
					grid[key] = int(grid.get(key, 0)) + int(value)
				else:
					grid[key] = value
			tuned["grid"] = grid
			tuned["id"] = variant(String(id), index)
			tuned["base"] = String(id)
			tuned["tuned"] = OPTIONS[index]
			tuned["tune"] = String(option.get("name", ""))
			tuned["tune_grid"] = delta.duplicate(true)
			tuned["name"] = String(part.get("name", id)) + "+"
			tuned.erase("tuning")
			parts[tuned["id"]] = tuned


## `ar_hammer`, option 0 -> `ar_hammer:a`.
static func variant(id: String, option: int) -> String:
	return "%s:%s" % [base_of(id), OPTIONS[clampi(option, 0, OPTIONS.size() - 1)]]


## The part a tuned id was cut from (`ar_hammer:a` -> `ar_hammer`); an untuned id is its own.
static func base_of(id: String) -> String:
	var at: int = id.find(":")
	return id if at < 0 else id.substr(0, at)


## The model a part is DRAWN with (029): a new part may wear another part's model (`"model"` in
## its JSON) until it has its own; a tuned part wears its base part's. Filled by `ContentDB`.
static var models: Dictionary = {}


static func model_of(id: String) -> String:
	var base: String = base_of(id)
	return String(models.get(base, base))


static func is_tuned(id: String) -> bool:
	return id.find(":") >= 0


## Whether `id` can still be tuned: a known part, not tuned yet, with options to choose from.
static func can_tune(parts: Dictionary, id: String) -> bool:
	if id.is_empty() or is_tuned(id) or not parts.has(id):
		return false
	return not ((parts[id] as Dictionary).get("tuning", []) as Array).is_empty()
