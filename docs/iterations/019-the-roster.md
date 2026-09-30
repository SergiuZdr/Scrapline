# Iteration 019 — Models: the whole roster, made of scrap

**Status:** done -- waiting for the user to play it
**Started:** 2026-09-30 · **Finished:** 2026-09-30
**Answers:** the user on 018: yes to this Brute as the look, yes to livery by maker, yes to
sites through TRELLIS -- "do the rest of the roster, but the colours of different parts need to
be more than one colour, representing that they are made from actual scrap".

## Goal
All 40 parts are built the 018 way -- rounded, detailed, heavy -- each visibly patched together
from mismatched plate, and they are the game's models by default.

## Scope
- In:
  - **Every part** by `make_ink_parts.py`: 10 frames (a shape per role and a head, legs and back
    per frame), 10 arms (a shoulder per maker, a weapon per class), 10 cores (a plate per maker,
    the lens per damage type), 10 modules (hazard only on the three that overdrive).
  - **Made of scrap**: a new `patch` zone (a plate scavenged from another machine, in a colour
    that is NOT the part's maker's) and `rust` plates, chosen per piece from the part's id, plus
    bolted repair plates on the big surfaces. Maker colour stays the majority, so sets still read.
  - **Default**: the new set and livery by maker become what the game draws; `--models old`
    shows the shipped roster.
- Out (deliberately): sites and the Reclaimer (each needs the user at the TRELLIS page);
  new animation.

## Steps
1. The `patch` zone in the game; scrap helpers in the builder.
2. Frames; arms and weapons; cores; modules. Checks after each.
3. Pictures; the flag flipped; shots of the crew, a fight, the garage; a roster sheet.
4. Suites; docs.

## Acceptance criteria
- [ ] 40 parts in `art/parts_new/`; `verify_assembly -- --dir` passes for all 10 frames;
  `verify_animation` passes on the new set.
- [ ] A roster sheet from the game: ten frames told apart by silhouette, every part showing at
  least three colours with one that is not its maker's.
- [ ] Every suite passes with the new set as default; run bot unchanged.
- [ ] The user judges it.

## Result

The game draws the new roster by default; `-- --models old` shows the shipped one. Sheets:
`shots/019/roster.png` (ten frames, by the game), `shots/019/board.png`, `shots/019/garage.png`.

- **40 parts** from `tools/blender/make_ink_parts.py` (it builds every part in `data/parts/`):
  - **Frames**: one builder, a spec per frame (`FRAMES`): chest size and taper, a head (dome,
    box, slit, scoop, cab, skull, mast, visor), legs (heavy, wide or lean, scaled in girth), and
    what it carries on its back (stacks, crate, slab, coil, tank, fins, dish, quiver).
    7,800-10,200 triangles each.
  - **Arms**: a shoulder per maker (Kessler's round banded pauldron, Cinder's spiked slab,
    Vektor's angled plate over an ammunition box, Arclight's drum of windings) and a weapon per
    class (hammer, maul, saw, ripper, lance, rail driver, scattergun, mortar, emitter, spotter).
  - **Cores**: a plate per maker (bolted slab, furnace door, insulator panel, hex breech), the
    lens in the damage type's colour. **Modules**: ten, hazard ochre only on the three that
    overdrive.
- **Made of scrap**: `skin()` gives each secondary plate its maker's livery, a `patch` (another
  maker's faded paint) or `rust`, by the piece's own name; `repair()` bolts a mismatched plate
  onto the big surfaces. Maker colour stays the majority, so a set still reads.
- `verify_assembly -- --dir res://art/parts_new`: 141 passed (all ten frames); every suite passes with the new set as default (combat 189, input 22, run 127, run UI 48, onboarding 39, save 15, animation 34); run bot 88.7%, 0 illegal actions (unchanged).
- Pictures for all 40 in `art/thumbs_new/`.

Not done: sites and the Reclaimer (each needs the user at the TRELLIS page); the shipped
roster and its pictures are still in the repo (`art/parts/`, `art/thumbs_ink/`) for `--models old`.

## Decisions, lessons, open questions
- **The new roster and livery by maker are the game's look** (the user: yes to all three).
- **A part is patched from scrap**: livery, a scavenged `patch`, `rust`, neutral `steel`, `trim`.
- Lesson: a spec table per frame over one builder gave ten silhouettes for the cost of one.
- Open: the user's play-test of the roster; delete the shipped roster once it is accepted.

## Next
The user plays it; sites and the Reclaimer through TRELLIS; then Acts 2-3.
