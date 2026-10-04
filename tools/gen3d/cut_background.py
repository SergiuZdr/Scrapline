"""Cuts a concept's white background into transparency (020), so TRELLIS takes the shape from
our mask instead of its own background removal -- which once kept part of the white floor under
the gate and grew a white mound out of it.

    blender --background --python tools/gen3d/cut_background.py -- in.png out.png

Flood fill from the four corners over near-white pixels (numpy dilation, no PIL needed), then
the edge is softened by one pixel.
"""
import sys

import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1:]
source, target = args[0], args[1]
image = bpy.data.images.load(source)
w, h = image.size
px = np.array(image.pixels[:], dtype=np.float32).reshape(h, w, 4)
rgb = px[:, :, :3]
near_white = (rgb.min(axis=2) > 0.90) & ((rgb.max(axis=2) - rgb.min(axis=2)) < 0.08)
region = np.zeros((h, w), dtype=bool)
for y, x in ((0, 0), (0, w - 1), (h - 1, 0), (h - 1, w - 1)):
    region[y, x] = near_white[y, x]
while True:
    grown = region.copy()
    grown[1:, :] |= region[:-1, :]
    grown[:-1, :] |= region[1:, :]
    grown[:, 1:] |= region[:, :-1]
    grown[:, :-1] |= region[:, 1:]
    grown &= near_white
    if (grown == region).all():
        break
    region = grown
# 044: a pocket of background shut in by ropes or a fence (the warlord's crane, the arena's
# fence panels) never touches a corner. Near-PURE white anywhere is background too -- but only in
# patches bigger than a highlight: an opening (erode, then dilate) keeps a lit bulb or a glint on
# the object. A pale slab (the auction's, ~0.84) stays well below the threshold.
pure = (rgb.min(axis=2) > 0.972) & ((rgb.max(axis=2) - rgb.min(axis=2)) < 0.04)
opened = pure.copy()
for _ in range(3):
    inner = opened[1:-1, 1:-1] & opened[:-2, 1:-1] & opened[2:, 1:-1] & opened[1:-1, :-2] & opened[1:-1, 2:]
    opened = np.zeros_like(opened)
    opened[1:-1, 1:-1] = inner
for _ in range(3):
    grown = opened.copy()
    grown[1:, :] |= opened[:-1, :]
    grown[:-1, :] |= opened[1:, :]
    grown[:, 1:] |= opened[:, :-1]
    grown[:, :-1] |= opened[:, 1:]
    opened = grown & pure
region |= opened
alpha = np.where(region, 0.0, 1.0).astype(np.float32)
soft = alpha.copy()
soft[1:-1, 1:-1] = (alpha[1:-1, 1:-1] * 4 + alpha[:-2, 1:-1] + alpha[2:, 1:-1] + alpha[1:-1, :-2] + alpha[1:-1, 2:]) / 8.0
px[:, :, 3] = soft
out = bpy.data.images.new("cut", w, h, alpha=True)
out.pixels[:] = px.reshape(-1)
out.filepath_raw = target
out.file_format = "PNG"
out.save()
print("cut: %.0f%% of the image is background" % (100.0 * region.mean()))
