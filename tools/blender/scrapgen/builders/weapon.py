"""Weapons. Mount at the origin, working end along +Y.

Eight archetypes rather than four, because a weapon is the fastest thing to read on a
machine and the slowest to get bored of. Four ranged, four melee, so a squad built from
this kit can differ in what it does and not only in what it looks like.

`+Y is forward` is the load-bearing convention. `export_yup=True` maps Blender +Y onto
glTF -Z, which is Godot's forward, so a barrel modelled along +Y aims where the unit is
aiming with no per-weapon rotation fixup at runtime. A weapon authored along +X looks
fine in Blender, mounts fine on the arm, and fires sideways.

`MuzzleSocket` is the one FREE socket in the kit: it marks where a muzzle flash spawns,
and a sawblade, a sledge and a rail lance genuinely do not have that point in the same
place. Every builder here is responsible for declaring it.
"""

import math

from .. import greeble as gr
from .. import primitives as prim
from . import pick_archetype, asymmetry


ARCHETYPES = ["slug_cannon", "rivet_gun", "saw_blade", "sledge",
              "flamer", "rail_lance", "gatling", "grapple_claw", "sensor_mast"]

## Ranged weapons get a muzzle; melee weapons declare the socket at their striking
## face instead, so impact effects have somewhere to spawn either way.
MELEE = {"saw_blade", "sledge", "grapple_claw"}

## Carries no weapon read at all. A spotter that looks like a gun is a lie the player
## acts on: they read the silhouette, assume damage, and put it in the front line.
SUPPORT = {"sensor_mast"}


def build(component):
    rng = component.rng
    component.archetype = component.forced_archetype or pick_archetype(
        component.seed, ARCHETYPES, rng)
    asym = asymmetry(rng)
    component.recipe = {"archetype": component.archetype,
                        "melee": component.archetype in MELEE}

    _mount(component, rng)
    builder = {
        "slug_cannon":  _slug_cannon,
        "rivet_gun":    _rivet_gun,
        "saw_blade":    _saw_blade,
        "sledge":       _sledge,
        "flamer":       _flamer,
        "rail_lance":   _rail_lance,
        "gatling":      _gatling,
        "grapple_claw": _grapple_claw,
        "sensor_mast":  _sensor_mast,
    }[component.archetype]
    builder(component, rng, asym)
    _shared_dressing(component, rng, asym)
    return component


def _mount(component, rng):
    """The receiver at the origin: the block the arm's wrist clamp closes around.

    Every weapon has one, and it is what puts geometry behind `MountSocket`. It also
    gives the eight archetypes one thing in common, which is what makes them read as a
    weapon SET rather than eight unrelated objects."""
    component.add(prim.box(component.name + "_receiver",
                           (rng.span(0.085, 0.105), rng.span(0.11, 0.15),
                            rng.span(0.075, 0.095)),
                           location=(0, 0.030, 0), material="DarkMetal",
                           bevel_width=0.010, segments=2))
    component.add(prim.cylinder(component.name + "_trunnion", 0.048, 0.105,
                                location=(0, 0.010, 0), rotation=gr.AXIS_ROTATION["x"],
                                vertices=10, material="OldSteel"))
    component.add(gr.bolt_ring(component.name + "_mountbolt", 4, (0, -0.020, 0), 0.046,
                               axis="y", bolt_radius=0.012))


# --- Ranged ------------------------------------------------------------------

