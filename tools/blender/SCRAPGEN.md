# Scrap robot component generator

Procedurally generates interchangeable 3D components for scrapyard robots — heads,
torsos, arms, weapons, legs — and exports them as GLB for a game engine.

**This now feeds Scrapline's playable roster.** `tools/blender/make_scrap_parts.py`
composes these components into the 40 parts the game loads, and `art/parts/*.glb` is
built from it. `make_parts.py` is the previous generator; it still works and running it
silently overwrites the whole roster, because both write the same 40 filenames.

The kit keeps its own socket contract, naming and materials regardless. The bridge does
the translating, in one direction only — nothing in `scrapgen/` knows Scrapline exists,
which is what lets the kit stay a general-purpose generator instead of becoming one
game's asset script.

```bash
blender --background --python tools/blender/make_scrap_parts.py -- \
    --out art/parts --thumbs art/thumbs
$GODOT --headless --path . --import
$GODOT --headless --path . --script res://tools/verify_assembly.gd
```

```bash
blender --background --python tools/blender/scrap_robot_generator.py -- --out exports
python3 tools/blender/verify_scrap_exports.py exports
```

That builds 24 components (4 heads, 4 torsos, 4 arms, 8 weapons, 4 legs), assembles 3
demo robots from random combinations, validates the whole kit, and writes GLB.

## Layout

| Path | What lives there |
|---|---|
| `scrap_robot_generator.py` | CLI, and the five `generate_*` functions |
| `scrapgen/config.py` | Scale, proportions, budgets, collection and folder names |
| `scrapgen/sockets.py` | **The socket contract.** Read this one first |
| `scrapgen/rng.py` | Seeded determinism |
| `scrapgen/materials.py` | The seven materials, and their mapping to the game's zones |
| `scrapgen/primitives.py` | box / taper_box / cylinder / curve_tube, and transform surgery |
| `scrapgen/greeble.py` | The scrap vocabulary: engine blocks, radiators, shocks, cables |
| `scrapgen/builders/*.py` | One file per category |
| `scrapgen/component.py` | The Component object and the shared finalize pipeline |
| `scrapgen/registry.py` | The category table — the only place that knows there are five |
| `scrapgen/assembly.py` | Demo robots, built through the real socket lookup |
| `scrapgen/exporter.py` | GLB export |
| `scrapgen/validate.py` | `validate_components()` |
| `inspect_scrap.py` | Review renders |
| `verify_scrap_exports.py` | Checks the exported bytes, outside Blender |

## The socket contract

A modular kit is not modular because the pieces are separate files. It is modular
because every variant of a category presents its mounts **at the same place**, so any
arm fits any torso with an identity transform. One variant moving a socket to suit its
own silhouette means every combination involving it needs a hand-authored offset — and
a kit that needs 4×4×8 hand-authored offsets is not a kit.

So socket positions are a table in `sockets.py`, and `place_sockets` is the only way a
component gets its mounts. A builder cannot override them.

| Category | Sockets | Origin |
|---|---|---|
| Torso | `HeadSocket`, `ShoulderSocket_L/R`, `HipSocket_L/R` | pelvis centre |
| Head | `NeckSocket` | the socket itself |
| Arm | `ShoulderSocket`, `WeaponSocket` | the shoulder |
| Leg | `HipSocket` | the hip |
| Weapon | `MountSocket`, `MuzzleSocket` *(free)* | the mount |

Attachments are authored with their mount **at the origin**, so assembly is "set the
child's position to the parent's socket" and nothing else. `MuzzleSocket` is the one
free socket: it marks where a muzzle flash spawns, and a sawblade and a rail lance
genuinely do not have that point in the same place, so it is checked for existence
only.

**What varies, then?** Everything except the mount planes. A torso may be a boiler
barrel or a slab-sided box, 0.30 m wide or 0.46 m wide. What it may not do is decide
where its shoulders are — whatever shape it takes, `_shoulder_boss` bridges the body
out to `TORSO_SHOULDER_X` so an arm has something to sit against. Validation checks
exactly that: a socket with no geometry behind it is a mount hanging in the air.

