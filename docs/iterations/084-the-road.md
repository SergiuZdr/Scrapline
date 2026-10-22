# Iteration 084 — The road

**Status:** planned
**Started:** — · **Finished:** —
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

## Decisions, lessons, open questions

## Next
085: come back tomorrow.
