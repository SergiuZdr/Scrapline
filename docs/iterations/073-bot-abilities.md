# Iteration 073 — The bot uses shields and abilities

**Status:** in progress
**Started:** 2026-10-12
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
- [ ] Step 1 alone leaves `sim_fingerprint` at `abc8a920`.
- [ ] `tools/check.sh` green; `run_bot` reports 0 illegal actions.
- [ ] Every ability kind is used by the bot in a batch of fights (counted).
- [ ] `balance_fights --b bot.abilities=false`: the new bot is not worse than the old (B - A).
- [ ] `balance_fights --arms 150`: the Shield Caster is no longer measured as an empty arm.

## Result

## Decisions, lessons, open questions

## Next
