"""Turns a GENERATED machine part (TRELLIS, `tools/gen3d/next_part.sh`) into a part the game can
bolt together (045): the part contract of `make_ink_parts.py`, kept by a model nobody scripted.

    blender --background --python tools/blender/rig_generated_part.py -- \
        --in tools/gen3d/raw/parts/ch_brute.glb --spec tools/gen3d/parts/ch_brute.json \
        --out art/parts_gen/ch_brute.glb [--preview shots/045_ch_brute]

Each slot was generated ALONE (a frame without arms, an arm without a frame), so nothing has to
be cut apart between slots -- only a frame's legs, which the rig swings at the hips. What a part
needs, by slot (numbers in metres, in the game's frame: forward is -Y, up is +Z, the old Brute
stands 0.85 m with its hips at 0.354 -- `art/parts_new/ch_brute.glb`):

- every part: `rotate` [x, y, z] degrees after load (a TRELLIS model faces the way its concept was
  drawn, which is rarely the game's way), `size` (its longest side, or for a frame its HEIGHT),
  `budget` triangles, `posterize` flat colours (as the sites: soft baked shading fights the ramp).
- **chassis**: `hip_z` and `hip_x` (the leg pivots), `pelvis_x` (below the hips, faces nearer the
  middle than this stay on the body: the crotch), `cut_arms` [x, z] (faces outboard of |x| and
  below z are deleted -- FLUX draws arms on a frame however it is asked not to, and the arm slot
  brings its own), and `sockets` {name: [x, y, z]}. The feet land on z=0, centred.
- **arm / core / module**: `mount` -- which point of the part becomes its origin, the point the
  game bolts to the socket: "top" (an arm's shoulder), "back" (a core sits on the chest and faces
  forward) or "front" (a module hangs on the back). Arms are built as the RIGHT arm (the game
  mirrors it for the left) and hang down and forward from the shoulder, as `make_ink_parts.py`'s do.

The texture survives (UVs survive a collapse) and its material is `mat_texture`, which
`Ink.dress_machine` draws with `Ink.textured` under the toon ramp and the ink line. Children are
parented keeping their world transform (CLAUDE.md: a bare `.parent =` puts sockets at y=0).
"""

import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import clean_generated as cg  # noqa: E402


