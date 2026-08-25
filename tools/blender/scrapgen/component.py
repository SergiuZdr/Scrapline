"""The Component object and the finalize pipeline every category shares.

A builder's whole job is to produce loose pieces in the mount frame and say what it
built. Everything after that -- checking the pieces actually touch, joining, setting
the origin, declaring sockets, filing it in the right collection, counting triangles --
happens here, once, for all five categories.

That split is what makes adding a sixth category cheap. `builders/shoulder.py` would
be a function that returns pieces; it inherits the socket contract, the connectivity
check, the naming rules and the budget report for free, and none of them can drift
from how the other five work because there is only one copy.
"""

import bpy

from . import config
from . import primitives as prim
from . import sockets as socket_contract


class Component:
    """One generated variant, mid-build.

    Holds loose pieces plus the metadata the pipeline and the validator need. Nothing
    here touches Blender state except through `primitives`."""

    def __init__(self, category, index, seed, rng):
        if category not in config.PREFIXES:
            raise KeyError("unknown category %r" % category)
        self.category = category
        self.index = index
        self.seed = seed
        self.rng = rng
        self.name = "%s_%03d" % (config.PREFIXES[category], index)
        self.pieces = []
        self.socket_requests = []
        self.archetype = "unnamed"
        ## Overrides the seed's archetype choice, leaving every other roll to the seed.
        ##
        ## For callers that need a SPECIFIC silhouette but still want variety inside it
        ## -- the Scrapline bridge picks a torso shape from a chassis' role and a weapon
        ## shape from its `weapon_class`, so a Breaker Hammer is always a hammer while
        ## still being a differently-built hammer from every other one.
        self.forced_archetype = ""
        self.recipe = {}

    def add(self, *items):
        """Registers pieces. Accepts objects, lists, and nested lists, because the
        greeble library returns whichever is natural for the shape -- forcing every
        greeble to return a list would put brackets around half the call sites in the
        builders for no gain."""
        for item in items:
            if item is None:
                continue
            if isinstance(item, (list, tuple)):
                self.add(*item)
            else:
                self.pieces.append(item)
        return items[-1] if items else None

    def socket(self, name, location, rotation=(0.0, 0.0, 0.0)):
        """Declares a socket. Builders call this only for FREE sockets; fixed ones are
        placed from the contract table by `place_sockets`."""
        self.socket_requests.append((name, tuple(location), tuple(rotation)))

    def describe(self):
        return "%s [%s] seed=%d" % (self.name, self.archetype, self.seed)


def finalize(component, collection, check_connectivity=True):
    """Turns loose pieces into a finished, socketed, filed component.

    The order matters and is not arbitrary:

    1. **Connectivity is checked BEFORE the join**, because after the join every piece
       is one mesh and the question "does this bolt touch anything" can no longer be
       asked. Checking after the fact is how 315 floating pieces survived four rounds
       of fixing by eye.
    2. **The origin is set to the mount frame's zero**, not recentred to the geometry.
       Components are authored with the mount at (0,0,0) already -- a leg's hip, an
       arm's shoulder -- so moving the origin to the centre of mass would break the
       one property assembly depends on.
    3. **Sockets are parented last**, with `keep_transform`, so their local transforms
       are correct relative to a mesh whose origin has already settled."""
    from . import validate  # local: validate imports nothing from this module

    if not component.pieces:
        raise ValueError("%s produced no geometry" % component.name)

    report = validate.connectivity_report(component.pieces) if check_connectivity else None

    obj = prim.join(component.pieces, component.name, recentre=False)
    prim.triangulate(obj)
    prim.canonicalise(obj)
    prim.set_origin(obj, (0.0, 0.0, 0.0))

    socket_contract.place_sockets(component)
    for name, location, rotation in component.socket_requests:
        empty = _socket_empty(component, name, location, rotation)
        prim.parent_keeping_transform(empty, obj)

    prim.move_to_collection(obj, collection)

    # Survives into the `.glb` as node extras, so a component's recipe is recoverable
    # from the exported file rather than only from the console output of the run that
    # made it.
    obj["scrap_category"] = component.category
    obj["scrap_seed"] = component.seed
    obj["scrap_archetype"] = component.archetype

    component.object = obj
    component.triangles = prim.triangle_count(obj)
    component.connectivity = report
    return obj


def _socket_empty(component, name, location, rotation):
    """An ARROWS empty, named `<Component>_<Socket>` and tagged with the bare name.

    **Object names are unique per FILE in Blender, not per component.** Name the
    empties after the contract and the first torso gets `HeadSocket`, the second gets
    `HeadSocket.001`, the third `HeadSocket.002` -- silently, with no error. Two things
    then break at once: the assembler cannot find a socket by name on any component but
    the first, and every exported `.glb` after the first carries a mount the engine
    cannot look up either. Both failures appear only once there is more than one
    variant, which is exactly when a kit stops being testable by eye.

    So the object name is prefixed and always unique, and the CONTRACT name lives in a
    `socket` custom property. Everything that reads a socket -- assembly, validation,
    export -- reads the property. `exporter.export_component` renames to the bare names
    for the duration of one export, which is safe precisely because no bare name is
    ever taken while it does so.

    ARROWS rather than PLAIN_AXES: half these mounts carry an orientation that a weapon
    or a head inherits, and an empty that does not show its facing is an empty nobody
    can check by looking."""
    bpy.ops.object.empty_add(type="ARROWS", radius=0.07, location=location,
                             rotation=rotation)
    empty = bpy.context.active_object
    empty.name = "%s_%s" % (component.name, name)
    empty["socket"] = name
    return empty


def socket_name(empty):
    """The contract name of a socket empty, whatever Blender called the object."""
    return empty.get("socket", empty.name)
