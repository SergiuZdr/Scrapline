"""Torsos. Origin at the pelvis centre, geometry from z=0 up to TORSO_HEIGHT.

The torso is the hub of the whole kit: it publishes five mounts and the other four
categories consume them. That makes it the one category where "the silhouette is free
to vary" needs a caveat, and the caveat is enforced structurally here.

`_neck_mount`, `_shoulder_boss` and `_hip_yoke` are called by `build` for EVERY
archetype, before the archetype gets to run. They are what physically reaches the
contract's mount points. An archetype may then be a boiler barrel 0.19 m in radius or
a slab 0.24 m half-width -- the shoulder still sits at 0.34, because a boss spans the
gap from whatever the body turned out to be to where the contract says the arm goes.

Without that, a narrow torso presents its shoulder socket in mid-air and every arm
attached to it floats. It looks fine as a part, and wrong on every robot built from it.
"""

import math

AXIS_Y = (math.pi / 2, 0.0, 0.0)

from .. import config
from .. import greeble as gr
from .. import primitives as prim
from . import pick_archetype, asymmetry, repair_history


## The three REDESIGNED base torsos come first: each one is a recognisable piece of
## industrial plant rather than a shape. The four originals stay behind them so nothing
## that references them breaks while the new ones are being judged.
ARCHETYPES = ["generator_can", "engine_bay", "furnace_vessel",
              "boiler", "plated_box", "engine_block", "cage_frame"]

## The vertical band an archetype owns. Below it is the pelvis, above it the neck.
CHEST_BOTTOM = 0.14
CHEST_TOP = 0.72


def build(component):
    rng = component.rng
    component.archetype = component.forced_archetype or pick_archetype(
        component.seed, ARCHETYPES, rng)
    asym = asymmetry(rng)

    # Half-width of the body proper. The archetype gets to choose this; it does NOT
    # get to choose where the shoulders are.
    # Wider. The reference torso is a broad, deep box carrying a large chest feature --
    # a radiator grille or a lit power core -- and the shoulders sit outboard of it. A
    # narrow body under big pauldrons reads as a head on a coat hanger.
    half_width = rng.span(0.21, 0.30)
    component.recipe = {"archetype": component.archetype, "half_width": half_width,
                        "asym_side": asym["side"]}

    _hip_yoke(component, rng, half_width)
    builder = {
        "generator_can":  _generator_can,
        "engine_bay":     _engine_bay,
        "furnace_vessel": _furnace_vessel,
        "boiler":       _boiler,
        "plated_box":   _plated_box,
        "engine_block": _engine_block,
        "cage_frame":   _cage_frame,
    }[component.archetype]
    builder(component, rng, asym, half_width)
    _shoulder_boss(component, rng, half_width, 1.0)
    _shoulder_boss(component, rng, half_width, -1.0)
    _neck_mount(component, rng, half_width)
    _chest_feature(component, rng, half_width)
    _backpack(component, rng, half_width)
    _shared_dressing(component, rng, asym, half_width)
    repair_history(component, rng, [
        (asym["side"] * half_width * 0.85, half_width * 0.55, CHEST_BOTTOM + 0.16),
        (-asym["side"] * half_width * 0.80, -half_width * 0.60, CHEST_TOP - 0.16),
        (asym["side"] * half_width * 0.60, half_width * 0.50, CHEST_TOP - 0.26),
    ])
    return component


# --- Contract-bearing structure ----------------------------------------------

