# Plan — Combat

**Status:** 002 prototype built (2026-09-24): board, move, one attack per unit, direction-based intents, wrecks, win/lose, replay undo. Parts, heat, wheel, terrain effects, part damage and shove are 003.

> **Open problem from 002:** dodging a telegraphed line costs nothing, so enemies barely
> land hits (6 damage over a whole bot fight). The fix belongs in 003; see MEMORY.

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

| Shape | Classes | Pattern |
|---|---|---|
| Melee strike | hammer, maul, saw, ripper | adjacent tile; hammer and maul **shove** the target 1 tile |
| Line | lance, railgun | straight line; railgun pierces through units |
| Arc / lob | mortar | any tile at range 2–4, ignores cover, splashes adjacent tiles |
| Cone | scattergun | 3-tile cone, damage drops with distance, shoves |
| Utility | scanner, coil | scanner **marks** (next hit +50%); coil hits in a chain |

## Heat: the resource

- Each weapon action generates heat (defined per part in data).
- At **max heat** the construct **seizes**: it skips its next action and vents to 50%.
- **Vent** (a free action once per turn instead of attacking) removes a large chunk.
- Slag, thermal damage and some modules add heat. Thermal cores trade raw damage
  for burning the target's heat meter.

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

- Hits land on the **chassis HP pool**, but **a hit of 4 or more damage also damages a
  part**: an arm facing the attacker, or the module on a hit from behind. Facing
  matters, so it is shown on the unit.
- A damaged part works at reduced strength. A part damaged twice is **torn off** and
  drops on the tile as salvage.
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
