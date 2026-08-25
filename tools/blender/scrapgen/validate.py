"""Checks the generated kit against everything it is supposed to guarantee.

The reason this file exists at all: **checking the art in Blender is not checking the
kit.** A component can be beautiful, correctly named, and still be unusable because a
socket is 4 mm off, or a foot is 3 cm above the ground plane, or a bolt is floating
behind the body where no render angle shows it. None of those are visible to a human
reviewing renders, and all of them break every robot assembled from the part.

So the checks below are the ones a person cannot do by looking:

| Check | What it catches |
|---|---|
| naming | `Cube.001` in an export -- a part the engine silently cannot find |
| collection | a component filed where the exporter will not walk |
| socket existence | an arm with no weapon mount |
| socket POSITION | the drift that makes a kit need per-combination fixups |
| mount clearance | a socket hanging in space with no geometry behind it |
| origin | a component that renders offset from the node it is parented to |
| ground plane | a leg that leaves the robot hovering or buried |
| materials | a slot outside the palette, or an empty slot |
| connectivity | detached greeble, which hides at almost every angle |
| triangles | a greeble loop that ran away |

`connectivity_report` is the one that has to run mid-build, before the join, because
after the join every piece is one mesh and the question cannot be asked any more.
"""

import re

import bpy
from mathutils import Vector

from . import component as component_module
from . import config
from . import materials
from . import primitives as prim
from . import sockets as socket_contract


class Problem:
    __slots__ = ("severity", "where", "message")

    def __init__(self, severity, where, message):
        self.severity = severity
        self.where = where
        self.message = message

    def __str__(self):
        mark = {"error": "FAIL", "warn": "warn"}[self.severity]
        return "  [%s] %-14s %s" % (mark, self.where, self.message)


# --- Connectivity ------------------------------------------------------------

## How far apart two pieces may be and still count as touching. 4 mm absorbs the
## bevels and the float error of a rotated strut without letting a genuinely detached
## bolt through.
TOUCH_EPSILON = 0.004


def connectivity_report(pieces):
    """Which pieces touch nothing, computed BEFORE the join.

    Bounding boxes are measured from REAL VERTICES, never from `matrix_world @
    bound_box`: a rotated box's transformed corners describe a volume much larger than
    the mesh, and this check would then declare a floating piece connected -- failing
    at exactly the job it exists for.

    Bounds overlap is a conservative test, not an exact one: two pieces whose boxes
    intersect might still not touch. That is the right direction to be wrong in for a
    tripwire, and the alternative (real mesh intersection over ~60 pieces per
    component, 24 components) costs minutes per run to catch cases the eye already
    finds."""
    if len(pieces) < 2:
        return {"total": len(pieces), "floating": [], "islands": 1}

    bounds = [prim.world_bounds(piece) for piece in pieces]

    def touches(a, b):
        lo_a, hi_a = bounds[a]
        lo_b, hi_b = bounds[b]
        for axis in range(3):
            if hi_a[axis] + TOUCH_EPSILON < lo_b[axis]:
                return False
            if hi_b[axis] + TOUCH_EPSILON < lo_a[axis]:
                return False
        return True

    count = len(pieces)
    adjacency = [[] for _ in range(count)]
    for i in range(count):
        for j in range(i + 1, count):
            if touches(i, j):
                adjacency[i].append(j)
                adjacency[j].append(i)

    floating = [pieces[i].name for i in range(count) if not adjacency[i]]

    # Islands, not just orphans. A pair of pieces that touch each other and nothing
    # else passes a per-piece "does it touch anything" test while being a detached
    # sub-assembly -- an exhaust stack whose three parts hold together 2 cm clear of
    # the hull. Reporting the members of every island but the largest is what makes
    # that findable; reporting only the count says something is wrong and not what.
    seen = set()
    groups = []
    for start in range(count):
        if start in seen:
            continue
        stack = [start]
        seen.add(start)
        group = []
        while stack:
            node = stack.pop()
            group.append(node)
            for neighbour in adjacency[node]:
                if neighbour not in seen:
                    seen.add(neighbour)
                    stack.append(neighbour)
        groups.append(group)

    groups.sort(key=len, reverse=True)
    detached = [sorted(pieces[i].name for i in group) for group in groups[1:]]
    return {"total": count, "floating": floating, "islands": len(groups),
            "detached": detached}


