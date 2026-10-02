# Iteration 032 — Play-test 10 fixes

**Status:** in progress
**Started:** 2026-10-02 · **Finished:** —

## Goal
The quick half of [play-test 10](../playtests/2026-10-02-playtest-10.md): a bigger board, your
machines named on it, parts pictured wherever you trade them, a garage that lines up and reads,
an arena that is a real fight, and rares that are earned rather than everywhere by Act 3.

## Scope
- In: PT10-1 (rarity economy), PT10-2 (names on the board), PT10-3 (bigger boards), PT10-4 (part
  pictures at sites), PT10-5 (the arena), PT10-9 (garage alignment, NUMBERS readable), the crew
  card whose HP squares covered its HP line. Also: tools never touch the player's save or profile
  (a screenshot tool banked a bot's run into the user's profile while this was being planned;
  restored from the backup).
- Out (next iterations): the parts audit and new modules (033), unlock missions (034), the
  interactive pass (035), comic style (036).

## Steps
1. Tools: `RunStore.path()` and the `Profile` autoload use files of their own under `--script`.
2. Board: `run.json` `board` pads every run board (`rows` between the two sides, `cols` split to
   the edges) before terrain and objectives are rolled; the middle rows are worked out from the
   board's height, not `[2, 3, 4, 5]`.
3. Board tags: your machines carry their names; crew cards: 16 smaller squares a row, and a card
   grows if a third row is ever needed.
4. Sites: the refinery shows the hold as part cards with the price under each; the trader's sell
   list too; the auction shows the crate's prize as a card.
5. Arena: `enemies.arena` -- extra machines, every one tougher and armed, rarer parts.
6. Rarity: Act 2/3 salvage weights down, the Act 3 elite back to uncommon+, refinery and auction
   dearer and rarer on the map, auction legendary odds halved.
7. Garage: one grid -- three captions on one line, three columns that start and end together;
   NUMBERS in sections (STATS, WEAPONS, ABILITIES, ROLE, PERKS, SETS) at body size in full ink.

## Acceptance criteria
- [ ] A tool run leaves `user://profile.json` and `user://run.json` byte-identical.
- [ ] verify_run: a run board is `board.cols` wider and `board.rows` deeper than its template; every
  objective cell, start and terrain piece is on the board and on an open hex.
- [ ] Screenshots: a run fight on the bigger board with names over the crew; the refinery with
  cards; the garage (columns aligned, nothing clipped, NUMBERS readable).
- [ ] All suites pass; run bot 150, 0 illegal; by Act 3 fewer rares in the crew than at 031
  (the bot's mean crew rarity at the last gate, new in its report).

## Result

## Decisions, lessons, open questions

## Next
