# Iteration 086 — Builds that change rules

**Status:** done
**Started:** 2026-11-01 · **Finished:** 2026-11-02
**Answers:** the engagement review (`docs/plans/engagement-review.md`) and the user's answers of 2026-10-22.

## Goal
A level-up, a set, a legendary, a starter arm or a trophy changes what a machine does, and an elite is a different problem, not a bigger number.

## Scope
- In:
  - **T1** a RunBot that chooses perks and salvage by a dry run on the next fight; **T2** a trait-ownership table (perks, sets, legendaries, modules: who gives pierce, tears, arc, mark).
  - **A7** trophies: one salvage option is a part you tore off an enemy (TORN FROM THE TRACKER).
  - **A8** rule perks (Rending Grip, Spotter, AP Rounds, Scavenger, Barbed Hull); every level offer holds one.
  - **A9** legendaries from gate keepers only (the user), each a strong rule plus a visible drawback; warlords give a rare and scrap; SCRAP instead at hoards.
  - **A10** maker sets: 3 pieces of one maker give a verb (the user): Kessler thorns + unshovable, Arclight arc, Vektor pierce, Cinder tears; heat leaves the sets.
  - **B6** no dead arm in the starting kit (Saw stops copying the Cleaver); Focus gets a price (its own A/B).
  - **A5** elite affixes: volatile, rigged, bulwark; shown on the map node and as a tag; elite HP bonus down.

## Acceptance criteria
- [x] balance_fights (rule-perk share not met, see Result) --arms 150: no byte-identical rows, no legendary above +15; T1's bot picks a rule perk over half the time; every elite carries one affix, HP lost per elite 1.5-2x a skirmish; run_bot 150 reported.

## Result

### Summary
Three agents in parallel (V1 the run: spoils, rule perks, hoards, affix rolls, the T1 bot; V2 combat: legendary
rules, set verbs, affixes, the Saw and Focus; V3 the screens), then the user's picks applied on top.

`tools/check.sh --fingerprint` after the picks: verify_combat 428/0, verify_combat_input 52/0 (after the limit
change below), verify_run 332/0, verify_run_ui 124/0, verify_save 43/0, verify_onboarding 55/0, verify_meta
109/0, verify_assembly 168/0, verify_animation 38/0. Fingerprint TOTAL bdbf204e -> 23462268 (the rules and the
bot's choices changed on purpose).

- **A7 spoils:** a won fight's salvage shows a part torn off or out of an enemy as a FOURTH card, TORN FROM THE
  BRUTE (the user; V1 built it in place of the last card). 97% of fight rewards carry one (aim 70%+).
- **A8 rule perks:** Rending Grip (tears, any weapon), Spotter (mark), AP Rounds (shots pierce, other weapons
  +1), Scavenger (heal 2 per kill), Barbed Hull (thorns 1) replace Heat Sinks and Coolant Jacket; every level
  offer holds one; no slot `needs`; drawn build-weighted (the user).
- **A9 legendaries:** only from both gate keepers' hoards (the user: both always); warlords give a rare and
  scrap, the refinery stops at rare, the auction and Act 3 salvage give none. Each legendary has a rule and a
  drawback (table in `plans/parts-power.md`).
- **A10 sets:** 2 pieces a small stat, 3 pieces a verb: KESSLER thorns + anchored, ARCLIGHT arc, VEKTOR pierce,
  CINDER tears on every weapon (the user). No set touches heat.
- **B6:** the Saw tears at 4 (no longer a copy of the Cleaver); Pulse 3 damage; Focus costs 1 heat.
- **A5 affixes:** an elite's veteran carries VOLATILE (blast 5), RIGGED (keeps arms, anchored) or BULWARK
  (front plate 3, faced at the nearest crew machine from round 1); Act 1 rolls the first two. Elite HP bonus 2,
  elite scrap 14.
- **T1:** `RunBot.choose` dry-runs the next fight's first 3 rounds for perks and salvage (`bot.choose dry|old`).
- **T2:** the trait-ownership table in `plans/parts-power.md`.

### Measured
- Arm trial (`--arms 150`, points vs the average arm), before -> after: Sunspear +26.3 -> +15.5 (interval
  +6.9..+24.1; the user: leave it), Godhammer +21.7 -> +12.8, Saw/Cleaver +1.7/+1.7 (identical rows) -> +6.1/+2.8,
  Pulse -13.0 -> +0.8, Hammer -1.7 -> -1.9. No byte-identical rows.
- Focus A/B, uses per carrier per fight: free 1.06, **1 heat 0.95 (shipped)**, 2 heat 0.99, takes the move 0.18.
- Affixes, crew HP lost per random fight (4.3 plain): rigged everywhere 1.1x, bulwark (plate 2) 1.2x, volatile
  everywhere 3.1x, volatile on one 1.5x. BULWARK went to plate 3 and RIGGED anchored after (the user).
- T1 bot takes a rule perk at 39.2% of level-ups (aim over 50%): **not met** -- 3 rounds undervalue rules.
- run_bot 150 (V1's build, before the user's picks): 56.0% (48-64) vs 57.3%; legendaries 1.34 offered, 0.61 fitted,
  6.8% of sockets. After the picks: BOTNUMBERS
- The 2x enemy-turn gauge on slag_pit read 1836 ms (limit 1800). 086's code on 085's data plays it in 1586 ms:
  the new data changed what that turn holds, no beat grew. The limit for this fight is 1.9 s.

### Not met
- T1's rule-perk share (39% < 50%).
- Fights costing no HP at rung 10 (carried from 085).

## Decisions, lessons, open questions

## Next
087: every round counts.
