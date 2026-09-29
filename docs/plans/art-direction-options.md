# Plan — Art direction: three options to pick from

**Status:** **A, Ink & Rust, picked by the user on 2026-09-29.** Its style frame was built in
[015](../iterations/015-ink-style-frame.md), in the real combat scene; the rest of the game
follows once the user approves the frame. The options below are kept as proposed. Nothing
here changes a rule. Whichever is picked replaces the look of [art-and-audio](art-and-audio.md)
(010) but keeps its **read contracts** and a **one-meaning-per-colour registry**.

## Why the current look fails

- **It aims at realism.** Photographed PBR (Poly Haven), metallic machines and an HDRI sky are
  the language of a photoreal engine demo. Realism is exactly where procedural box geometry
  looks cheapest: every bevelled box is measured against a real machine and loses.
- **One murk.** Rust textures under a sodium key put board, props and machines in one
  brown-orange band. Contrast was measured and passed, but nothing has a *style* to be read in.
- **Placeholder objects.** Sites are arena props at small scale; the Reclaimer is gantries with
  red balls; drums are cylinders; heaps are corrugated boxes; pylons are hex columns. Each is a
  primitive standing in for a thing that was never designed.
- **Generic panels.** Dark flat rectangles, a thin border, one font: the default of every
  generated dashboard.

## The moments that must read (ranked)

Every option below is judged first on these, in this order. Mechanics are unchanged.

| # | Moment | The question on screen |
|---|---|---|
| 1 | Start of a turn | What will hit me, where, in what order, how hard? (intent hexes, badges, locked shots, a pad or a Reclaimer arrival due) |
| 2 | Any glance at a unit | Whose is it, what is it, how hurt, what state? (team, role silhouette, HP, heat/seized, marked, shield, anchored, carrier) |
| 3 | Picking a machine | Where can it go, what does the ground cost, where is it dangerous? (range, rubble/ridge cost, slag, pits, the path) |
| 4 | Aiming | What exactly will this do? (target, line and what stops it, pierce/chain/splash reach, shove direction and what is behind, kill/tear/overheat) |
| 5 | Reading the yard | What can I use? (drums and their blast, crates and heaps that block, pits that kill, ridges, pylons and their links, piles to take) |
| 6 | Resolution | What just happened? (hits, kills, tears, explosions, bumps, pickups) |
| 7 | The map | What is each site, where can I go, where does the Reclaimer take next, what is still fogged? |
| 8 | The garage | Which part is where on the machine, and what do sets, perks and tuning add? |

Moments 1, 3 and 4 decide fights; they get the highest contrast in every option.

---

## Option A — INK & RUST (comic noir)

**Pitch.** The yard drawn as a graphic novel: flat colour, heavy black ink, hard light. Boxy
machines look *drawn on purpose* instead of modelled cheaply.

**References.** Mike Mignola's *Hellboy* (black shadow shapes), Moebius (clean line, flat
colour), *Hi-Fi Rush* and *Sable* (cel shading in motion), *Into the Breach* (clarity).

**Palette.** Ink `#14110F` · paper `#EFE3C8` · rust `#B4532A` · mustard `#D9A441` ·
oxide `#9C3B2E` · olive `#6E7443` · steel `#7D8A8F` · night `#1B2233` · board `#2A2B2E`.
Signals: yours `#33C8E0`, danger `#FF3B30`, your action `#FFC43D`, gain `#8EDB4A`,
being built `#A070E0`.

**Shapes.** Exaggerated silhouettes: chunkier shoulders, bigger feet, thicker plates. Terrain as
a few big graphic shapes rather than photo noise: a heap is three angular slabs, rubble is a
scatter of small outlined stones.

**Materials.** No PBR. A three-band toon ramp (lit / mid / ink shadow), one hard highlight
stripe on metal, black ink outlines on everything (inverted hull, constant screen width).
Wear is *drawn*: black chips and rust shapes, not a photograph. Halftone dots in the shadow
band.

**Lighting.** One strong key (a floodlight, the moon) throwing long hard shadows; flat dark-blue
ambient. No bloom except on signals.

