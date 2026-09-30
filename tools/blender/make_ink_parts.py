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
PATCH = "zone:patch"   # a plate scavenged from another machine: a colour that is NOT the maker's (019)
ZONE_HEX = {"steel": "7d848c", "trim": "c8602a", "patch": "6e7443", "hazard": "d9a02b"}

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


# --- Scrap -------------------------------------------------------------------
#
# 019, the user: "the colours of different parts need to be more than one colour, representing
# that they are made from actual scrap". A machine here is rebuilt from what was lying about:
# most plate is its maker's livery, some was cut off another machine (`patch`: a colour that is
# NOT the maker's), some was never painted again (`rust`). Which piece is which comes from the
# piece's own name, so a part is the same every build.

def pick(name, salt=0):
    return msp.hash_id("%s/%d" % (name, salt))


def skin(name):
    """The material of a secondary armour piece: mostly livery, sometimes scavenged or rusted."""
    roll = pick(name) % 100
    return PAINT if roll < 50 else (PATCH if roll < 80 else RUST)


def repair(name, at, size, axis):
    """A bolted repair plate on a big surface, facing `axis` ('x' or 'y'), in a colour the
    surface is not: the cheapest way a panel says it has been mended."""
    sx, sz = size
    thin = 0.035
    dims = (thin, sx, sz) if axis == "x" else (sx, thin, sz)
    material = PATCH if pick(name) % 3 else RUST
    out = [block(name, dims, at, material, chamfer=0.45)]
    for i, (u, w) in enumerate(((-1, -1), (1, 1), (-1, 1), (1, -1))):
        if axis == "x":
            p = (at[0] + math.copysign(thin * 0.5, at[0]), at[1] + u * sx * 0.34, at[2] + w * sz * 0.34)
        else:
            p = (at[0] + u * sx * 0.34, at[1] + math.copysign(thin * 0.5, at[1]), at[2] + w * sz * 0.34)
        out.append(ball("%s_r%d" % (name, i), 0.017, p, DARK, 0.7))
    return out


def spike(name, radius, length, at, material, axis="z"):
    obj = prim.cone(name, radius, 0.0, length, location=at, rotation=AXIS[axis], vertices=8,
                    material="OldSteel")
    return colour(soften(bake(obj), 50.0), material)


# --- Frames ------------------------------------------------------------------
#
# One builder, a spec per frame. Role decides the silhouette (an anchor is a wide wall, a
# marksman lean and tall, a brawler top-heavy, a line machine plain); the head, the legs and
# what it carries on its back are the frame's own. Generator units; chest bottom at z = 0.19.

FRAMES = {
    #               chest (w, d, h)     taper        head     legs (thick, style)  back
    "ch_brute":      ((0.66, 0.50, 0.58), (1.08, 1.0), "dome",  (1.00, "heavy"), "stacks"),
    "ch_dredge":     ((0.70, 0.54, 0.52), (1.00, 1.0), "scoop", (1.05, "heavy"), "crate"),
    "ch_citadel":    ((0.78, 0.56, 0.62), (0.94, 1.0), "slit",  (1.15, "heavy"), "slab"),
    "ch_bulwark":    ((0.74, 0.50, 0.56), (0.96, 1.0), "box",   (1.05, "wide"),  "coil"),
    "ch_skirmisher": ((0.54, 0.42, 0.52), (1.04, 1.0), "box",   (0.82, "lean"),  "coil"),
    "ch_hauler":     ((0.62, 0.52, 0.54), (0.98, 1.0), "cab",   (0.95, "wide"),  "tank"),
    "ch_reaper":     ((0.58, 0.44, 0.54), (1.16, 1.0), "skull", (0.88, "lean"),  "fins"),
    "ch_strider":    ((0.44, 0.38, 0.56), (1.00, 1.0), "mast",  (0.70, "lean"),  "dish"),
    "ch_lancer":     ((0.48, 0.40, 0.58), (1.06, 1.0), "visor", (0.76, "lean"),  "quiver"),
    "ch_courier":    ((0.46, 0.40, 0.46), (1.00, 1.0), "visor", (0.72, "lean"),  "crate"),
}