# --- Full validation ---------------------------------------------------------

def validate_components(expected=None, verbose=True):
    """Validates every component in the scene. Returns (ok, problems).

    `expected` is `{category: count}`; components that should exist and do not are
    errors. Pass None to validate whatever happens to be there."""
    # Without this, `matrix_world` describes where objects USED to be, and every
    # socket position check reads stale numbers -- which is the most confusing
    # possible way for a validator to be wrong.
    bpy.context.view_layer.update()

    problems = []
    root = bpy.data.collections.get(config.ROOT_COLLECTION)
    if root is None:
        problems.append(Problem("error", "scene",
                                "collection %r does not exist" % config.ROOT_COLLECTION))
        return _finish(problems, verbose, {})

    _check_materials(problems)
    _check_scratch(problems)

    summary = {}
    for category in ("head", "torso", "arm", "weapon", "leg"):
        # A category nobody asked for is not a failure. `--only arm` builds one
        # category on purpose, and reporting four missing collections as errors turns
        # a deliberately narrow run into a red result that has to be ignored -- which
        # is how a validator trains people to stop reading it.
        if expected is not None and not expected.get(category, 0):
            continue
        collection = bpy.data.collections.get(config.COLLECTIONS[category])
        if collection is None:
            problems.append(Problem("error", category, "collection %r missing"
                                    % config.COLLECTIONS[category]))
            continue
        found = sorted([obj for obj in collection.objects if obj.type == "MESH"],
                       key=lambda o: o.name)
        summary[category] = found

        if expected is not None and len(found) != expected.get(category, 0):
            problems.append(Problem("error", category, "expected %d components, found %d"
                                    % (expected.get(category, 0), len(found))))

        for obj in found:
            _check_component(obj, category, problems)

    return _finish(problems, verbose, summary)


def _check_component(obj, category, problems):
    where = obj.name

    if not re.match(config.NAME_PATTERN, obj.name):
        problems.append(Problem("error", where, "name does not match %s"
                                % config.NAME_PATTERN))
    if not obj.name.startswith(config.PREFIXES[category] + "_"):
        problems.append(Problem("error", where, "filed under %s but named %r"
                                % (category, obj.name)))
    if obj.data.name != obj.name:
        problems.append(Problem("warn", where, "mesh datablock named %r" % obj.data.name))

    # Origin. A component whose origin drifted renders offset from the node it is
    # parented to, by exactly that drift, on every robot built from it.
    origin = obj.matrix_world.translation
    if origin.length > socket_contract.TOLERANCE:
        problems.append(Problem("error", where, "origin at %s, expected (0,0,0)"
                                % _fmt(origin)))
    if tuple(round(value, 4) for value in obj.scale) != (1.0, 1.0, 1.0):
        problems.append(Problem("error", where, "unapplied scale %s" % _fmt(obj.scale)))

    # Sockets, keyed on the contract name in the `socket` property rather than the
    # object name -- see `component._socket_empty` for why those differ.
    children = {component_module.socket_name(child): child
                for child in obj.children if child.type == "EMPTY"}
    for spec in socket_contract.specs_for(category):
        child = children.get(spec.name)
        if child is None:
            problems.append(Problem("error", where, "missing socket %r" % spec.name))
            continue
        local = (obj.matrix_world.inverted() @ child.matrix_world).translation
        if spec.fixed:
            drift = (Vector(spec.location) - local).length
            if drift > socket_contract.TOLERANCE:
                problems.append(Problem(
                    "error", where,
                    "socket %s at %s, contract says %s (drift %.4f m)"
                    % (spec.name, _fmt(local), _fmt(spec.location), drift)))
        _check_mount_clearance(obj, spec, local, where, problems)

    extra = set(children) - set(socket_contract.names_for(category))
    if extra:
        problems.append(Problem("warn", where, "undeclared sockets: %s"
                                % ", ".join(sorted(extra))))

    # Materials.
    if not obj.data.materials:
        problems.append(Problem("error", where, "no material slots"))
    for slot in obj.data.materials:
        if slot is None:
            problems.append(Problem("error", where, "empty material slot"))
        elif slot.name not in materials.PALETTE and not slot.name.startswith("mat_"):
            problems.append(Problem("error", where, "material %r is outside the palette"
                                    % slot.name))

    # Ground plane, for the categories that have one.
    lo, hi = prim.world_bounds(obj)
    plane = socket_contract.ground_plane(category)
    if plane is not None:
        if category == "leg":
            if abs(lo.z - plane) > 0.02:
                problems.append(Problem("error", where,
                                        "sole at z=%.3f, ground plane is %.3f"
                                        % (lo.z, plane)))
        elif lo.z < plane - 0.10:
            problems.append(Problem("warn", where,
                                    "geometry reaches z=%.3f, below the %.2f plane"
                                    % (lo.z, plane)))

    triangles = prim.triangle_count(obj)
    budget = config.TRI_BUDGET[category]
    if triangles > budget:
        problems.append(Problem("warn", where, "%d triangles, budget %d"
                                % (triangles, budget)))


