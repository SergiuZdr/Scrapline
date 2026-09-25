# Iteration 010 — The look

**Status:** planned
**Started:** 2026-09-26 · **Finished:** —
**Answers:** PT4-1, "a visual level-up for everything, from UI to models". Sources were
chosen and tested in the [art-sourcing spike](../plans/art-sourcing.md); the design frame is
the `art-direction-and-readability` skill (readability first, personality second, fidelity
never).

## Goal
Every screen looks like one premium game at night in a scrapyard: surfaces with real
material, lit by a sky that reflects, with the machines, intents and targets always the
brightest, sharpest things on screen — and a written style bible and colour registry that
every future asset is checked against.

## The rule this iteration is judged by
Photographed texture is the "fidelity creep" the skill warns about. So every new surface
comes in **capped**: large texture scale (low frequency), soft normals, tinted into broad
fields, and **below the machines in value**. The read that matters most at 40 px — whose
machine, what it is, what is about to hit it — must gain contrast from this pass, not lose
it. Measured, not eyeballed (step 1).

## Scope
- In: the style bible and colour registry; a luminance check tool; the combat board
  (tiles by terrain, pits, heaps, props, curb, surroundings, sky light); the machines'
  surface detail; combat VFX (shots, impacts, explosions, deaths); the HUD; the title
  screen; the map and garage passes that 009 left rough.
- Out: new machine geometry from the generator (a separate art iteration if the user
  wants it after seeing this); audio.

## Steps
1. **Style bible + registry + measure.** `docs/plans/art-and-audio.md`: named references,
   the palette, one meaning per signal colour, a read contract per element. A tool that
   measures, in a combat screenshot, the luminance margin of machines over the board.
2. **The board**: terrain tiles with capped PBR (metal plate, asphalt, rubble, slag with a
   glowing pool, ridges), hex edge bevels, pits with depth, heaps as scrap, HDRI sky light.
3. **The machines**: triplanar detail maps (normal + roughness) on paint and metal at low
   strength; rim and eye glow tuned so they stay the peak of local contrast.
4. **Effects**: tracers, muzzle flashes, impact sparks, barrel fireballs with smoke, the
   death burst, damage numbers.
5. **The HUD and screens**: panel material, iconography for weapon classes and abilities,
   crew cards with portraits in combat, a turn banner; the title screen as a 3D scene.
6. Before/after sheets of every screen, the luminance check, all tests, docs, merge.

## Acceptance criteria
- [ ] `docs/plans/art-and-audio.md` has a named reference set, the palette and a colour registry with one meaning per colour.
- [ ] The luminance check: machines stay at least as far above the board as before (numbers recorded).
- [ ] Before/after sheets for combat, map, garage, bay, title.
- [ ] All suites green; no new renderer errors in a windowed run.

## Result
(filled in on completion)
