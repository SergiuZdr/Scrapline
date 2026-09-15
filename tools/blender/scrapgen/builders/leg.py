"""Legs. Origin at the HipSocket, sole flat on z = -LEG_LENGTH.

Two things are contractual and everything else is free.

The **hip head** must sit at the origin, or the leg hangs off its own mount. The
**sole** must bottom out at exactly -`LEG_LENGTH`, because that plane is the ground:
a leg 3 cm short leaves the robot hovering, and a leg 3 cm long buries its foot. Both
look completely reasonable on the part in isolation, which is why `validate_components`
checks the ground plane rather than trusting the builder.

Between those two points the four archetypes take genuinely different paths -- a
reverse-jointed digitigrade stride, a straight hydraulic column, a heavy braced strut,
and an open cage of rails and springs.
"""

import math

from .. import config
from .. import greeble as gr
from .. import primitives as prim
from . import pick_archetype, asymmetry, repair_history


## The three REDESIGNED base legs first: a hydraulic ram, a suspension strut and a
## structural truss. Rigid, sprung and open -- three different ways a machine carries
## its own weight, rather than three thicknesses of the same tube.
ARCHETYPES = ["hydraulic_ram", "strut_leg", "gantry_leg",
              "digitigrade", "piston_column", "hoof_strut", "caged_leg"]

AXIS_X = (0.0, math.pi / 2, 0.0)

HIP = (0.0, 0.0, 0.0)
GROUND = -config.LEG_LENGTH


def build(component):
    rng = component.rng
    component.archetype = component.forced_archetype or pick_archetype(
        component.seed, ARCHETYPES, rng)
    asym = asymmetry(rng)
    component.recipe = {"archetype": component.archetype}

    _hip_head(component, rng)
    builder = {
        "hydraulic_ram": _hydraulic_ram,
        "strut_leg":     _strut_leg,
        "gantry_leg":    _gantry_leg,
        "digitigrade":   _digitigrade,
        "piston_column": _piston_column,
        "hoof_strut":    _hoof_strut,
        "caged_leg":     _caged_leg,
    }[component.archetype]
    ankle = builder(component, rng, asym)
    _shared_dressing(component, rng, asym)
    repair_history(component, rng, [
        (asym["side"] * 0.085, 0.050, config.LEG_KNEE_Z * 0.50),
        (-asym["side"] * 0.070, -0.055, config.LEG_KNEE_Z * 1.35),
    ], strength=0.8)
    return component


# --- Contract-bearing structure ----------------------------------------------

def _hip_head(component, rng):
    """Ball and race at the origin, where the torso's hip bearing closes on it."""
    component.add(prim.sphere(component.name + "_ball", rng.span(0.058, 0.070),
                              (0, 0, -0.014), segments=12, rings=7,
                              material="DarkMetal"))
    component.add(gr.bearing(component.name + "_hip_race", (0, 0, -0.014),
                             radius=rng.span(0.064, 0.078), axis="x"))
    component.add(prim.taper_box(component.name + "_hip_shroud",
                                 (rng.span(0.13, 0.17), rng.span(0.14, 0.18), 0.12),
                                 top_scale=(0.80, 0.85), location=(0, 0, -0.060),
                                 material="DirtyMetal", bevel_width=0.012, segments=2))


