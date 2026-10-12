# Plan — Tech architecture

**Status:** draft (Iteration 000).

Engine: **Godot 4.6, GDScript, Compatibility renderer** (unchanged, because it runs on
low-end Android).

## Layout (target after Iteration 004)

| Path | What lives there |
|---|---|
| `sim/` | Pure logic: grid combat rules. Same hard rules as before: `RefCounted`, `SimRNG`, integer math, fixed iteration order, no engine APIs |
| `sim/combat/` | **Built in 002:** `CombatSetup`, `CombatState`, `CombatSim`, `IntentAI`, `CombatBot`, `GridUnit`, `GridEv` |
| `sim/run/` | **Built in 004:** `RunSetup`, `RunState`, `RunSim` (region, front, sites, fights by replay, rewards, refit), `RunBot` |
| `scripts/run/` | `run_map_screen.gd` (map and site panels), `run_store.gd` (the save) |
| `sim/ai/` | intent selection (adapted doctrine rules) |
| `data/` | all content and tunables as JSON |
| `scripts/presentation/` | reads events, animates. Computes nothing |
| `scripts/ui/` | screens, ui_kit |
| `scripts/profile/` | meta profile (unlocks), commands, save |
| `tools/` | headless tests, run-bot, balance sim, art tools |

## Why determinism still matters (no server any more)

- **Undo** = replay from the start of the turn. One code path, no inverse operations.
- **Save mid-fight** = store the seed plus the action list, not a snapshot of every object.
- **Bug reports** = a seed plus actions reproduces any crash exactly.
- **Balance** = a headless bot plays thousands of runs overnight.
- **Shareable seeds** and an offline daily challenge come for free.

## Event stream

The combat sim returns a typed event list (`MOVED`, `ATTACKED`, `DAMAGED`, `PART_DAMAGED`,
`PART_TORN`, `SHOVED`, `HEAT`, `SEIZED`, `DESTROYED`, `INTENT_SET`…). Presentation plays
them. The old `event_stream.gd`/`events.gd` pattern is kept and the vocabulary changes.

## Save

- `user://profile.json`: meta profile (unlocks, settings, history), written through
  commands.
- `user://run.json` (**built**): `{version, seed, content, actions, fight}`. Rebuilt by
  replaying `actions`; `fight` is the in-progress fight's combat actions. Written atomically
  after every action. A content-hash mismatch refuses to resume, with a message.

## Tests (lean, only where they pay off)

| Test | Guards |
|---|---|
| `verify_combat.gd` | **built**: rules, determinism hash, prefix-stable undo, bot fight to the end |
| `verify_combat_input.gd` | **built**: the fight driven by synthetic clicks and keys |
| `verify_run.gd` | **built** (42): region invariants, every rule, determinism, save round trip |
| `verify_run_ui.gd` | **built** (12): the run through its screens, including quit and resume mid-fight |
| `verify_save.gd` | save → quit → load mid-fight equals continuing |
| `run_bot.gd` | **built**: a bot plays N full runs; reports win rate, loss causes and columns, fights per run. **The equivalent of the old `verify_loop.gd`** |
| `verify_assembly.gd` | kept: art export contract |
| `verify_animation.gd` | kept: rig behaviour |
| `check.sh` | **built** (070): every suite above in parallel, one line each; `--bot N`, `--fingerprint` |
| `sim_fingerprint.gd` | **built** (070): how the bot plays every fight file and four runs, hashed -- unchanged by any change meant only for speed |
| `profile_bot.gd` | **built** (070): a bot fight's time by phase, and the AI's hottest calls |

Their rates carry 95% intervals and `--b path=json` compares a variant on the same seeds or fights
(071, `tools/stats.gd`). Bot tools (`run_bot`, `balance_fights`, `sim_fingerprint`) take `--jobs N` and split themselves over
child processes (`tools/jobs.gd`); the default is one per core but one.

## Build targets

- Desktop: macOS and Windows (Steam later).
- Android: Compatibility renderer, test on a low-end device before 009.

## What a frame costs (040)

