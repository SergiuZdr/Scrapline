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
| 2026-09-24 | Undo covers every action in the current turn, attacks included | No damage randomness, so undo reveals nothing; forgives phone misclicks |
| 2026-09-24 | Attacks take two taps (aim, confirm); moves take one | The costly action gets the confirmation; the cheap one stays fast |
| 2026-09-24 | Tap priority: friendly unit → select, reachable tile → move, attack line → aim/fire | Any other order makes some action unreachable (see Lessons) |
| 2026-09-24 | Enemy intents are a DIRECTION fired from wherever the attacker stands at resolve | Stepping into a line takes the hit and stepping out lets it fly on, which gives body-blocking and friendly fire for free |
| 2026-09-24 | **The Crawler**: an immobile, unarmed objective on every board. Losing it loses the fight; in the run its HP will carry between fights (like FTL's hull) | Telegraphed attacks need something that CANNOT dodge, or dodging is free (002: 6 enemy damage per fight) |
| 2026-09-24 | ~~Tap priority select > move > aim~~ → **explicit modes**: select = move mode; a weapon button arms it; tap target to aim, again to fire; tap the weapon again to disarm | Lob landing tiles overlap move tiles; no priority can tell which the player meant |
| 2026-09-24 | Every construct stat comes from its five parts' `grid` blocks plus a role trait from `rules.json` | "Your machines ARE their parts" (VISION); no stat sheets to drift from the parts |
| 2026-09-24 | Enemies ignore heat | Heat is the player's resource; enemy heat would be another hidden state to read |
| 2026-09-24 | Arms tear right-then-left on hits ≥ 5 or any ripper hit; no facing | Learnable in one fight; facing would be one more thing on a phone screen |
| 2026-09-24 | Constructs are repaired after every fight and torn arms are restored; only a DESTROYED construct loses its parts (it keeps its chassis as a wreck) | Attrition lives in two visible things, the Crawler's HP and wrecks, not in per-construct bookkeeping |
| 2026-09-24 | The Reclaimer consumes a column every 2 moves; each move made FROM consumed ground costs the Crawler 3 HP | Pushes the player onward with a number instead of an instant loss |
| 2026-09-24 | A run is one action list; a fight is reported as ITS action list, which the run replays | The save cannot disagree with the game, and a run cannot be told a false fight result |
| 2026-09-24 | Enemy squads are generated from the parts pool by column and site type | Every run differs; authored rosters come with 005 |
| 2026-09-24 | Gold marks rare salvage | The premium currency it was reserved for no longer exists |
| 2026-09-24 | **PLAY-TEST 1 (see `docs/playtests/2026-09-24-playtest-1.md`)**: combat is a chore, the run has no build progression, jargon is unexplained, the map and refit screens are bad | The first human play. It overrides the bot's numbers |
| 2026-09-24 | ~~The Crawler~~ → **REMOVED** (user) | Unclear what it was for; an escort is not a decision |
| 2026-09-24 | **Hex grid** (user), with **free aim**: ranged weapons target any hex in range with line of sight; shots travel the hex line and pierce/stop along it; melee reaches all 6 neighbours | Square lines left targets unreachable (PT1-2). Hex alone still leaves off-axis tiles at range, so aim is free |
| 2026-09-24 | **Run attrition = machine HP carries between fights** (proposed with the Crawler's removal); repaired at workshops and by scrap piles; the run ends when all three machines are wrecks | The Crawler was the run's health bar; something has to be |
| 2026-09-24 | Destroyed machines become **scrap piles** (walkable), not blocking wrecks; either team can collect one (user's suggestion, PT1-4) | A wreck that blocks for no visible reason reads as a bug; a pile is a contested resource |
| 2026-09-24 | Progression: **perks (relics), manufacturer sets, part upgrades, machine levels** — all four (user) | "Not a true roguelike" (PT1-6): a run must build toward something |
| 2026-09-24 | Fight depth: **active part abilities, interactive terrain, distinct enemy types, fight objectives** — all four (user) | "A boring chore" (PT1-1) |
| 2026-09-24 | Process: **every iteration that changes how the game plays ends with the user playing it** | Three iterations passed on bot numbers alone; the bot cannot measure fun or clarity |
| 2026-09-24 | **Previews are dry runs**: an attack/ability is executed on `CombatState.clone()` and diffed | With explosions, chains, pits and bombers only the real rules can say what happens; a second calculation would eventually lie |
| 2026-09-24 | Abilities are player-only; enemies express threat through intents and kinds | An enemy ability the player cannot see coming breaks the telegraph promise |
| 2026-09-24 | Crate walls (and barricades) break into nothing, not rubble | Simpler, and a broken wall opening a lane is itself a decision |
| 2026-09-25 | Everything merged to `main` (user); iterations continue on branches and merge when done | The user asked |
| 2026-09-25 | **Reported problems are fixed before new features**, and anything deferred is told to the user in so many words | PT1-8/9 were quietly scheduled for 008 and the user saw them unchanged (PT2-1) |
| 2026-09-25 | **The hold starts at 8**; a workshop sells +2 room for 10, then 16, then 24 scrap. Any part can be **scrapped** outside a fight for 3 / 6 / 10 by rarity | PT2-2: 6 was too small and useless parts could not be got rid of |
| 2026-09-25 | Taking salvage is **always allowed**. An overfull hold blocks TRAVEL instead, until something is fitted or scrapped | PT2-3: refusing the pick left "leave it" as the only choice; blocking travel keeps the choice with the player |
| 2026-09-25 | The map **previews before it travels**: first tap shows the site, its direction and what the move costs; TRAVEL (or a second tap) goes | PT1-8: the player could not tell forward from sideways, or what a move would cost |
| 2026-09-25 | **A boss fight that is not won ends the run**, even with the crew alive | There is no road past the gate and the road back is reclaimed; the run bot found crews stranded there (3 in 150) |
| 2026-09-25 | Refit is its **own screen** (opaque), with drag and drop plus tap-then-tap | PT1-9/PT2-1; the map showing through a translucent sheet read as clutter |
| 2026-09-24 | ADAPT code that does not compile once CUT code is gone goes to `legacy/` (ignored by Godot through `.gdignore`), not straight to deletion | It stays greppable as reference while its replacement is written; it is deleted once replaced |
| 2026-09-25 | **The story**: the Reclaimer is a Combine harvester still obeying "reclaim all material"; the crew carries a stolen shutdown key to the Crucible and the Reclaimer follows the key. Enemies are spiked rigs (hence your parts); enemy kinds are its drones | PT3-4 asked for lore, a mission and a Reclaimer with a purpose. Chosen so every existing mechanic has a reason (`plans/story.md`) |
| 2026-09-25 | **The map is 3D and one click travels**; hover previews on PC, and the direction and cost are written on the site for touch | PT3-2/3 |
| 2026-09-25 | **Machine levels are the scrap sink** (not part upgrades): they need no per-part state, and the user had already chosen machine levels as progression | PT3-9. Part upgrades stay in 009 |
| 2026-09-25 | **Charge works after moving**, scaling with distance run | PT3-6: charging instead of moving was weaker than a move and an attack |
| 2026-09-25 | Piles are collected along the whole path, by both teams | PT3-8 |
| 2026-09-25 | **Art comes from tested sources**: Poly Haven (CC0) textures and HDRIs adopted; Kenney/Quaternius only as re-materialed shapes; free AI art rejected; our Blender pipeline for anything bespoke (`plans/art-sourcing.md`) | Play-test 4 asked for the best sources AND for their work to be judged: each was tried in the game with `tools/art_probe.gd` |
| 2026-09-25 | **The user batched 009–013** (fixes, the look, progression, onboarding, Act 1 content) with one play-test at the end | Play-test 4: "the game needs desperately the next 3 iterations" |
| 2026-09-25 | Shots and grapples take the **clear one of two equal leanings** (both teams) | PT4-9: a fixed nudge always leaned the same way, into heaps and allies |
| 2026-09-25 | Piercing overshoots 2 hexes at half damage; the coil arcs twice; enemies **carry scrap or not** (55%, seeded, shown) | PT4-10/11 |
| 2026-09-25 | **The hive's pad stays put** and counts down, warning the turn before | PT4-12: re-marking beside a walking hive made the site wander |
| 2026-09-25 | **9-column region under fog**, a following camera, the crew walking it; the Reclaimer shown as a **gauge and a ghost wall**, not text | PT4-5/6/7 |
| 2026-09-25 | **Assembly at run start** from a bench (commons free, default uncommons once): one `ASSEMBLE` action, before the first move | PT4-14 |
| 2026-09-25 | **Levels show on the model** (armour, chest plate, stacks, a bigger frame) and levelling up is an event | PT4-4 |
| 2026-09-26 | **The colour registry**: blue = yours, red = danger, amber = your action, copper = machine condition, green = a gain, purple = something being built, hazard ochre = overdrive, core lenses = damage type, rarity colours only on parts | 010, the art-direction skill: one meaning per signal colour. Caches moved from amber to blue |
| 2026-09-26 | **Surfaces are photographed, tinted, low-frequency; machines stay the brightest solid things** — and that is measured (`measure_contrast.gd`), not argued | 010: fidelity creep is the named risk of photo textures |
| 2026-09-26 | **Build progression: perks on level-up (1 of 3), tuning once per part at workshops (the plan's design), maker sets (2 and 3 pieces)**, all through one additive bonus path; salvage from three slots with a scrap option | Play-test 1: "no perks, no sets, nothing that makes a build strong"; play-test 4: levels did not feel like the machine becoming something |
| 2026-09-26 | **Sets are for player machines only** | Enemy parts are rolled per slot, so an enemy set would be noise; authored enemies can wear sets on purpose |
| 2026-09-26 | **Boss fight 5 enemies** (was 4), after trying four dials side by side | The crew now reaches the gate with 29.6 HP (24.3); the bot went 92.7% -> 88.0% |
| 2026-09-26 | **The tutorial is the real fight with a coach on top**, stepping on what happened in the event stream | It cannot teach anything the rules do not do, and a player acting out of order is never stuck |
| 2026-09-26 | **Skipping the shakedown counts as played**; it stays on the title as TUTORIAL | Offered once, never nagging |

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

## Lessons (from our own iterations)

| Date | Lesson |
|---|---|
| 2026-09-24 | `CLAUDE.md` is listed in `.git/info/exclude`, so edits to it are never committed. Anything that must be versioned belongs in `docs/` |
| 2026-09-24 | `--shot` used to be copied into each scene. It is now a `DevShot` autoload, so a new screen can be photographed with no code |
| 2026-09-24 | Keep docs as clean UTF-8. One invalid byte from an editor made Python tooling crash on `docs/README.md` |
| 2026-09-24 | `verify_animation.gd` prints an ObjectDB leak warning at exit. It is harmless for now, but check whether it predates 001 when the rig is next touched |
| 2026-09-24 | A melee unit's adjacent tiles are both "move" and "attack line". With attack first, a brawler could not step forward. Any overlapping tap meanings need an explicit priority |
| 2026-09-24 | `push_input(event)` treats positions as window coordinates; tests must pass `true` for viewport-local points. The headless root viewport is 1920×1920 |
| 2026-09-24 | A "put it back" check passes vacuously if nothing moved. Assert the precondition first |
| 2026-09-24 | `--check-only` does not know autoloads, so `Identifier not found: Audio` is a false positive. Launch the scene to be sure |
| 2026-09-24 | Set Control anchors AFTER `add_child`; before, the preset is computed against a zero-size parent |
| 2026-09-24 | **Free dodging kills intent pressure.** Bot fight: enemy set 12 intents and dealt 6 damage total, against 42 from the player |
| 2026-09-24 | Only a piercing weapon hits through a blocker, so shielding is a per-weapon question. Tests and the bot must know which lines can be blocked |
| 2026-09-24 | A HUD that rebuilds its buttons on refresh invalidates any reference held across a refresh. Look controls up again after every tap |
| 2026-09-24 | A script error inside a test coroutine stops it without quitting: the test hangs and looks slow, not failed. Every coroutine test gets a watchdog |
| 2026-09-24 | With the bot winning most fights, raw per-arm win rates all sit near the mean. Judge arms by their offset from the average, not a fixed band |
| 2026-09-24 | Enemy damage share understates pressure against a bot that dodges well; Crawler losses are the clearer signal |
| 2026-09-24 | zsh does not word-split an unquoted `$var` in a command line: use `${=var}` or the arguments arrive as one string |
| 2026-09-24 | JSON has no integers. A saved action comes back with floats and is a different action unless every number is turned back into an int (`RunStore._ints`) |
| 2026-09-24 | Bot route preferences change pacing a lot: preferring scrapyards gave about 1 fight a run. Tool biases show up as design numbers, so read run_bot results with the bot's policy in mind |
| 2026-09-24 | A hex line must be drawn in integers (fixed-point cube lerp + a constant nudge + floor-correct rounding) or the sim is no longer deterministic |
| 2026-09-24 | Free aim + tile-targeted intents make dodging free again: 005 bot runs won 100%. Objectives (defend) are the only pressure until enemy types and terrain arrive (006) |
| 2026-09-24 | Spawn fight models from the SETUP when animating from event 0; the state after `start` already has the enemies' opening moves applied |
| 2026-09-24 | Validate authored AND generated fights for overlapping starts: a clash does not crash, it just draws wrong |
| 2026-09-24 | The bot barely uses the new tools, so bot numbers after 006 are a FLOOR on player power. A smarter bot (ability use) is needed before trusting balance numbers again |
| 2026-09-25 | **A mesh has an orientation of its own.** `CylinderMesh` with 6 sides is already pointy-top; the extra 30° turn drew a flat-top board over pointy-top maths, so hexes met at their corners and every distance looked one short (PT2-10, and most of PT2-5/7). Check a board from its RENDERED geometry, not from the maths |
| 2026-09-25 | "Works on an ally, not on an enemy" was a hidden rule (anchors cannot be moved) plus a board that lied about distance. A rule the player cannot see reads as a bug: tag it (ANCHORED) |
| 2026-09-25 | Rebuilding a Control tree during a drag frees the node being dragged. During a drag only restyle; rebuild deferred, after the drop |
| 2026-09-25 | A "the road goes on" rule has to hold at the END of the road. Losing the boss objective with the crew alive left the run with no legal action; only the whole-game bot found it |
| 2026-09-25 | Measure a balance change by switching pieces OFF on the same seeds. "Levels made it easy" was half right: with levels priced out the run was still 8 points easier than 007, from pile scrap paying for repairs |
| 2026-09-25 | A coil that only arcs unit to unit never touches a drum, and nothing on screen says so: the player reads a missing interaction as a bug (PT3-7). When a mechanic meets terrain, the default must be that it interacts |
| 2026-09-25 | Leftover vocabulary lies quietly: `PartText` kept 002's "line" shape and printed every shot weapon as a "lob" for three iterations. Text generated from data needs a test or a screenshot that someone reads |
| 2026-09-25 | A CPUParticles3D pre-simulated before its parent is placed leaves its puffs where it was built. Set `local_coords` (and a soft texture, or every puff is a hard square) |
| 2026-09-25 | Test the 3D map through the real input path: `push_input` a mouse event at `YardView.screen_pos`. A test that called `_choose` directly would pass with picking broken |
| 2026-09-25 | **Judge an art source in the game, not by its reputation.** The same vignette rendered twice (`art_probe.gd`) settled in minutes what reviews could not: Poly Haven textures lift everything, its saturated props break the palette, free AI art ignores the prompt |
| 2026-09-25 | Respect `skillOverrides`: a skill switched off for Claude is not read around by opening its files. Say which ones are off and let the user decide |
| 2026-09-25 | `BILLBOARD_PARTICLES` discards the particle's scale unless `billboard_keep_scale` is on: every "tiny" mote was a 1 m square |
| 2026-09-25 | A fog tinted like the ground it covers is invisible, however correct the shader. Test an effect on a contrasting floor to know it works, then give it contrast in the game |
| 2026-09-25 | A counter that a first hit spends (`pierce_left`) must not also decide something about later hits. The overshoot test caught the far unit taking full damage |
| 2026-09-25 | Headless frames outrun real time: wait for tweened things with timers, not frame counts |
| 2026-09-25 | A class a `--script` tool names must not reference an autoload; pass what it needs in |
| 2026-09-26 | **Photographed texture raised contrast rather than lowering it**, because it went in darker and lower-frequency than the flat colours it replaced. Measure before and after; intuition said the opposite |
| 2026-09-26 | **The roster generator does not reproduce the committed roster.** Regenerating changed heads and dropped most pauldrons. Compare old and new thumbnails before trusting any regeneration, and restore on mismatch |
| 2026-09-26 | A photograph carries its own hue: rusty RED paint multiplied by a yellow livery is brown. Bake it to a hue-free wear map (white paint, rust-orange chips) and let the livery colour it |
| 2026-09-26 | A content id that is not a file (a tuned `ar_hammer:a`) breaks every tool that turns ids into paths. Resolve to the base in the few places that draw, and make every sampler skip variants |
| 2026-09-26 | A bot's reserve policy can hide a rule from the only test that plays the game: it tuned 0.1 parts a run until its reserve was halved |
| 2026-09-26 | A display class that reads an autoload for an argument nobody uses still breaks every `--script` tool that names a class that uses it (`MachinePortrait` -> `CombatHUD`) |
| 2026-09-26 | One fixed backup path meant every test profile overwrote the player's backup. Derive side files from the save they belong to |
| 2026-09-26 | A glossary link has to mean the word's sense: "the marked hex" linked to MARK. Write tutorial text around the linked vocabulary |

## Open questions

All six questions raised on 2026-09-23 were answered on 2026-09-24 (see Decisions above).

| Raised | Question | Proposed answer | Resolved |
|---|---|---|---|
| 2026-09-23 | Crew size? | 3 constructs, with an optional 4th unlock |3 all the way |
| 2026-09-23 | Can a destroyed construct be rebuilt within a run? | Yes: it leaves a chassis wreck you can rebuild at a workshop node for scrap. The parts it carried are lost |agree with the propose |
| 2026-09-23 | Grid size? | 8×8, to stay readable on a phone |8x8 for now |
| 2026-09-23 | What is the closing front? | "The Reclaimer": an automated scrap-harvesting swarm sweeping the region |agree with the propose |
| 2026-09-23 | Story delivery? | Light: site descriptions and event text, no cutscenes |agree with the propose for now |
| 2026-09-24 | **How do intents create pressure when dodging is free?** (see 002 result) | Try in 003: area attacks (mortar splash, cone), a salvage objective the crew must hold, enemies whose shot follows the unit's dodge tile, and reinforcements that close escape routes. Judge by the bot's damage taken and by the user play-testing | **003: the Crawler + lob/pierce weapons. 600 random fights: bot wins 73.8%, and every loss is the Crawler. Awaiting the user's play-test** |
| 2026-09-24 | Does the enemy damage share (22%) need to rise once HP carries across a run? | Re-measure in 004 with Crawler HP persisting | **004: runs are lost mostly to the Crawler (63 of 95 losses); pressure carries. Closed unless play-testing disagrees** |
| 2026-09-24 | Act length: the bot wins 3.2 fights per act; the plan said 4–5 | The front's speed is the dial. Decide after the user plays | |
| 2026-09-24 | The four 004 design calls (repair between fights, restored arms, front damage per move, generated squads) | Proposed; awaiting the user's veto | **Superseded by play-test 1**: the Crawler is gone and HP now carries; revisit the rest in 005 |
| 2026-09-23 | Keep 3D or go 2D? | Keep 3D. The whole art pipeline exists, and a tilted camera suits a grid |agree with the propose |
| 2026-09-25 | **Difficulty after 008**: the run bot wins 88.7% (76.7% after 007), and it barely uses abilities | Dials, in order: enemy count by column (`run.json` enemies), the speed of the front (`front.every`), level costs. Decide after play-test 4 | |
| 2026-09-26 | **Which roster is right: pauldrons on every arm (the shipped roster, CLAUDE.md) or per-archetype shoulders (`builders/arm.py` today)?** The generator no longer reproduces the roster, which blocks exporting the aluminium light value | Proposed: keep the shipped look (pauldrons everywhere), make the generator reproduce it, then export the aluminium. The user decides | |
| 2026-09-26 | **The gate now decides two thirds of the bot's losses** (12 of 18). A climax or a wall? | 013 replaces the gate fight with a real boss; judge it in the play-test | |
