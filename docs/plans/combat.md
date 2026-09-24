# Plan — Combat

**Status:** built through 003 (2026-09-24). Everything below is implemented unless marked
*later*. Numbers live in `data/parts/*.json` (`grid`), `data/terrain/tiles.json` (`grid`) and
`data/combat/rules.json`.

> **Pressure (002's open problem) is answered by the Crawler**: an immobile objective the
> enemy targets, which the crew must shield, kill for, or shove for. See MEMORY.

## Design goals

- A fight takes **3–6 minutes** and **5–8 rounds**.
- **Complete information about the next enemy turn**: every enemy telegraphs its action
  and target before you move. The randomness is in what the run offers you, not in whether
  an attack lands.
- Every turn poses a question with more than one good answer: kill the threat, block it,
  shove it, or tank the hit with a part you are willing to lose.

## The board

- **8×8 grid** (decided 2026-09-24, to revisit after play-testing). Square tiles, 4-directional
  movement, 8-directional line of sight for ranged attacks.
- Tiles reuse `data/terrain/tiles.json`, reinterpreted for turns:

| Tile | Grid effect |
|---|---|
| open | none |
| rubble | costs 2 movement; half cover (−25% damage from ranged) |
| scrap heap | blocks movement; full cover; **salvage point** (a unit adjacent to it can spend an action to search it) |
| ridge | +1 range for units standing on it |
| slag | +2 heat at the start of your turn for any unit on it |
| wall / container | blocks movement and line of sight; can be destroyed |

- Maps are **hand-authored templates plus seeded variation** (scatter, hazards,
  spawn points), picked by the node's site type.

## Turn structure

```
Enemy INTENT phase   – every enemy picks and SHOWS its action + target tiles
Player phase         – each construct: 1 MOVE + 1 ACTION, in any order, any unit order
Enemy RESOLVE phase  – enemies execute their shown intents in a displayed order
Environment phase    – hazards tick, reinforcements arrive at marked tiles
```

- Intents are a **direction fired from the attacker** (as built in 002). They hit the
  first unit, wreck or scrap heap in the line at resolve time. Step out and the shot flies
  on; step in and you take it. Shove the attacker and it fires from where it lands.
- **Undo**: anything in the current turn, attacks included (decided in 002). The sim is
  deterministic, so undo replays the fight minus the last action.
- **Execution order is shown** as a number on each enemy intent.

## Actions come from parts

A construct has no fixed moveset. Each part grants something (details in
[constructs-and-parts.md](constructs-and-parts.md)):

- **Chassis** gives HP, armour type, movement, and a passive trait based on its role.
- **Each arm** gives one weapon action. Its `weapon_class` decides the attack's shape.
- **Core** gives the damage type of every arm on this construct, plus the heat capacity.
- **Module** gives one utility action or passive.

Weapon shapes (first pass, mapped onto existing `weapon_class`):

As built (003), per `weapon_class`:

| Class | Shape | Damage | Special | Heat |
|---|---|---|---|---|
| hammer | melee | 3 | shove 1 | 1 |
| maul | melee | 5 | (tears by threshold) | 2 |
| saw | melee | 4 | | 1 |
| ripper | melee | 3 | **tears** an arm on any hit | 1 |
| lance | line 3 | 3 | pierce 1 | 1 |
| railgun | line 6 | 3 | pierce all (stopped by scrap) | 2 |
| scattergun | line 2 | 3 | shove 1 | 1 |
| mortar | lob 2–4 | 3 | splash 1 to the 4 neighbours, flies over blockers | 2 |
| scanner | line 5 | 1 | **mark**: next hit on the target +2 | 0 |
| coil | line 3 | 2 | chains to one neighbour of the first hit for 1 less | 1 |

Lines stop at the first unit (unless piercing), wreck or scrap heap. Cones were dropped:
a scattergun is a short shoving line, which reads the same at a fraction of the rules.

## Heat: the resource

- Each shot adds the weapon's heat plus core/module heat bonuses.
- Reaching the **heat cap** (chassis + module) marks the construct OVERHEATED. Next round
  it is **SEIZED**: it can move but not attack, and its heat resets to 0.
- Otherwise heat drops by the construct's **vent** (core + module) at each round start.
- **VENT** as the construct's action sets heat to 0.
- Enemies have no heat.
- *Later:* thermal damage burning the target's heat.

This carries the old sim's heat identity over into a turn economy. You always have the
option to push harder, and it always costs something.

## Damage

- Integer damage. **No hit rolls. Damage variance is 0 for the player** (determinism
  and readability). Enemies may have a small seeded variance that is shown as a range
  (e.g. 4–5).
- **Damage-type × armour-type wheel** carried over from `data/balance.json`
  (kinetic, thermal, emp, corrosive × plate, composite, reactive, shielded).
  The multiplier is **shown on the target preview** before you commit.
- HP scale drops from the hundreds to single and double digits (e.g. Brute 14 HP,
  hammer 4 damage). On a grid, small numbers are easier to read and plan around.

## Part damage (signature mechanic — test in Iteration 003)

- As built (003): a primary hit of **5+ damage** (after the wheel), or **any ripper hit**,
  **tears off an arm**: the right arm first, then the left. Its weapon is gone for the fight.
  The preview says "TEARS AN ARM OFF" before you commit.
- *Later (004+):* the torn arm drops as salvage on the tile. The damaged-part middle state
  and facing were cut for readability.
- A construct whose chassis HP reaches 0 becomes a **wreck**: it blocks its tile and can
  be searched for parts.

**Risk:** too many moving pieces for a phone screen. **Kill criterion:** if play-testing
in 003 shows players ignoring part damage or finding it confusing, cut it back to
"a torn-off arm on heavy hits only".

## Win and lose

- **Win**: destroy all enemies, **or** survive N rounds on "hold out" maps, **or** extract
  from a marked zone on "salvage run" maps. Objective variety keeps fights from all
  playing the same.
- **Lose the fight**: all constructs destroyed. That ends the run.
- **Rewards scale with how cleanly you won**: fewer parts lost and fewer rounds used
  mean more salvage choices.

## Deliverables

- 002: grid, movement, one generic attack per unit, intents, resolve order, win/lose,
  undo. Headless test: a scripted fight produces the same event hash every run.
- 003: part-driven actions, heat, damage wheel, terrain, part damage.