Measure with `tools/measure_draws.gd` (draw calls, objects, triangles; `--classes`, `--census`)
and a stack `sample` of the running game. Rules since 040: labels, sprites and particles cast no
shadows (the `Juice` watcher); a machine casts its shadow from its frame alone
(`Ink.frame_shadow_only`); static board pieces are merged per material (`Ink.merge_static`); 60 fps
cap, 12 in the background. The ink line's hull mesh has no LODs: dense imported models pay full
price twice.

## Appendix: showing screenshots from an agent

Moved here from the agent notes on 2026-10-12.

A screenshot written to disk and merely *mentioned* in the terminal is invisible.
Whether it can be shown inline depends entirely on the terminal emulator:

| Terminal | Inline images |
|---|---|
| **Apple Terminal** | none, ever — no protocol exists for it |
| **iTerm2** | yes, via `imgcat` (OSC 1337). Installed at `/usr/local/bin/imgcat` |

**Use `tools/show.sh`, which picks the right one.** It runs `imgcat` under iTerm2
and falls back to `open` (Preview) everywhere else, so no call site has to know.

**An agent cannot draw inline at all, and the failure is silent.** A command run
by an agent inherits `TERM_PROGRAM=iTerm.app` while its stdout is a capture pipe,
and the process has no controlling terminal: `tty` prints "not a tty" and
`/dev/tty` fails to open with "device not configured". Choosing `imgcat` on the
strength of `TERM_PROGRAM` alone therefore writes 600 KB of OSC 1337 into the
transcript and **nothing reaches the screen** — and `imgcat` exits 0, so it looks
like it worked.

The obvious repair does not work either, and it is worth recording so nobody
spends another hour on it. The terminal does exist — it belongs to an ancestor
process, `ps -o tty=` finds it (`ttys004`), and the device is writable because the
same user owns it. **Writing there still shows nothing**, because Claude Code's TUI
repaints over the region. Measured with a plain-text marker, not just an image:
the `write()` succeeds and the bytes never appear, scrollback included.

**A successful write is not a visible one.** Both dead ends above report success.
The only way to know an image was seen is that a human says so.

So `show.sh` draws inline only when stdout genuinely *is* a terminal — i.e. a human
typed it — and otherwise calls `open`, which needs no terminal and works from
anywhere.

**`open` puts the window BEHIND the terminal, and that looks identical to nothing
happening.** Three images sat in Preview windows under iTerm2 across several
exchanges while the answer being given was "I can't see it". `open` returns 0 and
does not reliably take focus, so `show.sh` follows it with
`osascript -e 'tell application "Preview" to activate'`. To check what is actually
open rather than guessing, ask Preview — `osascript -e 'tell application "Preview"
to get name of every window'`. Note `pgrep -x Preview` answers NO even while it is
running with windows open, so it is not a usable test.

The `SendUserFile` file card is **not** a second route here: it renders as an inert
filename that does nothing when clicked. Preview is the only thing that works from
a tool call, which makes composing a sheet before showing mandatory rather than
merely tidy — one window per batch, not one per file.

```bash
$GODOT --path . --resolution 1920x1080 -- --shot shots/title.png --after 30
./tools/show.sh shots/title.png
```

Two standing rules:

1. **Write shots to `shots/`, never `/tmp`.** `/tmp` is cleared on reboot and is
   awkward to reach from Finder. `shots/` is gitignored and sits in the project,
   so an old shot can still be compared against a new one.
2. **Also hand the file over with the `SendUserFile` tool.** `show.sh` puts the
   image in front of the player now; the file card is what survives in the
   transcript, and it is the only route that does not depend on the terminal.

**Compose a sheet before showing, never show eight files.** `compose_sheet.py`
already exists for this — eight `open` calls is eight Preview windows to close.

```bash
$GODOT --path . res://tools/gait_preview.tscn --resolution 560x560 -- \
    --shot shots/gait --frames 8 --every 6
python3 tools/blender/compose_sheet.py shots/gait shots/gait.png 8
./tools/show.sh shots/gait.png
```

## Appendix: per-iteration code notes (011-071)

Moved here from the agent notes on 2026-10-12, verbatim: where each system lives in the code. The agent notes keep only the gotchas.