def _shoulder_boss(component, rng, half_width, sign):
    """Bridges the body out to the shoulder mount, and puts a joint at it.

    The bearing sitting ON the socket is not decoration. It is what a shoulder joint
    looks like, and it is also what makes the mount visibly a mount -- an arm bolted
    to a flat slab reads as glued on."""
    mount_x = sign * config.TORSO_SHOULDER_X
    inner = half_width * 0.92
    span = abs(mount_x) - inner + 0.03
    component.add(prim.box("%s_shoulder_boss_%d" % (component.name, sign > 0),
                           (span, rng.span(0.15, 0.21), rng.span(0.13, 0.18)),
                           location=(sign * (inner + span * 0.5), rng.jitter(0.012),
                                     config.TORSO_SHOULDER_Z),
                           material="DirtyMetal", bevel_width=0.012, segments=2))
    component.add(gr.bearing("%s_shoulder_joint_%d" % (component.name, sign > 0),
                             (mount_x, 0.0, config.TORSO_SHOULDER_Z),
                             radius=rng.span(0.068, 0.086), axis="x"))
    # A gusset back to the chest, so the boss is braced rather than cantilevered.
    component.add(prim.box("%s_gusset_%d" % (component.name, sign > 0),
                           (span * 0.9, 0.024, 0.14),
                           location=(sign * (inner + span * 0.5), -0.055,
                                     config.TORSO_SHOULDER_Z - 0.085),
                           rotation=(0, sign * rng.span(0.30, 0.55), 0),
                           material="OldSteel", bevel_width=0.006, segments=1))
    component.add(gr.bolt_row("%s_shoulderbolt_%d" % (component.name, sign > 0), 3,
                              (sign * (inner + 0.02), -0.070,
                               config.TORSO_SHOULDER_Z - 0.045),
                              (0, 0.070, 0.045), axis="x", rng=rng, radius=0.014))


def _hip_yoke(component, rng, half_width):
    """The pelvis, and the two hip joints the legs hang from."""
    width = max(config.TORSO_HIP_X * 2.4, half_width * 1.7)
    component.add(prim.taper_box(component.name + "_pelvis",
                                 (width, rng.span(0.20, 0.26), 0.17),
                                 top_scale=(rng.span(0.86, 1.05), 1.0),
                                 location=(0, 0, 0.072),
                                 material="DirtyMetal", bevel_width=0.014, segments=2))
    for sign in (1.0, -1.0):
        component.add(gr.bearing("%s_hip_%d" % (component.name, sign > 0),
                                 (sign * config.TORSO_HIP_X, 0.0, 0.0),
                                 radius=rng.span(0.060, 0.076), axis="x"))
    component.add(gr.rib(component.name + "_pelvis_rib", width * 0.95,
                         (0, rng.sign() * 0.11, 0.115), thickness=0.030, height=0.040,
                         axis="x", material="OldSteel"))


def _neck_mount(component, rng, half_width):
    """The collar under the HeadSocket."""
    # Derived from the contract, never hardcoded. These three sat at 0.700/0.755/0.735
    # against a socket at 0.780, so moving the head meant finding four numbers in two
    # files and the collar would have been left behind in the air.
    base = config.TORSO_HEAD_Z
    component.add(prim.taper_box(component.name + "_yoke",
                                 (half_width * 1.5, rng.span(0.17, 0.22), 0.10),
                                 top_scale=(0.62, 0.70), location=(0, 0, base - 0.080),
                                 material="OldSteel", bevel_width=0.010, segments=2))
    component.add(prim.cylinder(component.name + "_neck_ring", 0.070, 0.070,
                                location=(0, 0, base - 0.025), vertices=12,
                                material="DarkMetal"))
    component.add(gr.bolt_ring(component.name + "_neckbolt", 6, (0, 0, base - 0.045),
                               0.066, axis="z", bolt_radius=0.012))


def _chest_feature(component, rng, half_width):
    """The big thing on the front of the chest: a rad core in a recessed frame.

    Every machine on the reference sheets carries one large feature centred on its
    chest -- a radiator grille, a power unit, an armoured plate with a number on it --
    and it is the first thing the eye lands on. Without it the torso is a bare box, and
    a bare box is what a placeholder looks like.

    Mechanical rather than emissive on purpose: the GAME mounts a lit core on this face
    through `socket_core`, and two glowing things on one chest means neither is the
    damage-type signal any more."""
    if component.recipe.get("owns_chest"):
        # The redesigned archetypes build their own front -- a control panel, an engine
        # bank, a firebox door. Stacking a generic rad core on top of one made the chest
        # a pile rather than a machine.
        return
    face = rng.span(0.030, 0.055)
    width = min(half_width * 1.35, 0.30)
    centre_z = rng.span(0.40, 0.48)

    component.add(prim.box(component.name + "_chestframe",
                           (width, 0.055, rng.span(0.20, 0.26)),
                           (0, half_width * 0.55 + face, centre_z),
                           bevel_width=0.012, material="OldSteel"))
    component.add(gr.radiator(component.name + "_rad",
                              (0, half_width * 0.55 + face + 0.020, centre_z),
                              size=(width * 0.82, 0.05, rng.span(0.15, 0.20)),
                              rng=rng, fins=rng.count(5, 8)))
    component.add(gr.bolt_ring(component.name + "_chestbolt", 4,
                               (0, half_width * 0.55 + face, centre_z),
                               width * 0.46, axis="y", bolt_radius=0.013))


