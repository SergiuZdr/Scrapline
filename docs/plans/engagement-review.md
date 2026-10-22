# Scrapline engagement review

*2026-10-22 · build `iter-081-saturation-and-props` (b8cb3d5) · synthesis of a bot-data pass, a screens pass, four hand play-tests, seven design lenses and three skeptic reviews. Nothing here has been judged by the user yet. Bots and agents can measure stakes and choice; only you can say whether it is fun.*

---

## 1. Verdict in five lines

1. **Round 1 of most fights is a real Into the Breach puzzle, and then the fight is over.** All four hand testers decided their fight in round 1 or 2. After that the remaining rounds were cleanup. This matches what you said: "a boring chore" (PT1-1) and "boring and easy" (PT8-7, PT9-3, PT11-15).
2. **Strength 1, the board as a weapon:** grapple into a pit, a pierce through a drum, a shove that turns an enemy's shot onto its ally. These were every tester's best moments.
3. **Strength 2, tearing an arm cancels that arm's attack.** Scrapline's own verb. It is readable and has no dice, and no other game in the genre has it.
4. **Problem 1, dodging is still free.** Only 0.5% of machine turns have no safe hex to stand on (median 26 safe hexes), and only 6% of enemy intents land. A "KILLED" warning goes away with one step, so after round 1 about half of all turns have one obvious answer.
5. **Problem 2, the run's promises are not built yet.** Salvage ignores what you tore off. Perks are flat stats. Elites are a bigger number. Bosses are long and low-threat (the Act 3 boss: 10.2 rounds for 6.9 crew HP lost). The game is readable, but it doesn't yet pay off how you played.

---

## 2. Strong points to protect

| Strength | Evidence (measured or seen) | Genre comparison |
|---|---|---|
| **Fully telegraphed intents with exact numbers and a numbered firing order; previews are real dry runs** (`CombatSim.dry_run` on `CombatState.clone()`) | Hand 1, proto_yard R1: "Relay loses 6 KILLED, Needle loses 8" gave real fear with several ways out. Screens: the "Enemy fire, in order" list and aimed previews that flag "(YOURS)" friendly fire and "fuel drum EXPLODES". Hand 3 avoided 4 friendly-fire mistakes because of the preview. | Matches Into the Breach and goes further: ITB still has one random roll (Grid Defense), Scrapline combat has none. Tactical Breach Wizards had to add previews like these after its playtests. |
| **Board-as-weapon displacement** (pits, drums, shoves, pierce, chains) | Hand 1: Needle grappled the Courier over the pit at (3,5), and it fell, but only from (4,6), not (4,5). Hand 2: a shove moved the Reaper so the warden's mortar hit it instead. Hand 4: one lance set off two drums for +3. | ITB pushes and TBW defenestration, which the genre treats as its best moments. |
| **Tearing an arm cancels its queued attack** (`tear_threshold` 5) | Torn arms removed intents in all four hand sessions: the tracker's Rail Driver, the Lancer's lance, both of the warden's arms, the Sentinel's Scattergun. | Beats ITB (Vek have no parts). It is BattleTech and Phoenix Point's location damage without the hit rolls. |
| **Ordering three machines, with move and attack as separate modes** | Hand 2, sorting_gate R4: lance, then Charge, then Focus+Scatter on the EXPOSED Sorter, 22 damage in one turn, sequenced so no shove broke a later line. That was the best turn of the session. | ITB's ordering puzzle. |
| **Boss tricks that change the puzzle** (EXPOSED windows, ERUPT, BOILED OVER) | Hand 4: the Core's ERUPT forced an all-in race (Relay at 1 HP landed the 8), "the most tense part of both fights". Hand 3: the Pour BOILED OVER and showed "C KILLED, A loses 7, B loses 7", the biggest fear spike. | ITB's finale and StS boss phases (Awakened One, Time Eater). |
| **Enemies built from the player's parts** | The census found 222 to 342 distinct chassis+arm combinations per act, none more than 9 times. | Beats ITB's fixed Vek roster, which draws its most common complaint (repetition). |
| **Free undo within the turn, a save after every action, mid-fight included** | 048 snapshot undo; `run_session.gd` saves per action. | Matches TBW's most praised trait. Beats ITB's single reset and StS's room-restart save. |
| **Fight length on ordinary fights** | Median 5 rounds per run fight (630 fights). | ITB's 4-5 turns, VISION's 3-6 minutes. Bosses are the outliers, not ordinary fights. |
| **Identity: Ink & Rust panels, the generated machines, one amber action per screen** | Screens: the bay and title are the strongest-looking screens, and the amber primary action is consistent everywhere. | Clearer at a glance than most of the genre. |

