#!/usr/bin/env python3
"""Every part's numbers as one score, in HP-equivalents per fight (033, play-test 10).

    python3 tools/part_points.py [--measured shots/033/power.json] [--md]

A MODEL, not a measurement: the weights below are what one point of each stat is worth over a
typical fight (about four attacks, three hits taken, a few hexes walked). Its job is to show
the SHAPE -- how much a rare adds over a common in each slot, and which parts sit off their
rarity's line. `tools/part_power.gd` measures the same parts in bot fights; pass its JSON with
--measured to print both side by side.
"""
import json, sys, glob, statistics

W = {
    "hp": 1.0,            # one hit point
    "armor": 3.0,         # one less per hit, about three hits a fight
    "move": 3.0,          # a hex further each turn: reaching, retreating, reaching piles
    "damage_all": 4.0,    # +1 on every attack (core, module): about four attacks a fight
    "range_all": 2.5,     # +1 range on every ranged weapon
    "heat_cap": 0.5,
    "vent": 1.5,
    "heat_all": -1.5,     # +1 heat on every attack
    "arm_damage": 2.0,    # +1 on one arm: about half the attacks
    "arm_range": 0.6,     # per hex of reach beyond melee
    "arm_heat": -1.0,
}
# 033: what a core or module does beyond the plain numbers, per point.
EXTRA = {"melee": 2.0, "unshovable": 1.5, "move_after_attack": 2.5, "chain": 1.0, "pierce": 3.0, "arc": 3.0,
         "mark": 2.5, "shove": 1.5, "tears": 1.5, "thorns": 1.5, "regen": 2.5, "kill_heal": 0.8,
         "last_stand": 5.0, "cooldown": 1.5}
ABILITY = {"charge": 3.0, "dash": 2.0, "barricade": 2.0, "focus": 2.5, "grapple": 2.0,
           "overdrive": 2.0, "flush": 1.0, "shield": 3.0, "magnet": 2.0}
ROLE = {"brawler": 1.0, "line": 1.5, "marksman": 1.5, "anchor": 1.0}


def load():
    parts = {}
    for f in glob.glob("data/parts/*.json"):
        if f.endswith("makers.json"):
            continue
        d = json.load(open(f))
        items = d if isinstance(d, list) else d.get("parts", d)
        for p in items:
            if isinstance(p, dict) and "id" in p:
                parts[p["id"]] = p
    return parts


def score(p):
    g = p.get("grid", {})
    slot = p["slot"]
    s = 0.0
    if slot == "chassis":
        s += g.get("hp", 0) * W["hp"] + (g.get("move", 3) - 3) * W["move"] + (g.get("heat_cap", 6) - 6) * W["heat_cap"]
        s += ROLE.get(p.get("role", ""), 0)
    elif slot == "arm":
        shape = g.get("shape", "melee")
        dmg = g.get("damage", 0)
        if shape == "cone":
            dmg *= 1.8          # up to four hexes, usually two things in them
        if shape == "shield":
            s += 4.0 + dmg      # protection, not damage
        else:
            s += dmg * W["arm_damage"]
        if shape in ("shot", "lob"):
            s += 1.0 + (g.get("range", 1) - 1) * W["arm_range"]
        if shape == "lob":
            s += 1.0            # over cover and heads
        s += g.get("heat", 0) * W["arm_heat"]
        pierce = g.get("pierce", 0)
        s += min(pierce, 3) * 1.2
        s += g.get("chain", 0) * 1.2
        for k, v in (("splash", 2.5), ("shove", 1.0), ("pull", 1.0)):
            if g.get(k, 0):
                s += v
        if g.get("tears"):
            s += 1.5
        if g.get("mark"):
            s += 1.0
    else:  # core, module: blocks that apply to the whole machine
        s += g.get("hp", 0) * W["hp"] + g.get("armor", 0) * W["armor"] + g.get("move", 0) * W["move"]
        s += g.get("damage", 0) * W["damage_all"] + g.get("range", 0) * W["range_all"]
        s += g.get("heat_cap", 0) * W["heat_cap"] + g.get("vent", 0) * W["vent"] + g.get("heat", 0) * W["heat_all"]
        for k, v in EXTRA.items():
            s += float(g.get(k, 0)) * v
    s += ABILITY.get(g.get("ability", ""), 0)
    return round(s, 1)


def main():
    parts = load()
    measured = {}
    if "--measured" in sys.argv:
        measured = json.load(open(sys.argv[sys.argv.index("--measured") + 1]))["parts"]
    md = "--md" in sys.argv
    rows = []
    for pid, p in parts.items():
        rows.append((p["slot"], p.get("rarity", 1), score(p), pid, p))
    rows.sort(key=lambda r: (["chassis", "core", "arm", "module"].index(r[0]), r[1], -r[2], r[3]))
    names = ["", "common", "uncommon", "rare", "legendary"]
    for slot in ["chassis", "core", "arm", "module"]:
        print(f"\n## {slot.upper()}" if md else f"\n== {slot}")
        if md:
            print("\n| Part | Rarity | Model | Measured HP saved/fight | Measured win |\n|---|---|---|---|---|")
        by = {}
        for r in rows:
            if r[0] != slot:
                continue
            by.setdefault(r[1], []).append(r[2])
            m = measured.get(r[3])
            ms = f"{m['net']:+.2f}" if m else "-"
            mw = f"{m['win']:+.1f}" if m else "-"
            if md:
                print(f"| {r[4].get('name', r[3])} | {names[r[1]]} | {r[2]} | {ms} | {mw} |")
            else:
                print(f"  {r[3]:16s} {names[r[1]]:9s} model {r[2]:5.1f}   measured net {ms:>6s} win {mw:>6s}")
        line = "  ".join(f"{names[k]} {statistics.mean(v):.1f} ({min(v)}-{max(v)}, {len(v)})" for k, v in sorted(by.items()))
        print(("\nMean by rarity: " if md else "  mean by rarity: ") + line)


if __name__ == "__main__":
    main()
