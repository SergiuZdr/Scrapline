# Changelog

Newest first. One entry per iteration; link to the iteration file for detail.

## [057] IK walk, staged strikes, kneel-then-fall deaths — 2026-10-09 ([detail](iterations/057-ik-walk.md))

### Changed
- Generated machines walk by IK: feet planted on the floor and lifted on an arc, knees forward, no feet
  under the ground, the Brute no longer bow-legged. Strikes are staged (wind-up, held impact, body in
  it). Deaths kneel first, arms slack, then fall forward.

## [056] Skeletons and animation for generated machines — 2026-10-09 ([detail](iterations/056-skeletons.md))

### Added
- Every generated part has a skeleton with standard bones; knees bend when walking, arms rest by
  weapon (hand weapons at the side, guns aimed), elbows work in strikes, knees fold on death.
### Fixed
- Wrecks no longer sink halfway into the floor: they tip over the edge of their footprint.

## [055] The starting crew as comic scrap — 2026-10-09 ([detail](iterations/055-crew-scrap.md))

### Added
- Needle and Relay as generated comic-scrap machines; the Brute's arms redrawn with elbows. All arms
  share one drawn layout (shoulder, elbow with piston, weapon forward), turned whole, never twisted.

## [054] Generated arms bolt into the shoulder ends — 2026-10-08 ([detail](iterations/054-arm-mounts.md))

### Fixed
- The scrap Brute's arms plug into its pauldrons' ends and hang outside its legs (rig `mount: "ring"`).

## [053] Scrap Brute fixes; rust that wears off with levels — 2026-10-08 ([detail](iterations/053-scrap-brute-fixes.md))

### Changed
- The generated Brute's arms hang from its shoulders (no push for generated frames; shoulder rings
  turned to the body; weapons twisted 90), its pauldrons are narrower, its core and backpack sit in.
- **A generated machine's rust wears off as it levels** (0 to 5), instead of the bolted level kit.
- Rig: `twist`, `squeeze`, `rust_map`; `tools/shot_machine.gd --level`.

## [051] Comic scrap machines: the Brute — 2026-10-08 ([detail](iterations/051-comic-machines.md))

### Added
- **The Brute as comic scrap**, drawn with `-- --models gen --gen-dir res://art/parts_gen_scrap`: five
  parts from ChatGPT Images concepts (one design), each in its maker's paint and patched with plates off
  other machines, made 3D by TRELLIS on Colab.
- `tools/gen3d/chatgpt_show.js` + `grab_crop.py`: saves ChatGPT images without the download dialog.
- `tools/shot_machine.gd`: one machine in the game's ink at chosen angles.
- The rig's `--style inked|zones`; `--gen-dir` picks a generated set; textured parts are hatched and
  rimmed like every machine.

## [045] Generated machines: the Brute — 2026-10-07 ([detail](iterations/045-generated-machines.md))

### Added
- **The Brute rebuilt from generated models** (concept -> TRELLIS -> rig), shown with `-- --models gen`:
  frame, saw, hammer, core and module, each made from a concept the user picked, multi-coloured scrap
  under the ink look. The default game is unchanged.
- `tools/gen3d/trellis_colab.ipynb`: TRELLIS on Colab's free T4, about a minute a model.
- `tools/gen3d/part_concept.sh` (FLUX concepts), `next_part.sh` (Hugging Face TRELLIS, or `--rig` again),
  `colab_prep.sh` (cut concepts for Colab, import its models), `queue_parts.sh` (waits out the allowance).
- `tools/blender/rig_generated_part.py`: orients, sizes, grades and posterizes a generated part, cuts
  a frame's legs at the hips and adds its sockets; specs per part in `tools/gen3d/parts/`.
- `tools/record_round.gd`: a fight playing itself for Godot's movie writer.

## [052] The agent played every boss — 2026-10-08 ([detail](iterations/052-boss-playtest.md))

### Fixed
- Enemies no longer shoot lone fuel drums that hurt nobody, or blow up drums beside their own side.
- Enemies no longer walk into the line of a shot an ally has already lined up.
- The Sorter's claw no longer "throws" a machine that is already beside it onto the same hex.

### Changed
- **The Grinder** also sticks when its charge hits a machine braced against something solid (or one
  of its own): stand with your back to a heap, take the blow, and it is open.
