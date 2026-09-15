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
from . import pick_archetype, asymmetry, repair_history


## The three REDESIGNED base arms first: a digger boom, a factory manipulator and a
## suspension strut. Angular-and-pinned, round-and-flanged, and sprung -- three
## different kinds of machine rather than three thicknesses of tube.
ARCHETYPES = ["excavator_arm", "manipulator_arm", "suspension_arm",
              "piston_arm", "girder_arm", "pipe_arm", "armour_arm"]

AXIS_X = (0.0, math.pi / 2, 0.0)

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
    "excavator_arm":   (1.05, "bracket"),
    "manipulator_arm": (0.88, "ring"),
    "suspension_arm":  (0.92, "collar"),
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
    # Pushed well behind the shoulder-wrist line so the limb visibly BREAKS at the
    # elbow. At 2-6 cm the bend was inside the width of the arm itself, so every
    # archetype read as one straight pole with a bearing stuck on the middle of it --
    # and a straight limb is most of what makes a machine read as a mannequin.
    elbow = (rng.jitter(0.015), rng.span(-0.15, -0.10), config.ARM_ELBOW_Z)
    component.recipe = {"archetype": component.archetype, "elbow": elbow}

    scale, style = SHOULDER_STYLE[component.archetype]
    _shoulder(component, rng, asym, scale, style)
    builder = {
        "excavator_arm":   _excavator_arm,
        "manipulator_arm": _manipulator_arm,
        "suspension_arm":  _suspension_arm,
        "piston_arm":  _piston_arm,
        "girder_arm":  _girder_arm,
        "pipe_arm":    _pipe_arm,
        "armour_arm":  _armour_arm,
    }[component.archetype]
    builder(component, rng, asym, elbow)
    _elbow_joint(component, rng, elbow)
    _wrist(component, rng, asym)
    _shared_dressing(component, rng, asym, elbow)
    repair_history(component, rng, [
        (asym["side"] * 0.070, -0.045, config.ARM_ELBOW_Z * 0.55),
        (-asym["side"] * 0.060, 0.040, config.ARM_ELBOW_Z * 1.35),
    ], strength=0.8)
    return component


# --- Contract-bearing structure ----------------------------------------------

