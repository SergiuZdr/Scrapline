# Iteration 017 — Models: the two routes, proved on two models

**Status:** done -- waiting for the user to pick
**Started:** 2026-09-29 · **Finished:** 2026-09-29
**Answers:** play-test 6, PT6-5 ("the game still needs all its models"), by the route the user
picked from [the models plan](../plans/models.md): **machines by the generator, led by concept
art; sites and the Reclaimer generated or from kits; proved on two models first.**

## Goal
One machine and one landmark, each made by its route, stand in the game beside the models they
would replace -- the Brute in the garage and on the board, the workshop on the map -- so the
user can judge both routes before the rest of the roster and the map are made.

## Scope
- In:
  - **Concept art first**: an ink-style concept of the Brute and of the workshop, generated with
    an open image model (FLUX.1-schnell, Apache 2.0: its images may be used commercially).
  - **Route A, the Brute**: the generator builds an ink-first Brute from the concept -- a chunkier
    silhouette, big plates, far fewer small parts (an ink line turns a bolt into a speck) -- as
    the same five-slot machine: chassis with its hip-jointed legs, the Rend Saw and Breaker
    Hammer arms, the Slug core. Built into its own folder; the shipped roster is not
    regenerated (CLAUDE.md: the generator no longer reproduces it exactly).
  - **Route C, the workshop**: the concept image turned into a mesh by an open image-to-3D model
    (TRELLIS, MIT licence) through its public demo, then cleaned in Blender by a script --
    decimated to flat, big faces, coloured into our zones, scaled and seated -- and shown on
    the map in place of the kit-built workshop.
  - **The comparison**: the old and new Brute in the garage and on the board; the old and new
    workshop on the map; one sheet for the user.
- Out (deliberately): any other model; changing which model the game loads by default (the
  user decides after seeing the proof).

## Steps
1. Concept images for the Brute and the workshop.
2. Route A: an ink-first build of the Brute's four parts, exported beside the roster; checks.
3. Route C: image-to-3D for the workshop; the Blender clean-up script; export.
4. The game shows the new models when asked (`--models new`), for the comparison shots.
5. The sheet; docs.

## Acceptance criteria
- [x] The new Brute passes the export contract (`verify_assembly.gd -- --dir res://art/parts_new`:
  15 passed) and walks, strikes and loses an arm like the old one (`verify_animation.gd --
  --models new`: 34 passed; the fight draws it through the same `ConstructView`).
- [x] The new workshop sits on its pad on the map, drawn in ink like everything else.
- [x] A sheet: old/new Brute (garage, board), old/new workshop (map), with the concepts
  (`shots/017_models.png`).
- [x] Every suite passes; the default game is unchanged until the user picks (see Result).
- [ ] The user picks.

## Result

**See it in the game:** `$GODOT --path . -- --models new` (every screen: title, garage, map,
fight). Without the flag the game is exactly as it shipped.

### Route A: the Brute, rebuilt from its concept
`tools/blender/make_ink_parts.py` builds the Brute's four parts from the concept sheet
(`art/concepts/brute.png`) with the generator's primitives and the bridge's whole export
contract (`make_scrap_parts`: frame, `SCALE`, the brawler proportion, sockets, hip-jointed
legs, `mat_<zone>`), into `art/parts_new/`:

| Part | Shipped | New |
|---|---|---|
| Brute Frame (with legs) | 9,768 triangles | 1,716 |
| Rend Saw | 3,008 | 580 |
| Breaker Hammer | 2,948 | 508 |
| Slug Core | 772 | 320 |

