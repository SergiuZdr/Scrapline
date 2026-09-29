# Iteration 017 — Models: the two routes, proved on two models

**Status:** in progress
**Started:** 2026-09-29 · **Finished:** —
**Answers:** play-test 6, PT6-5 ("the game still needs all its models"), by the route the user
picked from [the models plan](../plans/models.md): **machines by the generator, led by concept
art; sites and the Reclaimer generated or from kits; proved on two models first.**

## Goal
One machine and one landmark, each made by its route, stand in the game beside the models they
would replace -- the Brute in the garage and on the board, the workshop on the map -- so the
user can judge both routes before the rest of the roster and the map are made.

## Scope
- In:
  - **Concept art first**: an ink-style concept of the Brute and of the workshop, generated with
    an open image model (FLUX.1-schnell, Apache 2.0: its images may be used commercially).
  - **Route A, the Brute**: the generator builds an ink-first Brute from the concept -- a chunkier
    silhouette, big plates, far fewer small parts (an ink line turns a bolt into a speck) -- as
    the same five-slot machine: chassis with its hip-jointed legs, the Rend Saw and Breaker
    Hammer arms, the Slug core. Built into its own folder; the shipped roster is not
    regenerated (CLAUDE.md: the generator no longer reproduces it exactly).
  - **Route C, the workshop**: the concept image turned into a mesh by an open image-to-3D model
    (TRELLIS, MIT licence) through its public demo, then cleaned in Blender by a script --
    decimated to flat, big faces, coloured into our zones, scaled and seated -- and shown on
    the map in place of the kit-built workshop.
  - **The comparison**: the old and new Brute in the garage and on the board; the old and new
    workshop on the map; one sheet for the user.
- Out (deliberately): any other model; changing which model the game loads by default (the
  user decides after seeing the proof).

## Steps
1. Concept images for the Brute and the workshop.
2. Route A: an ink-first build of the Brute's four parts, exported beside the roster; checks.
3. Route C: image-to-3D for the workshop; the Blender clean-up script; export.
4. The game shows the new models when asked (`--models new`), for the comparison shots.
5. The sheet; docs.

## Acceptance criteria
- [ ] The new Brute passes the export contract (`verify_assembly.gd` on its parts) and walks,
  strikes and loses an arm in a fight like the old one.
- [ ] The new workshop sits on its pad on the map, drawn in ink like everything else.
- [ ] A sheet: old/new Brute (garage, board), old/new workshop (map), with the concepts.
- [ ] Every suite passes; the default game is unchanged until the user picks.

## Result

## Decisions, lessons, open questions

## Next
The user picks: then the roster (route A) and the map's sites and the Reclaimer (route C or B).
