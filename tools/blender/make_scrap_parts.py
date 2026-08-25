"""Builds Scrapline's playable part roster out of the scrap robot generator.

    blender --background --python tools/blender/make_scrap_parts.py -- --out art/parts
    $GODOT --headless --path . --script res://tools/verify_assembly.gd

This is the bridge between two systems that were designed apart: `scrapgen/` generates
interchangeable scrap components against its OWN socket contract, and the game consumes
a fixed roster of 40 parts against a DIFFERENT one. Nothing here changes either
contract. It composes scrapgen output into the shape the game already knows how to load,
so `data/parts/*.json`, `ContentDB`, `ConstructView`, `ConstructRig` and the entire
simulation are untouched.

## The two contracts, and how they map

The game's construct is five slots: `chassis`, `core`, `arm_l`, `arm_r`, `module`. The
generator's is five categories: torso, head, arm, weapon, leg. They are not the same
five, and pretending they were is where this would have gone wrong:

| Game slot | Built from | Why |
|---|---|---|
| `chassis` | torso + head + two legs, fused | The game has no head slot, and a head is not optional -- a machine without one reads as decapitated, not as modular |
| `core`    | a reactor built from greeble | The generator has no core. The core carries the DAMAGE-TYPE colour, which is the fastest read on the battlefield, so it has to exist |
| `arm_l/r` | arm + weapon, fused | The game's "arm" IS the weapon. Fusing keeps `weapon_class` driving both the model and the attack animation |
| `module`  | a small salvage assembly | Ditto: no generator equivalent, and it is the one slot that may carry hazard ochre |

## What the game requires, and where each requirement is met

* Feet at z=0 and the frame standing up — `_compose_chassis`, which lifts by LEG_LENGTH.
* Legs as separate objects named `limb_leg_l` / `limb_leg_r`, **origin on the hip**, or
  `ConstructRig` has nothing to rotate and the roster slides around without walking.
* Empties `socket_core`, `socket_arm_l`, `socket_arm_r`, `socket_module`.
* Attachments modelled with their mount **at the origin**.
* Blender **-Y is the game's forward**. The generator builds along +Y, so every part is
  turned 180° about Z on the way out. That rotation also maps the generator's `_L` to
  the game's `_l` on both shoulders and hips, which is why it is a rotation and not a
  mirror -- a mirror would flip the handedness of every asymmetric detail as well.
* Materials named `mat_<zone>`, because `PartMaterials` recolours by zone and only
  `paint` takes the team tint. Without it, two teams of six render identically.

## One scale for the whole kit

`SCALE` is applied to every part, not tuned per slot. A modular kit whose arms and
chassis are scaled independently stops fitting together the moment either is retuned,
and the fitting-together is the entire point.
"""

import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

_HERE = os.path.dirname(os.path.abspath(__file__))
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)
for _stale in [name for name in list(sys.modules) if name.startswith("scrapgen")]:
    del sys.modules[_stale]

from scrapgen import config, greeble as gr, materials, primitives as prim  # noqa: E402
from scrapgen import registry  # noqa: E402
from scrapgen.component import socket_name  # noqa: E402
from scrapgen.rng import ScrapRNG  # noqa: E402


## Generator metres to game metres.
##
## A generated robot stands 1.66 m to the shoulders of its torso; the game's roster is
## authored around 0.7 m and everything else -- terrain tiles, the arena kit, the camera
## framing, the height the name tags float at -- is built to that. Scaling the parts is
## a single number; rescaling the world is not.
SCALE = 0.43

## Where the game's chassis sockets sit, as fractions of the generator's torso. Held
## here rather than inside the composer so the four mount points can be read at once --
## they are a contract, and a contract spread across a function body is one nobody
## checks.
CORE_HEIGHT = 0.60      # up the torso, at the chest
CORE_FRONT = 0.30       # ...and proud of its front face
MODULE_HEIGHT = 0.52    # on the back
MODULE_BACK = 0.30

