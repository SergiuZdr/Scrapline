"""Verifies exported scrap components by reading the GLB files back.

    python3 tools/blender/verify_scrap_exports.py exports

**Checking the art in Blender is not checking the art.** This project has already shipped
a roster that was connected and correct in Blender and arrived in the engine lying on its
back with both arms on the floor: the fault was in the EXPORT, and no amount of checking on
the side that is correct can find it. `check_parts.py` passed that roster.

So this runs OUTSIDE Blender, on the bytes that actually ship. It parses the GLB container
directly -- no Blender, no Godot, no glTF library -- and asks the questions an engine will
ask when it loads the file:

* is there a node named exactly `HeadSocket`, or did Blender's per-file unique naming turn
  it into `HeadSocket.003` on the way out?
* is that node where the socket contract says, **in glTF's coordinate system**? Blender is
  Z-up and glTF is Y-up, so a correct component has its head mount at y=0.78, not z=0.78.
  Getting `export_yup` wrong produces files that import, assemble, and lie down.
* is the socket a CHILD of the mesh node, so a runtime that parents to it inherits the
  right frame?
* does the file carry meshes and materials at all?

Exit code 1 if anything fails, so it can sit in a build step.
"""

import json
import os
import struct
import sys


# The socket contract, restated in glTF terms. Duplicated from `scrapgen/sockets.py`
# ON PURPOSE: a checker that imports the thing it is checking agrees with it by
# construction and cannot catch a contract that changed by accident. These numbers are
# what the ENGINE expects, written out independently.
#
# Blender (x, y, z) -> glTF (x, z, -y), which is what `export_yup=True` performs.
CONTRACT = {
    "heads": {
        "prefix": "Head",
        "sockets": {"NeckSocket": (0.0, 0.0, 0.0)},
    },
    "torsos": {
        "prefix": "Torso",
        "sockets": {
            "HeadSocket":       (0.0, 0.78, 0.0),
            "ShoulderSocket_L": (0.34, 0.60, 0.0),
            "ShoulderSocket_R": (-0.34, 0.60, 0.0),
            "HipSocket_L":      (0.17, 0.0, 0.0),
            "HipSocket_R":      (-0.17, 0.0, 0.0),
        },
    },
    "arms": {
        "prefix": "Arm",
        "sockets": {
            "ShoulderSocket": (0.0, 0.0, 0.0),
            "WeaponSocket":   (0.0, -0.62, -0.10),
        },
    },
    "legs": {
        "prefix": "Leg",
        "sockets": {"HipSocket": (0.0, 0.0, 0.0)},
    },
    "weapons": {
        "prefix": "Weapon",
        # MuzzleSocket is deliberately free -- a sawblade and a rail lance do not have a
        # barrel tip in the same place -- so it is checked for existence only.
        "sockets": {"MountSocket": (0.0, 0.0, 0.0)},
        "present_only": ["MuzzleSocket"],
    },
}

TOLERANCE = 1e-3


def read_glb(path):
    """The JSON chunk of a GLB. Written out by hand because pulling in a glTF library
    to read twelve bytes of header would make this checker depend on the same ecosystem
    it exists to check."""
    with open(path, "rb") as handle:
        data = handle.read()
    magic, version, _length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF":
        raise ValueError("%s is not a GLB (magic %r)" % (path, magic))
    if version != 2:
        raise ValueError("%s is glTF version %d, expected 2" % (path, version))
    offset = 12
    while offset < len(data):
        chunk_length, chunk_type = struct.unpack_from("<II", data, offset)
        body = data[offset + 8:offset + 8 + chunk_length]
        if chunk_type == 0x4E4F534A:  # 'JSON'
            return json.loads(body.decode("utf-8"))
        offset += 8 + chunk_length + (-chunk_length % 4)
    raise ValueError("%s has no JSON chunk" % path)


