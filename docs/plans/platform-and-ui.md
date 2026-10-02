# Plan — Platform and UI (PC and mobile together)

**Status:** draft (Iteration 000). Input model built in 002.

## Rules

1. **Every interaction works with tap alone.** No hover-only information, no right-click-only
   actions, no drag-only actions. Mouse hover *adds* previews; it never gates them.
2. **Touch targets ≥ 48 px** at 1080p-equivalent. Grid tiles are sized so an 8×8 board
   fills a phone's landscape height.
3. **Landscape only**, one layout that scales. A 16:9 phone and a 21:9 monitor both work
   by widening side panels, never by reflowing the board.
4. **Selection model (003, replacing 002's tap priority):** tap a friendly construct →
   MOVE mode (blue tiles; tap one to move). Tap a weapon button in the bottom bar → that
   arm is ARMED (yellow targets; a lob shows its landing tiles). Tap a target to aim (the
   panel lists every hit, kills, torn arms and overheating) → tap it again to fire. Tap the
   armed weapon again to go back to moving. Keyboard: 1–3 select, TAB weapon, V vent.
   Modes exist because a lob's landing tile is often a tile you could walk to.
5. **Undo is a big, always-visible button.** Plans are provisional until the turn ends.

## Combat screen layout (landscape)

```
┌──────────┬─────────────────────────────┬──────────┐
│ CREW     │                             │ TARGET / │
│ cards ×3 │        8×8 board            │ PREVIEW  │
│ (parts,  │   (tilted 3D camera,        │ panel    │
│ HP, heat)│    intents drawn on tiles)  │          │
├──────────┴─────────────────────────────┴──────────┤
│  actions of the selected construct (from parts)  UNDO  END TURN │
└───────────────────────────────────────────────────┘
```

- **The action bar (007)** is two rows between the camera buttons and UNDO, so it can never
  run under them: ABILITIES (compact, blue edge) above WEAPONS (large, amber edge). Each
  button says FREE / USES ACTION and COOLDOWN n, or why it cannot be used; text wraps.
- **Intents are quiet by default (007)**: red target hexes and numbered badges. Full lines
  only for the enemy you tap or intents aimed at the selected machine; LINES (L) shows all.
- Crew cards reuse the **part-thumbnail strip** idea from the old Order Phase HUD.
- The damage preview shows the final number *after* the type wheel, cover and marks, with
  the part that will take damage highlighted.

## Ink & Rust (016)

- **Comic panels everywhere** (`UIKit`, `InkBox`): paper cards, a 3 px ink border, a hard offset
  shadow; buttons in Anton that drop onto their shadow when pressed; paper lettering with an ink
  edge for anything on the dark page or the 3D world (`UIKit.on_page`).
- **The fight asks for less (review point R5-2)**: the picked machine has the only full card; the
  others are slim rows (name, what they have left, HP). Card lines are short enough to fit.
- **Ability cards say what the ability does** ("move 2 more · free · cooldown 2", from the
  ability's `short`); the full text, effect first, is in the panel when it is armed.
- **Board labels never overlap**: each machine's tag, scrap mark and firing-order badge are one
  group, laid out in screen space every frame (`_declutter`); badges naming what will be hit
  are fixed on the ground. Companions are offset in the billboard's plane.
- **Hints and the coach are the narrator**: a pale caption box.

## Screens

| Screen | Purpose |
|---|---|
| Title | continue run / new run (the first offers the shakedown) / practice fight / tutorial / glossary / quit |
| Workshop (meta) | pick crew and tier, codex, run history |
| Region map | a 3D yard: landmarks, the Reclaimer wall, hover card, one click travels, crew strip, briefing (008) |
| Combat | as above |
| Salvage | part cards with a rarity banner and a verdict; always takeable (007) |
| Garage | replaces refit (008): the machine whole in 3D, PARTS / STATS tabs, hover lights a part, LEVEL UP, the hold as a sorted strip with SCRAP. 009: a real bay behind the machine, no black flash (models load in the background; the stage fades in), the SCRAP square is the button, levelling up is an event |
| Assembly bay | (009) after the briefing: build the three machines from a bench of basic parts |
| Site screens | workshop, trader, event text |

## Onboarding (012)

- **The shakedown** (`scenes/shakedown.tscn`, `data/tutorial.json`, `scripts/combat/coach.gd`):
  the real fight with a coach panel and an amber marker (a ring and chevron on the board, an
  outline on a button). A step ends when its thing happened in the event stream, or on NEXT.
- **Tap for meaning**: `Glossary.linkify` makes every term in running text a link (blue,
  underlined); a tap opens its card, the next tap anywhere closes it. Buttons do not carry
  links -- a link inside a button fights its tap.
- **First-time hints** (`Hints.show_once`): one callout per screen, amber-edged, GOT IT once.
- The **profile** (`Profile` autoload) remembers the tutorial and the hints; nothing else yet.

## Carried over from the old UI

`scripts/ui/ui_kit.gd`, the bundled fonts, the icon set and palette rules (amber = one
primary action per screen) stay. The hub, its tabs and every F2P screen are cut.

## Input and camera

- A fixed tilted camera over the board. Two-finger/wheel zoom and a rotate button that
  snaps in 90° steps. Free orbit is cut: on a grid game it only hides tiles.
- Keyboard: 1–3 select a construct, Q/E pick an action, Z undo, Space end turn.
- Controller support is optional and post-launch.

## Play-test 7 (024)

- **The machine under your hand**: an amber ring on the ground and an amber arrow over its tag,
  following it as it walks (amber is the player's action).
- **The opening card**: the board's name and objective, over the board while it is drawn; the
  objective plate is filled before the first event plays. Every effect is drawn once behind it,
  so no effect compiles its shader mid-fight.
- **Totals, not firing order**, on the board: red for what the enemy will do, amber for the aimed
  attack. The preview's list reads from the shooter outwards, the other side first.
- **Names**: crew machines have their crew's names; the frame is said beside them ("Brute frame").

## Play-test 8 (026)

- **Labels**: tags draw over every mark (priority 10) and move at most their own height.
  A scrap carrier carries a green bundle at its ring instead of a mark by its tag.
- **Attack lines** are arrows; a lob's arches over what it flies over. A beam's end is labelled.
- **The opening card** stays 5 s. **The garage** opens behind a cover until the machine is drawn.
- **Every card line is fitted** to its box (`UIKit.fit`: wrap, then a smaller font, then "...").

## Play-test 9 (027)

- **The bay**: THE CREW (cards, names) / ON THE LIFT (the machine, its numbers, a name field) /
  THE BENCH (socket tabs, part cards; once-only parts say so).
- **The garage**: THE MACHINE (bay, name and RENAME, level of 5, HP, LEVEL UP) / LOADOUT / NUMBERS,
  over the hold. No tabs: everything a machine is, at once.
- **UNLOCKS**: from the title and the run's end; every unlock as a goal with a progress bar.
- HP pips: fixed size, twelve to a row.

## Every control answers the hand (035)

The `Juice` autoload gives every BaseButton a hover lift, press squash, release bounce, sounds,
and a "no" shake when disabled -- no screen builds this itself. A control opts out with the meta
`no_juice`.
