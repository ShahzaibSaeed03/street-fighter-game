# Worlds 2–3 (awaiting approval)

Integration branch `cursor/integration-w2-w3-eb66` merges:
- `cursor/hero-3d-sprites-eb66` (base)
- `cursor/enemy-3d-pipeline-eb66` (clean merge, no conflicts)
- `cursor/env-3d-emberfall-eb66` (branch start)

## Whispering Mire (levels 5–9, boss = level 9)
Kit: `assets/models/env/whispering_mire/` (~5.0 MB GLB)
Poly Haven mud / moss / mud-rock. Custom glow mushrooms, swamp trees, reeds, water, grave, log, cauldron.
Outdoor fringe: swamp trees + water. Boss arena places cauldrons + extra mushrooms.
Fog green, spore particles.

## Crystal Deep (levels 10–14, boss = level 14)
Kit: `assets/models/env/crystal_deep/` (~3.9 MB GLB)
Poly Haven rock_05 / rock_06 / boulder_dry. Custom crystal clusters, geodes, stalactites, Kenney cave rock retargeted.
Outdoor fringe: crystal clusters. Boss arena: geodes + crystal ring.
Purple fog, mote particles.

## Tris / draw calls / FPS (one room, mid phone, gl_compatibility)
| | Whispering Mire | Crystal Deep |
|--|-----------------|--------------|
| Piece tris | floors 2–50, walls 300–600, props 28–268 | floors 2–50, walls 300–600, crystals ~30, geode ~188 |
| Visible tris / room | ~18–28k (MultiMesh floors+walls + props + outdoor fringe) | ~16–26k |
| Draw calls | ~2 MultiMesh + ~25–40 prop instances | similar |
| Lights | ≤8 Omni, no shadows | same |
| FPS estimate | 30–45 | 30–45 |

## Screenshots (Blender EEVEE GPU)
- `media/env-3d/whispering_mire/level_room_preview.png`
- `media/env-3d/whispering_mire/boss_arena_preview.png`
- `media/env-3d/crystal_deep/level_room_preview.png`
- `media/env-3d/crystal_deep/boss_arena_preview.png`

Windowed Godot did not stay up long enough for an in-engine capture on this machine. Gameplay logic unchanged.

## Stop
Worlds 4–8 not started.
