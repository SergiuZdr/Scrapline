"""The scrapyard vocabulary: engine blocks, radiators, shocks, bearings, cable runs.

This module is the reason the builders are short. A builder that composes raw boxes
produces a machine made of boxes no matter how many it uses -- the eye reads the
primitive, not the arrangement. A builder that composes an ENGINE BLOCK, a RADIATOR
and a SHOCK ABSORBER produces a machine made of salvaged car parts, because those
objects carry their own silhouette and their own real-world scale.

Everything here is authored in the caller's local frame and returns either one object
or a list of them; `Component.add` flattens both, so a builder never has to care which.

Two rules the whole file obeys:

* **Every piece touches something.** A greeble function that places a bolt places it
  ON a surface the caller passed in, not at a hopeful offset. Floating detail is
  invisible from most angles and unmissable from one.
* **Bolts, pistons and hoses are `DarkMetal` or `Rubber`, never painted.** Recessed
  mechanism reading as painted armour is what makes a construct look like one moulded
  toy rather than a thing assembled out of other things.
"""

import math

from mathutils import Vector

from . import primitives as prim


AXES = {"x": 0, "y": 1, "z": 2}

## Rotation that stands a Z-aligned primitive along another axis.
AXIS_ROTATION = {
    "x": (0.0, math.pi / 2, 0.0),
    "y": (math.pi / 2, 0.0, 0.0),
    "z": (0.0, 0.0, 0.0),
}


def _offset(location, axis, amount):
    out = list(location)
    out[AXES[axis]] += amount
    return tuple(out)


# --- Fasteners ---------------------------------------------------------------

def bolt(name, location, radius=0.020, depth=0.026, axis="y", material="DarkMetal"):
    """A hex head. Six vertices on purpose -- it IS a hex bolt, and it costs 20 tris."""
    return prim.cylinder(name, radius, depth, location=location,
                         rotation=AXIS_ROTATION[axis], vertices=6, material=material)


def bolt_row(prefix, count, start, step, axis="y", radius=0.018, rng=None,
             material="DarkMetal"):
    """A line of bolts.

    With `rng` the spacing wanders slightly. A perfectly even row reads as machined
    factory work, which is the opposite of what this kit is for -- these panels were
    bolted on by hand, in a hurry, by somebody who did not measure."""
    out = []
    for index in range(count):
        point = [start[axis_index] + step[axis_index] * index for axis_index in range(3)]
        if rng is not None:
            point = [value + rng.jitter(0.006) for value in point]
        out.append(bolt("%s_%02d" % (prefix, index), tuple(point), radius=radius,
                        axis=axis, material=material))
    return out


def bolt_ring(prefix, count, centre, radius, axis="y", bolt_radius=0.016,
              material="DarkMetal"):
    """Bolts around a circular flange -- the join between two pipe sections, a hub cap,
    an inspection plate."""
    out = []
    for index in range(count):
        angle = 2.0 * math.pi * index / count
        offset = [0.0, 0.0, 0.0]
        first, second = [i for i in range(3) if i != AXES[axis]]
        offset[first] = math.cos(angle) * radius
        offset[second] = math.sin(angle) * radius
        point = tuple(centre[i] + offset[i] for i in range(3))
        out.append(bolt("%s_%02d" % (prefix, index), point, radius=bolt_radius,
                        axis=axis, material=material))
    return out


def weld_seam(prefix, start, end, rng, count=5, size=0.020, material="RustyMetal",
              pieces=None):
    """A run of lumpy blobs along a join.

    A weld is what says "these two pieces were not made together". Randomised size and
    offset, because an even row of identical blobs reads as decoration.

    Pass `pieces` and each blob snaps to the nearest real surface. Without it the run
    is a straight line between two points, and a straight line between two points on a
    curved or open body spends its middle in mid-air -- three welded blobs hanging
    inside the chest cavity."""
    out = []
    start_vector, end_vector = Vector(start), Vector(end)
    for index in range(count):
        t = (index + 0.5) / count
        point = start_vector.lerp(end_vector, t)
        point += Vector((rng.jitter(0.010), rng.jitter(0.010), rng.jitter(0.008)))
        if pieces:
            point = Vector(prim.nearest_surface_point(pieces, tuple(point)))
        radius = size * rng.span(0.7, 1.3)
        out.append(prim.sphere("%s_%02d" % (prefix, index), radius, tuple(point),
                               segments=6, rings=4, material=material))
    return out


# --- Sheet and plate ---------------------------------------------------------

def plate(name, size, location, rotation=(0, 0, 0), thickness=0.022,
          material="DirtyMetal", bevel_width=0.008):
    """A flat armour panel. `size` is (width, height) in the plate's own plane."""
    return prim.box(name, (size[0], thickness, size[1]), location=location,
                    rotation=rotation, material=material,
                    bevel_width=bevel_width, segments=1)


