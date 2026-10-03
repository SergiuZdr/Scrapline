# Iteration 042 — A model for every part

**Status:** in progress
**Started:** 2026-10-03 · **Finished:** —

## Goal
Play-test 12, PT12-6: "the game lacks models for each robot part". Twenty-six parts wore another
part's model (`"model"`): the twelve modules of 033, ten parts of 029, the five legendaries and two
older ones. After this every part has its own model and its own picture.

## Scope
- `make_scrap_parts.py --only <id>` for each of the 26 -- the generator is seeded by the part's id,
  so each comes out its own shape; the committed roster is NOT regenerated (CLAUDE.md: it does not
  reproduce it). Arms may name a `look` (the Flamer a flamer, the Coilgun a gatling, the Harpoon a
  grapple claw) without touching `weapon_class`, which drives the attack animation.
- Pictures: `make_ink_thumbs.gd --only` the 26.
- Checks: verify_assembly (sockets, standing), the arm seating probe, a roster sheet from the game.

## Acceptance criteria
- [ ] No part has a `"model"` alias; every part's .glb and picture exists (verify_combat checks).
- [ ] verify_assembly passes over the new models.
- [ ] A sheet of the 26 rendered by the game.
- [ ] All suites.

## Result

## Decisions, lessons, open questions

## Next
