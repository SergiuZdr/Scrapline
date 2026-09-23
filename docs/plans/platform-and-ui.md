# Plan — Platform and UI (PC and mobile together)

**Status:** draft (Iteration 000). Input model built in 002.

## Rules

1. **Every interaction works with tap alone.** No hover-only information, no right-click-only
   actions, no drag-only actions. Mouse hover *adds* previews; it never gates them.
2. **Touch targets ≥ 48 px** at 1080p-equivalent. Grid tiles are sized so an 8×8 board
   fills a phone's landscape height.
3. **Landscape only**, one layout that scales. A 16:9 phone and a 21:9 monitor both work
   by widening side panels, never by reflowing the board.
4. **Selection model:** tap a unit to select → tap a tile to preview → tap again to confirm.
   A double confirm on phones prevents fat-finger moves; PC can enable one-click commit in
   settings.
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

- Crew cards reuse the **part-thumbnail strip** idea from the old Order Phase HUD.
- The damage preview shows the final number *after* the type wheel, cover and marks, with
  the part that will take damage highlighted.

## Screens

| Screen | Purpose |
|---|---|
| Title | continue run / new run / workshop / settings |
| Workshop (meta) | pick crew and tier, codex, run history |
| Region map | move between sites, see the front, fog, cargo |
| Combat | as above |
| Salvage/refit | pick rewards; drag or tap parts between constructs and cargo (reuses the old loadout screen's 3D preview) |
| Site screens | workshop, trader, event text |

## Carried over from the old UI

`scripts/ui/ui_kit.gd`, the bundled fonts, the icon set and palette rules (amber = one
primary action per screen) stay. The hub, its tabs and every F2P screen are cut.

## Input and camera

- A fixed tilted camera over the board. Two-finger/wheel zoom and a rotate button that
  snaps in 90° steps. Free orbit is cut: on a grid game it only hides tiles.
- Keyboard: 1–3 select a construct, Q/E pick an action, Z undo, Space end turn.
- Controller support is optional and post-launch.
