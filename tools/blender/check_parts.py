"""Finds pieces that touch nothing -- floating geometry -- across the whole roster.

    blender --background --python tools/blender/check_parts.py
    blender --background --python tools/blender/check_parts.py -- --part ch_brute

Exit status is 1 if anything floats, so this can gate a build.

Why this exists
---------------
Floating pieces were "fixed" four times by looking at renders, and survived every time,
because a detached bolt hides behind the body at most camera angles and the angle it
hides at is usually the one you happen to be looking from. Eyeballing cannot find this
class of fault; a script can, exhaustively, in seconds.

How it works
------------
`join()` is monkeypatched so that every group of pieces about to be merged is inspected
first. Each piece's world-space bounding box is computed, an overlap graph is built, and
the connected components are counted. A part is sound when every piece belongs to ONE
component -- i.e. you can walk from any piece to any other through things that touch.
Anything in a second component is, by definition, hanging in space.

Bounding boxes are a conservative proxy: two boxes can overlap without their surfaces
touching, so this UNDER-reports rather than crying wolf. Everything it does report is
genuinely disconnected.
"""

import bpy
import importlib.util
import json
import math
import os
import sys

from mathutils import Vector
from mathutils.bvhtree import BVHTree

# Pieces closer than this count as touching, absorbing float error in the bevel and
# rotation maths. Deliberately tiny -- a real join overlaps by ~3 cm.
TOLERANCE = 0.004

## How close an attachment's surface must come to the chassis to count as seated. A real
## mount overlaps by centimetres; 8 mm is generous and still catches anything a player
## would read as a gap.
SEAT_TOLERANCE = 0.008

_groups = []


