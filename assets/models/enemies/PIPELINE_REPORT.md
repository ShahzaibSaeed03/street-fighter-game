# Enemy 3D pipeline — final report

## Steps

| Step | Status |
|------|--------|
| 1 FBX inspect → `REPORT.md` | Done |
| 2 Nine procedural creatures → `*/model.glb` + `preview.png` | Done |
| 3 Mixamo optimize + shared anims → GLB ≤4 MB | Done |
| 4 Godot `EnemyModels` + `EnemyLook` SubViewport on Guard | Done |
| 5 Headless verify | Done (17/17 GLB load; Splash `--quit-after 90` clean) |

## Godot integration

- Autoload: `EnemyModels` (`EnemyModels.gd`) — paths, anim resolve, SubViewport slot pool (max 10).
- `EnemyLook.gd` — prefers GLB 3D-in-2D; falls back to `CreatureArt` / `EnemyArt`.
- `Guard.gd` — uses `EnemyLook` only; sets `move_amount` / `attacking` / `dying` for anims. AI, collisions, kinds unchanged.
- Boss: ~1.6× scale + red tint on 3D mesh.
- LOD: far enemies drop to `UPDATE_WHEN_VISIBLE` then release slot beyond ~640 px.

## Headless verify

```
SUMMARY ok=17 fail=0
```

All 17 species GLBs load. Canonical anims present: idle/move/attack/hit/death (+ run on Mixamo).

Splash smoke: `godot --headless --quit-after 90` — no parse/load script errors.

## Screenshots

World roster montages (species previews per world, titles match `Worlds.gd`):

`media/enemies-3d/worlds/01_EMBERFALL.png` … `08_NIGHT_CITADEL.png`

Per-species: `media/enemies-3d/previews/<species>.png` and `assets/models/enemies/<species>/preview.png`.

Full in-dungeon GPU captures were not taken in this headless cloud session (no display). Montages cover the art roster per world.

## Size / perf estimates

| Item | Estimate |
|------|----------|
| New GLB+preview (17 species) | ~22 MB uncompressed on disk |
| APK delta (ETC2/basis + compression) | roughly **+8–14 MB** vs pre-3D-enemy build (FBX already in repo; GLBs add most of the delta) |
| Mobile FPS (gl_compatibility) | **~30–45 FPS** mid-tier with ≤10 live SubViewports @192²; drops if many on-screen without pool eviction |
| Pool cap | 10 live 3D enemies; rest use 2D fallback art |

## Files created (high level)

**Scripts:** `tools/blender/lib_common.py`, `creatures.py`, `make_*.py`, `make_all.py`, `tools/blender_enemy_mixamo_pipeline.py`, `tools/verify_enemy_models.gd`, `EnemyModels.gd`, `EnemyLook.gd`

**Assets:** `assets/models/enemies/<17 species>/model.glb` (+ `preview.png`); Mixamo `body.fbx` untouched

**Docs:** `REPORT.md` (step 1), `STEP2_CREATURES.md`, `STEP3_MIXAMO.md`, this file

## Still missing / caveats

- Procedural creatures are low-poly kitbash PBR (dark look) — not photoreal Mixamo quality.
- Mixamo exports keep leftover `Armature*|mixamo_com|Layer0*` clip names alongside clean names; resolver prefers exact `idle`/`move`/….
- In-level gameplay screenshots need a display/GPU run.
- Touch controls / shop / AI not intentionally changed; shop still uses hero 3D path.
