# Iteration 010 — The look

**Status:** done (batch 009–013; play-test after 013)
**Started:** 2026-09-26 · **Finished:** 2026-09-26
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
- [x] `docs/plans/art-and-audio.md` has a named reference set, the palette and a colour registry with one meaning per colour.
- [x] The luminance check: machines stay at least as far above the board as before — they are further above it now.
- [x] Before/after sheets for title, combat and garage (`shots/010_before_after.png`); map and bay were rebuilt in 009 and keep their 009 shots.
- [x] All suites green; no renderer errors in windowed runs.
- [ ] The dirty-aluminium light value on the machines: wired, **not exported** (see below).

## Result

**Contrast, measured** (`tools/measure_contrast.gd`, machines' mean luminance over the ring
of pixels around them):

| Fight | Before 010 | After 010 |
|---|---|---|
| slag_pit | 0.300 / 0.162 = **1.84** | 0.325 / 0.143 = **2.27** |
| proto_yard | 0.309 / 0.174 = **1.77** | 0.315 / 0.151 = **2.08** |
| container_row | 0.327 / 0.168 = **1.94** | 0.318 / 0.143 = **2.23** |

The photographed board made the machines stand out MORE, not less: a darker, lower-frequency
field around them (the skill's "cap background frequency") plus sky reflections on them.

| Suite | Result |
|---|---|
| verify_combat / combat_input / run / run_ui | 134 / 20 / 70 / 33 passed |
| verify_save / assembly / animation | 14 / 100 / 34 passed |

**What changed on screen**
- **Board**: a photographed surface per terrain type, tinted to its field colour at low
  frequency (steel plate, gravel with chunks, worn concrete ridges with a lip, a crusted slag
  pool, rusted pits, corrugated-steel crates, red-rust drums); night HDRI sky light; a green
  gain ring under piles; caches wear the player's blue.
- **Machines**: paint wears the reference sheet's wear — Poly Haven's rusty painted metal
  baked into a livery-neutral map (`tools/make_wear_texture.py`): streaks from the fixings,
  chips, rust through them — with its normal and roughness maps; plate grain on metal; a
  stencilled crew number on the core plate.
- **Effects**: round soft glows instead of square flashes; streak sparks under gravity; a
  drum's fireball with a light flash, smoke and a scorch; kills burn; tracers with a hot core.
- **HUD**: crew cards with portraits of the real machines and HP pips; weapon buttons show
  the arm; text trims inside its card.
- **Title**: a scene — the crew on a hardstand under the floodlights, the Reclaimer's
  beacons in the fog on the horizon — with the menu over its dark side.

### Not done, and why
- **The aluminium light value** (art/reference: "the finding that matters most") is wired
  end to end — a new `Aluminium` material and `alu` zone in the generator, the game, the
  thumbnail and hero mirrors — but **the roster was not re-exported**: regenerating showed
  the committed generator does **not** reproduce the committed roster. Heads came out
  different, and most arms lost their pauldrons (`builders/arm.py` gives a pauldron to one
  arm archetype in seven, while the shipped roster and CLAUDE.md have one on every arm). The
  export was rolled back. Which one is right is an art decision for the user (open question
  in MEMORY); once settled, `make_scrap_parts.py` exports the aluminium with it.
- New machine geometry (the reference's heavier mechanism) was out of scope, as planned.
