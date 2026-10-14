# Iteration 079 — The Chain Flail's arc, cards that show the real parts, parts fitted to frames, a roomier garage

**Status:** done (the user plays and judges)
**Started:** 2026-10-14 · **Finished:** 2026-10-15
**Answers:** the user, after 078: "make the Chain Flail's attack; E10 (shards) a little darker; T7 must
attack in the shape of an arc, not straight lines; the cards in the game are not updated and many parts
have a one-colour overlay (they should show all their colours, as in Blender); the arms, the core and the
back module must be resizable by about 10% to look better on the frame", and a marked-up screenshot of
the garage (the machine filling its bay, LOADOUT narrower, DETAILS wider, the hold lower).

## Scope
- In: `ConstructRig` (`flail` style), `ShotFX` (`swing`, arc flamer), `Grit.shard_texture`,
  `tools/make_ink_thumbs.gd`, `Models.thumb_path`, `ConstructView._fit_parts`, `garage_panel.gd` layout,
  `combat_scene._shot_trail` (sweep cells, the shooter's centre), `data/fx/weapons.json` (`ar_flail`).
- Out: rules; the garage header (circled on the screenshot without a note -- left as it is, asked).

## Result
- **Chain Flail** (`flail`): the arm thrown out and back, the head whirled twice (stepped), swept flat
  across the front with the whole upper body (the hit mid-sweep), followed through and reeled back. Its
  look: a drawn swoosh round the machine across the arc it sweeps, thin to thick, with a star, sparks and
  dust on each hex it crosses, burning down into grit.
- **T7**: the hose sweeps -- 18 flame tongues thrown one after another across the wedge, each on a path
  that bows against the sweep, held until the sweep ends, so the fire draws an arc over the hexes.
- **E10**: the shards' metal 30% darker (E9 destruction with them).
- **Cards**: the pictures were rendered with one flat livery colour per zone, and the garage preferred
  the older `art/thumbs_new` pictures (models the game no longer draws). Now `make_ink_thumbs` dresses a
  part exactly as the fight does (its painted texture, posterised and inked) and a generated part always
  uses that picture. All 69 remade.
- **Fit** (`ConstructView._fit_parts`, ±10%): arms by the shoulder span (0.9 on Lancer/Skirmisher, 1.1 on
  the widest), the core to 55% of the torso's width at its socket, the module to at most 95% of the
  torso behind it (the Aegis Rig on the Lancer 0.9).
- **Garage**: bay 600x420 and the camera closer (the machine fills it), LOADOUT 570 -> 500, DETAILS
  600 -> 672, the columns 60 px taller and the hold that much lower (cards 196 -> 186 high).
- Sheets: `shots/079_efecte_inainte_dupa.png` (E10, E9, T7, T14 flail), `shots/079_marimi_inainte_dupa.png`,
  `shots/079_garaj_inainte_dupa.png`; the before from a scratch copy of `main` before 079.
- `tools/check.sh` all green (verify_combat 370/0, verify_combat_input 27/0, verify_run 187/0,
  verify_run_ui 51/0, verify_save 15/0, verify_onboarding 39/0, verify_meta 77/0, verify_assembly 168/0,
  verify_animation 38/0); `verify_assembly -- --dir res://art/parts_gen_scrap` 229/0. Not run:
  `run_bot.gd` (presentation only).

## Decisions, lessons, open questions
- **A card shows the part as the fight draws it** (game-rendered, textured).
- Lesson: a regenerated PNG is not in the game until `--import`; and an older picture set in front of it
  (`thumbs_new`) hides it -- look at the screen, not the file.
- Open: what the circle round the garage's header asks for.

## Next
- The user plays and judges.
