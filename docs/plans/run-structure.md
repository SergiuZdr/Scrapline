# Plan — Run structure (the scrapyard region)

**Status:** built in 004 (2026-09-24) for one act: region generation, fog, the front, skirmish,
elite, scrapyard, workshop and boss sites, salvage, the hold, refit, wrecks, rebuilds, and
save/resume. Numbers are in `data/run/run.json`. **Map and refit redesigned, and the hold
reworked, in 007 (play-test 2).** Traders, signals and watchtowers come with Act 1 content (010).

## The hybrid map

You asked for something between an open scrapyard region and a branching node map. The
proposal:

- Each act is **one region** drawn as a **top-down scrapyard map** with real geography:
  roads, container canyons, a flooded pit, a crane yard.
- **Sites (nodes)** sit on that geography, connected by **roads (edges)**. You move
  site to site along roads, which gives it node-map clarity.
- Unlike a strict Slay the Spire map, **you can go sideways and backtrack**. The region
  is a graph, not a one-way tree. What stops you wandering forever is the Reclaimer
  front.
- **Fog**: you see the sites next to you and anything revealed by scouting. Everything
  else shows as terrain only, so you know it is there but not what it is.

## The Reclaimer front (pressure)

- The front starts on one edge of the region and **advances one column every 2 moves**
  (as built).
- Sites the front swallows cannot be entered. **Each move made from consumed ground costs
  every machine 2 HP** (never below 1).
- The **exit** (the act boss) is on the far side. So the act is a question of how much of
  the region you can loot before you have to run.
- Backtracking works, but it spends moves the front will make you pay for.

## Site types

| Site | What happens | Frequency |
|---|---|---|
| Skirmish | standard fight, salvage reward | common |
| Elite wreck-field | hard fight, rare part guaranteed | 2–3 per act |
| Scrapyard | no fight; pick 1 of 3 parts or take scrap | common |
| Workshop | repair, rebuild a wreck, more hold, **tune a part** (011; costs scrap) | 2 per act |
| Trader | **built (013)**: three parts for sale (one tuned) by rarity; buys hold parts for twice their scrap value | weight 8 |
| Signal (event) | **built (013)**: one of seven events (`data/run/events.json`), never twice a run; every option states its cost and gain; effects are scrap, HP, parts, tuned parts, scouting, the Reclaimer moving, or a fight | weight 14 |
| Watchtower | **built (013)**: scouts every site within two columns | weight 6 |
| Boss gate | the act boss; exit to the next region | 1 |

## Crew HP carries (005, replacing the Crawler)

Each machine's HP carries from fight to fight; workshops patch the crew. A machine
destroyed in a fight is a wreck (chassis only) until a workshop rebuilds it. The run is
lost when all three are wrecked, or when **the boss fight is not won** (007: there is no
road past the gate and the road back is reclaimed, so a surviving crew would be stranded).

## How the map reads (009: fogged, followed, lived in)

Play-test 4: "bigger, not seen whole", "the crew list looks bad", "the Reclaimer's moves
should not be text", "it feels empty". Now:
- **9 columns, up to 4 rows**; the camera sits close and **follows the crew**, who stand on
  their site and **walk the road** when they travel. Drag, keys and the wheel look around;
  C comes back.
- **Fog of war** over everything not yet scouted (a pale mist, painted from what the crew
  has seen; roads and junk deep in it are not drawn). The gate's beacon shows through.
- **The Reclaimer gauge**: its name and one pip per move of its step; the last pulses when
  your next move brings it. On the map its **ghost** — a red curtain on the line it will
  take — pulses too, harder while you hover a move that triggers it.
- **Crew dock**: the three machines as real rendered portraits (levels and all), level
  marks and HP pips; each opens the garage.
- **Life**: scout drones with searchlights ahead of the front, smoking wrecks where fights
  were, a dead-industry skyline with blinking stacks, the Crucible's glow beyond the gate.

## How the map read in 008 (a 3D yard, superseded by 009)

Play-test 1, 2 and 3: first "you cannot tell forward from sideways", then "it is 2D, there
is dead space, and two clicks to move is annoying". `scripts/run/yard_view.gd`:

- A tilted camera over a dark yard. Each site is a **landmark built from the arena kit**
  (camp containers, wreck piles, a lit workshop gantry, the gate) on a pad whose ring says
  what it is to you now: amber here, blue reachable, grey done. Its icon floats above.
- Columns are **zones** named on the ground (CAMP, ZONE 2 … ZONE 6, GATE).
- **The Reclaimer is a wall** of harvester rigs across the whole map, red beacons over red
  dust, a glowing blade at its foot. Behind it the ground is stripped bare; the zone it
  takes next pulses red. It slides forward when the front moves.
- **One click travels.** Hovering (PC) shows a card with what the site is (in the world's
  voice) and what the move costs. For touch, the direction and any cost are written under
  every reachable site, so a tap never needs a preview.
- The crew is a strip of machines along the bottom (frame, name, level, HP); each opens
  the garage on that machine. The combined HP bar is gone.
