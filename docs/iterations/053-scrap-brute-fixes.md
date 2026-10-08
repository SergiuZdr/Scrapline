# Iteration 053 — Scrap Brute fixes; rust that wears off with upgrades

**Status:** in progress
**Started:** 2026-10-08 · **Finished:** —
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
- [ ] Arms touch their shoulders from every angle; weapons turned as asked.
- [ ] Pauldrons narrower; core and backpack no longer stand off the body.
- [ ] Level 0 vs level 5: visibly less rust, no rust on a level 5 machine's big plates.
- [ ] verify_assembly (gen set and default), verify_combat, verify_run pass.
- [ ] The user looks.

## Result

## Decisions, lessons, open questions

## Next