def frame_head(n, kind, top):
    """The head sits ON the chest. Every one has an eye in the team's zone."""
    z = top
    if kind == "dome":
        return [drum(n + "_collar", 0.19, 0.06, (0, 0.02, z + 0.015), STEEL),
                drum(n + "_head", 0.15, 0.12, (0, 0.02, z + 0.09), PAINT),
                ball(n + "_dome", 0.15, (0, 0.02, z + 0.145), skin(n + "_dome"), 0.62),
                drum(n + "_hood", 0.098, 0.11, (0, 0.155, z + 0.105), STEEL, "y"),
                drum(n + "_eye", 0.072, 0.03, (0, 0.205, z + 0.105), EYE, "y"),
                drum(n + "_ear_l", 0.055, 0.07, (0.165, 0.02, z + 0.105), STEEL, "x", 12),
                drum(n + "_ear_r", 0.055, 0.07, (-0.165, 0.02, z + 0.105), STEEL, "x", 12),
                drum(n + "_aerial_l", 0.013, 0.22, (0.10, -0.06, z + 0.29), STEEL, sides=6),
                drum(n + "_aerial_r", 0.013, 0.15, (-0.10, -0.06, z + 0.255), STEEL, sides=6),
                ball(n + "_tip_l", 0.03, (0.10, -0.06, z + 0.405), TRIM),
                ball(n + "_tip_r", 0.03, (-0.10, -0.06, z + 0.335), TRIM)]
    if kind == "box":
        return [block(n + "_neck", (0.20, 0.18, 0.06), (0, 0.02, z + 0.02), STEEL),
                block(n + "_head", (0.30, 0.26, 0.20), (0, 0.03, z + 0.13), PAINT),
                block(n + "_cheek", (0.31, 0.10, 0.08), (0, 0.06, z + 0.07), skin(n + "_cheek")),
                block(n + "_eye", (0.20, 0.03, 0.06), (0, 0.165, z + 0.15), EYE, chamfer=0.4),
                drum(n + "_lamp", 0.04, 0.05, (0.11, 0.15, z + 0.245), STEEL, "y", 10),
                drum(n + "_aerial", 0.012, 0.20, (-0.11, -0.05, z + 0.32), STEEL, sides=6)]
    if kind == "slit":
        return [block(n + "_head", (0.40, 0.30, 0.16), (0, 0.04, z + 0.06), PAINT, taper=(0.8, 0.8)),
                block(n + "_brow_plate", (0.42, 0.10, 0.06), (0, 0.15, z + 0.12), STEEL),
                block(n + "_eye", (0.26, 0.03, 0.04), (0, 0.195, z + 0.07), EYE, chamfer=0.4),
                drum(n + "_smoke_l", 0.04, 0.10, (0.15, -0.06, z + 0.17), DARK, sides=10),
                drum(n + "_smoke_r", 0.04, 0.10, (-0.15, -0.06, z + 0.17), DARK, sides=10)]
    if kind == "scoop":
        return [block(n + "_head", (0.26, 0.24, 0.16), (0, 0.0, z + 0.08), PAINT),
                block(n + "_jaw", (0.34, 0.20, 0.10), (0, 0.13, z + 0.03), RUST, taper=(0.8, 0.6)),
                drum(n + "_eye", 0.055, 0.03, (0.06, 0.125, z + 0.12), EYE, "y"),
                drum(n + "_eye_b", 0.035, 0.03, (-0.07, 0.125, z + 0.12), DARK, "y", 10),
                drum(n + "_beacon", 0.04, 0.06, (0, -0.05, z + 0.19), TRIM, sides=10)]
    if kind == "cab":
        return [block(n + "_cab", (0.36, 0.30, 0.24), (0, 0.06, z + 0.11), PAINT, taper=(0.86, 0.8)),
                block(n + "_eye", (0.26, 0.03, 0.09), (0, 0.20, z + 0.14), EYE, chamfer=0.3),
                block(n + "_visor_bar", (0.03, 0.04, 0.10), (0, 0.205, z + 0.14), DARK),
                block(n + "_roof", (0.34, 0.26, 0.04), (0, 0.04, z + 0.24), skin(n + "_roof")),
                drum(n + "_horn", 0.035, 0.12, (0.13, 0.0, z + 0.29), ALU, "y", 10)]
    if kind == "skull":
        return [ball(n + "_skull", 0.16, (0, 0.03, z + 0.10), PAINT, 0.85),
                block(n + "_jaw", (0.20, 0.14, 0.10), (0, 0.10, z + 0.01), STEEL, taper=(0.7, 0.8)),
                drum(n + "_eye", 0.045, 0.04, (0.065, 0.16, z + 0.11), EYE, "y", 10),
                drum(n + "_eye_r", 0.045, 0.04, (-0.065, 0.16, z + 0.11), EYE, "y", 10),
                spike(n + "_horn_l", 0.035, 0.16, (0.12, -0.02, z + 0.27), RUST),
                spike(n + "_horn_r", 0.035, 0.16, (-0.12, -0.02, z + 0.27), RUST)]
    if kind == "mast":
        return [drum(n + "_neck", 0.05, 0.16, (0, 0.0, z + 0.08), STEEL, sides=10),
                block(n + "_head", (0.20, 0.26, 0.14), (0, 0.04, z + 0.20), PAINT),
                drum(n + "_eye", 0.06, 0.04, (0, 0.18, z + 0.20), EYE, "y"),
                drum(n + "_scope", 0.035, 0.22, (0.13, 0.08, z + 0.22), DARK, "y", 10),
                drum(n + "_aerial", 0.011, 0.26, (-0.07, -0.08, z + 0.40), STEEL, sides=6),
                ball(n + "_tip", 0.025, (-0.07, -0.08, z + 0.535), TRIM)]
    # visor
    return [block(n + "_neck", (0.16, 0.16, 0.05), (0, 0.02, z + 0.02), STEEL),
            block(n + "_head", (0.26, 0.28, 0.16), (0, 0.05, z + 0.11), PAINT, taper=(0.8, 0.9)),
            block(n + "_eye", (0.22, 0.04, 0.045), (0, 0.185, z + 0.11), EYE, chamfer=0.4),
            block(n + "_crest", (0.04, 0.24, 0.07), (0, 0.02, z + 0.21), TRIM),
            drum(n + "_ear", 0.04, 0.05, (0.145, 0.03, z + 0.11), STEEL, "x", 10)]


