# Iteration 006 — Fight depth

**Status:** built; **waiting for the user's play-test** (005 + 006)
**Started:** 2026-09-24 · **Finished:** 2026-09-24 (pending play-test)
**Answers:** play-test 1 — **PT1-1** ("a boring chore; little thought needed"), with the
user's picks: active part abilities, interactive terrain, distinct enemy types. (Fight
objectives came in 005.)

## Why fights were a chore (diagnosis)
One move and one attack a turn, every enemy the same kind of threat, a board that is
scenery, and dodging that costs nothing. The only question each turn was "what can I hit
from here". 006 adds **things that interact**, so a turn has combinations to find:
shove an enemy into a pit, pull a bomber into its friends, block a tracker's line with
a barricade, detonate a barrel next to a warden.

## Design

### Terrain that does something
- **Explosive barrel** (`b`): an object with 1 HP that blocks movement and shots. When it
  takes any damage (a shot, a splash, something bumped into it) it **explodes: 3 damage to
  all 6 neighbours**, which can set off the next barrel.
- **Pit** (`o`): cannot be walked into; shots pass over it. **Anything shoved into a pit
  is destroyed**, player or enemy.
- **Crate wall** (`c`): breakable cover. It blocks like a scrap heap, but has 3 HP and
  breaks into rubble.
- Existing: scrap heap (permanent block), rubble (slow, cover), ridge (range), slag
  (burns at round start).

