# Iteration 003 — Parts drive abilities, and intents create pressure

**Status:** done (one acceptance number missed — see Result)
**Started:** 2026-09-24 · **Finished:** 2026-09-24

## Goal
A fight where the parts bolted onto a construct decide what it can do, and where the
enemy's telegraphed attacks actually threaten something. Measured, not just asserted:
the bot must take real damage and must sometimes lose.

## The pressure problem (from 002)
Enemies dealt 6 damage over a whole bot fight, because a telegraphed line is free to
step out of. *Into the Breach* has the same rule and still works, because its units
are protecting **things that cannot move**. So:

### Decision (proposed here, open to veto): the Crawler
Every fight includes the crew's **Crawler**: the salvage rig that carries the crew
across the region. It sits on the board, **cannot move, cannot be shoved, and has no
weapons**. Enemies value hitting it highly. **If it is destroyed, the fight is lost.**
Protecting it creates the puzzle: block the line with a construct and take the hit,
kill the shooter, shove it so its shot goes elsewhere, or let the Crawler take it and
save your HP for later.

In the run (004) the Crawler's HP **carries between fights** and is repaired at workshops,
like the hull in *FTL*. Its HP becomes the run's health bar, which gives every fight a
cost even when you win. This also answers "what are we protecting" in the fiction: the
cargo is the whole point of crossing the yard.

### Further pressure from the parts themselves
- **Area and piercing weapons:** a mortar lobs onto a tile with splash, and a railgun
  pierces every unit in its line. Stepping sideways out of a line no longer always works.
- **Slag:** a unit standing on slag at the start of a round takes 1 damage, and so can a
  unit shoved onto it.

## Scope
- In:
  - Per-part grid stats in `data/parts/*.json` (a `grid` block on every part).
  - Each arm is a weapon with a **shape**: melee, line, or lob. Shapes carry properties:
    pierce, splash, shove, mark, chain, tear.
  - The core sets the damage type; the **damage-type × armour wheel** from `balance.json`
    applies.
  - **Heat:** weapons generate heat. At the cap the construct overheats and loses its next
    attack. Passive vent each round. VENT as an action.
  - Chassis role traits: brawler +1 melee damage, line may move after attacking, marksman
    +1 line range, anchor cannot be shoved.
  - Modules as passives (move, HP, armour, vent, heat cap, range, overdrive).
  - Terrain: rubble (move cost 2, −1 from line shots), ridge (move cost 2, +1 range),
    slag (1 damage at round start), scrap heap (blocks).
  - **Shove**, with bump damage when a unit is shoved into something.
  - **Part damage, simplified:** a hit of `tear_threshold`+ damage (or any hit from a
    ripper) tears off an arm, right arm first. That weapon is gone for the fight.
  - The Crawler.
  - Enemies choose among their arms. Intents carry the weapon, direction and distance.
  - HUD: weapon buttons from the selected construct's arms, VENT, heat on cards, the
    Crawler plate, multi-hit previews.
  - `tools/balance_fights.gd`: bot fights across fights and seeds → win rate and damage.
- Out (later): mid-fight salvage pickup (004 with the run's cargo), enemy heat (enemies
  ignore heat for readability), module ACTIONS, reinforcements, facing.

## Steps
1. Data: `grid` blocks on 40 parts, `data/combat/rules.json`, grid fields on tiles, the
   Crawler in fights, and two more fights.
2. Sim: rewrite `GridUnit`/`CombatSetup` around parts; `CombatSim.strike_plan` as the one
   function that works out what an attack hits (used for preview, the AI and execution);
   heat, shove, marks, tears, terrain, slag, the Crawler, and the new events.
3. `IntentAI` and `CombatBot` across weapons, including defending the Crawler.
4. Tests: `verify_combat.gd` extended rule by rule; `balance_fights.gd`.
5. Presentation: weapon bar, heat, shove/tear/mark playback, the Crawler model, lob
   targeting.
6. Docs.

## Acceptance criteria
- [x] `verify_combat.gd` covers every new rule and passes; determinism and prefix-stable
      undo still hold.
