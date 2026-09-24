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
| 2026-09-24 | Does the enemy damage share (22%) need to rise once HP carries across a run? | Re-measure in 004 with Crawler HP persisting | |
| 2026-09-23 | Keep 3D or go 2D? | Keep 3D. The whole art pipeline exists, and a tilted camera suits a grid |agree with the propose |