def _slug_cannon(component, rng, asym):
    """A big-bore cannon with a muzzle brake and a drum magazine. The heaviest ranged
    silhouette: short, fat barrel, obvious ammunition."""
    length = rng.span(0.34, 0.46)
    bore = rng.span(0.052, 0.070)
    component.add(prim.cylinder(component.name + "_barrel", bore, length,
                                location=(0, 0.10 + length * 0.5, 0),
                                rotation=gr.AXIS_ROTATION["y"], vertices=14,
                                material="OldSteel"))
    component.add(prim.cylinder(component.name + "_jacket", bore * 1.35, length * 0.38,
                                location=(0, 0.14 + length * 0.19, 0),
                                rotation=gr.AXIS_ROTATION["y"], vertices=14,
                                material="DarkMetal"))
    muzzle_y = 0.10 + length

    # The brake: three rings with gaps, which is what a real one looks like from the
    # side and what makes the end of the barrel busy enough to read.
    for index in range(3):
        component.add(prim.torus("%s_brake_%02d" % (component.name, index),
                                 bore * 1.22, 0.014,
                                 location=(0, muzzle_y - 0.030 - index * 0.038, 0),
                                 rotation=gr.AXIS_ROTATION["y"],
                                 major_segments=12, minor_segments=4,
                                 material="RustyMetal"))

    component.add(gr.drum(component.name + "_mag",
                          (asym["side"] * rng.span(0.02, 0.06), 0.070,
                           rng.span(0.075, 0.105)),
                          radius=rng.span(0.070, 0.090), height=rng.span(0.075, 0.095),
                          axis="x", rng=rng, material="DirtyMetal"))
    component.add(gr.pipe_run(component.name + "_feed",
                              [(asym["side"] * 0.03, 0.070, 0.070),
                               (0, 0.080, 0.030), (0, 0.095, 0.010)],
                              radius=0.020, material="DarkMetal"))
    component.add(gr.plate(component.name + "_shield", (0.14, 0.12),
                           location=(0, 0.115, -0.010),
                           rotation=(math.pi / 2, 0, 0), thickness=0.022,
                           material="DirtyMetal"))
    component.socket("MuzzleSocket", (0, muzzle_y, 0))


def _rivet_gun(component, rng, asym):
    """A twin-barrel automatic fed from a hopper. Narrow and busy, where the cannon is
    fat and simple."""
    length = rng.span(0.30, 0.40)
    gap = rng.span(0.026, 0.040)
    for sign in (1.0, -1.0):
        component.add(prim.cylinder("%s_barrel_%d" % (component.name, sign > 0),
                                    rng.span(0.020, 0.028), length,
                                    location=(sign * gap, 0.09 + length * 0.5, 0.010),
                                    rotation=gr.AXIS_ROTATION["y"], vertices=10,
                                    material="OldSteel"))
    component.add(prim.box(component.name + "_shroud",
                           (gap * 2.6, length * 0.55, 0.070),
                           location=(0, 0.10 + length * 0.28, 0.010),
                           material="DarkMetal", bevel_width=0.008, segments=1))
    component.add(gr.grille(component.name + "_cooling", 4,
                            (0, 0.10 + length * 0.28, 0.010),
                            width=gap * 2.7, height=0.060))

    hopper_z = rng.span(0.075, 0.100)
    component.add(prim.taper_box(component.name + "_hopper",
                                 (rng.span(0.10, 0.13), rng.span(0.12, 0.16), 0.11),
                                 top_scale=(1.35, 1.25),
                                 location=(0, 0.075, hopper_z),
                                 material="DirtyMetal", bevel_width=0.010, segments=1))
    component.add(gr.bolt_row(component.name + "_hopperbolt", 3,
                              (-0.040, 0.075 + 0.070, hopper_z - 0.030),
                              (0.040, 0, 0.030), axis="y", rng=rng, radius=0.012))
    component.add(gr.cable(component.name + "_feed_hose", (0, 0.055, hopper_z - 0.045),
                           (0, 0.045, 0.035), rng, radius=0.014, sag=0.02))
    component.socket("MuzzleSocket", (0, 0.09 + length, 0.010))