**A run is one list of actions, and a fight is reported as its own action list.**
`RunSim` replays the fight through `CombatSim` to learn the result. That list IS the save
(`user://run.json`, written by `RunStore` after every action), so the save cannot
disagree with the game, and the run cannot be told it won a fight it did not win.
`Run.fight_actions` holds a fight in progress, which is how CONTINUE resumes mid-fight.

**JSON has no integers.** `RunStore.decode` turns every number back into an int, because
an action that comes back holding floats is a different action.

**A content-hash mismatch refuses to resume** (`Run.problem`). A run replayed against
changed rules is a different run, and silently becoming one is worse than saying so.

**The map is a 3D yard** (`scripts/run/yard_view.gd`, a Node3D under the map Control;
the UI draws over it). `YardView.build(state, columns, every, db)` -- it is handed the
ContentDB and must never read the `Run` autoload, because `--script` tools that name the
class compile it before autoloads exist. The camera FOLLOWS the crew (three real machines
standing on the site, walking the road on travel: `travel()` is awaited, so the site's
panel opens on arrival); drag/keys/wheel pan and zoom, C recentres. **Fog of war** is a
CPU-painted mask (`_update_fog`, repainted only when what is scouted changes) read by
`scripts/presentation/fog_of_war.gdshader`; roads and junk deep in fog are hidden
outright. The Reclaimer is a gauge in the top bar (pips) plus a ghost wall on its next
line -- never a sentence. ONE click travels (`_choose`); a left-drag pans instead. Labels
are Controls placed each frame at `label_pos`; picking is in SCREEN space and ignores
fogged sites. Tests click with real mouse events and **wait on timers, not frames**, for
anything tweened (headless frames outrun real time).

A run starts: briefing (`Run.briefed`) -> **assembly bay** (`scripts/run/assembly_panel.gd`,
`Run.bay_seen`; one `RunSim.ASSEMBLE`, legal only before the first move, from the bench in
`run.json` `assembly`) -> the map.

The **garage** (`scripts/run/garage_panel.gd`): a bay in a SubViewport (`own_world_3d`),
faded in once the model is drawn; the model is rebuilt only when its key changes; part
models are pre-warmed on background threads (`ConstructView.warm`) when the map opens.
`ConstructView.build_parts(ids, db, colour, level)` names each part `part_<slot>` and adds
the **level kit** (pieces tagged `level_kit`) and scale. STATS come from
`RunSim.preview_machine`. Level-up is `_celebrate` (an awaited sequence; `_celebrating`
guards it). During a drag the garage only RESTYLES. `MachinePortrait` renders a crew
machine once (`UPDATE_ONCE`) for the dock and the bay. `Surfaces` is the one place for
tinted Poly Haven materials and palette-dressed arena props. **Particles on a billboard
material need `billboard_keep_scale`**, or every particle is a 1 m square. **Story text**
is `data/run/story.json` (`ContentDB.story`), deliberately NOT in the content hash.

**Build progression (011)** -- three systems, one path into the numbers:
- **Tuning**: every part has two `tuning` options in its JSON. `PartTuning.expand` (called by
  `ContentDB`) turns them into real part entries `ar_hammer:a` / `:b` ("Breaker Hammer+",
  with `base`, `tuned`, `tune`, `tune_grid`), so any lookup by id works on a tuned part. Pools
  and the bench skip them; **anything that draws or pictures a part must go through
  `PartTuning.base_of`** (ConstructView `_part_id`/`warm`, `PartText.thumb`) or it looks for
  `ar_hammer:a.glb`. Tools that iterate `db.parts` must skip `PartTuning.is_tuned`.
  `[TUNE, where, index, option]` at a workshop (`where` = crew index or -1 for the hold).
- **Makers and sets**: `maker` on every part, bonuses in `data/parts/makers.json` (merged into
  `combat_rules.makers`). `CombatSetup.sets_of` counts them -- the fight applies it, every
  screen shows it. Player machines only.
- **Perks**: `data/run/perks.json` (merged into `run_rules.perks`). `RunSim.perk_offer` is the
  seeded three; `[LEVEL_UP, crew, choice]` keeps one. The garage opens the pick (`_picker`)
  before the level-up event.
