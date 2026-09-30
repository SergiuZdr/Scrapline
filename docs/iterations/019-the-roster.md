# Iteration 019 — Models: the whole roster, made of scrap

**Status:** in progress
**Started:** 2026-09-30 · **Finished:** —
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

## Decisions, lessons, open questions

## Next
