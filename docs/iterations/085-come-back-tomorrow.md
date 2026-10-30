# Iteration 085 — Come back tomorrow

**Status:** planned
**Started:** — · **Finished:** —
**Answers:** the engagement review (B4, B9, B10, T4) and the user's answers of 2026-10-22: harder overall;
"it must not be played once and uninstalled, it needs a motive to be played again and again"; players
should come back daily and weekly for something new (daily + weekly yard); a run starts with 3 deals,
each a gift and a cost; the story's ending waits for the user's own vision (the ladder does not move it).

## Goal
Every run leaves the player a next thing to chase: the next rung, today's yard, this week's contract, a
crew's medal, and every run opens with a choice that shapes it.

## Scope
- In:
  - **B4 the ladder:** about 10 rungs, each one announced rule through B1's `adds`; a rung opens by winning
    the one below; NEW RUN starts on the highest open rung; the title names it ("NEXT RUN: RUNG 5 ·
    TRACKERS LOCK ON"). Rungs prefer taking away free recovery or free dodges over adding HP. A per-crew
    record stamp (highest rung won). Rungs are cumulative: rung N carries rungs 1..N (the user).
  - **The daily yard:** a seed from the date (local clock, UTC day), one fixed act condition per act, fixed
    deals, any crew; one attempt a day; a local best (acts cleared, fights won, HP left) and a streak.
  - **The weekly contract:** a seed from the ISO week, harder (a fixed rung), a fixed crew and 2-3 announced
    twists drawn from existing rules (e.g. "no workshops", "trackers lock on", "every elite volatile");
    any number of attempts, the best kept; clearing it gives a TROPHY for the garage's wall and a LIVERY
    (the user, 2026-10-29: the 3D plates are dropped).
  - **Start deals** (below).
  - **B9** each crew changes one run rule; **B10** three medals per crew replacing the grind counters
    (earned unlocks are migrated, never revoked); **T4** career replay clock.
- Out: online leaderboards (later, needs a server or Steam), the story's ending.

## Start deals (the user asked for this elaborated)
Before the first map move, after the assembly bay, three fixers in the yard each offer one deal. A deal is a
**gift now and a cost for the run**, both shown in full, plus a fourth plain choice, WALK ON (no gift, no
cost). Deals are rolled from the run seed, so a seed code, the daily and the weekly always offer the same
three.

Why it works (Slay the Spire's Neow, Monster Train's pact shards, Hades' pacts): the first decision of a run
is about the whole run, a greedy start becomes a story ("I took the rare arm and the Reclaimer ate me in
Act 2"), and the same seed plays differently by the deal taken.

The deal pool is data (`data/run/deals.json`), each built only from things the run already has:

| Gift | Cost |
|---|---|
| A rare arm of your crew's maker, fitted now | The Reclaimer starts one column ahead |
| Every machine +3 max HP | No workshop in Act 1 |
| 60 scrap | Enemies +1 damage in Act 1 |
| A free level on one machine | Its first perk offer is 2 cards, not 3 |
| Scout every site of Act 1 (B2's cards all shown) | The first fight is an elite |
| A module of choice (1 of 3) | Salvage shows 2 options for the first three fights |
| Remove one starter arm for a random uncommon | You do not choose the arm |

Three rules keep them honest: a gift is worth about one good salvage pick; a cost is always a run rule the map
or the HUD shows (never a hidden number); one of the three is always a soft deal (small gift, small cost).
Higher rungs could add a fourth fixer with a bigger deal (a later choice for the user).

## Acceptance criteria
- [ ] Rungs 0/4/10 at 150 runs each: monotone; top rung 15-30% for the bot; no step over ~12 points;
      fights costing <= 0 HP fall toward 20-25%; rounds per run reported.
- [ ] The daily and weekly seeds are the same for every player on that day/week (verify_run: a fixed date
      gives a fixed seed and region); one daily attempt; the best and the streak survive a restart.
- [ ] Deals: the same seed offers the same three; each deal's cost shows on the map or the HUD; the save
      replays the pick; RunBot takes deals by a stated policy and the bot's win rate per deal is reported.
- [ ] Crews within about 10 points of each other; medals: fewer than 20% fall to the non-aiming bot in 10 runs.
- [ ] Screens: the ladder line, the daily/weekly panel, the three deals, a crew card with medals.

## Result

### The weekly reward: trophies and liveries (2026-10-29/30, the user's call)
- **Plates out:** `art/props/pl_*`, `ConstructView.add_plate`, the 2D plate badge (yard board, garage, roll
  call), `probe_plate`, `shot_plates`, `plate_views.py`, `cut_ears.py` and the plates in `import_props.sh`.
- **Rotation:** `data/weekly_rewards.json`, `[{id, trophy, livery, name}]` in order; `RunSetup.weekly_options`
  carries `reward` (the id for week % n); `WeeklyRewards.for_week(week, options)` reads it, else week % n.
- **Trophies:** six new drawings (ChatGPT Images in the user's Chrome, one chat; saved with
  `chatgpt_show.js` + a full-window capture + `grab_crop.py`, cut with `cut_background.py`, enclosed white
  pockets cleared, 512 px) in `art/trophies/`. The TROPHY WALL (`scripts/ui/trophy_wall.gd`, TROPHIES in the
  garage header): hung trophies with their week and livery, empty hooks with the week last offered.
- **Liveries:** `Ink.LIVERIES` (six schemes, see art-and-audio.md), repainted per zone in `ink_toon`
  (`repaint`); LIVERY under the machine opens the picker; `Profile.set_livery/livery_for(crew, slot)`;
  drawn in the garage and in fights (`combat_scene` by fielded slot; `--livery` for shots/measures).
- **Profile:** `finish_weekly(week, key, result, reward)` keeps `trophies`; `trophies()`, `liveries()`;
  stored `plates` migrate to the trophies of their weeks (`verify_save`).
- **Checks:** verify_save 43/43 (+ plate migration), verify_meta 109/109, verify_run_ui 111/111 (the wall
  and the picker by real clicks), verify_assembly 168/168.
- **Contrast** (slag_pit, three runs each, interleaved with the makers' paint): the ratio may only grow, and none falls.

  | Livery | Makers' paint (A) | With the livery (B) | Mean A -> B |
  |---|---|---|---|
  | HAZARD YELLOW | 2.09 2.16 2.22 | 2.24 2.17 2.25 | 2.16 -> 2.22 |
  | OXIDE RED | 2.21 2.21 2.21 | 2.24 2.18 2.24 | 2.21 -> 2.22 |
  | GUNMETAL CAMO | 2.21 2.21 2.17 | 2.24 2.24 2.19 | 2.20 -> 2.22 |
  | BONE WHITE | 2.20 2.16 2.19 | 2.24 2.15 2.25 | 2.18 -> 2.21 |
  | SODIUM ORANGE | 2.12 2.21 2.22 | 2.24 2.25 2.15 | 2.18 -> 2.21 |
  | TEAL SCRAPPER | 2.18 2.16 2.17 | 2.19 2.25 2.22 | 2.17 -> 2.22 |

  A first pass, not interleaved, read SODIUM ORANGE (2.14) and TEAL (2.15) below the makers' 2.19: both were
  lifted (e2742a -> f0903a, 4e8f72 -> 5a9c7e). The same build then read 2.12 an hour later, so the table
  above is A/B interleaved on one quiet run (`shots/085/contrast_ab.txt`).
- **Bolder on the board (the user: "too faint in fights").** A fight dresses the crew with `bold`: the
  livery goes in at 0.85 / `MACHINE_SAT` chroma (`Ink.LIVERY_CHROMA_FIGHT`; the garage keeps 0.6), olive
  panels and the plain mid-grey plating are painted too (not the dark mechanism or the rust), and painted
  value is pulled halfway to flat cel colour (ink_toon `livery_bold`). Ink edges are still read from the
  original texture. OXIDE RED went browner, then lighter (c4513a -> b5583f -> cc6e50 -> d27858) and GUNMETAL
  CAMO lighter (858c90 / 5f6656 -> a4acb0 / 7b856d): in bold both first measured BELOW the makers' paint.
  Final contrast on slag_pit, alternating makers (A) and livery (B), three pairs or more:

  | Livery | A | B | Mean A -> B |
  |---|---|---|---|
  | HAZARD YELLOW | 2.04 2.12 2.13 | 2.26 2.27 2.25 | 2.10 -> 2.26 |
  | OXIDE RED (d27858) | 2.04 2.07 2.11 2.15 | 2.05 2.14 2.26 2.25 | 2.09 -> 2.18 |
  | GUNMETAL CAMO (a4acb0) | 2.21 2.07 2.07 | 2.31 2.10 2.24 | 2.12 -> 2.22 |
  | BONE WHITE | 2.01 2.04 2.19 | 2.62 2.40 2.49 | 2.08 -> 2.50 |
  | SODIUM ORANGE | 2.21 2.15 2.17 | 2.25 2.26 2.29 | 2.18 -> 2.27 |
  | TEAL SCRAPPER | 2.02 2.02 2.03 | 2.11 2.13 2.08 | 2.02 -> 2.11 |

  Raw: `shots/085/contrast_ab_bold*.txt`. Sheet: `shots/085/fight_liveries_sheet.png` (the whole frame, the
  crew at 1:1, a grey copy, makers first).
- Sheets: `shots/085/liveries_sheet.png` (before/after on the three starting machines, with a grey copy),
  `shots/085/rewards_sheet.png` (wall, picker, garage, a fight, the six trophies).

## Decisions, lessons, open questions

## Next
086: builds that change rules.
