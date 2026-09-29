# Iteration 015 — Ink & Rust: the style frame

**Status:** done -- the frame waits for the user's verdict
**Started:** 2026-09-29 · **Finished:** 2026-09-29
**Answers:** the user's pick of [art direction A, Ink & Rust](../plans/art-direction-options.md)
(play-test 5, PT5-1 to PT5-3), and their correction of PT5-5: the "scrap on the ground" was
the **scrap piles** dropped by wrecked machines, not rubble.

## Goal
The fight draws as a graphic novel -- flat colour, ink lines, one hard light, comic panels --
and one composed frame, "the decision moment", shows every read a fight needs in that style,
for the user to judge before the look touches any other screen. And a machine walking past a
scrap pile takes the route through it.

## Scope
- In:
  - **Scrap on the way (PT5-5).** Every pile a machine walks over is already picked up (since
    play-test 3), but among equally cheap routes the one taken was the first found, so a
    machine walked round a pile as often as through it. Now, among the cheapest routes, the
    one that picks up the most scrap wins, then the one with fewer hexes. No detours: the
    move's cost and reach are unchanged, only which of the equal routes is walked. Both
    teams (one rule).
  - **The look, in the combat scene**, built into the real renderer so the frame is a
    screenshot of the game and not a mock-up:
    - `Ink` (presentation): the palette, a toon material (three bands -- lit, mid, ink
      shadow -- with halftone dots between mid and shadow and one hard highlight stripe on
      metal), an ink outline (inverted hull at a constant screen width, over smoothed
      normals so box corners do not crack), and a mark material (hatching and a border) for
      the board's overlays.
    - Light: one hard key with long shadows over a flat night ambient. No HDRI, no fog, glow
      only on signals.
    - Board: flat tiles with ink joints; rubble stippled with outlined stones; heaps as black
      masses edged in paper; pits black with a jagged paper rim; slag, ridges, the curb.
    - Props and piles: drums red with hazard chevrons and a flame glyph, crates, pylons black
      with red bands, piles as green bolts with a glint.
    - Machines: their zones through the toon material, with outlines. No geometry change
      (the silhouette pass is later).
    - Overlays: move hexes hatched in your blue with a border (slow ground fainter), threats
      hatched red, targets amber, a drum's blast ring dashed; lettered sound effects on the
      impacts that matter.
    - HUD: comic panels -- paper cards, 3 px ink borders, hard offset shadows, a heavy
      condensed display face (Anton), lettering (Bangers), the coach as a narration box.
  - **The frame**: an authored fight (`data/fights/style_frame.json`) staging the moment in
    the plan -- the Brute selected with its hammer aimed at a Reaper beside a drum (the kill,
    the wreck thrown into the drum, the blast), rubble, a heap, a pit, a pile, the Reaper's
    red intent on the Hauler, a carrier mark -- captured before and after, at 1920x1080 and at
    phone size, with a grayscale copy.
- Out (deliberately): the map, the Reclaimer, the garage, the title and every other screen's
  panels (they follow once the user approves the frame); chunkier machine silhouettes (a
  generator pass); new animation; audio.

## Steps
1. Sim: scrap on the way; tests; run bot.
2. The frame's fight, and its "before" shot in the current look.
3. `Ink`: toon, outline and mark shaders, palette; light and background.
4. Board, terrain, props, piles.
5. Machines.
6. Overlays, tags, lettering.
7. HUD: fonts, comic panels, the coach's narration box.
8. The frame at both sizes, grayscale, contrast measured; every suite; docs.

## Acceptance criteria
- [x] verify_combat: a machine whose cheapest routes include one over a pile takes it and the
  pile; the route never costs more than the cheapest; enemies do the same; dry runs still equal
  execution.
- [x] run_bot 150 recorded (target 85-92%), 0 illegal actions; balance_fights recorded.
- [x] The frame (`shots/015_frame_aim.png`, `015_frame_move.png`) and its phone-size and grey
  copies answer, without colour and at phone size: what will hit me and in what order; whose
  each machine is and how hurt; where the Brute can go and what the ground costs; what the aimed
  hit will do (kill, wreck into the drum, blast); what on the yard can be used.
- [x] `measure_contrast.gd`: the machines stand out from their surroundings more than in the old
  look, on every fight measured (same ruler for both, see below).
- [x] Every suite passes (the HUD is rebuilt, so the UI and onboarding tests matter).
- [ ] The user looks at the frame and decides whether the rest of the game should look like it.

## Result

| Suite | Result |
|---|---|
| verify_combat | **183** passed (175): two equally short routes, each with the pile on it, walked over the pile both ways round; the pile taken; no detour for a pile off the cheapest route; an enemy's route the same |
| verify_combat_input / run / run_ui / onboarding | 22 / 127 / 48 / 39 passed (the fight driven by clicks on the new HUD; the coach restyled) |
| verify_save / assembly / animation | 15 / 100 / 34 passed |