- **An exposed boss holds still** for the turn it is open, so melee machines can use the opening.
- **The Pour**: a coolant tank opens it for the rest of that turn (was two turns).
- **The Twin Furnaces** have 34 HP each (was 26); **the Core's** open side is +2 (was +3); **the
  Sorter** has 24 HP (was 18).

## [050] Boss tricks — 2026-10-07 ([detail](iterations/050-boss-tricks.md))

### Added
- **Every boss and warlord has a trick to turn against it**, warned a round ahead:
  - **The Grinder** marks a lane and charges down it. Charging into a heap, a crate, a drum, a pit
    or the board's edge leaves it **STUCK**: no saws, double damage for your turn.
  - **The Sorter**'s claw grabs the nearest machine within 4 and throws it onto its pad. Whenever
    its pad works -- builds, or is blocked -- its **hatch** is open: double damage, no pylons.
  - **The Pour**: burst a **coolant tank** within 2 of it and its shell cracks for two turns; the
    slag by the tank cools.
  - **The Magnet King** hauls drums, crates and tanks too. A drum hauled into it goes off in its face.
  - **The Core** has an **open side** that turns every round: +3 from there, no conduit cover.
  - **The Twin Furnaces** rebuild a fallen twin in 3 rounds unless you break the other first.
- A keeper caught open says EXPOSED on its tag and on the boss bar; the bar names each one's trick.

## [049] The hex yard — 2026-10-07 ([detail](iterations/049-hex-yard.md))

### Changed
- **The run map is built from the fight board's hexes**, inked and shaded like the board. Sites
  stand on raised hexes, roads are paved hex paths, and the roads you can take now wear the same
  blue hatching as the hexes a machine can move to (amber under the pointer). The crew walks the
  road hex by hex.
- **The Reclaimer eats the ground a zone at a time**: behind it the hexes are pits.
- Each act's ground has its own terrain: rubble and scrap heaps, slag in Act 2, flues in Act 3.
- Zone names are lettered like the board's tags.

## [048] Play-test 14: undo without a freeze, fuller arenas, map directions — 2026-10-06 ([detail](iterations/048-playtest-14.md))

### Changed
- **UNDO is instant.** It used to replay the whole fight from round 1 and rebuild every machine
  (up to two seconds by round 8). It now starts from the turn's own snapshot and only rebuilds a
  machine whose parts changed.
- **Boss and warlord arenas have cover**: rubble, scrap heaps, crate walls and a fuel drum are
  scattered into the middle of their boards. Their open floor is worked steel (deck plates, drain
  grates, oil stains, bolts) and they sit inside a closer wall of barriers and stacks.
- **Live wires** are a scorch mark, a heavy cable and a pale electric spark, not a red hex.

### Fixed
- The Pour's slag pools no longer vanish while the enemy is firing.

### Added
- A page of five mockups for the run map, for the user to pick a direction.

## [047] Difficulty: rarer shoves, three new arms, earlier traits — 2026-10-06 ([detail](iterations/047-difficulty.md))

### Changed
- **The Breaker Hammer and the Scattergun are uncommon.** The starting bench has one hammer;
  Relay starts with a Pulse Emitter. A shove into a pit is something you find now.
- **Three new arms, for you and for the enemy**:
  - **Chain Flail** hits the hex you aim at and the two beside it -- one step sideways is not
    always out of it.
  - **Snare Launcher**: whatever it hits cannot move next time (no move, dash or charge).
  - **Mine Layer** drops a mine on a hex; it goes off under whatever starts a round there.
- Special enemies (trackers, bombers, wardens, hives) turn up from the first fights of Act 1.
- The enemy-fire list says where a mine is going and who it waits under; snared machines say
  SNARED; mines sit on the board as red-ringed charges.

## [046] Agent play-test fixes — 2026-10-06 ([detail](iterations/046-agent-playtest-fixes.md))

### Fixed
- **A fight resumed with CONTINUE can be played.** It used to open with END TURN greyed and
  nothing answering a click.
- The level-up banner no longer says NEW ARMOUR (it is new plating on the model, not armour) and no
  longer covers the machine's name.

### Changed
- **Rewards stop repeating**: salvage, hoards, scrapyards, traders, signals and the auction never
  offer a part already in the hold or among the last six offered, and each legendary comes up once
  a run.
- **The map**: the first step always has something that is not a fight; there is always a workshop
  in the column before the gate; two linked sites are never the same service.
- **Swapping a frame keeps what the machine was missing**: a full machine stays full.
- **The board fits above the HUD**: the crew's own row is no longer under the hint line and ability
  cards. The gate's pylons stand inside the frame with lit caps.
