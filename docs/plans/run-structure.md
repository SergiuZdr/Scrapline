# Plan — Run structure (the scrapyard region)

**Status:** draft (Iteration 000). Implementation in 004.

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

- The front starts on one edge of the region and **advances one band every N moves**.
- Sites the front swallows are gone. If it reaches you, the next fight is a hard
  "caught by the Reclaimer" battle.
- The **exit** (the act boss) is on the far side. So the act is a question of how much of
  the region you can loot before you have to run.
- Backtracking works, but it spends moves the front will make you pay for.

## Site types

| Site | What happens | Frequency |
|---|---|---|
| Skirmish | standard fight, salvage reward | common |
| Elite wreck-field | hard fight, rare part guaranteed | 2–3 per act |
| Scrapyard | no fight; pick 1 of 3 parts or take scrap | common |
| Workshop | repair, rebuild a wreck, tune a part (costs scrap) | 2 per act |
| Trader | buy and sell parts for scrap | 1–2 per act |
| Signal (event) | text event with choices; risk/reward | common |
| Watchtower | reveals fog in a radius | 1–2 per act |
| Boss gate | the act boss; exit to the next region | 1 |

## The Crawler (from 003)

The Crawler is on the board in every fight and losing it loses the fight. **Its HP
carries across the whole run.** Workshops repair it for scrap. It is the run's health bar:
a won fight still costs something if the Crawler took hits. Losing the Crawler anywhere
ends the run.

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
