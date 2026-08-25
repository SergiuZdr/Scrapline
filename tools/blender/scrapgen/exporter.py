"""GLB export, one file per component, foldered by category.

```
exports/
  heads/Head_001.glb
  torsos/Torso_001.glb
  arms/Arm_001.glb
  weapons/Weapon_001.glb
  legs/Leg_001.glb
```

Three settings carry the whole thing:

* **`export_yup=True`** -- glTF is Y-up and Blender is Z-up. Without it every part
  arrives in the engine lying on its back.
* **`use_selection=True`** with the sockets selected alongside the mesh. Miss the
  empties and the file exports geometry with no mount points, which imports cleanly
  and cannot be assembled.
* **`export_apply=True`** -- bakes modifiers. Everything here is already applied, so
  it changes nothing today and prevents a live modifier added later from silently not
  shipping.

`export_extras=True` carries the archetype and seed into the file, so a `.glb` on disk
can say what recipe produced it without the run that made it still being open.
"""

import os

import bpy

from . import config
from . import materials
from . import primitives as prim
from . import registry


## Whether to write UV coordinates.
##
## OFF, and that is a real decision rather than an optimisation. Nothing in this kit is
## textured -- every material is a flat Principled BSDF driven by colour, metallic and
## roughness, and the game side assigns materials by ZONE at runtime rather than
## sampling a map. So the UVs Blender generates for its primitives are dead weight:
## about a quarter of the vertex data, describing nothing.
##
## They were also the ONE source of nondeterminism in the whole generator. Two runs
## from the same seeds produced geometry that was bit-for-bit identical and files that
## were not, because Blender's UV generation for a cylinder cap can land a single float
## differently between runs. That made `Head_003 is reproducible` a claim that failed a
## checksum while being true in every way that mattered -- the worst kind of claim to
## have in a README, since the first person to check it concludes the generator is
## unreliable.
##
## Flip this to True if these ever need texturing, and expect exports to stop being
## byte-comparable.
EXPORT_UVS = False


def export_component(obj, path, zone_names=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    for child in obj.children:
        child.select_set(True)
    bpy.context.view_layer.objects.active = obj

    renames = materials.zone_rename() if zone_names else []
    sockets = _bare_socket_names(obj)
    try:
        bpy.ops.export_scene.gltf(
            filepath=path,
            export_format="GLB",
            use_selection=True,
            export_apply=True,
            export_yup=True,
            export_extras=True,
            export_texcoords=EXPORT_UVS,
        )
    finally:
        _restore_socket_names(sockets)
        materials.zone_restore(renames)
    return path


def _bare_socket_names(obj):
    """Renames this component's sockets to their CONTRACT names for one export.

    In the working file every socket empty is prefixed (`Torso_002_HeadSocket`),
    because Blender object names are unique per file and unprefixed ones would collide
    into `HeadSocket.001`, `.002`, `.003` across the roster. The engine, though, looks
    a mount up by its contract name inside a single `.glb` -- so the file has to
    contain `HeadSocket`, exactly.

    Renaming only the component being exported is what makes this safe: no bare name
    is ever taken, so Blender has nothing to disambiguate against and cannot append a
    suffix behind our back. Restoring in a `finally` means a failed export leaves the
    file consistent rather than half-renamed."""
    saved = []
    for child in obj.children:
        if child.type != "EMPTY":
            continue
        bare = child.get("socket")
        if not bare:
            continue
        saved.append((child, child.name))
        child.name = bare
    return saved


def _restore_socket_names(saved):
    for child, name in saved:
        child.name = name


def export_all_components(root=None, zone_names=False, verbose=True):
    """Exports every component in every category collection.

    `zone_names=True` renames the scrapyard materials to the game's `mat_<zone>`
    contract for the duration of the export. Use it for parts headed into Scrapline,
    where `part_materials.gd` recolours by zone and only `paint` takes the team
    colour; leave it off for a standalone kit, where the readable names are worth
    more. The names are always restored afterwards, so the working file is unchanged
    either way."""
    root = root or config.DEFAULT_EXPORT_ROOT
    written = []
    for category in registry.ORDER:
        spec = registry.CATEGORIES[category]
        collection = bpy.data.collections.get(spec.collection)
        if collection is None:
            continue
        for obj in sorted(collection.objects, key=lambda o: o.name):
            if obj.type != "MESH":
                continue
            path = os.path.join(root, spec.export_dir, obj.name + ".glb")
            export_component(obj, path, zone_names=zone_names)
            written.append(path)
            if verbose:
                print("  %-28s %5d tris -> %s"
                      % (obj.name, prim.triangle_count(obj), path))
    if verbose:
        print("  %d component(s) written under %s/" % (len(written), root))
    return written


def export_demo_robots(root=None, zone_names=False, verbose=True):
    """Exports each assembled demo robot as a single GLB.

    Not part of the deliverable kit -- a demo is a check, not a shippable asset -- but
    it is the fastest way to confirm the socket contract survives the export, which is
    the one place it has broken before. If a demo robot imports into an engine
    standing up, the parts will too."""
    root = root or config.DEFAULT_EXPORT_ROOT
    collection = bpy.data.collections.get(config.DEMO_COLLECTION)
    if collection is None:
        return []
    written = []
    for anchor in sorted(collection.objects, key=lambda o: o.name):
        if anchor.type != "EMPTY" or anchor.parent is not None:
            continue
        path = os.path.join(root, "demo", anchor.name + ".glb")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        bpy.ops.object.select_all(action="DESELECT")
        _select_tree(anchor)
        bpy.context.view_layer.objects.active = anchor
        renames = materials.zone_rename() if zone_names else []
        try:
            bpy.ops.export_scene.gltf(filepath=path, export_format="GLB",
                                      use_selection=True, export_apply=True,
                                      export_yup=True, export_extras=True,
                                      export_texcoords=EXPORT_UVS)
        finally:
            materials.zone_restore(renames)
        written.append(path)
        if verbose:
            print("  %-28s -> %s" % (anchor.name, path))
    return written


def _select_tree(obj):
    obj.select_set(True)
    for child in obj.children:
        _select_tree(child)
