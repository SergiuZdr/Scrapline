# Iteration 030 — Warlords

**Status:** in progress
**Started:** 2026-10-01 · **Finished:** —
**Answers:** PT9-7, the third content direction ("a named mini-boss per act").

## Goal
Every act has a WARLORD: a named site on the map, a detour the player can choose, a fight with
its own rule, and a legendary in its hoard -- a big fight between the gates.

## Scope
- In:
  - A `warlord` site, one per act in `run.json` `warlord_column` (never on the only road),
    always revealed on the map; its fight is the act's authored warlord board (`"warlord": true`)
    with its keepers and rolled escorts; winning opens a hoard (a legendary, no act change).
  - **The Grinder** (Act 1): a ring of saws -- at the start of every round, 2 to each of your
    machines standing next to it (its neighbours are marked).
  - **The Magnet King** (Act 2): every other round it hauls each of your machines within 3 a hex
    toward it (into pits, into each other), marked a round ahead.
  - **The Twin Furnaces** (Act 3): two keepers; while both stand, each takes 2 less -- break one,
    then the other.
  - The view: marks, words, the map site; glossary; the bot can take or skip the detour.
- Out: new models (warlords are big machines from existing parts, like the keepers).

## Acceptance criteria
- [ ] verify_combat: the Grinder's ring hits its neighbours at round start; the Magnet King hauls
  machines within 3; a twin takes 2 less while its twin stands, and not after.
- [ ] verify_run: each act has one warlord site; its fight is the act's warlord board; winning it
  opens a hoard with a legendary and stays in the act.
- [ ] Bot 150 runs, 0 illegal; screenshots of each warlord fight.

## Result

## Decisions, lessons, open questions

## Next
031: sites and events.
