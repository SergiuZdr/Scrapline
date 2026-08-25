"""Deterministic randomness for the generator.

`Head_003` must be the same mesh on every machine, in every Blender session, forever.
The moment it is not, a component the artist approved yesterday is a different object
today and the whole "generate, review, keep the good ones" loop stops working.

Two things make that true here:

* **`hash()` is never used.** Python salts the hash of a string differently in every
  process, so `random.Random(hash("head"))` is a different sequence at every launch.
  `fnv1a` below is a real hash with a fixed basis -- the same one `ContentDB` uses on
  the game side, so the vocabulary is shared.
* **The category salts the seed.** Without it `generate_head(seed=1)` and
  `generate_torso(seed=1)` roll the same numbers, and a roster generated from seeds
  1..4 has its heads and torsos varying in lockstep -- four machines that all look
  "the small one" or "the bulky one" in every category at once.
"""

import random

_FNV_OFFSET = 0x811C9DC5
_FNV_PRIME = 0x01000193
_MASK32 = 0xFFFFFFFF


def fnv1a(text):
    """FNV-1a over a string. Stable across processes, runs and machines."""
    h = _FNV_OFFSET
    for byte in text.encode("utf-8"):
        h = ((h ^ byte) * _FNV_PRIME) & _MASK32
    return h


class ScrapRNG(random.Random):
    """A seeded RNG with the vocabulary a shape generator actually reaches for."""

    def __init__(self, category, seed):
        self.category = category
        self.seed_value = seed
        super().__init__((fnv1a(category) ^ (seed * 2654435761)) & _MASK32)

    def pick(self, options):
        """One of `options`."""
        return self.choice(list(options))

    def maybe(self, probability):
        """True with the given probability. Reads better than `random() < p` at a
        call site that is already dense with numbers."""
        return self.random() < probability

    def jitter(self, magnitude):
        """Symmetric noise in [-magnitude, +magnitude]. The workhorse: this is what
        stops a bolt row from being a perfectly regular bolt row."""
        return self.uniform(-magnitude, magnitude)

    def span(self, low, high):
        return self.uniform(low, high)

    def count(self, low, high):
        return self.randint(low, high)

    def sign(self):
        return 1.0 if self.random() < 0.5 else -1.0

    def sub(self, tag):
        """A child RNG for one section of a build.

        Detail loops draw a variable number of values, so adding one bolt to the head
        shell used to shift every number after it and silently redesign the antenna,
        the cables and the side plates too. Giving each section its own stream means a
        change stays local, which is the difference between tuning a generator and
        fighting it."""
        return ScrapRNG("%s/%s" % (self.category, tag), self.seed_value)
