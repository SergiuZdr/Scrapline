# Iteration 047 — Difficulty: rarer shoves, three new arms, earlier traits

**Status:** in progress
**Started:** 2026-10-06 · **Finished:** —

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
- [ ] `verify_combat.gd`: a sweep hits the arc of three; a snared crew machine has no moves next
      turn and an enemy snared by the crew stays put on its move; a mine bites once at round start
      and is gone, is counted by `incoming`, and survives `clone` without leaking; replay determinism.
- [ ] Every other suite passes; the bench offers one shove arm.
- [ ] Bot (150 runs) win rate below 046's 58.0%, Act 1 losses up; numbers recorded.
- [ ] Screenshots: a flail's arc aimed; a mine on the board; a snared machine.

## Result
(after the work)

## Decisions, lessons, open questions

## Next
The user plays Act 1 again.
