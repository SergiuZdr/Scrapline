"""Generates the scrapyard arena the battles are fought inside.

    blender --background --python tools/blender/make_arena.py -- --out art/arena
    blender --background --python tools/blender/make_arena.py -- --only floodlight --render

Why the arena is PROPS and not a model
--------------------------------------
Maps differ in size, so a single arena mesh would either float clear of a small map or
be cut through by a large one. Instead this builds a kit -- barrier, container, car
stack, tyre stack, floodlight, gantry -- and `battle_scene.gd` rings the play area with
it at whatever size the map turns out to be.

What the kit is FOR
-------------------
The berm of loose scrap said "there is junk here". It did not say **arena**: nothing
enclosed the fight, nothing implied anybody built the place or came to watch. These are
the pieces that do that job, in the order a viewer reads them:

* **barrier**    a low wall at the play edge -- the line the constructs fight inside
* **container**  stacked steel, the enclosing wall behind it
* **car_stack**  crushed cars: the single most legible "this is a scrapyard" object
* **tyre_stack** filler at human scale, so the constructs read as BIG
* **floodlight** the diegetic reason the yard is lit warm from above
* **gantry**     a tall silhouette on the skyline, so the arena has a horizon

Everything reuses `make_parts.py`'s zone materials, so the arena is lit by exactly the
same palette rules as the machines standing in it.
"""

import bpy
import importlib.util
import math
import os
import random
import sys


