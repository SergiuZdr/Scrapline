# Plan — Combat

**Status:** rebuilt on hexes in 005 (2026-09-24) after play-test 1. **Authoritative
description of the rules: `sim/combat/combat_sim.gd` and `docs/iterations/005-hex-core.md`**.
Sections below that still say "square", "line" or "Crawler" are history, kept for their
reasoning; the table in *Weapons* and the sections marked (005) are current.

(009) Play-test 4: **Both leanings** — a hex line along an edge has two equally short
paths; shots and grapples take the clear one (`CombatSim.best_line`), for both teams.
**Piercing shots overshoot** their range by 2 hexes at half damage. **The coil arcs
twice.** **Scrap carriers**: each enemy carries scrap or not (55%, seeded, marked on its
tag); only carriers drop a pile; drones never. **The hive's pad stays put**: set down once,
a drone every 2 rounds with a countdown and a red warning the turn before; standing on it
blocks, killing the hive shuts it. **The board has edges**: a steel curb on the hex
outline, asphalt and a ring of yard beyond it.

(008) Play-test 3: **Charge works after moving** and hits harder the further it runs
(3 + 1 per hex run first, plus the machine's damage bonus). **The coil's arc reaches
terrain**: from the machine or prop it hits, into an enemy, else a fuel drum, else a crate.
**Piles are collected along the whole path** of a move, dash or charge, by both teams.

(007) Play-test 2 fixes: the tiles are drawn **pointy-top** like the maths (they had been
turned 30°, so hexes met at corners and every distance looked one short). **Grapple aims
freely**: any unit 2..range away with a clear line that is not anchored; anchored machines
show ANCHORED. **Focus and Overdrive boost Charge** (any damaging action). A hive's build
site stays marked all turn.

(006) **Terrain acts**: fuel drums (chain explosions), crate walls (breakable), pits
(shove or drag in = gone). **Abilities** from chassis and modules (charge, grapple,
barricade, focus, dash, overdrive, flush, shield, magnet) with cooldowns. **Enemy kinds**:
tracker, bomber, warden, hive. **Previews are dry runs** of the real rules on a copy.

(005) The board is **pointy-top hexes** in odd-r offset. Aim is **free**: melee hits any of
the 6 neighbours; shots target any hex in reach and travel the hex line, stopping at the
first unit or scrap heap (piercing shots continue to full reach); lobs land on their hex
over everything, splashing the 6 around it. **Intents target a hex.** Every fight has an
**objective** (rout / defend caches / salvage piles). Destroyed machines become **scrap
piles**. The Crawler is gone.

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

### As of play-test 5 (014)

- **Pierce N** passes through the first N things in its line -- machines, drums and crates
  alike (a drum it passes goes off) -- and hits the one after; then it flies 2 hexes past its
  range at half damage (009). Scrap heaps still stop it.
- **Chain N** (the coil; 2 since 009): from the first thing hit, the arc makes N jumps, each to
  a hex next to the last, 1 weaker than the hit. It takes the **route that does the most**:
  every route is tried, an enemy counting the damage it takes, a drum the blast on the enemies
  around it, a crate a little; it never jumps into its own side, and it stops rather than
  waste a jump. **Scrap heaps conduct**: an arc runs through a heap to what stands beyond it,
  without spending a jump. (`CombatSim._arc` / `_arc_search`.)
- **A shove that kills throws the wreck** one hex along the shove: into anything solid it
  stops and the thing it hits takes the bump (a machine 1, a crate cracks, a drum goes off);
  into a pit it falls with its scrap; onto open ground it lands, and its pile with it.
  (`CombatSim.throw_wreck`, event `WRECK_THROWN`.)
- **Paths**: of two routes that cost the same, the one that **picks up the most scrap** wins
  (015: every pile on a route is taken, and machines walked round piles as often as over
  them), then the one with fewer hexes, so a machine walks through rubble when going round
  costs no less. Never a detour: the cost and the reach are the cheapest either way. Both
  teams. Hovering a hex in range draws the route; hexes that cost 2 show a fainter hatch.
- **UNDO** returns to the machine whose action it took back; an undone attack is armed again.
- **Shots along hex edges (016)**: a line that runs between two hexes has two equally short
  paths, and a piercing beam splits again past its target. Both are played out in
  `strike_plan` and the better one is fired -- first the one that reaches the aimed hex, then
  the one that does more for the shooter (`_shot_value`: damage and kills on the other side,
  twice that against it on its own side, a drum by its blast, a crate wall as a small cost),
  then the one through fewer obstacles. Both teams, so the preview, the AI and the shot agree.

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

## Play-test 7 (024): what the board promises

- **One total per hex.** `CombatSim.incoming` runs the enemy's volley and the next round's
  start (slag, floods, flues, the Core's pulse) on a copy; the board shows what each hex takes,
  whoever stands in a line's way included. Firing order lives in the info panel only.
- **A shove off the six axes** is exactly between two directions; the one better for the shover
  is taken (a pit, a bump into the other side or a drum, open ground last).
- **A piercing shot is aimed as far as its beam flies** (reach + `pierce_overshoot`): the line
  through the hex aimed at is the beam's whole path, so "the drum behind" is aimable.


## Act 3 (025): the Crucible

- **Furnace flues** (`f`): blow every `flue_every` (2) rounds for 3; hatched red the round before.
- **Conduits**: allies next to one hit 1 harder, shown as red links; the telegraphed totals
  include it, so killing or shoving the conduit visibly lowers them.
- **The Core** (gate): never moves; marks every hex within 2 a round ahead every third round and
  pulses 4 into the crew standing there; its pad builds a drone every 4 rounds.

## Objectives and conditions (028)

Six objectives: ROUT, DEFEND, SALVAGE, and HOLD (a three-hex zone: a round that starts with a crew
machine on it and no enemy scores; three win), HACK (terminals taken by ending a move on them),
SURVIVE (waves on the far row, marked a round ahead). Yard conditions, one at most, never at a gate:
DUST STORM (-1 reach), LIVE WIRES (cable hexes, 2 a round), SCRAP RAIN (double piles), HEAT WAVE
(-1 vent). All numbers in `rules.json` `modifiers` and `run.json` `objectives` / `modifiers`.
