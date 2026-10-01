# Iteration 027 — Play-test 9 fixes

**Status:** in progress
**Started:** 2026-10-01 · **Finished:** —
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
- [ ] verify_run: a RENAME is saved in the action list and replays; the default names.
- [ ] Bot: the gates of Acts 2-3 take a real share of the losses; scrap at the last gate lower.
- [ ] Screenshots: bay, garage, unlocks, a roster sheet with no arm in a body, crew cards.
- [ ] Every suite passes; `main` holds it all.

## Result

## Decisions, lessons, open questions

## Next
PT9-7: the user's content pick.
