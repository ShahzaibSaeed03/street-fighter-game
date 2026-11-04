# Quality upgrade — Emberfall, Whispering Mire, Crystal Deep

Gameplay, AI, collisions, and the shop are unchanged. Worlds 4–8 were not started.

Renderer target is `gl_compatibility` (no SSAO, no volumetric fog, no SDFGI). Lighting is an ambient color, one orthogonal directional shadow, one unshadowed rim, one hero point light, and up to four unshadowed room lights.

## What changed

- Floors and walls use one world-space material per world (`shaders/env_surface.gdshader`), so neighboring tiles share UVs instead of a checkerboard of different textures. A second Poly Haven map stains wear into the albedo. Roughness drops slightly on those stains (wet stone / mud).
- Ambient and fog are raised and graded: Emberfall red-orange, Mire green, Crystal Deep purple. The 2D vignette uses that fog color at strength 0.34 unless health is low (the low-health red vignette is unchanged).
- Lava is a dark basalt rim with a scrolling crack shader. Emission is capped so the pool does not clip to white.
- Crystals are faceted clusters in purple, cyan, and pink, with a rock base. Mushrooms are a stalk, cap, gills, and spots, in a cluster of three sizes. Emission stays near 1.0.
- Each room places 22 story props along the walls and corners (torches, crates, graves, cages, bones, chains, cobwebs, and the world hero prop), plus ceiling pieces on the wall line. Repeated props are one MultiMesh per mesh per room.

## Godot renders (`gl_compatibility`, Intel UHD)

Shots are in `media/env-3d/godot/`. `view3d_*.png` is the 3D viewport. The matching file without that prefix is the full game frame. Before shots are the Blender room previews in `media/env-3d/emberfall/`, `media/env-3d/whispering_mire/`, and `media/env-3d/crystal_deep/`.

| Shot | Worst room triangles | Room draw calls | Full-frame FPS in this capture |
| --- | --- | --- | --- |
| Emberfall level and boss | 6,076 | 20 | 16–26 |
| Mire level | 9,344 | 20 | 26 |
| Mire boss | 11,308 | 23 | 25 |
| Crystal Deep level and boss | 7,156 | 20 | 24–29 |

Room budgets are under 15k triangles and under 30 draw calls. The full frame on this PC also reported about 480–870 draw calls and ~390k primitives. Culling the 3D room did not drop that counter, so it is the rest of the frame (2D dungeon, HUD, enemy portrait viewports), not the room kit. A mid-range phone has headroom on the room itself; this Intel UHD capture of the whole game sat around 16–29 fps while the screenshot script was running.

## Still simple on purpose

Props are low-poly silhouettes sized for the triangle cap: crates, graves, crystals, and mushrooms read at a glance, and they are not sculpted set pieces. Lava only appears in rooms that already have lava pools.

## Capture command

Windowed Godot, not `--headless`. One shot per process (the root viewport texture stayed stuck when several levels were captured in one launch):

```
set CAPTURE_ONLY=emberfall_level.png
Godot_v4.7.2-stable_win64.exe --path W:\street-fighter-game --rendering-method gl_compatibility --script res://tools/capture_worlds.gd
```

`CAPTURE_ONLY` accepts `emberfall_level.png`, `emberfall_boss.png`, `mire_level.png`, `mire_boss.png`, `crystal_level.png`, `crystal_boss.png`.
