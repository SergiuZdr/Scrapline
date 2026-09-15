"""Heads. Origin at the NeckSocket, geometry above z=0.

A head is 12% of a robot's volume and most of its identity, because it is where a
viewer looks first and the only part with anything like a face. The four archetypes
are deliberately different KINDS of object rather than four shells: a welded box, a
drum on its side, a sensor wedge, and an open cage with a lamp in it. At the distance
this game is played, that is the difference a player can actually read.
"""

import math

from .. import config
from .. import greeble as gr
from .. import primitives as prim
from . import pick_archetype, asymmetry, repair_history


## The three REDESIGNED base heads first. Each is a real piece of equipment somebody
## bolted on where a head goes -- a camera, a welding hood, a control enclosure -- which
## is the whole difference between a machine and a mannequin with a box for a face.
ARCHETYPES = ["camera_housing", "welder_hood", "control_box",
              "visor_box", "cyclops_drum", "wedge_sensor", "cage_lamp"]

## Blender +Y is forward, so a face is on the +Y side. Getting this backwards builds a
## perfectly good head that stares at its own back armour.
FRONT = 1.0

AXIS_X = (0.0, math.pi / 2, 0.0)
AXIS_Y = (math.pi / 2, 0.0, 0.0)


def build(component):
    rng = component.rng
    component.archetype = component.forced_archetype or pick_archetype(
        component.seed, ARCHETYPES, rng)
    asym = asymmetry(rng)
    component.recipe = {"archetype": component.archetype, "asym_side": asym["side"]}

    top = _neck(component, rng)
    builder = {
        "camera_housing": _camera_housing,
        "welder_hood":    _welder_hood,
        "control_box":    _control_box,
        "visor_box":    _visor_box,
        "cyclops_drum": _cyclops_drum,
        "wedge_sensor": _wedge_sensor,
        "cage_lamp":    _cage_lamp,
    }[component.archetype]
    builder(component, rng, asym, top)
    _shared_dressing(component, rng, asym)
    repair_history(component, rng, [
        (asym["side"] * 0.085, -0.020, top + 0.075),
        (-asym["side"] * 0.075, 0.060, top + 0.130),
    ], strength=0.7)
    return component


def _neck(component, rng):
    """The collar and post every head sits on.

    This is what makes a head a head rather than a floating shell: it is the geometry
    that reaches down to the NeckSocket at the origin. Without it the mount point has
    nothing behind it, the head appears to hover a few centimetres above the torso,
    and `validate_components` fails the clearance check -- which is the check earning
    its keep."""
    collar = prim.cylinder(component.name + "_collar", 0.064, 0.048,
                           location=(0, 0, 0.022), vertices=12, material="DarkMetal")
    # Short. A long post is a neck, and these machines do not have one -- the head is
    # bolted down between the shoulder yokes.
    post = prim.cylinder(component.name + "_neck", 0.052, 0.034,
                         location=(0, 0, 0.036), vertices=10, material="OldSteel")
    component.add(collar, post)
    component.add(gr.bolt_ring(component.name + "_collarbolt", 5, (0, 0, 0.020), 0.062,
                               axis="z", bolt_radius=0.011))
    if rng.maybe(0.6):
        component.add(gr.cable(component.name + "_neckhose",
                               (0.05, -0.05, 0.085), (-0.045, -0.055, 0.020),
                               rng, radius=0.011, sag=0.03))
    return 0.076


# --- Archetypes --------------------------------------------------------------

