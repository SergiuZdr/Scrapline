# Iteration 030 — Warlords

**Status:** done -- waiting for the user to play it
**Started:** 2026-10-01 · **Finished:** 2026-10-01
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
- [x] verify_combat: the Grinder cuts its neighbours for 2 and nothing further; the Magnet King hauls
  a machine 3 away a hex closer; a twin takes 2 less while its twin stands; the three boards are
  bot-fought, replayed and undone exactly.
- [x] verify_run: one warlord per act, known from the start, each act's own board; its hoard has
  a legendary and keeps the act.
- [x] Bot 152 runs, 0 illegal; `shots/030-sheet.png`.

## Result

- **Run**: site `warlord` (`warlord_column` 5, never a column's only site, revealed), its fight
  `_make_gate_fight` on the act's `"warlord": true` board (`keepers` authored, `warlord_escorts`
  rolled), +30 scrap and `hoard(..., false)`. The map: a red-lit bunker, WARLORD, its line; the
  bot detours when the crew is healthy.
- **Combat**: `aura` (Grinder), `haul_every` / `haul_radius` (Magnet King, `HAULED`, through `shove`
  so pits and bumps apply), `twin_armor` (Twin Furnaces); all in `_round_hazards` or `damage_to`,
  so `incoming` and the previews include them. The board marks the saw ring every round, the haul
  reach the round before, and a beam between the twins.
- Suites: combat 276 (+12), run 164 (+5), the rest unchanged. **Run bot: 63.8%** (64.5%); lost in
  Act 1 / 2 / 3: 5.3% / 22.9% / 12.6%. The warlords' legendaries help Act 3 as much as they cost.

## Decisions, lessons, open questions
- **One warlord per act, a detour, a legendary**; warlords reuse the keeper machinery
  (`_make_gate_fight`, `keepers`).
- Open: are the warlords fun? Act 3 has become the easiest act by the bot -- tighten after 031.

## Next
031: sites and events.