## Chassis role to the silhouette it is built from. Role is what a player has to read
## mid-fight -- an anchor must look planted and a marksman must look fragile -- so it
## drives the archetype rather than being left to the seed.
## Two builds per role, picked by seed. One combination per role made the ten chassis
## read as four machines: the archetype is by far the strongest shape cue, and detail
## variation underneath it does not survive being 80 px tall on a battlefield. Two each
## is eight distinct frames across a roster of ten, which is close to the most a player
## can actually tell apart at that size.
ROLE_LOOK = {
    "brawler":  [("plated_box", "hoof_strut"), ("engine_block", "piston_column")],
    "anchor":   [("boiler", "hoof_strut"), ("plated_box", "piston_column")],
    "marksman": [("cage_frame", "digitigrade"), ("boiler", "caged_leg")],
    "line":     [("engine_block", "piston_column"), ("cage_frame", "hoof_strut")],
}

## `weapon_class` to weapon archetype. The same field drives the attack animation in
## `ConstructRig`, so the motion and the silhouette cannot describe two different
## weapons -- which is the property the game's own arm generator exists to protect.
WEAPON_LOOK = {
    "hammer":  "sledge",
    "maul":    "sledge",
    "ripper":  "grapple_claw",
    "saw":     "saw_blade",
    "lance":   "rail_lance",
    "railgun": "rail_lance",
    "scatter": "rivet_gun",
    "rifle":   "rivet_gun",
    "mortar":  "slug_cannon",
    "pulse":   "flamer",
    "coil":    "flamer",
    "scanner": "sensor_mast",
}

## Damage type to the emissive zone its core lens carries. These names are the game's,
## not the generator's, and they are written straight onto the material so
## `PartMaterials.zone_of` resolves them.
DAMAGE_ZONES = ["kinetic", "thermal", "emp", "corrosive"]


def part_seed(part_id):
    """A stable seed per part id, so `ch_brute` is the same machine in every build."""
    return ScrapRNG("scrapline", 0).__class__("scrapline/" + part_id, 1).seed_value + \
        sum(ord(c) * (i + 1) for i, c in enumerate(part_id))


def rng_for(part_id):
    return ScrapRNG("scrapline/" + part_id, 7)


# --- Transform helpers -------------------------------------------------------

def apply_matrix(objects, matrix):
    """Applies a world transform to objects and BAKES the rotation and scale.

    Location is deliberately not applied: baking it would move every origin to the
    world origin, and a leg's origin IS its hip joint. That is the single fact
    `ConstructRig` depends on to walk."""
    for obj in objects:
        obj.matrix_world = matrix @ obj.matrix_world
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


## The generator faces +Y; the game faces -Y. A rotation, never a mirror.
TO_GAME = Matrix.Rotation(math.pi, 4, "Z")


def game_matrix(lift, bulk=1.0):
    return Matrix.Scale(SCALE * bulk, 4) @ TO_GAME @ Matrix.Translation((0.0, 0.0, lift))


def to_game_point(point, lift, bulk=1.0):
    return game_matrix(lift, bulk) @ Vector(point)


def bulk_of(part):
    """How big this frame is, from its health.

    A Citadel has 1320 HP and a Strider has 470, and before this they were the same
    size: the roster looked interchangeable and the one thing a player most needs to
    read across a battlefield -- is that a heavy or a scout -- was not on the model at
    all. The old generator scaled by the same number, and it was doing real work.

    Kept to a narrow band. Arms and cores are built at a fixed scale, because they are
    standard parts bolted onto whatever frame will take them, and a chassis that varied
    by 40% would leave the biggest one holding visibly toy-sized weapons."""
    hp = float(part.get("hp", 800))
    return min(1.12, max(0.90, 0.90 + (hp - 470.0) / 3400.0))


