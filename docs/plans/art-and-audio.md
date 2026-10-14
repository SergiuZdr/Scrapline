# Plan — Art and audio

**Status:** rewritten in 010 (2026-09-26) as the **style bible**: the named target every
asset is scored against, the palette, the reserved-colour registry, and the read contract
of every element on screen. Where the art comes from, and how each source was judged, is
[art-sourcing.md](art-sourcing.md). The material doctrine (zones, livery, export contract)
is in `CLAUDE.md`, "The visual system", and still governs.

The frame is the `art-direction-and-readability` skill's law: **readability first,
personality second, fidelity never.** A thing on screen earns its place by answering a
question the player is asking.

## Ink & Rust (015-016): the look of the game

The user picked [option A](art-direction-options.md) and, after the style frame, asked for it
everywhere (016). It **replaces** the photographed surfaces, the HDRI and the sodium/blue rig
described further down, which stay as the record of 010. The read contracts and the one-meaning
colour registry carry over unchanged in meaning; only the hues moved to the ink palette.

- **One place**: `scripts/presentation/ink.gd` (palette, materials, dressing),
  `ink_toon.gdshader` (three bands: lit is the palette colour exactly, mid, ink shadow; halftone
  dots between mid and shadow; one hard stripe on metal), `ink_outline.gdshader` (the ink line:
  an inverted hull at a constant screen width over smoothed normals packed in UV2),
  `ink_mark.gdshader` (board marks). Machines are built as before and DRESSED by zone
  (`Ink.dress_machine`), so `ConstructView` and `PartMaterials` did not change.
- **Three line weights, and only three** (px at 1080 lines): world 1.6, machines 2.2, things
  you act on 3.0. Scenery gets a thinner line and no hue at all (monochrome, pushed into the
  night): a red container read as danger in the first frame.
- **Light**: one hard key from the camera's left, a flat night ambient, no fill, no sky, no
  fog; glow only on signals. Lit from behind, every machine showed the camera its shadow band.
- **Structure wears its part's livery**, a shade darker. Grey limbs under a painted chest made
  every machine the same grey figure.
- **A mark's meaning is in its hatching, not only its hue**: one diagonal for where you can go
  (fainter, with a broken border, on slow ground), the other for what will be hit, crossed for
  what you aim at, dashed borders for a drum's blast. The grey copy of the first frame could
  not tell a move hex from a threatened one without its badge.
- **Whose a machine is has a SHAPE too**: yours stand on a smooth ring, the enemy's on a saw
  blade. Eyes and ring hue stay the primary read.
- **Intent badges** are ink discs ringed in red with the firing order in paper, on the ground
  at the near edge of the hex (never over the machine standing there); the shooter wears its
  number over its tag, a carrier's scrap mark sits left of it.
- **Lettering** (Bangers) only on the impacts that matter: KRANG! (a thrown wreck slams into
  something), BOOM! (a drum) -- stacked like a panel's, never overprinted.
- **HUD**: comic panels (`InkBox`: flat fill, 3 px ink border, a hard offset shadow),
  Anton for names, numbers and buttons, Barlow for body text in ink on paper, glossary links
  in a dark blue; the hint and the coach are the narrator's pale caption box. Amber still means
  your action (the armed weapon, END TURN, the band on the selected card); an armed weapon also
  carries a heavier line.
- **Everywhere (016)**: every 3D screen uses `Ink.environment()` and `Ink.key_light()` (the
  toon ramp draws the directional key alone -- point lights and spots do nothing to it, so a
  lamp is a lit bulb); scenery is monochrome, landmarks keep a livery per kind of site
  (`Ink.dress_prop`); the map's fog is **unfinished drawing** (`ink_fog.gdshader`); part
  pictures are rendered by the game (`tools/make_ink_thumbs.gd`, `art/thumbs_ink/`).
- **Interface everywhere (016)**: `UIKit` is paper and ink (the old constant names, new values);
  text on the dark page or the 3D world is `UIKit.on_page` (paper, an ink edge); a selection is
  an amber border with ink lettering -- amber text does not read on paper.