def _check_mount_clearance(obj, spec, local, where, problems):
    """Is there real geometry near this socket?

    A mount with nothing behind it is the failure that survives every other check: the
    component is named right, filed right, and its socket is at the contracted
    position -- the position just happens to be in mid-air, so whatever bolts onto it
    floats. Only fixed sockets are checked; a muzzle deliberately sits at the END of a
    barrel and may legitimately have air in front of it."""
    if not spec.fixed:
        return
    target = obj.matrix_world.inverted() @ Vector(local)
    hit, surface, normal, _index = obj.closest_point_on_mesh(target)
    if not hit:
        problems.append(Problem("error", where, "socket %s: mesh query failed"
                                % spec.name))
        return

    delta = target - surface
    # A negative dot with the surface normal means the socket is INSIDE the mesh,
    # which is the most backed a mount can possibly be.
    #
    # This is why the check is against the surface and not against the nearest
    # VERTEX. Every neck mount in the kit sits on the axis of a collar ring, and a
    # cylinder has no vertex on its own axis -- the nearest one is a full radius away.
    # A vertex-distance check therefore failed all four torsos for having their head
    # mount correctly seated in the middle of the collar, which is a validator
    # inventing a bug and then reporting it four times.
    if delta.dot(normal) < 0.0:
        return
    if delta.length > socket_contract.MOUNT_CLEARANCE:
        problems.append(Problem("error", where,
                                "socket %s has no geometry within %.0f mm "
                                "(nearest surface %.0f mm, and the socket is outside it)"
                                % (spec.name, socket_contract.MOUNT_CLEARANCE * 1000,
                                   delta.length * 1000)))


def _check_materials(problems):
    for name in materials.PALETTE:
        if bpy.data.materials.get(name) is None:
            problems.append(Problem("error", "materials", "material %r was never built"
                                    % name))


def _check_scratch(problems):
    scratch = bpy.data.collections.get(config.SCRATCH_COLLECTION)
    if scratch is not None and scratch.objects:
        problems.append(Problem("warn", "scratch",
                                "%d object(s) left in %s -- a build leaked pieces"
                                % (len(scratch.objects), config.SCRATCH_COLLECTION)))


def _finish(problems, verbose, summary):
    errors = [p for p in problems if p.severity == "error"]
    if verbose:
        print("")
        print("=== validate_components ===")
        for category in ("head", "torso", "arm", "weapon", "leg"):
            objects = summary.get(category, [])
            if objects:
                print("  %-7s %d: %s" % (category, len(objects),
                                         ", ".join(o.name for o in objects)))
        if problems:
            print("")
            for problem in problems:
                print(problem)
        print("")
        print("  %d error(s), %d warning(s)"
              % (len(errors), len(problems) - len(errors)))
        print("  %s" % ("PASS" if not errors else "FAIL"))
    return (not errors), problems


def _fmt(vector):
    return "(%.3f, %.3f, %.3f)" % (vector[0], vector[1], vector[2])