---

## 3. Weak points, ranked by severity

| # | Problem | Evidence | Who solves it, and how |
|---|---|---|---|
| 1 | **Fights are decided in round 1, then become cleanup.** Choices drain away by the round. | Mean targets per turn: 4.30 (R2), 2.71 (R4), 1.76 (R7+). Forced turns go from 32.9% to 71.3%. Hand testers counted options worth weighing per round: 5,2,2,1 / 3,1 / ~4 then ~1.8 / 3,3,2,1,1,1. Crew damage across hand 2's three fights: 1 HP. | **Into the Breach**: Vek emergence is marked a turn ahead, and blocking a spawn costs the blocker 1 damage. Pressure keeps arriving until the map's turn limit. |
| 2 | **Dodging is free.** | Only 0.5% of 8,154 turns had no safe hex; median 26 safe hexes; 6% of intents land. Hand testers saw five "KILLED" warnings vanish after one step. The Pour floods the hexes the crew already stands on, so the same step dodges both its guns and its flood (verified: `combat_sim.gd` ~1728 marks the nearest crew machines, up to `floods`). | **ITB**: stakes sit on things that cannot move (buildings), and fire and acid stay on the ground. **TBW**: aim lines hold on a target and re-aim when it moves. |
| 3 | **Bosses are long and low-threat; the climax ends in a mop-up.** | Crew HP lost per boss: 1.8 / 6.1 / 6.9 for Acts 1-3, over 6.2 / 8.9 / 10.2 rounds. warlord_twins: 13.2 rounds for 3 HP. Hand 4: the Core was DESTROYED in R10, then a round of drone cleanup with Relay at 1 HP, because `_check_outcome` wins a rout only when every enemy is dead. Escorts die in R1-R4, so the keeper fights alone. | **Monster Train**: the boss acts every turn. **ITB**: killing the Psion ends its effect. **StS**: killing the boss ends a fight with minions. |
| 4 | **DEFEND is all or nothing and hard to read.** | 48 of 81 defend fights lost (59%), 34 of them in 1-2 rounds, with no salvage. You lost two of these yourself (PT8-8, PT10-3). | ITB: a lost building costs a little at a time. A first-time briefing for each mission type (ITB's CEO cards). |
| 5 | **The game teaches a false rule.** | `tutorial.json:9` and `glossary.json:17` say "MOVE once and ATTACK once, in any order". `combat_sim.gd:934` roots every machine without `move_after_attack`, which `rules.json` gives only to role `line`. Hand 2: "Relay was rooted after shooting." I verified both. | **XCOM 2** says "firing ends the turn" and greys out the move pips. |
| 6 | **The tagline isn't built: salvage ignores what you tore off.** | `run_sim.gd` `salvage()` rolls slot, rarity and pool. PART_TORN is counted only as a feat (~1507). About 2.35 enemy arms are torn per fight, and none can be won. | **BattleTech**: how you kill decides what you salvage. |
| 7 | **Run-building choices barely matter.** | A bot that always takes perk 0 and picks salvage by rarity still wins 67.3% (59-74). All 12 perks are flat stats or flags. Legendaries are mostly bigger copies of existing parts (Sunspear +28, Godhammer +23 in the arm trial). Elites are `elite_hp_bonus` plus a "Veteran" label: none of 54 census elites had a rule of its own. PT4-4: "levelling feels boring". | **StS** relics and elites as deck checks, **Balatro** jokers that change rules, ITB pilot traits that change a verb. |
| 8 | **Playback is slow and the run is long.** | Enemy phase 3.5-5.7 s. The 5 s opening card can't be skipped. About 86 rounds per run, an estimated 70-100 min against VISION's 45-60. Nothing touches `Engine.time_scale` (verified). You asked twice (PT1-5; 065). | **Balatro** x1-x4 speed, **StS** fast mode. |
| 9 | **The fight screen spreads attention.** | Screens: red means lava, danger hexes, enemy rings, arrows and damage all at once. Machines are about 50 px. The board uses about half the screen width. The Core screen is the most cluttered (the "3" covers the boss name, rule text sits on the board). Consequences live in a side panel. Live wires are already a scorch mark (CHANGELOG), so this is partly fixed; slag is still `6b2c14`. | ITB keeps tiles calm so intents read, and redraws a pushed Vek's attack on the board. |
| 10 | **Damage numbers change with no reason given.** | Hand 4: the same lance predicted 3 from one hex and 5 from another. You asked twice (PT11-10, PT11-14). | **StS**: modified numbers are tinted, and hovering lists each modifier. |
| 11 | **Rewards don't feel like rewards.** | Cards are about 70% empty paper. 69 written flavour lines exist, and no script reads them. Fitting a picked part takes about 6 taps across 2 screens. | StS shows the card itself and puts it straight into the deck. |
| 12 | **Bosses don't look like bosses.** | Screens 11/12: the Pour is small and hard to find. PT11-15, PT14-3. | ITB and StS: bigger, distinct silhouettes. |
| 13 | **Act 3 repeats.** | Only 3 Act 3 skirmish maps; 15 of 23 census runs repeated one. One opener (lance into a drum by the spawn) solved turn 1 of both furnace_mouths and the_core. | ITB AE rerolls spawns; StS2 alternate acts. |
| 14 | **Phone is not ready** (pre-ship). | Body text works out to about 0.94 mm on a 6.1" phone, against a ~1.9 mm minimum. Some rules are only in hover tooltips. There is no settings screen and no back handling. The garage uses fixed pixels. These sizes are calculated, not measured on a device. | StS, Balatro mobile: long-press to inspect, aspect-aware layout. |

---

## 4. Adaptations

**Rule:** a proposal stays if at least 2 of the 3 skeptics kept it. Duplicates are merged. Where I overrule the vote, I say why. The number in brackets is the skeptic vote.

### Fight pressure and bosses

**A1. A boss's death ends its fight** [3/3, absorbs "close the cleanup tail" part 1]
- **Problem:** #3. `_check_outcome` (`combat_sim.gd` ~2050) needs every enemy dead.
- **Precedent:** ITB Psions, StS boss-with-minions.
- **Scrapline version:** a new objective type `keeper`. When every ref in the fight's `keepers` list is dead, emit `GridEv.KEEPERS_FALL`, and the remaining enemies collapse into piles through the wreck path, so salvage still pays. Set it in sorting_gate, the_pour, the_core and the three warlord files. The banner reads "DESTROY THE POUR". The bot needs one score constant (like `SCORE_PYLON`).
- **Effort / impact:** S / high.
- **Measure:** 0 rounds after the keeper dies. Act 3 boss rounds go from 10.2 toward 7-8. Run win rate moves by less than 3 points. A verify_combat test for the Core dying with drones still alive. **You judge:** does the Core's death feel like the end of the run?
- **Not adopted:** the fallback ram for disarmed enemies. 2 of 3 skeptics said it undercuts tearing.

**A2. Bosses press from round 1** [2/3, trimmed]
- **Problem:** #3, and the second half of #2.
- **Precedent:** Monster Train, ITB spawn telegraphs, StS Time Eater.
- **Scrapline version**, three parts only:
  1. **Escort waves:** `escort_waves` in each gate and warlord file, e.g. 2 escorts at R1 and 2 at R4. Later waves are marked a round ahead using the existing `_waves` and `wave_marks` code. A machine standing on a mark blocks it and takes `block_damage` (rules.json, 1-2).
  2. **The Pour floods where you're going:** it marks the hex next to each machine on the side toward the keeper, not the hex under it. Separately, its text promises 4 floods, but the code caps at the crew count (3). Fix either the text or the targeting.
  3. **A visible pulse counter** for the Core ("PULSE IN 1").
- **Deferred:** Reclaimer-drone waves, +1 heart damage.
- **Effort / impact:** M / high. **Ships after A1.**
- **Measure:** crew HP lost per boss rises across the acts (aim about 4/8/12). Boss rounds stay at 8 or fewer. Boss win rate drops by at most 5 points per act. Test on fights a run built (`dump_boss_fights.gd`), not the plain files. **You judge:** do the Pour and the Core feel like the scary end of an act?

**A3. Marked reinforcements in ordinary fights from round 3** [2/3]
- **Problem:** #1, the main one.
- **Precedent:** ITB emergence plus a block cost; Wildfrost's bell. XCOM 2's flat timers are the warning.
- **Scrapline version:** reuse the A2 wave machinery. In `run.json` add `reinforcements: {from_round: 3, every: 2, count_by_column: [...], waves_by_act: [1,2,2]}`. Arrivals are rolled from the same pool and kinds table, on enemy-half hexes picked by hash, marked a round ahead. Blocking costs `block_damage`. The objective line shows "2 WAVES LEFT", so a strong opening can still finish early. Arrivals don't fire on the round they land.
- **Skeptic 1's objection stands:** this lengthens fights while A1 and A11 try to shorten them, and it adds marks to a board you found busy (PT2-9). So it **ships after A2 has proved the machinery on bosses, in its own iteration, as the only pressure change in that A/B.**
- **Effort / impact:** M+ / high.
- **Measure:** `balance_fights --b` with byround.py. Rounds 4+: mean targets 3 or more, forced turns 45% or less. Rounds per fight up by no more than 1.5. Run win rate within 5 points. **You judge:** does round 3 feel like a new problem, and is blocking a mark ever a real choice?

**A4. Lock-on intents, then lingering ground** [2/3, staged]
- **Problem:** #2.
- **Precedent:** TBW held aim lines; ITB fire and acid.
- **Scrapline version:**
  - Stage (a), data only: tracker weight by act in `run.json` kinds (30 / 40 / 45).
  - Stage (b), later: a `ground_after_hit` key so mortar and slag lobs leave a hazard hex for 1 round. Draw it as *floor* (MEMORY 2026-10-12, PT14-5), never red (A12).
  - The Pour part is covered by A2.
- **Effort / impact:** S for (a), M for (b) / medium.
- **Measure:** safe reachable hexes go from ~26 to 15-20, turns with no safe hex reach 5-15%, intents landing reach 12-20%. Watch Act 2-3 loss rates. **You judge:** does the board close in, or does it just feel unfair?

**A5. Elite affixes: one announced rule per elite** [3/3, trimmed]
- **Problem:** #7, and route choice (pillar 3).
- **Precedent:** StS elites as deck checks; Balatro boss blinds announced in advance.
- **Scrapline version:** an `elite_affixes` block in `enemy_kinds.json`, built only from rules the sim already has. Start with three:
  - `volatile`: blast 5 on death.
  - `rigged`: keeps its arms, so it cannot be disarmed.
  - `bulwark`: plate 2, front 3 hexes only, using the Core's open-side code.
  
  Act 1 offers 2. The affix shows on the map node ("ELITE: VOLATILE") and as a tag on the machine. `elite_hp_bonus` drops to 1-2. Defer `scrapper` (a new heal rule) and the rare-arm drop (that is A7).
- **Effort / impact:** M / high.
- **Measure:** every elite carries one affix. Crew HP lost per elite is about 1.5-2x a skirmish, and win rate stays within 5 points. **You judge:** does an elite node make you stop and choose?

**A6. Act 3 variety: prop slots, mirroring, no repeats within an act** [2/3]
- **Problem:** #13.
- **Scrapline version:** `prop_slots` (candidate hex groups, one picked by SimRNG), `"mirror": true` for symmetric objectives, and no repeated map within an act (the `recent_offers` pattern). Apply prop slots to the_core's drums too. Author 2-3 new Act 3 maps later, with the 081 arena kit.
- **Effort / impact:** M (slots) to L (maps) / medium.
- **Measure:** Act 3 repeats fall from 15/23 to fewer than 5/23; `verify_run` stays green. **You judge:** does turn 1 of Act 3 still have one known answer? Skeptic 2 noted you have never raised repetition, so this ranks low.

**A7-defend. Partial salvage for DEFEND** (my addition: the "crates" proposal was dropped 1/3, but every skeptic who discussed it called its DEFEND half useful)
- **Problem:** #4, 59% loss with no salvage.
- **Scrapline version:** salvage scales with caches saved over caches, and `cache_hp` goes from 5 to 7. Both are data in `run.json` and `rules.json`.
- **Effort / impact:** S / medium.
- **Measure:** defend loss rate and its share of run losses; run win rate within its interval.

### Build and progression

**A7. Torn from the Tracker: one salvage option is a part you tore off** [3/3, absorbs "Tear it, take it"]
- **Problem:** #6.
- **Precedent:** BattleTech salvage.
- **Scrapline version:** while replaying the fight, `RunSim` collects the part ids from enemy arms with PART_TORN, plus the module or core of each wrecked enemy. It keeps only ids that are in the pools, not tuned and not legendary, sorted by id with the unit ref as tiebreak. The slot set by `trophy_slot` (`run.json`) shows one trophy picked by SimRNG, capped by `trophy_max_rarity` per act. Boss hoards are unchanged (PT13-3). The card reads "TORN FROM THE TRACKER". The recap reads "Tore off: Rail Driver, Saw".
- **Effort / impact:** M / high. Deterministic, and the save stays one action list.
- **Measure:** 70% or more of fight rewards include a trophy; win rate stays inside its interval. **You judge:** did you ever aim at an arm because you wanted it?

**A8. Perks that change rules** [3/3, phase 1 only]
- **Problem:** #7, PT4-4.
- **Scrapline version:** data only, because `CombatSetup.apply_bonus` already reads `tears`, `pierce`, `mark`, `kill_heal`, `thorns`. Replace `heat_sinks` and `coolant` with:
  - Rending Grip (tears, needs melee)
  - Spotter (mark)
  - AP Rounds (pierce, needs ranged)
  - Scavenger (kill_heal 2)
  - Barbed Hull (thorns 1)
  
  Every level offer holds at least one rule perk.
- **Effort / impact:** S / high.
- **Measure:** this is **judged by you**, not the bot, until T1 below lands (`run_bot.gd:84` always takes perk 0). **You judge:** at which level-up did a machine become something different?

**A9. Legendaries: rarer, a rule plus a visible drawback** [2/3]
- **Problem:** #7, PT10-1, the 029 question.
- **Scrapline version:** rework the 6 parts in `data/parts/*.json` using existing verbs. Examples:
  - Godhammer: shoves 2 hexes and always tears, but the wielder can't move after striking.
  - Sunspear: pierces everything, allies included, shown in the preview.
  - Colossus: can't be shoved, but move 2.
  
  Every new key is copied in `clone()`. The supply cut (warlord_legend_pct 0) is a question for you (Q5), not a decision.
- **Effort / impact:** M+ / high.
- **Measure:** in `balance_fights --arms`, no legendary above +15. Legendaries make up under 8% of end-of-run sockets. **You judge:** did you ever turn one down?

**A10. Maker sets: 3 pieces become a verb, heat leaves the sets** [2/3, as a choice for you]
- **Scrapline version:** data only. Kessler 3 = thorns + unshovable; Arclight 3 = arc; Vektor 3 = pierce; Cinder 3 = tears. Optional "Mongrel" (4 makers on one machine: +1 armour). This answers the open question of 2026-10-08, so it waits on your answer (Q6).
- **Trait ownership:** A8, A9 and A10 hand out the same traits. **Decide which source owns each trait before building more than one of them** (see T2).

### Onboarding and clarity

**A11. Tell the truth about move-after-attack** [3/3]
- Fix the text in `tutorial.json` welcome and glossary `turn`.
- With a non-LINE machine's weapon armed before it has moved, the HUD shows "Firing ends Knuckles's move".
- A ROOTED tag with its own glossary card.
- **Effort:** S. No hash change.
- **Measure:** verify_onboarding fails if "any order" appears; the warning line shows when Knuckles is armed. **Do first.**

**A12. Every damage number explains itself (aimed target only)** [3/3]
- Add `CombatSim.damage_steps()`; `damage_to` becomes its sum.
- The aimed preview prints "5 → 3 (−2 armour, −1 cover, +1 marked)".
- Add glossary cards for LOCKED and KO.
- **Effort / impact:** M / medium.
- **Measure:** sum equals `damage_to` over a bot fight's hits, and the fingerprint TOTAL is unchanged. **You judge:** re-check PT11-10 and PT11-14.

**A13. First-encounter cards and a copy-clean pass** [3/3]
- Strip "(050)"-style leaks; I verified the coolant tile text has one.
- Add a coverage test for site types and hint ids.
- Add hints only where you complained: ladder and unlocks (PT9-4), new parts (PT12-5), EXPOSED, SEIZED.
- **Effort:** S. Text only, not hashed.

**A14. First time each objective appears: a three-panel strip** [2/3]
- Reuse the boss strip. Text goes in a `story.json` `objectives` block. One coach step points at the cache, terminal, pile or zone. `Profile.mark_seen('obj_defend')`.
- Hold back the `first_objectives` generation dial.
- **Effort / impact:** M / high for new players.
- **Measure:** you can't judge it as a newcomer (skeptic 2's point). Judge it by verify_onboarding plus a fresh-profile tester.

