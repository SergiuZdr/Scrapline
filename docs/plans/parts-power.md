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

## Trait ownership (086, T2)

The engagement review (T2): perks (A8), maker sets (A10), legendaries (A9) and the parts already
in the game hand out the same few traits. This table says who gives what, and the rule below says
what happens when two sources meet on one machine. **Decided before building any of them.**

| Trait | Rule perk (A8, V1) | Maker set, 3 pieces (A10) | Legendary (A9) | Cores / modules | Arms (their own) |
|---|---|---|---|---|---|
| **pierce** (shots go on through a machine) | AP Rounds +1 on shots; other weapons +1 damage (`ap`, no slot) | VEKTOR +1 | Sunspear: through *everything*, heaps and walls too (`breach`); hits your own on the line | Mag Core +1, Belt Feeder +1 | Lance 1, Coilgun 1, Railgun 9 |
| **tears** (a hit tears an arm off) | Rending Grip: every hit, any weapon | CINDER: every hit, any weapon | Godhammer: every hit (its own arm) | Solvent Core, Gripping Hooks: every melee hit | Ripper Claw every hit; **Saw at 4 damage** (`tear_at`, not the rules' 5) |
| **arc** (a shot jumps on) | -- (Arc Relay perk is `chain`: +1 on a weapon that already arcs) | ARCLIGHT +1 jump on every shot | -- | Tesla Core +1, Arc Relay module +1 | Pulse 2, Coilgun 1 |
| **mark** (next hit on it +2) | Spotter | -- | -- | Null Core, Spotter Uplink | Spotter Array |
| **thorns** (melee attackers take it) | Barbed Hull 1 | KESSLER 1 | -- | Spiked Plating 1 | -- |
| **unshovable** | Ground Spikes (needs shovable) | KESSLER | Colossus: and every machine of yours next to it (`anchors`) | Gyro Anchor | anchor frames (Bulwark, Citadel, Colossus) |
| **kill heal** | Scavenger 2 | -- | -- | Scrap Leech 3 | -- |
| shove | -- | -- | Godhammer: 2 hexes | Hydraulic Ram | Hammer, Scattergun, Godhammer |
| ward (neighbours take less) | -- | -- | Aegis Rig 2 (the enemy Warden's rule) | -- | -- |
| meltdown, rise, burn, roots | -- | -- | Crucible Heart, Phoenix Cell, Phoenix Cell, Godhammer | -- | -- |
| crew rule (`meta.json`) | -- | -- | -- | -- | WALL: abilities a round sooner (cooldown, as ARCLIGHT x2) |

**The rule.**
1. **Arms own their signature at their own number**; perks, sets, cores and modules lend a machine-wide
   trait (a flag, or +1); **legendaries own rules no other source gives** (breach, shove 2, roots, anchors,
   meltdown, ward, rise and burn). A legendary may also carry a shared trait, never as its point.
2. **Counted traits add up** (pierce, arc, chain, thorns, kill heal, cooldown): every source is +1, so no
   second source is ever dead.
3. **Flag traits are owned once** (tears, mark, unshovable, move after attacking): a second source on the
   same machine does nothing. So a perk that gives a flag is only offered where it would do something
   (`needs`): Ground Spikes already needs "shovable"; **Rending Grip should need a melee arm that does not
   already tear, Spotter a weapon that does not already mark** (V1's `needs`, reported).
4. **Saw against Rending Grip** (the overlap the review named): the Saw's trait is a *lower threshold*
   (tears at 4), the Grip's is *every hit*. On one machine the Grip covers the Saw and still works on the
   other arm, so the pick is never dead unless both arms already tear (rule 3 keeps it off the offer then).
5. **Sets carry no heat** (the user, 2026-10-22): the 2-piece is a small stat (KESSLER +2 HP, ARCLIGHT
   abilities a round sooner, VEKTOR +1 move, CINDER +1 melee), the 3-piece the maker's verb above.
   CINDER's 2-piece +1 works on melee arms only; its 3-piece tears now work on every weapon (the user,
   2026-11-02).
6. **No slot `needs` on rule perks (the user, 2026-11-02):** a rule perk works with any weapon, and the
   offer leans toward the build -- a perk that adds to a trait the machine carries, or to a set its makers
   build, has its seeded roll halved (`RunSim._perk_favoured`; counted traits and set keys only). A flag perk
   (tears, mark) is never offered when every weapon that hits already has the flag (`RunSim._perk_owned`).

## Measured (086)

`balance_fights --arms 150` (enemies +40 HP +5 damage), before 086 and after (crew won 67.7% -> 63.2%):

| Arm | Before | After | What changed |
|---|---|---|---|
| Sunspear | +26.3 | **+15.5** (+6.9 to +24.1) | pierces everything, heaps and walls too, and its own crew; 3 damage (was 5), range 5 (was 6) |
| Godhammer | +21.7 | **+12.8** (+4.3 to +21.3) | shoves 2, tears every hit, roots its wielder for the rest of the turn; 5 damage (was 7). A root into the NEXT turn measured -47.4 (10.7% won): a Godhammer that hits every turn never moves again |
| Saw / Cleaver | +1.7 / +1.7 (byte-identical rows) | +6.1 / +2.8 | the Saw tears at 4 |
| Pulse | -13.0 (outside the noise) | +0.8 | 3 damage (was 2): its arcs jump for 2, not 1 |
| Hammer | -1.7 | -1.9 | untouched (inside the noise both times) |

No two rows are byte-identical. The Sunspear sits at the +15 line (its interval is wide; heat 3 is the next
trim if it should come under). The non-arm legendaries (Colossus, Crucible Heart, Aegis Rig, Phoenix Cell) are
not in the arm trial; `part_power.gd` cannot separate them (see 033) -- they wait for the run bot and the user.

**Focus (B6)**, `balance_fights --fights 600 --b` on the same fights (per machine that carries Focus, per fight):
free 1.06; costs 1 heat 0.95 (overheats 0.78 -> 0.81); costs 2 heat 0.99 (overheats 0.91); counts as the move
0.18 (the bot moves first, then cannot focus). Win rate and crew HP lost unchanged in all three. **Shipped: 1
heat** -- the move dial (`takes_move`) all but deletes Focus for the bot; a human may play it differently.

**Elite affixes (A5)**, crew HP lost per random fight against 4.3 with no affix (no extra enemy, no HP bonus --
those are the run's): every enemy RIGGED 4.7 (x1.1), every enemy BULWARK 5.2 (x1.2), every enemy VOLATILE 13.4
(x3.1), one VOLATILE among its escorts 6.6 (x1.5). Win rates unchanged (94%). So VOLATILE belongs on one machine,
not a whole squad; RIGGED and BULWARK need the elite's extra enemy and HP to reach 1.5-2x.

## Measured by the arm trial (072)

`balance_fights --arms 150` finally separates the arms that `part_power.gd` could not: tougher enemies
(+40 HP +5 damage) so the crew wins about 63%, every arm on the same 150 scenarios. Against the
average arm: Sunspear +28 points, God Hammer +23, Railgun +15, Coilgun +10 (all real); Pulse -12,
Mortar -15, Snare -25, Shield Caster -27 (all real); the rest within the noise. The bot never cast
the Shield Caster then (073 fixed that). The Saw and the Cleaver tie because their fight numbers are
the same: an arm's `"ability"` (`ab_rend`, ...) is from the archived game and the hex fight ignores it.

With the bot playing every part (073; the crew wins 67%): the Lance joins the arms that win more
(+12.9); the Shield Caster, now cast about twice a fight, rises from -26.5 to -18.4 but still wins
less; the Mine Layer drops into "wins less" (-10.4); Snare (-22.4), Mortar (-16.4) and Pulse (-12.4)
stay at the bottom. Table: `docs/iterations/073-bot-abilities.md`.
Detail and the full table: `docs/iterations/072-arm-trial.md`.

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
