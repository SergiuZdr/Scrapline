# Iteration 057 — IK walk, staged strikes, kneel-then-fall deaths

**Status:** done -- waiting for the user's look
**Started:** 2026-10-09 · **Finished:** 2026-10-09
**Answers:** the user on 056: "the walk looks very bad, the Brute walks bow-legged, and all three
have their legs going under the ground while walking; in the attack animations I couldn't notice the
details, and at death I didn't understand what the difference is -- anyway it's not realistic".

## Result
- **Walk by IK** (`ConstructRig._walk_legs`, `_solve_leg`, `_foot_step`): each foot is placed -- on
  the floor sliding back in stance, on an arc forward in swing -- and the hip and knee are solved
  (two bones, knee bent toward the walk's forward), the foot kept at its rest orientation. A foot
  cannot go under the floor; feet are drawn in under the hips (`FEET_IN`, the Brute stood wide);
  the body DIPS into each step instead of bobbing up (bobbing up lifted the feet off the floor).
- **Staged strikes** for skeleton arms (`_strike_skeleton`): anticipation held, a short held impact,
  recovery, with the body leaning through the hit spring -- hammer raised overhead then slammed and
  held; saw lunge and grind; gun raised, steadied, hard kick that rocks the machine.
- **Death**: the knees give (hips drop, feet planted by the IK), the arms go slack, then it pitches
  forward from its knees.
- `tools/anim_reel.gd --crew N`: one machine, close, a follow camera and a floor grid;
  `shots/057_animatii.mp4` is the three joined.
- Checks: verify_animation 34, verify_combat 355, verify_assembly 168 (scrap set 58).

## Open
- The user judges the motion. Next if needed: hand-keyed clips in Blender on the same bone names.
