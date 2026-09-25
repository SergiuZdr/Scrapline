# Plan — Where the art comes from (sources, skills, and whether they are any good)

**Status:** spike run 2026-09-25 for play-test 4 ("find the best skills to make the assets
from 0 or find good ones on the internet, AND analyse if the work they do is good").
Every verdict below comes from **trying the thing in this project**, not from its reputation.
Probe shots: `shots/probe_sheet.png`, `shots/probe_close.png`,
`shots/probe_quaternius_kenney.png`, `shots/probe_ai_concept.jpg`.

## How each source was judged

`tools/art_probe.gd` renders one fixed vignette — a patch of hex board, a machine, three
props — under the game's own lights, in different dressings:

```bash
$GODOT --path . --resolution 1280x720 --script res://tools/art_probe.gd -- --mode a --out shots/probe_a.png
# a: the game as it is; b: Poly Haven HDRI + PBR + props; c: b under the game's dark sky
# --close frames the machine at portrait distance
```

Same camera, same lights, same machine: the only thing that changes is the source.

## Verdicts

| Source | What it is | Tried | Verdict |
|---|---|---|---|
| **Poly Haven textures** (CC0) | Photographed PBR sets: rusty painted metal, metal plate, asphalt, container siding, corrugated iron, burned ground | Board plates, ground, machine detail maps (triplanar, no UVs needed) | **Adopt.** The single biggest gain per byte: the board and ground stop being flat colour. Must be **tinted and darkened** into the palette, or the ground out-shines the machines (the value rule) |
| **Poly Haven HDRIs** (CC0) | Night skies for light and reflections | `dresden_station_night` as sky light in the Compatibility renderer | **Adopt, for light only** (mode c): real reflections on metal, while the camera still sees the game's dark sky |
| **Poly Haven models** (CC0) | Photoscanned props | Concrete road barrier, old tyre, plastic drum | **Curate.** Neutral props (concrete, tyres, rusted metal) work once darkened; anything saturated (the blue drum) breaks Rust & Sodium and is out |
| **Kenney kits** (CC0) | Clean low-poly kits; City Kit Industrial tried | Factory, water tower, containers rendered | **Shapes yes, look no.** Excellent topology and phone-cheap, but a toy-town palette. Usable as landmarks and a skyline **re-materialed through our zone system** |
| **Quaternius** (CC0) | Low-poly characters and robots | Flying robot enemy | Same toy aesthetic. A candidate silhouette for Reclaimer scout drones on the map, re-materialed. Not usable for our machines: single meshes, no per-part sockets |
| **AI images (free, Pollinations)** | Text-to-image, no key | A concept piece for the briefing | **Rejected.** Ignored most of the prompt (no harvester, no machines), watermarked despite `nologo`, 1024×576 |
| **AI images/3D (paid: FLUX pro, Midjourney, Meshy, Tripo, Rodin, Hunyuan3D)** | Better adherence; 3D generation | Not runnable here: need the user's API keys, or an NVIDIA GPU / Apple Silicon (this is an Intel Mac) | Optional later, only with the user's keys and budget |
| **Our Blender pipeline** (`tools/blender/`) | Procedural machines, terrain, arena kit | In use | **Keep for everything bespoke**: the machines (the per-part socket contract is ours alone), the Reclaimer, UI renders |

## Skills (Claude Code) — found and judged

Searched with the `skill-finder` skill (GitHub code search on `SKILL.md`, the skills
registries):

| Skill | Where | Verdict |
|---|---|---|
| `3d-essentials`, `art-direction-and-readability`, `game-feel-and-juice`, `ui-ux-and-feedback`, `combat-design`, `frontend-design`, `blender-materials`, `blender-lighting`, `blender-modeling-modifiers` | **Already installed** (`~/.claude/skills/`) | **The best available.** Real guides and checklists (e.g. `blender-materials` 500 lines, "the metallic switch"). Used per job: juice for the level-up, UI/UX for the map HUD, readability for texture values |
| `blender-kiln` (MIT, 13★) | elithril/blender-kiln | Well designed (brief → source → cleanup → texture → optimise → export) but **drives Blender through a live MCP connection and generates with Hunyuan3D**, neither of which runs here. Not installed; its cleanup/optimise checklist is borrowed |
| `ai-game-art-pipeline` (MIT, 294★) | ybuild-ai | Sound 2D pipeline (keyframes, chroma key, contact sheets) but provider-neutral: it needs an image model, and the free one failed the test. Not installed |
| `polyhaven-*` (no licence) | kevinbadi/blender-skills | Need the Blender MCP addon on port 9876; no licence. Replaced by `tools/fetch_polyhaven.py`, which calls the public Poly Haven API directly |
| `kenney-asset-kit` (no licence) | SeveralHerr | Careful ("measure the kit, never guess") but unlicensed; our `verify_assembly` already measures real vertices |

**No skill found online beats what is installed.** The gap was never guidance; it was
*supply* — and supply is now `tools/fetch_polyhaven.py` plus the Kenney kits.

## Rules for any third-party asset

- **Record provenance.** Poly Haven assets are listed in `art/thirdparty/polyhaven/SOURCES.md`
  by `tools/fetch_polyhaven.py`; any other source gets the same treatment and its licence
  file beside it, in the same commit.
- **CC0 or equivalent only**, unless the user decides otherwise.
- **Through the palette.** Nothing ships with its own colours: textures are tinted, props are
  re-materialed through `PartMaterials` zones. A beautiful asset in the wrong colours is worse
  than none, because it pulls the eye to the wrong place.
- **1k textures, JPG**, triplanar where the geometry has no UVs. A phone pays for every map.
- **Judge it in the game** (`art_probe.gd`), never from the vendor's preview render.
