# Iteration 015 — Ink & Rust: the style frame

**Status:** in progress
**Started:** 2026-09-29 · **Finished:** —
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
- [ ] verify_combat: a machine whose cheapest routes include one over a pile takes it and the
  pile; the route never costs more than the cheapest; enemies do the same; dry runs still equal
  execution.
- [ ] run_bot 150 recorded (target 85-92%), 0 illegal actions; balance_fights recorded.
- [ ] The frame (`shots/015_frame.png`) and its phone-size and grayscale copies answer, without
  colour and at phone size: what will hit me and in what order; whose each machine is and how
  hurt; where the Brute can go and what the ground costs; what the aimed hit will do (kill,
  wreck into the drum, blast); what on the yard can be used.
- [ ] `measure_contrast.gd`: the machines stand out from their surroundings at least as much as
  after 010 (2.1-2.3).
- [ ] Every suite passes (the HUD is rebuilt, so the UI and onboarding tests matter).
- [ ] The user looks at the frame and decides whether the rest of the game should look like it.

## Result

## Decisions, lessons, open questions

## Next
If the user approves the frame: Ink & Rust everywhere (016) -- the map and the Reclaimer, every
panel through the UI kit, the garage and the title, and the generator's silhouette pass.
