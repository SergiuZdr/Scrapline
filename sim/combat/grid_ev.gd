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
const INTENT_SET: int = 4    ## actor will fire weapon v1 at hex (x, y)
const ATTACK: int = 5        ## actor fires weapon v1 at hex (x, y); v2 = where it stopped, packed y * 64 + x
const DAMAGE: int = 6        ## actor hit target for v1; v2 = target's hp left. actor -1 = terrain
const DESTROYED: int = 7     ## target destroyed by actor
const MISSED: int = 8        ## actor's attack hit nothing; (x, y) = where it landed
const TURN_END: int = 9      ## the player ended the turn; enemy intents resolve next
const FIGHT_END: int = 10    ## v1 = outcome (CombatState.WON / LOST)
const SHOVED: int = 11       ## actor shoved target to (x, y); v1/v2 = where it was
const BUMP: int = 12         ## target was shoved into something at (x, y) and took v1 (actor = shover)
const HEAT: int = 13         ## actor's heat is now v1 of cap v2
const OVERHEAT: int = 14     ## actor reached its heat cap: no attack next round
const SEIZED: int = 15       ## actor starts this round seized (cannot attack); heat reset to 0
const VENTED: int = 16       ## actor vented; heat now v1
const MARKED: int = 17       ## actor marked target
const PART_TORN: int = 18    ## target lost its arm v1 (GridUnit.ARM_L / ARM_R) to actor
const PILE_DROPPED: int = 19 ## a scrap pile worth v1 appeared at (x, y) (target = the unit that burst)
const PILE_TAKEN: int = 20   ## actor collected the pile at (x, y) worth v1, patching v2 HP

const F_KIND: int = 0
const F_ACTOR: int = 1
const F_TARGET: int = 2
const F_X: int = 3
const F_Y: int = 4
const F_V1: int = 5
const F_V2: int = 6

const NAMES: PackedStringArray = [
	"FIGHT_START", "ROUND_START", "STEP", "MOVED", "INTENT_SET", "ATTACK",
	"DAMAGE", "DESTROYED", "MISSED", "TURN_END", "FIGHT_END", "SHOVED", "BUMP",
	"HEAT", "OVERHEAT", "SEIZED", "VENTED", "MARKED", "PART_TORN", "PILE_DROPPED", "PILE_TAKEN",
]


static func describe(e: Array) -> String:
	var kind: int = int(e[F_KIND])
	var name: String = NAMES[kind] if kind >= 0 and kind < NAMES.size() else "?%d" % kind
	return "%-11s actor=%d target=%d at=(%d,%d) v=(%d,%d)" % [
		name, e[F_ACTOR], e[F_TARGET], e[F_X], e[F_Y], e[F_V1], e[F_V2]]
