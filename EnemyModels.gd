extends Node
## EnemyModels.gd — species → GLB path + shared SubViewport pool for mobile.
## Autoload as EnemyModels.

const MAX_LIVE_VIEWS := 10
const VIEW_SIZE := Vector2i(192, 192)
const FAR_LOD_DIST := 520.0
const NEAR_UPDATE_DIST := 640.0

const SPECIES_PATHS := {
	"bat": "res://assets/models/enemies/bat/model.glb",
	"crab": "res://assets/models/enemies/crab/model.glb",
	"ghost": "res://assets/models/enemies/ghost/model.glb",
	"ghoul": "res://assets/models/enemies/ghoul/model.glb",
	"golem": "res://assets/models/enemies/golem/model.glb",
	"hound": "res://assets/models/enemies/hound/model.glb",
	"imp": "res://assets/models/enemies/imp/model.glb",
	"knight": "res://assets/models/enemies/knight/model.glb",
	"scorpion": "res://assets/models/enemies/scorpion/model.glb",
	"shroom": "res://assets/models/enemies/shroom/model.glb",
	"skeleton": "res://assets/models/enemies/skeleton/model.glb",
	"slime": "res://assets/models/enemies/slime/model.glb",
	"spider": "res://assets/models/enemies/spider/model.glb",
	"vulture": "res://assets/models/enemies/vulture/model.glb",
	"wasp": "res://assets/models/enemies/wasp/model.glb",
	"wraith": "res://assets/models/enemies/wraith/model.glb",
	"yeti": "res://assets/models/enemies/yeti/model.glb",
}

## Canonical anim names we expect in every enemy GLB.
const ANIMS := {
	"idle": "idle",
	"move": "move",
	"run": "run",
	"attack": "attack",
	"hit": "hit",
	"death": "death",
}

var _scene_cache: Dictionary = {}  # path -> PackedScene
var _live: Array = []  # EnemyLook nodes currently holding a live SubViewport


func has_model(species: String) -> bool:
	if not SPECIES_PATHS.has(species):
		return false
	return ResourceLoader.exists(String(SPECIES_PATHS[species]))


func model_path(species: String) -> String:
	return String(SPECIES_PATHS.get(species, ""))


func get_packed(species: String) -> PackedScene:
	var path := model_path(species)
	if path == "":
		return null
	if _scene_cache.has(path):
		return _scene_cache[path]
	if not ResourceLoader.exists(path):
		return null
	var packed: PackedScene = load(path)
	if packed:
		_scene_cache[path] = packed
	return packed


func request_slot(look: Node) -> bool:
	# Drop farthest / oldest if over budget
	_prune_dead()
	if look in _live:
		return true
	if _live.size() < MAX_LIVE_VIEWS:
		_live.append(look)
		return true
	# Evict the look farthest from the player camera / player
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		var old: Node = _live.pop_front()
		if old and old.has_method("release_3d_slot"):
			old.release_3d_slot()
		_live.append(look)
		return true
	var worst: Node = null
	var worst_d := -1.0
	for n in _live:
		if not is_instance_valid(n):
			continue
		var d: float = (n as Node2D).global_position.distance_squared_to(player.global_position)
		if d > worst_d:
			worst_d = d
			worst = n
	if worst and worst != look:
		if worst.has_method("release_3d_slot"):
			worst.release_3d_slot()
		_live.erase(worst)
	_live.append(look)
	return true


func release_slot(look: Node) -> void:
	_live.erase(look)


func _prune_dead() -> void:
	var kept: Array = []
	for n in _live:
		if is_instance_valid(n):
			kept.append(n)
	_live = kept


func resolve_anim(anim: AnimationPlayer, want: String) -> String:
	if anim == null:
		return ""
	var names := anim.get_animation_list()
	for n in names:
		var s := String(n)
		if s == want or s.ends_with("/" + want) or s.get_file() == want:
			return s
	for n in names:
		if want.to_lower() in String(n).to_lower():
			return String(n)
	# Common Mixamo / Blender aliases
	var aliases := {
		"move": ["walk", "Walk", "crawl", "fly"],
		"attack": ["slash", "Slash", "punch"],
		"hit": ["react", "Hurt", "damage"],
		"death": ["die", "Death"],
	}
	if aliases.has(want):
		for a in aliases[want]:
			for n in names:
				if String(a).to_lower() in String(n).to_lower():
					return String(n)
	return ""