**A15. Rewrite the shakedown around the signature verbs** [2/3]
- Same 12 steps, swapped for verbs: one tear (Runner Boss at 8 HP, a -4 scanner), one pit fall, one real threat, and heat as a stated choice.
- Coach text uses crew names. The move ring never sits on an aimed hex.
- **Effort / impact:** M / high for new players.
- **Measure:** the scripted line produces a tear, a fall and a heat decision; the fingerprint TOTAL is unchanged. Depends on A11.

### Feel and readability

**A16. Playback speed 1x/2x/3x plus hold-to-hurry** [3/3, merged with the UX version]
- A `Profile.playback` command. `Engine.time_scale` during the enemy phase, min(speed, 2) for player actions. Hit-stop stays real-time. Default 1x.
- **Opening-card skip:** only after shader warm-up and on a second sighting. That modifies PT8-5, so it's a question for you (Q3).
- Needs a home for the dial: the minimal settings sheet (A22).
- **Effort / impact:** S / high.
- **Measure:** enemy phase under 1.5 s at 2x; the event stream is identical at 1x and 3x. **You judge:** is anything unreadable at 2x?

**A17. A CANCELLED beat** [3/3, trimmed]
- `GridEv.INTENT_LOST` (event only) whenever a kill, fall, tear or SEIZE removes a standing intent.
- The cloud is struck through with "CANCELLED −7" in amber, a distinct sound, and the rare hit-stop.
- Defer chain pitch steps and pit lettering.
- **Effort / impact:** M / high.
- **Measure:** INTENT_LOST fires exactly when expected; record the fingerprint change on purpose if the hash covers events. **You judge:** did you notice the shot you cancelled?

