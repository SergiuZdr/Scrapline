# Iteration 043 — Play-test 13: the comic UI, the bay, the tier ladder

**Status:** in progress
**Started:** 2026-10-03 · **Finished:**

## Goal
Every panel and button wears the look the user picked (pop-art panels, pulp buttons); tags sit at
their machines; bosses and warlords keep their arms; the bay shows whole machines in tidy columns
with arms that sit on the frame; NEW RUN starts at once while the tiers become a ladder the game
cannot be finished without climbing; every unlock has a picture.

## Scope
- In: PT13-1..7 (see `docs/playtests/2026-10-03-playtest-13.md`). This applies 041's chosen option.
- Out (deliberately): new arm MODELS (the arms are re-proportioned and re-seated in the game, not
  regenerated; regenerating the roster is still the open question in MEMORY).

## Steps
1. Tags: measure a Label3D from its font, not its billboard AABB.
2. UIKit: `card`/`ink_card` = pop-art (heavy ink border, red hard shadow, cyan halftone);
   `primary`/`secondary`/`choice`/`ink_button` = pulp (wobbling inked border, ink shadow; the
   primary shaded with a halftone ramp). InkBox speaks StyleBoxFlat's property names so no screen
   breaks; its variables are exported so `duplicate()` copies them.
3. `keeps_arms` on boss and warlord kinds; `_would_tear` refuses (so preview and blow agree).
4. The tier ladder (recommendation below): NEW RUN goes straight in with the remembered crew and
   tier; the title shows the next run's crew and tier with a CHANGE button; a tier opens by WINNING
   the one below it and becomes the default when it opens; the game's ending is an unlock earned
   only by winning the top tier.
5. Bay: even columns, whole-machine framing, arms scaled down and pushed clear of the frame.
6. UNLOCKS: crews show their three machines, tiers a badge.
7. Suites, bot (rules changed: tiers and keeps_arms), docs, main.

## Acceptance criteria
- [ ] `verify_combat`, `verify_run`, `verify_meta`, `verify_save`, `verify_run_ui`,
      `verify_onboarding`, `verify_combat_input`, `verify_assembly` pass.
- [ ] Shot: a crowded fight with tags at their machines.
- [ ] Shots: title, a site modal, the fight HUD and the bay in the new look.
- [ ] A test: a warlord's arm is never torn, and the preview says so.
- [ ] A test: a tier opens only by winning the one below; NEW RUN starts with no choice screen.
- [ ] Shot: UNLOCKS with a picture on every row.
- [ ] Bot batch: win rate within a few points of 042's.

## Result

## Decisions, lessons, open questions

## Next
