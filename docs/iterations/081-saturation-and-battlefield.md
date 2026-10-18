# Iteration 081 — Machine colour back; real models for the battlefield

**Status:** in progress (battlefield concepts wait for the user's approval)
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

## Decisions, lessons, open questions

## Next