**A18. Consequences drawn on the board while aiming** [2/3]
- Ghosts of moved units, and red dashes for re-aimed intent lines, all from `dry_run`/`diff`. Only while aiming.
- This fixes hand 1's "the warning lied" (a re-aiming tracker).
- **Effort / impact:** M / medium.
- Design A12, A17 and A18 together under one HUD budget (T3).

**A19. Bosses read as the biggest thing on the board** [3/3]
- A `view_scale` data key (presentation only).
- Collapse boss tags to the name plus 2 icons; the sentences move to the tooltip and glossary.
- The opening push-in is **an option on the before/after sheet only**, given 081's camera decision.
- **Effort / impact:** S-M / medium.
- **Measure:** boss height at least 1.4x a crew machine; contrast may only grow.

**A20. Red means danger again** [2/3, trimmed to what is still live]
- Wires are already fixed. What remains: slag (`6b2c14`) becomes hatched umber; damage *dealt* floats in ink, not red; OVERHEATED and SEIZED become copper; the Core's ring hatching keeps red only on hexes where it hits a crew machine.
- The red card shadow is your pick, so it stays.
- A red-pixel census goes into `measure_contrast.gd`.
- **Effort / impact:** S / medium. Deliver as a named before/after sheet.

### Rewards, attachment and UX

