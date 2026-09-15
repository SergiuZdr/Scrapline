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


def repair_history(component, rng, near_points, strength=1.0):
    """Evidence the machine has been fixed, many times, by somebody in a hurry.

    Called by every category after its archetype has run, so the repairs land on real
    geometry rather than at computed coordinates that are only correct for the shape
    they were tuned against -- the same reason `snapped_patch` exists.

    Three rules keep this from becoming noise:

    * **Every repair does a job.** A patch is bolted AND welded. A brace spans two
      points that would need bracing. Nothing is placed because a surface looked empty.
    * **Repairs are in the WRONG metal.** A plate in the same paint as the panel under
      it is a feature; the mismatch is the entire read.
    * **Few and large.** Two or three repairs per component, at a size that survives
      being forty pixels tall. A hundred small ones is a texture, and a bad one.
    """
    from .. import greeble as gr

    pieces = list(component.pieces)
    if not pieces or not near_points:
        return

    count = max(1, min(len(near_points), int(round(rng.span(1.6, 2.6) * strength))))
    for index in range(count):
        near = near_points[index % len(near_points)]
        size = (rng.span(0.075, 0.135), rng.span(0.065, 0.115))
        component.add(gr.repair_patch("%s_repair_%d" % (component.name, index), size,
                                      near, rng, pieces=pieces))

    # One improvised brace, on the side the asymmetry roll already favoured, spanning
    # between two of the points the caller nominated as real structure.
    if len(near_points) >= 2 and rng.maybe(0.55 * strength):
        a = prim_nearest(pieces, near_points[0])
        b = prim_nearest(pieces, near_points[-1])
        component.add(gr.improvised_brace(component.name + "_brace", a, b, rng))


def prim_nearest(pieces, point):
    from .. import primitives as prim
    return prim.nearest_surface_point(pieces, point)
