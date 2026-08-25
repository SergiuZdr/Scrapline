"""Arms. Origin at the ShoulderSocket, wrist at the contract's WeaponSocket.

An arm is built once, for the LEFT side, and `assembly.mirror_component` produces the
right. That is why the wrist sits at x=0: a mirrored arm has a mirrored wrist, and if
the socket were offset in x, the two sides would present their weapon mounts in
different places and half the kit's weapons would sit crooked on half its arms.

Every archetype spans the same three points -- shoulder, elbow, wrist -- and differs in
what it puts between them: a hydraulic ram, a scavenged girder, a bundle of conduit, or
slabs of bolted plate. That is a real structural difference, not four skins on one bone.
"""

import math

from mathutils import Vector

from .. import config
from .. import greeble as gr
from .. import primitives as prim
from . import pick_archetype, asymmetry


ARCHETYPES = ["piston_arm", "girder_arm", "pipe_arm", "armour_arm"]

SHOULDER = (0.0, 0.0, 0.0)
WRIST = (0.0, config.ARM_FORWARD_CANT, -config.ARM_LENGTH)

## Shoulder treatment per archetype: (size scale, style).
##
## The first version gave all four arms the SAME pauldron, and it was the largest,
## palest, highest-contrast object on every one of them. Four arms that differ
## completely below the elbow still read as four of the same thing when the eye lands
## on an identical wedge at the top -- the shoulder is at chest height, which is
## exactly where a viewer looks. So the shoulder is now part of the archetype: a light
## collar on the hydraulic arm, an open bracket on the girder, a clamp ring on the
## pipe bundle, and a genuine slab pauldron only on the armoured one, where it is the
## point.
SHOULDER_STYLE = {
    "piston_arm": (0.80, "collar"),
    "girder_arm": (0.92, "bracket"),
    "pipe_arm":   (0.74, "ring"),
    "armour_arm": (1.20, "pauldron"),
}


def build(component):
    rng = component.rng
    component.archetype = component.forced_archetype or pick_archetype(
        component.seed, ARCHETYPES, rng)
    asym = asymmetry(rng)

    # The elbow sits slightly BEHIND the shoulder-wrist line, so the forearm swings
    # forward into the weapon. A straight arm reads as a pipe with a gun on the end.
    elbow = (rng.jitter(0.015), rng.span(-0.06, -0.02), config.ARM_ELBOW_Z)
    component.recipe = {"archetype": component.archetype, "elbow": elbow}

    scale, style = SHOULDER_STYLE[component.archetype]
    _shoulder(component, rng, asym, scale, style)
    builder = {
        "piston_arm":  _piston_arm,
        "girder_arm":  _girder_arm,
        "pipe_arm":    _pipe_arm,
        "armour_arm":  _armour_arm,
    }[component.archetype]
    builder(component, rng, asym, elbow)
    _elbow_joint(component, rng, elbow)
    _wrist(component, rng, asym)
    _shared_dressing(component, rng, asym, elbow)
    return component


# --- Contract-bearing structure ----------------------------------------------

