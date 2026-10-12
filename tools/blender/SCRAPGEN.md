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
| Head | `camera_housing`, `welder_hood`, `control_box`, then `visor_box`, `cyclops_drum`, `wedge_sensor`, `cage_lamp` |
| Torso | `generator_can`, `engine_bay`, `furnace_vessel`, then `boiler`, `plated_box`, `engine_block`, `cage_frame` |
| Arm | `excavator_arm`, `manipulator_arm`, `suspension_arm`, then `piston_arm`, `girder_arm`, `pipe_arm`, `armour_arm` |
| Weapon | `slug_cannon`, `rivet_gun`, `saw_blade`, `sledge`, `flamer`, `rail_lance`, `gatling`, `grapple_claw` |
| Leg | `hydraulic_ram`, `strut_leg`, `gantry_leg`, then `digitigrade`, `piston_column`, `hoof_strut`, `caged_leg` |

**The first three of each are the REDESIGNED base set.** Each one answers "what real
industrial object was this before it became a robot part" -- a portable generator, a
vehicle engine bay, a riveted furnace; an industrial camera, a welding hood, an
electrical enclosure; a digger boom, a factory manipulator, a suspension strut; a
hydraulic ram, a coil-over strut, a latticed gantry. The four originals stay behind them
so nothing referencing them breaks.

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

## Repair history is part of the identity

A scrapyard machine has been fixed many times, and that history is the visual identity
rather than damage laid on top of it. `builders.repair_history` runs for every category
after its archetype, and three rules keep it from becoming noise:

- **Every repair does a job.** `greeble.repair_patch` is bolted AND welded, because a
  plate with neither is a sticker and a plate with only one reads as unfinished. An
  `improvised_brace` spans two points that would need bracing. Nothing is placed because
  a surface looked empty.
- **Repairs are in the WRONG metal** (`greeble.REPAIR_METALS`, which deliberately
  excludes `DirtyMetal`). A patch in the same paint as the panel under it is a feature.
- **Few and large.** Two or three per component, at a size that survives being forty
  pixels tall. A hundred small ones is a texture, and a bad one.

The same principle governs plumbing: `greeble.hose_between` places a union at BOTH ends
and the hose between them, so a hose is a connection rather than a rubber band lying on
a model. A bare `cable` between two arbitrary coordinates is the single most common way
a hand-built machine starts looking procedurally generated.

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

## Appendix: the scrap roster, checking it, hero renders, the arena

Moved here from the agent notes on 2026-10-12. Since 064 the game draws `art/parts_gen_scrap` by default; this is the procedural roster in `art/parts`.

### The playable roster is generated by the SCRAP generator

`art/parts/*.glb` is built by **`tools/blender/make_scrap_parts.py`**, which composes
the roster out of `tools/blender/scrapgen/` — the procedural scrap-component generator.
`make_parts.py` is the previous generator and still works; running it overwrites the
whole roster with the old models and nothing warns you, because both write the same 40
filenames. Read `tools/blender/SCRAPGEN.md` before touching either.

**Nothing about the game changed to accommodate it.** `data/parts/*.json`, `ContentDB`,
`ConstructView`, `ConstructRig` and the entire simulation are untouched: the bridge
composes generator output into the shape the game already loads. That is the whole
design — an art pipeline that requires the game to change to suit it is one that will be
abandoned the next time the art changes.

The two systems have different socket contracts, and the mapping is not one-to-one:

| Game slot | Built from | Why |
|---|---|---|
| `chassis` | torso + head + two legs, fused | The game has no head slot, and a machine without one reads as decapitated rather than modular |
| `core` | a reactor built from greeble | The generator has no core, and the core carries the DAMAGE-TYPE colour — the fastest read on the battlefield |
| `arm_l/r` | arm + weapon, fused | The game's "arm" IS the weapon, so `weapon_class` keeps driving both the model and the attack animation |
| `module` | a small salvage assembly | The one slot allowed to carry hazard ochre, and only when `can_overdrive` is true |

**The generator faces +Y; the game faces −Y.** Every part is turned 180° about Z on the
way out. That rotation also maps the generator's `_L` mounts onto the game's `_l` on both
shoulders and hips, which is why it is a rotation and not a mirror — a mirror would flip
the handedness of every asymmetric detail with it.

