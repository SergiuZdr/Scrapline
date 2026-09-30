"""Ink-first parts (017, route A): machines drawn for the Ink & Rust look, led by concept art.

    blender --background --python tools/blender/make_ink_parts.py -- --out art/parts_new
    $GODOT --headless --path . --script res://tools/verify_assembly.gd -- --dir res://art/parts_new

The proof of route A in `docs/plans/models.md`: the Brute's four parts (chassis, Rend Saw,
Breaker Hammer, Slug core), built from the concept sheet (`art/concepts/brute.png`) rather
than from the scrap generator's greeble library. Exported into their own folder; the roster
in `art/parts/` is not touched (CLAUDE.md: the generator no longer reproduces it).

## What "ink-first" means for a mesh

Every mesh in the game gets an ink line at a constant screen width and a three-band toon
ramp. Both punish what the scrap generator is good at:

* A bolt, a cable or a vent slot becomes a black speck -- its outline is wider than it is.
  So: few pieces, each big enough to carry a line around it (a 3 cm bolt is the floor).
* A band is decided by a face's ANGLE to the key. Bevelled into many small facets, a box
  shades as noise; chamfered once, the chamfer is a clean highlight band. So: one-segment
  chamfers, flat faces, and smooth shading only on round things.
* A machine is read by its colour FAMILIES at 40 px: livery shell (paint), structure
  (metal, which the game tints toward the livery), mechanism (dark), one light value
  (alu), ground contact (rust), and the eye (the team). Each piece is one of those.

## What it keeps

The whole export contract, by calling the bridge's own helpers (`make_scrap_parts`): the
generator's frame (+Y forward, turned 180 degrees on the way out), `SCALE`, the role
proportion, the socket formulas, legs as `limb_leg_l/r` with their origin on the hip,
attachments with their mount at the origin, materials renamed to `mat_<zone>`. A new
part fits every old part, and every old part fits it.
"""

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

import make_scrap_parts as msp  # noqa: E402  (reloads scrapgen; take its modules from it)

config = msp.config
materials = msp.materials
prim = msp.prim

# The palette names, by the zone each exports as (`materials.ZONE_OF`).
PAINT = "DirtyMetal"   # paint: the part's livery
METAL = "OldSteel"     # metal: structure, tinted toward the livery in game
DARK = "DarkMetal"     # dark: joints, recesses, mechanism
RUST = "RustyMetal"    # rust: ground contact
ALU = "Aluminium"      # alu: the one light value
EYE = "Glass"          # glow_visor: the eye, lit in the team's colour

# Two zones the shipped roster never had (018): the user wanted several colours in every part.
STEEL = "zone:steel"   # neutral grey structure: joints, frames, hafts (NOT tinted by the livery)
TRIM = "zone:trim"     # the livery's accent colour: bands, toe caps, caps
ZONE_HEX = {"steel": "7d848c", "trim": "c8602a"}

## How round a box's edges are, as a fraction of its smallest side (018). The user on 017: "the
## concept has a lot of rounded sides, the game's looked like a Lego character with very blocky
## parts". Three segments, shaded smooth, with the flat faces kept flat by weighted normals.
ROUND = 0.30


# --- Pieces ------------------------------------------------------------------

def bake(obj):
    """Applies location, rotation and scale, so every piece shares the world origin.

    `prim.join` gives the joined mesh the FIRST piece's transform (CLAUDE.md: piece order
    decides the whole component's transform). With every piece baked, the joined part's
    origin is the frame's origin -- the hip, the shoulder, the mount -- whatever the order."""
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def colour(obj, material):
    if material.startswith("zone:"):
        zone = material[5:]
        obj.data.materials.clear()
        obj.data.materials.append(msp.zone_material(zone, ZONE_HEX[zone]))
    else:
        materials.apply(obj, material)
    return obj


def soften(obj, angle=40.0):
    """Round things shade smooth, their caps stay sharp: the toon ramp bands a smooth drum
    the way an inker shades a cylinder, and a 16-facet drum would band as stripes."""
    obj.data.shade_smooth()
    obj.data.set_sharp_from_angle(angle=math.radians(angle))
    return obj


