extends RefCounted
## Levels.gd — the 40 levels. The data lives in Worlds.gd (8 worlds x 5 levels); this file builds the
## list once and serves it as LEVELS (look, weather, difficulty, enemy species, hazards, boss ...).

const WorldsScript := preload("res://Worlds.gd")

const LAST := 39

## Patrol routes used for the extra guards each level adds (room-local coordinates).
const EXTRA_ROUTES: Dictionary = {
	"A": [Vector2(760, 200), Vector2(1000, 200), Vector2(1000, 450), Vector2(760, 450)],
	"B": [Vector2(576, 160), Vector2(576, 490)],
	"C": [Vector2(323, 150), Vector2(323, 540)],
	"D": [Vector2(150, 224), Vector2(1000, 224)],
	"E": [Vector2(160, 395), Vector2(990, 395)],
	"F": [Vector2(600, 230), Vector2(600, 420)],
}

static var LEVELS: Array[Dictionary] = WorldsScript.build()


## Which world (0-7) a level belongs to, and which stage (0-4) inside it.
static func world_of(level: int) -> int:
	return level / 5


static func stage_of(level: int) -> int:
	return level % 5
