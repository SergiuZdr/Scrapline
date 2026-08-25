"""The category registry: the one place that knows the five component types exist.

Adding a sixth -- a shoulder pod, a backpack, a tail -- is three edits and no rewrite:
a builder module with a `build(component)` function, a line in `config.COLLECTIONS` /
`PREFIXES` / `EXPORT_DIRS`, and a socket entry in `sockets.CONTRACT`. Everything else
(the seeded RNG, the connectivity check, the join, the origin, the socket placement,
the collection filing, the triangle budget, the exporter and the validator) is generic
over this table and picks the new category up for free.

That is the actual test of whether a generator is modular: not whether the meshes are
separate files, but whether adding a category touches one place or nine.
"""

from . import config
from . import primitives as prim
from .component import Component, finalize
from .rng import ScrapRNG
from .builders import head, torso, arm, weapon, leg


class CategorySpec:
    __slots__ = ("name", "build", "archetypes", "collection", "prefix", "export_dir",
                 "budget")

    def __init__(self, name, module):
        self.name = name
        self.build = module.build
        self.archetypes = module.ARCHETYPES
        self.collection = config.COLLECTIONS[name]
        self.prefix = config.PREFIXES[name]
        self.export_dir = config.EXPORT_DIRS[name]
        self.budget = config.TRI_BUDGET[name]


CATEGORIES = {
    "head":   CategorySpec("head", head),
    "torso":  CategorySpec("torso", torso),
    "arm":    CategorySpec("arm", arm),
    "weapon": CategorySpec("weapon", weapon),
    "leg":    CategorySpec("leg", leg),
}

## Fixed order, everywhere. Dictionaries preserve insertion order in modern Python,
## but relying on that for output ordering is the kind of thing that silently changes
## the report a human is diffing between two runs.
ORDER = ["head", "torso", "arm", "weapon", "leg"]


def generate(category, index, seed=None, archetype=""):
    """Builds one variant and returns its finished Component.

    `seed` defaults to `index`, so `Head_003` is seed 3 unless a caller says otherwise
    -- which makes the name of a component enough to reproduce it.

    `archetype` pins the silhouette while leaving every other roll to the seed. The
    Scrapline bridge needs that: a chassis' role decides whether it is a boiler or a
    cage, and a weapon's class decides whether it is a hammer or a rail lance, but two
    hammers should still not be the same hammer."""
    spec = CATEGORIES[category]
    if seed is None:
        seed = index

    scratch = prim.ensure_collection(config.SCRATCH_COLLECTION)
    prim.set_active_collection(scratch)

    component = Component(category, index, seed, ScrapRNG(category, seed))
    component.forced_archetype = archetype
    spec.build(component)

    root = prim.ensure_collection(config.ROOT_COLLECTION)
    target = prim.ensure_collection(spec.collection, root)
    finalize(component, target)
    return component


def generate_category(category, count, first_index=1):
    return [generate(category, first_index + offset) for offset in range(count)]


def generate_all(counts=None):
    """Builds the whole kit. Returns {category: [Component, ...]} in `ORDER`."""
    counts = counts or config.DEFAULT_COUNTS
    made = {}
    for category in ORDER:
        made[category] = generate_category(category, counts.get(category, 0))
    return made
