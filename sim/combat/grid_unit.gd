class_name GridUnit
extends RefCounted

## One machine on the board, or a salvage cache. Plain data: the rules live in `CombatSim`,
## and every number here was resolved from the unit's parts by `CombatSetup`.

const TEAM_PLAYER: int = 0
const TEAM_ENEMY: int = 1

## Index into `weapons`: the arm sockets, left then right.
const ARM_L: int = 0
const ARM_R: int = 1

## `team * 10 + slot`: cheap to compare, cheap to serialize, deterministic to sort.
var ref: int = 0
var team: int = TEAM_PLAYER
var slot: int = 0
var name: String = ""
## chassis, core, arm_l, arm_r, module -- the order `ConstructView` reads.
var part_ids: PackedStringArray = []
var role: String = ""
## A salvage cache (the defend objective): cannot move, act or be shoved.
var objective: bool = false
## An enemy's special rules ("tracker", "bomber", "warden", "hive"), or "". See
## `data/combat/enemy_kinds.json`.
var kind: String = ""
## Active abilities from its parts: `{ "id", "name", "kind", "cooldown", "free", ...params,
## "wait": rounds until usable again (0 = ready) }`.
var abilities: Array[Dictionary] = []
## A one-shot bonus for this machine's next attack this turn (Focus, Overdrive).
var boost_damage: int = 0
var boost_heat: int = 0
## Damage taken off every hit until the player's next turn (Shield).
var shield: int = 0

var x: int = 0
var y: int = 0
var hp: int = 1
var max_hp: int = 1
var move: int = 3
var armor: int = 0
## Index into the rules' `armor_types` / `damage_types` (the wheel's columns and rows).
var armor_type: int = 0
var damage_type: int = 0

## Two weapons, one per arm (see `weapon` in CombatSetup for the keys). A torn-off arm's
## weapon stays in the list with `"torn": true`, so indices never shift mid-fight.
var weapons: Array[Dictionary] = []
## Added to every shot's damage / heat / range (core, module, role).
var damage_bonus: int = 0
var heat_bonus: int = 0
var range_bonus: int = 0
var melee_bonus: int = 0

var heat: int = 0
var heat_cap: int = 6
var vent: int = 1
## Reached the heat cap: loses its next round's attack, then resets to 0.
var overheated: bool = false
## Cannot attack this round (was overheated last round).
var seized: bool = false
## The next hit it takes deals `mark_bonus` more, then the mark clears.
var marked: bool = false

var unshovable: bool = false
## Whether destroying it leaves a scrap pile (play-test 4: not every enemy does). Decided
## once, seeded, when the fight is built -- and shown on its tag, so it is a target choice.
var carries_scrap: bool = true
var move_after_attack: bool = false

## False once destroyed. A destroyed unit stays on its tile as a wreck that blocks.
var alive: bool = true
var moved: bool = false
var acted: bool = false


func is_enemy_of(other: GridUnit) -> bool:
	return team != other.team


func can_fire(w: int) -> bool:
	return w >= 0 and w < weapons.size() and not bool(weapons[w].get("torn", false))


func ability_ready(i: int) -> bool:
	return i >= 0 and i < abilities.size() and int(abilities[i]["wait"]) <= 0


func has_weapon() -> bool:
	for w: int in weapons.size():
		if can_fire(w):
			return true
	return false


func copy() -> GridUnit:
	var u := GridUnit.new()
	u.ref = ref
	u.team = team
	u.slot = slot
	u.name = name
	u.part_ids = part_ids.duplicate()
	u.role = role
	u.objective = objective
	u.kind = kind
	for ability: Dictionary in abilities:
		u.abilities.append(ability.duplicate(true))
	u.boost_damage = boost_damage
	u.boost_heat = boost_heat
	u.shield = shield
	u.x = x
	u.y = y
	u.hp = hp
	u.max_hp = max_hp
	u.move = move
	u.armor = armor
	u.armor_type = armor_type
	u.damage_type = damage_type
	for weapon: Dictionary in weapons:
		u.weapons.append(weapon.duplicate(true))
	u.damage_bonus = damage_bonus
	u.heat_bonus = heat_bonus
	u.range_bonus = range_bonus
	u.melee_bonus = melee_bonus
	u.heat = heat
	u.heat_cap = heat_cap
	u.vent = vent
	u.overheated = overheated
	u.seized = seized
	u.marked = marked
	u.unshovable = unshovable
	u.carries_scrap = carries_scrap
	u.move_after_attack = move_after_attack
	u.alive = alive
	u.moved = moved
	u.acted = acted
	return u
