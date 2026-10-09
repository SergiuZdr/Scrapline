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
| 013 | [Act 1 content](iterations/013-act1-content.md) | The Sorter at the gate (pylons, summons); the Reclaimer's drones in fights by its line; traders, watchtowers, signals (7 events); three new maps; **user play-test of 009–013** next | ✅ |
| — | [Play-test 5](playtests/2026-09-29-playtest-5.md) | The look reads as a generic engine demo; placeholders everywhere; flat panels; shove, pierce, chain, paths and undo; an outside review | ✅ |
| — | [Art direction options](plans/art-direction-options.md) | Three styles to pick from (Ink & Rust recommended), each with palette, shapes, materials, lighting, UI, interactables; one scene to prototype first | ✅ A picked |
| 014 | [Play-test 5 fixes](iterations/014-playtest-5-fixes.md) | Killing shoves throw the wreck; pierce through props; the arc's best route, heaps conduct; straighter paths; UNDO keeps the machine; fight recap; map consequence preview; deep gate pylons (bot 86.7%) | ✅ |
| 015 | [Ink & Rust: the style frame](iterations/015-ink-style-frame.md) | The fight drawn in ink: toon bands, ink lines, marks hatched by meaning, saw-blade enemy rings, the aim preview on the board, KRANG!/BOOM!, comic-panel HUD; scrap on the way (routes over piles win ties) | ✅ approved |
| — | [Play-test 6](playtests/2026-09-29-playtest-6.md) | The look approved for the whole game; a beam through a crate wall; every panel in the new design; ability text; new models | ✅ |
| 016 | [Ink & Rust everywhere](iterations/016-ink-everywhere.md) | Every screen in ink (the kit, the map with fog as unfinished drawing, the bays, portraits and part pictures); shots take the better side of a line; a quieter HUD (slim rows, ability cards that say what they do); labels that never overlap (bot 88.7%) | ✅ |
| — | [Models: three routes](plans/models.md) | From scratch (the generator), open-licence kits, or generated; the user: machines by the generator led by concept art, sites generated or from kits, proved on two models first | ✅ |
| 017 | [Models: the two routes, proved](iterations/017-models-proof.md) | The Brute rebuilt from concept art (route A, a sixth of the triangles); the workshop generated from its concept on this Mac (route C, TripoSR: TRELLIS's free demo is out of reach without an account) and cleaned for ink; both behind `--models new` | ✅ awaiting the pick |
| 018 | [Models, second pass](iterations/018-models-second-pass.md) | The user's notes on the proof: a rounded, detailed, multi-colour Brute; the workshop from TRELLIS with its detail kept; livery by maker proposed | ✅ awaiting the verdict |
| 019 | [The whole roster, made of scrap](iterations/019-the-roster.md) | All 40 parts rebuilt (rounded, patched from mismatched plate), livery by maker, the default models | ✅ awaiting the play-test |
| 020 | [Sites and the Reclaimer](iterations/020-sites.md) | Every site and the Reclaimer as TRELLIS models from concepts, four or five a day on the free allowance (`tools/gen3d/next_site.sh`); the Reclaimer a line of harvesters | ✅ awaiting the user's look |
| 021 | [Act 2: the Slag Flats](iterations/021-act-2.md) | Acts in the run; three boards, sentinels, The Pour and its flooding; bot 85.0% over two acts | ✅ awaiting the play-test |
| 022 | [Between-run progression](iterations/022-progression.md) | Unlocks only: 12 parts, two crews, two tiers by lifetime milestones; the crew and tier choice; a run saves its options | ✅ awaiting the play-test |
| 023 | [The feel pass](iterations/023-feel.md) | 16 new synthesised sounds and a yard ambience, hits drawn as ink stars, a kill's camera punch, a sound switch | ✅ awaiting the user's ears |
| — | [Play-test 7](playtests/2026-09-30-playtest-7.md) | Totals per hex, a lag, the objective from the start, shove and pierce, surf in the ambience, which robot is mine, stencils, names; Act 3 | ✅ |
| 024 | [Play-test 7 fixes](iterations/024-playtest-7-fixes.md) | One total per hex (the volley run on a copy), the aim's totals, the machine under your hand ringed, the opening card; the lag was shader compiles (measured, fixed); tied shoves, pierce aim, names, a hum not surf | ✅ awaiting the play-test |
| 025 | [Act 3: the Crucible](iterations/025-act-3.md) | Furnace flues, conduits, the Core that pulses its ring; three boards; the run ends at the Core (bot 66.0% over three acts) | ✅ awaiting the play-test |
| — | [Play-test 8](playtests/2026-10-01-playtest-8.md) | Pierce reach, the scrap mark and wandering HP, a readable loading card, overflowing cards, no rares late, easy late bosses, caches side by side, attack arrows | ✅ |
| 026 | [Play-test 8 fixes](iterations/026-playtest-8-fixes.md) | Tags at their machines and on top, a scrap bundle, arrowed/arched attacks, a 5 s card, fitted card text, a garage cover; rares and tougher Acts 2-3 (bot 56.6%) | ✅ awaiting the play-test |
| — | [Play-test 9](playtests/2026-10-01-playtest-9.md) | Main holds everything; names; easy late bosses and idle scrap; unclear unlocks; arms in bodies; the garage and bay need a design; too little content | ✅ |
| 027 | [Play-test 9 fixes](iterations/027-playtest-9-fixes.md) | Names and RENAME, a new bay and garage, an UNLOCKS screen, arms seated by measurement, escalating keepers, levels to 5 (bot 53.9%) | ✅ awaiting the play-test |
| 028 | [Objectives and yard conditions](iterations/028-objectives-and-modifiers.md) | HOLD, HACK, SURVIVE; dust storm, live wires, scrap rain, heat wave (bot 57.9%) | ✅ awaiting the play-test |
| 029 | [Weapons and legendary parts](iterations/029-weapons-and-legendaries.md) | Flamer, harpoon, shield caster; ten parts and five legendaries; the keeper's hoard (bot 64.5%) | ✅ awaiting the play-test |
| 030 | [Warlords](iterations/030-warlords.md) | The Grinder, the Magnet King, the Twin Furnaces: a detour per act with a legendary (bot 63.8%) | ✅ awaiting the play-test |
| 031 | [Sites and events](iterations/031-sites-and-events.md) | Arena, refinery, auction; twenty new signal events (bot 58.0%) | ✅ awaiting the play-test |
| — | [Play-test 10](playtests/2026-10-02-playtest-10.md) | Rares everywhere, names on the board, a bigger battlefield, pictures at sites, an easy arena, unlock missions, the parts audit and modules, interactive controls, the garage, comic style | ✅ |
| 032 | [Play-test 10 fixes](iterations/032-playtest-10-fixes.md) | 10 x 10 boards, names on the board, part cards at sites, a hard arena, rarer rares, the garage on one grid (bot 60.0%) | ✅ awaiting the play-test |
| 033 | [Parts audit and modules](iterations/033-parts-audit.md) | The power of every part by slot and rarity; twelve modules with mechanics; cores that grow with rarity (bot 56.7%) | ✅ awaiting the play-test |
| 034 | [Unlock missions](iterations/034-unlock-missions.md) | Feats from fights unlock nine of the new modules; UNLOCKS shows missions and progress | ✅ awaiting the play-test |
| 035 | [The interactive pass](iterations/035-interactive.md) | A Juice autoload: every button lifts, squashes, clicks, and says no when disabled | ✅ awaiting the play-test |
| 036 | [Comic style, a frame](iterations/036-comic-style.md) | The world printed (dots, slipped plates, grain), heavier ink, starbursts, a caption box | ✅ awaiting the user's verdict |
| — | [Play-test 11](playtests/2026-10-03-playtest-11.md) | Charge and terminals, damage types, ability previews, words that match, tags, the dock, NEW unlocks, the bosses, the comic options | ✅ |
| 037 | [Play-test 11 fixes](iterations/037-playtest-11-fixes.md) | Charge fixed and previewed, weapons with their own damage type and a type chart, totals with their parts, DETAILS, UPGRADE, what every site does (bot 57.3%) | ✅ awaiting the play-test |
| 038 | [The bosses](iterations/038-bosses.md) | The Core shielded by conduits and harder, the Pour stronger, dressed boards, bigger crimson bosses, a boss bar (bot 52.7%) | ✅ awaiting the play-test |
| 039 | [The comic, all the way](iterations/039-comic-pages.md) | Speech and thought balloons, sound-effect lettering, speed and focus lines, a panel border and page turns, caption titles, inked models, story strips | ✅ awaiting the user's look |
| — | [Play-test 12](playtests/2026-10-03-playtest-12.md) | Resources, a story that explains, garage at sites, clear unlocks, unlocked parts in the bay, models, comic panels and buttons | ✅ |
| 040 | [Play-test 12 fixes](iterations/040-playtest-12-fixes.md) | 42% fewer draws in a fight, the story rewritten, GARAGE at sites, unlocks that explain, the bench | ✅ awaiting the play-test |
| 041 | Comic panels and buttons | Three directions rendered (`shots/041/options.png`); the user picked "B with A's buttons", applied in 043 | ✅ |
| 042 | [A model for every part](iterations/042-part-models.md) | 26 generated models; modules shaped by what they do | ✅ awaiting the user's look |
| — | [Play-test 13](playtests/2026-10-03-playtest-13.md) | The comic UI pick, the tag, boss arms, the bay, the difficulty click-through, an unlock without a picture | ✅ |
| 043 | [Play-test 13 fixes](iterations/043-playtest-13.md) | Pop-art panels and pulp buttons everywhere, NEW RUN at once and a tier ladder with an ending, bosses keep their arms, the bay on three columns with whole machines and smaller arms | ✅ awaiting the play-test |
| 044 | [Models for the warlord, arena, refinery, auction](iterations/044-more-sites.md) | The four 030-031 site kinds as TRELLIS models, all in one evening | ✅ awaiting the user's look |
| 045 | [Generated machines](iterations/045-generated-machines.md) | The Brute's five parts generated (FLUX concept -> TRELLIS on free Colab -> rig) and drawn with `--models gen`; the roster waits on the user | ✅ awaiting the user's look |
| 046 | [Agent play-test fixes](iterations/046-agent-playtest-fixes.md) | The agent played Act 1: resume soft-lock, rewards that repeat, map rules, refit HP, the board under the HUD, tags, off-screen sites, big moments (bot 58.0%) | ✅ awaiting the play-test |
| 047 | [Difficulty](iterations/047-difficulty.md) | Shove arms uncommon (one on the bench); flail, snare launcher, mine layer for both sides; enemy traits earlier in Act 1 (bot 43.3%: Act 1 16.0% lost) | ✅ awaiting the play-test |
| — | [Play-test 14](playtests/2026-10-06-playtest-14.md) | The map's look, a slow UNDO, empty arenas, red live wires, slag that blinks | ✅ |
| 048 | [Play-test 14 fixes](iterations/048-playtest-14.md) | UNDO from the turn's snapshot (13 ms), arena cover and floor, the wire redrawn, slag that stays; five map directions (the user picked C) | ✅ awaiting the play-test |
| 049 | [The hex yard](iterations/049-hex-yard.md) | The run map as a diorama of the board's hexes, inked like the fight: raised site hexes, paved hex roads, move hatching on the roads you can take, zones eaten into pits | ✅ awaiting the user's look |
| 050 | [Boss tricks](iterations/050-boss-tricks.md) | The Grinder's charge, the Sorter's claw and hatch, coolant tanks, the Magnet hauling drums, the Core's open side, twins rebuilt; one shared EXPOSED opening (bot 47.3%) | ✅ awaiting the play-test |
| 051 | [Comic scrap machines](iterations/051-comic-machines.md) | The Brute redrawn as comic scrap (ChatGPT Images concepts, each part in its maker's paint, patched off other machines) and made 3D on Colab; `--gen-dir res://art/parts_gen_scrap` | ✅ awaiting the user's look |
| 052 | [The agent plays the bosses](iterations/052-boss-playtest.md) | Six keeper fights played turn by turn: two AI bugs and a claw bug fixed; braced charges, exposed keepers hold still, quench 1 turn, keepers' HP (bot 55.3%) | ✅ awaiting the user |
| 053 | [Scrap Brute fixes](iterations/053-scrap-brute-fixes.md) | Arms seated and turned, narrower shoulders, core and backpack set in; rust wears off level by level | ✅ awaiting the user's look |
| 054 | [Arm mounts](iterations/054-arm-mounts.md) | Generated arms bolted by their shoulder ring into the pauldron ends, hanging outside the legs | ✅ awaiting the user's look |
| 055 | [Crew as comic scrap](iterations/055-crew-scrap.md) | Knuckles, Needle and Relay all generated: bare frames, arms with elbows, every part its own model | ✅ awaiting the user's look |
| 056 | [Skeletons](iterations/056-skeletons.md) | Generated parts get standard skeletons: knee walk, rest pose by weapon, elbow strikes, knee-fold deaths; wrecks no longer sink | ✅ awaiting the user's look |
| — | Ship prep | Android and desktop exports, low-end phone performance, Steam demo | ⬜ |

## The first milestone that matters

**End of 006: one fight that is fun to replay.** Play-test 1 said 003's fights have
stakes but no interesting decisions. 005 and 006 exist to fix that, and they are judged
by the user playing, not by the bot. If fights built from part-driven
abilities, intents and part damage are not interesting to replay by then, change the
combat design before building the run structure on top of it.
