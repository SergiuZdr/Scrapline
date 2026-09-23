# Plan — Enemies and AI

**Status:** basic intent AI built in 002 (`sim/combat/intent_ai.gd`). For each reachable tile × 4 directions it scores the shot: a hit on a foe is 100 + damage×10 + missing HP of the target, +60 if it kills, and friendly fire is −100. If nothing is worth shooting it closes to a preferred distance (1 for melee, 3 for ranged). Ties are broken by a murmur3 hash. The roster comes in 005.

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

- **Elite** = a normal enemy with a rare part and one affix (armoured, volatile, regenerating…).
- **Boss** = a multi-part construct in the style of the old Colossus: limbs as separate
  targetable units and a guarded core. The old `is_vital` and `guard_refs` design carries
  straight over to the grid.
- One boss per act. Each teaches a lesson the next act assumes you have learned (shove,
  heat management, part targeting).

## Roster target

About 20 enemy archetypes plus 3 bosses at launch. Each act has 6–8, with some overlap.
