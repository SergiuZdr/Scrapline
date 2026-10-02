# Iteration 035 — The interactive pass

**Status:** in progress
**Started:** 2026-10-02 · **Finished:** —

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
- [ ] Every button on the title, map, garage, bay, site panels and fight HUD gets the behaviour
  (a test counts juiced buttons on each screen).
- [ ] verify_combat_input, verify_run_ui, verify_onboarding pass unchanged.
- [ ] A screenshot shows a hovered button lifted.

## Result

## Decisions, lessons, open questions

## Next