def frame_back(n, kind, d, top):
    """What the frame carries: the side a player sees most of their own crew."""
    y = -d * 0.5
    if kind == "stacks":
        return [block(n + "_pack", (0.46, 0.16, 0.42), (0, y - 0.05, 0.50), STEEL),
                drum(n + "_tank", 0.085, 0.36, (0, y - 0.14, 0.62), ALU, "x"),
                drum(n + "_stack_l", 0.06, 0.32, (0.16, y - 0.06, top + 0.04), DARK, sides=12),
                drum(n + "_stack_r", 0.06, 0.32, (-0.16, y - 0.06, top + 0.04), DARK, sides=12),
                drum(n + "_cap_l", 0.075, 0.05, (0.16, y - 0.06, top + 0.21), TRIM, sides=12),
                drum(n + "_cap_r", 0.075, 0.05, (-0.16, y - 0.06, top + 0.21), TRIM, sides=12)]
    if kind == "crate":
        return [block(n + "_crate", (0.40, 0.20, 0.30), (0, y - 0.08, 0.52), PATCH),
                block(n + "_strap_a", (0.05, 0.22, 0.32), (0.10, y - 0.08, 0.52), DARK, chamfer=0.4),
                block(n + "_strap_b", (0.05, 0.22, 0.32), (-0.10, y - 0.08, 0.52), DARK, chamfer=0.4),
                drum(n + "_roll", 0.06, 0.38, (0, y - 0.07, 0.72), RUST, "x", 12)]
    if kind == "slab":
        return [block(n + "_slab", (0.62, 0.10, 0.50), (0, y - 0.04, 0.50), skin(n + "_slab")),
                block(n + "_rib_a", (0.06, 0.14, 0.52), (0.20, y - 0.05, 0.50), STEEL),
                block(n + "_rib_b", (0.06, 0.14, 0.52), (-0.20, y - 0.05, 0.50), STEEL),
                drum(n + "_stack", 0.07, 0.30, (0, y - 0.06, top + 0.06), DARK, sides=12),
                drum(n + "_cap", 0.085, 0.05, (0, y - 0.06, top + 0.22), TRIM, sides=12)]
    if kind == "coil":
        out = [block(n + "_pack", (0.38, 0.14, 0.36), (0, y - 0.05, 0.50), STEEL)]
        for i, x in enumerate((-0.11, 0.11)):
            out.append(drum("%s_coil_%d" % (n, i), 0.07, 0.34, (x, y - 0.13, 0.52), DARK, sides=12))
            for j in range(3):
                out.append(drum("%s_ring_%d%d" % (n, i, j), 0.085, 0.035, (x, y - 0.13, 0.41 + j * 0.11), ALU, sides=12))
        return out
    if kind == "tank":
        return [drum(n + "_tank", 0.15, 0.46, (0, y - 0.10, 0.50), skin(n + "_tank"), "x"),
                drum(n + "_band_a", 0.16, 0.04, (0.14, y - 0.10, 0.50), STEEL, "x"),
                drum(n + "_band_b", 0.16, 0.04, (-0.14, y - 0.10, 0.50), STEEL, "x"),
                drum(n + "_pipe", 0.035, 0.30, (0.20, y - 0.04, top - 0.02), DARK, sides=10),
                drum(n + "_valve", 0.05, 0.04, (0, y - 0.25, 0.50), TRIM, "y", 10)]
    if kind == "fins":
        out = [block(n + "_pack", (0.30, 0.12, 0.34), (0, y - 0.04, 0.50), STEEL)]
        for i, x in enumerate((-0.12, 0.0, 0.12)):
            out.append(block("%s_fin_%d" % (n, i), (0.035, 0.22, 0.34), (x, y - 0.13, 0.56), RUST if i == 1 else TRIM,
                             rot=(0.45, 0, 0), chamfer=0.45))
        return out
    if kind == "dish":
        return [block(n + "_pack", (0.26, 0.12, 0.30), (0, y - 0.04, 0.48), STEEL),
                drum(n + "_pole", 0.02, 0.34, (0.0, y - 0.07, top + 0.06), STEEL, sides=8),
                ball(n + "_dish", 0.14, (0.0, y - 0.09, top + 0.25), ALU, 0.35),
                ball(n + "_feed", 0.03, (0.0, y - 0.09, top + 0.33), TRIM)]
    # quiver
    out = [block(n + "_pack", (0.30, 0.12, 0.34), (0, y - 0.04, 0.50), STEEL)]
    for i, x in enumerate((-0.09, 0.0, 0.09)):
        out.append(drum("%s_rod_%d" % (n, i), 0.025, 0.50, (x, y - 0.12, 0.62), ALU if i != 1 else RUST, sides=8))
    out.append(block(n + "_quiver", (0.30, 0.10, 0.20), (0, y - 0.12, 0.44), PATCH))
    return out


def frame_body(part_id):
    n = part_id
    (w, d, h), taper, head, _legs, back = FRAMES[part_id]
    sz = config.TORSO_SHOULDER_Z
    top = 0.19 + h
    cz = 0.19 + h * 0.5
    pieces = [
        block(n + "_chest", (w, d, h), (0, 0, cz), PAINT, taper=taper, chamfer=0.22),
        block(n + "_bezel", (min(0.46, w - 0.12), 0.06, 0.40), (0, d * 0.5 - 0.005, 0.47), STEEL),
        block(n + "_belt", (w - 0.10, d - 0.04, 0.08), (0, 0, 0.20), STEEL),
        block(n + "_brow", (w - 0.16, 0.10, 0.07), (0, d * 0.5 - 0.03, top - 0.035), TRIM),
        # The shoulders are a contract (x = +-0.34): a bar reaches them whatever the chest's width.
        drum(n + "_yoke", 0.08, 0.76, (0, 0, sz), STEEL, "x"),
        block(n + "_pelvis", (min(0.36, w - 0.2), 0.30, 0.22), (0, 0, 0.07), TRIM, taper=(1.15, 1.05)),
        block(n + "_codpiece", (0.16, 0.08, 0.16), (0, 0.16, 0.05), STEEL),
    ]
    for side in (1.0, -1.0):
        tag = "l" if side > 0 else "r"
        x = side * (w * 0.5 - 0.005)
        pieces.append(block("%s_flank_%s" % (n, tag), (0.04, d * 0.6, 0.30), (x, 0, 0.40), skin("%s_flank_%s" % (n, tag))))
        for i in range(3):
            pieces.append(block("%s_vent_%s%d" % (n, tag, i), (0.03, d * 0.4, 0.035), (x + side * 0.02, 0, 0.32 + i * 0.075), DARK))
    # Mended: one plate on the front beside the core's frame, one on a flank or the roof.
    side = 1.0 if pick(n, 1) % 2 else -1.0
    if w > 0.60:
        pieces += repair(n + "_mend_a", (side * (w * 0.5 - 0.07), d * 0.5 + 0.005, 0.30 + (pick(n, 2) % 20) * 0.01),
                         (0.11, 0.15), "y")
    pieces += repair(n + "_mend_b", (-side * (w * 0.5 + 0.012), 0.04, top - 0.14), (d * 0.34, 0.13), "x")
    pieces += bolts(n + "_stud", [(x, d * 0.5 + 0.005, z) for x in (-(w * 0.5 - 0.06), w * 0.5 - 0.06) for z in (0.28, top - 0.10)])
    pieces += frame_head(n, head, top - 0.01)
    pieces += frame_back(n, back, d, top)
    return prim.join(pieces, part_id)