def _camera_housing(component, rng, asym, base_z):
    """An old industrial camera on a yoke: barrel lens, sun hood, body, cable gland.

    The primary shape is the BARREL projecting forward, which gives the head a profile
    nothing box-shaped has, and the yoke underneath says it was clamped onto a mount
    rather than grown there."""
    body_w = rng.span(0.15, 0.19)
    body_d = rng.span(0.16, 0.20)
    body_h = rng.span(0.11, 0.14)
    centre = base_z + body_h * 0.5

    # The yoke it swivels in: a cheek and a trunnion each side.
    for sign in (1.0, -1.0):
        component.add(prim.box("%s_yoke_%d" % (component.name, sign > 0),
                               (0.022, body_d * 0.72, body_h * 1.25),
                               location=(sign * (body_w * 0.5 + 0.020), -0.010,
                                         centre - 0.010),
                               material="OldSteel", bevel_width=0.006, segments=1))
        component.add(prim.cylinder("%s_trunnion_%d" % (component.name, sign > 0),
                                    0.018, 0.030,
                                    location=(sign * (body_w * 0.5 + 0.026), -0.010,
                                              centre),
                                    rotation=AXIS_X, vertices=8, material="DarkMetal"))

    component.add(prim.box(component.name + "_body", (body_w, body_d, body_h),
                           location=(0, -0.012, centre), material="DirtyMetal",
                           bevel_width=0.010, segments=2))
    component.add(gr.bolt_row(component.name + "_bodybolt", 3,
                              (-body_w * 0.30, -body_d * 0.52, centre + body_h * 0.22),
                              (body_w * 0.30, 0, 0), axis="y", rng=rng, radius=0.010))

    # The barrel and its hood -- the read.
    barrel_r = rng.span(0.042, 0.054)
    barrel_y = body_d * 0.5 + 0.048
    component.add(prim.cylinder(component.name + "_barrel", barrel_r, 0.110,
                                location=(0, barrel_y, centre), rotation=AXIS_Y,
                                vertices=14, material="DarkMetal"))
    component.add(prim.cylinder(component.name + "_hood", barrel_r * 1.32, 0.052,
                                location=(0, barrel_y + 0.070, centre), rotation=AXIS_Y,
                                vertices=14, material="OldSteel"))
    component.add(gr.lens(component.name + "_glass",
                          (0, barrel_y + 0.052, centre), radius=barrel_r * 0.80,
                          axis="y"))
    component.add(gr.bolt_ring(component.name + "_barrelring", 5,
                               (0, barrel_y - 0.052, centre), barrel_r * 1.05,
                               axis="y", bolt_radius=0.009))
    # Cable gland out the back, and a small aiming lamp above.
    component.add(prim.cylinder(component.name + "_gland", 0.024, 0.038,
                                location=(0, -body_d * 0.5 - 0.018, centre),
                                rotation=AXIS_Y, vertices=8, material="Copper"))
    component.add(gr.cable(component.name + "_feed",
                           (0, -body_d * 0.5 - 0.030, centre),
                           (asym["side"] * 0.055, -body_d * 0.5 - 0.020, base_z + 0.010),
                           rng, radius=0.011, sag=0.03))
    component.add(prim.box(component.name + "_lamp", (0.045, 0.038, 0.030),
                           location=(asym["side"] * body_w * 0.26,
                                     body_d * 0.30, centre + body_h * 0.60),
                           material="OldSteel", bevel_width=0.005, segments=1))
    return component


def _welder_hood(component, rng, asym, base_z):
    """A welding helmet: raked face plate with a dark window, hinged at the temples.

    The rake is the point. Every other head in the kit presents a vertical face; this
    one leans, which reads instantly as a different object and throws a distinctive
    shadow under a key light."""
    width = rng.span(0.16, 0.20)
    depth = rng.span(0.15, 0.18)
    height = rng.span(0.15, 0.19)
    centre = base_z + height * 0.5

    component.add(prim.taper_box(component.name + "_shell",
                                 (width, depth, height),
                                 top_scale=(0.80, 0.86),
                                 location=(0, -0.020, centre),
                                 material="DirtyMetal", bevel_width=0.024, segments=3))
    rake = rng.span(0.24, 0.36)
    component.add(gr.plate(component.name + "_face", (width * 0.96, height * 0.92),
                           location=(0, depth * 0.44, centre),
                           rotation=(rake, 0, 0), thickness=0.030,
                           material="DirtyMetal"))
    component.add(gr.plate(component.name + "_window", (width * 0.62, height * 0.30),
                           location=(0, depth * 0.50, centre + height * 0.14),
                           rotation=(rake, 0, 0), thickness=0.016,
                           material="DarkMetal"))
    component.add(gr.plate(component.name + "_glass", (width * 0.54, height * 0.22),
                           location=(0, depth * 0.53, centre + height * 0.15),
                           rotation=(rake, 0, 0), thickness=0.010,
                           material="Glass"))
    component.add(gr.bolt_row(component.name + "_windowbolt", 4,
                              (-width * 0.26, depth * 0.52, centre + height * 0.28),
                              (width * 0.17, 0, 0), axis="y", rng=rng, radius=0.009))

    # Temple hinges: the detail that says it flips up.
    for sign in (1.0, -1.0):
        component.add(prim.cylinder("%s_hinge_%d" % (component.name, sign > 0), 0.026,
                                    0.030,
                                    location=(sign * width * 0.52, depth * 0.10,
                                              centre + height * 0.10),
                                    rotation=AXIS_X, vertices=10, material="OldSteel"))
        component.add(prim.box("%s_strap_%d" % (component.name, sign > 0),
                               (0.018, depth * 0.55, 0.026),
                               location=(sign * width * 0.50, -depth * 0.16,
                                         centre + height * 0.10),
                               material="Rubber", bevel_width=0.004, segments=1))
    # A filter canister slung on one side, because a scrapyard hood has one.
    component.add(gr.tank(component.name + "_filter",
                          (asym["side"] * width * 0.46, -depth * 0.42, centre - 0.030),
                          radius=0.034, length=0.075, axis="y", rng=rng))
    return component


