"""The seven scrapyard materials, and the one thing that keeps them useful in Godot.

Every material is a plain Principled BSDF driven by base colour, metallic and
roughness only. That is the subset glTF actually transports: procedural node trees,
Musgrave noise and geometry inputs all evaluate to nothing after export, so a
generator that leans on them produces beautiful Blender viewport shots and flat grey
meshes in the engine.

## Metallic is a switch

0.0 or ~0.9, never the middle. A value like 0.5 is neither dielectric nor conductor
and renders as plastic under any lighting -- it is the single most common reason
hard-surface work looks like a toy. `Rubber` and `Glass` sit at 0; the real metals
sit at 0.75-1.0; painted plate is a dielectric coat over metal and belongs at ~0.05.

## Why each material also carries a ZONE

`scripts/presentation/part_materials.gd` recolours a construct at runtime by reading
material names of the form `mat_<zone>` out of the `.glb`, and it is the only place
the game decides what a machine looks like. Only `paint` takes the team colour.

Exporting these components under their scrapyard names means the game cannot tint
them, so two teams of six render identically and nobody can tell friend from enemy.
`ZONE_OF` is the bridge: `export_all_components(zone_names=True)` renames on the way
out, and the same mesh serves both the standalone kit and the live game.
"""

import bpy


## name -> (sRGB hex, roughness, metallic, emission strength)
##
## Authored in sRGB because that is how the rest of the project writes colour, and
## converted to linear on the way into Blender.
PALETTE = {
    # Oxidised iron. Ground contact, heat stain, anything that has sat in the rain.
    "RustyMetal": ("8c4a26", 0.92, 0.10, 0.0),
    # Recesses and exposed mechanism: pistons, bolts, vents, rails.
    "DarkMetal":  ("2b2b30", 0.50, 0.75, 0.0),
    # Worn structural gunmetal. The honest, clean-ish metal of a frame member.
    "OldSteel":   ("6b6259", 0.40, 0.90, 0.0),
    # Bare copper: cable ends, coils, bus bars. The only warm accent that is a PIGMENT
    # rather than a light, which is why it is used sparingly.
    "Copper":     ("b87333", 0.35, 1.00, 0.0),
    # Hoses, tracks, grommets, bushings. Near-black and never shiny.
    "Rubber":     ("1b1a19", 0.95, 0.00, 0.0),
    # Lenses and eyes. Emissive rather than transmissive: real glass needs refraction
    # that glTF drops, and a dark unlit lens on a dark machine disappears entirely.
    "Glass":      ("ffb24a", 0.12, 0.00, 2.4),
    # Large painted armour surfaces, filthy. THE ONLY TEAM-TINTED ZONE downstream, so
    # a component with no DirtyMetal on it will read as neutral on both teams.
    #
    # Darker and greener than a neutral grey on purpose. At `8a8f96` this zone covers
    # most of every machine and, being the palest thing in the palette, rendered the
    # whole roster as clean white plastic -- the exact opposite of the brief. Paint is
    # also the one zone a viewer reads as "the machine's own colour", so it is where a
    # scrapyard look is won or lost; the rust patches cannot carry it alone.
    "DirtyMetal": ("6d7169", 0.74, 0.05, 0.0),
}


## Scrapyard material -> the game's material zone.
##
## `Copper` has no zone of its own and maps to `metal`; giving it `hazard` would put
## warning ochre on cable ends, and hazard means "this construct explodes" and nothing
## else.
ZONE_OF = {
    "RustyMetal": "rust",
    "DarkMetal":  "dark",
    "OldSteel":   "metal",
    "Copper":     "metal",
    "Rubber":     "tread",
    "Glass":      "glow_visor",
    "DirtyMetal": "paint",
}


def srgb(hex_string):
    """sRGB hex to linear RGB.

    Blender's Base Color input is linear. Feeding it sRGB values directly makes every
    surface come out noticeably lighter and washed out, which is then "fixed" by
    darkening the palette -- and the palette stops matching the one the game and the
    UI read."""
    value = hex_string.lstrip("#")
    out = []
    for index in (0, 2, 4):
        channel = int(value[index:index + 2], 16) / 255.0
        out.append(channel / 12.92 if channel <= 0.04045
                   else ((channel + 0.055) / 1.055) ** 2.4)
    return (out[0], out[1], out[2], 1.0)


def build_materials():
    """Creates every material in `PALETTE`, reusing any that already exist.

    Reuse matters: a fresh material per component gives a 24-part export 168
    materials, every draw call unbatchable, and a `.blend` nobody can retune."""
    made = {}
    for name, (hex_colour, roughness, metallic, emission) in PALETTE.items():
        material = bpy.data.materials.get(name)
        if material is None:
            material = bpy.data.materials.new(name)
        material.use_nodes = True
        bsdf = material.node_tree.nodes.get("Principled BSDF")
        if bsdf is None:
            bsdf = material.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
        colour = srgb(hex_colour)
        bsdf.inputs["Base Color"].default_value = colour
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
        if "Emission Color" in bsdf.inputs:
            bsdf.inputs["Emission Color"].default_value = colour
            bsdf.inputs["Emission Strength"].default_value = emission
        made[name] = material
    return made


def get(name):
    """The material by name, building the set on first use.

    Raises on an unknown name rather than falling back to a default. A typo that
    silently resolves to grey steel is a component that is wrong in a way no
    validation can see -- it has a material, it is just the wrong one."""
    if name not in PALETTE:
        raise KeyError("unknown material %r; expected one of %s"
                       % (name, ", ".join(sorted(PALETTE))))
    material = bpy.data.materials.get(name)
    if material is None:
        build_materials()
        material = bpy.data.materials[name]
    return material


def apply(obj, name):
    obj.data.materials.clear()
    obj.data.materials.append(get(name))
    return obj


def zone_rename(prefix="mat_"):
    """Renames every scrapyard material to the game's `mat_<zone>` contract.

    Called immediately before an export and undone immediately after, so the working
    `.blend` keeps the readable names. Several materials share a zone (`Copper` and
    `OldSteel` both become `mat_metal`), which is intended -- the game palette has
    fewer zones than the kit has materials, and merging them is the point of having
    zones at all."""
    renames = []
    for name in PALETTE:
        material = bpy.data.materials.get(name)
        if material is None:
            continue
        renames.append((material, name))
        material.name = prefix + ZONE_OF[name]
    return renames


def zone_restore(renames):
    for material, name in renames:
        material.name = name
