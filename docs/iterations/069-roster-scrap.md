# Iteration 069 — The rest of the roster as comic scrap

**Status:** in progress
**Started:** 2026-10-12 · **Finished:**
**Answers:** the user: make the models for all the remaining robot parts with ChatGPT images and
Colab's GPU, somewhat similar to the ones already made; every concept image approved by them before a
model is attempted.

## Goal
Every part in `data/parts/*.json` has a generated comic-scrap model in `art/parts_gen_scrap/`, drawn
from a concept the user approved, so no machine mixes generated and scripted parts.

## Scope
- In: the 55 parts without a model (Kessler 15, Cinder 15, Vektor 14, Arclight 11): ChatGPT concepts,
  one chat per maker, approved by batch sheet; TRELLIS on Colab driven in the user's Chrome; a rig spec
  per part (`tools/gen3d/parts/<id>_scrap.json`).
- Out (deliberately): new rules or numbers; the 14 parts already made; thumbnails for the gen set.

## Steps
1. Per maker (Kessler, Cinder, Vektor, Arclight): concepts in one ChatGPT chat seeded with that maker's
   approved concepts; the 051/055 rules (maker livery patched with other makers' plates; arms in the one
   side-view layout with an elbow; frames bare, head forward, square; one object per core/module).
2. A numbered sheet per batch (`shots/069_<maker>_<n>.png`); the user approves or sends back.
3. Approved concepts -> `colab_prep.sh` -> Colab notebook -> `colab_prep.sh --import` with a spec each.
4. Look sheets per maker (`tools/shot_machine.gd`); the user judges.

## Acceptance criteria
- [ ] Every concept approved by the user before it went to Colab.
- [ ] `verify_assembly.gd -- --dir res://art/parts_gen_scrap` passes for every part.
- [ ] `verify_assembly.gd`, `verify_animation.gd`, `verify_combat.gd` still green.
- [ ] Look sheets per maker shown; the user plays.

## Result
**Progress (2026-10-12).**
- Kessler: the first sheet (one chat seeded with the approved sheet) came back all one palette and one patch
  style -- the user hated it. Redrawn in a fresh chat with only the drawing technique as reference: every part its
  own salvage origin, colours and joinery, the maker's livery a single small plate; frames mix head, torso and legs
  from different machines; modules slim backpacks that show what they do (the user picked A/B per module).
- Built (TRELLIS on Colab, rigged into `art/parts_gen_scrap/`): ar_maul, ar_harpoon, ch_citadel, ch_dredge,
  ch_colossus, co_bile, co_mag, mo_spikes, mo_plating, mo_reactive, mo_hooks, mo_gyro, mo_ram.
  `verify_assembly.gd -- --dir res://art/parts_gen_scrap`: 115 passed, 0 failed.
  In the game on `main` (2026-10-12): the 13 models, their specs and concepts. `verify_assembly.gd` 168/0,
  `verify_animation.gd` 34/0. Look sheet of all 13 on six machines: `shots/newparts_sheet.png`.
- Frames measured with a width-profile probe (heights 0.58 / 0.60 / 0.70), no `grade` (it turned the Colossus's
  white and red brown). Orientation per part read off front/side previews (arms: weapon to -Y, ring face +X;
  cores: lens to -Y; modules: detailed face to +Y).
- Cinder: 15 concepts approved; Slag Mortar and Heat Fins redrawn for the user. Colab made 8 of them
  (cleaver, flail, flamer, godhammer, minelayer, ripper, reaper, scrapper), then ran out of GPU memory on the
  Crucible Heart (twice, also on a fresh session: too dense a shape for the T4), then on Ember, then the free GPU
  hit its daily limit -- and the runtime went with the 8 models before they were downloaded. Specs for all 15 are
  written (`tools/gen3d/parts/*_scrap.json`); they run again on the next allowance.
- Vektor: 14 approved (Mortar v2, Scattergun, Rail Driver, Snare, Sunspear, Lancer, Courier, Flywheel,
  Flux, Servo, Targeting, Jump Jets, Sprint Pistons, Spotter); cut into `shots/069/colab_in3`. Heat Fins
  redrawn as a cut-down radiator and approved (15 in `colab_in3`). Belt Feeder: the ammo-can idea was
  rejected twice; two new ideas without bullets (`vektor_4`), A (dart rack) approved: 16 in `colab_in3`.

## Decisions, lessons, open questions
- **Each part its own salvage origin, palette and joinery; the maker only as a small plate** (the user).
- **Always say what a part does when showing it**; modules get two variants to pick from.
- Lesson: a chat seeded with a sheet of same-style parts copies its palette and patchwork onto every new part.
- Lesson: ChatGPT edits an UPLOADED image far more faithfully than "your last image" (the flail lost its elbow).
- Lesson: Colab's free runtime disconnects while waiting on the user; the VM and its install sometimes survive.
- Lesson: no fire, smoke or liquid in a concept -- TRELLIS makes it solid.
- Lesson: **download Colab's zip after every few models**, not at the end: an OOM or the daily GPU limit takes the
  runtime and every model on it. A dense, boxy, ornate object (the Crucible) can exceed the T4 even alone.
- Lesson: ChatGPT drifts from the ink style to photo renders over a long chat; ask for "bold black ink outlines,
  flat cel colour" again.

## Next
