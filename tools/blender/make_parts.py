"""Generates Scrapline's modular construct parts as low-poly hard-surface meshes.

Run headless:

    blender --background --python tools/blender/make_parts.py -- --out art/parts
    blender --background --python tools/blender/make_parts.py -- --only ch_brute --render

Why this exists
---------------
The parts are machines: boxes, bevels, cylinders, panel lines, greebles. That is the
one subject procedural generation is genuinely good at, and it means a 20-part roster
costs an afternoon of iteration instead of weeks of modelling. It also means adding a
part later is a dictionary entry, not a modelling session.

What it guarantees for the game
-------------------------------
* **A shared socket standard.** Every chassis exports empties named `socket_core`,
  `socket_arm_l`, `socket_arm_r`, `socket_module`. Every attachment is modelled with
  its mount at the origin, facing +Z. That contract is what lets the game bolt any arm
  onto any chassis at runtime without per-combination fixups.
* **Consistent scale.** One Blender unit is one game metre. A chassis is ~1.1 m tall,
  matching the collision-free box sizes the battle view already uses.
* **A triangle budget.** Each part is checked against `TRI_BUDGET` and the script warns
  if it is exceeded, because the target is a phone.

Reads `data/parts/*.json` so the generated set always matches the actual roster --
the mesh path already recorded on each part is where its `.glb` is written.
"""

import bpy
import bmesh
import json
import math
import os
import random
import sys

from mathutils import Vector


# Twelve constructs on screen at once, so the real ceiling is roughly 45k triangles
# for the whole squad pair. A 2019 phone renders that without noticing; the budget
# exists to catch a runaway greeble loop, not to chase the last hundred tris.
TRI_BUDGET = 3800
UNIT = 1.0  # one Blender unit == one game metre

## Applied to every finished ATTACHMENT -- arm, core and module.
##
## All three were dimensioned against a `box()` that silently halved its input, so the
## corrected builder produces them at twice their intended size. Only the arms were
## scaled back at first, which left cores and modules WIDER THAN THE TORSO they mount to:
## a module box big enough to dominate the silhouette of every construct in the roster,
## and a core lens that made every frame read as "a dark box with a white circle on it".
ARM_SCALE = 0.5
ATTACH_SCALE = 0.5


def scale_part(obj, factor):
    """Scales a finished part in place and bakes it in."""
    obj.scale = (factor, factor, factor)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


# --- Blender housekeeping ----------------------------------------------------

