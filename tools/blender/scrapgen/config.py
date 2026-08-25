"""Scale, naming and budget constants for the scrap robot generator.

Everything here is a NUMBER A DESIGNER WOULD WANT TO TUNE. No geometry decisions,
no Blender imports -- this module is importable outside Blender, which is what lets
`validate.py` be reasoned about without launching the renderer.

One Blender unit is one game metre, the same as `make_parts.py`. A finished demo
robot stands about 1.95 m: legs 0.86, torso 0.80, head 0.30.
"""

UNIT = 1.0

# --- Collections -------------------------------------------------------------

ROOT_COLLECTION = "SCRAP_ROBOTS"

## Category -> the collection its variants live in. Adding a category means adding a
## line here and a line in `registry.py`; nothing else in the system needs to know.
COLLECTIONS = {
    "head":   "HEADS",
    "torso":  "TORSOS",
    "arm":    "ARMS",
    "weapon": "WEAPONS",
    "leg":    "LEGS",
}

## Assembled demo robots. Kept OUT of the component collections on purpose: the
## exporter walks the component collections, and a demo robot in one of them would
## ship as if it were a part.
DEMO_COLLECTION = "DEMO_ROBOTS"

## Where pieces live while a component is being built. Emptied at the end of every
## build; anything left in it is a leak and `validate_components` says so.
SCRATCH_COLLECTION = "_SCRAPGEN_SCRATCH"


# --- Naming ------------------------------------------------------------------

## Category -> the prefix its objects carry. `Head_001`, `Torso_002`, ...
PREFIXES = {
    "head":   "Head",
    "torso":  "Torso",
    "arm":    "Arm",
    "weapon": "Weapon",
    "leg":    "Leg",
}

## Objects are `<Prefix>_<index:03d>`. Validation enforces this exactly, because
## a stray `Cube.001` in an export is a part the game silently cannot find.
NAME_PATTERN = r"^(Head|Torso|Arm|Weapon|Leg)_\d{3}$"


# --- Budget ------------------------------------------------------------------

## Triangles per component. A robot is head + torso + 2 arms + 2 legs + 1 weapon,
## so the ceiling for one machine is ~14k and twelve of them is ~170k. That is more
## than `make_parts.py` allows itself, and deliberately so: these are scrap machines
## whose whole read is accumulated junk, and the greeble IS the art direction.
## Anything past the budget still builds -- the number is a tripwire, not a gate.
TRI_BUDGET = {
    "head":   1800,
    "torso":  4200,
    "arm":    2200,
    "weapon": 2200,
    "leg":    2400,
}


# --- Proportions -------------------------------------------------------------
#
# These are the only numbers that both a builder and the socket table are allowed to
# read. A builder that wants a wider torso varies WIDTH; it never varies the shoulder
# mount, because the mount is what another category is bolting onto.

TORSO_HEIGHT = 0.80      # pelvis plane (z=0) to the crown of the chest
TORSO_SHOULDER_Z = 0.60  # height of the shoulder mount plane
TORSO_SHOULDER_X = 0.34  # how far out the shoulder boss must reach
TORSO_HIP_X = 0.17       # hip spacing, half-width

HEAD_HEIGHT = 0.30

ARM_LENGTH = 0.62        # shoulder to wrist
ARM_ELBOW_Z = -0.30      # elbow along that run
ARM_FORWARD_CANT = 0.10  # how far the wrist sits ahead of the shoulder

LEG_LENGTH = 0.86        # hip to sole
LEG_KNEE_Z = -0.44

## Blender +Y is the direction a construct faces. `export_yup=True` maps Blender +Y
## onto glTF -Z, which is Godot's forward -- so a barrel modelled along +Y points
## where the unit is aiming, with no per-part rotation fixup at runtime.
FORWARD = (0.0, 1.0, 0.0)


# --- Export ------------------------------------------------------------------

## Category -> export subfolder, under `exports/`.
EXPORT_DIRS = {
    "head":   "heads",
    "torso":  "torsos",
    "arm":    "arms",
    "weapon": "weapons",
    "leg":    "legs",
}

DEFAULT_EXPORT_ROOT = "exports"

## How many variants the first pass generates. 24 components total.
DEFAULT_COUNTS = {
    "head":   4,
    "torso":  4,
    "arm":    4,
    "weapon": 8,
    "leg":    4,
}
