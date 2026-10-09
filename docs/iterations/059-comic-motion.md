# Iteration 059 — Comic motion: every robot animation redone

**Status:** done -- waiting for the user's look
**Started:** 2026-10-09 · **Finished:** 2026-10-09
**Answers:** the user on 058: the new models' animations "came out very bad"; redo every animation
(walk, attack, getting hit, dying) so they are interesting and expressive, never "AI slop", and in the
game's comic style (Borderlands).

## Goal
Every machine moves POSE TO POSE, like a comic: strong held key poses (the "panel"), fast snaps between
them, anticipation before every action and follow-through after it, a body that leads and limbs that
drag. The fight shows the strike's impact on the frame the weapon lands, and a death is a short story
the board can read.

## Why the old motion read as slop (diagnosis)
- Every motion was one smooth ease between two poses, all channels at once, at one speed: nothing held,
  nothing led, nothing dragged.
- Arm bones were turned about each BONE's local X, and on generated arms that axis points anywhere
  (the probe: a shoulder's X was (0.8, -0.57, 0.19)), so strikes spun arms about arbitrary axes.
- The torso bone never moved, and the arms/core/module (sockets) could not follow it: the upper body
  was a rigid block on legs.
- In a fight the shot, flash and sound fired the moment a strike STARTED, while the swing landed a
  third of a second later; and a death was never played at all -- the model shrank to nothing.
- The walk was a time-driven cycle under a 0.075 s-per-hex slide: legs flickered while the body zipped.

## Scope
- In: `ConstructRig` rewritten around additive pose CLIPS (keys + holds + curves) over named channels
  (body, torso, each arm's shoulder/elbow/wrist/flare, each foot); joints turned about BODY axes;
  the torso carries the sockets; a run cycle driven by distance; a per-role gait; a strike per weapon
  class; hit reactions with a held impact pose and a stumble; a staged death that ends on the ground.
  Both the generated skeleton machines and the default rigid roster.
- In: the combat scene waits for a strike's impact before the shot, plays the death and only then
  crunches the wreck into scrap; anticipation before a walk.
- Out: hand-keyed Blender clips; new models; sound.

## Steps
1. Probe the bones (`tools/probe_rig.gd`).
2. Rewrite the rig: channels, clip player, arm FK in socket space, torso-carries-sockets, IK legs kept.
3. Walk/run, strikes (10 weapon classes), hits, death; per-role gait.
4. Wire the combat scene (impact timing, death playback, walk anticipation).
5. Reel (`anim_reel.gd`) with contact sheets; tune by looking; tests.

## Acceptance criteria
- [x] verify_animation passes (updated only where the old behaviour is deliberately gone).
- [x] verify_combat, verify_combat_input, verify_assembly pass.
- [x] A reel for each crew machine (generated set) and the default roster: walk, two strikes, hit, death,
      plus contact sheets I have looked at.
- [ ] The user looks.

## Result
- `ConstructRig` rewritten (one public API kept; `strike` now returns the seconds to impact, new
  `set_gait(role)` and `start_lead()`): 22 named channels, additive clips of held key poses with five
  curves (SNAP, SMEAR, EASE, BACK, STEP), joints turned about the MACHINE's axes (front +Z), arm bones
  posed by FK in their socket's frame (mirrored left arms included), the torso bone carries the arm,
  core and module sockets, IK legs kept from 058.
- **Run**: phase follows the distance the holder travels; per-role gaits (brawler stomps and pumps its
  arms, anchor lumbers and sways, marksman bounds); knee-up and a stamp, a sink on each landing, weight
  over the planted foot, shoulders against hips, arms lagging the legs; a crouch before it sets off and
  a brake with follow-through when it stops. The rigid roster's legs now cycle the right way (they
  cycled backwards before).
- **Strikes** (10 classes): hammer/maul up and over, held, slammed with a stamp, held down; saw/ripper
  coil, lunge and a stepped grind; lance drawn back, held, full lunge; railgun brace with a stepped
  charge tremble then a skid back; mortar squat and a thump into the knees; coil/pulse leans into the
  shot with a rising shiver; scanner ticks left/right and locks with a nod; scattergun snap, kick, rack.
- **Hits**: held snap pose (torso with the push, arms thrown, knees give), a stumble step on heavy hits,
  a stepped shudder, the old spring on top.
- **Death**: snap (arms flung), held; a stepped sputter with one arm dying first; knees give, a beat
  kneeling; over away from the killer, land, bounce, rattle; a floor check keeps every bone, socket and
  body corner above the ground.
- **Fight**: the shot/flash/sound wait for the strike's impact; deaths play in the fight (they used to
  shrink to nothing) and the wreck lies 2 s before being crushed into scrap (`WRECK_LIES`, `_dying`);
  a hex takes 0.20 s (`T_STEP`, was 0.075, a slide the legs could not keep up with).
- Tools: `tools/probe_rig.gd` (bones and sockets in the body's frame); `anim_reel.gd` runs at the
  fight's pace from a three-quarter camera. Video: `shots/059_animatii.mp4` (Knuckles, Needle, Relay
  generated, then the default Brute).
- Checks: verify_animation 34/34 (one test reworded: it asserted the old backwards leg direction),
  verify_combat 355, verify_combat_input 27, verify_assembly 168; a 50 s bot fight with the generated
  crew played through without errors.

## Decisions, lessons, open questions
- Motion is pose to pose: held keys, snaps and smears, stepped keys for twitches; never one ease with
  every joint arriving together.
- Turn generated bones about the machine's axes, never the bone's own: a TRELLIS arm's bone X points
  anywhere. Pose a mirrored (negative-scale) arm by converting body-space rotations through its matrix.
- A machine's front is +Z (both rosters); 056-058 code assumed -Z in places.
- Show a strike's effect at its impact, not its start.
- Open: is 0.20 s a hex the right pace for long enemy turns? Hand-keyed clips only if this is still not
  enough.

## Next
The user looks at `shots/059_animatii.mp4` and a fight (`-- --models gen --gen-dir res://art/parts_gen_scrap`).