def block(name, size, at, material, rot=(0.0, 0.0, 0.0), taper=None, chamfer=ROUND):
    """A ROUNDED box: the workhorse. `chamfer` is the corner radius over the smallest side."""
    if taper is None:
        obj = prim.box(name, size, location=at, rotation=rot, material="OldSteel", bevel_width=0.0)
    else:
        obj = prim.taper_box(name, size, top_scale=taper, location=at, rotation=rot,
                             material="OldSteel", bevel_width=0.0)
    bake(obj)
    bevel = obj.modifiers.new("round", "BEVEL")
    bevel.width = min(size) * chamfer
    bevel.segments = 3
    bevel.limit_method = "ANGLE"
    bevel.angle_limit = math.radians(40.0)
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    obj.data.shade_smooth()
    weighted = obj.modifiers.new("flat_faces", "WEIGHTED_NORMAL")
    weighted.keep_sharp = False
    weighted.weight = 100
    bpy.ops.object.modifier_apply(modifier=weighted.name)
    return colour(obj, material)


AXIS = {"x": (0.0, math.pi / 2, 0.0), "y": (math.pi / 2, 0.0, 0.0), "z": (0.0, 0.0, 0.0)}


def drum(name, radius, depth, at, material, axis="z", sides=16):
    obj = prim.cylinder(name, radius, depth, location=at, rotation=AXIS[axis],
                        vertices=sides, material="OldSteel")
    return colour(soften(bake(obj)), material)


def ball(name, radius, at, material, squash=1.0):
    """A sphere (a dome when half of it is sunk in something): heads, bolts, antenna tips."""
    obj = prim.sphere(name, radius, location=at, segments=12, rings=6, material="OldSteel")
    obj.scale = (1.0, 1.0, squash)
    bake(obj)
    obj.data.shade_smooth()
    return colour(obj, material)


def bolts(name, points, material=STEEL, radius=0.026):
    """Round bolt heads, half sunk: the concept is studded with them, and at 2.6 cm (1.1 cm in
    the game) each is big enough to take a line in the garage."""
    return [ball("%s_%d" % (name, i), radius, p, material, 0.7) for i, p in enumerate(points)]