`ShoulderSocket` and `HipSocket` are suffixed `_L` / `_R` because a robot has two of
each. Underscores rather than Blender's `.L` / `.R`: the dot suffix carries mirror
semantics in Blender and gets mangled by some glTF pipelines, and these names have to
reach the engine intact.

## Variation is archetypes first

Varying sizes, plate counts and bolt patterns produces a roster of the same machine at
different scales. It passes every automated check and nobody can tell the parts apart.

So each builder starts by choosing an **archetype** — a structurally different way of
being a head — and layers detail inside it:

| Category | Archetypes |
|---|---|
| Head | `visor_box`, `cyclops_drum`, `wedge_sensor`, `cage_lamp` |
| Torso | `boiler`, `plated_box`, `engine_block`, `cage_frame` |
| Arm | `piston_arm`, `girder_arm`, `pipe_arm`, `armour_arm` |
| Weapon | `slug_cannon`, `rivet_gun`, `saw_blade`, `sledge`, `flamer`, `rail_lance`, `gatling`, `grapple_claw` |
| Leg | `digitigrade`, `piston_column`, `hoof_strut`, `caged_leg` |

Seeds 1..N map onto the N archetypes deterministically, so the first generation pass
shows what the kit can actually do rather than three boiler shells and a wedge by
chance. Beyond that the archetype is rolled.

Two archetypes per category are deliberately **open** — the cage head, the cage torso,
the caged leg. A roster where every mass is solid reads as one machine; being able to
see through a part is what proves the others are shells rather than blocks.

## Materials

Seven materials, all plain Principled BSDF driven by colour, metallic and roughness —
the subset glTF actually transports. Procedural node trees export as nothing.

`RustyMetal` · `DarkMetal` · `OldSteel` · `Copper` · `Rubber` · `Glass` · `DirtyMetal`

**Metallic is a switch**: 0.0 or ~0.9, never the middle. A value near 0.5 is neither
dielectric nor conductor and renders as plastic.

Each material also carries a **zone** (`materials.ZONE_OF`) mapping onto the contract
`scripts/presentation/part_materials.gd` already reads. `--zones` renames on export, so
the same mesh serves the standalone kit and the live game:

```bash
blender --background --python tools/blender/scrap_robot_generator.py -- --out exports --zones
```

Without it the game cannot tint these components, and two teams of six render
identically. `DirtyMetal` → `paint` is the only team-tinted zone, so a component with
no `DirtyMetal` on it reads as neutral on both teams.

## Adding a category

Three edits, no rewrite — a shoulder pod, a backpack, a tail:

1. `scrapgen/builders/pod.py` with a `build(component)` function and an `ARCHETYPES` list
2. a line each in `config.COLLECTIONS`, `PREFIXES`, `EXPORT_DIRS`, `TRI_BUDGET`
3. an entry in `sockets.CONTRACT` and one in `registry.CATEGORIES`

The seeded RNG, connectivity check, join, origin, socket placement, collection filing,
triangle budget, exporter and validator are all generic over that table and pick the
new category up for free. That is the real test of modularity: not whether the meshes
are separate files, but whether adding a category touches one place or nine.

## Checks

```bash
# Inside Blender: names, collections, sockets, origins, materials, ground plane
blender --background --python tools/blender/scrap_robot_generator.py -- --no-export

# Outside Blender, on the bytes that ship
python3 tools/blender/verify_scrap_exports.py exports

# Reproducibility: two runs must be byte-identical
blender --background --python tools/blender/scrap_robot_generator.py -- --out /tmp/a --no-demo
blender --background --python tools/blender/scrap_robot_generator.py -- --out /tmp/b --no-demo
python3 tools/blender/verify_scrap_exports.py /tmp/a --against /tmp/b

# Review renders
blender --background --python tools/blender/inspect_scrap.py -- --out art/scrapgen
python3 tools/blender/compose_sheet.py art/scrapgen/components art/scrapgen/sheet.png 4
```

