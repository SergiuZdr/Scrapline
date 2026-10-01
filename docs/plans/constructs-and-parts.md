# Plan — Constructs and parts

**Status:** implemented in 003 (2026-09-24). Every part has a `grid` block; a construct is
built from its five parts' blocks plus its chassis role's trait (`data/combat/rules.json`).
Salvage and the cargo hold are 004; content growth is 005. **011 (2026-09-26) built tuning,
makers and sets, and perks** (below).

## The crew

- A run is played with **exactly 3 constructs**, always (decided 2026-09-24). You pick a
  starting crew from the crews you have unlocked.
- A destroyed construct leaves a **chassis wreck**. A workshop rebuilds it for scrap with
  empty sockets; the parts it carried are lost.
- Each construct has **5 sockets**: `chassis`, `arm_l`, `arm_r`, `core`, `module`.
  These are the same keys the existing art pipeline and loadout screen already use.

## What each slot does

| Slot | Grants | Existing data it maps from |
|---|---|---|
| Chassis | HP, armour type, move range, **role trait** | `hp`, `armor_type`, `move_speed`, `role` |
| Arm (×2) | one weapon action each: shape, damage, heat cost (never below 0 an attack) | `weapon_class`, `ability` |
| Core | damage type of both arms, max heat, vent amount | `damage_type`, `heat_max`, `vent_rate` |
| Module | one utility action OR passive | `mo_*` (governor, coolant, servo, scavenger…) |

### Role traits (chassis passives)

| Role | Trait |
|---|---|
| brawler | +1 melee damage (built) |
| line | can move after attacking (built) |
| marksman | +1 range on line and lob weapons (built) |
| anchor | cannot be shoved (built) |

## Salvage: how the crew changes during a run

- **After a fight** you choose 1 of 3 parts (more for a clean win). An elite adds a
  guaranteed rare part.
- **During a fight**, torn-off parts and wrecks drop salvage on the board. A construct can
  spend its action to **pick up** a part it is standing on or next to. A part can be
  **fitted mid-fight** only at a salvage point (scrap heap). Otherwise it goes to the cargo
  hold.
- **Cargo hold** holds 4 spare parts (open question). Refitting is free between fights.
- **Workshop nodes** repair damaged parts and rebuild wrecks for scrap.

## Part rarity and upgrades

- Rarity: common, uncommon, rare (prototype is not built).
- **No levels. A part is tuned once, at a workshop, one of two ways** (built in 011). Every
  part carries its two options in its JSON (`"tuning": [{ "name", "grid" }, ...]`, numbers
  added to the part's grid, flags set). The breaker hammer is *Sledge Head* (+1 damage) or
  *Cold Striker* (-1 heat); a frame is usually more HP or a faster ability; a core, more
  damage for more heat or more venting. Tuning costs 6 / 10 / 14 scrap by rarity. A tuned
  part is its own content entry, `ar_hammer:a`, named "Breaker Hammer+", built by
  `PartTuning.expand` when the content loads, so every lookup that works on a part works on a
  tuned one; loot pools and the assembly bench skip them, and the model, livery and picture
  are the base part's. An elite's guaranteed part comes already tuned.
- **Synergies** come from combinations (a thermal core with a mortar, a scanner with a
  railgun, a bypass on anything) **and, since 011, from makers** (below): the plan said
  "rather than set bonuses", but with 40 parts and no sets, salvage had nothing to pull a
  crew toward, so a pick was a rarity comparison. A set is a reason to take a common part.

## Makers and sets (011)

Every part has a `maker` (`data/parts/makers.json`). Two parts from one maker on a machine
give the 2-piece bonus, three give the 3-piece one as well (duplicates count; five sockets
can hold two sets). **Player machines only**: enemy loadouts are rolled slot by slot, so a
set on one would be an accident, not a design; authored elites and bosses can wear real ones.

| Maker | Makes | 2 pieces | 3 pieces |
|---|---|---|---|
| Kessler Mining | Brute, Dredge, Citadel; Slug, Mag, Bile; hammer, maul; ablative, reactive | +2 HP | +1 armour |
| Arclight Electric | Skirmisher, Bulwark; Arc, Tesla, Null; pulse emitter; governor, coolant, capacitor | vents 1 more | abilities ready a round sooner |
| Vektor Ballistics | Courier, Strider, Lancer; Dynamo; scanner, lance, railgun, scattergun; targeting, servo | +1 move | +1 range |
| Cinder Foundry | Hauler, Reaper; Furnace, Ember, Solvent; ripper, saw, mortar; bypass, overclock, scavenger | +2 heat cap | +1 damage |

Every maker has a common in most slots, so a set can be built on the assembly bench from
the first minute. `CombatSetup.sets_of` is the one place a set is counted; the fight applies
it and the garage, bay and part cards show it ("MAKES KESSLER x3 ON BRUTE").

## Perks (011)

A level-up (garage, scrap) adds its HP and offers **three perks**; the machine keeps one for
the run (`data/run/perks.json`). The offer is seeded by the run, the machine and the level,
never repeats a perk it has, and only holds ones that do something for the machine as built
(no Arc Relay without an arcing weapon, no Combat Reflexes on a frame that already moves
after attacking). Twelve perks: Reinforced Frame (+3 HP), Extra Plating (+1 armour), Uprated
Servos (+1 move), Hot Loads (+1 damage, +1 heat), Heavy Hands (+1 melee), Long Barrels (+1
range), Heat Sinks (+3 heat cap), Coolant Jacket (+1 vent), Quick Cycle (abilities a round
sooner), Arc Relay (+1 chain jump), Ground Spikes (cannot be shoved), Combat Reflexes (moves
after attacking).

**One way numbers reach a machine**: tunings are merged into the part's grid; sets, levels
and perks are additive blocks applied by `CombatSetup.apply_bonus`, so a number means the
same thing wherever it came from, and `RunSim.max_hp` reads the unit the fight would build.

## Content targets

| Launch | Chassis | Arms | Cores | Modules |
|---|---|---|---|---|
| Existing (retune) | 10 | 10 | 10 | 10 |
| Launch target | 12 | 25 | 12 | 20 |

Most of the variety comes from arms and modules, the slots that grant actions.

## Data

Parts stay in `data/parts/*.json`. Add fields for the grid game (`move`, `grid_hp`,
`shape`, `range`, `damage`, `heat`, `tuning`) and remove fields for the continuous sim
(`speed` ticks, `range_bonus` in cm) once 003 lands.

## New families and legendaries (029)

Shapes now: melee, shot, lob, **cone** (flamer: the aimed neighbour and three beyond), **shield**
(aimed at an ally). A shot may **pull** (harpoon). Rarity 4 is LEGENDARY: from a gate's hoard and,
rarely, Act 3 salvage. A part with `"model"` borrows that part's model and picture until it has its
own (`PartTuning.model_of`); `"enemy": false` keeps a part off enemies.