def recolour(obj, from_material, to_material):
    """Swaps one palette material for another on a finished component.

    Per-object rather than per-piece, because the generator has already joined the
    pieces by the time the game's zone doctrine needs applying -- and because "legs are
    structure" is a statement about a whole limb, not about individual bolts."""
    target = materials.get(to_material)
    for index, slot in enumerate(obj.data.materials):
        if slot is not None and slot.name == from_material:
            obj.data.materials[index] = target


# --- Slot builders -----------------------------------------------------------

def build_chassis(part_id, part):
    """Torso + head + two legs, standing on z=0, with the game's four sockets."""
    role = str(part.get("role", "line"))
    seed = abs(hash_id(part_id))
    looks = ROLE_LOOK.get(role, ROLE_LOOK["line"])
    torso_look, leg_look = looks[seed % len(looks)]

    torso = registry.generate("torso", 1, seed=seed, archetype=torso_look).object
    head = registry.generate("head", 2, seed=seed + 1).object
    leg_l = registry.generate("leg", 3, seed=seed + 2, archetype=leg_look).object
    leg_r = registry.generate("leg", 4, seed=seed + 3, archetype=leg_look).object

    # Legs are STRUCTURE, not livery.
    #
    # `DirtyMetal` maps to the `paint` zone, and paint is the only zone the game tints
    # per team. With the generator's default tagging, the shells, hips and knee boxes of
    # both legs all landed in it -- and a construct that is two-thirds team colour is the
    # failure this project already shipped once, where twelve machines read as twelve
    # monochrome silhouettes in red and blue. The zone doctrine is explicit
    # that legs are worn structural gunmetal; this puts them back there.
    for limb in (leg_l, leg_r, head):
        recolour(limb, "DirtyMetal", "OldSteel")

    sockets = socket_table(torso)
    # The head sits on the torso's own HeadSocket, then becomes part of the chassis
    # mesh: the game has no head slot, and leaving it off makes every construct read as
    # decapitated rather than as modular.
    head.location = sockets["HeadSocket"]

    # Legs keep their own origins -- the hip -- and are only moved onto the torso's hip
    # mounts. `mirror_x` on the right leg rather than a second generate, so a pair
    # matches; the flip is why `prim.mirror_x` also flips normals.
    leg_l.location = sockets["HipSocket_L"]
    leg_r.location = sockets["HipSocket_R"]
    prim.mirror_x(leg_r)

    strip_sockets(torso)
    strip_sockets(head)
    strip_sockets(leg_l)
    strip_sockets(leg_r)

    body = prim.join([torso, head], part_id, recentre=False)
    leg_l.name = "limb_leg_l"
    leg_r.name = "limb_leg_r"

    # Lift so the soles land on z=0. The legs hang LEG_LENGTH below their hips, and the
    # hips are at the torso's own origin height, so that one number is the whole answer.
    lift = config.LEG_LENGTH
    matrix = game_matrix(lift, bulk_of(part))
    apply_matrix([body, leg_l, leg_r], matrix)

    for limb in (leg_l, leg_r):
        prim.parent_keeping_transform(limb, body)

    bulk = bulk_of(part)
    half_width = 0.22
    add_socket(body, "socket_core",
               to_game_point((0.0, half_width * CORE_FRONT * 3.0,
                              config.TORSO_HEIGHT * CORE_HEIGHT), lift, bulk))
    add_socket(body, "socket_module",
               to_game_point((0.0, -half_width * MODULE_BACK * 3.0,
                              config.TORSO_HEIGHT * MODULE_HEIGHT), lift, bulk))
    for side, name in ((1.0, "socket_arm_l"), (-1.0, "socket_arm_r")):
        # Taken from the generator's OWN shoulder mounts rather than recomputed, so an
        # arm lands exactly where the torso put a shoulder joint. Recomputing it is how
        # a kit ends up needing a per-chassis offset.
        source = sockets["ShoulderSocket_L" if side > 0 else "ShoulderSocket_R"]
        add_socket(body, name, to_game_point(source, lift, bulk))
    return body