def _foot(component, rng, ankle, style="plate", width=0.30, length=0.40):
    """The foot, with its sole ON the ground plane.

    `ankle` is where the leg's last member ends; the foot bridges from there down to
    -LEG_LENGTH. Built as a shared function precisely so no archetype can get the
    ground plane wrong for itself -- that is the sort of error that only shows up once
    six of them are standing in a line at different heights."""
    # A thicker, wider sole. Every reference machine stands on a big flat plate a good
    # deal wider than the shank above it -- that overhang is what stops a heavy frame
    # reading as balanced on sticks.
    sole_thickness = 0.062
    sole_z = GROUND + sole_thickness * 0.5
    forward = ankle[1] + length * rng.span(0.10, 0.22)

    component.add(gr.strut(component.name + "_shank_end", ankle,
                           (ankle[0], ankle[1], sole_z + 0.055),
                           (0.082, 0.082), material="DarkMetal", shape="cyl",
                           vertices=10))
    component.add(gr.bearing(component.name + "_ankle",
                             (ankle[0], ankle[1], sole_z + 0.075),
                             radius=rng.span(0.046, 0.058), axis="x"))

    if style == "hoof":
        component.add(prim.taper_box(component.name + "_hoof",
                                     (width * 1.15, length * 0.85, 0.13),
                                     top_scale=(0.62, 0.70),
                                     location=(ankle[0], forward - length * 0.06,
                                               sole_z + 0.055),
                                     material="RustyMetal", bevel_width=0.012,
                                     segments=2))
    else:
        component.add(prim.box(component.name + "_ankle_block",
                               (width * 0.60, length * 0.40, 0.075),
                               location=(ankle[0], ankle[1], sole_z + 0.065),
                               material="DarkMetal", bevel_width=0.010, segments=1))

    # The sole is DARK, not rust. Rust belongs on ground contact -- toes, heel, hoof --
    # but the sole is the single largest flat face on a leg, and in rust it made the
    # bottom of every machine a slab of bright orange: the highest-saturation colour in
    # the palette, at the least interesting place on the model, repeated twelve times
    # across a squad. Rust reads as rust when it is an accent.
    component.add(prim.box(component.name + "_sole", (width, length, sole_thickness),
                           location=(ankle[0], forward - length * 0.10, sole_z),
                           material="DarkMetal", bevel_width=0.010, segments=1))

    # Toes, for the archetypes that want a foot that grips rather than a pad.
    if style in ("claw", "hoof"):
        toes = rng.count(2, 3)
        for index in range(toes):
            offset = (index - (toes - 1) * 0.5) * width * 0.34
            component.add(prim.cone("%s_toe_%02d" % (component.name, index),
                                    0.036, 0.014, length * 0.34,
                                    location=(ankle[0] + offset,
                                              forward + length * 0.30,
                                              sole_z + 0.006),
                                    rotation=(math.pi / 2, 0, rng.jitter(0.18)),
                                    vertices=8, material="RustyMetal"))
    # A heel spur, so the foot is not symmetric front to back.
    component.add(prim.box(component.name + "_heel",
                           (width * 0.55, length * 0.26, 0.055),
                           location=(ankle[0], forward - length * 0.52, sole_z + 0.028),
                           rotation=(rng.span(-0.30, -0.12), 0, 0),
                           material="OldSteel", bevel_width=0.008, segments=1))
    component.add(gr.bolt_row(component.name + "_solebolt", rng.count(3, 4),
                              (ankle[0] - width * 0.30, forward - length * 0.30,
                               sole_z + sole_thickness * 0.5),
                              (width * 0.22, length * 0.20, 0), axis="z", rng=rng,
                              radius=0.013))


# --- Archetypes --------------------------------------------------------------

def _hydraulic_ram(component, rng, asym):
    """A heavy hydraulic cylinder standing as a leg: barrel thigh, rod shank, clevises.

    The primary shape is the CYLINDER -- a fat barrel above, a bright rod below -- and
    the step in diameter where the rod leaves the gland is the most legible knee in the
    set. Nothing else here has a polished member."""
    knee = (config.STANCE_WIDTH * 0.5, rng.jitter(0.020) + config.KNEE_FORWARD * 0.6,
            config.LEG_KNEE_Z + 0.02)
    ankle = (config.STANCE_WIDTH, rng.jitter(0.020), GROUND + rng.span(0.16, 0.21))

    component.add(gr.clevis(component.name + "_hipclevis", HIP, axis="x", gap=0.072,
                            depth=0.105))
    barrel_r = rng.span(0.078, 0.094)
    component.add(gr.strut(component.name + "_barrel", HIP, knee,
                           (barrel_r, barrel_r), material="DirtyMetal", shape="cyl",
                           vertices=14))
    # The gland: the shoulder where barrel meets rod, and where hoses land.
    component.add(prim.cylinder(component.name + "_gland", barrel_r * 1.18, 0.055,
                                location=knee, vertices=14, material="OldSteel"))
    component.add(gr.bolt_ring(component.name + "_glandbolt", 6, knee,
                               barrel_r * 0.94, axis="z", bolt_radius=0.012))
    rod_r = barrel_r * rng.span(0.52, 0.62)
    component.add(gr.strut(component.name + "_rod", knee, ankle, (rod_r, rod_r),
                           material="OldSteel", shape="cyl", vertices=12))
    component.add(gr.clevis(component.name + "_ankleclevis",
                            (ankle[0], ankle[1], ankle[2] + 0.030), axis="x",
                            gap=0.058, depth=0.078))

    # Hydraulic feed: two ports on the barrel, hoses running down the outside.
    for index, height in enumerate((0.10, -0.16)):
        at = (asym["side"] * barrel_r * 1.05, -barrel_r * 0.55,
              config.LEG_KNEE_Z * 0.5 + height)
        component.add(prim.cylinder("%s_port_%d" % (component.name, index), 0.022,
                                    0.040, location=at, rotation=AXIS_X, vertices=8,
                                    material="Copper"))
    component.add(gr.hose_between(component.name + "_hose",
                                  (asym["side"] * barrel_r * 1.05, -barrel_r * 0.55,
                                   config.LEG_KNEE_Z * 0.5 + 0.10),
                                  (asym["side"] * barrel_r * 0.7, -barrel_r * 0.40,
                                   ankle[2] + 0.11), rng,
                                  radius=0.013, sag=0.08, axis="x"))
    # A guard plate over the rod, so the polished section is not fully exposed.
    component.add(gr.plate(component.name + "_rodguard", (rod_r * 2.4, 0.19),
                           location=(ankle[0], ankle[1] + rod_r * 1.25,
                                     (knee[2] + ankle[2]) * 0.5),
                           thickness=0.018, material="DirtyMetal"))
    _foot(component, rng, ankle, style="plate", width=rng.span(0.31, 0.38),
          length=rng.span(0.28, 0.34))
    return ankle