**A21. FIT IT NOW on the salvage card** [3/3]
- When the verdict says "BEATS X", the card shows `UIKit.choice` "FIT ON KNUCKLES", which sends the pick plus an existing REFIT. No new action kind.
- **Effort:** S.

**A22. Show the flavour text that already exists** [3/3, cards only]
- One italic line on reward, garage and bay cards, through `UIKit.fit`. Defer barks and the events.json `{name}` change.
- **Effort:** S.

**A23. Roll call on the run-over screen** [2/3]
- Three crew columns: level, perks, signature part, kills, and STANDING or "FELL at <site>, Act N".
- Fix `endings.wrecked`, which mentions the Crucible even for an Act 1 loss.
- Write the text for THE LINE IS CUT.
- **Effort:** S. Story text, not hashed.

**A24. Settings sheet plus Android back and pause hooks** [2/3]
- Minimal now (speed, volume, abandon run), because A16 needs a home. The Android parts come at ship prep.

**A25, ship prep only** [2/3 each]:
- phone scale plus long-press inspect;
- anchored garage and map top bar layout.

Both are real (the mobile pillar; PT3-5, PT8-6, PT9-6, PT10-9) but don't change PC fun. Schedule them with the Android export preset.

### Tooling the skeptics flagged as missing (all three)