def build_arm(part_id, part):
    """A limb with its weapon fused on, mounted at the shoulder."""
    weapon_class = str(part.get("weapon_class", "rifle"))
    look = WEAPON_LOOK.get(weapon_class, "rivet_gun")
    seed = abs(hash_id(part_id))

    arm = registry.generate("arm", 1, seed=seed).object
    weapon = registry.generate("weapon", 2, seed=seed + 1, archetype=look).object

    weapon.location = socket_table(arm)["WeaponSocket"]
    strip_sockets(arm)
    strip_sockets(weapon)

    # The TORSO carries the team colour and nothing else does.
    #
    # Splitting the tint across torso, head, arms and legs left roughly three quarters
    # of every machine in one flat team hue, which is the exact failure the palette
    # exists to prevent: at battlefield distance the roster stops being weathered
    # machines wearing livery and becomes blue shapes and red shapes. Concentrating it
    # on the chest -- the largest single flat surface, and the one at eye height --
    # keeps the read instant while leaving three quarters of the model as metal.
    recolour(weapon, "DirtyMetal", "OldSteel")
    recolour(arm, "DirtyMetal", "OldSteel")

    fused = prim.join([arm, weapon], part_id, recentre=False)
    apply_matrix([fused], game_matrix(0.0))
    return fused


def build_core(part_id, part):
    """A chest reactor: housing, lens, cooling, plumbing.

    Built here rather than in the generator because it is a GAME concept -- the core
    carries a construct's damage type, and that colour is the fastest read on the
    battlefield for what a machine actually does. The generator has no such idea and
    should not grow one for a single consumer.
    """
    rng = rng_for(part_id)
    damage = str(part.get("damage_type", "kinetic"))
    pieces = []

    pieces.append(prim.taper_box(part_id + "_housing",
                                 (rng.span(0.30, 0.38), rng.span(0.20, 0.26),
                                  rng.span(0.26, 0.34)),
                                 top_scale=(rng.span(0.72, 0.92), rng.span(0.75, 0.95)),
                                 location=(0, 0.030, 0), material="DirtyMetal",
                                 bevel_width=0.014, segments=2))
    pieces.append(prim.cylinder(part_id + "_ring", rng.span(0.090, 0.115), 0.070,
                                location=(0, 0.115, 0), rotation=gr.AXIS_ROTATION["y"],
                                vertices=14, material="DarkMetal"))
    # The lens, and it is SMALL on purpose.
    #
    # This project has already shipped a core lens big enough that every construct read
    # as "a dark box with a white circle on it" -- the emissive is the brightest thing
    # in the palette and it wins any size contest it is entered into. Kinetic damage is
    # near-white, so the worst case is also the most common one. Big enough to carry the
    # damage-type colour at battle distance, small enough that the machine around it is
    # still the subject.
    lens = prim.cylinder(part_id + "_lens", rng.span(0.048, 0.062), 0.040,
                         location=(0, 0.150, 0), rotation=gr.AXIS_ROTATION["y"],
                         vertices=12, material="Glass")
    lens.data.materials.clear()
    lens.data.materials.append(glow_material(damage))
    pieces.append(lens)

    pieces.extend(gr.bolt_ring(part_id + "_bolt", 6, (0, 0.130, 0),
                               rng.span(0.125, 0.150), axis="y", bolt_radius=0.014))
    pieces.extend(gr.grille(part_id + "_vent", rng.count(3, 4), (0, 0.075, -0.115),
                            width=0.20, height=0.09))
    for sign in (1.0, -1.0):
        pieces.extend(gr.pipe_run("%s_pipe_%d" % (part_id, sign > 0),
                                  [(sign * 0.140, 0.060, 0.075),
                                   (sign * 0.175, -0.010, 0.030),
                                   (sign * 0.120, -0.060, -0.060)],
                                  radius=0.020, material="RustyMetal"))
    pieces.extend(gr.weld_seam(part_id + "_weld", (-0.13, 0.090, -0.120),
                               (0.13, 0.090, -0.120), rng, count=4, size=0.016,
                               pieces=pieces))

    fused = prim.join(pieces, part_id, recentre=False)
    apply_matrix([fused], game_matrix(0.0))
    return fused


