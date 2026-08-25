"""Procedural scrap-robot component generator -- entry point.

    blender --background --python tools/blender/scrap_robot_generator.py -- --out exports

Generates 4 heads, 4 torsos, 4 arms, 8 weapons and 4 legs as interchangeable modular
components, assembles demo robots from random combinations, validates the whole kit
against the socket contract, and exports GLB.

The real code lives in `tools/blender/scrapgen/`. This file is the CLI and the five
`generate_*` functions the brief asks for -- deliberately thin, so that the system can
grow without this file growing with it.

## Flags

    --out DIR         export root (default: exports)
    --heads N         per-category counts; also --torsos --arms --weapons --legs
    --demo N          how many demo robots to assemble (default: 3)
    --seed N          seed offset for the demo robot's random picks (default: 1)
    --zones           export materials renamed to the game's `mat_<zone>` contract
    --no-export       generate and validate only
    --no-demo         skip assembly
    --only CATEGORY   generate one category (head|torso|arm|weapon|leg)
    --save FILE.blend save the working file

## Reproducibility

`Head_003` is built from seed 3 and exports to a BYTE-IDENTICAL `.glb` on every run.
That is not a nicety: the review loop for a generator is "generate a batch, keep the
good ones, regenerate", and it does not work if the good ones cannot be got back.

Check it rather than trusting it:

    blender --background --python tools/blender/scrap_robot_generator.py -- --out /tmp/a --no-demo
    blender --background --python tools/blender/scrap_robot_generator.py -- --out /tmp/b --no-demo
    python3 tools/blender/verify_scrap_exports.py /tmp/a --against /tmp/b
"""

import os
import sys

import bpy


# Blender runs this file directly, so its own directory is not importable yet.
_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

# Re-running inside one Blender session would otherwise use the cached modules from
# the previous run, which makes editing a builder look like it changed nothing.
for _stale in [name for name in list(sys.modules) if name.startswith("scrapgen")]:
    del sys.modules[_stale]

from scrapgen import config, materials, primitives as prim, registry, validate  # noqa: E402
from scrapgen import assembly as assembly_module, exporter  # noqa: E402
from scrapgen.rng import ScrapRNG  # noqa: E402


# --- The five generators the brief asks for ----------------------------------
#
# Thin wrappers over the registry. Each takes a seed, returns a finished Component
# whose `.object` is the Blender object, and can be called on its own from Blender's
# text editor or a Python console for one-off experiments.

def generate_head(seed=1, index=None):
    """One head. `generate_head(seed=1)`, `(seed=2)`, `(seed=3)` are three different
    heads, not three sizes of one."""
    return registry.generate("head", index if index is not None else seed, seed)


def generate_torso(seed=1, index=None):
    return registry.generate("torso", index if index is not None else seed, seed)


def generate_arms(seed=1, index=None):
    """One ARM. Named plural to match the brief; a robot's second arm is a mirrored
    instance made at assembly time, not a separately generated component -- generating
    both would double the export for no variation."""
    return registry.generate("arm", index if index is not None else seed, seed)


def generate_weapon(seed=1, index=None):
    return registry.generate("weapon", index if index is not None else seed, seed)


def generate_legs(seed=1, index=None):
    """One LEG. Same reasoning as `generate_arms`."""
    return registry.generate("leg", index if index is not None else seed, seed)


# --- Whole-kit operations ----------------------------------------------------

def export_all_components(root=None, zone_names=False):
    """Every component to `exports/<category>/<Name>.glb`."""
    return exporter.export_all_components(root, zone_names=zone_names)


def validate_components(expected=None, verbose=True):
    """Checks names, collections, sockets, origins, materials and the ground plane."""
    return validate.validate_components(expected, verbose)


def build_kit(counts=None):
    """Fresh scene, materials, and every component."""
    prim.clear_scene()
    materials.build_materials()
    prim.ensure_collection(config.ROOT_COLLECTION)
    prim.ensure_collection(config.SCRATCH_COLLECTION)

    counts = counts or config.DEFAULT_COUNTS
    made = registry.generate_all(counts)

    print("")
    print("=== generated ===")
    for category in registry.ORDER:
        for component in made[category]:
            report = component.connectivity or {}
            detached = report.get("detached", [])
            islands = report.get("islands", 1)
            print("  %-12s %-14s %2d pieces %5d tris  %s"
                  % (component.object.name, component.archetype,
                     report.get("total", 0), component.triangles,
                     ("%d DETACHED GROUP(S)" % len(detached)) if detached else ""))
            for group in detached:
                print("      detached: %s" % ", ".join(group))
    return made


def build_demo_robots(made, count=3, seed=1):
    print("")
    print("=== demo robots ===")
    robots = []
    for index in range(1, count + 1):
        rng = ScrapRNG("demo", seed + index)
        anchor, _ = assembly_module.demo_robot(index, made, rng)
        ok, note = assembly_module.validate_assembly(anchor)
        print("      %s %s" % ("ok  " if ok else "WARN", note))
        robots.append(anchor)
    return robots


# --- CLI ---------------------------------------------------------------------

def _args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = {
        "out": config.DEFAULT_EXPORT_ROOT,
        "counts": dict(config.DEFAULT_COUNTS),
        "demo": 3,
        "seed": 1,
        "zones": False,
        "export": True,
        "assemble": True,
        "only": None,
        "save": None,
    }
    flag_counts = {"--heads": "head", "--torsos": "torso", "--arms": "arm",
                   "--weapons": "weapon", "--legs": "leg"}
    index = 0
    while index < len(argv):
        token = argv[index]
        if token == "--out":
            index += 1
            out["out"] = argv[index]
        elif token in flag_counts:
            index += 1
            out["counts"][flag_counts[token]] = int(argv[index])
        elif token == "--demo":
            index += 1
            out["demo"] = int(argv[index])
        elif token == "--seed":
            index += 1
            out["seed"] = int(argv[index])
        elif token == "--only":
            index += 1
            out["only"] = argv[index]
        elif token == "--save":
            index += 1
            out["save"] = argv[index]
        elif token == "--zones":
            out["zones"] = True
        elif token == "--no-export":
            out["export"] = False
        elif token == "--no-demo":
            out["assemble"] = False
        index += 1
    if out["only"]:
        out["counts"] = {key: (value if key == out["only"] else 0)
                         for key, value in out["counts"].items()}
        out["assemble"] = False
    return out


def main():
    options = _args()

    made = build_kit(options["counts"])

    if options["assemble"] and options["demo"] > 0:
        build_demo_robots(made, options["demo"], options["seed"])

    expected = {key: value for key, value in options["counts"].items() if value}
    ok, _ = validate_components(expected)

    if options["export"]:
        print("")
        print("=== export ===")
        export_all_components(options["out"], zone_names=options["zones"])
        if options["assemble"] and options["demo"] > 0:
            exporter.export_demo_robots(options["out"], zone_names=options["zones"])

    if options["save"]:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath(options["save"]))
        print("")
        print("  saved %s" % options["save"])

    # A non-zero exit is what makes this usable in a build step. A generator that
    # reports a broken socket contract and exits 0 gets ignored by every script that
    # calls it.
    if not ok:
        sys.exit(1)


if __name__ == "__main__":
    main()
