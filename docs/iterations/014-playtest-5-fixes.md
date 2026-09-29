# Iteration 014 — Play-test 5 fixes (combat and consequences)

**Status:** in progress
**Started:** 2026-09-29 · **Finished:** —
**Answers:** [play-test 5](../playtests/2026-09-29-playtest-5.md): PT5-4 to PT5-10, and the
review points R5-1, R5-3 and R5-4. The look (PT5-1 to PT5-3) waits for the user to pick one of
the [three art directions](../plans/art-direction-options.md); R5-2 (HUD hierarchy) goes with it.

## Goal
Every combat complaint from play-test 5 is gone, a fight ends by showing what the build did, a
move on the map shows what it costs and what it gives up, and the gate is hard through its own
rules and ground instead of its escort count.

## Plan, issue by issue

| Id | Fix |
|---|---|
| PT5-4 | **A killing shove throws the wreck.** Into something solid it stops, and the thing it hits takes the bump (a machine takes 1, a drum goes off, a crate cracks); into a pit, the wreck and its scrap are gone; onto open ground, the wreck lands there and its pile with it. The aim preview shows it |
| PT5-5 | **Straighter paths.** Among routes of equal cost, the one with fewer hexes wins, so a machine walks through rubble when it costs the same as going round. Hovering a hex in range draws the route; slow hexes are marked in the move range |
| PT5-6 | **Pierce goes through props.** A piercing shot damages a drum or crate in its line (the drum goes off) and carries on; a prop counts against pierce like a machine |
| PT5-7 | **The arc picks the most damage.** Every sequence of jumps is tried and the one that does the most to enemies wins -- a drum next to two enemies beats a lone enemy -- with damage to your own side counted against it |
| PT5-8 | **Scrap heaps conduct.** An arc can run through a heap (no damage, no jump spent) to whatever stands beyond it |
| PT5-9 | **Pierce explained** where the player looks: the arm's text says "pierce 2: through 2, hits the 3rd", and the glossary spells out the overshoot |
| PT5-10 | **UNDO returns to the machine whose action it took back**; an undone attack re-arms that weapon |
| R5-1 | **Fight recap**: per machine, damage dealt and taken, kills, arms torn; and "your build at work": each set, perk and tuning that changed a number this fight, with what it added (from the event stream) |
| R5-3 | **Consequence preview on the map**: what a site gives, how dangerous it is, whether the move advances the Reclaimer and whether its drones reach into the fight, and which sites the move leaves behind for good |
| R5-4 | **The gate's pressure from rules and ground**: pylon placement, summon timing, terrain and the round limit, tried side by side with the bot; escorts back to the plan's count if they do nothing |

## Steps
1. Sim: shove-kill, straighter paths, pierce through props, the arc search and conducting heaps;
   tests in verify_combat (each preview must equal its execution).
2. Scene: path hover and slow-hex marks, undo selection, the kill-shove and chain previews.
3. Run: fight recap data and screen; the map's consequence preview.
4. The gate: variants side by side; pick; tests.
5. Run bot, balance, screenshots, docs, merge.

## Acceptance criteria
- [ ] verify_combat: a killing shove into a machine bumps it, into a drum sets it off, into a pit
  loses the pile, onto open ground moves the pile; a piercing shot passes a drum (which goes off)
  and hits the machine behind; props count against pierce; the arc takes the drum by two enemies
  over a lone enemy, avoids its own side, relays through a heap; equal-cost paths take fewer
  hexes; dry runs still equal execution.
- [ ] verify_combat_input: UNDO selects the machine it took back, and an undone attack is armed.
- [ ] verify_run / verify_run_ui: the recap lists what the fight's events say; the map preview
  shows the move's consequences.
- [ ] run_bot 150 and balance_fights 600 recorded, win rate 85-92%.
- [ ] Screenshots: a kill-shove preview into a drum, an arc path, the recap, the map preview.

## Result
(filled in on completion)

## Decisions, lessons, open questions
(filled in on completion; also copied into MEMORY.md)

## Next
The art direction the user picks: its style frame first (the "decision moment" scene).