### Abilities from parts
Each machine gets its chassis's ability, plus its module's if it has one. An ability has
a **cooldown** in rounds. Some are **free** (they do not use the machine's action):

| Ability | From | Free? | Effect |
|---|---|---|---|
| Charge | brawler frames | no | Run up to 3 hexes straight at an enemy; 3 damage and a shove. Stops at the first thing in the way |
| Grapple | Hauler frame | no | Pull a unit up to 3 hexes away along a straight hex line until it is adjacent |
| Barricade | anchor frames | no | Drop a crate wall on an adjacent empty hex (3 HP) |
| Focus | marksman frames | yes | This machine's next shot this turn deals +2 |
| Dash | Skirmisher / Courier frames, Servo module | yes | Move again, up to 2 hexes, even after acting |
| Overdrive | Bypass / Overclock / Capacitor modules | yes | Next attack this turn +2 damage, +2 heat |
| Flush | Coolant module | yes | Heat to 0 |
| Shield | Reactive module | no | This machine and its neighbours take 2 less from every hit until your next turn |
| Magnet | Scavenger module | yes | Collect a scrap pile up to 2 hexes away |

### Enemies with rules
An enemy can have a **kind**, shown on its tag and in its info:

| Kind | Rule | What it asks of the player |
|---|---|---|
| **Tracker** | Its intent locks onto a **machine**, not a hex. The shot follows that machine. | You cannot step away. Break its line of sight (terrain, a barricade, another body), get out of range, kill it, or shove it |
| **Bomber** | Explodes when destroyed: 4 damage to all 6 neighbours, its own side included | Kill it next to its friends, never next to yours |
| **Warden** | Its neighbours take 2 less from every hit | Kill it or shove it away first |
| **Hive** | Every 2 rounds it marks a neighbouring hex and spawns a drone there next round | Stand on the marked hex to block the spawn, or kill the hive |

### Previews are the real rules on a copy
With explosions, chains, pits and bombers, a hand-worked preview would eventually lie.
The attack preview now **runs the real attack on a copy of the fight** and reports what
changed: every HP change, every kill, every shove, barrel and pit. The enemy AI uses the
same dry run to rank its best candidates, so it will also shove you into pits.

## Steps
1. Sim: props (barrels, crate walls), pits, dry-run preview, abilities with cooldowns,
   enemy kinds.
2. AI: the dry run for its top candidates; the kinds' behaviour; avoiding pits.
3. Data: ability blocks on parts, `data/combat/enemy_kinds.json`, new glyphs, fights with
   terrain, and generated fights that scatter props and roll kinds.
4. Tests for every rule, and balance tools.
5. Presentation: barrels, pits, crate walls, ability buttons with cooldowns, kind badges,
   explosion and pull and charge playback, and full-consequence previews in the panel.
6. Docs, then **the user plays 005 + 006**.

## Acceptance criteria
- [x] `verify_combat.gd` covers barrels (including chains), pits, crate walls, every
      ability, every enemy kind, and a preview that matches the real outcome in complex cases.
- [~] Bot numbers show dodging is no longer free: crew HP lost per fight well above 005's 1.5. **Mixed, see Result.**
- [x] Screenshots: a barrel's explosion preview, a tracker's locked intent, the ability bar, an armed charge.
- [ ] **The user plays and says whether a fight now takes thought.** ← next

## Result

### Built
- **Terrain that acts** (`data/terrain/tiles.json`): fuel drums `b` (1 HP; break → 3 damage
  to all 6 neighbours, chains), crate walls `c` (3 HP, block movement and shots), pits `o`
  (no walking in; shots pass over; shoved or dragged in = gone, no pile). Props live in
  `CombatState.props`; pits in `CombatSetup.pit`.
- **Nine abilities** (`data/combat/abilities.json`, `sim/combat/abilities.gd`) from chassis
  and modules: charge, grapple, barricade, focus, dash, overdrive, flush, shield, magnet,
  with cooldowns and free/action costs. `[ACT_ABILITY, ref, i, x, y]`.
- **Four enemy kinds** (`data/combat/enemy_kinds.json`): tracker (intent locks onto a
  machine), bomber (4-damage blast on death, both sides), warden (neighbours −2 per hit),
  hive (marks a hex, builds a drone there next round unless something stands on it).
- **Previews are dry runs**: `CombatSim.dry_run` executes the action on `CombatState.clone()`
  and `CombatSim.diff` reports what changed. The attack and ability previews show every
  HP change, destruction, pit fall and broken prop. A test proves the preview of a barrel +
  bomber chain equals what then happens.
- **AI**: the top 6 candidates are re-scored by dry run (so enemies use barrels and pits
  and avoid blowing up their own bombers next to friends); barrels are aim candidates;
  hives hang back. The bot uses Focus/Overdrive before attacking.
- **Content**: the three authored fights have drums, crate walls, pits and kinds; generated
  fights scatter 1–3 drums, 0–2 crate walls and 0–2 pits, and roll a kind per enemy with a
  chance rising by column (0% → 80%).
- **Scene**: pits with a glowing rim, drums, crate walls, explosions, falls, pulls, spawn
  marks ("DRONE NEXT ROUND"), kind and SHIELD tags, LOCKED intents, ability buttons with
  cooldowns, targeted abilities armed like weapons, and **tapping any hex explains what is
  on it** (a start on PT1-7, jargon).

### Checks
| Check | Result |
|---|---|
| `verify_combat.gd` | **103 passed** (35 new: drums and chains, crate walls, pits, all abilities, all four kinds, preview = outcome) |
| `verify_run.gd` | 46 passed (generated fights with terrain and kinds all build) |
| `verify_combat_input` / `verify_run_ui` / assembly / animation / save | 18 / 12 / 100 / 34 / 14 passed |
| `run_bot.gd --runs 50` | **78% wins** (005: 100%); every loss is the crew worn down over the run; 3.9 fights a run |
| `balance_fights.gd --fights 120` | random squads 90.8% (they carry no kinds); authored `proto_yard` crew now loses **13.4 HP per fight** (005: ~1) |
| Screenshots | `shots/006-start.png`, `006-barrel.png`, `006-charge.png` |

### What the numbers say
Where the new things are present, dodging stopped being free: the authored rout fight with
a tracker and a bomber costs the crew 13 HP, and full runs are now lost 22% of the time,
all by attrition, which is what HP carrying through the run was meant to create. The
random-squad tool understates this because its random enemies have no kinds. **The bot
still uses almost none of the new tools** (only boosts), so these numbers are a floor on
what the player can do, not a measure of it.

### What went wrong along the way (and is fixed)
1. The tracker test first stepped the victim out of range, which is legitimate
   counterplay rather than a dodge; the test now steps sideways within range.
2. The ability hint said "Rend Saw targets" while an ability was armed.
3. Ability details duplicated "Free".

## Next
**The user plays 005 + 006** (the hex board, objectives, piles, terrain, abilities, enemy
kinds). Then 007 (build progression) or corrections from the play-test first.

