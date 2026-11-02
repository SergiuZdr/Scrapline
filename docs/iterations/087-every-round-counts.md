# Iteration 087 — Every round counts

**Status:** in progress
**Started:** 2026-11-02 · **Finished:** —
**Answers:** the engagement review (`docs/plans/engagement-review.md`) and the user's answers of 2026-10-22.

## Goal
From round 3 on every round brings a new problem, dodging is no longer free, and every number and cancelled shot explains itself.

## Scope
- In:
  - **T3** a HUD budget (what the fight may show at once) before anything below lands.
  - **A3** marked reinforcements in ordinary fights from round 3 (run.json `reinforcements`), blocking a mark costs damage, the objective shows waves left. In the base game (the user, Q1).
  - **A4** lock-on intents (tracker weight by act) and lingering ground after mortar and slag hits, drawn as floor, never red.
  - **A12** every damage number explains itself (CombatSim.damage_steps).
  - **A17** a CANCELLED beat when a kill, fall, tear or seize removes a standing intent (GridEv.INTENT_LOST).
  - **A18** consequences drawn on the board while aiming (ghosts, re-aimed intents).
  - **A20** red means danger again (slag hatched umber, dealt damage in ink, OVERHEATED and SEIZED copper; a red-pixel census).

## The user's answers (2026-11-02)
- Lingering ground **adds heat** (+2 to a machine that enters or ends on it), one round, drawn as floor.
- Reinforcement waves **1 / 2 / 2** by act, counted down on the objective line.
- The CANCELLED beat: **strike-through + its own sound + the rare hit-stop**.

## Work split (parallel agents, disjoint files)
- **S, the sim:** A3, A4 (a, b), A12 `damage_steps`, A17 `INTENT_LOST`; run.json, enemy_kinds, verify_combat,
  verify_run, balance_fights/byround measurements.
- **V, the fight screen:** T3 HUD budget (`docs/plans/hud-budget.md`), A12/A17/A18 views, hot ground and waves
  drawn, glossary LOCKED/KO/HOT GROUND/REINFORCEMENTS; verify_combat_input.
- **R, red means danger:** A20 colours (ink.gd, ui_kit.gd, tile looks), a red-pixel census in measure_contrast,
  before/after sheets.

## Acceptance criteria
- [ ] byround: rounds 4+ have 3 or more mean targets and 45% or fewer forced turns; safe reachable hexes ~26 -> 15-20; intents landing 12-20%; rounds per fight up by no more than 1.5; sum(damage_steps) = damage_to over thousands of hits; INTENT_LOST fires exactly when expected; contrast does not drop; named before/after sheets.

## Result

## Decisions, lessons, open questions

## Next
088: first five minutes and Act 3.
