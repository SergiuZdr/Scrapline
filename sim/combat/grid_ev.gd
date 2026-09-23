class_name GridEv
extends RefCounted

## Event vocabulary of the grid combat sim.
##
## Every event is a flat Array of ints, `[kind, actor, target, x, y, v1, v2]`, so the
## stream hashes cheaply and never carries an object the presentation could mutate.
## Presentation reads these and animates. It never works out an outcome for itself.

const FIGHT_START: int = 0
const ROUND_START: int = 1   ## v1 = round number
const STEP: int = 2          ## actor walked one tile to (x, y)
const MOVED: int = 3         ## actor finished a move at (x, y); v1/v2 = where it started
const INTENT_SET: int = 4    ## actor will fire in direction v1, order v2; (x, y) = tile it would hit now
const ATTACK: int = 5        ## actor fires in direction v1; (x, y) = where the shot stopped; target = unit hit or -1
const DAMAGE: int = 6        ## actor hit target for v1; v2 = target's hp left
const DESTROYED: int = 7     ## target destroyed by actor
const MISSED: int = 8        ## actor's shot hit nothing that can take damage; (x, y) = where it stopped
const TURN_END: int = 9      ## the player ended the turn; enemy intents resolve next
const FIGHT_END: int = 10    ## v1 = outcome (CombatState.WON / LOST)

const F_KIND: int = 0
const F_ACTOR: int = 1
const F_TARGET: int = 2
const F_X: int = 3
const F_Y: int = 4
const F_V1: int = 5
const F_V2: int = 6

const NAMES: PackedStringArray = [
	"FIGHT_START", "ROUND_START", "STEP", "MOVED", "INTENT_SET", "ATTACK",
	"DAMAGE", "DESTROYED", "MISSED", "TURN_END", "FIGHT_END",
]


static func describe(e: Array) -> String:
	var kind: int = int(e[F_KIND])
	var name: String = NAMES[kind] if kind >= 0 and kind < NAMES.size() else "?%d" % kind
	return "%-11s actor=%d target=%d at=(%d,%d) v=(%d,%d)" % [
		name, e[F_ACTOR], e[F_TARGET], e[F_X], e[F_Y], e[F_V1], e[F_V2]]
