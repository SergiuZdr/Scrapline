# Iteration 037 — Play-test 11 fixes

**Status:** done -- waiting for the user to play it
**Started:** 2026-10-03 · **Finished:** 2026-10-03

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
- [x] verify_combat: charge onto a terminal takes it; a Flamer on a kinetic core burns (thermal);
  a dry run reports prop damage.
- [x] Screenshots: an aimed Charge with its total on the board; a pylon shot; DETAILS; the map
  dock with a 31 HP machine; UNLOCKS with NEW.
- [x] All suites; run bot 150, 0 illegal.

## Result

- **Charge** was wrong in two ways the play-test could not see: it ran its FULL range whatever hex
  was picked (so it ran past a terminal), and it never called the terminal capture. It now stops on
  the hex aimed at, takes a terminal, and counts the Brawler's +1 (a slam is melee). Its text says
  exactly that: 3 next to you, +1 a hex run (5 at most), plus bonuses and boosts, then a shove.
- The other abilities' texts were checked against `abilities.gd` and match (Dash, Focus, Overdrive,
  Flush, Shield, Magnet, Grapple, Barricade).
- **Damage types**: `weapon["dtype"]` from an arm's `damage_type` (Flamer, Sunspear thermal; Pulse
  Emitter, Coilgun EMP); `strike_plan` works a plan out with the weapon's type and puts the
  machine's back. Every weapon line names its type ("5 KINETIC"); the glossary has a DAMAGE TYPES
  tab with the chart (`TypeChart`); DETAILS says what the machine is strong / weak against and what
  hits it; an aimed hit says STRONG x1.3 / WEAK x0.7. The Dynamo Core is the Flywheel Core.
- **Previews**: an aimed ability draws its totals; `CombatSim.diff` reports damage to props that
  stand (a pylon -4 -> 2/6); `CombatSim.damage_parts` breaks a total into its parts ("-7 (4 + 3
  blast)", "arc: 1 less", "thorns"); weapon cards add Focus / Overdrive and conduits at once.
- **Words**: NUMBERS -> DETAILS; ROLE "LINE · can move after attacking (every Line frame)", the four
  roles' traits, and only EXTRA traits listed after; part cards lose "NOT RARER THAN YOURS"; tuning
  is UPGRADE everywhere (workshop, bench, glossary, hints); every unvisited site says what it does
  under its name on the map (`SITE_DOES`); the hover card's arena, warlord, gate lines corrected.
- **Layout**: a tag climbs at most its own height (a group's badges no longer count); the map dock's
  HP squares are a 16-wide grid; portraits frame the machine's width too.
- **UNLOCKS**: `Profile.unseen_unlocks` / `mark_unlocks_seen`; the title button says "UNLOCKS · N
  NEW", the screen opens with "NEW SINCE YOU LAST LOOKED: ..." and the green NEW marks.
- Suites: combat 294 (+6), run 177, meta 72, save 15, assembly 140, combat_input 22, run_ui 50,
  onboarding 39. Screenshots `shots/037/` (charge, types, garage, map). **Run bot 57.3%** (56.7%),
  0 illegal; lost by act 9.3 / 18.4 / 22.5%.

## Decisions, lessons, open questions
- Some weapons carry their own damage type: a Flamer that dealt kinetic because of its core was the
  "names do not match what they do" the user saw. Cores still set the type of everything else.
- Lesson: a test that SETS the precondition is what found Charge running past its target -- the
  ability had passed every test written from its own description.
- Open: is the type chart enough, or should the board show a machine's armour on its tag?

## Next
038: the bosses.
