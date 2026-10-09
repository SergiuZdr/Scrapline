# Iteration 058 — Feet on the ground, knees the drawn way, a slump for a death

**Status:** done -- waiting for the user's look
**Started:** 2026-10-09 · **Finished:** 2026-10-09
**Answers:** the user on 057: the Brute's legs seemed to lose half their length (knee to foot); Relay
walked backwards with its head turned to one side and its arms still not where they belong; the death
still looked deplorable; when walking or leaning the feet still went under the ground.

## Result
- **Feet anchored to the GROUND**: `_walk_legs` places each foot in the frame of the machine standing
  upright at its base and maps it into the skeleton as it is now (`_ground_to_skeleton`), so leaning,
  recoil, the walk's dip and the slump never carry a foot under the floor.
- **Knees bend the way the model is drawn** (per leg, from the rest knee's side of the hip-ankle line):
  Needle and Relay are reverse-jointed. Forward is the machine's own -Z, not guessed from the toes
  (that pointed Relay backwards). Feet drawn in only 15% (45% crushed the Brute's short shins).
- **Death is a slump**: knees give, hips drop, torso folds forward, arms hang, feet planted; no topple.
- **Relay's frame redrawn** with the head facing forward and the body symmetric (ChatGPT, TRELLIS on
  Hugging Face; `tools/gen3d/raw/parts/ch_strider_v3.glb`).
- `anim_reel.gd` walks a holder node (the rig owns the model's own transform, as in a fight).
- Checks: verify_animation 34, verify_combat 355, verify_assembly 168 (scrap set 58), verify_run 187.

## Open
- The user judges the motion; hand-keyed clips on the same bones if needed.