def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.objects):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def box(name, size, location=(0, 0, 0), bevel=0.015, segments=2, zone="metal"):
    """A bevelled box. Bevels are what stop low-poly hard surface reading as
    programmer art -- they catch the key light and give every edge a highlight."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.active_object
    obj.name = name
    # `size=1` builds a UNIT cube (-0.5..+0.5), so the scale factor to reach a dimension
    # of `d` is `d`, not `d / 2`. With the halving, every box in the roster came out at
    # half its declared size while every cylinder was correct -- which is the real reason
    # plates, bolts, cowls and crests floated: they were never placed wrongly, they were
    # simply too small to reach what they were supposed to be sitting on.
    obj.scale = (size[0], size[1], size[2])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        modifier = obj.modifiers.new("Bevel", "BEVEL")
        modifier.width = bevel
        modifier.segments = segments
        modifier.limit_method = "ANGLE"
        modifier.angle_limit = math.radians(40)
        bpy.ops.object.modifier_apply(modifier="Bevel")
    apply_material(obj, zone_material(zone))
    return obj


def cylinder(name, radius, depth, location=(0, 0, 0), vertices=12, rotation=(0, 0, 0),
             zone="metal"):
    bpy.ops.mesh.primitive_cylinder_add(
        radius=radius, depth=depth, vertices=vertices, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    apply_material(obj, zone_material(zone))
    return obj


def recentre_origin(obj):
    """Puts the object's origin at the world origin and bakes the offset into the mesh.

    Blender's join leaves the origin wherever the first piece happened to be, so a
    chassis exported straight after joining sits ~0.24 m off its own node. In the game
    that means every construct renders offset from the position the simulation thinks
    it occupies -- which is invisible until you look closely and then impossible to
    unsee."""
    previous = bpy.context.scene.cursor.location.copy()
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.context.scene.cursor.location = previous
    return obj


def join(objects, name, recentre=True):
    """Merges objects into one.

    `recentre=False` leaves the origin alone, for callers that are about to place it
    somewhere specific. Recentring to the world origin and THEN moving the origin to a
    joint shifts the mesh data twice, which leaves a limb whose geometry sits a hip's
    height below where its own bounds claim it is."""
    for obj in bpy.context.selected_objects:
        obj.select_set(False)
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = name
    return recentre_origin(joined) if recentre else joined


def set_origin(obj, point):
    """Moves an object's origin to `point` without moving the geometry.

    This is what makes a limb animatable. A leg joined like everything else has its
    origin wherever the joiner left it, so rotating the object swings the whole leg
    around some arbitrary spot in space. With the origin ON the hip joint, rotation is
    the hip rotating -- which is the entire walk cycle."""
    previous = bpy.context.scene.cursor.location.copy()
    bpy.context.scene.cursor.location = point
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.context.scene.cursor.location = previous
    return obj


def parent_keeping_transform(child, parent):
    """Parents `child` to `parent` the way Blender itself does it.

    Assigning `child.parent = parent` leaves `matrix_parent_inverse` at identity, so the
    child's transform is silently reinterpreted in the parent's frame. With `export_yup`
    the glTF exporter then writes child transforms in a rotated basis, and the runtime
    reads a socket that says "0.43 m up" and places the arm at ground level -- the whole
    construct assembles lying down. `parent_set(keep_transform=True)` sets the inverse
    matrix properly and the exported hierarchy matches what Blender shows."""
    bpy.ops.object.select_all(action="DESELECT")
    child.select_set(True)
    parent.select_set(True)
    bpy.context.view_layer.objects.active = parent
    bpy.ops.object.parent_set(type="OBJECT", keep_transform=True)
    return child


def socket(name, location, parent):
    """An empty the game reads as a mount point. Named exactly as the runtime expects."""
    bpy.ops.object.empty_add(type="ARROWS", radius=0.08, location=location)
    empty = bpy.context.active_object
    empty.name = name
    parent_keeping_transform(empty, parent)
    return empty


# --- Material zones ----------------------------------------------------------
#
# Every piece is tagged with a ZONE rather than a colour, and the zone name survives
# into the `.glb` as the material name. The game looks that name up in its own palette
# (`scripts/presentation/part_materials.gd`) and builds the real material there.
#
# That indirection is the whole point. Retuning the look of worn metal across a
# twenty-part roster is one edit in GDScript, not a twenty-part Blender re-export --
# and only the `paint` zone is team-tinted, so a construct keeps its own metal instead
# of becoming a monochrome silhouette in team red or team blue.
#
# The zones, and what each one is FOR:
#
#   paint   large armour surfaces that carry team livery -- the only tinted zone
#   metal   worn structural gunmetal: legs, barrels, frames
#   rust    oxidised, ground-contact and heat-stained surfaces: feet, toes
#   dark    recesses and exposed mechanism: pistons, bolts, vents, rails
#   tread   rubber and grip, near-black, never shiny
#   hazard  warning ochre -- reserved for "this will hurt you", nothing else
#   glow_*  emissive. `glow_visor` plus one per damage type for the core lens.

ZONE_COLOURS = {
    "paint":          "8a8f96",
    "metal":          "6b6259",
    "rust":           "8c4a26",
    "dark":           "2b2b30",
    "tread":          "1b1a19",
    "hazard":         "d9a02b",
    # Terrain zones. Shared with `make_terrain.py` so the battlefield and the machines
    # standing on it are described by one vocabulary.
    "rock":           "342d24",
    "scrapmetal":     "4a4036",
    "slag_crust":     "1a0c07",
    "slag_molten":    "ff5410",
    "glow_visor":     "ffb24a",
    ## Arena floodlamps. The diegetic source of the battlefield's sodium key light --
    ## the yard is lit warm because there are lamps in it, not because a shader says so.
    "glow_lamp":      "ffd79a",
    "glow_kinetic":   "dbd6c9",
    "glow_thermal":   "ff6b23",
    "glow_emp":       "42c2ff",
    "glow_corrosive": "8fdb38",
}


def srgb(hex_string):
    """Blender's Base Color is linear; the palette is authored in sRGB hex so it can be
    read against the same values the game and the UI use. Converting here keeps one
    source of truth instead of two lists of numbers that quietly drift apart."""
    out = []
    for i in (0, 2, 4):
        channel = int(hex_string[i:i + 2], 16) / 255.0
        out.append(channel / 12.92 if channel <= 0.04045
                   else ((channel + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def zone_material(zone):
    """The material for a zone, created once and shared. Named `mat_<zone>` because that
    string is the contract with the runtime palette."""
    name = f"mat_{zone}"
    existing = bpy.data.materials.get(name)
    if existing:
        return existing
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        rgb = srgb(ZONE_COLOURS.get(zone, ZONE_COLOURS["metal"]))
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.85 if zone == "rust" else 0.5
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = 0.0 if zone.startswith("glow") else 0.8
        if zone.startswith("glow") and "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = (*rgb, 1.0)
            bsdf.inputs["Emission Strength"].default_value = 2.0
    return material


def flat_material(name, rgb):
    """Fallback for anything that still wants a one-off colour."""
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.65
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = 0.25
    return material


def apply_material(obj, material):
    obj.data.materials.clear()
    obj.data.materials.append(material)


def triangle_count(obj):
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    bmesh.ops.triangulate(mesh, faces=mesh.faces)
    count = len(mesh.faces)
    mesh.free()
    return count


# --- Detail vocabulary -------------------------------------------------------
#
# A small, shared set of motifs. Coherence comes from every part being built out of the
# SAME handful of shapes -- panel, rib, bolt, piston, vent -- rather than from each part
# being individually interesting. This is the whole reason twenty procedural parts can
# read as one machine family.

def panel(name, size, location, depth=0.022, bevel=0.008, segments=1, zone="paint"):
    """A raised plate. Breaks a flat face into read-able surfaces and catches the key
    light along its edge. Painted by default -- plates are where livery goes."""
    return box(name, (size[0], depth, size[1]), location, bevel=bevel, segments=segments,
               zone=zone)


def rib(name, length, location, thickness=0.035, height=0.05, axis="x", zone="metal"):
    """A structural rib. Reads as welded-on reinforcement -- the single most useful
    motif for making something look salvaged rather than manufactured. Bare metal,
    because a weld that has been painted over stops reading as a repair."""
    size = (length, thickness, height) if axis == "x" else (thickness, length, height)
    return box(name, size, location, bevel=0.008, segments=1, zone=zone)


def bolt(name, location, radius=0.022, depth=0.03, axis="y", zone="dark"):
    rotation = (math.radians(90), 0, 0) if axis == "y" else (0, math.radians(90), 0)
    return cylinder(name, radius, depth, location, vertices=6, rotation=rotation, zone=zone)


def piston(name, length, location, radius=0.028, axis="z", zone="dark"):
    """Exposed hydraulics at a joint. Machines that show their actuators read as
    machines; sealed boxes read as props."""
    rotation = (0, 0, 0) if axis == "z" else (math.radians(90), 0, 0)
    return cylinder(name, radius, length, location, vertices=8, rotation=rotation, zone=zone)


def vent_stack(prefix, count, location, width=0.20, spacing=0.055, thickness=0.022,
               zone="dark"):
    """Louvres. The universal 'this thing runs hot' signal, and this game is about heat."""
    out = []
    for i in range(count):
        out.append(box(f"{prefix}_{i}", (width, 0.05, thickness),
                       (location[0], location[1], location[2] + i * spacing),
                       bevel=0.006, segments=1, zone=zone))
    return out


def bolt_row(prefix, count, start, step, axis="y", zone="dark"):
    return [bolt(f"{prefix}_{i}", (start[0] + step[0] * i, start[1] + step[1] * i,
                                   start[2] + step[2] * i), axis=axis, zone=zone)
            for i in range(count)]


# --- Structural vocabulary ---------------------------------------------------
#
# THE RULE: a construct is described by its JOINTS, and every piece of structure is
# generated to span between two of them.
#
# The parts used to be a list of boxes at hand-written coordinates. Nothing guaranteed
# that a thigh reached its knee or that a weapon reached its mount, and it showed --
# the constructs read as a pile of primitives hanging in roughly the right places
# rather than as machines. Offsets cannot be tuned into correctness one at a time;
# connection has to be structural, so `strut` takes two points and always joins them,
# and every joint gets a `hub` wider than the members meeting there to swallow the seam.

def strut(name, start, end, thickness, zone="metal", shape="box", overlap=0.03,
          bevel=0.012):
    """A structural member spanning exactly from `start` to `end`.

    Both ends are extended by `overlap` so the member sinks INTO whatever it meets
    rather than stopping flush against it. Flush is what produces a hairline gap the
    moment anything is scaled, and a hairline gap at joint after joint is precisely
    what makes a model read as disassembled."""
    a = Vector(start)
    b = Vector(end)
    direction = b - a
    length = direction.length
    if length < 1e-5:
        return None

    midpoint = (a + b) * 0.5
    span = length + overlap * 2.0
    if shape == "cylinder":
        obj = cylinder(name, thickness * 0.5, span, tuple(midpoint), vertices=8, zone=zone)
    else:
        obj = box(name, (thickness, thickness, span), tuple(midpoint), bevel=bevel,
                  segments=1, zone=zone)

    # Point the member's local +Z down the span. The rotation is left unapplied because
    # `join` bakes every object's transform into the merged mesh anyway.
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    return obj


def hub(name, point, radius, zone="dark", axis="x"):
    """The pivot at a joint. Always wider than the struts meeting there, so it reads as
    an articulated knee or shoulder AND hides the seam where the two members overlap."""
    rotation = (0, math.radians(90), 0) if axis == "x" else (math.radians(90), 0, 0)
    return cylinder(name, radius, radius * 1.55, point, vertices=10, rotation=rotation,
                    zone=zone)


def hose(prefix, start, end, rng, thickness=0.022, sag=0.06, zone="dark"):
    """A cable or hydraulic line slung between two points, in three segments with a sag.

    Loose lines are the single most effective 'this was rebuilt by hand' cue available:
    a manufactured machine routes its cabling inside the chassis, and a salvaged one
    cannot. They also visually TIE separate masses together, which is why a construct
    with them reads as one object and the same construct without them reads as parts."""
    a = Vector(start)
    b = Vector(end)
    drop = Vector((0, 0, -sag))
    mid_a = a.lerp(b, 0.33) + drop * rng.uniform(0.7, 1.15)
    mid_b = a.lerp(b, 0.66) + drop * rng.uniform(0.7, 1.15)
    pieces = []
    for index, (p0, p1) in enumerate(((a, mid_a), (mid_a, mid_b), (mid_b, b))):
        segment = strut(f"{prefix}_{index}", tuple(p0), tuple(p1), thickness,
                        zone=zone, shape="cylinder", overlap=thickness * 0.5)
        if segment is not None:
            pieces.append(segment)
    return pieces


def patch(name, size, location, rng, zone="rust", thickness=0.022):
    """A plate welded on at a careless angle.

    Every construct is supposed to have been dug out of a heap and made to walk again.
    Perfectly aligned panels say factory; a plate tacked on 6 degrees out of true, over
    a seam, says field repair -- and it costs four triangles."""
    plate = box(name, (size[0], thickness, size[1]), location, bevel=0.006, segments=1,
                zone=zone)
    plate.rotation_euler = (
        math.radians(rng.uniform(-7.0, 7.0)),
        math.radians(rng.uniform(-7.0, 7.0)),
        math.radians(rng.uniform(-9.0, 9.0)))
    return plate


def weld_seam(prefix, start, end, rng, count=5, size=0.026, zone="rust"):
    """A run of weld blobs along a seam.

    NOT CURRENTLY USED, and kept only as a warning. A weld is the clearest "a person
    joined these two things by hand" cue there is -- but only while it is touching both
    things it claims to join, and this places blobs at coordinates computed by hand
    against surfaces whose real positions are derived from half a dozen other terms.
    Every attempt to aim it left orange dots hanging in the air around the construct,
    which looks far worse than no weld at all.

    Anything using it must first be able to ASK the mesh where its surface is (a raycast
    onto the joined body, or seam points returned by the builders themselves). Placing
    it by guesswork does not work; three rounds of tuning confirmed that."""
    a = Vector(start)
    b = Vector(end)
    pieces = []
    for index in range(count):
        t = (index + 0.5) / count
        point = a.lerp(b, t)
        jitter = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)))
        point = point + jitter * size * 0.35
        blob = cylinder(f"{prefix}_{index}", size * rng.uniform(0.7, 1.15), size * 0.7,
                        tuple(point), vertices=6,
                        rotation=(math.radians(90), 0, rng.uniform(0, 3.14)), zone=zone)
        pieces.append(blob)
    return pieces


def drum(name, location, radius=0.14, height=0.34, zone="rust", axis="z"):
    """A salvaged barrel, with the two rolling hoops that make it read as one.

    This is the single most legible piece of scrap there is: nobody manufactures a war
    machine with an oil drum in it, so a drum says SALVAGED louder than any amount of
    surface grime. The hoops matter -- a bare cylinder is a cylinder."""
    rotation = (0, 0, 0) if axis == "z" else (math.radians(90), 0, 0)
    pieces = [cylinder(name, radius, height, location, vertices=12, rotation=rotation,
                       zone=zone)]
    for offset in (-height * 0.30, height * 0.30):
        hoop_location = (location[0], location[1], location[2] + offset) if axis == "z" \
            else (location[0], location[1] + offset, location[2])
        pieces.append(cylinder(f"{name}_hoop{offset:.2f}", radius * 1.09, height * 0.10,
                               hoop_location, vertices=12, rotation=rotation, zone="dark"))
    return pieces


def girder(name, start, end, rng, web=0.05, flange=0.14, zone="metal"):
    """A structural I-beam, cut from something bigger and bolted in as a brace.

    Two flanges and a web rather than a plain bar, because the profile is what makes it
    read as reclaimed building steel instead of as a machined strut."""
    a = Vector(start)
    b = Vector(end)
    direction = b - a
    if direction.length < 1e-5:
        return []
    pieces = [strut(f"{name}_web", start, end, web, zone=zone)]
    # Flanges offset perpendicular to the span.
    normal = direction.normalized().cross(Vector((0, 0, 1)))
    if normal.length < 1e-4:
        normal = Vector((1, 0, 0))
    normal = normal.normalized() * flange * 0.5
    for sign in (-1, 1):
        offset = normal * sign
        plate = strut(f"{name}_flange{sign}", tuple(a + offset), tuple(b + offset),
                      web * 0.7, zone=zone)
        if plate is not None:
            plate.scale = (flange / (web * 0.7), 1.0, 1.0)
            pieces.append(plate)
    _ = rng
    return [p for p in pieces if p is not None]


def part_rng(part_id):
    """A generator seeded by part id.

    Every construct must look hand-repaired, but the SAME construct has to look the
    same on every machine and in every build -- so the scrap is deterministic, not
    random. Regenerating the roster never silently reshuffles what a player owns."""
    return random.Random(sum((i + 1) * ord(c) for i, c in enumerate(part_id)))


# --- Part builders -----------------------------------------------------------
#
# Each returns the root object with sockets parented. Silhouette is the priority:
# a construct has to be identifiable at 200 px on a phone, so the frames differ in
# proportion and stance rather than in surface detail nobody will ever see.

def build_chassis(part_id, part):
    """A salvaged walking frame with four mount points.

    Built from JOINTS, not from coordinates. Every leg is a chain -- hip, knee, ankle,
    toe -- and each segment is a `strut` generated to span two of those points, with a
    `hub` at every joint wide enough to swallow the seam. That is what makes the frame
    one connected machine instead of a stack of boxes standing near each other, which is
    what the hand-placed version produced no matter how its offsets were tuned.

    Silhouette is driven by ROLE, because that is what the player has to read mid-fight:
    a brawler hunches forward on short legs, an anchor is a wide squat wall behind skirt
    armour, a marksman is a tall thin frame on stilts with a sensor mast.

    Character is driven by SCRAP -- mismatched patches tacked on out of true, hydraulic
    lines slung between masses, an asymmetric brace on one side only. Seeded per part id,
    so a Brute Frame is repaired the same way on every machine and in every build.
    """
    role = part.get("role", "line")
    hp = part.get("hp", 600)
    speed = part.get("speed", 100)
    rng = part_rng(part_id)
    bulk = min(1.30, max(0.70, hp / 800.0))
    quick = min(1.30, max(0.78, speed / 100.0))

    # width, depth, torso height, leg height, forward lean.
    #
    # The first three were authored while `box()` silently halved every dimension, so
    # they described a torso twice the size of the one on screen. With `box()` corrected
    # they are halved here to keep the silhouette that was actually tuned -- leg height
    # and lean are POSITIONS, which the halving never touched, so they are unchanged.
    # LEG HEIGHT IS HALVED HERE TOO.
    #
    # When `box()` was corrected, the first three values were halved to preserve the
    # tuned silhouette but leg height was left alone on the reasoning that it is a
    # position, not a box size. That was wrong in effect: the bodies shrank by half and
    # the legs did not, so the whole roster became a small torso on long stick legs --
    # and with struts now spanning their joints properly, those legs read as bare poles.
    # A construct is a heavy machine; the body has to dominate.
    shape = {
        "brawler":  (0.40, 0.33, 0.30, 0.20, 0.10),
        "anchor":   (0.50, 0.36, 0.26, 0.13, 0.00),
        "marksman": (0.26, 0.24, 0.27, 0.34, -0.04),
        "line":     (0.34, 0.29, 0.31, 0.24, 0.03),
    }.get(role, (0.34, 0.29, 0.31, 0.24, 0.03))

    width = shape[0] * bulk
    depth = shape[1] * bulk
    torso_h = shape[2] * bulk
    leg_h = shape[3] * quick
    lean = shape[4]

    hip_z = leg_h + 0.10
    # Sunk onto the pelvis rather than floating 6 cm above it.
    torso_z = hip_z + torso_h / 2 - 0.03
    front_y = -depth / 2 - 0.01 + lean
    back_y = depth / 2 - 0.01
    pieces = []

    # Slimmer than the members they replace, but with a FLOOR. Scaled purely by bulk, a
    # light frame (bulk 0.70) came out with 8 cm limbs -- bare sticks that read as
    # fragile scaffolding rather than as legs, and which visually snapped at every hub.
    thigh_t = max(0.098, 0.122 * bulk)
    shin_t = max(0.082, 0.100 * bulk)

    # --- Legs. Joint positions first, then structure generated to span them.
    #
    # Leg pieces are collected SEPARATELY from the body. Each leg is joined into its own
    # object with its origin on the hip joint, so the runtime can swing it: a construct
    # welded into one mesh cannot walk, and units sliding across the ground on a static
    # model is the loudest "unfinished" cue left in the battle view.
    legs = {-1: [], 1: []}
    hip_points = {}
    for side in (-1, 1):
        x = side * width * 0.30
        # A knee carried forward of the hip is what reads as a leg braced to take
        # weight; a dead-vertical chain reads as a table leg.
        hip_p = (x, 0.0, hip_z - 0.03)
        knee_p = (x + side * 0.012, -0.055 * bulk + lean, hip_z * 0.50)
        ankle_p = (x, 0.025, 0.115)
        toe_p = (x, -0.155 * bulk, 0.04)
        heel_p = (x, 0.115 * bulk, 0.05)

        hip_points[side] = hip_p
        legs[side].append(strut(f"{part_id}_thigh{side}", hip_p, knee_p, thigh_t))
        legs[side].append(strut(f"{part_id}_shin{side}", knee_p, ankle_p, shin_t))
        legs[side].append(strut(f"{part_id}_toe{side}", ankle_p, toe_p, shin_t * 0.92,
                            zone="rust"))
        legs[side].append(strut(f"{part_id}_heel{side}", ankle_p, heel_p, shin_t * 0.78,
                            zone="rust"))

        # Hubs are only fractionally wider than the struts they cap. Oversized they stop
        # reading as joints and start reading as wheels.
        legs[side].append(hub(f"{part_id}_hipjoint{side}", hip_p, thigh_t * 0.60))
        legs[side].append(hub(f"{part_id}_kneejoint{side}", knee_p, thigh_t * 0.56))
        legs[side].append(hub(f"{part_id}_anklejoint{side}", ankle_p, shin_t * 0.58))

        # A flat pad under the toes. Constructs that end in a point look like they are
        # balancing; a sole says the thing has weight and puts it somewhere.
        legs[side].append(box(f"{part_id}_sole{side}",
                          (0.21 * bulk, 0.36 * bulk, 0.045),
                          (x, -0.03 * bulk, 0.028), bevel=0.01, zone="tread"))

        # The actuator spans two REAL points on the leg it drives, so it reads as the
        # thing extending the knee rather than as a pipe floating beside it.
        legs[side].append(strut(f"{part_id}_ram{side}",
                            (x + side * 0.055 * bulk, 0.075 * bulk, hip_z - 0.09),
                            (x + side * 0.015, 0.015, hip_z * 0.42),
                            0.048, zone="dark", shape="cylinder"))

        # Hydraulic line from the torso down to the knee. Lines tie separate masses
        # together -- with them the frame reads as one object, without them as parts.
        legs[side].extend(hose(f"{part_id}_legline{side}",
                           (x * 0.55, depth * 0.26, torso_z - torso_h * 0.34),
                           (knee_p[0], knee_p[1] + 0.04, knee_p[2] + 0.05),
                           rng, thickness=0.020, sag=0.05))

    # --- Pelvis: one member spanning hip to hip, so the legs are joined to each other
    # and not merely both near the torso.
    pieces.append(strut(f"{part_id}_pelvis",
                        (-width * 0.30, 0, hip_z - 0.03), (width * 0.30, 0, hip_z - 0.03),
                        0.185 * bulk, zone="paint"))
    # Bolts sit ON the pelvis front face. At -depth * 0.32 they were hanging in the air a
    # full 10 cm in front of it -- the scattering of loose cubes around every construct's
    # waist was this line.
    pieces.extend(bolt_row(f"{part_id}_hipbolt", 4,
                           (-width * 0.24, -0.095 * bulk, hip_z - 0.03),
                           (width * 0.16, 0, 0)))

    # --- Waist column: pelvis into torso. Without it the torso floats above the hips.
    pieces.append(strut(f"{part_id}_waist", (0, 0, hip_z - 0.02),
                        (0, lean, torso_z - torso_h * 0.40),
                        0.17 * bulk, zone="dark", shape="cylinder"))

    # --- Torso, leaning forward on aggressive frames.
    # NOT rotated. The torso used to be tilted by `lean` while the chest plate, bolt row
    # and scrap patches were all positioned against an UNROTATED front face -- so every
    # frame with a lean had its chest detail hanging off the surface it belonged to.
    # Lean survives as the Y offset, which is what actually reads at gameplay distance.
    pieces.append(box(f"{part_id}_torso", (width, depth, torso_h), (0, lean, torso_z),
                      zone="paint"))

    # Per-role torso massing. One box on every frame meant ten chassis shared a body and
    # only their legs differed -- and legs are the first thing an attachment hides.
    if role == "anchor":
        # A stepped bunker: a second, wider block low down.
        pieces.append(box(f"{part_id}_bastion", (width * 1.12, depth * 0.88, torso_h * 0.36),
                          (0, lean, torso_z - torso_h * 0.28), zone="paint"))
    elif role == "marksman":
        # A narrow spine box carried high, with a counterweight behind it.
        pieces.append(box(f"{part_id}_spinebox", (width * 0.52, depth * 0.72, torso_h * 0.46),
                          (0, lean + depth * 0.20, torso_z + torso_h * 0.34), zone="paint"))
        pieces.append(box(f"{part_id}_counterweight",
                          (width * 0.34, 0.16, torso_h * 0.22),
                          (0, back_y + 0.10, torso_z - torso_h * 0.30), zone="rust"))
    elif role == "brawler":
        # A sloped glacis over the chest: mass carried forward and low.
        pieces.append(box(f"{part_id}_glacis", (width * 0.94, depth * 0.30, torso_h * 0.40),
                          (0, front_y + 0.10, torso_z - torso_h * 0.18), zone="paint"))

    # Chest plate, a rib above it and a bolt row below: three bands instead of a slab.
    pieces.append(panel(f"{part_id}_chest", (width * 0.66, torso_h * 0.46),
                        (0, front_y, torso_z + torso_h * 0.06), depth=0.05))
    pieces.append(rib(f"{part_id}_browrib", width * 0.80,
                      (0, front_y - 0.01, torso_z + torso_h * 0.34)))

    # --- Breaking up the paint.
    #
    # The torso is one large box in team colour, and at gameplay distance a construct was
    # reading as a flat coloured slab with details lost inside it. Paint is the team
    # signal and has to stay, but an unbroken field of it has no form -- these give the
    # key light something to catch across the middle of the body.
    #
    # A dark waist band under the chest, a shoulder yoke across the top, and vertical
    # seam ribs down the flanks. All structural, none of it decoration.
    pieces.append(box(f"{part_id}_waistband", (width * 1.02, depth * 1.02, torso_h * 0.16),
                      (0, lean, torso_z - torso_h * 0.34), zone="dark"))
    pieces.append(box(f"{part_id}_yoke", (width * 0.92, depth * 1.04, torso_h * 0.14),
                      (0, lean, torso_z + torso_h * 0.40), zone="dark"))
    for side in (-1, 1):
        pieces.append(box(f"{part_id}_seam{side}",
                          (0.045, depth * 1.03, torso_h * 0.66),
                          (side * width * 0.46, lean, torso_z), zone="metal"))
        pieces.append(rib(f"{part_id}_flankrib{side}", torso_h * 0.50,
                          (side * width * 0.30, front_y + 0.005, torso_z),
                          axis="y", height=0.035, zone="metal"))
    # Sunk INTO the torso face. `front_y` is already 1 cm proud of it, so at -0.03 the
    # bolts stood 2.5 cm off the chest on every frame -- narrow ones happened to catch
    # the chest plate, wide ones did not, which is why only some reported.
    pieces.extend(bolt_row(f"{part_id}_chestbolt", 3,
                           (-width * 0.18, front_y + 0.012, torso_z - torso_h * 0.24),
                           (width * 0.18, 0, 0)))

    # --- Scrap. Two or three plates tacked over the torso out of true, and one brace
    # on a single side -- asymmetry is what stops a procedural frame reading as stamped.
    # Plates of DIFFERENT sizes at DIFFERENT depths, overlapping each other. Uniform
    # patches at a uniform offset read as texture; mismatched armour that visibly came
    # off other machines reads as salvage, which is the whole fiction.
    plate_z = torso_z - torso_h * 0.30
    for index in range(3):
        plate_w = width * rng.uniform(0.30, 0.58)
        plate_h = torso_h * rng.uniform(0.18, 0.30)
        plate_x = rng.uniform(-width * 0.18, width * 0.18)
        plate_y = front_y - 0.02 - index * 0.014
        pieces.append(patch(f"{part_id}_plate{index}", (plate_w, plate_h),
                            (plate_x, plate_y, plate_z + plate_h * 0.5),
                            rng, thickness=rng.uniform(0.018, 0.032)))
        plate_z += plate_h * rng.uniform(0.75, 0.95)

    # The salvage bolted to the back, and it is DIFFERENT on every frame.
    #
    # An oil drum on all ten chassis was worse than no drum at all: it is the largest,
    # highest-contrast object on the model, so a roster shot showed ten machines with
    # the same silhouette and the same read. Which junk a frame was rebuilt with is the
    # cheapest per-chassis identity available, and it works at gameplay distance where
    # panel detail does not.
    salvage_x = rng.choice((-1, 1)) * width * 0.22
    salvage_z = torso_z - torso_h * 0.10
    salvage = rng.choice(("drum", "crate", "bottles", "coil"))
    if salvage == "drum":
        # Trimmed. At r=0.115 the drum was the largest single object on the construct and
        # in high-contrast rust against team paint, so the eye went to the barrel rather
        # than the machine. Salvage should say what the frame was built from, not BE the
        # frame.
        pieces.extend(drum(f"{part_id}_drum", (salvage_x, back_y + 0.11, salvage_z),
                           radius=0.086 * bulk, height=0.24 * bulk, axis="z"))
    elif salvage == "crate":
        # A stack of ammunition boxes, strapped down.
        for index in range(2):
            pieces.append(box(f"{part_id}_crate{index}",
                              (0.26 * bulk, 0.20 * bulk, 0.14 * bulk),
                              (salvage_x + index * 0.02, back_y + 0.10,
                               salvage_z - 0.07 * bulk + index * 0.15 * bulk),
                              bevel=0.012, zone="rust"))
        pieces.append(strut(f"{part_id}_cratestrap",
                            (salvage_x - 0.15 * bulk, back_y + 0.10, salvage_z),
                            (salvage_x + 0.15 * bulk, back_y + 0.10, salvage_z),
                            0.030, zone="dark", shape="cylinder"))
    elif salvage == "bottles":
        # Pressure cylinders in a rack -- tall and thin, the opposite read to the drum.
        # A rack strap across both bottles, and the pair pulled in against the back.
        # Standing off at +0.11 the outer bottle cleared the torso entirely on narrow
        # frames and hung in space beside it.
        for index in range(2):
            bottle_x = salvage_x + (index - 0.5) * 0.13 * bulk
            pieces.append(cylinder(f"{part_id}_bottle{index}", 0.058 * bulk, 0.38 * bulk,
                                   (bottle_x, back_y + 0.05, salvage_z),
                                   vertices=10, zone="hazard"))
            pieces.append(cylinder(f"{part_id}_bottlecap{index}", 0.030 * bulk, 0.06,
                                   (bottle_x, back_y + 0.05, salvage_z + 0.21 * bulk),
                                   vertices=8, zone="dark"))
        pieces.append(strut(f"{part_id}_bottlestrap",
                            (salvage_x - 0.13 * bulk, back_y + 0.03, salvage_z),
                            (salvage_x + 0.13 * bulk, back_y + 0.03, salvage_z),
                            0.028, zone="dark", shape="cylinder"))
    else:
        # A drum of cable on a spindle.
        pieces.append(cylinder(f"{part_id}_spool", 0.125 * bulk, 0.16 * bulk,
                               (salvage_x, back_y + 0.13, salvage_z), vertices=12,
                               rotation=(0, math.radians(90), 0), zone="dark"))
        for offset in (-0.09, 0.09):
            pieces.append(cylinder(f"{part_id}_spoolrim{offset:.2f}", 0.145 * bulk, 0.03,
                                   (salvage_x + offset * bulk, back_y + 0.13, salvage_z),
                                   vertices=12, rotation=(0, math.radians(90), 0),
                                   zone="rust"))
    brace_side = rng.choice((-1, 1))
    pieces.extend(girder(f"{part_id}_girder",
                         (brace_side * width * 0.44, back_y * 0.55, torso_z + torso_h * 0.34),
                         (-brace_side * width * 0.28, back_y * 0.55, torso_z - torso_h * 0.34),
                         rng, web=0.035, flange=0.10, zone="rust"))

    # --- Back: louvred heat stack. This game is about heat; the frames should show it.
    pieces.extend(vent_stack(f"{part_id}_vent", 3,
                             (0, back_y, torso_z - torso_h * 0.18), width=width * 0.52))
    pieces.append(box(f"{part_id}_spine", (width * 0.20, 0.07, torso_h * 0.86),
                      (0, back_y + 0.02, torso_z)))

    # --- Shoulders: a clavicle member out to the joint, then the pauldron over it. The
    # arm sockets sit ON these joints, so a mounted weapon is attached to structure
    # rather than hovering beside the torso.
    shoulder_z = torso_z + torso_h * 0.22
    armoured_side = rng.choice((-1, 1))
    for side in (-1, 1):
        # The shoulder sits against the torso side, not out on a rod. The long clavicle
        # strut left every pauldron floating a hand's width clear of the body with a thin
        # pipe between -- the arms read as bolted to nothing.
        # The mount sits just clear of the torso. At +0.10+0.13*bulk the arms hung off
        # the ends of long bare rods and every construct in the roster stood in a
        # scarecrow T-pose -- visible from the front, invisible from three-quarters,
        # which is why it survived until the turnaround.
        sx = side * (width / 2 + 0.06 * bulk)
        shoulder_p = (side * (width * 0.5 - 0.02), lean, shoulder_z)
        pieces.append(strut(f"{part_id}_clav{side}",
                            (side * width * 0.20, lean, shoulder_z),
                            shoulder_p, 0.145 * bulk, zone="metal", shape="cylinder"))
        pieces.append(hub(f"{part_id}_shoulderjoint{side}", shoulder_p, 0.105 * bulk))
        pieces.append(strut(f"{part_id}_upperarm{side}", shoulder_p, (sx, lean, shoulder_z),
                            0.115 * bulk, zone="metal", shape="cylinder"))
        # ASYMMETRIC. The heavy side gets a full salvaged pauldron; the other keeps a
        # stripped joint with a strap over it. Nothing rebuilt by hand out of a heap
        # comes out mirror-perfect, and perfect symmetry was reading as manufactured no
        # matter how much rust went on top of it.
        if side == armoured_side:
            pieces.append(box(f"{part_id}_pauldron{side}",
                              (0.30 * bulk, depth * 0.72, torso_h * 0.60),
                              (side * (width / 2 + 0.07), lean, shoulder_z + torso_h * 0.06),
                              zone="paint"))
        else:
            pieces.append(box(f"{part_id}_shoulderplate{side}",
                              (0.20 * bulk, depth * 0.46, torso_h * 0.30),
                              (side * (width / 2 + 0.02), lean, shoulder_z + torso_h * 0.14),
                              zone="rust"))
            pieces.append(strut(f"{part_id}_strap{side}",
                                (side * (width / 2 - 0.06), lean - depth * 0.24,
                                 shoulder_z + torso_h * 0.24),
                                (side * (width / 2 + 0.08), lean + depth * 0.24,
                                 shoulder_z - torso_h * 0.04),
                                0.034, zone="dark", shape="cylinder"))

    # --- Head on a real neck. A marksman gets a mast and dish; everything else a low
    # armoured cowl.
    # Set down onto the shoulders. At +0.09 above the torso the neck was long enough that
    # every frame in the roster read as a giraffe.
    head_z = torso_z + torso_h / 2 + 0.035
    pieces.append(strut(f"{part_id}_neck", (0, lean, torso_z + torso_h * 0.30),
                        (0, -depth * 0.06 + lean, head_z), 0.105 * bulk,
                        zone="dark", shape="cylinder"))
    if role == "marksman":
        pieces.append(strut(f"{part_id}_mast", (0, 0.02, head_z),
                            (0, 0.02, head_z + 0.30), 0.05, zone="dark",
                            shape="cylinder"))
        pieces.append(box(f"{part_id}_dish", (0.24, 0.16, 0.07), (0, -0.02, head_z + 0.29)))
        pieces.append(box(f"{part_id}_dishrim", (0.28, 0.05, 0.11), (0, -0.07, head_z + 0.29)))
    elif role == "anchor":
        # A bunker head: wide, low, and slotted rather than glazed. An anchor is the one
        # frame that never advances, so it reads as something dug in.
        pieces.append(box(f"{part_id}_head", (width * 0.44, depth * 0.40, 0.13),
                          (0, -depth * 0.08 + lean, head_z)))
        pieces.append(box(f"{part_id}_visor", (width * 0.34, 0.05, 0.035),
                          (0, -depth * 0.28 + lean, head_z), zone="glow_visor"))
        for side in (-1, 1):
            pieces.append(box(f"{part_id}_cheek{side}", (0.06, depth * 0.34, 0.16),
                              (side * width * 0.21, -depth * 0.06 + lean, head_z),
                              zone="paint"))
    elif role == "brawler":
        # A blunt wedge with a bar over the optic -- a frame built to walk into things
        # should look like it has been hit.
        pieces.append(box(f"{part_id}_head", (width * 0.34, depth * 0.46, 0.17),
                          (0, -depth * 0.10 + lean, head_z)))
        pieces.append(box(f"{part_id}_visor", (width * 0.24, 0.05, 0.06),
                          (0, -depth * 0.32 + lean, head_z), zone="glow_visor"))
        pieces.append(box(f"{part_id}_grille", (width * 0.30, 0.04, 0.03),
                          (0, -depth * 0.34 + lean, head_z), zone="rust"))
        pieces.append(box(f"{part_id}_crest", (0.06, depth * 0.30, 0.12),
                          (0, -depth * 0.02 + lean, head_z + 0.08), zone="rust"))
    else:
        pieces.append(box(f"{part_id}_head", (width * 0.36, depth * 0.48, 0.15),
                          (0, -depth * 0.10 + lean, head_z)))
        pieces.append(box(f"{part_id}_visor", (width * 0.30, 0.05, 0.05),
                          (0, -depth * 0.32 + lean, head_z + 0.01), zone="glow_visor"))
        pieces.append(box(f"{part_id}_crest", (0.05, depth * 0.42, 0.10),
                          (0, -depth * 0.06 + lean, head_z + 0.06), zone="paint"))

    # --- Anchor skirt: the clearest "this thing holds ground" cue on the field.
    if role == "anchor":
        # Pulled in tight against the hips. At +0.16 the skirt plates hung well clear of
        # the frame on a thin rod and read as two slabs floating beside the construct
        # rather than as armour hung on it.
        # Overlapping the torso outright, not touching it edge-to-edge. At a 1 cm
        # contact the bevels alone opened a visible seam and the plates read as two
        # slabs hanging beside the frame.
        for side in (-1, 1):
            sx = side * (width / 2 - 0.01)
            pieces.append(box(f"{part_id}_skirt{side}",
                              (0.15, depth * 0.86, torso_h * 0.78),
                              (sx, 0, hip_z + 0.04), zone="paint"))
            pieces.append(strut(f"{part_id}_skirtarm{side}",
                                (side * width * 0.24, 0, hip_z + 0.04), (sx, 0, hip_z + 0.04),
                                0.085, zone="metal", shape="cylinder"))

    # --- Brawler ram plate; a frame built to close should look like it.
    if role == "brawler":
        pieces.append(box(f"{part_id}_ramplate", (width * 0.86, 0.07, 0.12),
                          (0, front_y - 0.04, hip_z + 0.10)))
        pieces.extend(bolt_row(f"{part_id}_rambolt", 3,
                               (-width * 0.30, front_y - 0.07, hip_z + 0.10),
                               (width * 0.30, 0, 0)))
        for side in (-1, 1):
            pieces.append(strut(f"{part_id}_rambrace{side}",
                                (side * width * 0.34, front_y - 0.04, hip_z + 0.10),
                                (side * width * 0.24, front_y + 0.16, hip_z - 0.02),
                                0.05, zone="metal", shape="cylinder"))

    root = join([p for p in pieces if p is not None], part_id)

    # Each leg becomes its own child object named `limb_leg_l` / `limb_leg_r`, with its
    # ORIGIN on the hip joint. The runtime looks those names up and rotates them; because
    # the origin is the hip, rotating the object is the hip articulating, and a walk
    # cycle is two sine waves rather than a skinned armature.
    for side in (-1, 1):
        members = [p for p in legs[side] if p is not None]
        if not members:
            continue
        limb = join(members, "limb_leg_l" if side < 0 else "limb_leg_r", recentre=False)
        set_origin(limb, hip_points[side])
        parent_keeping_transform(limb, root)

    socket("socket_core", (0, front_y - 0.02, torso_z + torso_h * 0.06), root)
    socket("socket_arm_l", (-(width / 2 + 0.06 * bulk), lean, shoulder_z), root)
    socket("socket_arm_r", (width / 2 + 0.06 * bulk, lean, shoulder_z), root)
    socket("socket_module", (0, back_y + 0.04, torso_z), root)
    return root


def build_core(part_id, part):
    """Chest-mounted reactor. Damage type drives the lens colour, which is the fastest
    read on the battlefield for what a construct actually does -- so the lens is
    deliberately large and framed by a heavy cowl that catches light around it.

    Only the LENS carries the damage colour. The housing around it stays plain metal:
    when the whole core was tinted, the colour bled across the construct's chest and
    stopped being a signal at all."""
    lens_zone = "glow_" + part.get("damage_type", "kinetic")
    if lens_zone not in ZONE_COLOURS:
        lens_zone = "glow_kinetic"

    pieces = [
        box(f"{part_id}_housing", (0.32, 0.16, 0.32), (0, 0.05, 0)),
        box(f"{part_id}_cowl", (0.38, 0.06, 0.14), (0, -0.02, 0.15)),
        box(f"{part_id}_chin", (0.30, 0.06, 0.09), (0, -0.02, -0.15)),
    ]
    # Bracket arms around the lens: reads as a reactor clamped into a housing rather
    # than a light glued to a box.
    for side in (-1, 1):
        pieces.append(box(f"{part_id}_bracket{side}", (0.06, 0.10, 0.30),
                          (side * 0.15, -0.01, 0), bevel=0.01, segments=1, zone="dark"))
    # A reading light, not a headlamp. At r=0.10 the lens covered most of a construct's
    # chest and, being unshaded and glowing, was the brightest object on the whole
    # battlefield -- a status indicator out-shouting the machine carrying it.
    # Smaller again. In game the lens is the single brightest thing on a construct, so at
    # r=0.055 every frame in the roster read as "a dark box with a big white circle on
    # it" and the chassis behind it stopped registering at all.
    pieces.append(cylinder(f"{part_id}_ring", 0.062, 0.06, (0, -0.05, 0),
                           vertices=12, rotation=(math.radians(90), 0, 0), zone="dark"))
    pieces.append(cylinder(f"{part_id}_lens", 0.038, 0.08, (0, -0.075, 0),
                           vertices=12, rotation=(math.radians(90), 0, 0), zone=lens_zone))
    pieces.extend(bolt_row(f"{part_id}_bolt", 2, (-0.13, -0.04, 0.20), (0.26, 0, 0)))

    # See ATTACH_SCALE: authored against the halving bug, so twice intended size.
    return scale_part(join(pieces, part_id), ATTACH_SCALE)


def build_arm(part_id, part):
    """A weapon on an arm that physically reaches its mount.

    WEAPON CLASS drives the model. Everything used to be one parameterised tube whose
    only variable was length, so ten arms with ten different abilities were, to look at,
    the same stick -- and the earlier attempt to vary them keyed off `damage_type`, which
    arms do not even carry (that lives on the core). `weapon_class` is authored in
    `data/parts/arms.json` beside the ability it fires, so the silhouette and the
    behaviour cannot drift apart, and the same string picks the attack animation.

    The mount is a chain like the legs are: collar at the shoulder socket, forearm strut
    to an elbow hub, weapon built forward from the elbow.
    """
    reach = part.get("range", 300)
    weapon = part.get("weapon_class", "rifle")
    rng = part_rng(part_id)
    # Reach still orders the roster, over a tight range: a lance is visibly longer than
    # a scattergun without becoming an 8:1 stick that vanishes at gameplay distance.
    length = min(0.74, max(0.30, 0.20 + reach / 1700.0))

    elbow = (0.0, -0.17, -0.03)
    pieces = [
        # Painted: the collar is the seam between weapon and frame, and it is what makes
        # a mixed loadout look issued to one machine rather than looted.
        box(f"{part_id}_collar", (0.19, 0.19, 0.21), (0, 0, 0), zone="paint"),
        strut(f"{part_id}_forearm", (0, -0.02, 0), elbow, 0.115, zone="metal",
              shape="cylinder"),
        hub(f"{part_id}_elbow", elbow, 0.082),
    ]

    # --- Contact weapons -----------------------------------------------------
    if weapon in ("hammer", "maul", "ripper", "saw", "lance"):
        haft = 0.115 if weapon != "lance" else 0.085
        head_y = -length - 0.14
        pieces.append(strut(f"{part_id}_haft", elbow, (0.0, head_y, -0.03), haft))

        if weapon == "hammer":
            # A squared-off block on a short haft. Reads as WEIGHT: no edge, no teeth.
            pieces.append(box(f"{part_id}_head", (0.26, 0.24, 0.26),
                              (0, head_y - 0.06, -0.03)))
            pieces.append(box(f"{part_id}_face", (0.29, 0.06, 0.29),
                              (0, head_y - 0.17, -0.03), zone="rust"))
            pieces.extend(bolt_row(f"{part_id}_headbolt", 2, (-0.09, head_y - 0.06, 0.09),
                                   (0.18, 0, 0)))
        elif weapon == "maul":
            # The hammer's bigger cousin: a spiked drum, back-weighted.
            pieces.append(cylinder(f"{part_id}_head", 0.17, 0.30, (0, head_y - 0.04, -0.03),
                                   vertices=10, rotation=(0, math.radians(90), 0)))
            for index in range(4):
                angle = math.tau * index / 4
                pieces.append(box(f"{part_id}_spike{index}", (0.06, 0.13, 0.06),
                                  (math.cos(angle) * 0.16, head_y - 0.04,
                                   -0.03 + math.sin(angle) * 0.16), zone="rust"))
            pieces.append(cylinder(f"{part_id}_pommel", 0.07, 0.10, (0, -0.30, -0.03),
                                   vertices=8, rotation=(math.radians(90), 0, 0)))
        elif weapon == "ripper":
            # Three forward talons on a splayed hand. The only arm with a gap in its
            # silhouette, which is what makes it readable at a glance.
            for index, offset in enumerate((-0.11, 0.0, 0.11)):
                claw_base = (offset, head_y + 0.04, -0.03)
                claw_tip = (offset * 1.7, head_y - 0.22, -0.03 - abs(offset) * 0.35)
                pieces.append(strut(f"{part_id}_claw{index}", claw_base, claw_tip, 0.055,
                                    zone="rust"))
            pieces.append(box(f"{part_id}_knuckle", (0.28, 0.12, 0.16),
                              (0, head_y + 0.06, -0.03)))
        elif weapon == "saw":
            # A disc. Nothing else in the roster is a circle side-on.
            pieces.append(cylinder(f"{part_id}_disc", 0.26, 0.045,
                                   (0.02, head_y - 0.06, -0.03), vertices=16,
                                   rotation=(0, math.radians(90), 0), zone="dark"))
            for index in range(8):
                angle = math.tau * index / 8
                pieces.append(box(f"{part_id}_tooth{index}", (0.035, 0.07, 0.035),
                                  (0.02, head_y - 0.06 + math.cos(angle) * 0.26,
                                   -0.03 + math.sin(angle) * 0.26), zone="rust"))
            pieces.append(box(f"{part_id}_guard", (0.10, 0.20, 0.24),
                              (-0.10, head_y - 0.02, -0.03), zone="paint"))
            pieces.append(cylinder(f"{part_id}_motor", 0.085, 0.16, (-0.14, -0.34, -0.03),
                                   vertices=10, rotation=(0, math.radians(90), 0)))
        else:
            # Lance: a long tapered spike with a hand guard. Thrust, not swing.
            pieces.append(strut(f"{part_id}_shaft", (0.0, -0.30, -0.03),
                                (0.0, head_y - 0.34, -0.03), 0.075, zone="metal"))
            pieces.append(strut(f"{part_id}_tip", (0.0, head_y - 0.34, -0.03),
                                (0.0, head_y - 0.52, -0.03), 0.038, zone="rust"))
            pieces.append(cylinder(f"{part_id}_vamplate", 0.15, 0.05, (0, -0.28, -0.03),
                                   vertices=10, rotation=(math.radians(90), 0, 0),
                                   zone="paint"))

    # --- Ranged weapons ------------------------------------------------------
    else:
        receiver_p = (0.0, -0.30, -0.03)
        pieces.append(box(f"{part_id}_receiver", (0.22, 0.30, 0.22), receiver_p))
        # A belt back to the collar: ties the weapon to the arm, and is the clearest
        # "fed by hand, rebuilt in a yard" cue on the model.
        pieces.extend(hose(f"{part_id}_belt", (0.0, -0.02, -0.09),
                           (0.0, -0.26, -0.12), rng, thickness=0.026, sag=0.05))

        if weapon == "scattergun":
            # Short, fat, twin-barrelled. Reads as CLOSE RANGE from across the map.
            for side in (-1, 1):
                pieces.append(strut(f"{part_id}_barrel{side}", receiver_p,
                                    (side * 0.06, -length - 0.30, -0.03), 0.105,
                                    zone="dark", shape="cylinder"))
            pieces.append(box(f"{part_id}_shroud", (0.28, 0.20, 0.20),
                              (0, -length - 0.22, -0.03), zone="rust"))
            pieces.append(cylinder(f"{part_id}_shells", 0.09, 0.22, (0, -0.30, -0.16),
                                   vertices=10, rotation=(0, math.radians(90), 0)))
        elif weapon == "coil":
            # Induction rings down an open rail. Big enough to be seen against the
            # barrel -- at 1.25x thickness they were swallowed by it.
            pieces.append(strut(f"{part_id}_rail", receiver_p,
                                (0.0, -length - 0.34, -0.03), 0.075, zone="dark",
                                shape="cylinder"))
            for index in range(4):
                pieces.append(cylinder(f"{part_id}_coil{index}", 0.155, 0.055,
                                       (0, -0.46 - index * 0.13, -0.03), vertices=12,
                                       rotation=(math.radians(90), 0, 0), zone="dark"))
            pieces.append(cylinder(f"{part_id}_arc", 0.10, 0.10,
                                   (0, -length - 0.34, -0.03), vertices=10,
                                   rotation=(math.radians(90), 0, 0), zone="glow_emp"))
        elif weapon == "mortar":
            # A short fat tube angled UP. The only weapon in the roster that is not
            # pointed at the enemy, which says "this one lobs" without a tooltip.
            muzzle = (0.0, -length - 0.10, 0.20)
            pieces.append(strut(f"{part_id}_tube", (0.0, -0.28, -0.06), muzzle, 0.20,
                                zone="dark", shape="cylinder"))
            pieces.append(cylinder(f"{part_id}_mouth", 0.125, 0.07, muzzle, vertices=12,
                                   rotation=(math.radians(60), 0, 0), zone="rust"))
            pieces.append(strut(f"{part_id}_prop", (0.0, -0.30, -0.10),
                                (0.0, -0.16, -0.24), 0.05, zone="metal",
                                shape="cylinder"))
            pieces.append(cylinder(f"{part_id}_shellrack", 0.075, 0.24, (0.14, -0.26, -0.14),
                                   vertices=10, rotation=(0, math.radians(90), 0),
                                   zone="hazard"))
        elif weapon == "railgun":
            # Longest in the roster, with a bipod and a capacitor block: unmistakably a
            # weapon set up to shoot from where it is standing.
            pieces.append(strut(f"{part_id}_rail", receiver_p,
                                (0.0, -length - 0.42, -0.03), 0.085, zone="dark"))
            pieces.append(box(f"{part_id}_capacitor", (0.24, 0.26, 0.16),
                              (0, -0.34, 0.13), zone="paint"))
            pieces.append(box(f"{part_id}_muzzle", (0.16, 0.14, 0.16),
                              (0, -length - 0.44, -0.03), zone="rust"))
            for side in (-1, 1):
                pieces.append(strut(f"{part_id}_bipod{side}",
                                    (0.0, -length * 0.85, -0.05),
                                    (side * 0.13, -length * 0.95, -0.24), 0.034,
                                    zone="dark", shape="cylinder"))
        elif weapon == "scanner":
            # Not a gun at all: a dish and an optic on a mast. It marks, it does not
            # shoot, and it should be obvious which construct is the spotter.
            pieces.append(strut(f"{part_id}_mast", receiver_p, (0.0, -0.40, 0.26), 0.06,
                                zone="metal", shape="cylinder"))
            pieces.append(cylinder(f"{part_id}_dish", 0.21, 0.05, (0, -0.44, 0.30),
                                   vertices=14, rotation=(math.radians(72), 0, 0),
                                   zone="paint"))
            pieces.append(cylinder(f"{part_id}_optic", 0.075, 0.16, (0, -0.50, 0.30),
                                   vertices=10, rotation=(math.radians(72), 0, 0),
                                   zone="glow_visor"))
            pieces.append(box(f"{part_id}_computer", (0.20, 0.18, 0.14),
                              (0, -0.22, -0.14), zone="paint"))
        else:
            # Plain rifle: drum magazine and a heavy brake.
            pieces.append(strut(f"{part_id}_barrel", receiver_p,
                                (0.0, -length - 0.34, -0.03), 0.115, zone="dark",
                                shape="cylinder"))
            pieces.append(cylinder(f"{part_id}_drum", 0.115, 0.14, (0, -0.34, -0.15),
                                   vertices=12, rotation=(0, math.radians(90), 0)))
            pieces.append(box(f"{part_id}_brake", (0.19, 0.12, 0.19),
                              (0, -length - 0.36, -0.03), zone="dark"))

    # One scrap patch over the mount seam, on every weapon in the roster.
    pieces.append(patch(f"{part_id}_patch", (0.20, 0.14), (0.08, -0.22, -0.03), rng,
                        thickness=0.018))

    arm = join([p for p in pieces if p is not None], part_id)

    # Every dimension in this builder was authored while `box()` halved its input, so
    # with `box()` corrected the whole weapon doubled and dwarfed the chassis carrying
    # it. Scaling the finished arm restores the tuned silhouette in one place, rather
    # than reworking forty literals and reintroducing the same class of mistake.
    return scale_part(arm, ARM_SCALE)


def build_module(part_id, part):
    """Back-mounted auxiliary. Overdrive modules are visibly a hazard -- finned, vented
    and capped -- because a player should be able to see which constructs explode before
    one does."""
    pieces = [
        box(f"{part_id}_case", (0.36, 0.20, 0.30), (0, 0.10, 0), zone="paint"),
        box(f"{part_id}_lip", (0.40, 0.05, 0.07), (0, 0.02, 0.15)),
    ]
    pieces.extend(bolt_row(f"{part_id}_bolt", 2, (-0.14, 0.02, -0.10), (0.28, 0, 0)))

    if part.get("can_overdrive", False):
        # Hazard ochre on the fins and a live cap on the vent. `hazard` is reserved for
        # exactly this across the whole game -- if the warning colour also showed up as
        # decoration, it would stop meaning "this one explodes".
        for i in range(4):
            pieces.append(box(f"{part_id}_fin{i}", (0.34, 0.05, 0.03),
                              (0, 0.22, -0.10 + i * 0.07), bevel=0.006, segments=1,
                              zone="hazard"))
        pieces.append(cylinder(f"{part_id}_cap", 0.07, 0.10, (0, 0.24, 0),
                               vertices=8, rotation=(math.radians(90), 0, 0),
                               zone="glow_thermal"))
    else:
        # A plain module gets a heat fin and a coolant line instead.
        pieces.append(box(f"{part_id}_fin", (0.07, 0.24, 0.22), (0, 0.12, 0.02)))
        pieces.append(piston(f"{part_id}_line", 0.26, (0.13, 0.12, -0.04),
                             radius=0.022, axis="y"))

    # See ATTACH_SCALE. Unscaled, the module case came out wider than the torso it bolts
    # to and became the largest, bluest object on every construct in the roster.
    return scale_part(join(pieces, part_id), ATTACH_SCALE)


BUILDERS = {
    "chassis": build_chassis,
    "core": build_core,
    "arm": build_arm,
    "module": build_module,
}


# --- Pipeline ----------------------------------------------------------------

def load_parts(project_root):
    parts = {}
    parts_dir = os.path.join(project_root, "data", "parts")
    for name in sorted(os.listdir(parts_dir)):
        if not name.endswith(".json"):
            continue
        with open(os.path.join(parts_dir, name)) as handle:
            for entry in json.load(handle):
                parts[entry["id"]] = entry
    return parts


def export_glb(obj, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    for child in obj.children:
        child.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )


def render_preview(obj, path):
    """A three-quarter render, for eyeballing a part without opening Blender.

    This is the feedback loop that matters. Parts were tuned for a long time against the
    in-game screenshot, where a construct is 80 px tall in a dark scene -- at that size a
    detached shoulder or a floating cap is invisible, and every one of them shipped. A
    lit 720 px render of one part shows those in a second.

    Lighting here is deliberately NEUTRAL and bright, not the game's Rust & Sodium rig:
    the job is to inspect geometry, and a moody key hides exactly the seams being
    hunted for."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT" if hasattr(bpy.types, "SceneEEVEE") else "BLENDER_EEVEE"
    scene.render.resolution_x = 720
    scene.render.resolution_y = 720
    scene.render.filepath = path
    scene.render.film_transparent = False

    # Frame the part from its actual bounds, so a 1.6 m chassis and a 0.3 m module are
    # both filled to the frame instead of one being a speck.
    lowest = min((obj.matrix_world @ Vector(corner)).z for corner in obj.bound_box)
    highest = max((obj.matrix_world @ Vector(corner)).z for corner in obj.bound_box)
    height = max(0.4, highest - lowest)
    centre = (lowest + highest) * 0.5
    distance = height * 2.5

    bpy.ops.object.camera_add(
        location=(distance * 0.72, -distance * 0.86, centre + height * 0.42),
        rotation=(math.radians(74), 0, math.radians(40)))
    scene.camera = bpy.context.active_object
    scene.camera.data.lens = 55

    # Three-point: key, fill from the opposite side, and a rim to separate the
    # silhouette from the background.
    for location, energy, size in (((3, -3, 5), 5.0, 2.0), ((-4, -2, 2), 2.0, 3.0),
                                   ((0, 4, 3), 3.0, 2.0)):
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.active_object
        light.data.energy = energy * 40
        light.data.size = size
        constraint = light.constraints.new("TRACK_TO")
        constraint.target = obj

    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.16, 0.17, 0.19, 1)
    bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_dir = "art/parts"
    only = None
    do_render = False
    for i, arg in enumerate(argv):
        if arg == "--out" and i + 1 < len(argv):
            out_dir = argv[i + 1]
        elif arg == "--only" and i + 1 < len(argv):
            only = argv[i + 1]
        elif arg == "--render":
            do_render = True

    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    parts = load_parts(project_root)

    built = 0
    over_budget = []
    for part_id, part in sorted(parts.items()):
        if only and part_id != only:
            continue
        builder = BUILDERS.get(part.get("slot"))
        if builder is None:
            print(f"  skip {part_id}: unknown slot {part.get('slot')!r}")
            continue

        clear_scene()
        obj = builder(part_id, part)
        if not obj.data.materials:
            apply_material(obj, zone_material("metal"))

        tris = triangle_count(obj)
        if tris > TRI_BUDGET:
            over_budget.append((part_id, tris))

        glb_path = os.path.join(project_root, out_dir, f"{part_id}.glb")
        export_glb(obj, glb_path)
        if do_render:
            render_preview(obj, os.path.join(project_root, "art", "preview", f"{part_id}.png"))

        print(f"  {part_id:16s} {part.get('slot'):8s} {tris:5d} tris  -> {out_dir}/{part_id}.glb")
        built += 1

    print(f"\nbuilt {built} parts into {out_dir}")
    if over_budget:
        print(f"OVER BUDGET ({TRI_BUDGET} tris): " + ", ".join(f"{i}={t}" for i, t in over_budget))


if __name__ == "__main__":
    main()
