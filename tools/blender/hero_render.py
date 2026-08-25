"""Cycles BEAUTY renders of assembled constructs. The shot you put in a store listing.

    blender --background --python tools/blender/hero_render.py -- --chassis ch_brute
    blender --background --python tools/blender/hero_render.py -- --roster
    blender --background --python tools/blender/hero_render.py -- --chassis ch_reaper --team b --samples 400

Why this is NOT `inspect_parts.py`
----------------------------------
`inspect_parts.py` and `make_parts.render_preview` are deliberately flat, bright and
neutral, and they say so: a moody key hides exactly the seams a geometry check is hunting
for. They are correct and they stay as they are.

This tool has the opposite job. Nothing in the pipeline rendered a construct the way the
GAME lights it, so nothing ever showed what the roster actually looks like -- and a
machine judged only under inspection lighting is a machine nobody has ever really seen.

Three things separate this from the inspection path:

**Cycles, not EEVEE.** Worn metal is almost entirely reflection. EEVEE with no probes has
nothing to reflect, so every surface fell back to its flat base colour and forty
procedural parts rendered as forty pieces of coloured plastic.

**The metallic switch.** `make_parts.zone_material` sets Metallic 0.8 on every zone. That
is the one value the PBR rules single out as always wrong -- it is neither a dielectric
nor a conductor, and it renders energy-non-conservative and plasticky. The game itself
never had this bug: `part_materials.gd` already runs paint at 0.05 and metal at 0.90.
So the numbers below are read FROM the game (`ZONE_SURFACE`), snapped to the switch, and
the Blender-side placeholder is bypassed rather than trusted. The `.glb` export contract
is untouched -- these materials are built at render time and never exported.

**Wear the generator cannot author.** A procedural part is boxes and cylinders with no
UVs, so texture-based wear is not available. The wear here is derived from the geometry
itself: a Bevel node against the true normal finds every edge, and the paint chips off
those edges to bare metal. That single mask is what makes a scrapyard machine look
salvaged instead of freshly moulded, and it costs no texture and no UV pass.

The light rig is the game's own Rust & Sodium: warm sodium key, cold blue fill, cool
neutral surfaces, warmth from the LIGHT and never from the pigment.
"""

import bpy
import importlib.util
import json
import math
import os
import sys

from mathutils import Matrix, Vector


# --- The game's surface values ----------------------------------------------
#
# Mirrors `ZONE_SURFACE` in `scripts/presentation/part_materials.gd`, with metallic
# snapped to 0 or 1. The game's authored values are already on the right side of the
# switch (paint 0.05, rust 0.10, metal 0.90) -- snapping only removes the rounding.
#
# If the game's palette changes, change it there and mirror it here; these two lists
# are the same decision written twice, which the codebase already accepts for
# `ZONE_COLOURS` and calls out in `make_parts.py`.

ZONE_SURFACE = {
    "paint":      dict(roughness=0.62, metallic=0.0, coat=0.25),
    "metal":      dict(roughness=0.40, metallic=1.0),
    "rust":       dict(roughness=0.92, metallic=0.0),
    "dark":       dict(roughness=0.50, metallic=1.0),
    "tread":      dict(roughness=0.95, metallic=0.0),
    "hazard":     dict(roughness=0.60, metallic=0.0, coat=0.30),
    "rock":       dict(roughness=0.98, metallic=0.0),
    "scrapmetal": dict(roughness=0.78, metallic=1.0),
}

# Bare metal showing through a paint chip. One colour for every zone's wear, because the
# frames underneath are all the same salvaged plate.
#
# DARK on purpose. The first pass used a light grey (9a958c) and the wear mask was
# provably correct while being invisible in the render: pale chipped metal and pale lit
# paint sat at the same value, so a perfectly good mask blended one light tone into
# another. Exposed steel on a machine left outside is oxidised and dark, and the contrast
# is the entire point of drawing it.
WEAR_STEEL = "554d45"
# Heaviest wear bleeds to oxide rather than clean metal.
WEAR_RUST = "6d3a1f"

# --- Render-only albedo lifts ------------------------------------------------
#
# A conductor shows almost nothing but what it reflects, so a metal authored near black
# renders BLACK -- the standing rule is that a metal's base colour belongs above ~0.5
# sRGB. `dark` (2b2b30) and `tread` (1b1a19) are far under that, and in a night scene the
# legs, feet, pistons and vents simply left the picture: the first hero renders showed a
# torso apparently hovering over the floor with nothing underneath it.
#
# The GAME is not wrong to author them that way -- it lights with a bright sodium key at
# close range and wants those zones to read as recesses. This is a render-time lift only,
# and it is why these live here rather than in `part_materials.gd`.
HERO_ALBEDO = {
    "dark": "55555e",
    "tread": "302e2c",
}

# `battle_scene.gd` COL_TEAM_A / COL_TEAM_B.
TEAM_COLOURS = {"a": "4fa8d8", "b": "d8654f"}


