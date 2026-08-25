"""Blender primitives, and the four operations that decide whether a modular kit works.

The shape functions here are deliberately dumb -- a box is a box. What is not dumb,
and what every function below is careful about, is TRANSFORMS. A modular kit lives or
dies on whether a socket authored at 0.43 m arrives in the engine at 0.43 m, and
Blender offers several ways to get that wrong that all look fine in the viewport.

The four:

* `box` scales a UNIT cube, so the scale factor for a dimension `d` is `d`, not `d/2`.
* `set_origin` / `recentre_origin` move the origin without moving the geometry.
* `parent_keeping_transform` sets `matrix_parent_inverse`, which the raw assignment
  `child.parent = p` does not.
* `mirror_x` flips normals after applying a negative scale, which Blender does not.

Each one is a bug this project has already shipped once.
"""

import math

import bpy
import bmesh
from mathutils import Vector

from . import materials


# --- Scene and collection housekeeping ---------------------------------------

def clear_scene():
    """Empties the file, including orphaned datablocks.

    Without the second pass, a repeated run in one session accumulates meshes and
    materials that nothing references, and a `.blend` grows by tens of megabytes of
    invisible garbage."""
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.curves,
                  bpy.data.collections):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def ensure_collection(name, parent=None):
    """The named collection, created and linked under `parent` if it is missing."""
    collection = bpy.data.collections.get(name)
    if collection is None:
        collection = bpy.data.collections.new(name)
    host = parent if parent is not None else bpy.context.scene.collection
    if collection.name not in host.children:
        already_linked = any(collection.name in c.children for c in bpy.data.collections)
        if not already_linked and collection.name not in bpy.context.scene.collection.children:
            host.children.link(collection)
        elif parent is not None and collection.name not in host.children:
            host.children.link(collection)
    return collection


def set_active_collection(collection):
    """Makes `collection` the destination for anything `bpy.ops` creates next.

    Blender's add operators link into the ACTIVE layer collection, not into whatever
    the caller last touched. Building without setting this scatters pieces across the
    scene root, and the export -- which walks collections -- then ships some of them
    and not others."""
    layer = bpy.context.view_layer.layer_collection
    found = _find_layer_collection(layer, collection.name)
    if found is not None:
        bpy.context.view_layer.active_layer_collection = found
    return found


def _find_layer_collection(layer, name):
    if layer.collection.name == name:
        return layer
    for child in layer.children:
        found = _find_layer_collection(child, name)
        if found is not None:
            return found
    return None


def move_to_collection(obj, collection):
    for existing in list(obj.users_collection):
        existing.objects.unlink(obj)
    collection.objects.link(obj)
    for child in obj.children:
        move_to_collection(child, collection)
    return obj


def activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    return obj


# --- Shapes ------------------------------------------------------------------