- The **hold zone** is drawn in paper with a heavier ring and a larger label (blue is your move).
  **Live wires** sit on a dim red floor with brighter sparks.
- **Tags of machines side by side** spread sideways instead of stacking.
- **A reachable site off screen** gets a named arrow at the edge of the map (click it to look);
  labels never sit under the controls line.
- **Big moments**: the warlord has its own icon (a crowned skull); hoards are titled THE WARLORD'S
  HOARD / THE KEEPER'S HOARD; winning at a gate says GATE BROKEN!, at a warlord WARLORD DOWN!.
- The upgrade screen's title no longer covers its subtitle, and says "upgrades" throughout; the title
  screen frames the crew clear of the menu.

## [044] Models for the warlord, arena, refinery and auction — 2026-10-04 ([detail](iterations/044-more-sites.md))

### Changed
- **The warlord, the arena, the refinery and the auction stand on the map as their own models**
  (generated from concepts, like the other sites): a throne of crushed cars under a crane magnet, a
  tyre-ringed pit, a glowing furnace, a stage under a striped awning.

## [043] Play-test 13: the comic UI, the bay, the tier ladder — 2026-10-03 ([detail](iterations/043-playtest-13.md))

### Changed
- **Every panel and button wears the look you picked**: pop-art panels (heavy ink border, a hard red
  shadow, cyan halftone) and pulp buttons (a hand-inked border on an ink shadow; the main action
  shaded into its corner).
- **NEW RUN starts at once.** The title says the next run's crew and tier, with CHANGE beside it.
- **The tiers are a ladder**: FOREMAN opens by winning a run, RECLAIMED by winning on FOREMAN, and a
  tier becomes your next run's the moment it opens. **The game's ending is won only on RECLAIMED.**
- **Bosses and warlords keep their arms** -- no tear can take one off, and the preview says so.
- **The assembly bay** sits on three even columns; every picture of a machine shows all of it;
  arms are smaller and stand clear of the legs as well as the body.
- Tags sit at their machines again (a long tag was measured as tall as it was wide).
- Every unlock has a picture: a crew its three frames, a tier its numeral, the ending its badge.

## [020] Sites and the Reclaimer — finished 2026-10-03 ([detail](iterations/020-sites.md))

### Changed
- **Every site on the map is a model generated from its concept** (TRELLIS, on the user's free
  Hugging Face account, four or five a day): the camp, ambush, elite bunker, scrapyard, trader,
  watchtower, signal, workshop and the gate, with their detail and texture kept.
- **The Reclaimer is a line of harvesters**: shredders forward, black edged in red, a beacon on each.
- `tools/gen3d/next_site.sh` makes one end to end; it cuts the concept's background itself, keeps
  the raw model, and retries a step that hangs.

## [042] A model for every part — 2026-10-03 ([detail](iterations/042-part-models.md))

### Added
- **26 parts have their own models and pictures** -- every module, legendary and 029 part that wore
  another's. Modules look like what they do: spikes, a flywheel, tesla coils, a sensor dish...

## [040] Play-test 12 fixes — 2026-10-03 ([detail](iterations/040-playtest-12-fixes.md))

### Changed
- **Lighter on the PC**: a fight draws 42% fewer things a frame and uses about 60% of a CPU core
  idle (was 75-100%); the title 32% (50%); 12 frames a second in the background.
- **The story explains the game**: the briefing, each act's arrival and each boss's strip say what
  is happening and what to do about it.
- **GARAGE** from every site you trade or choose at. **UNLOCKS** says what each part does and opens
  its card. **Unlocked parts are on the assembly bench.** The strips tilt; an act is told once.

## [039] The comic, all the way — 2026-10-03 ([detail](iterations/039-comic-pages.md))

### Added
- **Speech balloons**: the info panel and every hint point at what they are about.
- **Thought clouds** over the enemies: who fires in what order, and for how much.
- **Sound effects lettered** on every hit by damage type; **speed lines** on moves and charges;
  **focus lines** on heavy hits.
- **The board in a comic panel**, and **a page turning** between screens.
- **Caption-box titles** on every site window, the garage, the bench and UNLOCKS; the fight's result
  as a splash.
- **Inked models**: cross-hatching in the shade, a white rim highlight, a brush line.
- **Story in panels**: the run's briefing, an act's arrival and a boss's entrance are comic strips.

