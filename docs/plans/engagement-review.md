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


## 8. The four remaining lenses and your answers (2026-10-22)

*Four lenses missed the first pass because the account hit its spend limit: run structure, difficulty, replayability and meta, and dominant strategies. They have now run, and three skeptics reviewed them. The rules are the same as in section 4: a proposal stays if 2 of 3 skeptics kept it, and anything that duplicates A1-A25 is merged into that A item. The only new measurement is the front A/B (`out/genre-run-structure/explore_every1_ab30.txt`). Every other number comes from the lens runs under `scratchpad/out/` (`replay/`, `replaymeta/`, `difficulty*/`, `dominant2/`, `run-structure/`) or from sections 1-7. **Measured** means a tool produced the number. **Inferred** means it is reasoning or comes from what we know of other games.*

### 8.1 Your answers, and what each one changes

| # | Your answer | What changes in the plan |
|---|---|---|
| Q1 | "The fight can't be hard from first to last move, but it must still feel engaging through it." | Difficulty does not have to be even across a fight, but **every round needs something worth doing.** So **A3 (marked reinforcements) becomes required and stays in the base game.** One lens wanted A3 only on a ladder rung. Two skeptics rejected that, and your answer settles it: at rung 0 the cleanup rounds would still be there. The byround.py targets (rounds 4+: 3 or more mean targets, 45% or fewer forced turns) now also apply to boss fights in 083. Two new items serve Q1 directly: B5 (boss fights stop healing the crew) and B6 (Focus stops being the one obvious press). |
| Q2 | "Yes, harder, and it must not be played once and uninstalled. It needs a motive to be played again and again." | **Harder overall:** the earlier targets ("run win rate within 5 points of 67.3%") become a *falling* target. The rung-0 bot may drop to about 55-60% by the end of the pressure work, with each step reported and none larger than 8 points at 150 runs (my proposal; inferred). **Replay** becomes a top priority, with its own iterations: the tier bug fix (B1), the ladder (B4), the seed code and run history (B8), act conditions (B7), crew rules and medals (B9, B10). The first version of the ladder moves up to 085, ahead of the readability work. |
| Q3 | No to skipping the opening card by tap. | **A16's opening-card skip is dropped.** PT8-5 stands. 082 ships only the 1x/2x/3x playback dial and hold-to-hurry. |
| Q4 | "Yes" to run length (question 10 in section 6; it was the fourth question in the summary the user answered) | **A run of 70-100 min is fine.** No proposal needs to shorten runs; B4 still reports rounds per run so harder rungs do not quietly push past 100 min. The boss camera push-in (section 6, question 4) stays open. |

### 8.2 Per lens: strong points and weak points

**Run structure** (900 generated regions, 64 traced acts, explorer and forward bots on 30 seeds, plus the new front A/B)

| | Point | Evidence |
|---|---|---|
| Strong | Real branching on the map | Median 28 forward paths per act. 57.4% of choices with more than one option mix a fight with a service (measured) |
| Strong | The warlord is an optional detour you can see coming | Taken in 31 of 64 traced acts (measured) |
| Strong | Honest move previews | `RunSim.move_preview` already reports bites and drone reach, checked by verify_run |
| Strong | Losses are spread out | Column 8 holds only 12 of 49 losses (measured) |
| Weak | **The Reclaimer never bites** | 0 bites and 0 drone reaches in 64/64 acts. You can take 16 of ~21 sites per act and never be bitten. The explorer fought 21.5 fights against the forward bot's 13.4, and reached the last gate *stronger* (HP 46.3 vs 36.9, rare+ parts 7.7 vs 4.6). Both won 22/30 (measured) |
| Weak | The integer front key is too coarse | `front.every 1`: the explorer drops to 12.2 fights (below the forward bot), wins 17/30 instead of 22/30, and act 2 losses go from 3.6% to 15.4%. B-A is -16.7 points, but the 95% interval runs from -41 to +8, so at n=30 the win-rate change is **not significant**. The fight counts are clear (measured) |
| Weak | Fights are hidden until you arrive | The objective, condition and enemy kinds are rolled before travel (`run_sim.gd` 1203-1253) but shown only in the site panel (`run_map_screen.gd` 814-831). DEFEND loses 59% and can't be routed around |
| Weak | Every run has the same skeleton | One gate and one warlord per act, in a fixed order, with 6/5/3 skirmish templates (data) |

