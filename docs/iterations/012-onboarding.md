# Iteration 012 — Onboarding

**Status:** done (batch 009–013; play-test after 013)
**Started:** 2026-09-26 · **Finished:** 2026-09-26
**Answers:** play-test 1, PT1-7: "Names and jargon are explained nowhere. A tutorial at the
start would solve most of it." Since then the game has grown a lot more jargon: hexes and
intents, heat, pierce and chain, carriers and pads, perks, tuning, makers and sets.

## Goal
A new player learns the game by playing it: a short scripted first fight teaches the loop of
a turn, every keyword the game uses can be tapped for its meaning, and each screen explains
itself once, the first time it opens.

## Scope
- In:
  - **A profile** (`user://profile.json`, `Profile` autoload): the few things that outlive a
    run -- the tutorial done, the hints seen. Changed only through its own methods, which save
    at once (the old game's lesson: a write that bypasses the command evaporates).
  - **The shakedown**: a scripted first fight (`data/fights/tutorial.json` plus its steps in
    `data/tutorial.json`). A coach panel gives one instruction at a time and marks where to
    click (a hex, a machine, a button); a step ends when the thing it asks for has happened
    in the fight, or on NEXT for the ones that only explain. It covers selecting and moving,
    intents, arming and firing, heat, a barrel, an ability, END TURN, a scrap pile and the
    objective. It runs on the real rules (it is a normal fight with a coach on top), so it
    cannot teach something the game does not do.
    - The first NEW RUN on a profile offers it (PLAY THE SHAKEDOWN / SKIP); the title has
      TUTORIAL.
  - **The glossary**: `data/glossary.json`, every term the game uses with a one-line meaning
    in the world's voice. `Glossary.linkify` turns the terms in a text into links; tapping one
    opens its card (tap, not hover: rule 1 of platform-and-ui). Used on the combat info panel,
    the garage STATS tab and socket rows, perk cards, the tune bench, part cards' detail, the
    map's site preview, and a GLOSSARY screen (title, map, fight).
  - **First-time hints**: one callout per screen the first time it opens (map, assembly bay,
    salvage, garage, level-up, workshop, tune bench), saying the one thing that screen is for.
    Dismissed once, gone for good (profile).
- Out (deliberately):
  - Voice-over, animated tutorials, a separate tutorial map screen.
  - Rewriting the part and ability texts themselves (only linking their terms).

## Steps
1. `Profile` autoload and its tests.
2. Glossary data and `Glossary` (linkify, card, the screen); wire the links in.
3. The shakedown fight and its coach; title and first-run entry.
4. First-time hints.
5. Tests (verify_onboarding.gd: the profile, linkify, the tutorial driven by real clicks to
   the end), screenshots, docs, merge.

## Acceptance criteria
- [x] The profile saves and reloads; marking a hint twice is harmless; a corrupt file falls
  back to a fresh profile (SaveFile's backup).
- [x] Every term used in part, perk, ability and enemy-kind texts that the glossary defines
  becomes a link; tapping it shows its card.
- [x] The shakedown can be played start to finish by real clicks in a headless test, each step
  advancing on what it asks for, and finishing marks the tutorial done.
- [x] Each first-time hint shows once and never again after it is dismissed.
- [x] All suites green; run bot unchanged (the tutorial is not a run: RunSim skips its board).
- [x] Screenshots: a coach step with its marker, a glossary card, a first-time hint
  (`shots/012_*.png`).

## Result

| Suite | Result |
|---|---|
| **verify_onboarding** (new) | **39** passed: the profile (reload, idempotent hints, reset); the glossary (links, longest form, escaping, no links inside words, no spelling on two terms, every ability and enemy kind has a card); the tutorial data; hints (show once, no stacking, GOT IT remembered); **the shakedown by real clicks**: NEXT, the marked hex, a weapon, aim and fire at the marked runner, the Strider and FOCUS, the drum, END TURN, finishing the fight, TITLE marks it played |
| verify_save | **15** passed (14): the profile is version 2; the old game's profile migrates keeping its tips; a test profile's backup lives beside it |
| verify_combat / combat_input / run / run_ui | 140 / 20 / 107 / 42 passed |
| verify_assembly / animation | 100 / 34 passed |

**What the player gets**
- **The shakedown** (`scenes/shakedown.tscn`): a guided first fight on the real rules. A coach
  panel (bottom right) gives one instruction at a time; an amber ring and chevron mark the hex
  to click, or an amber outline the button. Twelve steps: move, intents, arm, aim and fire,
  heat, abilities, a drum, END TURN, scrap piles, the objective, and what a run is. Each can be
  skipped; the whole tutorial can be skipped. The first NEW RUN on a profile offers it; the title
  has TUTORIAL.
- **The glossary**: 56 terms in seven groups (`data/glossary.json`). Blue words are links in
  the fight's info panel, the garage STATS tab, the site panels, the coach and the hints; a tap
  opens the term's card. The GLOSSARY screen is on the title and a `?` on the map, in the garage
  and in the fight.
- **First-time hints** on eight screens (map, assembly bay, salvage, workshop, garage, the perk
  pick, the tune bench, a fight), each dismissed once for good.

### Found on the way
- **`MachinePortrait` read the `Run` autoload** for a content argument `ConstructView` ignores,
  so any `--script` tool that named `CombatHUD` failed to compile (the trap CLAUDE.md warns
  about, one class deeper). It passes nothing now.
- **Every test wrote its profile's backup over the player's** (`SaveFile` had one fixed backup
  path); backup and temp files now live beside the save they belong to.
- The first ready machine is picked automatically, so a "pick the Brute" step passed before
  the player read it. The step was folded into MOVE.
- A link must mean the word's sense: "the marked hex" linked to MARK, and the enemy name "Scrap
  Runner" linked to SCRAP. Tutorial text says "the amber ring"; the runners are Yard Runners.

### Different from the plan
- Part cards, socket rows, perk and tune cards are buttons, and a link inside a button would
  fight its tap; their terms are covered by the STATS tab, the info panel and the glossary.
- The old `SaveFile` profile was repurposed (version 2) rather than a new file: its atomic
  write, backup and migration chain were exactly what the profile needed.

## Decisions, lessons, open questions
- **The tutorial is the real fight with a coach on top**, advancing on what happened in the
  event stream, never on a script of expected actions: it cannot teach something the rules do
  not do, and a player who does things out of order is not stuck.
- **Skipping counts as played**: the shakedown is offered once and then lives on the title.
- **Tests use their own profile with every hint seen**: a callout over a click point makes a
  UI test fail for a reason that has nothing to do with what it tests.

## Next
013 Act 1 content, then the user's play-test of 009–013.