- **T1. A RunBot that makes choices:** perks and salvage scored by a dry run on the next fight. Without it, A7-A10 can only be judged by you. Folded in from the rejected "give the build something to beat".
- **T2. A trait-ownership table:** which of perks, sets, legendaries and modules gives pierce, tears, arc and mark.
- **T3. A HUD budget:** what the fight screen may show at once, before A12, A17, A18 and A5's tags all land.

### Dropped (fewer than 2 of 3, or merged)

| Proposal | Reason |
|---|---|
| Bonus goals per fight | 0/3. Pays in scrap you already had 230 of unspent (PT9-3), and crowds the HUD. |
| Salvage crates on the board | 1/3. Too close to the escort logic you removed with the Crawler; adds rewards. Its DEFEND half kept as A7-defend. |
| Pit counter-traits | 0/3. You kept pits on purpose (2026-10-06). |
| Role personalities | 0/3. L effort; moves every bot number. |
| Enemy-only keeper parts | 0/3. A19 is the cheaper first step. |
| Turn-1 threat in the first run fight | 0/3. Undoes your PT10-3 spacing; A15 teaches it instead. |
| Recap headline | 0/3. Low impact. |
| Wreck pile recovery | 1/3. Amends your 2026-09-24 decision. Offered as Q8. |
| Battle scars | 0/3. |
| Save checkpoints across content changes | 0/3. Post-launch work. |

