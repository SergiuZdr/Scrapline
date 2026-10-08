# Iteration 051 — Comic machines

**Status:** done -- waiting for the user's look in the game
**Started:** 2026-10-08 · **Finished:** 2026-10-08
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
- [x] Each set passes `verify_assembly.gd -- --dir <set>` (A, B, C and the final scrap set: 15/15 each).
- [ ] A close-up sheet of 045 / A / B / C in one fight frame -- dropped: the user chose a new direction
  (concept 2 in the comic style, then ChatGPT Images) before it was needed.
- [x] verify_combat 355, verify_run 187, verify_assembly 168; the default game unchanged (`--models gen` is opt-in).
- [x] The user approved the scrap concepts and asked for the 3D Brute: `shots/051_brute_views.png`,
  `shots/051_round.mp4`. The in-game look is theirs to judge.

## Result
- **A / B / C** were built (`--style inked|zones` in the rig; C from a comic FLUX concept). The user
  picked comic concept 2, then said FLUX "always looks kinda bad, with inconsistent design and flaws".
- **ChatGPT Images** (the user's pick of four generators): the whole Brute from concept 2, then each
  part from the same chat, so one design. The user: the robot must read as **scrap** -- parts of
  different colours, off different machines, and no single "right" build. So each part wears its
  **maker's** paint (Kessler mining yellow: frame, hammer, core; Cinder foundry red: saw, backpack)
  and is patched with plates off other machines (`art/concepts/machines/*_scrap.png`).
- **Capture without downloads**: Chrome's Save dialog stops every download and ChatGPT's page blocks
  posting to localhost, so `tools/gen3d/chatgpt_show.js` shows one image alone on white in the page,
  the browser extension saves the screen, `tools/gen3d/grab_crop.py` crops it.
- **3D**: Colab (runtime 2025.07, ~11 min install, ~1 min a model), rigged into `art/parts_gen_scrap/`
  (specs `tools/gen3d/parts/*_scrap.json`): the frame came armless and facing forward; the hammer
  turned -90, the core 180; arms 0.5 m; only the frame graded ([0.7, 0.72]) back to the concept's
  mustard -- grading the arms turned the hammer beige. 20,013 triangles.
- `tools/shot_machine.gd`: one machine in the game's ink at chosen angles.

## Decisions, lessons, open questions
- **Concepts come from ChatGPT Images, one chat per machine** (the whole machine first, then each
  part against it): one design, no FLUX flaws.
- **A part wears its maker's paint and patches off other machines**: mixed builds look right, and no
  single build looks "correct". Open: maker SET bonuses (011) still reward matching in play.
- Lesson: a capture beats a download when the browser asks where to save; `scale` on a saved
  screenshot shrinks the file too -- capture at full size.
- Lesson: grade per part, never one number for the set: the same grade dulled the frame's yellow
  correctly and turned the hammer beige.

## Next
The user looks in the game (`-- --models gen --gen-dir res://art/parts_gen_scrap`) and decides on the roster this way.
