# Iteration 013 — Act 1 content

**Status:** done (the last of the 009–013 batch; the user's play-test follows)
**Started:** 2026-09-26 · **Finished:** 2026-09-26
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
- [x] verify_combat: pylons shield the Sorter by 3 and stop when broken; pylons never act and
  do not count for ROUT; the Sorter's pad calls drones on schedule; Reclaimer arrivals are
  marked a round ahead, spawn on schedule, are blocked by a machine standing there.
- [x] verify_run: the gate fight is the Sorter's map; a fight in the column the front takes next
  carries Reclaimer drones and one further forward does not; trader buy/sell prices and hold
  rules; a tower scouts two columns; every event's options are legal or refused as stated, and
  apply exactly their stated effects; the bot plays all of it with no illegal action.
- [x] verify_run_ui: a signal choice, a trader purchase and sale, a tower's panel by clicks.
- [x] run_bot 150 and balance_fights 600 recorded; the win rate stays within 85-92% (90.0%).
- [x] Screenshots: the Sorter's fight, a Reclaimer arrival, each new site's panel
  (`shots/013_*.png`, `shots/013_sheet.png`).

## Result

| Suite | Result |
|---|---|
| verify_combat | **163** passed (140): the Sorter's pylon shield (3 off, until both are broken), pylons as props that neither act nor count, its pad every 3 rounds; Reclaimer arrivals (marked round 2 on the back row, spawned round 3, one blocked by a machine, none without the reach); bot fights on the three new maps, the gate and the shakedown |
| verify_run | **124** passed (107): the gate map with the Sorter, pylons and 3 escorts, building clean; the reach (next column yes, further no); the trader (stock of three with one tuned, price, no double buy, sell at 2x, LEAVE); the watchtower (two columns scouted); **every option of every signal applies exactly its stated effects**; a scrap cost refused when short; no event repeats until all are met |
| verify_run_ui | **48** passed (42): buying from and selling to a trader, a watchtower, a signal option by clicks |
| verify_onboarding / combat_input / save / assembly / animation | 39 / 20 / 15 / 100 / 34 passed |

**Balance** (run bot, 150 runs each, side by side with `--set`):

| Variant | Won |
|---|---|
| **3 escorts at the gate (kept)** | **90.0%** |
| 2 escorts | 91.3% |
| 4 escorts | 90.0% |

0 illegal actions in all 450 runs. 8.2 moves and **5.2 fights won** a run (5.7: some stops are
now traders, towers and signals), 3.4 levels bought. Losses: 9 crews wrecked, **6 gates held**
(the crew alive but the Sorter not broken in 20 rounds), spread over columns 3 to 8 rather than
two thirds at the gate (011). balance_fights: every authored fight 100% for the bot's squad;
random squads **94.3%** on the six run maps (89.5% on the old three) -- the new maps are ROUT in
that tool, and objective losses were most of its losses; in a run the objective is rolled.

### Found on the way
- **A new prop drew as a crate**: `PROP_PLACED` carried "barrel or not" as its value, so the
  pylons were placed in the sim and drawn as crate stacks. The event now carries an index into
  `GridEv.PROP_KINDS`.
- **The fight-balance tool counted the tutorial's board** as a place random squads meet (97%).
  It samples the run's maps only now.
- The standalone gate fight is won by the bot's squad with almost no damage taken (1.4 a fight):
  its opening lets the crew dodge every intent. In runs the gate still holds 6 times in 150.

### Different from the plan
- **No new parts**: blocked on the roster generator question (010).
- Escort count turned out not to be the gate's dial (90.0 / 91.3 / 90.0): the pylons and the
  20-round limit are.

## Decisions, lessons, open questions
- **Pylons are props, not units**: they block and break like crates and never act, so none of
  the unit rules (objectives, AI, ROUT) had to learn about them.
- **Every signal states its cost and gain on its button**; no hidden dice. A choice made
  without the information is a guess, not a decision.
- **Kinds that build share one pad**: the Sorter reuses the hive's pad with its own pace.
- Open for the play-test: is the Sorter a climax (break the shield, burst the keeper), and do
  signals, traders and towers make the map feel less empty (PT4-8)?

## Next
The user's play-test of 009–013. Then 014, Acts 2–3.
