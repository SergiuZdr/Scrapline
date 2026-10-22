# Iteration 085 — Come back tomorrow

**Status:** planned
**Started:** — · **Finished:** —
**Answers:** the engagement review (B4, B9, B10, T4) and the user's answers of 2026-10-22: harder overall;
"it must not be played once and uninstalled, it needs a motive to be played again and again"; players
should come back daily and weekly for something new (daily + weekly yard); a run starts with 3 deals,
each a gift and a cost; the story's ending waits for the user's own vision (the ladder does not move it).

## Goal
Every run leaves the player a next thing to chase: the next rung, today's yard, this week's contract, a
crew's medal, and every run opens with a choice that shapes it.

## Scope
- In:
  - **B4 the ladder:** about 10 rungs, each one announced rule through B1's `adds`; a rung opens by winning
    the one below; NEW RUN starts on the highest open rung; the title names it ("NEXT RUN: RUNG 5 ·
    TRACKERS LOCK ON"). Rungs prefer taking away free recovery or free dodges over adding HP. A per-crew
    record stamp (highest rung won). Whether rungs are cumulative (rung N = rungs 1..N, as in Slay the Spire) is asked before building.
  - **The daily yard:** a seed from the date (local clock, UTC day), one fixed act condition per act, fixed
    deals, any crew; one attempt a day; a local best (acts cleared, fights won, HP left) and a streak.
  - **The weekly contract:** a seed from the ISO week, harder (a fixed rung), a fixed crew and 2-3 announced
    twists drawn from existing rules (e.g. "no workshops", "trackers lock on", "every elite volatile");
    any number of attempts, the best kept; a cosmetic plate for clearing it.
  - **Start deals** (below).
  - **B9** each crew changes one run rule; **B10** three medals per crew replacing the grind counters
    (earned unlocks are migrated, never revoked); **T4** career replay clock.
- Out: online leaderboards (later, needs a server or Steam), the story's ending.

## Start deals (the user asked for this elaborated)
Before the first map move, after the assembly bay, three fixers in the yard each offer one deal. A deal is a
**gift now and a cost for the run**, both shown in full, plus a fourth plain choice, WALK ON (no gift, no
cost). Deals are rolled from the run seed, so a seed code, the daily and the weekly always offer the same
three.

Why it works (Slay the Spire's Neow, Monster Train's pact shards, Hades' pacts): the first decision of a run
is about the whole run, a greedy start becomes a story ("I took the rare arm and the Reclaimer ate me in
Act 2"), and the same seed plays differently by the deal taken.

The deal pool is data (`data/run/deals.json`), each built only from things the run already has:

| Gift | Cost |
|---|---|
| A rare arm of your crew's maker, fitted now | The Reclaimer starts one column ahead |
| Every machine +3 max HP | No workshop in Act 1 |
| 60 scrap | Enemies +1 damage in Act 1 |
| A free level on one machine | Its first perk offer is 2 cards, not 3 |
| Scout every site of Act 1 (B2's cards all shown) | The first fight is an elite |
| A module of choice (1 of 3) | Salvage shows 2 options for the first three fights |
| Remove one starter arm for a random uncommon | You do not choose the arm |

Three rules keep them honest: a gift is worth about one good salvage pick; a cost is always a run rule the map
or the HUD shows (never a hidden number); one of the three is always a soft deal (small gift, small cost).
Higher rungs could add a fourth fixer with a bigger deal (a later choice for the user).

## Acceptance criteria
- [ ] Rungs 0/4/10 at 150 runs each: monotone; top rung 15-30% for the bot; no step over ~12 points;
      fights costing <= 0 HP fall toward 20-25%; rounds per run reported.
- [ ] The daily and weekly seeds are the same for every player on that day/week (verify_run: a fixed date
      gives a fixed seed and region); one daily attempt; the best and the streak survive a restart.
- [ ] Deals: the same seed offers the same three; each deal's cost shows on the map or the HUD; the save
      replays the pick; RunBot takes deals by a stated policy and the bot's win rate per deal is reported.
- [ ] Crews within about 10 points of each other; medals: fewer than 20% fall to the non-aiming bot in 10 runs.
- [ ] Screens: the ladder line, the daily/weekly panel, the three deals, a crew card with medals.

## Result

## Decisions, lessons, open questions

## Next
086: builds that change rules.
