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

_(in progress -- a site lands whenever `tools/gen3d/next_site.sh` finds allowance)_

| Kind | Landed | Triangles (from) | Notes |
|---|---|---|---|
| workshop | 2026-09-30 (018, by hand) | 12,000 (63,518) | door turned to the camera |
| trader | 2026-10-01 | 11,999 (43,375) | the user's first run of the script; counter to the camera |
| start (camp) | 2026-10-01 | 12,000 (48,134) | two containers round a fire; the crew stands in its yard |
| skirmish | 2026-10-01 | 12,000 (22,612) | a wreck behind a tyre barricade |
| elite | 2026-10-01 | 12,000 (28,354) | spiked bunker, turret, skull signs |
| scrapyard | 2026-10-01 | 12,000 (24,117) | a heap of pipes and gears under a lattice crane |
| tower, signal, boss, Reclaimer | -- | | the sixth run of 2026-10-01 was refused |

- **The free allowance is bigger than the plan assumed**: six TRELLIS runs went through on
  2026-10-01 (about 26 s of GPU each). The sixth was refused with "120s requested vs. 166s
  left": a call needs a margin above the 120 s it reserves, so the last ~2-3 minutes of a day's
  allowance cannot be used.
- **The same model on every site of a kind** read as a stamped copy (seven identical wrecks on
  seed 11). Sites without a front (`YardView.FACING_SITES`: the workshop, the trader and the
  camp have one) now turn by their id (215 +- 35 degrees) and vary their size (0.92-1.04).
  A second model per kind (a second concept) is the real fix if it still reads as repeated.
- verify_run_ui 48 and verify_onboarding 39 pass with the generated sites on the map.

## Decisions, lessons, open questions

## Next
