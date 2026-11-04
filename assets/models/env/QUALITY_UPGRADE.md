# Quality upgrade — Emberfall, Whispering Mire, Crystal Deep

Gameplay, AI, collisions, touch controls, and the shop are unchanged. Worlds 4–8 were not started.

Renderer is `gl_compatibility`. No SSAO, no volumetric fog, no SDFGI, no screen-space reflections.

## Layout pass

Props sit in small groups along the walls and in the corners. The east-west walk through the middle of the room, the north-south walk, the door gaps, and the area around the player start stay clear. Kenney doorways and arches are placed on the door opening, and corner towers sit on the wall corners.

The 3D camera is `(0.4, 9.6, 10.8)`, fov 43, so the player, enemies, and pickups read. The 2D camera is unchanged.

Emberfall lava follows the tile grid. Those floor tiles are lowered 0.55 m. A rounded lava surface sits in the trench, with a dark crust from the shader and a sloped stone riser on each open edge. The old spiky bank and crack cards are gone. One unshadowed orange light warms the floor next to the channel. Emission stays clamped so the lava does not blow out to white.

Crystal walls use sparse, broken veins mixed into the rock, with a low glow. Crystal clusters sit on the north bank and in the corners. The neon grid is gone.

Whispering Mire uses the Kenney tree-log, turned so the trunk runs along the north wall. Mushroom clusters, roots, a grave, one swamp tree, and hanging moss sit off the walk. The flat reed cards are not placed. Water is the same kind of lowered-tile pool, with a visible fill and a dark rim.

The hard triangle light shafts are gone. One low fog sheet remains, plus the cheap environment fog. Each world keeps its grade and adds a second hue: a cool rim in Emberfall, warm torch light in the Mire and Crystal Deep.

## Godot frames

Shots are in `media/env-3d/godot/`. `view3d_*.png` is the 3D view only. Counts below are `Env3D.debug_stats()` for the heaviest room. The full-frame performance counter is much higher because it includes the 2D dungeon and the HUD.

| Shot | Worst room triangles | Room draw calls |
| --- | --- | --- |
| Emberfall level and boss | 7,072 | 20 |
| Whispering Mire level and boss | 6,908 | 14 |
| Crystal Deep level and boss | 6,412 | 20 |

Under 15k triangles and under 30 draw calls.

## Still not possible here

- The trench is lowered floor tiles plus a riser, not a boolean hole cut out of one mesh. From this camera the stone bank reads as a dark rim around the lava.
- Water does not reflect the room. `gl_compatibility` has no screen-space reflections. The shader samples the HDRI panorama.
- Heat does not bend the image.
- A pale wedge in the full frame is the enemy's 2D sight marker. The 3D shafts that drew hard triangles were removed.
- Weapon racks, bone piles, and chains were not added. `assets/models/env_cc0/quaternius/` was not on disk.
