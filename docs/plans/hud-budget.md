# Plan — The fight screen's budget (T3, 087)

What the fight may show at once, which layer wins when the board is crowded, and what yields.
Written before A12 (damage explained), A17 (CANCELLED), A18 (consequences while aiming), A4b (hot
ground) and A3 (reinforcement waves) landed, so each of them had to find a place inside it instead of
on top of the others. Anything new on the fight screen names its layer here first.

## The rule

**One question at a time gets the loud channel.** The screen has three states, and each owns
one loud layer; everything else is quiet (floor, small, ink) or gone.

| State | The loud layer | What it answers |
|---|---|---|
| **Planning** (your turn, nothing armed) | the enemy's intents: red hexes, numbered thought clouds, volley totals | What will hit me if I end the turn now? |
| **Aiming** (a target tapped once) | your action: amber target hexes, amber totals, the preview balloon, the consequences (A18) | What does this shot do, all of it? |
| **Playback** (events running) | the beat on screen: one lettered word, one float, the hit-stop | What just happened? |

The loud layer of one state is never drawn in another: intent lines are cleared while events
play (they would lie mid-volley), consequence ghosts exist only while a target is aimed, and a
beat's lettering is gone before the next turn's marks come back.

## The layers, by priority

Higher wins when two want the same pixels. "Yields" says what the lower one does.

| # | Layer | Where | Budget | Yields how |
|---|---|---|---|---|
| 1 | **The playback beat** (KRANG!, CANCELLED −7, INTO THE PIT) | over the machine | one lettered word per cause; at most one hit-stop per 0.62 s (`BattleVFX.HITSTOP_COOLDOWN`) | n/a: it is alone (playback clears every mark) |
| 2 | **Aimed preview balloon** (HUD) | right panel | title + at most: drawback lines, the AIMED target's explanation line, one line per other machine hurt, the overheat line | other machines' lines keep their short "(4 + 3 blast)" form; only the aimed target gets the step-by-step line |
| 3 | **Amber totals and KO** on the board | far edge of each hex the shot hurts | one disc per machine | the enemy's red volley total on the same hex sits at the near edge, so both read |
| 4 | **Consequence ghosts** (A18, aiming only) | the hex a machine would be moved to | one ghost per moved machine; one dashed line per intent that re-aims | not drawn for the aimed target itself when it dies (the KO says it) |
| 5 | **Intent clouds** (order · −damage) | over each enemy's head | one cloud per enemy | `_declutter` moves tags, never clouds; in the aimed state they stay (they are what the shot can cancel) |
| 6 | **Red threat hexes, volley totals** | floor, near edge | one total per hex (`CombatSim.incoming`) | full lines only for the tapped enemy, shots at the selected machine, or LINES |
| 7 | **Machine tags** (HP, name, statuses) | over each machine | HP line + one status line; an elite's affix word above | shifted by `_declutter` (at most a tag's height up or down, half its width sideways) |
| 8 | **Board labels** (DRONE NEXT TURN, ESCORT NEXT ROUND, FLOODS NEXT TURN) | at a hex's near edge, flat | 24-40 px, one per marked hex | never over a machine's tag (they sit under the hex) |
| 9 | **Floor states** (slag, flooded slag, mines, hot ground) | the tile itself | drawn as floor: no text, no outline, no red | never yields: it is the ground |
| 10 | **The objective line** (HUD, top) | top plate | one line: the objective, then its clocks ("2 WAVES LEFT", "3 rounds left") | a clock is dropped before the objective is shortened |

## Colours the layers may use

From the reserved colours (`art-and-audio.md`): **red** only for what will hit you (intents,
threat hexes, enemy marks to block); **amber** for your action (aim, your totals, KO, and the
CANCELLED beat: the shot you cancelled is your doing); **copper** for machine condition; floor
states are told apart by **texture and value**, never by a signal colour. Hot ground is a
scorched, heat-shimmered plate: dark umber-black with a pale shimmer, so in grey it is a darker
hex with a moving light ripple, unlike slag (a lit pool) and unlike a mine (a disc with lamps).

## What the new items get (087)

- **A12, damage explained.** The aimed target only, one line, in the balloon:
  `NAME  5 → 3 (−2 armour, −1 cover, +1 marked)`. From `CombatSim.damage_steps`; a step of 0 is
  left out; the line is dropped when the only step is the base. Other machines in the blast keep
  the short form. Never on the board (the board has the total).
- **A17, CANCELLED.** A playback beat (layer 1): the enemy's thought cloud comes back for the
  beat, struck through, with `CANCELLED −7` in amber over it, its own sound, and the rare
  hit-stop (the cooldown decides; two cancels in one blow give one freeze). Held 0.45 s of game
  time, so 2x and 3x shorten it with everything else.
- **A18, consequences.** Aiming only (layer 4): a ghost of each machine the shot would move (a
  shove, a pull) on the hex it ends on, a pit drop shown as a ghost sunk into the pit; a dashed
  red line from each enemy whose intent would aim somewhere else after the shot, to its new end.
  Cleared the moment the aim is dropped.
- **A4b, hot ground.** Floor (layer 9). The heat it adds is said in the terrain info when the hex
  is tapped, never painted on the hex.
- **A3, reinforcements.** The wave mark is layer 8 (a ghost and a label at the hex, as the escort's);
  the count is a clock on the objective line (layer 10): `· 2 WAVES LEFT`.

## When it is still too much

In this order, until it fits: drop full intent lines (keep hexes and totals) → shorten board
labels to their first clause → let tags overlap (they already stop shifting past their own
height) → in the aimed state, hide intent clouds of enemies the shot cannot touch. The objective
line and the aimed preview are never cut.
