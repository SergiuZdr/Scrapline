# Iteration 016 — Ink & Rust everywhere

**Status:** done -- waiting for the user to play it
**Started:** 2026-09-29 · **Finished:** 2026-09-29
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
- [x] verify_combat: a beam past its target takes the open side over a crate wall (both ways
  round), and the side with a second enemy; the existing leaning checks still pass.
- [x] run_bot 150 recorded (85-92%), 0 illegal actions.
- [x] Every suite passes (UI tests click the real screens).
- [x] Screenshots of every screen in the new look, on one sheet (`shots/016_everything.png`),
  with no photographed surface, no default theme and no light-on-dark leftovers.
- [x] On a crowded board no two labels overlap (the defend fight of play-test 6, `14_fight`).
- [ ] The user plays it.

## Result

| Suite | Result |
|---|---|
| verify_combat | **189** passed (183): a crate wall on either side past the target leaves the wall standing and hits the target; a second enemy on one side draws the beam through both |
| verify_combat_input / run / run_ui / onboarding | 22 / 127 / 48 / 39 passed -- the fight, the map, every site panel and the shakedown driven through the restyled screens |
| verify_save / assembly / animation | 15 / 100 / 34 passed |

**Shots (PT6-2)**: run bot **88.7%** won (86.7%), 0 illegal actions, 5.1 fights won a run.
Both sides now pick the better side of a line: the gate held 5 times (12) -- piercing shots
reach the pylons behind the Sorter more often -- and whole crews wrecked 12 times (8), the
enemy's shots being smarter too. Inside the 85-92% band.

**Every screen** (`shots/016_final/`, one sheet: `shots/016_everything.png`): title, briefing,
assembly bay, the map, the fight panel, salvage, workshop, tuning, garage (parts and stats),
the perk pick, the glossary, the shakedown's coach, a fight, the decision frame.

- **The kit**: `UIKit`'s constant names kept, their values paper and ink, so every screen built
  from it changed at once; `card()` and the button styles are paper with a 3 px ink border and
  a hard offset shadow; the theme's buttons are Anton and drop onto their shadow when pressed
  (`UIKit.pressed`); `font_display()` is Anton. What sits on the dark page or over the 3D
  world is lettered in paper with an ink edge (`UIKit.on_page`).
- **The map**: the fight's light, hatched ground, roads as bold strokes (reachable ones in your
  blue), landmarks drawn in a livery per kind of site (`Ink.dress_prop`), icon badges on ink
  discs ringed in the site's state, reclaimed ground hatched red, the Reclaimer black edged in
  dark red and lit only by its teeth and beacons, and fog as **unfinished drawing**
  (`ink_fog.gdshader`: pencil hatching with a ragged edge).
- **The title stage, the garage bay, the assembly bay, the dock** in ink; a lit garage part gets
  a thick amber line.
- **Thumbnails** rendered by the game in ink (`tools/make_ink_thumbs.gd` -> `art/thumbs_ink/`).
- **The fight's HUD (R5-2)**: machines not picked are slim rows; card lines fit; ability cards
  say what the ability does ("move 2 more · free · cooldown 2"); labels never overlap.
- **Text (PT6-4)**: every ability's text rephrased effect-first, with a `short` for its card.

### Found on the way
- **A world-height offset is half an offset on screen.** The camera looks down at 56 degrees,
  so a badge raised 0.4 m above a billboard tag showed about 0.2 m up and sat on the tag's
  first line. Badges and scrap marks are lifted in the billboard's own plane now (`offset`),
  which is also the only way the scrap mark stays on the LEFT after a Q/E camera turn.
- **A label's size is stale for a frame after its text changes**: `Label3D.get_aabb()` measures
  the old text until the mesh is rebuilt. The badge measures the tag from its text.
- **`material_overlay` is the ink line's slot**, and the garage used it to light a part -- which
  would have stripped the part's line for good when the light went off.
- **The toon ramp draws the directional key alone**: every point light and spot (lamps, the
  title's floodlight, the drones' searchlights) did nothing to a toon material. Lamps are lit
  bulbs now; the title is keyed by a directional light.
- **Amber text does not read on paper.** Selected tabs and "YOU ARE HERE"-style lines were amber
  lettering; the selection is an amber border now and the lettering stays ink.
- The garage's STATS tab and the tuning bench's option column put text straight on the dark
  page; both are on paper cards or lettered on the page now.
- The ability texts are in the content hash (`combat_abilities`): **a run saved before 016 will
  not resume.** That is the right outcome this time -- the shot rule changed too, in code the
  hash cannot see, and an old save replayed under it could quietly play out differently.

### Different from the plan
- Nothing was modelled: every screen is dressed from the geometry that exists. New models are
  017 (PT6-5).
- The scenery (containers, cranes, the skyline) is drawn as monochrome silhouettes rather than
  redrawn; the landmarks keep colour.

## Decisions, lessons, open questions
- **Ink & Rust is the whole game's look** (the user's verdict on the frame).
- **A shot along hex edges fires the better of its two sides**: the one that reaches the aimed
  hex, then the one that does more for the shooter, then the one through fewer obstacles.
- **Selection is an amber border; lettering on paper is ink.**
- Lesson: offset a billboard's companions in the billboard's plane, never in world height.
- Open: which route for the new models (017)?

## Next
017: models (PT6-5) -- machines, sites and the Reclaimer rebuilt for the ink style, by the route
the user picks (the generator reworked, open-licence kits, or generated models).
