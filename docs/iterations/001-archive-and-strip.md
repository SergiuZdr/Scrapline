# Iteration 001 — Archive and strip

**Status:** done
**Started:** 2026-09-24 · **Finished:** 2026-09-24

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
- [x] `git tag` lists `archive/f2p-battler`, pointing at `0b72f74`.
- [x] `$GODOT --headless --path . --import` finishes with no `SCRIPT ERROR` / `Parse Error`.
- [x] `verify_assembly.gd`, `verify_animation.gd` and `verify_save.gd` pass.
- [x] The game launches to the placeholder title with no errors, confirmed by a screenshot
      in `shots/`.
- [x] `grep` finds no references to removed class names outside `legacy/`.

## Result

- **Tag** `archive/f2p-battler` points at `0b72f74`. Work is on branch `iter-001-strip`.
- **Removed:** 165 tracked files, about 24,000 lines: PvP, net, the Nakama server,
  store, season pass, crates, foundry, economy, campaign, gauntlet, co-op and guild
  services, content patches, analytics, the continuous real-time sim, the hub, and 20
  tests for cut systems. The ignored `server/` build output and `node_modules` were
  deleted too.
- **Moved to `legacy/`** (18 scripts plus `battle.tscn`, `roster_photo.tscn`): battle
  scene and camera, loadout screen, hub yard, profile store and commands, session,
  doctrine, unit builder, damage and heat resolvers, colossus, roster photo, balance sim.
- **Trimmed:** `ContentDB` no longer loads economy, crates, buildings, campaign, store or
  battle pass, and its comments describe save validation instead of server verification.
  `gait_preview` uses `ContentDB.load_all()` instead of the `Session` autoload.
- **New:** `scenes/main.tscn` + `scripts/ui/title_screen.gd` (placeholder title) and
  a `DevShot` autoload, so `-- --shot <png> --after <frames>` works on **any** scene.
  It used to be copied into each scene.
- **Autoloads:** `Session` and `Analytics` removed; `Audio` and `DevShot` remain.
- **`CLAUDE.md` rewritten:** 1,257 → 811 lines. The new header covers the docs workflow,
  history, sim rules, layout, commands and tests. The art, roster, export, hero-render,
  arena, animation and screenshot doctrine is kept verbatim, and the F2P, online, PvP,
  monetization, hub and fairness sections are dropped.

### Checks
| Check | Result |
|---|---|
| `--import` | no errors |
| `--check-only` on every `.gd` in `scripts/ sim/ tools/` | 0 errors |
| `verify_assembly.gd` | 100 passed, 0 failed |
| `verify_animation.gd` | 34 passed, 0 failed. Prints an `ObjectDB instances leaked at exit` warning; not checked whether it predates this iteration |
| `verify_save.gd` | 14 passed, 0 failed |
| Launch + screenshot | `shots/001-title.png`: title screen renders, no errors |
| Grep for removed classes outside `legacy/` | only a comment in `sim/sim_unit.gd` (colossus guard fields, kept for the boss design) |

## Decisions, lessons, open questions
- ADAPT code that no longer compiles goes to `legacy/` with a `.gdignore`, as reference.
- `CLAUDE.md` is excluded from git (`.git/info/exclude`), so its rewrite is **not**
  versioned. The docs in `docs/` are.
- A user edit left `docs/README.md` with an invalid UTF-8 byte in the title (a broken
  em dash). Fixed. Python's `open()` crashes on such a file, so keep docs as clean UTF-8.

## Next
002 Grid fight prototype: write `iterations/002-grid-fight.md` first. `sim/sim_unit.gd`,
`balance.gd`, `sim_defs.gd` and `events.gd` still hold continuous-sim fields; 002 replaces
them with grid equivalents rather than editing them in place.
