# Iteration 038 — The bosses

**Status:** in progress
**Started:** 2026-10-03 · **Finished:** —

(Written after the build, which followed straight from the diagnosis below; recorded so the order
is not hidden.)

## Goal
Play-test 11, PT11-15: "Acts 2 and 3's bosses do not look scary at all, their abilities feel too
weak; Act 3's is supposed to be the end boss but feels easier and weaker than some warlords; the
boss boards feel too empty." After this, every gate's keeper is unmistakably THE boss on screen,
and the Core is the hardest fight of the run.

## What the code showed
- The Pour was not in the scene's big kinds at all: Act 2's boss was drawn at a normal machine's
  size, a Bulwark like any other.
- The Core's board authored a Conduit, but the gate keeps only `keepers` (1) authored machines and
  rolls escorts into the other positions: the end boss had never had its conduit.
- Both bosses are built from ordinary frames in ordinary liveries; their boards were authored 8 x 8
  with little on them, and 032's padding made them emptier.

## Scope
- Rules: `cover_kind` / `cover_armor` (a kind shielded while a machine of another kind stands): the
  Core takes 2 less while a conduit stands. The Core 72 HP (46), two authored conduits
  (`keepers` 3), pulses every 2 rounds (3), builds every 3 (4); erupts to pulse EVERY round, 3 out,
  for 5. The Pour 52 HP (38), floods 4 (3); boils over to flood 5 every round at 3.
- Boards: the Core's and the Pour's floors dressed with crates, drums, slag and flues.
- Presentation: bosses drawn 1.75x (warlords 1.4x), the bosses in crimson and the warlords in
  gunmetal (one livery, `Ink.dress_machine(..., paint)`), tags name them ("THE CORE"), a boss bar
  across the top (name, HP, SHIELDED / ENRAGED / erupts at half HP), boss fights framed to clear it.

## Acceptance criteria
- [x] verify_combat: the Core's conduit shield on and off; the Core's gate fields both conduits.
- [x] Screenshots of the three bosses with their bars (`shots/038/bosses.png`).
- [ ] All suites; run bot 150, 0 illegal; the bot loses more at the Act 3 gate than at Act 2's.

## Result

## Decisions, lessons, open questions

## Next
