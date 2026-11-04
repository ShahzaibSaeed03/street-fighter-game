extends RefCounted
## Levels3D.gd — per-level 3D environment presets (World 1 Emberfall first).
## Other worlds stay on the 2D fallback until approved.

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
		"species": ["imp", "hound", "bat", "knight", "ghoul", "golem", "ghost"],
	},
}


static func for_level(level_idx: int) -> Dictionary:
	# Levels 0-4 = Emberfall (world 0). Only Emberfall ships 3D kit for now.
	var world_i: int = int(level_idx / 5)
	if world_i != 0:
		return {}
	var preset: Dictionary = WORLDS["emberfall"].duplicate(true)
	preset["level_idx"] = level_idx
	preset["boss_arena"] = (level_idx % 5) == 4
	preset["lighting_boost"] = 1.25 if preset["boss_arena"] else 1.0
	return preset


static func has_3d(level_idx: int) -> bool:
	return not for_level(level_idx).is_empty()