def frame_leg(name, owner):
    """One leg, hip at the origin, foot planted outboard (+X) and knee loaded forward.
    `t` scales its girth; a lean leg is a strut with a shin guard, a wide one a broad boot."""
    t, style = FRAMES[owner][3]
    knee = (0.085, config.KNEE_FORWARD, config.LEG_KNEE_Z + 0.02)
    fx = 0.11 if style != "lean" else 0.09
    sole = -config.LEG_LENGTH
    o = owner + name[-2:]
    foot_w = (0.33 if style != "wide" else 0.40) * (0.6 + 0.4 * t)
    pieces = [
        drum(name + "_hip", 0.105 * t, 0.14, (0.05, 0, 0), STEEL, "x"),
        drum(name + "_knee", 0.09 * t, 0.23 * t, knee, STEEL, "x"),
        ball(name + "_kneepad", 0.12 * t, (knee[0], knee[1] + 0.07, knee[2]), skin(o + "_kneepad"), 0.9),
        block(name + "_foot", (foot_w, 0.50 * (0.7 + 0.3 * t), 0.08), (fx, 0.07, sole + 0.05), PAINT, taper=(0.88, 0.82)),
        block(name + "_toe", (foot_w, 0.14, 0.09), (fx, 0.07 + 0.22 * (0.7 + 0.3 * t), sole + 0.045), TRIM, taper=(0.9, 0.6)),
        block(name + "_heel", (0.22 * t, 0.10, 0.10), (fx, -0.17 * t, sole + 0.05), STEEL),
        block(name + "_sole", (foot_w + 0.01, 0.50 * (0.7 + 0.3 * t), 0.025), (fx, 0.07, sole + 0.0125), DARK, chamfer=0.2),
    ]
    if style == "lean":
        pieces += [
            drum(name + "_thigh", 0.075 * t + 0.02, 0.36, (0.07, 0, -0.21), STEEL),
            block(name + "_thigh_guard", (0.16, 0.10, 0.26), (0.08, 0.07, -0.20), PAINT),
            drum(name + "_shank", 0.06 * t + 0.02, 0.34, (0.09, 0.03, -0.62), STEEL),
            block(name + "_shin_guard", (0.17, 0.09, 0.28), (0.095, 0.10, -0.60), skin(o + "_shin")),
            drum(name + "_ram", 0.022, 0.30, (0.09, -0.07, -0.60), ALU, sides=8),
        ]
    else:
        pieces += [
            block(name + "_thigh", (0.27 * t, 0.29 * t, 0.32), (0.08, 0, -0.20), PAINT, taper=(1.06, 1.04)),
            block(name + "_thigh_plate", (0.05, 0.20, 0.20), (0.08 + 0.145 * t, 0, -0.19), skin(o + "_thigh_plate")),
            block(name + "_shin", (0.28 * t, 0.30 * t, 0.22), (0.095, 0.03, -0.53), skin(o + "_shin"), taper=(0.9, 0.88)),
            block(name + "_shin_plate", (0.17 * t, 0.05, 0.17), (0.095, 0.03 + 0.145 * t, -0.54), ALU),
            block(name + "_boot", (0.32 * t, 0.35 * t, 0.17), (fx, 0.04, -0.705), STEEL, taper=(0.9, 0.9)),
        ]
        pieces += bolts(name + "_side", [(0.08 + 0.175 * t, y, -0.19) for y in (-0.06, 0.06)], STEEL, 0.022)
    return prim.join(pieces, name)


def build_frame(part_id, part):
    d = FRAMES[part_id][0][1]
    body = frame_body(part_id)
    leg_l = frame_leg("limb_leg_l", part_id)
    leg_r = frame_leg("limb_leg_r", part_id)
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
    # Core on the chest's own front, module on the back of whatever the frame carries.
    msp.add_socket(body, "socket_core", msp.to_game_point((0.0, d * 0.5 - 0.03, 0.48), lift, bulk))
    msp.add_socket(body, "socket_module", msp.to_game_point((0.0, -d * 0.5 - 0.19, 0.40), lift, bulk))
    for side, name in ((1.0, "socket_arm_l"), (-1.0, "socket_arm_r")):
        msp.add_socket(body, name, msp.to_game_point(
            (side * config.TORSO_SHOULDER_X, 0.0, config.TORSO_SHOULDER_Z), lift, bulk))
    return body


# --- Arms --------------------------------------------------------------------
#
# Built as the RIGHT arm (`socket_arm_r`); the game mirrors it for the left. The right
# shoulder is at the generator's -X, so outboard is -X here. The SHOULDER is the maker's;
# the weapon is the class's.

WRIST = (0.0, config.ARM_FORWARD_CANT, -config.ARM_LENGTH)
ELBOW = (0.0, -0.12, config.ARM_ELBOW_Z)


