# Iteration 024 — Play-test 7 fixes

**Status:** done -- waiting for the user to play it
**Started:** 2026-09-30 · **Finished:** 2026-09-30
**Answers:** [play-test 7](../playtests/2026-09-30-playtest-7.md), every item but Act 3 (025).

## Goal
The fight reads at a glance and plays without freezing: one total per hex the enemy will hit,
the machine under your hand obvious, the objective up from the first frame, no shader stalls,
labels that stay on their machine; shoves and pierce do what a player expects.

## Scope
- In:
  - **Enemy fire as totals** (PT7-3): a new sim query runs the enemy's volley on a copy and
    reports what every unit and prop would take; the board shows ONE number per hex hit,
    including anything in the way. Firing-order badges go (the list stays in the info panel).
  - **Your aim on the board** (PT7-12): the aimed attack's damage on every hex it touches, and
    the preview list ordered by distance from the shooter, enemies first.
  - **No stalls** (PT7-4): short-lived materials keep their shader alive (`Ink.hold`); the
    drum's useless omni light goes; every effect is drawn once behind the opening card
    (`_warm_up`); hits from one cause land together instead of one after another.
  - **The opening card** (PT7-5): the fight's name and objective over the board while it loads;
    the objective panel is filled before the first event plays.
  - **Selection** (PT7-9): an amber ring and a chevron over the machine under your hand.
  - **Labels** (PT7-2): the scrap mark sits on the tag's HP line; a crowded tag moves the
    shorter way (up or down) instead of always down.
  - **Shoves** (PT7-6): of two equally good directions, the one better for the shover (a pit,
    a bump into the other side, over open ground last); the preview draws where it goes.
  - **Pierce** (PT7-7): a piercing weapon may be aimed as far as its beam flies, so the line can
    be drawn through the thing behind.
  - **Audio** (PT7-8): the ambience is a low machine hum, no surf.
  - **Models** (PT7-10): no stencilled numbers.
  - **Names** (PT7-11): crew machines keep their crew's names (not their frame's); names proposed.
- Out (deliberately): Act 3 (025).

## Steps
1. Sim: `CombatSim.incoming`, shove direction choice, pierce aim reach; tests.
2. Scene: totals, aim numbers, selection marker, labels, opening card and warm-up, batching.
3. Audio, stencils, names.
4. Measure (hitches, contrast), suites, run bot, docs.

## Acceptance criteria
- [ ] `measure_hitches.gd` on a bot fight: no frame over 100 ms after the opening card. **Not
  met in full**: 0 frames over 350 ms (from 29 up to 2.3 s); the rest (100-340 ms) are the bot
  planning its own turn and the enemy planning inside END TURN -- see Result.
- [x] verify_combat: `incoming` equals what the volley does to every unit's HP; a tied shove takes
  the pit on either side; a piercing weapon can aim into its overshoot and its plan reaches there.
- [x] Screenshots: one total per hit hex, the selected machine marked, the scrap mark on its tag.
- [x] Every suite passes; the run bot plays 152 runs with 0 illegal actions.

## Result

**The lag (PT7-4) was measured first** (`tools/measure_hitches.gd`, the bot playing slag_pit):
29 frames over 40 ms, most of them 300-850 ms at attacks and hits, 1.1 s at a kill, 2.3 s at a
torn arm. `sample` on the running game put the time in the GL driver compiling shaders. Fixes,
each re-measured:

| Change | Frames over 40 ms (after the opening) | Worst |
|---|---|---|
| before | 29 | 2877 ms |
| fireball's omni light removed; `Ink.hold` on throwaway materials | 27 (holding did nothing: the copy was never asked for its RID) | 2859 |
| hold builds the shader (`get_rid()`), the tracer additive not emissive, effects warmed behind the opening card | 18 | 765 (the first marks and HUD) |
| marks, HUD and a scrap pile warmed too; a cause's hits played together | 7-8 | 310-340 (the bot planning its own turn) |

A tracer alone went from 590 ms every shot to 33 ms after the first. What is left is the bot's
own planning and the enemy's (`IntentAI` inside END TURN, 0.1-0.2 s): the banner answers the
press first now. Act 3's Core fight (six enemies): worst frame 153 ms.

- **Totals** (`CombatSim.incoming`, `_volley_badges`): the Lancer's rail through its own Reaper
  and a drum shows "-7" on the Reaper; two shots into Knuckles one "-4". Firing-order badges are
  gone from the board. **Aim totals** amber at the far edge; the preview list nearest-enemy first.
- **Selection**: an amber ring and a drawn arrow over the tag (`shots/024/select_crop.png`).
- **Opening card** (`shots/024/opening.png`) with the objective; the plate is filled at once.
- **Labels**: the scrap mark sits on the HP line (`_place_loot`); declutter moves the shorter way.
- **Shoves and pierce** in the sim; **names** (Knuckles, Mule, Stilts; Slab, Winch, Needle; Dash,
  Magpie, Wick -- proposals, the user picks), the frame on the card; no stencils; a hum.
- Suites: combat 219, input 22, run 138, run UI 48, onboarding 39, save 15, meta 59, animation 34,
  assembly 140. Contrast (slag_pit): ratio 3.13 (2.51 at 015; it has only grown).
- **Run bot, 152 two-act runs: 78.3%** (75.3% before), 0 illegal; losses 12 in Act 1, 21 in Act 2.
  Aiming a beam into its overshoot and choosing the better shove help the player a little.

Not done: nobody has looked at the totals in a real play; the names wait for the user's pick.

## Decisions, lessons, open questions
- **Totals, not firing order**, on the board; the order stays in the info panel.
- **A tied shove takes the better hex; a piercing weapon aims as far as it flies.**
- Lesson: "it lags" was the GL driver compiling shaders -- measure frames and sample the process
  before guessing; a held material only helps if its shader was built (`get_rid()`); a
  transparent emissive material recompiles anyway.
- Open: the names; whether the totals and ring read in play.

## Next
025: Act 3, the Crucible.
</content>
</invoke>
