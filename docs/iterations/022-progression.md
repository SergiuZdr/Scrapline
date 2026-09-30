# Iteration 022 — Between-run progression

**Status:** in progress
**Started:** 2026-09-30 · **Finished:** —
**Answers:** the user: "continue with the feel pass and between run progression".
Plan: `plans/meta-progression.md` (unlocks only: nothing carried between runs makes a machine's
numbers bigger).

## Goal
A run leaves something behind. Parts, starting crews and harder tiers unlock as runs are played
-- something after nearly every one of the first runs, win or lose -- and a new run starts from a
choice of crew and tier.

## Scope
- In:
  - **What is locked** (`data/meta.json`): twelve parts (every rare, a few uncommons) start out
    of the pools; two alternative starting crews; two harder tiers.
  - **What unlocks them**: lifetime milestones -- runs played, fights won, the furthest act
    reached, runs won -- in one ordered table, so the first ten runs each give something.
  - **Pure rules** (`sim/run/meta.gd`): what a set of stats has earned; the options a run starts
    with (crew, tier overlay, locked parts), resolved once and SAVED with the run, so a run
    replays the same whatever unlocks later.
  - **The profile** holds the stats and unlocks, banked once per run.
  - **Screens**: NEW RUN offers crew and tier once there is a choice; the run's end lists what
    it unlocked; the title shows progress.
  - The run bot and tests play with everything unlocked (their numbers stay comparable).
- Out (deliberately): the codex; blueprints as drops inside a run; ten tiers (two for now).

## Steps
1. `data/meta.json`, `Meta`, `RunSetup` options, the save carrying them; tests.
2. Profile: stats, unlocks, banking. 3. Screens. 4. Suites, run bot, docs.

## Acceptance criteria
- [ ] `verify_meta.gd`: a fresh profile's pools lack the locked parts; the milestones unlock in
  order; a run saved with its options replays identically after more unlocks; banking a run
  twice counts once; a tier's overlay reaches the fight.
- [ ] A fresh profile starts a run with no chooser; after unlocks the chooser appears.
- [ ] Run bot unchanged (everything unlocked); every suite passes.

## Result

## Decisions, lessons, open questions

## Next