def snapped_patch(name, size, near, rng, pieces, thickness=0.018,
                  material="RustyMetal"):
    """A patch welded onto whatever surface is nearest to `near`.

    The safe way to place dressing. `patch` puts a plate at the coordinate you give
    it, which is only correct if you already know the shape underneath -- and shared
    dressing code by definition does not, because it runs for every archetype
    including ones written later."""
    point = prim.nearest_surface_point(pieces, near)
    # A free orientation, not an axis-aligned one. The patch is centred on the surface
    # so it intersects whatever it landed on regardless of angle, and a plate welded on
    # slightly askew is the entire visual argument for it being a repair.
    rotation = (rng.jitter(1.2), rng.jitter(1.2), rng.jitter(1.2))
    return patch(name, size, point, rng, rotation=rotation, thickness=thickness,
                 material=material)


def patch(name, size, location, rng, rotation=(0, 0, 0), thickness=0.018,
          material="RustyMetal"):
    """A scrap plate welded over a hole. Deliberately off-square and slightly canted --
    a patch that lines up with the panel under it is not a patch, it is a feature."""
    canted = (rotation[0] + rng.jitter(0.09),
              rotation[1] + rng.jitter(0.09),
              rotation[2] + rng.jitter(0.14))
    return prim.box(name, (size[0] * rng.span(0.8, 1.2), thickness,
                           size[1] * rng.span(0.8, 1.2)),
                    location=location, rotation=canted, material=material,
                    bevel_width=0.005, segments=1)


def rib(name, length, location, thickness=0.030, height=0.045, axis="x",
        material="OldSteel"):
    """A stiffening rib. Cheap, and it breaks up a large flat panel at a distance where
    bolts have already stopped resolving."""
    size = {"x": (length, thickness, height),
            "y": (thickness, length, height),
            "z": (thickness, height, length)}[axis]
    return prim.box(name, size, location=location, material=material,
                    bevel_width=0.006, segments=1)


def grille(prefix, count, location, width=0.20, height=0.16, axis="y",
           material="DarkMetal"):
    """Louvred slats in a recess -- a vent, a radiator face, an intake."""
    out = []
    spacing = height / max(1, count)
    for index in range(count):
        z = location[2] - height * 0.5 + spacing * (index + 0.5)
        slat = prim.box("%s_%02d" % (prefix, index), (width, 0.030, spacing * 0.55),
                        location=(location[0], location[1], z),
                        rotation=(0.42, 0, 0), material=material,
                        bevel_width=0.0, segments=1)
        out.append(slat)
    return out


# --- Mechanism ---------------------------------------------------------------

def piston(name, start, end, rng=None, barrel_radius=0.036, rod_radius=0.016,
           extension=0.55):
    """A hydraulic ram: barrel, exposed rod, and a collar where they meet.

    The collar is not decoration. Without it the rod appears to pass through the
    barrel's end cap, and the piece reads as one stepped cylinder rather than as two
    parts that slide."""
    start_vector, end_vector = Vector(start), Vector(end)
    direction = end_vector - start_vector
    length = direction.length
    if length < 1e-5:
        return []
    rotation = direction.to_track_quat("Z", "Y").to_euler()
    barrel_length = length * (1.0 - extension)
    rod_length = length * extension + 0.02

    barrel_centre = start_vector + direction.normalized() * (barrel_length * 0.5)
    rod_centre = end_vector - direction.normalized() * (rod_length * 0.5)
    collar_centre = start_vector + direction.normalized() * barrel_length

    out = [
        prim.cylinder(name + "_barrel", barrel_radius, barrel_length,
                      location=tuple(barrel_centre), rotation=rotation, vertices=10,
                      material="DarkMetal"),
        prim.cylinder(name + "_rod", rod_radius, rod_length, location=tuple(rod_centre),
                      rotation=rotation, vertices=8, material="OldSteel"),
        prim.cylinder(name + "_collar", barrel_radius * 1.15, 0.030,
                      location=tuple(collar_centre), rotation=rotation, vertices=10,
                      material="Copper" if (rng and rng.maybe(0.35)) else "DarkMetal"),
    ]
    return out


def strut(name, start, end, size=(0.06, 0.06), material="OldSteel", shape="box",
          overlap=0.02, bevel_width=0.008, vertices=10, taper=None):
    """A structural member spanning two points.

    Limbs are built as a chain of these, and `overlap` is why they hold together: a
    strut cut exactly to length meets the next one at a mathematical point, and the
    join opens into a visible gap the moment either end is beveled. Two centimetres of
    overrun at each end costs nothing and makes the seam disappear.

    `taper` gives the far end a different cross-section, which is what a limb SHELL
    needs. The alternative -- placing an axis-aligned box at the midpoint of a slanted
    bone -- is the mistake that made the armoured arm read as two white blocks with a
    gap between them: the bone leans forward and the shell does not, so the shell
    crosses it instead of covering it."""
    start_vector, end_vector = Vector(start), Vector(end)
    direction = end_vector - start_vector
    length = direction.length
    if length < 1e-5:
        return None
    rotation = direction.to_track_quat("Z", "Y").to_euler()
    centre = tuple(start_vector + direction * 0.5)
    if taper is not None:
        return prim.taper_box(name, (size[0], size[1], length + overlap * 2),
                              top_scale=taper, location=centre, rotation=rotation,
                              material=material, bevel_width=bevel_width, segments=2)
    if shape == "cyl":
        return prim.cylinder(name, size[0], length + overlap * 2, location=centre,
                             rotation=rotation, vertices=vertices, material=material)
    return prim.box(name, (size[0], size[1], length + overlap * 2), location=centre,
                    rotation=rotation, material=material, bevel_width=bevel_width,
                    segments=1)