**Difficulty** (838 traced fights from the lens, tier A/B on 36 seeds)

| | Point | Evidence |
|---|---|---|
| Strong | Difficulty rises by act | Skirmish HP lost 3.1 → 4.4 → 5.4. Of runs reaching each act, 8.0 / 13.8 / 15.1% lose there (measured) |
| Strong | Recovery layers (undo, repair, rebuild, arrival repair) | Rungs should thin these, never remove undo |
| Weak | **The ladder's tiers do nothing in Acts 2-3 (a bug)** | `RunSetup.overlay` (`run_setup.gd:32-41`) merges one level deep. `rules_of` (`run_sim.gd` ~1003) lays each act's `enemies {hp_all 5, bonus{damage 1|2}}` over the tier's values and replaces them. In `out/replay/tier_overlay.txt`, tier 1 in act 2 equals tier 0. Same-seed wins over 36 seeds: YARD HAND 19, RECLAIMED as shipped 22, RECLAIMED fixed 16. Verified in code by all three skeptics |
| Weak | Only 3 rungs, and they only add HP | `meta.json` tiers. MEMORY 2026-09-30 says enemy HP is not difficulty against a levelled crew |
| Weak | Many fights are free, a few are spikes | 39% of fights cost 0 HP or gain HP; 6-9% cost half the crew (measured) |
| Weak | **Boss fights heal the crew** | In 9 of 10 gate losses the crew survived 20-22 rounds, often *gaining* HP (15 → 29). Act 3 warlords cost -0.3 / -0.6 / -5.5 HP. "The gate held" is 8 of 49 losses (measured). The cause, `pile_heal 2` on every kill and drone, is inferred: no A/B has run |

**Replayability and meta** (48 runs, career.py over 16 careers, a tier dump)

| | Point | Evidence |
|---|---|---|
| Strong | High build variety | Final crews share 19% of part ids (Jaccard 0.19). 222-342 enemy chassis+arm combinations per act. 28 signal events (measured) |
| Strong | Unlocked crews are real alternatives | WALL 6/8 and RUNNERS 6/8 against SALVAGERS 4/8 on the same seeds (small n) |
| Strong | The run-over screen always points at the next unlock | `run_map_screen.gd:1102-1120` |
| Weak | Nothing is left to chase after about run 5 | The ending comes at a median of run 5 (career.py, 16 bot careers; inferred for a human). 11 of 26 unlocks are "play N runs" or "win N fights". u17 and u20 fall in run 1 without being aimed at (measured on the bot) |
| Weak | No seed, score or run history | Nothing in `scripts/`, `sim/` or `data/` shows a seed or accepts one (checked) |
| Weak | Repetition | Skirmish maps repeat within an act in 31/48, 28/48 and 34/48 runs. The gate and warlord sequence is the same in every run (measured). **You have never raised repetition** (skeptic 2), so this is inferred to matter |

**Dominant strategies** (20 RunBot runs, 337 fights, three 240-fight arm trials)

