# Iteration 029 — New weapons and legendary parts

**Status:** in progress
**Started:** 2026-10-01 · **Finished:** —
**Answers:** PT9-7, the second of the four content directions.

## Goal
New ways to fight and something to hunt for: three new weapon families, more parts, and a
LEGENDARY tier that only keepers and late elites give up.

## Scope
- In:
  - **Weapon families**: the FLAMER (a cone: the hex aimed at and the three beyond it), the
    HARPOON (a shot that drags its target a hex toward you -- into your blade, off a ledge), the
    SHIELD CASTER (aimed at an ally: it takes `damage` less from every hit until your next turn).
  - **Ten new parts** (arms, cores, modules, a frame) and **five legendaries** (rarity 4), each with
    its two tunings. New parts wear an existing part's model (`model` in the part's JSON) until
    they get their own.
  - **Keepers drop**: breaking a gate offers a salvage pick with a legendary in it before the next
    act; Act 3's elites can roll them.
  - Prices, scrap values and colours for the fourth rarity; glossary.
- Out: new 3D models for the new parts (they borrow); a mine layer (needs walkable props).

## Acceptance criteria
- [ ] verify_combat: the flamer's cone hits its four hexes; a harpoon drags; a shield caster shields.
- [ ] verify_run: a gate offers a legendary; legendaries never roll on enemies or the bench.
- [ ] Bot 150 runs, 0 illegal; screenshots of a flamer's cone and the garage with a legendary.

## Result

## Decisions, lessons, open questions

## Next
030: warlords.
