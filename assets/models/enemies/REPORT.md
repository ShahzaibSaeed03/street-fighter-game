# Mixamo enemies — STEP 1 report

## Bodies

| Species | MB | Kaydara | Meshes | Tris | Bones | Textures |
|---|---:|:---:|---:|---:|---:|---|
| skeleton | 17.51 | True | 1 | 12486 | 73 | file1 [2048, 2048], file1.001 [2048, 2048], file3 [2048, 2048], file4 [2048, 2048], file6 [2048, 2048], file7 [2048, 2048] |
| ghoul | 13.77 | True | 1 | 14934 | 72 | file5 [2048, 2048], file6 [2048, 2048], file7 [2048, 2048] |
| golem | 13.42 | True | 1 | 9620 | 66 | file1 [2048, 2048], file2 [2048, 2048] |
| imp | 11.33 | True | 8 | 16318 | 79 | file1 [2048, 2048], file2 [2048, 2048], file3 [2048, 2048] |
| wraith | 16.13 | True | 1 | 15021 | 99 | file11 [2048, 2048], file11.001 [2048, 2048], file6 [512, 512], file7 [2048, 2048], file8 [2048, 2048], file9 [2048, 2048] |
| yeti | 12.07 | True | 1 | 12626 | 81 | file1 [2048, 2048], file2 [2048, 2048], file3 [2048, 2048] |
| knight | 9.05 | True | 2 | 14660 | 67 | file1 [2048, 2048], file3 [2048, 2048], file4 [2048, 2048] |

## Shared animations

| Anim | MB | Kaydara |
|---|---:|:---:|
| idle | 0.618 | True |
| walk | 0.67 | True |
| attack | 0.62 | True |
| death | 0.669 | True |
| hit | 0.55 | True |
| run | 0.34 | True |
| slash | 0.426 | True |

## Notes
- Bone prefixes may be `mixamorig:` or `mixamorigN:` — normalize in export pipeline.
- `wraith` GLB will also cover game species `ghost`.
- Missing (non-Mixamo): bat, crab, hound, scorpion, shroom, slime, spider, vulture, wasp.
