# Iteration 053 — Scrap Brute fixes; rust that wears off with upgrades

**Status:** done -- waiting for the user's look
**Started:** 2026-10-08 · **Finished:** 2026-10-08
**Answers:** the user on 051's scrap Brute: "i want the robots to have lesser rusty parts with each
upgrade, currently the arms are not connected to the body and both of them need the hammer/saw
rotated to 90 in relation to the shoulder, the body of the new brute is too wide (the shoulder plates
need to be narrower), the front and back modules are sticking out of the body too much also, make the
changes and show me the robot again from more angles".

## Goal
The generated Brute's arms sit in its shoulders with the weapons turned right, its pauldrons are
narrower, its core and backpack sit into the body, and a machine's rust patches clean up as it
levels (0-5). Shown from many angles.

## Scope
- In: `ConstructView._seat_arms` leaves generated frames alone (their sockets are exact); arm specs
  turned 90 at the shoulder; a `squeeze` in the rig for the pauldrons; core and module sockets set
  into the body; a rust mask + clean texture per generated part, read by `Ink` by the machine's level.
- Out: the other machines; the scripted roster (its own wear is unchanged).

## Steps
1. More angles of the current Brute, to read the shoulders. 2. Arms: no push for generated frames, turned.
3. Rig: `squeeze`, sockets. 4. Rust by level. 5. Sheets at several angles and levels. 6. Checks, docs.

## Acceptance criteria
- [x] Arms hang from their shoulders from every angle (`shots/053_angles.png`, 8 angles); weapons turned 90.
- [x] Pauldrons narrower (0.29 -> 0.23 m from the middle); core and backpack set into the body.
- [~] Level 0 vs 5 (`shots/053_levels.png`): the rust patches go, but some clean to grey (the paint
  around them is painted in, and next to a grey plate that is grey).
- [x] verify_assembly 168 (scrap set 15), verify_combat 355, verify_run 187, verify_animation 34.
- [ ] The user looks.

## Result
- **Arms not connected**: `ConstructView._seat_arms` pushed every arm out of the body's box; a
  generated frame's sockets are placed by hand, so it is skipped for them. Both arms' shoulder rings
  faced forward: turned -90 (the hammer first stood up: TRELLIS laid it 35 degrees off horizontal,
  `rotate [0, 55, -90]`), and the weapon then twisted 90 against the shoulder (`twist [share,
  degrees]` in the rig: below a share of the height, about the arm's own vertical). Arms 0.44 m.
- **Too wide**: `squeeze [z, x, factor]` in the rig pulls everything above z and beyond x inward.
- **Modules sticking out**: their sockets sat on the body's surface, so each stood its full depth off
  it; sockets moved in (core y -0.12 -> -0.05, module 0.15 -> 0.07), parts a little smaller.
- **Rust by level**: `rust_map` in the rig finds the texture's rust (orange-brown, darker than paint),
  paints it over from the paint around it and saves `<part>_clean.png` (RGB clean, ALPHA the order each
  rust texel cleans in, smooth noise so patches go in chunks). `ink_toon.gdshader` shows a texel clean
  once `clean` passes it; `Ink.clean_of` reads the level `ConstructView.build_parts` puts on the model
  (level / 5). A generated frame skips the bolted level kit (placed for the scripted frames, it floated
  off this one) and keeps the growth.

## Decisions, lessons, open questions
- **On a generated machine the level shows as rust wearing off, not as bolted kit** (the user).
- Lesson: TRELLIS gives an arm in whatever pose the concept drew it; every arm needs its shoulder
  ring turned to the body and its weapon checked against the shoulder.
- Open: rust that cleans to grey next to grey plates -- paint the patch in from the part's main
  paint instead, if the user wants cleaner level 5 machines.

## Next
The user looks at the angles and the levels.
