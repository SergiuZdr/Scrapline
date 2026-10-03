# Iteration 043 — Play-test 13: the comic UI, the bay, the tier ladder

**Status:** done (awaiting the play-test)
**Started:** 2026-10-03 · **Finished:** 2026-10-03

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
- [x] `verify_combat` 298, `verify_run` 178, `verify_meta` 77, `verify_save` 15, `verify_run_ui` 50,
      `verify_onboarding` 39, `verify_combat_input` 22, `verify_assembly` 168, `verify_animation` 34: all pass.
- [x] Shot: a crowded fight with tags at their machines (`shots/042_tags.png`).
- [x] Shots: title, salvage modal, the fight HUD and the bay in the new look (`shots/043_*.png`).
- [x] A test: a warlord's arm is never torn, and the preview says so.
- [x] A test: a tier opens only by winning the one below and becomes the next run's tier. (NEW RUN
      starting with no choice screen is checked by eye and by `verify_run_ui`, not by its own test.)
- [x] Shot: UNLOCKS with a picture on every row (`shots/043_unlocks.png`).
- [x] Bot batch: 150 runs, **51.3%** won (038: 52.7%), 0 illegal; act losses 9.3 / 19.9 / 29.4%.

## Result
All of the steps landed. Arm intrusion (`tools/probe_arms.gd`, now counting the legs) is at most
6.0% for every frame and arm (0 of 204 over 12%). The title's QUIT button was pushed off the screen
by the new NEXT RUN line, so it moved into the row of small buttons. The arm MODELS were not
regenerated: they are drawn smaller and seated better. If the user still dislikes how they look,
regenerating them is the next step.

## Decisions, lessons, open questions
- The ladder. NEW RUN starts at once. Winning a tier opens the next one and makes it the default.
  The ending is won only on the top tier. Other options were offered in MEMORY.
- A billboard Label3D's AABB is a cube. A StyleBox subclass must export its variables or
  `duplicate()` loses them. Frame a model after its turn.
- Open: more rungs on the ladder; whether the arms need new models.

## Next
The user plays: the look, the ladder, the bay.