def _shoulder(component, rng, asym, scale, style):
    """The ball at the origin, plus whatever this archetype covers it with.

    The ball is what the torso's shoulder bearing closes around; without geometry at
    the origin the arm hangs off its own mount. Something has to cover it -- an exposed
    ball joint at the top of a limb reads as a broken arm -- but WHAT covers it is the
    archetype's decision, not a shared default."""
    component.add(prim.sphere(component.name + "_ball", rng.span(0.062, 0.076),
                              (0, 0, -0.010), segments=12, rings=7,
                              material="DarkMetal"))
    component.add(gr.bearing(component.name + "_shoulder_race", (0, 0, -0.010),
                             radius=rng.span(0.070, 0.086), axis="x"))
    size = rng.span(0.16, 0.21) * scale

    if style == "pauldron":
        component.add(prim.taper_box(component.name + "_pauldron",
                                     (size, size * rng.span(0.90, 1.15), 0.13),
                                     top_scale=(rng.span(0.68, 0.90),
                                                rng.span(0.68, 0.90)),
                                     location=(rng.jitter(0.012), rng.jitter(0.015),
                                               0.020),
                                     rotation=(rng.jitter(0.10), 0, 0),
                                     material="DirtyMetal", bevel_width=0.014,
                                     segments=2))
        component.add(gr.bolt_row(component.name + "_pauldronbolt", rng.count(3, 4),
                                  (-size * 0.30, -size * 0.40, 0.068),
                                  (size * 0.22, size * 0.28, 0), axis="z", rng=rng,
                                  radius=0.014))
    elif style == "bracket":
        # Two flat cheeks with the joint visible between them.
        for sign in (1.0, -1.0):
            component.add(gr.plate("%s_cheek_%d" % (component.name, sign > 0),
                                   (size * 0.85, size * 0.80),
                                   location=(sign * size * 0.44, rng.jitter(0.012),
                                             -0.010),
                                   rotation=(0, 0, math.pi / 2), thickness=0.026,
                                   material="DirtyMetal"))
        component.add(gr.rib(component.name + "_yoke", size * 0.98,
                             (0, -size * 0.30, 0.030), thickness=0.038, height=0.055,
                             axis="x"))
    elif style == "ring":
        component.add(prim.cylinder(component.name + "_clamp", size * 0.52, 0.11,
                                    location=(0, 0, 0.012), vertices=12,
                                    material="DirtyMetal"))
        component.add(prim.torus(component.name + "_clamp_band", size * 0.55, 0.016,
                                 location=(0, 0, 0.040), major_segments=12,
                                 minor_segments=4, material="DarkMetal"))
        component.add(gr.bolt_ring(component.name + "_clampbolt", 4, (0, 0, 0.040),
                                   size * 0.55, axis="z", bolt_radius=0.012))
    else:  # collar
        component.add(prim.taper_box(component.name + "_collar",
                                     (size * 0.92, size * 0.86, 0.085),
                                     top_scale=(0.72, 0.72),
                                     location=(0, rng.jitter(0.012), 0.008),
                                     material="DirtyMetal", bevel_width=0.012,
                                     segments=2))
        component.add(gr.plate(component.name + "_scapula",
                               (size * 0.70, size * 0.80),
                               location=(0, -size * 0.42, -0.045),
                               thickness=0.022, material="DirtyMetal"))


def _elbow_joint(component, rng, elbow):
    """The hinge. Placed after the archetype so it always sits on top of whatever
    structure ran through it, rather than being buried by a later plate."""
    component.add(gr.bearing(component.name + "_elbow", elbow,
                             radius=rng.span(0.052, 0.068), axis="x"))


def _wrist(component, rng, asym):
    """The clamp at the WeaponSocket.

    This is the piece the contract check looks for. It also carries the visual promise
    that a weapon can be swapped: a clamp with bolts around it says removable, and a
    smooth taper says welded on."""
    component.add(prim.cylinder(component.name + "_wrist", rng.span(0.048, 0.062), 0.075,
                                location=(WRIST[0], WRIST[1] - 0.010, WRIST[2] + 0.020),
                                rotation=(math.pi / 2 * 0.28, 0, 0), vertices=10,
                                material="DarkMetal"))
    component.add(prim.box(component.name + "_wrist_plate", (0.115, 0.085, 0.028),
                           location=(WRIST[0], WRIST[1] - 0.020, WRIST[2] + 0.012),
                           material="OldSteel", bevel_width=0.008, segments=1))
    component.add(gr.bolt_ring(component.name + "_wristbolt", 4,
                               (WRIST[0], WRIST[1] - 0.010, WRIST[2] + 0.018), 0.052,
                               axis="y", bolt_radius=0.012))


# --- Archetypes --------------------------------------------------------------