def load_builders():
    path = os.path.join(os.path.dirname(__file__), "make_parts.py")
    spec = importlib.util.spec_from_file_location("make_parts", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def world_box(obj):
    corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    low = Vector((min(c.x for c in corners), min(c.y for c in corners),
                  min(c.z for c in corners)))
    high = Vector((max(c.x for c in corners), max(c.y for c in corners),
                   max(c.z for c in corners)))
    return low, high


def boxes_touch(a, b):
    (a_low, a_high), (b_low, b_high) = a, b
    for axis in range(3):
        if a_low[axis] - TOLERANCE > b_high[axis] or b_low[axis] - TOLERANCE > a_high[axis]:
            return False
    return True


def components(objects):
    """Connected components over the 'bounding boxes touch' relation."""
    # `bound_box` and `matrix_world` are evaluated lazily. The builders create geometry
    # through operators that apply scale and modifiers, and without forcing the depsgraph
    # every box read here is one step stale -- which reports touching pieces as floating
    # and would have sent me chasing ~300 faults that do not exist.
    bpy.context.view_layer.update()
    boxes = [world_box(obj) for obj in objects]
    parent = list(range(len(objects)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for i in range(len(objects)):
        for j in range(i + 1, len(objects)):
            if boxes_touch(boxes[i], boxes[j]):
                root_i, root_j = find(i), find(j)
                if root_i != root_j:
                    parent[root_i] = root_j

    groups = {}
    for index in range(len(objects)):
        groups.setdefault(find(index), []).append(objects[index])
    return list(groups.values())


def patch_join(mp):
    """Wraps `join` so each group of pieces is inspected before it is merged away."""
    original = mp.join

    # `**kwargs` rather than a fixed signature: this wrapper must survive `join` gaining
    # an argument. It did, and the checker died mid-roster with a TypeError that read as
    # a clean run right up until the summary line failed to appear.
    def wrapped(objects, name, **kwargs):
        live = [o for o in objects if o is not None]
        if len(live) > 1:
            # Names are captured HERE, while the objects still exist. `join` frees them,
            # and reading `.name` afterwards raises "StructRNA has been removed".
            _groups.append((name, [[o.name for o in comp] for comp in components(live)]))
        return original(objects, name, **kwargs)

    mp.join = wrapped


def bvh_of(objects):
    """A BVH over the world-space surface of several objects."""
    verts = []
    polys = []
    for obj in objects:
        matrix = obj.matrix_world
        base = len(verts)
        verts.extend([matrix @ v.co for v in obj.data.vertices])
        for polygon in obj.data.polygons:
            polys.append([base + i for i in polygon.vertices])
    return BVHTree.FromPolygons(verts, polys)


def surface_gap(piece, tree):
    """Smallest distance from any vertex of `piece` to the surface in `tree`.

    Bounding boxes are useless for this: an arm's box can overlap a torso's box while
    the two surfaces are 10 cm apart, which is precisely the gap a player sees and the
    reason the AABB pass reported a roster that 'all seats' while parts visibly hung in
    the air. This measures the actual geometry."""
    matrix = piece.matrix_world
    smallest = 1e9
    for vertex in piece.data.vertices:
        found = tree.find_nearest(matrix @ vertex.co)
        if found is not None and found[3] is not None:
            smallest = min(smallest, found[3])
    return smallest


def mesh_objects(obj):
    """An object and any mesh children. A chassis is a root plus its two leg limbs."""
    out = [obj] if obj.type == "MESH" else []
    for child in obj.children:
        if child.type == "MESH":
            out.append(child)
    return out


def check_assembly(mp, parts):
    """Does every ATTACHMENT actually touch the chassis it is socketed to?

    `components()` only looks inside one `join` group, so it proves a chassis is a
    connected chassis and an arm is a connected arm -- and says nothing about whether the
    arm reaches the shoulder. That gap is exactly where a construct comes apart, because
    the socket is a single authored coordinate and the geometry around it moved every
    time a proportion was retuned.

    Any arm can be bolted to any chassis, so this checks the whole matrix rather than one
    representative loadout: a gap that only appears on the narrowest frame is still a gap
    a player will see.
    """
    chassis_ids = sorted(p for p, d in parts.items() if d.get("slot") == "chassis")
    faults = []

    for chassis_id in chassis_ids:
        mp.clear_scene()
        root = mp.BUILDERS["chassis"](chassis_id, parts[chassis_id])
        sockets = {c.name: c.location.copy() for c in root.children if c.type == "EMPTY"}
        bpy.context.view_layer.update()
        chassis_tree = bvh_of(mesh_objects(root))

        for attach_id in sorted(parts):
            definition = parts[attach_id]
            slot = definition.get("slot")
            socket_names = {
                "core": ["socket_core"],
                "arm": ["socket_arm_l", "socket_arm_r"],
                "module": ["socket_module"],
            }.get(slot)
            if socket_names is None:
                continue

            for socket_name in socket_names:
                if socket_name not in sockets:
                    faults.append((chassis_id, attach_id, socket_name, "no socket"))
                    continue
                piece = mp.BUILDERS[slot](attach_id, definition)
                piece.location = sockets[socket_name]
                if socket_name == "socket_arm_l":
                    # The runtime mirrors the left arm; a gap can exist on one side only.
                    piece.scale = (-1, 1, 1)
                bpy.context.view_layer.update()
                gap = surface_gap(piece, chassis_tree)
                if gap > SEAT_TOLERANCE:
                    faults.append((chassis_id, attach_id, socket_name,
                                   "gap %.0f mm" % (gap * 1000.0)))
                bpy.data.objects.remove(piece, do_unlink=True)

        # The chassis' OWN pieces against each other. The legs are joined and parented
        # separately so they can be animated, which means nothing so far has ever checked
        # that a leg actually meets the pelvis -- `components()` only looks inside one
        # join group, and the loop above only compares attachments to the whole chassis.
        limbs = mesh_objects(root)
        if len(limbs) > 1:
            body = limbs[0]
            body_tree = bvh_of([body])
            for limb in limbs[1:]:
                gap = surface_gap(limb, body_tree)
                if gap > SEAT_TOLERANCE:
                    faults.append((chassis_id, limb.name, "limb",
                                   "gap %.0f mm" % (gap * 1000.0)))

    print("\n=== attachments that do not reach their chassis ===")
    if not faults:
        print("  all attachments seat on every chassis")
    else:
        by_socket = {}
        for chassis_id, attach_id, socket_name, why in faults:
            by_socket.setdefault((socket_name, why), []).append(f"{chassis_id}/{attach_id}")
        for (socket_name, why), pairs in sorted(by_socket.items()):
            print(f"  {socket_name:16s} {why:10s} {len(pairs):4d}  e.g. "
                  + ", ".join(pairs[:4]))
    return len(faults)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = None
    for index, arg in enumerate(argv):
        if arg == "--part" and index + 1 < len(argv):
            only = argv[index + 1]

    mp = load_builders()
    patch_join(mp)

    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    parts = {}
    parts_dir = os.path.join(root_dir, "data", "parts")
    for name in sorted(os.listdir(parts_dir)):
        if name.endswith(".json"):
            with open(os.path.join(parts_dir, name)) as handle:
                for entry in json.load(handle):
                    parts[entry["id"]] = entry

    total_floaters = 0
    print("\n=== floating geometry ===")
    for part_id, definition in sorted(parts.items()):
        if only and part_id != only:
            continue
        builder = mp.BUILDERS.get(definition.get("slot"))
        if builder is None:
            continue

        _groups.clear()
        mp.clear_scene()
        builder(part_id, definition)

        faults = []
        for group_name, comps in _groups:
            if len(comps) <= 1:
                continue
            # The largest component is the part; everything else is floating.
            comps.sort(key=len, reverse=True)
            for stray in comps[1:]:
                faults.extend(stray)

        if faults:
            total_floaters += len(faults)
            print(f"  {part_id:16s} {len(faults):3d} floating: "
                  + ", ".join(sorted(faults)[:8])
                  + (" ..." if len(faults) > 8 else ""))
        else:
            print(f"  {part_id:16s}  ok")

    print(f"\n{total_floaters} floating pieces across the roster")

    # The second, harder question: does a construct hold together once ASSEMBLED?
    total_floaters += check_assembly(mp, parts)

    if total_floaters:
        sys.exit(1)


if __name__ == "__main__":
    main()