---

## 5. Proposed iterations

**Before 082: play-test 15 on the current build.** The last play-test was PT14 on 2026-10-06, about 30 iterations ago, and many "the user plays" questions are still open: 029 legendaries, 032 board, 050/052 boss tricks, 038 Core. Several answers below depend on it.

| Iteration | Goal | Contents | Acceptance checks |
|---|---|---|---|
| **082-truth-and-speed** | Stop teaching a false rule; make fights faster to watch | A11, A13, A16 (opening skip only if Q3 is yes), A22, minimal A24 | `tools/check.sh` green. verify_onboarding: no "any order", ROOTED warning shown, no `(\d{3})` in player text, hint coverage passes. Event stream identical at 1x and 3x; `--fingerprint` TOTAL unchanged. Timing probe: enemy phase under 1.5 s at 2x on slag_pit and the_pour. Shots of the flavour line on reward and garage. |
| **083-the-boss-is-the-fight** | Bosses end on the kill and press from round 1 | A1, then A2 (trimmed), A19 | verify_combat: Core death ends the fight with drones alive; replayed prefixes match. balance_fights on the gate and warlord fights: 0 rounds after the keeper dies, mean boss rounds 8 or fewer, HP lost per boss rising across the acts. `run_bot --runs 150`: win rate within 5 points of 67.3%. Before/after sheet of 11_boss_pour and 12_boss_core; contrast does not drop. |
| **084-cancel-and-explain** | Make the signature moments and the numbers readable | T3 HUD budget first, then A17, A12, A20 (A18 if the budget allows) | sum(damage_steps) equals damage_to over thousands of bot hits; TOTAL unchanged. INTENT_LOST fires exactly when expected (verify_combat). Red census about 0 outside intents; contrast does not drop. Named before/after sheets. |
| **085-trophies** | Salvage pays off how you played | T1 (RunBot choice policy), A7, A21, A7-defend | `run_bot --b` trophy_slot on/off, 150+ runs: win rate inside its interval, 70% or more of fight rewards with a trophy. verify_run_ui: FIT IT NOW leaves the part fitted, and replaying the log reproduces the same RunState. Defend loss rate reported before and after. |
| **086-rules-not-numbers** | Level-ups, sets and legendaries change what a machine does | T2, A8, then A9 and A10 per your answers to Q5 and Q6 | `balance_fights --arms 150`: no legendary above +15. The T1 bot A/B for perks: rule-perk pick share above 50%. Content hash bumped on purpose. |
| **087-elites** | An elite is a different problem, not a bigger number | A5 (3 affixes) | Census: every elite has one affix, no repeat within a run. `balance_fights --b`: HP lost per elite at about 1.5-2x a skirmish, win rate within 5 points. Map node shot. |
| **088-pressure** | Rounds 3+ stay decisions | A3 on its own, then A4(a) in a later A/B | byround.py: rounds 4+ mean targets 3 or more, forced turns 45% or less. Rounds per fight up by no more than 1.5. `run_bot` win rate within 5 points, with Act 2-3 loss rates reported. **Must be play-tested before A4(b).** |
| **089-onboarding** | A new player meets tear, pit and cancel in the first 5 minutes | A15, A14, A23 | verify_onboarding wins the new shakedown by real clicks with a tear, a fall and a heat choice; no ring on an aimed hex; strip shown once per objective. A fresh-profile play-test. |
| **090-act-3-variety** | Openers can't be memorised | A6 | Repeat-rate target met; verify_run green. |
| *Ship prep* | Android | A25, the rest of A24, an export preset | measure_touch (new): body text 1.9 mm or more, targets 7 mm or more; four-aspect garage sheet with no blank band over 5%. |