- Levels, perks and sets are additive blocks through **`CombatSetup.apply_bonus`** (the spec's
  `bonus`, from `RunSim.bonus_of`); **`RunSim.max_hp` reads the unit `CombatSetup` builds**,
  so the run cannot disagree with the fight. Heat per attack is `CombatSim.attack_heat`
  (never below 0) -- use it anywhere heat is shown or predicted.
- Salvage is `RunSim.salvage`: three parts from three slots, the second leaning to the crew's
  makers, a scrap alternative (`PICK -1`), an elite's part pre-tuned.
- `run_bot.gd -- --set path=json` overrides one run.json number for that run only, so balance
  dials can be tried side by side (16 cores: four variants at once is fine).

**Onboarding (012).** The **`Profile` autoload** (`user://profile.json`, `SaveFile` v2) holds
the tutorial flag and the first-time hints seen, changed only through its methods (which
save at once). **Every UI test points it at its own file (`Profile.use_path`) and marks all
hints seen**, or a callout sits over a click point. The **shakedown** is `scenes/shakedown.tscn`
(combat_scene with `tutorial = true`), its board `data/fights/shakedown.json` (`"tutorial":
true`, which RunSim never picks) and its steps `data/tutorial.json`; `coach.gd` advances on
what happened in the event stream and marks targets with `coach_point` (board) or an outline
(`CombatHUD.control_for`). **`Glossary`** (`data/glossary.json`, text only, not hashed):
`linkify` for RichTextLabels, `label`, `show_card`, `open`; never put links inside a Button.
`Hints.show_once(parent, id, db, at)` is idempotent per parent.

**Act 1 content (013).** The gate is `data/fights/sorting_gate.json` (`"boss": true`: only the
boss site uses it, via `RunSim._make_gate_fight`; its first enemy is the authored Sorter, the
rest are positions for rolled escorts). **Gate pylons are props** (`p`, tile `pylon`, 6 HP):
`CombatSim._pylon_cover` gives the Sorter `pylon_armor` while any stands. **Kinds that `builds`**
(hive, sorter) share the pad code with their own `every`. **Reclaimer arrivals**: a fight dict
with `reclaimer: {round, count}` (added by `RunSim._start_fight` when `reclaimer_reaches`)
marks `state.arrivals` a round ahead and spawns `setup.reclaimer_drone` copies
(`ARRIVAL_MARKED`, `SPAWNED` with actor -1). `PROP_PLACED.v1` is an index into
`GridEv.PROP_KINDS` -- a new prop kind must be added there or it draws as a crate. New sites:
`trader` (`BUY`, `SELL`), `tower`, `signal` (`CHOOSE`, `data/run/events.json`, in the content
hash because effects are rules); `LEAVE` closes any of `RunSim.LEAVABLE`. `shot_run.gd --force
KIND` turns the camp's neighbours into KIND for screenshots; `combat.tscn -- --reclaimer` shows
arrivals in a practice fight.

**Play-test 5 (014).** Combat: `CombatSim.throw_wreck` (a killing shove throws the wreck:
`WRECK_THROWN` v1 = the start hex packed `y * 64 + x`, v2 = 1 landed / 0 hit something;
`PILE_LOST` when its scrap leaves a hex); pierce passes props and counts them; the arc is a
search (`_arc_search`, values `ARC_KILL` / `ARC_CRATE`, heaps relay for free); `paths_from`
breaks cost ties by fewer hexes. The scene draws the hovered route (`_hover_path`) and marks
cost-2 hexes `COL_MOVE_SLOW`; `_undo` reselects the undone action's machine. Run:
`FightRecap.build` (pure, from the event stream) feeds the result screen; `RunSim.move_preview`
feeds the map's hover card (tested against what each move then does). A fight map may set its
own `max_rounds`. `run_bot.gd --set combat.<path>=json` / `fight.<id>.<path>=json` try combat
and map variants; `shot_combat.gd --move X Y`, `shot_recap.gd`. The gate's pylons stand on
the back row behind the Sorter; of escorts, summon pace and round limit, only the round limit
moves its difficulty (12 rounds: 86.0% to 80.0%).

