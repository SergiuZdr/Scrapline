# Iteration 047 — Difficulty: rarer shoves, three new arms, earlier traits

**Status:** done (awaiting the user's call on the later acts)
**Started:** 2026-10-06 · **Finished:** 2026-10-06

## Goal
Act 1 stops being free for a careful player (the agent's play-through, 2026-10-05: all three
machines through the gate, most rounds nothing hit, pits killing full-HP machines off a common
shove). The user chose the approach: shoves become a find, not a given; new arms that make a
single step not always enough; enemy traits earlier. No change to pits.

## Scope
- In:
  - **Shove arms uncommon or better**: Breaker Hammer and Scattergun go to rarity 2 (the God Hammer
    is already legendary). The starting bench keeps ONE shove arm (the hammer, as an extra); Relay
    starts with a Pulse Emitter instead of the Scattergun.
  - **Three new arms**, for both sides:
    - **Chain Flail** (common): shape `sweep` -- hits the hex aimed at and the two beside it at the
      same distance (an arc), so one step sideways is not always out of it.
    - **Snare Launcher** (uncommon): a shot with `snare` -- the machine it hits cannot move on its
      side's next move (the crew's next turn, or the enemy's next move).
    - **Mine Layer** (uncommon): shape `mine` -- drops a mine on a hex; it goes off once on whatever
      starts a round there. Mines are read as hazards (`CombatState.hazard`), so the AI steers
      round them and the board's incoming totals count them.
  - Uncommons reach enemies from Act 1's column 3 (`rarity_cap_by_column`), so snares and mines
    appear in the second half of Act 1.
  - **Traits earlier**: Act 1's `kinds.chance_by_column` starts at 20%, not 0%.
  - Board, cards, garage and glossary say what each new arm does; mines and snares are drawn.
- Out: pits (unchanged, the user's call); grenade lob and overwatch (later, if needed).

## Steps
1. Sim: `sweep` and `mine` shapes, `snare`, `CombatState.mines`, `GridUnit.snared`, clone, events
   `MINE_LAID`, `MINE_BLEW`, `SNARED`; the AI values snares and mines.
2. Data: three arms (borrowed models), rarity of hammer/scatter, bench, starting crew, kinds.
3. Presentation: attack animation and marks for sweep and mine, a mine model, a snared tag.
4. Text: part cards, garage, glossary.
5. Tests in `verify_combat.gd`; all suites; `run_bot.gd` (150) against 046's 58.0%; screenshots.

## Acceptance criteria
- [x] `verify_combat.gd`: a sweep hits the arc of three; a snared crew machine has no moves next
      turn and an enemy snared by the crew stays put on its move; a mine bites once at round start
      and is gone, is counted by `incoming`, and survives `clone` without leaking; replay determinism.
- [x] Every other suite passes; the bench offers one shove arm.
- [x] Bot (150 runs) win rate below 046's 58.0%, Act 1 losses up; numbers recorded.
- [x] Screenshots: a flail's arc aimed; a mine on the board; a snared machine.

## Result
- `verify_combat` 312/312 -- new: the flail's arc of three (not the hex behind); an enemy's snare
  holds a crew machine for its next turn (no move, dash or charge) and frees it after; the crew's
  snare holds an enemy's move; a mine is planned with no hits, counted by `incoming`, leaves no
  mine after a dry run, goes off once at the round's start, stays on an empty hex, reads as a
  hazard, cannot be stacked; replay with mines is the same.
- `verify_run` 187/187 -- new: the bench offers exactly one shove arm (`ar_hammer`, once) and no
  second hammer. Four old checks assumed the hammer was a common (refinery input, tuning costs,
  the assembly "commons without limit" build, a trader's price in `verify_run_ui`); they use a
  common that still is one, or the new costs.
- `verify_run_ui` 51, `verify_combat_input` 22, `verify_onboarding` 39, `verify_save` 15,
  `verify_meta` 77, `verify_assembly` 168: all pass.
- **Bot, 150 runs: 43.3%** (046: 58.0%). Act 1 lost 16.0% (was 11.3%) -- the aim. But Act 2 lost
  27.8% (18.8%) and Act 3 28.6% (19.4%): there every enemy can roll the uncommon snares and mines,
  and the crew has fewer shoves to answer with. 11.8 fights won a run (12.9).
- Screenshots: `shots/047_flail.png` (the arc of three aimed), `shots/047_mine_marker.png` (two
  mines on the board, Knuckles SNARED with MOVE greyed and Charge NOT NOW), `shots/047_mines2.png`
  (a mine counted as -4 under Knuckles).
- Found on the way: the enemy-fire list said "Mine Layer -> nothing" (a mine is not a hit); it now
  says "a mine under Knuckles (-4 next round unless it moves)".

## Decisions, lessons, open questions
- Shoves uncommon with one hammer on the bench; flail common, snare and mine uncommon (the user's
  pick of the proposal). Pits unchanged.
- Mines are hazards (one rule for the AI, the bot, the board's totals); a mine goes off once.
- Open: the later acts got 9 points harder each. Dials, if the user wants them back: keep snares
  and mines out of later acts' enemy rolls, or more repair on arriving in Acts 2-3, or mine damage
  3. The user plays first.

## Next
The user plays Act 1 again and says whether Acts 2-3 should be eased back.
