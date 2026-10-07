# Iteration 050 — Boss tricks: every keeper has something to turn against it

**Status:** in progress
**Started:** 2026-10-07 · **Finished:** —
**Answers:** the user, after 048's arena numbers: "the bosses don't need just cover and extra
rounds, there needs to be more engaging boss/mini-boss passives/caveats to the fight so the player
will not just hit a bulky dummy". They approved all six proposals.

## Goal
Each boss and warlord has a trick: something to do besides hitting, a window where it is open,
telegraphed a round ahead like everything else.

## Scope
- In (rules in `enemy_kinds.json`, one shared state `exposed`):
  - **EXPOSED**: for the crew's next turn(s) a keeper skips its pylon / conduit / twin armour and
    takes `exposed_pct` (double) damage. The Grinder stuck, the Sorter's hatch, The Pour quenched.
  - **Grinder**: every `charge_every` rounds it marks a straight lane (`charge_range`) a round ahead
    and charges down it at the round's start: the first machine in the way takes `charge_damage`
    and is shoved on; if the charge ends against a heap, a prop, a pit's edge or the board's edge
    it is STUCK (exposed, no saws) for `stuck_rounds`.
  - **Sorter**: every `grab_every` rounds it marks the nearest machine within `grab_range`; next
    round, if that machine is still in reach, the claw throws it onto the Sorter's pad for
    `grab_damage`. Whenever its pad works (builds, or is blocked) its hatch is open: exposed.
  - **The Pour**: COOLANT TANKS (a new prop): one that breaks within `quench_radius` of it quenches
    it (exposed `quench_rounds`) and cools the slag around the tank.
  - **Magnet King**: its haul drags props too; a fuel drum hauled next to it goes off.
  - **The Core**: one OPEN SIDE, turning a sixth each round: hits from that side take `open_bonus`
    more and ignore its conduits' cover.
  - **Twin Furnaces**: one that falls while its twin stands is rebuilt in `rebuild_rounds` at
    `rebuild_pct` of its HP unless the other falls first.
- Out (deliberately): new models; the cover question (judged after this, by the user).

## Steps
1. Sim: state (`exposed`, `charge`, `grabs`, `facing`, `rebuilds`, all in `clone`), events,
   rules, `damage_to`; boards (coolant tanks on The Pour's, drums on the Magnet King's).
2. `verify_combat`: one test per trick, the dry-run / clone check, replay determinism.
3. Scene: marks for the lane, the grab, the open side, the rebuild countdown; animations for the
   charge, the throw, a hauled prop, a quench, a rebuild; EXPOSED on the tag; glossary and kind
   texts.
4. Bot 150 runs; screenshots; docs.

## Acceptance criteria
- [ ] `verify_combat`: each trick does what its text says, is in `incoming` where it bites at a
      round's start, and survives `clone`/`snapshot` without leaking.
- [ ] Every suite passes.
- [ ] Bot 150 runs recorded against 048 (39.3%).
- [ ] Screenshots of each trick's telegraph.
- [ ] The user plays.

## Result

## Decisions, lessons, open questions

## Next