def _backpack(component, rng, half_width):
    """What the machine carries on its back: a tank, and stacks that vent it.

    The reference calls this out as its own component category -- fuel tank, battery
    pack, exhaust -- and it does two jobs. It gives the back of a construct something to
    be, which matters in a game where half the units on screen are facing away, and it
    breaks the torso's profile so the machine is not a slab from the side."""
    back = -(half_width * 0.55 + rng.span(0.045, 0.075))
    component.add(gr.tank(component.name + "_pack",
                          (0, back, rng.span(0.42, 0.50)),
                          radius=rng.span(0.070, 0.092), length=half_width * 1.5,
                          axis="x", rng=rng))
    for sign in (1.0, -1.0):
        component.add(gr.exhaust_stack(
            "%s_stack_%d" % (component.name, sign > 0),
            (sign * half_width * rng.span(0.45, 0.65), back + 0.015,
             rng.span(0.56, 0.62)),
            height=rng.span(0.16, 0.24), radius=rng.span(0.030, 0.040), rng=rng))
    component.add(gr.cable_bundle(component.name + "_packhose",
                                  (half_width * 0.30, back, 0.40),
                                  (half_width * 0.55, back + 0.030, 0.20), rng,
                                  count=rng.count(2, 3), radius=0.012, sag=0.05))


# --- Archetypes --------------------------------------------------------------

def _generator_can(component, rng, asym, half_width):
    """A portable generator laid across the chest: finned can, control panel, frame.

    The primary shape is the CAN -- a horizontal cylinder, which immediately separates
    this torso from anything box-shaped -- and everything else is what a generator
    carries: cooling fins down its flanks, an instrument panel on the operator side, a
    tubular carry frame around it, a fuel tank on top."""
    component.recipe["owns_chest"] = True
    centre_z = (CHEST_BOTTOM + CHEST_TOP) * 0.5
    radius = half_width * rng.span(0.82, 0.95)
    length = half_width * 1.85

    component.add(prim.cylinder(component.name + "_can", radius, length,
                                location=(0, 0, centre_z), rotation=(0, math.pi / 2, 0),
                                vertices=16, material="DirtyMetal"))
    for sign in (1.0, -1.0):
        component.add(prim.cylinder("%s_endcap_%d" % (component.name, sign > 0),
                                    radius * 1.04, 0.030,
                                    location=(sign * length * 0.5, 0, centre_z),
                                    rotation=(0, math.pi / 2, 0), vertices=16,
                                    material="OldSteel"))
        component.add(gr.bolt_ring("%s_endbolt_%d" % (component.name, sign > 0), 6,
                                   (sign * (length * 0.5 + 0.012), 0, centre_z),
                                   radius * 0.72, axis="x", bolt_radius=0.013))
        component.add(gr.cooling_fins("%s_fin_%d" % (component.name, sign > 0),
                                      rng.count(4, 6),
                                      (sign * length * 0.28, 0, centre_z),
                                      span=length * 0.34, depth=radius * 1.55,
                                      axis="x"))

    # The operator side: panel, and the pull-start it was scavenged with.
    component.add(gr.control_panel(component.name + "_panel",
                                   (0, radius * 0.98, centre_z + 0.020),
                                   size=(half_width * 0.95, 0.14), rng=rng))
    component.add(prim.cylinder(component.name + "_starter", 0.052, 0.036,
                                location=(half_width * 0.62, radius * 0.92,
                                          centre_z - 0.10),
                                rotation=AXIS_Y, vertices=12, material="RustyMetal"))

    # A tubular carry frame, which is what makes it read as portable plant.
    top = centre_z + radius * 1.08
    for sign in (1.0, -1.0):
        component.add(gr.pipe_run("%s_frame_%d" % (component.name, sign > 0), [
            (sign * length * 0.42, radius * 0.75, CHEST_BOTTOM + 0.02),
            (sign * length * 0.48, radius * 0.55, top),
            (sign * length * 0.48, -radius * 0.55, top),
            (sign * length * 0.42, -radius * 0.75, CHEST_BOTTOM + 0.02),
        ], radius=0.020, material="OldSteel", flanges=False))
    component.add(gr.pipe_run(component.name + "_framebar", [
        (-length * 0.48, 0.0, top), (length * 0.48, 0.0, top),
    ], radius=0.020, material="OldSteel", flanges=False))
    component.add(gr.tank(component.name + "_fuel", (0, 0.0, top - 0.045),
                          radius=rng.span(0.058, 0.074), length=length * 0.66,
                          axis="x", rng=rng))
    return component


