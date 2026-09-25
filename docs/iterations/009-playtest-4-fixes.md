# Iteration 009 — Play-test 4 fixes

**Status:** done (the user asked for 009–013 in one batch; play-test after 013)
**Started:** 2026-09-25 · **Finished:** 2026-09-26
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
- [x] verify_combat: a shot between two equal paths takes the clear one (both leanings tested); overshoot hits at half damage past range; the arc jumps twice; only carriers drop piles; the pad stays put, counts down, spawns, is blocked when occupied, dies with the hive.
- [x] verify_run: ASSEMBLE legal only at the start, only from the bench, respecting counts; 9-column regions stay valid.
- [x] verify_run_ui: the assembly bay; the garage scrap button (click and drop); level-up; the map travels by click, the crew walks, the fog is painted.
- [x] run_bot and balance_fights recorded.
- [x] Screenshots: board edges and the pad; the garage bay mid level-up; the fogged map with the convoy and the gauge; the assembly bay.

## Result

| Suite | Result |
|---|---|
| verify_combat | **134** passed (116): both leanings with a heap on each side and with an ally in the way; overshoot hits one past range at half damage and not past the overshoot; the double arc; carriers are the seeded hash and only they drop; the pad timeline (set down, 2, NEXT TURN, a drone, reset, blocked by standing on it, shut down with the hive, drones carry nothing) |
| verify_combat_input | 20 passed |
| verify_run | **70** passed (61): ASSEMBLE — the default crew is itself legal, commons without limit, frames name the machines (II), full HP, only once, not two saws, no rares, parts fit their sockets, not after the first move |
| verify_run_ui | **33** passed (26): briefing → TO THE BAY → the assembly bay (stepping changes the draft only; ROLL OUT is one action) → the map; hover and one click; **the crew walks the road before the site opens**; the garage including **pick a part, click SCRAP** |
| verify_save / assembly / animation | 14 / 100 / 34 passed |
| run_bot 150 | **89.3%** won (88.7% after 008), 0 illegal actions; **8.2 moves and 5.5 fights a run** (6.1 / 4.3 — the 9-column region); losses mostly at the gate (9 of 16) |
| balance_fights 600 | random squads **87.3%** (88.0%); coil −2.5 and ripper −4.9 against the mean, hammer +3.9 |

Difficulty held through the combat changes; the bigger map lengthened the act by about one
fight. It is still easy for a bot that barely uses abilities — for the user's play-test.

### Found on the way
- **A piercing overshoot bug the new test caught**: the far-damage check read the shot's
  remaining pierce count, which the first hit had already spent, so the unit past range took
  full damage. It now asks whether the WEAPON pierces.
- **Billboard particles throw their scale away** unless `billboard_keep_scale` is set: the
  garage's dust motes were 1 m squares and washed the bay out in pale blocks (the map's dust
  had the same bug, unnoticed because its puffs were meant to be big).
- **A near-black fog over near-black asphalt is drawn and invisible.** The fog shader was
  right all along (checked in isolation on a bright floor); the fog is now a pale night mist,
  and anything deep in it is hidden outright.
- **A display class must not read the `Run` autoload**: a `--script` tool that names it
  compiles it before autoloads exist. `YardView` takes the content database instead.
- **Headless frames outrun real time**: a test waiting 400 frames for a 2.6 s walk timed
  out. Tweened things are waited on with timers.

### Different from the plan
- Several relevant skills (`game-feel-and-juice`, `3d-essentials`, `combat-design`, ...) are
  switched off for Claude in the user's settings; they were respected, not read around. The
  level-up was designed without the juice skill.
- The ghost of the Reclaimer is a translucent red curtain on its next line rather than a
  copy of the rigs: read from above, a curtain is a line, and the line is the information.

### Screenshots
`shots/009_board.png` (edges, yard, pad, scrap marks), `009_levelup_14.png` / `_32.png`
(mid level-up), `009_garage.png`, `009_map.png` and `009_map_wide.png` (fog, crew, dock,
gauge), `009_bay.png`.

### Proposals for "the map feels empty" (PT4-8), for the user to choose
Built now: the crew on the map, fog to explore, scout drones with searchlights, smoking
wrecks, a skyline with blinking stacks and the Crucible's glow. Proposed next (Act 1
content, 013), in the order they would add the most:
1. **Signals** — event sites with a short story and a choice (salvage a crashed hauler at a
   risk, free a spiked rig to join as a part source, bargain with scavengers).
2. **Watchtowers** — climb one to lift the fog over a whole zone (fog makes these matter).
3. **Traders** — buy and sell parts for scrap; a second use for scrap besides levels.
4. **Caches off the road** — a side site worth a detour, so sideways moves are a real call.
5. **Crew chatter** — one line from a machine when something happens, in the world's voice.
