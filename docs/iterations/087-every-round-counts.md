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

## The user's answers on the sheets (2026-11-03)
- Hot ground: **brighter ochre cracks, like embers** (never red).
- Push ghosts: **a see-through copy of the machine's own model** (not the amber box), with the arrow.
- CANCELLED: the lettering **beside the thought cloud**, so it never covers the hit floats; -4 dB kept.
- Wording kept: "REINFORCEMENT NEXT ROUND · block it: -N HP", "N WAVES LEFT", "RE-AIMS" / "WILL MISS".
- Slag: **mostly the old look**, about two thirds from umber toward the old glow, with only the hottest red
  taken out; the pools keep a warm glow and the ink hatch.
- Damage dealt floats **in a colour per damage type** (kinetic steel-white, thermal copper, EMP teal,
  corrosive acid green); red stays for damage the crew takes.
- **OVERHEATED stays red** (it hurts); **SEIZED is copper**.
- Core pulse ring: a hex under a crew machine stays solid red; an empty ring hex is a **red dashed outline
  with a light red hatch**, still a warning ("both colours you showed do not say machines get hurt there").
- Slag, after the sheets: the **brighter ember** (d88a3c, value 1.1, hatch 0.15) **with its small contrast drop
  accepted** (slag_pit 2.10 -> 2.07, slag_lake 1.98 -> 1.95; world red 21.85 -> 16.48 and 21.51 -> 10.02 per
  mille). A straight two-thirds mix toward the old glow read red on screen (the print pass fringes bright warm
  pools red), so the hue leans yellow.
- The other reds on the board (a yard container, crate trim, the fuel drum, the SCRAP BLAST label, the Core's
  props) **stay** as they are.

## The user's answers on the sim numbers (2026-11-03)
The first full build (waves 1/2/2 from round 3, trackers 30/40/45, hot ground from lobs) took the bot's run
win rate from ~56% to **30.0%** (150 runs; Act 2 lost 44.6%, Act 3 41.6%).
- Waves keep their sizes but **start at round 4**.
- **Boss escorts hold fire the round they land**, like reinforcements: one rule.
- Hot ground comes from enemy **lob, cone and sweep** (lobs alone almost never happened: one rare arm).
- **Fix the bot's tracker read**: a locked shot follows its target; the bot treated it as dodgeable. Every
  number after this is measured with the fixed bot.

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
