# Iteration 027 — Play-test 9 fixes

**Status:** done -- waiting for the user to play it
**Started:** 2026-10-01 · **Finished:** 2026-10-01
**Answers:** [play-test 9](../playtests/2026-10-01-playtest-9.md); PT9-7 (content) is the user's
pick from five options, after this.

## Goal
Every change lands on `main`. The crew is Knuckles, Needle and Relay unless renamed; bosses 2 and 3
are fights with an escalation and scrap has somewhere to go; unlocks are visible as goals; arms sit
clear of their bodies; the garage and the assembly bay are redesigned; HP pips keep the card's size.

## Scope
- In: the default names and a RENAME action (garage, bay) remembered by the profile; HP pips in
  fixed rows; an UNLOCKS screen with progress and the run's end naming what is next; arms placed
  clear of the chassis (measured); The Pour and the Core escalate at half HP, more machine levels
  as a scrap sink, less late scrap; a new assembly bay and a new garage.
- Out: new content (PT9-7, next).

## Steps
1. Branch, then `main` after every iteration (fast-forward, pushed).
2. Names; pips; unlocks; arms.
3. Bosses and economy (run bot, gate losses).
4. Assembly bay; garage. Screenshots.
5. Suites, docs, merge.

## Acceptance criteria
- [x] verify_run: a RENAME is saved in the action list and replays; the default names.
- [~] Bot: the Core's gate now takes 11 runs (was 3); The Pour's still only 5. Scrap held going
  into the last gate: 36.6 on average (the bot spends; the user had 230 -- two more levels to buy).
- [x] Screenshots: `shots/027/bay.png`, `garage.png`, `shots/027_unlocks.png`,
  `shots/027_arms_compare.png`.
- [x] Every suite passes; `main` holds it all.

## Result

- **`main`**: fast-forwarded to everything from 024 on and pushed (`origin/main` was the old
  battler); every iteration now ends there.
- **Names**: Knuckles, Needle, Relay (the Wall's Lancer became Longshot); `RENAME` in the bay (a
  name field on the lift) and the garage (RENAME); the profile remembers names per crew.
- **HP pips**: 13 x 9 px, 12 to a row (`PIP_SIZE`, `PIPS_PER_ROW`).
- **Unlocks**: an UNLOCKS screen (title and run end) -- every unlock, what it gives, what earns
  it, a progress bar, held / NEW / NEXT; the title says the next goal and how far.
- **Arms**: measured (`tools/probe_arms.gd`): 78 of 100 frame/arm pairs had more than 12% of
  the arm inside the body, up to 38%; each arm is now pushed out until at most 6% is (0 of 100).
- **Bosses**: The Pour (38 HP) and the Core (46 HP) escalate at half HP -- the Pour floods every
  round, four hexes, for 3; the Core pulses every other round, 3 hexes out, for 5 -- and call three
  guard drones. **Economy**: levels 4 and 5 (65, 95 scrap); late scrap back to the run's own.
- **The bay** is THE CREW / ON THE LIFT / THE BENCH; **the garage** is THE MACHINE / LOADOUT /
  NUMBERS over the hold.

| Run bot, 152 three-act runs | Won | Lost in Act 1 / 2 / 3 | at their gates |
|---|---|---|---|
| 026 | 56.6% | 5.9% / 23.1% / 21.8% | -- |
| escalating keepers, levels 4-5 | 55.9% | 5.9% / 28.0% / 17.5% | 4 / 6 / 3 |
| + Pour 38 HP, Core 46 HP, three guards (**kept**) | **53.9%** | 5.9% / 27.3% / 21.2% | 4 / 5 / 11 |

- Suites: combat 246, input 22, run 152, run UI 49, onboarding 39, save 15, meta 59,
  animation 34, assembly 140.

## Decisions, lessons, open questions
- **Everything lands on `main`**, pushed, at the end of every iteration.
- **Keepers escalate at half HP**; levels go to 5.
- **Names are the player's** (RENAME, remembered per crew).
- Lesson: "arms go through the body" was 78 of 100 combinations by measurement, not a few
  models; a placement rule measured on the real geometry fixed all of them at once.
- Open: is The Pour hard enough (5 gate losses in 110)? Do the new bay and garage read well?

## Next
PT9-7: the user's content pick from five options.
