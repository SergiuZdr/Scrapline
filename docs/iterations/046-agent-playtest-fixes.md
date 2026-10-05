# Iteration 046 — Agent play-test fixes

**Status:** in progress
**Started:** 2026-10-06 · **Finished:** —

## Goal
Everything the agent's play-through of Act 1 (2026-10-05, 10 fights through the Sorting Gate)
found, except difficulty, is fixed: the two bugs, rewards that stop repeating, map rules that
always leave a repair stop before the gate, a board the HUD does not cover, labels that do not
pile up, and the big moments (warlord, hoards, a broken gate) that look like what they are.
Difficulty (free dodging, one-shot pits) is deliberately left for a measured iteration of its own.

## Scope
- In:
  - **Bugs:** a resumed fight stayed `_busy` (END TURN greyed, nothing clickable); the level-up
    banner said NEW ARMOUR for the level kit and covered the name; two `Juice` log errors.
  - **Rewards:** no part offered that is in the hold or was offered in the last
    `rewards.recent_offers` parts; a legendary at most once a run; applies to salvage, hoards,
    scrapyards, traders, signals and the auction.
  - **Map:** column 1 always has a site that is not a fight; a workshop guaranteed in the column
    before the gate; no two linked sites the same service.
  - **Refit:** a swapped frame keeps the machine's missing HP, not its current HP.
  - **Board:** the camera frames the whole board above the HUD; the hold zone in its own colour
    with a readable label; live wires that read; the gate pylons inside the frame with a cap.
  - **Labels:** tags of machines side by side spread sideways; reachable map sites off screen get
    an edge arrow with their name; site labels never sit under the controls hint.
  - **Big moments:** the warlord's own icon; hoards titled as hoards; the act's gate win as its own
    card.
  - **Small:** the upgrade screen's title over its subtitle and "tunings" wording; the title's
    button row over the left machine.
- Out (deliberately): difficulty (dodging, pit kills, Act 1 enemy numbers) — next iteration,
  measured with `run_bot` first.

## Steps
1. Bugs (done before this file: resume, banner, Juice) + a resume check in `verify_run_ui.gd`.
2. Rewards in `RunSim` (`RunState.offered`, `RunState.legends`), `run.json` `recent_offers`.
3. Map rules in `_generate_region`; `run.json` `workshop_guaranteed_columns`.
4. Refit keeps missing HP.
5. Board: camera, hold zone, live wires, pylons.
6. Labels: board declutter sideways, map edge arrows, hint line.
7. Big moments and small fixes.
8. Tests for 2-4 in `verify_run.gd`; all suites; `run_bot.gd`; screenshots.

## Acceptance criteria
- [ ] `verify_run_ui.gd`: a resumed fight is not busy and END TURN is live.
- [ ] `verify_run.gd`: over many seeds, no reward offers a part in the hold or among the last
      `recent_offers`; no legendary offered twice in a run; column 1 never all fights; a workshop
      in the column before the gate; no two linked sites the same service; a frame swap keeps
      the missing HP.
- [ ] Every other suite passes; `run_bot.gd` still plays (win rate recorded, compared with 045's).
- [ ] Screenshots: a fight's bottom row clear of the HUD; the hold zone; the gate pylons in frame;
      a map with an off-screen site arrow; a warlord hoard and a gate win card; the level-up banner.

## Result
(after the work)

## Decisions, lessons, open questions

## Next
Difficulty: dodging and pit kills, measured with `run_bot` and `balance_fights`, then the user.
