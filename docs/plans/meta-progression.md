# Plan — Meta-progression (unlocks only)

**Status:** built in 022 (parts, crews, two tiers; `data/meta.json`, `sim/run/meta.gd`); 043 made the tiers a LADDER (below). The codex and blueprints-as-drops are not built.

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

## Missions (034)

Unlocks may ask for FEATS as well as runs, fights, acts and wins: `RunSim.tally_feats` counts, from
each fight's events, `kills`, `multi_kill`, `pit_kills`, `bumps`, `tears`, `flawless`,
`close_calls`, `<objective>_wins`, `elites`, `arenas`, `warlords`, `gates`; `Meta.stats_after` adds
them up across runs. Nine missions (`mission: true` in `data/meta.json`) open 033's uncommon-and-up
modules; UNLOCKS shows MILESTONES and MISSIONS in their own columns.


## The ladder (043, play-test 13)
The user hated choosing a difficulty after NEW RUN, and wanted the tiers to be something the game
makes you climb. So:
- **NEW RUN starts at once** with the remembered crew and tier. The title shows them ("NEXT RUN: THE
  SALVAGERS · FOREMAN") with **CHANGE** (the old choice screen, now opt-in, with BACK).
- **A tier opens by winning the one below** (`wins_t<N>` per tier, counted by `Meta.stats_after`):
  FOREMAN by any win, RECLAIMED by a win on FOREMAN.
- **The opened tier becomes the next run's at once** (`Profile.bank_run`): the player is carried up
  and may step down.
- **The game's ending** is the unlock `u26` (`kind: ending`), earned only by a win on RECLAIMED;
  the title's ladder line says what is won, open and shut, and what cuts the line.
- Open: more rungs (the plan's ~10 stacking tiers) once the user has played this one.
