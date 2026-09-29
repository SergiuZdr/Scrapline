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

## One chamfer everywhere a box has an edge, as a fraction of its smallest side. A fixed
## width made small pieces all chamfer and no face, and big ones read as sharp.
CHAMFER = 0.16


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


def soften(obj, angle=40.0):
    """Round things shade smooth, their caps stay sharp: the toon ramp bands a smooth drum
    the way an inker shades a cylinder, and a 16-facet drum would band as stripes."""
    obj.data.shade_smooth()
    obj.data.set_sharp_from_angle(angle=math.radians(angle))
    return obj


def block(name, size, at, material, rot=(0.0, 0.0, 0.0), taper=None, chamfer=CHAMFER):
    width = min(size) * chamfer
    if taper is None:
        obj = prim.box(name, size, location=at, rotation=rot, material=material,
                       bevel_width=width, segments=1)
    else:
        obj = prim.taper_box(name, size, top_scale=taper, location=at, rotation=rot,
                             material=material, bevel_width=width, segments=1)
    return bake(obj)


AXIS = {"x": (0.0, math.pi / 2, 0.0), "y": (math.pi / 2, 0.0, 0.0), "z": (0.0, 0.0, 0.0)}


def drum(name, radius, depth, at, material, axis="z", sides=16):
    obj = prim.cylinder(name, radius, depth, location=at, rotation=AXIS[axis],
                        vertices=sides, material=material)
    return soften(bake(obj))


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
    materials.apply(obj, material)
    return obj


def along(a, b):
    """(centre, length, x-rotation) of a box laid from `a` to `b` in the YZ plane."""
    dy, dz = b[1] - a[1], b[2] - a[2]
    centre = tuple((a[i] + b[i]) * 0.5 for i in range(3))
    # +theta about X tips -Z toward +Y.
    return centre, math.hypot(dy, dz), math.atan2(dy, -dz)


# --- The Brute ---------------------------------------------------------------
#
# Read off the concept sheet: a wide box of a chest, flat-topped, with one bolted plate on
# its front (the core) and a small domed head with one big lens sunk into the top; square
# pauldrons as big as the chest's upper corners; short thick legs on wide flat feet;
# a saw and a sledge carried low. Generator units throughout (the robot stands ~1.7 tall,
# pelvis at z=0, facing +Y); `msp.game_matrix` takes it to the game.

def brute_body(part_id):
    pieces = [
        # The chest: wider at the shoulders than at the waist.
        block(part_id + "_chest", (0.60, 0.46, 0.58), (0.0, 0.0, 0.47), PAINT,
              taper=(1.06, 1.0), chamfer=0.14),
        # The core's frame: the one big feature on the chest (CLAUDE.md), dark and recessed
        # so the plate the core bolts in reads as a separate object.
        block(part_id + "_bezel", (0.42, 0.05, 0.36), (0.0, 0.225, 0.47), DARK),
        # Shoulder bosses, so an arm without a pauldron still has something to sit against.
        drum(part_id + "_boss_l", 0.075, 0.06, (0.325, 0.0, config.TORSO_SHOULDER_Z), DARK, "x"),
        drum(part_id + "_boss_r", 0.075, 0.06, (-0.325, 0.0, config.TORSO_SHOULDER_Z), DARK, "x"),
        # Side panels, one line each at the flank.
        block(part_id + "_flank_l", (0.03, 0.28, 0.22), (0.30, 0.0, 0.36), METAL),
        block(part_id + "_flank_r", (0.03, 0.28, 0.22), (-0.30, 0.0, 0.36), METAL),
        # Waist: a narrower block in ground-contact rust, as the concept's orange hips.
        block(part_id + "_pelvis", (0.34, 0.28, 0.24), (0.0, 0.0, 0.07), RUST,
              taper=(1.15, 1.05)),
        # The head sits ON the chest, not above the shoulders on a neck.
        drum(part_id + "_collar", 0.17, 0.05, (0.0, 0.01, 0.765), DARK),
        drum(part_id + "_head", 0.135, 0.15, (0.0, 0.01, 0.84), PAINT),
        drum(part_id + "_crown", 0.10, 0.04, (0.0, 0.01, 0.93), METAL),
        # One big eye: the team's colour, the strongest read at distance.
        drum(part_id + "_eye_rim", 0.085, 0.05, (0.0, 0.13, 0.845), DARK, "y"),
        drum(part_id + "_eye", 0.062, 0.05, (0.0, 0.15, 0.845), EYE, "y"),
        # The BACK is the side the player sees most: the board's camera stands behind the
        # crew. A pack with two stacks rising past the shoulders gives it a silhouette of its
        # own, and the module hangs on the pack (`BACK_SOCKET`).
        block(part_id + "_pack", (0.42, 0.14, 0.40), (0.0, -0.28, 0.50), METAL),
        drum(part_id + "_stack_l", 0.055, 0.30, (0.14, -0.30, 0.78), DARK, sides=12),
        drum(part_id + "_stack_r", 0.055, 0.30, (-0.14, -0.30, 0.78), DARK, sides=12),
        drum(part_id + "_cap_l", 0.068, 0.045, (0.14, -0.30, 0.94), RUST, sides=12),
        drum(part_id + "_cap_r", 0.068, 0.045, (-0.14, -0.30, 0.94), RUST, sides=12),
    ]
    return prim.join(pieces, part_id)