## [038] The bosses — 2026-10-03 ([detail](iterations/038-bosses.md))

### Changed
- **The Core is the end boss**: 72 HP, shielded by two conduits until they fall, pulses every other
  round -- and every round once it erupts. **The Pour** has 52 HP and floods more.
- **Bosses look like bosses**: bigger, in crimson (warlords in gunmetal), named on the board, with a
  health bar across the top that says what they are doing. Their boards are dressed.

### Fixed
- Act 2's boss was drawn at a normal machine's size; the Core's conduit was never on its board.

## [037] Play-test 11 fixes — 2026-10-03 ([detail](iterations/037-playtest-11-fixes.md))

### Fixed
- **Charge** stops on the hex you aim at (it ran its full range), takes a terminal it ends on, and
  counts the Brawler's bonus; its text says exactly what it does, and it shows its damage before
  you confirm.
- A Focus or Overdrive shows on the weapon cards at once. Damage to pylons and crates is previewed.
- A tag no longer climbs far above its machine; the map's portraits and HP squares fit.

### Added
- **Damage types made visible**: a chart in the glossary, each weapon's type on its card, STRONG /
  WEAK on an aimed hit, and what a machine beats and fears in DETAILS. The Flamer and Sunspear always
  burn, the Pulse Emitter and Coilgun are always EMP.
- Every damage total says what it is made of ("-7 (4 + 3 blast)").
- Every site says what it does under its name on the map; UNLOCKS marks what is new.

### Changed
- NUMBERS is DETAILS; ROLE explains the role; tuning is UPGRADE; "NOT RARER THAN YOURS" is gone.

## [036] Comic style, a frame — 2026-10-03 ([detail](iterations/036-comic-style.md))

### Changed
- **The world is printed on paper**: dot screens in the shadows, slightly slipped colour plates,
  paper grain -- on the fight, the map and the title, never over the interface.
- **Heavier ink**; damage in **starbursts**; the round in a **caption box**.

## [035] The interactive pass — 2026-10-03 ([detail](iterations/035-interactive.md))

### Changed
- **Every button answers the hand**: it lifts under the cursor, squashes when pressed, springs back,
  clicks -- and a button that cannot be used shakes "no" instead of doing nothing.

## [034] Unlock missions — 2026-10-03 ([detail](iterations/034-unlock-missions.md))

### Added
- **Missions**: nine unlocks earned by doing something in a fight -- a flawless win, two kills with
  one attack, enemies dropped into pits, HOLD / HACK / DEFEND wins, beating the warlords -- each
  opening one of the new modules. The UNLOCKS screen lists them with their progress.

## [033] Parts: the power audit and modules with mechanics — 2026-10-02 ([detail](iterations/033-parts-audit.md))

### Added
- **Twelve new modules** with new rules: thorns, a repair drone, a scrap leech that heals on kills,
  a Phoenix Cell that survives its first wreck, and modules that lend weapons pierce, arcs, marks,
  shoves or tearing.
- **The parts analysis** ([parts-power](plans/parts-power.md)): every part's power by slot and rarity.

### Changed
- **Rare cores do something**: the Tesla Core arcs every shot, the Mag Core pierces; uncommon cores
  each carry a trait. The Targeting Suite, Heat Governor, Flamer and Shield Caster are stronger.

### Fixed
- The Aegis Rig's "Fast Cycle" tuning made its shield slower.

## [032] Play-test 10 fixes — 2026-10-02 ([detail](iterations/032-playtest-10-fixes.md))

### Changed
- **A bigger battlefield**: run boards are 10 x 10 (were 8 x 8), the two sides further apart; Acts 2
  and 3 field one more enemy.
- **Your machines' names** over them on the board. HP squares 16 to a row.
- **Part pictures** at the refinery, the trader's sell list and the auction.
- **The arena is a real fight**: two more enemies than an elite, each tougher and harder-hitting;
  its salvage starts at a rare.
- **Rares are earned**: rarer salvage in Acts 2-3, a dearer refinery and auction, warlords' hoards
  a legendary only sometimes.
- **The garage on one grid**, and NUMBERS in readable sections.

### Fixed
- Screenshot and test tools could write the player's save and profile; they have their own now.

## [031] Sites and events — 2026-10-01 ([detail](iterations/031-sites-and-events.md))

### Added
- **The arena**: a harder fight for more scrap and better salvage. **The refinery**: a part from the
  hold becomes one of the next rarity. **The auction**: a blind crate, sometimes a legendary.
