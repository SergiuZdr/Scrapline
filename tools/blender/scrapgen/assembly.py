"""Bolts components together into a demo robot, through the real socket lookup.

This is the only honest check that the kit is a kit. A part can be perfectly built,
correctly named, socketed to the millimetre and still wrong on a machine -- and the
first version of a modular set is always wrong on a machine in some way that no
single-part render shows.

The assembler deliberately uses the SAME lookup a runtime would: find the parent's
socket empty by name, read its world position, put the child's origin there. If that
is not enough to assemble a robot, the contract is broken, and it should be broken
here rather than in the engine.

Demo robots are copies. The originals stay untouched in their category collections, so
assembling never disturbs what is about to be exported.
"""

import bpy

from . import component as component_module
from . import config
from . import primitives as prim


def demo_robot(index, components, rng, on_ground=True):
    """Assembles one robot from a `{category: [Component, ...]}` dictionary.

    Picks a head, a torso, TWO arms (independently -- a scrapyard robot has no reason
    to have matching limbs), two legs and one weapon. The right-side limbs are mirrored
    copies of whatever was picked for them.
    """
    root = prim.ensure_collection(config.DEMO_COLLECTION)
    prim.set_active_collection(root)

    name = "DemoRobot_%03d" % index
    chosen = {
        "torso":  rng.pick(components["torso"]),
        "head":   rng.pick(components["head"]),
        "arm_l":  rng.pick(components["arm"]),
        "arm_r":  rng.pick(components["arm"]),
        "leg_l":  rng.pick(components["leg"]),
        "leg_r":  rng.pick(components["leg"]),
        "weapon": rng.pick(components["weapon"]),
    }

    parts = []

    torso_obj, torso_sockets = _instantiate(chosen["torso"].object, name + "_Torso", root)
    # Stand the robot on z=0 rather than hanging it from the torso origin, so a sheet
    # of demo robots lines up on a floor instead of at hip height.
    torso_obj.location = (0.0, 0.0, config.LEG_LENGTH if on_ground else 0.0)
    parts.append(torso_obj)
    bpy.context.view_layer.update()

    head_obj, _ = _instantiate(chosen["head"].object, name + "_Head", root)
    head_obj.location = _socket_world(torso_obj, "HeadSocket")
    parts.append(head_obj)

    arms = {}
    for side, key in (("L", "arm_l"), ("R", "arm_r")):
        arm_obj, arm_sockets = _instantiate(chosen[key].object,
                                            "%s_Arm%s" % (name, side), root,
                                            mirror=(side == "R"))
        arm_obj.location = _socket_world(torso_obj, "ShoulderSocket_" + side)
        arms[side] = (arm_obj, arm_sockets)
        parts.append(arm_obj)

    for side, key in (("L", "leg_l"), ("R", "leg_r")):
        leg_obj, _ = _instantiate(chosen[key].object, "%s_Leg%s" % (name, side), root,
                                  mirror=(side == "R"))
        leg_obj.location = _socket_world(torso_obj, "HipSocket_" + side)
        parts.append(leg_obj)

    # The weapon goes on the right hand. One weapon, per the brief -- and it is worth
    # seeing an armed arm next to an unarmed one to confirm a bare wrist still reads
    # as finished.
    bpy.context.view_layer.update()
    weapon_obj, _ = _instantiate(chosen["weapon"].object, name + "_Weapon", root)
    weapon_obj.location = _socket_world(arms["R"][0], "WeaponSocket")
    parts.append(weapon_obj)

    # An empty as the robot's root, so a demo is one selectable thing.
    bpy.ops.object.empty_add(type="PLAIN_AXES", radius=0.25, location=(0, 0, 0))
    anchor = bpy.context.active_object
    anchor.name = name
    prim.move_to_collection(anchor, root)
    bpy.context.view_layer.update()
    for part in parts:
        prim.parent_keeping_transform(part, anchor)

    print("  %s = %s + %s + %s/%s + %s/%s + %s"
          % (name, chosen["torso"].object.name, chosen["head"].object.name,
             chosen["arm_l"].object.name, chosen["arm_r"].object.name,
             chosen["leg_l"].object.name, chosen["leg_r"].object.name,
             chosen["weapon"].object.name))
    return anchor, chosen


