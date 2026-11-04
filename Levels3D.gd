extends RefCounted
## Levels3D.gd — per-level 3D environment presets.
## Worlds 1–3 ship 3D kits (Emberfall approved; Mire + Crystal Deep pending review).
## Worlds 4–8 stay on the 2D fallback.

const PX_TO_M := 2.0 / 64.0  # TILE 64px → 2 m

## world_id used as folder under res://assets/models/env/
const WORLDS := {
	"emberfall": {
		"id": "emberfall",
		"kit": "res://assets/models/env/emberfall/",
		"fog_color": Color(0.35, 0.12, 0.06),
		"fog_density": 0.018,
		"ambient": Color(0.45, 0.28, 0.18),
		"ambient_energy": 0.55,
		"sun_color": Color(1.0, 0.55, 0.25),
		"sun_energy": 0.7,
		"sun_pitch_deg": -48.0,
		"torch_color": Color(1.0, 0.45, 0.15),
		"torch_energy": 2.2,
		"torch_range": 7.0,
		"max_torches": 8,
		"weather": "embers",
		"prop_density": 1.0,
		"outdoor": false,
		"outdoor_piece": "",
		"accent_piece": "rubble",
		"boss_piece": "brazier",
		"particle_color": Color(1.0, 0.4, 0.08, 0.8),
		"species": ["imp", "hound", "bat", "knight", "ghoul", "golem", "ghost"],
	},
	"whispering_mire": {
		"id": "whispering_mire",
		"kit": "res://assets/models/env/whispering_mire/",
		"fog_color": Color(0.12, 0.28, 0.16),
		"fog_density": 0.028,
		"ambient": Color(0.28, 0.42, 0.32),
		"ambient_energy": 0.42,
		"sun_color": Color(0.65, 0.9, 0.55),
		"sun_energy": 0.45,
		"sun_pitch_deg": -42.0,
		"torch_color": Color(0.55, 1.0, 0.4),
		"torch_energy": 1.8,
		"torch_range": 6.5,
		"max_torches": 8,
		"weather": "spores",
		"prop_density": 1.05,
		"outdoor": true,
		"outdoor_piece": "swamp_tree",
		"accent_piece": "glow_mushroom",
		"boss_piece": "cauldron",
		"particle_color": Color(0.6, 1.0, 0.45, 0.7),
		"species": ["slime", "shroom", "wasp", "spider", "hound", "golem", "ghost"],
	},
	"crystal_deep": {
		"id": "crystal_deep",
		"kit": "res://assets/models/env/crystal_deep/",
		"fog_color": Color(0.22, 0.14, 0.38),
		"fog_density": 0.02,
		"ambient": Color(0.32, 0.26, 0.48),
		"ambient_energy": 0.5,
		"sun_color": Color(0.7, 0.55, 1.0),
		"sun_energy": 0.55,
		"sun_pitch_deg": -50.0,
		"torch_color": Color(0.7, 0.45, 1.0),
		"torch_energy": 2.0,
		"torch_range": 7.5,
		"max_torches": 8,
		"weather": "motes",
		"prop_density": 1.0,
		"outdoor": true,
		"outdoor_piece": "crystal_cluster",
		"accent_piece": "crystal_cluster",
		"boss_piece": "geode",
		"particle_color": Color(0.75, 0.55, 1.0, 0.75),
		"species": ["crab", "golem", "bat", "wraith", "hound", "scorpion"],
	},
}

const WORLD_BY_INDEX := ["emberfall", "whispering_mire", "crystal_deep"]


static func for_level(level_idx: int) -> Dictionary:
	var world_i: int = int(level_idx / 5)
	if world_i < 0 or world_i >= WORLD_BY_INDEX.size():
		return {}
	var key: String = WORLD_BY_INDEX[world_i]
	if not WORLDS.has(key):
		return {}
	var preset: Dictionary = WORLDS[key].duplicate(true)
	preset["level_idx"] = level_idx
	preset["boss_arena"] = (level_idx % 5) == 4
	preset["lighting_boost"] = 1.3 if preset["boss_arena"] else 1.0
	if preset["boss_arena"]:
		preset["prop_density"] = float(preset["prop_density"]) * 1.35
	return preset


static func has_3d(level_idx: int) -> bool:
	return not for_level(level_idx).is_empty()