## Where the module hangs: on the back of the pack. The bridge's formula puts it at the
## torso's back face, which this chest is deeper than -- a module there was buried in it.
## Every module is modelled reaching FORWARD from its socket, so the socket sits proud.
BACK_SOCKET = (0.0, -0.40, 0.45)


def brute_leg(name):
    """One leg, hip at the origin, foot planted outboard (+X) and knee loaded forward."""
    knee = (0.08, config.KNEE_FORWARD, config.LEG_KNEE_Z + 0.02)
    foot_x = 0.105
    sole = -config.LEG_LENGTH
    pieces = [
        drum(name + "_hip", 0.10, 0.13, (0.05, 0.0, 0.0), DARK, "x"),
        block(name + "_thigh", (0.25, 0.27, 0.32), (0.075, 0.0, -0.20), PAINT,
              taper=(1.06, 1.04)),
        drum(name + "_knee", 0.085, 0.21, knee, DARK, "x"),
        block(name + "_kneepad", (0.19, 0.08, 0.18), (knee[0], knee[1] + 0.10, knee[2]),
              METAL, rot=(-0.15, 0.0, 0.0), taper=(0.8, 1.0)),
        # Two-tone below the knee, as the concept's: a painted shin into a heavier metal
        # boot. A leg of one colour top to bottom read as a stack of boxes.
        block(name + "_shin", (0.26, 0.28, 0.22), (0.09, 0.03, -0.53), PAINT,
              taper=(0.9, 0.88)),
        block(name + "_boot", (0.30, 0.33, 0.17), (foot_x, 0.04, -0.705), METAL,
              taper=(0.9, 0.9)),
        # A wide flat foot: the overhang past the boot is what plants a heavy frame.
        block(name + "_foot", (0.31, 0.47, 0.07), (foot_x, 0.07, sole + 0.045), PAINT,
              taper=(0.86, 0.8)),
        block(name + "_toe", (0.31, 0.12, 0.06), (foot_x, 0.28, sole + 0.03), RUST,
              taper=(0.9, 0.5)),
        block(name + "_sole", (0.32, 0.48, 0.02), (foot_x, 0.07, sole + 0.01), RUST),
    ]
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
        (0.0, half_width * msp.CORE_FRONT * 3.0, config.TORSO_HEIGHT * msp.CORE_HEIGHT), lift, bulk))
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
    """Pauldron, a short upper arm, a gauntlet of a forearm. The pauldron is as big as the
    chest's corner (the concept), seated OVER the joint and in the part's livery."""
    upper, upper_len, upper_rot = along((0.0, 0.0, -0.02), ELBOW)
    fore, fore_len, fore_rot = along(ELBOW, WRIST)
    pieces = [
        drum(part_id + "_joint", 0.085, 0.14, (-0.02, 0.0, 0.0), DARK, "x"),
        block(part_id + "_pauldron", (0.30, 0.36, 0.25), (-0.07, 0.0, 0.07), PAINT,
              taper=(0.88, 0.9), chamfer=0.18),
        block(part_id + "_pauldron_rim", (0.32, 0.38, 0.05), (-0.07, 0.0, -0.065), METAL),
        block(part_id + "_upper", (0.13, 0.14, upper_len), upper, METAL, rot=(upper_rot, 0, 0)),
        drum(part_id + "_elbow", 0.075, 0.16, ELBOW, DARK, "x"),
        block(part_id + "_forearm", (0.20, 0.22, fore_len), fore, PAINT,
              rot=(fore_rot, 0.0, 0.0), taper=(0.82, 0.82)),
    ]
    return prim.join(pieces, part_id + "_arm")


