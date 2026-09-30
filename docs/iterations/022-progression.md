# Iteration 022 — Between-run progression

**Status:** done -- waiting for the user to play it
**Started:** 2026-09-30 · **Finished:** 2026-09-30
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

- **`data/meta.json`**: 12 locked parts (every rare and four uncommons; none in the default crew
  or on the bench), 3 crews (the Salvagers; the Wall and the Runners to unlock), 3 tiers (Yard
  Hand; Foreman and Reclaimed to unlock), 16 unlocks keyed to lifetime runs, fights won, the
  furthest act and wins.
- **`Meta`** (`sim/run/meta.gd`, pure): `stats_after`, `earned`, `next_unlock`, `opened`,
  `options`. **`RunSetup.create(..., options)`** lays the tier's overlay on the rules
  (`RunSetup.overlay`, which acts now share), swaps the starting crew and keeps locked parts out
  of the pools. The save carries the options (`RunStore`), so a run replays the same later.
- **Profile**: `stats`, `unlocked`, `bank_run(key, state, rules)` (once per run), `run_choice`,
  `choose_run`. `Run.bank()` and `Run.new_run_from_profile()`.
- **Screens**: NEW RUN goes straight in on a profile with nothing to choose, through THE NEXT RUN
  (crew, tier, START) once something is unlocked (`shots/022/choose.png`); the run's end lists what
  it unlocked and what comes next; the title shows "UNLOCKED n / 16".
- `verify_meta.gd`: 57 passed (ten runs of five fights with one win: every one of the ten unlocks
  something). Every suite passes; run bot over 150 two-act runs: **75.3%**, 0 illegal actions (021's 85.0% was a 60-run sample: the larger run is the number to keep).

Found on the way: 021 shipped two enemy kinds with no glossary card (the onboarding suite was
not run before its merge). Both have one now.

Not done: the chooser and the unlock lines were checked in screenshots and tests, not played
through a real run's end.

## Decisions, lessons, open questions
- **Unlocks widen options, never numbers**; a fresh profile has 28 of 40 parts, one crew, one tier.
- **A run saves the options it started with**, so nothing unlocked later changes a run in progress.
- Lesson: run EVERY suite before a merge, not the ones that seem related.
- Open: is one unlock per early run the right pace? Are two harder tiers enough for now?

## Next
The feel pass (023); Act 3.
