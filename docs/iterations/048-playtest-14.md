# Iteration 048 — Play-test 14: undo without a freeze, fuller arenas, map directions

**Status:** done (awaiting the play-test)
**Started:** 2026-10-06 · **Finished:** 2026-10-07
**Answers:** [play-test 14](../playtests/2026-10-06-playtest-14.md).

## Goal
UNDO is instant at any round; boss and warlord arenas are full of cover and look like places; live
wires and The Pour's slag look right; the user has visual directions for the run map to pick from.

## Scope
- In: an UNDO that starts from a turn-start snapshot and keeps the models it did not change;
  `arena_terrain` for gate and warlord boards plus arena floor dressing and a closer ring of
  scenery; a new live-wire look; persistent slag pools; a page of five map mockups.
- Out (deliberately): building a new map. The user picks a direction first (PT14-1).

## Steps
1. `CombatState.snapshot()` (clone plus history); the scene keeps `_turn_state` and UNDO applies
   the turn's actions to it; `_resync_units` keeps a view whose look key matches.
2. Tests: `verify_combat` plays every fight on from each turn's snapshot; `verify_combat_input`
   checks UNDO keeps untouched models, snaps the moved one, and is fast in round 2.
3. `run.json` `arena_terrain`, scattered by `RunSim._make_gate_fight` (rubble and scrap added to
   `_scatter_terrain`, drawing no dice where a terrain table does not name them).
4. Scene: `_dress_arena_floor`, `_build_arena_ring`; the wire's scorch, cable and spark;
   `_flood_views`.
5. Map mockups page; screenshots; all suites; bot 150 runs against 047's 43.3%.

## Acceptance criteria
- [x] `verify_combat`: a turn-start snapshot played on matches the full fight, every fight.
- [x] `verify_combat_input`: UNDO keeps untouched models, snaps the moved machine; a round-2 UNDO
      matches a full replay and takes under 150 ms.
- [x] `verify_run` and every other suite pass (the content hash changes: `arena_terrain`).
- [x] Bot 150 runs: gate and warlord results recorded against 047.
- [x] Screenshots: an arena before and after; wires before and after.
- [x] The map page is published; the user picks a direction (C, the hex diorama: 049).

## Result
- **UNDO**: measured first (headless) -- replaying the fight from round 1 took 832 ms at round 5
  (slag_pit) and 1605 ms at round 8 (sorting_gate); rebuilding the machines 300-480 ms more. Now a
  round-2 undo takes **13 ms** (`verify_combat_input`). `CombatState.snapshot()` = `clone()` plus the
  event history and action count; the scene keeps `_turn_state`; `_resync_units` keeps every view
  whose look key (parts, torn arms, level, kind, team, scrap) is unchanged and snaps it back.
- `verify_combat` **331/331**: new, every fight played on from each turn-start snapshot (and from
  the start, for the shakedown, which the bot wins inside its first turn) reaches the full fight's
  hash and leaves its source alone. `verify_combat_input` **27/27** (new: untouched models kept,
  the moved one snapped, round-2 undo exact and fast). `verify_run` 187, `verify_run_ui` 51,
  `verify_onboarding` 39, `verify_save` 15, `verify_meta` 77: all pass.
- **Slag pools** (`_flood_views`) and **live wires** (scorch, cable, spark) as planned;
  `shots/pt14/048_sheet.png`.
- **Arenas**: `arena_terrain` + `_dress_arena_floor` + `_build_arena_ring`. Bot, the same 150
  seeds each time:

  | Variant | Won | Gate held (rounds) | Act 1 lost (at gate) |
  |---|---|---|---|
  | no arena terrain (= 047) | 43.3% | 25 | 16.0% (11) |
  | rubble 2-3, scrap 1-2, crates 1-2, drum 1 (**shipped**) | 39.3% | 33 | 20.0% (14) |
  | lighter (rubble 1-2, one of each) | 39.3% | 31 | 20.7% (17) |
  | scrap and crates only | 38.0% | 34 | 18.0% (14) |
  | shipped + 2 rounds on the limit | 40.0% | 31 | 19.3% (13) |

  Every kind of cover costs the bot 3-5 points, and extra rounds do not give them back, so the
  extra rounds were taken out again. The user's answer (below) is to make the bosses' own rules
  engaging rather than tune the cover: 050.
- **Map**: five mockups published as a page (https://claude.ai/artifact/LdTz3dMup4QwW3bTuB4DnQ);
  the user picked C, with the battle's comic look.

## Decisions, lessons, open questions
- UNDO from the turn's snapshot; views kept by look key (MEMORY decisions).
- Gate and warlord boards get `arena_terrain` (MEMORY decisions).
- Something that stays on the board must not be an intent mark (MEMORY lessons).
- The user, on the cover: "the bosses don't need just cover and extra rounds ... there needs to be
  more engaging boss/mini-boss passives ... so the player will not just hit a bulky dummy".

## Next
049 builds the hex yard; 050 gives every boss and warlord a trick the player can turn on it.