def _control_box(component, rng, asym, base_z):
    """An electrical enclosure: door, latches, conduit, indicator lamp.

    The most deliberately UNFACE-like head in the set. It reads as somebody bolting the
    nearest junction box where the head goes, which is exactly the fiction -- and the
    single lit indicator does all the work a face would."""
    width = rng.span(0.17, 0.21)
    depth = rng.span(0.12, 0.15)
    height = rng.span(0.17, 0.21)
    centre = base_z + height * 0.5

    component.add(prim.box(component.name + "_enclosure", (width, depth, height),
                           location=(0, -0.008, centre), material="DirtyMetal",
                           bevel_width=0.012, segments=2))
    component.add(gr.plate(component.name + "_door", (width * 0.90, height * 0.86),
                           location=(0, depth * 0.50, centre), thickness=0.024,
                           material="DirtyMetal"))
    component.add(gr.rib(component.name + "_doorfold", width * 0.90,
                         (0, depth * 0.52, centre - height * 0.44), thickness=0.026,
                         height=0.020, axis="x", material="OldSteel"))
    for sign in (1.0, -1.0):
        component.add(prim.box("%s_hinge_%d" % (component.name, sign > 0),
                               (0.020, 0.028, 0.040),
                               location=(-width * 0.46, depth * 0.48,
                                         centre + sign * height * 0.26),
                               material="OldSteel", bevel_width=0.005, segments=1))
    component.add(prim.cylinder(component.name + "_latch", 0.022, 0.040,
                                location=(width * 0.36, depth * 0.54, centre),
                                rotation=AXIS_Y, vertices=8, material="Copper"))
    component.add(gr.plate(component.name + "_label", (width * 0.44, height * 0.16),
                           location=(0, depth * 0.53, centre - height * 0.22),
                           thickness=0.010, material="OldSteel"))
    # Indicator lamp: the one lit thing, and therefore the face.
    component.add(prim.cylinder(component.name + "_lampcan", 0.030, 0.036,
                                location=(0, depth * 0.52, centre + height * 0.24),
                                rotation=AXIS_Y, vertices=10, material="DarkMetal"))
    component.add(gr.lens(component.name + "_lamp",
                          (0, depth * 0.56, centre + height * 0.24), radius=0.023,
                          axis="y"))
    component.add(prim.cylinder(component.name + "_gland", 0.026, 0.032,
                                location=(asym["side"] * width * 0.30,
                                          -depth * 0.42, base_z + 0.020),
                                vertices=8, material="Copper"))
    component.add(gr.pipe_run(component.name + "_conduit", [
        (asym["side"] * width * 0.30, -depth * 0.42, base_z + 0.010),
        (asym["side"] * width * 0.30, -depth * 0.62, base_z - 0.030),
    ], radius=0.018, material="OldSteel", flanges=False))
    return component