- **Twenty new signal events.**

### Fixed
- A signal's "uncommon or better" could hand out a legendary.

## [030] Warlords — 2026-10-01 ([detail](iterations/030-warlords.md))

### Added
- **A warlord in every act**: a named site in the middle of the map, always visible, with its own
  rule -- the Grinder's saw ring, the Magnet King's haul, the Twin Furnaces that shield each other --
  and a hoard with a legendary part.

## [029] New weapons and legendary parts — 2026-10-01 ([detail](iterations/029-weapons-and-legendaries.md))

### Added
- **Three new weapon families**: the Slag Flamer (burns a wedge of four hexes), the Hook Harpoon
  (drags its target toward you -- into a pit, or into your blade) and the Aegis Caster (shields an
  ally). Ten new parts in all.
- **Legendary parts**: the Godhammer, the Sunspear, the Crucible Heart, the Aegis Rig and the
  Colossus Frame. Every broken gate opens the keeper's hoard, with a legendary in it.

## [028] New objectives and yard conditions — 2026-10-01 ([detail](iterations/028-objectives-and-modifiers.md))

### Added
- **HOLD** (keep a machine on the blue zone, no enemy on it, three rounds), **HACK** (end moves on
  terminals) and **SURVIVE** (outlast waves that come in on the far row) fights.
- **Yard conditions**: DUST STORM (shots reach 1 less), LIVE WIRES (sparking cables, 2 a round),
  SCRAP RAIN (piles worth double), HEAT WAVE (your machines vent 1 less).

## [027] Play-test 9 fixes — 2026-10-01 ([detail](iterations/027-playtest-9-fixes.md))

### Changed
- **The crew is Knuckles, Needle and Relay**, and any machine can be **renamed** (in the bay or
  the garage); the names stay for that crew's next run.
- **A new assembly bay**: the crew on the left, the machine big on the lift with its numbers,
  the bench of parts as cards by socket.
- **A new garage**: the machine, its loadout and its numbers side by side over the hold.
- **UNLOCKS**: every between-run unlock with what it gives, what earns it and how close you are.
- **The Pour and the Core fight back at half HP** (faster, wider, harder, with three guards) and
  have more HP; machines can be levelled to 5.
- Arms no longer sit inside their bodies. HP squares keep a fixed size, twelve to a row.

## [026] Play-test 8 fixes — 2026-10-01 ([detail](iterations/026-playtest-8-fixes.md))

### Changed
- **HP stays with its machine and on top** of the red hatching; a scrap carrier now carries a
  little green bundle at its feet instead of a mark by its HP.
- **Enemy attacks are arrows**; a lob's arrow arches. A piercing beam shows where it ends.
- **The opening card stays 5 seconds.** The garage opens once its machine is on the lift.
- **No text runs past its card** in the garage or on the fight's weapon and ability cards.
- **Acts 2 and 3 find rare parts** (and elites in Act 3 always offer one), and fight back harder;
  The Pour and the Core are tougher; defend caches no longer stand side by side.
  Run bot over three acts: 56.6%.

## [025] Act 3: the Crucible — 2026-09-30 ([detail](iterations/025-act-3.md))

### Added
- **The run goes on past The Pour** into the Crucible, the furnace-city: three new boards,
  bigger squads of rare parts, and the run's real ending.
- **Furnace flues**: grates that blow every other round for 3, marked red the round before.
- **Conduits**: every enemy next to one hits 1 harder (red links show who).
- **The Core**, the last gate: it never moves, and every third round it pulses the ring around
  it for 4 -- hit it, then get out. Breaking it wins the run. Run bot over three acts: 66.0%.

A run saved before 025 will not resume.

## [024] Play-test 7 fixes — 2026-09-30 ([detail](iterations/024-playtest-7-fixes.md))

### Changed
- **One number per hex under fire**: the total the enemy's volley (and the next round's start)
  will do there, including whatever stands in a line's way. Your aimed attack shows its own
  totals in amber; its list reads from the nearest enemy outwards.
- **No more half-second freezes** when a lot happens: effects stopped recompiling their shaders
  mid-fight, and one cause's hits land together.
- **The fight opens on a card** with the board's name and objective; the objective stays up.
- **The machine you control** stands in an amber ring with an arrow over it.
- The scrap mark sits on its enemy's HP line; crowded labels no longer slide onto the machines.
- A shove that could go two ways goes the way that does more; a piercing weapon can be aimed as
  far as its beam flies.