def _engine_bay(component, rng, asym, half_width):
    """A vehicle engine compartment worn as a chest: block, head, pulleys, battery.

    The most literal "this came off a truck" torso in the kit. The block is the primary
    mass; the bank of cylinder heads, the belt run and the battery box are the secondary
    structures that make it an engine rather than a cube."""
    component.recipe["owns_chest"] = True
    centre_z = (CHEST_BOTTOM + CHEST_TOP) * 0.5

    component.add(gr.engine_block(component.name + "_block",
                                  (0, -0.010, centre_z + 0.020),
                                  size=(half_width * 1.75, half_width * 1.15,
                                        (CHEST_TOP - CHEST_BOTTOM) * 0.62),
                                  rng=rng, cylinders=rng.count(4, 6)))
    # Sump below, head above: an engine has a top and a bottom and it should read.
    component.add(prim.taper_box(component.name + "_sump",
                                 (half_width * 1.45, half_width * 0.95, 0.13),
                                 top_scale=(1.10, 1.05),
                                 location=(0, 0, CHEST_BOTTOM + 0.055),
                                 material="DarkMetal", bevel_width=0.012, segments=2))
    component.add(prim.box(component.name + "_head",
                           (half_width * 1.55, half_width * 0.85, 0.085),
                           location=(0, -0.010, CHEST_TOP - 0.085),
                           material="OldSteel", bevel_width=0.012, segments=2))
    component.add(gr.bolt_row(component.name + "_headbolt", rng.count(4, 6),
                              (-half_width * 0.62, half_width * 0.34,
                               CHEST_TOP - 0.038),
                              (half_width * 0.31, 0, 0), axis="z", rng=rng,
                              radius=0.014))

    # Belt run on one flank -- asymmetric, because an engine's accessory drive is.
    side = asym["side"]
    for index, height in enumerate((0.10, -0.05)):
        component.add(gr.pulley("%s_pulley_%d" % (component.name, index),
                                (side * half_width * 1.02, half_width * 0.30,
                                 centre_z + height),
                                radius=rng.span(0.048, 0.066), axis="x"))
    component.add(gr.cable(component.name + "_belt",
                           (side * half_width * 1.02, half_width * 0.30,
                            centre_z + 0.10),
                           (side * half_width * 1.02, half_width * 0.30,
                            centre_z - 0.05), rng, radius=0.012, sag=0.05,
                           material="Rubber"))
    # Battery box on the other, and the manifold that feeds the pack on the back.
    component.add(prim.box(component.name + "_battery",
                           (half_width * 0.52, half_width * 0.62, 0.15),
                           location=(-side * half_width * 0.92, half_width * 0.22,
                                     centre_z + 0.075),
                           material="DirtyMetal", bevel_width=0.010, segments=2))
    component.add(gr.pipe_run(component.name + "_manifold", [
        (-half_width * 0.55, -half_width * 0.62, centre_z + 0.10),
        (0.0, -half_width * 0.78, centre_z + 0.16),
        (half_width * 0.55, -half_width * 0.62, centre_z + 0.10),
    ], radius=0.026, material="RustyMetal"))
    return component


