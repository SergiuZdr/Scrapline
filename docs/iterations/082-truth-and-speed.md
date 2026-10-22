# Iteration 082 — Truth, speed and an honest ladder

**Status:** in progress
**Started:** 2026-10-22 · **Finished:** —
**Answers:** the engagement review (`docs/plans/engagement-review.md`, sections 4 and 8) and the user's
answers of 2026-10-22: every round must hold something worth doing, harder overall, a reason to come
back daily and weekly, no tap-skip of the opening card, 70-100 min runs are fine, and every iteration
must carry impactful changes.

## Goal
The game stops teaching a false rule, fights play back as fast as the player wants, the difficulty
tiers really apply in all three acts, and the run's rewards and endings say what happened to the crew.

## Scope
- In:
  - **A11** the move-after-attack truth: tutorial and glossary text, the "Firing ends <name>'s move"
    warning when a non-LINE machine arms before moving, a ROOTED tag with its glossary card.
  - **A13** copy-clean pass ("(050)"-style leaks out of player text), first-time hints for the ladder
    and unlocks, new parts, EXPOSED, SEIZED, and a coverage test for site types and hint ids.
  - **A16** playback 1x/2x/3x (`Profile.playback`) plus hold-to-hurry; `Engine.time_scale` in the enemy
    phase, min(speed, 2) for the player's own actions; hit-stop stays real time. **No opening-card skip.**
  - **A24 (minimal)** a settings sheet: playback speed, volume, abandon run; reachable from the title,
    the map and the fight.
  - **B1** tiers apply on top of the act (`meta.json` tiers get `adds`, applied after the act overlay
    in `RunSim.rules_of`); the tier bug fixed.
  - **A21** FIT IT NOW on a salvage card that BEATS a fitted part (pick + an existing REFIT).
  - **A22** the parts' flavour lines on reward, garage and bay cards.
  - **A23** the roll call on the run-over screen; `endings.wrecked` no longer names the wrong act.
- Out: boss changes (083), the ladder's new rungs (085), FOREMAN as a damage delta (balance, its own A/B
  in 085), the opening-card skip (the user: no).

## Steps (parallel work packages, disjoint files)
1. P1 truth and copy (A11, A13): `data/tutorial.json`, `data/glossary.json`, `scripts/combat/combat_hud.gd`,
   `scripts/ui/hints.gd`, `tools/verify_onboarding.gd`.
2. P2 speed and settings (A16, A24): `scripts/autoload/profile.gd`, `scripts/combat/combat_scene.gd`,
   new `scripts/ui/settings_sheet.gd`, `scripts/ui/title_screen.gd`, `tools/verify_combat_input.gd`.
3. P3 the ladder fix (B1): `sim/run/run_setup.gd`, `sim/run/run_sim.gd`, `data/meta.json`, `tools/verify_run.gd`,
   `tools/verify_meta.gd`.
4. P4 rewards and roll call (A21, A22, A23): `scripts/run/run_map_screen.gd`, `scripts/run/garage_panel.gd`,
   `scripts/run/assembly_panel.gd`, `scripts/ui/part_card.gd`, `data/run/story.json`, `tools/verify_run_ui.gd`.

## Acceptance criteria
- [ ] `tools/check.sh` green.
- [ ] verify_onboarding fails on "any order" in player text and on `(\d{3})` leaks; the ROOTED warning shows
      when Knuckles arms before moving; hint coverage passes.
- [ ] The event stream is identical at 1x and 3x; the enemy phase takes under 1.5 s at 2x on slag_pit.
- [ ] verify_run prints every tier x act value and asserts tier N >= tier N-1 on every key; `--fingerprint`
      TOTAL unchanged at tier 0; content hash bumped on purpose.
- [ ] verify_run_ui: FIT IT NOW leaves the part fitted and the replayed log reproduces the RunState.
- [ ] Screenshots: the settings sheet, the ROOTED warning, a reward card with flavour, the roll call.
- [ ] `run_bot --runs 150`: win rate reported against 67.3% (59-74).

## Result
(filled in at the end)

## Decisions, lessons, open questions

## Next
083: the boss is the fight.