def _visor_box(component, rng, asym, base_z):
    """A welded box with a horizontal vision slit. The workhorse silhouette: wide,
    flat-topped, and unmistakably a machine somebody fabricated out of plate."""
    width = rng.span(0.24, 0.30)
    depth = rng.span(0.20, 0.25)
    height = rng.span(0.17, 0.21)
    centre_z = base_z + height * 0.5 - 0.008

    shell = prim.taper_box(component.name + "_shell", (width, depth, height),
                           top_scale=(rng.span(0.80, 0.98), rng.span(0.78, 0.95)),
                           location=(0, 0, centre_z),
                           shear=(0, rng.jitter(0.02)),
                           material="DirtyMetal", bevel_width=0.014, segments=2)
    component.add(shell)

    # The visor: a recessed dark channel with the glass set INSIDE it. Putting the
    # glass flush with the shell instead makes it read as a painted stripe.
    slit_z = centre_z + height * rng.span(0.02, 0.14)
    front_y = depth * 0.5 * FRONT
    component.add(prim.box(component.name + "_visor_recess",
                           (width * 0.80, 0.055, 0.062),
                           location=(0, front_y - 0.012, slit_z),
                           material="DarkMetal", bevel_width=0.006, segments=1))
    component.add(prim.box(component.name + "_visor_glass",
                           (width * 0.70, 0.030, 0.034),
                           location=(0, front_y + 0.004, slit_z),
                           material="Glass", bevel_width=0.004, segments=1))

    # A brow, canted over the slit. Cheap, and it is what stops the front face being
    # a flat rectangle with a stripe on it.
    component.add(prim.box(component.name + "_brow", (width * 0.96, 0.075, 0.026),
                           location=(0, front_y - 0.010, slit_z + 0.055),
                           rotation=(rng.span(0.30, 0.55), 0, 0),
                           material="OldSteel", bevel_width=0.006, segments=1))

    # Cheek plates, one heavier than the other.
    for sign, scale in ((1.0, 1.0), (-1.0, 0.68 if asym["swap_plates"] else 1.0)):
        if scale < 0.75 and rng.maybe(0.4):
            continue
        component.add(gr.plate("%s_cheek_%d" % (component.name, sign > 0),
                               (depth * 0.62, height * 0.52 * scale),
                               location=(sign * width * 0.5, front_y - depth * 0.34,
                                         centre_z - 0.010),
                               rotation=(0, 0, math.pi / 2),
                               thickness=0.020, material="DirtyMetal"))
        component.add(gr.bolt_row("%s_cheekbolt_%d" % (component.name, sign > 0), 3,
                                  (sign * (width * 0.5 + 0.006),
                                   front_y - depth * 0.55, centre_z - 0.055),
                                  (0, depth * 0.22, 0.042), axis="x", rng=rng,
                                  radius=0.013))

    top_z = centre_z + height * 0.5
    _crest(component, rng, asym, top_z, width, depth)


def _cyclops_drum(component, rng, asym, base_z):
    """A drum lying on its side, one big eye in the end cap.

    The circular face pointing forward is doing the work here -- it is the only
    archetype whose front is round, so it reads differently in silhouette even when
    the whole roster is backlit."""
    radius = rng.span(0.105, 0.130)
    length = rng.span(0.19, 0.24)
    centre_z = base_z + radius - 0.006

    component.add(gr.drum(component.name + "_drum", (0, 0, centre_z),
                          radius=radius, height=length, axis="y", rng=rng,
                          material="DirtyMetal" if rng.maybe(0.55) else "RustyMetal"))

    front_y = length * 0.5 * FRONT
    component.add(gr.lens(component.name + "_eye", (0, front_y, centre_z),
                          radius=radius * rng.span(0.44, 0.58), axis="y", rng=rng,
                          depth=0.034))

    # Cage bars across the lens. A bare lens is a headlight; bars make it a machine
    # that expects to be hit in the face.
    bars = rng.count(2, 3)
    for index in range(bars):
        offset = (index - (bars - 1) * 0.5) * radius * 0.40
        component.add(prim.box("%s_bar_%02d" % (component.name, index),
                               (0.020, 0.045, radius * 1.5),
                               location=(offset, front_y + 0.026, centre_z),
                               rotation=(0, rng.jitter(0.06), 0),
                               material="OldSteel", bevel_width=0.004, segments=1))

    # A hat plate over the top, sitting on the barrel.
    component.add(prim.box(component.name + "_hat",
                           (radius * 1.7, length * 0.9, 0.030),
                           location=(rng.jitter(0.014), rng.jitter(0.012),
                                     centre_z + radius - 0.004),
                           rotation=(rng.jitter(0.07), 0, rng.jitter(0.10)),
                           material="OldSteel", bevel_width=0.008, segments=1))

    side = asym["side"]
    component.add(gr.exhaust_stack(component.name + "_stack",
                                   (side * radius * 0.55, -length * 0.30,
                                    centre_z + radius * 0.75),
                                   height=rng.span(0.08, 0.15), radius=0.030, rng=rng))
    if rng.maybe(0.7):
        component.add(gr.pipe_run(component.name + "_conduit",
                                  [(-side * radius * 0.7, -length * 0.4, centre_z),
                                   (-side * radius * 1.05, -length * 0.15,
                                    centre_z - radius * 0.4),
                                   (-side * radius * 0.5, 0.0, base_z - 0.01)],
                                  radius=0.020, material="RustyMetal"))