def i_beam(prefix, start, end, web=0.030, flange=0.090, material="OldSteel"):
    """A girder: two flanges and a web between them.

    Three struts rather than one, and worth it. An I-beam is the most recognisable
    structural shape there is, and its cross-section reads as "this was scavenged from
    a building" in a way no amount of bolt detail on a plain box does."""
    start_vector, end_vector = Vector(start), Vector(end)
    direction = (end_vector - start_vector)
    length = direction.length
    if length < 1e-5:
        return []
    normal = direction.normalized()
    reference = Vector((0, 1, 0)) if abs(normal.y) < 0.9 else Vector((1, 0, 0))
    side = normal.cross(reference).normalized() * (flange * 0.5)
    out = [strut(prefix + "_web", start, end, (web, flange * 0.72), material=material,
                 bevel_width=0.004)]
    for index, sign in enumerate((1, -1)):
        offset = side * sign
        out.append(strut("%s_flange_%d" % (prefix, index),
                         tuple(start_vector + offset), tuple(end_vector + offset),
                         (flange, web), material=material, bevel_width=0.004))
    return out


def coil_spring(name, start, end, turns=6, radius=0.045, wire=0.010,
                material="OldSteel"):
    """A helical spring, swept as one tube.

    Built from a curve rather than stacked toruses: twenty toruses is twenty shells
    with visible gaps and four times the triangles, and it still does not look
    continuous."""
    start_vector, end_vector = Vector(start), Vector(end)
    axis = end_vector - start_vector
    length = axis.length
    if length < 1e-5:
        return None
    direction = axis.normalized()
    # Any vector not parallel to the axis gives us a stable frame to wind around.
    reference = Vector((0, 0, 1)) if abs(direction.z) < 0.9 else Vector((1, 0, 0))
    side = direction.cross(reference).normalized()
    up = direction.cross(side).normalized()

    points = []
    steps = turns * 6
    for index in range(steps + 1):
        t = index / steps
        angle = 2.0 * math.pi * turns * t
        point = (start_vector + direction * (length * t)
                 + side * (math.cos(angle) * radius)
                 + up * (math.sin(angle) * radius))
        points.append(tuple(point))
    return prim.curve_tube(name, points, wire, material=material, resolution=1,
                           smooth=False)


def shock_absorber(name, start, end, rng, barrel_radius=0.032, spring_radius=0.052):
    """A damper with a spring wound around it. Salvaged suspension, doing the job it
    was built for on a machine it was not."""
    out = piston(name, start, end, rng, barrel_radius=barrel_radius,
                 rod_radius=barrel_radius * 0.45, extension=0.5)
    spring = coil_spring(name + "_spring", start, end,
                         turns=rng.count(5, 8), radius=spring_radius, wire=0.011)
    if spring is not None:
        out.append(spring)
    return out


def bearing(name, location, radius=0.075, axis="x", material="DarkMetal"):
    """A joint: race, hub and a face bolt. This is the piece that says a limb bends
    HERE, and a limb without one bends nowhere in particular."""
    rotation = AXIS_ROTATION[axis]
    return [
        prim.torus(name + "_race", radius, radius * 0.30, location=location,
                   rotation=rotation, major_segments=12, minor_segments=5,
                   material=material),
        prim.cylinder(name + "_hub", radius * 0.55, radius * 0.9, location=location,
                      rotation=rotation, vertices=10, material="OldSteel"),
        bolt(name + "_cap", _offset(location, axis, radius * 0.5), radius=radius * 0.24,
             depth=radius * 0.35, axis=axis, material="Copper"),
    ]


def gear(name, location, radius=0.07, teeth=8, axis="x", material="OldSteel"):
    """An exposed gear. Teeth are boxes on the rim rather than a modelled involute --
    at gameplay distance the silhouette is the whole read, and eight boxes deliver it
    for a tenth of the cost."""
    rotation = AXIS_ROTATION[axis]
    out = [prim.cylinder(name + "_disc", radius, 0.030, location=location,
                         rotation=rotation, vertices=12, material=material)]
    first, second = [i for i in range(3) if i != AXES[axis]]
    for index in range(teeth):
        angle = 2.0 * math.pi * index / teeth
        point = list(location)
        point[first] += math.cos(angle) * radius
        point[second] += math.sin(angle) * radius
        tooth_rotation = list(rotation)
        tooth_rotation[AXES[axis]] += angle
        out.append(prim.box("%s_tooth_%02d" % (name, index),
                            (radius * 0.28, radius * 0.28, 0.028),
                            location=tuple(point), rotation=tuple(tooth_rotation),
                            material=material, bevel_width=0.0, segments=1))
    return out