**Role is a PROPORTION, not a size.** `bulk_of` scaled a chassis uniformly by HP, and a
uniformly scaled copy has the same outline as its original — so a 1320 HP Citadel and a
470 HP Strider came out as one thin humanoid at two sizes, and role, the thing a player
must judge across a battlefield in a glance, was not on the model at all. Silhouette is
the only cue that survives being 40 px tall. `ROLE_PROPORTION` gives each role a
per-axis (width, depth, height) scale — an anchor is a squat wide wall, a marksman is
lean and tall — and HP is weighted almost entirely into width and depth. Letting HP
drive height too made the two cancel: a heavy anchor is shortened by its role and
lengthened by its health, and the roster came back all one height. **Mass reads as
girth; role reads as stature.** A per-axis scale is only safe because `TO_GAME` is a 180°
turn about Z, which a diagonal scale commutes with exactly.

**One scale for the whole kit** (`SCALE`), never per slot. Chassis vary within a narrow
band by HP so a Citadel reads as heavier than a Strider — the old generator did the same
and it was doing real work — but arms and cores stay fixed, because they are standard
parts bolted onto whatever frame will take them.

**Only the torso is team-painted.** The generator tags most large shells `DirtyMetal`,
which maps to the `paint` zone, and paint is the only zone the game tints. Left alone,
that put roughly three quarters of every machine in one flat team hue and the roster
became blue shapes and red shapes — the exact failure the palette exists to prevent. The
bridge recolours head, arms and legs to `metal`, which is also what the zone doctrine
above already said legs were.

**A budget has to measure the whole part.** `make_scrap_parts.py` checked each slot
against `config.TRI_BUDGET["torso"]` — 4200, one generator component's number — while
every game slot is a FUSION of several, and while the legs, being child objects, were
not counted at all. So a chassis reported 4516 when it was really 8412, and five
chassis were flagged whose every torso, head and leg sits comfortably inside its own
budget. `SLOT_BUDGET` is derived from the components each slot actually fuses, and
`part_triangles` counts the limbs. The run now also prints the per-construct and
12-unit field totals, because the per-part number is not the one a phone pays:
15,380 mean per construct and 184,560 on the field, against a 22,000 / 264,000
ceiling.

**Pictures are regenerated with the meshes**: `tools/make_ink_thumbs.gd` after any part model
changes. New geometry against old pictures makes every card a picture of a part that no
longer exists, which is worse than a missing picture because it is wrong rather than absent.

### Checking art in BLENDER is not checking the game

`check_parts.py` passed a roster the game was drawing **lying on its back with both arms
on the floor**. It was not wrong — in Blender everything was connected and every
attachment seated. The fault was in the EXPORT, and no amount of checking on the side
that is correct can find it.

**Parent with `parent_set(keep_transform=True)`, never `child.parent = root`.** A bare
assignment leaves `matrix_parent_inverse` at identity, so the child's transform is
reinterpreted in the parent's frame; `export_yup` then writes the hierarchy in a rotated
basis. A socket authored 0.43 m up arrives in Godot at ground level, and the arm bolted
to it sits in the dirt looking exactly like a detached part.

```bash
$GODOT --headless --path . --script res://tools/verify_assembly.gd
```

`verify_assembly.gd` loads each exported `.glb` through the game's own path and asks
where things ended up: is the chassis on the ground, is each socket off the floor, is
each socket actually on the chassis. **Sockets at y=0 is the signature of that export
bug**, and it is the check that matters.

Two traps inside the checker itself, both of which produced confident wrong answers:

- **Never measure geometry with `global_transform * get_aabb()`.** The importer leaves
  the conversion rotation on mesh nodes, and the axis-aligned bound of a tilted box
  overstated one chassis by 23 cm — reporting a correctly standing frame as sunk into
  the ground. Measure real vertices.
- **"Taller than wide" is not a test for upright.** An anchor is deliberately a squat
  wide wall and fails it while standing perfectly.