def _piston_arm(component, rng, asym, elbow):
    """Hydraulic: an OPEN twin-rail frame with the ram working inside it.

    ## Why the frame is open

    The first two versions of this archetype ran a single solid bone down the middle
    and hung the ram behind it, and the mechanism was invisible both times -- for two
    different reasons, which is what makes it worth writing down.

    Thin bone, ram behind it: the ram was there and legible only in exact profile,
    because the arm hangs at the construct's side and the body occludes everything
    behind it from the front three-quarter view the game is actually played at.

    Thick bone, ram pushed further out: the ram cleared the bone and the bone then
    read as the arm, with a small dark cylinder floating alongside it -- an accessory
    rather than the thing driving the joint.

    Neither is fixable by moving the ram, because the problem is the bone. A solid
    member down the centre of a limb will hide whatever is behind it and out-read
    whatever is beside it. So there is no centre member: two slim rails carry the load
    at the OUTSIDE of the arm and the ram sits between them, visible through the gap
    from every angle including straight on. That is also how real hydraulic machinery
    is built, which is not a coincidence -- the linkage has to be reachable.

    ## The bell-crank

    A ram whose rod simply ends at the elbow reads as a strut. What makes hydraulics
    legible is the TRIANGLE: rod, crank plate and the pivot they drive, all visible at
    once. It is three small pieces and it does more for the read than the ram itself.
    """
    # The frame has to be WIDER than the ram, by enough to see daylight through.
    #
    # The version before this one put the rails at 0.055 and the ram at a 0.052
    # radius, so the ram exactly filled the gap: geometrically an open frame,
    # visually a solid slab, and the mechanism was as hidden as it had been inside a
    # single bone. "Open" is not a topology property, it is a measurable clearance --
    # about 3 cm each side here, which survives being 90 px tall on a phone.
    rail_x = rng.span(0.088, 0.108)
    ram_radius = rng.span(0.040, 0.048)

    # Twin rails, one either side, carrying the load around the outside of the ram.
    for sign in (1.0, -1.0):
        component.add(gr.strut("%s_rail_%d" % (component.name, sign > 0),
                               (sign * rail_x * 0.70, SHOULDER[1] + 0.010, -0.030),
                               (elbow[0] + sign * rail_x, elbow[1] + 0.010, elbow[2]),
                               (0.026, 0.048), material="OldSteel", bevel_width=0.006))
    # A spacer at each end, or the rails are two loose bars rather than a frame.
    component.add(gr.rib(component.name + "_spacer_top", rail_x * 2.0,
                         (0, 0.000, -0.055), thickness=0.030, height=0.040, axis="x"))
    component.add(gr.rib(component.name + "_spacer_low", rail_x * 2.1,
                         (elbow[0], elbow[1] + 0.020, elbow[2] + 0.070),
                         thickness=0.030, height=0.038, axis="x"))

    # THE RAM. On the centreline for X, but standing PROUD of the frame in Y.
    #
    # Level with the rails it is only visible dead-on, and an arm hangs at the
    # construct's side where dead-on is the one angle the camera never has. Forward of
    # them it breaks the frame's silhouette from every three-quarter view, which is
    # the view the game is actually played at.
    ram_y = -rng.span(0.030, 0.042)
    ram_top = (0.0, ram_y, -0.055)
    ram_bottom = (elbow[0], elbow[1] + ram_y * 0.5, elbow[2] + 0.085)
    component.add(gr.piston(component.name + "_ram", ram_top, ram_bottom, rng,
                            barrel_radius=ram_radius, rod_radius=ram_radius * 0.42,
                            extension=0.52))
    # A copper band at the gland. Copper is the palette's one warm accent and the
    # brightest thing available at this scale -- on the ram it is what makes the eye
    # land on the mechanism rather than on the frame around it.
    component.add(prim.torus(component.name + "_gland", ram_radius * 1.22, 0.013,
                             location=(ram_top[0] + (ram_bottom[0] - ram_top[0]) * 0.46,
                                       ram_top[1] + (ram_bottom[1] - ram_top[1]) * 0.46,
                                       ram_top[2] + (ram_bottom[2] - ram_top[2]) * 0.46),
                             rotation=(0.12, 0, 0), major_segments=12, minor_segments=4,
                             material="Copper"))
    # Anchor pins at both ends, so the ram is pinned into the frame rather than
    # floating in the middle of it.
    for label, point in (("top", ram_top), ("low", ram_bottom)):
        component.add(gr.bolt("%s_rampin_%s" % (component.name, label), point,
                              radius=0.017, depth=rail_x * 2.3, axis="x",
                              material="DarkMetal"))

    # The bell-crank: rod, plate, pivot. This is the piece that says "hydraulic".
    crank_tip = (elbow[0] + asym["side"] * rng.span(0.055, 0.080),
                 elbow[1] - rng.span(0.070, 0.095), elbow[2] + 0.020)
    component.add(prim.box(component.name + "_crank",
                           (0.024, 0.062, 0.105),
                           location=((crank_tip[0] + elbow[0]) * 0.5,
                                     (crank_tip[1] + elbow[1]) * 0.5,
                                     (crank_tip[2] + elbow[2]) * 0.5),
                           rotation=(rng.span(-0.75, -0.45), 0,
                                     asym["side"] * rng.span(0.30, 0.55)),
                           material="DarkMetal", bevel_width=0.006, segments=1))
    component.add(gr.bolt(component.name + "_crank_pin", crank_tip, radius=0.019,
                          depth=0.048, axis="x", material="Copper"))
    # The link from the crank down onto the forearm -- the closing side of the triangle.
    component.add(gr.strut(component.name + "_link", crank_tip,
                           (WRIST[0], WRIST[1] - 0.045, WRIST[2] + 0.170),
                           (0.020,), material="OldSteel", shape="cyl", vertices=8))

    # The forearm is a single member: the frame trick is spent above the elbow, and
    # doing it twice would make the arm read as scaffolding rather than as a limb.
    component.add(gr.strut(component.name + "_radius", elbow, WRIST,
                           (0.056, 0.056), material="OldSteel", shape="cyl",
                           vertices=10))
    component.add(gr.piston(component.name + "_ram_fore",
                            (elbow[0], elbow[1] - 0.062, elbow[2] - 0.040),
                            (WRIST[0], WRIST[1] - 0.040, WRIST[2] + 0.090),
                            rng, barrel_radius=rng.span(0.030, 0.038),
                            rod_radius=0.015))

    # Hoses run TO the ram's barrel, which is where hydraulic lines actually go, and
    # is what ties the mechanism into the rest of the machine.
    component.add(gr.cable_bundle(component.name + "_hyd",
                                  (rail_x * 0.6, -0.075, -0.020),
                                  (0.0, -0.055, elbow[2] * 0.45),
                                  rng, count=rng.count(2, 3), radius=0.011, sag=0.055))
    component.add(gr.plate(component.name + "_frame_plate",
                           (rail_x * 1.5, 0.11),
                           location=(0, rng.span(0.030, 0.050), -0.085),
                           thickness=0.020, material="DirtyMetal"))


