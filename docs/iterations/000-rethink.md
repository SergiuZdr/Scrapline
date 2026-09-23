# Iteration 000 — Rethink

**Status:** done
**Started:** 2026-09-23 · **Finished:** 2026-09-23

## Goal
Replace the F2P live-service vision with the game the project was meant to be, and set
up a documentation workflow that records every step.

## Scope
- In: vision, a plan per aspect, salvage audit, doc structure, iteration workflow.
- Out: any code change. Deleting code is 001.

## Steps
1. Ask about core experience, scope, what happens to existing code, and workflow.
2. Ask the roguelike specifics: combat model, run shape, meta, platform.
3. Survey the codebase: 22k lines of GDScript, 40 parts, the art pipeline.
4. Write `docs/`: VISION, ROADMAP, CHANGELOG, MEMORY, 9 plans, the iteration template.
5. Point `CLAUDE.md` at the new docs.

## Answers that set the direction
| Question | Answer |
|---|---|
| Core experience | Roguelike campaign |
| Scope | Small premium indie |
| Existing code | Decide after the vision |
| Workflow | Separate .md files (memory, changelog, detailed plans per aspect) for every step, every iteration |
| Combat | Turn-based tactics |
| Run shape | Between an open scrapyard region and a branching node map |
| Meta | Unlocks only |
| Platform | PC and mobile together |

## Acceptance criteria
- [x] VISION states the game in one sentence, with pillars and non-goals.
- [x] Every aspect has its own plan file.
- [x] Every old system is marked keep, adapt or cut.
- [x] ROADMAP lists the iterations up to ship.
- [x] CHANGELOG and MEMORY are started.

## Result
Docs written. No code touched. Open questions (crew size, rebuild rules, grid size, the
front, story, 3D vs 2D) are listed in MEMORY with proposed answers, awaiting the user.

## Next
**001 Archive and strip**: tag `archive/f2p-battler`, delete the CUT list, get the project
booting to an empty main scene, and keep the art tests green. Rewrite `CLAUDE.md`.