# --- Plumbing ----------------------------------------------------------------

def pipe_run(name, points, radius=0.026, material="OldSteel", flanges=True):
    """Rigid conduit through a list of corners, with a flange at each end.

    Hard POLY corners, not a smooth sweep: this is welded steel pipe, and a pipe that
    curves gently between two points is a hose."""
    out = [prim.curve_tube(name, points, radius, material=material, resolution=1,
                           smooth=False)]
    if flanges and len(points) >= 2:
        for label, point in (("a", points[0]), ("b", points[-1])):
            out.append(prim.sphere("%s_flange_%s" % (name, label), radius * 1.5, point,
                                   segments=8, rings=4, material="DarkMetal"))
    return out


def cable(name, start, end, rng, radius=0.014, sag=0.08, material="Rubber"):
    """A hose or loom that hangs.

    The sag is the whole point. A cable drawn as a straight line between two mounts
    reads as a strut, and a machine covered in struts looks welded rather than
    plumbed. Gravity is the cheapest cue that a thing is slack."""
    start_vector, end_vector = Vector(start), Vector(end)
    points = []
    steps = 6
    for index in range(steps + 1):
        t = index / steps
        point = start_vector.lerp(end_vector, t)
        # A parabola pinned at both ends, plus enough noise that no two cables on a
        # machine hang identically.
        point.z -= math.sin(math.pi * t) * sag
        point.x += rng.jitter(0.012) * math.sin(math.pi * t)
        point.y += rng.jitter(0.012) * math.sin(math.pi * t)
        points.append(tuple(point))
    return prim.curve_tube(name, points, radius, material=material, resolution=1,
                           smooth=True)


def cable_bundle(prefix, start, end, rng, count=3, radius=0.011, sag=0.08):
    """Several cables between the same two points, each hanging differently. One cable
    is plumbing; three is a machine somebody kept repairing."""
    out = []
    for index in range(count):
        spread = (index - (count - 1) * 0.5) * radius * 2.6
        out.append(cable("%s_%02d" % (prefix, index),
                         (start[0] + spread, start[1], start[2]),
                         (end[0] + spread, end[1], end[2]), rng,
                         radius=radius * rng.span(0.85, 1.15),
                         sag=sag * rng.span(0.7, 1.4),
                         material="Rubber" if rng.maybe(0.75) else "Copper"))
    return out


def exhaust_stack(name, location, height=0.24, radius=0.038, rng=None,
                  material="RustyMetal"):
    """A stub stack with a burnt tip and a heat shield ring. Reads as a working engine
    even when nothing is moving."""
    out = [
        prim.cylinder(name + "_pipe", radius, height,
                      location=(location[0], location[1], location[2] + height * 0.5),
                      vertices=10, material=material),
        prim.cylinder(name + "_tip", radius * 1.18, 0.035,
                      location=(location[0], location[1], location[2] + height - 0.015),
                      vertices=10, material="DarkMetal"),
        prim.cylinder(name + "_shield", radius * 1.35, 0.026,
                      location=(location[0], location[1], location[2] + height * 0.35),
                      vertices=10, material="OldSteel"),
    ]
    if rng is not None and rng.maybe(0.5):
        out.append(prim.cylinder(name + "_cap", radius * 1.1, 0.020,
                                 location=(location[0], location[1] + radius * 0.7,
                                           location[2] + height + 0.010),
                                 rotation=(0.5, 0, 0), vertices=8,
                                 material="RustyMetal"))
    return out


# --- Salvaged assemblies -----------------------------------------------------

def engine_block(name, location, size=(0.30, 0.26, 0.24), rng=None, cylinders=4):
    """A car engine: block, a bank of cylinder heads, a manifold and head bolts.

    The single most legible "this came off a vehicle" object in the kit, which is why
    it earns its triangles. The cylinder bank is what carries it -- a bare block is
    just a box."""
    out = [prim.box(name + "_block", size, location=location, material="DarkMetal",
                    bevel_width=0.014, segments=2)]
    top = location[2] + size[2] * 0.5
    spacing = size[0] / (cylinders + 0.6)
    heads = []
    for index in range(cylinders):
        x = location[0] - size[0] * 0.5 + spacing * (index + 0.8)
        head = prim.cylinder("%s_head_%02d" % (name, index), spacing * 0.36, 0.085,
                             location=(x, location[1], top + 0.030), vertices=10,
                             material="OldSteel")
        heads.append(head)
        out.append(head)
        out.append(bolt("%s_headbolt_%02d" % (name, index),
                        (x, location[1], top + 0.070), radius=0.014, depth=0.024,
                        axis="z"))
    # A manifold tying the heads together, on whichever side the caller's rng picks.
    if heads:
        side = (rng.sign() if rng is not None else 1.0) * (size[1] * 0.5 + 0.030)
        manifold = [(heads[0].location.x, location[1] + side, top + 0.030)]
        for head in heads:
            manifold.append((head.location.x, location[1] + side, top + 0.030))
        manifold.append((heads[-1].location.x, location[1] + side, location[2]))
        out.extend(pipe_run(name + "_manifold", manifold, radius=0.022,
                            material="RustyMetal", flanges=False))
    return out


