# Plan — Tech architecture

**Status:** draft (Iteration 000).

Engine: **Godot 4.6, GDScript, Compatibility renderer** (unchanged, because it runs on
low-end Android).

## Layout (target after Iteration 004)

| Path | What lives there |
|---|---|
| `sim/` | Pure logic: grid combat rules. Same hard rules as before: `RefCounted`, `SimRNG`, integer math, fixed iteration order, no engine APIs |
| `sim/combat/` | **Built in 002:** `CombatSetup`, `CombatState`, `CombatSim`, `IntentAI`, `CombatBot`, `GridUnit`, `GridEv` |
| `sim/run/` | **Built in 004:** `RunSetup`, `RunState`, `RunSim` (region, front, sites, fights by replay, rewards, refit), `RunBot` |
| `scripts/run/` | `run_map_screen.gd` (map and site panels), `run_store.gd` (the save) |
| `sim/ai/` | intent selection (adapted doctrine rules) |
| `data/` | all content and tunables as JSON |
| `scripts/presentation/` | reads events, animates. Computes nothing |
| `scripts/ui/` | screens, ui_kit |
| `scripts/profile/` | meta profile (unlocks), commands, save |
| `tools/` | headless tests, run-bot, balance sim, art tools |

## Why determinism still matters (no server any more)

- **Undo** = replay from the start of the turn. One code path, no inverse operations.
- **Save mid-fight** = store the seed plus the action list, not a snapshot of every object.
- **Bug reports** = a seed plus actions reproduces any crash exactly.
- **Balance** = a headless bot plays thousands of runs overnight.
- **Shareable seeds** and an offline daily challenge come for free.

## Event stream

The combat sim returns a typed event list (`MOVED`, `ATTACKED`, `DAMAGED`, `PART_DAMAGED`,
`PART_TORN`, `SHOVED`, `HEAT`, `SEIZED`, `DESTROYED`, `INTENT_SET`…). Presentation plays
them. The old `event_stream.gd`/`events.gd` pattern is kept and the vocabulary changes.

## Save

- `user://profile.json`: meta profile (unlocks, settings, history), written through
  commands.
- `user://run.json` (**built**): `{version, seed, content, actions, fight}`. Rebuilt by
  replaying `actions`; `fight` is the in-progress fight's combat actions. Written atomically
  after every action. A content-hash mismatch refuses to resume, with a message.

## Tests (lean, only where they pay off)

| Test | Guards |
|---|---|
| `verify_combat.gd` | **built**: rules, determinism hash, prefix-stable undo, bot fight to the end |
| `verify_combat_input.gd` | **built**: the fight driven by synthetic clicks and keys |
| `verify_run.gd` | **built** (42): region invariants, every rule, determinism, save round trip |
| `verify_run_ui.gd` | **built** (12): the run through its screens, including quit and resume mid-fight |
| `verify_save.gd` | save → quit → load mid-fight equals continuing |
| `run_bot.gd` | **built**: a bot plays N full runs; reports win rate, loss causes and columns, fights per run. **The equivalent of the old `verify_loop.gd`** |
| `verify_assembly.gd` | kept: art export contract |
| `verify_animation.gd` | kept: rig behaviour |

## Build targets

- Desktop: macOS and Windows (Steam later).
- Android: Compatibility renderer, test on a low-end device before 009.

## What a frame costs (040)

Measure with `tools/measure_draws.gd` (draw calls, objects, triangles; `--classes`, `--census`)
and a stack `sample` of the running game. Rules since 040: labels, sprites and particles cast no
shadows (the `Juice` watcher); a machine casts its shadow from its frame alone
(`Ink.frame_shadow_only`); static board pieces are merged per material (`Ink.merge_static`); 60 fps
cap, 12 in the background. The ink line's hull mesh has no LODs: dense imported models pay full
price twice.