- **Contrast** (`measure_contrast.gd`) now hides labels in both renders -- the new tags are big
  paper lettering, and counting them as surroundings measured the lettering, not the ground.
  Both looks measured with that ruler: the machines stand out more in ink on every fight.
- **Models for ink (017)**: see [models.md](models.md). Big plates with one chamfer (a chamfer
  is a clean band; many small facets are noise), nothing smaller than a line can surround, the
  one light value (`alu`) on the weapon heads so the weapon reads first at board distance, and
  a back worth seeing -- the board's camera stands behind the crew.

## The named target

"Stylised" is not a target. These are:

| Reference | What it fixes |
|---|---|
| `art/reference/worker_unit.png`, `brawler_03_and_arena.png` ([STYLE.md](../../art/reference/STYLE.md)) | The machines: worn yellow / oxide red / olive paint chipped to rusted steel, **dirty aluminium** hydraulics as the one light value, big plate feet, a low head, asymmetric arms, a stencilled two-digit number |
| *Into the Breach* (Subset Games) | The board: every tile, unit and intent readable at phone size in one glance; the enemy's next move drawn on the board |
| Simon Stålenhag's industrial night paintings | The world: machines too big for the landscape, sodium and cold light, haze, stillness |
| Ian McQue's junk-built vehicles | The kitbash: bolted plates, visible mechanism, nothing smooth |

Scored per asset: does it look like it belongs on the reference sheet (materials, wear,
proportion)? does the board still read like *Into the Breach* at 40 px? does the world read
as a Stålenhag night?

## The palette

Night. **Warmth comes from the light, never the pigment** (a warm key over warm albedo put
everything in one orange band). Surfaces are cool and neutral; the sodium key and the cold
blue fill do the colour.

| Layer | Value | Rule |
|---|---|---|
| Sky, fog | darkest | Never competes; the HDRI lights and reflects, the camera does not see it |
| Ground, board, scenery | low | Photographed texture at **capped frequency** (large scale, soft normals), tinted into broad fields. Terrain types are told apart by field colour first, texture second |
| Machines | mid-high | The brightest solid things on screen. Worn livery paint; aluminium is their highlight |
| Signals (below) | highest | Emissive or unshaded, and nothing else on screen is allowed to be this bright |

**Measured, not argued**: `tools/measure_contrast.gd` renders a fight twice (whole, and
machines alone) and reports the machines' luminance against their surroundings. That margin
may only grow.

## Reserved colours — one meaning each

A signal colour means one thing everywhere, or it stops meaning anything.

| Colour | Means | Used on | Never on |
|---|---|---|---|
| **Blue** (`4fa8d8` family) | **Yours**: your machines and where they can go | Player eyes and rings; move tiles; reachable sites on the map; UI info | Anything hostile |
| **Red** (`d8654f` → `ff3b24` family) | **Danger**: the enemy and what will hit you | Enemy eyes and rings; enemy fire tiles and lines; the Reclaimer; the hive pad's last-turn warning | Decoration, the arena, UI chrome |
| **Amber** (`e5b33d`) | **Your action**: what you are about to do | The primary button (one per screen); an armed weapon's targets; the selected machine; the crew's site on the map | Objectives, scenery (defend caches used it until 010; they wear your blue now — a cache is yours to protect) |
| **Copper** (`UIKit.GOLD`, `d68b52`) | **Machine condition** | Heat, a torn arm, a bump (HUD and floats) | The world |
| **Green** (`98ae58`) | **A gain** | Scrap you can take, a carrier's scrap mark, level-up gains, healthy HP | Enemies |
| **Purple** (`a070e0`) | **Something is being built** | A hive's pad and the beam to it | Anything else |
| **Hazard ochre** | **This machine can overdrive** | Overdrive modules only | The arena, UI |
| **Core lens colours** (kinetic white, thermal orange, emp cyan, corrosive green) | **Damage type** | The core's lens, and nothing else on the machine | Team or UI signals |
| **Rarity** (grey, blue, copper) | **How rare a part is** | Part cards and part names only — the loot convention | Anywhere outside a part |

