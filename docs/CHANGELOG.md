# Changelog

Newest first. One entry per iteration; link to the iteration file for detail.

## [013] Act 1 content — 2026-09-26 ([detail](iterations/013-act1-content.md))

The map has things to find and the act a boss worth reaching (play-test 4, PT4-8).

### Added
- **The Sorter** holds the Sorting Gate: big, shielded by two gate pylons (3 less from every hit while one stands; red beams show it), calling a drone every 3 rounds. Its own map, with three rolled escorts.
- **The Reclaimer reaches into fights**: fight in the zone it takes next and two of its drones come in behind you at round 3, on hexes marked red a round ahead (stand on one to block it). The fight panel warns you.
- **New sites**: traders (three parts for sale, one tuned; they buy your spares at twice the scrap value), watchtowers (scout two zones), signals (seven events with stated costs and gains: a crashed hauler, a lone rig, scavengers, a relay mast, a sealed locker, a downed drone, a fuel cache).
- **Three new fight maps**: Pit Row, Crane Legs, Slag Channel.
- Glossary terms for all of it; `shot_run.gd --force KIND`, `combat.tscn -- --reclaimer`.

### Changed
- Site mix: fewer scrapyards (12), plus traders 8, towers 6, signals 14. Run bot 90.0%.
- balance_fights samples the run's maps only (not the tutorial's or the gate's).

## [012] Onboarding — 2026-09-26 ([detail](iterations/012-onboarding.md))

Play-test 1: "names and jargon are explained nowhere. A tutorial at the start would solve
most of it."

### Added
- **The shakedown**: a guided first fight on the real rules, a coach giving one step at a time with an amber marker on what to click; offered on the first NEW RUN, and as TUTORIAL on the title.
- **The glossary**: 56 terms. Blue words are tappable links in the fight's info panel, the garage STATS, site panels, the coach and hints; the GLOSSARY screen from the title and a `?` on the map, garage and fight.
- **First-time hints** on eight screens, dismissed once for good.
- **The profile** (`Profile` autoload, `user://profile.json`): the tutorial flag and the hints seen.
- `tools/verify_onboarding.gd` (the shakedown played by real clicks) and `tools/shot_onboarding.gd`.

### Changed
- The profile save is version 2: the archived game's profile migrates, keeping its tips. Backups live beside their own save.
- A weapon that makes no heat no longer says "+0 heat" in the fight.

## [011] Build progression — 2026-09-26 ([detail](iterations/011-build-progression.md))

A crew is now BUILT over a run: levels are choices, parts can be re-cut, makers add up, and
salvage pulls in different directions.

### Added
- **Perks**: every level-up offers three (only ones that do something for that machine) and it keeps one; the level-up event names it.
- **Tuning** at workshops: every part can be re-cut one of two ways, once ("Breaker Hammer+"), 6 / 10 / 14 scrap; the TUNE bench shows both options with the numbers before and after.
- **Makers and sets**: Kessler, Arclight, Vektor, Cinder. Two parts from one maker on a machine give a bonus, three give another. Shown on socket rows (pips), in the garage, the assembly bay and on part cards ("MAKES KESSLER x3 ON BRUTE").
- Salvage offers **three parts from three different slots**, one leaning to a maker the crew builds, and **TAKE 8 SCRAP INSTEAD**; an elite's part comes tuned.
- `run_bot.gd --set path=json` to try balance dials side by side; the bot reports levels, tunings and unspent scrap.

### Changed
- Level 2 no longer adds +1 damage on every weapon (it became the Hot Loads perk); every level is +2 HP.
- The boss fight has 5 enemies (was 4). Run bot 88.0%.
- Heat per attack can never go below zero; a cold weapon's card no longer says "+0 heat".

## [010] The look — 2026-09-26 ([detail](iterations/010-the-look.md))

A visual pass over everything, from the sources the art spike tested, judged by the
`art-direction-and-readability` frame: readability first, and measured.

