# Iteration 084 — The road

**Status:** done
**Started:** 2026-10-23 · **Finished:** 2026-10-24
**Answers:** the engagement review (B2, B3, B7, B8) and the user's answers of 2026-10-22: wandering must
cost at the default difficulty so the player is pushed forward; a reason to come back (seeds feed 085's
daily and weekly yard).

## Goal
Every map node is a choice made with the facts, a sideways step is a bet against the Reclaimer, each act
of a run has its own condition and warlord, and any run can be replayed from its seed code.

## Scope
- In:
  - **B2** the fight on the map: `RunSim.fight_preview` calls the same roll as `_make_fight`; a revealed
    fight site's card says "DEFEND · dust · 2 shredders, 1 mortar"; unscouted sites stay "?".
  - **B3** the Reclaimer as a budget: `front.pace` (moves per column x100); the front advances when
    `moves*100 >= (front_col+2)*pace`. Rung 0 default (the user). Any cost shows on the move preview.
  - **B7** an act condition rolled per act from the seed (dust, wires, scrap rain, heat wave), announced
    on the act card and the map header, applied to every fight in the act; the three warlords rotated
    across acts with escorts scaled to the act.
  - **B8** a seed as a short word code (carrying the content version) on the run-over screen with PLAY THIS
    SEED, a seed field at NEW RUN, `Profile.run_history` (last 50 runs) shown as a ledger; a seeded run
    never overwrites a live save; seeded wins do not count toward the ladder or unlocks.
- Out: the daily and weekly yard (085, built on B8), new boss files.

## Acceptance criteria
- [ ] verify_run: preview equals `_make_fight` after travel over 300 regions; a seed code round-trips to
      the identical RunState; the same seed gives the same region, conditions and warlord order.
- [ ] B3 with `run_bot --b`: explorer fights per run 15-17, bites or drone reaches in 30%+ of explorer
      acts; win rate at 150 runs reported.
- [ ] Conditions over 300 seeds: each in 20-35% of acts; `balance_fights --b` per condition within 5 points.
- [ ] verify_save: the run history survives a restart.
- [ ] Screenshots: a node card with its fight, the act header with its condition, the seed on run-over.

## Result
Two agents in parallel (the run sim; the screens and the profile), then the user's answers built in.

- `tools/check.sh`: verify_combat 398, verify_combat_input 39, verify_run 244, verify_run_ui 90,
  verify_save 25, verify_onboarding 54, verify_meta 83, verify_assembly 168, verify_animation 38 -- all
  passed. Fingerprint `580c912b` -> `bdbf204e` (rules, on purpose).
- B2: every card equals the fight made after travel (2016 fights over 300 regions, routes that hurt and
  wreck the crew while the front moves).
- B3, explorer vs forward on 40 paired seeds: pace 200 (the old `every 2`) explorer +17.5 points; pace 150
  -7.5; with lingering drones (more, sooner) explorer 32.5% vs forward 55.0%, B-A -22.5 (-38.7 to -6.3),
  real. The forward bot is reached or bitten in 1.2% of acts.
- B7: conditions over 900 acts: dust 23%, heat wave 25%, scrap rain 25%, wires 25%; per condition against
  none (balance_fights, hardened enemies): dust +1.8, wires +2.0, scrap rain 0.0, heat wave -3.8 -- all
  within 5 points. All 6 warlord orders appear; same seed, same region, conditions and warlords.
- B8: 3000 codes read back to their seeds; a code started is the identical run (fingerprints equal at
  every step); history survives a reload and caps at 50; a seeded win unlocks nothing.
- `run_bot --runs 150` (forward): 86/150 = 57.3% (49-65), from 60.7% after 083 (-3.4 points).
- Screens: `shots/084/sheet.png`.
- Seen, not fixed: one `Parameter "t" is null` from `models.gd:132` via `yard_view.gd:891` in one
  verify_run_ui run (no check failed).

## Decisions, lessons, open questions
- The user's decisions: MEMORY 2026-10-23/24 (pace 150; a condition every act, bosses clean; warlords
  rotate, the Twins may land in Act 1; more and sooner drones for lingering, piles still heal; seeded runs
  count for nothing; the condition replaces the mission line; ledger pictures and replay; objective words).
- Lesson: a cost the player can heal back is not a cost -- more drones alone changed nothing until they
  also came sooner.
- Open: a human sweeping part of a column sits between the two bots; `round_per_linger` 4 or `max` 6 are
  the dials if whole sweeps should stay viable.

## Next
085: come back tomorrow.
