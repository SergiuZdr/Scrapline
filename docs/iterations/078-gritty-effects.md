# Iteration 078 — Every effect gritty; the flamer along its throw; a slimmer Sunspear; shots from the muzzle

**Status:** done (the user plays and judges)
**Started:** 2026-10-14 · **Finished:** 2026-10-14
**Answers:** the user, after 077: "every effect not yet changed must be redone; T7 the fire must not have
vertical flames but go along the throw; T11 looks too thick and cartoony; check that the trails start
from the point where each weapon shoots".

## Goal
All 18 fight effects drawn in the 076 style; the flamer a jet along its line of fire; the Sunspear a narrow
hard spear; every shot leaving from the middle of its gun's mouth.

## Scope
- In: `Grit` (stars, blast, rays, spark, shards, shock ring, dust cloud, scorch), `BattleVFX` (every
  effect wired to them, the glowing helpers removed), `ShotFX._flame` / `_sun`, `ConstructRig._bind_muzzle`,
  `tools/bake_fx.gd` (bakes every drawing the fight uses), `tools/shot_trails.gd --muzzle`.
- Out: rules, sounds, firing animations.

## Result
- **Muzzles.** `tools/shot_trails.gd --muzzle` marks `ConstructRig.muzzle` on each gun at the moment it
  fires. 12 of 13 sat on the mouth; the Rail Lance's sat on the barrel's lower lip (the furthest-forward
  vertex). Now the mouth's middle: the mean of the vertices within 2 cm of the front, on the same bone.
  All 13 on the mouth: `shots/078_puncte_de_tragere.png`.
- **Effects** (before = `main` before 078, from a scratch copy; after = this): muzzle flash, impact and
  impact star (jagged, hatched, eroding), sparks (hard slivers), blast (torn fireball with a white heart
  and hatched soot, ragged action lines, eroding), shock ring (drawn flat on the floor with a jagged
  heart, was a glowing torus), shards (torn plates: mustard, rust, steel, riveted), dust (gritty brown
  clouds), ground lines (ragged, eroding), scorch (a drawn burn with cracks and embers, was soft soot);
  destruction, crush and the four breaks follow. `shots/078_efecte_inainte_dupa.png` (E1-E18).
- **T7** flame tongues laid along the throw, swelling and licking ahead, burning down into grit; **T11** a
  narrow serrated gold spear with a white core and crackles along it, no sunburst disc.
  `shots/078_urme_T7_T11.png`.
- Baked: 82 drawings (1.4 MB) in `art/fx/`, including every colour the fight bursts and flashes in.
- `tools/check.sh` all green: verify_combat 370/0, verify_combat_input 27/0, verify_run 187/0,
  verify_run_ui 51/0, verify_save 15/0, verify_onboarding 39/0, verify_meta 77/0, verify_assembly 168/0,
  verify_animation 38/0. Not run: `run_bot.gd` (presentation only).

## Decisions, lessons, open questions
- A shot leaves from the middle of the gun's mouth, not its furthest vertex.
- Lesson: a camera on the wrong side photographs the other arm -- frame a check on the thing checked.

## Next
- The user picks again from the sheets; the Chain Flail's arc attack.
