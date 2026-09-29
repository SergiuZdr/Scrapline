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
