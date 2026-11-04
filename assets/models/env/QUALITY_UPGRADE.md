# Quality upgrade — Emberfall, Whispering Mire, Crystal Deep

Gameplay, AI, collisions, touch controls, and the shop are unchanged. Worlds 4–8 were not started.

Renderer target is `gl_compatibility`. There is no SSAO, no volumetric fog, no SDFGI, and no screen-space reflections. Lighting is an ambient color, one orthogonal directional shadow, one unshadowed rim light, one hero point light, and four unshadowed spot lights aimed at the wall and floor (7 lights).

## What this pass changes

- Floor and wall no longer share a material. The floor keeps the cracked ground / mud / rock map. The wall uses a different Poly Haven map (herringbone, moss brick, or rock_06) at a lower value, with a bright top rim and a dark foot. A separate unshaded strip sits where the wall meets the floor.
- Walls are taller and thicker (`Vector3(1.0, 1.65, 2.1)` on the procedural wall). Kenney wall modules stay out: `template-wall.glb` is about 448 triangles, and a room has about 50 segments, which is over the 15k cap before any props.
- Emberfall places a lava river and two pools in every room, plus a transparent heat sheet and rising ember particles. The lava shader keeps a dark rim and an orange-yellow crack. Emission stays under white.
- Whispering Mire and Crystal Deep place glossy water planes in every room. Mire fog is lighter than the first retry so the floor can read, and two crooked trees sit at the room edges.
- Prop spots are larger than the first pass (about 1.55–2.05, crystals and mushrooms higher) and grouped on the open floor. Crates, barrels, pillars, statues, banners, logs, graves, reeds, rocks, and roots are decimated Kenney CC0 meshes with one Poly Haven material override. Crystals, mushrooms, lava, chains, cobwebs, and bone piles stay the custom meshes, because those kits do not include them.
- Crystal walls get a vein term in `shaders/env_surface.gdshader`. It is a sine mask, not a modeled crack.

## Godot renders (`gl_compatibility`)

New shots: `media/env-3d/godot/`. `view3d_*.png` is the 3D view. The file without that prefix is the full frame. The previous Godot shots are in `media/env-3d/godot-before/`.

| Shot | Worst room triangles | Room draw calls | Instances counted per room |
| --- | --- | --- | --- |
| Emberfall level and boss | 7,598 | 22 | 37 |
| Mire level | 11,730 | 18 | 41 |
| Mire boss | 13,804 | 21 | 41 |
| Crystal Deep level and boss | 7,568 | 20 | 38 |

Those instance counts include lava, water, and repeated dressing. They are not a count of distinct props you can name in the screenshot. Room budgets stay under 15k triangles and under 30 draw calls.

## What the screenshots actually show

- Emberfall walls are darker than the floor, with a bright top edge, a dark base, herringbone on the wall, and cracked stone on the floor. That part of the request is visible.
- Lava is a glowing strip in the boss frame and a smaller strip in the level frame. It does not read as several rivers and pools. Props sit on top of it, and the mesh is still a flat plane.
- The framed floor does not show 20 separate props. The room does instance that many, but the 3/4 camera (player start is `origin + (170, 324)`, not the room center) only shows a cluster: a barrel, torches, a pillar, rubble, and one large blocky piece. A lot of the dressing is off that view or merged into one silhouette.
- Whispering Mire has a lighter mossy floor, a darker brick wall, one crooked tree, a mushroom cluster, and a crate. It does not read as a swamp. The water planes do not show up as reflective pools in the level frame. There are no fog layers, no reed bed, and no firefly field you can see.
- Crystal Deep shows larger glowing crystal clusters, two pillars, and flat blue puddles. Wall “veins” are soft blobs from the sine mask. The puddles do not reflect the room.

## Limits of this renderer and these meshes

These are not a claim that the pass matches the review.

- Water cannot reflect the room. `gl_compatibility` has no screen-space reflections. `shaders/water_gloss.gdshader` is a glossy fresnel of the fog color.
- Heat does not bend the image. A refraction shader needs the screen texture, which this renderer does not provide. The haze sheet is a transparent scrolling quad.
- Fog is one distance fog. Layered fog banks are volumetric, which this renderer does not have.
- Kenney props were decimated to roughly 80–180 triangles and then given one shared floor texture, so they read as dressed shapes. The source GLBs on disk have more detail, and using that detail on every spot breaks the 15k cap.
- Crystals are opaque cones with emission. They are not translucent.

## Assets that would close the gap

Put new files under `assets/textures/env_cc0/` or `assets/models/env_cc0/` and leave worlds 4–8 alone.

1. A real lava material, not a sine shader. CC0 sets from ambientCG (search “Lava” on https://ambientcg.com/) — albedo, roughness, normal, and emission. A second mesh that is a channel cut into the floor, not a rectangle laid on top. Drop the textures in `assets/textures/env_cc0/polyhaven_w1_emberfall/lava/`.
2. Fake reflections. A CC0 cave HDRI and a swamp HDRI from https://polyhaven.com/hdris , saved under `assets/textures/env_cc0/hdri/`. Godot can use those on a reflection probe. They still will not reflect the crates in the room.
3. Hero props at useful poly. The Kenney kits already in `assets/models/env_cc0/` are the right library (castle, graveyard, pirate, nature, fantasy town). Use a few of them per room at their original triangle count instead of 24 decimated copies. For weapon racks, bone piles, and chains, Kenney does not ship those. Quaternius CC0 dungeon and nature packs are at https://quaternius.com/packs.html (Ultimate Dungeon and Ultimate Nature). Mushrooms with a stalk and cap are already on disk: `assets/models/env_cc0/kenney_nature-kit/Models/GLTF format/mushroom_redGroup.glb`. Reeds: `grass_large.glb` and `plant_flatTall.glb` in that same folder.
4. Wall modules only if each room uses long pieces, not one module per 2 m. `assets/models/env_cc0/` castle and fantasy-town wall GLBs are about 400 triangles. Fifty of them do not fit. About sixteen long pieces plus the props can fit.

## Capture command

Windowed Godot, not `--headless`. One shot per process:

```
set CAPTURE_ONLY=emberfall_level.png
Godot_v4.7.2-stable_win64.exe --path W:\street-fighter-game --rendering-method gl_compatibility --script res://tools/capture_worlds.gd
```

`CAPTURE_ONLY` is one of `emberfall_level.png`, `emberfall_boss.png`, `mire_level.png`, `mire_boss.png`, `crystal_level.png`, `crystal_boss.png`.
