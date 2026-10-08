# Iteration 051 — Comic machines

**Status:** in progress
**Started:** 2026-10-08 · **Finished:** —
**Answers:** the user on 045's generated Brute: "better now in terms of how detailed it looks, but it
does not fit in the concept art of a comics art game".

## Goal
The generated Brute keeps its detail but is drawn like the rest of the game: flat colour in the
game's palette, three bands, hatching, an ink line -- not a photographed, speckled texture. The user
picks the look from side-by-side renders in the fight.

## Scope
- In: stylizing the existing generated parts (no GPU): **A** the texture simplified, snapped to the
  game's palette and inked along its colour edges; **B** the texture dropped, each face given a
  material zone by its colour, so `Ink.dress_machine` paints it like every scripted machine (livery,
  hatching, rim). **C** (if neither is enough) comic-style concepts regenerated through TRELLIS.
  `--models gen` can name which set to draw.
- Out: the rest of the roster.

## Steps
1. `rig_generated_part.py`: `style` "texture" (045) | "inked" (A) | "zones" (B).
2. The Brute in each style into its own set; `Models` takes `--gen-dir`.
3. Same fight, same frame, close-ups side by side; the user picks.

## Acceptance criteria
- [ ] Each style passes `verify_assembly.gd -- --dir <set>`.
- [ ] A close-up sheet of 045 / A / B (and the old scripted Brute) in the same fight frame.
- [ ] verify_combat, verify_run pass; the default game unchanged.
- [ ] The user picks.

## Result

## Decisions, lessons, open questions

## Next