- The concept's read, in the game's rules: a wide flat-topped chest carrying one bolted plate
  (the core, with the damage-type lens in it); a small drum head sunk into the chest with ONE
  big eye (the team's colour); square pauldrons as big as the chest's corners; short heavy
  legs, two-tone (painted shin, metal boot) on wide rust-soled feet; the saw a white toothed
  disc under a guard, the hammer a white banded block. Colours stay the game's: each part in
  its own livery (the Brute's frame primer grey, the saw arm olive, the hammer arm orange).
- **The one light value (`alu`) goes on the weapon heads and the core plate**, so at board
  distance (60-80 px) the machine reads as "a saw, a sledge, an eye" before anything else.
- **The back is the side you see most** -- the board's camera stands behind the crew -- so the
  chassis carries a pack with two rust-capped stacks, and the module hangs on the pack (a
  per-chassis socket; the bridge's formula buried it in this deeper chest).
- Pictures: `art/thumbs_new/` (`make_ink_thumbs.gd -- --models new --out res://art/thumbs_new`).

### Route C: the workshop, generated
- **TRELLIS could not be run**: every capable image-to-3D demo on Hugging Face runs on ZeroGPU,
  and one TRELLIS call asks for 120 s of GPU against an anonymous quota that cannot cover it
  ("120s requested vs. 0s left"). A Hugging Face account's token would.
- **TripoSR (MIT, code and weights) runs on this Mac's CPU** instead: 15 s from image to
  triplane, 17 s to a mesh (`tools/gen3d/triposr_run.py`; setup in its header). It rebuilds
  what the image shows; the sides it cannot see come back grey and lumpy, and the crane's
  lattice boom comes back as a solid fin.
- **`tools/blender/clean_generated.py`** makes any generated mesh a set piece: levels it (the
  concept camera's 15 degrees came along), squares its walls to the axes, voxel-remeshes,
  relaxes the ripples, collapses and dissolves to big faces (144,936 -> 3,053 triangles), zones
  each face by the colour under it (several references per zone, speckle voted out, guessed
  grey walls joined to the body, the slab found and made ground), smooth-shades it with sharp
  corners, seats it at 2.6 m. It stands on every workshop site with `--models new`, dressed by
  `Ink.dress_prop` like any landmark.
- Against the old workshop (a thin gantry lost inside its ring) it reads as a PLACE: a yellow
  container on a slab. It also reads as generated: lumpy walls, a fin for a crane.

### The switch
`Models` (`scripts/presentation/models.gd`): `-- --models new` makes `ConstructView`,
`PartText.thumb` and the map take the new file where one exists and the shipped one otherwise,
so one new machine stands among the old in every screen. `ConstructView` caches by path, so a
tool can build both sets in one process (`tools/shot_models.gd` does: old and new side by side,
near and at the board's own distance).

### Suites
| Suite | Result |
|---|---|
| verify_combat / combat_input / run / run_ui / onboarding / save | 189 / 22 / 127 / 48 / 39 / 15 passed (unchanged) |
| verify_assembly | shipped **140** passed (100 + the new leg-pivot checks); new set 15 passed |
| verify_animation | 34 passed; with `--models new` 34 passed |
| run_bot 150 | **88.7%** won, 0 illegal actions, 5.1 fights won a run; the gate held 5, crews wrecked 12 -- identical to 016 (no rule changed) |

The comparison sheet is `shots/017_models.png` (concept, shipped and new for both routes, all
rendered by the game); the pieces are in `shots/017/`.

### Found on the way
- **`alu` never worked.** `PartMaterials.zone_of` did not know the zone the palette has carried
  since 010, so `mat_alu` fell through to `metal` -- in ink, the part's livery. Nothing exported
  it until now, so nothing noticed.
- **`make_scrap_parts.load_parts` broke on `data/parts/makers.json`** (a table, added in 011):
  the roster generator could not have run since. Fixed; it skips anything that is not a list.
- **Blender does not refresh `matrix_world` when `.location` is set**: composing the game
  matrix onto it straight after baked BOTH legs at the pelvis centre -- a one-legged robot.
  `view_layer.update()` first. The shipped bridge was saved by a join in between.
- **A majority vote over `set()` is not deterministic in Python**: string hashing is seeded per
  process, so ties broke differently each run and the export changed. Sorted first.
- **The crew number is stencilled across the core's lens** -- on the old core as on the new: the
  stencil rule (`ConstructView._stencil`) sizes the number to 59% of the plate.

### Different from the plan
- TripoSR instead of TRELLIS for route C (the quota, above); the pipeline takes either one's mesh.
- `verify_assembly` also checks that every chassis's legs pivot at a hip, off the floor.

## Decisions, lessons, open questions
- **New models live beside the old** (`art/parts_new/`, `art/sites/`) behind `--models new`,
  per part, until the user picks.
- **Concept art leads the shapes; the game's rules keep the colours** (livery per part, team in
  the eye, one light value).
- Lesson: a single-image model reconstructs what it sees; level, square and relax it before
  judging, and expect the unseen sides to be guesses.
- Lesson: the side a player sees most of their own machine is its back.
- Open: **the user's pick** -- route A for the whole roster? route C (TripoSR as is, or TRELLIS
  with a Hugging Face token), or B (kits), for the sites and the Reclaimer?
- Open: the stencil across the lens.

## Next
The user picks; then the roster (route A) and the map's sites and the Reclaimer (by the chosen
route) are one iteration, before Acts 2-3.
