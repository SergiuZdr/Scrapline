# Iteration 034 — Unlock missions

**Status:** done -- waiting for the user to play it
**Started:** 2026-10-02 · **Finished:** 2026-10-03

## Goal
Play-test 10, PT10-6: "unlocks need diverse missions to get some parts". Unlocks so far ask for
four counts (runs, fights won, the act reached, runs won). After this, most of 033's new modules
are earned by doing something in a fight -- a flawless win, two kills with one attack, enemies in
pits, objectives of each kind, the warlords -- and the UNLOCKS screen shows each mission's
progress.

## Scope
- In: `RunState.feats`, tallied by `RunSim` from every fight's event stream (the same replay
  that decides the fight); `Meta.stats_after` adds them to the lifetime stats, so a mission is an
  ordinary unlock condition (`"when": {"flawless": 1}`); nine missions in `data/meta.json`, each
  unlocking one of 033's uncommon-or-better modules (the commons stay open from the start).
- Out: missions that need state across runs beyond counts (streaks); cosmetic rewards.

## Feats
`kills`, `multi_kill` (one attack destroys two or more), `pit_kills`, `bumps` (an enemy shoved
into something), `tears` (arms torn), `flawless` (a fight won with no crew HP lost), `close_calls`
(won with a machine on 2 HP or less), and wins by kind: `defend_wins`, `salvage_wins`,
`hold_wins`, `hack_wins`, `survive_wins`, `elites`, `arenas`, `warlords`, `gates`.

## Steps
1. Feats in the sim, from events; tested on a real fight.
2. Lifetime stats and the missions; the locked list.
3. The UNLOCKS screen and the run-over screen read them (they already show `text` and progress).
4. Suites, bot, docs.

## Acceptance criteria
- [x] verify_run: a fight's feats match its events (kills = enemy DESTROYED events, and so on);
  feats are the same after a save and replay.
- [x] verify_meta: feats add up across runs; a mission unlocks when its count is reached and not
  before; every mission names a part that is locked until then.
- [x] Screenshot of the UNLOCKS screen with missions and progress.
- [x] All suites; run bot 150, 0 illegal.

## Result

- `RunState.feats`, counted by `RunSim.tally_feats(feats, result, kind)` over the replayed fight's
  events right after the replay that decides it; `Meta.stats_after` adds them to the lifetime
  stats (all keys kept). A mission is an unlock whose `when` names a feat, marked `mission: true`.
- Nine missions, each unlocking one of 033's modules (the three new commons are open from the
  start): flawless win -> Repair Drone; 8 bumps -> Hydraulic Ram; 2 pit kills -> Gyro Anchor; a
  double kill in one attack -> Belt Feeder; 2 HOLD wins -> Sprint Pistons; 2 HACK wins -> Spotter
  Uplink; 3 DEFEND wins -> Arc Relay; 2 wins with a machine on 2 HP or less -> Scrap Leech; 3
  warlords -> Phoenix Cell. 21 parts start locked (12 + 9).
- UNLOCKS: three columns -- MILESTONES down two, MISSIONS in the third -- with progress bars
  (`shots/034/unlocks.png`).
- Suites: run 177 (+2), meta 72 (+4 and two counts now read from data), combat 288, the rest
  unchanged. A bot run's feats, e.g. seed 99: 100 kills, 50 tears, 6 multi kills, 5 flawless, 3
  hold and 3 hack wins, 1 warlord; replayed identically.
- Run bot: 56.7%, identical to 033 run for run -- missions lock parts only for a real profile; the
  bot plays with every part, as before.

## Decisions, lessons, open questions
- Feats are counted from the event stream, never kept on the side by the screens: the save is the
  action list, so a resumed run must recount exactly (it does: the replay check).
- The commons stay open: variety should show on the first run; missions gate the uncommon-and-up.
- Open: are the missions the right difficulty (a flawless win is easy early; three warlords is a
  long goal)? Would the user rather missions unlock crews and tiers too?

## Next
035: the interactive pass.