def plate_x(name, outline, depth, x, material):
    """A flat plate in the YZ plane, `depth` thick along X: a saw blade, a guard.

    `outline` is (y, z) points around a centre it is star-shaped about, fanned from that
    centre -- a toothed blade is concave, and a fan from its hub is the one triangulation
    of it that is always right."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    cy = sum(p[0] for p in outline) / len(outline)
    cz = sum(p[1] for p in outline) / len(outline)
    half = depth * 0.5
    sides = []
    for sx in (-half, half):
        centre = bm.verts.new((x + sx, cy, cz))
        ring = [bm.verts.new((x + sx, y, z)) for y, z in outline]
        sides.append((centre, ring))
    count = len(outline)
    for side, (centre, ring) in enumerate(sides):
        for i in range(count):
            a, b = ring[i], ring[(i + 1) % count]
            bm.faces.new((centre, a, b) if side else (centre, b, a))
    back, front = sides[0][1], sides[1][1]
    for i in range(count):
        j = (i + 1) % count
        bm.faces.new((back[i], back[j], front[j], front[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return colour(obj, material)


def along(a, b):
    """(centre, length, x-rotation) of a box laid from `a` to `b` in the YZ plane."""
    dy, dz = b[1] - a[1], b[2] - a[2]
    centre = tuple((a[i] + b[i]) * 0.5 for i in range(3))
    # +theta about X tips -Z toward +Y.
    return centre, math.hypot(dy, dz), math.atan2(dy, -dz)


# --- The Brute ---------------------------------------------------------------
#
# Read off the concept sheet (art/concepts/brute.png), second pass (018): ROUNDED plates, a
# domed head with a hooded lens, ears and antennae; a bolted chest plate (the core); huge
# rounded pauldrons with a trim band; thick arms; heavy two-tone legs with knee pads, shin
# plates and big boots; and several colours in every part -- livery plates, steel structure,
# trim accents, dark recesses, one light value. Generator units throughout.

def brute_body(part_id):
    n = part_id
    sz = config.TORSO_SHOULDER_Z
    pieces = [
        block(n + "_chest", (0.66, 0.50, 0.58), (0.0, 0.0, 0.48), PAINT, taper=(1.08, 1.0), chamfer=0.22),
        block(n + "_bezel", (0.46, 0.06, 0.40), (0.0, 0.245, 0.47), STEEL),
        block(n + "_belt", (0.56, 0.46, 0.08), (0.0, 0.0, 0.20), STEEL),
        block(n + "_brow", (0.50, 0.10, 0.07), (0.0, 0.22, 0.735), TRIM),
        drum(n + "_boss_l", 0.085, 0.07, (0.345, 0.0, sz), STEEL, "x"),
        drum(n + "_boss_r", 0.085, 0.07, (-0.345, 0.0, sz), STEEL, "x"),
        block(n + "_pelvis", (0.36, 0.30, 0.22), (0.0, 0.0, 0.07), TRIM, taper=(1.15, 1.05)),
        block(n + "_codpiece", (0.16, 0.08, 0.16), (0.0, 0.16, 0.05), STEEL),
        # The head: a dome on a drum, sunk into the chest, one hooded eye, ears, antennae.
        drum(n + "_collar", 0.19, 0.06, (0.0, 0.02, 0.775), STEEL),
        drum(n + "_head", 0.15, 0.12, (0.0, 0.02, 0.85), PAINT),
        ball(n + "_dome", 0.15, (0.0, 0.02, 0.905), PAINT, 0.62),
        drum(n + "_hood", 0.098, 0.11, (0.0, 0.155, 0.865), STEEL, "y"),
        drum(n + "_eye", 0.072, 0.03, (0.0, 0.205, 0.865), EYE, "y"),
        drum(n + "_ear_l", 0.055, 0.07, (0.165, 0.02, 0.865), STEEL, "x", sides=12),
        drum(n + "_ear_r", 0.055, 0.07, (-0.165, 0.02, 0.865), STEEL, "x", sides=12),
        drum(n + "_aerial_l", 0.013, 0.22, (0.10, -0.06, 1.05), STEEL, sides=6),
        drum(n + "_aerial_r", 0.013, 0.15, (-0.10, -0.06, 1.015), STEEL, sides=6),
        ball(n + "_tip_l", 0.03, (0.10, -0.06, 1.165), TRIM),
        ball(n + "_tip_r", 0.03, (-0.10, -0.06, 1.095), TRIM),
        # The BACK is the side the player sees most: a pack, a tank, two capped stacks.
        block(n + "_pack", (0.46, 0.16, 0.42), (0.0, -0.30, 0.50), STEEL),
        drum(n + "_tank", 0.085, 0.36, (0.0, -0.39, 0.62), ALU, "x"),
        drum(n + "_stack_l", 0.06, 0.32, (0.16, -0.31, 0.80), DARK, sides=12),
        drum(n + "_stack_r", 0.06, 0.32, (-0.16, -0.31, 0.80), DARK, sides=12),
        drum(n + "_cap_l", 0.075, 0.05, (0.16, -0.31, 0.97), TRIM, sides=12),
        drum(n + "_cap_r", 0.075, 0.05, (-0.16, -0.31, 0.97), TRIM, sides=12),
    ]
    for side in (1.0, -1.0):
        tag = "l" if side > 0 else "r"
        pieces.append(block("%s_flank_%s" % (n, tag), (0.04, 0.30, 0.30), (side * 0.325, 0.0, 0.40), STEEL))
        for i in range(3):
            pieces.append(block("%s_vent_%s%d" % (n, tag, i), (0.03, 0.20, 0.035),
                                (side * 0.345, 0.0, 0.32 + i * 0.075), DARK))
    pieces += bolts(n + "_stud", [(x, 0.255, z) for x in (-0.27, 0.27) for z in (0.28, 0.68)])
    pieces += bolts(n + "_top", [(x, y, 0.775) for x in (-0.24, 0.24) for y in (-0.14, 0.12)])
    return prim.join(pieces, part_id)


## Where the module hangs: on the back of the pack. The bridge's formula puts it at the
## torso's back face, which this chest is deeper than -- a module there was buried in it.
## Every module is modelled reaching FORWARD from its socket, so the socket sits proud.
BACK_SOCKET = (0.0, -0.44, 0.40)


def brute_leg(name):
    """One leg, hip at the origin, foot planted outboard (+X) and knee loaded forward."""
    knee = (0.085, config.KNEE_FORWARD, config.LEG_KNEE_Z + 0.02)
    fx = 0.11
    sole = -config.LEG_LENGTH
    pieces = [
        drum(name + "_hip", 0.105, 0.14, (0.05, 0.0, 0.0), STEEL, "x"),
        block(name + "_thigh", (0.27, 0.29, 0.32), (0.08, 0.0, -0.20), PAINT, taper=(1.06, 1.04)),
        block(name + "_thigh_plate", (0.05, 0.20, 0.20), (0.225, 0.0, -0.19), TRIM),
        drum(name + "_knee", 0.09, 0.23, knee, STEEL, "x"),
        ball(name + "_kneepad", 0.12, (knee[0], knee[1] + 0.07, knee[2]), PAINT, 0.9),
        block(name + "_shin", (0.28, 0.30, 0.22), (0.095, 0.03, -0.53), PAINT, taper=(0.9, 0.88)),
        block(name + "_shin_plate", (0.17, 0.05, 0.17), (0.095, 0.175, -0.54), ALU),
        block(name + "_boot", (0.32, 0.35, 0.17), (fx, 0.04, -0.705), STEEL, taper=(0.9, 0.9)),
        block(name + "_foot", (0.33, 0.50, 0.08), (fx, 0.07, sole + 0.05), PAINT, taper=(0.88, 0.82)),
        block(name + "_toe", (0.33, 0.14, 0.09), (fx, 0.29, sole + 0.045), TRIM, taper=(0.9, 0.6)),
        block(name + "_heel", (0.22, 0.10, 0.10), (fx, -0.17, sole + 0.05), STEEL),
        block(name + "_sole", (0.34, 0.50, 0.025), (fx, 0.07, sole + 0.0125), DARK, chamfer=0.2),
    ]
    pieces += bolts(name + "_stud", [(0.095 + x, 0.205, -0.54 + z) for x in (-0.055, 0.055) for z in (-0.055, 0.055)],
                    DARK, 0.018)
    pieces += bolts(name + "_side", [(0.255, y, -0.19) for y in (-0.06, 0.06)], STEEL, 0.022)
    return prim.join(pieces, name)


def build_brute(part_id, part):
    body = brute_body(part_id)
    leg_l = brute_leg("limb_leg_l")
    leg_r = brute_leg("limb_leg_r")
    prim.mirror_x(leg_r)
    leg_l.location = (config.TORSO_HIP_X, 0.0, 0.0)
    leg_r.location = (-config.TORSO_HIP_X, 0.0, 0.0)
    leg_l.name, leg_r.name = "limb_leg_l", "limb_leg_r"
    # `apply_matrix` composes onto `matrix_world`, which a `.location` write does not refresh
    # until the scene updates: without this both legs were baked at the pelvis centre.
    bpy.context.view_layer.update()

    lift = config.LEG_LENGTH
    bulk = msp.proportion_of(part)
    msp.apply_matrix([body, leg_l, leg_r], msp.game_matrix(lift, bulk))
    for limb in (leg_l, leg_r):
        prim.parent_keeping_transform(limb, body)

    # The bridge's own socket formulas for the core and arms, so any old core or arm sits
    # where it would on any other frame; the module hangs on the pack.
    half_width = 0.22
    msp.add_socket(body, "socket_core", msp.to_game_point(
        (0.0, half_width * msp.CORE_FRONT * 3.0 + 0.02, config.TORSO_HEIGHT * msp.CORE_HEIGHT), lift, bulk))
    msp.add_socket(body, "socket_module", msp.to_game_point(BACK_SOCKET, lift, bulk))
    for side, name in ((1.0, "socket_arm_l"), (-1.0, "socket_arm_r")):
        msp.add_socket(body, name, msp.to_game_point(
            (side * config.TORSO_SHOULDER_X, 0.0, config.TORSO_SHOULDER_Z), lift, bulk))
    return body


# --- Arms --------------------------------------------------------------------
#
# Built as the RIGHT arm (`socket_arm_r`); the game mirrors it for the left. The right
# shoulder is at the generator's -X, so outboard is -X here.

WRIST = (0.0, config.ARM_FORWARD_CANT, -config.ARM_LENGTH)
ELBOW = (0.0, -0.12, config.ARM_ELBOW_Z)


def heavy_arm(part_id):
    """A huge rounded pauldron with a trim band and studs, a steel upper arm, a gauntlet of a
    forearm with a light plate and a trim cuff."""
    n = part_id
    upper, upper_len, upper_rot = along((0.0, 0.0, -0.02), ELBOW)
    fore, fore_len, fore_rot = along(ELBOW, WRIST)
    pieces = [
        drum(n + "_joint", 0.095, 0.16, (-0.02, 0.0, 0.0), STEEL, "x"),
        block(n + "_pauldron", (0.36, 0.42, 0.30), (-0.09, 0.0, 0.08), PAINT, taper=(0.86, 0.88), chamfer=0.34),
        block(n + "_pauldron_rim", (0.385, 0.445, 0.07), (-0.09, 0.0, -0.075), TRIM, chamfer=0.4),
        drum(n + "_upper", 0.075, upper_len, upper, STEEL, "z"),
        drum(n + "_elbow", 0.09, 0.19, ELBOW, STEEL, "x"),
        drum(n + "_elbow_cap", 0.06, 0.21, ELBOW, TRIM, "x", sides=12),
        block(n + "_forearm", (0.25, 0.27, fore_len), fore, PAINT, rot=(fore_rot, 0.0, 0.0),
              taper=(0.8, 0.8), chamfer=0.3),
        block(n + "_cuff", (0.27, 0.29, 0.07), (WRIST[0], WRIST[1] - 0.035, WRIST[2] + 0.055), TRIM,
              rot=(fore_rot, 0.0, 0.0), chamfer=0.4),
        block(n + "_arm_plate", (0.04, 0.16, 0.20), (-0.125, fore[1], fore[2]), ALU, rot=(fore_rot, 0.0, 0.0)),
    ]
    # The upper arm is a drum along Z: lay it along shoulder -> elbow.
    up = pieces[3]
    up.rotation_euler = (upper_rot, 0.0, 0.0)
    pivot = Vector(upper)
    up.location = pivot - (up.rotation_euler.to_matrix() @ pivot)
    bake(up)
    pieces += bolts(n + "_stud", [(-0.09 + x, y, 0.235) for x in (-0.07, 0.07) for y in (-0.11, 0.11)])
    return prim.join(pieces, part_id + "_arm")


def fist(n, y):
    """A closed hand round a haft that runs along +Y: the concept's machines have hands."""
    out = [block(n + "_palm", (0.15, 0.13, 0.13), (0.0, y, 0.0), STEEL, chamfer=0.35)]
    for i in range(4):
        out.append(block("%s_finger_%d" % (n, i), (0.05, 0.035, 0.11), (0.0, y - 0.045 + i * 0.03, 0.075),
                         DARK, chamfer=0.4))
    out.append(block(n + "_thumb", (0.05, 0.06, 0.05), (0.075, y + 0.03, 0.03), DARK, chamfer=0.4))
    return out


