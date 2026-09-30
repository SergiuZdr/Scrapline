# Iteration 020 — Models: the sites and the Reclaimer, a few a day

**Status:** in progress
**Started:** 2026-09-30 · **Finished:** —
**Answers:** the user: "do the sites and the reclaimer next"; on the GPU allowance: "stay free,
do one or two a day".

## Goal
Every kind of site on the map, and the Reclaimer, is a TRELLIS model made from its concept
(`art/concepts/<kind>.png`), cleaned with its detail kept -- arriving one or two a day, as the
free Hugging Face allowance permits, with no step that needs the user.

## Scope
- In:
  - Concepts for the eight remaining kinds (camp, skirmish, elite, scrapyard, trader, tower,
    signal, the gate) and the Reclaimer (FLUX.1-schnell; done, in `art/concepts/`).
  - **`tools/gen3d/next_site.sh`**: takes the next kind with no model, runs TRELLIS with the
    token in `~/.cache/huggingface/token`, cleans it (`clean_generated.py --keep-texture`) into
    `art/sites/<kind>.glb`, imports it. Stops cleanly when the day's allowance is spent.
  - The map uses a generated model for ANY kind that has one, the kit for the rest.
  - The Reclaimer's model on the map once it exists.
- Out (deliberately): paying for a bigger allowance; new site kinds.

## Steps
1. The map takes any `art/sites/<kind>.glb`; the script; a first run.
2. One or two kinds a day until all nine exist; a shot of each on the map.
3. The Reclaimer wired in; suites; docs.

## Acceptance criteria
- [ ] `next_site.sh` run with allowance left produces one site end to end, and with none left
  says so and changes nothing.
- [ ] Each kind with a model shows it on the map; kinds without one still show the kit.
- [ ] All nine exist; every suite passes; the user judges them.

## Result

## Decisions, lessons, open questions

## Next
