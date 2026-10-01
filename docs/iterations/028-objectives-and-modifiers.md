# Iteration 028 — New objectives and fight modifiers

**Status:** done -- waiting for the user to play it
**Started:** 2026-10-01 · **Finished:** 2026-10-01
**Answers:** PT9-7 ("too little content"). The user, offered four directions: "I like all these
ideas". Order: 028 objectives and modifiers (fights stop feeling alike; no new art needed), 029
weapons and legendary parts, 030 warlords, 031 sites and events.

## Goal
A fight is no longer only rout / defend / salvage on a plain yard: three new objectives and four
yard conditions, rolled by the run, each telegraphed on the board and readable from the card.

## Scope
- In:
  - **HOLD**: three marked hexes; a round that starts with a crew machine on the zone and no enemy
    on it scores; three scores win (or rout). Enemies contest it.
  - **SURVIVE**: no caches, waves: drones come in on the top row every 2 rounds, marked a round
    ahead; outlast 6 rounds (or rout).
  - **HACK**: four terminals; a crew machine that ends a move on one takes it; three win (or rout).
  - **Conditions** (`modifiers`): DUST STORM (every shot and lob 1 shorter), LIVE WIRES (2-4 hexes
    of sparking cable: 2 damage to whatever starts a round on one), SCRAP RAIN (piles worth double),
    HEAT WAVE (your machines vent 1 less). Rolled per fight by act and column; named on the
    opening card, the objective plate and the map's fight card.
  - The AI and the bot play them: enemies contest the zone; the bot takes terminals and the zone.
- Out: escort and rescue (they need a friendly unit that moves on its own).

## Steps
1. Sim: objectives (state, status, outcome, clone), modifiers in `CombatSetup`; tests.
2. Run: rolling them; data weights; the bot.
3. View: zone, terminals, waves, wires; texts; glossary.
4. Run bot; suites; docs; main.

## Acceptance criteria
- [x] verify_combat: HOLD scores 1, 2, 3 and wins, an enemy on the zone denies a round; HACK takes a
  terminal on a move's end (dry runs copy it); SURVIVE's waves come in and outlasting wins; DUST
  STORM -1 reach, HEAT WAVE -1 vent, SCRAP RAIN double piles, LIVE WIRES 2 a round.
- [x] verify_run: all six objectives and all four conditions are rolled over 40 runs; every such
  fight builds.
- [x] Bot 152 runs, 0 illegal; `shots/028_hold.png` (with wires), `shots/028_hack.png` (dust).

## Result

- **Objectives** (`CombatSim._hold`, `capture`, `_waves`; `state.hold_score`, `hacked`,
  `wave_marks`, all cloned; events `HOLD_SCORED`, `HACKED`, `WAVE_MARKED`; `SPAWNED` actor -2 is a
  wave). The AI: both sides value the HOLD zone (`IntentAI.SCORE_ZONE`), the crew a terminal not yet
  taken (`SCORE_TERMINAL`). Weights now rout 22, defend 22, salvage 16, hold 14, hack 14, survive 12.
- **Conditions**: `rules.json` `modifiers` (names, texts, numbers), `CombatSetup.modifiers` /
  `range_mod` / `vent_mod`, the `wire` tile (`w`, hazard 2); rolled by `RunSim._roll_modifier` from
  `run.json` `modifiers` (15% at column 1 to 50% at the gate's column; never at a gate).
- **View**: blue zone rings and HOLD ZONE n/3, terminals (blue, green when taken), the wave's
  ghost, cables on wire hexes; the objective plate, the opening card and the map's fight card name
  the condition.
- Suites: combat 258 (+12), run 155 (+3), run UI 49 (it now starts from a fresh profile), input 22,
  onboarding 39. Run bot, 152 runs: **57.9%** (53.9% before); lost in Act 1 / 2 / 3: 9.2% / 18.8% /
  21.4%. The new objectives are a little easier for the bot than the rout they partly replace.

## Decisions, lessons, open questions
- **Six objectives and four yard conditions**, all data-rolled; a gate is always a rout with no
  condition.
- Lesson: a UI test that reuses a profile file inherits what an earlier run of it saved -- start
  from a fresh file AND its backup.
- Open: are HOLD, HACK and SURVIVE fun? Are the conditions too subtle (one line of text)?

## Next
029: weapons and legendary parts.