def hammer(part_id):
    """A sledge in a fist: a haft, a banded block with a trim stripe."""
    n = part_id
    pieces = fist(n, 0.06) + [
        drum(n + "_haft", 0.038, 0.40, (0.0, 0.20, 0.0), STEEL, "y", sides=10),
        block(n + "_head", (0.24, 0.22, 0.40), (0.0, 0.44, 0.0), ALU, chamfer=0.25),
        block(n + "_band_a", (0.255, 0.235, 0.05), (0.0, 0.44, 0.115), DARK, chamfer=0.4),
        block(n + "_band_b", (0.255, 0.235, 0.05), (0.0, 0.44, -0.115), DARK, chamfer=0.4),
        block(n + "_stripe", (0.25, 0.23, 0.06), (0.0, 0.44, 0.0), TRIM, chamfer=0.4),
    ]
    return prim.join(pieces, part_id + "_weapon")


def saw(part_id):
    """A toothed disc on a motor, its upper half under a guard."""
    n = part_id
    centre_y, radius, teeth = 0.30, 0.225, 12
    outline = []
    for i in range(teeth * 2):
        # A raked tooth: the tip leads, the gullet trails.
        a = 2.0 * math.pi * (i + (0.25 if i % 2 == 0 else 0.0)) / (teeth * 2)
        r = radius + (0.05 if i % 2 == 0 else 0.0)
        outline.append((centre_y + r * math.cos(a), r * math.sin(a)))
    blade = plate_x(n + "_blade", outline, 0.028, 0.0, ALU)
    guard_outline = [(centre_y, 0.0)]
    for i in range(11):
        a = math.radians(30.0 + i * 14.0)
        guard_outline.append((centre_y + 0.295 * math.cos(a), 0.295 * math.sin(a)))
    guard = plate_x(n + "_guard", guard_outline, 0.035, -0.04, TRIM)
    pieces = [
        block(n + "_motor", (0.19, 0.20, 0.19), (0.0, 0.03, 0.0), PAINT),
        drum(n + "_exhaust", 0.035, 0.12, (-0.05, -0.02, 0.13), DARK, sides=10),
        block(n + "_bracket", (0.07, 0.30, 0.09), (0.0, 0.17, 0.0), STEEL),
        blade,
        guard,
        drum(n + "_hub", 0.075, 0.08, (0.0, centre_y, 0.0), STEEL, "x"),
        ball(n + "_nut", 0.035, (0.045, centre_y, 0.0), DARK, 0.8),
    ]
    return prim.join(pieces, part_id + "_weapon")


