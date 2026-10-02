# Parts: the power audit (033)

Play-test 10: "take all the parts and analyse how the power spike goes for each category and
between categories; there is too little variety, modules above all."

## How it was measured

**A points model** (`tools/part_points.py`): every number a part carries, priced in
HP-equivalents per fight -- what one point of each stat is worth over a typical fight of about four
attacks, three hits taken and a few hexes walked (+1 damage on every attack = 4, +1 armour = 3,
+1 move = 3, +1 range = 2.5, an ability 1-3...). The weights are written at the top of the script.
It shows the SHAPE: how much each rarity adds, and which parts sit off their rarity's line.

**A measurement** (`tools/part_power.gd`): paired bot fights -- the same board, enemies and seed
played with a reference crew of commons, and again with the part under test on the first machine.
**It did not separate parts**: the bot won all 40 trials with every part against five tougher
enemies, so the win column is 0 throughout, and the HP-per-fight differences (within +-1.4) are
mostly noise (the Colossus, +7 HP, measures -0.05: HP the crew keeps does not show in a fight it
wins anyway). Its loudest signals agree with the model -- the Flamer and Shield Caster below every
common arm, the Lance and Coilgun on top -- and those were acted on. Losses in the game come from
damage carried between fights, which a single fight cannot see; the run bot measures that.

## What it found (031 roster)

Mean points by rarity:

| Slot | Common | Uncommon | Rare | Legendary | Rare over common |
|---|---|---|---|---|---|
| Chassis | 11.6 | 13.5 | 16.8 | 23.0 | +5.2 |
| Arm | 6.8 | 7.5 | 10.4 | 15.1 | +3.6 |
| Core | 2.5 | 3.7 | **4.0** | 11.0 | **+1.5** |
| Module | 3.0 | 4.9 | **5.0** | 10.0 | **+2.0** |

- **Between categories**: a rare chassis or arm is a real upgrade; a rare core or module barely is.
  Chassis carry most of a machine's power (HP), so swapping a frame is the biggest decision and
  cores the smallest.
- **Cores were flat**: the rare Tesla and Mag Cores had exactly the common Furnace Core's numbers
  (+1 damage, +1 heat, vent 1); four cores of two rarities were the same "vent 2". Rarity bought a
  damage type and nothing else.
- **Modules were stat sticks** (thirteen, all plain numbers but the abilities), and the rare
  **Targeting Suite (+1 range) was the weakest module in the game** (2.5): worse than any common.
- **Two uncommon arms sat below every common**: the Flamer (5.2) and the Shield Caster (6.0).
- The Heat Governor (common, +2 heat cap) was worth 1.0. The Aegis Rig's "Fast Cycle" tuning had
  the wrong sign (`cooldown: -1` made its shield SLOWER).
- Within slots the spread is healthy elsewhere; the Brute (common, 15) is a common that plays like
  an uncommon, which is fine for a starter.

## What changed (033)

- **Modules with mechanics**, new rules in the sim: **thorns** (melee attackers take damage),
  **regen** (repairs each round), **kill heal** (HP back per kill), **last stand** (survives its
  first wreck at 1 HP); and **traits a core or module lends the weapons**: pierce and arcs on shots,
  shove and tears on melee, marks on every hit, plus the role traits (melee damage, cannot be
  shoved, moves after attacking).
- **Twelve new modules** (13 -> 25): Spiked Plating, Heat Fins, Gripping Hooks (common); Repair
  Drone, Gyro Anchor, Belt Feeder, Hydraulic Ram, Sprint Pistons (uncommon); Scrap Leech, Arc Relay,
  Spotter Uplink (rare); Phoenix Cell (legendary).
- **Cores grow with rarity**: Slug +2 HP, Arc abilities a round sooner, Ember +1 melee, Solvent
  tears, Null marks, **Tesla arcs every shot, Mag pierces every shot**.
- Fixed: Targeting Suite +1 range **and +1 damage**; Heat Governor +1 vent; Aegis tuning; the
  Flamer 3 damage (was 2); the Shield Caster range 4 and no heat.

After (mean points by rarity):

| Slot | Common | Uncommon | Rare | Legendary |
|---|---|---|---|---|
| Chassis | 11.6 | 13.5 | 16.8 | 23.0 |
| Arm | 6.8 | 8.2 | 10.4 | 15.1 |
| Core | 3.4 | 4.9 | 7.0 | 11.0 |
| Module | 3.1 | 4.2 | 5.6 | 9.8 |

Every slot now rises with every rarity. Modules still add the least (they are the slot that
changes HOW a machine plays, not how big it is), and the chassis the most.

## Every part


## CHASSIS

| Part | Rarity | Model | Measured HP saved/fight | Measured win |
|---|---|---|---|---|
| Brute Frame | common | 15.0 | +0.00 | +0.0 |
| Hauler Frame | common | 11.5 | -0.35 | +0.0 |
| Courier Frame | common | 10.5 | +0.95 | +0.0 |
| Skirmisher Frame | common | 9.5 | +0.90 | +0.0 |
| Scrapper Frame | uncommon | 16.0 | +0.75 | +0.0 |
| Bulwark Frame | uncommon | 15.0 | +0.03 | +0.0 |
| Dredge Frame | uncommon | 13.0 | -0.72 | +0.0 |
| Strider Frame | uncommon | 12.0 | +0.12 | +0.0 |
| Lancer Frame | uncommon | 11.5 | +0.80 | +0.0 |
| Reaper Frame | rare | 17.0 | +0.75 | +0.0 |
| Citadel Frame | rare | 16.5 | +0.03 | +0.0 |
| Colossus Frame | legendary | 23.0 | -0.05 | +0.0 |

