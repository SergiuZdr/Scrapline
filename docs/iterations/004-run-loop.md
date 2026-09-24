# Iteration 004 — The run loop

**Status:** done
**Started:** 2026-09-24 · **Finished:** 2026-09-24

## Goal
A complete run through Act 1, start to finish. Title → NEW RUN → a region map →
fights, scrapyards and workshops → salvage and refits → the act boss → a win or a lost
run. The Crawler's HP carries between fights, and quitting at any point resumes exactly
where you were, mid-fight included. A bot plays whole runs headlessly.

## Design calls made here (proposed, open to veto)
1. **Constructs are repaired after every fight, and torn arms are bolted back on.** Only
   a *destroyed* construct loses anything: it keeps its chassis as a wreck and its other
   four parts are gone (MEMORY 2026-09-24). A workshop rebuilds the wreck, and you refit
   its sockets from cargo. The run's attrition lives in the Crawler's HP and in wrecks,
   two things the player can see, rather than in per-construct damage bookkeeping.
2. **The Reclaimer front** consumes one column of the region every `front_every` moves.
   You cannot enter a consumed site. **Each move you make while standing in consumed
   ground costs the Crawler `front_damage` HP.** It pushes you onward without an instant
   loss, and it makes lingering a number instead of a rule.
3. **One act** in this iteration. The boss is a hard generated fight; real bosses are 005.
4. **Site types now:** skirmish, elite, scrapyard, workshop, boss. Traders, signals and
   watchtowers come in 007.
5. **Enemy squads are generated** from the parts pool by column and site type, on maps
   taken from the authored fight files. Every run is different; the same seed gives the
   same run.

## Scope
- `sim/run/`: `RunSetup`, `RunState`, `RunSim` (pure, seeded). Region generation, travel,
  the front, site resolution, fight generation, fight results (by **replaying the fight's
  own action log**, so a run is one action list), rewards, workshop, refit, run end.
- `data/run/run.json`: every run number (region shape, site weights, front, rewards,
  prices).
- `CombatSetup`: the Crawler's current HP and empty sockets (a rebuilt wreck).
- A `Run` autoload: holds the live run, applies actions, saves `user://run.json` after
  each one, and resumes. Combat progress is saved per action.
- Screens: the region map (2D), reward and scrapyard pick, workshop, refit, run over. The
  combat scene reads its fight from the run and reports back.
- Title: CONTINUE / NEW RUN / PRACTICE FIGHT / QUIT.
- `tools/verify_run.gd` (generation invariants, rules, determinism, save round trip) and
  `tools/run_bot.gd`, **the test that plays the real game**.

## Acceptance criteria
- [x] `verify_run.gd` passes: every generated region is connected start → boss; the same
      seed gives the same region; each site type resolves; the Crawler's HP carries; a
      destroyed construct becomes a wreck and a workshop rebuilds it; saving and
      reloading mid-run gives an identical state.
- [x] `run_bot.gd` plays at least 100 full runs with no errors and reports win rate,
      where runs end and why.
- [x] The game is playable end to end by tapping: title → run → fights → rewards → refit
      → boss → result. Screenshots of the map, a reward, the refit screen.
- [x] Quit mid-fight, relaunch, CONTINUE: the fight resumes at the same turn.

## Result

**A whole act plays start to finish.** Title → NEW RUN → region map → fights, scrapyards,
workshops → salvage and refits → the boss → ACT 1 CLEARED or RUN OVER. Quit anywhere,
mid-fight included, and CONTINUE puts you back on the same turn.

### Built
- `sim/run/`: `RunSetup`, `RunState`, `RunSim`, `RunBot`. Pure and seeded. **A fight's result
  is derived by replaying its own action log**, so a whole run is one list of actions: that
  list is the save file, and the run cannot be told it won a fight it did not win.
- Region generation: 7 columns, 2–3 sites each, forward links plus sideways links (a region,
  not a tree), fog, a guaranteed workshop, fights and scrapyards only in the first column.