def shoulder(n, maker):
    if maker == "kessler":      # mining: a huge rounded pauldron, banded and studded
        out = [block(n + "_pauldron", (0.36, 0.42, 0.30), (-0.09, 0, 0.08), PAINT, taper=(0.86, 0.88), chamfer=0.34),
               block(n + "_pauldron_rim", (0.385, 0.445, 0.07), (-0.09, 0, -0.075), TRIM, chamfer=0.4)]
        out += bolts(n + "_stud", [(-0.09 + x, y, 0.235) for x in (-0.07, 0.07) for y in (-0.11, 0.11)])
        return out + repair(n + "_mend", (-0.262, 0.03, 0.09), (0.16, 0.12), "x")
    if maker == "cinder":       # foundry: a slab cut from a furnace door, spiked
        return [block(n + "_pauldron", (0.30, 0.44, 0.22), (-0.10, 0, 0.10), PAINT, taper=(0.6, 0.9), chamfer=0.25),
                block(n + "_lip", (0.10, 0.46, 0.10), (-0.24, 0, 0.03), RUST),
                spike(n + "_spike_a", 0.05, 0.20, (-0.10, 0.12, 0.30), RUST),
                spike(n + "_spike_b", 0.05, 0.16, (-0.10, -0.10, 0.28), STEEL),
                block(n + "_grate", (0.20, 0.30, 0.03), (-0.08, 0, -0.02), DARK)]
    if maker == "vektor":       # ballistics: a slim angled plate over an ammunition box
        return [block(n + "_pauldron", (0.22, 0.34, 0.20), (-0.08, 0, 0.09), PAINT, taper=(0.7, 0.8)),
                block(n + "_ammo", (0.16, 0.20, 0.14), (-0.10, -0.12, -0.06), PATCH),
                block(n + "_stripe", (0.235, 0.06, 0.205), (-0.08, 0.06, 0.09), TRIM, taper=(0.7, 1.0), chamfer=0.4)]
    # arclight: electric: a drum of windings
    out = [drum(n + "_pauldron", 0.17, 0.26, (-0.09, 0, 0.05), PAINT, "x")]
    for i in range(3):
        out.append(drum("%s_winding_%d" % (n, i), 0.185, 0.035, (-0.17 + i * 0.08, 0, 0.05), ALU if i != 1 else TRIM, "x"))
    out.append(ball(n + "_knob", 0.05, (-0.09, 0, 0.23), RUST))
    return out


def arm_of(part_id, maker, thick=1.0):
    n = part_id
    upper, upper_len, upper_rot = along((0.0, 0.0, -0.02), ELBOW)
    fore, fore_len, fore_rot = along(ELBOW, WRIST)
    up = drum(n + "_upper", 0.075 * thick, upper_len, upper, STEEL, "z")
    up.rotation_euler = (upper_rot, 0.0, 0.0)
    pivot = Vector(upper)
    up.location = pivot - (up.rotation_euler.to_matrix() @ pivot)
    bake(up)
    pieces = [
        drum(n + "_joint", 0.095, 0.16, (-0.02, 0, 0), STEEL, "x"),
        up,
        drum(n + "_elbow", 0.09 * thick, 0.19, ELBOW, STEEL, "x"),
        drum(n + "_elbow_cap", 0.06 * thick, 0.21, ELBOW, TRIM, "x", sides=12),
        block(n + "_forearm", (0.25 * thick, 0.27 * thick, fore_len), fore, skin(n + "_forearm"),
              rot=(fore_rot, 0, 0), taper=(0.8, 0.8), chamfer=0.3),
        block(n + "_cuff", (0.27 * thick, 0.29 * thick, 0.07), (WRIST[0], WRIST[1] - 0.035, WRIST[2] + 0.055), TRIM,
              rot=(fore_rot, 0, 0), chamfer=0.4),
        block(n + "_arm_plate", (0.04, 0.16, 0.20), (-0.125 * thick, fore[1], fore[2]), ALU, rot=(fore_rot, 0, 0)),
    ]
    return prim.join(pieces + shoulder(n, maker), part_id + "_arm")


def fist(n, y):
    """A closed hand round a haft that runs along +Y: the concept's machines have hands."""
    out = [block(n + "_palm", (0.15, 0.13, 0.13), (0, y, 0), STEEL, chamfer=0.35)]
    for i in range(4):
        out.append(block("%s_finger_%d" % (n, i), (0.05, 0.035, 0.11), (0, y - 0.045 + i * 0.03, 0.075), DARK, chamfer=0.4))
    out.append(block(n + "_thumb", (0.05, 0.06, 0.05), (0.075, y + 0.03, 0.03), DARK, chamfer=0.4))
    return out


def w_hammer(n):
    return fist(n, 0.06) + [
        drum(n + "_haft", 0.038, 0.40, (0, 0.20, 0), STEEL, "y", 10),
        block(n + "_head", (0.24, 0.22, 0.40), (0, 0.44, 0), ALU, chamfer=0.25),
        block(n + "_band_a", (0.255, 0.235, 0.05), (0, 0.44, 0.115), DARK, chamfer=0.4),
        block(n + "_band_b", (0.255, 0.235, 0.05), (0, 0.44, -0.115), DARK, chamfer=0.4),
        block(n + "_stripe", (0.25, 0.23, 0.06), (0, 0.44, 0), TRIM, chamfer=0.4)]


def w_maul(n):
    """The siege maul: a drum of a head on a long haft, spiked at both faces."""
    return fist(n, 0.06) + [
        drum(n + "_haft", 0.042, 0.52, (0, 0.26, 0), STEEL, "y", 10),
        drum(n + "_head", 0.17, 0.44, (0, 0.54, 0), ALU, "z", 14),
        drum(n + "_hoop_a", 0.185, 0.05, (0, 0.54, 0.13), RUST, "z", 14),
        drum(n + "_hoop_b", 0.185, 0.05, (0, 0.54, -0.13), DARK, "z", 14),
        spike(n + "_spike_a", 0.10, 0.16, (0, 0.54, 0.30), STEEL),
        block(n + "_weight", (0.16, 0.16, 0.10), (0, 0.54, -0.26), PATCH)]


