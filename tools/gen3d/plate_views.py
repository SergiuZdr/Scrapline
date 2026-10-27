"""085: a plate's front and back, textured, for judging its facing and cutting its ears.

    blender --background --python tools/gen3d/plate_views.py -- art/props/pl_shield.glb shots/085/pl_shield
writes <out>_front.png (camera on -Y, Blender's front) and <out>_back.png.
"""
import math
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "FLAT"
scene.display.shading.color_type = "TEXTURE"
scene.render.resolution_x = scene.render.resolution_y = 512
scene.render.film_transparent = False
scene.world = bpy.data.worlds.new("w")
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = 0.26
scene.collection.objects.link(cam)
scene.camera = cam
for name, y, rz in (("front", -1.0, 0.0), ("back", 1.0, math.pi)):
    cam.location = (0, y, 0.09)
    cam.rotation_euler = (math.pi / 2, 0, rz)
    scene.render.filepath = "%s_%s.png" % (out, name)
    bpy.ops.render.render(write_still=True)
