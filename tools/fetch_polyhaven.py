#!/usr/bin/env python3
"""Fetch CC0 assets from Poly Haven into art/thirdparty/polyhaven/, and record them.

    python3 tools/fetch_polyhaven.py texture rusty_painted_metal asphalt_02
    python3 tools/fetch_polyhaven.py hdri dresden_station_night
    python3 tools/fetch_polyhaven.py model concrete_road_barrier --res 1k

Poly Haven (polyhaven.com) publishes everything under CC0: no attribution is required,
but every asset is still listed in SOURCES.md with its page, so where a file came from is
never a guess. Textures come as JPG (diffuse, OpenGL normal, roughness, AO/rough/metal
packed "arm"); HDRIs as .hdr; models as glTF with their textures beside them.

Only the standard library is used, so it runs anywhere Python 3 does.
"""
import json
import os
import sys
import urllib.request

API = "https://api.polyhaven.com"
ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "art", "thirdparty", "polyhaven")
TEXTURE_MAPS = {"Diffuse": "diff", "nor_gl": "nor_gl", "Rough": "rough", "arm": "arm", "Metal": "metal"}


def _get(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "Scrapline-asset-fetch/1.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def _save(url: str, path: str) -> int:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path):
        return os.path.getsize(path)
    data = _get(url)
    with open(path, "wb") as f:
        f.write(data)
    return len(data)


def fetch(kind: str, asset: str, res: str) -> list:
    files = json.loads(_get(f"{API}/files/{asset}"))
    out_dir = os.path.join(ROOT, kind + "s", asset)
    written = []
    if kind == "texture":
        for key, short in TEXTURE_MAPS.items():
            entry = files.get(key, {}).get(res, {}).get("jpg")
            if entry:
                path = os.path.join(out_dir, f"{asset}_{short}_{res}.jpg")
                written.append((path, _save(entry["url"], path)))
    elif kind == "hdri":
        entry = files["hdri"][res]["hdr"]
        path = os.path.join(out_dir, f"{asset}_{res}.hdr")
        written.append((path, _save(entry["url"], path)))
    elif kind == "model":
        entry = files["gltf"][res]["gltf"]
        path = os.path.join(out_dir, f"{asset}_{res}.gltf")
        written.append((path, _save(entry["url"], path)))
        for relative, include in entry.get("include", {}).items():
            inc_path = os.path.join(out_dir, relative)
            written.append((inc_path, _save(include["url"], inc_path)))
    else:
        raise SystemExit(f"unknown kind {kind!r}: texture, hdri or model")
    _record(kind, asset, res)
    return written


def _record(kind: str, asset: str, res: str) -> None:
    sources = os.path.join(ROOT, "SOURCES.md")
    line = f"| {kind} | `{asset}` | {res} | https://polyhaven.com/a/{asset} | CC0 |\n"
    if not os.path.exists(sources):
        with open(sources, "w") as f:
            f.write("# Poly Haven assets\n\nAll CC0 (https://polyhaven.com/license). Fetched with "
                    "`tools/fetch_polyhaven.py`.\n\n| Kind | Asset | Res | Page | Licence |\n|---|---|---|---|---|\n")
    with open(sources) as f:
        if line in f.read():
            return
    with open(sources, "a") as f:
        f.write(line)


def main(argv: list) -> None:
    if len(argv) < 2:
        raise SystemExit(__doc__)
    res = "1k"
    if "--res" in argv:
        i = argv.index("--res")
        res = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    kind, assets = argv[0], argv[1:]
    for asset in assets:
        total = 0
        for path, size in fetch(kind, asset, res):
            total += size
        print(f"{kind} {asset}: {total / 1e6:.2f} MB")


if __name__ == "__main__":
    main(sys.argv[1:])