def build_module(part_id, part):
    """A bolt-on salvage pod. Hazard ochre ONLY when it can overdrive."""
    rng = rng_for(part_id)
    # `can_overdrive` is the game's own field, so the warning colour cannot drift from
    # the behaviour. Hazard means "this construct explodes" and nothing else -- putting
    # it on every module would spend the one colour the palette reserves.
    hot = bool(part.get("can_overdrive", False))
    pieces = []

    pieces.append(prim.box(part_id + "_frame",
                           (rng.span(0.26, 0.34), rng.span(0.16, 0.22),
                            rng.span(0.22, 0.28)),
                           location=(0, 0.020, 0),
                           material="hazard" if False else "DirtyMetal",
                           bevel_width=0.012, segments=2))

    style = rng.pick(["tank", "drum", "radiator", "gearbox"])
    if style == "tank":
        pieces.extend(gr.tank(part_id + "_tank", (0, 0.100, 0.020),
                              radius=rng.span(0.065, 0.085), length=rng.span(0.20, 0.26),
                              axis="x", rng=rng))
    elif style == "drum":
        pieces.extend(gr.drum(part_id + "_drum", (0, 0.095, 0.010),
                              radius=rng.span(0.075, 0.095), height=rng.span(0.16, 0.22),
                              axis="x", rng=rng))
    elif style == "radiator":
        pieces.extend(gr.radiator(part_id + "_rad", (0, 0.100, 0.010),
                                  size=(rng.span(0.22, 0.28), 0.060,
                                        rng.span(0.16, 0.22)),
                                  rng=rng, fins=rng.count(4, 6)))
    else:
        pieces.extend(gr.gear(part_id + "_gear", (0, 0.090, 0.010),
                              radius=rng.span(0.070, 0.095), teeth=rng.count(7, 9),
                              axis="y"))
        pieces.extend(gr.pipe_run(part_id + "_shaft",
                                  [(0, 0.090, 0.010), (0.10, 0.050, -0.060)],
                                  radius=0.022, material="OldSteel"))

    if hot:
        # A warning band, and the exhaust that earns it.
        for index in range(2):
            band = prim.box("%s_hazard_%02d" % (part_id, index),
                            (rng.span(0.28, 0.34), 0.030, 0.045),
                            location=(0, 0.020, -0.070 + index * 0.075),
                            material="DirtyMetal", bevel_width=0.006, segments=1)
            band.data.materials.clear()
            band.data.materials.append(zone_material("hazard", "d9a02b"))
            pieces.append(band)
        pieces.extend(gr.exhaust_stack(part_id + "_stack", (0.085, -0.040, 0.100),
                                       height=rng.span(0.14, 0.20), radius=0.030,
                                       rng=rng))

    pieces.extend(gr.bolt_row(part_id + "_bolt", rng.count(3, 4),
                              (-0.100, -0.075, -0.080), (0.070, 0, 0.055),
                              axis="y", rng=rng, radius=0.014))
    pieces.extend(gr.cable_bundle(part_id + "_loom", (0.090, -0.050, 0.070),
                                  (0.020, -0.070, -0.040), rng, count=2, radius=0.011,
                                  sag=0.04))

    fused = prim.join(pieces, part_id, recentre=False)
    apply_matrix([fused], game_matrix(0.0))
    return fused


# --- Material helpers --------------------------------------------------------

