# Iteration 008 — The yard and the garage

**Status:** in progress
**Started:** 2026-09-25 · **Finished:** —
**Answers:** every issue in [play-test 3](../playtests/2026-09-25-playtest-3.md).

## Goal
The run is a PLACE with a reason to cross it: a 2.5D scrapyard map under a Reclaimer you
can see, a story that says why you are running, and a garage where a machine is seen
whole and scrap buys it something. The three combat rules the play-test tripped on do
what a player expects.

## Scope
- In: the four combat and text fixes; machine levels as the scrap sink; the story; the 3D
  map; the garage.
- Out (deliberately): part upgrades, perks and manufacturer sets (build progression, now
  009); story beyond text and the map (no cutscenes, per the 2026-09-24 decision); the
  Reclaimer as an enemy faction in fights.

## Plan, issue by issue

| Id | Fix |
|---|---|
| PT3-6 | **Charge works after moving**, and hits harder the further it runs: 2 damage + 1 per hex run (3–5). Still uses the action, still cooldown 3 |
| PT3-7 | **The arc reaches terrain.** From whatever the shot hits first (machine OR prop) it jumps to one neighbour: an enemy machine if there is one, else a fuel drum, else a crate, else any machine. A drum it touches goes off |
| PT3-8 | **Piles are collected along the whole path**, by moves and dashes, for both teams |
| (found) | Part text: shots say "shot N", lobs "lob N-M"; the "line" leftover is gone |
| PT3-9 | **Machine levels**: in the garage, scrap buys a machine a level (12 / 20 / 30 scrap, max 3). Each level: +2 max HP (and 2 HP now), +1 damage on every weapon. Numbers in `run.json` |
| PT3-4 | **The story** (`docs/plans/story.md`): what the Reclaimer is, why the crew crosses the yards, what each act's gate is. In game: a briefing on NEW RUN, the act and mission on the map, site text in the world's voice, and endings that say what happened |
| PT3-1/2/4 | **The map is 3D**: a tilted camera over a dark yard; each site a landmark built from the arena kit (wrecks, containers, a lit workshop gantry, the gate); roads on the ground; **the Reclaimer a wall of harvester rigs with red light and smoke** that visibly advances, the ground behind it stripped. The combined HP bar goes; the crew is a strip of portraits with their own HP and level |
| PT3-3 | **One click travels.** Hover (PC) shows the preview and the move's cost; click goes. On touch, the direction and cost are written on the site itself, and a tap goes |
| PT3-5 | **GARAGE** replaces REFIT: crew tabs; the machine whole in 3D; beside it PARTS and STATS tabs; hovering a part turns the machine to it and makes it glow; LEVEL UP in STATS; the hold a low strip along the bottom with SORT (rarity / slot / newest) and SCRAP. Drag and drop and tap-then-tap still work |

## Steps
1. Combat fixes + part text, with tests. Run balance and the run bot.
2. Machine levels in the sim (`RunSim.LEVEL_UP`), with tests.
3. The story doc, and the text hooks in game.
4. The 3D map.
5. The garage.
6. Tests, screenshots, docs, merge, play-test 4.

## Acceptance criteria
- [ ] verify_combat: charge after a move, damage scaling by distance; chain into a drum sets it off; a move through a pile collects it.
- [ ] verify_run: LEVEL_UP costs, caps, raises HP and damage in the next fight.
- [ ] verify_run_ui: one click travels; the garage fits by tap and by drop, sorts, levels up.
- [ ] run_bot 150 and balance_fights run; numbers recorded.
- [ ] Screenshots: the 3D map (with a hover preview), the briefing, the garage with a hovered part glowing, the STATS tab.
- [ ] Merged to main. **The user plays.**

## Result
(filled in on completion)
