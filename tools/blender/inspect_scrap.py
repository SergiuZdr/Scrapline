"""Renders the generated kit for review.

    blender --background --python tools/blender/inspect_scrap.py -- --out art/scrapgen
    blender --background --python tools/blender/inspect_scrap.py -- --out art/scrapgen --robots 6
    python3 tools/blender/compose_sheet.py art/scrapgen/components art/scrapgen/sheet.png 5

Two sheets, and they answer different questions:

* **components** -- one frame per part, same angle, same scale. The question is whether
  four heads look like FOUR heads. A generator that varies plate counts and bolt
  patterns passes every automated check and produces a roster nobody can tell apart,
  and this is the only view that shows it.
* **robots** -- assembled demo machines. The question is whether the parts belong to
  each other: proportions, and whether an arm from one archetype reads as the same
  scale of object as a torso from another.

Lighting here is deliberately FLAT and BRIGHT, not a moody key. This is a geometry
review, and a night key hides exactly the seams and gaps it exists to hunt for -- which
is the same reason `inspect_parts.py` and `hero_render.py` are separate tools in this
repo and must both keep existing.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)
for _stale in [name for name in list(sys.modules) if name.startswith("scrapgen")]:
    del sys.modules[_stale]

from scrapgen import config, materials, primitives as prim, registry  # noqa: E402
from scrapgen import assembly as assembly_module  # noqa: E402
from scrapgen.rng import ScrapRNG  # noqa: E402


RESOLUTION = 640


def setup_render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT" if hasattr(bpy.types, "SceneEEVEE") \
        else "BLENDER_EEVEE"
    scene.render.resolution_x = RESOLUTION
    scene.render.resolution_y = RESOLUTION
    scene.render.film_transparent = False
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.15, 0.16, 0.18, 1)


## Camera azimuth, in the convention below: the camera sits at
## `(sin(yaw), -cos(yaw), ...)`, so yaw=0 is behind the subject and yaw=180 is dead in
## front of it. Constructs FACE +Y, so a three-quarter FRONT view is around 135.
##
## Worth stating explicitly because the first sheet out of this script was rendered at
## 38 -- a three-quarter view of the roster's BACKS. Every face, visor, lens and radiator
## was hidden, and every weapon projected directly away from the camera behind the arm
## holding it, so the robots appeared to be unarmed. The renders looked entirely
## plausible; they were simply of the wrong side.
YAW_THREE_QUARTER_FRONT = 135.0

## Weapons project along +Y. Dead-front points the barrel at the lens and an eight-frame
## sheet shows eight circles; this is far enough round to read length.
YAW_WEAPON = 105.0


def frame_objects(objects, yaw=YAW_THREE_QUARTER_FRONT, pitch=72.0, margin=1.32):
    """Fits the camera to real vertices, not to bounding boxes.

    A forward-projecting weapon makes the depth extent huge while adding almost nothing
    to screen width, so solving the camera from `max(width, depth)` pulls it far enough
    back that the subject is a speck in the middle of the frame."""
    bpy.context.view_layer.update()
    lo = None
    hi = None
    for obj in objects:
        if obj.type != "MESH":
            continue
        obj_lo, obj_hi = prim.world_bounds(obj)
        lo = list(obj_lo) if lo is None else [min(lo[i], obj_lo[i]) for i in range(3)]
        hi = list(obj_hi) if hi is None else [max(hi[i], obj_hi[i]) for i in range(3)]
    if lo is None:
        return None

    centre = Vector([(lo[i] + hi[i]) * 0.5 for i in range(3)])
    extent = max(hi[0] - lo[0], hi[2] - lo[2], (hi[1] - lo[1]) * 0.55, 0.25)
    distance = extent * margin * 2.0

    yaw_r = math.radians(yaw)
    pitch_r = math.radians(pitch)
    offset = Vector((math.sin(yaw_r) * math.sin(pitch_r),
                     -math.cos(yaw_r) * math.sin(pitch_r),
                     math.cos(pitch_r))) * distance

    for old in [o for o in bpy.data.objects if o.type == "CAMERA"]:
        bpy.data.objects.remove(old, do_unlink=True)
    bpy.ops.object.camera_add(location=tuple(centre + offset))
    camera = bpy.context.active_object
    camera.data.lens = 60
    bpy.context.scene.camera = camera

    direction = centre - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    return camera


def setup_lights():
    for old in [o for o in bpy.data.objects if o.type == "LIGHT"]:
        bpy.data.objects.remove(old, do_unlink=True)
    # Bright enough to show every seam, dim enough that VALUES are still comparable.
    # The first rig ran nearly twice this and clipped the top of the range: every
    # material above mid-grey rendered as the same white, so a palette change made no
    # visible difference and the roster looked like clean plastic no matter what the
    # albedo said. An inspection light that destroys the thing being inspected is worse
    # than no render.
    for location, energy, size in (((3, -3, 4), 180, 4.0), ((-4, -2, 2), 100, 5.0),
                                   ((0, 4, 3), 130, 4.0), ((0, -1, -3), 55, 6.0)):
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.active_object
        light.data.energy = energy
        light.data.size = size
        light.rotation_euler = (Vector((0, 0, 0)) - Vector(location)) \
            .to_track_quat("-Z", "Y").to_euler()


def hide_all(except_objects):
    keep = set()
    for obj in except_objects:
        keep.add(obj.name)
        for child in obj.children:
            keep.add(child.name)
    for obj in bpy.data.objects:
        if obj.type in ("CAMERA", "LIGHT"):
            continue
        obj.hide_render = obj.name not in keep


def render_to(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = "art/scrapgen"
    robots = 3
    index = 0
    while index < len(argv):
        if argv[index] == "--out":
            index += 1
            out = argv[index]
        elif argv[index] == "--robots":
            index += 1
            robots = int(argv[index])
        index += 1

    prim.clear_scene()
    materials.build_materials()
    prim.ensure_collection(config.ROOT_COLLECTION)
    prim.ensure_collection(config.SCRATCH_COLLECTION)
    made = registry.generate_all()

    setup_render()
    setup_lights()

    # One frame per component, in a fixed order so the composed sheet reads by row.
    frame = 0
    for category in registry.ORDER:
        for component in made[category]:
            hide_all([component.object])
            yaw = YAW_WEAPON if category == "weapon" else YAW_THREE_QUARTER_FRONT
            frame_objects([component.object], yaw=yaw)
            render_to(os.path.join(out, "components", "%03d.png" % frame))
            print("  %s -> %03d.png" % (component.object.name, frame))
            frame += 1

    for number in range(1, robots + 1):
        rng = ScrapRNG("preview", number)
        anchor, _ = assembly_module.demo_robot(number, made, rng)
        parts = [child for child in anchor.children if child.type == "MESH"]
        hide_all(parts)
        frame_objects(parts, yaw=YAW_THREE_QUARTER_FRONT - 20.0, pitch=78.0,
                      margin=1.15)
        render_to(os.path.join(out, "robots", "%03d.png" % (number - 1)))

    print("")
    print("  components -> %s/components  (%d frames)" % (out, frame))
    print("  robots     -> %s/robots      (%d frames)" % (out, robots))
    print("  compose:   python3 tools/blender/compose_sheet.py %s/components "
          "%s/sheet.png 5" % (out, out))


if __name__ == "__main__":
    main()
