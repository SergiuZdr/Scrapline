# Iteration 083 — The boss is the fight

**Status:** done
**Started:** 2026-10-22 · **Finished:** 2026-10-23
**Answers:** the engagement review (A1, A2, A19, A7-defend, B5) and the user's answers of 2026-10-22:
every round must hold something worth doing; harder overall; the boss push-in judged from a sheet;
a guarded wreck saves one part.

## Goal
A boss fight presses from round 1 and ends the moment the boss falls; bosses stop healing the crew and
read as the biggest thing on the board; losing a DEFEND or a machine costs a part of the reward, not all.

## Scope
- In:
  - **A1** a `keeper` objective: when every keeper is dead the fight is won (`GridEv.KEEPERS_FALL`), the
    rest collapse into piles so salvage still pays. sorting_gate, the_pour, the_core, the three warlords.
  - **A2** escort waves marked a round ahead (`escort_waves`, the existing `_waves`/`wave_marks`), a
    machine on a mark blocks it and takes `block_damage`; the Pour floods where the crew is going (and
    its text matches its flood count); the Core shows "PULSE IN n".
  - **B5** `pile_heal: 0` in boss and warlord fights (piles still pay scrap and salvage).
  - **A19** a `view_scale` for bosses (at least 1.4x a crew machine), boss tags collapsed to the name
    plus two icons; the opening push-in built behind a switch and shown as a before/after sheet.
  - **A7-defend** salvage scales with caches saved; `cache_hp` 5 -> 7.
  - **Wreck recovery** (the user, amending 2026-09-24): a wrecked crew machine's pile, still standing at
    the fight's end, saves one of its parts (the player picks which at the reward).
- Out: overtime (held until A1 is measured), new boss files (later), reinforcements in ordinary fights (087).

## Acceptance criteria
- [ ] verify_combat: the Core's death ends the fight with drones alive; every replayed prefix matches.
- [ ] Run-built boss fights (`dump_boss_fights.gd`) with `balance_fights --b`: 0 rounds after the keeper
      dies; mean boss rounds <= 8; HP lost per boss rising across the acts (aim ~4/8/12); gate losses
      with rising crew HP -> 0.
- [ ] Defend loss rate and share of run losses reported before/after.
- [ ] verify_run: a guarded wreck pile offers one of its parts; the save replays it.
- [ ] Before/after sheet: the Pour and the Core at 1.0 and the new scale, with and without the push-in.
- [ ] Contrast does not drop (`measure_contrast`, three runs).
- [ ] `run_bot --runs 150`: win rate reported (falling is allowed: harder overall), no fall over 8 points.

## Result
Three agents in parallel (sim, run, presentation), then the user's answers built in (escorts on top,
blocked escorts retry, piles banked, a lighter but harder Core, a second wave at round 6 in Acts 2-3,
one random part from guarded wrecks, 1.6x bosses, the push-in on).

- `tools/check.sh`: verify_combat 398, verify_combat_input 39, verify_run 215, verify_run_ui 67,
  verify_save 20, verify_onboarding 54, verify_meta 79, verify_assembly 168, verify_animation 38 -- all
  passed. The fingerprint changed on purpose (rules): `1dd1b7d8` -> `580c912b`.
- Run-built boss and warlord fights, 300 per variant (before -> after, without the round-6 wave): win
  98.3% -> 98.3%; rounds 7.2 -> 6.2; crew HP lost 4.2 -> 5.3; rounds after the keeper fell 0.15 -> 0.00;
  losses where the crew's HP rose 0. By act, HP lost ~4.6 / 5.8 / 5.6 against the 4/8/12 aim -- not met,
  hence the round-6 wave in Acts 2-3 (the user's pick), measured only through run_bot below.
- The Core: 8.4 -> 7.6 rounds, HP lost 7.6 -> 8.0 (sweep 8.4 -> 9.1), timeouts 1 -> 0. The Twins still
  time out 3 in 50 (the user: leave it).
- `run_bot --runs 150`: 91/150 = 60.7% (53-68), from 67.3% (-6.6 points, inside the 8-point limit: harder, as asked). Losses at the gates 4/1/7 -> 5/5/10; Act 2 lost 13.8% -> 18.1%, Act 3 15.1% -> 19.5%.
- Contrast (three runs): the_pour 1.71/1.68/1.66 -> 1.77/1.79/1.80; the_core 1.61/1.63/1.61 -> 1.77/1.79/1.79.
- Sheets: `shots/083/sheet_the_pour.png`, `shots/083/sheet_the_core.png`; wreck and defend panels
  `shots/083/wreck_pick.png`, `shots/083/defend_partial.png`.
- Not measured: the defend loss rate on its own.

## Decisions, lessons, open questions
- Decisions (the user): see MEMORY 2026-10-23 -- escorts on top, blocked escorts retry, piles banked,
  the Core lighter but harder, a round-6 wave in Acts 2-3, the Twins left, one random wreck part,
  fewer salvage options for a partial DEFEND, 1.6x bosses with the lift, the push-in on.
- Lesson: a fight file's keys do not reach a run unless `_make_gate_fight` copies them -- the first
  measurement ran without escort waves or `pile_heal` 0 in real runs.
- Lesson: raising a telegraphed pulse's damage does nothing against a crew that steps out of its ring;
  a boss gets harder by what it does every round, not by a bigger number on a dodgeable mark.
- Open: Act 2-3 boss HP cost against the 8/12 aim after the round-6 wave.

## Next
084: the road.