def w_saw(n):
    cy, radius, teeth = 0.30, 0.225, 12
    outline = []
    for i in range(teeth * 2):
        a = 2.0 * math.pi * (i + (0.25 if i % 2 == 0 else 0.0)) / (teeth * 2)
        r = radius + (0.05 if i % 2 == 0 else 0.0)
        outline.append((cy + r * math.cos(a), r * math.sin(a)))
    guard = [(cy, 0.0)] + [(cy + 0.295 * math.cos(math.radians(30 + i * 14)), 0.295 * math.sin(math.radians(30 + i * 14)))
                           for i in range(11)]
    return [block(n + "_motor", (0.19, 0.20, 0.19), (0, 0.03, 0), PAINT),
            drum(n + "_exhaust", 0.035, 0.12, (-0.05, -0.02, 0.13), DARK, sides=10),
            block(n + "_bracket", (0.07, 0.30, 0.09), (0, 0.17, 0), STEEL),
            plate_x(n + "_blade", outline, 0.028, 0.0, ALU),
            plate_x(n + "_guard", guard, 0.035, -0.04, RUST),
            drum(n + "_hub", 0.075, 0.08, (0, cy, 0), STEEL, "x"),
            ball(n + "_nut", 0.035, (0.045, cy, 0), DARK, 0.8)]


def w_ripper(n):
    """A three-fingered claw: hooked talons round a dark palm."""
    out = [block(n + "_wrist", (0.18, 0.16, 0.18), (0, 0.04, 0), PAINT),
           drum(n + "_palm", 0.10, 0.10, (0, 0.15, 0), DARK, "y", 12)]
    for i, (x, z) in enumerate(((0.0, 0.11), (0.10, -0.06), (-0.10, -0.06))):
        out.append(block("%s_knuckle_%d" % (n, i), (0.07, 0.20, 0.07), (x * 1.2, 0.26, z * 1.2), STEEL,
                         rot=(-z * 2.0, 0, x * 2.0)))
        out.append(spike("%s_talon_%d" % (n, i), 0.045, 0.30, (x * 0.9, 0.48, z * 0.9), ALU if i else RUST, "y"))
    return out


def w_lance(n):
    """The rail lance: a long spear between two rails, a coil at its root."""
    return [block(n + "_breech", (0.18, 0.22, 0.18), (0, 0.05, 0), PAINT),
            drum(n + "_coil", 0.10, 0.10, (0, 0.20, 0), TRIM, "y", 12),
            block(n + "_rail_a", (0.04, 0.70, 0.05), (0, 0.55, 0.06), STEEL, chamfer=0.4),
            block(n + "_rail_b", (0.04, 0.70, 0.05), (0, 0.55, -0.06), STEEL, chamfer=0.4),
            drum(n + "_shaft", 0.028, 0.80, (0, 0.62, 0), ALU, "y", 8),
            spike(n + "_point", 0.06, 0.22, (0, 1.12, 0), ALU, "y"),
            block(n + "_clamp", (0.10, 0.06, 0.16), (0, 0.78, 0), RUST)]


def w_railgun(n):
    """The rail driver: a heavy boxed barrel with cooling ribs and a scope."""
    out = [block(n + "_receiver", (0.20, 0.30, 0.22), (0, 0.10, 0), PAINT),
           block(n + "_barrel", (0.12, 0.74, 0.14), (0, 0.60, 0), STEEL, chamfer=0.25),
           block(n + "_muzzle", (0.16, 0.10, 0.18), (0, 0.98, 0), DARK),
           drum(n + "_scope", 0.04, 0.26, (0, 0.20, 0.15), ALU, "y", 10),
           block(n + "_mag", (0.10, 0.16, 0.18), (0, 0.08, -0.17), PATCH)]
    for i in range(4):
        out.append(block("%s_rib_%d" % (n, i), (0.17, 0.035, 0.19), (0, 0.38 + i * 0.13, 0), TRIM if i == 1 else DARK, chamfer=0.4))
    return out


def w_scatter(n):
    """The scattergun: a short fat cluster of barrels in a drum."""
    out = [block(n + "_receiver", (0.20, 0.24, 0.22), (0, 0.06, 0), PAINT),
           drum(n + "_drum", 0.13, 0.12, (0, 0.20, 0), RUST, "y", 12),
           block(n + "_stock_plate", (0.22, 0.05, 0.10), (0, 0.0, 0.12), TRIM)]
    for i in range(5):
        a = i * math.tau / 5
        out.append(drum("%s_barrel_%d" % (n, i), 0.042, 0.34, (0.075 * math.cos(a), 0.42, 0.075 * math.sin(a)), STEEL, "y", 10))
    out.append(drum(n + "_band", 0.135, 0.05, (0, 0.54, 0), DARK, "y", 12))
    return out


def w_mortar(n):
    """The slag mortar: a fat tube tipped up on a yoke, a shell rack beside it."""
    tilt = -0.75
    out = [block(n + "_yoke", (0.24, 0.20, 0.16), (0, 0.06, 0), PAINT),
           drum(n + "_tube", 0.14, 0.52, (0, 0.26, 0.20), STEEL, "y", 14),
           drum(n + "_mouth", 0.16, 0.07, (0, 0.44, 0.37), RUST, "y", 14),
           drum(n + "_bore", 0.11, 0.075, (0, 0.445, 0.375), DARK, "y", 14),
           block(n + "_rack", (0.08, 0.20, 0.20), (0.17, 0.08, 0.02), PATCH)]
    for obj in out[1:4]:
        obj.rotation_euler = (tilt, 0, 0)
        obj.location = Vector((0, 0.10, 0.04)) - (obj.rotation_euler.to_matrix() @ Vector((0, 0.10, 0.04)))
        bake(obj)
    out += [ball("%s_shell_%d" % (n, i), 0.045, (0.17, 0.02 + i * 0.07, 0.14), ALU if i else TRIM) for i in range(3)]
    return out