def _flamer(component, rng, asym):
    """A nozzle with the fuel it burns strapped to the back. The tanks are the point:
    a flamethrower whose fuel is not visible is just a short pipe."""
    length = rng.span(0.20, 0.28)
    component.add(prim.cylinder(component.name + "_pipe", rng.span(0.030, 0.040), length,
                                location=(0, 0.10 + length * 0.5, 0),
                                rotation=gr.AXIS_ROTATION["y"], vertices=10,
                                material="RustyMetal"))
    nozzle_y = 0.10 + length
    component.add(prim.cone(component.name + "_nozzle", rng.span(0.055, 0.072), 0.028,
                            0.075, location=(0, nozzle_y + 0.020, 0),
                            rotation=(-math.pi / 2, 0, 0), vertices=12,
                            material="DarkMetal"))
    component.add(prim.torus(component.name + "_pilot", 0.030, 0.010,
                             location=(0, nozzle_y - 0.010, 0.040),
                             rotation=gr.AXIS_ROTATION["y"], major_segments=10,
                             minor_segments=4, material="Copper"))

    tanks = rng.count(2, 3)
    for index in range(tanks):
        angle = 2.0 * math.pi * index / tanks + 0.4
        component.add(gr.tank("%s_fuel_%02d" % (component.name, index),
                              (math.cos(angle) * 0.070, 0.055,
                               math.sin(angle) * 0.070 + 0.020),
                              radius=rng.span(0.040, 0.052),
                              length=rng.span(0.16, 0.22), axis="y", rng=rng,
                              material="DirtyMetal"))
    component.add(gr.cable_bundle(component.name + "_fuel_line",
                                  (0.055, 0.130, 0.050), (0, 0.145, 0.010), rng,
                                  count=rng.count(2, 3), radius=0.012, sag=0.035))
    component.socket("MuzzleSocket", (0, nozzle_y + 0.055, 0))


def _rail_lance(component, rng, asym):
    """Two long rails, a coil stack, and almost nothing else. The longest and thinnest
    thing in the kit, which is exactly how a sniper weapon should read at a glance."""
    length = rng.span(0.62, 0.82)
    gap = rng.span(0.030, 0.046)
    for sign in (1.0, -1.0):
        component.add(prim.box("%s_rail_%d" % (component.name, sign > 0),
                               (0.026, length, 0.048),
                               location=(sign * gap, 0.10 + length * 0.5, 0),
                               material="Copper" if rng.maybe(0.5) else "OldSteel",
                               bevel_width=0.005, segments=1))
    coils = rng.count(3, 5)
    for index in range(coils):
        y = 0.13 + (length * 0.62) * (index + 0.5) / coils
        component.add(prim.torus("%s_coil_%02d" % (component.name, index),
                                 gap * 1.6, rng.span(0.014, 0.020), location=(0, y, 0),
                                 rotation=gr.AXIS_ROTATION["y"], major_segments=12,
                                 minor_segments=5, material="Copper"))
    component.add(prim.box(component.name + "_breech", (gap * 3.0, 0.13, 0.085),
                           location=(0, 0.105, 0), material="DarkMetal",
                           bevel_width=0.010, segments=1))
    component.add(gr.tank(component.name + "_cap",
                          (asym["side"] * 0.055, 0.085, 0.070),
                          radius=rng.span(0.038, 0.050), length=rng.span(0.13, 0.18),
                          axis="y", rng=rng))
    component.add(gr.cable_bundle(component.name + "_bus",
                                  (asym["side"] * 0.055, 0.085, 0.048),
                                  (0, 0.115, 0.038), rng, count=2, radius=0.011,
                                  sag=0.025))
    # A bipod, because a barrel this long with nothing under it looks unsupported.
    for sign in (1.0, -1.0):
        component.add(gr.strut("%s_bipod_%d" % (component.name, sign > 0),
                               (0, 0.10 + length * 0.55, -0.020),
                               (sign * 0.075, 0.10 + length * 0.62, -0.105),
                               (0.018, 0.018), material="DarkMetal", shape="cyl",
                               vertices=6))
    component.socket("MuzzleSocket", (0, 0.10 + length, 0))


