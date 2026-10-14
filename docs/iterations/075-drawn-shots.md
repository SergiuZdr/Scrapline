# Iteration 075 — Shots drawn in ink

**Status:** done (the user plays and judges)
**Started:** 2026-10-14 · **Finished:** 2026-10-14
**Answers:** the user, after 074: "all the trails you made look ok, but I need something more detailed
that matches the game's style".

## Goal
Every ranged arm's trail is drawn the way the game draws its blasts and sparks -- ink edges, flat bands,
half-tone shade, a paper highlight, nothing glowing or fading -- and carries more detail than 074's.

## Scope
- In: `ShotFX` only (the same 13 trails, the same `play` / `warm` contract), `tools/shot_trails.gd`.
- Out (deliberately): the firing animations (074, the user said they are fine), rules, sounds.

## Steps
1. Read the style bible and `BattleVFX`'s drawings (boom, puff, spark, star).
2. Replace the additive glow primitives with drawn pieces: painted textures per colour
   (`Ink.texture`), ribbons turned to the camera for beams, tails, chains and darts, sprites for balls,
   stars, nets, bubbles; pop-hold-shrink timing, beams thinned in stepped bites.
3. More detail per trail: muzzle stars, speed lines, dotted paths, after-images, forks, barbs, links,
   a hex mesh, a net, a mine's blinking eye; the game's impact star and drawn sparks where it lands.
4. `warm` fires every arm's trail in its own colour, so every texture is painted behind the card.

## Acceptance criteria
- [x] A sheet of all 13 trails in flight and on landing, in the ink style, shown to the user.
- [x] `tools/check.sh` green; `verify_animation` still checks every ranged arm's style and trail.
- [x] The warm-up cost measured.

## Result
- `ShotFX` rewritten: 22 drawn textures (beam, muzzle star, ball, comet tail, dart, slug, ring, hex
  ring, hex bubble, diamond, dash, reticle, flame tongue, shell, harpoon head, chain, cord, net, mine lit
  and unlit, sunburst, speed lines), each with an ink edge, the arm's colour in flat bands, half-tone in
  the shade and a paper or white heart. Ribbons: an unshaded alpha-scissor quad laid along the shot and
  turned to the camera about its line, the texture tiled along beams and chains. Impacts use
  `BattleVFX.star` and `sparks`, smoke `BattleVFX.smoke` -- the same drawings as the rest of the fight.
- Sheet: `shots/075_trails_v2.png` (each arm in flight, then landing), from `tools/shot_trails.gd`
  (now also writes `_land`).
- `ShotFX.warm` (every arm's trail in its colour): 161 ms, behind the opening card.
- `tools/check.sh` all green: verify_combat 370/0, verify_combat_input 27/0, verify_run 187/0,
  verify_run_ui 51/0, verify_save 15/0, verify_onboarding 39/0, verify_meta 77/0, verify_assembly 168/0,
  verify_animation 38/0. Not run: `run_bot.gd` (presentation only).

## Decisions, lessons, open questions
- **Effects are drawings, not light**: a shot is ink-edged flat colour that pops and shrinks, like every
  other effect in the fight; additive glow read as another game.
- Lesson: a ribbon (a quad laid along a line and turned to the camera about it) draws beams, tails,
  chains and darts with one piece of code and keeps the ink edge at any angle.

## Next
- The user plays and judges; the Chain Flail's arc attack.
