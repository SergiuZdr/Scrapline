# Project memory

What was decided, why, what we learned, and what is still open. Add to it every
iteration. When a decision changes, strike the old entry through (`~~like this~~`) rather
than deleting it, and add the new entry with its date. Record **why** as well as what.

## Decisions

| Date | Decision | Why |
|---|---|---|
| 2026-09-23 | Genre is a **roguelike campaign**, not a live-service squad battler | The F2P battler did not match what the game was meant to be |
| 2026-09-23 | **Premium, single-player, offline.** No servers, IAP or gacha | Small indie scope that a solo developer can ship |
| 2026-09-23 | Combat is **turn-based grid tactics** with telegraphed enemy intents | Readable, puzzle-like fights, and turn-based play suits touch |
| 2026-09-23 | Run map is a **hybrid of an open scrapyard region and a branching node map** | Keeps the exploration feel of a region plus the clear choices of a node map |
| 2026-09-23 | Meta-progression is **unlocks only** | A win should come from skill and knowledge, not grinding |
| 2026-09-23 | **PC and mobile together** from day one | Both inputs get designed in, so a port is not a retrofit later |
| 2026-09-23 | Existing code: **decide after the vision**, and the salvage audit is the result | Salvage what fits, do not preserve systems for their own sake |
| 2026-09-23 | Workflow: every iteration produces its own .md file and updates CHANGELOG, MEMORY, plans and ROADMAP | The user asked for a step-by-step written record of the project |
| 2026-09-23 | Old game is archived with a git tag before anything is deleted | It stays recoverable, and deleting code needs no second thoughts |
| 2026-09-24 | **Crew is 3 constructs, always.** No 4th slot, not even as an unlock | User: "3 all the way". Keeps the board readable and every loss meaningful |
| 2026-09-24 | A destroyed construct leaves a **chassis wreck** that a workshop can rebuild for scrap; the parts it carried are lost | Losing a unit hurts but does not end the run |
| 2026-09-24 | **8×8 grid**, for now | Readable on a phone; revisit after play-testing 002/003 |
| 2026-09-24 | The closing front is **the Reclaimer**, an automated scrap-harvesting swarm | Gives the map pressure a face, and it doubles as an enemy faction |
| 2026-09-24 | **Light story**: site descriptions and event text, no cutscenes, for now | Solo-dev scope |
| 2026-09-24 | **Stay 3D**, with a tilted camera over the grid | The whole art pipeline already exists |
| 2026-09-24 | ADAPT code that does not compile once CUT code is gone goes to `legacy/` (ignored by Godot through `.gdignore`), not straight to deletion | It stays greppable as reference while its replacement is written; it is deleted once replaced |

## Lessons carried over from the old codebase

The old `CLAUDE.md` holds hard-won lessons. These still apply:

- **Deterministic pure-logic sim** (integer math, seeded `SimRNG`, fixed iteration order)
  still pays off: seeded runs, replayable bug reports, undo, and headless balance
  simulation.
- **Presentation never computes an outcome.** The sim emits events and the view animates
  them.
- **All tunable numbers live in `data/*.json`.**
- **Art contract lessons** (material zones, export parenting, measuring vertices instead
  of AABBs, and verifying art in the game rather than only in Blender) are unchanged and
  stay in `CLAUDE.md`.
- **One test that plays the real game** (the old `verify_loop.gd`) caught what every unit
  test missed. The new game needs an equivalent: a headless bot that plays a full run.

## Open questions

All six questions raised on 2026-09-23 were answered on 2026-09-24 (see Decisions above).

| Raised | Question | Proposed answer | Resolved |
|---|---|---|---|
| 2026-09-23 | Crew size? | 3 constructs, with an optional 4th unlock |3 all the way |
| 2026-09-23 | Can a destroyed construct be rebuilt within a run? | Yes: it leaves a chassis wreck you can rebuild at a workshop node for scrap. The parts it carried are lost |agree with the propose |
| 2026-09-23 | Grid size? | 8×8, to stay readable on a phone |8x8 for now |
| 2026-09-23 | What is the closing front? | "The Reclaimer": an automated scrap-harvesting swarm sweeping the region |agree with the propose |
| 2026-09-23 | Story delivery? | Light: site descriptions and event text, no cutscenes |agree with the propose for now |
| 2026-09-23 | Keep 3D or go 2D? | Keep 3D. The whole art pipeline exists, and a tilted camera suits a grid |agree with the propose |
