# Iteration 056 — Skeletons and animation for generated machines

**Status:** done -- waiting for the user's look
**Started:** 2026-10-09 · **Finished:** 2026-10-09
**Answers:** the user: "none of the robots has the arms in the right position" and "how will the
attack, walk, hit and death animations be made?" They picked a FULL SKELETON (over rigid pieces or
procedural splits) and a rest pose that depends on the weapon (hand weapons at the side, guns aimed).

## Goal
Every generated part carries a skeleton with standard bone names, and ConstructRig drives them: knees
bend in the walk, arms rest by weapon, elbows work in strikes, knees fold on death.

## Result
- `rig_generated_part.py --skeleton`: frame bones `torso`, `hip/knee/ankle_l/r`; arm bones `shoulder`,
  `elbow`, `wrist`. Joints are found from the geometry (the centroid of the ring of vertices at a share
  of the limb's length from its root -- works for any drawn pose); every vertex bound RIGIDLY to one
  bone (metal does not stretch). Bone local X is the lateral axis on every bone, so one turn sign
  means "swing forward" everywhere.
- `ConstructRig`: finds the skeletons by bone name; walk bends the knees (`KNEE_BEND`) and keeps the
  feet level; `set_stances(classes)` (called by the combat scene) turns each forearm to a target pitch
  worked out from that arm's own rest geometry -- hand weapons hang (`PITCH_MELEE`), guns are level
  (`PITCH_AIM`); strikes add elbow and wrist motion; a skeleton gun kicks back through the shoulder
  instead of sliding out of it; death folds the knees.
- **Death sank every wreck halfway into the floor** (scripted models too): the topple pivoted on the
  middle of the feet. It now pivots on the footprint's edge (`_reach`, `_pivot`).
- `verify_assembly.gd` accepts skeleton frames (bones present, hips off the floor): scrap set 58/58.
- `tools/anim_reel.gd`: the crew walking, striking, hit and dying, for the movie writer
  (`shots/056_animatii.mp4`). `shot_machine.gd --walk/--die`.
- Checks: verify_animation 34, verify_combat 355, verify_assembly 168.

## Decisions, lessons, open questions
- Bone names are the contract: any arm with shoulder/elbow/wrist plays every arm motion.
- Lesson: a pose drawn into a generated arm differs per part; a rest pose must be computed from each
  arm's geometry, not a fixed angle (fixed angles pointed the guns at the sky).
- Lesson: topple about the footprint edge; about the middle, half a wreck goes underground.
- Open: hand-authored keyframe clips (Blender actions) if the procedural curves are not enough.
