# Iteration 023 — The feel pass

**Status:** in progress
**Started:** 2026-09-30 · **Finished:** —
**Answers:** the user: "continue with the feel pass and between run progression". Roadmap:
"Audio, camera, final VFX (hit effects in ink)".

## Goal
A fight sounds and lands like the comic it is drawn as: every kind of action has its own sound,
a hit bursts as an inked star, a kill punches the camera in, and the yard has a bed of noise
under it. All synthesised -- still no audio file in the game.

## Scope
- In:
  - **Sound**: a voice per weapon class (saw, shot, lob, coil, blunt), steps, pickups, heat and
    seize, shields, pads and arrivals, the flood, travel on the map, salvage, the run's end (won
    and lost), and a looping yard ambience. A SOUND ON/OFF switch on the title, kept in the profile.
  - **Hits in ink**: an impact is a spiked star, flat paper-and-amber with an ink edge, that pops
    and is gone -- the glow-particle flash goes. Heavier hits, bigger star.
  - **Camera**: a kill punches in and eases back; nothing else moves it (a fixed camera is a
    rule: hidden hexes are hidden information).
  - The Pour's marks and floods get their floating words and sounds (021 drew them silently).
- Out (deliberately): music; new animation; per-part sound.

## Steps
1. The bank: new synth shapes and sounds; ambience; the switch.
2. Hooks: the fight's events, the map, the garage.
3. The ink star; the kill punch.
4. Suites; docs.

## Acceptance criteria
- [ ] Every sound named by a call exists in the bank (a test lists the calls and the bank).
- [ ] With sound off nothing plays; the choice survives a restart.
- [ ] A hit shows the ink star (a screenshot mid-hit); every suite passes.
- [ ] The user listens and plays.

## Result

## Decisions, lessons, open questions

## Next