def load_make_parts():
    """The generator is the single source of geometry. Importing it rather than
    duplicating any builder is what keeps a hero render honest -- it renders the same
    meshes the game ships, not a prettier restatement of them."""
    path = os.path.join(os.path.dirname(__file__), "make_parts.py")
    spec = importlib.util.spec_from_file_location("make_parts", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_parts(root):
    parts = {}
    for name in sorted(os.listdir(os.path.join(root, "data", "parts"))):
        if name.endswith(".json"):
            with open(os.path.join(root, "data", "parts", name)) as handle:
                for entry in json.load(handle):
                    parts[entry["id"]] = entry
    return parts


def srgb(hex_string):
    out = []
    for i in (0, 2, 4):
        c = int(hex_string[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


# --- Node helpers ------------------------------------------------------------

def sock(node, name, index=0):
    """A node socket by name, skipping the disabled duplicates.

    `ShaderNodeMix` carries one A/B/Result pair per data type and disables all but the
    active one. Every pair answers to the same name, so a plain `node.inputs['A']`
    returns the FLOAT socket while the node is in RGBA mode -- it links without error and
    silently does nothing. Filtering on `enabled` is what makes the lookup mean what it
    reads like."""
    hits = [s for s in node.inputs if s.name == name and s.enabled]
    return hits[index] if hits else None


def osock(node, name):
    hits = [s for s in node.outputs if s.name == name and s.enabled]
    return hits[0] if hits else None


def set_input(node, name, value):
    """Set an input by name, tolerating sockets that fail string-key lookup."""
    for inp in node.inputs:
        if inp.name == name and inp.enabled:
            inp.default_value = value
            return True
    return False


def feed(nt, target, value):
    """Drive `target` from either an upstream socket or a constant.

    Wear and grime stack -- a roughness is a filth mix that is then re-mixed toward the
    polish on a worn edge -- so every mixer input has to accept the previous mixer's
    output as readily as a number."""
    if hasattr(value, "is_output"):
        nt.links.new(value, target)
    else:
        target.default_value = value


def mix_rgb(nt, factor, colour_a, colour_b):
    """A colour mix node wired to `factor`, returning its Result socket."""
    node = nt.nodes.new("ShaderNodeMix")
    node.data_type = "RGBA"
    feed(nt, sock(node, "Factor"), factor)
    feed(nt, sock(node, "A"), colour_a if hasattr(colour_a, "is_output") else (*colour_a, 1.0))
    feed(nt, sock(node, "B"), colour_b if hasattr(colour_b, "is_output") else (*colour_b, 1.0))
    return osock(node, "Result")


def mix_float(nt, factor, value_a, value_b):
    node = nt.nodes.new("ShaderNodeMix")
    node.data_type = "FLOAT"
    feed(nt, sock(node, "Factor"), factor)
    feed(nt, sock(node, "A"), value_a)
    feed(nt, sock(node, "B"), value_b)
    return osock(node, "Result")


# --- Look development --------------------------------------------------------

def edge_wear_mask(nt, radius=0.035):
    """A 0..1 mask that is 1 on convex edges and 0 on flat faces.

    The classic procedural-wear trick, and the only one available here: these parts have
    no UVs, so nothing can be painted on. A Bevel node returns the normal a rounded
    version of the surface would have; where that disagrees with the true normal, the
    surface is an edge. Dot the two and everything below 1 is a corner.

    This is what the whole scrapyard read hangs on -- paint survives on flat plate and
    is knocked off every edge and corner, which is exactly how a real machine wears."""
    bevel = nt.nodes.new("ShaderNodeBevel")
    bevel.samples = 8
    bevel.inputs["Radius"].default_value = radius

    geometry = nt.nodes.new("ShaderNodeNewGeometry")

    dot = nt.nodes.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    nt.links.new(bevel.outputs["Normal"], dot.inputs[0])
    nt.links.new(geometry.outputs["True Normal"], dot.inputs[1])

    # Dot is 1.0 on flat surfaces and falls away at an edge. Inverted, so 1 == edge.
    #
    # The window is WIDE on purpose. The first version paired a 0.006 radius with a
    # 0.55-0.99 window and produced a mathematically perfect one-pixel outline -- visible
    # in a mask render, invisible in the actual shot, so the machines still came back
    # looking freshly moulded. Wear has to be a band with area, not a wireframe.
    ramp = nt.nodes.new("ShaderNodeMapRange")
    ramp.inputs["From Min"].default_value = 0.10
    ramp.inputs["From Max"].default_value = 0.995
    ramp.inputs["To Min"].default_value = 1.0
    ramp.inputs["To Max"].default_value = 0.0
    ramp.clamp = True
    nt.links.new(dot.outputs["Value"], ramp.inputs["Value"])
    return ramp.outputs["Result"]


def grime_mask(nt, scale=5.0, detail=6.0):
    """Large-scale filth. Object coordinates, so it does not swim when a part moves and
    is consistent between the two arms of one construct.

    Contrast is stretched afterwards: raw Noise sits in a narrow band around 0.5, and a
    filth pass that never approaches either end is a uniform grey wash that reads as
    slightly dirty lighting rather than as dirt."""
    coord = nt.nodes.new("ShaderNodeTexCoord")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = detail
    noise.inputs["Roughness"].default_value = 0.62
    nt.links.new(coord.outputs["Object"], noise.inputs["Vector"])

    stretch = nt.nodes.new("ShaderNodeMapRange")
    stretch.inputs["From Min"].default_value = 0.34
    stretch.inputs["From Max"].default_value = 0.72
    stretch.clamp = True
    nt.links.new(noise.outputs["Fac"], stretch.inputs["Value"])
    return stretch.outputs["Result"], coord


def streak_mask(nt, coord):
    """Vertical run-off staining across a panel FACE, not just around its rim.

    Edge wear alone is a rim effect. On a roster built from large flat boxes that means
    every worn pixel sits within a few pixels of a silhouette edge, and the middle of
    every panel stays factory-fresh -- which is why the machines still read as moulded
    after the edge mask was provably working.

    Stretching the noise along Z makes it run downward like water and rust actually do,
    so the stain reads as something that happened to the machine rather than as generic
    marble."""
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (7.0, 7.0, 0.85)
    nt.links.new(coord.outputs["Object"], mapping.inputs["Vector"])

    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 3.2
    noise.inputs["Detail"].default_value = 9.0
    noise.inputs["Roughness"].default_value = 0.72
    nt.links.new(mapping.outputs["Vector"], noise.inputs["Vector"])

    contrast = nt.nodes.new("ShaderNodeMapRange")
    contrast.inputs["From Min"].default_value = 0.42
    contrast.inputs["From Max"].default_value = 0.68
    contrast.clamp = True
    nt.links.new(noise.outputs["Fac"], contrast.inputs["Value"])
    return contrast.outputs["Result"]


def plate_variation(nt, coord, spread=0.30):
    """Patchy panel-to-panel brightness, as if plates came off different machines.

    The parts are joined into one mesh, so there is no per-panel attribute to randomise
    against -- a Voronoi on object coordinates is the closest available thing, and its
    cells land at roughly plate size. Without this every flat surface on a construct is
    the identical value and the whole machine reads as injection-moulded in one go, which
    is the opposite of salvage."""
    voronoi = nt.nodes.new("ShaderNodeTexVoronoi")
    voronoi.feature = "F1"
    voronoi.inputs["Scale"].default_value = 7.0
    nt.links.new(coord.outputs["Object"], voronoi.inputs["Vector"])

    spread_node = nt.nodes.new("ShaderNodeMapRange")
    spread_node.inputs["From Min"].default_value = 0.0
    spread_node.inputs["From Max"].default_value = 1.0
    spread_node.inputs["To Min"].default_value = 1.0 - spread
    spread_node.inputs["To Max"].default_value = 1.0 + spread
    nt.links.new(voronoi.outputs["Distance"], spread_node.inputs["Value"])
    return spread_node.outputs["Result"]


def cavity_mask(nt, distance=0.10):
    """Dirt collects where a surface cannot be reached. The AO node is that, for free."""
    ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
    ao.samples = 8
    ao.inputs["Distance"].default_value = distance
    invert = nt.nodes.new("ShaderNodeMapRange")
    invert.inputs["From Min"].default_value = 0.0
    invert.inputs["From Max"].default_value = 1.0
    invert.inputs["To Min"].default_value = 1.0
    invert.inputs["To Max"].default_value = 0.0
    nt.links.new(ao.outputs["AO"], invert.inputs["Value"])
    return invert.outputs["Result"]


def hero_material(zone, base_hex, team_hex=None):
    """The render-time material for one zone. Never exported -- see the module docstring.

    Built once per zone and cached by name, exactly like `make_parts.zone_material`, so a
    twelve-part construct shares seven materials rather than carrying eighty."""
    name = f"hero_{zone}" + (f"_{team_hex}" if (zone == "paint" and team_hex) else "")
    existing = bpy.data.materials.get(name)
    if existing:
        return existing

    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nt = material.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    surface = ZONE_SURFACE.get(zone, dict(roughness=0.55, metallic=1.0))

    # --- Emissive zones are their own thing: a lens, not a surface. ---
    if zone.startswith("glow"):
        rgb = srgb(base_hex)
        set_input(bsdf, "Base Color", (*rgb, 1.0))
        set_input(bsdf, "Metallic", 0.0)
        set_input(bsdf, "Roughness", 0.18)
        set_input(bsdf, "Emission Color", (*rgb, 1.0))
        # Cycles is linear and unbloomed: the game's 1.8 reads as barely-on here. A core
        # lens is the one thing on the machine that must survive a dark scene.
        set_input(bsdf, "Emission Strength", 14.0 if zone != "glow_visor" else 8.0)
        return material

    base_rgb = srgb(base_hex)
    if zone == "paint" and team_hex:
        # `part_materials.gd` knocks the raw team colour back before use, so the warm key
        # has headroom and the machine does not read as a flat team silhouette. Same move
        # here -- darken, then drag toward the frame's own gunmetal -- but knocked back
        # considerably harder. The game's 0.18 darken is tuned for a bright sodium key at
        # close range; at a hero exposure that value washed to pastel mint and every bit
        # of wear underneath it stopped separating.
        team = srgb(team_hex)
        base_rgb = tuple(t * 0.42 + m * 0.22
                         for t, m in zip(team, srgb("6b6259")))

    steel = srgb(WEAR_STEEL)
    grime_fac, coord = grime_mask(nt)
    cavity = cavity_mask(nt)

    # TWO edge masks at different widths, because wear has two separate signatures and
    # driving both from one mask produced neither.
    #
    # A single mask pushed base colour, metallic AND roughness together, so every edge
    # became a hard white specular pinstripe -- metallic 1.0 at roughness 0.3 facing a
    # sodium key -- and the machine came out looking chrome-lined rather than salvaged.
    # The dirty band has to be WIDE and the polished contact strip NARROW.
    edge = edge_wear_mask(nt, radius=0.055)          # wide: oxide and chipped paint
    edge_tight = edge_wear_mask(nt, radius=0.010)    # narrow: rubbed-back contact shine

    # --- Where the paint has come off -------------------------------------
    # Edge wear, bitten into by the grime noise so the chipping is irregular rather than
    # a uniform pinstripe down every corner in the roster.
    #
    # Grime MODULATES rather than gates. Multiplying the two directly meant a panel with
    # clean noise lost its chipping entirely, and since the noise averages about a half
    # it also quietly halved the wear everywhere else.
    irregular = nt.nodes.new("ShaderNodeMapRange")
    irregular.inputs["From Min"].default_value = 0.0
    irregular.inputs["From Max"].default_value = 1.0
    irregular.inputs["To Min"].default_value = 0.45
    irregular.inputs["To Max"].default_value = 1.0
    nt.links.new(grime_fac, irregular.inputs["Value"])

    wear = nt.nodes.new("ShaderNodeMath")
    wear.operation = "MULTIPLY"
    nt.links.new(edge, wear.inputs[0])
    nt.links.new(irregular.outputs["Result"], wear.inputs[1])
    boost = nt.nodes.new("ShaderNodeMath")
    boost.operation = "MULTIPLY"
    boost.inputs[1].default_value = 3.4 if zone in ("paint", "hazard") else 1.4
    nt.links.new(wear.outputs["Value"], boost.inputs[0])
    clamped = nt.nodes.new("ShaderNodeClamp")
    nt.links.new(boost.outputs["Value"], clamped.inputs["Value"])
    wear_fac = clamped.outputs["Result"]

    # --- Base colour: plate variation, then filth, then bare steel on the edges ---
    plates = plate_variation(nt, coord)
    varied = nt.nodes.new("ShaderNodeMix")
    varied.data_type = "RGBA"
    varied.blend_type = "MULTIPLY"
    set_input(varied, "Factor", 1.0)
    sock(varied, "A").default_value = (*base_rgb, 1.0)
    nt.links.new(plates, sock(varied, "B"))

    dirt_rgb = srgb("3a3128")
    dirtied = mix_rgb(nt, cavity, osock(varied, "Result"), dirt_rgb)

    # Multiply the grime pass over the dirtied base: a light/dark filth wash. A float Fac
    # promotes to greyscale on a colour socket, which is exactly what a filth pass is.
    shade = nt.nodes.new("ShaderNodeMix")
    shade.data_type = "RGBA"
    shade.blend_type = "MULTIPLY"
    set_input(shade, "Factor", 0.55)
    nt.links.new(dirtied, sock(shade, "A"))
    nt.links.new(grime_fac, sock(shade, "B"))

    # Rust run-off over the panel faces. Applied to every zone including bare metal,
    # because the stain comes from what is above a surface, not from what the surface is.
    streaks = streak_mask(nt, coord)
    stain_strength = nt.nodes.new("ShaderNodeMath")
    stain_strength.operation = "MULTIPLY"
    stain_strength.inputs[1].default_value = 0.55 if zone != "rust" else 0.25
    nt.links.new(streaks, stain_strength.inputs[0])
    coloured = mix_rgb(nt, stain_strength.outputs["Value"],
                       osock(shade, "Result"), srgb(WEAR_RUST))

    if zone in ("paint", "hazard"):
        # Paint feeds A; exposed metal shows only where the edge wear has taken it off.
        # The exposed metal is itself two-tone -- oxide where the filth sits, bare steel
        # where it does not -- so a chipped edge is not one flat grey line.
        exposed = mix_rgb(nt, grime_fac, steel, srgb(WEAR_RUST))
        bridge = nt.nodes.new("ShaderNodeMix")
        bridge.data_type = "RGBA"
        nt.links.new(wear_fac, sock(bridge, "Factor"))
        nt.links.new(coloured, sock(bridge, "A"))
        nt.links.new(exposed, sock(bridge, "B"))
        nt.links.new(osock(bridge, "Result"), bsdf.inputs["Base Color"])
        # Metallic follows the NARROW mask only. Bare metal appears where paint has been
        # rubbed through to the substrate, not across the whole dirty band -- and it is
        # capped below 1.0 so an edge reads as scuffed steel rather than as chrome trim.
        polish = nt.nodes.new("ShaderNodeMath")
        polish.operation = "MULTIPLY"
        polish.inputs[1].default_value = 0.75
        nt.links.new(edge_tight, polish.inputs[0])
        metallic = mix_float(nt, polish.outputs["Value"], surface["metallic"], 1.0)
        nt.links.new(metallic, bsdf.inputs["Metallic"])
        # The clear coat is gone wherever the paint is: no lacquer on a chipped panel.
        coat = mix_float(nt, wear_fac, surface.get("coat", 0.0), 0.0)
        nt.links.new(coat, bsdf.inputs["Coat Weight"])
        set_input(bsdf, "Coat Roughness", 0.28)
    else:
        nt.links.new(coloured, bsdf.inputs["Base Color"])
        set_input(bsdf, "Metallic", surface["metallic"])

    # --- Roughness: never one number ---------------------------------------
    # A single roughness value is the other half of why the flat version read as plastic.
    # Filth is rough, worn edges are polished by contact.
    rough_low = max(0.05, surface["roughness"] - 0.18)
    rough_high = min(1.0, surface["roughness"] + 0.16)
    roughness = mix_float(nt, grime_fac, rough_low, rough_high)
    if zone in ("paint", "hazard", "metal", "dark"):
        # Rubbed-back edges catch the key: the highlight that reads as "handled".
        # 0.45, not 0.30 -- worn scrap is scuffed, and a polished value here is what put
        # a mirror line down every corner of the roster.
        roughness = mix_float(nt, edge_tight, roughness, 0.45)
    nt.links.new(roughness, bsdf.inputs["Roughness"])

    # --- Micro surface -----------------------------------------------------
    # Cast and hammered plate is not optically flat. Very fine noise into a Bump keeps
    # the key light from sliding across a panel as one unbroken sheet.
    fine = nt.nodes.new("ShaderNodeTexNoise")
    fine.inputs["Scale"].default_value = 44.0
    fine.inputs["Detail"].default_value = 4.0
    nt.links.new(coord.outputs["Object"], fine.inputs["Vector"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.13 if zone != "rust" else 0.30
    bump.inputs["Distance"].default_value = 0.006
    nt.links.new(fine.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])

    return material


def apply_hero_materials(objects, team_hex, mp):
    """Swap every `mat_<zone>` slot for its hero equivalent.

    Per SLOT, not per object. The generator joins each part into one mesh carrying a
    slot per zone, so an object-level override is the classic `material_override`
    mistake -- it throws away every bevel, rib and vent the generator
    exists to produce and returns a monochrome silhouette."""
    swapped = set()
    for obj in objects:
        if obj.type != "MESH":
            continue
        for index, slot in enumerate(obj.material_slots):
            if slot.material is None:
                continue
            zone = slot.material.name[4:] if slot.material.name.startswith("mat_") else None
            if zone is None:
                continue
            base_hex = HERO_ALBEDO.get(zone, mp.ZONE_COLOURS.get(zone))
            if base_hex is None:
                continue
            obj.material_slots[index].material = hero_material(zone, base_hex, team_hex)
            swapped.add(zone)
    return sorted(swapped)


# --- Scene ------------------------------------------------------------------

def mount(child, pivot):
    """Parent `child` so that it sits AT `pivot`, rather than where it was built.

    NOT `parent_keeping_transform`. That helper exists for the export path, where a
    socket must not move when it gains a parent -- and it is the right tool there. Used
    here it does exactly what it promises and pins each attachment at the origin it was
    built at, so the core and the module rendered lying on the ground under a floating
    torso while their pivots sat correctly at the shoulders.

    Clearing the parent inverse is the whole operation: it makes the child's local
    transform read relative to the pivot, so local (0,0,0) IS the socket. A bare
    `child.parent =` is the usual trap because it leaves that matrix at identity by
    accident -- here identity is the intent, so it is set explicitly."""
    child.parent = pivot
    child.matrix_parent_inverse.identity()
    child.location = (0, 0, 0)


def descendants(roots):
    """Every object in the hierarchy, roots included.

    A chassis is not one mesh: each leg is its own child object so the runtime can rotate
    it at the hip. Anything that walks only the roots therefore misses both legs -- which
    silently gave the framing a torso-height subject to fit, and left the legs on the
    generator's flat placeholder materials while the body got the hero pass."""
    out = []
    stack = list(roots)
    seen = set()
    while stack:
        obj = stack.pop()
        if obj.name in seen:
            continue
        seen.add(obj.name)
        out.append(obj)
        stack.extend(obj.children)
    return out


def aim_at(obj, target):
    target_pos = Vector(target.location) if hasattr(target, "location") else Vector(target)
    direction = (target_pos - obj.location).normalized()
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def rust_and_sodium(centre, extent):
    """The game's light rig, as lights.

    Warm sodium key, cold blue fill, cool neutral surfaces -- warmth comes
    from the LIGHT, never from the pigment. A warm albedo under a warm key puts every
    pixel in one orange band and the palette stops being two colours.

    Ratios matter more than intensities here. At 7:1 the cold fill was too weak to tint
    anything, so blue team paint sat under nothing but an orange key and rendered a
    desaturated mint -- physically right, and the exact opposite of a two-colour palette.
    Around 2.5:1 the shadow side stays blue while the key side goes warm, which is the
    whole Rust & Sodium read. Energy scales with the square of the distance, so a 0.4 m
    module and a 2 m chassis are lit the same way rather than one being blown out."""
    distance = max(extent * 1.6, 1.2)
    # Tuned against the render, not derived. The first pass ran ~4x this and AgX did what
    # AgX does with overexposure: rolled every highlight toward white, so a rust-and-
    # sodium palette came back as mint and salmon pastel. The palette only exists in the
    # exposure band where the key can still be seen to be orange.
    base = 24.0 * (distance / 1.5) ** 2

    # KEY -- sodium vapour, high and to the camera's right. ~2000K is far oranger than a
    # tungsten key; that is the whole identity of the palette.
    key = bpy.data.objects.new("LGT-key", bpy.data.lights.new("LGT-key", type="AREA"))
    key.data.energy = base * 4.0
    key.data.size = distance * 0.55
    key.data.color = (1.0, 0.66, 0.32)
    bpy.context.collection.objects.link(key)
    key.location = (centre.x + distance * 0.85, centre.y - distance * 0.62,
                    centre.z + distance * 0.95)
    aim_at(key, centre)

    # FILL -- cold blue, opposite and much weaker. This is the only thing keeping the
    # shadow side from going to pure black, and it is what makes the metal read as cool
    # neutral rather than as orange plastic.
    fill = bpy.data.objects.new("LGT-fill", bpy.data.lights.new("LGT-fill", type="AREA"))
    fill.data.energy = base * 1.6
    fill.data.size = distance * 1.5
    fill.data.color = (0.42, 0.60, 1.0)
    bpy.context.collection.objects.link(fill)
    fill.location = (centre.x - distance * 0.95, centre.y - distance * 0.45,
                     centre.z + distance * 0.45)
    aim_at(fill, centre)

    # RIM -- cold, behind and high. Separates the silhouette from a dark background, which
    # is the same job the in-engine silhouette rim does and the reason scenery is denied
    # one.
    rim = bpy.data.objects.new("LGT-rim", bpy.data.lights.new("LGT-rim", type="AREA"))
    rim.data.energy = base * 1.8
    rim.data.size = distance * 0.7
    rim.data.color = (0.62, 0.78, 1.0)
    bpy.context.collection.objects.link(rim)
    rim.location = (centre.x - distance * 0.35, centre.y + distance * 1.0,
                    centre.z + distance * 1.05)
    aim_at(rim, centre)

    # A second sodium bounce low and in front, standing in for the floodlit yard floor.
    # Without it the legs and feet -- all rust and tread -- fall out of the picture.
    bounce = bpy.data.objects.new("LGT-bounce", bpy.data.lights.new("LGT-bounce", type="AREA"))
    bounce.data.energy = base * 0.35
    bounce.data.size = distance * 1.2
    bounce.data.color = (1.0, 0.72, 0.42)
    bpy.context.collection.objects.link(bounce)
    bounce.location = (centre.x + distance * 0.25, centre.y - distance * 0.9,
                       centre.z * 0.15)
    aim_at(bounce, centre)

    world = bpy.context.scene.world or bpy.data.worlds.new("World")
    bpy.context.scene.world = world
    world.use_nodes = True
    nodes = world.node_tree.nodes
    for node in list(nodes):
        nodes.remove(node)
    output = nodes.new("ShaderNodeOutputWorld")
    background = nodes.new("ShaderNodeBackground")
    # Not black. A metal with nothing to reflect renders black, and the roster is mostly
    # metal -- this dim cold sky is what puts a gradient on every curved surface.
    background.inputs["Color"].default_value = (0.030, 0.042, 0.070, 1.0)
    background.inputs["Strength"].default_value = 1.0
    world.node_tree.links.new(background.outputs["Background"], output.inputs["Surface"])


def scrapyard_floor(centre, extent):
    """Ground, so the machine has contact shadow and stands on something.

    Deliberately darker than the constructs. Dressing the arena in the constructs' own
    materials once made the walls brighter than the machines in front of them, and the
    eye went to the containers."""
    bpy.ops.mesh.primitive_plane_add(size=max(extent * 14.0, 24.0),
                                     location=(centre.x, centre.y, 0.0))
    floor = bpy.context.active_object
    floor.name = "GEO-floor"

    material = bpy.data.materials.new("hero_floor")
    material.use_nodes = True
    nt = material.node_tree
    bsdf = nt.nodes["Principled BSDF"]

    coord = nt.nodes.new("ShaderNodeTexCoord")
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 2.4
    noise.inputs["Detail"].default_value = 8.0
    nt.links.new(coord.outputs["Object"], noise.inputs["Vector"])

    nt.links.new(mix_rgb(nt, noise.outputs["Fac"], srgb("0d0f12"), srgb("191712")),
                 bsdf.inputs["Base Color"])
    # Damp patches. A uniformly rough floor eats the sodium light; the wet streaks are
    # what throw it back up under the machine and put it in a place rather than on a card.
    nt.links.new(mix_float(nt, noise.outputs["Fac"], 0.28, 0.85), bsdf.inputs["Roughness"])
    set_input(bsdf, "Metallic", 0.0)

    floor.data.materials.append(material)
    return floor


def hero_camera(centre, height, radius, yaw_deg, lens, fstop, focus_target, res,
                points, margin=1.10):
    """Long-ish lens, three-quarter yaw, subject filling the frame.

    85 mm rather than the inspection rig's 55-60: the compression flatters a machine and
    stops the near leg from ballooning. The yaw is not optional -- weapons project
    straight forward, so a dead-on view points every barrel at the camera and the
    silhouette disappears.

    Distance is SOLVED from the field of view, not guessed from the subject's height. The
    first version used `height * 1.55`, which is roughly right for a 50 mm and puts an
    85 mm inside the machine -- the render came back as a close-up of one shoulder. A
    longer lens has to stand further back to see the same subject, so the lens has to be
    in the arithmetic."""
    bpy.ops.object.camera_add()
    camera = bpy.context.active_object
    camera.data.lens = lens
    # Explicit, because AUTO fits the sensor to whichever image dimension is larger and
    # the framing would then change silently between a portrait and a landscape run.
    camera.data.sensor_fit = "VERTICAL"
    camera.data.sensor_height = 24.0
    camera.data.dof.use_dof = True
    camera.data.dof.focus_object = focus_target
    # f/5.6 keeps the whole construct sharp while the yard falls away behind it. Anything
    # faster and the far arm goes soft, which reads as a mistake rather than as a look.
    camera.data.dof.aperture_fstop = fstop

    aspect = res[0] / float(res[1])
    tan_y = camera.data.sensor_height / (2.0 * lens)
    tan_x = tan_y * aspect

    yaw = math.radians(yaw_deg)
    distance = max(height, radius * 2.0) * 2.5
    camera.constraints.new("TRACK_TO").target = focus_target
    bpy.context.scene.camera = camera

    def place(d):
        camera.location = (
            centre.x + math.sin(yaw) * d,
            centre.y - math.cos(yaw) * d,
            centre.z + height * 0.18)
        bpy.context.view_layer.update()

    # Fit by PROJECTING the subject, not from its bounding box.
    #
    # Solving from `max(width, depth)` treats a forward-projecting weapon as if it were
    # screen width. From a three-quarter yaw most of that reach goes INTO the screen, so
    # the solve pulled the camera far back and framed the machine at half the height it
    # should have filled. Projecting asks the only question that matters -- where does
    # this vertex actually land in frame -- and it needs no special case for a lance.
    for _ in range(4):
        place(distance)
        matrix = camera.matrix_world.inverted()
        worst = 0.0
        for point in points:
            local = matrix @ point
            depth = -local.z
            if depth <= 1e-4:
                continue
            worst = max(worst, abs(local.x) / (depth * tan_x),
                        abs(local.y) / (depth * tan_y))
        if worst <= 1e-6:
            break
        distance *= worst * margin
    place(distance)
    return camera


def setup_cycles(samples, res_x, res_y, exposure=0.0):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.render.resolution_x = res_x
    scene.render.resolution_y = res_y
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False

    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        for backend in ("METAL", "OPTIX", "CUDA", "HIP", "ONEAPI"):
            try:
                prefs.compute_device_type = backend
                prefs.get_devices()
                if any(d.type == backend for d in prefs.devices):
                    for device in prefs.devices:
                        device.use = True
                    scene.cycles.device = "GPU"
                    print(f"  cycles device: GPU/{backend}")
                    break
            except (TypeError, AttributeError):
                continue
        else:
            print("  cycles device: CPU")
    except (KeyError, AttributeError):
        print("  cycles device: CPU (no cycles preferences)")

    # 128 is the working default, not a compromise. This content is area lights on
    # opaque hard surfaces -- no glass, no caustics, no SSS -- so adaptive sampling plus
    # OpenImageDenoise converges early; 200 samples cost three times as long for a
    # difference that did not survive being looked at. Raise it for a final press shot.
    scene.cycles.samples = samples
    scene.cycles.use_adaptive_sampling = True
    scene.cycles.adaptive_threshold = 0.015
    scene.cycles.use_denoising = True
    try:
        scene.cycles.denoiser = "OPENIMAGEDENOISE"
    except TypeError:
        pass
    scene.cycles.max_bounces = 12
    scene.cycles.glossy_bounces = 6
    # Emissive core lenses at strength 14 next to dark metal: without a firefly clamp the
    # denoiser smears the speckle into blotches around every glow.
    scene.cycles.sample_clamp_indirect = 8.0

    view = scene.view_settings
    view.view_transform = "AgX"
    # AgX is neutral to a fault. A scrapyard at night wants the contrast put back, or the
    # blacks sit at mid-grey and the whole frame reads as fogged.
    #
    # The look name is version-specific and a wrong one raises rather than warns, so the
    # fallback chain is real. It must not end in a silent `pass`: a render that quietly
    # loses its grade looks like a lighting bug and gets debugged as one.
    for candidate in ("AgX - Medium High Contrast", "AgX - Base Contrast", "None"):
        try:
            view.look = candidate
            break
        except TypeError:
            continue
    else:
        print("  WARNING: no AgX look applied -- grade will be flat")
    view.exposure = exposure


# --- Assembly and posing -----------------------------------------------------

# The signature moment of each strike in `construct_rig.gd`. A render is one frame, so
# the frame has to be the readable one: for a hammer that is the TOP of the wind-up, not
# the impact -- the wind-up is the tell, and it is the pose that says "heavy".
#
# Rotation is about the shoulder, in Blender's frame: negative X raises the weapon,
# positive X drops it. Forward is -Y.
POSES = {
    "hammer":     dict(rot=(-0.95, 0.0, 0.0)),
    "maul":       dict(rot=(-0.85, 0.0, 0.0)),
    "ripper":     dict(rot=(-0.42, 0.0, 0.10)),
    "saw":        dict(rot=(-0.38, 0.0, -0.10)),
    "lance":      dict(rot=(0.06, 0.0, 0.0), loc=(0.0, -0.22, 0.0)),
    "mortar":     dict(rot=(-0.50, 0.0, 0.0)),
    "railgun":    dict(rot=(-0.05, 0.0, 0.0), loc=(0.0, 0.14, 0.0)),
    "coil":       dict(rot=(-0.12, 0.0, 0.0), scale=1.14),
    "scanner":    dict(rot=(-0.10, 0.55, 0.0)),
    "scattergun": dict(rot=(-0.16, 0.0, 0.0), loc=(0.0, 0.08, 0.0)),
}


def swing_limb(limb, angle):
    """Rotate a leg about its hip, PRESERVING the rest orientation the builder authored.

    `limb.rotation_euler = (angle, 0, 0)` is the obvious spelling and it is wrong. The
    generator splays and flips each leg into place -- `ch_brute`'s left leg rests at
    (-0.32, 3.14, 0.30), a third of a turn plus a half turn -- and assigning a fresh
    euler discards all of it. The legs came out inverted and folded up inside the torso,
    which rendered as a machine with no legs at all hovering above the floor.

    Composing about the world X axis through the origin keeps the rest and adds a stride.
    The origin is already the hip, which is what `set_origin` in the generator is for."""
    if limb is None:
        return
    hip = limb.matrix_world.translation.copy()
    rotation = Matrix.Rotation(angle, 4, "X")
    limb.matrix_world = (Matrix.Translation(hip) @ rotation
                         @ Matrix.Translation(-hip) @ limb.matrix_world)


def build_construct(mp, parts, loadout, pose=True):
    """Chassis plus attachments, mounted through the same socket contract the game reads.

    Each attachment is parented to an empty AT the socket rather than moved to it. That
    is how the runtime does it -- `construct_rig.gd` rotates a Node3D sitting at the
    socket, not the mesh -- and it is the only way a pose pivots at the shoulder. The
    arm mesh's own origin was recentred to its bounding box by `join`, so rotating the
    mesh directly swings the weapon around its middle and pulls it out of the shoulder."""
    chassis_id = loadout["chassis"]
    root = mp.BUILDERS["chassis"](chassis_id, parts[chassis_id])

    sockets = {child.name: child.location.copy()
               for child in root.children if child.name.startswith("socket_")}
    limbs = {child.name: child for child in root.children
             if child.name.startswith("limb_")}

    objects = [root]
    pivots = []
    for socket_name, key in (("socket_core", "core"), ("socket_arm_l", "arm_l"),
                             ("socket_arm_r", "arm_r"), ("socket_module", "module")):
        attach_id = loadout.get(key)
        if attach_id is None or socket_name not in sockets:
            continue
        definition = parts[attach_id]
        piece = mp.BUILDERS[definition["slot"]](attach_id, definition)

        bpy.ops.object.empty_add(type="PLAIN_AXES", radius=0.05,
                                 location=sockets[socket_name])
        pivot = bpy.context.active_object
        pivot.name = f"pivot_{key}"
        mount(piece, pivot)
        mp.parent_keeping_transform(pivot, root)

        if key == "arm_l":
            # Mirrored, exactly as the game mirrors the left arm.
            pivot.scale = (-1, 1, 1)

        if pose and key in ("arm_l", "arm_r"):
            weapon = definition.get("weapon_class", "rifle")
            shape = POSES.get(weapon, dict(rot=(-0.10, 0.0, 0.0)))
            # Only ONE arm plays its strike. Both arms mid-swing reads as a stumble, and
            # it hides whichever weapon is behind the other.
            if key == "arm_r":
                pivot.rotation_euler = shape["rot"]
                if "loc" in shape:
                    pivot.location = pivot.location + Vector(shape["loc"])
                if "scale" in shape:
                    factor = shape["scale"]
                    pivot.scale = (factor, factor, factor)
            else:
                # The off arm is braced: dropped and turned slightly in, which is what
                # makes the striking arm read as the one doing something.
                pivot.rotation_euler = (0.18, 0.0, 0.0)

        objects.append(piece)
        pivots.append(pivot)

    if pose:
        # A stride. In a still, a construct standing square on both feet reads as a
        # display model -- the offset legs are most of what says "walking machine".
        swing_limb(limbs.get("limb_leg_l"), -0.22)
        swing_limb(limbs.get("limb_leg_r"), 0.20)

    return objects, root


def world_points(objects):
    """Every evaluated vertex, in world space. The input to both framing and bounds."""
    deps = bpy.context.evaluated_depsgraph_get()
    points = []
    for obj in objects:
        if obj.type != "MESH":
            continue
        evaluated = obj.evaluated_get(deps)
        mesh = evaluated.to_mesh()
        matrix = obj.matrix_world
        for vertex in mesh.vertices:
            points.append(matrix @ vertex.co)
        evaluated.to_mesh_clear()
    return points


def real_bounds(objects):
    """Bounds from evaluated vertices, in world space.

    NOT `matrix_world @ bound_box` -- the trap `verify_assembly` already caught:
    the axis-aligned bound of a tilted box overstated one chassis by 23 cm and reported a
    correctly standing frame as sunk into the ground. Here it would simply mis-frame the
    shot, but it is the same wrong measurement."""
    points = world_points(objects)
    if not points:
        return Vector((0, 0, 0)), 1.0, 1.0
    xs = [p.x for p in points]
    ys = [p.y for p in points]
    zs = [p.z for p in points]
    centre = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2,
                     (min(zs) + max(zs)) / 2))
    height = max(zs) - min(zs)
    radius = max(max(xs) - min(xs), max(ys) - min(ys)) * 0.5
    return centre, max(height, 0.3), max(radius, 0.2)


def pick_loadout(parts, chassis_id, index):
    """A different core, module and weapon pair per construct.

    Ten renders that vary only the frame do not show a modular roster -- they show one
    machine ten times. Stepping each slot by a different stride walks the whole 40-part
    roster across ten shots, and the two arms are deliberately never the same weapon."""
    def ids(slot):
        return sorted(p for p, d in parts.items() if d.get("slot") == slot)

    arms, cores, modules = ids("arm"), ids("core"), ids("module")
    return {
        "chassis": chassis_id,
        "arm_r": arms[index % len(arms)],
        "arm_l": arms[(index * 3 + 4) % len(arms)],
        "core": cores[(index * 7 + 2) % len(cores)],
        "module": modules[(index * 9 + 5) % len(modules)],
    }


def render_one(mp, parts, loadout, team, out_path, samples, res, yaw, lens, fstop,
               pose=True, exposure=0.0):
    mp.clear_scene()
    objects, root = build_construct(mp, parts, loadout, pose=pose)
    # The whole hierarchy, not the roots: the legs are separate child objects.
    every = descendants(objects)
    zones = apply_hero_materials(every, TEAM_COLOURS.get(team, TEAM_COLOURS["a"]), mp)

    points = world_points(every)
    centre, height, radius = real_bounds(every)
    rust_and_sodium(centre, max(height, radius * 2))
    scrapyard_floor(centre, max(height, radius * 2))

    bpy.ops.object.empty_add(location=(centre.x, centre.y, centre.z + height * 0.08))
    focus = bpy.context.active_object
    focus.name = "focus"
    hero_camera(centre, height, radius, yaw, lens, fstop, focus, res, points)

    setup_cycles(samples, res[0], res[1], exposure)
    bpy.context.scene.render.filepath = out_path
    bpy.ops.render.render(write_still=True)

    weapon = parts[loadout["arm_r"]].get("weapon_class", "?")
    print(f"  {loadout['chassis']:14s} {weapon:11s} zones={','.join(zones)}"
          f"  -> {os.path.basename(out_path)}")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []

    def flag(name, default=None, cast=str):
        if name in argv:
            index = argv.index(name)
            if index + 1 < len(argv):
                return cast(argv[index + 1])
        return default

    chassis_id = flag("--chassis")
    do_roster = "--roster" in argv
    team = flag("--team", "a")
    samples = flag("--samples", 128, int)
    yaw = flag("--yaw", 38.0, float)
    lens = flag("--lens", 85.0, float)
    fstop = flag("--fstop", 9.0, float)
    exposure = flag("--exposure", 0.0, float)
    out_dir = flag("--out", "art/hero")
    no_pose = "--no-pose" in argv
    resolution = flag("--res", "1400x1750")
    res = tuple(int(v) for v in resolution.lower().split("x"))

    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    parts = load_parts(root_dir)
    mp = load_make_parts()

    target_dir = os.path.join(root_dir, out_dir)
    os.makedirs(target_dir, exist_ok=True)

    chassis_ids = sorted(p for p, d in parts.items() if d.get("slot") == "chassis")

    if "--poses" in argv:
        # One frame per WEAPON CLASS on a single chassis, each at its signature moment.
        #
        # Catching a strike in a live battle screenshot does not work -- every attempt
        # photographs a machine standing still -- and the roster sheet varies the frame
        # as well as the weapon, so it cannot show that the ten attacks differ. Holding
        # the chassis fixed and stepping the arm is the only view that isolates the
        # motion, which is the same reason `gait_preview.tscn` exists for the walk.
        base_chassis = chassis_id or "ch_brute"
        arm_ids = sorted(p for p, d in parts.items() if d.get("slot") == "arm")
        print(f"pose sheet: {len(arm_ids)} weapon classes on {base_chassis}")
        for index, arm_id in enumerate(arm_ids):
            weapon = parts[arm_id].get("weapon_class", "?")
            loadout = {"chassis": base_chassis, "arm_r": arm_id, "arm_l": arm_id,
                       "core": sorted(p for p, d in parts.items()
                                      if d.get("slot") == "core")[0],
                       "module": sorted(p for p, d in parts.items()
                                        if d.get("slot") == "module")[0]}
            render_one(mp, parts, loadout, team,
                       os.path.join(target_dir, f"pose_{index:02d}_{weapon}.png"),
                       samples, res, yaw, lens, fstop, pose=True, exposure=exposure)
        print(f"\n{len(arm_ids)} pose(s) -> {out_dir}")
        return

    if do_roster:
        jobs = list(enumerate(chassis_ids))
    elif chassis_id:
        if chassis_id not in parts:
            print(f"unknown chassis: {chassis_id}")
            return
        jobs = [(chassis_ids.index(chassis_id), chassis_id)]
    else:
        jobs = [(0, chassis_ids[0])]

    print(f"hero render: {len(jobs)} construct(s), {samples} samples, {res[0]}x{res[1]}, "
          f"team {team}")
    for index, cid in jobs:
        loadout = pick_loadout(parts, cid, index)
        render_one(mp, parts, loadout, team,
                   os.path.join(target_dir, f"{cid}.png"),
                   samples, res, yaw, lens, fstop, pose=not no_pose,
                   exposure=exposure)

    print(f"\n{len(jobs)} hero render(s) -> {out_dir}")


if __name__ == "__main__":
    main()