- The background hum no longer sounds like the sea. No numbers painted on the machines.
- **Crew machines have names** (Knuckles, Mule, Stilts; Slab, Winch, Needle; Dash, Magpie,
  Wick), not their frames'.

## [023] The feel pass — 2026-09-30 ([detail](iterations/023-feel.md))

### Added
- **Sixteen new sounds**, all synthesised: each kind of weapon, steps, pickups, warnings, shields,
  spawns, the flood, travel, salvage, winning and losing; a looping yard ambience.
- **Hits are drawn**: an inked star pops on every impact, bigger for harder hits.
- **A kill punches the camera in.** The Pour's marks and floods speak.
- **SOUND: ON/OFF** on the title.

## [022] Between-run progression — 2026-09-30 ([detail](iterations/022-progression.md))

### Added
- **Runs leave something behind**: 12 parts, two starting crews (the Wall, the Runners) and two
  harder tiers (Foreman, Reclaimed) unlock as runs are played -- by runs, fights won, reaching
  the Slag Flats, and wins. A new profile starts with 28 of the 40 parts.
- **THE NEXT RUN**: once there is a choice, NEW RUN asks for the crew and the tier.
- The run's end lists what it unlocked and what comes next; the title shows progress.
- Glossary cards for the Sentinel and The Pour (missing from 021).

## [021] Act 2: the Slag Flats — 2026-09-30 ([detail](iterations/021-act-2.md))

### Added
- **The run goes on past the Sorting Gate**: Act 2, the Slag Flats -- a new region with the same
  crew, three new boards, slag on the ground, bigger and harder-hitting squads.
- **Sentinels**: plated (1 less from every hit) and bolted down (cannot be shoved).
- **The Pour**, Act 2's gate: it marks the hexes your machines stand on and floods them with
  slag a round later, for the rest of the fight.
- Winning Act 2's gate wins the run. Run bot over both acts: 85.0%.

A run saved before 021 will not resume.

## [019] The whole roster, made of scrap — 2026-09-30 ([detail](iterations/019-the-roster.md))

The user: yes to the new Brute, to livery by maker and to TRELLIS sites; "do the rest of the roster".

### Changed
- **All 40 parts are new and are the game's models**: ten frames with their own heads, legs and
  backs; a shoulder per maker and a weapon per class; a core plate per maker; ten modules.
- **Parts look patched from scrap**: mismatched and rusted plates, bolted repairs.
- **Livery by maker** everywhere. `-- --models old` shows the previous roster.

### Added
- `tools/shot_roster.gd`; the `patch` zone.

## [018] Models, second pass — 2026-09-30 ([detail](iterations/018-models-second-pass.md))

The user on 017: the Brute was "Lego", the workshop "a yellow brick". Still behind `--models new`.

### Changed
- **The Brute**: rounded plates, a domed head with antennae, bolts, a fist on the hammer, heavier
  limbs, several colours in every part (new `steel` and `trim` zones).
- **The workshop** is TRELLIS's model (run on the user's account) with its detail and texture kept.
- Proposal: **livery by maker** (Kessler yellow, Cinder red, Vektor olive, Arclight grey).

### Added
- `clean_generated.py --keep-texture --posterize`, `Ink.dress_set_piece`.

## [017] Models: the two routes, proved — 2026-09-29 ([detail](iterations/017-models-proof.md))

Play-test 6 (PT6-5): new models, by the route the user picked -- proved on one machine and one
landmark before the rest. **Nothing changes by default**: `-- --models new` shows them.

### Added
- **The Brute rebuilt from concept art** (route A): chassis, Rend Saw, Breaker Hammer, Slug core
  -- big plates, one eye, square pauldrons, heavy two-tone legs, a pack on its back, white saw
  and sledge heads; a sixth of the triangles (`tools/blender/make_ink_parts.py`, `art/parts_new/`).
- **A generated workshop** (route C): the concept turned into a mesh by TripoSR on this Mac and
  cleaned for ink in Blender (`tools/gen3d/`, `tools/blender/clean_generated.py`, `art/sites/`).
- `--models new` (`Models`), `tools/shot_models.gd` (old and new side by side), concept art in
  `art/concepts/`, `verify_assembly -- --dir` and leg-pivot checks, `make_ink_thumbs -- --out`.

