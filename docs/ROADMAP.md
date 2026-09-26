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
| 008 | [The yard and the garage](iterations/008-yard-and-garage.md) | Every play-test 3 issue: the story; a 3D map with the Reclaimer as a thing; one click to travel; the garage (machine whole in 3D, parts/stats, hover glow, sorted hold); machine levels as the scrap sink; charge, chain and pile fixes; **user play-test** | ✅ (play-test 4) |
| — | [Play-test 4](playtests/2026-09-25-playtest-4.md) | A jump forward; wants a visual level-up of everything (with sourcing tested), the next three iterations, and a list of garage, map and combat fixes | ✅ |
| — | [Art sourcing spike](plans/art-sourcing.md) | Sources and skills tried in-engine and judged: Poly Haven adopted, Kenney/Quaternius as re-materialed shapes, free AI art rejected | ✅ |
| 009 | [Play-test 4 fixes](iterations/009-playtest-4-fixes.md) | Both-leaning shots, pierce overshoot, double chain, scrap carriers, a fixed hive pad with a countdown, board edges; garage scrap button, no black flash, a real bay, levelling up as an event with levels on the model; a bigger fogged map with the crew in it, a Reclaimer gauge and ghost wall, ambient life; assembling the crew at run start | ✅ |
| 010 | [The look](iterations/010-the-look.md) | Style bible and colour registry; measured contrast (1.8 → 2.2); photographed board and worn-paint machines, crew numbers; effects; portraits in the HUD; the title as a scene | ✅ |
| 011 | [Build progression](iterations/011-build-progression.md) | Perks (1 of 3 per level), tuning once per part at workshops, maker sets, salvage from three slots with a scrap option; boss fight 5 enemies (bot 88.0%) | ✅ |
| 012 | [Onboarding](iterations/012-onboarding.md) | The shakedown (a guided first fight on the real rules), a 56-term glossary with tappable words, first-time hints on eight screens, the profile | ✅ |
| 013 | Act 1 content | Real boss, the Reclaimer's drones in fights, more fight maps, more parts, events, traders, watchtowers; **user play-test of 009–013** | ⬜ |
| 014 | Acts 2–3 | The Slag Flats and the Crucible | ⬜ |
| 015 | Feel pass | Audio, camera, final VFX | ⬜ |
| 016 | Ship prep | Android and desktop exports, low-end phone performance, Steam demo | ⬜ |

## The first milestone that matters

**End of 006: one fight that is fun to replay.** Play-test 1 said 003's fights have
stakes but no interesting decisions. 005 and 006 exist to fix that, and they are judged
by the user playing, not by the bot. If fights built from part-driven
abilities, intents and part damage are not interesting to replay by then, change the
combat design before building the run structure on top of it.