- A new run opens on the **briefing** (`data/run/story.json`), see `plans/story.md`.

## The hold (007)

- Starts at **8** parts. A workshop sells **+2 room** for 10, then 16, then 24 scrap.
- Any part can be **scrapped** outside a fight for 3 / 6 / 10 scrap by rarity (in refit:
  drag it onto SCRAP).
- Taking salvage is **always allowed**. An overfull hold **blocks travel** until something
  is fitted or scrapped; the map says so and makes REFIT the primary button.

## The garage (008, replacing refit)

After a "manage soldier" reference the user supplied. Crew tabs across the top; the
selected machine stands whole in 3D (drag to turn it); beside it **PARTS** (five socket
rows) and **STATS** (every number, read from `RunSim.preview_machine`, the unit the next
fight will field). **Hovering a part turns the machine to show it, lights it and stands
it proud.** The hold is a low strip along the bottom with **SORT** (newest, rarity, slot)
and a SCRAP bin. Drag onto a socket, a crew tab, the hold or SCRAP; tap-then-tap does the
same. **LEVEL UP** sits under the machine's name.

## Assembly (009)

Play-test 4: "a way to customise the starting robots from basic parts". After the briefing
the **assembly bay** opens: three machines, each socket stepped through a bench of every
common part (no limit) plus one each of the default crew's uncommons (`run.json`
`assembly`). ROLL OUT is one `RunSim.ASSEMBLE`, legal only before the first move, so the
build is in the action list and a replay rebuilds it. The frame names the machine ("Brute",
"Brute II"). Unlocks (meta-progression) will widen the bench.

## Machine levels (008) and perks (011): where scrap goes

Play-test 3: "scrap seems pretty useless". In the garage a machine buys its next level for
15, 25, then 40 scrap (3 levels). Since 011 every level is +2 HP (max, and that much now)
**and one perk of three** ([constructs-and-parts](constructs-and-parts.md)): LEVEL UP opens
the pick, the pick is part of the `LEVEL_UP` action, and the level-up event names it. The
+1 damage that level 2 used to give became a perk (Hot Loads). +1 damage on EVERY level
took the run bot from 85% to 94% in 008. A wreck keeps its level and perks when rebuilt.
Numbers in `run.json` `levels`.

## Salvage (011): always a real choice

A won fight or a scrapyard offers **three parts from three different slots** (so the options
pull in different directions), each rolled by rarity; the first meets the elite minimum; the
second comes from a maker the crew is building a set from when one fits. **Every salvage
screen has a scrap alternative** (8 after a fight, 15 at a scrapyard), so leaving the parts is
a choice, not a skip. An elite's guaranteed part comes tuned. Each card says what it would
beat and which set it would make ("MAKES CINDER x3 ON BRUTE").

## Workshops (011): tuning

Besides patching, rebuilding and hold room, a workshop **tunes** a part, fitted or in the
hold, one of its two ways, once (6 / 10 / 14 scrap by rarity): the TUNE bench lists the
crew's parts by machine and the hold, and shows the two options side by side with the
numbers before and after.

## The Reclaimer reaches into fights (013)

A fight at a site in the column the Reclaimer takes next gets its drones: two arrive on the
crew's back row at round 3, on hexes marked red at round 2 (stand on one to block it). The
fight panel says so before the player walks in. Lingering by the line now costs inside a
fight as well as on the road.

## What a move and a fight tell you (014)

Two screens answer the questions a player was left guessing at (review points R5-3, R5-1).

- **Before a move, the map says what it costs and what it gives up** (`RunSim.move_preview`):
  what the site gives, how many enemies wait there (with elites and the gate's escorts), whether
  the Reclaimer moves with you, and which unvisited sites it swallows when it does, by type;
  and whether its drones reach the fight. `verify_run` checks every preview on a bot's route
  against what the move then did.
- **After a fight, the result shows what the build did** (`FightRecap`): each machine's damage
  dealt and taken, kills and torn arms, and up to four "your build at work" lines naming the
  set, perk or tuning that added damage or took it off, and by how much. It counts only what
  the event stream shows. Range, move, vent and cooldown bonuses are real but not claimed.

## Currency

**Scrap** is the only currency inside a run. It comes from fights, scrapyards and selling
parts, and it is spent at workshops and traders. It resets every run.

## Pacing targets

| | Per act | Per run (3 acts) |
|---|---|---|
| Sites visited | 7–10 | ~25 |
| Fights | 4–5 + boss | ~15 |
| Time | 15–20 min | 45–60 min |

## Generation

- Each region is built from a **hand-authored layout template** with seeded site placement
  and seeded site types, under rules such as "a workshop never sits beside the start"
  and "at least 2 routes to the boss gate".
- The whole run comes from one **run seed**, so a seed can be shared and replayed
  offline. A daily seed is possible later with no server, as a local challenge.

## Save

The run is saved after **every site and every combat turn**. Quitting on a phone
mid-fight loses nothing.