def _girder_arm(component, rng, asym, elbow):
    """A structural I-beam with plate bolted to it. Angular, flat-sided, and obviously
    scavenged from a building rather than a vehicle."""
    component.add(gr.i_beam(component.name + "_humerus", SHOULDER, elbow,
                            web=0.042, flange=rng.span(0.120, 0.150)))
    component.add(gr.i_beam(component.name + "_radius", elbow, WRIST,
                            web=0.036, flange=rng.span(0.100, 0.128)))

    # Plates lagged onto the beam at intervals, each a slightly different size.
    for index in range(rng.count(2, 4)):
        t = (index + 0.5) / 4.0
        z = -config.ARM_LENGTH * t
        y = config.ARM_FORWARD_CANT * t - 0.02
        component.add(gr.plate("%s_lag_%02d" % (component.name, index),
                               (rng.span(0.09, 0.14), rng.span(0.08, 0.13)),
                               location=(rng.jitter(0.02), y + 0.055, z),
                               rotation=(rng.jitter(0.10), 0, rng.jitter(0.08)),
                               thickness=0.022, material="DirtyMetal"))
        component.add(gr.bolt_row("%s_lagbolt_%02d" % (component.name, index), 2,
                                  (-0.030, y + 0.072, z - 0.028), (0.060, 0, 0.056),
                                  axis="y", rng=rng, radius=0.013))

    component.add(gr.weld_seam(component.name + "_weld",
                               (-0.04, -0.03, elbow[2] + 0.05),
                               (0.04, -0.03, elbow[2] - 0.05), rng,
                               count=rng.count(3, 5), size=0.015))
    if rng.maybe(0.5):
        component.add(gr.scrap_sheet(component.name + "_offcut", (0.14, 0.12),
                                     (asym["side"] * 0.055, -0.055,
                                      elbow[2] - 0.10), rng))


