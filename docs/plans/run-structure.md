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
| Workshop | repair, rebuild a wreck, tune a part (costs scrap) | 2 per act |
| Trader | buy and sell parts for scrap | 1–2 per act |
| Signal (event) | text event with choices; risk/reward | common |
| Watchtower | reveals fog in a radius | 1–2 per act |
| Boss gate | the act boss; exit to the next region | 1 |

## Crew HP carries (005, replacing the Crawler)

Each machine's HP carries from fight to fight; workshops patch the crew. A machine
destroyed in a fight is a wreck (chassis only) until a workshop rebuilds it. The run is
lost when all three are wrecked, or when **the boss fight is not won** (007: there is no
road past the gate and the road back is reclaimed, so a surviving crew would be stranded).

## How the map reads (007)

Play-test 1 and 2: "you cannot tell when you need to move ahead or can move sideways".

- Columns are drawn as **zones** (START, ZONE 2 … ZONE 6, GATE), named across the top.
- The Reclaimer is a red wall over what it has taken; the **next zone to fall is striped**;
  the header says **"THE RECLAIMER TAKES ZONE N IN M MOVES"**.
- Every reachable site is labelled **FORWARD / SIDEWAYS / BACK**.
- The first tap **previews** a site (what it is, and what this move costs: "this move lets
  the Reclaimer take ZONE 3", "leaving reclaimed ground costs 2 HP each"); TRAVEL goes.
- The side panel is the crew (HP bars and part thumbnails) and REFIT with the hold count.
  There is no log.

## The hold (007)

- Starts at **8** parts. A workshop sells **+2 room** for 10, then 16, then 24 scrap.
- Any part can be **scrapped** outside a fight for 3 / 6 / 10 scrap by rarity (in refit:
  drag it onto SCRAP).
- Taking salvage is **always allowed**. An overfull hold **blocks travel** until something
  is fitted or scrapped; the map says so and makes REFIT the primary button.

## Refit (007)

Its own screen. Three machine columns of five sockets and the hold as part cards. Drag a
part onto a socket (the sockets it fits light up), from a socket back to the hold or to
another machine, or onto SCRAP. Tap a part, then tap where it goes, does the same on a
phone. Each card carries a rarity banner and a verdict against the crew's fitted parts.

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
