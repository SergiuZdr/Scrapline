# Plan — Salvage audit of the old codebase

**Status:** CUT list executed in 001 (2026-09-24). ADAPT files that depended on cut code now sit in `legacy/`, and each is deleted once 002–006 replaces it.

Before anything is deleted, the current `main` is tagged **`archive/f2p-battler`**, so
nothing is lost.

## KEEP (works as-is or nearly)

| What | Where | Why |
|---|---|---|
| Scrap part generator + roster art | `tools/blender/` (make_scrap_parts, scrapgen, make_terrain, make_arena, check_parts, inspect_parts, hero_render, compose_sheet), `art/` | The most valuable asset in the repo: 40 generated parts with a working export contract |
| Construct view + materials | `scripts/presentation/construct_view.gd`, `part_materials.gd` | Assembles a unit from 5 part ids, which is exactly the new game's model |
| Animation rig | `scripts/presentation/construct_rig.gd` | Strike, stagger and collapse work on a grid too |
| VFX | `scripts/presentation/battle_vfx.gd` | Hit-stop, sparks, debris |
| UI kit, fonts, icons | `scripts/ui/ui_kit.gd`, `art/fonts/`, `art/icons/` | One consistent interface language |
| Synth audio | `scripts/autoload/audio.gd` | No licensing |
| Deterministic primitives | `sim/rng.gd`, `sim/sim_math.gd` | The foundation for the new sim |
| Content loading | `scripts/content_db.gd` | JSON to typed lookups |
| Part data | `data/parts/*.json` | Retuned for the grid in 003 |
| Terrain tiles | `data/terrain/tiles.json` | Reinterpreted for the grid |
| Art/anim tests | `tools/verify_assembly.gd`, `verify_animation.gd`, `gait_preview.*`, `tools/show.sh` | Guard the art contract |

## ADAPT (the idea survives, the code gets rewritten or trimmed)

| What | Where | Becomes |
|---|---|---|
| Event stream | `sim/events.gd`, `event_stream.gd` | Grid combat event vocabulary |
| Damage/heat resolvers | `sim/resolvers/damage.gd`, `heat.gd` | Turn-based versions; the type wheel moves over |
| Doctrine engine | `sim/doctrine/doctrine.gd` | Enemy intent rules |
| Unit builder | `sim/unit_builder.gd`, `sim_unit.gd` | Builds a grid unit from 5 parts |
| Balance tunables | `data/balance.json` | Keep the damage wheel; drop the tick values |
| Boss design | `scripts/coop/colossus.gd`, `data/bosses.json` | Multi-part grid boss (vital core + guarded limbs) |
| Profile and commands | `scripts/profile/profile_store.gd`, `player_profile.gd`, `scripts/commands/` | Meta-unlock profile; the same "only commands mutate" rule |
| Save | `scripts/save/` | Profile plus run save |
| Loadout screen | `scripts/ui/loadout_screen.gd` | Salvage and refit screen |
| Battle camera | `scripts/battle/battle_camera.gd` | Fixed tilted board camera with 90° snaps |
| Battle scene | `scripts/battle/battle_scene.gd` | Board scene: its arena, lighting and team-ring code gets mined |
| Balance sim | `tools/balance_sim.gd` | `run_bot.gd` |
| Session autoload | `scripts/autoload/session.gd` | A slim game-state autoload |

## CUT (the F2P/online layer; recoverable from the tag)

| What | Where |
|---|---|
| PvP, ranked, tournaments | `scripts/pvp/`, `sim/battle_submission.gd`, `sim/battle_verifier.gd` |
| Networking and server | `scripts/net/`, `server/`, `tools/nakama_http.gd`, `tools/verify_worker.gd`, `tools/liveops.gd` |
| Co-op, guilds | `scripts/coop/coop_service.gd`, `guild_service.gd` |
| Store, IAP, season pass | `scripts/store/`, `scripts/profile/battle_pass.gd`, `pass_service.gd`, `data/store.json`, `data/battle_pass.json` |
| Crates, foundry, economy | `scripts/profile/crates.gd`, `foundry.gd`, `economy.gd`, `data/crates.json`, `data/buildings.json`, `data/economy.json` |
| Campaign, gauntlet | `scripts/campaign/`, `data/campaign.json` |
| Live content patches | `scripts/content_patch.gd`, `tools/publish_content.gd`, `patches/` |
| Analytics | `scripts/autoload/analytics.gd` (revisit only if there is an opt-in) |
| Continuous real-time sim | `sim/battle_sim.gd`, `battlefield.gd`, `resolvers/movement.gd`, `targeting.gd`, `battle_controller.gd`, `order_panel.gd` |
| Hub | `scripts/ui/hub_scene.gd`, `hub_yard.gd`, `yard_hub.gd`, `doctrine_editor.gd` |
| Old tests for cut systems | `verify_pvp`, `verify_online`, `verify_anticheat`, `verify_store`, `verify_coop`, `verify_content`, `verify_meta`, `verify_gauntlet`, `verify_loop`, `verify_interactive`, `verify_ui`, `verify_symmetry`, `verify_battle` |

Iteration 001 checks every removal by grep, confirming nothing in KEEP or ADAPT still
references it, before deleting.

## CLAUDE.md

After 001, rewrite `CLAUDE.md` for the new game. Keep the art, export and animation
doctrine sections verbatim (they are still true), and drop the F2P, online and
monetization sections.