def _strut_leg(component, rng, asym):
    """Vehicle suspension: coil-over strut, trailing arm, hub and brake disc.

    Sprung where the ram is rigid. The exposed coil gives a leg an open, wiry section
    in the middle of an otherwise solid limb, which is a silhouette none of the others
    can produce."""
    knee = (config.STANCE_WIDTH * 0.55,
            rng.jitter(0.020) + config.KNEE_FORWARD, config.LEG_KNEE_Z)
    ankle = (config.STANCE_WIDTH, rng.jitter(0.020), GROUND + rng.span(0.15, 0.20))

    # Top mount and the strut itself.
    component.add(prim.cylinder(component.name + "_topmount", rng.span(0.082, 0.098),
                                0.032, location=(0, 0, -0.020), vertices=14,
                                material="OldSteel"))
    component.add(gr.bolt_ring(component.name + "_mountbolt", 4, (0, 0, -0.020),
                               0.068, axis="z", bolt_radius=0.012))
    component.add(gr.shock_absorber(component.name + "_strut", (0, 0, -0.045), knee,
                                    rng, barrel_radius=rng.span(0.040, 0.050),
                                    spring_radius=rng.span(0.072, 0.086)))

    # Trailing arm from the hip, braced back to the hub.
    component.add(gr.strut(component.name + "_trailing",
                           (0.020, -0.075, -0.030),
                           (ankle[0], ankle[1] - 0.030, ankle[2] + 0.075),
                           (0.048, 0.062), material="DirtyMetal"))
    component.add(gr.clevis(component.name + "_trailingpin", (0.020, -0.075, -0.030),
                            axis="x", gap=0.050, depth=0.066))

    # Knuckle, hub and disc: the assembly a wheel would bolt to.
    component.add(gr.bearing(component.name + "_knuckle", knee, radius=0.058, axis="x"))
    component.add(gr.strut(component.name + "_upright", knee,
                           (ankle[0], ankle[1], ankle[2] + 0.055), (0.062, 0.070),
                           material="DirtyMetal"))
    hub = (ankle[0] + asym["side"] * 0.030, ankle[1], ankle[2] + 0.085)
    component.add(prim.cylinder(component.name + "_disc", rng.span(0.082, 0.098), 0.020,
                                location=hub, rotation=AXIS_X, vertices=16,
                                material="OldSteel"))
    component.add(prim.cylinder(component.name + "_hub", 0.038, 0.046, location=hub,
                                rotation=AXIS_X, vertices=10, material="DarkMetal"))
    component.add(gr.bolt_ring(component.name + "_lugs", 5, hub, 0.030, axis="x",
                               bolt_radius=0.010))
    component.add(prim.box(component.name + "_caliper", (0.036, 0.055, 0.070),
                           location=(hub[0] - asym["side"] * 0.055, hub[1] - 0.020,
                                     hub[2] + 0.045),
                           material="RustyMetal", bevel_width=0.006, segments=1))
    component.add(gr.cable(component.name + "_brakeline",
                           (0.030, -0.070, -0.060),
                           (hub[0] - asym["side"] * 0.050, hub[1] - 0.020, hub[2] + 0.06),
                           rng, radius=0.010, sag=0.07))
    _foot(component, rng, ankle, style="plate", width=rng.span(0.30, 0.36),
          length=rng.span(0.30, 0.36))
    return ankle


