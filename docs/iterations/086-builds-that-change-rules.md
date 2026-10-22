# Iteration 086 — Builds that change rules

**Status:** planned
**Started:** — · **Finished:** —
**Answers:** the engagement review (`docs/plans/engagement-review.md`) and the user's answers of 2026-10-22.

## Goal
A level-up, a set, a legendary, a starter arm or a trophy changes what a machine does, and an elite is a different problem, not a bigger number.

## Scope
- In:
  - **T1** a RunBot that chooses perks and salvage by a dry run on the next fight; **T2** a trait-ownership table (perks, sets, legendaries, modules: who gives pierce, tears, arc, mark).
  - **A7** trophies: one salvage option is a part you tore off an enemy (TORN FROM THE TRACKER).
  - **A8** rule perks (Rending Grip, Spotter, AP Rounds, Scavenger, Barbed Hull); every level offer holds one.
  - **A9** legendaries from gate keepers only (the user), each a strong rule plus a visible drawback; warlords give a rare and scrap; SCRAP instead at hoards.
  - **A10** maker sets: 3 pieces of one maker give a verb (the user): Kessler thorns + unshovable, Arclight arc, Vektor pierce, Cinder tears; heat leaves the sets.
  - **B6** no dead arm in the starting kit (Saw stops copying the Cleaver); Focus gets a price (its own A/B).
  - **A5** elite affixes: volatile, rigged, bulwark; shown on the map node and as a tag; elite HP bonus down.

## Acceptance criteria
- [ ] balance_fights --arms 150: no byte-identical rows, no legendary above +15; T1's bot picks a rule perk over half the time; every elite carries one affix, HP lost per elite 1.5-2x a skirmish; run_bot 150 reported.

## Result

## Decisions, lessons, open questions

## Next
087: every round counts.
