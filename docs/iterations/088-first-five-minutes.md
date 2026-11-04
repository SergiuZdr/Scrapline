# Iteration 088 — First five minutes and Act 3

**Status:** done
**Started:** 2026-11-03 · **Finished:** 2026-11-04
**Answers:** the engagement review (A15, A14, A6) and the user's answers of 2026-11-03.

## Goal
A new player meets the game's signature moves (tear, pit, cancel, heat) in the shakedown. Each objective is
pointed out the first time it appears. Act 3's openers can no longer be learned by heart.

## Scope
- In:
  - **A15, the shakedown rebuilt** around the signature verbs, in 12 coached steps:
    - one tear (an enemy at low HP, its arm torn off);
    - one pit fall (a shove into a pit);
    - one CANCELLED intent (a kill before it fires);
    - one real threat;
    - heat as a stated choice.
    - Coach text uses the crew's names, and the move ring never sits on an aimed hex.
    - **A SKIP button on its first screen** (the user).
  - **A14, the first time each objective appears**:
    - **a coach callout only, no strip** (the user);
    - the callout points at the cache, terminal, pile or zone;
    - it is shown once per objective per profile (`Profile.mark_seen('obj_<kind>')`), with its text in `story.json`.
  - **A6, Act 3 variety**:
    - `prop_slots`: groups of candidate hexes, one picked by SimRNG (the_core's drums too);
    - `"mirror": true` for symmetric objectives;
    - no map repeated within an act;
    - **3 new Act 3 maps** from the 081 arena kit, each built around a different objective (the user).
- Out: a strip for objectives, onboarding beyond the shakedown and objectives, new art assets.

## The user's answers (2026-11-03)
- Shakedown: 12 steps, skippable.
- Objectives: only a coach callout on the board, no comic strip.
- Act 3: 3 new maps.
- On the built shakedown:
  - SKIP jumps to the last card over a dimmed board.
  - A first-time callout is added for REINFORCEMENT marks, besides defend, salvage, hold, hack and survive.
  - A fuel drum stays on the shakedown board with no coached step.
- On the maps (2026-11-04):
  - **Accept the 45.3% run win rate**: Act 3 is the hard act.
  - A site whose dealt map the crew already met this act switches to a fresh map, and its card changes then.
  - Every Act 3 map mirrors half the time, the Core included.

## Work split (parallel agents, disjoint files)
- **O, onboarding:**
  - A15 and A14;
  - files: `data/fights/shakedown.json` and the onboarding scripts and screens;
  - `story.json`, `glossary.json`;
  - `verify_onboarding`, `shot_onboarding`.
- **M, maps:**
  - A6;
  - files: `sim/combat/combat_setup.gd` (prop slots, mirror) and `sim/run` (no repeats);
  - the new `data/fights/*.json` for Act 3, `run.json`;
  - `verify_combat`, `verify_run`.

## Acceptance criteria
- [ ] verify_onboarding wins the new shakedown by real clicks with a tear, a fall, a cancelled intent and a heat
      choice; SKIP works; no ring on an aimed hex; each objective callout is shown once per profile.
- [ ] Act 3 repeats within an act fall from 15/23 to fewer than 5/23 (bot runs); verify_run green; each new map
      is won by the bot at a rate near the other Act 3 maps (balance_fights).
- [ ] `tools/check.sh --fingerprint` green; run_bot 150 within 5 points of 087's 52.0%.
- [ ] Sheets: the shakedown's verbs, an objective callout, the 3 new maps and prop-slot variants.

## Result

### Summary
Two agents in parallel (O onboarding, M maps). `tools/check.sh --fingerprint`: verify_combat 483, verify_combat_input 86, verify_run 351, verify_run_ui 124,
verify_save 43, verify_onboarding 85, verify_meta 109, verify_assembly 168, verify_animation 38 -- all passed
(verify_run 1026 s under the 1500 s limit). Fingerprint TOTAL **72fc6fe5** (087: 4f403a1d; the Core's drums and
mirroring now follow the seed, and the shakedown changed).

- **run_bot 150: 68 won, 45.3% (38-53)**, below 087's 52.0%; the user accepted it. Lost of runs reaching each
  act: 1.3 / 13.5 / **46.9%** (087: 6.0 / 24.1 / 27.1). The new maps win single fights as often as the old ones
  but take 1-3 more rounds against 2-3 more enemies, so the crew wears down in Act 3.
- A first build, before the new maps were tuned, measured 65.3% (57-72): they were won 89-93%.
- **Repeats** (map_census, 150 bot runs, seeds 1000-1149): Act 3 runs with a repeated map 93/107 -> **2/128**;
  Act 3 fights on a map already met that act 185/437 -> 2/485; Act 1 runs with a repeat 107 -> 3, Act 2 100 -> 17.
- **New maps**, paired on the same 377 Act 3 fights (map_census --swap): Blowing House 93% -> 82% (7.7 rounds),
  Taphole 89% -> 82% (10.1), Skull Cracker 93% -> 79% (9.2); old maps 78-81%. Only a tighter need AND more
  enemies together matched the old maps; either alone moved 1-4 points. `balance_fights --maps` wins ~95%
  everywhere and cannot tell maps apart.
- **Shakedown**: verify_onboarding wins it by real clicks in round 2 with a real threat on Relay, a CANCELLED
  shot (Needle kills the Gunner), a FELL (the Runner shoved into the pit), FOCUS paid for heat and a PART_TORN
  that cancels the Boss's lance; both coached rings off aimed hexes; SKIP; the drum still standing.
- Objective callouts: defend, salvage, hold, hack, survive and reinforcements, once per profile; none for rout
  (the shakedown teaches it) or bosses (their strip does).

### What was built
- **A15** `data/fights/shakedown.json` and `data/tutorial.json`: 12 steps (THE SHAKEDOWN with SKIP, READ THE
  ENEMY, BREAK IT FIRST, CANCEL ITS SHOT, MOVE, INTO THE PIT, HEAT IS A CHOICE, TEAR AN ARM OFF, END TURN, SCRAP
  PILES, FINISH IT, THAT IS THE LOOP); a fuel drum at (0,4) with no step (a probe showed the coached line plays
  event for event the same). SKIP marks `tutorial_done` and `shakedown_skipped` and shows the last card.
- **A14** `scripts/combat/objective_callout.gd`: a ring on the objective's first piece and a balloon with its tail
  on it, after the YOUR TURN hint; text in `story.json objectives`, copied into `tutorial.hints` as `obj_<kind>`
  (every tool already marks those seen).
- **A6** `prop_slots` (one group of candidate hexes per entry, by SimRNG; the Core's drums on one of five pairs);
  `"mirror": true` (odd-r reflection after widening; `CombatSetup.mirrored`); maps dealt to a region's fight
  sites when it is made (least used within 6 links), a site whose map the crew met this act switches to a fresh
  one; `own_objective`, `extra_enemies`, `widen_cut` per map; `widen` moves a map's objective cells.
- **Three new Act 3 maps**: The Blowing House (HACK, all 5 terminals, +2 enemies), The Taphole (HOLD the tapping
  floor 4 rounds, +2), The Skull Cracker (SALVAGE, all 4 piles round a drop pit, +3).
- Tools: `tools/map_census.gd` (`--swap` replays each Act 3 fight on every Act 3 map), `balance_fights --maps`.
- 084's card test now checks the card just before travel (a switched site's card may differ from the act's
  start: 335 of 2016 fights).

### Sheets
`shots/088/088_shakedown_and_objectives_before_after.png` (every verb step, SKIP, the drum, the DEFEND, SALVAGE and
reinforcement callouts), `shots/088/088_act3_maps_and_core_variants.png` (the three maps, one mirrored, two Core
drum layouts).

## Decisions, lessons, open questions
- Decisions: the user's answers above.
- Lesson: random squads (balance_fights) win ~95% on every Act 3 map; only the bot's own Act 3 fights replayed
  on each map (`map_census --swap`) told the maps apart.
- Lesson: a map tuned to the old maps' single-fight win rate can still make an act harder: longer fights with more
  enemies cost HP the next fight inherits. Judge an act's maps by run_bot, not per fight.
- Lesson: 088's maps agent built its work in 30 minutes and spent 12+ hours measuring in series; agents now get a
  cap of one 150-run bot plus one confirmation.
- Open: Act 3 loses 47% of the runs that reach it; the play-test decides whether that is the right wall.

## Next
The play-test of 082-088 by the user.
