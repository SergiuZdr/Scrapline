# Iteration 033 — Parts: the power audit and modules with mechanics

**Status:** done -- waiting for the user to play it
**Started:** 2026-10-02 · **Finished:** 2026-10-02

(This plan was written after the first code: the audit and the new mechanics were built while
032's bot ran. Recorded here so the order is not hidden.)

## Goal
Answer play-test 10's "analyse how the power spike goes for each category and between
categories", and fix what it finds: rarity must mean something in every slot, and modules (the
thinnest slot, all stat sticks) get parts that change how a machine plays.

## Scope
- In: a points model of every part (`tools/part_points.py`) and a measured one
  (`tools/part_power.gd`: paired bot fights, the part on a reference crew vs without); the
  analysis in `docs/plans/parts-power.md`; new module mechanics in the sim (thorns, regen, kill
  heal, last stand) and weapon traits a core or module can lend (pierce and arc on shots, shove
  and tears on melee, mark on everything, plus the role traits); twelve new modules; cores
  reworked so a rare core is more than a damage type; the weakest parts fixed (Targeting Suite,
  Heat Governor, the Aegis tuning's wrong sign).
- Out: new models (new modules borrow existing ones, as the legendaries do); unlocking the new
  parts (034 puts some behind missions).

## Steps
1. The two measures, run over the 031 roster.
2. Mechanics in `GridUnit` / `CombatSetup.apply_bonus` / `CombatSim` (`REPAIRED`, `LAST_STAND`),
   drawn on the board, described by `PartText`, in the glossary.
3. Data: modules, cores, fixes. Re-measure.
4. The analysis document; tests; bot.

## Acceptance criteria
- [x] Points model: the mean of every slot rises with rarity, common < uncommon < rare < legendary.
- [ ] Measured: no rare or legendary part measures below its slot's commons -- NOT MET as a test: the measurement could not separate parts (see Result).
- [x] verify_combat covers every new mechanic, a dry run carries them (clone), every module and core
  describes itself.
- [x] All suites; run bot 150, 0 illegal.

## Result

- The analysis is [`docs/plans/parts-power.md`](../plans/parts-power.md): mean points by rarity,
  before and after, and every part. Before: a rare core added 1.5 over a common, a rare module
  2.0 (a rare chassis 5.2, a rare arm 3.6); the rare Targeting Suite was the weakest module. After:
  every slot rises with every rarity (cores 3.4 / 4.9 / 7.0 / 11.0, modules 3.1 / 4.2 / 5.6 / 9.8).
- The measurement (`tools/part_power.gd`, 40 paired trials a part, 15 processes): the reference
  crew won every trial with every part, so it measured HP per fight only, within +-1.4, mostly
  noise. Its loudest readings agreed with the model (Flamer -0.95, Shield Caster -0.50, Lance
  +1.35, Coilgun +1.27) and the two weak arms were buffed (Flamer 3 damage, Shield Caster range 4,
  no heat).
- Mechanics: `GridUnit.thorns/regen/kill_heal/last_stand/stood` (copied in `copy()`), `REPAIRED`
  and `LAST_STAND` events drawn on the board (+N HP, HOLDS!), `CombatSetup.EXTRA_KEYS` read from a
  core or module through `apply_bonus` (`pierce`, `arc`, `mark`, `shove`, `tears` on the weapons).
  Twelve new modules (25), seven cores reworked, Targeting, Governor and the Aegis tuning fixed.
  Glossary: thorns, repairs, last stand.
- Found while doing 034: model aliases do not chain -- Sprint Pistons and Spiked Plating pointed
  at parts that themselves borrow a model, so no model existed. Fixed; verify_combat checks every
  part's model now.
- Suites: combat 288 (+12), run 175, meta 59, save 15, assembly 140, combat_input 22, run_ui 49,
  onboarding 39. **Run bot 56.7%** (032: 60.0%), 0 illegal; lost by act 10.7 / 22.4 / 18.3%;
  rare+ fitted at the last gate 5.7 of 15. Enemies roll the new modules and cores too.

## Decisions, lessons, open questions
- Modules are the slot that changes HOW a machine plays; cores carry a damage type and, from
  uncommon up, a trait. Rarity buys a trait, not only a number.
- Lesson: a measurement that cannot fail is not one. The paired test was built, run for an hour,
  and could not separate parts because the bot wins single fights; the run bot's losses come from
  damage carried across fights. Calibrate a harness against a known difference (a +7 HP frame)
  before trusting its zeros.
- Lesson: aliases do not chain; anything that resolves a reference once must be tested for every
  entry, not for the ones written first.
- Open: do the new modules feel different in the hand? Is the game too hard at 56.7% now enemies
  carry them (Act 2 lost 22.4%)?

## Next
034: missions unlock most of the new modules.
