# Iteration 020 — Models: the sites and the Reclaimer, a few a day

**Status:** done -- waiting for the user's look
**Started:** 2026-09-30 · **Finished:** 2026-10-03
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
- [x] `next_site.sh` run with allowance left produces one site end to end, and with none left
  says so and changes nothing (exit 2, nothing written).
- [x] Each kind with a model shows it on the map; kinds without one still show the kit (the
  030-031 kinds -- warlord, arena, refinery, auction -- borrow a generated model or the kit).
- [x] All nine exist, and the Reclaimer; run_ui and onboarding pass with them on the map.
- [ ] The user judges them.

## Result

Ten models over four days, all from `tools/gen3d/next_site.sh` (sheet: `shots/020_sites_all.png`).

| Kind | Landed | Triangles (from) | Notes |
|---|---|---|---|
| workshop | 2026-09-30 (018, by hand) | 12,000 (63,518) | door turned to the camera |
| trader | 2026-10-01 | 11,999 (43,375) | the user's first run of the script; counter to the camera |
| start (camp) | 2026-10-01 | 12,000 (48,134) | two containers round a fire; the crew stands in its yard |
| skirmish | 2026-10-01 | 12,000 (22,612) | a wreck behind a tyre barricade |
| elite | 2026-10-01 | 12,000 (28,354) | spiked bunker, turret, skull signs |
| scrapyard | 2026-10-01 | 12,000 (24,117) | a heap of pipes and gears under a lattice crane |
| tower | 2026-10-02 | 11,999 (14,237) | the user's run; lattice, cabin, searchlight, 5.2 m tall |
| signal | 2026-10-02 | 12,000 (32,098) | a crashed robot under a radio mast (the first try hung: see below) |
| boss (the gate) | 2026-10-03 | 11,999 (34,284) | third try: the darker concept with our own background mask -- rusted red pylons, red lamps, the shutter, the conveyor, no mound; kept facing the camera (`--no-square`) |
| Reclaimer | 2026-10-02 | 3,500 (33,453) | a dozen copies make its wall: shredders forward (+X), darkened, its red beacons on top |

- **The free allowance is bigger than the plan assumed**: six TRELLIS runs went through on
  2026-10-01 (about 26 s of GPU each). The sixth was refused with "120s requested vs. 166s
  left": a call needs a margin above the 120 s it reserves, so the last ~2-3 minutes of a day's
  allowance cannot be used.
- **The same model on every site of a kind** read as a stamped copy (seven identical wrecks on
  seed 11). Sites without a front (`YardView.FACING_SITES`: the workshop, the trader and the
  camp have one) now turn by their id (215 +- 35 degrees) and vary their size (0.92-1.04).
  A second model per kind (a second concept) is the real fix if it still reads as repeated.
- verify_run_ui 48 and verify_onboarding 39 pass with the generated sites on the map.

### 2026-10-02
- **The Reclaimer is a line of harvesters** (`YardView._build_reclaimer`): the kit's crane rigs
  are replaced by copies of `art/sites/reclaimer.glb`, turned so the shredders face +X (the way
  it advances), jittered in angle and size, textured toon darkened to near black, outlined in the
  Reclaimer's dark red, a red beacon on each. The blade and its red teeth stay as the exact line
  of the front. Cleaned to 3,500 triangles: twelve copies cost 42,000.
- **A step can hang**: TRELLIS's background removal once never sent its result, and the stream's
  heartbeats kept the socket open for ten minutes. `gradio_queue.py` now gives each step
  `STEP_LIMIT` seconds; `next_site.sh` tries that step twice. The retry went through.
- **The raw TRELLIS output is kept** (`tools/gen3d/raw/<kind>.glb`, gitignored): a site can be
  cleaned again for free (the Reclaimer at 3,500, the gate's grey apron, without GPU).
- **The gate went wrong twice.** Its first concept (pale concrete on white) came out white with
  no shutter. A darker concept (`art/concepts/boss.png`: rusted pylons, red lamps, a red shutter,
  a conveyor) came out right above and grew a white mound out of the slab below -- TRELLIS's
  background removal had kept part of the white floor. Deleting the white faces left holes the
  ink line showed through; recolouring them dark concrete (`clean_generated.py --grey-white`)
  turned the mound into an apron, which still hides half the shutter. **Fix for tomorrow**:
  `tools/gen3d/cut_background.py` cuts the concept's background ourselves (flood fill from the
  corners) and `next_site.sh` uploads the cut image, whose alpha TRELLIS uses as the mask.
- The day's allowance: the user's run plus four (signal, gate, Reclaimer, gate again); the sixth
  was refused at 177 s left.

### 2026-10-03
- **The allowance is a rolling 24 hours, not a daily reset.** The user's morning run and my
  retries at 11:37, 11:57 and 16:13 all got "177s left"; at 16:33 -- 24 hours after the first of
  the previous day's runs -- the gate went through. A free account seems to hold about 300 s and a
  call needs about 1.5 times the 120 s it reserves (refused at 166 and 177 s left), so four or
  five runs a day, the next day's starting when the first of today's ages out.
- A background retry loop is cut off after 30 minutes; a scheduled check in the session
  (CronCreate, every 20 minutes from 16:13) is what caught the window.
- **Our own mask worked**: with `cut_background.py`'s cut-out uploaded, the gate came back with no
  mound and nothing white (`--grey-white` greyed 0%).
- **Squaring broke the gate's facing**: the clean-up turned it 51 degrees to square a near-square
  footprint, and the map's 215-degree facing then showed the lintel end-on. A TRELLIS model faces
  the way its concept was drawn, so the sites that face the camera now skip squaring
  (`clean_generated.py --no-square`, passed by `next_site.sh` for the workshop, trader, camp and
  gate); re-cleaned from the kept raw file, no GPU spent.

## Decisions, lessons, open questions
- **Every site and the Reclaimer are TRELLIS models** made from concepts, cleaned with their detail
  and texture kept; the Reclaimer's wall is a line of harvesters.
- **Upload our own mask** (`cut_background.py`); keep the raw output (`tools/gen3d/raw/`, gitignored);
  sites with a front keep TRELLIS's facing (`--no-square`).
- Lesson: a free ZeroGPU allowance is a rolling 24 hours; a refused call costs nothing, so retry
  on a schedule rather than by hand.
- Lesson: a pale concept on a white background loses to the background removal (the first gate).
  Concepts for TRELLIS should be dark or saturated against white.
- Open: the user's verdict on the ten models; a second model per kind if the map still reads as
  stamped; models for the 030-031 kinds (warlord, arena, refinery, auction) and Acts 2-3's gates.

## Next
The user looks at the map. More concepts the same way when wanted -- each costs one run.