### Fixed
- The light `alu` zone rendered as structure (it was never recognised); the roster generator
  failed on `makers.json` since 011.

## [016] Ink & Rust everywhere — 2026-09-29 ([detail](iterations/016-ink-everywhere.md))

The user's verdict on the style frame: "apply this look to the entire game". Play-test 6.

### Changed
- **Every screen in ink**: title, briefing, assembly bay, the map, every site panel, the garage, tuning, the perk pick, the glossary, hints, the fight's results. Paper cards, heavy ink borders, hard shadows, comic lettering; text on the dark page lettered in paper.
- **The map**: roads as strokes, landmarks in a colour per kind of site, icon badges, the Reclaimer black edged in red, and **fog as unfinished drawing** -- pencil hatching over what is not scouted.
- **The title stage, the garage and assembly bays, every portrait and every part picture** are drawn like the fight.
- **Shots along hex edges take the better side**: the one that reaches the target, then the one that does more, then the one through fewer obstacles -- no more beams through a crate wall with the other side open.
- **The fight's HUD asks for less**: machines not picked are slim rows; card lines fit; ability cards say what the ability does.
- **Board labels never overlap**; LOCKED / MISSES read beside their badge.
- **Ability texts** rephrased, effect first. A run saved before 016 will not resume.

### Added
- `tools/make_ink_thumbs.gd` (part pictures rendered by the game), `ink_fog.gdshader`, `UIKit.on_page`, `UIKit.pressed`.

## [015] Ink & Rust: the style frame — 2026-09-29 ([detail](iterations/015-ink-style-frame.md))

The user picked art direction A. The fight is drawn in it; the rest of the game follows the
user's verdict on the frame.

### Changed
- **The fight is drawn in ink**: flat colour in three bands under one hard key, heavy ink lines on everything (three weights), no photographs, no sky, glow only on signals.
- **The board**: flat fields with ink joints; rubble stippled with outlined stones; scrap heaps as black masses edged in paper; pits black with a torn rim; drums red with hazard chevrons and a flame glyph; piles as green bolts with a glint.
- **Marks carry their meaning in their hatching**: where you can go one diagonal (fainter on slow ground), what will be hit the other, what you aim at crossed. The enemy stands on a saw-blade ring.
- **The aim preview is drawn on the board**: a drum's blast over every hex it reaches, an arrow where a killed machine's wreck is thrown.
- **KRANG!** and **BOOM!** lettered on the impacts that matter.
- **The HUD is comic panels**: paper cards with ink borders and hard shadows, Anton lettering, ink portraits in halftone frames; the hint and the tutorial coach speak in the narrator's caption box.
- **Scrap on the way**: of routes that cost the same, a machine takes the one over scrap (PT5-5, as the user meant it). Run bot 86.7%.

### Added
- Anton and Bangers (SIL OFL 1.1) in `art/fonts/`.
- `combat.tscn -- --fight-file`, `tools/frames/decision.json`, `shot_combat.gd --steps`.

## [014] Play-test 5 fixes — 2026-09-29 ([detail](iterations/014-playtest-5-fixes.md))

Play-test 5's combat points, and three points from an outside review. The look waits for
the user to pick one of [three art directions](plans/art-direction-options.md).

### Changed
- **A shove that kills throws the wreck**: whatever it lands on takes the bump (a drum goes off), a pit swallows it and its scrap, open ground takes it and its pile.
- **Pierce goes through drums and crates** (a drum goes off), counting them like machines. The arm's text says "pierce 1", "chain 2".
- **The chain arc takes the route that does the most damage** (a drum by two enemies beats a lone enemy), never into your own machines. **Scrap heaps conduct.**
- **Straighter paths**: equal-cost routes take fewer hexes (through rubble, not round it); hovering a hex draws the route; cost-2 hexes show dimmer.
- **UNDO** returns to the machine whose action it took back, weapon armed again.
- **The gate**: pylons on the back row behind the Sorter, flanked by heaps. Run bot 86.7%.

### Added
- **Fight recap** on the result screen: each machine's damage dealt and taken, kills, torn arms, and "your build at work" (sets, perks and tunings that added damage or took it off).
- **Consequence preview on the map**: what a site gives, how many enemies, whether the Reclaimer moves with you and what it swallows, whether its drones reach the fight.
- A fight map can set its own round limit; `run_bot --set combat.*` / `fight.<id>.*`; `shot_combat --move`, `shot_recap.gd`.

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