### Added
- **The style bible and colour registry** ([art-and-audio](plans/art-and-audio.md)): named references, palette layers, one meaning per signal colour, a read contract per element.
- `tools/measure_contrast.gd`: the machines' luminance over their surroundings (1.8–1.9 before, **2.1–2.3 after**).
- **The board** in photographed surfaces by terrain, with rubble chunks, crusted slag, ridge lips, rusted pits; HDRI sky light.
- **Worn paint on the machines** (a baked wear map from Poly Haven's rusty painted metal, with normals), plate grain on metal, **stencilled crew numbers**.
- **Effects**: soft glows, streak sparks, fireballs with smoke and scorch, burning kills, glowing tracers.
- **HUD**: crew cards with machine portraits and HP pips; weapon buttons show the arm.
- **The title screen as a scene**: the crew under floodlights, the Reclaimer's beacons on the horizon.

### Changed
- Defend caches wear the player's blue (amber means your action); copper (`UIKit.GOLD`) means machine condition.

### Not shipped
- The dirty-aluminium zone is wired but not exported: the generator no longer reproduces the committed roster (an open question for the user).

## [009] Play-test 4 fixes — 2026-09-25 ([detail](iterations/009-playtest-4-fixes.md))

Answers play-test 4 (all but the full visual overhaul, which is 010), after an art-source
spike that tried every candidate in the game ([art-sourcing](plans/art-sourcing.md)).

### Added
- **Assembly bay**: build the three machines from a bench of basic parts before the first move.
- **The map, fogged and followed**: 9 zones; a close camera that follows the crew, who stand on the map and walk the roads; fog of war over everything not yet scouted; drag, keys and wheel to look around.
- **The Reclaimer as a gauge** (a pip per move, the last pulsing) and a **ghost wall** on the line it takes next.
- **Crew dock** with rendered portraits of the real machines, level marks and HP pips.
- **Map life**: scout drones with searchlights, smoking wrecks, a skyline with blinking stacks, the Crucible's glow.
- **Levels on the machine** (shoulder armour, chest plate, exhaust stacks, a bigger frame) in the garage, on the map and in fights; **levelling up as an event** (sparks, scan ring, flare, banner, sound).
- **A garage bay** behind the machine (corrugated wall, lift, gantry, work lamps, dust).
- **Board edges**: a steel curb on the hex outline, asphalt and a ring of yard beyond.
- The hive's **pad**: stays put, counts down, warns red the turn before.
- Enemies **carrying scrap** are marked; only they drop a pile.
- Tools: `fetch_polyhaven.py` (CC0 assets with provenance), `art_probe.gd`; shared `Surfaces` (tinted PBR, kit props), `MachinePortrait`.

### Changed
- Shots and grapples take the **clear one of two equal leanings**. Piercing shots **overshoot** 2 hexes at half damage. The coil **arcs twice**.
- The SCRAP square is the button. Part models load in the background; the garage stage fades in (no black square).
- Tests: `verify_combat` 116 → 134, `verify_run` 61 → 70, `verify_run_ui` 26 → 33.

### Fixed
- The overshoot's damage check read a counter the first hit had spent (caught by its test).
- Billboard particles ignored their scale; fog was invisible on dark ground.

## [008] The yard and the garage — 2026-09-25 ([detail](iterations/008-yard-and-garage.md))

Answers every issue in play-test 3.

### Added
- **The story** ([plans/story.md](plans/story.md), `data/run/story.json`): the Reclaimer, the stolen shutdown key, the Crucible. A briefing on every new run, the act and mission on the map, site text and endings in the world's voice.
- **The map is a 3D yard**: landmarks from the arena kit, roads, zones named on the ground, and the Reclaimer as a wall of harvester rigs with red beacons and dust that slides forward as it takes each zone. A crew strip with each machine's HP and level; the combined HP bar is gone.
- **One click travels.** Hover shows what a site is and what the move costs; direction and cost are also written under each reachable site.
- **The garage** replaces refit: crew tabs, the machine whole in 3D (drag to turn), PARTS and STATS tabs, hovering a part turns the machine to it and lights it, the hold as a low strip with SORT (newest, rarity, slot) and SCRAP; drop a part on a crew tab to fit it there.
- **Machine levels**, the scrap sink: 15 / 25 / 40 scrap for +2 HP, +2 HP and +1 damage, +3 HP.

### Fixed
- Charge works after moving, and hits for 3 + 1 per hex run (+ the machine's damage bonus).
- The coil's arc reaches terrain: from the machine or prop it hits into an enemy, else a fuel drum, else a crate.
- Scrap piles are collected along the whole path of a move, dash or charge.
- Part text called every shot weapon a "lob".

### Changed
- `verify_combat` 108 → 116, `verify_run` 55 → 61, `verify_run_ui` 19 → 26. Run bot 76.7% → 88.7% (see the iteration's balance table).

## [007] Play-test 2 fixes — 2026-09-25 ([detail](iterations/007-playtest-2-fixes.md))

Answers every issue in play-test 2, including PT1-8/9 (map and refit), which 006 had left unchanged.

### Fixed
- Hexes now meet side to side (the tiles were turned 30°, so the board lied about adjacency and range).
- Grapple aims freely at any unit in range with a clear line; anchored machines are tagged ANCHORED.
- Charge takes Focus and Overdrive bonuses. Part text names a module's ability instead of "+0 ability".
- A boss fight that times out ends the run instead of stranding the crew at the gate.

### Added
- **Region map redesign**: zones as columns, the Reclaimer as a wall with a countdown, the next zone to fall striped, FORWARD / SIDEWAYS / BACK on every reachable site, a preview with the move's cost before TRAVEL, site icons, crew cards with HP bars. The log is gone.
- **Refit redesign**: its own screen; drag a part onto a socket (fitting sockets light up), back to the hold, onto another machine, or onto SCRAP. Tap-then-tap still works.
- Part cards with a rarity banner and a verdict ("BETTER THAN BRUTE'S BRUTE FRAME").
- Scrap any part for 3 / 6 / 10 by rarity. The hold starts at 8; workshops sell +2 room (10 / 16 / 24).
- Battle bar in two rows: WEAPONS (amber) and ABILITIES (blue), each with FREE / USES ACTION and COOLDOWN n; text wraps inside the button.
- Quiet intents: target hexes and numbered badges, with lines only for the enemy you tap or those aimed at your selected machine. LINES (key L) shows all.
- A hive's build site stays marked on the board ("DRONE NEXT ROUND"), with a beam from the hive.

### Changed
- Salvage can always be taken; an overfull hold blocks travel until something is fitted or scrapped.
- `verify_combat` 103 → 108, `verify_combat_input` 20, `verify_run` 52 → 55, `verify_run_ui` 12 → 19.

## [006] Fight depth — 2026-09-24 ([detail](iterations/006-fight-depth.md))

Answers play-test 1: PT1-1 (the chore), with the user's picks.

### Added
- Terrain that acts: fuel drums (chain explosions), crate walls (breakable cover), pits (shove or drag in = gone).
- Nine part abilities with cooldowns: charge, grapple, barricade, focus, dash, overdrive, flush, shield, magnet.
- Four enemy kinds: tracker (locked shots), bomber (death blast), warden (shields neighbours), hive (builds drones; block the hex).
- Dry-run previews: every attack and ability preview is the real rules run on a copy.
- Tap any hex to learn what is on it.

### Changed
- Enemy AI re-scores its best candidates by dry run; uses barrels and pits.
- Generated fights scatter terrain and roll enemy kinds by column.
- `verify_combat.gd` 68 → 103.

## [005] Hex combat core — 2026-09-24 ([detail](iterations/005-hex-core.md))

Answers play-test 1: PT1-2 (diagonals), PT1-3 (the Crawler), PT1-4 (death, wrecks), PT1-5 (lag).

### Added
- Hex board (odd-r offset, integer hex lines) with free aim and true line of sight.
- Fight objectives: rout, defend (salvage caches), salvage (scrap piles), on an always-visible plate.
- Scrap piles: destroyed machines burst into walkable piles worth scrap and 2 HP.
- `tools/verify_combat.gd` rewritten for hexes (68 checks). `verify_run` sweeps 370 generated fights.

### Changed
- Machine HP carries through the run; workshops patch the crew; the front bites every machine.
- Intents target a hex; shoving an enemy out of reach makes it miss (shown on the board).
- Faster playback: one glide per move, shorter waits; a burst death instead of a topple.
- `CombatSetup` rejects overlapping, off-board or on-scrap starts.

### Removed
- The Crawler.
- Wrecks that block hexes.

## [004] The run loop — 2026-09-24 ([detail](iterations/004-run-loop.md))

### Added
- A full Act 1 run: region map with fog and the advancing Reclaimer; skirmish, elite,
  scrapyard, workshop and boss sites; salvage picks, the hold and refits; wrecks and
  rebuilds; the Crawler's HP carrying between fights; the run ends at the boss or with
  the Crawler.
- `sim/run/` (RunSetup, RunState, RunSim, RunBot) and `data/run/run.json`.
- Save and resume via the `Run` autoload and `RunStore`, per action, mid-fight included.
- Title: CONTINUE / NEW RUN / PRACTICE FIGHT / QUIT.
- Tests and tools: `verify_run.gd` (42), `verify_run_ui.gd` (12), `run_bot.gd`, `shot_run.gd`.

### Changed
- `CombatSetup` accepts the Crawler's current HP and empty sockets.
- The combat scene runs in run mode when a run fight is pending: it saves per action and
  reports its action log back.

## [003] Parts drive abilities, and intents create pressure — 2026-09-24 ([detail](iterations/003-parts-and-pressure.md))

### Added
- **The Crawler**: an immobile salvage rig on every board. Lose it and you lose the fight.
- Per-part `grid` stats on all 40 parts. A construct is exactly its parts plus a role trait.
- Weapon shapes (melee, line, lob) with pierce, splash, shove, mark, chain and tear.
- The damage-type wheel, cover, armour and marks; heat, overheat, seize and VENT.
- Terrain effects (rubble, ridge, slag), shove and bump, and arms torn off by heavy hits.
- Two new fights (`slag_pit`, `container_row`) and `data/combat/rules.json`.
- HUD weapon bar, heat on cards, the Crawler plate, multi-hit previews; explicit move and
  attack modes.
- `tools/balance_fights.gd` (bulk bot fights) and `tools/shot_combat.gd` (aimed screenshots).

### Changed
- `verify_combat.gd` 41 → 77 checks; `verify_combat_input.gd` 13 → 18 with a watchdog.
- The tap priority from 002 is replaced by modes (select → move; weapon button → aim).

### Removed
- `data/combat/prototype.json` (role and weapon-group stats), superseded by per-part stats.

## [002] Grid fight prototype — 2026-09-24 ([detail](iterations/002-grid-fight.md))

### Added
- A playable turn-based fight on an 8×8 grid. Title → FIGHT → fight → YARD CLEARED /
  CREW LOST → FIGHT AGAIN.
- Pure deterministic combat sim in `sim/combat/`: move, attack, telegraphed enemy intents
  that fire down a line in order, wrecks, win/lose, replay-based undo, event stream.
- `IntentAI` for enemies, reused as `CombatBot` for tests and the `--bot` demo.
- 3D board scene with the existing construct models, rig, VFX and lighting; tap/click
  controls, a two-tap attack, UNDO, END TURN, 90° camera turns, zoom, keyboard shortcuts.
- `data/combat/prototype.json`, `data/fights/proto_yard.json`, and `blocks` on terrain tiles.
- Tests: `verify_combat.gd` (41), `verify_combat_input.gd` (13).

### Changed
- `ContentDB` loads combat rules and fights. `ConstructView.build_parts` builds a model
  from part ids.

## [001] Archive and strip — 2026-09-24 ([detail](iterations/001-archive-and-strip.md))

### Added
- Git tag `archive/f2p-battler` (the full old game at `0b72f74`).
- `scenes/main.tscn` and a placeholder title screen as the new entry point.
- `DevShot` autoload: `--shot` screenshots work on any scene.
- `legacy/`: old code being adapted, ignored by Godot.

### Changed
- `ContentDB` trimmed to the content the roguelike uses.
- `project.godot`: new description and main scene. Autoloads are now `Audio` and `DevShot`.
- `CLAUDE.md` rewritten for the roguelike (not tracked by git).

### Removed
- All F2P, online and live-service systems, the real-time sim, the hub, and their tests
  (165 files, about 24k lines).

## [000] Rethink — 2026-09-23

**Direction change.** Scrapline is now a premium, single-player, turn-based tactics
roguelike for PC and mobile. The F2P live-service squad battler is retired.

### Added
- `docs/` structure: VISION, ROADMAP, CHANGELOG, MEMORY, a plan for each aspect, and
  one file per iteration.
- Detailed plans for combat, constructs and parts, run structure, meta-progression,
  enemies and AI, platform and UI, art and audio, and tech architecture.
- A salvage audit that marks every existing system as keep, adapt or cut.

### Changed
- `CLAUDE.md` starts with a pivot notice pointing at `docs/`.

### Removed
- Nothing yet. Code removal is Iteration 001.

## [pre-000] Previous direction (archived)

- `7276809` First commit: the deterministic sim and everything built on it.
- `0b72f74` Game-style hub, Rust & Sodium art pass, scrap-generated roster.
