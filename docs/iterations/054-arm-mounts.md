# Iteration 054 — Generated arms bolt into the shoulder ends

**Status:** done -- waiting for the user's look
**Started:** 2026-10-08 · **Finished:** 2026-10-08
**Answers:** the user on 053: "The arm are not placed in the right spot, and they float inside the
actual body/legs".

## Goal
The scrap Brute's arms plug into the round openings at the ends of its pauldrons and hang outside its legs.

## Scope
- In: a `ring` mount in `rig_generated_part.py` (an arm bolted by its shoulder ring's face, not its top
  centre); the frame's arm sockets at the pauldrons' outer faces.
- Out: everything else.

## Steps
1. `mount: "ring"`. 2. Sockets to the pauldron ends. 3. Eight angles; checks; docs.

## Acceptance criteria
- [x] From eight angles the arms come out of the pauldron ends and hang clear of the body and legs
  (`shots/054_angles.png`).
- [x] verify_assembly: scrap set 15/15, default 168.
- [ ] The user looks.

## Result
The arms were mounted by their top centre at sockets inside the pauldrons (x 0.215), so each hung
under its shoulder, through the body and legs. Now each is bolted by its ring's face (the arm's
innermost x, at the middle of its upper ring) to a socket on the pauldron's outer face (x 0.23,
z 0.46), and hangs outside the legs.

## Decisions, lessons, open questions
- Lesson: a generated arm's mount is its shoulder ring, not its bounding box; mount by the part the
  concept drew as the joint.

## Next
The user looks.
