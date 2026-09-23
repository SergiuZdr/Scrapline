# Plan — Meta-progression (unlocks only)

**Status:** draft (Iteration 000). Implementation in 006.

## The rule

Nothing that carries between runs makes a construct's numbers bigger. Meta-progression
**widens options**: more parts in the pool, more starting crews, harder tiers. It never
adds power.

## What unlocks

| Unlock | How | Effect |
|---|---|---|
| Parts | Blueprints found during runs (a rare drop from elites and bosses); some tied to achievements ("win a fight using only melee") | The part joins the loot pool for future runs |
| Chassis | Beat an act boss with a given role for the first time | New chassis in the pool |
| Starting crews | Reach act 2 or 3, beat the game with certain crews | A new pre-built 3-construct crew with a different strategy |
| Pressure tiers | Beat the game on the current tier | Tier N+1: stacking modifiers (faster front, tougher elites, fewer repairs…), about 10 tiers |
| Codex entries | See a part, enemy or site for the first time | Encyclopedia with lore and exact numbers |

## Pacing

- A new player should unlock **something after nearly every run, including losses**,
  for the first ~10 runs.
- The full unlock set needs roughly **30–40 runs**. After that, pressure tiers carry
  long-term play.

## The between-run screen: the Workshop

- Choose a starting crew and a pressure tier.
- Browse the Codex and see blueprints.
- Show run history: seed, crew, how far you got, what killed you.

## Data and save

- `data/unlocks.json` describes unlock conditions.
- The player profile stores unlocked ids, pressure tier per crew, run history, codex
  seen-flags and settings. It stays small, offline and local.
- The old `ProfileStore`/command pattern is adapted for this (see
  [salvage-audit.md](salvage-audit.md)). All writes go through commands, so saving
  cannot silently drop a change.