def load_helpers():
    path = os.path.join(os.path.dirname(__file__), "make_parts.py")
    spec = importlib.util.spec_from_file_location("make_parts", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# --- Props -------------------------------------------------------------------
#
# One Blender unit is one game metre, as everywhere else. A construct is ~1.3 m tall, so
# these are sized against that: a container the constructs can walk past but not over.

def build_barrier(mp, rng):
    """A concrete block with a scuffed top and a rebar stub. Waist height on a construct
    -- high enough to read as a boundary, low enough to see the fight over."""
    pieces = [
        mp.box("barrier_body", (1.60, 0.42, 0.62), (0, 0, 0.31), bevel=0.03, zone="rock"),
        mp.box("barrier_foot", (1.72, 0.56, 0.14), (0, 0, 0.07), bevel=0.02, zone="rock"),
        mp.box("barrier_cap", (1.62, 0.30, 0.10), (0, 0, 0.62), bevel=0.02, zone="rock"),
    ]
    # A worn steel capping strip -- NOT hazard ochre. `hazard` is reserved across the
    # whole game for "this will hurt you", i.e. overdrive modules. Painting it along
    # every barrier in the arena put a bright warning colour around the entire play area
    # and diluted the one signal it exists to carry.
    pieces.append(mp.box("barrier_strip", (1.30, 0.32, 0.05), (0, 0, 0.66),
                         bevel=0.01, zone="rust"))
    for index in range(2):
        pieces.append(mp.cylinder(f"barrier_rebar{index}", 0.025, 0.30,
                                  (rng.uniform(-0.6, 0.6), 0, 0.70), vertices=6,
                                  zone="rust"))
    return mp.join(pieces, "barrier")


def build_container(mp, rng):
    """A shipping container. Corrugation is what makes it read as one -- a plain box at
    this size is just a box, and the ribs cost sixteen triangles."""
    body = mp.box("container_body", (6.0, 2.4, 2.5), (0, 0, 1.25), bevel=0.04,
                  zone="scrapmetal")
    pieces = [body]
    # Vertical ribs down both long sides.
    for index in range(11):
        x = -2.6 + index * 0.52
        for side in (-1, 1):
            pieces.append(mp.box(f"container_rib{index}_{side}",
                                 (0.10, 0.08, 2.30), (x, side * 1.20, 1.25),
                                 bevel=0.012, zone="scrapmetal"))
    # Door end: two leaves and four locking bars.
    pieces.append(mp.box("container_door", (0.10, 2.36, 2.36), (3.0, 0, 1.25),
                         bevel=0.02, zone="rust"))
    for index in range(4):
        pieces.append(mp.cylinder(f"container_bar{index}", 0.045, 2.20,
                                  (3.06, -0.85 + index * 0.57, 1.25), vertices=6,
                                  zone="dark"))
    # Corner castings.
    for corner_x in (-3.0, 3.0):
        for corner_y in (-1.2, 1.2):
            for corner_z in (0.14, 2.36):
                pieces.append(mp.box(f"container_cast{corner_x}{corner_y}{corner_z}",
                                     (0.30, 0.26, 0.28), (corner_x, corner_y, corner_z),
                                     bevel=0.02, zone="dark"))
    _ = rng
    return mp.join(pieces, "container")


def build_car_stack(mp, rng):
    """Three crushed cars. The most legible scrapyard object there is: nothing else
    reads as 'this place destroys vehicles' in one silhouette."""
    pieces = []
    height = 0.0
    for index in range(3):
        # Thicker than a genuinely crushed car. At 0.34 m the slabs read as planks or
        # ramps from the game camera; a car has to keep enough depth to look like a car
        # that was flattened rather than like sheet material.
        thickness = rng.uniform(0.52, 0.72)
        length = rng.uniform(3.4, 4.0)
        width = rng.uniform(1.5, 1.8)
        slab = mp.box(f"car_body{index}", (length, width, thickness),
                      (rng.uniform(-0.16, 0.16), rng.uniform(-0.14, 0.14),
                       height + thickness * 0.5),
                      bevel=0.05, zone="rust" if index % 2 else "scrapmetal")
        # Crushed cars never stack square.
        slab.rotation_euler = (math.radians(rng.uniform(-4, 4)),
                               math.radians(rng.uniform(-6, 6)),
                               math.radians(rng.uniform(-12, 12)))
        pieces.append(slab)
        # A roof/cabin remnant so the slab reads as a CAR and not as a plank.
        pieces.append(mp.box(f"car_cabin{index}", (length * 0.36, width * 0.82,
                                                   thickness * 0.55),
                             (rng.uniform(-0.5, 0.5), 0,
                              height + thickness * 0.95),
                             bevel=0.04, zone="dark"))
        height += thickness * 0.88
    return mp.join(pieces, "car_stack")


def build_tyre_stack(mp, rng):
    """A column of tyres. Human-scale filler -- its job is to make the constructs look
    big, which nothing else in the kit does."""
    pieces = []
    count = rng.randint(4, 6)
    for index in range(count):
        pieces.append(mp.cylinder(f"tyre{index}", rng.uniform(0.40, 0.46), 0.24,
                                  (rng.uniform(-0.05, 0.05), rng.uniform(-0.05, 0.05),
                                   0.12 + index * 0.22),
                                  vertices=14, zone="tread"))
    return mp.join(pieces, "tyre_stack")


def build_floodlight(mp, rng):
    """A lattice mast with a bank of lamps.

    This is where the battlefield's warm key light is coming from. Without a visible
    source the lighting is just a setting in an Environment; with one the yard reads as
    a place somebody wired up to hold fights in after dark."""
    height = 6.4
    pieces = [
        mp.box("flood_base", (0.90, 0.90, 0.30), (0, 0, 0.15), bevel=0.03, zone="rock"),
    ]
    # Four legs converging into a mast: a solid pole at this height reads as a pipe.
    for corner_x in (-1, 1):
        for corner_y in (-1, 1):
            pieces.append(mp.strut(f"flood_leg{corner_x}{corner_y}",
                                   (corner_x * 0.32, corner_y * 0.32, 0.24),
                                   (corner_x * 0.10, corner_y * 0.10, height * 0.72),
                                   0.075, zone="scrapmetal"))
    # Cross bracing, so it reads as a lattice tower.
    for index in range(5):
        z = 0.6 + index * (height * 0.70 - 0.6) / 5.0
        span = 0.30 - index * 0.04
        pieces.append(mp.strut(f"flood_brace_a{index}", (-span, -span, z), (span, span, z),
                               0.035, zone="scrapmetal"))
        pieces.append(mp.strut(f"flood_brace_b{index}", (-span, span, z), (span, -span, z),
                               0.035, zone="scrapmetal"))

    pieces.append(mp.box("flood_head", (1.30, 0.34, 0.22),
                         (0, 0, height * 0.74), bevel=0.03, zone="dark"))
    # The lamps themselves, angled down into the arena.
    for index in range(4):
        lamp = mp.box(f"flood_lamp{index}", (0.26, 0.30, 0.26),
                      (-0.48 + index * 0.32, -0.10, height * 0.74 - 0.04),
                      bevel=0.02, zone="glow_lamp")
        lamp.rotation_euler = (math.radians(-22), 0, 0)
        pieces.append(lamp)
        pieces.append(mp.box(f"flood_hood{index}", (0.32, 0.20, 0.30),
                             (-0.48 + index * 0.32, 0.06, height * 0.74 + 0.02),
                             bevel=0.02, zone="dark"))
    # A cable run down the mast.
    pieces.extend(mp.hose("flood_cable", (0.10, 0.12, height * 0.72),
                          (0.24, 0.30, 0.20), rng, thickness=0.035, sag=0.22))
    return mp.join(pieces, "floodlight")


def build_gantry(mp, rng):
    """A crane gantry. Pure skyline: it exists so the arena has something tall behind it
    and does not end at the containers."""
    height = 8.0
    reach = 5.5
    pieces = []
    for corner_x in (-1, 1):
        pieces.append(mp.strut(f"gantry_leg{corner_x}", (corner_x * 0.8, 0, 0),
                               (corner_x * 0.28, 0, height), 0.16, zone="scrapmetal"))
        for index in range(6):
            z = 0.7 + index * (height - 1.2) / 6.0
            pieces.append(mp.strut(f"gantry_rung{corner_x}{index}",
                                   (-0.8 + (0.8 - 0.28) * z / height, 0, z),
                                   (0.8 - (0.8 - 0.28) * z / height, 0, z),
                                   0.07, zone="scrapmetal"))
    # The jib, and a hook on a cable.
    pieces.append(mp.strut("gantry_jib", (-0.3, 0, height), (reach, 0, height * 0.86),
                           0.20, zone="scrapmetal"))
    pieces.append(mp.strut("gantry_tie", (-0.3, 0, height), (reach * 0.55, 0, height * 0.93),
                           0.06, zone="dark"))
    pieces.extend(mp.hose("gantry_cable", (reach * 0.92, 0, height * 0.87),
                          (reach * 0.92, 0, height * 0.42), rng, thickness=0.045,
                          sag=0.02))
    pieces.append(mp.box("gantry_hook", (0.34, 0.34, 0.46),
                         (reach * 0.92, 0, height * 0.36), bevel=0.03, zone="rust"))
    return mp.join(pieces, "gantry")


def build_service_gantry(mp, rng):
    """The Parts station: a service portal a construct hangs in to be worked on.

    This is the first prop built for the yard HUB rather than for the battlefield, and
    the job is different. A battlefield prop only has to read at forty pixels from a
    camera that never stops moving; a station is looked AT, close, while the player
    decides something. So it carries the detail that says a machine gets serviced here --
    a hoist with real chain, a grated work deck, spools, a tool rack, work lamps aimed at
    where the construct hangs -- and the silhouette has to say "workshop" before any
    label does.

    Sized so a construct hangs clear of the ground under the beam with headroom. The
    portal is deliberately wider than one machine: a frame that fits exactly reads as a
    packing crate, and one with air around it reads as a place you walk into."""
    height = 2.62
    half_span = 1.34
    pieces = []

    # --- The portal. Legs canted outward at the base, which is both how a real gantry
    # stands and what stops the frame reading as a doorway.
    for side in (-1, 1):
        pieces.append(mp.strut(f"sg_leg{side}", (side * (half_span + 0.16), 0.0, 0.0),
                               (side * half_span, 0.0, height), 0.13, zone="scrapmetal"))
        pieces.append(mp.strut(f"sg_legback{side}", (side * (half_span + 0.10), -0.52, 0.0),
                               (side * half_span, -0.10, height), 0.10, zone="scrapmetal"))
        pieces.append(mp.box(f"sg_foot{side}", (0.46, 0.72, 0.10),
                             (side * (half_span + 0.13), -0.24, 0.05), bevel=0.02,
                             zone="rust"))
        # Cross bracing between the two legs of each A-frame.
        for index in range(3):
            z = 0.55 + index * 0.72
            pieces.append(mp.strut(f"sg_brace{side}{index}",
                                   (side * (half_span + 0.13 - 0.02 * index), 0.0, z),
                                   (side * (half_span + 0.07 - 0.02 * index), -0.50, z + 0.34),
                                   0.05, zone="dark"))

    # --- The top beam, and the trolley that runs on it.
    pieces.append(mp.strut("sg_beam", (-half_span - 0.22, 0.0, height),
                           (half_span + 0.22, 0.0, height), 0.17, zone="scrapmetal"))
    pieces.append(mp.strut("sg_beam_back", (-half_span - 0.10, -0.46, height - 0.06),
                           (half_span + 0.10, -0.46, height - 0.06), 0.11, zone="scrapmetal"))
    for index in range(5):
        x = -0.96 + index * 0.48
        pieces.append(mp.strut(f"sg_beamtie{index}", (x, 0.0, height),
                               (x + 0.30, -0.46, height - 0.06), 0.045, zone="dark"))

    pieces.append(mp.box("sg_trolley", (0.44, 0.34, 0.26), (0.0, -0.16, height - 0.20),
                         bevel=0.02, zone="metal"))
    pieces.append(mp.cylinder("sg_drum", 0.13, 0.40, (0.0, -0.16, height - 0.20),
                              rotation=(0, math.pi / 2, 0), zone="dark"))

    # --- The hoist chain, and the spreader bar a construct actually hangs from. The bar
    # is what makes this read as a lifting rig rather than as a swing.
    pieces.extend(mp.hose("sg_chain", (0.0, -0.16, height - 0.34), (0.0, -0.16, 1.86),
                          rng, thickness=0.035, sag=0.0, zone="dark"))
    pieces.append(mp.strut("sg_spreader", (-0.62, -0.16, 1.82), (0.62, -0.16, 1.82),
                           0.075, zone="rust"))
    for side in (-1, 1):
        pieces.append(mp.box(f"sg_hook{side}", (0.10, 0.10, 0.22),
                             (side * 0.58, -0.16, 1.66), bevel=0.02, zone="rust"))
        pieces.extend(mp.hose(f"sg_sling{side}", (side * 0.58, -0.16, 1.62),
                              (side * 0.40, -0.16, 1.14), rng, thickness=0.022, sag=0.03,
                              zone="dark"))

    # --- Work deck on one side, with a ladder. Human scale: the thing that says a person
    # works here, which is what makes the machine beside it read as large.
    deck_x = half_span + 0.42
    pieces.append(mp.box("sg_deck", (0.86, 1.10, 0.07), (deck_x, -0.20, 1.02),
                         bevel=0.015, zone="scrapmetal"))
    pieces.append(mp.box("sg_deck_lip", (0.86, 0.08, 0.16), (deck_x, 0.31, 1.13),
                         bevel=0.015, zone="rust"))
    for index in range(4):
        y = -0.66 + index * 0.30
        pieces.append(mp.strut(f"sg_rail{index}", (deck_x + 0.40, y, 1.06),
                               (deck_x + 0.40, y, 1.52), 0.035, zone="dark"))
    pieces.append(mp.strut("sg_railtop", (deck_x + 0.40, -0.72, 1.52),
                           (deck_x + 0.40, 0.34, 1.52), 0.04, zone="rust"))
    for index in range(4):
        z = 0.20 + index * 0.26
        pieces.append(mp.strut(f"sg_rung{index}", (deck_x - 0.30, -0.72, z),
                               (deck_x + 0.30, -0.72, z), 0.03, zone="dark"))

    # --- Work lamps under the beam, aimed at where the construct hangs. The station has
    # to be the brightest thing in the yard or the camera arriving there means nothing.
    for side in (-1, 1):
        pieces.append(mp.box(f"sg_lamphood{side}", (0.30, 0.22, 0.16),
                             (side * 0.74, 0.30, height - 0.30), bevel=0.02, zone="dark"))
        pieces.append(mp.box(f"sg_lamp{side}", (0.24, 0.05, 0.11),
                             (side * 0.74, 0.19, height - 0.32), bevel=0.01,
                             zone="glow_lamp"))

    # --- The floor of the bay, and the junk that collects around one.
    pieces.append(mp.box("sg_pad", (3.30, 2.30, 0.05), (0.0, -0.20, 0.025), bevel=0.02,
                         zone="rock"))
    pieces.append(mp.cylinder("sg_spool", 0.34, 0.46, (-half_span - 0.55, -0.62, 0.34),
                              rotation=(0, math.pi / 2, 0), zone="rust"))
    pieces.append(mp.cylinder("sg_spool_core", 0.16, 0.50, (-half_span - 0.55, -0.62, 0.34),
                              rotation=(0, math.pi / 2, 0), zone="dark"))
    pieces.append(mp.box("sg_bench", (0.92, 0.46, 0.08), (-half_span - 0.62, 0.42, 0.72),
                         bevel=0.02, zone="scrapmetal"))
    for side in (-1, 1):
        pieces.append(mp.strut(f"sg_benchleg{side}", (-half_span - 0.62 + side * 0.36, 0.42, 0.0),
                               (-half_span - 0.62 + side * 0.36, 0.42, 0.70), 0.05,
                               zone="dark"))
    for index in range(3):
        pieces.append(mp.box(f"sg_tool{index}", (0.09, 0.09, 0.30),
                             (-half_span - 0.92 + index * 0.26, 0.42, 0.90), bevel=0.01,
                             zone="metal"))
    return mp.join(pieces, "service_gantry")


BUILDERS = {
    "barrier": build_barrier,
    "service_gantry": build_service_gantry,
    "container": build_container,
    "car_stack": build_car_stack,
    "tyre_stack": build_tyre_stack,
    "floodlight": build_floodlight,
    "gantry": build_gantry,
}

## How many deterministic variants of each prop. Repetition is what makes a boundary read
## as a fence rather than as a wall somebody built out of junk.
VARIANTS = {
    "barrier": 2,
    "container": 2,
    "car_stack": 3,
    "tyre_stack": 3,
    "floodlight": 1,
    "gantry": 1,
    # One only. This is a specific place in the yard, not scatter -- a second variant
    # would mean the workshop looked different depending on which one the hash picked.
    "service_gantry": 1,
}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_dir = "art/arena"
    only = None
    do_render = False
    for index, arg in enumerate(argv):
        if arg == "--out" and index + 1 < len(argv):
            out_dir = argv[index + 1]
        elif arg == "--only" and index + 1 < len(argv):
            only = argv[index + 1]
        elif arg == "--render":
            do_render = True

    mp = load_helpers()
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

    built = 0
    for name, builder in sorted(BUILDERS.items()):
        if only and name != only:
            continue
        for variant in range(VARIANTS[name]):
            mp.clear_scene()
            # Seeded per (prop, variant): regenerating never reshuffles the arena.
            rng = random.Random(hash((name, variant)) & 0xFFFFFFFF)
            obj = builder(mp, rng)

            stem = name if VARIANTS[name] == 1 else f"{name}_{variant}"
            path = os.path.join(root_dir, out_dir, f"{stem}.glb")
            mp.export_glb(obj, path)
            if do_render:
                mp.render_preview(obj, os.path.join(root_dir, "art", "preview",
                                                    f"arena_{stem}.png"))
            print(f"  {stem:16s} {mp.triangle_count(obj):5d} tris  -> {out_dir}/{stem}.glb")
            built += 1

    print(f"\nbuilt {built} arena props into {out_dir}")


if __name__ == "__main__":
    main()