def w_coil(n):
    """The pulse emitter: stacked rings round a core, a ball at the tip."""
    out = [block(n + "_base", (0.18, 0.18, 0.18), (0, 0.04, 0), PAINT),
           drum(n + "_core", 0.05, 0.50, (0, 0.34, 0), DARK, "y", 10),
           ball(n + "_tip", 0.085, (0, 0.63, 0), ALU)]
    for i in range(4):
        out.append(drum("%s_ring_%d" % (n, i), 0.12 - i * 0.015, 0.045, (0, 0.18 + i * 0.11, 0),
                        (ALU, TRIM, ALU, RUST)[i], "y", 14))
    out += [drum("%s_strut_%d" % (n, i), 0.014, 0.44, (0.11 * s, 0.34, 0), STEEL, "y", 6) for i, s in enumerate((1, -1))]
    return out


def w_scanner(n):
    """The spotter array: a dish on a short mast, a lamp and an aerial."""
    return [block(n + "_base", (0.18, 0.20, 0.16), (0, 0.05, 0), PAINT),
            drum(n + "_mast", 0.03, 0.26, (0, 0.24, 0), STEEL, "y", 8),
            ball(n + "_dish", 0.17, (0, 0.40, 0), ALU, 1.0),
            drum(n + "_feed", 0.025, 0.16, (0, 0.52, 0), DARK, "y", 8),
            ball(n + "_horn", 0.04, (0, 0.61, 0), TRIM),
            block(n + "_lamp", (0.08, 0.10, 0.08), (0.12, 0.12, 0.06), PATCH),
            drum(n + "_aerial", 0.012, 0.30, (-0.08, 0.06, 0.20), STEEL, sides=6)]


WEAPONS = {"hammer": (w_hammer, "melee", 1.0), "maul": (w_maul, "melee", 1.1), "saw": (w_saw, "melee", 1.0),
           "ripper": (w_ripper, "melee", 0.95), "lance": (w_lance, "gun", 0.85), "railgun": (w_railgun, "gun", 0.9),
           "scattergun": (w_scatter, "gun", 0.9), "mortar": (w_mortar, "gun", 1.0), "coil": (w_coil, "gun", 0.85),
           "scanner": (w_scanner, "gun", 0.8)}


def build_arm(part_id, part):
    make, rest, thick = WEAPONS[str(part.get("weapon_class", "hammer"))]
    arm = arm_of(part_id, str(part.get("maker", "kessler")), thick)
    pieces = make(part_id)
    # A flattened dish: squash along the mast after the fact (ball() squashes Z only).
    for obj in pieces:
        if obj.name.endswith("_dish"):
            obj.scale = (1.0, 0.35, 1.0)
            centre = sum((v.co for v in obj.data.vertices), Vector()) / len(obj.data.vertices)
            obj.location = centre - Vector((centre.x, centre.y * 0.35, centre.z))
            bake(obj)
    weapon = prim.join(pieces, part_id + "_weapon")
    # As the bridge does it: grown about the mount, drooped at the wrist, seated on it.
    weapon.scale = (msp.WEAPON_SCALE,) * 3
    weapon.rotation_euler = (msp.WEAPON_REST_PITCH[rest], 0.0, 0.0)
    weapon.location = WRIST
    fused = prim.join([arm, weapon], part_id)
    msp.apply_matrix([fused], msp.game_matrix(0.0))
    return fused


# --- Cores -------------------------------------------------------------------

def build_core(part_id, part):
    """A plate on the chest with the damage-type lens in it. The plate's shape is the maker's;
    a housing reaches back into the chest, so it sits on any frame."""
    n = part_id
    maker = str(part.get("maker", "kessler"))
    lx = 0.05 if pick(n, 3) % 2 else -0.05
    lens = drum(n + "_lens", 0.055, 0.035, (lx, 0.12, -0.045), EYE, "y")
    lens.data.materials.clear()
    lens.data.materials.append(msp.glow_material(str(part.get("damage_type", "kinetic"))))
    pieces = [block(n + "_housing", (0.30, 0.14, 0.25), (0, -0.02, 0), DARK),
              drum(n + "_rim", 0.082, 0.04, (lx, 0.10, -0.045), STEEL, "y"), lens]
    if maker == "kessler":      # a bolted slab
        pieces += [block(n + "_plate", (0.36, 0.07, 0.30), (0, 0.06, 0), ALU if pick(n) % 2 else PAINT, chamfer=0.35),
                   block(n + "_tab", (0.10, 0.03, 0.04), (-lx * 2, 0.10, -0.10), TRIM, chamfer=0.4)]
        pieces += bolts(n + "_bolt", [(x, 0.095, z) for x in (-0.14, 0.14) for z in (-0.11, 0.11)], STEEL, 0.03)
    elif maker == "cinder":     # a furnace door: round, barred
        pieces += [drum(n + "_plate", 0.18, 0.07, (0, 0.06, 0), PAINT, "y", 16),
                   drum(n + "_ring", 0.19, 0.03, (0, 0.04, 0), RUST, "y", 16)]
        pieces += [block("%s_bar_%d" % (n, i), (0.30, 0.03, 0.03), (0, 0.10, 0.06 + i * 0.05), DARK, chamfer=0.4) for i in range(2)]
        pieces.append(block(n + "_hinge", (0.05, 0.05, 0.16), (-0.19 if lx > 0 else 0.19, 0.07, 0), STEEL))
    elif maker == "arclight":   # a panel between two insulators
        pieces += [block(n + "_plate", (0.26, 0.07, 0.30), (0, 0.06, 0), PAINT, chamfer=0.3)]
        for i, x in enumerate((-0.16, 0.16)):
            pieces.append(drum("%s_post_%d" % (n, i), 0.035, 0.26, (x, 0.08, 0), DARK, sides=10))
            pieces += [drum("%s_disc_%d%d" % (n, i, j), 0.055, 0.03, (x, 0.08, -0.08 + j * 0.08), ALU if j != 1 else TRIM, sides=10)
                       for j in range(3)]
    else:                       # vektor: a hex breech with a feed box
        pieces += [drum(n + "_plate", 0.19, 0.07, (0, 0.06, 0), PAINT, "y", 6),
                   block(n + "_feed", (0.12, 0.08, 0.10), (-lx * 2.2, 0.09, 0.09), PATCH),
                   block(n + "_stripe", (0.30, 0.03, 0.035), (0, 0.10, -0.125), TRIM, chamfer=0.4)]
    fused = prim.join(pieces, part_id)
    msp.apply_matrix([fused], msp.game_matrix(0.0))
    return fused


