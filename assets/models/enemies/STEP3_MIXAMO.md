# STEP 3 — Mixamo enemies mobile-ready

Pipeline: `tools/blender_enemy_mixamo_pipeline.py`

- Body FBX kept intact on disk; export is a new `model.glb` beside it.
- Shared anims retargeted by `mixamorig:` bone names → NLA strips named
  `idle`, `move` (from walk), `run`, `attack`, `hit`, `death`.
- Materials darkened (grime multiply); small emissive glow-eye spheres on Head.
- Textures resized to 512; meshes decimated to ~7k tris.
- `ghost` aliases `wraith` (copied GLB + preview).

| Species | Tris (export) | GLB MB |
|---------|---------------|--------|
| skeleton | ~7k | 2.31 |
| ghoul | ~7k | 2.18 |
| golem | ~7k | 1.98 |
| imp | ~11k | 2.22 |
| wraith / ghost | ~7k | 2.74 |
| yeti | ~7k | 2.23 |
| knight | ~7k | 1.93 |

All under the ~4 MB target after recompress pass.