| | Point | Evidence |
|---|---|---|
| Strong | Heat binds | 196 overheats and 149 seizes, in 39% of fights (measured) |
| Strong | Hanging back doesn't stall | 1 of 337 fights reached round 20. Median 4-5 rounds |
| Strong | No build lock-in | 16 different arms at run end; 56 parts fitted |
| Weak | **Dead starter arms** | The Hammer is fitted in 292 fights, swung 0.17 times a fight, for 0.8% of crew damage. Saw (rarity 2) and Cleaver (rarity 1) have identical grid blocks and gave byte-identical trial results. Pulse is -12.4 in the 073 arm ranking but sits on 2 of 3 starters (measured) |
| Weak | **Focus is a free button** | Used 579 times, more than all other abilities combined. It costs nothing, with cooldown 2 (measured) |
| Weak | Rarity is a straight power ladder | The top 5 arms are 55 of 88 end-of-run arms. 13 of 20 runs end with a legendary. Sunspear is carried in 19% of fights and deals 15% of crew damage. ar_lance is in 78% of winning crews (measured) |
| Weak | Losing a DEFEND is cheap | 30 of 34 bot losses are DEFEND. A lost DEFEND costs 3.2 HP against 4.6 for an average won fight. `run_sim.gd:597-601` only clears pending salvage (measured; that a human would throw one on purpose is inferred) |
| Weak | Crew choice fades | 0.98 starting parts are left per machine at run end, so the three crews differ only until Act 2 (measured) |
| Observation | In bot play, the board-as-weapon strength is rare | 96% of enemy deaths are direct crew hits; 1% are pits. This may reflect how the bot plays rather than the game. The hand testers' best moments were all board kills. It is why "wary yard" was dropped (below) |

### 8.3 New adaptations B1-B10

The vote in brackets is the skeptics'. "Merged" means several lenses proposed the same thing and one version was kept.

