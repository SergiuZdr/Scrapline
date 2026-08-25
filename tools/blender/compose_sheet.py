"""Composes rendered views into one strip, so a turnaround is a single image to look at.

    python3 tools/blender/compose_sheet.py art/preview/turn art/preview/turn.png

Runs under SYSTEM python (it needs PIL), not Blender's bundled interpreter.

Six separate PNGs are six separate things to open, and in practice that means only the
first one gets looked at properly -- which is exactly how a roster of parts with detached
shoulders passed inspection. One strip makes every angle unavoidable.
"""

import os
import sys

from PIL import Image


def main():
    source = sys.argv[1] if len(sys.argv) > 1 else "art/preview/turn"
    target = sys.argv[2] if len(sys.argv) > 2 else "art/preview/turn.png"
    columns = int(sys.argv[3]) if len(sys.argv) > 3 else 0

    names = sorted(n for n in os.listdir(source) if n.endswith(".png"))
    if not names:
        print(f"no PNGs in {source}")
        return

    tiles = [Image.open(os.path.join(source, n)).convert("RGB") for n in names]
    width, height = tiles[0].size
    if columns <= 0:
        columns = len(tiles)
    rows = (len(tiles) + columns - 1) // columns

    sheet = Image.new("RGB", (width * columns, height * rows), (28, 30, 33))
    for index, tile in enumerate(tiles):
        sheet.paste(tile, ((index % columns) * width, (index // columns) * height))

    os.makedirs(os.path.dirname(target) or ".", exist_ok=True)
    sheet.save(target)
    print(f"composed {len(tiles)} views -> {target} ({sheet.size[0]}x{sheet.size[1]})")


if __name__ == "__main__":
    main()
