# Iteration 040 — Play-test 12 fixes

**Status:** in progress
**Started:** 2026-10-03 · **Finished:** —

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
- [ ] measure_draws: the idle fight under 1,600 draw calls (from 2,600); CPU measured before/after.
- [ ] Screenshots: briefing, an act arrival, a boss strip, a site with GARAGE, UNLOCKS with part
  lines, the bay with an unlocked part.
- [ ] All suites.

## Result

## Decisions, lessons, open questions

## Next
