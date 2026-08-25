"""Generates the battlefield terrain props, one per tile type in data/terrain/tiles.json.

    blender --background --python tools/blender/make_terrain.py -- --out art/terrain

Each prop is a 1x1 metre tile that drops straight onto the grid the simulation already
uses, so terrain art and terrain rules can never disagree about where cover is.

Design rules, all of them driven by readability rather than realism:

* **Height encodes what the tile does.** A ridge is tall because it grants reach; scrap
  is chest-high because it grants the most cover; slag is a depression because it is a
  hazard you sink into. A player should be able to read the tactical value of ground
  from its shape alone, without a legend.
* **Nothing pokes above knee height except the ridge.** The constructs are the subject.
  Terrain that occludes them is terrain that has to be cropped by the camera.
* **Seeded variation.** Each tile type generates a handful of variants so a field of
  rubble is not visibly stamped. The seed is fixed, so the art is reproducible.
"""

import bpy
import bmesh
import importlib.util
import json
import math
import os
import random
import sys


VARIANTS = 3
TILE = 1.0


def load_helpers():
    path = os.path.join(os.path.dirname(__file__), "make_parts.py")
    spec = importlib.util.spec_from_file_location("make_parts", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def hex_to_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


# --- Tile builders -----------------------------------------------------------

def build_open(mp, rng, tile):
    """Cracked foundry apron. Even 'nothing here' should read as a poured concrete floor
    with expansion seams, not a blank plane."""
    pieces = [mp.box("open_slab", (TILE, TILE, 0.05), (0, 0, -0.025), bevel=0.015)]
    # A couple of seams. Barely visible individually; across a whole field they are the
    # difference between a floor and a void.
    for i in range(2):
        pieces.append(mp.box(f"open_seam_{i}", (TILE * 0.96, 0.025, 0.012),
                             (0, rng.uniform(-0.3, 0.3), 0.004), bevel=0.004, segments=1))
    return mp.join(pieces, "open")


def build_rubble(mp, rng, tile):
    """Collapsed structure: broken slab chunks with rebar sticking out of them. Passable,
    slows you, gives partial cover."""
    pieces = [mp.box("rubble_base", (TILE * 0.99, TILE * 0.99, 0.05), (0, 0, -0.02), bevel=0.01)]
    for i in range(rng.randint(4, 6)):
        size = rng.uniform(0.16, 0.30)
        height = size * rng.uniform(0.45, 0.85)
        chunk = mp.box(f"rubble_{i}",
                       (size, size * rng.uniform(0.7, 1.3), height),
                       (rng.uniform(-0.32, 0.32), rng.uniform(-0.32, 0.32), height * 0.45),
                       bevel=0.02, segments=1)
        # Tilted, because rubble that sits flat reads as furniture.
        chunk.rotation_euler = (rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25),
                                rng.uniform(0, math.pi))
        pieces.append(chunk)
    for i in range(rng.randint(2, 4)):
        bar = mp.cylinder(f"rubble_rebar_{i}", 0.012, rng.uniform(0.14, 0.26),
                          (rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), 0.10),
                          vertices=5)
        bar.rotation_euler = (rng.uniform(-0.9, 0.9), rng.uniform(-0.9, 0.9), 0)
        pieces.append(bar)
    return mp.join(pieces, "rubble")


def build_scrap(mp, rng, tile):
    """A sorted heap: stacked plate, crushed hull sections, cut pipe. The best cover on
    the field, so it is the tallest thing that is not a ridge -- roughly chest height on
    a construct, which is exactly what cover should look like."""
    pieces = [mp.box("scrap_base", (TILE * 0.99, TILE * 0.99, 0.06), (0, 0, -0.02), bevel=0.01)]

    # A stack of plate. Layered slabs read as "sorted salvage" rather than random noise.
    stack_h = 0.0
    for i in range(rng.randint(3, 5)):
        thickness = rng.uniform(0.045, 0.075)
        stack_h += thickness
        plate = mp.box(f"scrap_plate_{i}",
                       (rng.uniform(0.42, 0.60), rng.uniform(0.34, 0.52), thickness),
                       (rng.uniform(-0.10, 0.10), rng.uniform(-0.10, 0.10), stack_h - thickness / 2),
                       bevel=0.012, segments=1)
        plate.rotation_euler = (0, 0, rng.uniform(-0.35, 0.35))
        pieces.append(plate)

    # Cut pipe ends and a couple of bent hull panels leaning on the stack.
    for i in range(rng.randint(2, 3)):
        pipe = mp.cylinder(f"scrap_pipe_{i}", rng.uniform(0.05, 0.08), rng.uniform(0.20, 0.34),
                           (rng.uniform(-0.34, 0.34), rng.uniform(-0.34, 0.34), 0.09),
                           vertices=8, rotation=(math.radians(90), 0, rng.uniform(0, math.pi)))
        pieces.append(pipe)
    for i in range(rng.randint(1, 2)):
        panel = mp.box(f"scrap_panel_{i}", (rng.uniform(0.24, 0.38), 0.035, rng.uniform(0.26, 0.42)),
                       (rng.uniform(-0.30, 0.30), rng.uniform(-0.30, 0.30), 0.18),
                       bevel=0.01, segments=1)
        panel.rotation_euler = (rng.uniform(-0.45, -0.15), 0, rng.uniform(0, math.pi))
        pieces.append(panel)
    return mp.join(pieces, "scrap")


