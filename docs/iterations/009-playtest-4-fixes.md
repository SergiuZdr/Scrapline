# Iteration 009 — Play-test 4 fixes

**Status:** in progress
**Started:** 2026-09-25 · **Finished:** —
**Answers:** [play-test 4](../playtests/2026-09-25-playtest-4.md), all but PT4-1 (the full
visual overhaul, 010). Uses the sources chosen in [art-sourcing](../plans/art-sourcing.md).

## Goal
Every specific complaint from play-test 4 is gone: the garage is fast, full and exciting to
level up in; the map is a bigger, fogged place with the crew in it and a Reclaimer you read
at a glance; shots never take the blocked path of two equal ones; the hive's pad stands
still and warns you; the board has edges; and a run starts by building your own crew.

## Plan, issue by issue

| Id | Fix |
|---|---|
| PT4-9 | **Both leanings.** `Hex.line`/`ray` take a lean (±1). `strike_plan` tries both and takes the one that reaches the target clear (else the one that gets further); grapple sees and pulls the same way. Both teams, so previews, AI and execution agree |
| PT4-10 | **Pierce overshoot**: a piercing shot carries 2 hexes past its range at half damage (rounded up). **Chain**: the coil arcs twice — each jump one point weaker than the hit, never below 1 — preferring an enemy, then a drum, then a crate |
| PT4-11 | **Scrap carriers**: each enemy carries scrap or not (55%, seeded), shown on its tag. Only carriers drop a pile. Hive drones carry none |
| PT4-12 | **The hive's pad stays put.** Built once beside the hive, it builds a drone every 2 rounds while the hive lives. The pad is its own object on the board with a countdown ("2", then a red pulsing "NEXT TURN"). Standing on it blocks a drone; killing the hive shuts it down |
| PT4-13 | **The board has edges**: a raised curb traces the hex outline; outside it, dark asphalt, the arena kit (containers, wrecks, floodlights) and fog |
| PT4-2 | The **SCRAP square is the button**: drop a part on it, or pick a part and click it. No separate SCRAP IT |
| PT4-3 | **No black square, no wait**: part models are loaded in the background when the map opens; the stage is transparent until the machine is drawn and fades it in. **A real bay behind the machine**: corrugated wall, lift platform, gantry, work lights, dust in the light |
| PT4-4 | **Levelling up is an event**: sparks, a scan ring sweeping up the machine, a power-up pulse, a camera push, a LEVEL banner with the gains, stat bars filling, a sound. **Levels show on the machine**: armour collars (1), a chest plate (2), a heavier frame (3) — in the garage, on the map and in fights |
| PT4-5 | **The crew is in the world**: the three machines stand on the current site and walk the road when you travel. A slim crew dock on the left (rendered portrait, level marks, HP pips) replaces the bottom strip |
| PT4-6 | **A bigger map, in fog**: 9 columns and up to 4 rows; the camera sits close and follows the crew (drag, keys and wheel to look around); anything not yet scouted is under fog; the gate glows through it |
| PT4-7 | **The Reclaimer as a gauge, not text**: pips that fill with each move; a ghost of the wall at its next line, brighter as it gets closer, flashing when your next move brings it |
| PT4-8 | **A living map**: Reclaimer scout drones with searchlights, smoke from the wrecks, a dead-industry skyline. Further proposals are listed under Result for the user |
| PT4-14 | **Assembly**: after the briefing, build the three machines from a bench of basic parts (every common part, plus one each of the defaults' uncommons). One `ASSEMBLE` action, legal only before the first move |

## Steps
1. Combat rules (1–5), with tests.
2. Run: `ASSEMBLE`, bigger region, with tests.
3. Garage: scrap button, preloading, bay, level-up event, level kit.
4. Map: camera, fog, convoy, dock, gauge, ghost wall, ambient life.
5. Assembly bay screen.
6. Tests, bot, balance, screenshots, docs, merge.

## Acceptance criteria
- [ ] verify_combat: a shot between two equal paths takes the clear one (both leanings tested); overshoot hits at half damage 2 hexes past range; the arc jumps twice; only carriers drop piles; the pad stays put, counts down, spawns, is blocked when occupied, dies with the hive.
- [ ] verify_run: ASSEMBLE legal only at the start, only from the bench, respecting counts; 9-column regions stay valid.
- [ ] verify_run_ui: the assembly bay; the garage scrap button (click and drop); level-up animation runs and the level shows on the model; the map travels by click with fog and the convoy.
- [ ] run_bot and balance_fights recorded.
- [ ] Screenshots: board edges and the pad; the garage bay mid level-up; the fogged map with the convoy and the gauge; the assembly bay.

## Result
(filled in on completion)