def zone_material(zone, hex_colour, emissive=False):
    """A material named for a GAME zone directly.

    The generator's palette is renamed to `mat_<zone>` at export, but the core lens and
    the hazard band need zones the generator's palette does not have. Naming them
    outright is simpler than teaching the palette about damage types, and it keeps the
    coupling one-way: the generator still knows nothing about Scrapline."""
    name = "mat_" + zone
    material = bpy.data.materials.get(name)
    if material is not None:
        return material
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    colour = materials.srgb(hex_colour)
    bsdf.inputs["Base Color"].default_value = colour
    bsdf.inputs["Roughness"].default_value = 0.35 if emissive else 0.60
    bsdf.inputs["Metallic"].default_value = 0.0 if emissive else 0.10
    if emissive and "Emission Color" in bsdf.inputs:
        bsdf.inputs["Emission Color"].default_value = colour
        bsdf.inputs["Emission Strength"].default_value = 2.4
    return material


GLOW_COLOURS = {
    "kinetic": "dbd6c9",
    "thermal": "ff6b23",
    "emp": "42c2ff",
    "corrosive": "8fdb38",
}


def glow_material(damage_type):
    key = damage_type if damage_type in GLOW_COLOURS else "kinetic"
    return zone_material("glow_" + key, GLOW_COLOURS[key], emissive=True)


# --- Plumbing ----------------------------------------------------------------

def hash_id(text):
    from scrapgen.rng import fnv1a
    return fnv1a(text) % 100000


def socket_table(obj):
    """Contract name -> local position, for a finished generator component."""
    bpy.context.view_layer.update()
    out = {}
    for child in obj.children:
        if child.type != "EMPTY":
            continue
        local = (obj.matrix_world.inverted() @ child.matrix_world).translation
        out[socket_name(child)] = Vector(local)
    return out


def strip_sockets(obj):
    """Removes the generator's sockets. The game's are added afterwards under its own
    names, and leaving both would export a part carrying two mount vocabularies."""
    for child in list(obj.children):
        if child.type == "EMPTY":
            bpy.data.objects.remove(child, do_unlink=True)


def add_socket(parent, name, location):
    bpy.ops.object.empty_add(type="ARROWS", radius=0.06, location=location)
    empty = bpy.context.active_object
    empty.name = name
    prim.parent_keeping_transform(empty, parent)
    return empty


def load_parts(project_root):
    parts = {}
    parts_dir = os.path.join(project_root, "data", "parts")
    for name in sorted(os.listdir(parts_dir)):
        if not name.endswith(".json"):
            continue
        with open(os.path.join(parts_dir, name)) as handle:
            for entry in json.load(handle):
                parts[entry["id"]] = entry
    return parts


def export_part(obj, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    for child in obj.children:
        child.select_set(True)
    bpy.context.view_layer.objects.active = obj
    renames = materials.zone_rename()
    try:
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB",
                                  use_selection=True, export_apply=True,
                                  export_yup=True, export_texcoords=False)
    finally:
        materials.zone_restore(renames)


BUILDERS = {
    "chassis": build_chassis,
    "arm": build_arm,
    "core": build_core,
    "module": build_module,
}


## Thumbnail size, matching the existing `art/thumbs/` set. RGBA on a transparent
## background, because the cards sit on a lighter well in the battle HUD and a baked-in
## backdrop would show as a rectangle behind every part.
THUMB_SIZE = 224


def setup_thumb_render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT" if hasattr(bpy.types, "SceneEEVEE") \
        else "BLENDER_EEVEE"
    scene.render.resolution_x = THUMB_SIZE
    scene.render.resolution_y = THUMB_SIZE
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"


