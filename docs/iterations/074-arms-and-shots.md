# Iteration 074 — Arms on their shoulders, a look for every shot

**Status:** in progress
**Started:** 2026-10-14 · **Finished:** —
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
- [ ] Front view of three generated machines: no daylight between arm and shoulder.
- [ ] Every ranged arm (13) has a fire style and a trail of its own; a test fails if one is missing.
- [ ] Sheet of all 13 shots, shown to the user.
- [ ] `tools/check.sh` green; `verify_animation` covers each new style (impact time > 0, back to rest).
- [ ] Fingerprint unchanged (presentation only).

## Result

## Decisions, lessons, open questions

## Next
