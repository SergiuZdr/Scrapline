# Iteration 008 — The yard and the garage

**Status:** done, awaiting the user's play-test
**Started:** 2026-09-25 · **Finished:** 2026-09-25
**Answers:** every issue in [play-test 3](../playtests/2026-09-25-playtest-3.md).

## Goal
The run is a PLACE with a reason to cross it: a 2.5D scrapyard map under a Reclaimer you
can see, a story that says why you are running, and a garage where a machine is seen
whole and scrap buys it something. The three combat rules the play-test tripped on do
what a player expects.

## Scope
- In: the four combat and text fixes; machine levels as the scrap sink; the story; the 3D
  map; the garage.
- Out (deliberately): part upgrades, perks and manufacturer sets (build progression, now
  009); story beyond text and the map (no cutscenes, per the 2026-09-24 decision); the
  Reclaimer as an enemy faction in fights.

## Plan, issue by issue

| Id | Fix |
|---|---|
| PT3-6 | **Charge works after moving**, and hits harder the further it runs: 3 damage + 1 per hex run first (3–5), plus the machine's damage bonus. Still uses the action, still cooldown 3 |
| PT3-7 | **The arc reaches terrain.** From whatever the shot hits first (machine OR prop) it jumps to one neighbour: an enemy machine if there is one, else a fuel drum, else a crate, else any machine. A drum it touches goes off |
| PT3-8 | **Piles are collected along the whole path**, by moves and dashes, for both teams |
| (found) | Part text: shots say "shot N", lobs "lob N-M"; the "line" leftover is gone |
| PT3-9 | **Machine levels**: in the garage, scrap buys a machine a level (15 / 25 / 40 scrap, max 3): +2 HP; +2 HP and +1 damage; +3 HP. Numbers in `run.json` (tuned, see Result) |
| PT3-4 | **The story** (`docs/plans/story.md`): what the Reclaimer is, why the crew crosses the yards, what each act's gate is. In game: a briefing on NEW RUN, the act and mission on the map, site text in the world's voice, and endings that say what happened |
| PT3-1/2/4 | **The map is 3D**: a tilted camera over a dark yard; each site a landmark built from the arena kit (wrecks, containers, a lit workshop gantry, the gate); roads on the ground; **the Reclaimer a wall of harvester rigs with red light and smoke** that visibly advances, the ground behind it stripped. The combined HP bar goes; the crew is a strip of portraits with their own HP and level |
| PT3-3 | **One click travels.** Hover (PC) shows the preview and the move's cost; click goes. On touch, the direction and cost are written on the site itself, and a tap goes |
| PT3-5 | **GARAGE** replaces REFIT: crew tabs; the machine whole in 3D; beside it PARTS and STATS tabs; hovering a part turns the machine to it and makes it glow; LEVEL UP under the machine's name; the hold a low strip along the bottom with SORT (rarity / slot / newest) and SCRAP. Drag and drop and tap-then-tap still work |

## Steps
1. Combat fixes + part text, with tests. Run balance and the run bot.
2. Machine levels in the sim (`RunSim.LEVEL_UP`), with tests.
3. The story doc, and the text hooks in game.
4. The 3D map.
5. The garage.
6. Tests, screenshots, docs, merge, play-test 4.

## Acceptance criteria
- [x] verify_combat: charge after a move, damage scaling by distance; chain into a drum sets it off; a move through a pile collects it.
- [x] verify_run: LEVEL_UP costs, caps, raises HP and damage in the next fight.
- [x] verify_run_ui: one click travels; the garage fits by tap and by drop, sorts, levels up.
- [x] run_bot 150 and balance_fights run; numbers recorded.
- [x] Screenshots: the 3D map (with a hover preview), the briefing, the garage with a hovered part glowing, the STATS tab.
- [x] Merged to main. [ ] **The user plays.**

## Result

| Suite | Result |
|---|---|
| verify_combat | 116 passed (108): charge after a move, 3/4/5 by distance, Overdrive + Bypass on a charge; the arc into a drum and from a crate; a move through a pile |
| verify_combat_input | 20 passed |
| verify_run | 61 passed (55): levels cost 15/25/40, cap at 3, +2/+2/+3 HP and +1 damage at level 2, none mid-fight |
| verify_run_ui | 26 passed (19): the briefing and ROLL OUT; hover previews without moving (a real mouse event on the 3D yard); **one click travels**; the garage: tap-fit, hover lights the part on the model, drop to hold, drop on a crew tab, SORT by rarity, SCRAP, STATS, LEVEL UP, BACK TO MAP |
| verify_save / assembly / animation | 14 / 100 / 34 passed |
| balance_fights 600 | random squads **88.0%** (90.8% after 006): the combat fixes did not make single fights easier |
| run_bot 150 | **88.7%** won (76.7% after 007), 0 illegal actions, 4.3 fights won a run |

**Balance, measured on the same 150 seeds:**

| Build | Run bot wins |
|---|---|
| 007 | 76.7% |
| 008, levels priced out of reach | 84.7% |
| 008, +2 HP and +1 damage on EVERY level | 94.0% (94.7% at 12/20/30) |
| 008 as shipped (+2 / +2 and +1 damage / +3) | **88.7%** |

Without levels the run is already 8 points easier: picking up piles along the whole path
means more scrap, and the bot spends it on workshop repairs. Damage on every level was
the big lever and was cut to one level. The bot barely uses abilities, so a person will
find it easier than 88.7%. **Difficulty is left for the user's play-test** (open question
in MEMORY, with the dials).

### Different from the plan
- The hover glow is a pulsing additive overlay plus a 14% scale-up of the part; there is
  no separate "protrude" animation.
- On touch there is no hover: the direction and cost are written under each reachable
  site instead, and a tap travels at once.
- A part can be dropped on a **crew tab** as well as a socket (not in the plan; it is how
  a part moves to another machine without switching tabs).

### Screenshots
`shots/008_briefing.png`, `008_map.png`, `008_garage.png` (right arm hovered),
`008_garage_stats.png`.
