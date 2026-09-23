# Plan — Tech architecture

**Status:** draft (Iteration 000).

Engine: **Godot 4.6, GDScript, Compatibility renderer** (unchanged, because it runs on
low-end Android).

## Layout (target after Iteration 004)

| Path | What lives there |
|---|---|
| `sim/` | Pure logic: grid combat rules. Same hard rules as before: `RefCounted`, `SimRNG`, integer math, fixed iteration order, no engine APIs |
| `sim/combat/` | board, unit, actions, intents, resolver, events |
| `sim/run/` | run state, region graph, front, site resolution, rewards. Also pure and seeded |
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
- `user://run.json`: current run as `{seed, content_version, action_log}`, rebuilt by
  replaying. Written after every committed action.

## Tests (lean, only where they pay off)

| Test | Guards |
|---|---|
| `verify_combat.gd` | scripted fights; determinism hash; rules edge cases |
| `verify_run.gd` | region generation invariants (reachability, site counts) |
| `verify_save.gd` | save → quit → load mid-fight equals continuing |
| `run_bot.gd` | a bot plays N full runs; reports win rate, deaths by cause, part pick rates. **The equivalent of the old `verify_loop.gd`** |
| `verify_assembly.gd` | kept: art export contract |
| `verify_animation.gd` | kept: rig behaviour |

## Build targets

- Desktop: macOS and Windows (Steam later).
- Android: Compatibility renderer, test on a low-end device before 009.
