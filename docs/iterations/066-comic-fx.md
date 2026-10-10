# Iteration 066 — Comic explosions, smoke, sparks and debris

**Status:** done -- waiting for the user's look
**Started:** 2026-10-10 · **Finished:** 2026-10-10
**Answers:** the user on 065: "I don't want realistic effects, but effects that match the style of the
game (comics, Borderlands)".

## Goal
Every explosion, puff of smoke, spark and bit of debris is DRAWN: flat colour, ink edges, popping in
and shrinking out, never glowing or fading like a photo.

## Scope
- In: `BattleVFX.fireball`, `smoke`, `sparks`, `destruction` (so barrels, props, kills and deaths all
  change at once); new `shards`. Signatures unchanged.
- Out: muzzle flash, burst ring and scorch (unchanged).

## Acceptance criteria
- [x] Blast: action lines, a lumpy cartoon cloud (pale heart, yellow, orange with half-tone dots,
  thick ink edge) that pops big, holds a beat and shrinks away into smoke balls.
- [x] Smoke: grey cartoon balls with a shadow side, a highlight and an ink edge; they rise and shrink out.
- [x] Sparks: ink-edged slivers tinted by the old colour; debris: ink-edged rust shards in arcs.
- [x] verify_animation, verify_combat_input, verify_run_ui, verify_onboarding pass.

## Result
- Textures are painted once in code (`Ink.texture`: `comic_boom`, `comic_rays`, `comic_puff`,
  `comic_shard`, `comic_spark`) and drawn as unshaded billboards over the world; particle sparks use
  one held alpha-scissor material per tint. The opening card already fires `fireball`, `destruction`
  and `impact`, so all of these compile behind it.
- Landing dust made smaller (it hid the wreck).
- Checks: verify_animation 34, verify_combat_input 27, verify_run_ui 51, verify_onboarding 39.
  Reel `shots/066_deaths.mp4`, sheet `shots/066_sheet.png`.
- **Not checked in a recorded fight**: `record_round.gd` froze after a few seconds (the hidden-window
  movie-writer stall); the fight scene itself runs in verify_combat_input.

## Decisions, lessons, open questions
- Effects follow the look: flat bands and ink edges; things pop in and SHRINK out, they never fade.

## Next
The user plays a fight.
