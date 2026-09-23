class_name GridUnit
extends RefCounted

## One construct on the grid. Plain data: the rules live in `CombatSim`.

const TEAM_PLAYER: int = 0
const TEAM_ENEMY: int = 1

## `team * 10 + slot`: cheap to compare, cheap to serialize, deterministic to sort.
var ref: int = 0
var team: int = TEAM_PLAYER
var slot: int = 0
var name: String = ""
## chassis, core, arm_l, arm_r, module -- the order `ConstructView` reads.
var part_ids: PackedStringArray = []

var x: int = 0
var y: int = 0
var hp: int = 1
var max_hp: int = 1
var move: int = 3
var attack_range: int = 1
var damage: int = 1
## The right arm's class: picks the attack animation and, in 002, melee vs ranged.
var weapon_class: String = ""

## False once destroyed. A destroyed unit stays on its tile as a wreck that blocks.
var alive: bool = true
var moved: bool = false
var acted: bool = false


func is_enemy_of(other: GridUnit) -> bool:
	return team != other.team


func copy() -> GridUnit:
	var u := GridUnit.new()
	u.ref = ref
	u.team = team
	u.slot = slot
	u.name = name
	u.part_ids = part_ids.duplicate()
	u.x = x
	u.y = y
	u.hp = hp
	u.max_hp = max_hp
	u.move = move
	u.attack_range = attack_range
	u.damage = damage
	u.weapon_class = weapon_class
	u.alive = alive
	u.moved = moved
	u.acted = acted
	return u
