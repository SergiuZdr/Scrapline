# Iteration 031 — Sites and events

**Status:** in progress
**Started:** 2026-10-01 · **Finished:** —

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
- [ ] verify_run: refining changes the part's rarity by one in the same slot and costs the price,
  once per visit; a bid costs its tier and adds a part of at least its rarity, once per visit;
  an arena fight has more enemies than a skirmish in the same column; every event is reachable
  and valid.
- [ ] All suites pass; screenshots of the refinery and the auction.
- [ ] Bot 150 runs, 0 illegal.

## Result

## Decisions, lessons, open questions

## Next