def _gatling(component, rng, asym):
    """A rotary cluster around a spindle, with a motor behind it. The one weapon whose
    silhouette says it will keep firing."""
    length = rng.span(0.30, 0.40)
    barrels = rng.count(5, 7)
    cluster = rng.span(0.042, 0.058)
    for index in range(barrels):
        angle = 2.0 * math.pi * index / barrels
        component.add(prim.cylinder("%s_barrel_%02d" % (component.name, index),
                                    rng.span(0.016, 0.022), length,
                                    location=(math.cos(angle) * cluster,
                                              0.12 + length * 0.5,
                                              math.sin(angle) * cluster),
                                    rotation=gr.AXIS_ROTATION["y"], vertices=8,
                                    material="OldSteel"))
    component.add(prim.cylinder(component.name + "_spindle", cluster * 0.55, length * 0.9,
                                location=(0, 0.12 + length * 0.45, 0),
                                rotation=gr.AXIS_ROTATION["y"], vertices=10,
                                material="DarkMetal"))
    for y in (0.135, 0.12 + length * 0.62, 0.12 + length - 0.020):
        component.add(prim.torus("%s_clamp_%.0f" % (component.name, y * 1000),
                                 cluster * 1.28, 0.016, location=(0, y, 0),
                                 rotation=gr.AXIS_ROTATION["y"], major_segments=14,
                                 minor_segments=4, material="DarkMetal"))
    component.add(prim.cylinder(component.name + "_motor", rng.span(0.068, 0.086), 0.090,
                                location=(0, 0.075, 0), rotation=gr.AXIS_ROTATION["y"],
                                vertices=12, material="DirtyMetal"))
    component.add(gr.gear(component.name + "_drive",
                          (asym["side"] * 0.070, 0.075, 0), radius=rng.span(0.048, 0.062),
                          teeth=rng.count(7, 9), axis="y"))
    component.add(gr.drum(component.name + "_ammo",
                          (-asym["side"] * 0.030, 0.055, -0.080),
                          radius=rng.span(0.060, 0.075), height=0.080, axis="x",
                          rng=rng, material="DirtyMetal"))
    component.socket("MuzzleSocket", (0, 0.12 + length, 0))


def _sensor_mast(component, rng, asym):
    """A dish and an aerial array. The one mount in the set that is not a weapon.

    Worth its own archetype rather than reskinning a barrel. A spotter is a real role
    in this game -- it marks a target and does almost no damage -- and if it carries
    something gun-shaped the player reads "gun", fields it accordingly, and loses the
    unit. The silhouette is the only part of a loadout readable at battle distance, so
    it has to be the truth: no barrel, no muzzle, a dish that obviously looks rather
    than shoots.
    """
    mast_h = rng.span(0.30, 0.42)
    component.add(prim.box(component.name + "_base", (0.11, 0.13, 0.085),
                           location=(0, 0.070, 0), material="DirtyMetal",
                           bevel_width=0.010, segments=2))
    # The mast leans forward rather than standing vertical: it reads as aimed.
    lean: float = rng.span(0.55, 0.85)
    tip = (0.0, 0.070 + math.sin(lean) * mast_h, math.cos(lean) * mast_h)
    component.add(gr.strut(component.name + "_mast", (0, 0.070, 0.030), tip,
                           (0.020,), material="OldSteel", shape="cyl", vertices=8))

    dish_radius = rng.span(0.095, 0.135)
    component.add(prim.cone(component.name + "_dish", dish_radius, 0.018, 0.055,
                            location=tip, rotation=(math.pi * 0.5 - lean, 0, 0),
                            vertices=14, material="OldSteel"))
    component.add(prim.cylinder(component.name + "_feed", 0.016, 0.075,
                                location=(tip[0], tip[1] + math.sin(lean) * 0.045,
                                          tip[2] + math.cos(lean) * 0.045),
                                rotation=(math.pi * 0.5 - lean, 0, 0), vertices=6,
                                material="Copper"))
    # A lens at the hub: the one emissive cue that it is powered and looking.
    component.add(gr.lens(component.name + "_eye",
                          (0, 0.070 + 0.055, 0.020), radius=0.030, axis="y", rng=rng,
                          depth=0.022))

    # Whip aerials, at different heights so the array reads as improvised.
    for index in range(rng.count(2, 3)):
        component.add(gr.antenna("%s_aerial_%02d" % (component.name, index),
                                 (asym["side"] * rng.span(0.03, 0.055) * (index + 1),
                                  0.045, 0.040),
                                 height=rng.span(0.16, 0.30), rng=rng))
    component.add(gr.cable_bundle(component.name + "_loom", (0.045, 0.030, 0.030),
                                  (0.0, 0.020, -0.020), rng, count=2, radius=0.010,
                                  sag=0.03))
    # Declared at the dish, not at a barrel tip: whatever the game spawns here is a
    # scan, not a muzzle flash.
    component.socket("MuzzleSocket", tip)