def bevel(obj, width=0.012, segments=2, angle=40.0):
    """A bevel, applied immediately.

    Bevels are what stop low-poly hard surface reading as programmer art: they give
    every edge a highlight to catch the key light with. Applied rather than left live
    so that piece counts, bounds checks and the triangle budget all describe the mesh
    that actually exports."""
    if width <= 0:
        return obj
    activate(obj)
    modifier = obj.modifiers.new("Bevel", "BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    modifier.angle_limit = math.radians(angle)
    modifier.harden_normals = False
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def box(name, size, location=(0, 0, 0), rotation=(0, 0, 0), material="OldSteel",
        bevel_width=0.012, segments=2):
    """A bevelled box of the DECLARED size.

    `primitive_cube_add(size=1)` builds a unit cube spanning -0.5..+0.5, so reaching a
    dimension `d` means scaling by `d`. Halving it here is the bug that produced 315
    floating pieces on a roster that had been fixed by eye four times: plates, bolts
    and cowls were never misplaced, they were half-size and could not reach what they
    sat on. Nothing found it by looking at renders, because a detached bolt hides
    behind the body at most angles."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = (size[0], size[1], size[2])
    activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel(obj, bevel_width, segments)
    materials.apply(obj, material)
    return obj


def taper_box(name, size, top_scale=(0.6, 0.6), location=(0, 0, 0), rotation=(0, 0, 0),
              material="OldSteel", bevel_width=0.010, segments=1, shear=(0.0, 0.0)):
    """A box whose top face is scaled and optionally shoved sideways.

    The single most useful shape in the kit. Wedges, sloped glacis plates, tapered
    shells and canted shoulders all come from here, and they are what stop a roster of
    boxes reading as a roster of boxes. `shear` slides the top face along X/Y in local
    units, which is how a shell leans."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    hx, hy, hz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
    tx, ty = hx * top_scale[0], hy * top_scale[1]
    sx, sy = shear
    lower = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz)]
    upper = [(-tx + sx, -ty + sy, hz), (tx + sx, -ty + sy, hz),
             (tx + sx, ty + sy, hz), (-tx + sx, ty + sy, hz)]
    verts = [bm.verts.new(point) for point in lower + upper]
    bm.faces.new(verts[0:4][::-1])
    bm.faces.new(verts[4:8])
    for index in range(4):
        nxt = (index + 1) % 4
        bm.faces.new((verts[index], verts[nxt], verts[4 + nxt], verts[4 + index]))
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler = rotation
    bevel(obj, bevel_width, segments)
    materials.apply(obj, material)
    return obj


def cylinder(name, radius, depth, location=(0, 0, 0), rotation=(0, 0, 0), vertices=12,
             material="OldSteel", bevel_width=0.0, segments=1):
    bpy.ops.mesh.primitive_cylinder_add(
        radius=radius, depth=depth, vertices=vertices, location=location,
        rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    if bevel_width > 0:
        bevel(obj, bevel_width, segments)
    materials.apply(obj, material)
    return obj


def cone(name, radius1, radius2, depth, location=(0, 0, 0), rotation=(0, 0, 0),
         vertices=12, material="OldSteel"):
    bpy.ops.mesh.primitive_cone_add(
        radius1=radius1, radius2=radius2, depth=depth, vertices=vertices,
        location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    materials.apply(obj, material)
    return obj


def sphere(name, radius, location=(0, 0, 0), segments=12, rings=6, material="OldSteel"):
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=radius, segments=segments, ring_count=rings, location=location)
    obj = bpy.context.active_object
    obj.name = name
    materials.apply(obj, material)
    return obj


def torus(name, major, minor, location=(0, 0, 0), rotation=(0, 0, 0), major_segments=16,
          minor_segments=6, material="DarkMetal"):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major, minor_radius=minor, major_segments=major_segments,
        minor_segments=minor_segments, location=location, rotation=rotation)
    obj = bpy.context.active_object
    obj.name = name
    materials.apply(obj, material)
    return obj