def _wedge_sensor(component, rng, asym, base_z):
    """An angled sensor head: narrow, forward-raked, twin eyes, a mast on top.

    Where the box archetype is wide and flat, this one is tall and pointed. Two shapes
    that differ in aspect ratio read apart at any distance, which the plate detail on
    either of them does not."""
    width = rng.span(0.17, 0.21)
    depth = rng.span(0.24, 0.29)
    height = rng.span(0.16, 0.20)
    centre_z = base_z + height * 0.5 - 0.006

    component.add(prim.taper_box(component.name + "_wedge", (width, depth, height),
                                 top_scale=(rng.span(0.55, 0.72), rng.span(0.70, 0.88)),
                                 location=(0, 0, centre_z),
                                 shear=(0, -depth * rng.span(0.10, 0.20)),
                                 material="DirtyMetal", bevel_width=0.012, segments=2))

    # The rake plate: a slab across the front face, leaning back. This is the piece
    # that makes it a wedge rather than a narrow box.
    front_y = depth * 0.5 * FRONT
    component.add(prim.box(component.name + "_glacis", (width * 1.02, 0.10, height * 0.8),
                           location=(0, front_y - 0.028, centre_z + 0.006),
                           rotation=(rng.span(-0.42, -0.26), 0, 0),
                           material="OldSteel", bevel_width=0.008, segments=1))

    eye_gap = width * rng.span(0.24, 0.34)
    for sign in (1.0, -1.0):
        component.add(gr.lens("%s_eye_%d" % (component.name, sign > 0),
                              (sign * eye_gap, front_y + 0.006, centre_z + height * 0.10),
                              radius=rng.span(0.026, 0.038), axis="y", rng=rng,
                              depth=0.026))

    # Sensor mast, leaning off the asymmetric side.
    mast_base = (asym["side"] * width * 0.28, -depth * 0.18, centre_z + height * 0.5 - 0.010)
    component.add(prim.cylinder(component.name + "_mast_foot", 0.030, 0.045,
                                location=(mast_base[0], mast_base[1],
                                          mast_base[2] + 0.018),
                                vertices=8, material="DarkMetal"))
    mast_h = rng.span(0.14, 0.22)
    lean = asym["side"] * rng.span(0.10, 0.26)
    component.add(prim.cylinder(component.name + "_mast", 0.016, mast_h,
                                location=(mast_base[0] + math.sin(lean) * mast_h * 0.5,
                                          mast_base[1], mast_base[2] + mast_h * 0.5),
                                rotation=(0, -lean, 0), vertices=8, material="OldSteel"))
    dish_at = (mast_base[0] + math.sin(lean) * mast_h,
               mast_base[1], mast_base[2] + mast_h * 0.98)
    component.add(prim.cone(component.name + "_dish", rng.span(0.045, 0.070), 0.008,
                            0.030, location=dish_at, rotation=(1.05, 0, lean),
                            vertices=10, material="OldSteel"))

    component.add(gr.scrap_sheet(component.name + "_offcut",
                                 (width * 0.9, height * 0.55),
                                 (-asym["side"] * width * 0.48, -depth * 0.05, centre_z),
                                 rng))


