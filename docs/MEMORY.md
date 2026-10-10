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
| 2026-09-26 | **Gate pylons are props; the Sorter's shield is `pylon_armor` while any stands** | Props already block, break and never act: no unit rule had to change |
| 2026-09-26 | **Signals state every cost and gain up front** (no hidden dice) | A choice without the information is a guess |
| 2026-09-26 | **The Reclaimer's drones join fights in the column it takes next** | Lingering by the line has to cost inside fights too, not only on the road |
| 2026-09-29 | **Photoreal PBR is abandoned as the base of the look**; the user picks one of three styles (Ink & Rust recommended), proved in one style frame first | Play-test 5: "looks done in Unreal by a bot in a day". Realism is where generated box geometry looks cheapest |
| 2026-09-29 | **A killing shove throws the wreck; pierce passes props; the arc searches for its best route; heaps conduct** | Play-test 5, the user's calls |
| 2026-09-29 | **The fight recap claims only what the event stream backs** | A recap that guessed at contributions would be a second, wrong model of the rules |
| 2026-09-29 | **The gate: deep pylons, 20 rounds, 3 escorts** | Side-by-side runs: only the round limit moves difficulty, and the gate already decides most losses |
| 2026-09-29 | **Art direction A, Ink & Rust: the fight is drawn in it** (flat colour, ink lines, one hard key, comic panels); the rest of the game follows the user's verdict on the style frame | The user's pick from three options (play-test 5) |
| 2026-09-29 | **Of equally cheap routes, the one over the most scrap wins** (both teams, never a detour) | PT5-5 as the user meant it: machines walked round piles as often as over them |
| 2026-09-29 | **The look is applied by dressing after the build** (`Ink.dress_machine` by zone); `ConstructView`/`PartMaterials` unchanged | The other screens keep working in the old look until they follow |
| 2026-09-29 | **Three line weights; a mark's meaning is in its hatching; the enemy's ring is a saw blade** | Readability that survives grey and colour-blindness: the frame's grey copy failed three colour-only reads |
| 2026-09-29 | **Ink & Rust is the whole game's look** | The user, on the style frame: "apply this look to the entire game" |
| 2026-09-29 | **A shot along hex edges fires the better of its two sides** (reaches the target, then does more, then fewer obstacles) | Play-test 6: a rail beam ploughed through a crate wall with the other side open |
| 2026-09-29 | **Selection is an amber border; lettering on paper is ink; text on the dark page is paper with an ink edge** | Amber text does not read on paper |
| 2026-09-29 | **Models: machines by the generator, led by concept art (route A); sites and the Reclaimer generated or from kits (C or B); proved on two models first** | The user: "go with the recommendation" ([plans/models.md](plans/models.md)). Modularity (tearing, levels, salvage) is the game, and only the generator keeps it for free |
| 2026-09-29 | **New models live beside the old, behind `--models new`, per part**, until the user picks | A proof has to stand in the real screens without changing the game anyone plays |
| 2026-09-29 | **Concept art leads the shapes; the game's rules keep the colours** (livery per part, the team in the eye, one light value on the weapon heads) | The concept is all one yellow; the game reads a machine by its parts' colours and its eye |
| 2026-09-29 | **Route C runs on this Mac (TripoSR, MIT)**; TRELLIS needs a Hugging Face account | Every capable image-to-3D demo is on ZeroGPU and one TRELLIS call asks more than the anonymous quota ever holds |
| 2026-09-30 | **Machines are rounded and multi-coloured (`steel`, `trim` zones); a good generated model keeps its texture; livery by maker is proposed** (all behind `--models new`) | The user on 017: "Lego/Roblox ... I want each part to have more than one colour"; "a yellow brick with no details" |
| 2026-09-30 | **The rebuilt roster (rounded, patched from scrap) and livery by maker are the game's look**; the old roster stays behind `--models old` until the user has played | The user: "yes to all 3, do the rest of the roster ... made from actual scrap" |
| 2026-09-30 | **An act is a rules overlay in data** (`run.json` `acts`), a run is two acts until Act 3 exists, and Act 2's enemies hit 1 harder | 021: side-by-side bot runs -- bigger squads and +3 HP left the win rate at 95%, +1 damage took it to 85% |
| 2026-09-30 | **Between-run progression is unlocks only** (12 parts, 2 crews, 2 tiers by lifetime milestones); a run saves the options it started with | `plans/meta-progression.md`; a run must replay the same whatever unlocks later |
| 2026-09-30 | **The board shows totals, not firing order** (`CombatSim.incoming`: the volley plus the next round's start, on a copy); the aim's totals in amber | PT7-3: "several enemies on one spot: one number, the total", and anything in the way shows its damage |
| 2026-09-30 | **A tied shove takes the better hex for the shover; a piercing shot aims as far as its beam flies** | PT7-6/7: a shove "always took the free hex"; a drum "right behind" was off the aimed line and out of aim |
| 2026-09-30 | **Crew machines are named by their crew, not their frame**; no numbers painted on them | PT7-10/11 (the names are proposals until the user picks) |
| 2026-09-30 | **A run is three acts; breaking the Core wins it.** Act 3 (the Crucible) is `run.json` `acts[2]`: flues, conduits, +4 HP and +1 damage, rarity 3 | PT7-1 "do act 3"; bot 66.0% over three acts |
| 2026-10-01 | **Later acts pay in rares** (Act 2 35/45/20, Act 3 10/45/45; Act 3 elites always a rare) **and fight harder** (+5 HP; Act 3 hits 2 harder; keepers armed like their act) | PT8-7: a built crew found no rares and got bored; bot 71.7% with rares alone, 56.6% with the harder acts |
| 2026-10-01 | **Card text is fitted** (`UIKit.fit`); **tags never move more than their own height and draw over every mark** | PT8-3/4/6 |
| 2026-10-01 | **Every iteration ends on `main`, pushed** (branch, then fast-forward) | PT9-1: "all the changes need to be on the main" |
| 2026-10-01 | **Knuckles, Needle, Relay**; names are the player's (RENAME, remembered per crew) | PT9-2 |
| 2026-10-01 | **Keepers escalate at half HP and call guards; levels go to 5** | PT9-3: late bosses "boring and easy", 230 scrap unspent |
| 2026-10-01 | **Content order: objectives & conditions (028), weapons & legendaries (029), warlords (030), sites & events (031)** | The user liked all four directions offered; objectives first because they need no new art |
| 2026-10-01 | **A new part may borrow another's model** (`"model"`, `PartTuning.model_of`); **legendaries come from gate hoards** (and rarely Act 3) | 029: new mechanics without waiting on art; something to hunt for |

| 2026-10-03 | **Every site and the Reclaimer are TRELLIS models** (020), made by `tools/gen3d/next_site.sh` on the user's free Hugging Face account | The user: "do the sites and the reclaimer", "stay free, do one or two a day" |
| 2026-10-03 | **The UI is pop-art panels with pulp buttons** (041's B with A's buttons): `UIKit.card`/`ink_card` heavy ink, red hard shadow, cyan halftone; `primary`/`secondary`/`choice` a wobbling inked border on an ink shadow | PT13-1, the user's pick |
| 2026-10-03 | **Difficulty is a ladder, not a menu**: NEW RUN starts at once with the remembered crew and tier; a tier opens by WINNING the one below (`wins_t<N>`) and becomes the default when it opens; the ending (`kind: ending`) is won only on the top tier. CHANGE on the title steps down or switches crew | PT13-5: "hate clicking through the difficulty", yet it should be a system the player must climb. Alternatives offered: a remembered choice alone (no push upward), per-crew ladders (more to track), an in-run "hard road" (the run decides the tier) |
| 2026-10-03 | **Bosses and warlords keep their arms** (`keeps_arms` on the kind) | PT13-3 |
| 2026-10-03 | **Arms are drawn at 0.8 of their model** (`ConstructView.ARM_SCALE`) and seated clear of the legs too | PT13-4: arms too big and through the frame; the models are not regenerated |
| 2026-10-06 | **Rewards never offer a part in the hold or among the last `recent_offers` (6) offered; each legendary once a run** (`RunSim.avoided`, `RunState.offered`/`legends`). A preference, not a wall: if a pool would empty it falls back, except legendaries (a rare stands in) | The agent's Act 1: Coolant Loop offered four times, the same legendary from the warlord and the gate |
| 2026-10-06 | **Map rules: a non-fight in column 1, a workshop in the column before the gate (`workshop_guaranteed_columns` `-1`), no two linked sites the same service (`no_linked_repeat`)** | The agent's Act 1: three fights to start, two workshops back to back, no repair before the Sorter |
| 2026-10-06 | **A refit keeps the machine's MISSING HP** (`RunSim._keep_missing`), never below 1 | A full Needle came out of the garage 14/17 on a bigger frame |
| 2026-10-06 | **Shoves are a find: Breaker Hammer and Scattergun uncommon, one hammer on the bench. New arms: Chain Flail (`sweep`), Snare Launcher (`snare`), Mine Layer (`mine`); Act 1 traits from 20%. Pits unchanged** | The user: "make more types of arms and the ones that have shove to be uncommon+"; then "go with your recommendation" (flail, snare, mines; grenade and overwatch later) |
| 2026-10-06 | **A mine is a hazard** (`CombatState.hazard` counts it; `ground_hazard` is what bites) and goes off once | One rule for the AI's steps, the bot's danger and `incoming`; a permanent mine would choke the board |
| 2026-10-06 | **UNDO starts from a snapshot of the turn's start** (`CombatState.snapshot`, the scene's `_turn_state`), not a replay from round 1; a view is kept when its look key (parts, torn arms, level, kind) is unchanged (048) | Play-test 14: undo froze for up to 2 s. The action log is still the fight: `verify_combat` plays every fight on from every turn's snapshot and requires the full fight's hash |
| 2026-10-06 | **Gate and warlord boards get `arena_terrain`** (run.json, per act overridable) scattered into their middle rows after everything else is rolled (048) | Play-test 14: "boss battlefields look too empty" -- authored 8x8 and padded with bare rows, they were the only fights with no scattered terrain |