# --- Melee -------------------------------------------------------------------

def _saw_blade(component, rng, asym):
    """A circular blade on a motor. The only weapon in the kit that is mostly a flat
    disc, so it separates in silhouette from every barrel here."""
    radius = rng.span(0.135, 0.185)
    disc_y = rng.span(0.20, 0.27)
    component.add(prim.cylinder(component.name + "_disc", radius, 0.020,
                                location=(0, disc_y, 0.020),
                                rotation=gr.AXIS_ROTATION["x"], vertices=20,
                                material="OldSteel"))
    # The disc's axis is X, so the blade lies in the YZ plane and the teeth ring
    # around Y and Z. Ringing them around X and Z instead -- the reflex, because most
    # of this kit is authored in XZ -- puts every tooth in the plane the disc is
    # thinnest in: they float clear of the rim, ten detached blocks around a bare
    # circle, and it is invisible from the one angle a saw is usually rendered at.
    teeth = rng.count(10, 14)
    for index in range(teeth):
        angle = 2.0 * math.pi * index / teeth
        component.add(prim.box("%s_tooth_%02d" % (component.name, index),
                               (0.024, 0.032, 0.032),
                               location=(0, disc_y + math.cos(angle) * radius * 0.97,
                                         0.020 + math.sin(angle) * radius * 0.97),
                               rotation=(-angle, 0, 0), material="RustyMetal",
                               bevel_width=0.0, segments=1))
    component.add(prim.cylinder(component.name + "_hub", radius * 0.28, 0.055,
                                location=(0, disc_y, 0.020),
                                rotation=gr.AXIS_ROTATION["x"], vertices=12,
                                material="DarkMetal"))

    # The guard covers the top rear quadrant only -- a fully shrouded blade is a
    # cylinder, and the exposed cutting edge is the whole read.
    component.add(prim.taper_box(component.name + "_guard",
                                 (0.070, radius * 1.3, radius * 0.85),
                                 top_scale=(1.0, 0.55),
                                 location=(0, disc_y - radius * 0.20,
                                           0.020 + radius * 0.62),
                                 material="DirtyMetal", bevel_width=0.010, segments=1))
    component.add(gr.strut(component.name + "_arm", (0, 0.075, 0),
                           (0, disc_y, 0.020), (0.070, 0.070), material="DarkMetal"))
    component.add(prim.cylinder(component.name + "_motor", rng.span(0.055, 0.070), 0.095,
                                location=(asym["side"] * 0.050, 0.115, -0.030),
                                rotation=gr.AXIS_ROTATION["x"], vertices=12,
                                material="DirtyMetal"))
    component.add(gr.cable(component.name + "_drive_belt",
                           (asym["side"] * 0.050, 0.115, 0.010),
                           (0, disc_y - 0.020, 0.020), rng, radius=0.012, sag=0.02))
    component.socket("MuzzleSocket", (0, disc_y + radius * 0.8, 0.020))


