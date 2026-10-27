"""085 (the user): the shield and the hubcap plates without their side tabs -- the bracket ears with
bolt holes TRELLIS kept from the concepts. Cuts the faces beyond the main body's outline from a
CLEANED plate (art/props/pl_*.glb) and writes it back, texture and UVs kept.

    blender --background --python tools/gen3d/cut_ears.py -- art/props/pl_shield.glb [--profile]

The body's outline is measured, not guessed: per height slice, the widest |x| of the plate; the ears
are the slices that stand out from their neighbours. `--profile` prints the slices and stops.
  - shield: the side runs straight down past the ears, so the body's half width at the ear band is
    the widest half width just outside it;
  - hubcap: round, so the outline is the ellipse through the slices outside the ear band.
Faces whose centre lies outside the outline go, then the plate is centred on x again and re-seated.
"""
import math
import sys

import bmesh
import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
path = argv[0]
profile_only = "--profile" in argv
SLICES = 40

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)
obj = next(o for o in bpy.context.scene.objects if o.type == "MESH")
mesh = obj.data
bm = bmesh.new()
bm.from_mesh(mesh)
xs = [v.co.x for v in bm.verts]
zs = [v.co.z for v in bm.verts]
cx = (min(xs) + max(xs)) * 0.5
z0, z1 = min(zs), max(zs)
step = (z1 - z0) / SLICES
half = [0.0] * SLICES
for v in bm.verts:
    i = min(SLICES - 1, int((v.co.z - z0) / step))
    half[i] = max(half[i], abs(v.co.x - cx))
widest = max(half)
# The ear band: slices within 6% of the widest that stand out by more than 8% from the median width.
order = sorted(half)
median = order[len(order) // 2]
band = [i for i, h in enumerate(half) if h > widest * 0.94 and h > median * 1.08]
if profile_only or not band:
    for i, h in enumerate(half):
        print("slice %2d z %.3f half %.4f %s" % (i, z0 + (i + 0.5) * step, h, "EAR" if i in band else ""))
    print("band", band)
    sys.exit(0)
lo, hi = min(band), max(band)
name = path.rsplit("/", 1)[-1]
outside = [i for i in range(SLICES) if i < lo - 1 or i > hi + 1]
if "hubcap" in name:
    # The ellipse through the outline outside the band: centre height and radii from the slices.
    zc = (z0 + z1) * 0.5
    rz = (z1 - z0) * 0.5
    # For each outside slice, h^2 = rx^2 (1 - ((z - zc)/rz)^2): the best rx over them (the median).
    fits = []
    for i in outside:
        z = z0 + (i + 0.5) * step
        k = 1.0 - ((z - zc) / rz) ** 2
        if k > 0.3:
            fits.append(half[i] / math.sqrt(k))
    fits.sort()
    rx = fits[len(fits) // 2] * 1.01

    def inside(x, z):
        return ((x - cx) / rx) ** 2 + ((z - zc) / rz) ** 2 <= 1.0
    print("ellipse rx %.4f rz %.4f" % (rx, rz))
else:
    near = [half[i] for i in (lo - 2, lo - 3, hi + 2, hi + 3) if 0 <= i < SLICES]
    limit = max(near) * 1.01
    zlo, zhi = z0 + (lo - 1) * step, z0 + (hi + 2) * step

    def inside(x, z):
        return not (zlo <= z <= zhi and abs(x - cx) > limit)
    print("side %.4f from z %.3f to %.3f" % (limit, zlo, zhi))
gone = [f for f in bm.faces if not inside(f.calc_center_median().x, f.calc_center_median().z)]
bmesh.ops.delete(bm, geom=gone, context="FACES")
loose = [v for v in bm.verts if not v.link_faces]
bmesh.ops.delete(bm, geom=loose, context="VERTS")
# Bits left floating past the cut (a bolt head's far side): keep the biggest connected piece only.
pieces = []
seen = set()
for f in bm.faces:
    if f.index in seen:
        continue
    stack, part = [f], []
    seen.add(f.index)
    while stack:
        g = stack.pop()
        part.append(g)
        for e in g.edges:
            for h in e.link_faces:
                if h.index not in seen:
                    seen.add(h.index)
                    stack.append(h)
    pieces.append(part)
bm.faces.ensure_lookup_table()
pieces.sort(key=len, reverse=True)
small = [f for part in pieces[1:] if len(part) < len(pieces[0]) * 0.02 for f in part]
bmesh.ops.delete(bm, geom=small, context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
xs = [v.co.x for v in bm.verts]
shift = -(min(xs) + max(xs)) * 0.5
for v in bm.verts:
    v.co.x += shift
print("cut %d faces (%d floating), %d left, width %.3f m" % (len(gone), len(small), len(bm.faces), max(xs) - min(xs)))
bm.to_mesh(mesh)
bm.free()
bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_yup=True, export_texcoords=True, export_normals=True)
