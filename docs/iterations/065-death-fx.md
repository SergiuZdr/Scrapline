# Iteration 065 — Deaths: the core and backpack explode, faster, with effects

**Status:** done -- waiting for the user's look
**Started:** 2026-10-10 · **Finished:** 2026-10-10
**Answers:** the user on 064: "the core/back module still go through the frame of the robot when it
is falling; I want it to explode (or fall faster to a spot with no other parts); the animations need
to be faster and they need effects in game".

## Goal
Nothing falls through a dying machine; deaths play faster; every break, explosion and landing has an
effect in the fight.

## Scope
- In: `ConstructRig` (explode instead of drop, speed), the combat scene's `on_break` effects,
  `anim_reel.gd` drawing the same effects.
- Out: new choreography, new sounds (the existing bank is used).

## Acceptance criteria
- [x] The module and the core never become loose bodies (probe_death: only arms are left loose).
- [x] Deaths play at 1.7x; the fall is quicker (gravity 13 -> 24); the wreck goes sooner (3.6 -> 2.6 s).
- [x] Effects: module KA-BLAM (fireball, sparks, shake), core BOOM on landing (bigger fireball, sparks,
  shake, a short hit-stop), landing THUD (dust, shake), arm KRAK (sparks and a puff of smoke).
- [x] verify_animation, verify_combat, verify_combat_input, verify_run_ui pass.

## Result
- `ConstructRig._explode_part(name)`: the part leaves the machine at once (its points leave the floor
  and reach measurements) and `on_break` gets `explode_module` / `explode_core`; landing sends `land`.
  The backpack used to drop behind a machine that then fell backwards onto it, and the core rolled out
  of a chest lying on top of it.
- `DEATH_SPEED` 1.7 divides every death key; `FALL_GRAVITY` 24.
- probe_death: all nine settle flat, wreck middle 0.00 m from the hex middle, 2-3 cm after landing.
- Checks: verify_animation 34, verify_combat 355, verify_combat_input 27, verify_run_ui 51.
- Video `shots/065_deaths.mp4` (real speed, reel effects without shake or words), sheet `shots/065_sheet.png`.

## Decisions, lessons, open questions
- A part that would have to fall through the body is blown up instead: no physics can be right when
  the body lands where the part lies.

## Next
The user plays a fight and judges speed and effects live.