def _shoulder(component, rng, asym, scale, style):
    """An articulated shoulder ASSEMBLY, not a plate on a ball.

    Four things, and the spec is the reference sheets: a large circular joint, a
    structural bracket carrying the load into the limb, a shaped armour cowl over the
    top, and a hydraulic or cable connection feeding it. The previous version was a
    sphere with a flat slab balanced on it -- which is what "flat block shoulders" means
    and why it dominated every arm it was attached to.

    `style` still varies the cowl and the bracing, so the archetypes stay distinct; what
    no longer varies is whether the shoulder is a mechanism at all."""
    size = rng.span(0.24, 0.31) * scale

    # 1. The large circular joint. Flanged and bolted, so it reads as something that
    #    was assembled and can be unbolted -- a bare race reads as a doll's pin.
    joint_r = rng.span(0.082, 0.098)
    # The BALL goes in first, and the order matters more than it looks: `prim.join`
    # makes the first piece the active object and the joined mesh inherits ITS
    # transform, so a first piece carrying the 90-degree rotation an x-axis cylinder
    # needs turns the whole component -- and every socket on it -- a quarter turn. The
    # arm's WeaponSocket landed at (0.62, 0.10, 0.00) instead of (0.00, 0.10, -0.62),
    # which `validate_components` caught exactly as it is meant to.
    component.add(prim.sphere(component.name + "_ball", joint_r * 0.62,
                              (0, 0, -0.012), segments=12, rings=7,
                              material="DarkMetal"))
    component.add(gr.flange_joint(component.name + "_shoulderjoint", (0, 0, -0.012),
                                  radius=joint_r, axis="x", thickness=0.075, bolts=6))

    # 2. The structural bracket: a fork straddling the joint and reaching down into the
    #    limb, which is what actually carries the arm's weight.
    for sign in (1.0, -1.0):
        component.add(gr.plate("%s_fork_%d" % (component.name, sign > 0),
                               (size * 0.62, size * 0.72),
                               location=(sign * joint_r * 0.92, -0.010, -size * 0.30),
                               rotation=(0, 0, math.pi / 2), thickness=0.020,
                               material="DirtyMetal"))
    component.add(gr.rib(component.name + "_forkspine", joint_r * 1.85,
                         (0, -size * 0.26, -size * 0.44), thickness=0.034,
                         height=0.046, axis="x", material="OldSteel"))
    component.add(gr.bolt_row(component.name + "_forkbolt", rng.count(2, 3),
                              (-joint_r * 0.92, -size * 0.20, -size * 0.24),
                              (joint_r * 0.92, 0, 0), axis="x", rng=rng, radius=0.012))

    # 3. The cowl. Tapered hard and canted outward so it sits OVER the joint like a
    #    fitted shell rather than lying flat on top of it. Style decides its shape.
    # A shoulder PAD: wider than it is tall, hugging the joint, canted outward. Tall and
    # hard-tapered it came out a pale pyramid sitting on top of the arm -- a lampshade,
    # and the single loudest object on the limb. Armour over a joint is low and broad.
    if style == "pauldron":
        cowl = (size * 0.90, size * 0.84, size * 0.38)
        top_scale = (0.82, 0.86)
        cant = rng.span(0.20, 0.30)
    elif style == "bracket":
        cowl = (size * 0.74, size * 0.92, size * 0.32)
        top_scale = (0.76, 0.90)
        cant = rng.span(0.14, 0.22)
    elif style == "ring":
        cowl = (size * 0.70, size * 0.70, size * 0.34)
        top_scale = (0.88, 0.88)
        cant = rng.span(0.06, 0.12)
    else:  # collar
        cowl = (size * 0.80, size * 0.74, size * 0.30)
        top_scale = (0.84, 0.88)
        cant = rng.span(0.16, 0.24)

    component.add(prim.taper_box(component.name + "_cowl", cowl,
                                 top_scale=top_scale,
                                 location=(asym["side"] * size * 0.10, rng.jitter(0.012),
                                           joint_r * 0.18),
                                 rotation=(rng.jitter(0.05), 0, cant * asym["side"]),
                                 material="DirtyMetal", bevel_width=0.030, segments=4))
    # A skirt under the cowl's outer lip: the overlap that makes armour read as plates
    # rather than as one moulded lump.
    component.add(gr.plate(component.name + "_cowlskirt",
                           (cowl[0] * 0.78, size * 0.44),
                           location=(asym["side"] * size * 0.30, 0.0, -size * 0.10),
                           rotation=(0, 0, math.pi / 2 + cant * 0.5), thickness=0.018,
                           material="DirtyMetal"))
    component.add(gr.bolt_row(component.name + "_cowlbolt", rng.count(3, 4),
                              (-cowl[0] * 0.28, -cowl[1] * 0.30,
                               joint_r * 0.18 + cowl[2] * 0.42),
                              (cowl[0] * 0.19, cowl[1] * 0.20, 0), axis="z", rng=rng,
                              radius=0.012))

    # 4. The connection: a short ram working the joint, and a hose feeding it.
    ram_top = (asym["side"] * size * 0.34, -size * 0.30, joint_r * 0.30)
    ram_foot = (asym["side"] * size * 0.16, -size * 0.10, -size * 0.56)
    component.add(gr.piston(component.name + "_shoulderram", ram_top, ram_foot, rng,
                            barrel_radius=rng.span(0.022, 0.029), rod_radius=0.011,
                            extension=0.5))
    component.add(gr.hose_between(component.name + "_shoulderhose",
                                  (-asym["side"] * size * 0.30, -size * 0.34,
                                   joint_r * 0.20),
                                  (-asym["side"] * size * 0.12, -size * 0.16,
                                   -size * 0.62), rng,
                                  radius=0.011, sag=0.05, axis="x"))


def _elbow_joint(component, rng, elbow):
    """The hinge. Placed after the archetype so it always sits on top of whatever
    structure ran through it, rather than being buried by a later plate."""
    component.add(gr.bearing(component.name + "_elbow", elbow,
                             radius=rng.span(0.052, 0.068), axis="x"))
    # The ram that works it. Every arm on the reference sheets has a cylinder bridging
    # the elbow, and it is what says the joint is DRIVEN rather than merely articulated.
    # Anchored on the OUTSIDE of the break so it reads from the front rather than being
    # tucked into the crook.
    side = rng.sign() * rng.span(0.035, 0.055)
    component.add(gr.piston(component.name + "_elbow_ram",
                            (side, elbow[1] - 0.055, elbow[2] + rng.span(0.16, 0.22)),
                            (side * 0.6, elbow[1] + 0.020,
                             elbow[2] - rng.span(0.10, 0.15)),
                            rng, barrel_radius=rng.span(0.026, 0.034),
                            rod_radius=0.013, extension=0.5))


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


