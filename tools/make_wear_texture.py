#!/usr/bin/env python3
"""Bake the worn-paint map every machine's paint zone is multiplied by.

    python3 tools/make_wear_texture.py

Reads Poly Haven's `rusty_painted_metal` (CC0; art/thirdparty/polyhaven) and writes
`art/textures/paint_wear.png`: WHITE where the paint survives -- keeping the photograph's
own streaks and grime as shades of grey -- and rust-orange where it has worn through.

Why a baked map and not the photograph: the photograph is RED paint. Multiplied by a
yellow livery it would come out brown. Stripped of its hue it becomes a wear mask any
livery can wear: `livery x white = livery`, `livery x rust-orange = the chip where that
livery has rusted through`. The rust patches are found from the roughness map (rust is the
roughest thing on the sheet), so the chips land exactly where the photograph's rust is.

This keeps the paint zone a plain StandardMaterial3D (triplanar, its normal map intact) --
no custom shader, nothing the Compatibility renderer might treat differently.
"""
import os
import statistics

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "art", "thirdparty", "polyhaven", "textures", "rusty_painted_metal", "rusty_painted_metal_")
OUT = os.path.join(ROOT, "art", "textures", "paint_wear.png")

# Rust starts where the source roughness passes RUST_FROM and is full by RUST_FROM + RUST_SPAN.
RUST_FROM = 0.80
RUST_SPAN = 0.10
# How strongly the photograph's streaks darken the paint: 1.0 keeps them all, 0 none.
# Kept under 1 so a livery still reads as its colour at 40 px.
STREAK = 0.7
# The colour a livery becomes where it has worn through, as a multiplier of the livery.
RUST = (0.62, 0.34, 0.18)


def main() -> None:
    diff = Image.open(SOURCE + "diff_1k.jpg").convert("RGB")
    rough = Image.open(SOURCE + "rough_1k.jpg").convert("L")
    width, height = diff.size
    d = diff.load()
    r = rough.load()
    lums = []
    for y in range(0, height, 8):
        for x in range(0, width, 8):
            red, green, blue = d[x, y]
            lums.append(0.299 * red + 0.587 * green + 0.114 * blue)
    reference = statistics.median(lums)
    out = Image.new("RGB", (width, height))
    o = out.load()
    for y in range(height):
        for x in range(width):
            red, green, blue = d[x, y]
            lum = (0.299 * red + 0.587 * green + 0.114 * blue) / reference
            shade = 1.0 + (min(1.2, lum) - 1.0) * STREAK
            rust = min(1.0, max(0.0, (r[x, y] / 255.0 - RUST_FROM) / RUST_SPAN))
            colour = [shade * (1.0 - rust) + (RUST[i] * shade + 0.03) * rust for i in range(3)]
            o[x, y] = tuple(int(max(0.0, min(1.0, v)) * 255) for v in colour)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    out.save(OUT)
    print("wrote", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
