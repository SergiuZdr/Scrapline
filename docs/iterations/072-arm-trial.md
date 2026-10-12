# Iteration 072 — The arm trial

**Status:** done
**Started:** 2026-10-12 · **Finished:** 2026-10-12
**Answers:** the user, after 071 found that random fights cannot rank the arms (the crew wins 98%):
"make the arms test harder".

## Goal
A test that ranks every arm with a verdict: which arms make the crew win more, or win faster, than
the average arm -- on fights the crew can actually lose.

## Scope
- In: `balance_fights.gd --arms N`: N scenarios (map, random crew, random enemy squad toughened by
  `--arm-hp` / `--arm-damage`), each played once per arm with that arm on every crew machine's left
  socket and nothing else changed; ranking against the per-scenario average of all arms, with
  intervals sized for all arms judged at once.
- Out (deliberately): changing any arm, or the bot (its blind spots are reported, not fixed); the
  normal random section (unchanged, now pointing to `--arms`).

## Steps
1. Rank ARMS, not weapon classes: a class mixes unlike arms (mortar holds the Mine Layer, scanner the
   Shield Caster, hammer the Flail).
2. Paired design: every arm meets the same scenarios; each is scored by how far it sits from the
   average of all arms on that scenario (win, rounds, crew HP lost).
3. Calibrate the enemy toughening so the crew wins 50-75% and most scenarios go either way.
4. A 150-scenario batch; read the ranking.

## Acceptance criteria
- [x] The crew's win rate in the trial is between 50% and 75% by default (63.1%).
- [x] Most scenarios depend on the arm (125 of 150 went either way).
- [x] The ranking flags arms with intervals that exclude zero, sized for 20 arms at once.
- [x] The normal `balance_fights` path and `stats.gd` self-check still work.

## Result
Calibration (15 scenarios each): +0 HP: the crew won 100%; +8 HP +2 damage: 93% (the bot dodges almost
every telegraphed shot); +16/+4: 89%; +30/+4: 76%; **+40 HP +5 damage: 66%, 14 of 15 scenarios
decisive** -- the default. Losses then are mostly out of rounds (689 of 1106), so the trial weighs an
arm's damage most, which is its job; crews were also wrecked (238) and objectives lost (179).

`balance_fights --arms 150` (3000 fights, 26 min with Chrome busy on the same Mac):

| Arm | Rarity | Won | vs average | Rounds vs average | Verdict |
|---|---|---|---|---|---|
| Sunspear | 4 | 91.3% | +28.2 (+20.6 to +35.8) | -4.5 | wins more, faster |
| God Hammer | 4 | 86.0% | +22.9 (+14.5 to +31.3) | -2.4 | wins more, faster |
| Railgun | 3 | 78.0% | +14.9 (+6.5 to +23.2) | -1.7 | wins more, faster |
| Coilgun | 3 | 73.3% | +10.2 (+1.9 to +18.5) | -0.7 | wins more, faster |
| Lance | 2 | 70.7% | +7.5 | -0.6 | |
| Maul | 2 | 69.3% | +6.2 | +0.2 | |
| Cleaver, Saw | 1, 2 | 67.3% | +4.2 | +0.2 | identical: see below |
| Ripper, Scattergun, Hammer, Flamer | 1-2 | 61-66% | -2 to +3 | | |
| Mine Layer | 2 | 59.3% | -3.8 | +0.9 | slower |
| Flail, Scanner, Harpoon | 1 | 57-58% | -5 to -7 | | Scanner slower |
| Pulse | 1 | 51.3% | -11.8 (-20.1 to -3.5) | +1.0 | wins less, slower |
| Mortar | 2 | 48.0% | -15.1 (-24.0 to -6.3) | +0.8 | wins less |
| Snare | 2 | 38.0% | -25.1 (-34.7 to -15.6) | +1.8 | wins less, slower |
| Shield Caster | 2 | 36.7% | -26.5 (-35.4 to -17.6) | +1.6 | wins less, slower |

What it says:
- Rarity mostly orders power (the two legendaries, then the two rares), which is the curve working.
- **The Mortar and the Snare are weak for rarity 2**: they lose to every common melee arm.
- **Two results are the BOT, not the arm.** The Shield Caster is never cast: `IntentAI._best_shot`
  skips any attack that hits nobody, and a shield hits nobody, so a crew carrying it fights one-armed.
  The Saw and the Cleaver measure exactly the same because their numbers in the fight ARE the same
  (melee, 4 damage, 1 heat; they differ only in their tunings). *Corrected in 073: this said the Saw's
  ability, Rend, made the difference -- but an arm's `"ability": "ab_rend"` is left over from the
  archived real-time game and the hex fight never reads it.* An arm whose worth is an ability or a support effect is
  under-rated by this trial until the bot uses it.

Checks: `stats.gd` self-check all good; `balance_fights --fights 60` unchanged (95.0%); no sim file
touched.

## Decisions, lessons, open questions
- **Arms are ranked by the arm trial** (`--arms 150`): paired scenarios, toughened enemies (+40 HP +5
  damage by default) so the crew wins about 63%, ranking against the per-scenario average, intervals
  for 20 at once. Rank arms, never weapon classes.
- **A tie to the decimal between two parts means the test cannot see what separates them** -- or that
  nothing does (Saw and Cleaver have the same numbers; corrected in 073). Read a trial against what
  the bot can do, and check the parts' numbers before blaming the bot.
- Open: should the bot cast shields and use abilities (it would change the enemy AI too -- the same
  `IntentAI` plays both sides)? Should the Mortar and the Snare get stronger?

## Next
Before an arm change, run `--arms 150` on both sides of it (or `--arms 150 --set ...` against the
plain run). The user decides what to do with the Mortar, the Snare and the bot's blind spots.
