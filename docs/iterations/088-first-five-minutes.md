# Iteration 088 — First five minutes and Act 3

**Status:** in progress
**Started:** 2026-11-03 · **Finished:** —
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

## Decisions, lessons, open questions

## Next
The play-test of 082-088 by the user.
