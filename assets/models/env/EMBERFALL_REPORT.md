# Emberfall (World 1) — 3D environment (awaiting approval)

**Stop here:** Worlds 2–8 not started until Emberfall look is approved.

## Step 1 — Audit
- `assets/models/env_cc0/AUDIT.md` (+ `AUDIT.json`)
- Dungeon/cave GLBs measured; Kenney corridor ≈ 4 units → scale **0.5** for 2 m tile
- Licenses copied to `assets/licenses/*-License.txt`

## Step 2 — Blender kit
Scripts: `tools/blender/env/emberfall_kit.py`, `emberfall_room_preview.py`, `audit_kits.py`

Exports: `assets/models/env/emberfall/*.glb` (~4.6 MB total @ 512 PBR) + `preview_kit.png`

Pieces: floor_a/b/c, wall_straight/corner/end/t, door_frame, door, arch, pillar, stairs, ceiling, lava_plane, brazier, rubble, bone_pile, cracked_statue, ash_heap, chains, ember_rock, gate (+ Kenney retargets)

Materials: Poly Haven volcanic_rock_tiles / volcanic_herringbone_01 / rock_boulder_cracked (diffuse+normal+rough), bevel + light displace, decimated for mobile.

## Step 3 — Godot
- `Env3D.gd` — SubViewport CanvasLayer backdrop; MultiMesh floors/walls; props; torch OmniLights (cap 8); fog; ember GPUParticles; camera ~60° follow
- `Levels3D.gd` — Emberfall preset only (`has_3d` for levels 0–4)
- `Dungeon.gd` — accessors + `env3d_overlay` (ghost 2D floor/walls; collisions unchanged)
- `Game.gd` — wires Env3D when Emberfall

## Step 4 — Level data
Emberfall levels 0–4 via `Levels3D.for_level`; boss (level 4) gets lighting_boost.

## Screenshots (approval)
- `media/env-3d/emberfall/level01_room_preview.png`
- `media/env-3d/emberfall/boss_arena_preview.png`
- `media/env-3d/emberfall/preview_kit.png`

In-engine GPU captures of Main.tscn not taken in this headless session (Blender room layout matches the kit Env3D loads).

## Perf estimate (Emberfall)
| Metric | Estimate |
|--------|----------|
| Kit on disk | ~4.6 MB GLB + textures already in `assets/textures` |
| APK delta | ~+3–6 MB (ETC2) for Emberfall only |
| Tris / room | floors Multimesh ~ few hundred instances × &lt;1k tris; walls similar; props LOD via visibility range |
| Draw calls | MultiMesh floors/walls + limited props; max 8 OmniLights, no shadows |
| FPS target | 30+ mid Android (gl_compatibility) |

## Still missing (by design until approval)
- Worlds 2–8 kits / presets
- Shared atlas bake (currently per-piece 512 embeds)
- Outdoor Emberfall ash fields
- Full in-game screenshot pass on device/GPU
