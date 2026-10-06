# Iteration 046 — Agent play-test fixes

**Status:** done
**Started:** 2026-10-06 · **Finished:** 2026-10-06

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
- [x] `verify_run_ui.gd`: a resumed fight is not busy and END TURN is live.
- [x] `verify_run.gd`: over many seeds, no reward offers a part in the hold or among the last
      `recent_offers`; no legendary offered twice in a run; column 1 never all fights; a workshop
      in the column before the gate; no two linked sites the same service; a frame swap keeps
      the missing HP.
- [x] Every other suite passes; `run_bot.gd` still plays (win rate recorded, compared with 045's).
- [x] Screenshots: a fight's bottom row clear of the HUD; the hold zone; the gate pylons in frame;
      a map with an off-screen site arrow; a warlord hoard and a gate win card; the level-up banner.

## Result
Everything in scope is in. Checks:
- `verify_run_ui` 51/51 -- the new resume check failed without the fix and passes with it.
- `verify_run` 185/185 -- new: 4 bot runs (177 offers) with no part offered from the hold or the
  last six and no legendary twice; 200 regions x every act with a non-fight first step, a workshop
  before the gate and no linked repeats; a refit keeps the missing HP both ways. (A first version
  played 40 whole bot runs and took over 9 minutes; 4 is enough to see every reward kind.) The old
  "warlord's hoard holds a legendary some of the time" check now clears the run's seen legendaries
  between rolls -- it measures the chance, and 046 makes each legendary once a run.
- `verify_combat` 298, `verify_combat_input` 22, `verify_onboarding` 39, `verify_save` 15,
  `verify_meta` 77: all pass.
- **Bot, 150 runs: 58.0%** (038: 52.7%). Act 1 lost 11.3%, Act 2 18.8%, Act 3 19.4%; 5.0 of 15
  rare+ parts at the last gate. The workshop before every gate and rewards that do not repeat make
  runs a little easier -- in the direction 047 corrects.
- Screenshots (`shots/046_*.png`): fights and the gate framed above the HUD with pylon caps; map edge
  arrows and labels clear of the hint line; THE WARLORD'S HOARD; GATE BROKEN!; the level-up banner;
  the upgrade header; the title framing.
- First tries that failed: the calm first column was placed before the no-repeat pass, which then
  rerolled it into a fight (fixed by running it last); edge arrows showed for sites visible left of
  the crew dock (now only off screen or under the dock); the title camera first overshot and cut the
  third machine.

## Decisions, lessons, open questions
- Rewards avoid the hold, the last `recent_offers` and seen legendaries; a preference, not a wall.
- Map rules and refit-keeps-missing-HP as in MEMORY.
- Lesson: a test that waits on `_busy` must fail when it never clears.
- Open: the user's eye on the framing, the paper hold zone and the edge arrows.

## Next
047, difficulty (the user's pick): shove arms uncommon with one on the starting bench; flail, snare launcher and mine layer; enemy traits earlier in Act 1; measured against this 58.0%.