`check_parts.py` monkeypatches `join`; its wrapper takes `**kwargs` so that `join`
gaining an argument does not kill the run mid-roster with a `TypeError` that looks like
a clean pass until the summary never prints.

### Looking at the art — do not trust one render

**`check_parts.py` is the gate, not your eyes.** It builds every part, computes each
piece's world bounding box, and reports any piece that touches nothing. It exits 1 if
anything floats.

```bash
blender --background --python tools/blender/check_parts.py          # whole roster
blender --background --python tools/blender/check_parts.py -- --part ch_brute
```

It found **315 floating pieces** on a roster that had been "fixed" four times by eye.
The cause was a single line: `box()` scaled a unit cube by `size / 2`, so **every box in
the game was half its declared size** while every cylinder was correct. Plates, bolts,
cowls and crests were never misplaced — they were too small to reach what they sat on.
Nothing found that by looking at renders, because a detached bolt hides behind the body
at most angles and the angle it hides at is usually the one you are looking from.

A consequence worth remembering: **every authored dimension in the file was tuned against
the halved output**, so correcting `box()` doubled all of them. Undoing that was not one
edit but four, and each one was found only by looking at the result:

- `shape` table — body width, depth and torso height halved.
- `leg_h` in the same table — missed at first on the reasoning that it is a position, not
  a box size. True, and irrelevant: bodies shrank by half and legs did not, so the whole
  roster became a small torso on long stick legs.
- `ARM_SCALE` — arms doubled and dwarfed the chassis carrying them.
- `ATTACH_SCALE` — cores and modules, missed when only the arms were scaled back. They
  came out **wider than the torso they mount to**: a module box that dominated the
  silhouette of every construct, and a core lens that made every frame read as "a dark
  box with a white circle on it".

The pattern is worth naming: fixing a unit bug at the bottom of a generator invalidates
every number tuned above it, and they do not announce themselves.

```bash
# Six-angle turnaround; --assembled bolts attachments on via the real socket lookup
blender --background --python tools/blender/inspect_parts.py -- --assembled ch_brute
python3 tools/blender/compose_sheet.py art/preview/turn art/preview/turn.png 3

# One view per chassis, same angle, for judging whether the roster reads as distinct
for c in ch_brute ch_bulwark ch_strider; do
  blender --background --python tools/blender/inspect_parts.py -- \
    --assembled $c --angles 1 --yaw 40 --keep --out art/preview/roster
done
python3 tools/blender/compose_sheet.py art/preview/roster art/preview/roster.png 5
```

**Render the roster from the GAME, not from Blender.** `gait_preview.tscn --still --yaw`
does this, one frame per chassis at a fixed angle. The Blender grid showed a roster that
looked fine while the game was drawing tiny torsos on stick legs with modules wider than
their chests — every proportion fault above was invisible until the sheet came out of the
engine. Use `--yaw` on it: weapons project straight forward, so a dead-on view points all
of them at the camera and a ten-frame sheet shows no weapons at all.

```bash
for c in ch_brute ch_bulwark ch_strider; do
  $GODOT --path . res://tools/gait_preview.tscn --resolution 520x520 -- \
    --shot /tmp/roster --frames 1 --every 4 --still --yaw 145 --chassis $c
done
python3 tools/blender/compose_sheet.py /tmp/roster /tmp/roster.png 5
```

The roster grid is what caught every chassis carrying the same oil drum — the largest,
highest-contrast object on the model, repeated ten times. **Which junk a frame is
rebuilt from is the cheapest per-chassis identity there is**, and it survives at
gameplay distance where panel detail does not.

### Hero renders — `tools/blender/hero_render.py`

Cycles beauty renders of assembled constructs: the shot for a store listing, and the only
view that shows the roster lit the way the game lights it.

```bash
blender --background --python tools/blender/hero_render.py -- --chassis ch_brute
blender --background --python tools/blender/hero_render.py -- --roster --team a
# One frame per weapon class on one chassis, each at its signature strike moment
blender --background --python tools/blender/hero_render.py -- --poses --chassis ch_reaper
python3 tools/blender/compose_sheet.py art/hero art/hero/sheet.png 5   # art/hero is gitignored output
```

