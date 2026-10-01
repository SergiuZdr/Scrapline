# Iteration 031 — Sites and events

**Status:** done -- waiting for the user to play it
**Started:** 2026-10-01 · **Finished:** 2026-10-01

## Goal
The map offers more kinds of decision between fights: three new sites (the arena, the refinery,
the auction) and twenty new signal events, so a run is not the same five stops every time
(play-test 9: "the game feels like it has too little content").

## Scope
- In: `arena` (a harder fight -- elite plus `arena_extra` -- for `arena_scrap` 35 and an elite's
  salvage); `refinery` (`[REFINE, cargo]`: a part in the hold becomes a random part of the next
  rarity, same slot, for `refinery.costs`; a rare becomes a legendary); `auction` (`[BID, tier]`:
  a blind crate, two tiers, a `legend_pct` chance of a legendary). Twenty new events in
  `data/run/events.json`. Each new site on the map (a landmark, a name, a panel), in the bot, in
  the story text.
- Fix: a signal's "uncommon or better" could hand out a legendary (`_roll_at_least`).
- Out (deliberately): a convoy site (a moving target needs map rules of its own); new event
  effects (every new event uses the effects that exist).

## Steps
1. Sim: REFINE, BID, the arena as a fight type; site weights in `run.json`.
2. Events: twenty more, from the existing effect vocabulary.
3. UI: refinery and auction panels; map names, hover lines, landmarks.
4. Bot: refines its best hold part when it can pay, bids the better tier it can afford, takes
   an arena when healthy.
5. Tests, screenshots, bot.

## Acceptance criteria
- [x] verify_run: refining changes the part's rarity by one in the same slot and costs the price,
  once per visit; a bid costs its tier and adds a part of at least its rarity, once per visit;
  an arena fight has more enemies than a skirmish in the same column; every event is reachable
  and valid.
- [x] All suites pass; screenshots of the refinery and the auction.
- [x] Bot 150 runs, 0 illegal.

## Result

- Suites: combat 276, combat_input 22, run 170 (+6), run_ui 49, onboarding 39, meta 59, save 15,
  assembly 140 -- all pass. Screenshots: `shots/031/refinery.png`, `shots/031/auction.png`.
- **Run bot: 58.0%** (63.8% at 030), 0 illegal, 11.5 fights a run. Lost in Act 1 / 2 / 3:
  14.7% / 19.5% / 15.5% (5.3 / 22.9 / 12.6 before); gate losses 8 / 9 / 4; scrap going into the
  last gate 33.3.
- The first bot batch (8 processes x 19 runs) hit the one-hour limit: a run takes ~55 s alone and
  ~5 min with 15 sharing the CPU. Split into 15 x 10 it finished in about an hour.

## Decisions, lessons, open questions
- The arena is rolled like an elite and pays like one plus 15 scrap; the bot takes it when healthy,
  which is why Act 1 losses tripled -- the bot's policy as much as the site.
- Legendaries come only from hoards, the refinery (rare in) and the auction.
- Open: is Act 1 now too hard for a player who takes arenas early? Does the refinery make the
  Act 3 crew too strong? The user plays.

## Next
The content series (028-031) is done; the next iteration follows the user's play-test.