def curve_tube(name, points, radius, material="DarkMetal", resolution=1, smooth=True):
    """A tube swept along a polyline, converted to mesh.

    This is the right primitive for cables, hoses, conduit and coil springs, and the
    reason is topology, not convenience: a hose built from twenty short cylinders is
    twenty disjoint shells that leave visible gaps at every bend and cost four times
    the triangles. `resolution=1` gives an 8-sided tube, which is plenty at the scale
    a cable is ever seen.

    `smooth=False` gives a POLY spline with hard corners -- correct for rigid conduit
    and square-bent pipe runs. The default NURBS sag is correct for anything hanging."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    # `resolution_u` is the single most expensive number in this file. A seven-point
    # cable at 3 is ~300 triangles, and a machine can carry a dozen of them; at 2 it
    # is ~200 and the difference is not visible on a hose 1.4 cm across. Cables were
    # most of the overspend on the arms.
    curve.resolution_u = 2 if smooth else 1
    curve.bevel_depth = radius
    curve.bevel_resolution = resolution
    curve.use_fill_caps = True

    spline = curve.splines.new("NURBS" if smooth else "POLY")
    spline.points.add(len(points) - 1)
    for index, point in enumerate(points):
        spline.points[index].co = (point[0], point[1], point[2], 1.0)
    if smooth:
        spline.use_endpoint_u = True
        spline.order_u = min(4, len(points))

    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    activate(obj)
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.active_object
    obj.name = name
    materials.apply(obj, material)
    return obj


# --- Transform surgery -------------------------------------------------------

def recentre_origin(obj):
    """Puts the origin at the world origin without moving the geometry."""
    return set_origin(obj, (0.0, 0.0, 0.0))


def set_origin(obj, point):
    """Moves an object's origin to `point`, leaving the geometry where it is.

    This is what makes a component mountable. Blender's join leaves the origin
    wherever the first piece happened to be, so a leg exported straight after joining
    hangs off its own node by whatever that offset was -- and every robot assembled
    from it is subtly disjointed in a way that is invisible per-part."""
    previous = tuple(bpy.context.scene.cursor.location)
    bpy.context.scene.cursor.location = point
    activate(obj)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.context.scene.cursor.location = previous
    return obj


def join(objects, name, recentre=False):
    """Merges objects into one mesh.

    `recentre` defaults to FALSE here, unlike the older generator. Components in this
    kit are built directly in their own mount frame -- a leg is authored with the hip
    at (0,0,0) -- so the origin is already correct and recentring would only be a
    no-op waiting to become a bug the day someone builds off-centre."""
    objects = [obj for obj in objects if obj is not None]
    if not objects:
        raise ValueError("join() called with no objects")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = name
    joined.data.name = name
    return recentre_origin(joined) if recentre else joined


def parent_keeping_transform(child, parent):
    """Parents the way Blender itself does it, inverse matrix included.

    `child.parent = parent` leaves `matrix_parent_inverse` at identity, so the child's
    transform is silently reinterpreted in the parent's frame. With `export_yup` the
    glTF exporter then writes the hierarchy in a rotated basis: a socket authored
    0.43 m up arrives in the engine at ground level, and the whole robot assembles
    lying on its back with its arms on the floor. It renders perfectly in Blender,
    which is why checking the art in Blender cannot find it."""
    bpy.ops.object.select_all(action="DESELECT")
    child.select_set(True)
    parent.select_set(True)
    bpy.context.view_layer.objects.active = parent
    bpy.ops.object.parent_set(type="OBJECT", keep_transform=True)
    return child


def mirror_x(obj):
    """Mirrors an object across X in place, normals included.

    Applying a negative scale leaves every face wound backwards, so the mirrored limb
    renders inside-out: with backface culling on it looks hollow, and with it off it
    looks merely wrong in a way that is hard to name. Blender does not fix this for
    you."""
    activate(obj)
    obj.scale = (-1.0, 1.0, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    for face in bm.faces:
        face.normal_flip()
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    return obj


# --- Measurement -------------------------------------------------------------

def world_bounds(obj):
    """(min, max) over the object's REAL vertices in world space.

    Never `matrix_world @ bound_box`. The bounding box is axis-aligned in local space,
    so for anything rotated -- and half this kit is rotated -- its transformed corners
    describe a volume substantially larger than the mesh. That overstatement once
    reported a correctly standing chassis as sunk 23 cm into the ground, and it
    reports floating pieces as connected, which is exactly the check it would be used
    for."""
    if obj.type != "MESH" or not obj.data.vertices:
        point = obj.matrix_world.translation
        return Vector(point), Vector(point)
    matrix = obj.matrix_world
    first = matrix @ obj.data.vertices[0].co
    lo = Vector(first)
    hi = Vector(first)
    for vertex in obj.data.vertices:
        point = matrix @ vertex.co
        for axis in range(3):
            lo[axis] = min(lo[axis], point[axis])
            hi[axis] = max(hi[axis], point[axis])
    return lo, hi


def triangulate(obj):
    """Triangulates in place, with a FIXED method.

    Two reasons, and the second is the one that cost a debugging session.

    The mesh ships as triangles either way -- if the generator does not triangulate,
    the glTF exporter does. But the exporter's triangulation is not stable between
    runs: two exports of bit-identical geometry produced identical vertex buffers and
    DIFFERENT index buffers, so the files failed a checksum comparison while
    describing the same object down to the last float. That made "the same seed gives
    the same component" a claim that looked false to anyone who checked it.

    `FIXED` rather than `BEAUTY` for both methods: beauty triangulation picks the
    diagonal by edge length, which is a comparison between floats that can tie, and a
    tie is resolved by whatever order the faces happen to be in.

    Doing it here also makes the reported triangle count the count that actually
    ships, instead of an estimate of what the exporter will produce."""
    activate(obj)
    modifier = obj.modifiers.new("Triangulate", "TRIANGULATE")
    modifier.quad_method = "FIXED"
    modifier.ngon_method = "CLIP"
    modifier.min_vertices = 4
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def canonicalise(obj):
    """Rewrites the mesh with its faces in a deterministic order.

    Blender's vertex order is already reproducible: the same seed produces a
    bit-identical vertex buffer in every process, which was confirmed by hashing it
    across separate runs. What is NOT reproducible is the order the POLYGONS end up
    in -- stable within one session, different in the next process, because BMesh's
    internal ordering is tied to allocation rather than to anything about the model.

    The effect is invisible (identical geometry, identical normals, identical render)
    and annoying out of proportion to that: every exported `.glb` fails a checksum
    comparison, so "seed 3 always gives the same component" cannot be verified with
    `md5` and looks false to whoever tries. Sorting faces by their vertex indices --
    a total order, since the vertex order is fixed -- makes the export byte-stable.

    Rebuilt rather than sorted in place because Blender has no API to reorder polygons.
    Vertex order is preserved exactly, so the position buffer is untouched."""
    mesh = obj.data
    vertices = [tuple(vertex.co) for vertex in mesh.vertices]
    faces = sorted((tuple(polygon.vertices), polygon.material_index)
                   for polygon in mesh.polygons)

    rebuilt = bpy.data.meshes.new(mesh.name)
    rebuilt.from_pydata(vertices, [], [face for face, _material in faces])
    rebuilt.update()
    for index, (_face, material_index) in enumerate(faces):
        rebuilt.polygons[index].material_index = material_index
    for material in mesh.materials:
        rebuilt.materials.append(material)

    name = mesh.name
    obj.data = rebuilt
    bpy.data.meshes.remove(mesh)
    rebuilt.name = name
    return obj


def nearest_surface_point(pieces, point, skip=()):
    """The vertex, among everything built so far, closest to `point`.

    This is how dressing gets placed. A rust patch dropped at a plausible-looking
    coordinate is plausible for the archetype it was tuned against and floating for
    the other three -- a cage torso is mostly air where a boiler is solid, and the
    open half is exactly where a random offset tends to land. Snapping to real
    geometry makes the placement correct for a shape the dressing code has never
    heard of, which is the property that matters when a sixth archetype is added
    later.

    Vertices rather than faces: it is one pass over data already in memory, and a
    patch is centred on the point with its own thickness around it, so being on a
    vertex instead of a face centre is a difference of millimetres."""
    best = None
    best_distance = None
    target = Vector(point)
    for piece in pieces:
        if piece in skip or piece.type != "MESH":
            continue
        matrix = piece.matrix_world
        for vertex in piece.data.vertices:
            world = matrix @ vertex.co
            distance = (world - target).length_squared
            if best_distance is None or distance < best_distance:
                best_distance = distance
                best = world
    return tuple(best) if best is not None else tuple(point)


def triangle_count(obj):
    if obj.type != "MESH":
        return 0
    return sum(max(0, len(polygon.vertices) - 2) for polygon in obj.data.polygons)
