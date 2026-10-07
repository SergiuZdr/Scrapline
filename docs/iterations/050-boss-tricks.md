# Iteration 050 — Boss tricks: every keeper has something to turn against it

**Status:** done (awaiting the play-test)
**Started:** 2026-10-07 · **Finished:** 2026-10-07
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
- [x] `verify_combat`: each trick does what its text says, is in `incoming` where it bites at a
      round's start, and survives `clone`/`snapshot` without leaking.
- [x] Every suite passes.
- [x] Bot 150 runs recorded against 048 (39.3%).
- [~] Screenshots of each trick's telegraph: the Grinder's lane and its STUCK, the claw, the
      coolant tanks, the open side. Not shot: a quench, a haul dragging a drum, a rebuild.
- [ ] The user plays.

## Result
- `verify_combat` **352/352**: new -- a charge into a heap sticks (exposed, double damage) and its
  saws idle; a charge into a machine hits for 3 and shoves it on, not stuck; the lane is marked
  toward the machine it reaches and `incoming` counts it; the claw marks the machine within 4 and
  throws it onto the pad for 2, not one that got away; a blocked pad opens the hatch; a coolant
  tank within 2 quenches The Pour for two turns and cools the slag by it, one far away does
  nothing; a drum hauled against the Magnet King does `haul_blast` + its blast, a crate is dragged
  a hex; the Core's open side does +3 and turns a sixth a round; a fallen twin is back at half HP
  after 3 rounds, both down wins; `clone` carries all of it without leaking. The old pad test now
  allows the claw blocking the pad (it did, on the first run: the new rule working).
- `verify_combat_input` 27, `verify_run` 187, `verify_run_ui` 51, `verify_onboarding` 39,
  `verify_save` 15, `verify_meta` 77: all pass.
- **Bot, 150 runs: 47.3%** (048 with cover 39.3%; 047 43.3%). Gate held (out of rounds) 15 (was 33).
  Act 1 lost 17.3% (at gate 15), Act 2 30.6% (8), Act 3 17.4% (4, was 12): the openings are big
  damage windows, the Core's +3 side the most.
- Screenshots: `shots/050/grinder.png` (the lane), `grinder_r2.png` (STUCK, EXPOSED x2 on the tag
  and the bar), `sorter.png` (the claw's arrow), `pour.png` (coolant tanks), `core.png` (the open
  side -- hard to see under the pulse ring; the bar names it).

## Decisions, lessons, open questions
- One shared opening, EXPOSED (double damage, no pylon / conduit / twin cover), for three keepers
  (MEMORY decisions).
- Open: Act 3 got much easier for the bot (17.4% lost, was 31.4%). Try `open_bonus` 2, or the side
  turning two sixths, after the user plays.
- Open: ground labels are small at the board's zoom ("CHARGES NEXT ROUND", "FLOODS NEXT TURN"
  alike); the boss bar carries each trick.

## Next
The user plays the tricks; tune by what they say.
