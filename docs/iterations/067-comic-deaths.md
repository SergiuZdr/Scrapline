# Iteration 067 — Comic deaths and a comic filter on the machines

**Status:** done -- waiting for the user's play-test
**Started:** 2026-10-12 · **Finished:** 2026-10-12
**Answers:** the user on 066: "new effects for the death animation, as close as possible to the style
of a hit or of something exploding on the board; and the robots should have some kind of filter in
game so they look as close as possible to a comic". No video afterwards: the user will play-test.

## Goal
A death speaks the same drawn language as a hit and a blast (impact stars, action lines, cartoon
blasts, shards, drawn dust), and every machine is printed like a comic panel: flat colour bands,
inked darks, hatched shade and a white rim stroke.

## Scope
- In: `BattleVFX` (one `on_break` vocabulary shared by the fight and `anim_reel.gd`: stars, ground
  action lines, drawn dust, the final crush), the combat scene's death beats, `ink_toon.gdshader`
  (`comic`: posterised texture, inked darks) and `Ink._dress_node` (machines get comic, hatch, rim).
- Out (deliberately): timings of the death choreography, sounds, scenery and props' materials.

## Steps
1. BattleVFX: `star`, `dust`, `ground_lines`, `crush`, `on_break(at, what)`.
2. Combat scene: the killing blow, every break and the final crush use them; warm-up fires them.
3. Shader `comic` mode; machines dressed with it.
4. Checks, a still screenshot (no video), docs.

## Acceptance criteria
- [x] No glowing or fading-photo effect is left in a death (the additive ring at the crush is gone).
- [x] Arm break, module/core explosion, landing and crush each show a drawn star or blast and shards.
- [x] Machines in a fight read posterised with inked darks (a still shot).
- [x] verify_animation, verify_combat_input, verify_run_ui, verify_onboarding pass.

## Result
- `BattleVFX.star` (the hit's star, any size), `on_break(at, what)` (one vocabulary for the fight and
  `anim_reel.gd`), `dust` (flat paper-brown balls along the floor), `ground_lines` (action lines lying
  on the floor), `crush` (the last beat; replaces the additive torus `burst`). The killing blow adds a
  big star and focus lines; BOOM adds focus lines; the crush says CRUNCH!. All of them fire in the
  opening warm-up so their shaders compile behind the card.
- `ink_toon.gdshader` `comic` (posterise 4 steps, +0.55 of a step, saturation x1.15, ink below 0.15
  luminance, texture read at mip bias 1.2) for textured parts; `Ink.comic_machine` sets comic, hatch 1
  and rim 0.45 on every machine surface (kit included). Scenery, props and the drum are untouched.
- Checks: verify_animation 34, verify_combat_input 27, verify_run_ui 51, verify_onboarding 39.
- Stills only (the user asked for no video): `shots/067_machine.png` (before / after / Strider),
  `shots/067_death_sheet.png` (reel frames: star + blast at the module, shards, drawn dust at landing),
  `shots/067_after.png` (a fight).

## Decisions, lessons, open questions
- Posterising must round to the middle of a step, not up: rounding up with a saturation push turned
  dark rust into bright orange blotches (first pass).
- Open: 3 steps instead of 4, or ink lines found in the texture (edges), if the user wants more comic.

## Next
The user play-tests (and records their own tutorial).
