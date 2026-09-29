"""TripoSR (MIT: code and weights) on the CPU: one concept image -> one vertex-coloured mesh.
Route C of `docs/plans/models.md` (017), the part that runs on this Mac with no account.

    $ENV/bin/python tools/gen3d/triposr_run.py art/concepts/workshop.png /tmp/ws.obj
    blender --background --python tools/blender/clean_generated.py -- --in /tmp/ws.obj ...

Setup, once (Intel Mac: torch 2.2.2 is the last x86_64 macOS build, and it wants numpy 1):

    git clone https://github.com/VAST-AI-Research/TripoSR.git tools/gen3d/TripoSR   # 107cefd
    uv venv --python 3.12 $ENV
    VIRTUAL_ENV=$ENV uv pip install "torch==2.2.2" "numpy<2" "omegaconf==2.3.0" Pillow \
        "einops==0.7.0" "transformers==4.35.0" trimesh "huggingface-hub<0.26" PyMCubes

The weights (1.7 GB, `stabilityai/TripoSR`) download on first use; after that an image takes
about 15 s to a triplane and 17 s to a mesh on 8 cores. The clone and the environment stay
out of git (`tools/gen3d/.gitignore`).

The image's background is cut by flood fill from the corners (black: TRELLIS's preprocessed
cut-out; white: a raw concept on white), then framed the way TripoSR's run.py frames it.
torchmcubes is replaced by PyMCubes and TripoSR's video and background-removal imports are
stubbed, so nothing has to be compiled.

It reconstructs what the image SHOWS: the sides it cannot see are guessed (grey, lumpy) and a
thin lattice becomes a solid sheet. TRELLIS (MIT) rebuilds the unseen sides properly but needs
an NVIDIA GPU; its public demo (`gradio_queue.py`) runs on Hugging Face ZeroGPU, whose
anonymous quota is too small for one call -- a free account's token gives a few a day.
"""
import argparse
import os
import sys
import time
import types

import mcubes
import numpy as np
import torch
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get("TRIPOSR", os.path.join(HERE, "TripoSR")))


def _marching_cubes(volume, threshold):
    v, f = mcubes.marching_cubes(volume.detach().cpu().numpy().astype(np.float64), float(threshold))
    # torchmcubes returns (k, j, i); the caller swaps back to (i, j, k).
    v = v[:, [2, 1, 0]]
    return torch.from_numpy(v.astype(np.float32)), torch.from_numpy(f.astype(np.int64))


sys.modules["torchmcubes"] = types.SimpleNamespace(marching_cubes=_marching_cubes)
# Imported by tsr/utils.py for video and background removal, neither of which is used here.
sys.modules["imageio"] = types.SimpleNamespace()
sys.modules["rembg"] = types.SimpleNamespace()

from tsr.system import TSR  # noqa: E402


def cut_out(image, background):
    rgb = np.asarray(image.convert("RGB")).astype(np.int32)
    h, w, _ = rgb.shape
    if background == "black":
        near = rgb.max(axis=2) < 12
    else:
        near = rgb.min(axis=2) > 236
    seen = np.zeros((h, w), dtype=bool)
    stack = [(0, 0), (0, w - 1), (h - 1, 0), (h - 1, w - 1)]
    while stack:
        y, x = stack.pop()
        if y < 0 or x < 0 or y >= h or x >= w or seen[y, x] or not near[y, x]:
            continue
        seen[y, x] = True
        stack.extend(((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)))
    alpha = np.where(seen, 0, 255).astype(np.uint8)
    rgba = np.dstack([rgb.astype(np.uint8), alpha])
    return Image.fromarray(rgba, "RGBA")


def frame(rgba, ratio):
    a = np.asarray(rgba)
    ys, xs = np.nonzero(a[:, :, 3])
    crop = a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    side = int(max(crop.shape[0], crop.shape[1]) / ratio)
    canvas = np.zeros((side, side, 4), dtype=np.uint8)
    y0 = (side - crop.shape[0]) // 2
    x0 = (side - crop.shape[1]) // 2
    canvas[y0:y0 + crop.shape[0], x0:x0 + crop.shape[1]] = crop
    f = canvas.astype(np.float32) / 255.0
    rgb = f[:, :, :3] * f[:, :, 3:4] + (1 - f[:, :, 3:4]) * 0.5
    return Image.fromarray((rgb * 255.0).astype(np.uint8)).resize((512, 512), Image.LANCZOS)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("image")
    p.add_argument("out")
    p.add_argument("--mc", type=int, default=256)
    p.add_argument("--ratio", type=float, default=0.85)
    p.add_argument("--mask-from", default="white")
    p.add_argument("--threshold", type=float, default=25.0)
    a = p.parse_args()
    torch.set_num_threads(os.cpu_count() or 8)
    t = time.time()
    image = frame(cut_out(Image.open(a.image), a.mask_from), a.ratio)
    image.save(os.path.splitext(a.out)[0] + "_input.png")
    model = TSR.from_pretrained("stabilityai/TripoSR", config_name="config.yaml", weight_name="model.ckpt")
    model.renderer.set_chunk_size(8192)
    model.to("cpu")
    print("model loaded in %.0fs" % (time.time() - t))
    t = time.time()
    with torch.no_grad():
        codes = model([image], device="cpu")
    print("image -> triplane in %.0fs" % (time.time() - t))
    t = time.time()
    with torch.no_grad():
        mesh = model.extract_mesh(codes, True, resolution=a.mc, threshold=a.threshold)[0]
    print("mesh in %.0fs: %d verts, %d faces" % (time.time() - t, len(mesh.vertices), len(mesh.faces)))
    mesh.export(a.out)
    print("wrote", a.out)


if __name__ == "__main__":
    main()
