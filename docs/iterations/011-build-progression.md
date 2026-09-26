# Iteration 011 — Build progression

**Status:** in progress (batch 009–013; play-test after 013)
**Started:** 2026-09-26 · **Finished:** —
**Answers:** play-test 1 ("no build progression"), play-test 3 ("scrap seems pretty useless"),
play-test 4 ("the level-up doesn't sell the robot getting stronger"). Follows the design already
written in [constructs-and-parts](../plans/constructs-and-parts.md): tuning, not part levels.

## Goal
A crew is BUILT over a run, not only re-equipped: every level-up is a choice of what the machine
becomes, every workshop can re-cut a part one of two ways, parts from the same maker add up to
something, and every salvage screen offers options that pull in different directions.

## Scope
- In:
  - **Perks.** A level-up still adds HP, and now also offers **three perks** (seeded, only ones
    that do something for this machine); the player takes one. `LEVEL_UP` carries the choice.
  - **Tuning** (the plan's "tuned once at a workshop, one of two upgrades"). Every part has two
    tunings in its JSON. A workshop tunes a fitted or held part for scrap by rarity; a tuned part
    is `id:a` / `id:b`, named "Name+", and can never be tuned again. `TUNE` is a run action.
  - **Makers and sets.** Every part has a maker (Kessler Mining, Arclight Electric, Vektor
    Ballistics, Cinder Foundry). Two parts from one maker on a machine give its 2-piece bonus,
    three give the 3-piece one too. Player machines only.
  - **Rewards that are a real choice.** Salvage offers three parts from three different slots,
    one of them from a maker the crew already runs (so sets can be built on purpose), and a scrap
    alternative instead of LEAVE IT. An elite's guaranteed part comes already tuned.
  - UI: the perk pick in the garage (then the level-up event, with the perk named); set lines and
    perks on the garage and in STATS; maker and tuning on every part card and socket row; set
    lines in the assembly bay; a TUNE panel at workshops; the reward screen's scrap option and
    set verdicts.
  - The run bot uses all of it (picks perks, tunes at workshops, takes scrap over useless parts).
- Out (deliberately):
  - Sets on enemies: enemy loadouts are rolled slot by slot, so a set on one would be an
    accident rather than a design. Authored elites and bosses (013) can wear real sets.
  - Part levels (Mk II/III): one tuning per part, as the plan says; it keeps copies different.
  - New art: tuning, perks and sets are numbers and words this iteration, not geometry.

## Design

**One way numbers reach a machine.** `CombatSetup._build_unit` already sums chassis, core and
module blocks. Levels, perks and sets become one more additive **bonus grid** in the spec
(`hp, move, heat_cap, vent, armor, damage, heat, range, melee, cooldown, chain` plus the flags
`unshovable, move_after_attack`), applied in one function. `RunSim.max_hp` reads the unit
`CombatSetup` builds, so the garage, the run and the fight cannot disagree about HP.

**Tuned parts are content, not state.** `ContentDB` expands each part's two tunings into real
entries (`ar_hammer:a`, with `base`, `tuned`, `tune` and the merged `grid`), so every lookup
that already works on a part id works on a tuned one. Pools and the assembly bench skip them;
visuals (model, livery, thumbnail) resolve the base id through `PartTuning.base_of`.

**Heat per attack never goes below zero** (a tuning can take heat off a weapon; a scanner with a
cold core must not cool the machine by firing).

| Maker | Makes | 2 pieces | 3 pieces |
|---|---|---|---|
| Kessler Mining | heavy frames, kinetic and bile cores, hammer, maul, plating | +2 HP | +1 armour |
| Arclight Electric | light frames, EMP cores, pulse emitter, heat and overdrive modules | vents +1 | abilities a round sooner |
| Vektor Ballistics | marksman frames, the courier, dynamo, every gun | +1 move | +1 range |
| Cinder Foundry | the hauler and reaper, thermal and solvent cores, claws, saw, mortar, overdrive | +2 heat cap | +1 damage |

## Steps
1. Sim: bonus grid, heat clamp, cooldown cut; `PartTuning` (expand, base_of); makers and sets in
   `CombatSetup`; `RunSim`: perks (offer, `LEVEL_UP` with a choice), `TUNE`, rewards (distinct
   slots, maker bias, tuned elite part, scrap option), `max_hp` from the unit. Data: tunings on
   all 40 parts, `makers.json`, `perks.json`, run.json numbers. Tests.
2. Bot: perks, tuning, scrap over useless parts. Run bot and balance; tune numbers.
3. UI: part cards and socket rows (maker, tuning), garage (perk pick, sets, perks, STATS),
   workshop TUNE panel, reward screen, assembly set lines. UI tests.
4. Screenshots, docs, merge.

## Acceptance criteria
- [ ] verify_run: every part has two tunings and both variants load; pools and bench hold no tuned
  part; `TUNE` only at a workshop, costs scrap by rarity, changes the socket or hold entry, never
  twice, and the fight unit shows it; a perk offer is three distinct eligible perks, the same on
  replay, and only an offered perk can be taken; a machine's sets change its numbers (2 and 3
  pieces), enemies get none; reward options are three different slots; skipping a fight's
  salvage pays scrap; an elite's first option is tuned; `max_hp` equals the fight unit's.
- [ ] verify_combat: heat per attack is never negative; a cooldown cut shortens an ability's wait.
- [ ] verify_run_ui: level up through the perk pick; tune a part at a workshop through the panel;
  take scrap instead of salvage.
- [ ] run_bot 150 and balance_fights 600 recorded; win rate not above 92% (it was 89.3%).
- [ ] Screenshots: the perk pick, the garage with sets and perks, the workshop tune panel, the
  reward screen.

## Result
(filled in on completion)

## Decisions, lessons, open questions
(filled in on completion; also copied into MEMORY.md)

## Next
012 Onboarding: the new words (perk, tune, maker, set) join the glossary it builds.
