# Plan — Enemies and AI

**Status:** basic intent AI built in 002 (`sim/combat/intent_ai.gd`). For each reachable tile × 4 directions it scores the shot: a hit on a foe is 100 + damage×10 + missing HP of the target, +60 if it kills, and friendly fire is −100. If nothing is worth shooting it closes to a preferred distance (1 for melee, 3 for ranged). Ties are broken by a murmur3 hash. The roster comes in 005.

## Enemy kinds (built in 006)

| Kind | Rule |
|---|---|
| Tracker | Intent locks onto a machine; the shot follows it. Counter: line of sight, range, kill, shove |
| Bomber | 4 damage to all 6 neighbours on death, both sides |
| Warden | Neighbours take 2 less per hit |
| Hive | Sets down one pad beside itself; it builds a drone every 2 rounds (warning red the round before) unless something stands on it (009) |
| Sorter (013) | The Sorting Gate's keeper: authored (Citadel frame, maul, mortar, 18 HP), 3 less from every hit while any **gate pylon** stands (props, 6 HP, red beams to it), and a pad that builds a drone every 3 rounds |
| Reclaimer drone (013) | Arrives in a fight fought in the column the Reclaimer takes next: two, at round 3, on the crew's back row, marked a round ahead; a machine standing on the hex blocks it |

The AI re-scores its 6 best candidates by dry run (`IntentAI._dry_value`), so it uses
drums and pits and avoids its own bombers' blasts.

## Enemies are constructs too

Enemies use the **same part system** as the player. A "Reclaimer Harvester" is a chassis
with two arms, a core and a module, so everything the player learns about parts reads on
enemies too. When an enemy dies, its parts are what you salvage.

A few **unique enemy-only parts** give bosses and elites identity. They can be unlocked
as blueprints later.

## Factions (proposed)

| Faction | Where | Style |
|---|---|---|
| Scavenger gangs | Act 1 | mixed ad-hoc builds, cowardly, flee when damaged |
| Reclaimer drones | all acts, the front | swarm, weak alone, spawn reinforcements |
| Yard sentinels | Act 2 | old guard machines: anchors and marksmen, heavy armour |
| The Foundry Mind | Act 3 | coordinated, combo attacks, fields that change the terrain |

## Intent AI

- In the INTENT phase each enemy scores candidate actions with a **rule list** and
  commits to the best one. It then **shows** the action and never changes it.
- The rule format is based on the old `sim/doctrine/` engine (conditions to action,
  first match wins). That engine is being adapted rather than rewritten.
- Behaviour profiles by role: brawlers close in and hit the nearest target; marksmen stay
  at range and target the lowest-HP unit; anchors guard allies; supports mark and heal.
- **Tie-breaks are deterministic** (seeded hash ending in the unit ref), a lesson carried
  over from the old sim's `_tie_key` bug.

## Elites and bosses

**Built (013): the Sorter at the Sorting Gate** (`data/fights/sorting_gate.json`). The gate is
its own authored map -- the Sorter between two pylons, scrap walls, three escorts rolled by
the run -- and the first boss teaches the lesson the plan asked for: part targeting, by way of
the pylons (break the shield, then burst the keeper). The player's bot values breaking a pylon
(`IntentAI.SCORE_PYLON`). The multi-part Colossus-style boss below stays the plan for acts 2-3.

**014: the gate's pressure comes from its ground and its clock.** Tried side by side (150 runs
each): the escort count (2/3/4 in 013) and the summon pace (every 2 rounds) barely move the
result; the round limit does (12 rounds: 86.0% down to 80.0%). With two thirds of the bot's
losses already at the gate, it was not made harder. The pylons moved to the back row behind
the Sorter, each beside a heap, so the shield is reached by piercing through the keeper, by
lobs, or by arcs run through the heaps. Same difficulty, a different fight.


- **Elite** = a normal enemy with a rare part and one affix (armoured, volatile, regenerating…).
- **Boss** = a multi-part construct in the style of the old Colossus: limbs as separate
  targetable units and a guarded core. The old `is_vital` and `guard_refs` design carries
  straight over to the grid.
- One boss per act. Each teaches a lesson the next act assumes you have learned (shove,
  heat management, part targeting).

## Roster target

About 20 enemy archetypes plus 3 bosses at launch. Each act has 6–8, with some overlap.

## Act 3 (025): the Foundry Mind

- **Conduit** (a kind): every ally next to it hits 1 harder, drawn as red links. The combo the
  plan asked for, readable in one glance: the telegraphed totals already include it, so killing
  or shoving the conduit visibly lowers every number around it.
- **The Core** (kind `heart`, the gate): never moves (`still`), anchored, builds drones every 4
  rounds, and every third round marks every hex within 2 of it -- a round later it pulses 4 into
  each of the crew still in the ring. The fight is a rhythm: hit it, then be out of the ring when
  the red goes up. Its own side is not hurt by the pulse.
- The terrain that changes the fight: **furnace flues** blow every other round (both sides; the
  enemy AI stays off a flue about to blow, the player's bot too).

## Escalation (027)

A keeper with an `enraged` block changes its rules once, at half HP, and calls guards for the next
round: The Pour floods every round (four hexes, 3 a round), the Core pulses every other round,
3 hexes out, for 5. Each calls three drones. The fight has a second half.

## Warlords (030)

One per act, a detour in the middle of the map: the Grinder (Act 1, `aura` 2 -- a saw ring at round
start), the Magnet King (Act 2, `haul_every` 2 / `haul_radius` 3 -- hauls the crew a hex closer),
the Twin Furnaces (Act 3, `twin_armor` 2 while both stand). Each is an authored board with
`"warlord": true` and its keepers, escorts rolled; its hoard holds a legendary.

## Bosses (038)

The gates' keepers: the Sorter (18 HP, pylons), the Pour (52, floods 4 every 2 rounds; boils over:
5 every round at 3), the Core (72, shielded -2 by its two conduits via `cover_kind`, pulses every 2;
erupts: every round, radius 3, 5). Authored machines a gate must keep are counted in `keepers`.
Drawn 1.75x in crimson (warlords 1.4x, gunmetal) with a boss bar (`CombatHUD.set_boss`).