- The Reclaimer front (one column per 2 moves; 3 Crawler HP per move made from consumed
  ground). The Crawler's HP carries between fights. Wrecks, rebuilds, repairs.
- Generated enemy squads by column and site type (rarity caps, elite extras, boss).
  Salvage weighted by rarity, with an elite guaranteeing an uncommon or better.
- `data/run/run.json`: every run number.
- `CombatSetup`: the Crawler's current HP, and empty sockets (a rebuilt wreck).
- `Run` autoload and `RunStore` (atomic JSON save of seed + content hash + actions + the
  in-progress fight's actions; ints restored after JSON).
- Screens: region map, fight / salvage / scrapyard / workshop / refit / run-over panels,
  and a title with CONTINUE, NEW RUN and PRACTICE FIGHT. The combat scene reads from and
  reports to the run.
- `PartText`: one description of a part for every screen.
- Tools: `verify_run.gd`, `verify_run_ui.gd`, `run_bot.gd`, `shot_run.gd`.

### Measured (`run_bot.gd --runs 150`)
| | |
|---|---|
| Bot win rate (Act 1) | **36.7%** |
| Fights won per run | 3.2 |
| Moves per run | 5.1 |
| Reached the boss | 81 / 150, Crawler going in at 11.8 / 16 |
| Losses | 63 Crawler destroyed, 32 crew wiped |
| Losses by column | 1: 6, 2: 7, 3: 10, 4: 19, 5: 27, 6: 26 |

The difficulty rises through the act instead of walling at one point. The bot has no undo,
takes no care over refits beyond rarity, and never lingers, so a person should do clearly
better. That is the next thing to check by playing.

### Checks
| Check | Result |
|---|---|
| `verify_run.gd` | 42 passed: 200 regions connected with one boss and a workshop each; seeded generation; travel and the front; every site type; the Crawler's HP in and out of a fight; wreck → rebuild → empty sockets that still build; refit rules; replay determinism; JSON save round trip, full and halfway |
| `verify_run_ui.gd` | 12 passed: map tap → travel → saved; ENTER FIGHT → run-mode combat with the run's Crawler HP; combat actions saved as they happen; CONTINUE resumes the same fight; CONTINUE after the fight reports it back; salvage card → hold; refit socket → hold card swaps |
| `run_bot.gd` | 150 runs, **0 illegal actions** |
| `verify_combat` / `verify_combat_input` | 77 / 18 passed |
| `verify_assembly` / `verify_animation` / `verify_save` | 100 / 34 / 14 passed |
| Screenshots | `shots/004-title.png`, `004-map.png` (start), `004-map-mid.png` (front advancing), `004-reward-3.png` (salvage), `004-refit.png`, `004-reward.png` (actually ACT 1 CLEARED: seed 7's bot run went straight through) |

### What went wrong along the way (and is fixed)
1. The first bot preferred scrapyards to fights, giving runs of about one fight. It now
   prefers fights, and runs average 3.2.
2. The map labelled scrapyards "SALVAGE", the same word as the post-fight salvage panel.
   They are "SCRAPYARD" now.
3. The boss with 5 enemies was a wall (12 of 25 losses in one 40-run sample). It has 4.
4. zsh does not word-split an unquoted `$var`, so screenshot arguments arrived as one
   string and were ignored. Use `${=var}`.

## Decisions, lessons, open questions
- The design calls at the top of this file are in (repair between fights, torn arms
  restored, wrecks lose all but the chassis, front damage per move, one act, generated
  squads). All are open to the user's veto.
- Gold now marks rare salvage (it was reserved for premium currency, which no longer exists).
- `verify_run_ui.gd` presses buttons by emitting `pressed` rather than clicking. Board
  picking by real clicks stays covered by `verify_combat_input.gd`.
- Open: is 3.2 fights an act the right length? The plan said 4–5. The front (every 2 moves)
  is the dial.

## Next
005 Act 1 content: a real boss (multi-part, the old Colossus design), an enemy roster with
identity instead of random parts, more parts (target 25 arms), events. **Before that, the
user should play a run**: the whole loop exists now, and the bot cannot say whether it is
fun.

