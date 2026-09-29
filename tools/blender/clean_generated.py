"""Turns a GENERATED mesh (image-to-3D) into a set piece the game can draw in ink (017, route C).

    blender --background --python tools/blender/clean_generated.py -- \
        --in shop.obj --out art/sites/workshop.glb --size 3.0 \
        --zones "paint=e0a030,rust=b53a2a,alu=c4bca8,rock=8c8b86,dark=34302e" [--preview shots/ws]

An image-to-3D model is one dense, wavy, vertex-coloured shell: tens of thousands of
triangles from marching cubes, every flat wall slightly rippled, colour baked per vertex.
Under the ink look each of those is a fault -- a ripple is a band change, a band change on
every triangle is a scribble, and a colour per vertex is not a zone the palette can own.
So, in order:

1. **Stand it up and square it.** The model comes in its generator's frame (`--up`); its
   walls are turned to the axes by the rectangle of least area around its footprint, so a
   container's sides land on X and Y and the remesh below builds them flat.
2. **Remesh on a voxel grid**, which closes the holes and evens the topology, then
   **collapse** to a working budget and **dissolve** near-coplanar faces (`--planar`
   degrees): a rippled wall becomes one face, which is one band, which is what an inker
   would draw.
3. **Zone by colour.** Each face takes the colour of the original surface under it (the
   k nearest source vertices), then the nearest of the `--zones` references in Lab, and a
   face that disagrees with all of its neighbours joins them (speckle is noise in ink).
   Zones are the game's (`mat_<zone>`), so `Ink.dress_prop` paints the landmark exactly as
   it paints the kit: `paint` in the site's livery, the rest in the zone palette.
4. **Seat and size**: footprint to `--size` metres, the lowest point on z=0, centred.

No UVs are written, as for every part (CLAUDE.md: the exporter writes no texcoords).
"""

import argparse
import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.kdtree import KDTree


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--in", dest="source", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--size", type=float, default=3.0, help="footprint, metres")
    p.add_argument("--up", default="z", help="the source's up axis: z, y or -y")
    p.add_argument("--yaw", type=float, default=0.0, help="extra turn after squaring, degrees")
    p.add_argument("--voxel", type=float, default=0.012, help="remesh cell, fraction of size")
    p.add_argument("--budget", type=int, default=6000, help="triangles before dissolving")
    p.add_argument("--planar", type=float, default=9.0, help="dissolve angle, degrees")
    p.add_argument("--smooth", type=int, default=6, help="relax passes before dissolving")
    p.add_argument("--sharp", type=float, default=35.0, help="shading breaks at corners sharper than this")
    p.add_argument("--ground", default="", help="ZONE:ABOVE:BELOW -- faces of ZONE above ABOVE m join the body; "
                   "everything below BELOW m is ZONE")
    p.add_argument("--zones", default="paint=e0a030,rust=b53a2a,alu=c4bca8,rock=8c8b86,dark=34302e")
    p.add_argument("--preview", default="")
    return p.parse_args(argv)


# --- Colour --------------------------------------------------------------------