`verify_scrap_exports.py` runs **outside Blender on purpose**, and restates the socket
contract in its own numbers rather than importing `sockets.py`. A checker that imports
the thing it checks agrees with it by construction and cannot catch a contract that
changed by accident. This project has already shipped a roster that was correct in
Blender and arrived in the engine lying on its back with both arms on the floor — the
fault was in the export, and no amount of checking on the side that is correct finds it.

## Things that cost a wrong result first

- **Object names are unique per FILE, not per component.** Name socket empties after
  the contract and the first torso gets `HeadSocket`, the second `HeadSocket.001`,
  silently. The assembler then finds sockets on one component in four, and every
  exported `.glb` after the first carries a mount the engine cannot look up. Empties
  are prefixed and carry the contract name in a `socket` custom property;
  `exporter._bare_socket_names` renames for the duration of one export, which is safe
  because no bare name is ever taken.
- **`parent_set(keep_transform=True)`, never `child.parent = p`.** The bare assignment
  leaves `matrix_parent_inverse` at identity, `export_yup` writes the hierarchy in a
  rotated basis, and a socket authored 0.43 m up arrives at ground level.
- **`box()` scales a unit cube, so the factor for dimension `d` is `d`, not `d/2`.**
  Halving it makes every box half its declared size while every cylinder is correct,
  and plates and bolts float because they are too small to reach what they sit on.
- **Measure with real vertices, never `matrix_world @ bound_box`.** The transformed
  corners of a rotated box describe a much larger volume, which reports floating pieces
  as connected — the exact job the check exists for.
- **Mount clearance is a surface query, not a nearest-vertex query.** Every neck mount
  sits on the axis of a collar ring, and a cylinder has no vertex on its own axis. The
  vertex version failed all four torsos for being correct.
- **Shared dressing must snap to geometry.** A patch at a computed coordinate is right
  for the archetype it was tuned against and floating for the rest — a cage torso is
  air exactly where a boiler is a wall. `snapped_patch` finds the nearest real surface.
- **Connectivity is checked before the join**, because afterwards every piece is one
  mesh and the question cannot be asked. It reports detached ISLANDS, not just orphans:
  an exhaust stack whose three parts hold each other 2 cm clear of the hull passes a
  per-piece test.
- **A limb shell must be a strut along the bone, not a box at its midpoint.** The elbow
  leans forward; an axis-aligned shell crosses the arm instead of covering it, and the
  armoured arm rendered as two pale blocks with a gap between them.
- **"Open" is a clearance, not a topology.** The hydraulic arm hid its ram three times.
  Behind a thin bone it was visible only in exact profile, which is the one angle the
  camera never has for a limb hanging at a construct's side. Beside a thick bone the bone
  read as the arm and the ram as an accessory. Between twin rails it was *still* hidden,
  because the rails sat at 0.055 and the ram had a 0.052 radius — an open frame with no
  gap in it. What fixed it was measurable air: rails at ~0.10, ram at ~0.044, and the ram
  pushed forward so it breaks the frame's silhouette from three-quarter views instead of
  only from dead-on. A copper gland then tells the eye where to land.
- **Render from the front.** The first review sheet was rendered at yaw 38 — a
  three-quarter view of the roster's backs, with every face hidden and every weapon
  projecting away behind the arm holding it, so the robots appeared unarmed. The
  renders looked entirely plausible.
- **Inspection light must not clip.** The first rig was bright enough that everything
  above mid-grey rendered as the same white, so a palette change made no visible
  difference and the roster looked like clean plastic whatever the albedo said.
- **Blender's polygon order varies between processes.** Vertices are reproducible;
  polygon order is not, so exports failed checksums while being geometrically
  identical. `primitives.canonicalise` sorts faces into a fixed order so `md5` can
  answer the reproducibility question directly.
