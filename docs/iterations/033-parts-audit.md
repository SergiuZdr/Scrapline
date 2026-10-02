# Iteration 033 — Parts: the power audit and modules with mechanics

**Status:** in progress
**Started:** 2026-10-02 · **Finished:** —

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
- [ ] Points model: the mean of every slot rises with rarity, common < uncommon < rare < legendary.
- [ ] Measured: no rare or legendary part measures below its slot's commons.
- [ ] verify_combat covers every new mechanic, a dry run carries them (clone), every module and core
  describes itself.
- [ ] All suites; run bot 150, 0 illegal.

## Result

## Decisions, lessons, open questions

## Next