**Ink & Rust (015-016): the game's look.** The user picked art direction A and approved the
style frame; since 016 EVERY screen is drawn in it (the "Rust & Sodium" sections below are the
history of 010). Every 3D screen: `Ink.environment()` + `Ink.key_light()` -- the toon ramp
draws the directional key ALONE, so point lights and spots do nothing (lamps are lit bulbs).
UI: `UIKit`'s old constant names now hold paper and ink (SURFACE is paper, TEXT is ink);
anything on the dark page or over the 3D world must be `UIKit.on_page(label)` (paper, an ink
edge) or it is invisible; a selection is an amber BORDER with ink lettering (amber text does
not read on paper); `UIKit.pressed(style)` for a button's pressed state. Part pictures come
from `tools/make_ink_thumbs.gd` (`art/thumbs_ink/`, preferred by `PartText.thumb`) -- rerun it
after any part model changes. `material_overlay` holds the ink line: anything that lights a
part must hand the line back. Board labels are laid out every frame (`_declutter` in the
combat scene); a label's companions are offset in the billboard plane (`offset`), never in
world height (the camera looks down: a world step shows at half size). A shot along hex edges
fires the better of its two sides (`CombatSim._shot_along` / `_better_shot`). `Ink`
(`scripts/presentation/ink.gd`) is the one place: palette and signals, `toon()` (three bands;
the lit band is the palette colour exactly because the key's HUE is used, never its energy),
`line()` (the ink outline: `material_overlay` of an inverted hull at constant screen width,
over smoothed normals packed octahedrally into UV2 by `hull_mesh` -- a box's split normals
crack at every corner), `dress_machine` (machines are built by `ConstructView` as before and
then dressed by zone; the level kit is recognised by PartMaterials' cached materials). Three
line weights only (`LINE_WORLD`/`LINE_MACHINE`/`LINE_ACT`). Marks use `ink_mark.gdshader` via
`MARK_STYLES` in the scene: **the hatching direction carries the meaning** (move one diagonal,
threat the other, target crossed) so it survives grey; the enemy's ring is a saw blade. HUD
panels are `InkBox` (a StyleBox with a hard offset shadow; `StyleBoxFlat` can only blur) via
`UIKit.ink_card/ink_button/ink_caption`; Anton is `UIKit.font_comic()`, Bangers
`font_letters()` (sound effects only). **Check a new look in grey**: the first frame failed three
colour-only reads. `measure_contrast.gd` hides Label3D/Sprite3D in both renders now -- compare
looks only with the same tool (re-measure the baseline). The frame is `tools/frames/decision.json`
(NOT content: anything in `data/fights/` joins the run's pool and the hash), shot with
`shot_combat.gd --fight-file res://tools/frames/decision.json --steps "select=2 weapon=0 tap=0,3
tap=0,3 select=0 weapon=1 tap=2,3"`. Among equally cheap routes, the one over the most scrap
wins (`CombatSim._better`).

**New models (017, proof; the user picks the routes for the rest).** Route A: machines are built
from concept art (`art/concepts/`) by `tools/blender/make_ink_parts.py` (the generator's
primitives + the bridge's contract via `make_scrap_parts` helpers) into `art/parts_new/`; route C:
set pieces come from **`tools/gen3d/next_site.sh [kind]`** (020: concept -> our own background mask
`cut_background.py` -> TRELLIS with the user's token in `~/.cache/huggingface/token` -> raw kept in
`tools/gen3d/raw/` -> `tools/blender/clean_generated.py --keep-texture` -> `art/sites/<kind>.glb`;
exit 2 = no allowance: a rolling 24 h, four or five runs a day; facing sites pass `--no-square`).
TripoSR (`triposr_run.py`, CPU) was the first try and is kept as a fallback. **`-- --models new`** (`Models`)
swaps them in per part/site everywhere; the default game is unchanged. `tools/shot_models.gd`
compares old and new (`--site workshop` for landmarks); `verify_assembly.gd -- --dir
res://art/parts_new`; thumbs `make_ink_thumbs.gd -- --models new --out res://art/thumbs_new
--only ids`. In Blender, **call `view_layer.update()` after writing `.location`** before composing
onto `matrix_world` (both legs once baked at the pelvis). `alu` (the one light value) is a real
zone now (`PartMaterials.zone_of`). The board camera sees your crew from BEHIND: give a chassis a back.

**Play-test 7 (024).** **Short-lived materials go through `Ink.hold(m)`**: Godot frees a
StandardMaterial3D's shader with the last material using it, so a tracer that threw its material
away recompiled it on the next shot -- 300 ms each on this Mac's GL driver (a transparent
EMISSIVE material recompiled even when held: use additive, over-bright albedo instead). **No
OmniLight3D in effects**: the toon ramp ignores it and every material in range compiles a new
variant. Every effect is drawn once behind the **opening card** (`combat_scene._opening`, the
fight's name and objective) so first uses compile there; add any new effect or mark to it.
`tools/measure_hitches.gd -- --bot --fight X` lists slow frames with the event being played
(not headless). Consequences of one cause play together (`CONCURRENT`, `T_TOGETHER`). The board
shows **one total per hex** from `CombatSim.incoming` (the enemy volley AND the next round's
start, run on a copy) -- red; the aimed attack's totals are amber at the hex's far edge. A shove
off the six axes takes the better of its two directions (`CombatSim.shove_dir`); a piercing shot
may be aimed as far as its beam flies (`CombatSim.aim_reach`). The selected machine wears an amber
ring and arrow (`_follow_selection`). Labels declutter up OR down, the shorter way.

**Act 3 (025).** The Crucible: `run.json` `acts[2]`, boards `casting_floor`, `ladle_line`,
`furnace_mouths` (`"acts": [3]`), gate `the_core`. **Furnace flues** (tile `f`, grid `flue`;
not "vents" -- VENT is what heat does): blow at the start of every `rules.json` `flue_every`-th
round (`CombatSim.flues_blow`, `FLUE_BLEW`). **Conduits** (kind `conduit`): allies next to one
hit `boost` harder, inside `strike_plan` (`CombatSim.conduit_boost`). **The Core** is kind
`heart` (the id is not "core", which is a part slot the glossary would mislink): `still` (never
moves), `anchored`, `builds`, and pulses (`pulse_every`/`pulse_radius`/`pulse_damage`,
`state.pulse_marks`/`pulse_by`, `PULSE_MARKED`, `PULSED`). Round-start effects live in
`CombatSim._round_hazards`, which `incoming` also runs. A terrain an act does not name draws no
dice (`_scatter_terrain` skips `flues`), so earlier acts generate exactly as before.

**Play-test 8 (026).** **Card text goes through `UIKit.fit(label, width, max_lines, min_size)`**:
it wraps and steps the font down until the text fits (ellipsis past `min_size`); it measures with
the label's own font override, so give every fitted label a face (`PartCard._label` and the
garage's `_label` always do). Board tags have `render_priority` 10 (over hatching, marks and
badges) and never move more than their own height (`_declutter`); a scrap carrier wears a green
bundle at its ring (`_scrap_bundle`), no mark by the tag. The opening card holds
`OPENING_SECONDS` (5). Enemy lines are arrows, lobs arched (`_intent_marker_bar`, over the
machines). A beam's end is labelled BEAM ENDS. The garage opens behind a cover (`_build_cover`)
until its machine is drawn. Salvage, scrapyards and traders roll with the ACT's `rewards`
(`RunSim.rules_of`); caches are rolled `cache_spacing` apart; the act's `enemies.bonus` arms its
keeper too. `run_bot.gd --from N` starts at seed 1000 + N; `tools/sum_bot.py` sums such reports.

**Play-test 9 (027).** **Every iteration ends on `main`**: work on `iter-NNN`, then fast-forward
`main` and push it (the user: "all the changes need to be on the main"). Names: the default crew
is Knuckles, Needle, Relay; `[RENAME, crew, name]` (`RunSim.clean_name`, `NAME_MAX` 12) from the
bay and the garage via `Run.rename`, which also stores it in `Profile.crew_names(crew_id)` so the
crew's next run re-applies it as actions. Keepers with an `enraged` kind block escalate once at
half HP (`CombatSim.kind_rules`, `_maybe_enrage`, `ENRAGED`, guards summoned next round via
`state.summons`); read a kind's numbers through `kind_rules`, never `setup.kinds` directly.
Levels go to 5. Arms are seated clear of the body at build time (`ConstructView._seat_arms`,
`ARM_INSIDE`, `tools/probe_arms.gd`). `UnlocksPanel` (title and run end) shows every unlock with
`Meta.progress`. The bay (`assembly_panel.gd`) is crew / lift / bench; the garage is MACHINE /
LOADOUT / NUMBERS over the hold.

**Content (028-031).** Objectives `hold` / `hack` / `survive` (`state.hold_score`, `hacked`,
`wave_marks`; `IntentAI._objective_value`) and yard **modifiers** (`run.json` `modifiers`,
`RunSim._roll_modifier`, read by `CombatSetup`). New arm shapes `cone` (flamer) and `shield`
(shield caster) and `pull` (harpoon); **legendaries** are rarity 4, never rolled by "at least N"
unless N is 4 (`_roll_at_least`), and may borrow another part's model (`"model"`,
`PartTuning.model_of` -- anything that draws a part goes through it). **Warlords** (030): one
`warlord` site per act at `warlord_column`, an authored `"warlord": true` board through
`_make_gate_fight`; rules `aura`, `haul_every`/`haul_radius`, `twin_armor`, all in
`_round_hazards` / `damage_to` so `incoming` sees them. A gate or warlord win opens a `hoard`.
**Sites (031)**: `arena` (a fight type: elite plus `arena_extra`), `refinery` (`[REFINE, cargo]`),
`auction` (`[BID, tier]`), each once a visit (`pending.used`). `RENAME` (027) names a machine;
`Profile` remembers custom names per crew.

**Play-test 10 (032-036).** Tools under `--script` use `user://tool_run.json` and
`user://tool_profile.json` (`RunStore.path()`, `Profile._ready`) -- a screenshot once banked a bot
run into the player's profile. Run boards are templates padded by `run.json` `board` (2 rows
between the sides, a column each edge: `RunSim.widen`; middle rows via `RunSim.middle_rows`);
an act's `board.enemies` adds enemies (Acts 2-3: +1). `enemies.arena`, act `rewards`, refinery /
auction prices and `warlord_legend_pct` set the rarity economy; the bot reports rare+ fitted at
the last gate. Cores and modules may carry `CombatSetup.EXTRA_KEYS` (pierce, arc, mark, shove,
tears, melee, unshovable, move_after_attack, thorns, regen, kill_heal, last_stand) through
`apply_bonus`; `REPAIRED` / `LAST_STAND` events. A borrowed `"model"` must name a part with its own
.glb (aliases do not chain). `tools/part_points.py` prices every part; `docs/plans/parts-power.md`.
Missions: `RunSim.tally_feats` counts feats from each fight's events into `RunState.feats`;
`Meta.stats_after` banks them; a `mission: true` unlock's `when` names a feat. The `Juice` autoload
animates every BaseButton (opt out: meta `no_juice`). `Ink.print_pass(parent, layer)` prints the 3D
world under the HUD (`-- --look plain` to compare); measure looks on a quiet machine.

**Play-tests 11-12 (037-042).** Charge stops on the hex aimed at and captures terminals; an arm may
carry its own `damage_type` (`weapon["dtype"]`, used by `strike_plan`); `CombatSim.damage_parts`
breaks a total into its parts; `diff` reports damage to props that stand. Bosses: `cover_kind` /
`cover_armor` (the Core's conduits), authored machines a gate keeps are counted in `keepers`, the
boss bar is `CombatHUD.set_boss`. The comic layer: `BalloonTail`, thought clouds, SFX words, speed and
focus lines, `UIKit.caption_title` (tilted inside a holder: containers reset rotation),
`ComicStrip`, `show_opening_strip`, page turns in `Juice`; story text with lore AND gameplay in
`story.json` (`briefing.panels`, `acts[].arrival`, `bosses`). Performance: measure with
`tools/measure_draws.gd`; labels/sprites cast no shadows, machines shadow from the frame only,
the board is merged per material (`Ink.merge_static`). Models: `make_scrap_parts.py --only <id>`
for a missing part, never the whole roster; arms and modules may name a `look`.

**Play-test 13 (043).** UI: `UIKit.card`/`ink_card`/`primary`/`secondary`/`choice`/`pressed` return
`InkBox` (pop-art panels, pulp buttons -- the user's pick); InkBox speaks StyleBoxFlat's property
names and exports its variables (so `duplicate()` works); type a UIKit style as `InkBox`, not
`StyleBoxFlat`. A billboard Label3D is measured from its font (`_screen_box`), never `get_aabb()`.
`keeps_arms` on a kind stops tears (bosses, warlords). The tier ladder: NEW RUN starts at once,
`wins_t<N>` opens tier N+1, `Profile.bank_run` moves the choice up, `kind: ending` (u26) is the top
tier's win (`Meta.top_tier`, `Meta.finished`). Arms are drawn at `ConstructView.ARM_SCALE` and seated
clear of the legs; `MachinePortrait` "full" frames the whole machine after its turn.

**Generated machines (045).** A machine part can be generated: FLUX concept (`tools/gen3d/part_concept.sh`,
the user picks) -> TRELLIS on **Colab's free T4** (`tools/gen3d/trellis_colab.ipynb`, runtime 2025.07;
`colab_prep.sh` cuts concepts and imports models) -> `tools/blender/rig_generated_part.py` with a spec in
`tools/gen3d/parts/<id>.json` (`next_part.sh <id> --rig`) -> `art/parts_gen_scrap/`, **the default
since 064** (`Models.gen_models`; `--models new`/`old` for the other sets). Each slot is generated alone; only a frame's legs are cut.
TRELLIS bakes highlights into its texture: always `grade` before the toon ramp. `Ink._dress_node` keeps a
textured part's texture. `tools/record_round.gd` + `--write-movie` records a fight playing itself.

**Comic scrap machines (051).** Concepts now come from **ChatGPT Images** in the user's Chrome, one chat per
machine (whole machine first, then each part against it), each part in its MAKER's paint (`Ink.MAKER_LIVERY`)
patched with plates off other machines -- the user: robots must read as scrap and no build may look "correct".
Downloads stop at Chrome's Save dialog: show the image with `tools/gen3d/chatgpt_show.js` (`__grab(-1)`), save a
FULL-size extension screenshot, crop with `tools/gen3d/grab_crop.py`. 3D on Colab, rig specs
`tools/gen3d/parts/<id>_scrap.json` -> `art/parts_gen_scrap/`, drawn with `-- --models gen --gen-dir
res://art/parts_gen_scrap`; `tools/shot_machine.gd` shoots one machine in ink at chosen angles. Grade per part.

**Fast tools (070).** Bot tools split themselves over every core: `--jobs N` (default one per core but
one) on `run_bot.gd`, `balance_fights.gd`, `sim_fingerprint.gd`, through `tools/jobs.gd` (children take
interleaved items, write `+`/`-` progress lines and JSON numbers; the parent sums with `Jobs.merge`; load
it with `preload`). `--jobs 1` runs in one process (use it to see a child's script error). **A change
meant only for speed must leave `sim_fingerprint.gd`'s TOTAL unchanged** (`tools/check.sh
--fingerprint` compares with the last one kept). `Hex.line`/`ray`/`within` are cached and return
READ-ONLY arrays: copy one before changing it. `verify_combat`/`verify_run` print a `time` line for any
test over a second.

**Numbers with margins (071).** `run_bot`/`balance_fights` print 95% intervals; `--b path=json`
(repeatable) plays variant B on the same seeds/fights and prints B - A with a verdict ("real" only when
the interval leaves out zero). Statistics live in `tools/stats.gd` (Wilson, Newcombe, `z_for` for
several judged at once; self-check in `check.sh`), as does the one `--set` parser (`Stats.override`,
which errors on a misspelt path). A run dial needs ~150+ runs: runs diverge after one changed fight,
so same seeds help little; a combat dial is sharp with `balance_fights --b`.

**An overfull hold blocks travel, never a pick** (`RunState.overfull`,
`RunSim.destinations`). A boss fight that is not won ends the run: there is no road past
the gate.

**zsh does not word-split `$var`.** Looping over argument strings needs `${=var}`, or
they reach Godot as one argument and are ignored.