def check_file(path, spec, problems):
    name = os.path.splitext(os.path.basename(path))[0]
    gltf = read_glb(path)
    nodes = gltf.get("nodes", [])
    by_name = {}
    for index, node in enumerate(nodes):
        by_name.setdefault(node.get("name", "<unnamed>"), index)

    def fail(message):
        problems.append("%-14s %s" % (name, message))

    if not gltf.get("meshes"):
        fail("no meshes in the file")
    if not gltf.get("materials"):
        fail("no materials in the file")

    root_index = by_name.get(name)
    if root_index is None:
        fail("no node named %r (nodes: %s)"
             % (name, ", ".join(sorted(by_name)[:8])))
        return
    root = nodes[root_index]
    children = set(root.get("children", []))

    for socket, expected in spec["sockets"].items():
        index = by_name.get(socket)
        if index is None:
            fail("MISSING socket %r -- names present: %s"
                 % (socket, ", ".join(sorted(by_name))))
            continue
        if index not in children:
            fail("socket %r is not a child of %r" % (socket, name))
        actual = nodes[index].get("translation", [0.0, 0.0, 0.0])
        drift = max(abs(actual[axis] - expected[axis]) for axis in range(3))
        if drift > TOLERANCE:
            fail("socket %s at (%.3f, %.3f, %.3f), contract says (%.3f, %.3f, %.3f)"
                 % (socket, actual[0], actual[1], actual[2],
                    expected[0], expected[1], expected[2]))

    for socket in spec.get("present_only", []):
        if socket not in by_name:
            fail("MISSING free socket %r" % socket)


def check_reproducible(root, other, problems):
    """Compares two export trees byte for byte.

    A plain checksum is the right test here, and it took work to make it so. Blender's
    polygon ordering varies between processes even when the geometry is bit-identical,
    so exports used to differ in their index buffers while describing exactly the same
    object -- which meant the honest reproducibility guarantee could not be checked
    with the obvious tool, and looked false to anyone who tried. `primitives.canonicalise`
    sorts faces into a fixed order for exactly this reason, so `md5` now answers the
    question directly.

    Run it as two generations into two directories: if a component's bytes differ, a
    seed has stopped meaning one particular object, and the review loop this generator
    is built around ("generate a batch, keep the good ones, regenerate") is broken."""
    import hashlib

    for folder in sorted(CONTRACT):
        directory = os.path.join(root, folder)
        mirror = os.path.join(other, folder)
        if not os.path.isdir(directory) or not os.path.isdir(mirror):
            problems.append("%-14s cannot compare %s" % ("(repro)", folder))
            continue
        for filename in sorted(f for f in os.listdir(directory) if f.endswith(".glb")):
            left = os.path.join(directory, filename)
            right = os.path.join(mirror, filename)
            if not os.path.exists(right):
                problems.append("%-14s missing from %s" % (filename, other))
                continue
            with open(left, "rb") as a, open(right, "rb") as b:
                if hashlib.md5(a.read()).digest() != hashlib.md5(b.read()).digest():
                    problems.append("%-14s NOT REPRODUCIBLE -- differs between runs"
                                    % filename)


def main():
    argv = sys.argv[1:]
    against = None
    if "--against" in argv:
        position = argv.index("--against")
        against = argv[position + 1]
        argv = argv[:position] + argv[position + 2:]
    root = argv[0] if argv else "exports"
    problems = []
    checked = 0

    for folder, spec in sorted(CONTRACT.items()):
        directory = os.path.join(root, folder)
        if not os.path.isdir(directory):
            problems.append("%-14s directory %s does not exist" % ("(kit)", directory))
            continue
        files = sorted(f for f in os.listdir(directory) if f.endswith(".glb"))
        if not files:
            problems.append("%-14s no .glb files in %s" % ("(kit)", directory))
        for filename in files:
            check_file(os.path.join(directory, filename), spec, problems)
            checked += 1

    if against:
        check_reproducible(root, against, problems)

    print("=== verify_scrap_exports ===")
    print("  %d component file(s) checked under %s/" % (checked, root))
    if against:
        print("  reproducibility compared against %s/" % against)
    if problems:
        print("")
        for problem in problems:
            print("  [FAIL] %s" % problem)
        print("")
        print("  %d problem(s)  FAIL" % len(problems))
        sys.exit(1)
    print("  every socket present, correctly parented, and at its contracted "
          "position in glTF's Y-up frame")
    print("  PASS")


if __name__ == "__main__":
    main()
