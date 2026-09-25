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

## Screens

| Screen | Purpose |
|---|---|
| Title | continue run / new run / workshop / settings |
| Workshop (meta) | pick crew and tier, codex, run history |
| Region map | zones, the Reclaimer countdown, FORWARD/SIDEWAYS/BACK, preview then TRAVEL, crew (007) |
| Combat | as above |
| Salvage | part cards with a rarity banner and a verdict; always takeable (007) |
| Refit | its own screen: drag or tap parts between sockets, the hold and SCRAP (007) |
| Site screens | workshop, trader, event text |

## Carried over from the old UI

`scripts/ui/ui_kit.gd`, the bundled fonts, the icon set and palette rules (amber = one
primary action per screen) stay. The hub, its tabs and every F2P screen are cut.

## Input and camera

- A fixed tilted camera over the board. Two-finger/wheel zoom and a rotate button that
  snaps in 90° steps. Free orbit is cut: on a grid game it only hides tiles.
- Keyboard: 1–3 select a construct, Q/E pick an action, Z undo, Space end turn.
- Controller support is optional and post-launch.
