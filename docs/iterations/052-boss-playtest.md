# Iteration 052 — The agent plays every boss and warlord

(Numbered 051 while it was built; another session's 051 is `051-comic-machines.md`. Code comments
and commits from this iteration say 051.)

**Status:** done (awaiting the user)
**Started:** 2026-10-08 · **Finished:** 2026-10-08
**Answers:** the user (`/act-as-me`): "play every boss and miniboss to check in game if there are any
issues/bugs and if u think they need a new change".

## Goal
Each of the six keeper fights played by hand, turn by turn; what is broken fixed, what is weak
changed, the rest written down for the user.

## How it was played
- `tools/play_fight.gd` (new): replays an action log and prints the board as text, the machines
  (with their reachable hexes), the enemy's intents and `incoming`, the tricks' state, the best
  attack previews, and last turn's events; `--arena` / `--escorts N` build a practice board as a run
  would; `--bot N` lets `CombatBot` play the crew on and lists every trick event.
- `tools/dump_boss_fights.gd` (new): bot runs, saving each boss and warlord fight exactly as the run
  built it (its crew with their parts, levels and perks) with its combat seed.
- Grinder, Sorter, Magnet King: played by hand with the starting crew on run-shaped boards; The Pour:
  by hand with run 1000's crew; Twin Furnaces and the Core: run 1001/1003 and 1000's crews, played by
  `CombatBot`, watched.

## Findings
| # | Fight | What happened | Kind | Done |
|---|---|---|---|---|
| 1 | All | Enemies shot lone fuel drums that hurt nobody -- and the Lancer's shot through a drum by the Sorter hurt three of its own. The quick score's drum bonus (+40) was a guess the dry run could only RAISE, never lower | Bug (AI) | Fixed: the attack is chosen from the dry runs |
| 2 | Pour, Sorter | A later enemy walked into an earlier ally's committed line (drones shooting drones, a Hauler in front of The Pour) | Bug (AI) | Fixed: allies' committed lines are danger to the planner |
| 3 | Sorter | The claw re-grabbed the machine already on its pad, "throwing" it onto the hex it stood on for 2 | Bug | Fixed: a machine beside it or on its pad is not grabbed |
| 4 | Grinder | Over 5 rounds the charge never stuck: it sticks only when the lane happens to end on a wall; a charge into a machine never did. The player had no way to make it happen | Design | A charge into a machine BRACED against something solid (or into its own side) sticks too |
| 5 | Sorter | The hatch opened (the throw-onto-the-pad combo works) but the Sorter walked off the thrown machine, so only guns could use the opening | Design | An exposed keeper holds still for the turn it is open |
| 6 | Pour | One burst tank gave two turns of double damage: 52 -> 18 in two turns | Design | `quench_rounds` 1: burst it and hit it in the same turn |
| 7 | Twins | A real Act 3 crew killed both twins in the same turn, round 4; the rebuild never mattered | Balance | Twin HP 26 -> 34 (the same crew still wins in 4: it is a strong run) |
| 8 | Core | Over in 6 rounds (7 without the open side), the crew barely scratched | Balance | `open_bonus` 3 -> 2 |
| 9 | Magnet | The haul drags drums by itself; the player cannot set one up | Design | Open: let the crew's Magnet ability pull a drum (proposed to the user) |
| 10 | All | Ground labels ("CHARGES NEXT ROUND", "THE CLAW", "OPEN SIDE") are small at the board's zoom and the claw's sits under the hint bar | UI | Open |
| 12 | Sorter | After 1-6 the bot lost the Act 1 gate 3 times in 150 (was 15): the claw now reliably feeds the pad-block combo and the open Sorter holds still | Balance | Sorter HP 18 -> 24 (5 losses) |
| 11 | Practice | `--fight` boards field every enemy authored; a run fields the act's escorts (Act 1 warlord: 2, not 4) | Tooling | `play_fight.gd --escorts` |

## Acceptance criteria
- [x] Every fix has a `verify_combat` check; every suite passes.
- [x] Bot 150 runs recorded against 050 (47.3%).
- [ ] The user reads the findings and answers the open ones.

## Result
- `verify_combat` **355/355** (new: a braced charge sticks; an exposed keeper holds still; the claw
  skips a machine beside it; the quench and open-side checks read their numbers from the rules).
  `verify_combat_input` 27, `verify_run` 187, `verify_run_ui` 51, `verify_onboarding` 39,
  `verify_save` 15, `verify_meta` 77: all pass.
- The six real fights (`shots/play/real_*.json`) with `CombatBot`: all won in 4-7 rounds by those
  runs' crews; the Grinder stuck in round 2, the claw -> pad -> hatch chain fired, a tank burst, the
  twins' rebuild started.
- **Bot, 150 runs: 55.3%** (050: 47.3%). After the fixes with an 18 HP Sorter: Act 1 lost 10.0% (gate
  3), Act 2 22.2% (6), Act 3 21.0% (7). With the Sorter at 24 HP: Act 1 11.3% (gate 5), Act 2 20.3%
  (5), Act 3 21.7% (8). The AI fixes help the bot's own crew as well as the enemy (it shares
  IntentAI), so part of the rise is the bot playing better, not the fights getting easier.
- Screenshots: `shots/051/sorter_claw.png` (a real run's Sorter fight, the claw's mark),
  `shots/051/core.png`.

## Decisions, lessons, open questions
- IntentAI picks the attack from the dry runs, not the quick guess (MEMORY decisions).
- Lesson: practice boards are not run boards -- `--fight` fields every authored enemy and the
  starting crew; judge a keeper on a fight a run actually built (`dump_boss_fights.gd`).
- Open: the Magnet King's trick has no player agency (finding 9); small ground labels (finding 10);
  the overall rise to 55.3% (043-047 aimed lower).

## Next
The user plays the keepers; answers on 9, 10 and the difficulty.
