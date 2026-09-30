# Iteration 023 — The feel pass

**Status:** done -- waiting for the user to listen and play
**Started:** 2026-09-30 · **Finished:** 2026-09-30
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

- **The bank** (`scripts/autoload/audio.gd`) grew from 10 sounds to 26, all synthesised: two new
  shapes (`_buzz`, a chopped swept sawtooth for motors and arcs; `_notes`, short notes in a row)
  and `step`, `shot`, `lob`, `thump`, `zap`, `saw`, `clang`, `pickup`, `warn`, `shield`, `spawn`,
  `flood`, `travel`, `reward`, `win`, `lose`; a four-second looping yard **ambience**
  (`Audio.ambience`), on in the map and the fight.
- **Hooks**: a shot sounds by its kind (an arcing weapon zaps, a saw or claw buzzes, anything
  else clangs; a lob whistles and thumps); every step of a walk; pickups; pads and arrivals
  warn; shields; spawns; travel; a salvage pick; the fight's and the run's end.
- **The Pour** now says what it does: POUR_MARKED and FLOODED float their words, shake and sound
  (021 drew the marks only when the board was next refreshed).
- **The ink star** (`BattleVFX._star_texture`, `shots/023_star.png`): every hit pops a spiked
  amber star with a paper heart and an ink edge, sized by how hard it was; the glow flash is gone.
- **The kill punch** (`combat_scene._punch`): 7% in over 0.07 s, back over 0.3 s.
- **SOUND: ON/OFF** on the title, kept in the profile (`Profile.sound_on/set_sound`).
- `verify_meta.gd` 59 passed: every sound a screen asks for is in the bank (it reads the
  scripts), and SOUND OFF is kept. SUITES.

Not done, and not checkable from here: **nobody has listened to it.** The sounds were written
as waveforms and never heard; levels, pitch and whether the ambience is pleasant need the user's
ears. The star was seen as a texture, not caught mid-hit in a fight.

## Decisions, lessons, open questions
- **Still no audio file in the game**; sound is a switch, not a slider, for now.
- **A kill is the only thing that moves the fight's camera.**
- Open: how does it sound? Which sounds are wrong, too loud, or missing? Is music wanted?

## Next
Act 3; ship prep.
