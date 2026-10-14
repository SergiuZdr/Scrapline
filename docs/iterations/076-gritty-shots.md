# Iteration 076 — Gritty shots and smoke

**Status:** done (the user plays and judges)
**Started:** 2026-10-14 · **Finished:** 2026-10-14
**Answers:** the user, after 075: "I don't like how the trails and the smoke come out, they look too
cartoony; the game's style is not only Ink & Rust but something similar to Borderlands and comics".

## Goal
Shots and smoke drawn like a Borderlands comic panel: jagged silhouettes, thick wobbling ink lines,
hatched shade, grit in the fills; fire, flashes and smoke erode into grain instead of shrinking.

## Scope
- In: `Grit` (new: the drawing vocabulary), `ShotFX`'s drawings and its flash and fire timing,
  `BattleVFX.smoke` (the whole game's smoke), baking drawings to `art/fx/` (`Ink.texture`,
  `tools/bake_fx.gd`).
- Out (deliberately): the blast (`BattleVFX.fireball`'s round lobes), the impact star, the firing
  animations, rules.

## Steps
1. `Grit`: noise for every edge, diagonal hatching (crossed in the darkest), grain specks, erodible
   alpha, `erode` (an alpha cut raised from 0.5 to 1 eats a drawing from its edges into specks), the
   smoke billow.
2. Redraw every `ShotFX` texture in that vocabulary; muzzle flashes and flame tongues erode.
3. `BattleVFX.smoke`: jagged hatched billows that swell, rise and erode (was round cartoon balls).
4. Painting the gritty drawings took 3.3 s at a fight's opening: bake them to `art/fx/` and load.

## Acceptance criteria
- [x] Sheet of all 13 trails in flight and on landing, and close-ups of fire, smoke and a beam.
- [x] The opening warm-up back under 0.1 s, nothing painted at run time.
- [x] `tools/check.sh` green.

## Result
- `scripts/presentation/grit.gd`; `ShotFX` drawings redrawn (texture names `shot2_*`); smoke from
  `Grit.smoke_texture` (four billows). Sheet `shots/076_trails_sheet.png`; close-ups of the flamer,
  the scattergun's smoke, the Sunspear and the mortar.
- Warm-up: painted 3.3 s; baked (41 drawings, 424 KB, `art/fx/`, lossless, not re-compressed for 3D)
  44 ms, nothing painted. A drawing painted at run time warns ("run tools/bake_fx.gd").
- `tools/check.sh` all green: verify_combat 370/0, verify_combat_input 27/0, verify_run 187/0,
  verify_run_ui 51/0, verify_save 15/0, verify_onboarding 39/0, verify_meta 77/0, verify_assembly 168/0,
  verify_animation 38/0. Not run: `run_bot.gd` (presentation only).

## Decisions, lessons, open questions
- **The look is Borderlands-like comic, not cartoon** (the user): jagged inked shapes, hatching, grit;
  effects erode. Round smoke balls and smooth bubbles are out.
- Lesson: noise-painted drawings cost seconds in GDScript; bake them (`tools/bake_fx.gd`) and rerun it
  after changing a drawing or a weapon colour.
- Open: the blast (`BattleVFX.fireball`) still has round lobes and half-tone dots -- the next to redraw if
  the user wants the explosions in the same style.

## Next
- The user plays and judges; the blast in the gritty style; the Chain Flail's arc attack.