def _furnace_vessel(component, rng, asym, half_width):
    """A riveted furnace: tapered vessel, firebox door, hoop bands, flue.

    Tapered rather than straight-sided, which gives it the only genuinely conical
    silhouette in the set, and the firebox door gives the chest a single large feature
    that reads from any distance."""
    component.recipe["owns_chest"] = True
    height = CHEST_TOP - CHEST_BOTTOM
    centre_z = (CHEST_BOTTOM + CHEST_TOP) * 0.5

    component.add(prim.taper_box(component.name + "_vessel",
                                 (half_width * 2.0, half_width * 1.5, height),
                                 top_scale=(rng.span(0.66, 0.78),
                                            rng.span(0.70, 0.82)),
                                 location=(0, 0, centre_z),
                                 material="DirtyMetal", bevel_width=0.020, segments=3))
    component.add(prim.cylinder(component.name + "_crown", half_width * 0.74, 0.070,
                                location=(0, 0, CHEST_TOP - 0.030), vertices=16,
                                material="OldSteel"))

    bands = rng.count(3, 4)
    for index in range(bands):
        z = CHEST_BOTTOM + height * (index + 0.6) / bands
        shrink = 1.0 - 0.30 * (z - CHEST_BOTTOM) / height
        component.add(gr.rib("%s_band_%d" % (component.name, index),
                             half_width * 2.02 * shrink, (0, 0, z),
                             thickness=half_width * 1.52 * shrink, height=0.034,
                             axis="x", material="RustyMetal"))

    # The firebox: a hinged door with a latch, low and central.
    door_z = CHEST_BOTTOM + height * 0.30
    face = half_width * 0.76
    component.add(prim.box(component.name + "_doorframe",
                           (half_width * 0.98, 0.050, height * 0.40),
                           location=(0, face, door_z), material="OldSteel",
                           bevel_width=0.012, segments=2))
    component.add(prim.box(component.name + "_door",
                           (half_width * 0.80, 0.045, height * 0.32),
                           location=(0, face + 0.030, door_z), material="DarkMetal",
                           bevel_width=0.010, segments=2))
    component.add(prim.cylinder(component.name + "_doorlatch", 0.030, 0.075,
                                location=(half_width * 0.36, face + 0.052, door_z),
                                rotation=AXIS_Y, vertices=10, material="Copper"))
    for sign in (1.0, -1.0):
        component.add(prim.cylinder("%s_hinge_%d" % (component.name, sign > 0), 0.020,
                                    height * 0.10,
                                    location=(-half_width * 0.40, face + 0.030,
                                              door_z + sign * height * 0.12),
                                    vertices=8, material="OldSteel"))
    # Flue off the shoulder, on one side only.
    component.add(gr.pipe_run(component.name + "_flue", [
        (asym["side"] * half_width * 0.55, -half_width * 0.40, CHEST_TOP - 0.10),
        (asym["side"] * half_width * 0.85, -half_width * 0.70, CHEST_TOP + 0.02),
    ], radius=0.034, material="RustyMetal"))
    return component


def _boiler(component, rng, asym, half_width):
    """A pressure boiler stood on end: round, ribbed, riveted.

    Round in plan where the other three are square, so it separates in silhouette from
    directly ahead -- which is the angle a player sees a torso from most."""
    radius = half_width
    height = CHEST_TOP - CHEST_BOTTOM
    centre = (CHEST_BOTTOM + CHEST_TOP) * 0.5
    component.add(prim.cylinder(component.name + "_barrel", radius, height,
                                location=(0, 0, centre), vertices=14,
                                material="DirtyMetal"))
    component.add(prim.sphere(component.name + "_dome", radius,
                              (0, 0, CHEST_TOP - radius * 0.35),
                              segments=12, rings=6, material="DirtyMetal"))

    # Hoop and bolt-ring density is where this archetype's triangles go: five hoops at
    # 16x5 with seven bolts each is 1,500 triangles of detail that stops resolving two
    # metres from the camera. Three or four hoops read identically and leave the budget
    # for the silhouette, which does not stop resolving.
    hoops = rng.count(3, 4)
    for index in range(hoops):
        z = CHEST_BOTTOM + height * (index + 0.5) / hoops
        component.add(prim.torus("%s_hoop_%02d" % (component.name, index),
                                 radius * 1.01, 0.018, location=(0, 0, z),
                                 major_segments=12, minor_segments=4,
                                 material="RustyMetal" if rng.maybe(0.4) else "DarkMetal"))
        component.add(gr.bolt_ring("%s_hoopbolt_%02d" % (component.name, index),
                                   rng.count(4, 6), (0, 0, z), radius * 1.03,
                                   axis="z", bolt_radius=0.011))

    # A chest plate strapped over the front, because a bare cylinder has no face.
    component.add(gr.plate(component.name + "_chestplate",
                           (radius * 1.5, height * rng.span(0.40, 0.55)),
                           location=(0, radius * 0.92, centre + rng.jitter(0.05)),
                           thickness=0.026, material="DirtyMetal"))
    component.add(gr.grille(component.name + "_vent", rng.count(3, 5),
                            (0, radius * 0.98, centre - height * 0.24),
                            width=radius * 1.1, height=0.13))

    side = asym["side"]
    component.add(gr.tank(component.name + "_tank",
                          (side * radius * 0.85, -radius * 0.80, centre + 0.10),
                          radius=rng.span(0.055, 0.075), length=rng.span(0.22, 0.30),
                          axis="z", rng=rng))
    component.add(gr.pipe_run(component.name + "_feed",
                              [(side * radius * 0.85, -radius * 0.80, centre + 0.24),
                               (side * radius * 0.85, -radius * 0.80, centre + 0.30),
                               (side * radius * 0.30, -radius * 0.55, CHEST_TOP - 0.02)],
                              radius=0.022, material="Copper"))
    component.add(gr.exhaust_stack(component.name + "_stack",
                                   (-side * radius * 0.55, -radius * 0.62, CHEST_TOP - 0.04),
                                   height=rng.span(0.14, 0.22), radius=0.034, rng=rng))


