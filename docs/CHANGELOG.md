# Changelog

Newest first. One entry per iteration; link to the iteration file for detail.

## [002] Grid fight prototype — 2026-09-24 ([detail](iterations/002-grid-fight.md))

### Added
- A playable turn-based fight on an 8×8 grid. Title → FIGHT → fight → YARD CLEARED /
  CREW LOST → FIGHT AGAIN.
- Pure deterministic combat sim in `sim/combat/`: move, attack, telegraphed enemy intents
  that fire down a line in order, wrecks, win/lose, replay-based undo, event stream.
- `IntentAI` for enemies, reused as `CombatBot` for tests and the `--bot` demo.
- 3D board scene with the existing construct models, rig, VFX and lighting; tap/click
  controls, a two-tap attack, UNDO, END TURN, 90° camera turns, zoom, keyboard shortcuts.
- `data/combat/prototype.json`, `data/fights/proto_yard.json`, and `blocks` on terrain tiles.
- Tests: `verify_combat.gd` (41), `verify_combat_input.gd` (13).

### Changed
- `ContentDB` loads combat rules and fights. `ConstructView.build_parts` builds a model
  from part ids.

## [001] Archive and strip — 2026-09-24 ([detail](iterations/001-archive-and-strip.md))

### Added
- Git tag `archive/f2p-battler` (the full old game at `0b72f74`).
- `scenes/main.tscn` and a placeholder title screen as the new entry point.
- `DevShot` autoload: `--shot` screenshots work on any scene.
- `legacy/`: old code being adapted, ignored by Godot.

### Changed
- `ContentDB` trimmed to the content the roguelike uses.
- `project.godot`: new description and main scene. Autoloads are now `Audio` and `DevShot`.
- `CLAUDE.md` rewritten for the roguelike (not tracked by git).

### Removed
- All F2P, online and live-service systems, the real-time sim, the hub, and their tests
  (165 files, about 24k lines).

## [000] Rethink — 2026-09-23

**Direction change.** Scrapline is now a premium, single-player, turn-based tactics
roguelike for PC and mobile. The F2P live-service squad battler is retired.

### Added
- `docs/` structure: VISION, ROADMAP, CHANGELOG, MEMORY, a plan for each aspect, and
  one file per iteration.
- Detailed plans for combat, constructs and parts, run structure, meta-progression,
  enemies and AI, platform and UI, art and audio, and tech architecture.
- A salvage audit that marks every existing system as keep, adapt or cut.

### Changed
- `CLAUDE.md` starts with a pivot notice pointing at `docs/`.

### Removed
- Nothing yet. Code removal is Iteration 001.

## [pre-000] Previous direction (archived)

- `7276809` First commit: the deterministic sim and everything built on it.
- `0b72f74` Game-style hub, Rust & Sodium art pass, scrap-generated roster.
