# Iteration 063 — Cleanup

(Begun as 062 before the parallel 062 landed on `main`; renumbered.)

**Status:** done
**Started:** 2026-10-10 · **Finished:** 2026-10-10

## Goal
Everything the roguelike no longer uses is gone: the legacy battler code, the real-time sim it
left behind, content tables nothing reads, art and tools no screen or pipeline loads, and the
CLAUDE.md sections describing code that no longer exists. The game plays exactly as before.

## Scope
- In (the audit's levels 1-3, the user: "delete level 1 2 and 3"):
  - L1: `legacy/`; `fog_of_war.gdshader`; `EventStream`; functions with no caller.
  - L2: unused Poly Haven sets, `art/thumbs`, `art/terrain`, `art/hero`, `art/preview`,
    `art/parts_gen{,_a,_b,_c}` and their specs, one-off shot tools, TripoSR/gradio fallbacks.
  - L3: `SimUnit`/`SimDefs`/`SimMath`/`SimEv`/`Balance` (the type wheel moves to
    `data/combat/rules.json`); `data/abilities`, `conditions`, `maps`, `linkages.json`,
    `bosses.json`; the stale CLAUDE.md sections.
- Out: `art/parts` (fallback for 26 parts), the model routes awaiting the user's pick,
  `make_parts.py` (imported by other generators), `art/reference`.

## Steps
1. Level 1 deletions.
2. Level 2 deletions; `Models.GEN_PARTS` defaults to `parts_gen_scrap`.
3. Level 3: the type wheel into `rules.json`, tools onto `ConstructView.build_parts`, delete the
   old sim classes, the dead tables and the hash sections.
4. Trim CLAUDE.md.
5. Tests, bot, docs.

## Acceptance criteria
- [ ] `--import` clean (no missing class/resource errors).
- [ ] verify_combat, verify_combat_input, verify_run, verify_run_ui, verify_save,
      verify_onboarding, verify_meta, verify_animation, verify_assembly pass.
- [ ] run_bot plays runs to the end.
- [ ] The game launches to the title and a fight renders (screenshot).

## Result
- **Level 1**: `legacy/` (16 files, 4,621 lines), `fog_of_war.gdshader`, `EventStream`, and 15 functions
  no one called (`combat_scene._material`, `BattleVFX.clear_transients`, `ConstructRig.has_skeleton`,
  `Models.use_gen`, `Surfaces.pbr` and `_texture`, `garage_panel._build_tabs` and `_tab`,
  `SaveFile.status_name`, `CombatSim._already_hit` / `_prop_struck`, `CombatState.intent_of`,
  `RunSim.level_bonus`, `SimRNG.state_string`).
- **Level 2**: Poly Haven down to the three sets `PartMaterials` reads (HDRIs, two models and six
  textures gone); `art/thumbs` (`PartText.thumb` no longer falls back to it: `thumbs_ink` covers every
  part); `art/terrain` and `make_terrain.py`; `art/hero` and `art/preview` (now gitignored output);
  `art/parts_gen`, `_a`, `_b`, `_c` and their six specs (`Models.GEN_PARTS` and `next_part.sh` now
  write/read `art/parts_gen_scrap`; `GEN_THUMBS` pointed at a folder that never existed); the
  Big Shoulders font (nothing loaded it); `shot_unlocks`, `shot_glossary`, `shot_strip`,
  `shot_ui_options`, `triposr_run.py`. **Kept** `gradio_queue.py`: the audit called it dead, but three
  generator scripts call it by path.
- **Level 3**: `SimUnit`, `SimDefs`, `SimMath`, `SimEv`, `Balance` deleted; `ConstructView.build(SimUnit)`
  gone, `gait_preview` and `verify_animation` use `build_parts`. The type wheel moved to
  `data/combat/rules.json` `effectiveness` (`ContentDB.effectiveness`; `TypeChart` reads it there).
  `data/balance.json`, `abilities/`, `conditions/`, `maps/`, `linkages.json`, `bosses.json` deleted and
  dropped from the content hash. **The hash changed: a run saved before 063 refuses to resume.**
  CLAUDE.md trimmed (1206 -> ~1070 lines): the hub/loadout/Session lessons, Rust & Sodium's photographed
  tiles and HDRI, `battle_scene` references, `make_terrain`, `art/thumbs`.
- About 130 MB of tracked files gone; ~15,000 lines deleted.
- Checks: `--import` clean; verify_combat 355, verify_combat_input 27, verify_run 187, verify_run_ui 51,
  verify_save 15, verify_onboarding 39, verify_meta 77, verify_animation 34, verify_assembly 168 -- all
  passed, 0 failed. Title and an aimed fight shot (`shots/063/`) render as before, part pictures and all.
- run_bot: 12 runs (seeds 1000-1011, one process each): 8 won, 0 illegal actions, no script errors -- every run played to its end.

## Decisions, lessons, open questions
- The wheel is a combat rule, so it lives with the combat rules (and stays hashed through them).
- Search every name across the game AND the tools before calling something dead; a file the game never
  loads can be a tool's input (`gradio_queue.py`).
- A 30-run bot batch in one process takes hours: split it with `--from` (CLAUDE.md already says so).

## Next
The user's 062 look, then play; nothing in the game should look or play differently.
