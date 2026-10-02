# Iteration 037 — Play-test 11 fixes

**Status:** in progress
**Started:** 2026-10-03 · **Finished:** —

## Goal
Everything the game does is said, and said where it happens: abilities show their damage before
they are confirmed, every number on the board says what it is made of, damage types are visible,
and the screens' words match what the buttons do.

## Scope
- Rules: Charge captures a terminal it ends on, and counts the Brawler's melee bonus (a slam is
  melee). Some weapons deal their OWN damage type (the Flamer and the Sunspear heat, the Pulse
  Emitter and Coilgun EMP) instead of the core's; the Dynamo Core (kinetic) is renamed the
  Flywheel Core.
- Previews: an aimed ability draws its totals on the board; damage to props (pylons, drums,
  crates) is shown; every total says its parts ("-7 (4 + 3 blast)", "(arc)"); weapon cards include
  a Focus / Overdrive boost the moment it is used.
- Text: every ability's text checked against its code (Charge rewritten); the garage's NUMBERS
  becomes DETAILS; ROLE says what the role is and its trait for all four roles; part cards drop
  "NOT RARER THAN YOURS"; the workshop says UPGRADE, and every site says what it does on the map.
- Damage types: a chart (glossary card and in DETAILS), the type on every weapon line, and STRONG /
  WEAK on an aimed hit.
- Layout: a tag never climbs more than its own height (badges no longer count); the map's
  portraits frame the machine's width; HP squares 16 to a row there too.
- UNLOCKS marks what is new since the screen was last opened (`Profile`), and the title says how
  many.

## Acceptance criteria
- [ ] verify_combat: charge onto a terminal takes it; a Flamer on a kinetic core burns (thermal);
  a dry run reports prop damage.
- [ ] Screenshots: an aimed Charge with its total on the board; a pylon shot; DETAILS; the map
  dock with a 31 HP machine; UNLOCKS with NEW.
- [ ] All suites; run bot 150, 0 illegal.

## Result

## Decisions, lessons, open questions

## Next
