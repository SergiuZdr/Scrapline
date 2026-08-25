class_name BattleSetup
extends RefCounted

## Everything needed to reproduce a battle, and nothing else.
##
## This is what a client submits alongside its order log when it reports a PvP
## result. The server rebuilds the units from these specs, replays the orders, and
## compares event-stream hashes. So it must contain no live object references and
## nothing that varies by machine -- only ids, integers, and the seed.

var seed_value: int = 0
var condition_id: String = ""
var map_id: String = ""

## Two squads. Each entry is a build spec:
##   {"name": "Ripper", "parts": {"chassis": "ch_brute", "core": "co_thermal", ...}}
## Index in the array is the formation slot: 0-1 front, 2-3 mid, 4-5 back.
var team_specs: Array[Array] = [[], []]


static func make(
	seed_value: int, team_a: Array, team_b: Array,
	condition_id: String = "", map_id: String = ""
) -> BattleSetup:
	var s := BattleSetup.new()
	s.seed_value = seed_value
	s.team_specs = [team_a.duplicate(true), team_b.duplicate(true)]
	s.condition_id = condition_id
	s.map_id = map_id
	return s


func specs_for(team: int) -> Array:
	if team < 0 or team >= team_specs.size():
		return []
	return team_specs[team]


func to_dict() -> Dictionary:
	return {
		"seed": seed_value,
		"condition": condition_id,
		"map": map_id,
		"teams": team_specs,
	}


static func from_dict(d: Dictionary) -> BattleSetup:
	var s := BattleSetup.new()
	s.seed_value = int(d.get("seed", 0))
	s.condition_id = String(d.get("condition", ""))
	s.map_id = String(d.get("map", ""))
	var teams: Array = d.get("teams", [[], []])
	var specs: Array[Array] = [[], []]
	for i: int in mini(2, teams.size()):
		specs[i] = teams[i]
	s.team_specs = specs
	return s
