# Iteration 048 — Play-test 14: undo without a freeze, fuller arenas, map directions

**Status:** in progress
**Started:** 2026-10-06 · **Finished:** —
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
- [ ] `verify_combat`: a turn-start snapshot played on matches the full fight, every fight.
- [ ] `verify_combat_input`: UNDO keeps untouched models, snaps the moved machine; a round-2 UNDO
      matches a full replay and takes under 150 ms.
- [ ] `verify_run` and every other suite pass (the content hash changes: `arena_terrain`).
- [ ] Bot 150 runs: gate and warlord results recorded against 047.
- [ ] Screenshots: an arena before and after; wires before and after.
- [ ] The map page is published; the user picks a direction.

## Result

## Decisions, lessons, open questions

## Next
The map direction the user picks becomes its own iteration.
