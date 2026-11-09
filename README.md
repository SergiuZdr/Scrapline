# Scrapline

A turn-based tactics roguelike about three scrap-built war machines crossing a dead
industrial wasteland. Built in Godot 4.6 with GDScript. Work in progress, single developer.

## The game today

You lead a crew of three machines across a scrapyard region, picking a route between
sites while the Reclaimer, a line of harvester machines, closes in behind you. Fights are
short puzzles on a hex board: every enemy shows its attack before you move, every fight
has an objective (rout, defend, salvage, hold, hack, survive), and barrels, pits, mines and
cover are weapons too. A machine is literally its parts: chassis, two arms, core and
module set its attacks, movement and weak points. Arms get torn off in battle, wrecks
burst into scrap, and salvage is how the crew grows. A full run has three acts, each with
its own boards, warlords and a boss, plus between-run unlocks, a difficulty ladder, a
daily yard and a weekly contract. A full run is playable today on desktop, start to
ending, drawn in a hand-inked comic style ("Ink & Rust").

Planned, not done yet: Android and desktop export builds, performance work for low-end
phones, and a Steam demo. The target is a premium, offline, single-player game for PC
and mobile.

## Technical highlights

**A deterministic simulation, separate from the presentation.** All game rules live in
`sim/` as plain `RefCounted` classes with no scene tree, no signals and no engine calls.
Inside `sim/`:

- integer math only (fractions scaled by 100, no floats, no `sqrt`);
- a custom seeded xorshift128 RNG (`sim/rng.gd`) instead of the engine RNG, so a seed
  gives the same sequence on every platform and engine version;
- a fixed iteration order (never Dictionary order; sorts end in an explicit tiebreaker);
- every outcome reported as a typed event stream that the 3D view only plays back.

The determinism was first designed so a server could re-run a client's battle and reject
a tampered result (anti-cheat for an earlier online version of the project). The game
is now offline, and the same property pays for other features:

- **Undo** is a replay of the turn's action list, with no inverse operations.
- **Save anywhere**, even mid-fight: the save file is the seed plus the list of actions,
  replayed on load, so the save cannot disagree with the game.
- **Exact bug reproduction** from a seed and an action list.
- **A headless bot** plays hundreds of full runs on every CPU core to measure balance,
  with 95% confidence intervals and A/B comparison on the same seeds.
- **A fingerprint check** hashes how the bot plays every fight; a change meant only for
  speed must leave it unchanged.

**Data-driven content.** Parts, enemies, fights, maps, events and every balance number
are JSON in `data/`; no tuning number lives in code.

**3D models from Blender Python.** `tools/blender/` holds Blender scripts: a procedural
generator (`scrapgen/`, `make_scrap_parts.py`) that builds interchangeable robot parts and
exports them as GLB, and a pipeline that cleans, sockets, skins and rigs every part model
the game loads. A socket contract (one unit is one metre, fixed socket names, attachments
modelled at the origin) lets any arm bolt onto any chassis with no per-combination fixes,
and `verify_assembly.gd` checks it. Machines are animated pose to pose with IK-placed feet.

**Custom rendering style.** Toon shading, ink outlines and hatching are shaders kept in
one place (`scripts/presentation/ink.gd`); UI contrast is measured by a tool and may only
increase. All sound effects are synthesised in code.

## Project structure

| Path | Contents |
|---|---|
| `sim/combat/` | Hex combat rules: geometry, setup, the rules engine, enemy intent AI, the combat bot |
| `sim/run/` | The run: region generation, sites, salvage, unlocks, the run bot |
| `scripts/` | Presentation and UI: the 3D board, playback, rigs, effects, screens, save files |
| `scenes/` | Title, run map, fight, and the tutorial fight |
| `data/` | All content and tuning as JSON (parts, fights, enemies, run, glossary) |
| `tools/` | Headless test suites, bots, balance and measurement tools |
| `tools/blender/` | Blender Python model generators, rigging and checks |
| `art/` | Part models (`.glb`), effects, thumbnails, fonts (SIL OFL), third-party textures |
| `docs/` | Vision, roadmap, changelog, design plans, one file per iteration, play-test notes |

## Running it

1. Install [Godot 4.6](https://godotengine.org/download/archive/) (the standard build, not
   .NET; developed on 4.6.2). Below, `godot` stands for the path to that binary.
2. Clone the repo. Large model files are stored in normal git, so the clone is a few
   hundred MB.
3. Open `project.godot` in the editor and press Play, or from a terminal:

```bash
godot --path . --import     # first time only: import assets
godot --path .              # play
```

## Tests

Every suite runs headless. One suite:

```bash
godot --headless --path . --script res://tools/verify_combat.gd
```

All suites in parallel, one line each (macOS/Linux; set `GODOT` to your Godot binary):

```bash
GODOT=/path/to/godot tools/check.sh
GODOT=/path/to/godot tools/check.sh --bot 30 --fingerprint   # then 30 full bot runs and the sim fingerprint
```

Suites: `verify_combat` (rules, determinism, undo), `verify_combat_input` (the fight
driven by synthetic clicks), `verify_run`, `verify_run_ui`, `verify_save`,
`verify_onboarding`, `verify_meta`, `verify_assembly`, `verify_animation`, `stats`.

## Documentation

The design and its history are in [docs/](docs/README.md): the vision, the roadmap with
every iteration, the changelog, one design plan per system, and notes from each play-test.

## Licence

No open-source licence is granted; code and original art are all rights reserved.
Third-party assets keep their own licences, noted next to them: `art/thirdparty/`
(Poly Haven, Kenney) and `art/fonts/` (SIL OFL).