def _plated_box(component, rng, asym, half_width):
    """Slab-sided armour: layered plate, heavy bolt rows, a sloped glacis.

    The heaviest-reading archetype, and the one that carries the most team paint --
    which matters, because `DirtyMetal` is the only zone the game tints."""
    width = half_width * 2.0
    depth = rng.span(0.26, 0.34)
    height = CHEST_TOP - CHEST_BOTTOM
    centre = (CHEST_BOTTOM + CHEST_TOP) * 0.5

    component.add(prim.taper_box(component.name + "_hull", (width, depth, height),
                                 top_scale=(rng.span(0.82, 0.96), rng.span(0.85, 1.0)),
                                 location=(0, 0, centre),
                                 shear=(rng.jitter(0.02), rng.jitter(0.03)),
                                 material="DirtyMetal", bevel_width=0.016, segments=2))

    # Layered plate on the front. Each layer is offset and slightly rotated, which is
    # what makes it read as ADDED armour rather than a moulded surface.
    layers = rng.count(2, 4)
    for index in range(layers):
        z = centre + height * (index / max(1, layers) - 0.32)
        component.add(prim.box("%s_glacis_%02d" % (component.name, index),
                               (width * rng.span(0.72, 0.95), 0.045,
                                height / layers * rng.span(0.62, 0.90)),
                               location=(rng.jitter(0.02), depth * 0.5 + 0.012, z),
                               rotation=(rng.jitter(0.10), 0, rng.jitter(0.04)),
                               material="DirtyMetal", bevel_width=0.008, segments=1))
        component.add(gr.bolt_row("%s_glacisbolt_%02d" % (component.name, index),
                                  rng.count(3, 5),
                                  (-width * 0.32, depth * 0.5 + 0.030, z),
                                  (width * 0.64 / 4, 0, 0), axis="y", rng=rng,
                                  radius=0.014))

    # Side skirts, one heavier than the other.
    for sign, scale in ((1.0, 1.0), (-1.0, 0.7 if asym["swap_plates"] else 1.0)):
        component.add(gr.plate("%s_skirt_%d" % (component.name, sign > 0),
                               (depth * 0.80, height * 0.62 * scale),
                               location=(sign * (half_width + 0.014), rng.jitter(0.02),
                                         centre - height * 0.10),
                               rotation=(0, 0, math.pi / 2),
                               thickness=0.024, material="DirtyMetal"))

    component.add(gr.radiator(component.name + "_rad",
                              (asym["side"] * half_width * 0.45, -depth * 0.5 - 0.030,
                               centre + height * 0.14),
                              size=(width * 0.42, 0.070, height * 0.42), rng=rng,
                              fins=rng.count(5, 8)))
    component.add(gr.grille(component.name + "_intake", rng.count(3, 5),
                            (-asym["side"] * half_width * 0.45, depth * 0.5 + 0.006,
                             centre + height * 0.24),
                            width=width * 0.30, height=0.12))


