# Changelog

Newest first. One entry per iteration; link to the iteration file for detail.

## [004] The run loop — 2026-09-24 ([detail](iterations/004-run-loop.md))

### Added
- A full Act 1 run: region map with fog and the advancing Reclaimer; skirmish, elite,
  scrapyard, workshop and boss sites; salvage picks, the hold and refits; wrecks and
  rebuilds; the Crawler's HP carrying between fights; the run ends at the boss or with
  the Crawler.
- `sim/run/` (RunSetup, RunState, RunSim, RunBot) and `data/run/run.json`.
- Save and resume via the `Run` autoload and `RunStore`, per action, mid-fight included.
- Title: CONTINUE / NEW RUN / PRACTICE FIGHT / QUIT.
- Tests and tools: `verify_run.gd` (42), `verify_run_ui.gd` (12), `run_bot.gd`, `shot_run.gd`.

### Changed
- `CombatSetup` accepts the Crawler's current HP and empty sockets.
- The combat scene runs in run mode when a run fight is pending: it saves per action and
  reports its action log back.

## [003] Parts drive abilities, and intents create pressure — 2026-09-24 ([detail](iterations/003-parts-and-pressure.md))

### Added
- **The Crawler**: an immobile salvage rig on every board. Lose it and you lose the fight.
- Per-part `grid` stats on all 40 parts. A construct is exactly its parts plus a role trait.
- Weapon shapes (melee, line, lob) with pierce, splash, shove, mark, chain and tear.
- The damage-type wheel, cover, armour and marks; heat, overheat, seize and VENT.
- Terrain effects (rubble, ridge, slag), shove and bump, and arms torn off by heavy hits.
- Two new fights (`slag_pit`, `container_row`) and `data/combat/rules.json`.
- HUD weapon bar, heat on cards, the Crawler plate, multi-hit previews; explicit move and
  attack modes.
- `tools/balance_fights.gd` (bulk bot fights) and `tools/shot_combat.gd` (aimed screenshots).

### Changed
- `verify_combat.gd` 41 → 77 checks; `verify_combat_input.gd` 13 → 18 with a watchdog.
- The tap priority from 002 is replaced by modes (select → move; weapon button → aim).

### Removed
- `data/combat/prototype.json` (role and weapon-group stats), superseded by per-part stats.

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
