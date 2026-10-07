# Iteration 049 — The hex yard: the run map as a diorama of the board's hexes

**Status:** done (awaiting the user's look)
**Started:** 2026-10-06 · **Finished:** 2026-10-07
**Answers:** PT14-1. From the five mockups (048) the user picked **C, the hex diorama, "with the
comics aesthetics like in battle"**.

## Goal
The run map's ground is the fight board's hexes at map scale, inked and toon-shaded like the
board; sites stand on raised hexes, roads are paved hex paths, the roads you can take wear the
board's move hatching, and the Reclaimer turns the zones it passes into the board's pits.

## Scope
- In: `YardHexes` (cells at map scale, hex paths, zone bands); `YardView` ground, pads, roads,
  road marks, clutter, the Reclaimer's pits, zone captions, the crew walking the road's hexes;
  `shot_run.gd --pan`.
- Out (deliberately): new site models; the camera, fog, labels, picking and every rule (the map
  screen asks the yard the same questions as before).

## Steps
1. `scripts/run/yard_hexes.gd`: odd-r pointy-top cells, `cell_of`, `centre`, `path`, `band_of`.
2. `YardView`: sites snap to hex centres; the hex field per zone (merged), the act's terrain (rubble,
   slag, flues, scrap heaps), each zone's pits; pads and hex rings; paved roads; move hatching on
   the roads you can take; junk on its own hexes; zone captions in the comic face.
3. Checks: verify_run_ui, verify_onboarding; draw calls against the old yard; screenshots in all
   three acts.

## Acceptance criteria
- [x] verify_run_ui passes (it clicks sites on the yard by screen position).
- [x] Draw calls not above the old yard's (`measure_draws.gd --scene res://scenes/run_map.tscn`).
- [~] Screenshots: Act 1 near the crew and the Reclaimer's pits; Act 3's flues seen only behind the
      run-over card, and the Act 2 shot is covered by the act's arrival card.
- [ ] The user looks.

## Result
- `verify_run_ui` **51/51**, `verify_onboarding` passes.
- `measure_draws.gd --scene res://scenes/run_map.tscn` (1920x1080, while bot batches ran, so the
  process times are not comparable): **1410 draw calls, 739k primitives** a frame; the old yard
  1712 and 945k. A thousand hexes merge into a few meshes per zone (`Ink.merge_static`), and the
  outlined hex is built once per shape (`_add_inked`) -- `Ink.line` makes a fresh hull for every
  primitive.
- Screenshots: `shots/pt14/hex_map_1.png` (at the crew), `hex_map_4.png` (the pits),
  `049_sheet.png` (before and after).
- `shot_run.gd` learned `--pan DX DY` and `--act N` (moves start again at every act).

## Decisions, lessons, open questions
- The map's ground is the board's hexes (`YardHexes`, R 1.62 m, three to a zone); sites snap to hex
  centres; a zone's hexes swap for pits when the wall passes (MEMORY decisions).
- Open: does the yard read at the user's zoom and in later acts? (The user looks.)

## Next
050: boss and warlord tricks.