def _gantry_leg(component, rng, asym):
    """A structural machinery support: latticed I-beam thigh, braced knee, box shank.

    The OPEN leg of the three. Being able to see through a limb is what proves the
    others are solid castings rather than blocks, and a truss reads as "cut from a
    building" the way no smooth member does."""
    knee = (config.STANCE_WIDTH * 0.5,
            rng.jitter(0.015) + config.KNEE_FORWARD * 0.8, config.LEG_KNEE_Z - 0.02)
    ankle = (config.STANCE_WIDTH, rng.jitter(0.020), GROUND + rng.span(0.17, 0.22))

    # Thigh: a real I-beam, with lattice bracing across its web.
    component.add(gr.i_beam(component.name + "_thigh", HIP, knee, web=0.034,
                            flange=0.115))
    for index in range(rng.count(2, 3)):
        fraction = (index + 1) / (rng.count(3, 4) + 1)
        z_a = config.LEG_KNEE_Z * fraction
        z_b = config.LEG_KNEE_Z * (fraction + 0.28)
        component.add(gr.strut("%s_lattice_%d" % (component.name, index),
                               (knee[0] * fraction - 0.052, knee[1] * fraction - 0.040,
                                z_a),
                               (knee[0] * fraction + 0.052, knee[1] * fraction + 0.030,
                                z_b),
                               (0.020, 0.024), material="OldSteel"))

    # Knee: a bolted flange joint with a gusset either side.
    component.add(gr.flange_joint(component.name + "_kneejoint", knee, radius=0.076,
                                  axis="x", thickness=0.062, bolts=6))
    for sign in (1.0, -1.0):
        component.add(gr.plate("%s_gusset_%d" % (component.name, sign > 0),
                               (0.090, 0.105),
                               location=(knee[0] + sign * 0.062, knee[1] + 0.020,
                                         knee[2] - 0.020),
                               rotation=(0, 0, math.pi / 2), thickness=0.016,
                               material="DirtyMetal"))

    # Shank: a welded box section with lightening holes implied by ribs.
    component.add(gr.strut(component.name + "_shank", knee, ankle, (0.098, 0.112),
                           material="DirtyMetal", taper=(0.88, 0.92),
                           bevel_width=0.012))
    for index in range(rng.count(2, 3)):
        z = knee[2] + (ankle[2] - knee[2]) * (index + 0.5) / 3.0
        component.add(gr.rib("%s_shankrib_%d" % (component.name, index), 0.118,
                             (ankle[0], ankle[1], z), thickness=0.120, height=0.024,
                             axis="x", material="OldSteel"))
    # A ram bracing the knee from behind, so the truss is driven and not just standing.
    component.add(gr.piston(component.name + "_kneeram",
                            (asym["side"] * 0.055, -0.075, -0.090),
                            (knee[0] + asym["side"] * 0.030, knee[1] - 0.055,
                             knee[2] - 0.045), rng,
                            barrel_radius=rng.span(0.026, 0.034), rod_radius=0.013))
    _foot(component, rng, ankle, style="hoof", width=rng.span(0.34, 0.41),
          length=rng.span(0.30, 0.36))
    return ankle


def _digitigrade(component, rng, asym):
    """Reverse-jointed, like a bird. The knee breaks FORWARD and the ankle backward,
    which gives a leg with two visible angles in it instead of one -- the most
    animated-looking silhouette in the set, standing still."""
    knee = (rng.jitter(0.010) + config.STANCE_WIDTH * 0.45,
            rng.span(0.10, 0.16) + config.KNEE_FORWARD, config.LEG_KNEE_Z + 0.04)
    ankle = (config.STANCE_WIDTH, rng.span(-0.12, -0.06), GROUND + rng.span(0.16, 0.22))

    component.add(gr.strut(component.name + "_thigh", HIP, knee, (0.125, 0.138),
                           material="DirtyMetal", bevel_width=0.012))
    component.add(gr.bearing(component.name + "_knee", knee,
                             radius=rng.span(0.056, 0.070), axis="x"))
    component.add(gr.strut(component.name + "_shank", knee, ankle, (0.100, 0.112),
                           material="OldSteel", bevel_width=0.010))

    # The hamstring: a shock from the hip down the back of the shank. It is what makes
    # the reverse joint read as sprung rather than broken.
    component.add(gr.shock_absorber(component.name + "_hamstring",
                                    (0, -0.055, -0.055),
                                    (ankle[0], ankle[1] - 0.010, ankle[2] + 0.10),
                                    rng, barrel_radius=rng.span(0.030, 0.040),
                                    spring_radius=rng.span(0.048, 0.060)))
    component.add(gr.cable(component.name + "_tendon", (0, 0.075, -0.045),
                           (knee[0], knee[1] + 0.030, knee[2] - 0.030), rng,
                           radius=0.013, sag=0.03))
    component.add(gr.plate(component.name + "_knee_guard", (0.13, 0.14),
                           location=(knee[0], knee[1] + 0.055, knee[2]),
                           rotation=(rng.span(0.10, 0.30), 0, 0), thickness=0.022,
                           material="DirtyMetal"))
    _foot(component, rng, ankle, style="claw", width=rng.span(0.26, 0.31),
          length=rng.span(0.26, 0.32))
    return ankle