**Scrap on the way**: run bot **86.7%** won, 0 illegal actions, 5.0 fights won a run, crew HP
into the gate 28.5 (28.4 before) -- the same as 014, as a tie-break should be. balance_fights:
every authored fight exactly as in 014; random squads **95.3%** (95.3%), 3.6 rounds a fight (3.7), the arms exactly as in 014 (scanner -1.5 to scattergun +1.8).

**The look.** Everything in the fight is drawn in ink: `Ink` (palette, toon and ink materials,
dressing by zone), three shaders, `InkBox` (comic panels), Anton and Bangers (SIL OFL 1.1, in
`art/fonts/` with their licences). The frame is a staged fight outside the content
(`tools/frames/decision.json`, `combat.tscn -- --fight-file`), photographed by
`shot_combat.gd --steps`:

| Shot | What it shows |
|---|---|
| `015_frame_move.png` | The Brute picked: its reach hatched in your blue, the rubble hex's fainter hatch and broken border (it costs 2), the route to a hex past the scrap pile drawn over it, the enemies' order badges, red-hatched hexes where they will hit |
| `015_frame_aim.png` | The Breaker Hammer armed (amber, heavy line) and aimed at the Reaper: its hex cross-hatched, an arrow where the wreck is thrown, the drum's blast dashed over every hex it reaches, and the panel: Reaper destroyed, runner destroyed, drum explodes |
| `015_frame_hit_78.png` | The hit resolving: KRANG! as the wreck slams into the drum, BOOM! above it |
| `015_frame_*_grey.png`, `015_frame_phone_small.png`, `015_coach.png` | The checks; the shakedown's coach as the narrator |
| `015_before_after.png`, `015_checks.png` | The sheets the user judges |

**Contrast** (`measure_contrast.gd`, machines' mean luminance over the ring around them). The
tool now hides labels in both renders (below); the old look was measured again with it, from
`main`, so both columns use one ruler:

| Fight | Old look (014) | Ink & Rust |
|---|---|---|
| slag_pit | 0.293 / 0.139 = **2.11** | 0.350 / 0.139 = **2.51** |
| proto_yard | 0.252 / 0.139 = **1.81** | 0.318 / 0.161 = **1.97** |
| container_row | 0.274 / 0.139 = **1.97** | 0.329 / 0.164 = **2.00** |

The margins grew more (0.154 -> 0.211, 0.113 -> 0.157, 0.135 -> 0.165): the machines are
brighter, and the ink line separates them besides.

### Found on the way
- **Lit from behind, every machine showed the camera its shadow band.** The first frame kept
  the old key's direction; the key comes from the camera's left now.
- **Grey limbs**: the scrap bridge makes head, arms and legs `metal`, so in flat colour every
  machine was the same grey figure with a painted chest. Structure wears its part's livery, a
  shade darker.
- **The first measure fell** (1.55 / 1.23 on slag_pit / proto_yard). Part was real -- a lighter
  board, darker machines, glowing rings: fixed by a darker board, lighter structure, a lighter mid
  band and flat rings. Part was the ruler: the tool hid marks but not the machines' TAGS, and the
  new tags are big paper lettering, so they counted as bright surroundings. Labels are hidden in
  both renders now, and the old look was re-measured with the same tool before comparing.
- **The grey copy failed three reads**: a move hex and a threatened hex differed only by hue
  (hatching directions now carry the meaning), whose machine is differed only by ring hue (the
  enemy's ring is a saw blade), and the armed weapon's amber card barely differed from paper (a
  heavy line).
- **KRANG! and BOOM! overprinted** into one word when a wreck hits a drum. Stacked now.
- Pre-existing: the WEAPONS row's caption sat under the camera buttons (hidden since 009).
- A red container in the scenery read as danger: scenery carries no hue now.

### Different from the plan
- **Two shots of one moment, not one**: the fight shows the move range only while no weapon is
  armed, so "where the Brute can go" and "what the hammer will do" cannot share one frame
  without changing the rules of the interface. Both are the same turn.
- **The frame lives in `tools/frames/`**, not `data/fights/`: every file there joins the run's
  map pool and the content hash.
- The weapon cards still show the old PBR thumbnails, and hit sparks are the old particles; both
  go with the rest of the game.
- At phone size the board and every signal read, but the cards' small print does not: that is
  the HUD hierarchy work (R5-2) planned for the rollout.

## Decisions, lessons, open questions
- **Ink & Rust is the fight's look**; the rest follows the user's verdict on the frame.
- **Dress after building**: `ConstructView`/`PartMaterials` untouched, the look applied by zone
  afterwards -- the other screens keep working while they wait.
- **Three line weights**; **meaning in the hatching**; **the enemy's ring is a saw blade**.
- **The scrap tie-break**: of equally cheap routes, the one over the most scrap.
- Lesson: **a grey copy finds what a colour screenshot hides** -- three of the frame's reads
  were colour alone.
- Lesson: **re-measure the baseline with the new ruler** before comparing. Changing a tool and
  comparing to numbers the old tool produced compares two tools.

## Next
If the user approves the frame: Ink & Rust everywhere (016) -- the map and the Reclaimer, every
panel through the UI kit (with the HUD hierarchy of R5-2), the garage and the title, part
thumbnails and hit effects redrawn, and the generator's silhouette pass.
