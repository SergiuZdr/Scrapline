# Iteration 061 — A death that stays on its hex; solid parts; the Brute's feet and stance

**Status:** done -- waiting for the user's look
**Started:** 2026-10-10 · **Finished:** 2026-10-10
**Answers:** the user on 060: the broken arm flies too far (the machines stand on hexes, parts must
stay on the spot); when the knees give, the legs turn toward the torso, nearly to the chest, and it
lies on its back with them still up at 45 degrees; the core and the arm fall as if not solid (through
each other and the torso); the Brute looks like it holds a boulder between its legs and cannot bring
them closer; its feet (the part on the ground) stretch a lot.

## Goal
Everything that comes off a machine is a solid body and stays on its hex; the death kneels and lies
down like a heavy machine; the Brute's legs, crotch and feet are rigged so nothing stretches.

## Result
- **Solid parts**: a part that breaks off becomes a `RigidBody3D` with a box from its own posed
  vertices (85% of them, boxes are fatter than the pieces); the wreck carries a box per frame bone
  (an `AnimatableBody3D` moved with the bones); a floor plane under the hex; all on physics layer 20
  only. Parts collide with each other, the wreck and the floor; they ignore the wreck for 0.3 s after
  breaking off (they start inside it). A clank on the first hard contact.
- **On its hex**: smaller throws (an arm is knocked off its shoulder, up and a little out), and a part
  that passes `LOOSE_RADIUS` (0.42 of a machine's size) from the middle is turned back and slowed.
- **Kneel** 0.30 of the leg (was 0.52: the knees came up to the chest); as it goes over, the legs go
  slack toward straight (their local poses slerped to rest), so it lies with its legs out on the floor.
- **Brute**: the crotch between the legs (|x| < 0.09) rides up whole with the stretch instead of being
  stretched into a block (`stretch_keep_x`); its feet are drawn in under the hips in the run and the
  stance (`feet_in` 0.32 in the brawler gait).
- **Feet stretching**: the ankle joint sat at the sole, so the foot plate was bound to the SHIN bone
  and stretched whenever the shin turned and the foot stayed flat. All three frames re-rigged with
  `foot_top` (the ankle at the top of the plate, the plate bound to it). Needle's frame is rigged
  from `ch_hauler_v2.glb` (the raw that reproduces the shipped model), Relay's from `ch_strider_v3.glb`.
- `anim_reel.gd --cam x,y,z` films from any side; `--slow` slows the physics too (`Engine.time_scale`).
- Video `shots/061_animatii.mp4`: each crew machine at 1x, at 0.4x, then its death at 0.4x from the side.
- Checks: verify_animation 34, verify_combat 355, verify_combat_input 27, verify_assembly scrap 58;
  probe_floor worst -0.1 cm.

## Decisions, lessons, open questions
- Loose parts are physics; the machine's own motion stays authored. Physics on its own layer only.
- Bind a foot plate to the ankle by height (`foot_top`), not by distance along the leg.
- A front 3/4 camera makes a machine lying on its back (head away) look like it is kneeling: check a
  death from the side.

## Next
The user looks.