def srgb_to_lab(rgb):
    def lin(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (lin(c) for c in rgb)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = (0.2126 * r + 0.7152 * g + 0.0722 * b)
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def f(t):
        return t ** (1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
    fx, fy, fz = f(x), f(y), f(z)
    return (116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


def hex_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


# --- Steps -----------------------------------------------------------------------

def load(path, up):
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    if path.lower().endswith(".obj"):
        # Read as authored (no axis conversion); `--up` says what the source meant.
        bpy.ops.wm.obj_import(filepath=path, forward_axis="Y", up_axis="Z")
    else:
        bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for m in meshes:
        m.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.active_object
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    turn = {"z": Matrix.Identity(4),
            "y": Matrix.Rotation(math.pi / 2, 4, "X"),
            "-y": Matrix.Rotation(-math.pi / 2, 4, "X")}[up]
    obj.data.transform(turn)
    return obj


def colours_of(obj):
    """Per-vertex sRGB colour of the source: a point colour attribute, or a face-corner one
    averaged onto its vertices."""
    mesh = obj.data
    if not mesh.color_attributes:
        return [(0.5, 0.5, 0.5)] * len(mesh.vertices)
    attr = mesh.color_attributes[0]
    out = [[0.0, 0.0, 0.0, 0] for _ in mesh.vertices]
    if attr.domain == "POINT":
        for i, c in enumerate(attr.data):
            col = c.color_srgb
            out[i] = [col[0], col[1], col[2], 1]
    else:
        for loop in mesh.loops:
            col = attr.data[loop.index].color_srgb
            acc = out[loop.vertex_index]
            acc[0] += col[0]
            acc[1] += col[1]
            acc[2] += col[2]
            acc[3] += 1
    return [(a[0] / max(a[3], 1), a[1] / max(a[3], 1), a[2] / max(a[3], 1)) for a in out]


def level(obj):
    """Stands the model on its ground: a single image is seen from above, and the model comes
    back tilted by the camera's angle. The upward-facing area (the slab, the roof) is averaged,
    weighted by area, and turned onto +Z. Marching cubes may wind its faces inward; a slab's
    top and its underside are parallel, so either reading levels it."""
    mesh = obj.data
    up = Vector((0.0, 0.0, 0.0))
    for poly in mesh.polygons:
        if abs(poly.normal.z) > 0.6:
            up += poly.normal * (poly.area if poly.normal.z > 0 else -poly.area)
    if up.length < 1e-9:
        return 0.0
    up.normalize()
    mesh.transform(up.rotation_difference(Vector((0.0, 0.0, 1.0))).to_matrix().to_4x4())
    return math.degrees(up.angle(Vector((0.0, 0.0, 1.0))))


def square_up(obj, extra_yaw):
    """Turns the footprint's least-area rectangle onto the axes (walls onto X and Y)."""
    points = [(v.co.x, v.co.y) for v in obj.data.vertices]
    best = None
    for step in range(90):
        a = math.radians(step)
        c, s = math.cos(a), math.sin(a)
        xs = [x * c - y * s for x, y in points]
        ys = [x * s + y * c for x, y in points]
        area = (max(xs) - min(xs)) * (max(ys) - min(ys))
        if best is None or area < best[0]:
            best = (area, a)
    obj.data.transform(Matrix.Rotation(best[1] + math.radians(extra_yaw), 4, "Z"))
    return math.degrees(best[1])


def seat(obj, size):
    """Footprint to `size` metres, lowest point on z=0, centred on the origin."""
    co = [v.co for v in obj.data.vertices]
    lo = Vector((min(p.x for p in co), min(p.y for p in co), min(p.z for p in co)))
    hi = Vector((max(p.x for p in co), max(p.y for p in co), max(p.z for p in co)))
    k = size / max(hi.x - lo.x, hi.y - lo.y)
    centre = Vector(((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, lo.z))
    obj.data.transform(Matrix.Scale(k, 4) @ Matrix.Translation(-centre))
    return k


def flatten(obj, voxel, budget, planar, smooth, sharp):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    obj.data.remesh_voxel_size = voxel
    obj.data.remesh_voxel_adaptivity = 0.0
    bpy.ops.object.voxel_remesh()
    # Marching cubes leaves every flat wall rippled; relax it before the dissolve looks for
    # flat regions, or the ripples survive as a scatter of small faces.
    mod = obj.modifiers.new("relax", "SMOOTH")
    mod.factor = 0.6
    mod.iterations = smooth
    bpy.ops.object.modifier_apply(modifier=mod.name)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if tris > budget:
        mod = obj.modifiers.new("collapse", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = budget / float(tris)
        bpy.ops.object.modifier_apply(modifier=mod.name)
    mod = obj.modifiers.new("planar", "DECIMATE")
    mod.decimate_type = "DISSOLVE"
    mod.angle_limit = math.radians(planar)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mod = obj.modifiers.new("tri", "TRIANGULATE")
    mod.quad_method = "BEAUTY"
    mod.ngon_method = "BEAUTY"
    bpy.ops.object.modifier_apply(modifier=mod.name)
    # Smooth across the ripples a flat face could not absorb, sharp at real corners: flat
    # shading banded every leftover ripple into its own stripe (crumpled foil from the map's
    # height), where an inker draws a wall as one tone.
    obj.data.shade_smooth()
    obj.data.set_sharp_from_angle(angle=math.radians(sharp))


def zone_faces(obj, source_points, source_colours, zones, ground, k=10, passes=3):
    tree = KDTree(len(source_points))
    for i, p in enumerate(source_points):
        tree.insert(p, i)
    tree.balance()
    refs = [(name, srgb_to_lab(hex_rgb(value))) for name, value in zones]
    mesh = obj.data
    chosen = []
    for poly in mesh.polygons:
        acc = [0.0, 0.0, 0.0]
        found = tree.find_n(poly.center, k)
        for _, index, _ in found:
            c = source_colours[index]
            acc[0] += c[0]
            acc[1] += c[1]
            acc[2] += c[2]
        n = max(len(found), 1)
        lab = srgb_to_lab((acc[0] / n, acc[1] / n, acc[2] / n))
        best = min(range(len(refs)), key=lambda r: sum((lab[i] - refs[r][1][i]) ** 2 for i in range(3)))
        # A zone may list several references (a wall lit and in shadow): the NAME is the zone.
        chosen.append(refs[best][0])
    # Speckle: a face that fewer than two of its neighbours agree with takes their majority.
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.faces.ensure_lookup_table()
    for _ in range(passes):
        changed = 0
        for face in bm.faces:
            around = [chosen[f.index] for e in face.edges for f in e.link_faces if f.index != face.index]
            if around and around.count(chosen[face.index]) < min(2, len(around)):
                chosen[face.index] = max(sorted(set(around)), key=around.count)
                changed += 1
        if changed == 0:
            break
    bm.free()
    names = chosen
    if ground:
        # An image-to-3D model guesses the sides it could not see, and it guesses grey:
        # the ground's colour. Ground-coloured faces up on the body are the body.
        # And the slab it stands on is ground, whatever was guessed for it (`ZONE:ABOVE:BELOW`).
        zone, above, below = (ground.split(":") + ["0"])[:3]
        if above == "auto":
            # The slab's top: the height, in the lower half, with the most upward-facing area.
            top = max(p.center.z for p in mesh.polygons)
            bins = {}
            for p in mesh.polygons:
                if p.normal.z > 0.85 and p.center.z < top * 0.5:
                    key = round(p.center.z / 0.03)
                    bins[key] = bins.get(key, 0.0) + p.area
            slab = max(bins, key=bins.get) * 0.03 if bins else 0.0
            above, below = slab + 0.15, slab + 0.04
            print("ground slab top at %.2f m" % slab)
        body = [n for n, p in zip(names, mesh.polygons) if n != zone and p.center.z > float(above)]
        if body:
            main = max(sorted(set(body)), key=body.count)
            names = [main if n == zone and p.center.z > float(above) else n
                     for n, p in zip(names, mesh.polygons)]
        names = [zone if p.center.z < float(below) else n for n, p in zip(names, mesh.polygons)]
    unique = []
    for name, value in zones:
        if name not in [u[0] for u in unique]:
            unique.append((name, value))
    mesh.materials.clear()
    for name, value in unique:
        mat = bpy.data.materials.get("mat_" + name) or bpy.data.materials.new("mat_" + name)
        mat.diffuse_color = (*[c ** 2.2 for c in hex_rgb(value)], 1.0)
        mesh.materials.append(mat)
    slot = {name: i for i, (name, _) in enumerate(unique)}
    for poly, name in zip(mesh.polygons, names):
        poly.material_index = slot[name]
    counts = {}
    for name in names:
        counts[name] = counts.get(name, 0) + 1
    return counts


def preview(obj, prefix):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_object_outline = True
    scene.render.resolution_x = scene.render.resolution_y = 520
    bpy.ops.object.camera_add()
    camera = bpy.context.active_object
    scene.camera = camera
    co = [obj.matrix_world @ v.co for v in obj.data.vertices]
    top = max(p.z for p in co)
    span = max(max(p.x for p in co) - min(p.x for p in co), max(p.y for p in co) - min(p.y for p in co), top)
    centre = Vector((0.0, 0.0, top * 0.4))
    for i, yaw in enumerate((35, 125, 215, 305)):
        a = math.radians(yaw)
        d = span * 2.0
        camera.location = centre + Vector((math.sin(a) * d, -math.cos(a) * d, d * 0.75))
        camera.rotation_euler = (centre - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = "%s_%d.png" % (prefix, i)
        bpy.ops.render.render(write_still=True)


def main():
    a = args()
    zones = [tuple(item.split("=")) for item in a.zones.split(",")]
    obj = load(a.source, a.up)
    source_colours = colours_of(obj)
    tilt = level(obj)
    turned = square_up(obj, a.yaw)
    scale = seat(obj, a.size)
    source_points = [v.co.copy() for v in obj.data.vertices]
    before = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    flatten(obj, a.voxel * a.size, a.budget, a.planar, a.smooth, a.sharp)
    counts = zone_faces(obj, source_points, source_colours, zones, a.ground)
    after = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    obj.name = os.path.splitext(os.path.basename(a.out))[0]
    obj.data.name = obj.name
    co = [v.co for v in obj.data.vertices]
    print("cleaned: levelled %.0f deg, turned %.0f deg, scale %.3f, %d -> %d triangles, %.2f x %.2f x %.2f m"
          % (tilt, turned, scale, before, after, max(p.x for p in co) - min(p.x for p in co),
             max(p.y for p in co) - min(p.y for p in co), max(p.z for p in co)))
    print("zones (faces):", counts)
    os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=a.out, export_format="GLB", use_selection=True,
                              export_yup=True, export_texcoords=False, export_normals=True)
    if a.preview:
        preview(obj, a.preview)


if __name__ == "__main__":
    main()