**This is the opposite tool to `inspect_parts.py` and they must both exist.** Inspection
lighting is flat and bright on purpose — a moody key hides the seams a geometry check is
hunting. A hero render hides them too, which is exactly why it is never the thing you
check geometry with.

Everything below cost a wrong render first:

- **Metallic is a switch.** `make_parts.zone_material` puts every zone at 0.8, which is
  neither dielectric nor conductor and renders plasticky. The GAME was always right —
  `part_materials.gd` runs paint at 0.05 and metal at 0.90 — so the hero materials read
  from the game's values, not from the Blender placeholders. Nothing here is exported;
  the `mat_<zone>` glTF contract is untouched.
- **A metal authored near black renders black.** `dark` and `tread` sit far below the
  ~0.5 sRGB floor a conductor needs, so under a night key the legs, feet and pistons left
  the picture entirely and the first renders showed a torso hovering over the floor.
  `HERO_ALBEDO` lifts those two zones for render only.
- **Wear has to have area.** A Bevel node dotted against the true normal finds every
  edge with no UVs, but paired with a tight radius it produces a perfect one-pixel
  outline: provably correct in a mask render, invisible in the shot. And it needs a
  second, wider mask — driving colour, metallic and roughness from ONE mask turned every
  edge into a chrome pinstripe.
- **Edge wear alone is a rim effect.** On a roster of large flat boxes that leaves every
  panel centre factory-fresh. The vertical `streak_mask` staining is what actually reads
  as salvage.
- **Frame by projecting vertices, not from the bounding box.** A forward-projecting lance
  makes the depth extent huge while contributing almost nothing to screen width, so a
  `max(width, depth)` solve pulls the camera miles back. Solve the lens into the distance
  too — `height * 1.55` is a 50 mm rule and puts an 85 mm inside the machine.
- **Never assign a limb a fresh euler.** The generator rests `ch_brute`'s left leg at
  (-0.32, 3.14, 0.30); `rotation_euler = (angle, 0, 0)` discards that and folds the legs
  up inside the torso. `swing_limb` composes about the hip instead.
- **Attachments mount with `mount()`, not `parent_keeping_transform`.** The latter is
  correct for the export path and does exactly what it says here: it pins each part at
  the origin it was built at, so cores and modules render lying on the floor.
- **Key:fill ratio is an art decision, not a brightness one.** At 7:1 the cold fill was
  too weak to tint anything and blue team paint under a pure sodium key came back
  desaturated mint. Around 2.5:1 the shadow side stays blue while the key side goes warm,
  which is the entire Rust & Sodium read.

Cycles is CPU-only on this machine (Intel Mac, no Metal backend), so 128 samples with
adaptive sampling and OpenImageDenoise is the working default — 200 cost three times as
long for a difference that did not survive being looked at.

### The arena

`tools/blender/make_arena.py` builds a **kit**, not a model: maps differ in size, so a
single arena mesh would float clear of a small one and be cut through by a large one.
`Surfaces.kit(name, dim)` dresses a piece in the palette; the combat scene, the yard, the
garage and the title stage place them.

Read from the fight outwards, each ring does one job:

| Ring | Job |
|---|---|
| `barrier` | low concrete line at the play edge — the boundary, without a glowing rectangle |
| `container` | stacked steel: the wall that encloses the yard, plus 45° stacks closing the corners |
| `car_stack` / `tyre_stack` | fill at human scale, so the constructs read as **big** |
| `floodlight` | the diegetic source of the key light (a lit bulb: the toon ramp ignores point lights) |
| `gantry` | crane on the FAR skyline, so the arena has a horizon instead of an edge |

**Scenery is darkened by `ARENA_DIM`.** Dressed in the constructs' own materials the
walls came out brighter than the machines in front of them and the eye went to the
containers — the same mistake the loose-scrap berm made. Lamps are exempt. Scenery also
loses the silhouette rim: that rim is part of what separates a unit from its background,
so giving it to the background throws the distinction away.

**Never put `hazard` ochre on the arena.** It was on every barrier cap for one build,
which ringed the play area in the exact colour reserved for "this construct explodes".

```bash
blender --background --python tools/blender/make_arena.py -- --out art/arena
```
