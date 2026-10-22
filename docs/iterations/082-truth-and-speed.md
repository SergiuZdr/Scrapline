# Iteration 082 — Truth, speed and an honest ladder

**Status:** done
**Started:** 2026-10-22 · **Finished:** 2026-10-22
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
- [x] `tools/check.sh` green.
- [x] verify_onboarding fails on "any order" in player text and on `(\d{3})` leaks; the ROOTED warning shows
      when Knuckles arms before moving; hint coverage passes.
- [x] The event stream is identical at 1x and 3x; the enemy phase takes under 1.5 s at 2x on slag_pit.
- [x] verify_run prints every tier x act value and asserts tier N >= tier N-1 on every key; `--fingerprint`
      TOTAL unchanged at tier 0; content hash bumped on purpose.
- [x] verify_run_ui: FIT IT NOW leaves the part fitted and the replayed log reproduces the RunState.
- [x] Screenshots: the settings sheet, the ROOTED warning, a reward card with flavour, the roll call.
- [x] `run_bot --runs 150`: win rate reported against 67.3% (59-74).

## Result
Built by four agents in parallel in a second checkout (`/Users/Sergiu/DevG/Scrapline-082`, the user's
choice: another session was still on 081 in the main folder), one package each with disjoint files.

- `tools/check.sh --fingerprint`: every suite green -- verify_combat 370, verify_combat_input 39,
  verify_run 193, verify_run_ui 63, verify_save 20, verify_onboarding 54, verify_meta 79,
  verify_assembly 168, verify_animation 38; fingerprint TOTAL `1dd1b7d8`, unchanged.
- Tiers x acts (verify_run prints it): FOREMAN enemy HP 2/7/7 (was 2/5/5), RECLAIMED HP 2/7/7 and damage
  1/2/3 (was 1/1/2). `meta.json` is not in the content hash, so saves are not refused; a run already
  started on a tier replays with its old options.
- Bot on the same 60 seeds: tier 0 45/60 (75%), RECLAIMED 24/60 (40%). `run_bot --runs 150` at tier 0:
  101/150 (67.3%, 59-74), the same as before 082: tier 0 plays the same sim.
- Playback (headless wall time, slag_pit's first enemy turn): 5.05 / 2.57 / 1.76 s at 1x/2x/3x before
  the beats were cut; 2.97 / 1.58 / 1.19 s after (the user chose "shorter beats at every speed"). The
  1.5 s aim at 2x is missed by 0.08 s; verify_combat_input fails above 1.8 s. the_pour's second enemy
  turn is still 2.07 s at 2x. The event stream is identical at 1x, 2x and 3x.
- The gear's call form opens the sheet (checked headless); each screen's gear is shown when the sheet exists.
- Screens: `shots/082/sheet_082.png` (garage flavour, salvage with FIT ON, roll call, ROOTED warning,
  settings, the abandon question).
- Not done: whether 1x now reads as rushed needs the user's eyes (the windowed recording is too small).

## Decisions, lessons, open questions
- Decision: a tier is a list of integer adds applied after the act overlay; the next rungs (085) are
  more lists. Tiers do not inherit each other yet: 085 decides whether rung N joins rungs 1..N.
- Decision: shorter enemy-turn beats at every speed (the user), enemy walks overlap.
- Lesson: a one-level overlay silently loses nested keys; any layered rule set must merge by path.
- Open: FIT ON also shows for a part that only fills an empty socket -- kept (it is the same choice).

## Next
083: the boss is the fight.
