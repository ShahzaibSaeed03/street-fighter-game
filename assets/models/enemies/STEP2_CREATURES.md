# STEP 2 — Procedural creatures (Blender)

Built with `tools/blender/make_*.py` + `make_all.py` / `creatures.py` / `lib_common.py`.
Own geometry only (no downloaded meshes). Animations: `idle`, `move`, `attack`, `hit`, `death`.

| Species | Tris (approx) | GLB | Preview |
|---------|---------------|-----|---------|
| bat | 1248 | model.glb | preview.png |
| crab | 1764 | model.glb | preview.png |
| hound | 2154 | model.glb | preview.png |
| scorpion | 2742 | model.glb | preview.png |
| shroom | 3224 | model.glb | preview.png |
| slime | 1378 | model.glb | preview.png |
| spider | 2956 | model.glb | preview.png |
| vulture | 1050 | model.glb | preview.png |
| wasp | 1758 | model.glb | preview.png |

All under ~6k triangles. Materials use Principled BSDF (dark / dangerous look, glowing eyes where fitting).
Re-run: `blender --background --python tools/blender/make_all.py`
