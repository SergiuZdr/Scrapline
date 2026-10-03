# Iteration 039 — The comic, all the way

**Status:** in progress
**Started:** 2026-10-03 · **Finished:** —

## Goal
The user, after 038: "I love all the suggestions from the comics list." 036 printed the world on
paper; this makes the game READ as a comic in every layer -- how it talks to the player, how it
shows the enemy's mind, how hits and moves land, how screens are framed, and how the story is told.

## Scope (the eight suggestions)
1. **Speech balloons**: the fight's info panel and every first-time hint are balloons with a TAIL
   pointing at what they talk about (the machine selected or aimed at; the hint's spot).
2. **Thought balloons for intents**: each enemy's order badge sits in a thought cloud with puffs
   trailing to its head.
3. **Sound-effect lettering** on every hit, by damage type (KRANG! kinetic, WHOOMPH! thermal, FZZT!
   EMP, HSSS! corrosive; WHAM! melee, THUD! bumps), one word per attack.
4. **Speed lines** behind a machine that moves or charges; **focus lines** around a heavy hit.
5. **Panel framing**: the board inside a thick inked panel border; every scene change is a page
   turning (a paper panel wipes across).
6. **Comic pages**: site windows, the garage and the run's end with caption-box titles set at a
   slant, panels with hard ink borders.
7. **Models**: uneven ink lines, cross-hatching in the shade band, a white rim highlight.
8. **Story beats**: an act's arrival and a boss's entrance told in comic panels.

Out: new 3D models (the models change by shading and line only); controller support.

## Acceptance criteria
- [ ] Screenshots of each of the eight on screen.
- [ ] `measure_contrast.gd`: machines vs. surround no lower than 038 (it may only grow).
- [ ] `measure_hitches.gd`: no new long frames from the new effects (they are drawn once behind the
  opening card).
- [ ] All suites pass (no rules change: the run bot is 038's).

## Result

## Decisions, lessons, open questions

## Next
