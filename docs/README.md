# Scrapline — project documents

These files describe the game and record how it gets built. They are updated at the end of **every iteration**. If code and these docs disagree, the docs are stale and fixing them is part of the work.

| File | What it holds | When it changes |
|---|---|---|
| [VISION.md](VISION.md) | What the game is, who it is for, and what it is not | Only when a core decision changes. Every change gets logged in MEMORY.md |
| [ROADMAP.md](ROADMAP.md) | Ordered iterations with a status for each | Every iteration: its status, plus the next one refined |
| [CHANGELOG.md](CHANGELOG.md) | What changed, iteration by iteration, newest first | Every iteration: one entry |
| [MEMORY.md](MEMORY.md) | Decisions and the reasons for them, lessons learned, open questions | Whenever something is decided, learned or left open |
| [plans/](plans/) | One detailed design/plan per aspect of the game | When the aspect is worked on |
| [iterations/](iterations/) | One file per iteration: goal, scope, steps, acceptance, result | Written before the work starts, closed out after |

## Plans by aspect

| Plan | Aspect |
|---|---|
| [plans/combat.md](plans/combat.md) | Turn-based grid tactics: turns, intents, heat, damage, terrain |
| [plans/constructs-and-parts.md](plans/constructs-and-parts.md) | How parts become units and abilities; part damage; salvage |
| [plans/run-structure.md](plans/run-structure.md) | The scrapyard region map, node types, acts, run pacing |
| [plans/meta-progression.md](plans/meta-progression.md) | Unlocks between runs, difficulty tiers |
| [plans/story.md](plans/story.md) | The world: the Reclaimer, the key, the Crucible; the three yards; voice |
| [plans/enemies-and-ai.md](plans/enemies-and-ai.md) | Enemy roster, intents, elites, bosses |
| [plans/platform-and-ui.md](plans/platform-and-ui.md) | PC and mobile together: input, layout, screens |
| [plans/art-and-audio.md](plans/art-and-audio.md) | Visual direction and what carries over from the existing pipeline |
| [plans/tech-architecture.md](plans/tech-architecture.md) | Code structure, determinism, save/load, testing |
| [plans/salvage-audit.md](plans/salvage-audit.md) | Keep, adapt or cut for every system in the old codebase |

## The iteration loop

Every step we take follows the same six moves:

1. **Plan.** Create `iterations/NNN-short-name.md` from the template in
   [iterations/_TEMPLATE.md](iterations/_TEMPLATE.md), with goal, scope, steps and
   acceptance criteria. Agree on it before building.
2. **Build.** Do the work in small commits.
3. **Verify.** Run the acceptance checks written in step 1 and record the results in the
   iteration file, including the ones that failed.
4. **Log.** Add a CHANGELOG entry.
5. **Remember.** Add to MEMORY.md every decision, every lesson, and every question that
   is still open.
6. **Re-plan.** Update the affected `plans/*.md` and ROADMAP.md, and refine the next
   iteration.

