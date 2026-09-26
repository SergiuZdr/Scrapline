# Iteration 011 — Build progression

**Status:** done (batch 009–013; play-test after 013)
**Started:** 2026-09-26 · **Finished:** 2026-09-26
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
- [x] verify_run: every part has two tunings and both variants load; pools and bench hold no tuned
  part; `TUNE` only at a workshop, costs scrap by rarity, changes the socket or hold entry, never
  twice, and the fight unit shows it; a perk offer is three distinct eligible perks, the same on
  replay, and only an offered perk can be taken; a machine's sets change its numbers (2 and 3
  pieces), enemies get none; reward options are three different slots; skipping a fight's
  salvage pays scrap; an elite's first option is tuned; `max_hp` equals the fight unit's.
- [x] verify_combat: heat per attack is never negative; a cooldown cut shortens an ability's wait.
- [x] verify_run_ui: level up through the perk pick; tune a part at a workshop through the panel;
  take scrap instead of salvage.
- [x] run_bot 150 and balance_fights 600 recorded; win rate not above 92% -- 88.0%, after one dial.
- [x] Screenshots: the perk pick, the garage with sets and perks, the workshop tune panel, the
  reward screen (`shots/011_sheet.png`).

## Result

| Suite | Result |
|---|---|
| verify_run | **107** passed (70): levels with perks, perks' effects and eligibility over 59 seeds, tuning (variants, pools, bench, costs, once, hold, HP now), sets (2/3 pieces, tuned parts count, enemies none, Vektor), salvage (three slots over 59 seeds, the maker lean 80%+, a tuned elite part, the scrap option) |
| verify_combat | **140** passed (134): heat never below 0, cooldown cut and its floor, chain only on arcing weapons, flags; the stats test now names the sets its fixtures carry |
| verify_run_ui | **42** passed (33): the perk pick (nothing bought until a pick, the pick kept), the tune bench by clicks (a tuned row becomes a label), TAKE 8 SCRAP INSTEAD |
| verify_combat_input / save / assembly / animation | 20 / 14 / 100 / 34 passed |

**Balance.** The new systems made the crew stronger, as intended -- the default crew now carries
sets (Brute: Kessler 3 and Cinder 2; Strider: Vektor 3 and Arclight 2) and HP going into the boss
rose from 24.3 to 29.6. Four dials were tried side by side (`run_bot.gd --set`, 150 runs each):

| Variant | Won |
|---|---|
| 011 as built | 92.7% |
| enemies 5 from column 6 | 92.7% |
| elite / boss HP +2 / +3 | 92.0% |
| **boss fight 5 enemies (was 4)** | **87.3%**, kept |

Final run bot: **88.0%** won (89.3% after 009), **0 illegal actions**, 8.2 moves and 5.7 fights a
run, 3.9 levels bought and 0.3 parts tuned a run, 27 scrap unspent at the end; 12 of 18 losses
at the gate. balance_fights (random squads, now with sets): **89.5%** (87.3%); ripper -4.1 and
coil -3.3 are still the weakest arms, railgun +2.8 the strongest.

### Found on the way
- **The bot hoarded a whole rebuild in reserve and tuned 0.1 parts a run** -- too rarely to test
  the rule. It keeps half a rebuild for tuning now (0.3 a run). Scrap is genuinely contested:
  levels, tuning, repairs, rebuilds and hold room all want it (play-test 3's "scrap is useless").
- **Five tools iterated every part id** (balance, animation, assembly checks, gait preview) and
  would have looked for `ar_hammer:a.glb`. Anything that pictures or samples parts skips tuned ones.

### Different from the plan
- The plan doc said synergies come "rather than set bonuses". Sets were built because, with no
  pull toward a build, every salvage pick was a rarity comparison (play-test 1: "no perks, no
  sets"). Recorded as a decision.
- Makers are words and pips, not colours: the colour registry has no free colour, and a maker
  is not a signal the player must read at 40 px in a fight.
## Decisions, lessons, open questions
- **Sets are player-only**; enemy loadouts are random, so an enemy set would be an accident.
  Authored elites and bosses (013) can wear them on purpose.
- **Level 2's +1 damage became a perk** (Hot Loads): damage on every level was the dial that took
  the bot from 85% to 94% in 008; now it is one choice among three.
- **The boss fight has 5 enemies** (was 4): the crew arrives with more HP, so the gate carries the
  difficulty. Open question for the play-test: is a gate that decides two thirds of the losses a
  climax or a wall? 013 replaces it with a real boss anyway.

## Next
012 Onboarding: the new words (perk, tune, maker, set) join the glossary it builds.
