# Iteration 005 — Hex combat core

**Status:** done (user play-test deferred to after 006; see Result)
**Started:** 2026-09-24 · **Finished:** 2026-09-24
**Answers:** play-test 1 — PT1-2 (diagonals), PT1-3 (the Crawler), PT1-4 (death, wrecks),
PT1-5 (lag), and the pressure half of PT1-1.

## Goal
The fight is rebuilt on a hex board with free aim. The Crawler is gone, and pressure comes
from what each fight asks for. A destroyed machine bursts into a scrap pile that either
side can grab. The crew's damage carries through the run. Playback is fast.

## Design
- **Hex board**, pointy-top, maps still authored as rows of glyphs ("odd-r": odd rows sit
  half a hex to the right). 6 neighbours; hex distance.
- **Free aim.** Every weapon targets a hex, not a direction:
  - *melee*: any of the 6 neighbours.
  - *shot*: any hex in range. The shot travels the hex line toward it and hits the first
    unit or scrap heap on the way (the true line of sight). Piercing shots carry on
    through units to their full range.
  - *lob*: any hex from min to max range, over everything, with splash on its neighbours.
- **Intents target a hex.** At the end of the turn the enemy fires from where it stands
  at the hex it chose. Step off the hex and a shot flies on down its line; a blow simply
  misses. Shove a brawler away and its swing hits air.
- **Objectives, not an escort.** Every fight has one, shown on screen from the first turn:
  - *Rout*: destroy every enemy.
  - *Defend*: salvage caches on the board. Survive N rounds (or rout). Every cache still
    standing pays out scrap. Enemies want them.
  - *Salvage*: scrap piles on the board. Collect N before the enemy carries them off (or rout).
- **Scrap piles.** A destroyed machine bursts into a pile on its hex. Piles are walkable.
  Ending a move on one collects it: the player gets its scrap and the machine patches 2 HP;
  an enemy that reaches it carries it off and patches itself. Wrecks no longer block.
- **HP carries through the run.** A machine enters each fight with the HP the last one left
  it. Workshops repair. A machine destroyed in a fight is a wreck at run level (chassis
  kept, rebuilt at a workshop). The run ends when all three are wrecks. The Reclaimer's bite
  hits every machine instead of the Crawler.
- **Faster playback.** One continuous tween along a path instead of a stop per hex; shorter
  waits between events; a death is a burst into a pile, not a slow topple.

## Steps
1. `sim/combat/hex.gd`: offset ↔ cube, neighbours, distance, integer hex lines.
2. Combat sim on hexes with free aim; piles; objectives; the Crawler removed.
3. AI and bot for hex aim, caches and piles.
4. Fights with objectives; the run with HP carried per machine.
5. Tests rewritten for hex; the balance tools re-run.
6. The scene: hex tiles, aiming at hexes, piles, caches, objective plate, fast playback,
   burst death.
7. Docs, then **the user plays it**.

## Acceptance criteria
- [x] `verify_combat.gd` covers hex movement, free aim and line of sight, lobs, piles,
      each objective, and still proves determinism and prefix-stable undo.
- [x] `verify_run.gd` and `run_bot.gd` pass with HP carried and the Crawler gone.
- [x] Input and run-UI tests pass.
- [x] Screenshots: a hex board with an off-axis shot aimed, a defend fight with caches,
      a scrap pile after a kill.
- [ ] The user plays a run and says whether PT1-2, 3, 4 and 5 are fixed. **Deferred: played together with 006**, because 005 alone does not yet touch PT1-1 (the chore) and a play-test now would mostly re-report it.

## Result

### Built
- `sim/combat/hex.gd`: odd-r offset ↔ cube, neighbours, distance, `within`, and an
  **integer** hex line and ray (fixed-point cube lerp with a constant nudge, round-half-up
  integer division that floors negatives correctly). No floats reach the sim.
- The combat sim on hexes: 6-neighbour movement, **free aim** (melee on any neighbour;
  shots at any hex in reach along the true hex line, stopped by the first unit or scrap
  heap, piercing shots as a beam to full reach; lobs over everything with splash), shoves
  along the hex direction.
- **Intents target a hex.** An intent whose hex is out of reach at resolution (the shooter
  was shoved) misses, and the board shows it grey, marked MISSES.
- **The Crawler is gone.** Fight objectives instead (`rout`, `defend` with caches, `salvage`
  with piles), each shown on an objective plate from the first turn.
- **Scrap piles**: destroyed machines burst into walkable piles. Ending a move on one
  collects its scrap (banked by the run) and patches 2 HP; enemies grab them too.
- **HP carries through the run**; workshops patch every machine; wrecks are rebuilt at half
  HP; the front bites every machine (never below 1); a lost objective with the crew alive
  costs the salvage, not the run.
- Generated fights roll an objective (rout 30 / defend 40 / salvage 30), with caches and
  piles placed on free hexes. `CombatSetup` now rejects two things starting on one hex.
- Presentation: hex prisms, hex highlights, pixel-to-hex picking, cache crates, glinting
  pile heaps, a burst death, **moves played as one glide** (≈0.075 s a hex, shorter waits
  everywhere), and a fresh fight that animates from the setup's starting positions.

### Checks
| Check | Result |
|---|---|
| `verify_combat.gd` | **68 passed**: hex geometry, off-axis aim, line of sight, melee on all 6, pierce, lob, wheel, cover, shove/bump, mark, heat, tear, slag, hex intents (dodge, shoved-out-of-reach misses), piles (drop, walkable, collect, enemy grab), all three objectives, 3 bot fights deterministic and prefix-stable |
| `verify_run.gd` | **46 passed**, including **370 generated fights that all build with no errors** |
| `verify_combat_input.gd` / `verify_run_ui.gd` | 18 / 12 passed |
| `balance_fights.gd --fights 150` | bot wins 89.3%; enemy damage share **9%**; crew loses **1.5 HP per fight** |
| `run_bot.gd --runs 60` | **100% wins**, 0 illegal actions, 4.5 fights a run |
| Screenshots | `shots/005-start.png` (hex board, angled intents, objective plate), `005-defend-aim.png` (caches, rail driver aimed off-axis), `005-piles.png` (a pile after a kill, salvage progress) |

### What the numbers say
**005 fixed the board and the readability complaints, and made the game too easy.** With
free aim and tile-targeted intents, stepping off a targeted hex is free again, and only
defend fights have teeth (the authored one is won 20% of the time). This is 006's first
job: enemy types whose attacks cannot simply be sidestepped, and terrain and abilities
that make positioning a real choice.

### What went wrong along the way (and is fixed)
1. A cache and a player machine started on the same hex in `container_row` (two HP tags
   drawn on top of each other). The fight data is fixed, and the setup now rejects any
   overlap, off-board start or start on scrap.
2. A fresh fight built its models from the state AFTER the enemies' opening moves, so
   those moves animated from where the units already were. It now builds them from the
   setup.

## Next
006 Fight depth, then **the user plays 005 + 006 together**.