def _excavator_arm(component, rng, asym, elbow):
    """A digger boom and stick: box sections, pinned joints, a ram on top of each.

    The most recognisable industrial arm there is. The two ram cylinders sitting ON TOP
    of the members -- not hidden inside them -- are the whole read: that is what plant
    equipment looks like and what a plain tube can never say."""
    boom_size = (rng.span(0.075, 0.090), rng.span(0.090, 0.110))
    stick_size = (rng.span(0.062, 0.074), rng.span(0.076, 0.092))

    # Boom: shoulder to elbow, a tapered box section.
    component.add(gr.strut(component.name + "_boom", SHOULDER, elbow, boom_size,
                           material="DirtyMetal", taper=(0.86, 0.82), bevel_width=0.012))
    component.add(gr.rib(component.name + "_boomrib", boom_size[0] * 1.10,
                         (elbow[0] * 0.4, elbow[1] * 0.4 + 0.030,
                          config.ARM_ELBOW_Z * 0.45),
                         thickness=0.024, height=0.030, axis="x"))
    # Stick: elbow to wrist.
    component.add(gr.strut(component.name + "_stick", elbow, WRIST, stick_size,
                           material="DirtyMetal", taper=(0.80, 0.76), bevel_width=0.012))

    # The boom ram, mounted proud on the outer face and pinned at both ends.
    side = asym["side"] * rng.span(0.055, 0.072)
    boom_top = (side, elbow[1] * 0.25 - 0.070, -0.055)
    boom_foot = (side * 0.7, elbow[1] + 0.010, elbow[2] + 0.055)
    component.add(gr.clevis(component.name + "_boomclevis_a", boom_top, axis="x",
                            gap=0.050, depth=0.070))
    component.add(gr.piston(component.name + "_boomram", boom_top, boom_foot, rng,
                            barrel_radius=rng.span(0.030, 0.038), rod_radius=0.014,
                            extension=0.52))
    component.add(gr.clevis(component.name + "_boomclevis_b", boom_foot, axis="x",
                            gap=0.046, depth=0.062))

    # The stick ram, on the opposite face so the arm is not symmetric about its own axis.
    stick_top = (-side * 0.8, elbow[1] - 0.055, elbow[2] + 0.070)
    stick_foot = (-side * 0.5, WRIST[1] - 0.020, WRIST[2] + 0.135)
    component.add(gr.piston(component.name + "_stickram", stick_top, stick_foot, rng,
                            barrel_radius=rng.span(0.024, 0.031), rod_radius=0.012,
                            extension=0.48))
    component.add(gr.clevis(component.name + "_stickclevis", stick_foot, axis="x",
                            gap=0.040, depth=0.052))

    # Hose runs following the members, which is what fills the space between them.
    component.add(gr.hose_between(component.name + "_hose",
                                  (side * 0.5, elbow[1] * 0.3 - 0.045, -0.10),
                                  (side * 0.4, WRIST[1] - 0.030, WRIST[2] + 0.16),
                                  rng, radius=0.012, sag=0.06, axis="x"))
    component.add(gr.bolt_row(component.name + "_boompin", 3,
                              (0, elbow[1] - 0.050, -0.11),
                              (0, 0, -0.075), axis="x", rng=rng, radius=0.012))
    return component


def _manipulator_arm(component, rng, asym, elbow):
    """A factory robot arm: cylindrical housings joined by bolted flange joints.

    Where the excavator is angular and pinned, this is round and flanged -- the two
    read as different KINDS of machine at a glance. Every joint is a `flange_joint`,
    which is the detail that says each section unbolts from the next."""
    upper_r = rng.span(0.062, 0.074)
    fore_r = upper_r * rng.span(0.78, 0.88)

    component.add(gr.flange_joint(component.name + "_j1", (0, 0, -0.045),
                                  radius=upper_r * 1.22, axis="x", thickness=0.060,
                                  bolts=6))
    component.add(gr.strut(component.name + "_upper", (0, 0, -0.070), elbow,
                           (upper_r, upper_r), material="DirtyMetal", shape="cyl",
                           vertices=14))
    # A cast rib along the housing: the giveaway that it is a moulded casing, not a pipe.
    component.add(gr.rib(component.name + "_upperrib", upper_r * 2.05,
                         (0, elbow[1] * 0.5 - upper_r * 0.92,
                          config.ARM_ELBOW_Z * 0.5),
                         thickness=0.022, height=0.026, axis="z", material="OldSteel"))

    component.add(gr.flange_joint(component.name + "_elbowjoint", elbow,
                                  radius=fore_r * 1.35, axis="x", thickness=0.070,
                                  bolts=6))
    component.add(gr.strut(component.name + "_fore", elbow, WRIST, (fore_r, fore_r),
                           material="DirtyMetal", shape="cyl", vertices=14))
    component.add(gr.flange_joint(component.name + "_wristjoint",
                                  (WRIST[0], WRIST[1], WRIST[2] + 0.055),
                                  radius=fore_r * 1.20, axis="z", thickness=0.052,
                                  bolts=5))

    # Servo cans bolted to the outside of each joint, and the conduit that feeds them.
    for index, (at, radius) in enumerate((((0, 0, -0.045), upper_r), (elbow, fore_r))):
        component.add(prim.cylinder("%s_servo_%d" % (component.name, index),
                                    radius * 0.62, radius * 1.30,
                                    location=(asym["side"] * (radius * 1.35), at[1],
                                              at[2]),
                                    rotation=AXIS_X, vertices=12, material="DarkMetal"))
    component.add(gr.pipe_run(component.name + "_conduit", [
        (asym["side"] * upper_r * 1.30, -upper_r * 0.55, -0.10),
        (asym["side"] * fore_r * 1.20, elbow[1] - fore_r * 0.60, elbow[2] + 0.030),
        (asym["side"] * fore_r * 0.80, WRIST[1] - fore_r * 0.50, WRIST[2] + 0.12),
    ], radius=0.016, material="OldSteel"))
    return component