def radiator(name, location, size=(0.26, 0.06, 0.22), rng=None, fins=7):
    """A rad core: frame, fins, and top and bottom tanks. Flat, wide, and instantly
    readable as a cooling element -- which is the silhouette a heat-management machine
    wants somewhere on it."""
    out = [
        prim.box(name + "_frame", size, location=location, material="OldSteel",
                 bevel_width=0.008, segments=1),
        prim.box(name + "_tank_top", (size[0] * 1.04, size[1] * 1.3, 0.045),
                 location=(location[0], location[1], location[2] + size[2] * 0.5),
                 material="Copper" if (rng and rng.maybe(0.4)) else "DarkMetal",
                 bevel_width=0.008, segments=1),
        prim.box(name + "_tank_bottom", (size[0] * 1.04, size[1] * 1.3, 0.040),
                 location=(location[0], location[1], location[2] - size[2] * 0.5),
                 material="DarkMetal", bevel_width=0.008, segments=1),
    ]
    spacing = size[2] * 0.86 / fins
    for index in range(fins):
        z = location[2] - size[2] * 0.43 + spacing * (index + 0.5)
        out.append(prim.box("%s_fin_%02d" % (name, index),
                            (size[0] * 0.94, size[1] * 1.25, spacing * 0.42),
                            location=(location[0], location[1], z),
                            material="DarkMetal", bevel_width=0.0, segments=1))
    return out


def drum(name, location, radius=0.13, height=0.30, axis="z", rng=None,
         material="RustyMetal"):
    """An oil drum with rolling hoops.

    Use it sparingly. A drum is the largest, highest-contrast object available here,
    and putting one on every variant makes the whole roster read as the same machine
    -- which is exactly what happened to this project's chassis set once already."""
    rotation = AXIS_ROTATION[axis]
    out = [prim.cylinder(name + "_body", radius, height, location=location,
                         rotation=rotation, vertices=14, material=material)]
    for offset in (-height * 0.26, height * 0.26):
        out.append(prim.torus(name + ("_hoop_%d" % (offset > 0)), radius * 1.02, 0.016,
                              location=_offset(location, axis, offset),
                              rotation=rotation, major_segments=14, minor_segments=4,
                              material="DarkMetal"))
    if rng is not None and rng.maybe(0.6):
        out.append(prim.cylinder(name + "_bung", radius * 0.22, 0.020,
                                 location=_offset(location, axis, height * 0.5),
                                 rotation=rotation, vertices=8, material="Copper"))
    return out


def tank(name, location, radius=0.075, length=0.28, axis="y", rng=None,
         material="OldSteel"):
    """A pressure vessel: cylinder with domed ends and a valve. Fuel, coolant,
    hydraulic accumulator -- whatever the machine needs to be carrying."""
    rotation = AXIS_ROTATION[axis]
    out = [prim.cylinder(name + "_body", radius, length, location=location,
                         rotation=rotation, vertices=12, material=material)]
    for sign in (-1, 1):
        out.append(prim.sphere("%s_cap_%d" % (name, sign > 0), radius,
                               _offset(location, axis, sign * length * 0.5),
                               segments=10, rings=5, material=material))
    valve_axis = "z" if axis != "z" else "y"
    out.append(prim.cylinder(name + "_valve", radius * 0.28, 0.055,
                             location=_offset(location, valve_axis, radius * 0.9),
                             rotation=AXIS_ROTATION[valve_axis], vertices=8,
                             material="Copper"))
    if rng is not None:
        out.extend(bolt_ring(name + "_band", 6, location, radius * 1.02, axis=axis,
                             bolt_radius=0.012))
    return out


def lens(name, location, radius=0.055, axis="y", rng=None, depth=0.030):
    """An eye: recessed housing, glass, and a hood over it.

    The hood is what makes it read as an eye rather than a headlight. It also stops the
    emissive disc washing out under the game's warm key light, which is the difference
    between a lens that glows and a white dot."""
    rotation = AXIS_ROTATION[axis]
    out = [
        prim.cylinder(name + "_housing", radius * 1.28, depth * 0.9, location=location,
                      rotation=rotation, vertices=12, material="DarkMetal"),
        prim.cylinder(name + "_glass", radius, depth,
                      location=_offset(location, axis, depth * 0.35),
                      rotation=rotation, vertices=12, material="Glass"),
    ]
    hood_axis = "z" if axis != "z" else "x"
    out.append(prim.box(name + "_hood", (radius * 2.5, radius * 1.1, 0.022),
                        location=_offset(_offset(location, axis, depth * 0.30),
                                         hood_axis, radius * 1.15),
                        rotation=(0.34 if axis == "y" else 0.0, 0, 0),
                        material="OldSteel", bevel_width=0.006, segments=1))
    return out


