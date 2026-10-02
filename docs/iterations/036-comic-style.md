# Iteration 036 — Comic style (the frame)

**Status:** done -- a style frame, waiting for the user's verdict
**Started:** 2026-10-02 · **Finished:** 2026-10-03

## Goal
Play-test 10, PT10-10: "I'd love it if the game had more of a comic's art style, on the UI and the
3D models". Ink & Rust (015-016) already draws the game as a comic -- toon bands, halftone, ink
outlines, InkBox panels with hard shadows. This pushes it further toward PRINT, as a frame the user
judges before it spreads to every element.

## Scope
- In: a print pass over the 3D world (fight, map, title): dot screens in the shadows, the colour
  plates slightly misregistered, paper grain and warm highlights -- under the HUD, so the
  interface stays crisp; heavier ink lines; damage and threat totals in STARBURSTS; the round
  lettered in a CAPTION BOX. `-- --look plain` turns the print pass off, for comparing.
- Out (if the frame is approved): speech-balloon hints and tooltips, speed lines on moves and
  shots, panel borders around the board, the garage's stage printed too, models redrawn.

## Steps
1. `scripts/presentation/ink_print.gdshader` + `Ink.print_pass(parent, layer)`.
2. Lines 1.6 / 2.2 / 3.0 -> 2.0 / 3.0 / 3.6; badges as bursts; the banner in a caption box.
3. Frames before and after; contrast measured (it may only grow).

## Acceptance criteria
- [x] The fight, the map and the title are printed; the HUD and menus are not.
- [x] `measure_contrast.gd` (slag_pit): no lower than without the pass.
- [x] All suites pass.
- [ ] The user approves the direction (a frame, not the finished look).

## Result
- Frames: `shots/036/comic_sheet.png` (fight, map, title; left without the print pass, right
  with it) and `shots/036/comic2.png` (the final strength). The pass: a 6 px dot screen at 45
  degrees below luminance 0.3 at 60%, plates 1.5 px apart (2.0 fringed the board's lettering),
  grain 9%, highlights warmed 6%.
- Contrast (slag_pit, quiet machine): 2.90-2.91 without the pass, 2.91 with it. An earlier 2.97 /
  2.84 pair was measured while 15 bot processes ran: under load the tool varies more than the
  difference being measured.
- Suites: combat 288, run 177, meta 72, save 15, assembly 140, combat_input 22, run_ui 50,
  onboarding 39. No rules changed (the run bot is 035's: 56.7%).

## Decisions, lessons, open questions
- Print the WORLD, not the interface: the pass sits on a CanvasLayer under the HUD's (layer 0 under
  1 in the fight; -1 under the map and title's controls), so text stays sharp.
- Lesson: measure looks on a quiet machine; a contrast reading taken under bot load moved by more
  than the change.
- Open: is this the comic the user means? Stronger (bigger dots, more slip), weaker, or a different
  idea (speech balloons, speed lines, panel frames)?

## Next
After the user's verdict: spread the approved look (balloons, speed lines, the garage stage).
