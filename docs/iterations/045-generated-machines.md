# Iteration 045 — Generated machines: a proof on the Brute

**Status:** done -- waiting for the user's look
**Started:** 2026-10-05 · **Finished:** 2026-10-07
**Answers:** the user: "till now u made them using scripts in blender and the result were bad to say
the least, i need u to find way we can make better robots that will match the aesthetics of the game".
They picked **AI image-to-3D** (the route that made the sites), **proved on one machine first**.

## Goal
The Brute's five parts (ch_brute, ar_saw, ar_hammer, co_slug, mo_scavenger) exist as TRELLIS
models that keep the part contract (sockets, hip-pivoted legs, mounts at the origin), and the game
draws them with `-- --models gen` so the user can compare them with the scripted machines.

## Scope
- In: a FLUX concept per part (picked by the user before any TRELLIS run); `tools/gen3d/next_part.sh`;
  `tools/blender/rig_generated_part.py` (clean, orient, size, split the legs, add sockets);
  `art/parts_gen/`; `Models` learns `--models gen`; `Ink.dress_machine` keeps a part's texture.
- Out (deliberately): the rest of the roster (the user decides after the proof); the default game
  (unchanged until the user picks); unique boss models.

## Steps
1. Concepts: 3 variants per part, one sheet, the user picks.
2. `next_part.sh <id>` per part (five TRELLIS runs, about a day's allowance).
3. `rig_generated_part.py` per part, guided by `tools/gen3d/parts/<id>.json`.
4. Game: `Models` (`--models gen`), `Ink._dress_node` textured path, thumbs.
5. Checks; sheets; docs.

## Acceptance criteria
- [x] `verify_assembly.gd -- --dir res://art/parts_gen` passes (15/15; the default set 168/168).
- [ ] The gait preview walks the generated Brute -- not run; the round's video shows it walking.
- [x] A fight with `--models gen` draws the generated Brute with its texture and ink line
  (`shots/045_round.mp4`, `shots/045_compare.png`). Arm tearing not checked separately.
- [ ] In grey / `measure_contrast.gd` -- not run.
- [x] Under 22,000 triangles: 20,264 (frame 7,756, arms 3,912 + 3,940, core 2,500, module 2,156).
- [x] verify_combat 352, verify_run 187 pass; the default game is unchanged (`--models gen` is opt-in).
- [ ] The user looks.

## Result
**2026-10-05 (day 1): tooling done, waiting on the GPU allowance.**
- Built: `tools/gen3d/part_concept.sh` (FLUX prompts in `part_concepts.json`), `tools/gen3d/next_part.sh`
  (TRELLIS, raw kept in `tools/gen3d/raw/parts/`, `--rig` reruns without GPU),
  `tools/blender/rig_generated_part.py` (size, cut FLUX's arms off a frame, split the legs at the hips,
  sockets, mount at the origin; spec per part in `tools/gen3d/parts/<id>.json`), `Models` `--models gen`
  (`art/parts_gen/` first), `Ink._dress_node` keeps a textured part's texture under the ramp.
- Smoke test: a raw TRELLIS site rigged as a stand-in chassis passed `verify_assembly.gd -- --dir
  res://art/parts_gen` (15 passed) and drew in a fight with `--models gen` without errors; removed after.
- Concepts (`art/concepts/machines/`): 3 chassis, 4 hammer arms, 1 saw arm before the allowance ran out.
  **The user picked ch_brute_3** and **hammer 1 "but the head of the hammer needs to have no hole"**:
  the hole was painted out by hand (`ar_hammer.png`). Still to come: saw, core and module concepts.
- **FLUX draws arms on a frame however the prompt says "without arms"** (all three did): the rig cuts
  them off below the shoulders instead (`cut_arms`).
- **FLUX's Space spends the same ZeroGPU allowance as TRELLIS**: eight concepts, then TRELLIS was refused.

**2026-10-06/07: the free allowance was too slow; Colab was not.**
- On the free Hugging Face tier the frame took a day (one TRELLIS run plus seven concepts emptied a
  rolling 24 h). The user chose to stay free and use **Google Colab's free T4**: the notebook
  `tools/gen3d/trellis_colab.ipynb` makes a model in ~1 minute (hammer 57 s, saw 57 s, core 101 s,
  module ~60 s), after a ~20 min install per runtime. Claude drove it in the user's Chrome.
- What it took to run TRELLIS on Colab (all in the notebook): runtime **2025.07** (Python 3.11,
  torch 2.6/cu124 -- the latest runtime is Python 3.13, no spconv wheel); xformers 0.0.29.post3
  (the T4 cannot run flash-attn 2); **pyvista 0.43.10 + vtk 9.3.1** (the newest pyvista wants a newer
  IPython); **`CUMM_DISABLE_JIT=1`** (cumm thinks it is an editable install and tries to compile
  itself, which fails); stand-ins for `open3d` and `kaolin` (only text-to-3D and flexicubes' asserts
  import them); restart the session after installing.
- The user picked saw 1, core 1 and module 2 (feet cut, `cut_below`).
- **Rig fixes found by looking**: the frame came back facing sideways on a plinth (`rotate`,
  `floor`); FLUX drew arms on it anyway (cut by a measured width profile: legs |x| < 0.24, a gap,
  then the hanging arms); the arms' concept drop shadow became a disc (`drop_shadow`: a loose,
  mostly pale piece in the bottom quarter -- a thinness test tore real plates off, since a TRELLIS
  model is many thin shells); in the fight the Brute read **cream** -- TRELLIS bakes its render's
  highlights into the texture and the board camera looks down at them (`grade`: saturation 1.45,
  highlights under 0.62, then 10 flat colours); at 0.78 m with its pauldrons it spilled off its hex
  (now 0.64 m, arms 0.42).
- `tools/record_round.gd` + Godot's `--write-movie` recorded a round with the bot playing
  (`tools/frames/045_brute.json`, the default crew on Container Row).

## Decisions, lessons, open questions
- **Machines can be generated per slot and keep the part contract**: each slot is its own concept
  and its own TRELLIS model; only a frame's legs are cut apart. Proved on the Brute, opt-in
  (`--models gen`) until the user decides.
- **Free generation runs on Colab, not the Hugging Face allowance** (about a minute a model).
- Lesson: TRELLIS bakes the concept render's highlights into the texture; grade it before it meets
  the toon ramp, which shows a texture's lit colour exactly.
- Lesson: a TRELLIS model is many thin loose shells: never remove pieces by shape alone.
- Open: does the user want the roster this way? About 60 parts, roughly an hour of Colab plus a
  rig spec per part (the frames need their hips and sockets read off a width profile).

## Next
The user looks at `shots/045_round.mp4` (or plays with `-- --models gen`) and decides on the roster.