# --- Modules -----------------------------------------------------------------
#
# Hung on the frame's back; every one reaches forward from its socket, so what shows is its
# -Y face. Hazard ochre ONLY on a module that can overdrive (the colour registry).

HAZARD = "zone:hazard"


def build_module(part_id, part):
    n = part_id
    kind = part_id[3:]
    pieces = [block(n + "_frame", (0.32, 0.20, 0.26), (0, 0.02, 0), skin(n + "_frame"))]
    b = -0.09      # the visible face
    if kind == "governor":      # radiator fins
        pieces += [block("%s_fin_%d" % (n, i), (0.30, 0.10, 0.025), (0, b - 0.03, -0.09 + i * 0.045), ALU if i % 2 else STEEL, chamfer=0.4) for i in range(5)]
    elif kind in ("bypass", "overclock", "capacitor"):
        count = 3 if kind == "overclock" else 2
        for i in range(count):
            x = (i - (count - 1) / 2) * (0.20 / max(count - 1, 1)) * (1.0 if count > 2 else 1.2)
            pieces.append(drum("%s_cell_%d" % (n, i), 0.055, 0.24, (x, b - 0.04, 0.0), ALU if kind == "capacitor" else DARK, sides=12))
            pieces.append(drum("%s_cellcap_%d" % (n, i), 0.06, 0.04, (x, b - 0.04, 0.125), TRIM, sides=12))
        pieces.append(block(n + "_hazard", (0.34, 0.06, 0.06), (0, b - 0.01, -0.10), HAZARD, chamfer=0.4))
        if kind == "bypass":
            pieces.append(drum(n + "_pipe", 0.03, 0.30, (0, b - 0.10, 0.06), RUST, "x", 10))
    elif kind in ("ablative", "reactive"):
        layers = 3 if kind == "ablative" else 1
        for i in range(layers):
            pieces.append(block("%s_layer_%d" % (n, i), (0.36 - i * 0.05, 0.05 if layers > 1 else 0.10, 0.30 - i * 0.05),
                                (0, b - 0.02 - i * 0.045, 0), (PAINT, PATCH, RUST)[i], chamfer=0.35))
        pieces += bolts(n + "_stud", [(x, b - (0.13 if layers > 1 else 0.08), z) for x in (-0.10, 0.10) for z in (-0.08, 0.08)], STEEL, 0.028)
    elif kind == "servo":
        pieces += [drum(n + "_gear_a", 0.10, 0.05, (-0.06, b - 0.03, 0.02), STEEL, "y", 10),
                   drum(n + "_gear_b", 0.07, 0.05, (0.09, b - 0.03, -0.05), RUST, "y", 8),
                   drum(n + "_axle_a", 0.03, 0.09, (-0.06, b - 0.04, 0.02), DARK, "y", 8),
                   drum(n + "_axle_b", 0.025, 0.09, (0.09, b - 0.04, -0.05), DARK, "y", 8)]
    elif kind == "coolant":
        pieces += [drum(n + "_tank", 0.085, 0.34, (0, b - 0.06, 0.03), ALU, "x", 14),
                   drum(n + "_band", 0.095, 0.04, (0, b - 0.06, 0.03), TRIM, "x", 14),
                   drum(n + "_hose", 0.025, 0.22, (0.13, b - 0.04, -0.09), DARK, "z", 8)]
    elif kind == "targeting":
        pieces += [ball(n + "_dish", 0.11, (0, b - 0.08, 0.04), ALU, 0.9),
                   drum(n + "_lens", 0.04, 0.05, (0, b - 0.17, 0.04), DARK, "y", 10),
                   drum(n + "_aerial", 0.012, 0.30, (0.12, b - 0.02, 0.22), STEEL, sides=6),
                   ball(n + "_tip", 0.025, (0.12, b - 0.02, 0.375), TRIM)]
    else:                       # scavenger: a magnet on a hook
        pieces += [block(n + "_magnet_l", (0.07, 0.16, 0.20), (-0.09, b - 0.06, -0.02), RUST),
                   block(n + "_magnet_r", (0.07, 0.16, 0.20), (0.09, b - 0.06, -0.02), RUST),
                   block(n + "_yoke", (0.25, 0.10, 0.07), (0, b - 0.03, 0.10), STEEL),
                   drum(n + "_spool", 0.05, 0.12, (0, b - 0.05, 0.17), ALU, "x", 10)]
    fused = prim.join(pieces, part_id)
    msp.apply_matrix([fused], msp.game_matrix(0.0))
    return fused


SLOT_BUILDERS = {"chassis": build_frame, "arm": build_arm, "core": build_core, "module": build_module}


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

    for part_id in sorted(parts):
        builder = SLOT_BUILDERS.get(str(parts[part_id].get("slot", "")))
        if builder is None or (only and part_id not in only.split(",")):
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