def _engine_block(component, rng, asym, half_width):
    """A vehicle engine carried as a chest, with its plumbing exposed.

    The most literal reading of the brief -- a robot built out of car parts -- and the
    only archetype whose main mass is a recognisable real object rather than
    fabricated plate. Used once in four, because used more often it becomes the thing
    every machine has."""
    height = CHEST_TOP - CHEST_BOTTOM
    centre = (CHEST_BOTTOM + CHEST_TOP) * 0.5
    block_h = height * rng.span(0.50, 0.62)
    # Held in a variable rather than rolled inline at each use. The radiator below has
    # to sit ON the front face of the block, and the block's depth is unrelated to
    # `half_width` -- placing the rad from half_width instead left it hanging up to
    # 9 cm clear of the engine on wide torsos, as a thirteen-piece detached island.
    block_depth = rng.span(0.24, 0.30)

    component.add(prim.box(component.name + "_cradle",
                           (half_width * 2.05, block_depth, 0.055),
                           location=(0, 0, CHEST_BOTTOM + 0.020),
                           material="OldSteel", bevel_width=0.010, segments=1))
    component.add(gr.engine_block(component.name + "_engine",
                                  (rng.jitter(0.02), rng.jitter(0.02),
                                   CHEST_BOTTOM + block_h * 0.5 + 0.035),
                                  size=(half_width * 1.85, block_depth, block_h),
                                  rng=rng, cylinders=rng.count(3, 5)))

    # The upper deck: whatever the engine is bolted under. This is what carries the
    # neck yoke and stops the archetype ending in a flat block.
    deck_z = CHEST_BOTTOM + block_h + 0.055
    component.add(prim.taper_box(component.name + "_deck",
                                 (half_width * 1.7, rng.span(0.22, 0.28),
                                  CHEST_TOP - deck_z),
                                 top_scale=(rng.span(0.70, 0.90), rng.span(0.75, 0.95)),
                                 location=(0, rng.jitter(0.02),
                                           (deck_z + CHEST_TOP) * 0.5),
                                 material="DirtyMetal", bevel_width=0.012, segments=2))

    side = asym["side"]
    rad_depth = 0.065
    component.add(gr.radiator(component.name + "_rad",
                              (0, block_depth * 0.5 + rad_depth * 0.5 - 0.012,
                               centre + 0.02),
                              size=(half_width * 1.4, rad_depth, height * 0.44), rng=rng,
                              fins=rng.count(6, 9)))
    component.add(gr.cable_bundle(component.name + "_loom",
                                  (side * half_width * 0.7, -half_width * 0.5, deck_z),
                                  (side * half_width * 0.4, -half_width * 0.4,
                                   CHEST_BOTTOM + 0.06),
                                  rng, count=rng.count(2, 4), radius=0.013, sag=0.07))
    for index in range(rng.count(1, 2)):
        component.add(gr.exhaust_stack("%s_stack_%02d" % (component.name, index),
                                       (side * half_width * (0.5 + index * 0.45),
                                        -half_width * 0.7, deck_z + 0.02),
                                       height=rng.span(0.13, 0.24), radius=0.032, rng=rng))
    component.add(gr.gear(component.name + "_flywheel",
                          (-side * half_width * 1.0, rng.jitter(0.03),
                           CHEST_BOTTOM + block_h * 0.45),
                          radius=rng.span(0.070, 0.100), teeth=rng.count(7, 10),
                          axis="x"))


