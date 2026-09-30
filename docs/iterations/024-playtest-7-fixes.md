# Iteration 024 — Play-test 7 fixes

**Status:** in progress
**Started:** 2026-09-30 · **Finished:** —
**Answers:** [play-test 7](../playtests/2026-09-30-playtest-7.md), every item but Act 3 (025).

## Goal
The fight reads at a glance and plays without freezing: one total per hex the enemy will hit,
the machine under your hand obvious, the objective up from the first frame, no shader stalls,
labels that stay on their machine; shoves and pierce do what a player expects.

## Scope
- In:
  - **Enemy fire as totals** (PT7-3): a new sim query runs the enemy's volley on a copy and
    reports what every unit and prop would take; the board shows ONE number per hex hit,
    including anything in the way. Firing-order badges go (the list stays in the info panel).
  - **Your aim on the board** (PT7-12): the aimed attack's damage on every hex it touches, and
    the preview list ordered by distance from the shooter, enemies first.
  - **No stalls** (PT7-4): short-lived materials keep their shader alive (`Ink.hold`); the
    drum's useless omni light goes; every effect is drawn once behind the opening card
    (`_warm_up`); hits from one cause land together instead of one after another.
  - **The opening card** (PT7-5): the fight's name and objective over the board while it loads;
    the objective panel is filled before the first event plays.
  - **Selection** (PT7-9): an amber ring and a chevron over the machine under your hand.
  - **Labels** (PT7-2): the scrap mark sits on the tag's HP line; a crowded tag moves the
    shorter way (up or down) instead of always down.
  - **Shoves** (PT7-6): of two equally good directions, the one better for the shover (a pit,
    a bump into the other side, over open ground last); the preview draws where it goes.
  - **Pierce** (PT7-7): a piercing weapon may be aimed as far as its beam flies, so the line can
    be drawn through the thing behind.
  - **Audio** (PT7-8): the ambience is a low machine hum, no surf.
  - **Models** (PT7-10): no stencilled numbers.
  - **Names** (PT7-11): crew machines keep their crew's names (not their frame's); names proposed.
- Out (deliberately): Act 3 (025).

## Steps
1. Sim: `CombatSim.incoming`, shove direction choice, pierce aim reach; tests.
2. Scene: totals, aim numbers, selection marker, labels, opening card and warm-up, batching.
3. Audio, stencils, names.
4. Measure (hitches, contrast), suites, run bot, docs.

## Acceptance criteria
- [ ] `measure_hitches.gd` on a bot fight: no frame over 100 ms after the opening card.
- [ ] verify_combat: `incoming` equals what END TURN does to every unit's HP; a tied shove takes
  the pit / the bump; a piercing weapon can aim into its overshoot and its plan reaches there.
- [ ] A screenshot: one total per hit hex, the selected machine marked, the scrap mark on its tag.
- [ ] Every suite passes; the run bot plays 150 runs with 0 illegal actions.

## Result

## Decisions, lessons, open questions

## Next
025: Act 3, the Crucible.
</content>
</invoke>