WEAPONS = {"hammer": hammer, "maul": hammer, "saw": saw}


def build_arm(part_id, part):
    weapon_class = str(part.get("weapon_class", "hammer"))
    arm = heavy_arm(part_id)
    weapon = WEAPONS[weapon_class](part_id)
    # As the bridge does it: grown about the mount, drooped at the wrist, seated on it.
    weapon.scale = (msp.WEAPON_SCALE,) * 3
    weapon.rotation_euler = (msp.WEAPON_REST_PITCH["melee"], 0.0, 0.0)
    weapon.location = WRIST
    fused = prim.join([arm, weapon], part_id)
    msp.apply_matrix([fused], msp.game_matrix(0.0))
    return fused


# --- Core --------------------------------------------------------------------

def build_core(part_id, part):
    """The concept's bolted chest plate, with the damage-type lens low in it (the crew number
    is stencilled top-left). A housing reaches back into the chest, so it sits on any frame."""
    n = part_id
    damage = str(part.get("damage_type", "kinetic"))
    lens = drum(n + "_lens", 0.055, 0.035, (0.05, 0.12, -0.045), EYE, "y")
    lens.data.materials.clear()
    lens.data.materials.append(msp.glow_material(damage))
    pieces = [
        block(n + "_housing", (0.30, 0.14, 0.25), (0.0, -0.02, 0.0), DARK),
        block(n + "_plate", (0.36, 0.07, 0.30), (0.0, 0.06, 0.0), ALU, chamfer=0.35),
        drum(n + "_rim", 0.082, 0.04, (0.05, 0.10, -0.045), STEEL, "y"),
        lens,
        block(n + "_tab", (0.10, 0.03, 0.04), (-0.10, 0.10, -0.10), TRIM, chamfer=0.4),
    ]
    pieces += bolts(n + "_bolt", [(x, 0.095, z) for x in (-0.14, 0.14) for z in (-0.11, 0.11)], STEEL, 0.03)
    fused = prim.join(pieces, part_id)
    msp.apply_matrix([fused], msp.game_matrix(0.0))
    return fused


