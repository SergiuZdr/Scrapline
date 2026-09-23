# Iteration 001 — Archive and strip

**Status:** in progress
**Started:** 2026-09-24 · **Finished:** —

## Goal
The old F2P squad battler is safely archived, every CUT system is gone, and the project
boots into a clean placeholder title screen with no script errors. The kept art and
animation tests still pass.

## Scope
- In: git tag, deleting CUT code/data/tests/server, moving ADAPT code that no longer
  compiles into `legacy/`, trimming kept scripts off removed dependencies, a new main scene,
  and a rewritten `CLAUDE.md`.
- Out (deliberately): any new gameplay. The grid sim is 002.

## Steps
1. Tag the current `main` as `archive/f2p-battler`. Work on branch `iter-001-strip`.
2. Commit the docs from 000/001.
3. Delete every CUT item in [plans/salvage-audit.md](../plans/salvage-audit.md).
4. Move ADAPT scripts that depend on cut code into `legacy/` (with a `.gdignore`, so Godot
   never parses them): battle_scene, battle_camera, loadout_screen, profile/commands,
   session, doctrine, unit_builder, damage/heat resolvers, colossus, hub_yard,
   roster_photo, balance_sim.
5. Trim the kept scripts: `ContentDB` drops the economy, crates, store, pass and campaign
   sections; `gait_preview` stops using the `Session` autoload.
6. Remove the `Session` and `Analytics` autoloads. The main scene becomes
   `scenes/main.tscn`, a UIKit title placeholder.
7. Run `--import`, then check that the project parses clean and run the kept tests.
8. Rewrite `CLAUDE.md` for the new game, keeping the art, export and animation doctrine.

## Acceptance criteria
- [ ] `git tag` lists `archive/f2p-battler`, pointing at `0b72f74`.
- [ ] `$GODOT --headless --path . --import` finishes with no `SCRIPT ERROR` / `Parse Error`.
- [ ] `verify_assembly.gd`, `verify_animation.gd` and `verify_save.gd` pass.
- [ ] The game launches to the placeholder title with no errors, confirmed by a screenshot
      in `shots/`.
- [ ] `grep` finds no references to removed class names outside `legacy/`.

## Result
(filled in on completion)

## Next
002 Grid fight prototype.
