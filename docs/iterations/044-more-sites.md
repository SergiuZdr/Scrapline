# Iteration 044 — Models for the warlord, the arena, the refinery and the auction

**Status:** done -- waiting for the user's look
**Started:** 2026-10-04 · **Finished:** 2026-10-04
**Answers:** the user: "do models for warlord, arena, refinery, auction" -- the four site kinds of
030-031, which still stand on the map as kit props (the warlord borrowing the elite's bunker).

## Goal
Each of the four kinds stands on the map as its own TRELLIS model, made the 020 way.

## Scope
- In: a concept per kind (FLUX.1-schnell, dark or saturated on white, front toward the viewer);
  `tools/gen3d/next_site.sh` for each (our own mask, raw kept, cleaned with detail kept); the
  kinds with a front (warlord, refinery, auction) facing the camera; the warlord keeps its red lamp.
- Out (deliberately): Acts 2-3's gates (one gate model serves every act); second variants.

## Steps
1. Concepts. 2. `next_site.sh` knows the four kinds; runs as the allowance allows (four or five
a day, a rolling 24 h). 3. Each checked alone and on the map. 4. Suites; docs.

## Acceptance criteria
- [x] Four models in `art/sites/`, each standing on its kind's sites, fronts toward the camera.
- [x] run_ui 50, onboarding 39, run 178 pass.
- [ ] The user looks.

## Result

Sheet: `shots/044_sites.png` (each alone), `shots/044_map.png` (each on the map).

| Kind | Concept | Model | On the map |
|---|---|---|---|
| warlord | a throne welded from crushed cars under a crane magnet, spiked walls, a red banner | 11,999 triangles (27,562) | 1.3x, facing, its red lamp kept |
| arena | a round pit ringed by tyres, floodlights, a fence, a scoreboard | 11,998 (23,285) | turns freely (it is round) |
| refinery | a furnace with a glowing mouth, a chimney, a conveyor up to a tank | 11,999 (30,631) | facing |
| auction | a stage under a red-and-black awning, crates, a price board | 12,000 (44,315) | facing; its white slab greyed |

- **All four in one evening**: the allowance was full again (the last run, the gate, was more than
  24 hours earlier), so FLUX for the four concepts and TRELLIS for the four models fit.
- **The cut learned two things** (`cut_background.py`): background shut in by ropes or a fence (the
  warlord's crane triangle, the arena's fence panels) never touches a corner, so near-pure white
  anywhere counts as background too -- in patches larger than a highlight, so a lit bulb stays; and
  the refinery's smoke was painted out of its concept (it would have become a white lump on the
  chimney).
- **The auction's slab glared white on the map**: re-cleaned from the kept raw file with
  `--grey-white` (no GPU); `next_site.sh` now does that for the auction too.
- **The warlord** stands at 1.3x, as its borrowed bunker did: a mini-boss's lair should stand over
  the sites around it.

## Decisions, lessons, open questions
- **The four 030-031 kinds have their own models**; nothing on the map borrows another site's now.
- Lesson: a background pocket enclosed by thin lines is still background; cut it by colour, not
  only by reach from the corners. Smoke and steam belong out of a concept meant for a model.
- Open: the user's look; Acts 2-3's own gates (one gate serves every act).

## Next
The user looks at the map.
