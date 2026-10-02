# Iteration 034 — Unlock missions

**Status:** in progress
**Started:** 2026-10-02 · **Finished:** —

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
- [ ] verify_run: a fight's feats match its events (kills = enemy DESTROYED events, and so on);
  feats are the same after a save and replay.
- [ ] verify_meta: feats add up across runs; a mission unlocks when its count is reached and not
  before; every mission names a part that is locked until then.
- [ ] Screenshot of the UNLOCKS screen with missions and progress.
- [ ] All suites; run bot 150, 0 illegal.

## Result

## Decisions, lessons, open questions

## Next
