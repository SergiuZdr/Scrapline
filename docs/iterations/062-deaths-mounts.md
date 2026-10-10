# Iteration 062 — A death for each loadout; wrecks flat; Needle's and Relay's arm mounts

**Status:** done -- waiting for the user's look
**Started:** 2026-10-10 · **Finished:** 2026-10-10
**Answers:** the user on 061: machines with one or no weapons should die differently; fallen robots
still lie about 30 degrees off the ground; Needle's and Relay's arms are too far from the frame and
not centred on the visual socket.

## Result
- **Three deaths** by what is still bolted on (`ConstructRig._death_two/_one/_none`):
  - two arms (060): one arm breaks off, it looks where it was, one step, reaches with the other,
    the backpack drops, kneels, lifts its head once, goes over BACKWARDS;
  - one arm: knocked back two stumbling steps, hunches and clutches its chest, the backpack drops,
    straightens to reach for its killer, shaking -- the last arm drops off -- sags to its knees and
    falls FORWARD on its face;
  - no arms: looks down at one stump, then the other, sways wider each time, a knee gives on one
    side and it topples SIDEWAYS.
- **Flat wrecks**: going over, the upper body unbends (it was still bowed over its knees), the legs
  turn in under the hips and the feet point along the shins (a frame drawn standing wide lay with its
  legs open and its feet up like flaps); lying, it rests exactly ON the floor (it hovered up to 12 cm
  face-down) and stops bouncing (a micro-bounce never ended, so it never counted as settled); its
  middle slides back over its hex as it falls. `tools/probe_death.gd`: all nine (3 machines x 2/1/0
  arms) settle, lowest point 0.6 cm (the margin), parts within 0.41-0.62 m of the hex's middle (a hex
  is 0.78 to its edge); lying height 0.32-0.82 m (the Brute on its side is its shoulder width).
- **Arm mounts**: the arm sockets of Needle's and Relay's frames are moved to the CENTRE of each
  shoulder's outer face, measured on the mesh (they sat 1.4-1.7 cm low and 2.8 cm behind it); the
  upper arm hangs straight down from its shoulder (`stance_fl`: a drawn arm slanting outward held the
  whole arm off the frame); generated arms are no longer splayed and canted on top of their pose
  (`ConstructView`, the old roster keeps its splay).
- Tools: `shot_machine.gd --hide-arms --marks --dist --aim-y --height --top` for mount close-ups;
  `anim_reel.gd --arms N --death-only`; `probe_death.gd`.
- Video `shots/062_deaths.mp4` (each machine with 2, 1, 0 arms at 0.5x); stills `shots/062_mounts_fixed.png`.
- Checks: verify_animation 34, verify_combat 355, verify_combat_input 27, verify_assembly 168 + scrap 58;
  probe_floor worst -0.1 cm.

## Decisions, lessons, open questions
- A socket goes on the measured centre of the part's visible mounting face, never a guessed number.
- Straightening a bird-leg knee for the lying pose made wrecks TALLER (tried, measured, reverted).

## Next
The user looks.
