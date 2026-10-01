# Iteration 029 — New weapons and legendary parts

**Status:** done -- waiting for the user to play it
**Started:** 2026-10-01 · **Finished:** 2026-10-01
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
- [x] verify_combat: the flamer's cone hits its four hexes and only from next door; a harpoon drags
  its target a hex; a shield caster shields an ally and nothing else.
- [x] verify_run: a gate's hoard offers a legendary and the pick moves on to the next act; no
  enemy carries a legendary or a shield caster; none is on the bench.
- [x] Bot 152 runs, 0 illegal; `shots/029_flamer.png` (a Colossus with the Crucible Heart, the
  Godhammer and the Aegis Rig aiming its flamer).

## Result

- **Sim**: shapes `cone` (the aimed neighbour and the three hexes beyond it) and `shield` (aimed
  at an ally: `shield = damage` until the crew's next turn, `SHIELDED`); weapon field `pull`
  (drag a hex toward the shooter through `shove`, so pits and bumps work). Cores can carry `range`.
- **Parts** (55 now): Slag Flamer, Hook Harpoon, Aegis Caster (`"enemy": false`), Scrap Cleaver,
  Arc Coilgun, Flux Core, Jump Jets, Hull Plating, Scrapper Frame; legendaries Godhammer,
  Sunspear, Crucible Heart, Aegis Rig, Colossus Frame. Each borrows a model (`"model"`,
  `PartTuning.model_of`, used by every drawing path). LEGENDARY colour, price 60, scrap 18.
- **The hoard**: a broken gate (not the last) offers three parts, the first legendary, or 25
  scrap; the pick moves the crew on (`RunSim.hoard`, `pending.then`); the map rebuilds itself on
  the new act. Act 3's salvage can roll a legendary (6%).
- Suites: combat 264 (+6), run 159 (+4), meta 59 and assembly 140 (now read the part list), run
  UI 49, input 22, onboarding 39, save 15. **Run bot: 64.5%** (57.9% before): the legendaries
  make the crew stronger; Act 3 lost 16.2%, its gate 8.

## Decisions, lessons, open questions
- **A new part may borrow a model** until it gets its own: the game draws `model_of`, never the id.
- **Legendaries come from gates (always) and Act 3 (rarely)**; never on enemies or the bench.
- Open: do the new weapons feel different? Should the late game be pushed back up toward 55%
  (030's warlords add fights)?

## Next
030: warlords.
