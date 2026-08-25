# Blender part pipeline

Generates every construct part as a low-poly hard-surface mesh, straight from
`data/parts/*.json`, so the art set can never drift from the actual roster.

## Run it

```bash
brew install --cask blender          # once

blender --background --python tools/blender/make_parts.py -- --out art/parts
blender --background --python tools/blender/make_parts.py -- --only ch_brute --render
```

`--render` also writes a three-quarter PNG per part to `art/preview/`, which is how
silhouettes get reviewed without opening Blender.

## The socket contract

This is the part that matters, and it must not drift:

* One Blender unit is **one game metre**. A chassis stands roughly 1.1 m.
* Every **chassis** exports four empties: `socket_core`, `socket_arm_l`,
  `socket_arm_r`, `socket_module`.
* Every **attachment** (core, arm, module) is modelled with its mount **at the origin,
  facing +Z**, so the runtime can parent it to a socket with an identity transform.

Get that right and any arm bolts onto any chassis with no per-combination fixups.
Get it wrong and every combination needs a manual offset — which is the whole reason
modular art projects collapse.

## Budget

`TRI_BUDGET = 1500` per part. Twelve constructs on screen is then under 50k triangles,
which is nothing on the target hardware. The script prints the count for every part and
lists anything over.

## Terrain

```bash
blender --background --python tools/blender/make_terrain.py -- --out art/terrain
```

One 1x1 m prop per tile type in `data/terrain/tiles.json`, three seeded variants each so
a field of rubble is not visibly stamped. **Height encodes function**: a ridge is tall
because it grants reach, scrap is chest-high because it is the best cover, slag is a
sunken pool because it is a hazard. A player should read the tactical value of ground
from its shape without a legend.

The slag rim must sit *above* y=0. The first version buried the whole basin under the
ground slab and only stray crust poked through.

## Review renders

```bash
blender --background --python tools/blender/render_sheet.py -- --out art/preview/sheet.png
blender --background --python tools/blender/render_sheet.py -- --out art/preview/assembled.png --assembled
```

`--assembled` bolts whole constructs together through the same socket lookup the game
uses. That is the only honest check: a part can look fine alone and wrong on a frame.

Two traps, both already hit:
* `bpy.context.view_layer.update()` before reading `matrix_world`, or bounds describe
  where objects *used to be* and the camera frames nothing.
* Run it through `importlib` (see the diag pattern in the session) if `--python` on the
  file directly goes quiet — Blender can swallow the traceback.

## Status

**Working on Blender 4.5.12 LTS.** 20 parts + 13 terrain props generate, export, import
into Godot with sockets intact, and assemble correctly at runtime.
