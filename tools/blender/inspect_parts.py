"""Renders a TURNAROUND of a part or an assembled construct, for judging geometry.

    blender --background --python tools/blender/inspect_parts.py -- --part ch_brute
    blender --background --python tools/blender/inspect_parts.py -- --assembled ch_brute
    blender --background --python tools/blender/inspect_parts.py -- --part ar_pulse --angles 8

Why this exists
---------------
A single three-quarter render is not an inspection. A detached shoulder, a strut that
misses its joint, a plate floating a centimetre off the chest -- every one of those hides
at some angle, and the angle they hide at is usually the pretty one. Parts were signed
off from one view of one part and shipped with all of those faults intact.

So: six views, evenly spaced, at a fixed elevation, every part. Composed into one strip
by `compose_sheet.py` so a whole turnaround is a single image to look at.

`--assembled` bolts the attachments onto the chassis through the same socket lookup the
game uses, because a part can look correct alone and wrong the moment something is
mounted to it -- and the mount is exactly where these faults live.
"""

import bpy
import importlib.util
import json
import math
import os
import sys

from mathutils import Vector


def load_builders():
    path = os.path.join(os.path.dirname(__file__), "make_parts.py")
    spec = importlib.util.spec_from_file_location("make_parts", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_parts(root):
    parts = {}
    parts_dir = os.path.join(root, "data", "parts")
    for name in sorted(os.listdir(parts_dir)):
        if name.endswith(".json"):
            with open(os.path.join(parts_dir, name)) as handle:
                for entry in json.load(handle):
                    parts[entry["id"]] = entry
    return parts


def pick(parts, slot, index=0):
    ids = sorted(p for p, d in parts.items() if d.get("slot") == slot)
    return ids[index % len(ids)] if ids else None


def build_subject(mp, parts, part_id, assembled):
    """Returns the list of objects making up the subject."""
    definition = parts[part_id]
    builder = mp.BUILDERS[definition["slot"]]
    root = builder(part_id, definition)
    if not assembled or definition["slot"] != "chassis":
        return [root]

    # Same socket contract the runtime reads.
    sockets = {child.name: child.location.copy() for child in root.children}
    loadout = {
        "socket_core": pick(parts, "core"),
        "socket_arm_l": pick(parts, "arm"),
        "socket_arm_r": pick(parts, "arm", 2),
        "socket_module": pick(parts, "module"),
    }
    objects = [root]
    for socket_name, attach_id in loadout.items():
        if socket_name not in sockets or attach_id is None:
            continue
        attach_def = parts[attach_id]
        piece = mp.BUILDERS[attach_def["slot"]](attach_id, attach_def)
        piece.location = sockets[socket_name]
        if socket_name == "socket_arm_l":
            piece.scale = (-1, 1, 1)
        objects.append(piece)
    return objects


def bounds_of(objects):
    lows = []
    highs = []
    for obj in objects:
        for corner in obj.bound_box:
            point = obj.matrix_world @ Vector(corner)
            lows.append(point)
            highs.append(point)
    min_z = min(p.z for p in lows)
    max_z = max(p.z for p in highs)
    radius = max(max(abs(p.x) for p in lows), max(abs(p.y) for p in lows), 0.25)
    return min_z, max_z, radius


def setup_lighting(target):
    """Neutral and bright. A moody key hides precisely the seams being hunted for."""
    for location, energy, size in (((4, -4, 5), 6.0, 3.0), ((-5, -2, 2), 2.5, 4.0),
                                   ((0, 5, 3), 3.5, 3.0), ((0, 0, -4), 1.2, 4.0)):
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.active_object
        light.data.energy = energy * 50
        light.data.size = size
        light.constraints.new("TRACK_TO").target = target

    world = bpy.context.scene.world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.20, 0.21, 0.23, 1)