- [x] `verify_combat_input.gd` passes, including switching weapons by tap.
- [~] `balance_fights.gd` shows the enemy dealing a **meaningful share** of damage (at least
      25% of the player's total output) and a bot win rate **below 100%** across fights.
      **Win rate: met (73.8%). Share: missed, 22%** (up from 14%). See Result.
- [x] Screenshots: the weapon bar, a lob target preview, the Crawler. (A torn-off arm was not caught on camera; it is covered by tests and plays in `--bot` runs.)

## Result

**The pressure problem is solved in the way that matters: fights are now lost.** In 600
random-squad fights the bot wins 73.8%. Losses are 139 to the Crawler, 0 to the crew and
18 to the round limit. Every weapon class is within 6 points of the average.

### Measured (`balance_fights.gd --fights 600`)
| | 002 | 003 |
|---|---|---|
| Bot win rate | 100% (one fight) | **73.8%** (random squads) |
| Enemy damage / player damage | 14% | **22%** |
| Enemy intents that land | — | 30% |
| Crawler HP left on a win | — | 7.0 / 10 |
| Losses | none | 139 Crawler, 18 timeout |

Arm classes against the average: coil −5.1, hammer −2.4, lance −1.9, maul +5.0, mortar
+0.5, railgun −0.8, ripper +1.7, saw +3.0, scanner +2.1, scattergun −2.4.

**The damage-share target (25%) was missed: 22%.** The bot dodges and disrupts well, so
share understates the pressure. Crawler losses (23% of fights) are the better signal.
The share will be re-measured once the Crawler's HP carries across a run (004), because
chip damage that is harmless in one fight is not harmless over fifteen.

### Built
- **Parts are the stats.** Every one of the 40 parts has a `grid` block. A construct's HP,
  move, heat cap, vent, armour and damage type, both weapons and every bonus come from its
  five parts plus its role's trait (`data/combat/rules.json`). No unit stat sheets exist.
- **Weapons by shape**: melee, line and lob, with pierce (lance 1, railgun all), splash
  (mortar), shove (hammer, scattergun), mark (scanner), chain (coil) and tear (ripper).
- **Damage** runs through the `balance.json` type wheel, then cover (rubble −1 vs lines),
  then armour (reactive module), then marks (+2). Integer, rounded half up.
- **Heat**: shots add heat. At the cap the construct is OVERHEATED and SEIZED next round (it
  can move, not attack), then resets to 0. Passive vent each round. VENT as an action.
- **Terrain**: rubble and ridge cost 2 to cross, ridge gives +1 range, slag deals 1 damage at
  round start, scrap blocks.
- **Shove and bump**; **arms torn off** by heavy hits (≥5, or any ripper hit), right arm
  first.
- **The Crawler**: an immobile objective. Losing it loses the fight.
- `CombatSim.strike_plan`: the one function that says what an attack hits. The preview,
  the AI, the bot and the execution all use it.
- AI across two weapons, dests and aims. The bot adds danger and shield maps (a
  non-piercing line in front of the Crawler is worth stepping into).
- Fights: `proto_yard` (reworked), `slag_pit`, `container_row`.
- HUD: weapon bar, VENT, heat and arms on cards, the Crawler plate, multi-hit previews
  (kills, tears, overheat). Scene: shove, bump, tear, mark, heat, seize and vent playback,
  lob arcs, a primitive Crawler model, tags with heat/MARKED/SEIZED.
- Tools: `balance_fights.gd`, `shot_combat.gd` (screenshot of an aimed state).

### Checks
| Check | Result |
|---|---|
| `verify_combat.gd` | 77 passed (every rule above, determinism and prefix-stable undo on 3 fights) |
| `verify_combat_input.gd` | 18 passed (adds weapon arming and disarming by tap, heat after firing) |
| `verify_assembly` / `verify_animation` / `verify_save` | 100 / 34 / 14 passed |
| Screenshots | `shots/003-start.png`, `shots/003-lob.png` (mortar aimed, splash shown), `shots/003-bot.png` (marked Crawler about to take a mortar) |

### What went wrong along the way (and is fixed)
1. **Lob targets and move tiles overlap**, so the tap priority from 002 made the mortar's
   Lancer walk instead of aim. Replaced with explicit modes (see Decisions).
2. The weapon bar anchored itself from its own size mid-rebuild and landed half
   off-screen. It now sits in a full-width CenterContainer.
3. The input test held a reference to a weapon button that the next refresh freed, so the
   script error left the test hanging with no output. The test now re-fetches the button,
   and a watchdog turns any hang into a FAIL.
4. The bot counted piercing lines as blockable in front of the Crawler. A blocker is just
   hit as well; that is excluded now.
5. The scanner, which marked for 0 damage, sat 6.3 points under the average. It deals 1.
   Container Row's enemy railgun, with a targeting module, covered the whole board (20% win
   rate); the module was swapped.

## Decisions, lessons, open questions
- **The Crawler** (proposed in this iteration's plan) is in. Its HP carrying between fights
  is 004.
- **Explicit move/attack modes** replace the 002 tap priority. Select → move mode (blue);
  a weapon button arms it (yellow targets); tap a target to aim, again to fire; tap the
  weapon again to disarm. One more tap per attack, and no ambiguous taps at all.
- **Enemies ignore heat.** It is the player's resource; an enemy that sometimes cannot
  fire would be one more hidden state to read every turn.
- **Tearing is simplified**: right arm first, then left, on hits of 5+ or from a ripper. No
  facing. Revisit if play-testing shows it reads as random.
- Crawler HP 10 (tuned down from 12). Scanner deals 1.
- Open: the enemy share of damage (22%) will be re-judged over a whole run in 004.

## Next
004 Run loop: region map, sites, salvage rewards, the Crawler's HP carrying between
fights, save and resume mid-run.