def antenna(name, base, height=0.26, rng=None):
    """A whip aerial with a mounting foot, and sometimes a dish. Cheap vertical
    interest, and the one thing that gives a head a recognisable profile from behind."""
    lean = (rng.jitter(0.22), rng.jitter(0.16), 0.0) if rng is not None else (0, 0, 0)
    out = [
        prim.cylinder(name + "_foot", 0.026, 0.030, location=base, vertices=8,
                      material="DarkMetal"),
        prim.cone(name + "_whip", 0.013, 0.004, height,
                  location=(base[0] + math.sin(lean[1]) * height * 0.5,
                            base[1] - math.sin(lean[0]) * height * 0.5,
                            base[2] + height * 0.5),
                  rotation=lean, vertices=6, material="OldSteel"),
    ]
    if rng is not None and rng.maybe(0.4):
        tip = (base[0] + math.sin(lean[1]) * height,
               base[1] - math.sin(lean[0]) * height, base[2] + height)
        out.append(prim.cone(name + "_dish", 0.055, 0.010, 0.035, location=tip,
                             rotation=(lean[0] + 1.2, lean[1], 0), vertices=10,
                             material="OldSteel"))
    return out


def scrap_sheet(name, size, location, rng, material="RustyMetal"):
    """A bent offcut of sheet steel: two panels meeting at an angle.

    Structurally useless, visually load-bearing. It is the piece that makes a machine
    look like it was finished with whatever was lying nearby."""
    fold = rng.span(0.25, 0.75)
    half = size[0] * 0.5
    return [
        prim.box(name + "_a", (half, 0.014, size[1]),
                 location=(location[0] - half * 0.5, location[1], location[2]),
                 rotation=(0, 0, rng.jitter(0.10)), material=material,
                 bevel_width=0.004, segments=1),
        prim.box(name + "_b", (half, 0.014, size[1] * rng.span(0.7, 1.0)),
                 location=(location[0] + half * 0.5,
                           location[1] + math.sin(fold) * half * 0.4, location[2]),
                 rotation=(0, 0, fold), material=material,
                 bevel_width=0.004, segments=1),
    ]


# --- Industrial composites ---------------------------------------------------
#
# Everything below exists because the roster read as primitives bolted together. A box
# with a cylinder on it is a box with a cylinder on it however it is bevelled; what
# makes a machine read as salvaged industrial equipment is that its parts are
# RECOGNISABLE OBJECTS -- a flanged rotary joint, a hydraulic clevis, a bank of cooling
# fins, a control panel. These are the vocabulary the redesigned archetypes compose
# from, so a builder places "a pump housing", not "a cylinder".

def flange_joint(name, location, radius=0.070, axis="x", thickness=0.055,
                 bolts=6, material="OldSteel"):
    """A bolted rotary joint: two flanges face to face with a bolt circle through them.

    The single most recognisable "this rotates and was engineered" detail on industrial
    machinery, and the thing a bare `bearing` does not say. A bearing is a race; this is
    a joint somebody built and can unbolt."""
    rotation = AXIS_ROTATION[axis]
    offset = {"x": (thickness * 0.5, 0, 0), "y": (0, thickness * 0.5, 0),
              "z": (0, 0, thickness * 0.5)}[axis]
    out = [
        prim.cylinder(name + "_hub", radius * 0.55, thickness * 1.6, location=location,
                      rotation=rotation, vertices=12, material="DarkMetal"),
    ]
    for sign in (1.0, -1.0):
        centre = tuple(location[i] + offset[i] * sign for i in range(3))
        out.append(prim.cylinder("%s_flange_%d" % (name, sign > 0), radius,
                                 thickness * 0.55, location=centre, rotation=rotation,
                                 vertices=14, material=material))
        out.extend(bolt_ring("%s_flangebolt_%d" % (name, sign > 0), bolts, centre,
                             radius * 0.74, axis=axis, bolt_radius=radius * 0.13))
    return out


def clevis(name, location, radius=0.038, axis="x", gap=0.055, depth=0.085,
           material="OldSteel"):
    """The forked end of a hydraulic ram: two cheeks and a pin through them.

    Every cylinder on real plant equipment terminates in one of these. Without it a
    piston is a tube that happens to touch another tube, and the eye reads glue rather
    than a pinned joint."""
    out = []
    across = {"x": 1, "y": 0, "z": 0}[axis]
    for sign in (1.0, -1.0):
        centre = list(location)
        centre[across] += sign * gap * 0.5
        out.append(prim.box("%s_cheek_%d" % (name, sign > 0),
                            (0.020 if across == 0 else depth,
                             depth if across == 0 else 0.020, depth),
                            location=tuple(centre), material=material,
                            bevel_width=0.006, segments=1))
    out.append(prim.cylinder(name + "_pin", radius * 0.42, gap * 1.5,
                             location=location, rotation=AXIS_ROTATION[axis],
                             vertices=8, material="DarkMetal"))
    return out