BUILDERS = {
    "ch_brute": build_brute,
    "ar_saw": build_arm,
    "ar_hammer": build_arm,
    "co_slug": build_core,
}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = argv[argv.index("--out") + 1] if "--out" in argv else "art/parts_new"
    only = argv[argv.index("--only") + 1] if "--only" in argv else ""
    project_root = os.path.dirname(os.path.dirname(_HERE))
    parts = msp.load_parts(project_root)

    prim.clear_scene()
    materials.build_materials()
    prim.ensure_collection(config.ROOT_COLLECTION)
    prim.set_active_collection(prim.ensure_collection(config.SCRATCH_COLLECTION))

    for part_id, builder in BUILDERS.items():
        if only and part_id != only:
            continue
        obj = builder(part_id, parts[part_id])
        msp.export_part(obj, os.path.join(out, part_id + ".glb"))
        limbs = len([c for c in obj.children if c.type == "MESH"])
        sockets = len([c for c in obj.children if c.type == "EMPTY"])
        print("  %-10s %5d tris  %d limb(s) %d socket(s)"
              % (part_id, msp.part_triangles(obj), limbs, sockets))
        for stale in list(bpy.data.objects):
            bpy.data.objects.remove(stale, do_unlink=True)
        for mesh in list(bpy.data.meshes):
            if mesh.users == 0:
                bpy.data.meshes.remove(mesh)


if __name__ == "__main__":
    main()
