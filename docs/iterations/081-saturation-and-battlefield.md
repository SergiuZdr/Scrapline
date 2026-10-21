# Iteration 081 — Machine colour back; real models for the battlefield

**Status:** in progress (lots 1-2 of the battlefield in the game; lot 3, the yard, on Colab)
**Started:** 2026-10-18 · **Finished:** —
**Answers:** the user, after 080: "the robots' colours are now too desaturated, but lighter, which is ok;
now models must be made for every element on the battlefield that does not have a normal model yet (what
you generated yourself looks ugly/basic, like a temporary mock-up)".

## Goal
Machines in saturated colour at 080's lightness; every battlefield element (props, terrain features,
objectives, the yard around the board) a real model made the 069 way: a ChatGPT concept the user
approves, then TRELLIS on Colab, then dressed in ink in the game.

## Scope
- In: `Ink.MACHINE_SAT`; the battlefield inventory below; concepts, approval, Colab, integration in
  `combat_scene` (each builder loads its model, keeps its signal colour and the thick "act on it" line).
- Out: rules; the board's hex surface and curb (drawn, not modelled).

## Inventory (what the fight builds from boxes and cylinders, or from the old Blender kit)
- Acted on: fuel drum (explodes), crate wall (cover), gate pylon (shields the Sorter), coolant tank.
- Terrain features: rubble chunks (rough), slag pool (burns), live wire (shocks), furnace flue (erupts),
  ridge lip (high ground), pit.
- Objects: scrap pile (a wreck's salvage), salvage cache (defend objective), the scrap-carrier mark,
  the hive's fabricator pad.
- The yard around the board (`art/arena`): containers, car stacks, tyre stacks, barriers, floodlight,
  gantry, service gantry.
- Staged on one board: `tools/frames/props.json`; before: `shots/081/props_before.png`.

## Result
- **Saturation**: `Ink.MACHINE_SAT` 1.15 -> 2.0 (tried 1.6: too little on the rust-brown generated
  textures; 2.2 pushed the Brute's yellow to orange). Cards remade. `measure_contrast --fight slag_pit`
  ratio 2.37 -> 2.36 (margin +0.219 -> +0.217): the same within the tool's noise.
  `shots/081_saturatie_inainte_dupa.png`.

- **Lot 1, the props and objects, in the game** (`shots/081_campul_lot1_modele.png`). Concepts approved
  over four sheets: drum (A), gate pylon (B, lattice tower with a red dish), coolant (B, cryo bottle
  bank), cache (A), the scrap pile (the first, green-patched), the hive pad redrawn as a flat floor
  hatch (a robot must stand on it to block a drone), and the crate wall as a welded hexagonal wall block.
  Seven TRELLIS models in one Colab run -> `tools/gen3d/import_props.sh` -> `art/props/<name>.glb`,
  loaded by `Models.prop`, dressed by `Ink.dress_set_piece` with the props' line (`Ink.LINE_ACT`).
  `combat_scene` builds each from its model when one exists and keeps the scripted build otherwise.
  The wall is one block per hex turned square to the pointy-top grid (30 degrees), 1.56 m corner to
  corner, so neighbours close into one wall in a line or bent; the pile turns by cell; the pylon's
  beam leaves from the dish (1.2 m). Close-ups: `tools/shot_props.gd`; board: `tools/frames/props_wall.json`.
- **Lot 2, terrain** (`shots/081_teren_lot2_inainte_dupa.png`). Concepts approved: rubble A, slag B (on
  the ground, no pipe), ridge A (a slag mound, narrowed in the game), pit A, heap B, flue B with the bars
  in concentric hexagons, wire A (a cable out of the ground, no sparks drawn: the game keeps its spark).
  Each is a whole hex tile (`art/props/tr_<id>.glb`, 1.5 m corner to corner), placed by
  `combat_scene._generated_tile` with its riveted plate at the ground's top and turned onto the
  pointy-top grid; the slab, hints and threat marks stay. The ridge is scaled 0.72 wide, 0.5 high and
  machines stand on its top (`RIDGE_TOP` 0.21, presentation only). The flue keeps 48 colours, or its
  painted embers go dark; a glow hex under its grate does not show (the generated grate is solid).
- **Scrap icon** in the map header (`art/icons/scrap_gain.png`, concept A), green like the piles.

## Decisions, lessons, open questions
- The crate wall: per-hex modular blocks that touch beat "block + link" pieces -- no pieces to match
  at the seams. Generated crate stacks read as random boxes; a welded wall reads as a wall.
- ChatGPT drew a "hexagon" with five visible sides twice in a long chat; a new chat with the last image
  as reference and "exactly six sides, not a pentagon" fixed it.
- Posterizing to 16 colours merged the pile's green paint into the rust; the pile keeps 48.
- The drum and the coolant tank 40% smaller (the user): 0.47 and 0.43 m across.
- **Contrast, re-measured with the screen awake** (the fixed tool, `--fight slag_pit`): generated props
  ratio 1.87 (margin +0.145), scripted props (`--props old`) 1.78 (+0.135) -- the new props let the
  machines stand out a little more. Not comparable with 080's 2.37: the tool counted props as machines
  then. The baseline from here is 1.87.
- **Contrast not measured for lot 1 at first.** In this session the game window stopped redrawing while the
  user was away (both the last commit and the change gave a frame with the opening card still up, then
  a stale frame with the HUD the tool had hidden), so the numbers (8.98 / 9.46, 1.46-1.80) mean
  nothing. The tool now waits for the card by the clock and keeps props out of the machine mask;
  re-measure (`--props old` against the default) with the screen awake. Open.
- A staged board cannot be given piles by poking the scene (the opening replays the fight); a fight
  file's `objective.piles` puts them on the board from the start.

## Next