def cooling_fins(prefix, count, location, span=0.24, depth=0.13, axis="z",
                 material="DarkMetal"):
    """A stack of cooling fins on a housing: an air-cooled engine or a generator can.

    Reads as "this makes heat and was designed to shed it", which is most of what says
    a torso is machinery rather than a container."""
    out = []
    step = span / max(1, count)
    for index in range(count):
        offset = -span * 0.5 + step * (index + 0.5)
        centre = list(location)
        centre["xyz".index(axis)] += offset
        size = {"z": (depth, depth, step * 0.42),
                "x": (step * 0.42, depth, depth),
                "y": (depth, step * 0.42, depth)}[axis]
        out.append(prim.box("%s_%d" % (prefix, index), size, location=tuple(centre),
                            material=material, bevel_width=0.004, segments=1))
    return out


def control_panel(prefix, location, size=(0.16, 0.14), rotation=(0, 0, 0), rng=None,
                  material="DarkMetal"):
    """A recessed instrument panel: face plate, two gauges and a row of switches.

    Small, but it is the detail that says a person operated this thing -- which is what
    separates salvaged equipment from a prop."""
    out = [plate(prefix + "_face", size, location, rotation=rotation, thickness=0.020,
                 material=material)]
    for index, side in enumerate((-1.0, 1.0)):
        centre = (location[0] + side * size[0] * 0.24, location[1] - 0.014,
                  location[2] + size[1] * 0.20)
        out.append(prim.cylinder("%s_gauge_%d" % (prefix, index), size[0] * 0.15, 0.016,
                                 location=centre, rotation=AXIS_ROTATION["y"],
                                 vertices=10, material="OldSteel"))
        out.append(prim.cylinder("%s_glass_%d" % (prefix, index), size[0] * 0.11, 0.008,
                                 location=(centre[0], centre[1] - 0.012, centre[2]),
                                 rotation=AXIS_ROTATION["y"], vertices=10,
                                 material="Glass"))
    count = 3 if rng is None else rng.count(3, 4)
    for index in range(count):
        x = location[0] - size[0] * 0.26 + size[0] * 0.52 * index / max(1, count - 1)
        out.append(prim.box("%s_switch_%d" % (prefix, index), (0.016, 0.020, 0.026),
                            location=(x, location[1] - 0.016,
                                      location[2] - size[1] * 0.26),
                            material="Copper", bevel_width=0.003, segments=1))
    return out


def pulley(name, location, radius=0.058, width=0.036, axis="x", material="DarkMetal"):
    """A belt pulley with a grooved rim. Vehicle engine vocabulary."""
    rotation = AXIS_ROTATION[axis]
    return [
        prim.cylinder(name + "_disc", radius, width, location=location,
                      rotation=rotation, vertices=14, material=material),
        prim.torus(name + "_groove", radius * 0.98, width * 0.22, location=location,
                   rotation=rotation, major_segments=14, minor_segments=4,
                   material="OldSteel"),
        prim.cylinder(name + "_boss", radius * 0.30, width * 1.5, location=location,
                      rotation=rotation, vertices=10, material="OldSteel"),
    ]


# --- Repair history ----------------------------------------------------------
#
# A scrapyard machine has been fixed many times, and that history is part of its
# identity rather than damage laid on top of it. The rule everything below follows:
# a repair must look FUNCTIONAL. A patch is bolted AND welded, because one alone is a
# floating plate. A brace spans two points that would actually need bracing. A hose
# starts and ends at a fitting. Detail that does not do a job reads as noise, and noise
# is what makes a model look procedurally generated.

## Metals a repair is made from. Deliberately not `DirtyMetal`: a patch in the same
## paint as the panel under it is a feature, not a repair.
REPAIR_METALS = ["RustyMetal", "OldSteel", "DarkMetal"]


def mixed_bolt_row(prefix, count, start, step, rng, axis="y", radius=0.016,
                   material="DarkMetal"):
    """A bolt row where one or two fasteners have been replaced with the wrong size.

    The cheapest repair cue there is, and the most believable: nobody rebuilding a
    machine out of salvage has a full set of matching bolts."""
    out = []
    swap = rng.count(1, 2)
    picked = {rng.count(0, max(0, count - 1)) for _ in range(swap)}
    for index in range(count):
        at = tuple(start[i] + step[i] * index for i in range(3))
        if index in picked:
            out.append(bolt("%s_new_%d" % (prefix, index), at,
                            radius=radius * rng.span(1.25, 1.55), axis=axis,
                            material="OldSteel"))
        else:
            out.append(bolt("%s_%d" % (prefix, index), at, radius=radius, axis=axis,
                            material=material))
    return out


