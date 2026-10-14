# Iteration 074 — Arms on their shoulders, a look for every shot

**Status:** done (the user plays and judges)
**Started:** 2026-10-14 · **Finished:** 2026-10-14
**Answers:** the user, after 069: "make the arms no longer detached from the frames, and for every
ranged weapon make different trails behind the shot and different shooting animations".

## Goal
Every generated arm sits on its frame's shoulder with no daylight between them, and each of the 13
ranged arms fires with its own animation and leaves its own trail, so a shot tells which gun fired it.

## Scope
- In: `ConstructView` (how a generated arm is seated), `ConstructRig` (one firing animation per ranged
  arm, the muzzle point), a new presentation file `data/fx/weapons.json` (fire style, trail, colour per
  arm; not in the content hash), `ShotFX` (the trails), `combat_scene._attack` and the opening warm-up.
- Out (deliberately): any rule or number; melee strikes (the Chain Flail's arc stays for later); sounds
  beyond picking among the existing ones.

## Steps
1. Measure the gap between each arm and its frame, at rest and posed; find why the front view shows
   daylight.
2. Seat generated arms by their silhouette at shoulder height (`ConstructView._snug_arms`).
3. `data/fx/weapons.json` + `WeaponFX`: per ranged arm a fire style and a trail.
4. `ConstructRig.strike(..., style)`: new styles; `muzzle(slot)` the real tip of the gun.
5. `ShotFX`: one trail per arm, every material held and warmed behind the opening card.
6. `tools/shot_trails.gd`: a sheet of every ranged arm mid-shot, for the user.

## Acceptance criteria
- [x] Front view of three generated machines: no daylight between arm and shoulder.
- [x] Every ranged arm (13) has a fire style and a trail of its own; a test fails if one is missing.
- [x] Sheet of all 13 shots, shown to the user.
- [x] `tools/check.sh` green; `verify_animation` covers each new style (impact time > 0, back to rest).
- [x] Fingerprint unchanged (presentation only).

## Result
- **The gap.** Measured on the posed skinned vertices, every arm's NEAREST point touches its frame (under
  2 cm). The daylight in the front view is the arm's bulk: a generated arm is mounted by its innermost
  vertex (`rig_generated_part.py`), usually a bolt or a ring rim, so the gun body and shoulder pad stood
  2-4 cm off the shoulder. `ConstructView._snug_arms` draws each arm in until the 12th percentile of its
  silhouette in a 5 cm band at socket height sits 1.2 cm inside the socket (at most 8 cm). Close-ups
  before/after of the Lancer, Skirmisher and Reaper: no daylight after (`shots/074_*_b_0.png`).
- **Shots.** `data/fx/weapons.json` gives each of the 13 ranged arms a firing style and a trail, colour
  and sound (`WeaponFX`). New `ConstructRig` styles: Rail Lance punch, Pulse triple burst, Flamer hose
  sweep, Harpoon fire-and-yank, Aegis raise-and-push, Sunspear charge-and-shove, Snare whirl-and-flick,
  Mine Layer underarm toss; Scattergun (pump), Mortar, Rail Driver, Coilgun and Spotter keep their
  class's. `ConstructRig.muzzle(slot)`: the shot leaves from the gun's real tip (the arm vertex furthest
  forward, carried by its bone), no longer from the chest. `ShotFX`: needle, scan dots and reticle,
  three pulse bolts, pellet fan, smoking shell, ringed rail beam, flame stream, hook and chain, aegis
  ripples and bubble, flickering lightning, swelling sun beam, bola and net, hopping mine. All warmed
  behind the opening card under a hidden holder.
- Sheets: `shots/074/trails_sheet.png` (in flight), `shots/074/fire_sheet.png` (the moment it fires),
  from `tools/shot_trails.gd`.
- `verify_animation` 38/0 (new: every ranged arm has a style and a trail, no two alike, each style shoots
  from in front of the machine and comes home). `tools/check.sh --fingerprint` all green: verify_combat
  370/0, verify_combat_input 27/0, verify_run 187/0, verify_run_ui 51/0, verify_save 15/0,
  verify_onboarding 39/0, verify_meta 77/0, verify_assembly 168/0. Fingerprint TOTAL 1dd1b7d8, the same
  as `main` before this iteration (run from a scratch copy); it differs from the abc8a920 noted at 073.
- Not run: `run_bot.gd` (no rule or content changes).

## Decisions, lessons, open questions
- **How a shot looks is presentation data** (`data/fx/weapons.json`), outside the content hash: a new
  look never refuses a saved run.
- Lesson: "nearest point" says an arm touches; the eye reads the silhouette. Measure the band, not the
  minimum.
- Open: the fingerprint moved between 073 and 069's end (abc8a920 -> 1dd1b7d8) without a sim change in
  074; worth a look before the next speed-only change.

## Next
- The user plays and judges the shots; the Chain Flail's arc attack is still to do.