**UI.** Comic panels: 3 px ink borders, cream paper cards with halftone shading, hard offset
shadows (no blur), headings in a heavy condensed face, narration boxes for the coach and hints,
speech-bubble callouts that point at the thing they explain. Big lettered sound effects on
impacts (KRANG, BOOM) — used only for the events that matter.

**How interactables stand out.** Everything has a line; interactables get a thicker line and an
inner colour line when relevant (aimed at: amber; threatened: red). Heaps are solid black masses
(obviously impassable). Rubble is stippled with outlined stones (obviously rough). Pits are pure
black with a jagged pale rim. Drums: red, hazard chevrons, a flame glyph, and a dashed blast ring
when aimed. Piles: green bolts with a white glint. Pylons: black with red lightning bands.

**Map.** An establishing shot: ink-wash ground, roads as bold strokes, sites as big outlined
landmarks. **Unexplored ground is unfinished drawing** — pencil sketch lines that get inked when
scouted (fog that means something). The Reclaimer: a colossal black silhouette with red
searchlights and heavy hatching; its next line a red slash across the paper.

**Build cost here.** Low-medium. A toon ShaderMaterial replaces `PartMaterials`/`Surfaces`; an
outline `next_pass` on every mesh; generated halftone and paper textures; new UIKit styleboxes
and one display face (OFL). Works on the Compatibility renderer and on phones. The generator
keeps its geometry (a pass to chunk silhouettes up helps).

**Risks.** Inconsistent line weight or hatching looks cheap fast: it needs written rules (one
world line weight, one for silhouettes). Thin rods can blob under outlines.

---

## Option B — PAINTED MINIATURES (tabletop diorama)

**Pitch.** Every machine a hand-painted miniature on a base, the board a sculpted terrain tile
under a hobby lamp. The game looks like the best-painted wargame table you have seen.

**References.** Games Workshop's *Necromunda* and *Kill Team* terrain and paint schemes,
*Warhammer Underworlds* boards, *Bad North* for the floating diorama.

**Palette.** Brass `#B08D57` · bone `#E6D8B8` · gunmetal `#4A4F57` · rust `#A4461F` ·
oxidised teal `#3B7A70` · mustard `#C9A227` · blood `#8E2A21` · base earth `#6B5A45` ·
drybrushed earth `#8C7A62`. Team: base rims yours `#2FA8D8`, enemy `#D8432F`.

**Shapes.** Heroic scale: slightly big heads and weapons, deep panel lines, rivets. **Every unit
stands on a round base** whose rim carries the team (like a miniature). Terrain is modular
sculpted pieces with painted sides; the board floats as a diorama.

**Materials.** Matte paint: base colour, darker wash in the recesses, **drybrushed light edges**
(edge highlight from a per-vertex convexity value the generator bakes), satin "metallic paint"
instead of mirror metal, small painted chips.

**Lighting.** A warm hobby-lamp key and soft fill; soft shadows; a gentle tilt-shift blur at the
top and bottom of the screen to sell the scale.

**UI.** Physical game components: cardstock unit cards with rounded corners and a printed frame,
status as round tokens (heat, marked, shield), damage as dice-style numbers, the glossary as a
rulebook page, the turn as a track with a marker. Cards cast soft shadows as if on the table.

**How interactables stand out.** Interactables are tokens: bright enamel rims and bases. Drums
painted hazard yellow with red bands and a flame decal; heaps tall and sculpted; rubble low and
gritty; pits deep with a dark wash; piles as glinting gear heaps with a green gem token. Move
range as glowing blue gel on the terrain; targets as amber rings.

**Map.** A painted campaign board on the table: sites as miniature buildings on bases, fog as a
cloth laid over the unexplored tiles, the crew as three miniatures, the Reclaimer a huge
miniature at the board edge with red lights.

**Build cost here.** High. The drybrush and wash need baked per-vertex data from the generator;
bases and extra sculpt detail on every part; the tilt-shift blur is a custom screen shader (the
Compatibility renderer has no depth of field) and costs on phones.

**Risks.** The most asset detail of the three, and miniatures without real detail look like
toys. The tabletop framing can soften the grim story.

---

## Option C — SCHEMATIC LOW-POLY (clean faceted diorama)

**Pitch.** Crisp faceted shapes, no textures, a muted world where only the things you act on
glow. Calm, legible, elegant, and cheap to render.

