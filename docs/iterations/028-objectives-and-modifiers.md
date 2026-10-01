# Iteration 028 — New objectives and fight modifiers

**Status:** in progress
**Started:** 2026-10-01 · **Finished:** —
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
- [ ] verify_combat: each objective wins as stated and not before; each modifier does what it
  says; dry runs leak nothing.
- [ ] verify_run: all six objectives and the modifiers are rolled across generated fights.
- [ ] Bot 150 runs, 0 illegal; screenshots of each objective and the wires.

## Result

## Decisions, lessons, open questions

## Next
029: weapons and legendary parts.
