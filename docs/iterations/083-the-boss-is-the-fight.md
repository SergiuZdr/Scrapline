# Iteration 083 — The boss is the fight

**Status:** planned
**Started:** — · **Finished:** —
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

## Decisions, lessons, open questions

## Next
084: the road.