def render_thumbnails(mp, parts, root_dir, out_dir, size):
    """One card thumbnail per part, on transparency.

    The loadout screen shows parts as cards, and a card without a picture is a row of
    text with a border -- which is the interface the 3D roster was supposed to replace.
    Rendered here rather than in-engine because forty live SubViewports is not something
    to put on a phone."""
    target = os.path.join(root_dir, out_dir)
    os.makedirs(target, exist_ok=True)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    # Transparent, so a card can sit on any background the UI happens to use.
    scene.render.film_transparent = True

    for part_id, definition in sorted(parts.items()):
        builder = mp.BUILDERS.get(definition.get("slot"))
        if builder is None:
            continue
        mp.clear_scene()
        obj = builder(part_id, definition)

        min_z, max_z, radius = bounds_of([obj])
        height = max(0.30, max_z - min_z)
        centre = (min_z + max_z) * 0.5

        bpy.ops.object.empty_add(location=(0, 0, centre))
        focus = bpy.context.active_object
        setup_lighting(focus)

        distance = max(height * 2.0, radius * 3.4)
        bpy.ops.object.camera_add(
            location=(distance * 0.62, -distance * 0.78, centre + height * 0.30))
        camera = bpy.context.active_object
        camera.data.lens = 62
        camera.constraints.new("TRACK_TO").target = focus
        scene.camera = camera

        scene.render.filepath = os.path.join(target, f"{part_id}.png")
        bpy.ops.render.render(write_still=True)
        print(f"  thumb {part_id}")

    print(f"\nthumbnails -> {out_dir}")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    part_id = None
    assembled = False
    angles = 6
    yaw_offset = 0.0
    keep = False
    out_dir = "art/preview/turn"
    for index, arg in enumerate(argv):
        if arg == "--yaw" and index + 1 < len(argv):
            yaw_offset = float(argv[index + 1])
        elif arg == "--keep":
            # Do not clear the output directory: lets a shell loop accumulate one view
            # per part into a single folder for a roster grid.
            keep = True
        if arg == "--part" and index + 1 < len(argv):
            part_id = argv[index + 1]
        elif arg == "--assembled" and index + 1 < len(argv):
            part_id = argv[index + 1]
            assembled = True
        elif arg == "--angles" and index + 1 < len(argv):
            angles = int(argv[index + 1])
        elif arg == "--out" and index + 1 < len(argv):
            out_dir = argv[index + 1]

    mp = load_builders()
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    parts = load_parts(root_dir)

    if "--thumbs" in argv:
        render_thumbnails(mp, parts, root_dir, "art/thumbs", 224)
        return

    if part_id not in parts:
        print(f"unknown part: {part_id}")
        return

    mp.clear_scene()
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 420
    scene.render.resolution_y = 560
    scene.render.film_transparent = False

    objects = build_subject(mp, parts, part_id, assembled)
    min_z, max_z, radius = bounds_of(objects)
    height = max(0.4, max_z - min_z)

    # An empty at the subject's centre: the camera and every light track it, so framing
    # holds at every angle instead of drifting as the camera swings round.
    bpy.ops.object.empty_add(location=(0, 0, (min_z + max_z) * 0.5))
    focus = bpy.context.active_object
    setup_lighting(focus)

    distance = max(height * 2.2, radius * 4.0)
    bpy.ops.object.camera_add()
    camera = bpy.context.active_object
    camera.data.lens = 60
    camera.constraints.new("TRACK_TO").target = focus
    scene.camera = camera

    target_dir = os.path.join(root_dir, out_dir)
    os.makedirs(target_dir, exist_ok=True)
    if not keep:
        for existing in os.listdir(target_dir):
            if existing.endswith(".png"):
                os.remove(os.path.join(target_dir, existing))

    for step in range(angles):
        # `--yaw` offsets the whole sweep, so `--angles 1 --yaw 40` gives one
        # three-quarter view -- the frame used for roster grids, where every construct
        # has to be shot from the same angle to be comparable.
        yaw = math.tau * step / angles + math.radians(yaw_offset)
        camera.location = (
            math.sin(yaw) * distance,
            -math.cos(yaw) * distance,
            (min_z + max_z) * 0.5 + height * 0.30)
        stem = f"{part_id}_{step:02d}" if keep else f"{step:02d}"
        scene.render.filepath = os.path.join(target_dir, f"{stem}.png")
        bpy.ops.render.render(write_still=True)
        print(f"  angle {step * 360 // angles:3d}deg -> {step:02d}.png")

    print(f"\nturnaround of {part_id}{' (assembled)' if assembled else ''}: "
          f"{angles} views in {out_dir}")


if __name__ == "__main__":
    main()
