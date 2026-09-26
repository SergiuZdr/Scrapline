# Iteration 013 — Act 1 content

**Status:** in progress (the last of the 009–013 batch; the user's play-test follows)
**Started:** 2026-09-26 · **Finished:** —
**Answers:** play-test 4, PT4-8 ("the map feels a bit empty"), the proposals recorded in
[009](009-playtest-4-fixes.md) (signals, watchtowers, traders), and MEMORY's open question
about the gate ("a climax or a wall?"): the gate becomes a real boss.

## Goal
Act 1 is a place with things to find and a fight at the end worth reaching: the map offers
events with choices, traders and watchtowers besides fights; the Reclaimer reaches into
fights fought near its line; three more yards to fight in; and the Sorting Gate is held by a
boss with rules of its own.

## Scope
- In:
  - **The Sorter** at the gate (`data/fights/sorting_gate.json`, enemy kind `sorter`): a heavy
    machine behind two **gate pylons**. While a pylon stands, the Sorter takes 3 less from every
    hit (a red beam from each pylon shows it); every 3 rounds it calls a drone from a pad beside
    it (the hive's pad, warning a turn ahead). Escorts are rolled as before. Pylons are enemy
    objects: they do not act and do not count for ROUT.
  - **The Reclaimer reaches in**: a fight at a site in the column the Reclaimer takes next gets
    its drones -- at round 3 they arrive on the crew's back row, on hexes marked red at round 2
    (stand on one to block it). Lingering by the line costs inside fights too.
  - **New sites** (weights in `run.json`):
    - **Trader**: three parts for sale (priced by rarity) and buys parts from the hold for twice
      what breaking them down pays.
    - **Watchtower**: climbing it scouts every site within two columns.
    - **Signal**: an event from `data/run/events.json` -- a short scene and two or three choices
      with their costs stated up front (scrap, HP, a part, a tuned part, a fight, scouting,
      the Reclaimer moving). Never a hidden dice roll.
  - **Three more fight maps** (pit row, crane legs, slag channel).
  - Landmarks, icons and panels for the new sites; the run bot uses them; story text.
- Out (deliberately):
  - **New parts**: they need models, and the roster generator no longer reproduces the
    committed roster (010's open question). Blocked until the user settles which is right.
  - Acts 2 and 3 (014).

## Steps
1. Sim: pylons and the `sorter` kind (armour while pylons stand, summons), Reclaimer arrivals
   in `CombatSetup`/`CombatSim`; tests in verify_combat.
2. Run: the boss fight from the gate map; Reclaimer drones for fights by the line; trader,
   tower, signal sites and their actions (`BUY`, `SELL`, `CHOOSE`, `LEAVE` for any site
   panel); events data; tests in verify_run; the bot.
3. Presentation: pylons, beams, the Sorter's size, arrival hexes; landmarks and panels.
4. Maps; run bot and balance; screenshots; docs; merge; ask the user for the play-test.

## Acceptance criteria
- [ ] verify_combat: pylons shield the Sorter by 3 and stop when broken; pylons never act and
  do not count for ROUT; the Sorter's pad calls drones on schedule; Reclaimer arrivals are
  marked a round ahead, spawn on schedule, are blocked by a machine standing there.
- [ ] verify_run: the gate fight is the Sorter's map; a fight in the column the front takes next
  carries Reclaimer drones and one further forward does not; trader buy/sell prices and hold
  rules; a tower scouts two columns; every event's options are legal or refused as stated, and
  apply exactly their stated effects; the bot plays all of it with no illegal action.
- [ ] verify_run_ui: a signal choice, a trader purchase, a tower's reveal by clicks.
- [ ] run_bot 150 and balance_fights 600 recorded; the win rate stays within 85-92%.
- [ ] Screenshots: the Sorter's fight, a Reclaimer arrival, each new site's panel, the map
  with the new landmarks.

## Result
(filled in on completion)

## Decisions, lessons, open questions
(filled in on completion; also copied into MEMORY.md)

## Next
The user's play-test of 009–013. Then 014, Acts 2–3.
