# Iteration 002 — Grid fight prototype

**Status:** done
**Started:** 2026-09-24 · **Finished:** 2026-09-24

## Goal
One complete, playable, turn-based fight on an 8×8 grid: 3 player constructs against
enemies that telegraph their attacks. It plays with mouse or touch alone, the sim is pure
and deterministic, and a headless test proves it.

## Scope
- In:
  - Pure sim in `sim/combat/`: board, units, move, attack, enemy intents, resolve order,
    wrecks, win/lose, replay-based undo, and an event stream.
  - Enemy AI (`IntentAI`), also used as a bot for the player side in tests.
  - Board scene in 3D (tiles, the existing construct models, sodium/cold light rig,
    fixed tilted camera with 90° rotate and zoom).
  - HUD: crew cards, info/preview panel, round banner, UNDO, END TURN, win/lose overlay.
  - Title screen → FIGHT (prototype) button.
- Out (deliberately, 003+):
  - Per-part actions, heat, damage-type wheel, terrain effects beyond blocking, part
    damage and salvage, shove. For now each unit gets **one attack**, chosen by its right
    arm's weapon class (melee or ranged line); HP and move come from the chassis role.

## Rules implemented (prototype)
- 4-directional movement by BFS. Units may pass through allies but never through enemies,
  wrecks or scrap heaps.
- Per turn each construct gets **1 move, then 1 attack**. It cannot move after attacking.
- Attacks fire in one of 4 directions. Melee reaches 1 tile. Ranged is a line up to range
  that **stops at the first unit, wreck or scrap heap**, friend or foe.
- Enemies move during their planning phase, then **commit a direction**. At the end of
  the player's turn each intent fires from where the attacker stands, in that direction,
  in the displayed order. Step into the line and you take the hit; step out and the shot
  flies on to whatever is behind you, including another enemy.
- A destroyed construct becomes a wreck that blocks its tile.
- **Undo** anything done this turn. Undo replays the fight from the start with one fewer
  action; the sim is deterministic, so this is exact.
- Win when all enemies are destroyed. Lose when all constructs are destroyed or
  `max_rounds` passes.

## Steps
1. `data/combat/prototype.json` (role and weapon stats, max rounds) and
   `data/fights/proto_yard.json` (the map and both squads). Mark scrap heaps as `blocks`.
2. `sim/combat/`: `GridEv`, `GridUnit`, `CombatSetup`, `CombatState`, `CombatSim`, `IntentAI`.
3. `tools/verify_combat.gd`: rules, determinism and a bot-played fight.
4. `ConstructView.build_parts` (build from part ids without a `SimUnit`).
5. `scenes/combat.tscn` + `scripts/combat/combat_scene.gd` (+ HUD). `--bot` flag plays
   the player side automatically, for screenshots and demos.
6. Title → FIGHT button.

## Acceptance criteria
- [x] `verify_combat.gd` passes: rule checks, same event hash on 3 replays, undo equals
      replay of the prefix, and a bot-vs-AI fight finishes inside `max_rounds`.
- [x] Every script passes `--check-only` (except the known autoload false positive, see Result); kept tests still pass.
- [x] Screenshot of the fight at the start of a player turn shows the board, three
      player machines, enemies with intent markers, and the HUD.
- [x] Screenshot of a `--bot` fight mid-way shows damage and wrecks.
- [x] Every action can be done by tapping or clicking only (proved by `verify_combat_input.gd`, not just by screenshots).

## Result

**Playable.** Title → FIGHT → an 8×8 fight: 3 constructs against 4 enemies, with
telegraphed intents, undo, win/lose and FIGHT AGAIN. Everything the plan listed is in.

### Built
- `sim/combat/`: `GridEv`, `GridUnit`, `CombatSetup`, `CombatState`, `CombatSim`,
  `IntentAI`, `CombatBot`. Pure, integer-only, with fixed iteration order and a murmur3
  finalizer as the tie-break hash.
- `data/combat/prototype.json` (role HP and move, weapon groups), `data/fights/proto_yard.json`,
  and `blocks` added to `data/terrain/tiles.json` (true only for scrap heaps).
- `ContentDB` loads `combat_rules` and `fights/`, and both feed `content_version()`.
- `ConstructView.build_parts(part_ids, …)`. `build(SimUnit, …)` is kept as a wrapper for
  the rig tests.
- `scenes/combat.tscn`: `combat_scene.gd` (board, light rig, 90° camera turns and zoom,
  event playback with the existing rig and VFX, input) and `combat_hud.gd` (crew cards,
  info/preview panel, banner, UNDO, END TURN, result overlay).
- `tools/verify_combat.gd` (41 checks) and `tools/verify_combat_input.gd` (13 checks).

### Checks
| Check | Result |
|---|---|
| `verify_combat.gd` | 41 passed, 0 failed. Bot fight: WON in 5 rounds, 3/3 standing, 30 actions, 140 events, hash `a5541681`; same hash on 3 replays and on a fresh content load; every tested prefix matches |
| `verify_combat_input.gd` | 13 passed, 0 failed: select by tap, move by tap, UNDO button, melee step-beside, two-tap attack, ally select, SPACE ends the turn |
| `verify_assembly` / `verify_animation` / `verify_save` | 100 / 34 / 14 passed |
| `--check-only` on all scripts | clean except `combat_scene.gd` "Identifier not found: Audio". That is a false positive, because check-only compiles without autoloads; the scene runs |
| Screenshots | `shots/002-start.png` (turn 1: HUD, move/attack highlights, Lancer's intent line onto the Strider), `shots/002-bot.png` (round 3, grey wreck rings), `shots/002-end.png` (YARD CLEARED overlay) |

### What went wrong along the way (and is fixed)
1. HUD anchors set before `add_child` computed against a zero-size parent, which put the
   banner off the top-left corner. Now every node is anchored after it enters the tree.
2. The tap priority let attack lines beat moves: a melee unit could not step beside
   itself, and tapping an ally in a line of fire aimed at it. The order is now select →
   move → aim → fire.
3. The first input test sent window coordinates and every click missed. Two checks passed
   vacuously because nothing had moved. Fixed with `push_input(event, true)`.
4. Rotation glyphs (⟲ ⟳) do not exist in the bundled fonts; the buttons are text now.
5. Wrecks were near-invisible. They keep a grey ring now, because a wreck blocks its tile.

## Decisions, lessons, open questions
- **Undo covers anything in the current turn, attacks included**, not only moves (the
  combat plan said moves). Damage has no randomness, so undoing an attack reveals
  nothing, and it forgives misclicks on a phone.
- **Attacks take two taps** (aim, then confirm); moves take one. A move is cheap to undo,
  and an attack is the thing a fat finger should not do by accident.
- **DESIGN FINDING: dodging is free, so intents create almost no pressure.** Over a full
  bot fight the enemy set 12 intents and dealt **6 damage in total** (the player dealt 42).
  The bot just steps out of every red line. *Into the Breach* works because you are
  protecting things that cannot move. 003 has to add pressure. Candidates: attacks that
  cover areas rather than lines, objectives/salvage you must hold, enemies that punish
  the tile you dodge to, and reinforcements. Tracked in MEMORY as an open question.
- The fallen models are hard to see from the battle camera even with the ring. This
  goes to the feel pass (008).

## Next
003 Parts drive abilities, **with the pressure problem as its first design question**.

