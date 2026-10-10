# Iteration 060 — Motion, second pass: feet, guns, a death that falls apart

**Status:** done -- waiting for the user's look
**Started:** 2026-10-10 · **Finished:** 2026-10-10
**Answers:** the user on 059: the Brute's legs need to be longer; the shooting attacks need redoing
(better); the death still looks bad -- "it should fall apart, but in an emotional way"; the run was
too fast to tell whether it was right; the feet still go through the ground.

## Goal
Nothing of a machine goes under the floor, measured on its real vertices; guns aim level at the
target and kick; a death is a machine coming apart and minding it; the Brute stands on longer legs;
slow-motion reels to judge by.

## Steps
1. A measurement first: `ConstructRig.lowest()` from each skinned mesh's vertices per bone;
   `tools/probe_floor.gd` runs, strikes and hits every crew machine and reports the worst.
2. Fix what it finds; longer Brute legs in the rigger (`leg_stretch`).
3. Guns, then the death; reels at 1x and 0.4x (`anim_reel.gd --slow`).

## Acceptance criteria
- [x] probe_floor: worst under 1 cm for the generated crew and the default roster (was 17-22 cm).
- [x] verify_animation 34, verify_combat 355, verify_combat_input 27, verify_assembly 168 + scrap 58.
- [x] `shots/060_animatii.mp4`: each crew machine at 1x then 0.4x, then the default Brute.
- [ ] The user looks.

## Result
- **Why feet went through the floor** (measured, not guessed): bending knees swung the bottom of the
  shin under the ground (the IK solved the knee in the pure forward plane, not where it is drawn); the
  foot kept its pose square to a LEANING body (toe under); a death clip's last pose was added twice on
  the frame it ended; and on the rigid roster a crouch lowered the body on stiff legs. Fixed: the knee
  bends toward its drawn side (`pole`), the foot stays flat to the ground, a per-leg guard lifts a foot
  until no leg vertex is under the floor, stiff legs SPLAY to crouch, and a last-resort lift for stiff
  legs. Arms are guarded too (a hanging hammer swings onto the floor, not through it). Worst now
  -0.5 cm (generated) / -0.1 cm (default), from -17.5 / -21.6.
- **Brute's legs** 1.5x between the feet and the hips (`leg_stretch` in `rig_generated_part.py`,
  spec `ch_brute_scrap.json`); the body and sockets ride up with them.
- **Guns** (`_gun_aim`): the gun arm comes up to shoulder height with the forearm kept LEVEL (the elbow
  undoes the shoulder's raise -- before, raising the arm tilted the barrel at the sky), shoulders
  squared, the other arm braced, feet set front and back; arrives with an overshoot and holds. Then per
  class: scattergun BOOM (barrel flips, body snaps back, slides a step) and a stepped rack; railgun a
  rising stepped charge tremble and a skid back feet-and-all; pulse/coil leans in, shivers, pushes the
  bolt OUT then bucks; mortar thumps down into its knees; scanner points, ticks across, locks, pings.
- **Death** (about 2 s standing, then over): the snap; the arm on the hit side BREAKS OFF and flies;
  it reels from the lost weight and turns to look where the arm was; one faltering step and the other
  arm reaches out, shaking; the backpack drops off; the knees give; on its knees it lifts its head once,
  bows -- and goes over away from its killer; landing, its core rolls out and the last arm comes loose.
  Loose parts fall, bounce dully and settle on the floor (their own vertices against it). The fight
  throws sparks and KRAK!/CLUNK!/TINK! as parts come off (`ConstructRig.on_break`); the wreck lies
  3.6 s before it is crushed into scrap.
- Tools: `tools/probe_floor.gd`; `anim_reel.gd --slow K`, lit-side camera following the machine.

## Decisions, lessons, open questions
- Measure penetration on the posed VERTICES (per-bone samples of the skin), never on bone points or
  bounding boxes: it named the shin, the hammer and the core as culprits in minutes.
- A packed array read out of a Dictionary is a copy: appending to it changes nothing.
- When a clip ends, check "was it playing" BEFORE advancing it, or its last pose counts twice.
- Open: the death's parts come off the same way every time; the user may want variety.

## Next
The user looks at `shots/060_animatii.mp4`.