def _sledge(component, rng, asym):
    """An engine block on a shaft. Comically heavy, and the most literal expression of
    the whole brief -- it is a car part being used as a club."""
    shaft = rng.span(0.26, 0.36)
    component.add(gr.strut(component.name + "_shaft", (0, 0.075, 0),
                           (0, 0.075 + shaft, 0), (0.055, 0.055), material="OldSteel",
                           shape="cyl", vertices=10))
    for fraction in (0.35, 0.70):
        component.add(prim.torus("%s_grip_%.0f" % (component.name, fraction * 100),
                                 0.036, 0.012,
                                 location=(0, 0.075 + shaft * fraction, 0),
                                 rotation=gr.AXIS_ROTATION["y"], major_segments=10,
                                 minor_segments=4, material="Rubber"))

    head_y = 0.075 + shaft + rng.span(0.045, 0.070)
    component.add(gr.engine_block(component.name + "_head", (0, head_y, 0),
                                  size=(rng.span(0.16, 0.22), rng.span(0.14, 0.19),
                                        rng.span(0.15, 0.20)),
                                  rng=rng, cylinders=rng.count(2, 3)))
    # A striking face, so the hammer has an obvious business end.
    component.add(prim.box(component.name + "_face", (0.16, 0.045, 0.15),
                           location=(0, head_y + rng.span(0.085, 0.105), 0),
                           material="RustyMetal", bevel_width=0.012, segments=2))
    component.add(gr.weld_seam(component.name + "_weld",
                               (-0.070, head_y - 0.070, 0.0),
                               (0.070, head_y - 0.070, 0.0), rng,
                               count=rng.count(4, 6), size=0.017))
    component.add(gr.cable(component.name + "_lanyard", (0, 0.085, 0.040),
                           (asym["side"] * 0.050, 0.14, -0.020), rng,
                           radius=0.010, sag=0.045))
    component.socket("MuzzleSocket", (0, head_y + 0.12, 0))


def _grapple_claw(component, rng, asym):
    """A hydraulic pincer. Two jaws, open, with the rams that close them on show --
    the only weapon here with moving parts you can trace by eye."""
    base_y = rng.span(0.12, 0.16)
    component.add(prim.taper_box(component.name + "_housing",
                                 (rng.span(0.11, 0.14), rng.span(0.13, 0.17), 0.10),
                                 top_scale=(0.85, 0.75), location=(0, base_y, 0),
                                 rotation=(math.pi / 2, 0, 0),
                                 material="DirtyMetal", bevel_width=0.012, segments=2))
    jaw_length = rng.span(0.19, 0.26)
    spread = rng.span(0.30, 0.55)
    for sign in (1.0, -1.0):
        hinge = (sign * 0.055, base_y + 0.055, 0)
        tip = (sign * (0.055 + math.sin(spread) * jaw_length),
               base_y + 0.055 + math.cos(spread) * jaw_length, 0)
        component.add(gr.bearing("%s_hinge_%d" % (component.name, sign > 0), hinge,
                                 radius=0.042, axis="z"))
        component.add(gr.strut("%s_jaw_%d" % (component.name, sign > 0), hinge, tip,
                               (0.050, 0.070), material="OldSteel"))
        # The claw tip, angled inward so the jaws would actually meet if closed.
        component.add(prim.cone("%s_tip_%d" % (component.name, sign > 0), 0.038, 0.010,
                                0.090, location=tip,
                                rotation=(math.pi / 2 - spread * 0.55, 0,
                                          -sign * spread * 0.8),
                                vertices=8, material="RustyMetal"))
        component.add(gr.piston("%s_ram_%d" % (component.name, sign > 0),
                                (sign * 0.030, base_y - 0.030, 0),
                                (sign * (0.055 + math.sin(spread) * jaw_length * 0.45),
                                 base_y + 0.055 + math.cos(spread) * jaw_length * 0.45,
                                 0),
                                rng, barrel_radius=0.028, rod_radius=0.013))
    component.add(gr.cable_bundle(component.name + "_hyd", (0.045, 0.060, 0.020),
                                  (0.020, base_y + 0.020, 0.010), rng,
                                  count=rng.count(2, 3), radius=0.011, sag=0.03))
    component.socket("MuzzleSocket",
                     (0, base_y + 0.055 + math.cos(spread) * jaw_length, 0))


# --- Shared dressing ---------------------------------------------------------

def _shared_dressing(component, rng, asym):
    for index in range(rng.count(1, 2)):
        component.add(gr.snapped_patch(
            "%s_patch_%02d" % (component.name, index),
            (rng.span(0.045, 0.085), rng.span(0.040, 0.075)),
            (rng.jitter(0.050), rng.span(0.05, 0.16), rng.jitter(0.050)),
            rng, component.pieces))
