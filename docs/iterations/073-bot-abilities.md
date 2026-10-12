# Iteration 073 — The bot uses shields and abilities

**Status:** done
**Started:** 2026-10-12 · **Finished:** 2026-10-12
**Answers:** the user, after 072: "yes, make the bot use shields and abilities".

## Goal
The bot plays every part it is given: it casts the Shield Caster on a threatened ally, and it uses
every ability a machine has (Charge, Grapple, Barricade, Shield, Dash, Flush, Magnet; it already used
Focus and Overdrive), each when the real rules played on a copy say it is worth more than the plain
attack. The arm trial then measures the support arms instead of the bot's blind spot.

## Scope
- In: `CombatBot` (the player's side) and `IntentAI` where it scores a shield cast; a switch to play
  the old bot (`--set bot.abilities=false`, `--b bot.abilities=false`) so the new bot is judged
  against the old on the same fights; the arm trial and the run bot re-measured.
- Out (deliberately): the enemy AI. Abilities are the player's only (`CombatAbilities.usable`) and
  no enemy carries a shield-casting arm (`"enemy": false`), so the enemies play exactly as before.
  No rule, number or part changes.

## Steps
1. Refactor first, no change in play: the dry-run scoring in `IntentAI._dry_value` becomes a
   function of two states (`effects_value`), shared with the abilities. Fingerprint unchanged.
2. `CombatBot.protection(before, after)`: what an action saves the crew from the enemy's volley
   (`CombatSim.incoming` on both states), scored like damage dealt.
3. Shield Caster: `_best_shot` keeps a plan that shields an ally; quick score from the danger map,
   refined by `protection`.
4. Abilities in `plan_unit`: Flush before planning when the next attack would overheat; after the
   move, Charge / Grapple / Barricade / Shield played on a copy for every target and taken instead of
   the attack when worth more; after the action, Dash out of danger and Magnet a pile in reach.
5. Machines that protect (a shield arm, Shield, Barricade) act last, after the others have moved.
6. `plan_unit(..., false)` plans on a copy, so the `--bot` demo and the tests see the same actions.
7. Measure: old bot against new on the same fights; the arm trial; the run bot.

## Acceptance criteria
- [x] Step 1 alone leaves `sim_fingerprint` at `abc8a920`.
- [x] `tools/check.sh` green; `run_bot` reports 0 illegal actions.
- [x] Every ability kind is used by the bot in a batch of fights (counted) -- except Flush, see Result.
- [x] `balance_fights --b bot.abilities=false`: the new bot is not worse than the old (B - A).
- [x] `balance_fights --arms 150`: the Shield Caster is no longer measured as an empty arm.

## Result
Built as planned. The scope line about the enemy was right and 072's warning was wrong: abilities are
the player's only and no enemy carries a shield arm, so **the enemies play exactly as before** -- the
old-bot mode (`bot.abilities=false`) reproduces the old fingerprint `abc8a920` exactly. The new bot's
fingerprint is `1dd1b7d8`: the baseline for `check.sh --fingerprint` from now on.

**Whole runs, new bot (A) against the old (B), same 150 seeds** (`run_bot --runs 150 --b bot.abilities=false`, 20 min):

| | New bot | Old bot |
|---|---|---|
| Runs won | **67.3% (59-74)** | 54.7% (47-62) |
| B - A | | **-12.7 points (95%: -22.0 to -3.4), real** |
| Fights won per run | 13.8 +-0.7 | 12.9 +-0.8 |
| Lost in act 1 / 2 / 3 (of those who got there) | 8.0% / 13.8% / 15.1% | 10.7% / 20.9% / 22.6% |
| Crew HP going into the boss (sum of three) | 38.7 | 36.0 |
| Illegal actions | 0 | 0 |

**Single fights** (`balance_fights --fights 600 --b bot.abilities=false`): random fights 98.7% against
98.3%, B - A -0.3 (-1.0 to +0.3), not detectable -- the crew already wins nearly all of them -- but
crew HP lost per fight 2.5 +-0.3 against 2.9 +-0.3. The gain is HP carried between fights, which is
why it shows over a run and hardly in one fight.

**The arm trial with the new bot** (`--arms 150`, 3000 fights, 30 min): the crew won 67.1% (63.1% in
072). Used: Charge 3273, Dash 2492, boosts 7883, shield arm casts 298, Magnet 193, Grapple 140,
Barricade 67, Shield 37, Flush 0.

| Arm | 072 (old bot) | 073 (new bot) |
|---|---|---|
| Sunspear | 91.3%, +28.2 | 93.3%, +26.3 wins more |
| God Hammer | 86.0%, +22.9 | 89.3%, +22.3 wins more |
| Railgun | 78.0%, +14.9 | 82.7%, +15.6 wins more |
| Lance | 70.7%, +7.5 | 80.0%, **+12.9 wins more** |
| Coilgun | 73.3%, +10.2 | 75.3%, +8.3 (faster only) |
| Maul .. Scanner (11 arms) | within the noise | within the noise |
| Mine Layer | 59.3%, -3.8 | 56.7%, **-10.4 wins less** |
| Pulse | 51.3%, -11.8 | 54.7%, -12.4 wins less |
| Mortar | 48.0%, -15.1 | 50.7%, -16.4 wins less |
| Shield Caster | 36.7%, -26.5 | **48.7%, -18.4** wins less |
| Snare | 38.0%, -25.1 | 44.7%, -22.4 wins less (now last) |

What it says:
- The Shield Caster is now played (about two casts a fight) and gained 12 points, but it still wins
  less than any attacking arm: a 3-point field on one ally for one volley is worth less than a hit,
  in fights where the bot already steps out of most telegraphed shots. That is now a fact about the
  arm, not about the bot.
- Mortar, Snare and Pulse stay at the bottom with a bot that plays everything: their weakness is real.
- Flush was never triggered in 3600 fights: the bot's condition (the next attack would reach the heat
  cap) does not come up, because the bot already shuns attacks that would overheat and vents when it
  has nothing to hit. `verify_combat` shows it is used when the condition holds.

Checks: `tools/check.sh --fingerprint` (in a scratch copy): ten suites ok (verify_combat 370 with 073's ten
bot checks, verify_run 187, verify_run_ui 51, ...), fingerprint `1dd1b7d8`. The new
bot plans about 10% slower (83 s against 77 s for 300 fights).

## Decisions, lessons, open questions
- **The bot plays every part it is given**: an ability or a shield cast is played for real on a copy
  for every target and taken when it is worth more than the plain attack; what protects is scored by
  what it saves the crew from the volley (`CombatBot.protection`, `CombatSim.incoming` before and
  after), a point kept worth a point hit. Machines that protect move last.
- **`--set bot.abilities=false` plays the bot as it was**, so any later bot change is judged against
  the old one on the same seeds (and it is how the old fingerprint was proved untouched).
- Lesson: **the bot's skill is part of every number it reports.** The run win rate rose 12.7 points
  with no rule changed; every earlier report was measured with a bot that left Charge, Dash and
  every support part unused. Re-measure before tuning difficulty against older reports.
- Lesson: 072 made two wrong claims, both checked here: the Saw ties the Cleaver because their numbers
  are the same (an arm's `"ability"` is archive data), and abilities could not change the enemy AI
  (they are the player's only).
- Open: is the Shield Caster meant to be this weak (rarity 2, wins 18 points less than the average
  arm)? Mortar, Snare, Pulse and now the Mine Layer still rank low. Should the game be harder, now
  that the bot wins 67% of runs?

## Next
Balance work starts from the new bot: `run_bot --runs 150` gives 67%; the arm trial gives the table
above.
