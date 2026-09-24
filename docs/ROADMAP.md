# Roadmap

Status: ✅ done · 🔨 in progress · ⏭ next · ⬜ planned

Each iteration gets its own file in [iterations/](iterations/) before work starts.
Iterations further ahead are sketches and get refined as we get closer.

| # | Iteration | Goal | Status |
|---|---|---|---|
| 000 | [Rethink](iterations/000-rethink.md) | New vision, doc structure, salvage audit | ✅ |
| 001 | [Archive and strip](iterations/001-archive-and-strip.md) | Tag the old game, delete cut systems, the project boots clean, kept tests pass | ✅ |
| 002 | [Grid fight prototype](iterations/002-grid-fight.md) | Pure-logic turn-based grid sim: move, attack, enemy intents, win/lose. One playable fight with mouse and touch using existing construct models | ✅ |
| 003 | [Parts drive abilities](iterations/003-parts-and-pressure.md) | The Crawler (intent pressure), per-part stats, weapon shapes, heat, wheel, terrain, shove, torn arms | ✅ |
| 004 | [Run loop](iterations/004-run-loop.md) | Region map, site types, fight → salvage → next site, Crawler HP carries, save and resume mid-run | ✅ |
| 005 | Act 1 content | A real multi-part boss, an enemy roster with identity, more parts (toward 25 arms), events, balance with `run_bot` | ⏭ (after the user's play-test) |
| 006 | Meta and workshop | Unlock tracking, starting crews, difficulty tiers, the between-run screen | ⬜ |
| 007 | Acts 2–3 | Two more regions, events, traders, two bosses | ⬜ |
| 008 | Feel pass | VFX, audio, animation, camera, onboarding for a first run | ⬜ |
| 009 | Ship prep | Android and desktop exports, performance on a low-end phone, Steam demo build | ⬜ |

## The first milestone that matters

**End of 003: one fight that is fun to replay.** *(003 is done. This now needs the user's play-test: the bot says fights have stakes, and only a person can say they are fun.)* If fights built from part-driven
abilities, intents and part damage are not interesting to replay by then, change the
combat design before building the run structure on top of it.
