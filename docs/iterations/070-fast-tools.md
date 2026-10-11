# Iteration 070 — Faster tests and bot tools

**Status:** done
**Started:** 2026-10-12 · **Finished:** 2026-10-12
**Answers:** the user: the test and run tools "work too long and their efficiency seems mediocre",
they should be updated.

## Goal
The tests and the bot tools give the same answers in a fraction of the time: the sim plays the same
game faster, a bot batch uses every core by itself, and one command runs every test.

## Scope
- In: measuring where the time goes; speeding up the sim's hottest calls WITHOUT changing a single
  outcome (proved by a fingerprint of how the bot plays); `--jobs` for `run_bot.gd`,
  `balance_fights.gd` and the fingerprint; redundant work inside `verify_combat` / `verify_run`;
  `tools/check.sh`; `tools/profile_bot.gd`.
- Out (deliberately): any rule, number or AI choice; the art tools (`make_ink_thumbs`, `measure_*`,
  `shot_*`), which are run rarely and are bound by rendering; weakening any test's coverage.

## Steps
1. Baseline every headless suite, `run_bot` and `balance_fights`; profile a bot fight by phase.
2. A fingerprint of the sim (`tools/sim_fingerprint.gd`): every fight file played by the bot on three
   seeds plus four whole runs, hashed. Every optimisation must leave it unchanged.
3. The hot calls: `Hex.neighbors` (offset tables instead of the cube round trip), `Hex.distance`
   (inlined), `Hex.line` / `ray` / `within` (cached, read-only), `conduit_boost` / `_warden_cover`
   (check the kind before the distance), `IntentAI._best_shot` (aims only at hexes holding something,
   in `aim_options`' order), `IntentAI._dry_value` (one copy of the state, not two).
4. `tools/jobs.gd`: a tool runs itself as N child processes on interleaved work items and sums them.
5. `verify_combat`: two replays instead of three; the snapshot check walks the fight once instead of
   replaying every prefix. `verify_run`: the save round trip compared as text (stricter: it tells 1
   from 1.0), one half replay instead of two. Both suites print any test over a second.
6. `tools/check.sh`: every suite in parallel, one line each, `--bot N`, `--fingerprint`.

## Acceptance criteria
- [x] The fingerprint is identical before and after (`abc8a920`, 57 fights + 4 runs).
- [x] Every suite passes (`tools/check.sh`): 958 checks, 0 failed.
- [x] `run_bot.gd` and `balance_fights.gd` give the same report as before for the same seeds.
- [x] A practice fight with `--bot` plays with no errors.

## Result
Baselines were taken with all eleven tools running at once (so they are slow in absolute terms); the
after numbers with `check.sh`'s nine suites at once. The fingerprint runs alone on both builds.

| Tool | Before | After |
|---|---|---|
| sim fingerprint, one process | 227 s | 117 s (**1.9x**) |
| sim fingerprint, `--jobs` 15 | -- | 48 s (4.7x) |
| `verify_combat` | 250 s | 60 s |
| `verify_run` | 349 s | 115 s |
| all nine suites | 349 s (one after another: ~670 s) | **115 s** (`check.sh`) |
| `balance_fights --fights 60` | 261 s | 21 s, identical report |
| `run_bot`, per run | 68 s (loaded), 31 s side by side | 17 s side by side |
| `run_bot --runs 45` | 23-51 min in one process (31-68 s a run) | 4 min 43 s (15 processes) |

Per call (`profile_bot.gd`, slag_pit): `Hex.neighbors` 9.4 -> 0.8 us, `Hex.line` 21 -> 0.9 us,
`damage_to` 43 -> 10 us, `conduit_boost` 33 -> 2 us. A machine's plan now costs about 17 ms and an
enemy turn 44 ms on average (all fight files, seed 1001).

Checks: `tools/check.sh --bot 45 --fingerprint` -- every suite ok (verify_combat 360, verify_run 187,
verify_run_ui 51, verify_combat_input 27, verify_save 15, verify_onboarding 39, verify_meta 77,
verify_assembly 168, verify_animation 34); 45 bot runs, 62.2% won, 0 illegal actions. The base and
new fingerprints, both with the default seeds, diff empty. `combat.tscn -- --bot --fight slag_pit`
for 2400 frames: no errors.

What is still slow: `verify_run`'s `_test_agent_playtest` (four whole bot runs, ~70 s) is now the
longest pole of `check.sh`. The bot's time is spread over thousands of small GDScript calls
(`strike_plan` ~8-90 us each, `state.clone` ~200 us); more speed means fewer calls, which risks
changing what the AI picks.

## Decisions, lessons, open questions
- **A speed-up of the sim is proved by an unchanged fingerprint**, not by green tests: the tests check
  rules, the fingerprint checks that the bot plays the same moves. Tie-breaks depend on visiting order,
  so a filtered search keeps the order of the search it replaces (`_aims_among`).
- **Caches in `sim/` are allowed for pure geometry only, and hand out read-only arrays**
  (`make_read_only`): a caller that changed a shared line would change it for every later caller.
- **Bot batches split themselves** (`--jobs`, `tools/jobs.gd`, interleaved items so slow seeds are
  shared); `--from` + `sum_bot.py` remain for old reports. On this 8-core i9, 15 processes beat 8
  (135 s against 182 s for 30 runs).
- **A long suite names its slow tests** (`time` lines over a second): that is how the snapshot check's
  O(n^2) replays and the save test's three extra whole-run replays were found.
- ~~Open: should `_test_agent_playtest` watch two runs instead of four?~~ The user, 2026-10-12: leave it as it is (four runs).

## Next
Run `tools/check.sh` after any change, `--bot 150` after content or rules changes (about 15 min now),
and `--fingerprint` after anything meant not to change play.