**References.** *Bad North* (muted world, bright units), *Into the Breach* (clarity),
*Townscaper* (light), *Mini Metro* (UI restraint), technical drawings for the interface.

**Palette.** Sky `#22304A` to `#E3A36B` (dusk). Ground in four steps `#34383F`, `#43484F`,
`#565B61`, `#6E7278`. Machines: safety yellow `#F2B632`, signal orange `#E8612C`, teal
`#2F8F9D`, off-white `#E8E4DA`, graphite `#2C2F33`. Signals: yours `#4CC3FF`, danger `#FF4D4D`,
your action `#FFD23F`, gain `#7BE08A`, being built `#B48CFF`.

**Shapes.** Simplified faceted geometry with crisp bevels and bold colour blocking (livery panels
against dark mechanism). Heaps as stacked angular slabs, rubble as low wedges, drums as hex
prisms.

**Materials.** One flat colour per zone per face (faceted normals), no texture at all, soft
vertex ambient occlusion, emission only on signals.

**Lighting.** A low dusk sun with soft shadows and a sky-gradient ambient; fog toward the
horizon; bloom only on signals.

**UI.** Technical schematic: panels built from 1 px rules and corner ticks, **leader lines from
the interface to the object they describe**, tabular numerals, small-caps labels, icons first.
Colour only for signals.

**How interactables stand out.** They are the only saturated, faintly glowing things in a grey
world. Hover draws a 2 px white outline; the board grid is fine light lines; the chosen hex
fills solid.

**Map.** A clean isometric diorama with a distinct geometric landmark per site type; fog as a
hex-pattern dissolve; the Reclaimer a vast dark wedge with a glowing orange cutting line.

**Build cost here.** Lowest. A faceted-normal shader, vertex AO, gradient sky and fog; a UI
redesign built on rules and leader lines.

**Risks.** The easiest to make generic ("a low-poly asset pack"), and a flat UI done without
real structure would repeat PT5-3.

---

## Side by side

| | A · Ink & Rust | B · Painted Miniatures | C · Schematic Low-Poly |
|---|---|---|---|
| Readability at 40 px | Excellent (outlines separate everything) | Good (bases carry team) | Excellent (muted world, bright signals) |
| Identity | Strong, uncommon in tactics games | Strong, familiar to wargamers | Medium, crowded style |
| Fit with procedural box geometry | Best: boxes look drawn on purpose | Weakest: minis need sculpted detail | Good: boxes look designed |
| Fit with the story (night, a machine eating the valley) | Best (noir) | Softer (tabletop) | Neutral |
| Phones / Compatibility renderer | Good | Heaviest | Best |
| Work to reach finished | Medium | High | Low-medium |
| Main risk | Line-weight discipline | Looking like toys | Looking generic |

## Recommendation

**Prototype A, Ink & Rust, first.** It answers all three complaints at once: it is the furthest
from glossy realism (PT5-1), it makes our generated machines and props look authored rather than
placeholder (PT5-2), and it gives every panel a real identity (PT5-3). It also suits the story
best, and its main risk -- inconsistent lines -- is a rule we can write down and test.

### The one scene to prototype: "the decision moment"

One frame that contains every read from the table above, in-engine, at 1920x1080 and at phone
size:

- a 5 x 5 corner of a real board: open ground, one **rubble** hex, one **scrap heap**, one **fuel
  drum**, one **pit**, one **scrap pile**;
- the **Brute** selected (move range shown, one rubble hex costing 2), its **Rend Saw armed and
  aimed** at an enemy Reaper standing beside the drum -- the preview showing the kill, the shove
  throwing the wreck into the drum, and the drum's blast;
- the Reaper's **red intent** on the Hauler; a **carrier** mark on one enemy;
- the HUD pieces the moment needs: the selected machine's card and the weapon/ability bar, and
  one coach callout.

**It passes if:** a grayscale copy still answers moments 1-5; the frame reads at phone size;
the machines hold the peak contrast; and the user looks at it and wants the rest of the game
to look like that. If it fails, it has cost one scene, not the whole game.

**After that, in order:** the board and every battlefield object; the machines (generator pass
for silhouettes); the map, its site landmarks and the Reclaimer; the UI kit and every panel;
the garage and the title.