def args():
    import argparse
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--in", dest="source", required=True)
    p.add_argument("--spec", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--preview", default="")
    return p.parse_args(argv)


def bounds(obj):
    co = [v.co for v in obj.data.vertices]
    return (Vector((min(p.x for p in co), min(p.y for p in co), min(p.z for p in co))),
            Vector((max(p.x for p in co), max(p.y for p in co), max(p.z for p in co))))


def size_to(obj, size, by_height):
    lo, hi = bounds(obj)
    span = hi - lo
    k = size / (span.z if by_height else max(span))
    obj.data.transform(Matrix.Scale(k, 4))
    return k


def cut(obj, plane_co, plane_no):
    """A clean edge along a plane, so what is split or deleted next has a straight border."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=plane_co, plane_no=plane_no)
    bm.to_mesh(obj.data)
    bm.free()


def delete_faces(obj, test):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    doomed = [f for f in bm.faces if test(f.calc_center_median())]
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    return len(doomed)


def split_off(obj, name, test):
    """The faces passing `test` become their own object (same material, same UVs)."""
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")
    picked = 0
    for poly in obj.data.polygons:
        poly.select = test(poly.center)
        picked += poly.select
    if picked == 0:
        return None
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    part = [o for o in bpy.context.selected_objects if o != obj][0]
    part.name = name
    part.data.name = name
    return part


def set_origin(obj, point):
    """Moves the object's origin to `point` (world) without moving its geometry."""
    obj.data.transform(Matrix.Translation(-(point - obj.location)))
    obj.location = point
    bpy.context.view_layer.update()


def parent_keep(child, parent):
    bpy.context.view_layer.update()
    world = child.matrix_world.copy()
    child.parent = parent
    child.matrix_parent_inverse = parent.matrix_world.inverted()
    child.matrix_world = world


def profile(obj, bands=12):
    """Width of the frame per height band, to place `hip_z` and `cut_arms` from numbers."""
    lo, hi = bounds(obj)
    step = (hi.z - lo.z) / bands
    for b in range(bands - 1, -1, -1):
        xs = [v.co.x for v in obj.data.vertices if lo.z + b * step <= v.co.z < lo.z + (b + 1) * step]
        ys = [v.co.y for v in obj.data.vertices if lo.z + b * step <= v.co.z < lo.z + (b + 1) * step]
        if xs:
            cells = set(int((x + 0.6) / 0.04) for x in xs)
            print("  " + "".join("#" if c in cells else "." for c in range(30)))
            print("  z %.2f-%.2f  x %+.3f..%+.3f  y %+.3f..%+.3f" % (lo.z + b * step, lo.z + (b + 1) * step,
                                                                  min(xs), max(xs), min(ys), max(ys)))


def grade(obj, saturation, ceiling):
    """TRELLIS bakes its render's highlights into the texture, so the top of a pauldron comes back
    near-white -- and the board camera looks straight down at it, where the toon ramp shows the
    texture's own colour (045: the Brute read cream). Saturation up, and the value of every texel
    squeezed under \`ceiling\`, so the concept's paint comes back."""
    import numpy as np
    for slot in obj.material_slots:
        if not (slot.material and slot.material.use_nodes):
            continue
        for node in slot.material.node_tree.nodes:
            if node.type != "TEX_IMAGE" or node.image is None:
                continue
            image = node.image
            px = np.array(image.pixels[:], dtype=np.float32).reshape(-1, 4)
            rgb = px[:, :3]
            v = rgb.max(1, keepdims=True)
            grey = rgb.mean(1, keepdims=True)
            rgb = np.clip(grey + (rgb - grey) * saturation, 0.0, 1.0)
            # Highlights compress toward the ceiling; darks are left alone.
            scale = np.where(v > 0.0, np.minimum(1.0, (ceiling * np.tanh(v / ceiling)) / np.maximum(v, 1e-4)), 1.0)
            px[:, :3] = rgb * scale
            image.pixels[:] = px.reshape(-1)
            image.update()
            image.pack()


def chassis(obj, spec):
    size_to(obj, spec["size"], True)
    lo, hi = bounds(obj)
    obj.data.transform(Matrix.Translation(Vector((-(lo.x + hi.x) * 0.5, -(lo.y + hi.y) * 0.5, -lo.z))))
    if spec.get("floor", 0.0) > 0.0:
        # TRELLIS grows a plinth under a standing figure: everything below `floor` goes, and the
        # feet are set back down on z=0.
        cut(obj, Vector((0, 0, spec["floor"])), Vector((0, 0, 1)))
        gone = delete_faces(obj, lambda c: c.z < spec["floor"])
        lo, hi = bounds(obj)
        obj.data.transform(Matrix.Translation(Vector((-(lo.x + hi.x) * 0.5, -(lo.y + hi.y) * 0.5, -lo.z))))
        print("floor: %d faces below %.3f" % (gone, spec["floor"]))
    profile(obj)
    if "cut_arms" in spec:
        ax, az = spec["cut_arms"]
        for side in (1.0, -1.0):
            cut(obj, Vector((side * ax, 0, 0)), Vector((1, 0, 0)))
        cut(obj, Vector((0, 0, az)), Vector((0, 0, 1)))
        gone = delete_faces(obj, lambda c: abs(c.x) > ax and c.z < az)
        print("arms cut: %d faces outboard of %.3f below %.3f" % (gone, ax, az))
    hip_z, hip_x, pelvis = spec["hip_z"], spec["hip_x"], spec.get("pelvis_x", 0.0)
    cut(obj, Vector((0, 0, hip_z)), Vector((0, 0, 1)))
    legs = {}
    for name, side in (("limb_leg_l", -1.0), ("limb_leg_r", 1.0)):
        leg = split_off(obj, name, lambda c, s=side: c.z < hip_z and c.x * s > pelvis)
        if leg is None:
            raise SystemExit("no leg below hip_z %.3f on the %s" % (hip_z, name))
        set_origin(leg, Vector((side * hip_x, 0.0, hip_z)))
        legs[name] = leg
    set_origin(obj, Vector((0.0, 0.0, hip_z)))
    for leg in legs.values():
        parent_keep(leg, obj)
    for name, at in spec["sockets"].items():
        empty = bpy.data.objects.new(name, None)
        bpy.context.scene.collection.objects.link(empty)
        empty.location = Vector(at)
        parent_keep(empty, obj)
    return [obj] + list(legs.values())


def drop_shadow(obj, lum_min=0.42, sat_max=0.28, share=0.6, low=0.25):
    """Removes the concept's drop shadow, which TRELLIS turns into a pale disc under the object
    (045, both arms): a loose piece in the bottom `low` of the part whose faces are mostly pale in
    the texture. Not by shape -- a TRELLIS model is many thin loose shells, and a thinness test tore
    real plates off both arms."""
    import numpy as np
    image = None
    for slot in obj.material_slots:
        if slot.material and slot.material.use_nodes:
            for node in slot.material.node_tree.nodes:
                if node.type == "TEX_IMAGE" and node.image is not None:
                    image = node.image
    if image is None or not obj.data.uv_layers:
        return
    w, h = image.size
    px = np.array(image.pixels[:], dtype=np.float32).reshape(h, w, 4)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    uv = bm.loops.layers.uv.active
    bm.faces.ensure_lookup_table()

    def pale(face):
        u = sum(l[uv].uv.x for l in face.loops) / len(face.loops)
        v = sum(l[uv].uv.y for l in face.loops) / len(face.loops)
        r, g, b = px[min(int(v % 1.0 * h), h - 1), min(int(u % 1.0 * w), w - 1), :3]
        return 0.2126 * r + 0.7152 * g + 0.0722 * b > lum_min and max(r, g, b) - min(r, g, b) < sat_max

    zs = [v.co.z for v in bm.verts]
    floor = min(zs) + (max(zs) - min(zs)) * low
    seen, doomed = set(), []
    for face in bm.faces:
        if face.index in seen:
            continue
        island, stack = [], [face]
        seen.add(face.index)
        while stack:
            f = stack.pop()
            island.append(f)
            for e in f.edges:
                for g in e.link_faces:
                    if g.index not in seen:
                        seen.add(g.index)
                        stack.append(g)
        top = max(v.co.z for f in island for v in f.verts)
        if top < floor and sum(1 for f in island if pale(f)) >= share * len(island):
            doomed += island
    bmesh.ops.delete(bm, geom=doomed, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    print("shadow dropped: %d faces" % len(doomed))


def attachment(obj, spec):
    if spec.get("drop_shadow", False):
        drop_shadow(obj)
    if spec.get("cut_below", 0.0) > 0.0:
        # A share of the height off the bottom: legs FLUX gave an object that hangs on a machine.
        lo, hi = bounds(obj)
        z = lo.z + (hi.z - lo.z) * spec["cut_below"]
        cut(obj, Vector((0, 0, z)), Vector((0, 0, 1)))
        print("cut below: %d faces" % delete_faces(obj, lambda c: c.z < z))
    size_to(obj, spec["size"], False)
    lo, hi = bounds(obj)
    mid = (lo + hi) * 0.5
    point = {"top": Vector((mid.x, mid.y, hi.z)),
             "back": Vector((mid.x, hi.y, mid.z)),
             "front": Vector((mid.x, lo.y, mid.z))}[spec["mount"]]
    obj.data.transform(Matrix.Translation(-point + Vector(spec.get("offset", [0, 0, 0]))))
    return [obj]


def preview(objects, prefix):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_object_outline = True
    scene.render.resolution_x = scene.render.resolution_y = 420
    scene.render.film_transparent = False
    bpy.ops.object.camera_add()
    camera = bpy.context.active_object
    scene.camera = camera
    co = [o.matrix_world @ v.co for o in objects for v in o.data.vertices]
    lo = Vector([min(p[i] for p in co) for i in range(3)])
    hi = Vector([max(p[i] for p in co) for i in range(3)])
    centre = (lo + hi) * 0.5
    d = max(hi - lo) * 2.4
    # front, three-quarter front, side, back (the game's front is -Y)
    for i, yaw in enumerate((0, 35, 90, 180)):
        a = math.radians(yaw)
        camera.location = centre + Vector((math.sin(a) * d, -math.cos(a) * d, d * 0.35))
        camera.rotation_euler = (centre - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = "%s_%d.png" % (prefix, i)
        bpy.ops.render.render(write_still=True)


def main():
    a = args()
    with open(a.spec) as f:
        spec = json.load(f)
    obj = cg.load(a.source, spec.get("up", "z"))
    rx, ry, rz = spec.get("rotate", [0, 0, 0])
    obj.data.transform(Matrix.Rotation(math.radians(rz), 4, "Z") @ Matrix.Rotation(math.radians(ry), 4, "Y")
                       @ Matrix.Rotation(math.radians(rx), 4, "X"))
    before = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    cg.collapse(obj, spec.get("budget", 5000), spec.get("sharp", 45.0))
    if "grade" in spec:
        grade(obj, *spec["grade"])
    cg.posterize(obj, spec.get("posterize", 16))
    part_id = os.path.splitext(os.path.basename(a.out))[0]
    obj.name = part_id
    obj.data.name = part_id
    objects = chassis(obj, spec) if spec["slot"] == "chassis" else attachment(obj, spec)
    after = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objects)
    bpy.context.view_layer.update()
    for o in objects:
        lo, hi = bounds(o)
        print("  %-12s origin %s  %.2f x %.2f x %.2f m" % (o.name, tuple(round(x, 3) for x in o.matrix_world.translation),
                                                         *(hi - lo)))
    print("rigged %s: %d -> %d triangles" % (part_id, before, after))
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.context.scene.objects:
        o.select_set(o in objects or (o.type == "EMPTY" and o.parent in objects))
    bpy.ops.export_scene.gltf(filepath=a.out, export_format="GLB", use_selection=True,
                              export_yup=True, export_texcoords=True, export_normals=True)
    if a.preview:
        preview(objects, a.preview)


if __name__ == "__main__":
    main()