def repair_patch(name, size, location, rng, pieces=None, rotation=(0, 0, 0),
                 thickness=0.016):
    """A plate in the WRONG metal, bolted over a surface and welded round its edge.

    Bolts and welds together, because a plate with neither is a sticker and a plate
    with only one reads as unfinished. Pass `pieces` and it snaps to the nearest real
    surface rather than floating at a computed coordinate."""
    metal = REPAIR_METALS[rng.count(0, len(REPAIR_METALS) - 1)]
    at = location if pieces is None else prim.nearest_surface_point(pieces, location)
    plate_obj = patch(name, size, at, rng, rotation=rotation, thickness=thickness,
                      material=metal)
    out = [plate_obj]
    half_w, half_h = size[0] * 0.5, size[1] * 0.5
    for corner_x, corner_z in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        out.append(bolt("%s_bolt_%d%d" % (name, corner_x > 0, corner_z > 0),
                        (at[0] + corner_x * half_w * 0.78, at[1],
                         at[2] + corner_z * half_h * 0.78),
                        radius=0.011, axis="y", material="OldSteel"))
    out.extend(weld_seam("%s_weld" % name,
                         (at[0] - half_w, at[1], at[2] - half_h),
                         (at[0] + half_w, at[1], at[2] - half_h), rng,
                         count=rng.count(3, 5), size=0.014))
    return out


def improvised_brace(name, start, end, rng, material="OldSteel"):
    """A strap bolted across two points that needed holding together.

    Flat bar rather than tube, with a bolt at each end and a kink in the middle -- the
    shape of something cut from stock and bent by hand to fit."""
    mid = tuple((start[i] + end[i]) * 0.5 for i in range(3))
    kink = (mid[0] + rng.jitter(0.020), mid[1] + rng.span(0.012, 0.032),
            mid[2] + rng.jitter(0.020))
    out = [
        strut(name + "_a", start, kink, (0.030, 0.014), material=material,
              bevel_width=0.004),
        strut(name + "_b", kink, end, (0.030, 0.014), material=material,
              bevel_width=0.004),
    ]
    for index, at in enumerate((start, end)):
        out.append(prim.box("%s_pad_%d" % (name, index), (0.046, 0.020, 0.046),
                            location=at, material=material, bevel_width=0.005,
                            segments=1))
        out.append(bolt("%s_padbolt_%d" % (name, index), at, radius=0.013, axis="y",
                        material="DarkMetal"))
    return out


def access_panel(name, size, location, rng, rotation=(0, 0, 0), axis="y",
                 material="DirtyMetal"):
    """A recessed inspection hatch: sunk frame, proud door, hinge and a captive screw.

    Layered rather than flat -- the frame sits IN the surface and the door sits proud
    of it, which is the overlap that makes a panel read as manufactured."""
    thickness = 0.020
    out = [
        plate(name + "_frame", (size[0] * 1.12, size[1] * 1.12), location,
              rotation=rotation, thickness=thickness * 0.6, material="DarkMetal"),
        plate(name + "_door", size,
              (location[0], location[1] - 0.010, location[2]),
              rotation=rotation, thickness=thickness, material=material),
    ]
    out.append(prim.box(name + "_hinge", (size[0] * 0.22, 0.018, 0.016),
                        location=(location[0] - size[0] * 0.44, location[1] - 0.016,
                                  location[2]),
                        material="OldSteel", bevel_width=0.004, segments=1))
    out.append(prim.cylinder(name + "_screw", 0.014, 0.022,
                             location=(location[0] + size[0] * 0.38,
                                       location[1] - 0.020, location[2]),
                             rotation=AXIS_ROTATION[axis], vertices=8,
                             material="Copper"))
    return out


def hose_port(name, location, axis="y", radius=0.020, material="Copper"):
    """A boss and union where a hose lands. The thing that makes a hose a CONNECTION."""
    rotation = AXIS_ROTATION[axis]
    return [
        prim.cylinder(name + "_boss", radius * 1.35, 0.024, location=location,
                      rotation=rotation, vertices=10, material="OldSteel"),
        prim.cylinder(name + "_union", radius, 0.034, location=location,
                      rotation=rotation, vertices=8, material=material),
    ]


def hose_between(name, start, end, rng, radius=0.012, sag=0.06, axis="y",
                 material="Rubber"):
    """A hose WITH a fitting at each end.

    The whole point. A hose drawn between two arbitrary coordinates is a rubber band
    lying on a model; the same hose leaving a union and arriving at another is
    plumbing, and the eye knows the difference immediately."""
    out = list(hose_port(name + "_a", start, axis=axis, radius=radius * 1.5))
    out.extend(hose_port(name + "_b", end, axis=axis, radius=radius * 1.5))
    out.append(cable(name + "_line", start, end, rng, radius=radius, sag=sag,
                     material=material))
    return out
