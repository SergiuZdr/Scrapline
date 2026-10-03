# Iteration 039 — The comic, all the way

**Status:** done -- waiting for the user to look at it
**Started:** 2026-10-03 · **Finished:** 2026-10-03

## Goal
The user, after 038: "I love all the suggestions from the comics list." 036 printed the world on
paper; this makes the game READ as a comic in every layer -- how it talks to the player, how it
shows the enemy's mind, how hits and moves land, how screens are framed, and how the story is told.

## Scope (the eight suggestions)
1. **Speech balloons**: the fight's info panel and every first-time hint are balloons with a TAIL
   pointing at what they talk about (the machine selected or aimed at; the hint's spot).
2. **Thought balloons for intents**: each enemy's order badge sits in a thought cloud with puffs
   trailing to its head.
3. **Sound-effect lettering** on every hit, by damage type (KRANG! kinetic, WHOOMPH! thermal, FZZT!
   EMP, HSSS! corrosive; WHAM! melee, THUD! bumps), one word per attack.
4. **Speed lines** behind a machine that moves or charges; **focus lines** around a heavy hit.
5. **Panel framing**: the board inside a thick inked panel border; every scene change is a page
   turning (a paper panel wipes across).
6. **Comic pages**: site windows, the garage and the run's end with caption-box titles set at a
   slant, panels with hard ink borders.
7. **Models**: uneven ink lines, cross-hatching in the shade band, a white rim highlight.
8. **Story beats**: an act's arrival and a boss's entrance told in comic panels.

Out: new 3D models (the models change by shading and line only); controller support.

## Acceptance criteria
- [x] Screenshots of each of the eight on screen.
- [x] `measure_contrast.gd`: machines vs. surround no lower than 038 (it may only grow).
- [x] `measure_hitches.gd`: no new long frames from the new effects (they are drawn once behind the
  opening card).
- [x] All suites pass (no rules change: the run bot is 038's).

## Result

1. **Speech balloons**: `BalloonTail` (a paper wedge in ink, drawn before its panel): the fight's
   info panel points at the hex aimed at, else the enemy tapped, else the machine selected
   (`_point_info`, every frame, tail capped at 110 px so it points rather than covers); every
   first-time hint has a tail (`Hints.show_once(..., point)`).
2. **Thought clouds**: each enemy with an intent has a cloud over its head -- its place in the
   volley and the damage it plans ("1 · -8") -- with two puffs down to it (`_thought`).
3. **Sound-effect lettering**: the first hit of every attack is lettered by the weapon's damage type
   (KRANG! / WHOOMPH! / FZZT! / HSSS!, WHAM! for kinetic melee), bumps THUD! (`_sfx_word`).
4. **Speed lines** behind every step of a walk or charge (`_streaks`); **focus lines** around a heavy
   hit (`_focus_lines`). Both drawn once behind the opening card.
5. **Panel framing**: the print pass draws a paper gutter and a heavy ink border round the 3D view;
   every scene change is a page turning (the `Juice` autoload, layer 120, never takes a click).
6. **Comic pages**: `UIKit.caption_title` -- every site window, the garage, the upgrade bench and
   UNLOCKS are titled with a tilted caption box (in a holder: a container resets rotation); the
   fight's result is a splash in the sound-effect face.
7. **Models**: cross-hatching in the shade band (one diagonal, then both), a white rim stroke, and a
   brush-like outline that swells and thins along the model.
8. **Story beats**: a boss's or warlord's fight opens as a strip -- AT THE GATE / the boss with its
   portrait in its livery / YOUR JOB with the crew's portraits (`show_opening_strip`); the run's
   briefing is four panels (FORTY YEARS AGO... EVER SINCE... LAST NIGHT... TODAY...); a new act
   arrives as a strip (MEANWHILE... / THE ROAD / AT THE END) via `ComicStrip`.

- Contrast (slag_pit): 2.92 (038: 2.90-2.91) -- hatching first cost 0.02; thinner lines and a
  brighter rim gave it back. Hitches (slag_pit, bot): worst 319-321 ms, 22-25 frames over 40 ms;
  038 measured the same (321-327 ms, 21-22): the long frames are turn planning, not the effects.
- Suites: combat 296, run 177, meta 72, save 15, assembly 140, combat_input 22, run_ui 50,
  onboarding 39 (the hint test now expects the balloon's tail). No rules changed: the run bot is
  038's (52.7%).
- Screenshots: `shots/039/` (thought, balloon, models_crop, strip, briefing, site_crop, fight).

## Decisions, lessons, open questions
- The comic is in how the game TALKS (balloons, captions, strips) as much as how it looks; the
  board's information (totals, intents, HP) stays exactly as legible.
- Lesson: a Container resets its children's rotation and scale when it lays them out -- anything
  tilted inside one needs a plain holder.
- Open: too much? Which of the eight does the user want stronger or quieter?

## Next
The user looks; then whatever play-test 12 says.
