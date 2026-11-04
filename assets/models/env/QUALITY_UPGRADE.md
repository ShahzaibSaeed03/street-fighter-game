# Quality upgrade — Emberfall, Whispering Mire, Crystal Deep

Gameplay, AI, collisions, touch controls, and the shop are unchanged. Worlds 4–8 were not started. The Quaternius folder was not on disk, so those packs were skipped.

Renderer is `gl_compatibility`. No SSAO, no volumetric fog, no SDFGI, no screen-space reflections.

## What this pass changes

- The 3D camera sits closer (`(0.35, 7.2, 8.0)`, fov 46) so the first frame is the area around the player. Level rooms dress a cluster within about 6 m of `origin + (170, 324)`. Boss rooms dress the same cluster around the room center, which is where the capture teleports the player.
- Each room uses 8–12 Kenney meshes (castle doorway, corner, arch, plus crates, barrels, pillars, statues, trees, graves, reeds, plants). They are decimated to at most 500 triangles and retextured with the Poly Haven floor material. Mushrooms are `mushroom_redGroup.glb`, recolored with a teal emission. Repeated meshes are one MultiMesh.
- Plain walls stay the textured modules. Kenney wall pieces are only the doorway, corner, and arch. The wall shader keeps the dark foot, bright top rim, stain, and a thin crack. Crystal veins are thin emissive lines, not blobs.
- Emberfall lava uses ambientCG Lava001 (color, emission, normal, roughness) with a scrolling UV. Each room has one river and two pools, a raised stone bank, a crack decal, a haze sheet, and rising embers. Emission is clamped so it stays orange.
- Sky and ambient come from `cave_wall_1k.hdr` (Emberfall, Crystal Deep) or `mossy_forest_1k.hdr` (Mire). Water samples that panorama for a fake reflection, with two scrolling normals. Three low fog sheets and three additive shafts sit in the cluster.

## Godot frames

New shots: `media/env-3d/godot/`. Previous shots: `media/env-3d/godot-before/`. Side by side: `media/env-3d/godot/compare/`. `view3d_*.png` is the 3D view.

| Shot | Worst room triangles | Room draw calls |
| --- | --- | --- |
| Emberfall level and boss | 6,891 | 26 |
| Mire level | 7,146 | 17 |
| Mire boss | 7,438 | 20 |
| Crystal Deep level and boss | 6,390 | 20 |

Under 15k triangles and under 30 draw calls.

## Still not possible here

- The lava sits in a raised stone rim on top of the floor tiles. The floor is a full tile grid, so the channel is not a boolean hole cut out of those tiles.
- Water does not reflect the crates. `gl_compatibility` has no screen-space reflections. The shader samples the HDRI panorama.
- Heat does not bend the image. The haze is a scrolling transparent sheet, and props next to lava use a warmer tint.
- Fog sheets and light shafts are transparent cards and cones, not volumetric fog.
- Weapon racks, bone piles, and chains were not added. Those are in the Quaternius packs, and `assets/models/env_cc0/quaternius/` was not on disk.
