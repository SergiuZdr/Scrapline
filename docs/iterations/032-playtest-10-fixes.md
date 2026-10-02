# Iteration 032 — Play-test 10 fixes

**Status:** done -- waiting for the user to play it
**Started:** 2026-10-02 · **Finished:** 2026-10-02

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
- [x] A tool run leaves `user://profile.json` and `user://run.json` byte-identical.
- [x] verify_run: a run board is `board.cols` wider and `board.rows` deeper than its template; every
  objective cell, start and terrain piece is on the board and on an open hex.
- [x] Screenshots: a run fight on the bigger board with names over the crew; the refinery with
  cards; the garage (columns aligned, nothing clipped, NUMBERS readable).
- [x] All suites pass; run bot 150, 0 illegal; by Act 3 fewer rares in the crew than at 031
  (the bot's mean crew rarity at the last gate, new in its report).

## Result

- **Tools**: under `--script`, `RunStore.path()` is `user://tool_run.json` and the `Profile`
  autoload uses `user://tool_profile.json` (every hint seen). The player's profile was checked
  byte-identical (md5) after every suite and screenshot. The one polluted profile (a bot run banked
  by `shot_run.gd`: runs 4 -> 5, fights 75 -> 85, `u08`) was restored from `profile.backup.json`.
- **Board**: `run.json` `board` {rows 2, cols 2}: run boards are 10 x 10 (templates 8 x 8); terrain,
  wires, piles and terminals in `RunSim.middle_rows`. Barrels 2-4 and crates 1-3 for the space.
  `board.enemies` (per act): Acts 2 and 3 field one more enemy.
- **Names** on your machines' board tags; crew cards: 16 squares of 10 x 8 a row, a card grows by a
  row if needed.
- **Sites**: `_part_grid` -- the refinery and the trader's sell list are part cards with a caption
  (price, or what it costs you); the auction shows its prize as a card.
- **Arena**: `enemies.arena` {extra 2, hp 3, damage 1, cap 3}; its salvage starts at a rare.
- **Rarity**: Act 2 salvage 55/38/7 (was 35/45/20), Act 3 35/48/15/2 (was 10/42/42/6) and its elites
  uncommon+ (were rare+); refinery 15/35/70 (10/18/40), auction 25/55 at 4%/12% legendary (20/45,
  8%/25%), both weight 4 (7/6); a warlord's hoard a rare, legendary 35% (always legendary).
- **Garage**: three captions on one line, three columns from y 146 to 690, the hold under them;
  NUMBERS in sections (STATS, WEAPONS, ABILITIES, ROLE, PERKS, SETS) at 18-22 px in full ink.
- Suites: combat 276, run 175 (+5), meta 59, save 15, assembly 140, combat_input 22, run_ui 49,
  onboarding 39. Screenshots `shots/032/` (garage_after, fight, refinery).
- **Run bot** (150): the bigger board alone 67.3% (it gave the crew room); +1 enemy everywhere
  54.7% with Act 1 at 19.3% lost; **final, +1 enemy in Acts 2-3: 60.0%**, lost by act 11.3 / 12.0 /
  23.1%, 0 illegal. **Rare+ parts fitted at the last gate: 5.5 of 15** (031, measured the same way
  over 30 runs: 6.8; 032's first rarity cut alone: 6.7).

## Decisions, lessons, open questions
- A bigger board makes the game EASIER for the crew (more turns to shoot before contact): it needed
  more enemies to stay where it was. Put them where the game was too easy (Acts 2-3), not Act 1.
- Lesson: a tool that drives the real `Run` autoload writes the player's save and profile. Tools
  get their own files by construction (`--script`), not by each tool remembering to.
- Lesson: the first rarity cut moved the bot's late crews from 6.8 to 6.7 rare parts -- the rarity
  of what is offered is not what ends up fitted. Measure the outcome (now in the bot report).
- Open: is the 10 x 10 board right, or too big on a phone? Do defend fights now feel fair?

## Next
033: the parts audit and new modules.