def _cage_frame(component, rng, asym, half_width):
    """An open roll-cage carrying loose salvage: tanks, a rad, a drum.

    You can see through it. That is worth one archetype in four on its own -- a roster
    where every chest is a solid mass reads as one machine, and the cage is the variant
    that proves the others are shells rather than blocks."""
    height = CHEST_TOP - CHEST_BOTTOM
    centre = (CHEST_BOTTOM + CHEST_TOP) * 0.5
    depth = rng.span(0.22, 0.28)

    # Four corner girders and the rails tying them together.
    for sx in (1.0, -1.0):
        for sy in (1.0, -1.0):
            component.add(prim.box("%s_post_%d%d" % (component.name, sx > 0, sy > 0),
                                   (0.040, 0.040, height),
                                   location=(sx * half_width * 0.92, sy * depth * 0.5,
                                             centre),
                                   material="OldSteel", bevel_width=0.006, segments=1))
    for z in (CHEST_BOTTOM + 0.030, centre, CHEST_TOP - 0.030):
        component.add(gr.rib("%s_rail_%.0f" % (component.name, z * 100),
                             half_width * 1.90, (0, depth * 0.5, z),
                             thickness=0.034, height=0.038, axis="x"))
        component.add(gr.rib("%s_railb_%.0f" % (component.name, z * 100),
                             half_width * 1.90, (0, -depth * 0.5, z),
                             thickness=0.034, height=0.038, axis="x"))

    # The cargo. Everything sits between the rails, touching them.
    component.add(gr.drum(component.name + "_drum",
                          (asym["side"] * half_width * 0.42, 0, centre + height * 0.16),
                          radius=min(half_width * 0.62, 0.115),
                          height=height * rng.span(0.42, 0.52), axis="z", rng=rng))
    component.add(gr.tank(component.name + "_tank",
                          (-asym["side"] * half_width * 0.48, 0, centre - height * 0.18),
                          radius=rng.span(0.055, 0.072), length=rng.span(0.20, 0.26),
                          axis="z", rng=rng))
    component.add(gr.radiator(component.name + "_rad",
                              (0, depth * 0.5 + 0.020, centre + height * 0.06),
                              size=(half_width * 1.5, 0.055, height * 0.40), rng=rng,
                              fins=rng.count(5, 8)))

    # A single armour plate, so the cage still has somewhere to take team paint.
    component.add(gr.plate(component.name + "_bibplate",
                           (half_width * 1.6, height * rng.span(0.28, 0.40)),
                           location=(rng.jitter(0.03), -depth * 0.5 - 0.016,
                                     centre + rng.jitter(0.06)),
                           rotation=(0, rng.jitter(0.06), 0),
                           thickness=0.024, material="DirtyMetal"))
    component.add(gr.cable_bundle(component.name + "_loom",
                                  (half_width * 0.85, -depth * 0.42, CHEST_TOP - 0.05),
                                  (half_width * 0.6, -depth * 0.42, CHEST_BOTTOM + 0.05),
                                  rng, count=rng.count(2, 4), radius=0.012, sag=0.09))


# --- Shared dressing ---------------------------------------------------------

def _shared_dressing(component, rng, asym, half_width):
    """Welds, patches, and the hoses that tie the shoulders into the body.

    The shoulder hoses matter more than they look: without something crossing the
    boss-to-body seam, an arm mount reads as a peg pushed into a slot."""
    for sign in (1.0, -1.0):
        if rng.maybe(0.75):
            component.add(gr.cable("%s_shoulder_hose_%d" % (component.name, sign > 0),
                                   (sign * config.TORSO_SHOULDER_X * 0.92, -0.055,
                                    config.TORSO_SHOULDER_Z - 0.02),
                                   (sign * half_width * 0.55, -half_width * 0.45,
                                    config.TORSO_SHOULDER_Z - 0.22),
                                   rng, radius=0.014, sag=0.05))
    # Patches SNAP to whatever surface is nearest. The four archetypes are solid in
    # completely different places -- a cage torso is mostly air exactly where a boiler
    # is a wall -- so a patch placed at a computed coordinate is correct for the
    # archetype it was tuned against and floating for the rest.
    for index in range(rng.count(2, 4)):
        component.add(gr.snapped_patch(
            "%s_patch_%02d" % (component.name, index),
            (rng.span(0.07, 0.15), rng.span(0.06, 0.14)),
            (rng.span(-half_width, half_width) * 1.1,
             rng.sign() * (half_width + 0.02),
             rng.span(CHEST_BOTTOM + 0.05, CHEST_TOP - 0.05)),
            rng, component.pieces))

    component.add(gr.weld_seam(
        component.name + "_weld",
        (-half_width * 0.8, half_width * 0.5, CHEST_BOTTOM + 0.01),
        (half_width * 0.8, half_width * 0.5, CHEST_BOTTOM + 0.01),
        rng, count=rng.count(4, 6), size=0.016, pieces=component.pieces))