def hammer(part_id):
    """A sledge: a haft and a banded block. Weapon space: mount at the origin, +Y forward."""
    pieces = [
        block(part_id + "_grip", (0.11, 0.11, 0.11), (0.0, 0.02, 0.0), DARK),
        drum(part_id + "_haft", 0.035, 0.34, (0.0, 0.19, 0.0), METAL, "y", sides=10),
        block(part_id + "_head", (0.20, 0.20, 0.36), (0.0, 0.40, 0.0), ALU, chamfer=0.18),
        block(part_id + "_band_a", (0.215, 0.215, 0.045), (0.0, 0.40, 0.10), DARK),
        block(part_id + "_band_b", (0.215, 0.215, 0.045), (0.0, 0.40, -0.10), DARK),
    ]
    return prim.join(pieces, part_id + "_weapon")


def saw(part_id):
    """A toothed disc on a bracket, its upper half under a guard."""
    centre_y, radius, teeth = 0.27, 0.215, 12
    outline = []
    for i in range(teeth * 2):
        # A raked tooth: the tip leads, the gullet trails.
        a = 2.0 * math.pi * (i + (0.25 if i % 2 == 0 else 0.0)) / (teeth * 2)
        r = radius + (0.045 if i % 2 == 0 else 0.0)
        outline.append((centre_y + r * math.cos(a), r * math.sin(a)))
    blade = plate_x(part_id + "_blade", outline, 0.025, 0.0, ALU)
    guard_outline = [(centre_y, 0.0)]
    for i in range(9):
        a = math.radians(40.0 + i * 15.0)
        guard_outline.append((centre_y + 0.275 * math.cos(a), 0.275 * math.sin(a)))
    guard = plate_x(part_id + "_guard", guard_outline, 0.03, -0.035, PAINT)
    pieces = [
        block(part_id + "_motor", (0.15, 0.16, 0.16), (0.0, 0.02, 0.0), PAINT),
        block(part_id + "_bracket", (0.07, 0.26, 0.08), (0.0, 0.15, 0.0), DARK),
        blade,
        guard,
        drum(part_id + "_hub", 0.065, 0.07, (0.0, centre_y, 0.0), DARK, "x"),
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
    """The concept's bolted chest plate, with the damage-type lens in the middle of it.

    A housing reaches back into the chest, so the plate sits flush on any frame's socket."""
    damage = str(part.get("damage_type", "kinetic"))
    lens = drum(part_id + "_lens", 0.058, 0.035, (0.0, 0.115, 0.0), EYE, "y")
    lens.data.materials.clear()
    lens.data.materials.append(msp.glow_material(damage))
    pieces = [
        block(part_id + "_housing", (0.30, 0.14, 0.25), (0.0, -0.02, 0.0), DARK),
        block(part_id + "_plate", (0.34, 0.06, 0.28), (0.0, 0.06, 0.0), ALU, chamfer=0.3),
        drum(part_id + "_rim", 0.085, 0.03, (0.0, 0.10, 0.0), DARK, "y"),
        lens,
    ]
    for x in (-0.125, 0.125):
        for z in (-0.095, 0.095):
            pieces.append(drum("%s_bolt_%d_%d" % (part_id, x > 0, z > 0), 0.03, 0.03,
                               (x, 0.095, z), DARK, "y", sides=8))
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