Known overlaps, deliberate: red is one family (the enemy, its fire and the Reclaimer are
all *danger*); blue covers "yours" and "you can go there" (both are the player's agency).

## Read contracts

| Element | The question it answers |
|---|---|
| Machine silhouette | What role is it? (proportion, not size — `ROLE_PROPORTION`) |
| Eyes + ground ring | Whose is it? |
| Core lens | What damage does it deal? |
| Tag (HP, status) | How close is it to breaking; is it anchored, shielded, marked? |
| Scrap mark over an enemy | Will it drop a pile? |
| Red target hexes, numbered badges | What will be hit, in what order? |
| Tile field colour | What does this ground do (rubble, slag, ridge, pit)? |
| Steel curb | Where does the board end? |
| Hive pad + numeral | Where does the next drone come from, and when? |
| Level kit (armour, chest plate, stacks) | How far has this machine been built up? |
| Fog | What has not been scouted? |
| Reclaimer gauge + ghost wall | When does it move, and where to? |

An element that cannot name its question is decoration competing with the ones that can.

## Audio

Still the synthesised PCM bank in `scripts/autoload/audio.gd` (no files to license). Music
is a later decision: licensed, commissioned or generated.

**The yard's ambience (024)** is machinery idling: two low drones beating slowly and a faint
transformer whine, no noise. The first one (023) swelled filtered noise and read as surf (the
user: "this game is not about the beach").

**No numbers on the machines (024).** The stencilled crew number (010) is gone at the user's
word; a crew machine is told by its name, its card and, in the fight, the amber ring when it is
the one under your hand.

**Effects and shaders (024).** Every short-lived material goes through `Ink.hold`, no effect lights
an OmniLight3D, and a transparent material is additive rather than emissive -- each of these
compiled a shader mid-fight (up to 850 ms a frame here). New effects join the fight's warm-up.

## The print pass (036, a frame)

`Ink.print_pass(parent, layer)` puts `ink_print.gdshader` on a CanvasLayer UNDER the screen's
interface: the 3D world is printed (a 6 px dot screen below luminance 0.3, plates 1.5 px apart,
grain, warm highlights) and the HUD is not. On the fight, the map and the title; `-- --look plain`
turns it off. Ink lines 2.0 / 3.0 / 3.6; totals in starbursts; the round in a caption box.
Contrast unchanged (2.91 both ways, slag_pit). Awaiting the user's verdict before it spreads.

## The comic, all the way (039)

On top of 036's print pass: speech balloons (`BalloonTail`; the info panel points at its subject,
hints have tails), thought clouds over enemies with intents, sound-effect lettering per damage type,
speed and focus lines, a panel border (in `ink_print.gdshader`) and page turns (`Juice`), caption-box
titles (`UIKit.caption_title`), inked models (hatching in the shade band, a rim stroke, a brush line
in `ink_outline.gdshader`), and story strips (`ComicStrip`, `CombatHUD.show_opening_strip`).
Every new effect is drawn once behind the opening card. Contrast 2.92.

## Machines printed, deaths drawn (067-068)
Every machine surface is `Ink.comic_machine`: a generated part's texture is posterised into four flat
steps (hue kept), its darkest texels inked, ink lines drawn wherever its value changes sharply (plate
edges, bolts, rust borders; 068), the shade band cross-hatched and the lit silhouette rimmed in white.
The world behind stays quieter so machines read first. A death uses the hit's vocabulary
(`BattleVFX.on_break`): impact stars, cartoon blasts, shards, drawn dust and floor action lines; nothing
glows or fades.

