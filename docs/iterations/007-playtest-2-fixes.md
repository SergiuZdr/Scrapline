# Iteration 007 — Play-test 2 fixes

**Status:** done, awaiting the user's play-test
**Started:** 2026-09-25 · **Finished:** 2026-09-25
**Answers:** every issue in [play-test 2](../playtests/2026-09-25-playtest-2.md), including PT1-8/9
(map and refit), which were deferred without saying so.

## Rule for this iteration
Reported problems are fixed before new features. Build progression (perks, sets, upgrades,
levels) moves to 008.

## Plan, issue by issue

| Id | Fix |
|---|---|
| PT2-10 | Tiles sit side to side. The 30° turn is removed and a test checks it from the render positions: the centres of neighbouring hexes are exactly one hex width apart |
| PT2-5, PT2-7 | Largely PT2-10: the board lied about distance. On top of that: **grapple aims freely** (any unit in range it can see, not only on the 6 straight lines); **anchored** machines are tagged ANCHORED and a grapple preview says why they cannot be moved; ranges in text are hex counts, and the armed ability lights every hex it can reach |
| PT2-5 | Part text shows a part's ability by name and effect, never "+0 ability" |
| PT2-8 | Focus and Overdrive apply to the next damaging action, Charge included |
| PT2-2 | **Scrap a part** anywhere outside a fight for scrap by rarity (3 / 6 / 10). The hold starts at **8** and a workshop sells **+2 room** (10, 16, 24 scrap) |
| PT2-3 | Taking salvage is always allowed. If the hold goes over, the map shows **HOLD OVERFULL** and blocks travel until something is fitted or scrapped, with the refit screen one tap away |
| PT2-4, PT2-6 | The action bar becomes **two rows**: WEAPONS (large, amber-marked) and ABILITIES (compact, blue-marked), each showing its cost. Abilities show **COOLDOWN n** or **READY** and FREE/ACTION. Full text goes in the info panel; button text wraps and never leaves the button. The bar is laid out between the camera buttons and UNDO, so it cannot run under them |
| PT2-9 | Intents are quiet by default: red target hexes and a numbered badge on each. The **full line** is drawn only for the enemy you tap, or for intents aimed at your selected machine. SHOW ALL toggles every line |
| PT2-12 | A hive's build site is a **persistent marker** on the board, "DRONE IN 1 ROUND", with a beam from the hive. The drone is built on screen with a label |
| PT2-11 | Every part card carries a **rarity banner** (COMMON / UNCOMMON / RARE) and a comparison: "↑ better than Brute's Scattergun" or "no better than what you have" |
| PT1-8, PT2-1 | **Map redesign**: zones as columns, the Reclaimer drawn as a wall with **"advances in N moves"**, the next zone to fall striped, each reachable site labelled **FORWARD / SIDEWAYS / BACK**, a site preview before travelling ("after this move the Reclaimer takes Zone 2"), site icons, and no log |
| PT1-9, PT2-1 | **Refit redesign**: drag a part from the hold onto a socket (valid sockets light up; the preview shows the stat change), drag a socket's part back to the hold, drag onto the SCRAP bin to sell. Tap-then-tap still works for phones. The button says BACK TO MAP |

## Acceptance
- [x] Each issue above has a check: a test where it is a rule, a screenshot where it is a look.
- [x] All suites green; run_bot runs with the new hold rules.
- [~] Screenshots: the hex board, the new map (with a preview), the new refit, salvage with a full hold, the battle bar. **Not taken: refit mid-drag** (a headless drag cannot be photographed; drops are tested by calling the drop handlers).
- [x] Merged to main (fast-forward). [ ] **The user plays.**

## Result

| Suite | Result |
|---|---|
| verify_combat | 108 passed (103 before): range, anchors, Charge with Overdrive |
| verify_combat_input | 20 passed: tiles meet side to side, measured from the rendered vertices |
| verify_run | 55 passed (52): hold 8, overfull blocks travel, scrap value, expand hold, **a boss fight not won ends the run** |
| verify_run_ui | 19 passed (12): preview then TRAVEL, the refit panel by tap, drop on hold, drop on SCRAP, BACK TO MAP |
| verify_save / assembly / animation | 14 / 100 / 34 passed |
| run_bot 150 | **76.7% won, 0 illegal actions**, 6.2 moves, 4.0 fights won a run. Losses: 30 whole crew wrecked, 5 held at the gate |

**The run bot found a real bug.** The first 150-run pass had 3 illegal actions: the boss
fight had timed out with the crew alive, which counts as "objective failed, the road goes
on", but there is no road past the gate and the road back was reclaimed. The crew was
stranded with no legal action. A boss fight that is not won now ends the run.

### Different from the plan
- **Refit does not preview the stat change** of a swap. The status line says what goes
  where ("Fit X as Brute's core (the Y goes to the hold)") and each card carries a
  verdict by rarity. Real stat deltas come with build progression (008), when parts have
  levels to compare.
- The intents toggle is labelled **LINES** (key L), not SHOW ALL.
- The hive marker reads "DRONE NEXT ROUND / stand here to block".

### Screenshots
`shots/007_map.png`, `007_refit.png`, `007_salvage_full.png`, `007_workshop.png`,
`007_battle.png`.
