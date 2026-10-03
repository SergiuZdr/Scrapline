# Iteration 040 — Play-test 12 fixes

**Status:** done -- waiting for the user to play it
**Started:** 2026-10-03 · **Finished:** 2026-10-03

## Goal
The game draws a fraction of what it drew; the story says something; every site can open the
garage; UNLOCKS shows what each new part does; the bay offers unlocked parts; the strip tilts and
an act's arrival is told once a run.

## Scope
- Performance: labels, sprites and particles cast no shadows; the floor casts none; a machine casts
  its shadow from its frame only; generated set pieces and the harvesters cast none; the board's
  static pieces are merged per material (`Ink.merge_static`); 60 fps at most, 12 in the
  background. `tools/measure_draws.gd` counts draw calls, objects and triangles.
- Story: the briefing, an act's arrival and a boss's strip carry the lore AND what the player needs
  -- who the crew is, why the Reclaimer follows, how the run works, what is new in the act, how
  this boss is beaten.
- Sites: a GARAGE button on every site window.
- UNLOCKS: each part says what it does (its card line), new ones stand out, tapping one shows its card.
- The bay: parts the player has unlocked join the bench.
- The strip's panels tilt (a holder, as captions); an act's arrival is told once per run (Profile).
- Out: comic panels and buttons (041); a model for every part (042).

## Acceptance criteria
- [x] measure_draws: the idle fight under 1,600 draw calls (from 2,600); CPU measured before/after.
- [x] Screenshots: briefing, an act arrival, a boss strip, a site with GARAGE, UNLOCKS with part
  lines, the bay with an unlocked part.
- [x] All suites.

## Result

- **Resources** (idle, this Mac; an empty Godot window is 3% of a core):

  | Screen | Draw calls a frame | Triangles | CPU (one core) |
  |---|---|---|---|
  | Fight | 2,599 -> 1,516 | 718k -> 509k | 75-100% -> ~60% |
  | Map | 1,686 -> 1,265 | 1.17M -> 790k | ~62% -> ~62% |
  | Title | 814 -> 814 | 394k | ~50% -> ~32% |

  The main thread was ~92% GL draw calls; scripts ~3%. Fixes: no shadows from labels, sprites and
  particles (Godot's default cast them), the floor, the non-frame parts of a machine, the generated
  set pieces or the harvesters; the board's static pieces merged per material (`Ink.merge_static`,
  carrying the ink line's smoothed normals); 60 fps cap, 12 in the background. The map is still
  heavy: the generated set pieces (20 x ~40k triangles) draw their ink line over meshes that lose
  their LODs when the line is built -- the next thing to fix.
- **Story** (`story.json`): the briefing is THE VALLEY / THE KEY / YOUR CREW / THE ROAD, each the lore
  and what it means on screen (the red wall, the gauge, parts, workshops, three gates); each act's
  arrival is MEANWHILE / NEW HERE (the act's new hazards and enemies) / AT THE END (its boss and
  how it is beaten); a boss's strip is AT THE GATE / BOSS (how it fights) / HOW TO WIN (`bosses`).
  An arrival is told once per run (`Profile.act_told` / `tell_act`). Strip panels tilt (holders).
- **GARAGE** in the title row of the salvage, trader, refinery, auction, watchtower and signal
  windows.
- **UNLOCKS**: each part's row says what it does (its card line); a new one says NEW!; a click
  opens the part's card; the list scrolls.
- **The bay**: `Meta.options` carries `unlocked`; `RunSim.bench_count` puts each unlocked part on the
  bench once.
- Suites: combat 296, run 178 (+1), meta 72, save 15, assembly 140, combat_input 22, run_ui 50,
  onboarding 39. Screenshots `shots/040/`.

## Decisions, lessons, open questions
- Lesson: the cost was not where the code map pointed. Profile before refactoring: CombatScene
  "bridging 15 clusters" costs nothing; 2,600 draw calls did.
- Lesson: Godot casts shadows from Label3D and Sprite3D by default.
- Open: the map's set pieces (decimate them, or keep LODs under the ink line).

## Next
041: comic panels and buttons. 042: a model for every part.