Mean by rarity: common 11.6 (9.5-15.0, 4)  uncommon 13.5 (11.5-16.0, 5)  rare 16.8 (16.5-17.0, 2)  legendary 23.0 (23.0-23.0, 1)

## CORE

| Part | Rarity | Model | Measured HP saved/fight | Measured win |
|---|---|---|---|---|
| Furnace Core | common | 4.0 | +0.07 | +0.0 |
| Slug Core | common | 3.5 | +0.00 | +0.0 |
| Arc Core | common | 3.0 | +0.15 | +0.0 |
| Dynamo Core | common | 3.0 | +0.60 | +0.0 |
| Bile Core | uncommon | 5.5 | +0.05 | +0.0 |
| Null Core | uncommon | 5.5 | -0.47 | +0.0 |
| Ember Core | uncommon | 5.0 | +0.20 | +0.0 |
| Solvent Core | uncommon | 4.5 | +0.70 | +0.0 |
| Flux Core | uncommon | 4.0 | +1.18 | +0.0 |
| Mag Core | rare | 7.0 | +0.93 | +0.0 |
| Tesla Core | rare | 7.0 | +0.17 | +0.0 |
| Crucible Heart | legendary | 11.0 | +0.60 | +0.0 |

Mean by rarity: common 3.4 (3.0-4.0, 4)  uncommon 4.9 (4.0-5.5, 5)  rare 7.0 (7.0-7.0, 2)  legendary 11.0 (11.0-11.0, 1)

## ARM

| Part | Rarity | Model | Measured HP saved/fight | Measured win |
|---|---|---|---|---|
| Pulse Emitter | common | 7.6 | -0.20 | +0.0 |
| Scattergun | common | 7.6 | +0.70 | +0.0 |
| Scrap Cleaver | common | 7.0 | +0.23 | +0.0 |
| Ripper Claw | common | 6.5 | -0.25 | +0.0 |
| Spotter Array | common | 6.4 | -0.10 | +0.0 |
| Hook Harpoon | common | 6.2 | +0.30 | +0.0 |
| Breaker Hammer | common | 6.0 | -0.17 | +0.0 |
| Slag Mortar | uncommon | 10.3 | +0.42 | +0.0 |
| Slag Flamer | uncommon | 8.8 | -0.95 | +0.0 |
| Rail Lance | uncommon | 8.4 | +1.35 | +0.0 |
| Siege Maul | uncommon | 8.0 | +0.45 | +0.0 |
| Rend Saw | uncommon | 7.0 | +0.23 | +0.0 |
| Aegis Caster | uncommon | 7.0 | -0.50 | +0.0 |
| Rail Driver | rare | 11.6 | +0.97 | +0.0 |
| Arc Coilgun | rare | 9.2 | +1.27 | +0.0 |
| Sunspear | legendary | 15.6 | +0.97 | +0.0 |
| Godhammer | legendary | 14.5 | +0.78 | +0.0 |

Mean by rarity: common 6.8 (6.0-7.6, 7)  uncommon 8.2 (7.0-10.3, 6)  rare 10.4 (9.2-11.6, 2)  legendary 15.1 (14.5-15.6, 2)

## MODULE

| Part | Rarity | Model | Measured HP saved/fight | Measured win |
|---|---|---|---|---|
| Hull Plating | common | 4.0 | +0.00 | +0.0 |
| Scavenger Rig | common | 4.0 | +0.15 | +0.0 |
| Spiked Plating | common | 3.5 | +0.15 | +0.0 |
| Ablative Plating | common | 3.0 | +0.00 | +0.0 |
| Heat Fins | common | 2.5 | +0.00 | +0.0 |
| Heat Governor | common | 2.5 | +0.00 | +0.0 |
| Gripping Hooks | common | 2.5 | +0.30 | +0.0 |
| Reactive Slab | uncommon | 6.0 | +0.70 | +0.0 |
| Jump Jets | uncommon | 5.0 | +0.20 | +0.0 |
| Servo Cluster | uncommon | 5.0 | +0.20 | +0.0 |
| Governor Bypass | uncommon | 4.5 | -0.12 | +0.0 |
| Gyro Anchor | uncommon | 4.5 | +0.05 | +0.0 |
| Coolant Loop | uncommon | 4.0 | +0.00 | +0.0 |
| Hydraulic Ram | uncommon | 3.5 | +0.47 | +0.0 |
| Sprint Pistons | uncommon | 3.5 | +0.60 | +0.0 |
| Belt Feeder | uncommon | 3.0 | +0.25 | +0.0 |
| Repair Drone | uncommon | 2.5 | +0.75 | +0.0 |
| Overclock Bank | rare | 7.5 | +0.42 | +0.0 |
| Targeting Rig | rare | 6.5 | +1.12 | +0.0 |
| Surge Capacitor | rare | 5.0 | +0.15 | +0.0 |
| Spotter Uplink | rare | 5.0 | +0.65 | +0.0 |
| Scrap Leech | rare | 4.9 | +0.90 | +0.0 |
| Arc Relay | rare | 4.5 | +0.05 | +0.0 |
| Aegis Rig | legendary | 10.0 | +0.53 | +0.0 |
| Phoenix Cell | legendary | 9.5 | +0.60 | +0.0 |

Mean by rarity: common 3.1 (2.5-4.0, 7)  uncommon 4.2 (2.5-6.0, 10)  rare 5.6 (4.5-7.5, 6)  legendary 9.8 (9.5-10.0, 2)
