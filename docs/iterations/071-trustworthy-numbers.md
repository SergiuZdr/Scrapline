# Iteration 071 — Numbers you can trust

**Status:** done
**Started:** 2026-10-12 · **Finished:** 2026-10-12
**Answers:** the user, after 070: yes, do the second part -- make the bot tools' numbers mean
something (margins of error, comparing variants), not only arrive faster.

## Goal
Every rate the bot tools print says how sure it is, a balance change can be measured against the
current game on the same seeds with a verdict, and an arm is flagged only when the difference is
bigger than the noise.

## Scope
- In: `tools/stats.gd` (Wilson intervals, paired and unpaired differences, runs needed, the shared
  `--set` parser); `run_bot.gd` (intervals on the win rate, per-act losses and fights per run; `--b`
  A/B on the same seeds with a verdict); `balance_fights.gd` (`--set`, `--b`, `--seeds`; intervals;
  arms judged by fights with the arm against fights without it).
- Out (deliberately): any rule, number or AI choice; the bot's policy; the report's existing lines
  (kept, with the margins added) so old reports still compare and `sum_bot.py` still reads them.

## Steps
1. `tools/stats.gd` and a self-check against known values (`--self-check`).
2. `run_bot.gd`: margins; `--b path=json` (repeatable) plays A and B on every seed and reports B - A.
3. `balance_fights.gd`: `--set`/`--b` (same syntax), `--seeds` for the authored fights, margins, the
   arm comparison.
4. Measure: a known-null A/B (B = A) must say "no detectable difference"; a real dial must show.

## Acceptance criteria
- [x] `stats.gd --self-check` matches textbook values (Wilson 7/10 = 39.7-89.2%; Newcombe's own
  example 56/70 vs 48/80 = 0.052 to 0.334; z for ten tests 2.807).
- [x] `run_bot --runs 30 --b starting_scrap=10` (the current value) reports "no difference at all".
- [x] `run_bot --b` with a real dial reports a difference and an interval.
- [x] `balance_fights` prints intervals and flags arms only when the interval excludes zero.
- [x] `tools/check.sh` green; `sim_fingerprint` unchanged (`abc8a920`; no sim file touched).

## Result
Built as planned, plus two corrections found by using it:
- The textbook interval for a difference (p1 - p2 +- z*se) collapses at 0% or 100%: its first batch
  called three arms that won 100% "real". Now Newcombe's interval from the two Wilson intervals.
- Ten arms judged at 95% each flag one by chance in about 40% of batches. The arm intervals are now
  sized for the number of arms (Bonferroni, `Stats.z_for`).

What the tools now say about the game:
- **A whole-run A/B needs many runs.** `run_bot --runs 45 --b 'enemies.count_by_column=[4,4,4,4,5,5,5,6,6]'`
  (one more enemy per fight): A 62.2% (48-75), B 53.3% (39-67), B - A -8.9 points (95%: -27 to +9),
  not detectable. Same seeds hardly help over a whole run: one changed fight changes the salvage and
  the route, and the two runs part ways (11 seeds only A won, 7 only B). Fights won per run did move
  (13.7 +-1.2 against 12.3 +-1.5). A run-level dial of this size needs ~200+ runs per variant.
- **A fight-level A/B is sharp.** `balance_fights --fights 300 --b combat.max_rounds=6`: random fights
  98.3% -> 91.3%, B - A -7.0 points (95%: -9.9 to -4.1), real; authored -11.6 (-18.0 to -5.1), real.
  The same squads fight the same fight, so pairing works.
- **The random fights cannot rank the arms**: the crew wins 98.3% (96-99), so every arm sits within a
  few points of it and none is told apart (all ten intervals include 0). The old "mortar -8.2, more
  than 6 points off" at 60 fights was noise. Arms can only be compared in fights the crew can lose.
- The authored fights at five seeds read "100% (57-100)" each: the interval shows how little five
  samples say. Seeds do change these fights (measured: five different event hashes and round counts
  for every board) -- 070's report called them nearly identical, which was wrong.

Checks: `tools/check.sh --bot 15 --fingerprint`: ten suites ok (the stats self-check is one now),
15 runs 73.3% (48-89), 0 illegal actions, fingerprint `abc8a920` unchanged. Times were about double
070's because Chrome was busy on the same machine.

## Decisions, lessons, open questions
- **Every rate a bot tool prints carries its 95% interval; a difference between variants is judged by
  whether its interval leaves out zero, and several judged at once share the 5%** (`tools/stats.gd`).
- **Compare balance dials at the level where pairing works**: a combat dial with `balance_fights --b`
  (same squads, same fight), a run dial with `run_bot --b` and a lot of runs. Runs diverge after one
  changed fight, so same seeds buy little over a whole run.
- **A test the crew always wins cannot rank anything.** Open: should `balance_fights`' random squads
  face harder enemy squads (more of them, or higher rarity) so the arms can be told apart?

## Next
Use `--b` for the next balance question; for a run dial, start at `--runs 150`.
