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
| — | [Play-test 1](playtests/2026-09-24-playtest-1.md) | The user plays the full loop: combat a chore, no build progression, bad map/refit, no tutorial | ✅ |
| 005 | [Hex combat core](iterations/005-hex-core.md) | Hex board with free aim and line of sight; the Crawler removed; scrap piles; fight objectives (rout, defend caches, salvage); machine HP carries through the run; faster animations and a new death | ✅ |
| 006 | [Fight depth](iterations/006-fight-depth.md) | Active part abilities with cooldowns; interactive terrain (barrels, pits, breakable cover); distinct enemy types; **user play-test of 005 + 006** | ✅ (play-test 2) |
| — | [Play-test 2](playtests/2026-09-25-playtest-2.md) | Terrain combos praised; map/refit unchanged, hold too small, HUD overflow, hexes touching at corners, range confusion | ✅ |
| 007 | [Play-test 2 fixes](iterations/007-playtest-2-fixes.md) | Every play-test 2 issue: hex orientation, grapple/range trust, selling and hold size, battle bar, intents, spawns, rarity, **map and refit redesign**; **user play-test** | ✅ (play-test 3) |
| — | [Play-test 3](playtests/2026-09-25-playtest-3.md) | Starting to like it; map weak and 2D, two clicks to move, no story, refit screen, charge weak, chain ignores terrain, piles not collected on the way, scrap useless | ✅ |
| 008 | [The yard and the garage](iterations/008-yard-and-garage.md) | Every play-test 3 issue: the story; a 3D map with the Reclaimer as a thing; one click to travel; the garage (machine whole in 3D, parts/stats, hover glow, sorted hold); machine levels as the scrap sink; charge, chain and pile fixes; **user play-test** | ✅ (awaiting play-test 4) |
| 009 | Build progression | Part upgrades, perks, manufacturer sets; rewards that are always a real choice; **user play-test** | ⬜ |
| 010 | Onboarding | Tutorial first fight; glossary; tap-for-info everywhere | ⬜ |
| 011 | Act 1 content | Real bosses, enemy roster with identity, parts toward 25 arms, events, the Reclaimer's drones in fights | ⬜ |
| 012 | Acts 2–3 | The Slag Flats and the Crucible, traders, events, bosses | ⬜ |
| 013 | Feel pass | Art on the board, VFX, audio, camera | ⬜ |
| 014 | Ship prep | Android and desktop exports, low-end phone performance, Steam demo | ⬜ |

## The first milestone that matters

**End of 006: one fight that is fun to replay.** Play-test 1 said 003's fights have
stakes but no interesting decisions. 005 and 006 exist to fix that, and they are judged
by the user playing, not by the bot. If fights built from part-driven
abilities, intents and part damage are not interesting to replay by then, change the
combat design before building the run structure on top of it.
