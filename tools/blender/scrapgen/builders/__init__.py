"""Per-category shape builders.

Every builder is one function, `build(component)`, that adds pieces to the component
and sets `component.archetype`. It never joins, never sets an origin, never places a
fixed socket and never touches a collection -- `component.finalize` does all of that
for all five categories at once.

## The archetype rule

Variation that only scales a shape produces a roster of the same machine at different
sizes. So each builder starts from an ARCHETYPE: a structurally different way of being
a head, and the first thing the seed chooses. Plate counts, pipe routes, bolt patterns
and asymmetry are layered on afterwards, and they vary a lot -- but they vary WITHIN a
silhouette that was already distinct.

`pick_archetype` makes the first N seeds deterministically cover the N archetypes.
That matters for the first generation pass specifically: asking for four heads and
getting three boiler shells and a wedge by chance is a poor first look at a kit that
can in fact do four different things.
"""


def pick_archetype(seed, archetypes, rng):
    """Archetype for a seed, spreading the low seeds across all of them."""
    if 1 <= seed <= len(archetypes):
        return archetypes[seed - 1]
    return rng.pick(archetypes)


def asymmetry(rng, magnitude=1.0):
    """The shared asymmetry roll: which side gets the extra junk, and how much.

    Asymmetry is the single strongest "hand-built" cue available, and it has to be
    decided once per component rather than per detail. Rolling it per piece averages
    out to symmetry with noise, which reads as a machined part with a bad texture."""
    return {
        "side": rng.sign(),
        "strength": rng.span(0.4, 1.0) * magnitude,
        "swap_plates": rng.maybe(0.55),
    }
