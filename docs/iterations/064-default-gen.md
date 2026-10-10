# Iteration 064 — Generated machines by default; deaths that stay put and never fall sideways

**Status:** done -- waiting for the user's look
**Started:** 2026-10-10 · **Finished:** 2026-10-10
**Answers:** the user on 062: "the death animations of the new robot models are drifting when
falling; I don't want to see the robots falling on a side; make the new models the default so I can
see them in game live".

## Goal
The generated scrap machines are what the game draws with no flags; a dying machine falls forward
or backward and its wreck stays on its hex.

## Scope
- In: `Models` default, the fall direction of all three deaths, the wreck's slide.
- Out: new death choreography, new models.

## Steps
1. Measure the drift (`probe_death.gd` now reports how far the wreck's middle moves going over and
   after landing).
2. Fix the slide; fix the fall directions; switch the default.
3. Tests, a reel of the nine deaths.

## Acceptance criteria
- [x] No flags draws `art/parts_gen_scrap` (`--models new` / `--models old` still give the others).
- [x] Every death falls along the machine's own front-back axis, whatever side the hit came from.
- [x] A lying wreck moves less than 2 cm after landing and ends on its hex's middle.
- [x] verify_animation, verify_combat, verify_combat_input, verify_assembly, verify_run_ui,
  verify_onboarding pass.

## Result
- **The drift was a bug**: `_keep_above_floor` added `-0.15 x offset` to `_slide` every frame, but the
  body is placed afresh each frame, so the offset it measured never shrank and the sum ran away:
  a lying wreck slid **6-9 m** across the board (measured). `_slide` is now the offset itself,
  weighted by how far over it is. After: 0.9-1.6 cm of movement after landing (the bounce), wreck
  middle 0.00 m from the hex middle, for all nine cases.
- **Never on its side**: two arms -> backwards, one arm -> forward on its face, no arms -> both knees
  give, it sits back and goes over backwards (was: a knee gives and it topples sideways; the two-arm
  death fell away from the hit, sideways when hit from the side).
- **Default models**: `Models._mode` is 2 (generated in front of the new set) unless `--models new`
  or `--models old`.
- `verify_animation.gd`: the direction test now asserts backwards with no sideways component from
  front, back and left hits; the chassis test counts skeleton legs (the generated frames).
- Checks: verify_animation 34/34, verify_combat 355, verify_combat_input 27, verify_assembly 168,
  verify_run_ui 51, verify_onboarding 39. Reel `shots/064_deaths.mp4` (0.5x), sheet
  `shots/064_deaths_sheet.png`.

## Decisions, lessons, open questions
- A correction applied to a transform that is rebuilt every frame must be an offset, never an
  accumulator: the measurement never sees the previous correction.

## Next
The user plays with the generated machines live.
