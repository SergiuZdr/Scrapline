# Plan — Art and audio

**Status:** draft (Iteration 000). Mostly carried over; a feel pass comes in 008.

## Direction: unchanged

"Rust & Sodium" stays: a working scrapyard at night, a warm sodium key with a cold blue
fill, and worn livery paint. The detailed doctrine in `CLAUDE.md` (material zones,
livery vs team markers, silhouette rules, export contract) is still correct and still
governs.

## What changes for a grid game

| Old | New |
|---|---|
| Camera framed a free-roaming 6v6 fight | Fixed tilted camera over an 8×8 board; the board must read at phone size |
| Team read = lit eyes + ground ring | Keep both. Rings also show selection and intent targets |
| Arena ring kit around a free map | Same kit, now dressing the board's edges per site type |
| Hit-stop, springs, stagger rig | Keep. Turn-based play gives each hit more room to land |
| Continuous walk cycles | Tile-to-tile moves, so the gait needs clean start and stop |

## New art needs

- **Tile set** for the grid: open, rubble, scrap heap, ridge, slag, walls. Built on
  `make_terrain.py`.
- **Intent markers**: arrows, target highlights and order numbers. They must read in both
  a busy scene and a small screen.
- **Part-damage states**: damaged (sparks, bent panels) and torn off (dropped part mesh
  on the tile). The generator already builds each part separately, so a torn-off arm is
  the existing arm `.glb`.
- **Region map art**: a top-down stylised scrapyard with site icons.
- **Enemy factions**: livery sets for each faction via the existing `LIVERY` system.

## Audio

Keep the synthesised-PCM `audio.gd` for now (no assets to license). Music is a later
decision: licensed, commissioned or generated.