def _cage_lamp(component, rng, asym, base_z):
    """An open roll-cage with a work lamp inside it.

    No shell at all. It is the archetype that proves the kit is not just plate-bending:
    you can see straight through the head, and the lamp inside is the brightest thing
    on the robot."""
    radius = rng.span(0.095, 0.120)
    height = rng.span(0.17, 0.21)
    base = base_z - 0.006
    top = base + height

    component.add(prim.cylinder(component.name + "_floor", radius * 1.12, 0.028,
                                location=(0, 0, base + 0.014), vertices=12,
                                material="OldSteel"))
    component.add(prim.cylinder(component.name + "_roof", radius * 1.05, 0.030,
                                location=(0, 0, top - 0.015), vertices=12,
                                material="DirtyMetal"))

    bars = rng.count(4, 6)
    # Leave the front open so the lamp is not caged from the one angle it is seen at.
    start_angle = math.pi * 0.5 + math.pi / bars
    for index in range(bars):
        angle = start_angle + 2.0 * math.pi * index / bars * 0.86
        component.add(prim.cylinder("%s_bar_%02d" % (component.name, index),
                                    0.014, height - 0.020,
                                    location=(math.cos(angle) * radius,
                                              math.sin(angle) * radius,
                                              base + height * 0.5),
                                    vertices=6, material="OldSteel"))
    # Two hoops tying the bars together, or the cage is a row of loose posts.
    for fraction in (0.30, 0.78):
        component.add(prim.torus("%s_hoop_%.0f" % (component.name, fraction * 100),
                                 radius, 0.011,
                                 location=(0, 0, base + height * fraction),
                                 major_segments=14, minor_segments=4,
                                 material="DarkMetal"))

    component.add(prim.sphere(component.name + "_lamp", radius * 0.62,
                              (0, radius * 0.10, base + height * 0.52),
                              segments=12, rings=7, material="Glass"))
    component.add(prim.cylinder(component.name + "_lamp_can", radius * 0.66, 0.055,
                                location=(0, -radius * 0.30, base + height * 0.52),
                                rotation=gr.AXIS_ROTATION["y"], vertices=12,
                                material="DarkMetal"))

    component.add(gr.cable_bundle(component.name + "_loom",
                                  (asym["side"] * radius * 0.5, -radius * 0.55, top - 0.030),
                                  (asym["side"] * 0.030, -0.040, 0.045),
                                  rng, count=rng.count(2, 3), radius=0.010, sag=0.05))
    if rng.maybe(0.6):
        component.add(gr.antenna(component.name + "_aerial",
                                 (-asym["side"] * radius * 0.55, 0.0, top - 0.010),
                                 height=rng.span(0.12, 0.20), rng=rng))


# --- Shared dressing ---------------------------------------------------------

def _crest(component, rng, asym, top_z, width, depth):
    """Whatever is bolted to the top of a boxy head. Chosen from a small menu so two
    seeds of the same archetype still differ above the shoulder line, which is the
    part of a head visible over cover."""
    choice = rng.pick(["antenna", "stack", "sheet", "bare"])
    if choice == "antenna":
        component.add(gr.antenna(component.name + "_aerial",
                                 (asym["side"] * width * 0.28, -depth * 0.20, top_z - 0.008),
                                 height=rng.span(0.14, 0.24), rng=rng))
    elif choice == "stack":
        component.add(gr.exhaust_stack(component.name + "_stack",
                                       (asym["side"] * width * 0.26, -depth * 0.24,
                                        top_z - 0.010),
                                       height=rng.span(0.09, 0.16), radius=0.030, rng=rng))
    elif choice == "sheet":
        component.add(gr.patch(component.name + "_toppatch",
                               (width * 0.7, depth * 0.55),
                               (rng.jitter(0.03), rng.jitter(0.03), top_z + 0.006),
                               rng, rotation=(math.pi / 2, 0, 0), thickness=0.020))


def _shared_dressing(component, rng, asym):
    """Rust patches and welds, applied to every archetype.

    Kept out of the archetype functions on purpose: this is the layer that says
    "salvage", and it should be the same language on all four so the roster reads as
    one machine shop rather than four."""
    for index in range(rng.count(1, 3)):
        component.add(gr.snapped_patch(
            "%s_patch_%02d" % (component.name, index),
            (rng.span(0.05, 0.10), rng.span(0.04, 0.09)),
            (rng.span(-0.13, 0.13), rng.span(-0.12, 0.12), rng.span(0.11, 0.24)),
            rng, component.pieces))
