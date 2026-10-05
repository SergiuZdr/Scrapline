# Iteration 045 — Generated machines: a proof on the Brute

**Status:** in progress
**Started:** 2026-10-05 · **Finished:** —
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
- [ ] `verify_assembly.gd -- --dir res://art/parts_gen` passes for the five parts.
- [ ] The gait preview walks the generated Brute: legs swing at the hips, the torso stays whole.
- [ ] A fight with `--models gen` draws the generated Brute with its texture and ink line; arms tear.
- [ ] In grey the machine still separates from the board; `measure_contrast.gd` ratio not lower.
- [ ] Under 22,000 triangles for the whole machine.
- [ ] verify_combat, verify_run pass; the default game draws exactly what it drew before.
- [ ] The user looks.

## Result

## Decisions, lessons, open questions

## Next
