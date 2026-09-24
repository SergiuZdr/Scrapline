# Plan — Constructs and parts

**Status:** implemented in 003 (2026-09-24). Every part has a `grid` block; a construct is
built from its five parts' blocks plus its chassis role's trait (`data/combat/rules.json`).
Salvage and the cargo hold are 004; content growth is 005.

## The crew

- A run is played with **exactly 3 constructs**, always (decided 2026-09-24). You pick a
  starting crew from the crews you have unlocked.
- A destroyed construct leaves a **chassis wreck**. A workshop rebuilds it for scrap with
  empty sockets; the parts it carried are lost.
- Each construct has **5 sockets**: `chassis`, `arm_l`, `arm_r`, `core`, `module`.
  These are the same keys the existing art pipeline and loadout screen already use.

## What each slot does

| Slot | Grants | Existing data it maps from |
|---|---|---|
| Chassis | HP, armour type, move range, **role trait** | `hp`, `armor_type`, `move_speed`, `role` |
| Arm (×2) | one weapon action each: shape, damage, heat cost | `weapon_class`, `ability` |
| Core | damage type of both arms, max heat, vent amount | `damage_type`, `heat_max`, `vent_rate` |
| Module | one utility action OR passive | `mo_*` (governor, coolant, servo, scavenger…) |

### Role traits (chassis passives)

| Role | Trait |
|---|---|
| brawler | +1 melee damage (built) |
| line | can move after attacking (built) |
| marksman | +1 range on line and lob weapons (built) |
| anchor | cannot be shoved (built) |

## Salvage: how the crew changes during a run

- **After a fight** you choose 1 of 3 parts (more for a clean win). An elite adds a
  guaranteed rare part.
- **During a fight**, torn-off parts and wrecks drop salvage on the board. A construct can
  spend its action to **pick up** a part it is standing on or next to. A part can be
  **fitted mid-fight** only at a salvage point (scrap heap). Otherwise it goes to the cargo
  hold.
- **Cargo hold** holds 4 spare parts (open question). Refitting is free between fights.
- **Workshop nodes** repair damaged parts and rebuild wrecks for scrap.

## Part rarity and upgrades

- Rarity: common, uncommon, rare, prototype.
- **No levels.** A part can be **tuned once** at a workshop, which picks one of two
  upgrades (e.g. hammer: +1 damage *or* shove 2). One choice per part keeps it simple
  and makes each copy of a part different.
- **Synergies** come from combinations rather than set bonuses: a thermal core with a
  mortar fits a burn build, a scanner with a railgun fits a mark-and-snipe build, a
  bypass module unlocks overdrive (double damage and triple heat) on any arm.
  Existing `linkages.json` ideas get reviewed in 005.

## Content targets

| Launch | Chassis | Arms | Cores | Modules |
|---|---|---|---|---|
| Existing (retune) | 10 | 10 | 10 | 10 |
| Launch target | 12 | 25 | 12 | 20 |

Most of the variety comes from arms and modules, the slots that grant actions.

## Data

Parts stay in `data/parts/*.json`. Add fields for the grid game (`move`, `grid_hp`,
`shape`, `range`, `damage`, `heat`, `tuning`) and remove fields for the continuous sim
(`speed` ticks, `range_bonus` in cm) once 003 lands.