def _suspension_arm(component, rng, asym, elbow):
    """Vehicle suspension worn as a limb: a coil-over strut, an A-arm and a leaf pack.

    The only archetype whose main member is SPRUNG. A visible coil is a shape none of
    the others have, and it says the arm absorbs load rather than merely holding it."""
    # The coil-over is the upper member.
    component.add(gr.strut(component.name + "_strutbody", SHOULDER,
                           (elbow[0] * 0.6, elbow[1] * 0.6, elbow[2] + 0.060),
                           (0.040, 0.040), material="DarkMetal", shape="cyl",
                           vertices=12))
    component.add(gr.coil_spring(component.name + "_coil", (0, 0, -0.055),
                                 (elbow[0] * 0.7, elbow[1] * 0.7, elbow[2] + 0.030),
                                 turns=rng.count(5, 7),
                                 radius=rng.span(0.058, 0.070), wire=0.013))
    for at in ((0, 0, -0.040), (elbow[0] * 0.7, elbow[1] * 0.7, elbow[2] + 0.020)):
        component.add(prim.cylinder(component.name + "_seat%d" % int(at[2] * 1000),
                                    rng.span(0.070, 0.082), 0.020, location=at,
                                    vertices=14, material="OldSteel"))

    # An A-arm bracing back to the shoulder: two legs to one pin.
    for sign in (1.0, -1.0):
        component.add(gr.strut("%s_aarm_%d" % (component.name, sign > 0),
                               (sign * 0.075, -0.050, -0.020), elbow, (0.026, 0.032),
                               material="OldSteel"))
    component.add(gr.clevis(component.name + "_aarmpin", elbow, axis="x", gap=0.052,
                            depth=0.068))
    component.add(gr.bearing(component.name + "_knuckle", elbow, radius=0.052,
                             axis="x"))

    # Leaf pack forearm: stacked plates of decreasing length, bound by a centre clamp.
    leaves = rng.count(3, 4)
    for index in range(leaves):
        shrink = 1.0 - 0.16 * index
        component.add(gr.plate("%s_leaf_%d" % (component.name, index),
                               (0.052, (config.ARM_LENGTH * 0.42) * shrink),
                               location=(elbow[0] * 0.4 + asym["side"] * 0.008 * index,
                                         elbow[1] * 0.4 + 0.014 * index,
                                         (elbow[2] + WRIST[2]) * 0.5),
                               rotation=(rng.span(0.10, 0.20), 0, 0),
                               thickness=0.016, material="OldSteel"))
    component.add(gr.rib(component.name + "_leafclamp", 0.086,
                         (elbow[0] * 0.4, elbow[1] * 0.4 + 0.020,
                          (elbow[2] + WRIST[2]) * 0.5),
                         thickness=0.038, height=0.030, axis="x", material="DarkMetal"))
    component.add(gr.strut(component.name + "_hubarm",
                           (elbow[0] * 0.4, elbow[1] * 0.4, (elbow[2] + WRIST[2]) * 0.5),
                           WRIST, (0.046, 0.046), material="DirtyMetal", shape="cyl",
                           vertices=10))
    component.add(gr.cable(component.name + "_brakeline",
                           (asym["side"] * 0.050, -0.045, -0.070),
                           (elbow[0] * 0.4, WRIST[1] - 0.030, WRIST[2] + 0.10), rng,
                           radius=0.010, sag=0.07))
    return component


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
