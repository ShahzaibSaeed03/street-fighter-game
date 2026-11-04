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
		"ambient_energy": 1.15,
		"sun_color": Color(1.0, 0.55, 0.25),
		"sun_energy": 0.7,
		"sun_pitch_deg": -48.0,
		"torch_color": Color(1.0, 0.45, 0.15),
		"torch_energy": 1.35,
		"torch_range": 7.0,
		"max_torches": 8,
		"weather": "embers",
		"prop_density": 1.0,
		"outdoor": false,
		"outdoor_piece": "",
		"accent_piece": "brazier",
		"boss_piece": "brazier",
		"ceiling_piece": "ceiling_beam",
		"particle_color": Color(1.0, 0.4, 0.08, 0.8),
		"floor_albedo": "res://assets/textures/env_cc0/polyhaven_w1_emberfall/volcanic_rock_tiles/volcanic_rock_tiles_Diffuse_1k.jpg",
		"floor_detail": "res://assets/textures/env_cc0/polyhaven_w1_emberfall/rock_boulder_cracked/rock_boulder_cracked_Diffuse_1k.jpg",
		"floor_rough": "res://assets/textures/env_cc0/polyhaven_w1_emberfall/volcanic_rock_tiles/volcanic_rock_tiles_Rough_1k.jpg",
		"floor_normal": "res://assets/textures/env_cc0/polyhaven_w1_emberfall/volcanic_rock_tiles/volcanic_rock_tiles_nor_gl_1k.jpg",
		"surface_tint": Color(1.0, 0.78, 0.52),
		"wall_albedo": "res://assets/textures/env_cc0/polyhaven_w1_emberfall/volcanic_herringbone_01/volcanic_herringbone_01_Diffuse_1k.jpg",
		"wall_detail": "res://assets/textures/env_cc0/polyhaven_w1_emberfall/rock_boulder_cracked/rock_boulder_cracked_Diffuse_1k.jpg",
		"wall_rough": "res://assets/textures/env_cc0/polyhaven_w1_emberfall/volcanic_herringbone_01/volcanic_herringbone_01_Rough_1k.jpg",
		"wall_normal": "res://assets/textures/env_cc0/polyhaven_w1_emberfall/volcanic_herringbone_01/volcanic_herringbone_01_nor_gl_1k.jpg",
		"wall_tint": Color(0.42, 0.2, 0.12),
		"hdri": "res://assets/textures/env_cc0/hdri/cave_wall_1k.hdr",
		"wet_strength": 0.12,
		"dressing": ["crate", "barrel", "pillar", "statue", "rubble", "banner", "doorway", "corner_tower", "arch"],
		"species": ["imp", "hound", "bat", "knight", "ghoul", "golem", "ghost"],
	},
	"whispering_mire": {
		"id": "whispering_mire",
		"kit": "res://assets/models/env/whispering_mire/",
		"fog_color": Color(0.12, 0.28, 0.16),
		"fog_density": 0.02,
		"ambient": Color(0.28, 0.42, 0.32),
		"ambient_energy": 1.4,
		"sun_color": Color(0.65, 0.9, 0.55),
		"sun_energy": 0.75,
		"sun_pitch_deg": -42.0,
		"torch_color": Color(0.55, 1.0, 0.4),
		"torch_energy": 1.15,
		"torch_range": 6.5,
		"max_torches": 8,
		"weather": "spores",
		"prop_density": 1.05,
		"outdoor": true,
		"outdoor_piece": "swamp_tree",
		"accent_piece": "glow_mushroom",
		"boss_piece": "cauldron",
		"ceiling_piece": "hanging_moss",
		"particle_color": Color(0.6, 1.0, 0.45, 0.7),
		"floor_albedo": "res://assets/textures/env_cc0/polyhaven_w2_whispering_mire/brown_mud_leaves_01/brown_mud_leaves_01_Diffuse_1k.jpg",
		"floor_detail": "res://assets/textures/env_cc0/polyhaven_w2_whispering_mire/brick_moss_001/brick_moss_001_Diffuse_1k.jpg",
		"floor_rough": "res://assets/textures/env_cc0/polyhaven_w2_whispering_mire/brown_mud_leaves_01/brown_mud_leaves_01_Rough_1k.jpg",
		"floor_normal": "res://assets/textures/env_cc0/polyhaven_w2_whispering_mire/brown_mud_leaves_01/brown_mud_leaves_01_nor_gl_1k.jpg",
		"surface_tint": Color(0.78, 0.95, 0.62),
		"wall_albedo": "res://assets/textures/env_cc0/polyhaven_w2_whispering_mire/brick_moss_001/brick_moss_001_Diffuse_1k.jpg",
		"wall_detail": "res://assets/textures/env_cc0/polyhaven_w2_whispering_mire/brown_mud_rocks_01/brown_mud_rocks_01_Diffuse_1k.jpg",
		"wall_rough": "res://assets/textures/env_cc0/polyhaven_w2_whispering_mire/brick_moss_001/brick_moss_001_Rough_1k.jpg",
		"wall_normal": "res://assets/textures/env_cc0/polyhaven_w2_whispering_mire/brick_moss_001/brick_moss_001_nor_gl_1k.jpg",
		"wall_tint": Color(0.55, 0.68, 0.46),
		"hdri": "res://assets/textures/env_cc0/hdri/mossy_forest_1k.hdr",
		"wet_strength": 0.45,
		"dressing": ["glow_mushroom", "log", "reeds", "plants", "grave", "gravestone", "roots", "swamp_tree", "hanging_moss", "doorway", "corner_tower", "arch"],
		"species": ["slime", "shroom", "wasp", "spider", "hound", "golem", "ghost"],
	},
	"crystal_deep": {
		"id": "crystal_deep",
		"kit": "res://assets/models/env/crystal_deep/",
		"fog_color": Color(0.22, 0.14, 0.38),
		"fog_density": 0.02,
		"ambient": Color(0.32, 0.26, 0.48),
		"ambient_energy": 1.1,
		"sun_color": Color(0.7, 0.55, 1.0),
		"sun_energy": 0.55,
		"sun_pitch_deg": -50.0,
		"torch_color": Color(0.7, 0.45, 1.0),
		"torch_energy": 1.2,
		"torch_range": 7.5,
		"max_torches": 8,
		"weather": "motes",
		"prop_density": 1.0,
		"outdoor": true,
		"outdoor_piece": "crystal_cluster",
		"accent_piece": "crystal_cluster",
		"boss_piece": "geode",
		"ceiling_piece": "stalactite",
		"particle_color": Color(0.75, 0.55, 1.0, 0.75),
		"floor_albedo": "res://assets/textures/env_cc0/polyhaven_w3_crystal_deep/rock_05/rock_05_Diffuse_1k.jpg",
		"floor_detail": "res://assets/textures/env_cc0/polyhaven_w3_crystal_deep/rock_boulder_dry/rock_boulder_dry_Diffuse_1k.jpg",
		"floor_rough": "res://assets/textures/env_cc0/polyhaven_w3_crystal_deep/rock_05/rock_05_Rough_1k.jpg",
		"floor_normal": "res://assets/textures/env_cc0/polyhaven_w3_crystal_deep/rock_05/rock_05_nor_gl_1k.jpg",
		"surface_tint": Color(0.82, 0.78, 1.0),
		"wall_albedo": "res://assets/textures/env_cc0/polyhaven_w3_crystal_deep/rock_06/rock_06_Diffuse_1k.jpg",
		"wall_detail": "res://assets/textures/env_cc0/polyhaven_w3_crystal_deep/rock_boulder_dry/rock_boulder_dry_Diffuse_1k.jpg",
		"wall_rough": "res://assets/textures/env_cc0/polyhaven_w3_crystal_deep/rock_06/rock_06_Rough_1k.jpg",
		"wall_normal": "res://assets/textures/env_cc0/polyhaven_w3_crystal_deep/rock_06/rock_06_nor_gl_1k.jpg",
		"wall_tint": Color(0.5, 0.42, 0.68),
		"hdri": "res://assets/textures/env_cc0/hdri/cave_wall_1k.hdr",
		"wet_strength": 0.22,
		"dressing": ["crystal_cluster", "crystal_cyan", "crystal_pink", "stalactite", "cave_rock", "statue", "pillar", "doorway", "corner_tower", "arch"],
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
