# Iteration 055 — The starting crew as comic scrap

**Status:** done -- waiting for the user's look
**Started:** 2026-10-08 · **Finished:** 2026-10-09
**Answers:** the user on 054: the wrists looked "cursed" and the arms showed no elbow; then "make them
3D and show me the model with all the components together, and continue making the GPT images for the
other robots". On Needle and Relay's first bodies: modules baked into the frame, a strange pose, a round
thing on Relay's chest, and a spotter arm that "screams AI vibes".

## Goal
Knuckles (Brute), Needle and Relay all exist as generated comic-scrap machines, every part its own
model, arms with a readable shoulder and elbow, drawn with `--models gen --gen-dir res://art/parts_gen_scrap`.

## Scope
- In: new Brute arms; Needle (ch_hauler, co_furnace, ar_lance, ar_pulse, mo_ablative) and Relay
  (ch_strider, co_arc, ar_scanner, ar_pulse, mo_governor) from ChatGPT concepts through TRELLIS.
- Out: the rest of the roster; enemies.

## Acceptance criteria
- [x] Three machines from 8 angles (`shots/055_{brute,needle,relay}_angles.png`).
- [x] verify_assembly: scrap set 43, default 168; verify_combat 355; verify_run 187.
- [ ] The user looks.

## Result
- **Arms**: the 053 twist (90 degrees below the wrist) mangled the joint. Every arm is now DRAWN in
  one layout -- side view, round shoulder face toward the viewer, a visible elbow hinge with a piston,
  the forearm bent ~30 degrees forward, the weapon pointing the way it bends -- and only turned whole
  in the rig, never twisted. A `mirror_x` step exists for an arm TRELLIS returns as a left arm.
- **Bodies** are only head, torso, hips and legs (cores and modules are swappable parts and are never
  drawn on the frame), standing square; Needle drawn leaner than the Brute so the silhouettes differ.
- **Spotter array** redrawn as one tool: a boxy rangefinder with one lens.
- **Pulse emitter** is one model on both Needle and Relay: a part looks the same on any machine.
- Colab's free GPU hit its daily limit on 2026-10-09; the last three models went through the
  Hugging Face allowance (`next_part.sh`) instead.

## Decisions, lessons, open questions
- An arm's pose is set in the CONCEPT (one layout for all arms); the rig only turns it.
- A frame concept is drawn bare: no core, module or rack.
- Open: Relay's olive reads tan after grading; the rest of the roster.

## Next
The user looks; then the roster, machine by machine.