def _piston_column(component, rng, asym):
    """A straight hydraulic column. Industrial, machine-like, and the only archetype
    with no articulated silhouette at all -- which makes it read as the heavy, planted
    option next to the digitigrade."""
    knee = (config.STANCE_WIDTH * 0.5, rng.jitter(0.020) + config.KNEE_FORWARD * 0.7,
            config.LEG_KNEE_Z)
    ankle = (config.STANCE_WIDTH, rng.jitter(0.020), GROUND + rng.span(0.13, 0.18))

    component.add(gr.strut(component.name + "_upper", HIP, knee, (0.142, 0.142),
                           material="DirtyMetal", shape="cyl", vertices=12))
    component.add(prim.cylinder(component.name + "_knee_collar", 0.082, 0.070,
                                location=knee, vertices=12, material="DarkMetal"))
    component.add(gr.strut(component.name + "_lower", knee, ankle, (0.092, 0.092),
                           material="OldSteel", shape="cyl", vertices=10))

    rams = rng.count(2, 3)
    for index in range(rams):
        angle = 2.0 * math.pi * index / rams + rng.jitter(0.3)
        offset = (math.cos(angle) * 0.075, math.sin(angle) * 0.075)
        component.add(gr.piston("%s_ram_%02d" % (component.name, index),
                                (offset[0], offset[1], -0.070),
                                (offset[0] * 0.6, offset[1] * 0.6, ankle[2] + 0.11),
                                rng, barrel_radius=rng.span(0.028, 0.036),
                                rod_radius=0.014))
    for fraction in (0.35, 0.68):
        z = -config.LEG_LENGTH * fraction
        component.add(prim.torus("%s_band_%.0f" % (component.name, fraction * 100),
                                 rng.span(0.088, 0.108), 0.016, location=(0, 0, z),
                                 major_segments=14, minor_segments=4,
                                 material="RustyMetal"))
    component.add(gr.cable_bundle(component.name + "_hyd",
                                  (0.055, -0.070, -0.080),
                                  (0.030, -0.055, ankle[2] + 0.12), rng,
                                  count=rng.count(2, 3), radius=0.011, sag=0.07))
    _foot(component, rng, ankle, style="plate", width=rng.span(0.30, 0.37),
          length=rng.span(0.24, 0.30))
    return ankle


def _hoof_strut(component, rng, asym):
    """A heavy braced strut on a wide hoof. Wide at the bottom, narrow at the top:
    the visual opposite of the digitigrade, and the one that looks like it will not be
    pushed over."""
    knee = (rng.jitter(0.015) + config.STANCE_WIDTH * 0.5,
            rng.span(0.03, 0.08) + config.KNEE_FORWARD, config.LEG_KNEE_Z - 0.03)
    ankle = (config.STANCE_WIDTH, rng.span(-0.03, 0.03), GROUND + rng.span(0.17, 0.23))

    component.add(gr.i_beam(component.name + "_thigh", HIP, knee,
                            web=0.034, flange=rng.span(0.105, 0.135)))
    component.add(prim.taper_box(component.name + "_knee_box",
                                 (rng.span(0.15, 0.19), rng.span(0.15, 0.19), 0.14),
                                 top_scale=(0.75, 0.80), location=knee,
                                 material="DirtyMetal", bevel_width=0.014, segments=2))
    component.add(gr.strut(component.name + "_shank", knee, ankle, (0.150, 0.150),
                           material="DirtyMetal", bevel_width=0.014))

    # Diagonal braces, one per side, at different lengths.
    for sign in (1.0, -1.0):
        scale = 1.0 if sign > 0 or not asym["swap_plates"] else 0.72
        component.add(gr.strut("%s_brace_%d" % (component.name, sign > 0),
                               (sign * 0.070, -0.060, -0.090),
                               (sign * 0.030, -0.020,
                                knee[2] + 0.12 * (2.0 - scale)),
                               (0.030, 0.045), material="OldSteel"))
    component.add(gr.rib(component.name + "_shin_rib",
                         abs(ankle[2] - knee[2]) * 0.8,
                         (knee[0], knee[1] + 0.075, (knee[2] + ankle[2]) * 0.5),
                         thickness=0.034, height=0.048, axis="z"))
    component.add(gr.patch(component.name + "_shin_patch", (0.12, 0.16),
                           (knee[0] + asym["side"] * 0.060, knee[1] + 0.02,
                            (knee[2] + ankle[2]) * 0.5), rng,
                           rotation=(0, 0, math.pi / 2)))
    _foot(component, rng, ankle, style="hoof", width=rng.span(0.33, 0.40),
          length=rng.span(0.26, 0.33))
    return ankle