def build_slag(mp, rng, tile):
    """A tapped channel. The rim sits ABOVE the ground so the pool is visible; the
    surface sits inside it so you read 'sunken, and hot'. Crusted edges and a feed pipe
    make it a piece of working foundry rather than an orange puddle."""
    pieces = [mp.box("slag_basin", (TILE * 0.99, TILE * 0.99, 0.12), (0, 0, -0.03), bevel=0.02)]
    # A raised lip all the way round, so the pool has a container.
    for side, axis in ((-1, "x"), (1, "x"), (-1, "y"), (1, "y")):
        size = (TILE * 0.99, 0.09, 0.09) if axis == "y" else (0.09, TILE * 0.99, 0.09)
        location = (0, side * TILE * 0.45, 0.035) if axis == "y" else (side * TILE * 0.45, 0, 0.035)
        pieces.append(mp.box(f"slag_lip_{axis}{side}", size, location, bevel=0.012, segments=1))

    surface = mp.box("slag_surface", (TILE * 0.80, TILE * 0.80, 0.03), (0, 0, 0.012),
                     bevel=0.008, segments=1)
    pieces.append(surface)

    # Cooled crust breaking the surface, and a short feed spout over the rim.
    for i in range(rng.randint(2, 4)):
        crust = mp.box(f"slag_crust_{i}",
                       (rng.uniform(0.10, 0.19), rng.uniform(0.09, 0.17), 0.035),
                       (rng.uniform(-0.28, 0.28), rng.uniform(-0.28, 0.28), 0.028),
                       bevel=0.008, segments=1)
        crust.rotation_euler = (0, 0, rng.uniform(0, math.pi))
        pieces.append(crust)
    pieces.append(mp.cylinder("slag_spout", 0.05, 0.20,
                              (rng.choice([-1, 1]) * 0.40, rng.uniform(-0.2, 0.2), 0.11),
                              vertices=8, rotation=(0, math.radians(90), 0)))

    # Only the SURFACE is molten. Everything containing it -- basin, lip, crust, spout --
    # is cooled rock, and it has to be dark or the whole tile glows: a single bright
    # orange block per slag tile out-shouted the constructs, which are the subject.
    for piece in pieces:
        mp.apply_material(piece, mp.zone_material("slag_crust"))
    mp.apply_material(surface, mp.zone_material("slag_molten"))

    return mp.join(pieces, "slag"), surface


def build_ridge(mp, rng, tile):
    """A loading platform. The tallest tile, because it is the one that changes weapon
    reach and has to be visible from across the map -- so it gets a hard stepped edge
    and a kerb rather than a soft mound."""
    pieces = []
    steps = rng.randint(2, 3)
    for level in range(steps):
        inset = level * 0.11
        height = 0.18 + level * 0.14
        pieces.append(mp.box(f"ridge_{level}",
                             (TILE * 0.99 - inset * 2, TILE * 0.99 - inset * 2, height),
                             (rng.uniform(-0.02, 0.02), rng.uniform(-0.02, 0.02), height * 0.5),
                             bevel=0.022, segments=1))
    top = 0.18 + (steps - 1) * 0.14
    # A kerb along one edge and a support strut: it reads as built, not eroded.
    pieces.append(mp.box("ridge_kerb", (TILE * 0.86, 0.07, 0.07),
                         (0, -TILE * 0.40 + rng.uniform(-0.04, 0.04), top * 0.55),
                         bevel=0.012, segments=1))
    for i in range(2):
        pieces.append(mp.box(f"ridge_strut_{i}", (0.06, 0.06, top * 0.8),
                             (rng.uniform(-0.36, 0.36), -TILE * 0.42, top * 0.35),
                             bevel=0.008, segments=1))
    return mp.join(pieces, "ridge")


BUILDERS = {
    "open": build_open,
    "rubble": build_rubble,
    "scrap": build_scrap,
    "slag": build_slag,
    "ridge": build_ridge,
}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_dir = "art/terrain"
    for i, arg in enumerate(argv):
        if arg == "--out" and i + 1 < len(argv):
            out_dir = argv[i + 1]

    mp = load_helpers()
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    with open(os.path.join(root_dir, "data", "terrain", "tiles.json")) as handle:
        tiles = json.load(handle)

    built = 0
    for tile in tiles:
        tile_id = tile["id"]
        builder = BUILDERS.get(tile_id)
        if builder is None:
            print(f"  skip {tile_id}: no builder")
            continue

        for variant in range(VARIANTS if tile_id != "open" else 1):
            mp.clear_scene()
            # Fixed seed per (tile, variant): the variation is deliberate, not random
            # between runs, so regenerating does not silently change the battlefield.
            rng = random.Random(hash((tile_id, variant)) & 0xFFFFFFFF)

            result = builder(mp, rng, tile)
            emissive_surface = None
            if isinstance(result, tuple):
                obj, emissive_surface = result
            else:
                obj = result

            if tile_id == "slag":
                # Slag assigns its own materials per piece -- see `build_slag`. Painting
                # the joined object here would flatten the crust and the molten surface
                # back into one colour, which is exactly what it used to do.
                _ = emissive_surface
            else:
                base_rgb = hex_to_rgb(tile.get("colour", "222222"))
                mp.apply_material(obj, mp.flat_material(f"mat_{tile_id}", base_rgb))

            name = tile_id if VARIANTS == 1 or tile_id == "open" else f"{tile_id}_{variant}"
            path = os.path.join(root_dir, out_dir, f"{name}.glb")
            mp.export_glb(obj, path)
            print(f"  {name:14s} {mp.triangle_count(obj):5d} tris  -> {out_dir}/{name}.glb")
            built += 1

    print(f"\nbuilt {built} terrain props into {out_dir}")


if __name__ == "__main__":
    main()
