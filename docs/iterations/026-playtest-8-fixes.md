# Iteration 026 — Play-test 8 fixes

**Status:** done -- waiting for the user to play it
**Started:** 2026-10-01 · **Finished:** 2026-10-01
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
- [x] Screenshots (`shots/026/fight.png`, `garage.png`): tags at their machines and over the
  hatching; straight arrows and a lob's arch; a full hold with every line inside its card.
- [x] verify_run: caches at least 3 hexes apart (22 defend fights rolled); Act 3 salvage 25 of 63
  rare, an Act 3 elite always offers one.
- [x] Run bot 152 three-act runs, 0 illegal; every suite passes.

## Result

- **Labels**: tags drawn at `render_priority` 10, above the hatching that hid HP (PT8-4); a group
  never moves more than its own height (PT8-3: a tag had climbed to the banner). The scrap mark is
  gone (PT8-2): a carrier has a small green bundle of bolts at its ring, and its info says whether
  it drops a pile.
- **The opening card** stays 5 s (`OPENING_SECONDS`).
- **PT8-1** is answered in the play-test notes; the board now labels the hex where a beam ENDS and
  the preview says "the beam goes N hexes, then stops; past R it does half damage".
- **Attack lines**: a ribbon with an arrow head, over the machines; a lob's rises in an arch.
- **Cards**: `UIKit.fit` (wrap, then step the font down until it fits) on every line of a part
  card, the garage's socket rows and lettering, the scrap bin, and the fight's weapon and ability
  cards (ability cards 6 px taller). Verdicts shortened ("BEATS MULE'S PULSE EMITTER", "NOT RARER
  THAN YOURS"). The garage opens behind a cover until its machine is drawn; the lettering over the
  bay sits on a dark wash.
- **Balance** (PT8-7/8): Acts 2 and 3 roll salvage, scrapyards and traders with their own rewards
  (35/45/20 and 10/45/45 by rarity; an Act 3 elite always offers a rare); The Pour 22 -> 30 HP, the
  Core 28 -> 36, and each act's arming reaches its keeper; caches roll 3+ hexes apart.

| Run bot, 152 three-act runs | Won | Lost in Act 1 / 2 / 3 (of those reaching it) |
|---|---|---|
| 025 | 66.0% (150 runs) | 8.0% / 15.2% / 15.4% |
| rares, keepers, caches | 71.7% | 5.9% / 14.7% / 10.7% |
| + Acts 2-3 enemies +2 HP, Act 3 hits 2 harder (**kept**) | **56.6%** | 5.9% / 23.1% / 21.8% |

  With rare parts the crew outgrew the later acts; now Acts 2 and 3 are where runs are lost,
  as the user asked (Act 1 unchanged).
- Suites: combat 243, input 22, run 147 (+3), run UI 48, onboarding 39, save 15, meta 59,
  animation 34.

Not done: the garage's layout itself is unchanged (cards, cover and lettering only).

## Decisions, lessons, open questions
- **Later acts pay in rares and hit harder**; the keepers carry their act's arming.
- **Text is fitted, not trusted**: `UIKit.fit` on every card line.
- Lesson: letting labels move both ways without a limit traded one bug (a tag on its machine's
  body) for a worse one (a tag at the banner). Bound every automatic layout move.
- Open: is 56.6% right? Does the garage need a new layout, not just fitted cards?

## Next
The user plays; the crew names are still waiting for a pick.