Every iteration follows the docs workflow: an iteration file first, then CHANGELOG, MEMORY, plans, ROADMAP, and **your play-test before the next pressure or difficulty change.**

---

## 6. Questions only you can answer

1. **Is a decisive round 1 the rhythm you want** (an ITB-style alpha strike), or should rounds 3+ carry new problems (A3)? This decides whether 088 happens at all.
2. **What should overall difficulty be?** The bot wins 67%, and a skilled human likely wins much more. Should A1-A5 make the game harder overall, or stay neutral and only spread the difficulty more evenly?
3. **Can the 5 s opening card be skipped by a tap** after you've seen that fight once (it was your PT8-5 rule)?
4. **Boss camera:** a short push-in on the boss at fight start is a dolly, not a turn, but you removed camera control in 081. Yes, no, or show you a sheet?
5. **Legendaries:** remove them from warlord hoards so only gate keepers drop them (about 1-2 a run)? Warlords would give a rare instead, which changes why you'd take that detour.
6. **Maker sets** (the open question of 2026-10-08): keep them flat, make 3 pieces a verb (A10), and/or reward mixing ("Mongrel")?
7. **Crate-style stakes:** would you rather a dodge cost you *loot* or cost you *HP*? This was dropped as too close to the Crawler, but it's your call.
8. **Wreck recovery:** should a fallen machine's pile, if you protect it, let you keep one of its parts? This amends your 2026-09-24 decision.
9. **Is 12 shakedown steps already too long?** A15 keeps it at 12.
10. **Run length:** is 70-100 min acceptable, or should we cut fights per act or columns (the front's speed) toward 45-60? Time one run at your preferred playback speed.
11. **Sound** has never been heard (023). A17 leans on new sounds. Listen first?

---

## 7. Method and limits

**Measured** (all from the scratch copy; nothing in the live project was changed by this review):
- `run_bot.gd --runs 150`: 101/150 won (67.3%, 95% interval 59-74), no illegal actions.
- `balance_fights.gd --fights 400`: 99.0% won. The 19 authored maps were each played on only 5 seeds.
- A custom density script over 40 real runs (seeds 1000-1039): 630 fights, 8,154 machine turns. For each turn it listed every hex × weapon × aim, scored by `IntentAI.plan_value` + `_tile_value`.
- 22 screenshots at 1920x1080. Phone size was only *simulated* by scaling one shot to 800 px, because the tool always captured 1920x1080.
- 4 agents played 8 fights by hand through `tools/play_fight.gd`, a text tool, not the real HUD: shakedown, proto_yard, pit_row, container_row, sorting_gate (arena), slag_lake, the_pour (arena), furnace_mouths, the_core.
- 7 design lenses produced 40 proposals; 3 skeptics reviewed each one.
- I checked these claims myself in code and data:
  - "any order" (`tutorial.json:9`, `glossary.json:17`) against `combat_sim.gd:934`;
  - no `time_scale` anywhere in `scripts/`;
  - Pour floods capped by the number of targets (`combat_sim.gd` ~1740) against `floods: 4`;
  - slag colour `6b2c14`, and live wires already changed to a scorch mark (CHANGELOG);
  - next iteration number is 082.

**Limits:**
- **The bot's skill moves every number.** In 073, bot changes alone moved its win rate 12.7 points. RunBot picks by rarity and always takes perk 0, so it cannot judge any build proposal.
- **The density score is IntentAI's quick estimate,** not full dry-run consequences. It treats machines one at a time and doesn't count the choice of order.
- **Hand testers read text, not the real screen.** Some of their "surprises" (anchored targets, overheat, death blasts) may already be shown by the HUD.
- **Hand testers mostly played authored fight files with the default crew at full HP,** not run-built fights with carried damage. One seed (2026).
- **Phone sizes are calculated,** not measured on a device. There is no Android build yet.
- **Genre comparisons are the agents' research,** not measured here.
- **Nobody here can judge fun.** Every "you judge" line above is the actual test, and none of these changes should be called done without your play-test.- **Four of the eleven lenses did not run** (the account's spend limit): run structure, difficulty, replayability and meta, dominant strategies. Their ground is covered only through the bot data, the hand play-tests and the other lenses.
