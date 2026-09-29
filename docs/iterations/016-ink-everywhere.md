# Iteration 016 — Ink & Rust everywhere

**Status:** in progress
**Started:** 2026-09-29 · **Finished:** —
**Answers:** [play-test 6](../playtests/2026-09-29-playtest-6.md): PT6-1 (the look, everywhere),
PT6-2 (the shot's two sides), PT6-3 (every panel in the new design), PT6-4 (text and ability
descriptions); and from play-test 5, R5-2 (HUD competition) and the labels that overlap.
PT6-5 (new models) is the next iteration: this one dresses the geometry that exists.

## Goal
Every screen of the game -- title, briefing, assembly bay, the map, every site panel, the garage,
the glossary, the fight, the results -- is drawn in Ink & Rust and reads as one comic; the
fight's HUD asks for less attention; no two labels on the board overlap; and a shot along hex
edges takes the side that does more, never an obstacle it did not need.

## Scope
- In:
  - **Shots (PT6-2)**: both sides of an edge-aligned line are played out in `strike_plan` and
    the better one fired -- first the one that reaches the aimed hex, then the one that does
    more for the shooter (`_shot_value`, the arc's scale), then the one through fewer
    obstacles. Both teams; the preview, the AI and the shot agree.
  - **The interface kit goes ink**: `UIKit`'s palette and styles become paper, ink and hard
    shadows, and the theme follows, so every screen built from the kit changes at once; then a
    pass per screen for what sits on the dark page or the 3D world (paper lettering with an ink
    edge there) and for layout.
  - **The 3D worlds go ink**: the map (ground, roads, sites, clutter, skyline, the Reclaimer,
    drones, the crew, fog as unfinished drawing), the title stage, the garage bay, the assembly
    bay and every portrait.
  - **The fight's HUD asks for less** (R5-2): the machines not picked shrink to a slim row; card
    lines say less, so nothing is cut off.
  - **Board labels never overlap**: tags, badges and marks are laid out in screen space each
    frame; a badge's MISSES/LOCKED reads beside it.
  - **Text (PT6-4)**: ability descriptions and weapon lines reviewed for phrasing and shown where
    the choice is made.
- Out (deliberately): new models for machines, sites and the Reclaimer (017, PT6-5); new
  animation; audio.

## Steps
1. Shots: both sides played out; tests; run bot.
2. `UIKit` ink palette, styles and theme.
3. Per screen: title, briefing and assembly, the map and its panels, the garage, the glossary and
   hints, the fight's results and recap.
4. 3D: the map, the title stage, the garage bay, portraits.
5. The fight's HUD: slim rows for machines not picked, shorter card lines, label layout, badges.
6. Text: abilities and weapons.
7. Screenshots of every screen; every suite; run bot; docs.

## Acceptance criteria
- [ ] verify_combat: a beam past its target takes the open side over a crate wall (both ways
  round), and the side with a second enemy; the existing leaning checks still pass.
- [ ] run_bot 150 recorded (85-92%), 0 illegal actions.
- [ ] Every suite passes (UI tests click the real screens).
- [ ] Screenshots of every screen in the new look, on one sheet, with no photographed surface,
  no default theme and no light-on-dark leftovers.
- [ ] On a crowded board no two labels overlap (a screenshot of the defend fight from PT6).
- [ ] The user plays it.

## Result

## Decisions, lessons, open questions

## Next
017: models (PT6-5) -- machines, sites and the Reclaimer rebuilt for the ink style, by the route
the user picks (the generator reworked, open-licence kits, or generated models).