| 2026-10-07 | **The run map's ground is the fight board's hexes** (`YardHexes`, R 1.62 m, three to a zone; sites snap to hex centres; roads are hex lines; each zone merged into one node with its pits beside it) (049) | The user picked mockup C, "the hex diorama look, with the comics aesthetics like in battle": one world for map and fight |
| 2026-10-07 | **Every keeper has a trick, and three share one opening: EXPOSED** (`state.exposed`, ref -> the crew's turns; double damage via `exposed_pct`, no pylon / conduit / twin cover, counted down at the top of `_begin_round`) (050) | The user: bosses must not be "a bulky dummy" you just hit. A window to hit hard is the reward for using the trick |
| 2026-10-07 | **Machines can be generated, one slot at a time** (FLUX concept the user picks -> TRELLIS -> `rig_generated_part.py`; `art/parts_gen/`, `--models gen`) (045) | The user: the scripted Blender machines were "bad to say the least". Generating each slot separately keeps the part contract; only a frame's legs are cut |
| 2026-10-07 | **Free generation runs on Google Colab** (`tools/gen3d/trellis_colab.ipynb`), not the Hugging Face allowance (045) | The user wanted to stay free; the allowance made one or two models a day, a Colab T4 makes one a minute |
| 2026-10-08 | **IntentAI chooses the attack from the dry runs, not from the quick score** (the quick score only picks which candidates get one); enemies treat their allies' committed lines as danger (052) | The drum bonus was a guess the dry run could only raise: enemies shot lone drums and blew up their own side |
| 2026-10-08 | **Machine concepts come from ChatGPT Images, one chat per machine** (whole machine first, then each part against it), saved by `chatgpt_show.js` + `grab_crop.py` (051) | The user: FLUX "always looks kinda bad, with inconsistent design and flaws"; they picked ChatGPT of four generators |
| 2026-10-08 | **A part wears its maker's paint and is patched with plates off other machines** (051) | The user: the robots must read as scrap, "made from different machines", and must not push one build |
| 2026-10-08 | **A generated machine shows its level as rust wearing off** (`<part>_clean.png`, `ink_toon` `clean`), not the bolted kit (053) | The user: "i want the robots to have lesser rusty parts with each upgrade" |
| 2026-10-09 | **Generated parts carry skeletons with standard bone names** (frame torso/hip/knee/ankle, arm shoulder/elbow/wrist), driven by ConstructRig; rest pose by weapon (056) | The user picked full skeletons, and hand weapons at the side, guns aimed |

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
| 2026-09-26 | An event that encodes a kind as "barrel or not" silently draws every new kind as the "not". Encode kinds as an index into a named list |
| 2026-09-26 | A balance tool that samples every map samples the tutorial too. Measure on what the run actually uses |
| 2026-09-29 | Measured contrast passed and the look still failed: a metric can guard readability, it cannot choose a style. The style has to be picked by the person who will judge it, from concrete options |
| 2026-09-29 | A test that passes on a machine that never acted proves nothing: search for a case where the thing under test happens |
| 2026-09-29 | A grey copy of a frame finds what a colour screenshot hides: three of the style frame's reads were colour alone |
| 2026-09-29 | Changing a measuring tool and comparing against numbers the old tool produced compares two tools. Re-measure the baseline with the new ruler first |
| 2026-09-29 | Lit from behind, a toon ramp shows the camera every machine's shadow band: in a flat-colour style the key's direction decides whether anything reads at all |
| 2026-09-29 | A billboard's companions (badges, marks) must be offset in the billboard's own plane: a world-height step shows at about half its size under a camera looking down, and a world sideways step turns with the camera |
| 2026-09-29 | A label's measured size is stale for a frame after its text changes; measure from the text when placing things against it |
| 2026-09-29 | Before reusing an engine slot for a look (`material_overlay`), find everything else that writes it |
| 2026-09-29 | **A zone no model exports is a zone nobody tests**: `alu` sat in the palette from 010 and fell through to `metal` in `zone_of` until the first model carried it |
| 2026-09-29 | Blender does not refresh `matrix_world` when `.location` is written: a matrix composed onto it straight after drops the move (both legs baked at the pelvis). `view_layer.update()` first |
| 2026-09-29 | A single-image 3D model rebuilds what the image shows: the camera's tilt comes along, the unseen sides are guessed (grey, lumpy) and a lattice becomes a sheet. Level, square and relax before judging it |
| 2026-09-29 | Python's `set()` of strings iterates in a per-process order: a vote broken by `max(set(...))` made one export differ run to run. Sort before picking |
| 2026-09-29 | The side of your own machine you see most is its BACK: the board's camera stands behind the crew |
| 2026-09-29 | A tool nobody runs rots silently: the roster generator had not loaded the parts since `makers.json` (011) |
| 2026-09-30 | Browser automation cannot put a file into a cross-origin frame (drop, paste and clipboard all failed): ask the user for the one drag at once |
| 2026-09-30 | Cleaning a model is not one recipe: flatten-and-zone suits a guessed mesh and destroys a good one |
| 2026-09-30 | One builder with a spec row per frame gives a roster: the differences that read (head, legs, back, girth) are data |
| 2026-09-30 | Against a levelled crew, enemy HP is not difficulty; enemy damage is |
| 2026-09-30 | Run every suite before a merge: 021 went in with two enemy kinds missing their glossary cards because the onboarding suite "was not related" |
| 2026-09-30 | **"It lags" was shader compilation, not the game**: a stack sample showed the GL driver compiling. Godot frees a StandardMaterial3D's shader with its last material, so throwaway effect materials recompiled every shot; an omni light made every lit material compile a variant. Hold one copy (`Ink.hold` + `get_rid()`: a copy never asked for its RID holds nothing), draw every effect once behind a card, and measure frames (`measure_hitches.gd`) before and after |
| 2026-09-30 | A transparent EMISSIVE StandardMaterial3D recompiled on every use even with a live copy held; additive with an over-bright albedo does not. Test a material fix in isolation (`mat_probe`) rather than trusting the theory |
| 2026-09-30 | A glossary form is matched everywhere text is linked: a kind id that is also a common word ("core", "vent") links the wrong card. Pick ids no sentence uses for anything else |
| 2026-10-01 | An automatic layout move needs a bound: "the shorter way, up or down" with no limit sent a crowded tag to the banner (PT8-3) |
| 2026-10-01 | Measure an art complaint across every combination before fixing one model: "arms go through the body" was 78 of 100 frame/arm pairs |
| 2026-10-01 | A transparent overlay drawn at a higher render priority than a label hides it however "no depth test" the label is: order the priorities, labels last |
| 2026-10-01 | A bot batch is ~55 s a run alone and ~5 min with 15 processes sharing the CPU: size batches at 10 runs a process, launch them detached (`nohup`), and wait on the processes, or the one-hour limit kills them silently |
| 2026-10-02 | A tool that drives the real `Run` autoload writes the player's save and profile (a screenshot banked a bot run into the user's unlocks). Under `--script` both use files of their own, by construction |
| 2026-10-02 | A bigger board made the game easier (67% from 58%): room is time to shoot. Space and enemy count move together |
| 2026-10-02 | The rarity OFFERED is not the rarity FITTED: the first cut moved the bot's late crews from 6.8 to 6.7 rare parts. Measure the outcome (the bot reports rare+ fitted at the last gate) |
| 2026-10-02 | A measurement that cannot fail is not one: the paired part test ran an hour and could not separate parts (the bot wins single fights). Calibrate a harness against a known difference before trusting its zeros |
| 2026-10-02 | Model aliases do not chain (a part borrowing a borrowed model has none): test every entry that resolves a reference |
| 2026-10-03 | Behaviour every control should have belongs to one watcher of the tree (`Juice`), not to each screen: a dozen call sites had each dropped the hover style |
| 2026-10-03 | Measure looks on a quiet machine: contrast read under 15 bot processes moved more (2.97 vs 2.84) than the change did (2.91 vs 2.91) |
| 2026-10-03 | Write the test from the PRECONDITION, not the description: Charge passed every test written from its text while running past the hex it was aimed at |
| 2026-10-03 | On a gate board, only `keepers` authored machines are kept; the rest are rolled escorts. The Core's conduit was never in its fight |
| 2026-10-03 | A Container resets its children's rotation and scale on every layout: a tilted caption needs a plain holder |
| 2026-10-03 | Profile before refactoring: the code map's biggest "bridge" (CombatScene) cost ~3% of a frame; 2,600 draw calls cost the rest. Godot casts shadows from Label3D/Sprite3D by default |

