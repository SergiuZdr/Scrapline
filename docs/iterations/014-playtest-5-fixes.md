# Iteration 014 — Play-test 5 fixes (combat and consequences)

**Status:** done
**Started:** 2026-09-29 · **Finished:** 2026-09-29
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
- [x] verify_combat: a killing shove into a machine bumps it, into a drum sets it off, into a pit
  loses the pile, onto open ground moves the pile; a piercing shot passes a drum (which goes off)
  and hits the machine behind; props count against pierce; the arc takes the drum by two enemies
  over a lone enemy, avoids its own side, relays through a heap; equal-cost paths take fewer
  hexes; dry runs still equal execution.
- [x] verify_combat_input: UNDO selects the machine it took back, and an undone attack is armed.
- [x] verify_run: the recap's numbers are the fight's own events; **every map preview on a bot's
  route told the truth about its move** (front, lost sites, the Reclaimer's reach, enemy count).
- [x] run_bot 150 and balance_fights 600 recorded, win rate 85-92% (86.7%).
- [x] Screenshots: the kill-shove preview into a drum, the recap, the map preview, the new gate.

## Result

| Suite | Result |
|---|---|
| verify_combat | **175** passed (163): the wreck into a machine, a drum, a pit, open ground, and its preview; pierce through a drum and a crate (props count); the arc's best route, its own side spared, heaps conducting, its preview equal to what happens; the straighter path through rubble |
| verify_combat_input | **22** passed (20): UNDO returns to the machine and re-arms its weapon |
| verify_run | **127** passed (124): the recap against the events (damage to the other side, kills, Hot Loads credited once per hit); the map preview against every move of a bot's run |
| verify_run_ui / onboarding / save / assembly / animation | 48 / 39 / 15 / 100 / 34 passed |

**The gate (R5-4)**, 150 runs each, side by side:

| Variant | Won | Gate held |
|---|---|---|
| 014 combat as built | 86.0% | 13 |
| Sorter summons every 2 | 88.0% | 9 |
| Gate closes after 12 rounds | 80.0% | 22 |
| **Pylons deep, behind the Sorter, flanked by heaps (kept)** | **86.7%** | 12 |
| All three (14 rounds) | 80.7% | 17 |

The round limit is the only strong dial; escorts (013) and summon pace barely move the result.
With two thirds of the losses already at the gate, it was not made harder. The deep pylons
were kept because they change *how* the fight is won at the same difficulty: the shield is
reached by piercing through the keeper, by lobs, or by arcs run through the heaps beside the
pylons. Final run bot: **86.7%** won (90.0% after 013), 0 illegal actions in 750 runs, 5.0 fights
won a run. The combat changes cut both ways -- enemies throw wrecks and choose their arcs too.

balance_fights: random squads **95.3%** (94.3%); the arms closer together than ever (scanner
-1.5 to scattergun +1.8). Every authored fight 100% for the bot's own squad; the standalone gate
with its deep pylons takes longer (8.2 rounds against 7.6) and is still dodged almost entirely
(1.2 HP lost a fight).

### Found on the way
- **The recap first counted a machine's own drum blast as damage it dealt.** Dealt is damage
  to the other side now; taken is everything.
- The first recap check passed on a machine that never fought (0 dealt). The test now searches
  seeds for a fight where the perk's owner landed hits.
- **The Sorter's tag collides with its summon pad's label and the escorts' carrier marks**
  (`shots/014_gate.png`; the same in `013_gate.png`, so it predates 014). Board labels get a
  layout rule in the new look (015): they never overlap.
- Rubble was the "scrap on the ground" (PT5-5): the cheapest route went round it because it
  costs 2, and at equal cost the old tie-break could still pick the detour.

### Different from the plan
- The recap shows only the build effects the events can back (damage and melee per hit landed,
  armour per hit taken, HP that kept a machine standing). Range, move, vent and cooldowns are
  real but not measured, so they are not claimed.
- R5-2 (HUD hierarchy) moved to the art-direction work, as planned.

## Decisions, lessons, open questions
- **A killing shove throws the wreck** (the user's call): kills with shove weapons now change
  the board around the target.
- **The arc is a search, not a priority list**, and heaps conduct (the user's call).
- **Recap claims only what the events back.**
- **The gate keeps 20 rounds and 3 escorts; its pylons moved deep.** Open for the user: is a
  gate that decides most runs a climax or a wall?

## Next
The art direction the user picks: its style frame first (the "decision moment" scene).
