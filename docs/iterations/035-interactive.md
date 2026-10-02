# Iteration 035 — The interactive pass

**Status:** done -- waiting for the user to play it
**Started:** 2026-10-02 · **Finished:** 2026-10-03

## Goal
Play-test 10, PT10-8: "the entire game's buttons and everything need to feel more interactive".
Every control answers the hand: it rises under the cursor, squashes when pressed, springs back on
release, clicks, and a control that cannot be used says no instead of doing nothing.

## Why nothing answered
Most screens build their own buttons (`_button` in the map, the garage, the bay) and set the
`hover` style to the same style as `normal`, so the cursor changed nothing; only the theme's
default buttons had a hover state, and no button anywhere moved or made a sound.

## Scope
- In: a `Juice` autoload that watches the tree and gives every BaseButton -- any screen, any
  call site, now or later -- a hover lift, a press squash, a release bounce, a hover and a click
  sound, and a shake with a "no" sound when a disabled one is clicked. Two new synthesised
  sounds. Opt-out meta `no_juice`.
- Out: board interactions (the 3D hexes already answer the cursor); controller focus.

## Steps
1. `scripts/autoload/juice.gd`, registered in `project.godot`; `ui_hover`, `ui_click` in `Audio`.
2. Check every input test still lands its clicks (a lifted button is bigger, never smaller).
3. Screenshots mid-hover and mid-press.

## Acceptance criteria
- [x] Every button on the title, map, garage, bay, site panels and fight HUD gets the behaviour
  (a test counts juiced buttons on each screen).
- [x] verify_combat_input, verify_run_ui, verify_onboarding pass unchanged.
- [x] A screenshot shows a hovered button lifted.

## Result

- `scripts/autoload/juice.gd` (autoload `Juice`): on every BaseButton that enters the tree --
  hover scale 1.045 (TRANS_BACK), press 0.93, release overshoot then home, `ui_hover` (-18 dB) and
  `ui_click` (-10 dB), and a disabled control clicked shakes and plays `ui_deny`. One tween per
  button at a time; the pivot follows its size. Opt out with the meta `no_juice`.
- verify_run_ui counts the buttons on the map with the garage open: 23, all juiced. Input tests
  pass unchanged (combat_input 22, run_ui 50, onboarding 39). `tools/shot_hover.gd`:
  `shots/035/title_hover.png` (NEW RUN 364 px wide under the cursor, PRACTICE FIGHT 336 beside it)
  and `title_press.png`.
- Run bot: 56.7%, identical to 033 (presentation only).

## Decisions, lessons, open questions
- One watcher instead of a fix per screen: the hover styles were missing at a dozen call sites,
  and the next screen would have missed them too.
- Open: does it feel right in the hand -- too bouncy, too quiet? Should the board's hexes and the
  map's sites get the same treatment?

## Next
036: comic style.