| 2026-10-03 | A free ZeroGPU allowance is a rolling 24 hours (~300 s; a call needs ~1.5x the 120 s it reserves): four or five TRELLIS runs a day. A refused call costs nothing -- retry on a schedule |
| 2026-10-03 | Give TRELLIS our own mask (cut the white background ourselves) and dark or saturated concepts: its background removal kept a white floor and grew a mound out of it |
| 2026-10-03 | Squaring a near-square footprint turns a model arbitrarily: a site that must face the camera keeps the facing its concept was drawn with |
| 2026-10-03 | A billboard `Label3D`'s `get_aabb()` is a conservative cube -- as tall as its text is wide. Measure a label from its font (`get_multiline_string_size`) |
| 2026-10-03 | A StyleBox subclass has to EXPORT its variables or `duplicate()` returns defaults; giving it StyleBoxFlat's property names let every screen switch to it without a rewrite |
| 2026-10-03 | Frame a model after the turn it is shown at: a width measured before the three-quarter turn cut the arms off every crew portrait |
| 2026-10-04 | A background pocket enclosed by ropes or a fence never touches a corner: cut near-pure white by colour too (in patches bigger than a highlight). Paint smoke out of a concept meant for a model |
| 2026-10-06 | **A test that waits for `_busy` to clear must FAIL when it never does.** `verify_run_ui`'s resume check settled by running out of frames and then drove the fight itself, so a resumed fight that could never be played passed for weeks. The agent found it in one CONTINUE |
| 2026-10-06 | **An agent can play the real game**: a `--script` driver reading commands from a file (click/hex/site/press-by-label, screenshots, a text dump of the state and the sim's own queries) played Act 1 in about 250 calls. Text beat pixels; screenshots were for looks. Kept in the session scratchpad, not the repo |
| 2026-10-06 | **Frame the board by measuring it**, not by constants: `_fit_board` projects the far row (with a pylon's height) and the near row and moves the aim until both sit between the top bars and the HUD |
| 2026-10-06 | **Something that stays on the board must not be an intent mark.** Intents are cleared while the enemy acts; The Pour's slag pools were drawn as intents and blinked out for every volley (048, `_flood_views`) |
| 2026-10-06 | **A canvas context keeps its state between redraws**: the map mockups drew twice (once more when the fonts loaded) and the second pass inherited `textAlign = right` from the first, clipping every title. Reset the state at the top of each draw |
| 2026-10-07 | **`Ink.line` builds a new outline hull for every primitive mesh** (only ArrayMeshes are cached). A field of a thousand hexes must outline one mesh per shape and share it (`YardView._add_inked`) |
| 2026-10-07 | **TRELLIS bakes its render's highlights into the texture.** Under the toon ramp, which shows a texture's lit colour exactly, the Brute's pauldrons and chest read cream from the board camera. Grade the texture first (`grade`: saturation up, highlights under a ceiling) (045) |
| 2026-10-07 | **A TRELLIS model is many thin loose shells.** Removing "thin" pieces to drop a baked drop-shadow disc tore real plates off; pick the disc by colour and place instead (`drop_shadow`) (045) |
| 2026-10-07 | **FLUX ignores "without arms"**: every frame concept had arms. Cut them by a measured width profile (legs, a gap, then the arms) (045) |
| 2026-10-08 | **Judge a keeper on a fight a run built, not on its practice board**: `--fight` fields every authored enemy (the Act 1 warlord's 4 instead of 2) and the starting crew. `tools/dump_boss_fights.gd` saves the real ones; `tools/play_fight.gd` plays any fight as text, turn by turn |
| 2026-10-08 | **When the browser asks where to save, capture instead of downloading**: show the image alone in the page and save a full-size screenshot (a `scale`d screenshot saves small too) (051) |
| 2026-10-08 | **Grade a generated part on its own**: one grade for the set dulled the frame's yellow correctly and turned the hammer beige (051) |
| 2026-10-08 | **A generated arm comes in the concept's pose**: turn its shoulder ring to the body, then check the weapon against the shoulder (`rotate`, `twist`). A generated frame's sockets are exact: never push its arms (053) |
| 2026-10-08 | **Mount a generated arm by its shoulder ring, not its bounding box** (`mount: "ring"`): bolted by its top centre, the Brute's arms hung through its body and legs (054) |
| 2026-10-09 | **Set an arm's pose in the concept, never twist the mesh**: one drawn layout for all arms (shoulder face to the viewer, elbow with piston, weapon toward the bend); the 053 twist mangled the wrist. Frames are drawn bare -- no core, module or rack (055) |
| 2026-10-09 | **Compute a rest pose from each generated arm's own geometry**: fixed angles pointed the guns at the sky. **Topple a wreck about its footprint's edge**: about the middle, half of it went under the floor (056) |
| 2026-10-09 | **Walk a skeleton by placing its feet (IK), never by swinging angles**: angle swings on a splayed leg went sideways and under the floor. A walking body dips into its steps; bobbing up lifts the feet off the ground (057) |
| 2026-10-09 | **Anchor IK feet in the GROUND's frame, not the body's**: a leaning or recoiling body carried its feet under the floor. Take each knee's bend side from the drawn model (bird legs bend back) and forward from the machine's -Z (058) |
| 2026-10-09 | **Animate pose to pose** (held keys, SNAP/SMEAR/STEP curves, additive layers), **turn bones about the MACHINE's axes** (front is +Z; a generated bone's own X points anywhere), let the torso carry the sockets, and **show a strike's effect at its impact** (`strike` returns the lead). The rigid roster's legs had cycled backwards since the start (059) |
| 2026-10-10 | **Measure floor penetration on posed vertices** (`ConstructRig.lowest`, `tools/probe_floor.gd`), not bones or boxes. Solve a knee toward its DRAWN side and keep the foot flat to the ground, or the shin and toe go under. **A Packed array read from a Dictionary is a copy** (060) |
| 2026-10-10 | **Parts that come off are physics bodies, on their own layer, kept on the hex**; the machine's motion stays authored. **Bind a foot plate to the ankle by height** (`foot_top`), or it stretches with the shin. Check a death from the SIDE: from the front a machine on its back looks like it kneels (061) |

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
| 2026-09-26 | **Which roster is right: pauldrons on every arm (the shipped roster, CLAUDE.md) or per-archetype shoulders (`builders/arm.py` today)?** The generator no longer reproduces the roster, which blocks exporting the aluminium light value | Proposed: keep the shipped look (pauldrons everywhere), make the generator reproduce it, then export the aluminium. The user decides | **Superseded by 017**: the roster is rebuilt from concept art (`make_ink_parts.py`), which exports `alu` |
| 2026-09-26 | **The gate now decides two thirds of the bot's losses** (12 of 18). A climax or a wall? | 013 replaces the gate fight with a real boss; judge it in the play-test. 014: still 12 of 20; escorts and summon pace do not move it, the round limit does | |
| 2026-09-26 | **Play-test 5 (009-013)**: is the Sorter a climax? Do signals, traders and towers fix "the map feels empty"? Does the shakedown teach enough? | The user plays | |
| 2026-09-29 | **Which art direction?** A Ink & Rust, B Painted Miniatures, C Schematic Low-Poly ([options](plans/art-direction-options.md)) | A, proved first in the "decision moment" style frame | **A** (the user, 2026-09-29) |
| 2026-09-29 | **PT5-5: was the "scrap on the ground" rubble?** | Assumed rubble (costs 2); routes now take fewer hexes at equal cost and the route is drawn on hover | **No: the scrap piles** (the user). 015: routes over scrap win ties |
| 2026-09-29 | **The style frame (015): should the rest of the game look like this?** | Yes, then 016 carries it to the map, the Reclaimer, every panel, the garage and the title | **Yes** (the user); done in 016 |
| 2026-09-29 | **New models (PT6-5): from scratch, open-licence kits, or generated?** | See the 016 report and 017 | **A for machines, C or B for sites, proved first** (the user) |
| 2026-09-29 | **The proof (017): route A for the whole roster? Route C for the sites -- TripoSR as it runs here, TRELLIS with a Hugging Face token, or kits (B)?** | A for the roster; for sites, TRELLIS if a token is available (it rebuilds the unseen sides), else B | |
| 2026-09-29 | The crew number is stencilled across the core's lens (old and new cores): the stencil is sized to 59% of the plate | Place it from the core's own marked corner in the roster pass | |
| 2026-09-30 | **018: is this Brute the look? Livery by maker for the whole game? Sites by TRELLIS (needs the user's browser or a token each time)?** | Yes to all three | |
| 2026-09-30 | **019: does the roster play well? Remove the shipped roster?** | Remove once played | |
| 2026-09-30 | **021: is The Pour a good fight, and is 85% over two acts right?** | The user plays | |
| 2026-09-30 | **022: is an unlock after nearly every early run the right pace?** | The user plays | |
| 2026-09-30 | **023: how does the game sound?** Every sound was written as a waveform and never heard | The user listens; then a tuning pass | |
| 2026-09-30 | **024: do the totals, the ring and the opening card read? Which crew names?** (proposed: Knuckles/Mule/Stilts, Slab/Winch/Needle, Dash/Magpie/Wick) | The user plays and picks | |
| 2026-09-30 | **025: is 66% over three acts right? Should Act 3 bite harder than Act 2** (it loses 15.4% of the runs that reach it, Act 2 15.2%)? Is the Core a good last fight? | The user plays; a second point of Act 3 damage is the dial | |
| 2026-09-30 | The END TURN press plans the enemy's next round inside the action (0.1-0.2 s on a full board); the banner answers first so it reads as the enemy getting ready | Speed up `IntentAI.plan` if Act 3's bigger squads make it felt | |
| 2026-10-01 | **026: is 56.6% over three acts right? Does the garage need a new layout** (026 fitted its text and added a cover, the layout is 008's)? | The user plays | |
| 2026-10-01 | **027: is The Pour hard enough (5 gate losses in 110 bot runs)? Do the new bay and garage read well?** | The user plays | |
| 2026-10-01 | **028: are HOLD, HACK and SURVIVE fun? Are the yard conditions noticeable enough?** | The user plays | |
| 2026-10-01 | **029: do the flamer, harpoon and shield caster feel different? Are legendaries worth the hunt?** | The user plays | |
| 2026-10-01 | **030: are the warlords fun? Act 3 is now the bot's easiest act (12.6% lost)** | Tighten after 031; the user plays | |
| 2026-10-01 | **031: is Act 1 too hard with arenas (bot loses 14.7% there, was 5.3%)? Does the refinery make late crews too strong?** | The user plays | |
| 2026-10-02 | **032: is the 10 x 10 board right (and on a phone)? Do defend fights feel fair now? Is the arena hard enough?** | The user plays | |
| 2026-10-02 | **033: do the new modules feel different? 56.7% with enemies carrying them -- too hard in Act 2 (22.4% lost)?** | The user plays | |
| 2026-10-03 | **034: are the missions the right difficulty? Should missions unlock crews and tiers too?** | The user plays | |
| 2026-10-03 | **035: does the button feel right (bounce, sounds)? Should the board and map sites answer the cursor the same way?** | The user plays | |
| 2026-10-03 | **036: is the printed look the comic the user means -- stronger, weaker, or balloons / speed lines / panel frames instead?** | The user looks | |
| 2026-10-03 | **037: is the damage-type chart enough, or should tags show armour? Does UPGRADE read better than TUNE?** | The user plays | |
| 2026-10-03 | **038: is the Core hard in a good way, or only long? Is 52.7% overall too hard?** | The user plays | |
| 2026-10-03 | **039: is the comic too much anywhere? Which of the eight should be stronger or quieter?** | The user looks | |
| 2026-10-03 | **020: do the ten generated sites and the harvester wall look right on the map?** | The user looks | |
| 2026-10-03 | **040: does the new story read right? The map is still ~62% of a core idle (generated set pieces)** | The user plays; next perf step | |
| 2026-10-03 | **041: which comic direction for panels and buttons -- A pulp, B pop art, C inked panels?** | The user picks | |
| 2026-10-03 | **042: do the 26 new models read at board distance?** | The user looks | |
| 2026-10-04 | **044: do the warlord, arena, refinery and auction models read on the map?** | The user looks | |
| 2026-10-06 | **047: Act 1 is too easy for a careful player (the agent finished it with all three machines; most rounds nothing hit) and a 3-damage shove into a pit kills a 12 HP machine** | Done in 047 (shoves uncommon, three arms) | ~~open~~ |
| 2026-10-06 | **046: does the board framing, the paper hold zone and the edge arrows read right on the user's screen?** | The user plays | |
| 2026-10-06 | **047: Act 1 is harder (16.0% lost, was 11.3%) but Acts 2-3 jumped 9 points each (bot 43.3% overall). Ease the later acts back (no snares/mines in their rolls, more arrival repair, mine damage 3)?** | The user plays | |
| 2026-10-06 | **048: which direction for the run map** -- A ink atlas, B signal board, C hex diorama, D comic route, E floodlit yard (the mockup page)? | The user picks | C, with the battle's comic look (049) |
| 2026-10-07 | **050: Act 3 got much easier for the bot with the boss tricks (17.4% lost, was 31.4%; gate 4 losses, was 12). Core `open_bonus` 2, or turn two sixths?** | The user plays | |
| 2026-10-07 | **Do the rest of the machines the 045 way?** About 60 parts: an hour of Colab, a concept pick each, and a rig spec per part | The user looks at the generated Brute first | |
| 2026-10-08 | **052: the Magnet King's trick works by itself -- should the crew's Magnet ability pull fuel drums (so a drum can be set up)? And the bot is at 55.3% after the AI fixes: tune harder?** | The user | |
| 2026-10-08 | **Maker set bonuses reward matching parts, while the scrap look says any mix is right** -- keep, soften, or reward mixing? | The user decides | |
