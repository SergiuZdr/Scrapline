# Iteration 080 — Cores and modules close to the body, dark parts readable, a tighter garage header

**Status:** done (the user plays and judges)
**Started:** 2026-10-18 · **Finished:** 2026-10-18
**Answers:** the user, after 079: "many cores and modules take too much room in front of / behind the
robot; with the current filter some parts look practically all black, from the outline to tiny details
-- what is the fix?; the garage's top bar a little smaller and the middle panels extended up; in the
middle panel some text shows '...' instead of fitting the whole word -- make it fit inside the panel".

## Result
- **Depth.** Measured: cores and modules sat flush on the torso with their whole depth outside it, up to
  0.19 m on a 0.58 m frame. `ConstructView._seat_depth` squashes each toward its mount (to no less than
  60% of its depth) and sinks it into the torso (at most 40% of the torso's thickness) until it stands
  out no more than 0.07 m (core) or 0.08 m (module). Worst over every frame and part after: 0.074 / 0.087.
- **Black parts.** Four causes in `ink_toon.gdshader` + `Ink`: texels under 15% luminance inked; every
  weak edge of a generated texture's speckle inked; the unlit side at pure black; a 3 px hull swallowing
  small details. For machines only (`Ink.comic_machine`): ink below 6%, edges above 0.17 read from a
  coarser mip, the darkest posterised step at least 0.26, the unlit side at 0.3 (the hatching still inks
  the shade), the machine line 3.0 -> 2.4 px. `measure_contrast --fight slag_pit`: ratio 1.99 -> 2.37,
  margin +0.154 -> +0.219 (contrast may only grow: it grew). Cards remade with the new print.
- **Garage.** Header 72 -> 54 px (tabs 48 high, title 34), the three panels start 30 px higher (the
  bay 450 high). LOADOUT names: one line when it fits at 14 px, else two lines broken after the name;
  summaries on up to three lines; `UIKit.fit(..., slack)` measures against a narrower box, because the
  comic face renders a tuned part's "+" wider than `get_string_size` reports -- that was the "...".
  Checked for every part in every socket: all fit.
- Sheets: `shots/080_adancime_inainte_dupa.png`, `shots/080_filtru_inainte_dupa.png`,
  `shots/080_carduri_inainte_dupa.png`, `shots/080_garaj_inainte_dupa.png` (before from a copy of `main`).
- `tools/check.sh` all green (verify_combat 370/0, verify_combat_input 27/0, verify_run 187/0,
  verify_run_ui 51/0, verify_save 15/0, verify_onboarding 39/0, verify_meta 77/0, verify_assembly 168/0,
  verify_animation 38/0); after the last text change verify_run_ui 51/0 and verify_onboarding 39/0 again.
  Not run: `run_bot.gd` (presentation only).

## Decisions, lessons, open questions
- **A machine's print keeps a value in the dark**: ink only true blacks and strong edges; the shade is
  hatched, not filled.
- Lesson: `Font.get_string_size` can under-measure the comic face; fit text with slack.

## Next
- The user plays and judges.
