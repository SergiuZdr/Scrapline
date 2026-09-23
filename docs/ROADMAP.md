# Roadmap

Status: ✅ done · 🔨 in progress · ⏭ next · ⬜ planned

Each iteration gets its own file in [iterations/](iterations/) before work starts.
Iterations further ahead are sketches and get refined as we get closer.

| # | Iteration | Goal | Status |
|---|---|---|---|
| 000 | [Rethink](iterations/000-rethink.md) | New vision, doc structure, salvage audit | ✅ |
| 001 | Archive and strip | Tag the old game, delete cut systems, the project boots clean, kept tests pass | ⏭ |
| 002 | Grid fight prototype | Pure-logic turn-based grid sim: move, attack, enemy intents, win/lose. One playable fight with mouse and touch using existing construct models | ⬜ |
| 003 | Parts drive abilities | Each part grants actions; heat; damage-type wheel; terrain on the grid; part damage (arms can be shot off) | ⬜ |
| 004 | Run loop | Region map, node types, fight → salvage → next node, save and resume mid-run | ⬜ |
| 005 | Act 1 content | Enemy roster, elites, act boss, first 25 parts, balance pass with a headless run simulator | ⬜ |
| 006 | Meta and workshop | Unlock tracking, starting crews, difficulty tiers, the between-run screen | ⬜ |
| 007 | Acts 2–3 | Two more regions, events, traders, two bosses | ⬜ |
| 008 | Feel pass | VFX, audio, animation, camera, onboarding for a first run | ⬜ |
| 009 | Ship prep | Android and desktop exports, performance on a low-end phone, Steam demo build | ⬜ |

## The first milestone that matters

**End of 003: one fight that is fun to replay.** If fights built from part-driven
abilities, intents and part damage are not interesting to replay by then, change the
combat design before building the run structure on top of it.
