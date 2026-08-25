"""THE SOCKET CONTRACT. The one file that makes the kit modular.

A modular art set is not modular because the pieces are separate files. It is modular
because `Torso_004` and `Torso_001` present their shoulder mount at the SAME PLACE, so
any arm bolts onto any torso with an identity transform and no per-combination fixup.
The moment one variant moves a socket to suit its own silhouette, every combination
involving it needs a hand-authored offset, and a kit that needs 4x4x8 hand-authored
offsets is not a kit.

So socket positions are a TABLE here, not a decision inside a builder. `place_sockets`
is the only way a component gets its mounts, and a builder cannot override it.

## What varies, then?

Everything except the mount planes. A torso may be a boiler barrel or a slab-sided
box; it may be 0.30 m wide or 0.46 m wide; it may be plated, caged or bare. What it
may NOT do is decide where its shoulders are. The builder's job is to reach the mount:
whatever shape the body takes, it must put a shoulder boss out at `TORSO_SHOULDER_X`
so an arm has something to sit against. `validate_components` checks exactly that --
a socket with no geometry within `MOUNT_CLEARANCE` of it is a mount hanging in the air,
and an arm attached to it will float.

## Fixed versus free

Most sockets are `fixed=True`: their position is part of the contract and validation
compares it exactly. `MuzzleSocket` is `fixed=False` -- it marks the end of the barrel
so the game can spawn a muzzle flash there, and a sawblade and a rail lance genuinely
do not have that point in the same place. Free sockets must exist; where they sit is
the variant's business.

## Naming

The design brief lists `ShoulderSocket` and `HipSocket` in the singular. A robot has
two of each, so they are suffixed `_L` / `_R`. Underscores rather than Blender's `.L`
/ `.R` convention on purpose: the dot suffix carries mirror semantics in Blender and
gets mangled by some glTF pipelines, and these names have to survive into the engine
intact.
"""

from . import config


class SocketSpec:
    """One mount point. `fixed` means the position is contractual."""

    __slots__ = ("name", "location", "rotation", "fixed", "note")

    def __init__(self, name, location, rotation=(0.0, 0.0, 0.0), fixed=True, note=""):
        self.name = name
        self.location = tuple(location)
        self.rotation = tuple(rotation)
        self.fixed = fixed
        self.note = note


## Position tolerance, in metres. A tenth of a millimetre -- tight enough that a
## builder cannot quietly drift a mount, loose enough to absorb float round-trips
## through Blender's matrix maths.
TOLERANCE = 1e-4

## How close real geometry must come to a fixed socket for the mount to count as
## backed. 6 cm: generous enough that a recessed socket inside a hip cavity passes,
## tight enough that a shoulder mount floating clear of a narrow torso fails.
MOUNT_CLEARANCE = 0.06


CONTRACT = {
    # The torso is the hub: it publishes every mount, and the other four categories
    # consume them. Its own origin is the pelvis centre at z=0, which is also the
    # plane the legs hang from.
    "torso": [
        SocketSpec("HeadSocket", (0.0, 0.0, config.TORSO_HEIGHT - 0.02),
                   note="crown of the chest; the head's NeckSocket lands here"),
        SocketSpec("ShoulderSocket_L", (config.TORSO_SHOULDER_X, 0.0,
                                        config.TORSO_SHOULDER_Z),
                   note="the body may be any width, but a boss must reach this point"),
        SocketSpec("ShoulderSocket_R", (-config.TORSO_SHOULDER_X, 0.0,
                                        config.TORSO_SHOULDER_Z)),
        SocketSpec("HipSocket_L", (config.TORSO_HIP_X, 0.0, 0.0)),
        SocketSpec("HipSocket_R", (-config.TORSO_HIP_X, 0.0, 0.0)),
    ],

    # Attachments mount AT THEIR OWN ORIGIN, facing the frame they were built in. That
    # is what makes assembly a position assignment rather than a transform puzzle, and
    # it is the same rule `make_parts.py` uses for cores, arms and modules.
    "head": [
        SocketSpec("NeckSocket", (0.0, 0.0, 0.0),
                   note="origin; head geometry occupies z > 0"),
    ],

    "arm": [
        SocketSpec("ShoulderSocket", (0.0, 0.0, 0.0),
                   note="origin; the arm hangs into z < 0"),
        SocketSpec("WeaponSocket", (0.0, config.ARM_FORWARD_CANT, -config.ARM_LENGTH),
                   note="the wrist. Every arm ends here regardless of its shape, so "
                        "any weapon fits any arm"),
    ],

    "leg": [
        SocketSpec("HipSocket", (0.0, 0.0, 0.0),
                   note="origin; the sole sits at z = -LEG_LENGTH"),
    ],

    "weapon": [
        SocketSpec("MountSocket", (0.0, 0.0, 0.0),
                   note="origin; the weapon projects along +Y, which is forward"),
        SocketSpec("MuzzleSocket", (0.0, 0.0, 0.0), fixed=False,
                   note="barrel tip, for muzzle flash. Genuinely varies by weapon, so "
                        "it is checked for existence only"),
    ],
}


def specs_for(category):
    if category not in CONTRACT:
        raise KeyError("no socket contract for category %r" % category)
    return CONTRACT[category]


def names_for(category):
    return [spec.name for spec in specs_for(category)]


def fixed_specs(category):
    return [spec for spec in specs_for(category) if spec.fixed]


def place_sockets(component):
    """Declares every FIXED socket for the component's category.

    Called by the finalize pipeline, not by builders. A builder that wants to move a
    mount has to change this table, which means changing it for every variant at once
    -- which is the entire safety property.

    Free sockets (`MuzzleSocket`) are the builder's responsibility and are declared
    with `component.socket(...)` at the point the builder knows where the barrel ends."""
    for spec in specs_for(component.category):
        if spec.fixed:
            component.socket(spec.name, spec.location, spec.rotation)
    return component


def ground_plane(category):
    """Where this category's geometry is expected to bottom out, or None if it has no
    such expectation. Used by validation to catch a leg built upside down -- which
    looks entirely reasonable in isolation and is obvious only on an assembled robot."""
    return {
        "torso": 0.0,
        "head": 0.0,
        "leg": -config.LEG_LENGTH,
    }.get(category)
