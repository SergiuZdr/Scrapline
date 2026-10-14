# Iteration 077 — Every effect, before and after

**Status:** done; waiting for the user's picks
**Started:** 2026-10-14 · **Finished:** 2026-10-14
**Answers:** the user, after 076: "I like the direction; show before and after (with names) for every
effect you make; I'll tell you which to change".

## Goal
A named before/after sheet of every effect in the fight, so the user picks which ones are redrawn.

## Scope
- In: `tools/shot_effects.gd` (every `BattleVFX` effect beside a machine), `tools/shot_trails.gd --legacy`
  (the shots as drawn before 074), the two sheets.
- Out: changing any effect (the user picks first).

## Result
- Before: a scratch copy of `902fe6f` (before 074) for the `BattleVFX` effects; `--legacy` for the shots
  (the class's strike, the tracer or lobbed ball from the chest). After: `main`.
- `shots/077_efecte_inainte_dupa.png`: E1-E18 (muzzle flash, impact, impact star, sparks, smoke, blast
  start and end, colour burst, machine destruction, shards, dust, ground lines, crush, scorch, arm break,
  core blast, wreck landing, clank); changed so far: E5 smoke, E7 blast end (its smoke).
- `shots/077_urme_inainte_dupa.png`: T1-T13, each ranged arm before, after in flight, after on impact.
- No game code changed; no tests needed beyond the tools running (18 + 39 pictures).

## Decisions, lessons, open questions
- **Every effect change gets a named before/after sheet; the user picks which to redo.**

## Next
- Redraw the effects the user picks, in the 076 style.
