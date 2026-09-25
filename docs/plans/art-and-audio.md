# Plan — Art and audio

**Status:** rewritten in 010 (2026-09-26) as the **style bible**: the named target every
asset is scored against, the palette, the reserved-colour registry, and the read contract
of every element on screen. Where the art comes from, and how each source was judged, is
[art-sourcing.md](art-sourcing.md). The material doctrine (zones, livery, export contract)
is in `CLAUDE.md`, "The visual system", and still governs.

The frame is the `art-direction-and-readability` skill's law: **readability first,
personality second, fidelity never.** A thing on screen earns its place by answering a
question the player is asking.

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