## Motion (059)
Machines move **pose to pose, like comic panels** (`ConstructRig`): every motion is a clip of key poses
over named channels (body, upper body, each arm's joints, each foot), reached with SNAP / SMEAR / EASE /
BACK / STEP curves and HELD. Anticipation is a held key before the action; the impact is a held pose,
then a rebound past rest and a settle; stepped keys (no in-betweens) for sputters, ticks and grinds.
Each weapon class has its own strike; each chassis role its own run. The fight shows a strike's effect
at its impact (`strike` returns the lead), and a death plays out before the wreck becomes scrap.

060: a death FALLS APART (an arm breaks off first, the machine looks at it, reaches, kneels, goes over;
its core rolls out), and nothing of a machine ever goes under the floor -- checked on its posed
vertices by `tools/probe_floor.gd`.

074: **every ranged arm fires its own way and leaves its own trail** (`data/fx/weapons.json`, read by
`WeaponFX`; presentation only, not in the content hash). `fire` is a `ConstructRig.strike` style (a class's
strike, or one of `FIRE_STYLES`), `trail` a `ShotFX` kind drawn from the gun's real tip
(`ConstructRig.muzzle`). Trails are additive glow pieces held through `Ink.hold` and warmed behind the
opening card. A new ranged arm needs a row there, or `verify_animation` fails. Sheets:
`tools/shot_trails.gd`.

074: a generated arm sits ON its shoulder: `ConstructView._snug_arms` draws it in until the inner edge of
its silhouette at shoulder height (a low percentile, not one stray bolt) is just inside the socket.

## Appendix: Rust & Sodium (010) and the procedural roster

Moved here from the agent notes on 2026-10-12. Ink & Rust (015-016) replaced this look; kept for its reasons.


The look is a working scrapyard at night: **warm sodium key light, cold blue fill, cool
neutral surfaces**. Warmth comes from the LIGHT, never from the pigment. A warm albedo
under a warm key put every pixel in the same orange band and the palette stopped being
two colours — constructs, terrain and berm all measured the same.

**A part is tagged with a material ZONE, not a colour.** `tools/blender/make_parts.py`
tags every piece (`paint`, `metal`, `rust`, `dark`, `tread`, `hazard`, `glow_*`) and the
name survives into the `.glb` as `mat_<zone>`. `scripts/presentation/part_materials.gd`
is the other half of that contract and the only place a construct's look is decided.

| Zone | What it is |
|---|---|
| `paint` | Large armour surfaces. **The only team-tinted zone.** |
| `metal` | Worn structural gunmetal: legs, barrels, frames |
| `rust` | Ground contact and heat stain: feet, toes |
| `dark` | Recesses and exposed mechanism: pistons, bolts, vents, rails |
| `alu` | Dirty aluminium: the machines' one LIGHT value (hydraulic rods). Wired in 010, **not yet exported** — see below |
| `hazard` | Warning ochre. **Overdrive modules and nothing else** |
| `glow_*` | Emissive: visors, and one per damage type for the core lens |

**A 0.9-metallic zone is lit by what it REFLECTS, so it needs something to reflect.**
`metal` at albedo `6b6259` was tuned when it was a minority zone on a mostly-`paint`
model. The scrap bridge made it the majority — head, arms and legs — and two thirds of
every construct rendered as a featureless black void, geometry and all. The albedo and
roughness are lifted now (`8a8074`, 0.52), and `gait_preview.tscn` was given a real sky:
against `BG_COLOR` there is no radiance map at all, so the scene that exists to judge
the models was hiding most of each one. **A preview lit differently from the battle is a
preview that lies.**

**Paint wears, and the wear is TRIPLANAR noise, not a texture map.** None of this
geometry has UVs — the generator makes raw bevelled boxes and the exporter deliberately
writes no texcoords, because a single float of UV drift was breaking export
reproducibility. `uv1_triplanar` needs none, the mask is a `NoiseTexture2D` built at
load, and nothing new ships. Two settings decide whether it reads as wear or as
camouflage: the noise has to be FINE (0.12, not 0.035 — panel-sized blotches read as
disruptive pattern) and the ramp has to be heavily biased toward intact paint, so only
the darkest fifth shows as worn through. A 50/50 mask is a different machine.

**Piece ORDER decides the whole component's transform.** `prim.join` makes the first
piece the active object and the joined mesh inherits ITS transform, so a first piece
carrying the 90 degree rotation an x-axis cylinder needs turns the component and every
socket on it a quarter turn. An arm's `WeaponSocket` landed at (0.62, 0.10, 0.00)
instead of (0.00, 0.10, -0.62). Put an unrotated piece first.

**`verify_scrap_exports.py` restates the contract by hand, and that is the point.** When
`TORSO_HEAD_Z` moved, the external checker failed all four torsos -- correctly. Updating
its restated number is a second person signing off a deliberate contract change, not a
formality; a checker that imported `sockets.py` would have agreed with the move
silently and caught nothing.

**Five structural things separate a machine from a mannequin**, all read off
`art/reference/` and all now built for every archetype rather than for some:

- **The head sits BETWEEN the shoulders.** `config.TORSO_HEAD_Z` — it used to mount at
  `TORSO_HEIGHT - 0.02`, which is 0.18 above the shoulder plane before the neck post,
  and a box on a stalk above the shoulder line is one of the strongest cues a silhouette
  can give that it is a PERSON. The neck post shortened with it.
- **The chest carries one big feature** (`torso._chest_feature`) — a rad core in a
  recessed frame. Mechanical, not emissive: the GAME mounts a lit core on that same face
  through `socket_core`, and two glowing things on one chest means neither is the
  damage-type signal any more.
- **The back carries a pack** (`torso._backpack`) — tank, stacks, hoses. Half the units
  on screen are facing away, so the back needs to be something.
- **The elbow BREAKS, and a ram drives it.** The elbow sat 2-6 cm behind the
  shoulder-wrist line, which is inside the width of the arm, so every archetype was one
  straight pole with a bearing on the middle of it.
- **Legs are heavy columns.** 6-10 cm tubes under a torso widened to 0.60 across read as
  stilts.

**Anything derived from a contract position must READ it, not repeat it.** `_neck_mount`
hardcoded 0.700/0.755/0.735 against a socket at 0.780, so moving the head meant finding
four numbers in two files — and missing one leaves the collar behind in mid-air.

**A machine STANDS differently from a person, and the rest pose is most of the read.**
Every leg archetype planted its ankle at x=0 — directly under the hip — with a knee
straight to within 2 cm, and the arm hung vertically with the weapon modelled along +Y
sticking horizontally out of the bottom of it. Feet together, knees locked, one arm held
out: that is a person standing at attention holding something, and it is what made the
roster read as people rather than as machinery dumped in an arena.

- `config.STANCE_WIDTH` plants each foot outboard of its hip; `config.KNEE_FORWARD`
  breaks the knee forward so the leg carries weight instead of locking.
- `make_scrap_parts.WEAPON_REST_PITCH` droops the weapon at the wrist. Melee hangs
  further than a gun, because a barrel angled at the floor reads as unloaded — and the
  droop pivots on the MOUNT, which is safe only because the generator authors every
  weapon with its mount at the origin.

**Silhouette weight comes from the shoulders, the feet and the width — in that order.**
Measured against `art/reference/`, the roster was too light everywhere:

- **Every arm carries a pauldron now**, not one archetype in four. It is the biggest
  single object in a shoulder's outline, so three quarters of the roster having a bare
  joint read as three quarters of the machines being lighter than their stats say. What
  varies by archetype is the mechanism visible UNDER it.
- **A pauldron is seated OVER the joint, not above it**, and wears the machine's own
  livery. Perched high and painted rust it read as orange wings.
- **Feet are wide flat plates** — the overhang past the shank is what stops a heavy
  frame reading as balanced on sticks.
- **Torsos are wider and deeper.** A narrow body under big pauldrons is a head on a
  coat hanger.

**Paint is LIVERY. The team lives in markers that do nothing else.**
See `art/reference/STYLE.md` — the reference sheets carry no blue at all, and forcing a
construct's largest surface to answer "whose is it" is what made every machine a flat
block of UI blue or UI red. Now:

- `PartMaterials.LIVERY` — worn yellow, oxide red, olive, primer grey, worn orange,
  chosen per PART id, so a Brute is the same colour everywhere and a scavenged arm does
  not match the frame it is bolted to.
- `PartMaterials.TEAM_ZONES` — currently `glow_visor` alone. The eyes ARE the team.
- A ring on the board under every machine (the combat scene).

**Two channels, because each one alone has a blind spot.** Lit eyes are the strongest
read at distance, but a machine turned away or buried in a six-on-six melee shows none;
a ground ring is visible from every angle and is never occluded by its own unit. Neither
channel may ever be used for decoration — the moment a ring or an eye means something
else, the team read is gone.

**A thumbnail must wear the same livery the game draws.** `make_scrap_parts.livery_of`
mirrors `PartMaterials.livery_of` — the same FNV-1a over the same list. When the game
stopped painting parts team blue and the thumbnails did not, every card in the garage
became a picture of a machine that does not exist.

**Never apply `material_override` to a whole construct.** That was the original bug: one
flat team colour on every mesh threw away every bevel, rib, piston and vent the generator
exists to produce, and twelve machines rendered as twelve monochrome silhouettes in red
and blue. Tinting is per-SURFACE, and only `paint` takes the team colour. Terrain works
the same way — slag's basin is cooled rock and only its pool is molten.


**`scripts/ui/ui_kit.gd` is the only description of the interface.** Every screen and
the in-fight HUD build from it. Two screens that style themselves independently drift on
exactly the details a player reads as polish. Colour is a signal, not decoration:

- **Amber** — the primary action. **One per screen**, or it stops meaning anything. It is
  also the selection marker.
- **Blue** information, **green** gains, **red** costs and danger, **gold** premium only.

**"One per screen" has to survive screens that repeat an action**: where a screen offers
several equal choices there is no primary at all; those use `UIKit.choice` (an amber
outline, obviously pressable, not a saturated block).

Godot's default theme is the loudest "prototype" signal an interface can send, and it
reaches controls no call site touches — scrollbar grabbers, tooltips, disabled states.
`UIKit.apply(root)` is called once per screen root to catch all of them.

**The fonts are bundled, with their licences, in `art/fonts/`** (all SIL OFL 1.1):
Barlow Semi Condensed for everything a player reads (`UIKit.font()`, `font_strong()`,
`font_numbers()` with tabular figures), Anton for titles (`font_comic()`, also
`font_display()`), Bangers for sound effects only. Any new face needs its OFL (or equivalent)
licence file beside it in the same commit.

The palette is the reference sheets' material list, not a UI palette: warm dark steel
surfaces, dirty aluminium text, and the `AMBER` constant is now construction yellow
(`e5b33d`). The constant names are unchanged so no call site moved.

Regenerate art after touching either generator:

```bash
# THE ROSTER IN art/parts/ COMES FROM make_scrap_parts.py, NOT make_parts.py.
blender --background --python tools/blender/make_scrap_parts.py -- --out art/parts
$GODOT --path . --script res://tools/make_ink_thumbs.gd   # the part pictures (art/thumbs_ink)
$GODOT --headless --path . --import   # register new class_name / reimport .glb
```

**The style bible is `docs/plans/art-and-audio.md`** (010): named references, value layers,
the **reserved-colour registry** (blue = yours, red = danger, amber = your action, copper =
machine condition, green = a gain, purple = being built, ochre = overdrive, lens = damage
type, rarity colours on parts only) and a read contract per element. A new colour use
goes through that table first.

**Contrast is measured, not argued**: `tools/measure_contrast.gd -- --fight <id> [--json f]`
renders a fight whole and machines-only and prints machines vs. surround luminance. 1.8-1.9
before 010, 2.1-2.3 after. **That ratio may only grow.**

**Machine paint wears through a baked map**,
`art/textures/paint_wear.png` (`tools/make_wear_texture.py`: white where paint survives,
rust-orange where worn), multiplied by the livery -- a photographed red-rust texture
multiplied by yellow livery comes out brown, so the photo is baked hue-free first. Object
triplanar, because the parts have no UVs. **No numbers are painted on the machines** (the
user, play-test 7: `ConstructView._stencil` is gone); crew machines carry their crew's NAMES
instead (`run.json` `starting_crew`, `meta.json` crews), never their frame's.

**The title screen is a scene** (`scripts/ui/title_stage.gd`): the default crew numbered
01-03 on a hardstand, kit props, a floodlight, and the Reclaimer's red beacons on the
horizon. Display classes take `db`, never the `Run` autoload.

**`make_scrap_parts.py` does NOT reproduce the committed roster** (found in 010): a
regeneration changed the heads and dropped most pauldrons (`builders/arm.py`'s
`SHOULDER_STYLE` gives a pauldron to one archetype in seven; the shipped roster has one on
every arm, as this file says). It was rolled back with `git checkout -- art/parts`. **Do not regenerate the roster until that is settled** (open question in
`docs/MEMORY.md`); the `alu` zone ships with the next export.


## Appendix: animation notes

Moved here from the agent notes on 2026-10-12.


Chassis are **not** one welded mesh. Each leg exports as a child object named
`limb_leg_l` / `limb_leg_r` with its **origin on the hip joint**, so rotating the object
is the hip articulating — no armature, and a new chassis needs no rigging pass.
`ConstructRig` drives it and never computes an outcome: it is told a unit is moving,
told when it strikes, and told it was hit from a direction.

**Attack shape comes from `weapon_class`** in `data/parts/arms.json` — the same field
that picks the weapon's model, so the motion and the silhouette can never describe two
different weapons. Note that arms have **no `damage_type`** (that is on cores); an
earlier attempt to vary arms by damage type silently did nothing at all.

**The gait is not a sine.** A sine spends half its cycle either side of neutral and
moves fastest through the middle, which is backwards: the planted foot should be still
while the body travels over it, and the free leg is what moves quickly. `STANCE_FRACTION`
(0.42 now) — stance is a straight ramp, swing is a fast smoothstep. Two opposed sines read
as marching in place, which is what the roster did for a long time.

**A wreck topples; it does not flatten.** Destruction used to squash a construct to 5%
of its height where it stood — completely legible as "this unit is gone", and not a
physical event at all. The fall is angular about the FEET, which is free because the
body's origin is already at ground level: nothing has to be moved, and it cannot sink
through the floor on the way down. `collapse` is idempotent, because SKIP drains the
whole event queue in one frame and `DESTROYED` can arrive twice.

**`reset_transients` must not resurrect the dead.** Without a guard it stands every
wreck back up while the player studies the board.

**Reactions are a spring, not a tween**, and the three reasons are all load-bearing:
tweens do not COMPOSE (six units focusing one target produce six competing animations
and the last one wins, so a focused volley looks exactly like a single hit); a tween
caught mid-flight when playback stops FREEZES a construct leaning at 20°; and a spring scales honestly with severity. Firing
uses the same mechanism — to the body, a railgun's kick and a hit from the front are the
same event.

**The reaction integrator runs at a fixed 120 Hz**, not once per frame. Stepped per
frame it damps per frame, so the same hit travelled 3.5 cm at 60 fps and 0.4 cm at 15 —
the reaction quietly vanishing on exactly the phones least able to spare frames. Testing
each frame rate in isolation calls all three "stable"; only comparing them finds it.

**A reaction can be correct and invisible.** The first stagger was stable, correctly
signed, well damped and moved a construct 3.5 cm — about two pixels at battle distance.
Every test passed. `verify_animation.gd` now asserts a floor on how far a heavy hit
actually moves the machine, because "it animates" and "you can see it animate" are
different claims.

The combat scene converts the attacker's position into the **target's own space**
before handing it to the rig. The rig animates a model already turned to face its
heading, so a world direction makes every construct lurch toward world north.

```bash
# The ONLY honest way to check a walk cycle: hold a construct moving and film it.
$GODOT --path . res://tools/gait_preview.tscn --resolution 560x560 -- \
    --shot /tmp/gait --frames 8 --every 6 [--chassis ch_strider] [--strike]
# Same for a stagger. --stagger-from front|back|left|right, so the SIGN can be checked
# rather than assumed from the fact that something moved.
$GODOT --path . res://tools/gait_preview.tscn --resolution 460x460 -- \
    --shot /tmp/stag --frames 6 --every 3 --still --stagger --stagger-from left
python3 tools/blender/compose_sheet.py /tmp/gait /tmp/gait.png 8
```

Catching a walking unit in a live battle screenshot does not work — every attempt
photographed a construct standing still, and "no errors in the log" is not evidence that
a limb moved. **`--still` names its frame after the chassis** so a shell loop can build a
roster sheet; that is right for one frame and wrong for a sequence, where all eight
renders write to one file and compose as a one-frame sheet that looks like the animation
never played.