def _caged_leg(component, rng, asym):
    """Two open rails with springs between them. Light, skeletal, and see-through --
    the leg equivalent of the cage torso, and the reason a squad built from this kit
    does not read as six solid blocks on six solid posts."""
    knee = (config.STANCE_WIDTH * 0.5, rng.jitter(0.02) + config.KNEE_FORWARD * 0.8,
            config.LEG_KNEE_Z + rng.jitter(0.03))
    ankle = (config.STANCE_WIDTH, rng.jitter(0.02), GROUND + rng.span(0.15, 0.20))
    spread = rng.span(0.055, 0.080)

    for sign in (1.0, -1.0):
        component.add(gr.strut("%s_rail_up_%d" % (component.name, sign > 0),
                               (sign * spread * 0.6, 0.0, -0.045),
                               (sign * spread, knee[1], knee[2]),
                               (0.034, 0.048), material="OldSteel"))
        component.add(gr.strut("%s_rail_lo_%d" % (component.name, sign > 0),
                               (sign * spread, knee[1], knee[2]),
                               (sign * spread * 0.55, ankle[1], ankle[2]),
                               (0.030, 0.042), material="OldSteel"))
    for z, width in ((-0.16, spread * 1.9), (knee[2], spread * 2.1),
                     (ankle[2] + 0.09, spread * 1.5)):
        component.add(gr.rib("%s_cross_%.0f" % (component.name, abs(z) * 100),
                             width, (0, knee[1] * 0.5, z), thickness=0.030,
                             height=0.038, axis="x"))

    component.add(gr.shock_absorber(component.name + "_shock",
                                    (0, knee[1] - 0.055, -0.070),
                                    (0, ankle[1] - 0.030, ankle[2] + 0.10), rng,
                                    barrel_radius=rng.span(0.030, 0.038),
                                    spring_radius=rng.span(0.046, 0.058)))
    component.add(gr.gear(component.name + "_knee_gear", knee,
                          radius=rng.span(0.055, 0.075), teeth=rng.count(6, 9),
                          axis="x"))
    component.add(gr.cable(component.name + "_line",
                           (spread * 0.8, knee[1] + 0.045, -0.070),
                           (spread * 0.5, ankle[1] + 0.030, ankle[2] + 0.08), rng,
                           radius=0.012, sag=0.06))
    _foot(component, rng, ankle, style="claw", width=rng.span(0.25, 0.30),
          length=rng.span(0.24, 0.30))
    return ankle


# --- Shared dressing ---------------------------------------------------------

def _shared_dressing(component, rng, asym):
    """Rust patches, snapped onto whatever the archetype actually built.

    The foot is excluded from the snap candidates. A patch is 2 cm thick and lands
    centred on the surface it found, so one that snapped to the sole would hang 1 cm
    BELOW the ground plane -- and the leg would then fail the ground check for a reason
    nobody inspecting the leg would ever guess at, since the patch is the one piece on
    it that has nothing to do with standing."""
    upright = [piece for piece in component.pieces
               if prim.world_bounds(piece)[0].z > GROUND + 0.12]
    if not upright:
        return
    for index in range(rng.count(1, 3)):
        t = rng.span(0.12, 0.72)
        component.add(gr.snapped_patch(
            "%s_patch_%02d" % (component.name, index),
            (rng.span(0.06, 0.11), rng.span(0.05, 0.10)),
            (rng.jitter(0.070), rng.jitter(0.070), -config.LEG_LENGTH * t),
            rng, upright))