**B1. Tiers apply on top of the act, not under it** [3/3; merges difficulty #1 and replay G1]
- **Problem:** the tier bug above. The card text "every enemy" is false in two of three acts, and every ladder rung would inherit the bug.
- **Precedent:** StS Ascension and Monster Train covenants stack on top of each act's own scaling. A rung never switches off in Act 2.
- **Scrapline version:** `meta.json` tiers get an `adds` list of `{path, delta}` or `{path, set}` entries (integers, sorted by path). `RunSim.rules_of` applies them **after** the act overlay. Keep `rules` for keys no act touches (`front.damage`). FOREMAN becomes an enemy damage delta instead of HP, in a **separate** A/B, because that is a balance change and not part of the fix. Content hash bumped on purpose.
- **Effort / impact:** S / high. **This is a bug fix and lands in 082, ahead of any ladder work.**
- **Measure:** a verify_run check prints every tier × act value and asserts tier N ≥ tier N-1 on every key. The fingerprint TOTAL is unchanged at tier 0. The tier win-rate gap is read at 150+ runs: today it is noise (+3 of 36 for RECLAIMED).

**B2. Fight card on the map** [3/3; absorbs the useful half of "danger rating"]
- **Problem:** two skirmishes look the same on the map, so DEFEND (59% lost) can't be routed around. This is the run-level half of Q1: every node should be a choice.
- **Precedent:** ITB shows each region's objectives and reward before you pick. Balatro shows the boss blind an ante ahead.
- **Scrapline version:** a pure `RunSim.fight_preview(state, setup, site_id)` that calls **the same roll** as `_make_fight`, not a copy of it. A revealed fight site's hover card gets one line: "DEFEND · dust · 2 shredders, 1 mortar". Unscouted sites stay "?", which makes towers worth a detour. A5's affix appears on the same line once it exists. Show facts, not a skull score: the skull formula needs a dry run per node and is the bot's view, not a player's.
- **Effort / impact:** S / high. No hash or fingerprint change.
- **Measure:** verify_run checks that preview equals `_make_fight` after travel over 300 regions. Run this first, because `_make_fight` may read state that changes along the route. **You judge:** did you ever go the long way round a DEFEND, or toward a fight you wanted?

**B3. The Reclaimer as a budget: a fractional front pace in data** [3/3]
- **Problem:** with `every 2`, greed is free. With `every 1`, lateral moves disappear (measured above). This is MEMORY's open dial ("the front's speed is the dial", 2026-09-24).
- **Precedent:** ITB lets you take 4 of 5+ regions per island. FTL's rebel fleet advances per jump.
- **Scrapline version:** `front.pace` is moves per column ×100 (an integer). The front advances when `moves*100 >= (front_col+2)*pace`. `every` stays as the fallback. Try pace 150 and 167, plus an optional per-act override (e.g. 175/150/150). Any new cost appears on the hover card first. The workshop weight change (R7, 14 → 8) gets its **own** A/B so the two results don't mix.
- **Effort / impact:** S / high.
- **Measure:** explorer vs forward, `run_bot --b`. These targets are sharp at 60 seeds: explorer fights per run 15-17, and bites or drone reaches in 30% or more of explorer acts. Win-rate targets (explorer no higher than forward) need about 150 runs (MEMORY 2026-10-12). It becomes the rung-0 default only after you play it; until then it is a ladder rung. **You judge:** did a sideways step feel like a bet?

**B4. The ladder: about 10 rungs, one announced rule each** [3/3; merges run G3, difficulty #2, replay G2, dominant #1]
- **Problem:** Q2. There are 3 rungs, they add only HP, and they are broken in Acts 2-3 (B1).
- **Precedent:** StS Ascension 1-20, Monster Train covenants, Balatro stakes. Each step is one readable rule that takes away a comfort. **Not** a Hades Heat menu (MEMORY 2026-10-03: a ladder, not a menu).
- **Scrapline version:** keep 043 exactly. A rung opens by winning the one below, the default moves up, and NEW RUN starts at once. Each rung adds one rule through B1's `adds`, and the title line names it ("NEXT RUN: RUNG 5 · TRACKERS LOCK ON"). The rung order lives in data so you can reorder it after play-tests. Prefer rungs that take away free recovery or free dodges over rungs that add HP.
  - **Data-only now (085):** enemy damage +1 in every act; `pile_heal` 2 → 1; workshop repair 3 → 2 and `arrive.repair` 6 → 4; `front.damage` 3; B3's pace; start the run at 80% HP.
  - **Added when their A item ships:** elites with two affixes (A5, 089); trackers weighted 30/40/45 (A4a, 090); an extra escort wave at bosses (A2); later, lingering ground (A4b). A3 is **not** a rung, because it is in the base game (Q1).
  - **Rung candidates to revisit later:** the burning elite (after 089), a lost objective pushing the front (after B3 and A7-defend), `warlord_legend_pct 0` (only if Q5 says so).
  - **Per-crew record:** a display-only stamp of the highest rung each crew has won, on the crew card and in A23's roll call. It is **not** a per-crew default; MEMORY 2026-10-03 did not choose that.
  - **Where the ending sits** is your call (question 1 below).
- **Effort / impact:** M / high. Ships after B1 and PT15.
- **Measure:** rungs 0, 4 and 10 at 150 runs, as cumulative checkpoints (60 runs per rung can't resolve a 3-6 point step). The bot target is about 67% at rung 0 and about 15-30% at rung 10, with no single rung dropping more than ~12 points. Per-rung behaviour metrics: the share of fights costing ≤0 HP falls from 39% toward 20-25%; mean rounds per fight rise by no more than 0.5; estimated rounds per run are reported. Afterwards, re-run career.py for median runs to the ending, to the last unlock and to the last medal. **You judge:** did winning make you want the next rung?

**B5. Boss and warlord fights don't heal the crew** [3/3 for part 1]
- **Problem:** the heal-farm above. Late boss rounds have no threat, against Q1.
- **Precedent:** in StS, healing almost never happens inside a fight, so a long boss fight only bleeds you.
- **Scrapline version:** a fight-file `pile_heal: 0` (overlaying `rules.json`) on sorting_gate, the_pour, the_core and the three warlord files. Piles still count for salvage and still pay scrap. **Overtime** (the Reclaimer eating edge rows) is **held** until A1 is measured. If "The gate held" losses remain, overtime is the fix, drawn as floor, with every new field copied in `clone()`.
- **Effort / impact:** S / high. Lands in 083, as an A/B separate from A1 and A2.
- **Measure:** `balance_fights --b` on run-built boss fights (`dump_boss_fights.gd`). Warlord HP cost rises to at least 1.5× the act's skirmish figure (Act 3: about 0 → about 8). Gate losses where crew HP rose go from 9/10 to 0. **You judge:** did a boss still scare you after round 5?

**B6. No dead arm in the starting kit; Focus gets a price** [3/3, narrowed]
- **Problem:** "ignore half your kit, press Focus". Rounds have one obvious answer (Q1), and every first run plays the same.
- **Precedent:** ITB starting weapons each own a different verb. StS starters carry one signature card each. Cobalt Core and Wildfrost price even small buffs.
- **Scrapline version:** data through keys `apply_bonus` already reads.
  - **Saw:** stops being a copy of the Cleaver (for example `tears` at 4).
  - **Focus:** costs 1 heat **or** counts as the machine's move, decided by its own A/B. Heat binds today, so the "counts as the move" option may be the safer one.
  - **Hammer and Pulse:** touched only if `balance_fights --arms` puts them outside the noise. You called the Hammer's shove "a find", and MEMORY 2026-10-12 found "-8.2 on 60 fights" was noise.
  - **T2 (trait ownership) comes first**, because Saw-tears overlaps A8's Rending Grip.
- **Effort / impact:** S / medium-high.
- **Measure:** no two arms give byte-identical rows. Focus uses fall from 1.7 a fight to about 0.8-1.2, while Charge, Dash and Barricade rise. Overheats don't fall. Run win rate is reported. **You judge:** in the first fight of a run, do all six starting arms have a job?

**B7. Act conditions, and warlords rotated across acts** [3/3 for stage a; merges replay G6]
- **Problem:** run 5 has the same skeleton as run 1 (Q2).
- **Precedent:** StS shows each act's boss from a pool. Wildfrost and StS dailies roll a run-wide modifier.
- **Scrapline version:**
  - **(a)** An `act_condition` rolled per act from the run seed, out of the yard modifiers that already exist (dust, wires, scrap_rain, heat_wave). It is announced on the act briefing card and the map header ("THE SLAG FLATS · HEAT WAVE") and applies to every fight in that act.
  - **(a')** The three warlords rotated across acts with escorts scaled to the act. This is data only and gives 6 orderings.
  - **(b) Deferred:** new gate and warlord files. That is L effort (fight files, models, rigs), and it waits until A1/A2 make the bosses good fights.
- **Effort / impact:** S-M / medium.
- **Measure:** over 300 seeds, each condition appears in 20-35% of acts. `balance_fights --b` per condition keeps win rate within 5 points, so a condition changes the puzzle, not the power. verify_run: the same seed gives the same region. **You judge:** did run 3 feel different from run 1, and is a whole act of dust fun or tedious?

**B8. Seed code, PLAY THIS SEED, and run history** [3/3 for the narrow version; merges run G5, replay G4, difficulty #6 and dominant #6d]
- **Problem:** determinism makes seeded runs free, but nothing uses that.
- **Precedent:** StS and Balatro show the seed on game over and accept one. Hades and ITB keep a run history.
- **Scrapline version:**
  - The run-over screen shows the seed as a short word code, with PLAY THIS SEED as a `UIKit.choice`, and NEW RUN gets a seed field.
  - `Profile.run_history`: the last 50 runs, each with seed, crew, rung, act reached, what wrecked the crew, and the final parts. Written by a Profile command and shown as a ledger on the UNLOCKS panel.
  - **Rules the proposals missed:**
    - A seeded run started while a live run exists must refuse, or use its own save slot. One `user://run.json` would otherwise overwrite your run.
    - The code carries the content version, because a code from another build makes a different region.
    - Seeded wins don't count toward the ladder or unlocks.
  - The **daily/weekly yard** is deferred and asked below.
- **Effort / impact:** S / medium-high.
- **Measure:** verify_run: a code round-trips to the identical RunState. verify_save: the history survives a restart. **You judge:** after a loss, did you want to replay that seed?

**B9. Each crew changes one run rule** [2/3; dominant #6a]
- **Problem:** crew choice fades by Act 2 (0.98 starting parts left).
- **Precedent:** Balatro decks are one rule each; ITB squads each own a verb.
- **Scrapline version:** a `rules` block per crew in `meta.json`, from keys that already exist. For example: Salvagers see 4 salvage options; the Wall starts every fight with Barricade ready. The Runners' proposed "move after attack for all" collides with A11's ROOTED teaching, so the Runners need another rule. Entered in the T2 table. Unlocks only: it changes how you play, not your power.
- **Effort / impact:** S-M / high (inferred).
- **Measure:** `run_bot --runs 40` per crew: crew win rates within about 10 points of each other, and switching the rule off with `--set` moves at least one behaviour metric. **You judge:** does each crew play differently by Act 2?

**B10. Three medals per crew instead of grind counters** [2/3; replay G3, merges dominant #6b]
- **Problem:** 11 of 26 unlocks are grind, and some fall in run 1 without being aimed at.
- **Precedent:** ITB squad achievements; Balatro stake stickers.
- **Scrapline version:** 3 `medals` per crew in `meta.json`, read from feats `tally_feats` already counts plus a few run-end flags. Pick them to push against the dominant lines: "win with no legendary fitted", "win at rung 4+ without a workshop", "win with no machine wrecked". Rewards are cosmetics, plates and later crews, never stats. **Migrate** the existing "play N" unlocks; don't revoke anything already earned.
- **Effort / impact:** S / medium. Profile only, no hash change.
- **Measure:** in a career.py replay, fewer than 20% of medals fall to the non-aiming bot within 10 runs. verify_run_ui shows the stamp after a win.

**Folded into existing items, not new B items:** a "SCRAP instead" option at hoards goes into **A9** (the reworked hoard was 0/3 on its own). The elite scrap cut 20 → 14 goes into **A5**'s measurement in 089. RunBot reading node risk instead of its hard-coded -20/-30 (`run_bot.gd:236-263`) goes into **T1**.

**Dropped:**

| Proposal | Vote | Reason |
|---|---|---|
| Wary yard (enemies avoid drums and pits) | 0/3 | Works against the board as a weapon: only 1% of deaths are pits already. It moves every bot number and the fingerprint |
| A lost objective pushes the front | 1/3 | Changes nothing until B3 makes the front bite. DEFEND is already lost 59%. Revisit as a rung after B3 and A7-defend |
| Burning elite / cheaper elite scrap | 0/3 | Needs A5, A7 and T1. The evidence is biased (the bot skips elites when hurt) |
| Danger skull per node | 0/3 | B2 shows the facts instead |
| Per-crew ladders with their own default rung | 0/3 | MEMORY 2026-10-03 did not choose this. Only the record stamp survives (B4) |
| Challenge yards / weekly contract | 1/3 | Not data-only as claimed. Revisit after the ladder |
| New boss files per act | stage b | L effort. Fix the bosses (083) before multiplying them |
| Hoards as a choice, and the refinery stops making legendaries | 0/3 | Waits on A9 and Q5 |

**New tooling:**
- **T4, replay clock:** re-run `career.py` after B4, B9 and B10 and report the median number of runs to the ending, the last unlock and the last medal.
- **T5, measurement rule:** for run dials, behaviour metrics (fights per run, bites, HP-per-fight buckets, byround) come first. Win rate counts only at 150+ runs or at the ladder checkpoints.

### 8.4 Revised iteration sequence from 082

**Play-test 15 still comes before 082.** Further play-tests come **after 083, after 085 and after 090**, because each of those changes pressure or difficulty.

| Iteration | Goal | Contents | Acceptance checks |
|---|---|---|---|
| **082-truth-and-speed** | Stop teaching a false rule; faster playback; a ladder that does what it says | A11, A13, A16 (speed dial only, **no opening skip**, Q3), A22, minimal A24, **B1** | `tools/check.sh` green. verify_onboarding: no "any order", ROOTED warning shown, no `(\d{3})` in player text. Event stream identical at 1x and 3x. Enemy phase under 1.5 s at 2x. B1: verify_run tier × act assertion passes; `--fingerprint` TOTAL unchanged at tier 0; tier text matches the dump in all 3 acts |
| **083-the-boss-is-the-fight** | Bosses end on the kill, press from round 1, and stop healing the crew | A1, then A2, **B5** in its own A/B, A19 (the push-in only if you say yes to section 6, question 4) | verify_combat: the Core's death ends the fight with drones alive. 0 rounds after the keeper dies; boss rounds ≤ 8; HP lost per boss rising across the acts (about 4/8/12). B5: gate losses with rising crew HP → 0. byround on boss fights: rounds 4+ have 3 or more mean targets. `run_bot --runs 150`: win rate reported, falling by no more than 8 points. **Play-test** |
| **084-know-the-road** | Every map node is a choice; runs can be replayed | **B2**, **B8**, **B3** A/B (R7 in its own A/B) | verify_run: preview = `_make_fight` over 300 regions; a seed code round-trips; a seeded run never overwrites a live save. B3: explorer at 15-17 fights per run, bites in 30% or more of explorer acts, win rate at 150 runs. TOTAL unchanged for B2/B8 |
| **085-the-ladder** | A long, honest reason to climb | **B4** with data-only rungs and the per-crew record stamp; T4 | Rungs 0/4/10 at 150 runs: monotone, top rung 15-30% for the bot, no step over ~12 points. Fights costing ≤0 HP fall toward 20-25%. Rounds per run reported. career.py medians reported. Ladder line shot on the title. **Play-test** |
| **086-cancel-and-explain** | Signature moments and numbers become readable | T3, A17, A12, A20 (A18 if the budget allows) | As in section 5 |
| **087-trophies** | Salvage pays off how you played | T1, A7, A21, A7-defend | As in section 5, with the win-rate target changed to "reported" |
| **088-rules-not-numbers** | Level-ups, sets, legendaries and the starting kit change what a machine does | T2, A8, **B6** (Saw first, Focus in its own A/B), then A9 (with "SCRAP instead") and A10 per Q5/Q6 | `balance_fights --arms 150`: no byte-identical rows, no legendary above +15, Focus uses 0.8-1.2 a fight, overheats not lower |
| **089-elites** | An elite is a different problem | A5, plus its rung (two affixes) | As in section 5, plus the rung checkpoint |
| **090-pressure** | Every round holds something (Q1). Required now | **A3 in the base game**, then A4(a) in a later A/B, plus their rungs | byround: rounds 4+ have 3 or more mean targets and 45% or fewer forced turns. Rounds per fight up by no more than 1.5. Rung-0 win rate at or above ~55% with Act 2-3 losses reported. **Play-test before A4(b)** |
| **091-crews-and-region** | Run 5 doesn't look like run 1 | **B9**, **B10**, **B7**(a)+(a') | Crew win rates within ~10 points; each rule moves a behaviour metric. Medals: fewer than 20% fall to the bot within 10 runs; old unlocks migrated. Conditions: 20-35% each, within 5 points each. Same seed gives the same region. career.py re-run |
| **092-onboarding** | A new player meets tear, pit and cancel in the first 5 minutes | A15, A14, A23 (roll call shows rung and medals) | As in section 5 |
| **093-act-3-variety** | Openers can't be memorised | A6 | As in section 5 |
| *Ship prep* | Android | A25, the rest of A24 | As in section 5 |

The main change from section 5: replay and difficulty work (B1, B3, B4, B8) moves ahead of the readability items, as you asked. Readability still lands before any new content that would crowd the HUD (A5's tags, T3).

### 8.5 Remaining questions for you

1. **Where does the ending sit on a ~10-rung ladder?** On the top rung, as decided on 2026-10-03, the story would come at an inferred 25-40 runs. On rung 3-4 it would come at about 5-8 runs, with the higher rungs as the long tail.
2. **Should a sideways step on the map already cost something at the default difficulty** (B3 as the rung-0 default), or only on higher rungs?
3. **A daily, a weekly, or neither?** That would be a seeded run with one fixed condition and a local best score. At 70-100 min a run, a daily is a bigger commitment than StS's.
4. **A start-of-run pick (StS's Neow)?** That would be 1 of 3 announced boons, each with a cost, for example "a rare arm, but the Reclaimer starts a column ahead". One skeptic raised it; no lens proposed it.

Questions 4-9 and 11 from section 6 are still open and unchanged; 1, 2, 3 and 10 are answered (section 8.1).
