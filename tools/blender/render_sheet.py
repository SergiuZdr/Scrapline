"""Renders every part into one contact sheet, for reviewing silhouettes at a glance.

    blender --background --python tools/blender/render_sheet.py -- --out art/preview/sheet.png
    blender --background --python tools/blender/render_sheet.py -- --slot chassis --assembled

`--assembled` builds whole constructs from the socket data instead of showing loose
parts, which is the only honest way to judge whether the modular system reads: a part
can look fine alone and terrible bolted to a frame.

Silhouette is the thing being checked here. A construct has to be identifiable at
200 px on a phone, so this renders small on purpose.
"""

import bpy
import importlib.util
import math
import os
import sys


def load_builders():
    """Reuse make_parts.py rather than duplicating the geometry code."""
    path = os.path.join(os.path.dirname(__file__), "make_parts.py")
    spec = importlib.util.spec_from_file_location("make_parts", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def setup_scene(mp):
    mp.clear_scene()
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("W") if scene.world is None else scene.world
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.035, 0.042, 0.055, 1)

    # Key, fill and rim. The rim is what separates a dark machine from a dark
    # background, which is the whole readability problem in this art style.
    key = _light("KeySun", "SUN", (4, -5, 7), 4.5, (1.0, 0.94, 0.85))
    key.rotation_euler = (math.radians(52), 0, math.radians(38))
    fill = _light("Fill", "SUN", (-5, -3, 3), 1.4, (0.55, 0.68, 1.0))
    fill.rotation_euler = (math.radians(70), 0, math.radians(-60))
    rim = _light("Rim", "SUN", (0, 6, 4), 2.6, (0.75, 0.88, 1.0))
    rim.rotation_euler = (math.radians(115), 0, math.radians(180))


def _light(name, kind, location, energy, colour):
    bpy.ops.object.light_add(type=kind, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.energy = energy
    obj.data.color = colour
    return obj


def place(obj, x, y):
    obj.location.x += x
    obj.location.y += y


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = "art/preview/sheet.png"
    slot_filter = None
    assembled = False
    for i, arg in enumerate(argv):
        if arg == "--out" and i + 1 < len(argv):
            out = argv[i + 1]
        elif arg == "--slot" and i + 1 < len(argv):
            slot_filter = argv[i + 1]
        elif arg == "--assembled":
            assembled = True

    mp = load_builders()
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    parts = mp.load_parts(root_dir)
    setup_scene(mp)

    frame_material = mp.flat_material("mat_frame", (0.52, 0.55, 0.59))

    if assembled:
        items = _assemble_all(mp, parts, frame_material)
    else:
        items = _loose_parts(mp, parts, frame_material, slot_filter)

    if not items:
        print("nothing to render")
        return

    columns = min(5, len(items))
    spacing = 2.1 if assembled else 1.5
    for index, obj in enumerate(items):
        place(obj, (index % columns - (columns - 1) / 2) * spacing,
              -(index // columns) * spacing)

    rows = (len(items) + columns - 1) // columns
    _frame_camera(items, assembled)

    scene = bpy.context.scene
    # Square-ish cells. Assembled constructs are tall, so they need the height.
    cell = 340 if assembled else 260
    scene.render.resolution_x = cell * columns
    scene.render.resolution_y = int(cell * rows * (1.35 if assembled else 1.15))
    scene.render.filepath = os.path.join(root_dir, out)
    bpy.ops.render.render(write_still=True)
    print(f"rendered {len(items)} items -> {out}")


def _loose_parts(mp, parts, frame_material, slot_filter):
    items = []
    for part_id, part in sorted(parts.items(), key=lambda kv: (kv[1].get("slot", ""), kv[0])):
        slot = part.get("slot")
        if slot_filter and slot != slot_filter:
            continue
        builder = mp.BUILDERS.get(slot)
        if builder is None:
            continue
        obj = builder(part_id, part)
        if not obj.data.materials:
            mp.apply_material(obj, frame_material)
        # Sockets are construction data, not something to look at.
        for child in list(obj.children):
            bpy.data.objects.remove(child, do_unlink=True)
        items.append(obj)
    return items


def _assemble_all(mp, parts, frame_material):
    """One construct per chassis, wearing a representative loadout, built through the
    same socket lookup the game uses. If this looks wrong, the game will look wrong."""
    chassis_ids = sorted(k for k, v in parts.items() if v.get("slot") == "chassis")
    arms = sorted(k for k, v in parts.items() if v.get("slot") == "arm")
    cores = sorted(k for k, v in parts.items() if v.get("slot") == "core")
    modules = sorted(k for k, v in parts.items() if v.get("slot") == "module")

    items = []
    for index, chassis_id in enumerate(chassis_ids):
        frame = mp.build_chassis(chassis_id, parts[chassis_id])
        mp.apply_material(frame, frame_material)

        sockets = {child.name: child.location.copy() for child in frame.children}
        loadout = {
            "socket_core": cores[index % len(cores)],
            "socket_arm_l": arms[index % len(arms)],
            "socket_arm_r": arms[(index + 2) % len(arms)],
            "socket_module": modules[index % len(modules)],
        }
        attached = [frame]
        for socket_name, part_id in loadout.items():
            if socket_name not in sockets:
                continue
            builder = mp.BUILDERS[parts[part_id]["slot"]]
            piece = builder(part_id, parts[part_id])
            if not piece.data.materials:
                mp.apply_material(piece, frame_material)
            piece.location = sockets[socket_name]
            # Arms mirror on the left so the construct is not lopsided.
            if socket_name == "socket_arm_l":
                piece.scale.x = -1
            attached.append(piece)

        for child in list(frame.children):
            bpy.data.objects.remove(child, do_unlink=True)
        items.append(mp.join(attached, f"unit_{chassis_id}"))
    return items


def _frame_camera(items, assembled):
    """Frames from the actual bounding box of what was placed. Deriving it from grid
    maths instead is how the first attempt rendered a whole row off-screen."""
    import mathutils
    # Blender caches matrix_world until the depsgraph is evaluated, so bounds taken
    # straight after moving objects describe where they USED to be. This one line is
    # the difference between a framed sheet and a close-up of nothing.
    bpy.context.view_layer.update()

    min_v = mathutils.Vector((1e9, 1e9, 1e9))
    max_v = mathutils.Vector((-1e9, -1e9, -1e9))
    for obj in items:
        for corner in obj.bound_box:
            world = obj.matrix_world @ mathutils.Vector(corner)
            min_v = mathutils.Vector((min(min_v[i], world[i]) for i in range(3)))
            max_v = mathutils.Vector((max(max_v[i], world[i]) for i in range(3)))

    centre = (min_v + max_v) / 2.0
    span_x = max_v.x - min_v.x
    span_y = max_v.y - min_v.y
    span_z = max_v.z - min_v.z

    distance = max(span_x, span_y, span_z) * 1.6 + 4.0
    pitch = math.radians(58)

    bpy.ops.object.camera_add()
    camera = bpy.context.active_object
    camera.data.type = "ORTHO"
    # Orthographic so every part renders at the same scale and can be compared
    # honestly; perspective would make the back row look smaller than it is.
    # Generous and simple. A clever ortho_scale that is slightly wrong crops the sheet
    # and wastes a render cycle; an over-wide one only wastes pixels.
    camera.data.ortho_scale = max(span_x, span_y, span_z) * 1.30 + 1.2
    camera.rotation_euler = (pitch, 0, 0)
    camera.location = (
        centre.x,
        centre.y - distance * math.sin(pitch),
        centre.z + distance * math.cos(pitch),
    )
    bpy.context.scene.camera = camera
    _ = assembled