def _instantiate(source, name, collection, mirror=False):
    """A copy of a component, with its sockets rebuilt.

    Sockets are recreated rather than copied-with-parent on purpose. Applying a
    mirroring scale to a parent with children makes Blender compensate the children,
    which is exactly what we do NOT want here -- a mirrored arm's weapon mount has to
    move to the mirrored position, not stay put. Reading the socket positions out
    first, flipping them by hand and rebuilding is the version whose behaviour is
    obvious."""
    socket_locals = {}
    for child in source.children:
        if child.type != "EMPTY":
            continue
        # Keyed on the CONTRACT name from the custom property, never on the object
        # name -- Blender has already turned the fourth torso's `HeadSocket` object
        # into `HeadSocket.003`, and keying on that assembles three of four robots.
        local = (source.matrix_world.inverted() @ child.matrix_world).translation
        socket_locals[component_module.socket_name(child)] = [local.x, local.y, local.z]

    copy = source.copy()
    copy.data = source.data.copy()
    copy.name = name
    copy.data.name = name
    collection.objects.link(copy)
    copy.location = (0, 0, 0)

    if mirror:
        prim.mirror_x(copy)
        for local in socket_locals.values():
            local[0] = -local[0]

    for socket_name, local in sorted(socket_locals.items()):
        bpy.ops.object.empty_add(type="ARROWS", radius=0.06, location=(0, 0, 0))
        empty = bpy.context.active_object
        empty.name = "%s_%s" % (name, socket_name)
        empty["socket"] = socket_name
        prim.move_to_collection(empty, collection)
        empty.parent = copy
        empty.matrix_parent_inverse = copy.matrix_world.inverted()
        empty.location = local

    return copy, socket_locals


def _socket_world(obj, socket_name):
    """World position of a named socket on an assembled part.

    `view_layer.update()` first, every time. Blender evaluates transforms lazily, so
    reading `matrix_world` after moving a parent gives you where the child USED to be
    -- and an assembler that reads stale sockets builds a robot out of parts placed
    where the previous part was, which looks like a completely different bug."""
    bpy.context.view_layer.update()
    for child in obj.children:
        if child.type == "EMPTY" and component_module.socket_name(child) == socket_name:
            return child.matrix_world.translation.copy()
    available = [component_module.socket_name(c) for c in obj.children
                 if c.type == "EMPTY"]
    raise KeyError("%s has no socket %r (has: %s)"
                   % (obj.name, socket_name, ", ".join(available) or "none"))


def validate_assembly(anchor, tolerance=0.02):
    """Sanity-checks an assembled robot: is it standing on the floor, is it the height
    the proportions in `config` promise, and is anything below ground.

    A robot 4 cm into the floor is not visible in a three-quarter render and is
    extremely visible the moment a camera sits at eye level."""
    lo = None
    hi = None
    for child in anchor.children:
        if child.type != "MESH":
            continue
        child_lo, child_hi = prim.world_bounds(child)
        lo = child_lo if lo is None else [min(lo[i], child_lo[i]) for i in range(3)]
        hi = child_hi if hi is None else [max(hi[i], child_hi[i]) for i in range(3)]
    if lo is None:
        return False, "no meshes"

    height = hi[2] - lo[2]
    expected = config.LEG_LENGTH + config.TORSO_HEIGHT + config.HEAD_HEIGHT
    notes = []
    if abs(lo[2]) > tolerance:
        notes.append("stands at z=%.3f, not 0" % lo[2])
    if abs(height - expected) > 0.25:
        notes.append("%.2f m tall, expected about %.2f m" % (height, expected))
    return (not notes), "; ".join(notes) or "%.2f m, feet at %.3f" % (height, lo[2])