def render_thumbnail(obj, path):
    """One card image per part, rendered from the SAME mesh that was just exported.

    Regenerating these is not optional when the roster changes. The loadout screen and
    the Order Phase unit cards both read `art/thumbs/`, and the whole point of that
    shared directory is that a part looks identical in the garage and in the fight. Ship
    new geometry against the old thumbnails and every card in the game becomes a picture
    of a part that no longer exists -- which is worse than no picture, because it is
    wrong rather than missing."""
    for stale in [o for o in bpy.data.objects if o.type in ("CAMERA", "LIGHT")]:
        bpy.data.objects.remove(stale, do_unlink=True)

    bpy.context.view_layer.update()
    meshes = [obj] + [c for c in obj.children if c.type == "MESH"]
    lo = None
    hi = None
    for mesh in meshes:
        mesh_lo, mesh_hi = prim.world_bounds(mesh)
        lo = list(mesh_lo) if lo is None else [min(lo[i], mesh_lo[i]) for i in range(3)]
        hi = list(mesh_hi) if hi is None else [max(hi[i], mesh_hi[i]) for i in range(3)]
    centre = Vector([(lo[i] + hi[i]) * 0.5 for i in range(3)])
    extent = max(hi[0] - lo[0], hi[2] - lo[2], (hi[1] - lo[1]) * 0.6, 0.12)
    distance = extent * 2.5

    bpy.ops.object.camera_add(location=(centre.x + distance * 0.62,
                                        centre.y - distance * 0.78,
                                        centre.z + distance * 0.42))
    camera = bpy.context.active_object
    camera.data.lens = 62
    bpy.context.scene.camera = camera
    direction = centre - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    for location, energy in (((2.4, -2.6, 2.8), 260.0), ((-2.6, -1.4, 1.4), 130.0),
                             ((0.4, 2.6, 2.0), 150.0)):
        bpy.ops.object.light_add(type="AREA", location=(centre.x + location[0],
                                                        centre.y + location[1],
                                                        centre.z + location[2]))
        light = bpy.context.active_object
        light.data.energy = energy
        light.data.size = 3.0
        light.rotation_euler = (centre - light.location).to_track_quat("-Z", "Y").to_euler()

    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = "art/parts"
    thumbs = ""
    only = ""
    index = 0
    while index < len(argv):
        if argv[index] == "--out":
            index += 1
            out = argv[index]
        elif argv[index] == "--thumbs":
            index += 1
            thumbs = argv[index]
        elif argv[index] == "--only":
            index += 1
            only = argv[index]
        index += 1

    project_root = os.path.dirname(os.path.dirname(_HERE))
    parts = load_parts(project_root)

    prim.clear_scene()
    materials.build_materials()
    prim.ensure_collection(config.ROOT_COLLECTION)
    scratch = prim.ensure_collection(config.SCRATCH_COLLECTION)
    prim.set_active_collection(scratch)
    if thumbs:
        setup_thumb_render()

    written = 0
    over_budget = []
    for part_id in sorted(parts):
        part = parts[part_id]
        slot = str(part.get("slot", ""))
        if slot not in BUILDERS:
            continue
        if only and part_id != only:
            continue

        obj = BUILDERS[slot](part_id, part)
        triangles = prim.triangle_count(obj)
        path = os.path.join(out, part_id + ".glb")
        export_part(obj, path)
        written += 1
        if thumbs:
            render_thumbnail(obj, os.path.join(thumbs, part_id + ".png"))
        limbs = len([c for c in obj.children if c.type == "MESH"])
        empties = len([c for c in obj.children if c.type == "EMPTY"])
        print("  %-14s %-8s %5d tris  %d limb(s) %d socket(s)"
              % (part_id, slot, triangles, limbs, empties))
        if triangles > 4200:
            over_budget.append((part_id, triangles))

        # Wiped between parts. Forty parts' worth of geometry accumulating in one scene
        # makes every later export slower than the last and the final ones minutes long.
        for stale in list(bpy.data.objects):
            bpy.data.objects.remove(stale, do_unlink=True)
        for block in (bpy.data.meshes, bpy.data.curves):
            for item in list(block):
                if item.users == 0:
                    block.remove(item)

    print("")
    print("  %d part(s) written to %s/" % (written, out))
    for part_id, triangles in over_budget:
        print("  over budget: %s at %d triangles" % (part_id, triangles))


if __name__ == "__main__":
    main()
