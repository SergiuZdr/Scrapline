# Iteration 026 — Play-test 8 fixes

**Status:** in progress
**Started:** 2026-10-01 · **Finished:** —
**Answers:** [play-test 8](../playtests/2026-10-01-playtest-8.md), every item.

## Goal
Labels that never leave their machine and are never covered; a loading card that can be read;
a garage and fight cards whose text always fits; later acts that pay in rare parts and bosses
that are real fights; defend caches that one lob cannot take together; enemy attacks drawn as
arrows (straight or arched) that say what they do.

## Scope
- In:
  - **Labels** (PT8-2/3/4): the scrap mark goes; a carrier wears a green scrap bundle on its own
    ring (on the ground, with it) and says so in its info; tags never move more than their own
    height; every tag is drawn above hatching, marks and badges.
  - **The opening card** stays 5 s (PT8-5).
  - **Pierce** (PT8-1): the beam's last hex is marked (BEAM ENDS) and the preview says when
    a target is past its range (half damage).
  - **Cards** (PT8-6): one helper that shrinks a label's font until it fits its box
    (`UIKit.fit`); hold cards, socket rows and the fight's weapon/ability cards use it; the
    garage opens on a cover until its machine has been drawn.
  - **Balance** (PT8-7/8): salvage and elites lean rare in Acts 2-3; The Pour and the Core
    tougher; caches rolled at least 3 hexes apart; tuned with the run bot.
  - **Attack lines** (PT8-9): every enemy line has an arrow head; lobs arch.
- Out: new models; a garage layout from scratch (the card and loading passes only).

## Steps
1. Labels, card, pierce marks, attack arrows (scene).
2. `UIKit.fit`; garage cards and cover; HUD cards.
3. Balance data and cache spacing; run bot; suites; docs.

## Acceptance criteria
- [ ] Screenshots: a crowded board with every tag at its machine and over the hatching; a lob's
  arched arrow; the garage with a full hold, no text past its card; the fight's cards.
- [ ] verify_run: caches are at least 3 hexes apart; Acts 2-3 salvage offers rares.
- [ ] Run bot 150 three-act runs, 0 illegal; the result recorded; every suite passes.

## Result

## Decisions, lessons, open questions

## Next
The user plays.
