# Iteration 042 — A model for every part

**Status:** done -- waiting for the user to look
**Started:** 2026-10-03 · **Finished:** 2026-10-03

## Goal
Play-test 12, PT12-6: "the game lacks models for each robot part". Twenty-six parts wore another
part's model (`"model"`): the twelve modules of 033, ten parts of 029, the five legendaries and two
older ones. After this every part has its own model and its own picture.

## Scope
- `make_scrap_parts.py --only <id>` for each of the 26 -- the generator is seeded by the part's id,
  so each comes out its own shape; the committed roster is NOT regenerated (CLAUDE.md: it does not
  reproduce it). Arms may name a `look` (the Flamer a flamer, the Coilgun a gatling, the Harpoon a
  grapple claw) without touching `weapon_class`, which drives the attack animation.
- Pictures: `make_ink_thumbs.gd --only` the 26.
- Checks: verify_assembly (sockets, standing), the arm seating probe, a roster sheet from the game.

## Acceptance criteria
- [x] No part has a `"model"` alias; every part's .glb and picture exists (verify_combat checks).
- [x] verify_assembly passes over the new models.
- [x] A sheet of the 26 rendered by the game.
- [x] All suites.

## Result

- 26 new `.glb` in `art/parts/` and pictures in `art/thumbs/` (Blender) and `art/thumbs_ink/` (the
  game), built with `make_scrap_parts.py --only <id>` (8 Blender processes at once). The committed
  roster is untouched (no tracked art file changed).
- Arms: `look` -- the Flamer a flamer, the Harpoon a grapple claw, the Shield Caster a sensor mast,
  the Cleaver a saw blade, the Coilgun a gatling, the Godhammer a sledge, the Sunspear a rail lance
  (`weapon_class` unchanged: it drives the attack animation).
- Modules: the generator's four salvage pods repeated, so `MODULE_LOOKS` builds a shape per job --
  spikes (Spiked Plating), fins (Heat Fins), hooks, a welder arm (Repair Drone), a flywheel (Gyro
  Anchor), an ammo belt (Belt Feeder), a ram, springs (Sprint Pistons), a toothed maw (Scrap Leech),
  tesla coils (Arc Relay), a dish (Spotter Uplink), a furnace cage (Phoenix Cell), layered plates
  (Plating), a shield dome (Aegis Rig), thrusters (Jump Jets). The sheet: `042-new-models.png`.
- Checks: verify_assembly 168 (the 26 now included), verify_combat checks every part's model, arm
  seating 0 of 204 pairs over 12%. All suites pass. An intermittent "Nil to PackedVector3Array" in
  the UI test traced to a hull built over a surface with no vertices yet: such a mesh is now left as
  it is.

## Decisions, lessons, open questions
- Generate only what is missing (`--only`): the roster generator does not reproduce the committed
  roster, so a full run would change every machine.
- A module's look comes from what it DOES; the pods stay for the roster's originals.
- Open: do the new models read at board distance? Should the legendaries get a stronger look?

## Next
041, comic panels and buttons, once the user picks a direction.