def _pipe_arm(component, rng, asym, elbow):
    """A bundle of conduit wrapped in cable. The busiest read of the four, and the one
    that most obviously has no single load path -- it looks assembled from offcuts
    because it is."""
    pipes = rng.count(3, 4)
    spread = 0.055
    for index in range(pipes):
        angle = 2.0 * math.pi * index / pipes
        offset_x = math.cos(angle) * spread
        offset_y = math.sin(angle) * spread * 0.85
        component.add(gr.strut("%s_pipe_a_%02d" % (component.name, index),
                               (SHOULDER[0] + offset_x, SHOULDER[1] + offset_y, -0.020),
                               (elbow[0] + offset_x, elbow[1] + offset_y, elbow[2]),
                               (rng.span(0.030, 0.040),), material="OldSteel",
                               shape="cyl", vertices=8))
        component.add(gr.strut("%s_pipe_b_%02d" % (component.name, index),
                               (elbow[0] + offset_x * 0.8, elbow[1] + offset_y * 0.8,
                                elbow[2]),
                               (WRIST[0] + offset_x * 0.7, WRIST[1] + offset_y * 0.7,
                                WRIST[2] + 0.020),
                               (rng.span(0.026, 0.034),), material="RustyMetal",
                               shape="cyl", vertices=8))

    # Collars clamping the bundle. Without them it is four loose pipes, not a bundle.
    for fraction in (0.22, 0.55, 0.85):
        z = -config.ARM_LENGTH * fraction
        y = config.ARM_FORWARD_CANT * fraction - 0.03
        component.add(prim.cylinder("%s_collar_%.0f" % (component.name, fraction * 100),
                                    rng.span(0.072, 0.086), 0.032,
                                    location=(0, y, z), rotation=(0.18, 0, 0),
                                    vertices=10, material="DarkMetal"))
    component.add(gr.cable_bundle(component.name + "_wrap",
                                  (0.045, -0.045, -0.060),
                                  (0.030, WRIST[1] - 0.030, WRIST[2] + 0.080),
                                  rng, count=rng.count(2, 4), radius=0.011, sag=0.06))
    component.add(gr.tank(component.name + "_accumulator",
                          (asym["side"] * 0.055, -0.055, elbow[2] + 0.060),
                          radius=rng.span(0.036, 0.048), length=rng.span(0.10, 0.15),
                          axis="z", rng=rng))


def _armour_arm(component, rng, asym, elbow):
    """Slab armour over a short bone. The heaviest silhouette, and the one that carries
    the most team paint -- worth having in the set for exactly that reason."""
    component.add(gr.strut(component.name + "_humerus", SHOULDER, elbow,
                           (0.070, 0.070), material="DarkMetal", shape="cyl",
                           vertices=10))
    component.add(gr.strut(component.name + "_radius", elbow, WRIST,
                           (0.058, 0.058), material="DarkMetal", shape="cyl",
                           vertices=10))

    # The shells are STRUTS along the bone, not boxes at its midpoint.
    #
    # An axis-aligned box centred on a slanted segment crosses the bone rather than
    # covering it: the first version put the elbow's 6 cm of forward lean entirely
    # outside the armour, and the arm rendered as two pale blocks with a dark gap
    # between them, which is exactly what a broken limb looks like. `strut` orients to
    # the segment, so the shell follows the arm whatever the elbow does.
    for label, start, end, width in (
            ("upper", SHOULDER, elbow, rng.span(0.16, 0.21)),
            ("lower", elbow, WRIST, rng.span(0.14, 0.18))):
        mid = tuple((start[i] + end[i]) * 0.5 for i in range(3))
        length = (Vector(end) - Vector(start)).length
        component.add(gr.strut("%s_%s_shell" % (component.name, label), start, end,
                               (width, width * rng.span(0.85, 1.05)),
                               material="DirtyMetal", overlap=0.012,
                               bevel_width=0.014,
                               taper=(rng.span(0.78, 0.98), rng.span(0.78, 0.98))))
        component.add(gr.bolt_row("%s_%s_bolt" % (component.name, label),
                                  rng.count(3, 4),
                                  (0, mid[1] + width * 0.55, mid[2] - length * 0.28),
                                  (0, 0, length * 0.20), axis="y", rng=rng, radius=0.015))
        component.add(gr.rib("%s_%s_rib" % (component.name, label), width * 0.95,
                             (0, mid[1] + width * 0.50, mid[2] + length * 0.22),
                             thickness=0.026, height=0.036, axis="x"))

    component.add(gr.patch(component.name + "_scar", (0.10, 0.09),
                           (asym["side"] * 0.075, elbow[1] + 0.02, elbow[2] - 0.11),
                           rng, rotation=(0, 0, math.pi / 2)))


# --- Shared dressing ---------------------------------------------------------

def _shared_dressing(component, rng, asym, elbow):
    for index in range(rng.count(1, 2)):
        t = rng.span(0.15, 0.85)
        component.add(gr.snapped_patch(
            "%s_patch_%02d" % (component.name, index),
            (rng.span(0.05, 0.09), rng.span(0.04, 0.08)),
            (rng.jitter(0.055),
             config.ARM_FORWARD_CANT * t + rng.span(0.02, 0.06),
             -config.ARM_LENGTH * t),
            rng, component.pieces))
