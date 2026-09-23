# Vision

> **Scrapline is a turn-based tactics roguelike about a small crew of scrap-built war
> machines crossing a dead industrial wasteland, rebuilding themselves from what they
> tear off the enemy.**

## The pitch in three lines

- **Fights are short tactical puzzles.** Every enemy shows what it is about to do, and your
  turn is working out how to stop it (in the spirit of *Into the Breach*).
- **Your machines ARE their parts.** A construct's attacks, movement and weaknesses come
  from the chassis, arms, core and module bolted onto it. Parts get shot off in battle and
  salvaged from wrecks, so your squad keeps changing shape during a run.
- **The run is a journey across a scrapyard region.** You pick a route through connected
  sites, but a closing front means you cannot visit everything. Every detour is a trade.

## Pillars

Use these to settle disagreements. If a feature serves none of them, it is cut.

1. **Readable, then deep.** You can see everything that matters on the board: enemy intents,
   heat, which part a hit will break. Depth comes from how the pieces combine, never from
   hidden numbers.
2. **Salvage is the progression.** Power inside a run comes from parts you scavenge and
   rip off enemies, not from XP bars. Losing an arm mid-fight is a real decision point.
3. **Every route is a trade-off.** The map pushes you to choose between safety and loot,
   and between repairing and pushing on.
4. **Runs you can finish in a sitting.** Aim for 45–60 minutes per full run and 3–6
   minutes per fight. The game saves at every node and every turn, so a phone session can
   end anywhere.

## Scope and business model

- **Premium, single-player, offline.** Pay once. No servers, accounts, gacha, IAP, energy
  timers, battle pass or ads.
- **Solo-dev sized.** 3 acts, about 25 part types per slot at launch, about 20 enemy
  types, 3 bosses.
- **Platforms:** PC (Steam) and mobile (Android first, then iOS), **designed together
  from day one**. Landscape only. Turn-based play makes touch a first-class input.

## Meta-progression: unlocks only

Finishing or failing a run earns unlocks: new parts and chassis enter the loot pool, plus
new starting crews and harder difficulty tiers. **Nothing carries over as raw stat
power.** A veteran wins because they know more and have more options, not because their
numbers are bigger. See [plans/meta-progression.md](plans/meta-progression.md).

## What Scrapline is NOT (any more)

The previous direction was a free-to-play live-service game: 6v6 real-time battles with an
order pause, async PvP, ranked seasons, guilds, a co-op boss, crates, a season pass and a
Nakama server. **All of that is out of scope.** The code that survives the pivot is listed
in [plans/salvage-audit.md](plans/salvage-audit.md).

## Settled details

3 constructs per crew, always. An 8×8 grid. Destroyed constructs can be rebuilt at
workshops. The closing front is the Reclaimer swarm. Light story through text. 3D with a
tilted camera. See [MEMORY.md](MEMORY.md) for the reasoning.
