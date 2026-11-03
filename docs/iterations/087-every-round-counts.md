# Iteration 087 — Every round counts

**Status:** done
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

### Summary
Three agents in parallel (S the sim, V the fight screen, R red means danger), then a second pass on the user's
picks. `tools/check.sh --fingerprint`: verify_combat 457, verify_combat_input 86, verify_run_ui 124,
verify_save 43, verify_onboarding 55, verify_meta 109, verify_assembly 168, verify_animation 38 -- all passed;
verify_run 336 (alone: 17 min; check.sh's limit raised from 900 to 1500 s, since 4 whole bot runs inside it take ~460 s and the suites share the cores). Fingerprint TOTAL **4f403a1d** (from f23150b7: INTENT_LOST alone gave a4db7499 with every
outcome unchanged; the new rules and the bot's tracker fix change play on purpose).

- **run_bot, 150 runs: 78 won, 52.0% (44-60).** Lost among runs reaching each act: 6.0 / 24.1 / 27.1%
  (086: 2.0 / 24.5 / 18.9). 5.7 rounds per fight; 32.3% of fights cost the crew no HP.
- The first build (waves from round 3, old bot) measured **30.0%** at 150 runs; the user moved waves to round 4,
  made every escort hold fire, widened hot ground to cone and sweep, and fixed the bot.
- **The bot's tracker fix alone** took the base from 55.0% to 77.5% (40 runs): the bot had been walking into
  locked shots. Most of what A3/A4 take away is this gain.
- byround, 40 runs, rounds 4+ (base -> 087): targets 2.72 -> **3.00** (met), forced turns 40.3 -> **33.7%**
  (met), rounds per fight 5.2 -> 5.6 (met), safe hexes 23.6 -> 23.6 (**not met**, aim 15-20), intents landing
  7.5 -> 7.0% over all rounds (**not met**, aim 12-20%).
- 902 reinforcements arrived and 7 marks were blocked; hot ground set 1052 times; trackers 441 of 3029 enemies.
- `sum(damage_steps) == damage_to` over 22,273 hits; every planned hit's steps sum to its damage. INTENT_LOST:
  91 in 21 bot fights, none wrong.
- Contrast: slag_pit 2.10 -> 2.07, slag_lake 1.98 -> 1.95 with the brighter ember (**not met**, the user
  accepted it); world red 21.85 -> 16.48 and 21.51 -> 10.02 per mille.
- 2x enemy turn on slag_pit 1846-1876 ms on a quiet machine (limit 1.9 s); one run on a busy machine 1905 ms.

### What was built
- **A3 reinforcements** (`run.json reinforcements`): skirmishes, elites and arenas (never SURVIVE), from round 4
  every 2, waves 1/2/2 by act, 1 machine for columns 0-2 and 2 after; marked a round ahead (block the mark: the
  machine takes the HP shown); a landing machine holds fire that round (escorts too); a fight cleared before a
  wave lands is won. "N WAVES LEFT" on the objective line.
- **A4a** trackers weigh 30/40/45 by act. **A4b hot ground** (`rules.json ground_after_hit`): an enemy lob, cone
  or sweep leaves its aimed hex hot for one crew turn, +2 heat to a machine entering or crossing it; routes go
  round it; the bot weighs it. Drawn as scorched floor with ember cracks.
- **A12** `CombatSim.damage_steps`; every strike_plan hit carries `steps`; the aimed target's line explains its
  number ("3 -> 1 (-2 warden)").
- **A17** `INTENT_LOST`: a kill, a fall or tearing the arm in use cancels the intent: the cloud comes back struck
  through, CANCELLED -N beside it, its own sound, the rare hit-stop.
- **A18** while aiming: a see-through copy of each machine at the hex it would be pushed to, and dashed lines on
  intents that would re-aim (RE-AIMS) or miss (WILL MISS).
- **T3** `docs/plans/hud-budget.md`: three screen states, one loud layer each.
- **A20** red means danger: slag ember (no glow red), damage dealt in its damage type's colour, SEIZED copper,
  OVERHEATED red, the Core's empty ring hexes a red dashed zone; a red census in `measure_contrast`.
- Bot: `CombatBot.context(state, for_ref)` re-runs a tracker's locked shot from every hex the planned machine can
  reach; IntentAI shares it.
- Tools: `tools/byround.gd`, `tools/shot_red.gd`, `shot_combat --stage-hot/--stage-wave/--event-wait`,
  `Stats.override` indexes lists.

### Sheets
`shots/087/`: 087_a12_damage_explained, 087_a17_cancelled, 087_a18_ghosts_reaim, 087_a4_hot_ground_and_waves,
087_picks_1-3_ghost_cancel_hot, 087_picks_5-7_floats_seized_ring, red_before_after (+grey), slag_ember_sheet,
slag_ember_bright_sheet (+grey).

## Decisions, lessons, open questions
- Decisions: the user's answers above.
- Lesson: a bot that misreads a rule hides that rule's cost. Fixing the tracker read was worth +22 points, more
  than any content dial this iteration; fix the bot before tuning content against it.
- Lesson: a straight colour mix toward a red-orange glow still reads red on screen, because the print pass
  fringes bright warm pools in red; push the hue toward yellow instead.
- Open: safe hexes (23.6) and intents landing (7%) did not move toward the review's aims; the board stays roomy.
  Waves and hot ground were drawn in shots on a staged state; the play-test should see them made by the sim.

## Next
088: first five minutes and Act 3.
